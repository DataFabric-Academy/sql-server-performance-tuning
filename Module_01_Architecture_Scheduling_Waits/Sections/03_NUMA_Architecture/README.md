[⬅ Module 01](../../README.md) | [1.2 Scheduling](../02_Scheduling_Windows_vs_SQL/README.md) | Section 3/5 | ➡ ถัดไป: [04 Wait Statistics](../04_Wait_Statistics/README.md)

# 1.3 NUMA Architecture — ความจำใกล้ตัวสำคัญกว่าความจำเยอะ

> *"ถ้าข้อมูลอยู่ memory ของ node อื่น CPU ต้องเดินไปเอาเอง — และการเดินนั้นมีค่าใช้จ่าย"*

> **ต้องรู้มาก่อน**: [Section 1.1 — Engine Architecture & SQLOS](../01_Engine_Architecture_SQLOS/README.md) (ชั้นประมวลผลของ engine) และ [Section 1.2 — Scheduling](../02_Scheduling_Windows_vs_SQL/README.md) (scheduler, worker, quantum)
> ศัพท์ใหม่ดู [Glossary](../../../Glossary.md)

## เปิดเรื่อง

เมื่อ server มี CPU หลาย socket คำถามสถาปัตยกรรมแรกคือ "memory ตัวไหนอยู่ใกล้ CPU ตัวไหน" ในระบบ **SMP (Symmetric Multiprocessing)** CPU ทุกตัวแชร์ bus เดียวไปยัง memory เดียว — ยิ่ง CPU เยอะ bus ยิ่งแน่น ทางออกคือ **NUMA (Non-Uniform Memory Access)**: แบ่ง CPU+Memory เป็น **Node** ที่เข้าถึง memory ใน node ตัวเองเร็ว (Local Access) แต่เข้าถึง node อื่นช้ากว่า (Foreign Access)

```
Node 0                      Node 1
┌─────────────────┐        ┌─────────────────┐
│ CPU 0-7          │        │ CPU 8-15         │
│ Local Memory     │        │ Local Memory     │
└────────┬─────────┘        └────────┬─────────┘
         │      interconnect         │
         └───────────┬───────────────┘
              Foreign Access (ช้ากว่า)
```

---

## 1. Hardware NUMA vs Software (Soft) NUMA

| ชนิด | ที่มา | สังเกตได้จาก |
|:-----|:------|:-------------|
| **Hardware NUMA** | มากับ socket ของ mainboard — SQL Server ตรวจพบและใช้อัตโนมัติ | `sys.dm_os_nodes.node_state_desc` ระบุ ONLINE |
| **Software NUMA (Soft-NUMA)** | SQLOS สร้างอัตโนมัติ (2016+) เมื่อ logical core ต่อ node เกิน 8 | `ONLINE AUTOMATIC` |

```sql
SELECT node_id, node_state_desc, online_scheduler_count,
       active_worker_count, avg_load_balance
FROM sys.dm_os_nodes;
```

- node ที่มี state `ONLINE AUTOMATIC` = Soft-NUMA ที่ระบบสร้างให้เอง
- 2025: **Hot Add CPU ถูก deprecated** — วางแผนขนาด CPU ตั้งแต่ต้น อย่าคาดหวังเพิ่ม CPU ระหว่างใช้งาน

---

## 2. Memory Affinity & Thread Affinity

**หลักการ:** task ควรรันบน scheduler ใน node เดียวกับ memory ที่ต้องใช้ (Local Access) การข้าม node (Foreign Access) มี latency สูงกว่าชัดเจน

**สิ่งที่ SQL Server ทำให้อัตโนมัติ:**
- Memory nodes แบ่งตาม NUMA nodes — buffer pool แจกจ่ายทั่วถึง
- Scheduler ผูกกับ CPU ใน node ตัวเอง — ลดการย้ายข้าม
- Connection ถูกจับคู่ node แบบ round-robin

**สิ่งที่ควรตรวจหลังติดตั้ง:**
1. เก็บ NUMA topology ด้วย `sys.dm_os_sys_info` + `sys.dm_os_nodes` เป็น baseline ตั้งแต่วันแรก
2. ตรวจ `max_worker_count` และ worker ต่อ node (`sys.dm_os_nodes.active_worker_count`)
3. ห้าม set processor affinity กำปั้นเองโดยไม่มีเหตุผลชัดเจน — ปล่อยให้ SQLOS balance

---

## 3. ทำไม NUMA จึงสำคัญกับ Performance Tuning

1. **PLE ต้องอ่านต่อ node** — Page Life Expectancy มีค่าแยกตาม Buffer Node ค่ารวมทั้ง instance อ่านไม่ได้ (ดูต่อ Module 4)
2. **Parallel query ข้าม node** มีต้นทุนสูง — MAXDOP ที่เกินจำนวน core ต่อ node ทำให้ query ข้าม node มากขึ้น
3. **Workload isolation** — Soft-NUMA + Resource Governor จัดกลุ่มงานได้ละเอียดขึ้น
4. ** Glenn Berry diagnostic queries** มีหมวด NUMA พร้อมรัน — เก็บเป็น baseline ตั้งแต่วันแรกของระบบ

---

## สรุป Section 3

1. NUMA = CPU แต่ละกลุ่มมี memory ใกล้ตัว — Local เร็ว, Foreign ช้า
2. Hardware NUMA ตรวจอัตโนมัติ / Soft-NUMA สร้างอัตโนมัติเมื่อ cores ต่อ node > 8
3. อ่านค่า performance ระดับ node เสมอ (PLE, memory, workers) ไม่ใช่ค่ารวม

**ตรวจความเข้าใจ:**
1. Foreign Memory Access คืออะไร และเกิดขึ้นเมื่อไร?
2. เพราะอะไร MAXDOP ที่สูงกว่าจำนวน core ต่อ NUMA node อาจทำให้แย่ลง?

**➡ ถัดไป:** [Section 1.4 — Wait Statistics](../04_Wait_Statistics/README.md)

---

[⬅ Module 01](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [04 Wait Statistics](../04_Wait_Statistics/README.md)
