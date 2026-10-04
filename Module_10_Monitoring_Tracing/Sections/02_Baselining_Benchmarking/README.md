[⬅ Module 10](../../README.md) | [01 Monitoring & Tracing](../01_Monitoring_Tracing/README.md) | Section 2/2 | 🧪 [Labs](../../Labs/README.md)

# 10.2 Baselining & Benchmarking — รู้ว่า "ปกติ" คืออะไร ก่อนตัดสินว่า "ผิดปกติ"

> *"ตัวเลขที่ไม่มีจุดเทียบ คือตัวเลขที่ตีความไม่ได้ — PLE 500 ต่ำหรือเปล่า? คำตอบขึ้นอยู่กับว่า 'ปกติของเครื่องนี้' คือเท่าไร"*

> **ต้องรู้มาก่อน**: [Section 10.1](../01_Monitoring_Tracing/README.md) (Snapshot vs Cumulative, delta waits, PerfMon) และ [Section 1.4 — Wait Statistics](../../../Module_01_Architecture_Scheduling_Waits/Sections/04_Wait_Statistics/README.md) — บล็อกทดลองใน section นี้ใช้ **DDL พื้นฐาน** (`CREATE TABLE`, `CREATE OR ALTER PROCEDURE`) ใน **tempdb** และ `WHILE`/`WAITFOR DELAY` สำหรับ workload จำลอง
> ศัพท์ใหม่ดู [Glossary](../../../Glossary.md)

---

## ทำไม Baseline จึงเป็นใบเบิกทางของการ Tune

หลังผ่าน Module 1–9 คุณมีเครื่องมือวัดครบแล้ว แต่การวัดยังตอบไม่ได้คำถามที่ผู้จัดการถามจริง: **"วันนี้มันแย่ลงจากเมื่อวานกี่เท่า?"** — คำถามนี้ตอบได้ด้วย Baseline เท่านั้น เพราะเป็นการเก็บ "ภาพปกติ" ไว้ล่วงหน้า ก่อนที่ปัญหาจะมาเยือน

**นิยามให้ชัดก่อนใช้** (สองคำนี้ถูกใช้สลับกันผิด ๆ บ่อยมาก):

| ศัพท์ | นิยาม | คำถามที่ตอบ | มาจากไหน |
|:------|:-------|:-------------|:-----------|
| **Baseline** | ชุดสถิติ "สถานะปกติ" ของระบบ บันทึกต่อเนื่องครอบคลุม peak/off-peak | "ตอนนี้ผิดปกติไหม — เบี่ยงจากปกติกี่เท่า?" | เก็บเองจาก DMVs ตามรอบเวลา |
| **Benchmark** | เกณฑ์เป้าหมาย/ขีดจำกัดที่ระบบรับได้ มักจากการทดสอบควบคุมตัวแปร | "เครื่องนี้รับโหลดสูงสุดได้แค่ไหน?" | Stress test / ข้อตกลงระดับบริการ (SLA) |
| **Anomaly Detection** | กระบวนการธงว่าค่าปัจจุบัน "เบี่ยงจาก baseline" เกินจุดตัดที่กำหนด | "เมื่อไรควรตื่นมาดู?" | เทียบค่าปัจจุบันกับ baseline |
| **Delta** | ค่าสะสมช่วงล่าสุด − ค่าสะสมช่วงก่อน (หารช่วงเวลาได้ rate) | "ช่วง 15 นาทีที่ผ่านมารออะไร?" | ลบ snapshot สองจุด |
| **Benchmark คุมตัวแปร** | การทดสอบที่ **เปลี่ยนสิ่งเดียว** ระหว่างสองรอบวัด | "แก้แล้วดีขึ้นจริงหรือแค่เครื่องว่าง?" | วิธีวิทยาการวัด |

> [!IMPORTANT]
> ลำดับที่ถูกต้องของอาชีพนี้: **ทำ baseline ก่อนเสมอ** — ถ้ามีแต่ benchmark โดยไม่มี baseline คุณจะรู้ว่า "เครื่องควรทำได้เท่านี้" แต่ไม่รู้ว่า "วันนี้มันหลุดจากปกติตั้งแต่กี่โมง" เคส "ระบบช้าเป็นบางช่วง" แทบทุกเคสแก้ได้เพราะมี baseline จับพฤติกรรมช่วงเวลาไว้

---

## 1. Methodology — เก็บอะไร ถี่แค่ไหน เก็บนานแค่ไหน

ตอบ 3 คำถามนี้ให้ได้ก่อนเปิด SSMS:

### 1.1 เก็บอะไร (Metrics)

| กลุ่ม | Metrics | แหล่ง (จาก Section 10.1) |
|:------|:--------|:--------------------------|
| **Waits** | top waits + avg wait ต่อ interval (กรอง benign) | `sys.dm_os_wait_stats` |
| **I/O** | reads/writes + latency ต่อไฟล์ | `sys.dm_io_virtual_file_stats` |
| **CPU** | SQL CPU % + Other process % + runnable queue | Ring Buffer + `sys.dm_os_schedulers` |
| **Memory** | PLE, Memory Grants Pending, Total/Target Server Memory | `sys.dm_os_performance_counters` |
| **Workload** | Batch Requests/sec, Compilations/sec | `sys.dm_os_performance_counters` (rate) |
| **Concurrency** | blocking sessions, lock waits | `sys.dm_exec_requests` |
| **ขนาด/กำลังผลิต** | DB/log size, log space used %, last backup | `sys.databases`, `DBCC SQLPERF(LOGSPACE)`, msdb |
| **ระดับ query** | top regressed/top resource queries | Query Store (M8 — เปิดไว้ทุก production DB) |

### 1.2 ถี่แค่ไหน (Frequency)

| แหล่ง | ความถี่แนะนำ | เหตุผล |
|:------|:--------------|:--------|
| PerfMon (ระดับ OS) | ทุก 15–60 วินาที | เก็บละเอียดได้โดย overhead ต่ำ |
| DMV snapshot (ระดับ SQL) | ทุก 5–15 นาที (Lab ใช้ 15) | พอเห็นรูปแบบชั่วโมง/วัน โดยตารางไม่บวม |
| Glenn Berry diagnostics (สแนปช็อตเชิงลึก) | รายวัน/รายสัปดาห์ | เชิงลึกทั้งระบบ ไม่เหมาะราย 15 นาที |
| Query Store | อัตโนมัติตลอดเวลา | engine เก็บเอง (ค่า default flush 60 นาที) |

### 1.3 เก็บนานแค่ไหน (Retention)

แนะนำ **3–6 เดือน** เพื่อให้ครอบ business cycle รายเดือน (รัน payroll, รายงานสิ้นเดือน, รายไตรมาส) และเห็น trend การเติบโตเพื่อ Capacity Planning — พร้อมกันนั้นต้องวางแผนขนาดของตาราง baseline เองด้วย (snapshot 143 แถว × 96 รอบ/วัน ≈ 13,700 แถว/วัน สำหรับ wait stats เพียงอย่างเดียว — จึงควร purge ข้อมูลเก่าตามกำหนด)

---

## 2. ลงมือสร้าง — โครงสร้าง Baseline ฉบับทดลอง (tempdb)

หลักการมี 2 ส่วน: **ตารางเก็บ snapshot** กับ **procedure จับค่า 1 ครั้ง** จาก Section 10.1 (wait stats + file I/O) — แล็บเต็ม ([Lab 10](../../Labs/README.md)) สร้างเป็นฐานข้อมูลจริง `DBA_Baseline` พร้อม SQL Agent Job ทุก 15 นาที ส่วนที่นี่เราสร้าง **ใน tempdb เพื่อฝึกบนเครื่องทดสอบร่วม** แล้วลบทิ้งหมดจบใน section เดียว:

```sql
USE tempdb;
GO
CREATE TABLE dbo.M10_WaitSnapshot
(
    SnapshotId INT IDENTITY PRIMARY KEY,
    CapturedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    WaitType NVARCHAR(60),
    WaitingTasksCount BIGINT,
    WaitTimeMs BIGINT,
    SignalWaitTimeMs BIGINT
);
GO
CREATE TABLE dbo.M10_FileIOSnapshot
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
CREATE OR ALTER PROCEDURE dbo.M10_CaptureSnapshot
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.M10_WaitSnapshot (WaitType, WaitingTasksCount, WaitTimeMs, SignalWaitTimeMs)
    SELECT wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms
    FROM sys.dm_os_wait_stats
    WHERE waiting_tasks_count > 0;

    INSERT dbo.M10_FileIOSnapshot (DatabaseName, FileLogicalName, TypeDesc,
                                   NumOfReads, NumOfWrites, IoStallReadMs, IoStallWriteMs)
    SELECT DB_NAME(vfs.database_id), mf.name, mf.type_desc,
           vfs.num_of_reads, vfs.num_of_writes, vfs.io_stall_read_ms, vfs.io_stall_write_ms
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
    JOIN sys.master_files AS mf
        ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id;
END
GO
-- จับ snapshot แรก (ภาพ "ก่อน" ของหน้าต่างวัด)
EXEC dbo.M10_CaptureSnapshot;
GO
```

**อ้างอิงรันจริง** บน server หลักสูตร (SQL Server 2025 RTM-GDR 17.0.1135.8): snapshot แรกเติม `M10_WaitSnapshot` ~143–148 แถว (1 แถวต่อ wait type ที่มีค่าสะสม) และ `M10_FileIOSnapshot` ~19–26 แถว (1 แถวต่อไฟล์ data/log ของทุก DB) — ตรงกับ Expected ของ [Lab 10 Exercise 1](../../Labs/README.md) (143/19 แถว) ตัวเลขแกว่งได้ตามจำนวน wait type/ไฟล์ ณ เวลานั้น

> **หมายเหตุ VM ทดสอบ**: ถ้า `USE AdventureWorks` ในหัวข้อถัดไปขึ้น error ว่าไม่มี database ให้ตรวจชื่อจริงด้วย `SELECT name FROM sys.databases;` (VM ของหลักสูตรใช้ชื่อ `AdventureWorks`)

---

## 3. จำลอง Workload แล้วอ่าน Delta — หัวใจของ Baseline

### 3.1 สร้างโหลดผสม (อ่าน + เขียน log) ≤ 1 นาที

```sql
USE AdventureWorks;
GO
DECLARE @i INT = 0;
WHILE @i < 60
BEGIN
    -- อ่าน: scan เล็ก ๆ ใช้ CPU + logical I/O
    SELECT COUNT(*) FROM Sales.SalesOrderDetail WHERE ProductID % 10 = @i % 10;
    -- เขียน: บังคับสร้าง log records (SET = ค่าเดิม — ไม่เปลี่ยนข้อมูลจริง แต่ยังเขียน log)
    UPDATE TOP (50) Sales.SalesOrderDetail
    SET ModifiedDate = ModifiedDate
    WHERE SalesOrderDetailID % 700 = @i % 700;
    SET @i += 1;
    WAITFOR DELAY '00:00:00.3';
END
```

> [!TIP]
> `SET ModifiedDate = ModifiedDate` คือเทคนิคเดียวกับเดโม blocking ของ M11 — UPDATE ยังเดินเครื่อง log/lock ครบถ้วน แต่**ไม่เปลี่ยนข้อมูลจริง** เหมาะกับเครื่องสาธิตร่วม (สคริปต์ workload แบบเต็มอยู่ที่ `Scripts/01_Workload_Noise.sql`)

รัน workload (~20 วินาที) แล้วจับ snapshot ที่สอง จากนั้นคำนวณ delta ต่อ wait type — เทียบ "จับครั้งแรก vs ครั้งล่าสุด" ของแต่ละ WaitType:

### 3.2 จับ snapshot ที่สอง + Delta waits

```sql
USE tempdb;
EXEC dbo.M10_CaptureSnapshot;

WITH Snap AS (
    SELECT WaitType, WaitingTasksCount, WaitTimeMs, SignalWaitTimeMs,
           ROW_NUMBER() OVER (PARTITION BY WaitType ORDER BY SnapshotId ASC)  AS rn_first,
           ROW_NUMBER() OVER (PARTITION BY WaitType ORDER BY SnapshotId DESC) AS rn_last
    FROM dbo.M10_WaitSnapshot
)
SELECT TOP (10) f.WaitType,
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

**อ้างอิงรันจริง** บน server หลักสูตร: Top ของตารางถูกครองด้วย background waits (`SOS_WORK_DISPATCHER`, `SLEEP_TASK`, `LOGMGR_QUEUE`, `CHECKPOINT_QUEUE`) เพราะเครื่องทดสอบมี agent อื่นใช้ร่วม — **ไม่ใช่ความผิดของ query** แต่เป็นบทเรียนตรง ๆ ว่าทำไมต้องกรอง benign (หัวข้อ 4) กลุ่มที่ตรงกับ workload ของเราซ่อนอยู่ในลำดับถัดไป และสอดคล้องกับ Expected ของ [Lab 10 Exercise 2](../../Labs/README.md) ที่รันหน้าต่างยาวกว่า (~90 วิ): `WRITELOG` +199 ครั้ง (+272 ms ≈ 1 ms/ครั้ง) และ `SOS_SCHEDULER_YIELD` +2,581 ครั้ง

### 3.3 Delta ฝั่ง I/O — ยืนยันด้วยข้อมูลชั้นที่สอง

หลัก Waits & Queues ของ M1: wait เดียวไม่พอตัดสิน ต้องเทียบแหล่งที่สอง — ที่นี่คือ `M10_FileIOSnapshot`:

```sql
WITH Snap AS (
    SELECT DatabaseName, FileLogicalName, TypeDesc, NumOfReads, NumOfWrites, IoStallReadMs, IoStallWriteMs,
           ROW_NUMBER() OVER (PARTITION BY DatabaseName, FileLogicalName ORDER BY SnapshotId ASC)  AS rn_first,
           ROW_NUMBER() OVER (PARTITION BY DatabaseName, FileLogicalName ORDER BY SnapshotId DESC) AS rn_last
    FROM dbo.M10_FileIOSnapshot
)
SELECT TOP (10) f.DatabaseName, f.FileLogicalName, f.TypeDesc,
       l.NumOfReads - f.NumOfReads AS reads_delta,
       l.NumOfWrites - f.NumOfWrites AS writes_delta,
       l.IoStallWriteMs - f.IoStallWriteMs AS write_stall_delta_ms,
       CAST((l.IoStallWriteMs - f.IoStallWriteMs) * 1.0
            / NULLIF(l.NumOfWrites - f.NumOfWrites, 0) AS DECIMAL(10,2)) AS avg_write_ms
FROM Snap AS f
JOIN Snap AS l
    ON l.DatabaseName = f.DatabaseName AND l.FileLogicalName = f.FileLogicalName
WHERE f.rn_first = 1 AND l.rn_last = 1
  AND (l.NumOfReads - f.NumOfReads) + (l.NumOfWrites - f.NumOfWrites) > 0
ORDER BY write_stall_delta_ms DESC;
```

**อ้างอิงรันจริง** บน server หลักสูตร: `AdventureWorks_log` **+149 writes, write stall +173 ms → เฉลี่ย 1.16 ms/write** (ตามด้วย ROWS ไฟล์ +12 writes ที่ 2.42 ms) — สอดคล้องกับ `WRITELOG` delta ฝั่ง waits (~1 ms/ครั้ง) อย่างสม่ำเสมอ: มุมมอง "task ที่รอ" (WRITELOG) กับมุมมอง "storage ที่ทำงาน" (file stats) เล่าเรื่องเดียวกัน — นี่คือการอ่าน baseline ที่แท้จริง (เกณฑ์: log write < 5 ms = ปกติดี)

---

## 4. จุดตัด "ผิดปกติ" — จากข้อมูลดิบสู่ธงเตือน

### 4.1 หลักคิดสองชั้น

| ชั้น | วิธีตั้งจุดตัด | ตัวอย่าง | ข้อดี/ข้อเสีย |
|:-----|:----------------|:----------|:----------------|
| **Absolute threshold** (เกณฑ์สากล) | ค่าคงที่ที่วงการยอมรับ | log write > 5 ms, read > 20 ms, signal wait > 10–15% | เริ่มง่าย — แต่ไม่รู้ "ปกติของเครื่องนี้" |
| **Baseline-relative** (เทียบตัวเอง) | ค่าปัจจุบันเทียบค่าเฉลี่ย/p95 ของช่วงเวลาเดียวกันใน baseline | avg write ช่วง 9:00 วันนี้ = 3× ค่าเฉลี่ย 9:00 ของ 30 วันก่อน | จับความผิดปกติของเครื่องนี้ได้จริง — ต้องมีข้อมูลสะสมก่อน |

ใช้ **สองชั้นคู่กัน**: เริ่มจาก absolute เพื่อเปิดระบบได้ทันที แล้วเปลี่ยนเป็น baseline-relative เมื่อข้อมูลสะสม 2–4 สัปดาห์ — ถ้าตั้งเกณฑ์ตายตัวอย่างเดียว อาจพลาดเครื่องที่ "ปกติก็เกินเกณฑ์สากลอยู่แล้ว" หรือพลาดเครื่องที่ "แย่ลง 2 เท่าแต่ยังไม่ถึงเกณฑ์"

### 4.2 ธงเตือนจาก delta — กรอง benign แล้วติดป้ายอัตโนมัติ

```sql
USE tempdb;
WITH Snap AS (
    SELECT WaitType, WaitingTasksCount, WaitTimeMs,
           ROW_NUMBER() OVER (PARTITION BY WaitType ORDER BY SnapshotId ASC)  AS rn_first,
           ROW_NUMBER() OVER (PARTITION BY WaitType ORDER BY SnapshotId DESC) AS rn_last
    FROM dbo.M10_WaitSnapshot
),
Delta AS (
    SELECT f.WaitType,
           l.WaitingTasksCount - f.WaitingTasksCount AS waits_delta,
           l.WaitTimeMs - f.WaitTimeMs AS wait_ms_delta,
           (l.WaitTimeMs - f.WaitTimeMs)
               / NULLIF(l.WaitingTasksCount - f.WaitingTasksCount, 0) * 1.0 AS avg_wait_ms
    FROM Snap AS f
    JOIN Snap AS l ON l.WaitType = f.WaitType
    WHERE f.rn_first = 1 AND l.rn_last = 1
      AND l.WaitingTasksCount > f.WaitingTasksCount
      AND f.WaitType NOT IN (N'CHECKPOINT_QUEUE', N'DIRTY_PAGE_POLL', N'LAZYWRITER_SLEEP',
            N'LOGMGR_QUEUE', N'REQUEST_FOR_DEADLOCK_SEARCH', N'BROKER_TO_FLUSH',
            N'MEMORY_ALLOCATION_EXT', N'SLEEP_TASK', N'SLEEP_SYSTEMTASK', N'SLEEP_BPOOL_FLUSH',
            N'XE_TIMER_EVENT', N'WAITFOR', N'BROKER_TASK_STOP', N'BROKER_EVENTHANDLER',
            N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'HADR_WORK_QUEUE', N'HADR_TIMER_TASK',
            N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', N'SOS_WORK_DISPATCHER',
            N'SP_SERVER_DIAGNOSTICS_SLEEP', N'DISPATCHER_QUEUE_SEMAPHORE',
            N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', N'QDS_ASYNC_QUEUE', N'KSOURCE_WAKEUP',
            N'XE_DISPATCHER_WAIT')
      AND f.WaitType NOT LIKE N'PREEMPTIVE_%'
)
SELECT TOP (10) WaitType, waits_delta, wait_ms_delta,
       CAST(avg_wait_ms AS DECIMAL(10,1)) AS avg_wait_ms,
       CASE
           WHEN WaitType LIKE N'WRITELOG%'        AND avg_wait_ms > 5    THEN N'log latency > 5 ms — ตรวจ .ldf / auto-grow'
           WHEN WaitType LIKE N'PAGEIOLATCH%'     AND avg_wait_ms > 20   THEN N'read latency > 20 ms — ตรวจ storage / index'
           WHEN WaitType = N'SOS_SCHEDULER_YIELD' AND waits_delta > 1000 THEN N'CPU pressure — ดู signal wait + top CPU query'
           WHEN WaitType = N'SOS_SCHEDULER_YIELD'                        THEN N'CPU ถูกใช้หนักช่วงสั้น — ดู top CPU query'
           WHEN WaitType LIKE N'LCK_M%'                                  THEN N'blocking — หา head blocker'
           ELSE N'—'
       END AS interpretation
FROM Delta
ORDER BY wait_ms_delta DESC;
```

**อ้างอิงรันจริง** บน server หลักสูตร (หลัง workload 60 รอบ ~20 วินาที): หลังกรอง benign แล้ว workload จริงโผล่มาชัดเจน — `CXCONSUMER` +803, `PAGELATCH_EX` +3,009 (tempdb version store จาก RCSI), `WRITELOG` +78 ที่ ~1 ms, `SOS_SCHEDULER_YIELD` +946 ซึ่งติดธง *"CPU ถูกใช้หนักช่วงสั้น"* — ภาพเดียวกับ Expected ของแล็บ และแต่ละธงชี้ไปยังขั้นวินิจฉัยของโมดูลที่เกี่ยว (WRITELOG → M2/M3, SOS_SCHEDULER_YIELD → M1/M7, LCK_M → M5)

> **จุดเชื่อมโยง:** ตัว `interpretation` ใน query นี้คือต้นแบบของ **Runbook** — ธงแต่ละแถวควรผูกกับขั้นตอนตอบสนองที่เขียนไว้ล่วงหน้า ไม่ใช่คำอธิบายแล้วจบ (ต่อยอดใน [Module 11](../../../Module_11_Troubleshooting/Sections/01_Troubleshooting_Workflow/README.md))

---

## 5. Benchmark — พิสูจน์ว่า "ดีขึ้นจริง" ด้วยการคุมตัวแปร

Baseline ตอบว่า "ผิดปกติ" แต่ก่อนจะ claim ว่า "แก้แล้วเร็วขึ้น 3 เท่า" ต้องวัดด้วยวิธีที่ตรวจสอบได้ กฎ 4 ข้อของ benchmark:

1. **Warm-up ก่อนวัด** — รอบแรกจ่ายค่า compile/อ่าน disk จึง "ทิ้งผล" ไม่เอาไปเทียบ (cache ต้องเป็นตัวแปรคงที่)
2. **เปลี่ยนสิ่งเดียว** ระหว่างสองชุดการทดลอง — ถ้าเปลี่ยน query + index + statistics พร้อมกัน จะไม่มีใครรู้ว่าอะไรทำให้ดีขึ้น
3. **ใช้เมตริกที่เสถียร** — `logical reads` และ `CPU time` ทำซ้ำได้กว่า `elapsed time` (elapsed แกว่งตามโหลดร่วม)
4. **วัดซ้ำหลายรอบ** แล้วดูค่าที่ทำซ้ำได้ ไม่ใช่ค่าดีที่สุดที่เจอ

```sql
USE AdventureWorks;
GO
SET STATISTICS IO, TIME ON;

-- รอบอุ่นเครื่อง (warm-up) — ทิ้งผล ไม่นำไปเทียบ (จัดการแคชให้เป็นตัวแปรคงที่)
SELECT COUNT_BIG(*) FROM Sales.SalesOrderDetail WHERE ProductID = 897;

-- รูปแบบ A: index seek (จำกัดขอบเขตอ่าน)
SELECT COUNT_BIG(*) FROM Sales.SalesOrderDetail WHERE ProductID = 897;
SELECT COUNT_BIG(*) FROM Sales.SalesOrderDetail WHERE ProductID = 897;
SELECT COUNT_BIG(*) FROM Sales.SalesOrderDetail WHERE ProductID = 897;

-- รูปแบบ B: เงื่อนไขที่ไม่มี index รองรับ — ต้องสแกนทั้งตาราง
SELECT COUNT_BIG(*) FROM Sales.SalesOrderDetail WHERE CarrierTrackingNumber = N'5CF9-466-11';
SELECT COUNT_BIG(*) FROM Sales.SalesOrderDetail WHERE CarrierTrackingNumber = N'5CF9-466-11';
SELECT COUNT_BIG(*) FROM Sales.SalesOrderDetail WHERE CarrierTrackingNumber = N'5CF9-466-11';

SET STATISTICS IO, TIME OFF;
GO
```

**อ้างอิงรันจริง** บน server หลักสูตร (ตาราง `Sales.SalesOrderDetail` ~121,317 แถว):

| รูปแบบ | logical reads | CPU time | elapsed time (3 รอบ) |
|:--------|:---------------|:----------|:----------------------|
| A — seek ด้วย `ProductID` | **2** | 0 ms | ~0 ms คงที่ |
| B — scan ด้วย `CarrierTrackingNumber` | **1,935** | 16–31 ms | แกว่ง 21–27 ms |

อ่านผลแบบมืออาชีพ: A อ่าน 2 pages กับ B อ่าน 1,935 pages (**~967 เท่า**) โดยทำ "งานเดียวกัน" — สังเกตว่า **logical reads คงที่ 1,935 ทุกรอบ แต่ elapsed แกว่ง 21→27→21 ms** ตามโหลดร่วมของเครื่อง นี่คือเหตุผลข้อ 3: ถ้าเทียบด้วย elapsed บนเครื่องที่มีคนอื่นใช้ร่วม สรุปของคุณจะไม่ทำซ้ำได้

เครื่องมือ benchmark ระดับสูงขึ้น (แนะนำให้รู้จัก ใช้ตอนสอนบน VM):

| เครื่องมือ | ใช้ทำอะไร |
|:-----------|:-----------|
| **DiskSpd** | วัดเพดาน storage จริง ๆ (IOPS/latency) ก่อนตำหนิ SQL — ดู M2 |
| **Distributed Replay** | Replay trace จาก production หลาย client จำลองโหลดจริง ใช้ก่อน upgrade |
| **ostress (RML Utilities)** | ยิง query ซ้ำแบบ concurrency คุมได้ — ดีกับเคส blocking/plan cache |

---

## 6. Daily Health Check — Baseline ฉบับหน้าเดียวจบ

ทุกเช้ารันชุดเดียว 6 result sets (ต่อยอดเป็น [Lab 10 Exercise 3](../../Labs/README.md) และผูกกับแนวทาง Glenn Berry ในหัวข้อ 7):

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
LEFT JOIN msdb.dbo.backupset AS bs ON bs.database_name = d.name
WHERE d.database_id > 4
GROUP BY d.name
ORDER BY last_backup;
```

อ่านค่าแต่ละ result set เป็น "ธง" — และเช่นเคย ธงที่ดีเทียบกับ baseline ของเครื่องนี้:

| Result set | ปกติ | ธง "ต้องตามต่อ" |
|:------------|:------|:------------------|
| 0. version + restart | restart นานเดือน ๆ | restart เมื่อไม่กี่ชั่วโมง = สงสัย crash/failover (ค่าสะสมทั้งหมดถูกรีเซ็ตด้วย!) |
| 1. OS memory | `Available physical memory is high` | state เปลี่ยน / ว่างต่ำกว่า baseline มาก |
| 2. SQL memory | utilization สูงได้ แต่ `process_physical_memory_low = 0` | `= 1` = OS กำดันจริง (Resource Monitor เริ่ม trim cache) |
| 3. Runnable queue | 0 บนเครื่องว่าง | > 0 ค้างหลาย scheduler ตอนมีอาการ = CPU pressure |
| 4. Query Store ปิด | ว่าง (เปิดหมด) | มีชื่อ DB = เสีย baseline ระดับ query ของ DB นั้น |
| 5. Last backup | มีวันที่ล่าสุดตามนโยบาย | **NULL = ยังไม่เคย backup เลย** — วิกฤต แก้ก่อนเรื่อง tuning ทั้งหมด |

**อ้างอิงรันจริง** บน server หลักสูตร: restart ล่าสุดช่วงเช้าวันทดสอบ, OS memory `high` ว่าง ~10–12 GB, `memory_utilization_percentage = 100` แต่ `process_physical_memory_low = 0` (SQL ใช้เต็ม target ของตัวเอง — ปกติของ dynamic memory ไม่ใช่ pressure), runnable queue = 0, ไม่มี DB ที่ QS ปิด และ backup ล่าสุดของ AdventureWorks มีวันที่ (เครื่องแล็บมีการ backup ให้แล้ว — ต่างจาก Expected เดิมของแล็บที่ว่าง ตัวเลขเหล่านี้แกว่งได้ตามสภาพเครื่อง สิ่งสำคัญคือรู้ว่า "ธง" อยู่ตรงไหน)

เช็คเสริมที่ควรรู้จัก — พื้นที่ log แบบคำสั่งเดียว:

```sql
DBCC SQLPERF(LOGSPACE);
```

คืนขนาด log + % ที่ใช้จริงของทุก DB — ถ้า log ใหญ่มากแต่ % ใช้ต่ำ = จัดขนาดเกินหรือไม่เคย truncate (ดู recovery model/backup log ต่อใน M3)

---

## 7. เครื่องมือมาตรฐาน — Glenn Berry Diagnostics, dbatools และสิทธิ์ที่ถูกต้อง

### 7.1 Glenn Berry's Diagnostic Queries

ชุด query ตรวจสุขภาพที่วงการใช้เป็นมาตรฐาน (มีรุ่นสำหรับ SQL Server 2025 — ดาวน์โหลดจาก [glennsqlperformance.com/resources](https://glennsqlperformance.com/resources/)) จัดหมวด Instance Level, CPU/NUMA, Memory, Wait Stats, Index ฯลฯ ใช้เป็น **"ภาพถ่ายเชิงลึกรายวัน/รายสัปดาห์"**: รันใน SSMS แบบ *Results to File* เก็บไฟล์รายวัน แล้วเทียบกับ spreadsheet เดิมที่แนบมากับสคริปต์ — ค่าที่ขยับคือคนร้าย

และนี่คือจุดที่ต่อกับระบบของเรา: **สองชั้นเสริมกัน ไม่ใช่แทนกัน** — snapshot job ทุก 15 นาที (Lab 10) จับ delta เชิงเวลาอัตโนมัติ ส่วนชุด Glenn Berry ให้สแนปช็อตกว้างทั้งระบบที่รวม config/hardware/version ซึ่ง snapshot ง่าย ๆ ไม่ครอบ

### 7.2 dbatools (PowerShell)

ชุดคำสั่ง open source ของชุมชน (ดูที่ [dbatools.io](https://dbatools.io/)) — สั่งผ่าน `Invoke-DbaQuery`/cmdlet สำเร็จรูปได้แก่:

| คำสั่ง | ใช้ทำอะไร |
|:--------|:-----------|
| `Get-DbaWaitStatistic` | ดึง wait stats พร้อมกรอง benign ให้ (เทียบ delta ของเราได้ทันที) |
| `Test-DbaLastBackup` | Restore ทดสอบล่าสุดจริง ๆ — เช็คว่า backup "รู้อะไร" มากกว่าดูวันที่ |
| `Invoke-DbaDbDbccCheckTable` | ความสมบูรณ์ข้อมูลรายวัน |
| `Get-DbaIoLatency` | I/O latency ต่อไฟล์ (เทียบ `M10_FileIOSnapshot`) |

หมายเหตุ: บน VM ทดสอบของหลักสูตรยังไม่ได้ติดตั้งโมดูล dbatools — ตัวอย่างเหล่านี้เขียนไว้เพื่อรันจริงตอนสอนบน VM ที่จัดเตรียม

### 7.3 สิทธิ์ของ monitoring account

หลัก least privilege: บน SQL Server 2022+ ใช้บทบาทใหม่ `##MS_ServerPerformanceStateReader##` ให้สิทธิ์อ่าน DMV ด้าน performance ทั้ง server **โดยไม่ต้องเป็น sysadmin** — ผูกให้ account ที่ใช้เก็บ baseline ทุกตัว (ตรวจบทบาท server ทั้งหมดได้ใน M0/หัวข้อ Security ของแล็บ)

### 7.4 แผนผังรวม — ระบบ baseline ที่จบสมบูรณ์

```
SQL Agent Job / Task Scheduler (ทุก 15 นาที)
        │  เรียก
        ▼
procedure เก็บ snapshot  (wait stats + file I/O + PerfMon)   ← Section 10.1
        │  INSERT
        ▼
ตาราง baseline (DBA_Baseline ในงานจริง)                     ← Lab 10
        │  delta + กรอง benign + ธง interpretation           ← Section นี้ หัวข้อ 3–4
        ▼
รายงาน/Alert (Agent + Database Mail แจ้ง fail, ธงล่วงหน้า)    ← รันจริงตอนสอนบน VM
        ▼
ตรวจสอบรายวัน: Daily Health Check + Glenn Berry + dbatools   ← Section นี้ หัวข้อ 6–7
```

---

## สรุป Section 10.2

1. **Baseline** = ภาพ "ปกติของเครื่องนี้" เก็บต่อเนื่อง (peak/off-peak) · **Benchmark** = เกณฑ์เป้าหมาย/เพดานจากการทดสอบคุมตัวแปร — ทำ baseline ก่อนเสมอ
2. โครงระบบมี 4 ชิ้น: procedure เก็บ snapshot → ตารางปลายทาง → delta + กรอง benign → ธงเตือน/รายงาน (Lab 10 ประกอบจริงด้วย SQL Agent)
3. จุดตัด "ผิดปกติ" ใช้สองชั้นคู่กัน: absolute threshold (เริ่มได้ทันที) + baseline-relative (แม่นยำเมื่อข้อมูลสะสม 2–4 สัปดาห์)
4. Benchmark คุมตัวแปร: warm-up ทิ้งผลแรก, เปลี่ยนสิ่งเดียว, เทียบด้วยเมตริกเสถียร (logical reads/CPU), วัดซ้ำหลายรอบ
5. Daily Health Check 6 result sets คือ baseline ฉบับพก — ธงสำคัญ: restart ล่าสุด, `process_*_memory_low = 1`, runnable queue ค้าง, QS ปิด, **last_backup = NULL**
6. เครื่องมือมาตรฐาน: Glenn Berry (สแนปช็อตเชิงลึกรายวัน), dbatools (automation), `##MS_ServerPerformanceStateReader##` (สิทธิ์ที่ถูกต้อง)

**ตรวจความเข้าใจ:**

1. Baseline กับ Benchmark ต่างกันอย่างไร — และเพราะอะไรถึงต้องทำ baseline ก่อน?
2. ทำไมตาราง delta ที่ไม่กรอง benign waits จึงทำให้ตัดสินใจผิด อ้างจากผลรันจริงใน section นี้ (Top ถูกครองด้วย `SOS_WORK_DISPATCHER`/`LOGMGR_QUEUE`)
3. `WRITELOG` delta +78 ครั้ง ที่ ~1 ms และ file stats +149 writes ที่ 1.16 ms — สองแหล่งยืนยันกันอย่างไร และถ้าค่าเด้งเป็น 50 ms/ครั้ง จะตรวจอะไรต่อ?
4. ใน benchmark ทำไม `logical reads` จึงน่าเชื่อถือกว่า `elapsed time` บนเครื่องที่มีคนอื่นใช้ร่วม — อ้างตัวเลขจากผลรันจริง
5. ระบบ baseline ของคุณรันมา 3 วันแล้ว — จะตั้ง "จุดตัด" แบบ baseline-relative สำหรับ avg log write latency ของช่วง 9:00–9:15 ได้อย่างไร?
6. Daily Health Check เจอ `last_backup = NULL` กับ `process_physical_memory_low = 1` พร้อมกัน — แก้อะไรก่อน เพราะอะไร?

**➡ ถัดไป:** [Module 11 — Troubleshooting Workflow](../../../Module_11_Troubleshooting/Sections/01_Troubleshooting_Workflow/README.md) — ประกอบทุกโมดูลเป็นกรอบวินิจฉัย Top-down โดยมี baseline ที่สร้างวันนี้เป็นจุดเทียบ

---

### Cleanup — ล้างของทดลองทั้งหมด (อย่าลืม!)

```sql
USE tempdb;
DROP PROCEDURE IF EXISTS dbo.M10_CaptureSnapshot;
DROP TABLE IF EXISTS dbo.M10_WaitSnapshot;
DROP TABLE IF EXISTS dbo.M10_FileIOSnapshot;
```

> ในงานจริง ตาราง baseline **ไม่ลบ** — สร้างเป็นฐานข้อมูล `DBA_Baseline` ถาวรตาม [Lab 10](../../Labs/README.md) (cleanup block ท้ายแล็บมีตัวเลือกเก็บไว้ใช้ Lab 11)

---

[⬅ Module 10](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [Module 11 — Troubleshooting](../../../Module_11_Troubleshooting/README.md)
