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

---

## Exercise 2: จำลอง Workload แล้วอ่าน Delta

### Step 1 — สร้างโหลดผสม (รันในหลายหน้าต่าง ~2 นาที)

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

```sql
USE DBA_Baseline;
EXEC dbo.CaptureBaselineSnapshot;

-- Top waits ในช่วงระหว่าง snapshot 2 ตัวล่าสุด
WITH FirstSnap AS (
    SELECT WaitType, WaitingTasksCount, WaitTimeMs, SignalWaitTimeMs,
           ROW_NUMBER() OVER (ORDER BY SnapshotId DESC) AS rn
    FROM dbo.WaitSnapshot
)
SELECT f.WaitType,
       s.WaitingTasksCount - f.WaitingTasksCount AS waits_delta,
       s.WaitTimeMs - f.WaitTimeMs AS wait_ms_delta,
       (s.WaitTimeMs - f.WaitTimeMs)
           / NULLIF(s.WaitingTasksCount - f.WaitingTasksCount, 0) * 1.0 AS avg_wait_ms
FROM dbo.WaitSnapshot AS s
JOIN FirstSnap AS f ON f.WaitType = s.WaitType AND f.rn = 1
WHERE s.SnapshotId = (SELECT MAX(SnapshotId) FROM dbo.WaitSnapshot)
  AND s.WaitingTasksCount - f.WaitingTasksCount > 0
ORDER BY wait_ms_delta DESC;
```

✅ **ตีความ**: `SOS_SCHEDULER_YIELD` = CPU, `PAGEIOLATCH_*` = disk read, `WRITELOG` = log write latency, `LCK_M_*` = blocking — นี่คือการอ่าน baseline ที่แท้จริง

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
