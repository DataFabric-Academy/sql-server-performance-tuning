# Module 0 — เริ่มจากศูนย์: ภาษาที่คอร์สนี้พูด (ฉบับขั้นต่ำ)

> **ต้องรู้มาก่อน**: ไม่มีอะไรเลย — เพียงใช้ SSMS ได้ (เปิดหน้าต่าง query, กด F5) และเขียน `SELECT`/`JOIN` พื้นฐานได้
> ศัพท์ใหม่ทั้งหมดดู [Glossary](../Glossary.md) — ไฟล์นี้คือ "รถตัก" ที่พาคุณขึ้นเริ่มจุดตั้งต้นของ Module 1

---

## 1. Module นี้ใช้ทำอะไร

หลักสูตรนี้วินิจฉัยประสิทธิภาพด้วยการ**อ่านข้อมูลภายใน**ของ SQL Server ผ่านตัวเรียกว่า **DMV** — และตั้งแต่ Module 1 ตัวหนังสือจะโยนศัพท์อย่าง `sys.dm_os_wait_stats`, `scheduler`, `wait type` ใส่คุณตั้งแต่ย่อหน้าแรก โมดูลนี้จึงสอน 3 อย่างสั้น ๆ ก่อนเข้าคอร์สจริง:

1. ศัพท์แกน 4 คำที่ใช้ทั้งหลักสูตร (อ่าน 10 นาที)
2. Query แรกที่คุณรันตามได้ทันที (5 นาที)
3. ตรวจสภาพแวดล้อมว่าพร้อมเรียน (ชี้ไป Course Guide)

> ฉบับเต็ม (ฝึก setup ละเอียด + แบบฝึกหัด) อยู่ในแผนขยายของหลักสูตร — ฉบับนี้คือขั้นต่ำที่ทำให้คุณ**อ่าน Module 1 รอด**

---

## 2. ศัพท์แกน 4 คำ — นิยามแบบคนไม่มีพื้นฐาน

### 2.1 DMV (Dynamic Management View)

**View ที่ SQL Server เปิดให้คุณอ่านสถานะภายในของมัน** — เหมือนหน้าจอ Task Manager ของ Windows แต่อ่านด้วย SQL และละเอียดกว่ามาก ชื่อขึ้นต้นด้วย `sys.dm_` เสมอ เช่น `sys.dm_os_wait_stats` (สถิติการรอ) หรือ `sys.dm_exec_requests` (คำสั่งที่กำลังรัน)

- ใช้เหมือน SELECT จากตารางปกติ: `SELECT * FROM sys.dm_os_sys_info;`
- **ต้องมีสิทธิ์** `VIEW SERVER STATE` (หรือบทบาท `##MS_ServerPerformanceStateReader##`) — ถ้า error "permission was denied" แปลว่ายังไม่ได้สิทธิ์ ไม่ใช่ query ผิด

### 2.2 Wait Type (ประเภทการรอ)

เมื่อ SQL Server ต้อง**หยุดรออะไรบางอย่าง** (อ่านดิสก์, รอ lock, รอคิว CPU) มันจะจดบันทึกไว้ว่า "รอเพราะอะไร" โดยตั้งชื่อกำกับ เช่น:

| Wait Type | แปลว่ากำลังรอ... |
|---|---|
| `SOS_SCHEDULER_YIELD` | หมดเวลาใช้ CPU แล้วต้องต่อคิว (สัญญาณ CPU เริ่มแน่น) |
| `PAGEIOLATCH_SH` | อ่านหน้าข้อมูลจาก**ดิสก์** (เก็บไม่พอใน RAM) |
| `LCK_M_S` | รอ **lock** ที่คนอื่นถือค้าง (มี blocking) |
| `ASYNC_NETWORK_IO` | SQL Server พร้อมส่งผลแล้ว แต่ **client รับไม่ทัน** |

หลักคิดของทั้งหลักสูตร: **"ไม่เดา — อ่านว่าระบบรออะไร แล้วจัดอันดับจากมากไปน้อย"** (Waits & Queues) — จะลงลึกใน Module 1

### 2.3 Scheduler

SQL Server ไม่ให้ Windows จัดคิว CPU ให้ แต่สร้างระบบจัดคิวของตัวเอง — แต่ละ CPU หนึ่งตัวมี **scheduler หนึ่งตัว** (เครื่อง 8 vCPU = ~8 schedulers) ตัวบอกสุขภาพที่ใช้บ่อย: `runnable_tasks_count` (จำนวนงานที่พร้อมรันแต่ยังรอ CPU — ค้าง > 0 ต่อเนื่อง = มีคิว)

### 2.4 Execution Plan

เมื่อคุณส่ง query ให้ SQL Server มันไม่ได้ "รันตรง ๆ" แต่จะ**วางแผนก่อน** — ใช้ Index ไหน, ไล่ตารางยังไง, join แบบไหน — แผนนั้นคือ Execution Plan และ query "ช้า" มักแปลว่า "แผนแย่" หรือ "แผนดีแต่ข้อมูล/ทรัพยากรไม่พอ" — จะลงลึกใน Module 7

---

## 3. Query แรกของคุณ — รันตามได้ทันที

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT): `LEFT JOIN` = JOIN ปกติแต่คงแถวฝั่งซ้ายไว้แม้ไม่มีคู่; `SUM(x) OVER ()` = window function รวมทุกแถวโดยไม่ยุบ — อ่านเพิ่มที่ [Glossary](../Glossary.md)

```sql
-- Query แรก: ดูภาพรวมสุขภาพ instance ในคำถามเดียว
SET NOCOUNT ON;
SELECT
    si.cpu_count                                   AS [logical CPUs],
    si.numa_node_count                             AS [NUMA nodes],
    si.max_workers_count                           AS [worker เพดาน],
    ws.signal_wait_pct                             AS [Signal Wait % (>10-15 = CPU แน่น)],
    (SELECT COUNT(*) FROM sys.dm_exec_requests
     WHERE session_id > 50)                        AS [requests กำลังรัน]
FROM sys.dm_os_sys_info AS si
CROSS JOIN (
    SELECT SUM(signal_wait_time_ms) * 1.0
         / NULLIF(SUM(wait_time_ms), 0) * 100 AS signal_wait_pct
    FROM sys.dm_os_wait_stats WHERE wait_time_ms > 0
) AS ws;
```

**Expected:** ได้ 1 แถว — logical CPUs ตรงกับเครื่องคุณ, NUMA nodes ≥ 1, Signal Wait % ต่ำกว่า ~10–15% บนเครื่องปกติ
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), 2026-10-01: 4 vCPU / 1 NUMA node / worker 512 / Signal Wait 3.9% (เครื่องว่าง)

รันออกมาได้ = คุณเพิ่งใช้ DMV ครั้งแรกสำเร็จ — นี่คือเครื่องมือหลักที่จะใช้ตลอด 11 โมดูล

---

## 4. ตรวจว่าพร้อมเรียนหรือยัง

1. SQL Server 2025 (17.x) ติดตั้งแล้ว (รุ่นต่ำสุดของคอร์ส — ดูเหตุผลและทางเลือกที่ [Course Guide §5](../Trainer_Docs/Course_Guide_4Days.md))
2. Restore `AdventureWorks2025` แล้ว (ตามลิงก์ใน Course Guide §5)
3. มีสิทธิ์ `VIEW SERVER STATE` — รัน `SELECT HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') AS ok;` ต้องได้ 1
4. ศัพท์แกน 4 คำเล่ากลับได้โดยไม่เปิดไฟล์นี้

ครบ 4 ข้อ → เริ่ม [Module 01 — Architecture, Scheduling & Waits](../Module_01_Architecture_Scheduling_Waits/README.md) ได้เลย

---

## อ่านต่อ

- **ศัพท์เชิงลึกทั้งหมด:** [Glossary](../Glossary.md) (อภิธานศัพท์กลางของหลักสูตร)
- **เตรียมเครื่องละเอียด:** [Course Guide — Environment Setup](../Trainer_Docs/Course_Guide_4Days.md)
- **เริ่มเนื้อหาจริง:** [Module 01](../Module_01_Architecture_Scheduling_Waits/README.md)
