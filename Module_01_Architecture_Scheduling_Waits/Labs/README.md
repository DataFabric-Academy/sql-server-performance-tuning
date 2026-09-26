# Lab 1: Wait Statistics & CPU Pressure Analysis (บทที่ 1)

> **ที่มา**: ปรับปรุงจาก Microsoft 10987C **Lab01** (CPU and NUMA / Monitor Schedulers / Waits) + [Microsoft Learn — sys.dm_os_wait_stats](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql) + [Glenn Berry — SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
> รูปแบบ: **Instruction + Code block** — ทุก Step รันได้ทันทีใน SSMS (สคริปต์เสริมอยู่ใน `Scripts/`)

## Prerequisites

- SQL Server 2019+ (แนะนำ **2025 (17.x)**), database **AdventureWorks2025**
- Permission: `VIEW SERVER STATE` (หรือบทบาท `##MS_ServerPerformanceStateReader##`)
- เปิด SSMS ขึ้นมา 3 หน้าต่าง query (Window A, B, C)

## Scenario

บริษัท Proseware Inc. มีผู้ใช้ร้องเรียนว่า "ระบบช้ามาก" ทีม Infrastructure ปฏิเสธการเพิ่ม CPU เพราะกราฟแสดง CPU ใช้แค่ ~60% คุณสงสัยว่าปัญหาไม่ใช่ความจุ CPU แต่เป็น **Waits** และ **Inefficient CPU usage (Signal Waits)** — ให้พิสูจน์ด้วย DMV

## Objectives

1. ตรวจสอบ CPU/NUMA topology ของ instance
2. Monitor Schedulers และหาสัญญาณ CPU pressure
3. วิเคราะห์ Wait Statistics แยก Resource Waits vs Signal Waits
4. จำลอง workload จริงและติดตาม wait แบบ real-time

---

## Exercise 1: CPU and NUMA Topology (Window A)

### Step 1 — ตรวจสอบข้อมูล CPU, NUMA และ Worker ของ instance

```sql
SELECT cpu_count AS logical_cpus,
       socket_count AS physical_sockets,
       cores_per_socket,
       numa_node_count,
       max_workers_count,
       scheduler_count,
       scheduler_total_count,
       sqlserver_start_time
FROM sys.dm_os_sys_info;
```

✅ **สังเกต**: `max_workers_count` คือเพดาน Worker Threads (มักหลักหลายร้อยถึงหลายพันตาม CPU) — ถ้า workload ใช้เกินเกือบ 100% จะเกิด `THREADPOOL` wait

### Step 2 — ดู NUMA nodes และ CPU affinity

```sql
SELECT node_id,
       node_state_desc,          -- ONLINE / ONLINE AUTOMATIC = Soft-NUMA
       online_scheduler_count,
       active_worker_count,
       avg_load_balance,
       cpu_affinity_mask
FROM sys.dm_os_nodes;
```

✅ **สังเกต**: ถ้าเห็น `ONLINE AUTOMATIC` แปลว่า Soft-NUMA ถูกสร้างอัตโนมัติ (SQL Server 2016+)

### Step 3 — ตรวจ scheduler ต่อ NUMA node และสถานะ (Glenn Berry style)

```sql
SELECT parent_node_id,
       scheduler_id,
       status,
       is_online,
       is_idle,
       current_tasks_count,
       runnable_tasks_count,     -- > 0 ต่อเนื่อง = CPU queue
       work_queue_count,
       pending_disk_io_count,
       load_factor
FROM sys.dm_os_schedulers
WHERE scheduler_id < 1048576      -- visible schedulers เท่านั้น
ORDER BY parent_node_id, scheduler_id;
```

---

## Exercise 2: วัด Signal Wait Ratio (CPU Pressure Indicator) (Window A)

### Step 1 — คำนวณ Resource vs Signal Waits รวมทั้ง instance

```sql
SELECT SUM(signal_wait_time_ms) * 1.0 / SUM(wait_time_ms) * 100
           AS signal_wait_pct,                 -- > 10-15% = CPU pressure
       SUM(wait_time_ms - signal_wait_time_ms) * 1.0
           / SUM(wait_time_ms) * 100 AS resource_wait_pct,
       SUM(waiting_tasks_count) AS total_waiting_tasks
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > 0;
```

### Step 2 — Top waits แบบกรอง benign waits ออก (สไตล์ Glenn Berry)

```sql
WITH Waits AS
(
    SELECT wait_type, wait_time_ms / 1000.0 AS wait_s,
           (wait_time_ms - signal_wait_time_ms) / 1000.0 AS resource_s,
           signal_wait_time_ms / 1000.0 AS signal_s,
           waiting_tasks_count
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN (
        N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP',
        N'BROKER_TO_FLUSH', N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE',
        N'CHKPT', N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE',
        N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE', N'DBMIRROR_WORKER_QUEUE',
        N'DBMIRRORING_CMD', N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
        N'EXECSYNC', N'FSAGENT', N'FT_IFTS_SCHEDULER_IDLE_WAIT',
        N'FT_IFTSHC_MUTEX', N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
        N'HADR_LOGCAPTURE_WAIT', N'HADR_NOTIFICATION_DEQUEUE', N'HADR_TIMER_TASK',
        N'HADR_WORK_QUEUE', N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP',
        N'LOGMGR_QUEUE', N'MEMORY_ALLOCATION_EXT', N'ONDEMAND_TASK_QUEUE',
        N'PARALLEL_REDO_DRAIN_WORKER', N'PARALLEL_REDO_LOG_CACHE',
        N'PARALLEL_REDO_TRAN_LIST', N'PARALLEL_REDO_WORKER_SYNC',
        N'PARALLEL_REDO_WORKER_WAIT_WORK', N'PREEMPTIVE_XE_GETTARGETSTATE',
        N'PVS_PREALLOCATE', N'PWAIT_ALL_COMPONENTS_INITIALIZED',
        N'PWAIT_DIRECTLOGCONSUMER_GETNEXT', N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
        N'QDS_ASYNC_QUEUE', N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
        N'QDS_SHUTDOWN_QUEUE', N'REDO_THREAD_PENDING_WORK', N'REQUEST_FOR_DEADLOCK_SEARCH',
        N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH',
        N'SLEEP_DBSTARTUP', N'SLEEP_DCOMSTARTUP', N'SLEEP_MASTERDBREADY',
        N'SLEEP_MASTERMDREADY', N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP',
        N'SLEEP_SYSTEMTASK', N'SLEEP_TASK', N'SLEEP_TEMPDBSTARTUP',
        N'SNI_HTTP_ACCEPT', N'SOS_WORK_DISPATCHER', N'SP_SERVER_DIAGNOSTICS_SLEEP',
        N'SQLTRACE_BUFFER_FLUSH', N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        N'SQLTRACE_WAIT_ENTRIES', N'VDI_CLIENT_OTHER', N'WAIT_FOR_RESULTS',
        N'WAITFOR', N'WAITFOR_TASKSHUTDOWN', N'WAIT_XTP_RECOVERY',
        N'WAIT_XTP_HOST_WAIT', N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
        N'WAIT_XTP_CKPT_CLOSE', N'XE_DISPATCHER_JOIN', N'XE_DISPATCHER_WAIT',
        N'XE_LIVE_TARGET_TVF', N'XE_TIMER_EVENT')
    AND waiting_tasks_count > 0
)
SELECT TOP (25) wait_type, waiting_tasks_count,
       wait_s AS total_wait_s,
       CAST(100.0 * wait_s / SUM(wait_s) OVER () AS DECIMAL(10,1)) AS pct_total,
       resource_s, signal_s
FROM Waits
ORDER BY wait_s DESC;
```

✅ **สังเกต**: จด Top 5 ไว้เทียบกับผลหลังจากจำลอง workload

---

## Exercise 3: จำลอง CPU Pressure (Window B)

### Step 1 — รัน workload กิน CPU (คำนวณหนัก ๆ วนลูป)

```sql
-- Window B: รันทิ้งไว้ (~60 วินาที) แล้วไปทำ Exercise 4 ที่ Window C
DECLARE @n BIGINT = 0, @i BIGINT = 0;
WHILE @i < 500000000
BEGIN
    SET @n = @n + (@i % 7) * 3;
    SET @i += 1;
END
SELECT @n;
```

> **Tip**: เปิด Window B ซ้ำ 2–3 หน้าต่างแล้วรันพร้อมกัน เพื่อให้กิน CPU ครบทุก scheduler

### Step 2 — ดู runnable queue แบบ real-time (Window C)

```sql
SELECT scheduler_id,
       current_tasks_count,
       runnable_tasks_count,   -- ค้าง > 0 = task ต่อคิวรอ CPU
       current_workers_count,
       active_workers_count,
       work_queue_count
FROM sys.dm_os_schedulers
WHERE scheduler_id < 1048576 AND status = 'VISIBLE ONLINE'
ORDER BY runnable_tasks_count DESC;
```

### Step 3 — ดู wait ของ session ที่กำลังรัน

```sql
SELECT r.session_id, r.status, r.wait_type, r.wait_time,
       r.last_wait_type, r.cpu_time, r.total_elapsed_time,
       LEFT(t.text, 80) AS running_sql
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.session_id <> @@SPID AND r.is_user_process = 1;
```

✅ **สังเกต**: `wait_type = SOS_SCHEDULER_YIELD` + `runnable_tasks_count > 0` = quantum exhaustion (หมดคิว 4 ms ต่อครั้งแล้วต้องต่อคิว)

### Step 4 — วัดผลกระทบที่ Signal Waits หลัง workload จบ

```sql
-- รันซ้ำคำสั่ง Step 1 ของ Exercise 2
-- สังเกต signal_wait_pct สูงขึ้นชั่วคราว และ SOS_SCHEDULER_YIELD พุ่งใน Top waits
```

---

## Exercise 4: จำลอง ASYNC_NETWORK_IO (Client รับไม่ทัน)

### Step 1 — ส่ง result set ใหญ่ช้า ๆ ไปที่ client

```sql
-- Window B: รันทิ้งไว้
SELECT so.* , (SELECT COUNT(*) FROM sys.objects) AS filler
FROM sys.all_objects AS so
CROSS JOIN sys.all_columns AS sc;
```

### Step 2 — ตรวจ wait ปัจจุบันของ session นั้น

```sql
-- Window C:
SELECT session_id, wait_type, wait_time, blocking_session_id, cpu_time
FROM sys.dm_exec_requests
WHERE session_id <> @@SPID;
```

✅ **สังเกต**: `ASYNC_NETWORK_IO` = SQL Server พร้อมส่งข้อมูล แต่ client/network รับไม่ทัน — ปัญหาอยู่ฝั่ง application ไม่ใช่ storage

---

## Wrap-up: คำถามท้ายแล็บ

1. Signal Wait Ratio ของ instance ก่อน/หลัง workload ต่างกันเท่าไร? สรุปได้ว่า CPU เป็น bottleneck จริงหรือไม่?
2. `SOS_SCHEDULER_YIELD` กับ `CXPACKET` ต่างกันอย่างไรในเชิงการตีความ?
3. ถ้า `runnable_tasks_count` ค้าง > 0 ตลอดเวลา แต่ CPU utilization แค่ 60% — เป็นไปได้ไหม? เพราะอะไร (Hint: single-threaded query / SOS Scheduler)

## Cleanup

```sql
-- Reset wait stats (ทำเฉพาะบน VM ทดสอบ — ห้ามรันบน Production เพราะค่าสะสมจะหาย)
DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);
```

## แหล่งอ้างอิง

- 10987C Lab01 (CPU and NUMA, Monitor Schedulers, Waits) — `Trainer_Docs/10987/Labfiles/Lab01/`
- Microsoft Learn: [sys.dm_os_wait_stats](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql) · [sys.dm_os_schedulers](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-os-schedulers-transact-sql) · [Thread and Task Architecture Guide](https://learn.microsoft.com/sql/relational-databases/thread-and-task-architecture-guide)
- Glenn Berry: [SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
- ไฟล์ประกอบทั้งหมดอยู่ใน `Scripts/` ของโฟลเดอร์นี้ (`Scripts/01–08`) — โค้ดหลักของทุก Exercise ฝังอยู่ใน README ฉบับนี้แล้ว
