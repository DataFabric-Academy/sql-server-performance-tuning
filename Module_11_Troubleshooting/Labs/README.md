# Lab 11: "The Broken Server" — Capstone Troubleshooting (บทที่ 11)

> **ที่มา**: ปรับปรุงจาก Microsoft 10987C (End-to-end troubleshooting จากทุกโมดูล) + [Microsoft Learn — Performance Dashboard / Monitor SQL Server with DMVs](https://learn.microsoft.com/sql/relational-databases/performance/monitor-sql-server-with-dynamic-management-views) + [Glenn Berry — SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
> รูปแบบ: **Instruction + Code block** — ใช้ SSMS 4+ หน้าต่าง

## Prerequisites

- SQL Server 2019+ (แนะนำ **2025 (17.x)**), database **AdventureWorks2025**
- Permission: `sysadmin` (ต้องใช้ KILL)
- ทุกความรู้จากบทที่ 1–10

## Scenario

เช้าวันจันทร์ 09:00 โทรศัพท์ Helpdesk ดังไม่หยุด: "ระบบช้ามาก ใช้งานไม่ได้" ผู้ใช้ 200 คนติดต่อเข้ามา คุณมีเวลา 20 นาทีหา **root cause** และฟื้นระบบ — ผู้สอน (หรือคุณเอง) จะจุดชนวนปัญหาหลายอย่างพร้อมกัน แล้วคุณใช้ **Top-down framework** ไล่หาทีละชั้น

## Objectives

1. ปฏิบัติตาม framework: **Wait Stats → Resource → Query → Index → Config**
2. วิเคราะห์แบบสดด้วย DMVs + XEvents + Query Store
3. ตัดสินใจแก้เฉพาะหน้า (mitigate) และระบุการแก้ถาวร (root fix)

---

## Exercise 1: จุดชนวนความโกลาหล (Chaos Generator)

### Step 1 — รัน chaos script ใน 4 หน้าต่างพร้อมกัน

```sql
-- หน้าต่าง 1: Blocking (transaction ค้างถือ Lock อยู่)
USE AdventureWorks2025;
BEGIN TRAN;
UPDATE Production.ProductInventory SET Quantity = Quantity + 1
WHERE ProductID = 1;
WAITFOR DELAY '00:05:00';   -- ค้างไว้ 5 นาที — ยังไม่ commit
ROLLBACK;
```

```sql
-- หน้าต่าง 2: CPU (คำนวณหนัก)
DECLARE @n BIGINT = 0, @i BIGINT = 0;
WHILE @i < 800000000
BEGIN
    SET @n = @n + (@i % 13) * 7;
    SET @i += 1;
END
SELECT @n;
```

```sql
-- หน้าต่าง 3: I/O (result set ใหญ่ซ้ำ ๆ)
USE AdventureWorks2025;
SELECT * FROM Sales.SalesOrderDetail sod
CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),(7),(8)) AS v(n)
ORDER BY sod.CarrierTrackingNumber;
GO 3
```

```sql
-- หน้าต่าง 4: Memory grant หนัก (sort ใหญ่)
USE AdventureWorks2025;
SELECT CarrierTrackingNumber,
       CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS NVARCHAR(MAX)) AS pad
FROM Sales.SalesOrderDetail
ORDER BY pad DESC;
```

### Step 2 — บทบาทสลับ: คุณคือ DBA ที่เพิ่งเข้ามาใหม่

ปิดหน้าต่าง chaos ทั้งหมดไม่ให้เห็น (หรือให้เพื่อนรัน) — แล้วเริ่มวินิจฉัยจากศูนย์

---

## Exercise 2: Top-down Diagnosis

### Step 1 — ชั้น Waits: ระบบกำลังรออะไร "ตอนนี้"

```sql
-- สดจาก requests ที่กำลังรัน (ไม่ใช่ค่าสะสม)
SELECT r.session_id, r.blocking_session_id,
       r.wait_type, r.wait_time, r.wait_resource,
       r.cpu_time, r.total_elapsed_time, r.logical_reads,
       r.status, LEFT(t.text, 60) AS running_sql
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.session_id <> @@SPID AND r.is_user_process = 1
ORDER BY r.total_elapsed_time DESC;
```

### Step 2 — ชั้น Resource: จัดกลุ่มอาการ

```sql
-- Head blocker กับลูกโซ่ blocking
SELECT blocking_session_id, COUNT(*) AS victims_waiting,
       MAX(wait_time) AS longest_wait_ms
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0
GROUP BY blocking_session_id
ORDER BY victims_waiting DESC;

-- Scheduler queue (CPU pressure)
SELECT scheduler_id, runnable_tasks_count, current_tasks_count
FROM sys.dm_os_schedulers
WHERE scheduler_id < 1048576 AND runnable_tasks_count > 0;
```

✅ **คาดหวังจาก chaos นี้**: มี head blocker หนึ่งตัว (หน้าต่าง 1) + LCK_M_X waits จากทุก query ที่แตะ `Production.ProductInventory` / `Sales.*` + `SOS_SCHEDULER_YIELD` จาก CPU loop + `WRITELOG` จาก updates

### Step 3 — ชั้น Query: ตัวร้ายคือ query อะไร

```sql
-- Query ที่กิน resource มากสุดที่เคยรัน (cache) — ประกอบภาพ
SELECT TOP (10) qs.total_worker_time/1000 AS cpu_ms,
       qs.total_elapsed_time/1000 AS elapsed_ms,
       qs.total_logical_reads,
       LEFT(st.text, 80) AS query_text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY qs.total_worker_time DESC;

-- ถ้าเปิด Query Store: ดูจากประวัติจริงต่อช่วงเวลา
SELECT TOP (10) q.query_id, p.plan_id,
       rs.avg_cpu_time, rs.avg_duration, rs.count_executions,
       LEFT(qt.query_sql_text, 80) AS query_text
FROM sys.query_store_query AS q
JOIN sys.query_store_query_text AS qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan AS p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats AS rs ON p.plan_id = rs.plan_id
ORDER BY rs.avg_cpu_time DESC;
```

### Step 4 — ชั้น Config: ตั้งค่าใดเกี่ยวข้อง

```sql
SELECT name, value_in_use
FROM sys.configurations
WHERE name IN ('max degree of parallelism', 'cost threshold for parallelism',
               'max server memory (MB)', 'blocked process threshold (s)');
```

---

## Exercise 3: Mitigate → Root Fix

### Step 1 — ตัดตัวการ (mitigate เฉพาะหน้า)

```sql
-- หา spid ของ head blocker แล้ว
KILL <blocking_session_id>;    -- ทุก query ที่รอจะรันต่อทันที
```

### Step 2 — ยืนยันระบบฟื้น

```sql
-- รันซ้ำ Step 1 ของ Exercise 2 — ไม่มี waits ค้างเกินเกณฑ์
SELECT COUNT(*) AS still_blocked
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0;
```

### Step 3 — วางแผน root fix (เขียนคำตอบ)

| ปัญหาที่พบ | Root fix (ตัวอย่างคำตอบ) |
|:-----------|:--------------------------|
| Transaction เปิดค้างจาก app/SSMS | ตรวจ app connection pool timeout, สอน pattern BEGIN TRAN–COMMIT สั้น, เปิด XEvent `blocked_process_report` + `blocked process threshold = 5` |
| CPU query หนัก | ตรวจ plan (index ขาด?), DOP/CTFP, Query Store force plan |
| Result set ยักษ์สู่ client | แก้ query ฝั่ง app (เลือกColumn/แบ่งหน้า) — ASYNC_NETWORK_IO |
| Sort ใหญ่ + spill | เพิ่ม index ลด sort, Memory Grant Feedback, ตรวจ stats |

### Step 4 (Optional) — ตรวจด้วย XEvents ตอนกลับมามีปัญหาอีก

```sql
-- มี session ติดตั้งไว้แล้วจาก Lab 9 — ทวนสอบว่า start อยู่
SELECT s.name, s.create_time, t.target_name
FROM sys.dm_xe_sessions AS s
JOIN sys.dm_xe_session_targets AS t ON s.address = t.event_session_address;
```

---

## Wrap-up: คำถามท้ายแล็บ

1. คุณใช้เวลากี่นาทีในการหา root cause และ framework ขั้นไหนชี้ทางได้เร็วสุด?
2. ถ้า wait หลักเป็น `PAGEIOLATCH_SH` แทน `LCK_M_*` — เส้นทางวินิจฉัยเปลี่ยนไปทางไหน? (memory/buffer pool → I/O latency → index ลด logical reads)
3. การ mitigate (KILL) กับ root fix ต่างกันอย่างไรในเชิง professional communication กับผู้บริหาร?

## Cleanup

```sql
-- KILL session ที่ยังค้างจาก chaos (ถ้ามี)
-- ล้าง artifacts จาก Labs ก่อนหน้า:
USE DBA_Baseline;
EXEC dbo.CaptureBaselineSnapshot;   -- เก็บ baseline ปิดท้าย — เทียบกับตอนเริ่มแล็บ
```

## แหล่งอ้างอิง

- 10987C Demofiles/Labfiles (ทุกโมดูล) — `Trainer_Docs/10987/`
- Microsoft Learn: [Monitor with DMVs](https://learn.microsoft.com/sql/relational-databases/performance/monitor-sql-server-with-dynamic-management-views) · [Performance Dashboard](https://learn.microsoft.com/sql/tools/performance-dashboard) · [What's new in SQL Server 2025](https://learn.microsoft.com/sql/sql-server/what-s-new-in-sql-server-2025)
- Glenn Berry: [SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
- ไฟล์ประกอบทั้งหมดอยู่ใน `Scripts/` ของโฟลเดอร์นี้ (`Scripts/01–07`) — โค้ดหลักของทุก Exercise ฝังอยู่ใน README ฉบับนี้แล้ว
