[⬅ Module 01](../../README.md) | [1.1 Engine Architecture](../01_Engine_Architecture_SQLOS/README.md) | Section 2/5 | ➡ ถัดไป: [03 NUMA](../03_NUMA_Architecture/README.md)

# 1.2 Scheduling — Windows จัดคิวแบบไหน, SQL Server จัดคิวแบบไหน

> *"CPU หนึ่ง core รันได้ครั้งละหนึ่ง task เท่านั้น ทุกอย่างที่เหลือคือเรื่องของการจองคิว"*

## เปิดเรื่อง: ทำไม DBA ต้องเข้าใจ Scheduler

เวลา query ช้า หลายคนคิดถึง disk หรือ index ก่อน แต่คอขวดที่พบบ่อยอันดับต้น ๆ คือ **CPU scheduling** — และ SQL Server ไม่ได้ปล่อยให้ Windows จัดคิวให้ แต่สร้างระบบจัดคิวของตัวเองชื่อ **SQLOS Scheduler** คนที่เข้าใจกลไกนี้จะอ่านสัญญาณ CPU pressure ได้ก่อนคนอื่นหลายก้าว

---

## 1. Preemptive vs Non-Preemptive (Cooperative) Scheduling

| Aspect | Windows (Preemptive) | SQL Server (Non-Preemptive / Cooperative) |
|:-------|:---------------------|:------------------------------------------|
| **การหยุด Thread** | OS สั่งหยุด (Force) เมื่อหมด Time Slice | Thread หยุดเอง (Yield) เมื่อทำงานเสร็จหรือต้องรอ |
| **Quantum** | ~15.6 ms | ~4 ms |
| **Context Switch** | OS-managed (overhead สูงกว่า) | Application-managed (เบากว่ามาก) |
| **ผู้ควบคุม** | Windows Kernel | SQLOS |

```mermaid
sequenceDiagram
    participant Task1
    participant Scheduler
    participant Task2
    Note over Task1,Task2: Cooperative Scheduling
    Task1->>Scheduler: Running (uses CPU)
    Note right of Task1: ทำงานจนต้องรอ resource<br/>หรือครบ quantum 4ms
    Task1->>Scheduler: Yield!
    Scheduler->>Task2: Your turn
    Task2->>Scheduler: Running
    Task2->>Scheduler: Yield!
    Scheduler->>Task1: Resume
```

**เหตุผลที่ SQL Server เลือก Cooperative:**
- ลด context switch overhead — ตัดการประกาศจาก kernel ออก
- SQL Server รู้บริบทของงานดีกว่า OS (เช่น ตอนรอ I/O หรือ Lock ควรยอมแพ้ CPU ทันที)
- ผู้เขียน engine ควบคุม fairness ของคิวได้เองผ่านอัลกอริทึม

> [!WARNING]
> **lightweight pooling (fiber mode)** เทคนิคยุค 90s ที่พยายามลด context switch ด้วย user-mode fibers — **ถูกประกาศ deprecated ใน SQL Server 2025** และทำให้ CLR/XML/Linked Server ทำงานผิดปกติ อย่าตั้งค่านี้อีกต่อไป

---

## 2. SOS Scheduler — Scheduler-managed Lists (ห้าคิวในหนึ่ง scheduler)

แผนภาพใน Section 1.2 (ด้านขวา) คือหัวใจของ scheduler: task เปลี่ยน "State" ไปเรื่อย ๆ และ SQLOS จัดเก็บ worker ตามสถานะนั้นไว้ใน "List" ของ scheduler

> ✦ **State** บอกว่า *"worker กำลังทำอะไร"* — ✦ **List** บอกว่า *"worker กำลังรออะไร"*

| List | หน้าที่ |
|:-----|:--------|
| **Worker list** | Workers ที่ว่างอยู่ |
| **Runnable list** | Workers ที่รอ CPU (state: runnable) |
| **Waiter list** | Workers ที่รอ resource (state: suspended) |
| **I/O list** | คำขอ I/O ที่ค้างอยู่ |
| **Timer list** | Workers ที่จองเวลาทำงานล่วงหน้า (เช่น WAITFOR DELAY) |

- **หนึ่ง scheduler ให้ CPU กับ worker ได้ครั้งละหนึ่งตัว** — worker ตัวอื่นต้องต่อคิว
- worker ที่รอ resource จะออกจาก CPU และกลับเข้า Runnable เมื่อพร้อม
- อ่านค่าจริงจาก `sys.dm_os_schedulers`: `runnable_tasks_count` คือความยาวของ Runnable list

---

## 3. Quantum หมด → กลับเข้า Runnable (เส้นทางสีแดงใน diagram)

worker ที่ได้ CPU จะครองมันได้ไม่เกิน **quantum ~4 ms** ถ้างานยังไม่จบต้องยอม (yield) แล้วกลับเข้า Runnable list ต่อท้ายคิว:

- กลับเข้า Runnable รอบละครั้งเป็นเรื่องปกติของระบบ — แต่ถ้า **ย้อนกลับถี่มากและ Runnable list ยาวต่อเนื่อง** = งานล้น CPU
- เวลาที่เสียไปกับการต่อคิวนี้คือ **Signal Wait** — วัดได้จาก:

```sql
SELECT SUM(signal_wait_time_ms) * 1.0 / SUM(wait_time_ms) * 100 AS signal_wait_pct
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > 0;
-- > 10-15% ต่อเนื่อง = CPU pressure
```

- wait type ที่บันทึกตอน quantum หมดคือ `SOS_SCHEDULER_YIELD` — เจอเยอะใน top waits = ตรวจงาน CPU หนักก่อนเป็นอย่างแรก

---

## 4. User Request Life Cycle — แต่ละขั้นดู DMV ไหน

การเดินทางของ request สอดคล้องกับ state ของ worker ทุกขั้น:

| # | ขั้น | DMV | สถานะที่เกี่ยวข้อง |
|:-:|:-----|:----|:-------------------|
| 1 | Connection established | `sys.dm_exec_connections` | — |
| 2 | Session ID assigned | `sys.dm_exec_sessions` | — |
| 3 | Request created | `sys.dm_exec_requests` | task กำลังจะเกิด |
| 4 | Task(s) created | `sys.dm_os_tasks` | อาจแตกหลาย task ถ้า parallel |
| 5 | Task → Worker | `sys.dm_os_workers` | RUNNING เมื่อได้ CPU |
| 6 | Worker บน OS Thread | `sys.dm_os_threads` | — |
| 7 | Scheduler จัดคิว | `sys.dm_os_schedulers` | RUNNABLE เมื่อต่อคิว |

- 1 connection อาจมีหลาย session; 1 request อาจแตกเป็นหลาย task เมื่อ parallel plan
- `max_worker_threads` (default 0 = auto) คือเพดาน worker — ถ้าหมด เกิด wait `THREADPOOL` ซึ่งเป็นภาวะวิกฤต

---

## 5. Thread Life Cycle (State Machine)

![Thread Life Cycle (State Machine) — worker state transitions และ scheduler-managed lists](images/thread-life-cycle.png)

**อ่านด้านซ้าย (Worker State Transitions) เป็นเรื่องราว:**

1. task เข้ามาใหม่ → ต่อคิวที่ **RUNNABLE QUEUE** (state: runnable)
2. เมื่อถึงคิว scheduler **มอบ CPU** → **RUNNING ON CPU** (state: running)
3. ทำงานสำเร็จ → **COMPLETED** — จบการทำงาน
4. ถ้าระหว่างทางต้องรอ I/O หรือ resource (ไม่ใช่ CPU) → ถูก block เข้าสู่ **SUSPENDED / WAITER** (state: suspended)
5. เมื่อ **resource พร้อม** → กลับเข้า **RUNNABLE** ต่อคิวใหม่
6. ถ้าใช้ CPU ครบ **Quantum** แต่งานยังไม่จบ → กลับเข้า **RUNNABLE** เช่นกัน

**อ่านสถานะให้เป็นเรื่อง:**
- Response Time = **Service Time** (RUNNING) + **Resource Wait** (SUSPENDED) + **Signal Wait** (RUNNABLE)
- แก้ผิดจุด = เสียเวลาเปล่า: งานรอ disk ไปเพิ่ม CPU ก็ไม่ช่วย

---

## 6. หัวข้อขั้นสูงที่ควรรู้

---

## 6. หัวข้อขั้นสูงที่ควรรู้

- **Large Deficit First (LDF)** — อัลกอริทึมจัดคิว (2016+) ป้องกัน task ใหญ่ (เช่น read-ahead) แย่ง CPU จน task เล็กอดรัน
- **Hidden Schedulers** — scheduler สำหรับงานระบบ: Ghost Cleanup, Query Store async, Checkpoint และ **DAC** (Dedicated Admin Connection ไว้กู้ชีพเมื่อ server ค้าง)
- **PREEMPTIVE_\* waits** — เมื่อ SQL Server ต้องเรียก Windows API นอก SQLOS (เช่น `PREEMPTIVE_OS_FILEOPS`) สูงผิดปกติมักมาจาก Linked Server / xp_cmdshell / CLR
- **SQL Server 2025:** `lightweight pooling` ถูกประกาศ deprecated — cooperative scheduling คือโมเดลเดียวที่เหลืออยู่

---

## สรุป Section 2

1. SQL Server จัดคิว CPU เองแบบ **Cooperative** (quantum ~4 ms, thread yield เอง)
2. อาการ CPU pressure อ่านได้จาก **runnable queue** และ **Signal Wait Ratio** ไม่ใช่แค่ % CPU
3. Life cycle 3 สถานะ **RUNNABLE → RUNNING → SUSPENDED** คือภาษากลางของการวินิจฉัย

**ตรวจความเข้าใจ:**
1. task อยู่ใน Runnable List แปลว่ากำลังรออะไร? ต่างจาก Waiter List อย่างไร?
2. CPU utilization 60% แต่ query ช้า — กลไกไหนอธิบายสถานการณ์นี้ได้?

**➡ ถัดไป:** [Section 1.3 — NUMA Architecture](../03_NUMA_Architecture/README.md)

---

[⬅ Module 01](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [03 NUMA](../03_NUMA_Architecture/README.md)
