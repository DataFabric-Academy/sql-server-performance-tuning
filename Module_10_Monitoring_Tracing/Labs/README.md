# Lab 10: Baseline Collection & Daily Health Check (บทที่ 10)

> **ที่มา**: ปรับปรุงจาก Microsoft 10987C **Lab10** (Monitoring) + [Microsoft Learn — Performance monitoring tools](https://learn.microsoft.com/sql/relational-databases/performance/performance-monitoring-and-tuning-tools) + [Glenn Berry — SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
> รูปแบบ: **Instruction + Code block** — สร้าง baseline script ใช้ได้จริงกับ SQL Server 2025

## Prerequisites

- SQL Server 2019+ (แนะนำ **2025 (17.x)**), database **AdventureWorks2025**
- Permission: `VIEW SERVER STATE` (แนะนำใช้บทบาท `##MS_ServerPerformanceStateReader##`)
- ตารางเก็บ baseline จะถูกสร้างใน DB ใหม่ `DBA_Baseline`

## Scenario

คุณเพิ่งรับช่วงดูแล SQL Server ที่ไม่มีใครรู้ว่า "ปกติของมัน" หน้าตาเป็นอย่างไร ก่อนจะแก้ปัญหาอะไรได้ คุณต้องสร้าง **Performance Baseline** เก็บ key metrics ทุก 15 นาที และสร้าง Daily Health Check จากแนวทาง Glenn Berry

## Objectives

1. สร้างตารางและ procedure เก็บ baseline (waits, I/O latency, memory, blocking)
2. จำลอง workload แล้วเก็บ snapshot เทียบผล
3. สร้าง Daily Health Check script สำหรับรันทุกเช้า

---

## Exercise 1: สร้างโครงสร้าง Baseline

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): ขั้นนี้ใช้ **DDL สร้างโครงสร้าง** (`CREATE DATABASE`, `CREATE TABLE` = สร้างฐานข้อมูล/ตาราง), `CREATE OR ALTER PROCEDURE` (สร้างหรือแทนที่ stored procedure ในคำสั่งเดียว) และ `INSERT ... SELECT` (คัดลอกผลจาก DMV ลงตารางทีเดียวทั้งชุด) — Step 3 ใช้ระบบ stored procedures ของ SQL Server Agent (`sp_add_job` ฯลฯ) ลงทะเบียน job ตามตารางเวลา — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

### Step 1 — สร้าง DB และตารางเก็บ snapshot

```sql
CREATE DATABASE DBA_Baseline;
GO
USE DBA_Baseline;
GO
CREATE TABLE dbo.WaitSnapshot
(
    SnapshotId INT IDENTITY PRIMARY KEY,
    CapturedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    WaitType NVARCHAR(60),
    WaitingTasksCount BIGINT,
    WaitTimeMs BIGINT,
    SignalWaitTimeMs BIGINT
);
GO
CREATE TABLE dbo.FileIOSnapshot
(
    SnapshotId INT IDENTITY PRIMARY KEY,
    CapturedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    DatabaseName SYSNAME,
    FileLogicalName SYSNAME,
    TypeDesc NVARCHAR(10),
    NumOfReads BIGINT, NumOfWrites BIGINT,
    IoStallReadMs BIGINT, IoStallWriteMs BIGINT
);
GO
```

### Step 2 — procedure จับ snapshot ครั้งเดียวเก็บทั้งสองตาราง

```sql
CREATE OR ALTER PROCEDURE dbo.CaptureBaselineSnapshot
AS
BEGIN
    INSERT dbo.WaitSnapshot (WaitType, WaitingTasksCount, WaitTimeMs, SignalWaitTimeMs)
    SELECT wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms
    FROM sys.dm_os_wait_stats
    WHERE waiting_tasks_count > 0;

    INSERT dbo.FileIOSnapshot (DatabaseName, FileLogicalName, TypeDesc,
                               NumOfReads, NumOfWrites, IoStallReadMs, IoStallWriteMs)
    SELECT DB_NAME(vfs.database_id), mf.name, mf.type_desc,
           vfs.num_of_reads, vfs.num_of_writes, vfs.io_stall_read_ms, vfs.io_stall_write_ms
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
    JOIN sys.master_files AS mf
        ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id;
END
GO
-- จับ snapshot แรก
EXEC dbo.CaptureBaselineSnapshot;
```

### Step 3 — ตั้ง SQL Agent Job เก็บทุก 15 นาที

```sql
USE msdb;
GO
EXEC dbo.sp_add_job @job_name = N'DBA - Baseline Snapshot';
EXEC dbo.sp_add_jobstep
    @job_name = N'DBA - Baseline Snapshot',
    @step_name = N'Capture',
    @subsystem = N'TSQL',
    @database_name = N'DBA_Baseline',
    @command = N'EXEC dbo.CaptureBaselineSnapshot;';
EXEC dbo.sp_add_jobschedule
    @job_name = N'DBA - Baseline Snapshot',
    @name = N'Every 15 min',
    @freq_type = 4,                       -- daily
    @freq_interval = 1,
    @freq_subday_type = 4,                -- minutes
    @freq_subday_interval = 15,
    @active_start_time = 000000;
EXEC dbo.sp_add_jobserver @job_name = N'DBA - Baseline Snapshot';
GO
```

> **แนะนำเพิ่ม**: Database Mail + Operator เพื่อแจ้งเตือนเมื่อ job fail (`sp_add_operator`, `sp_update_job @notify_level_email = 2`)

**Expected:** หลัง Step 2 เห็น `WaitSnapshot` ถูกเติมหลักร้อยแถว (1 แถวต่อ wait type ที่มีค่าสะสม) และ `FileIOSnapshot` 1 แถวต่อไฟล์ข้อมูล/log ของทุก DB; หลัง Step 3 เห็น job "DBA - Baseline Snapshot" ใต้ SQL Server Agent → Jobs ใน Object Explorer พร้อม schedule "Every 15 min" — ถ้า Agent ยัง Stopped ต้อง START ก่อน แล้ว View History จะแสดง success ทุกรอบที่ Agent สั่งรัน
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: snapshot แรกได้ WaitSnapshot 143 แถว / FileIOSnapshot 19 แถว (Top read = AdventureWorks ROWS 3,702 reads) — บน VM ทดสอบพบ SQL Server Agent = Stopped (ตรวจจาก `sys.dm_server_services`) ขั้นสร้าง job จึงกำหนดให้ **รันจริงตอนสอนบน VM** เพื่อไม่ทิ้ง job/schedule ค้างบนเครื่อง

---

## Exercise 2: จำลอง Workload แล้วอ่าน Delta

### Step 1 — สร้างโหลดผสม (รันในหลายหน้าต่าง ~2 นาที)

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): Step 1 ใช้ **WHILE** loop (วนซ้ำใน T-SQL), `WAITFOR DELAY` (หน่วงเวลา 0.3 วิ/รอบ) และ `UPDATE TOP (n)` (อัปเดตจำกัดจำนวนแถว); Step 2 ใช้ **CTE** + window function `ROW_NUMBER() OVER (PARTITION BY WaitType ORDER BY SnapshotId ...)` = จัดลำดับแยกกลุ่มต่อ WaitType เพื่อหาแถว "จับครั้งแรก" กับ "จับครั้งล่าสุด" ของแต่ละ wait type — อ่านเพิ่มที่ [Glossary](../../Glossary.md)
> **หมายเหตุ VM ทดสอบ**: ถ้า `USE AdventureWorks2025;` ขึ้น error ว่า database ไม่มีอยู่ ให้เปลี่ยนเป็น `USE AdventureWorks;` (ชื่อจริงบน VM ทดสอบของหลักสูตร)

```sql
USE AdventureWorks2025;
GO
DECLARE @i INT = 0;
WHILE @i < 300
BEGIN
    -- I/O อ่าน
    SELECT COUNT(*) FROM Sales.SalesOrderDetail WHERE ProductID % 10 = @i % 10;
    -- เขียน log
    UPDATE TOP (50) Sales.SalesOrderDetail SET ModifiedDate = SYSDATETIME()
    WHERE SalesOrderDetailID % 700 = @i % 700;
    SET @i += 1;
    WAITFOR DELAY '00:00:00.3';
END
```

### Step 2 — จับ snapshot ที่สอง แล้วคำนวณ delta

> ⚠️ **แก้จากต้นฉบับ**: query เดิม (`ROW_NUMBER() OVER (ORDER BY SnapshotId DESC)` ไม่มี `PARTITION BY` คู่กับเงื่อนไข `s.SnapshotId = MAX(SnapshotId)`) เทียบแถวล่าสุดกับตัวมันเอง ผลลัพธ์จึง **ว่างเปล่าเสมอ** — ด้านล่างแก้เป็นเทียบ "จับครั้งแรก vs ครั้งล่าสุด" ของแต่ละ WaitType (ตรวจจริงบน 17.0.1135.8 แล้ว query เดิมได้ 0 แถว)

```sql
USE DBA_Baseline;
EXEC dbo.CaptureBaselineSnapshot;

-- Top waits ที่เพิ่มขึ้นระหว่างจับครั้งแรก → ครั้งล่าสุด (ของแต่ละ WaitType)
WITH Snap AS (
    SELECT WaitType, WaitingTasksCount, WaitTimeMs, SignalWaitTimeMs,
           ROW_NUMBER() OVER (PARTITION BY WaitType ORDER BY SnapshotId ASC)  AS rn_first,
           ROW_NUMBER() OVER (PARTITION BY WaitType ORDER BY SnapshotId DESC) AS rn_last
    FROM dbo.WaitSnapshot
)
SELECT f.WaitType,
       l.WaitingTasksCount - f.WaitingTasksCount AS waits_delta,
       l.WaitTimeMs - f.WaitTimeMs AS wait_ms_delta,
       (l.WaitTimeMs - f.WaitTimeMs)
           / NULLIF(l.WaitingTasksCount - f.WaitingTasksCount, 0) * 1.0 AS avg_wait_ms
FROM Snap AS f
JOIN Snap AS l ON l.WaitType = f.WaitType
WHERE f.rn_first = 1 AND l.rn_last = 1
  AND l.WaitingTasksCount > f.WaitingTasksCount
ORDER BY wait_ms_delta DESC;
```

✅ **ตีความ**: `SOS_SCHEDULER_YIELD` = CPU, `PAGEIOLATCH_*` = disk read, `WRITELOG` = log write latency, `LCK_M_*` = blocking — นี่คือการอ่าน baseline ที่แท้จริง

**Expected:** ได้ตาราง delta ต่อ wait type — Top ของ `wait_ms_delta` บนเครื่องที่มี background เยอะมักถูก wait ประเภท dispatcher/queue ครอง ให้โฟกัสกลุ่มที่ตรงกับ workload ของเรา: `WRITELOG` นำจาก UPDATE ต่อรอบ ตามด้วย `SOS_SCHEDULER_YIELD`/`CX*` จาก scan และ `PAGELATCH_*`/`LCK_M_*` (เทียบ `FileIOSnapshot` จะเห็น log writes เพิ่มสอดคล้องกัน)
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: หน้าต่างวัด ~90 วิ (workload 150 รอบ ≈ 56 วิ) — workload-relevant: `WRITELOG` +199 ครั้ง (+272 ms, ~1 ms/ครั้ง), `SOS_SCHEDULER_YIELD` +2,581 ครั้ง, `CXPACKET`/`CXCONSUMER` +139/+1,108 ครั้ง, `PAGELATCH_EX` +24 ครั้ง; log ของ AdventureWorks +490 writes (io_stall_write +567 ms) — ส่วน Top ของตารางเป็น background (`DISPATCHER_QUEUE_SEMAPHORE`, `LOGMGR_QUEUE`) เพราะ server ทดสอบมี agent อื่นใช้ร่วม ค่าจึงเป็นโดยประมาณ

---

## Exercise 3: Daily Health Check (Glenn Berry style)

### Step 1 — Health check แบบหน้าเดียวจบ

```sql
-- ===== Daily Health Check =====
SELECT @@SERVERNAME AS server_name, @@VERSION AS version,
       sqlserver_start_time AS last_restart
FROM sys.dm_os_sys_info;

-- 1. สุขภาพ memory ของ OS
SELECT system_memory_state_desc, available_physical_memory_kb/1048576.0 AS avail_gb
FROM sys.dm_os_sys_memory;

-- 2. SQL memory utilization
SELECT memory_utilization_percentage, process_physical_memory_low
FROM sys.dm_os_process_memory;

-- 3. Schedulers ที่มีคิวค้าง
SELECT COUNT(*) AS schedulers_with_runnable_queue
FROM sys.dm_os_schedulers
WHERE runnable_tasks_count > 0 AND scheduler_id < 1048576;

-- 4. Databases ที่ Query Store ปิด (ควรเปิดทั้งหมด)
SELECT name FROM sys.databases
WHERE database_id > 4 AND (is_query_store_on = 0 OR state_desc <> 'ONLINE');

-- 5. Last backup ของทุก DB
SELECT d.name, MAX(bs.backup_finish_date) AS last_backup
FROM sys.databases AS d
LEFT JOIN msdb.dbo.backupset AS bs
    ON d.database_id NOT IN (SELECT database_id FROM sys.databases WHERE name = 'tempdb')
   AND bs.database_name = d.name
WHERE d.database_id > 4
GROUP BY d.name
ORDER BY last_backup;
```

### Step 2 (Optional) — รันชุด Glenn Berry เต็ม

1. ดาวน์โหลด **SQL Server 2025 Diagnostic Queries** จาก [glennsqlperformance.com/resources](https://glennsqlperformance.com/resources/)
2. รันใน SSMS → `Query → Results to File` แล้วเก็บผลรายวันเทียบ spreadsheet ที่แนบมากับสคริปต์

**Expected:** Step 1 ได้ 6 result sets: เวอร์ชัน + เวลา restart, สถานะ memory ของ OS (`Available physical memory is high` + จำนวน GB ว่าง), memory utilization ของ SQL process, จำนวน scheduler ที่มีคิวค้าง (ปกติ = 0 บนเครื่องว่าง), รายชื่อ DB ที่ Query Store ปิด (ควรว่าง) และ last backup ต่อ DB — แถวใด `last_backup = NULL` = ยังไม่เคย backup เลย; Step 2 ควรได้ไฟล์ผลลัพธ์ต่อวันเก็บไว้เทียบ
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: last_restart 2026-10-02 03:09, avail_gb ≈ 9.9 (state = high), `memory_utilization_percentage = 100` แต่ `process_physical_memory_low = 0` (SQL ใช้เต็ม target memory ของตัวเอง ไม่ใช่ RAM เครื่องหมด), runnable queue = 1 (ช่วงวัดมี agent อื่นรัน CPU loop), DB ที่ QS ปิด = ไม่มี, last_backup ทุก user DB = NULL (ยังไม่เคย backup)

---

## Wrap-up: คำถามท้ายแล็บ

1. ทำไมต้องเก็บ delta แทนการดูค่าสะสมของ `sys.dm_os_wait_stats`? (ค่าสะสมตั้งแต่ startup ไม่บอก "ตอนนี้")
2. threshold อะไรบ้างที่คุณจะตั้ง alert ตาม baseline ของเครื่องนี้?
3. Query Store เสริมจุดไหนที่ wait stats ทำไม่ได้? (ระดับ query ต่อช่วงเวลา + ประวัติ plan)

## Cleanup

```sql
USE msdb;
EXEC dbo.sp_delete_job @job_name = N'DBA - Baseline Snapshot';
GO
-- เก็บ DBA_Baseline ไว้ใช้ Lab 11 ต่อ หรือลบทิ้ง:
-- DROP DATABASE DBA_Baseline;
```

## แหล่งอ้างอิง

- 10987C Lab10 — `Trainer_Docs/10987/Labfiles/Lab10/`
- Microsoft Learn: [Performance monitoring tools](https://learn.microsoft.com/sql/relational-databases/performance/performance-monitoring-and-tuning-tools) · [Server roles (2022+)](https://learn.microsoft.com/sql/relational-databases/security/authentication-access/server-level-roles)
- Glenn Berry: [SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
- สคริปต์ของแล็บนี้อยู่ใน `Sections/*/Scripts/` ของโมดูล จัดตามหัวข้อที่เกี่ยวข้อง (ลิงก์ในแต่ละ Exercise)
