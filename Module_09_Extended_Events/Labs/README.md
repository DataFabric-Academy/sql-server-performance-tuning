# Lab 9: Extended Events — Query Performance, Deadlocks & Long-Running Queries (บทที่ 9)

> **ที่มา**: ปรับปรุงจาก Microsoft 10987C **Lab09** (XEvents) + [Microsoft Learn — Extended Events](https://learn.microsoft.com/sql/relational-databases/extended-events/extended-events) + [Glenn Berry — SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
> รูปแบบ: **Instruction + Code block** — สร้าง session ด้วย T-SQL เป็นหลัก (Wizard ใช้เปรียบเทียบใน Exercise 1)

## Prerequisites

- SQL Server 2019+ (แนะนำ **2025 (17.x)**), database **AdventureWorks2025**
- Permission: `ALTER ANY EVENT SESSION`
- SSMS: Object Explorer → Management → Extended Events

## Scenario

หัวหน้าห้ามใช้ SQL Profiler เด็ดขาด (deprecated และ overhead สูง) คุณต้องสร้างระบบติดตาม 3 เรื่องด้วย Extended Events: (1) query ที่กิน CPU/IO มาก (2) deadlock (3) query ที่วิ่งนานเกินเกณฑ์ — โดยใช้ ring_buffer เพื่อดูสด และ event_file สำหรับ production

## Objectives

1. เข้าใจองค์ประกอบ session: Event / Action / Predicate / Target
2. สร้าง session จับ slow & expensive queries
3. จับ deadlock และดู Deadlock Graph
4. (2025) ใช้ Time-bound session (`AUTO_STOP`)

---

## Exercise 1: สร้าง Session จับ Query Performance

### Step 1 — สร้าง session ด้วย T-SQL (มี predicate filter duration > 500 ms)

```sql
CREATE EVENT SESSION [XE_SlowQueries] ON SERVER
ADD EVENT sqlserver.sql_statement_completed
(
    ACTION ( sqlserver.sql_text, sqlserver.client_app_name, sqlserver.session_id )
    WHERE ( duration > 500000 )        -- 500,000 µs = 500 ms (หน่วยµs)
)
ADD TARGET package0.ring_buffer      -- เก็บใน memory ดูสดได้เร็ว
(
    SET max_memory = 4096            -- KB
)
WITH ( MAX_DISPATCH_LATENCY = 5 SECONDS,
       STARTUP_STATE = OFF );
GO
ALTER EVENT SESSION [XE_SlowQueries] ON SERVER STATE = START;
```

> เทียบกับ Wizard: Object Explorer → Extended Events → New Session Wizard — เลือก template "Query Detail Tracking" ได้ผลใกล้เคียงกัน แต่ T-SQL ควบคุม predicate/target ได้ละเอียดและเก็บเป็นสคริปต์ได้

### Step 2 — สร้าง slow query จริง

```sql
USE AdventureWorks2025;
GO
-- จงใจให้ช้าเกิน 500 ms (รวมผลลัพธ์ใหญ่ + เรียง)
SELECT TOP (100000) *
FROM Sales.SalesOrderDetail
ORDER BY CarrierTrackingNumber, ModifiedDate;
```

### Step 3 — อ่านข้อมูลจาก ring_buffer

```sql
SELECT
    x.value('(event/@timestamp)[1]', 'DATETIME2')                      AS event_time,
    x.value('(event/data[@name="duration"]/value)[1]', 'INT')/1000.0   AS duration_ms,
    x.value('(event/data[@name="cpu_time"]/value)[1]', 'INT')/1000.0   AS cpu_ms,
    x.value('(event/data[@name="logical_reads"]/value)[1]', 'BIGINT')  AS logical_reads,
    x.value('(event/action[@name="sql_text"]/value)[1]', 'NVARCHAR(MAX)') AS sql_text,
    x.value('(event/action[@name="client_app_name"]/value)[1]', 'SYSNAME') AS app_name
FROM (
    SELECT CAST(target_data AS XML) AS buf
    FROM sys.dm_xe_session_targets AS t
    JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
    WHERE s.name = 'XE_SlowQueries' AND t.target_name = 'ring_buffer'
) AS d
CROSS APPLY buf.nodes('//event') AS n(x)
ORDER BY event_time DESC;
```

✅ **สังเกต**: duration/cpu/logical_reads ของ query ที่เพิ่งรัน — นี่คือ "Profiler แบบเบา"

---

## Exercise 2: จับ Deadlock + Deadlock Graph

### Step 1 — สร้าง session จับ xml_deadlock_report

```sql
CREATE EVENT SESSION [XE_DeadlockMonitor] ON SERVER
ADD EVENT sqlserver.xml_deadlock_report
ADD TARGET package0.ring_buffer ( SET max_memory = 4096 )
WITH ( MAX_DISPATCH_LATENCY = 5 SECONDS, STARTUP_STATE = ON );
GO
ALTER EVENT SESSION [XE_DeadlockMonitor] ON SERVER STATE = START;
```

### Step 2 — ทำ deadlock (จาก Lab 5 ย่อ ๆ — 2 หน้าต่าง)

```sql
-- หน้าต่าง A
USE AdventureWorks2025;
BEGIN TRAN;
UPDATE Production.Product SET ListPrice = ListPrice WHERE ProductID = 1;
UPDATE Sales.SalesOrderDetail SET OrderQty = OrderQty WHERE SalesOrderDetailID = 1;
COMMIT;
```

```sql
-- หน้าต่าง B (รันหลัง A ขึ้น statement แรก)
USE AdventureWorks2025;
BEGIN TRAN;
UPDATE Sales.SalesOrderDetail SET OrderQty = OrderQty WHERE SalesOrderDetailID = 1;
UPDATE Production.Product SET ListPrice = ListPrice WHERE ProductID = 1;
COMMIT;
```

✅ หนึ่งหน้าต่างจะได้ **error 1205** — deadlock เกิดขึ้นแล้ว

### Step 3 — ดึง Deadlock Graph จาก session

```sql
SELECT
    x.value('(event/@timestamp)[1]', 'DATETIME2') AS deadlock_at,
    x.query('(event/data[@name="xml_report"]/value)[1]') AS deadlock_xml
FROM (
    SELECT CAST(target_data AS XML) AS buf
    FROM sys.dm_xe_session_targets AS t
    JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
    WHERE s.name = 'XE_DeadlockMonitor' AND t.target_name = 'ring_buffer'
) AS d
CROSS APPLY buf.nodes('//event') AS n(x)
ORDER BY deadlock_at DESC;
```

✅ คลิก XML link → SSMS วาด **Deadlock Graph แบบภาพ** ระบุ victim และ resource

### Step 4 — Watch Live Data (GUI)

1. Object Explorer → Extended Events → Sessions → คลิกขวา `XE_DeadlockMonitor` → **Watch Live Data**
2. ทำ deadlock ซ้ำ — event เด้งขึ้นจอแบบ real-time

---

## Exercise 3: จับ Long-Running Queries แบบ Production-grade (event_file)

### Step 1 — session แบบ event_file + predicate หลายเงื่อนไข

```sql
CREATE EVENT SESSION [XE_LongRunning] ON SERVER
ADD EVENT sqlserver.rpc_completed
(
    ACTION ( sqlserver.sql_text, sqlserver.client_hostname, sqlserver.username )
    WHERE ( duration > 3000000            -- > 3 วินาที
            AND sqlserver.database_id = DB_ID('AdventureWorks2025') )
),
ADD EVENT sqlserver.sql_batch_completed
(
    ACTION ( sqlserver.sql_text, sqlserver.client_hostname )
    WHERE ( duration > 3000000
            AND sqlserver.database_id = DB_ID('AdventureWorks2025') )
)
ADD TARGET package0.event_file
(
    SET filename = N'XE_LongRunning.xel',
        max_file_size = 25,               -- MB
        max_rollover_files = 4
)
WITH ( MAX_MEMORY = 4096 KB,
       MAX_DISPATCH_LATENCY = 10 SECONDS,
       STARTUP_STATE = ON );              -- start อัตโนมัติตอน server restart
GO
ALTER EVENT SESSION [XE_LongRunning] ON SERVER STATE = START;
```

### Step 2 — อ่านไฟล์ .xel ด้วย T-SQL

```sql
SELECT
    x.value('(event/@timestamp)[1]', 'DATETIME2')                        AS event_time,
    x.value('(event/@name)[1]', 'SYSNAME')                               AS event_name,
    x.value('(event/data[@name="duration"]/value)[1]', 'INT')/1000000.0  AS duration_s,
    x.value('(event/action[@name="username"]/value)[1]', 'SYSNAME')      AS [user],
    x.value('(event/action[@name="sql_text"]/value)[1]', 'NVARCHAR(MAX)') AS sql_text
FROM sys.fn_xe_file_target_read_file('XE_LongRunning*.xel', NULL, NULL, NULL) AS f
CROSS APPLY ( SELECT CAST(f.event_data AS XML) ) AS c(x)
ORDER BY event_time DESC;
```

### Step 3 (SQL Server 2025) — Time-bound session กันลืมปิด

```sql
-- 2025: session หยุดเองหลังเวลาที่กำหนด — กันลืมเปิดค้างบน production
ALTER EVENT SESSION [XE_SlowQueries] ON SERVER STATE = STOP;
DROP EVENT SESSION [XE_SlowQueries] ON SERVER;

CREATE EVENT SESSION [XE_TimedCapture] ON SERVER
ADD EVENT sqlserver.sql_batch_completed
(
    WHERE duration > 500000
)
ADD TARGET package0.ring_buffer ( SET max_memory = 2048 )
WITH ( AUTO_STOP = ON );   -- ฟีเจอร์ใหม่ 2025: หยุดอัตโนมัติตามเวลา/เงื่อนไข
GO
ALTER EVENT SESSION [XE_TimedCapture] ON SERVER STATE = START;
```

---

## Wrap-up: คำถามท้ายแล็บ

1. ring_buffer กับ event_file ใช้ต่างกันอย่างไร? (สด/ชั่วคราว vs คงทน production)
2. predicate ทำหน้าที่อะไร และทำไมวาง filter ที่ event ช่วยลด overhead? (กรองตั้งแต่ก่อน dispatch)
3. หน่วยของ duration ใน XEvents คืออะไร? (ไมโครวินาที — เผลอมักชน 1,000 เท่า)

## Cleanup

```sql
ALTER EVENT SESSION [XE_DeadlockMonitor] ON SERVER STATE = STOP;
ALTER EVENT SESSION [XE_LongRunning] ON SERVER STATE = STOP;
ALTER EVENT SESSION [XE_TimedCapture] ON SERVER STATE = STOP;
DROP EVENT SESSION [XE_DeadlockMonitor] ON SERVER;
DROP EVENT SESSION [XE_LongRunning] ON SERVER;
DROP EVENT SESSION [XE_TimedCapture] ON SERVER;
```

## แหล่งอ้างอิง

- 10987C Lab09 — `Trainer_Docs/10987/Labfiles/Lab09/`
- Microsoft Learn: [Extended Events](https://learn.microsoft.com/sql/relational-databases/extended-events/extended-events) · [Time-bound sessions (2025)](https://learn.microsoft.com/sql/relational-databases/extended-events/sql-server-extended-events-sessions) · [Use SSMS XEvent profiler](https://learn.microsoft.com/sql/relational-databases/extended-events/use-the-ssms-xe-profiler)
- สคริปต์ของแล็บนี้อยู่ใน `Sections/*/Scripts/` ของโมดูล จัดตามหัวข้อที่เกี่ยวข้อง (ลิงก์ในแต่ละ Exercise)
