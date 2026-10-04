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
4. จำกัดอายุ session: ปิดตามเวลาด้วย SQL Agent job หรือ manual `STOP` (XEvents ไม่มี `AUTO_STOP` ในตัว — ตรวจแล้วบน 17.0.1000.7 syntax ไม่ผ่าน)

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

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): `CAST(target_data AS XML)` แปลงบัฟเฟอร์ของ target เป็น XML, `CROSS APPLY ... .nodes('//event')` ฉีกออกเป็นหลายแถว (แถวละ 1 event) แล้ว `.value()` ดึงค่าแต่ละ field ด้วย XQuery — path ต้องเขียน**สัมพัทธ์กับตัว `<event>`** เช่น `(@timestamp)`, `(data[@name="duration"]/value)` (ห้ามพิมพ์ `event/` นำหน้าซ้ำ เพราะ context node คือ `<event>` อยู่แล้ว — ใส่จะได้ NULL ทุกคอลัมน์ ตรวจจริงบน 17.x) — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

```sql
SELECT
    x.value('(@timestamp)[1]', 'DATETIME2')                            AS event_time,
    x.value('(data[@name="duration"]/value)[1]', 'BIGINT')/1000.0      AS duration_ms,
    x.value('(data[@name="cpu_time"]/value)[1]', 'BIGINT')/1000.0      AS cpu_ms,
    x.value('(data[@name="logical_reads"]/value)[1]', 'BIGINT')        AS logical_reads,
    x.value('(action[@name="sql_text"]/value)[1]', 'NVARCHAR(MAX)')    AS sql_text,
    x.value('(action[@name="client_app_name"]/value)[1]', 'SYSNAME')   AS app_name
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

**Expected:** ได้แถวเฉพาะ slow query ที่ผ่าน predicate (query สั้นกว่า 500 ms ไม่ปรากฏ); `duration_ms` ≥ 500, `sql_text` ตรงกับที่รัน, `app_name` เป็นชื่อเครื่องมือ client — และต้องรอ ≥ 5 วินาที (`MAX_DISPATCH_LATENCY`) ก่อนอ่าน buffer
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: จับได้ 1 event — `duration_ms = 2490.4` (CPU จริงแค่ 548 ms เพราะ duration รวมเวลาสตรีม 100,000 แถวออก client), `logical_reads = 1307`, `app_name = sqlcmd`; `SELECT TOP (5)` ถูก predicate กรองหาย

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

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): โครงเดียวกับ Exercise 1 Step 3 (`CAST AS XML` + `nodes()` + `CROSS APPLY`) แต่ใช้ `.query()` ซึ่งคืน**ชิ้น XML ทั้งก้อน** (ต่างจาก `.value()` ที่คืนค่า scalar) เพื่อดึง deadlock graph จาก field `xml_report` — path ก็สัมพัทธ์กับ `<event>` เหมือนกัน — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

```sql
SELECT
    x.value('(@timestamp)[1]', 'DATETIME2') AS deadlock_at,
    x.query('(data[@name="xml_report"]/value/deadlock)[1]') AS deadlock_xml
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

**Expected:** หนึ่งหน้าต่างได้ `Msg 1205 ... has been chosen as the deadlock victim` (อีกหน้าต่าง `COMMIT` ผ่าน); Step 3 ได้แถว `deadlock_xml` ที่คลิกเปิดได้ มี `<victim-list>` ระบุ victim + `<process-list>` 2 process + `<resource-list>`; ใน Watch Live Data เห็น event `xml_deadlock_report` เด้งสดทันทีที่ deadlock เกิด
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: หน้าต่าง A (spid 58, sqlcmd) เป็น victim ได้ Msg 1205, graph จาก ring_buffer หลังรอ ~7 วิ มี `<victim-list>` → `victimProcess` และ `<process-list>` 2 process (`logused 5740`, `waitresource KEY`)

---

## Exercise 3: จับ Long-Running Queries แบบ Production-grade (event_file)

### Step 1 — session แบบ event_file + predicate หลายเงื่อนไข

```sql
CREATE EVENT SESSION [XE_LongRunning] ON SERVER
ADD EVENT sqlserver.rpc_completed
(
    ACTION ( sqlserver.sql_text, sqlserver.client_hostname, sqlserver.username )
    WHERE ( duration > 3000000                     -- > 3 วินาที
            AND sqlserver.database_name = N'AdventureWorks2025' )
),
ADD EVENT sqlserver.sql_batch_completed
(
    ACTION ( sqlserver.sql_text, sqlserver.client_hostname )
    WHERE ( duration > 3000000
            AND sqlserver.database_name = N'AdventureWorks2025' )
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

> ⚠️ predicate ของ event session **ใส่ฟังก์ชันอย่าง `DB_ID()` ตรง ๆ ไม่ได้** (ได้ `Incorrect syntax near 'DB_ID'` — ตรวจจริงบน 17.0.1135.8) ให้ใช้ `sqlserver.database_name = N'...'` หรือใส่ค่า `database_id` ตัวเลขตรง ๆ แทน (หาค่าด้วย `SELECT DB_ID('AdventureWorks2025');`)

### Step 2 — อ่านไฟล์ .xel ด้วย T-SQL

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): `sys.fn_xe_file_target_read_file(...)` คือ TVF อ่านไฟล์ .xel ทีละแถว แล้ว `CROSS APPLY ( SELECT CAST(f.event_data AS XML) )` แปลงแต่ละแถวเป็น XML — ที่นี่ root ของ XML คือ `<event>` เอง จึงต้องเขียน path แบบ `event/data/...` (ต่างจาก Exercise 1–2 ที่ bind ที่ตัว `<event>` ผ่าน `nodes()` แล้ว จึงห้ามนำหน้าด้วย `event/`) — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

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

**Expected:** ได้แถวต่อ event ที่ผ่านเงื่อนไข (duration > 3 วิ และอยู่ใน DB ที่ระบุ) จากทุกไฟล์ .xel ที่ rollover ไว้; `event_name` เป็น `sql_batch_completed` (batch จาก sqlcmd/SSMS) หรือ `rpc_completed` (เรียก proc แบบมี parameter จาก application); คอลัมน์ `[user]` มีค่าเฉพาะแถว `rpc_completed` เพราะ action `username` ถูกขอไว้เฉพาะ event นั้น
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: batch `WAITFOR DELAY '00:00:04'; SELECT COUNT(*)...` ถูกจับเป็น `sql_batch_completed` `duration_s = 4.018` (predicate `database_name` ทำงานถูกต้อง), `[user] = NULL` ตามดีไซน์ และไฟล์เดียวกันยังเก็บ event ย้อนหลังจากการรันก่อนหน้า (rollover ยังไม่ถึง)

### Step 3 — จำกัดอายุ session กันลืมปิด (ทุกรุ่น 2008+)

> ⚠️ **ห้ามสอน `WITH (AUTO_STOP = ON)`** — option นี้ไม่มีอยู่จริงใน SQL Server 2025 (ตรวจจริงบน 17.0.1000.7 แล้วได้ `Incorrect syntax near 'AUTO_STOP'`) วิธีจริงคือกำหนดขนาด target แล้วปิดตามเวลาด้วย SQL Agent job หรือคำสั่ง `STATE = STOP`

```sql
ALTER EVENT SESSION [XE_SlowQueries] ON SERVER STATE = STOP;
DROP EVENT SESSION [XE_SlowQueries] ON SERVER;

CREATE EVENT SESSION [XE_TimedCapture] ON SERVER
ADD EVENT sqlserver.sql_batch_completed
(
    WHERE duration > 500000
)
ADD TARGET package0.ring_buffer ( SET max_memory = 2048 )
WITH ( MAX_DISPATCH_LATENCY = 5 SECONDS );   -- กระจายข้อมูลทุก 5 วิ ลดความเสี่ยงสูญข้อมูล
GO
ALTER EVENT SESSION [XE_TimedCapture] ON SERVER STATE = START;
-- ปิดตามเวลา: ตั้ง SQL Agent job ที่รัน "ALTER EVENT SESSION [XE_TimedCapture] ON SERVER STATE = STOP"
-- หรือสั่ง STOP เองเมื่อจบการจับ — ทางเลือกสำหรับรุ่นเก่า: รูปแบบนี้รันได้ตั้งแต่ SQL Server 2008+
```

**Expected:** สร้าง/START session สำเร็จ; หลัง START เห็นแถว `XE_TimedCapture` ใน `sys.dm_xe_sessions` (DMV นี้แสดงเฉพาะ session ที่กำลังรัน — ไม่มีคอลัมน์ status) และแถวหายไปทันทีหลัง `STOP`
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: START แล้วเห็น 1 แถวใน DMV, STOP แล้ว `COUNT(*) = 0`, DROP ผ่านครบ (ไม่มี AUTO_STOP)

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
- Microsoft Learn: [Extended Events](https://learn.microsoft.com/sql/relational-databases/extended-events/extended-events) · [Extended Events sessions](https://learn.microsoft.com/sql/relational-databases/extended-events/sql-server-extended-events-sessions) · [Use SSMS XEvent profiler](https://learn.microsoft.com/sql/relational-databases/extended-events/use-the-ssms-xe-profiler)
- สคริปต์ของแล็บนี้อยู่ใน `Sections/*/Scripts/` ของโมดูล จัดตามหัวข้อที่เกี่ยวข้อง (ลิงก์ในแต่ละ Exercise)
