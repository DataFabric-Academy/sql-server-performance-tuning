# Lab 3: Pages, VLF & TempDB Internals (บทที่ 3)

> **ที่มา**: ปรับปรุงจาก Microsoft 10987C **Lab03** (tempdb files / IFI / VLF) + [Microsoft Learn — tempdb database](https://learn.microsoft.com/sql/relational-databases/databases/tempdb-database) + [Glenn Berry — SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
> รูปแบบ: **Instruction + Code block** — ทุก Step รันได้ทันทีใน SSMS

## Prerequisites

- SQL Server 2019+ (แนะนำ **2025 (17.x)**), database **AdventureWorks2025**
- Permission: `sysadmin` (จำเป็นสำหรับ `DBCC PAGE` / `DBCC TRACEON(3604)` / ALTER tempdb)
- SSMS 2 หน้าต่าง query

## Scenario

คุณสอบสวนว่าทำไมตารางที่ใช้ Random GUID เป็น clustered key ถึง insert ช้าและทำให้ transaction log บวม พร้อมกันนั้นผู้ดูแลระบบลือว่า "tempdb ตั้งค่าไม่ดีตั้งแต่ติดตั้ง" — ต้องพิสูจน์ทั้งสองเรื่องด้วยเครื่องมือ internal

## Objectives

1. ตรวจสอบโครงสร้าง Page/Extent ด้วย `DBCC PAGE` และอ่าน allocation map
2. ตรวจสอบ VLF ด้วย `sys.dm_db_log_info` (วิธีปัจจุบัน) เทียบกับ `DBCC LOGINFO`
3. จำลอง tempdb contention และปรับจำนวน tempdb data files

---

## Exercise 1: ดูโครงสร้าง Page ด้วย DBCC PAGE

### Step 1 — หา page แรกของตาราง

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): บล็อกนี้ใช้ **DBCC PAGE / DBCC TRACEON** (คำสั่ง console ระดับ engine สำหรับดูเนื้อใน page — ใช้แบบ read-only เท่านั้น) และ DMF `sys.dm_db_database_page_allocations(...)` (function ระบบที่รายงาน page ทุกหน้าของตาราง ต้องส่ง `DB_ID()` / `OBJECT_ID()` เป็น argument) — อ่านเพิ่มที่ [Glossary](../../Glossary.md)
> ⚠️ **หมายเหตุจากการรันจริง**: แบบเดิมที่ดึงคอลัมน์ `allocated_page_page_id` จาก `sys.system_internals_allocation_units` จะ error `Invalid column name` บน SQL Server 2025 (คอลัมน์นี้ไม่มีใน view นั้น) — จึงใช้ `sys.dm_db_database_page_allocations` แทน

```sql
USE AdventureWorks2025;
GO
SELECT TOP (1) allocated_page_file_id  AS file_id,
       allocated_page_page_id AS first_page,
       page_type_desc
FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('Person.Person'), 1, NULL, 'DETAILED')
WHERE is_allocated = 1 AND page_type_desc = 'DATA_PAGE'
ORDER BY allocated_page_file_id, allocated_page_page_id;
```

### Step 2 — Dump page ด้วย DBCC PAGE (ตัวเลขจาก Step 1)

```sql
DBCC TRACEON(3604);   -- ส่งผลลัพธ์ DBCC ออกทาง client
GO
DBCC PAGE('AdventureWorks2025', <file_id จาก Step 1>, <first_page จาก Step 1>, 3);  -- 3 = แสดง header + row detail
GO
```

✅ **สังเกตใน Page Header**: `m_type = 1` (Data page), `m_freeCnt` (พื้นที่ว่าง), `Metadata: ObjectId`, `AllocUnitId` — page เดียว = 8 KB เสมอ

### Step 3 — ดูจำนวน extents/pages ของตาราง (GAM/SGAM/IAM ทำงานเบื้องหลัง)

```sql
SELECT au.type_desc, au.used_pages, au.total_pages
FROM sys.system_internals_allocation_units AS au
JOIN sys.partitions AS p ON au.container_id = p.partition_id
WHERE p.object_id = OBJECT_ID('Person.Person');
```

**Expected:** Step 1 ได้ 1 แถวเป็นเลข `file_id` + `first_page` ของ DATA_PAGE แรก; Step 2 Page Header แสดง `m_type = 1` (Data page), `m_level = 0`, `Metadata: ObjectId` ตรงกับ Person.Person และ `m_freeCnt` = ไบต์ว่างคงเหลือใน page; Step 3 ได้ used_pages/total_pages ต่อ allocation unit (แถว IN_ROW_DATA แรก = clustered index ของตาราง ต่อด้วยแถวของ NC indexes)
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: first DATA_PAGE = 1:736 · Header `m_type = 1`, `m_slotCnt = 5`, `m_freeCnt = 1162`, `Metadata: ObjectId = 898102240`, โยง page เพื่อนบ้าน (1:1279) ↔ (1:737) · IN_ROW_DATA used_pages = 3,831 / total_pages = 3,893 (ตามด้วย NC indexes 110/141 และ 67/81)

---

## Exercise 2: Random GUID vs Sequential Key (ผลต่อ pages + log)

### Step 1 — สร้างตารางคู่เปรียบเทียบ

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): Exercise นี้ใช้ **DDL** (`CREATE TABLE` / `CREATE CLUSTERED INDEX`), ทริค `GO 5` (สั่ง client รัน batch นี้ซ้ำ 5 ครั้ง — ไม่ใช่ T-SQL) และใน Step 4 ใช้ **Extended Events session** + `CROSS APPLY ... .nodes()` (แตก XML เป็นแถว) — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

```sql
USE AdventureWorks2025;
GO
CREATE TABLE dbo.BadKeyTable
(
    Id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    Payload CHAR(200) NOT NULL DEFAULT 'x'
);
CREATE CLUSTERED INDEX CIX_Bad ON dbo.BadKeyTable (Id);

CREATE TABLE dbo.GoodKeyTable
(
    Id INT IDENTITY NOT NULL,
    Payload CHAR(200) NOT NULL DEFAULT 'x'
);
CREATE CLUSTERED INDEX CIX_Good ON dbo.GoodKeyTable (Id);
GO
```

### Step 2 — Insert 10,000 แถวแบบจับเวลา

```sql
SET STATISTICS TIME ON;
INSERT INTO dbo.BadKeyTable (Payload) DEFAULT VALUES;  -- รันครั้งแรก
GO 5   -- รวม ~5 batch
INSERT INTO dbo.GoodKeyTable (Payload) DEFAULT VALUES;
GO 5
SET STATISTICS TIME OFF;
GO
```

> แต่ละ statement ใส่ 1 แถว; `GO 5` รันซ้ำ 5 ครั้ง — ใช้ได้กับ default 1 แถว เพื่อความเร็วของแล็บ ผู้สอนอาจสาธิตด้วยลูป 10,000 แถวในสคริปต์ `Labs/../../Sections/01_Structure_Internals/Scripts/01_Bad_vs_Good_Structure.sql`

### Step 3 — เทียบ fragmentation และ page count

```sql
SELECT OBJECT_NAME(object_id) AS table_name,
       index_type_desc,
       avg_fragmentation_in_percent,
       page_count,
       fragment_count,
       avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'DETAILED')
WHERE object_id IN (OBJECT_ID('dbo.BadKeyTable'), OBJECT_ID('dbo.GoodKeyTable'));
```

✅ **สังเกต**: เทียบทั้ง 3 ค่า (`avg_fragmentation_in_percent` / `page_count` / `avg_page_space_used_in_percent`) ระหว่างสองตาราง — ผลที่ควรเห็นและเหตุผลสรุปอยู่ที่ **Expected:** ท้าย Exercise นี้

### Step 4 — จับ page split แบบ real-time ด้วย Extended Events (เชื่อมกับบทที่ 9)

```sql
CREATE EVENT SESSION [XE_PageSplits] ON SERVER
ADD EVENT sqlserver.page_split
(
    WHERE ( database_id = DB_ID('AdventureWorks2025') )
)
ADD TARGET package0.ring_buffer ( SET max_memory = 4096 )
WITH ( MAX_DISPATCH_LATENCY = 5 SECONDS, STARTUP_STATE = OFF );
GO
ALTER EVENT SESSION [XE_PageSplits] ON SERVER STATE = START;
GO
-- รัน INSERT ลง BadKeyTable อีกชุด แล้ว...
```

```sql
SELECT
    x.value('(event/data[@name="file_id"]/value)[1]', 'INT')  AS file_id,
    x.value('(event/data[@name="page_id"]/value)[1]', 'INT')  AS page_id,
    x.value('(event/@timestamp)[1]', 'DATETIME2')             AS split_at
FROM ( SELECT CAST(target_data AS XML) AS buf
       FROM sys.dm_xe_session_targets AS t
       JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
       WHERE s.name = 'XE_PageSplits' AND t.target_name = 'ring_buffer' ) AS d
CROSS APPLY buf.nodes('//event') AS n(x);
```

### Step 5 — ปิด session เมื่อจบ

```sql
ALTER EVENT SESSION [XE_PageSplits] ON SERVER STATE = STOP;
DROP EVENT SESSION [XE_PageSplits] ON SERVER;
```

**Expected:** Step 3 แสดง `BadKeyTable` fragmentation สูงเกือบ 99%, `avg_page_space_used_in_percent` ต่ำ, page_count บวมกว่า `GoodKeyTable` ชัดเจน — เพราะ GUID สุ่มตำแหน่ง insert ทำให้เกิด page split ตลอดเวลา / `GoodKeyTable` fragment < 1–2% · Step 4 ระหว่าง XE session เปิดอยู่ การ INSERT ลง BadKeyTable จะถูกจับเป็น event `page_split` ทยอยเข้า ring buffer (ดึงด้วย query ด้านบน) — หมายเหตุ: `GO 5` (รวม 5 แถว) ยังเล็กเกินกว่าจะเกิด split ให้เห็น ทั้งสองตารางยังอยู่ 1 page ให้สาธิตรูปแบบเต็มด้วยลูปหลายพันแถวตามสคริปต์ `Sections/01_Structure_Internals/Scripts/01_Bad_vs_Good_Structure.sql`
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: ตามไฟล์ `GO 5` จริงได้ทั้งสองตาราง 1 page, frag 0% (เล็กเกิน) · insert ทีละแถว 3,000 แถว → BadKeyTable frag **98.5%** (132 pages, 132 fragments, space_used 67.1%) เทียบ GoodKeyTable frag **1.2%** (86 pages, 12 fragments, space_used 97.8%) · (ส่วน XE `page_split` ใน Step 4 ไม่ได้รันระหว่างการตรวจนี้เพราะ VM ทดสอบใช้ XE session ร่วมกัน — ผู้เรียนจะเห็นเองเมื่อรัน Step 4)

---

## Exercise 3: VLF — Transaction Log Internals

### Step 1 — ดู VLF ด้วย DMV ปัจจุบัน (SQL Server 2016 SP2+)

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): `sys.dm_db_log_info(NULL)` เป็น **TVF ระดับ instance** (ส่ง `NULL` = ดึงทุก database) และ Step 2-3 ใช้ **DDL** `ALTER DATABASE ... MODIFY FILE` (เปลี่ยนค่าไฟล์ log — ทำได้เฉพาะเครื่องทดสอบของผู้เรียนเอง ห้ามบน production) — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

```sql
SELECT DB_NAME(lg.database_id) AS database_name,
       mf.name AS logical_name,
       lg.file_id, lg.vlf_size_mb, lg.vlf_active, lg.vlf_status
FROM sys.dm_db_log_info(NULL) AS lg
JOIN sys.master_files AS mf
    ON lg.database_id = mf.database_id AND lg.file_id = mf.file_id
ORDER BY database_name, file_id, vlf_sequence_number;
```

### Step 2 — ทำให้ VLF ระเบิดด้วย autogrowth ทีละน้อย (VM ทดสอบเท่านั้น)

```sql
USE master;
GO
ALTER DATABASE AdventureWorks2025
MODIFY FILE (NAME = AdventureWorks2025_log, SIZE = 64 MB, FILEGROWTH = 1 MB);  -- จงใจให้โตทีละ 1 MB
GO
-- สร้าง log growth หลายรอบ
USE AdventureWorks2025;
CREATE TABLE dbo.LogBloat (Col1 CHAR(4000));
INSERT dbo.LogBloat VALUES ('a'), ('b'), ('c');  -- แล้วทำ transaction เขียน log หลายรอบ
GO
-- ตรวจซ้ำ Step 1 แล้วเทียบจำนวน VLF
```

### Step 3 — แก้กลับสู่ค่าที่ดี (growth เป็น MB ไม่ใช่ PERCENT)

```sql
USE master;
GO
ALTER DATABASE AdventureWorks2025
MODIFY FILE (NAME = AdventureWorks2025_log, FILEGROWTH = 256 MB);
GO
```

**Expected:** Step 1 เห็นแถวต่อ VLF เรียงตาม sequence — log ที่ตั้งค่าดีมี VLF ไม่กี่สิบก้อน ขนาดค่อนข้างเท่ากัน; หลัง grow ทีละ 1 MB หลายครั้ง (Step 2) จำนวน VLF เพิ่มขึ้นเป็นก้อนเล็กจำนวนมาก; Step 3 แก้ FILEGROWTH เป็น 256 MB แล้ว growth ครั้งถัดไปจะสร้าง VLF ใหญ่น้อยก้อน (VLF เดิมไม่หาย — รีเซ็ตจริงต้อง SHRINKFILE + grow ใหม่ตามหมายเหตุด้านล่าง)
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: AdventureWorks_log = **6 VLFs** รวม ~136 MB (active 1) — เห็น VLF ขนาดปนกัน 64 MB กับ ~1.9–2.2 MB ซึ่งเป็นร่องรอย autogrowth ขนาดเล็กจากอดีต · tempdb = 4 VLFs, master = 8 VLFs · (Step 2-3 เป็น ALTER DATABASE จึงไม่ได้รันบน VM ใช้ร่วม — ให้ผู้เรียนทำบนเครื่องทดสอบของตนเอง)

> **หมายเหตุ**: การลด VLF จริงจังทำผ่าน `DBCC SHRINKFILE(log, ...)` + grow ครั้งเดียวใหญ่ ๆ — อย่าทำบน production ระหว่างชั่วโมงทำงาน

---

## Exercise 4: TempDB — ตรวจค่า + จำลอง Contention + แก้

### Step 1 — ตรวจการตั้งค่า tempdb ปัจจุบัน

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): Step 2 ใช้ **temp table** (`#t` = ตารางชั่วคราวเฉพาะ session ที่อยู่ใน tempdb สร้าง/ลบด้วย CREATE/DROP TABLE) + **WHILE** loop (T-SQL แบบวนลูป ไม่ใช่ set-based) และ Step 4 ใช้ **DDL** `ALTER DATABASE tempdb ADD FILE` — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

```sql
SELECT name, size * 8 / 1024 AS size_mb,
       growth, is_percent_growth, physical_name
FROM tempdb.sys.database_files
ORDER BY file_id;
```

✅ **เกณฑ์**: หลาย data file ขนาดเท่ากัน + growth เป็น MB เท่ากัน (เริ่ม #files ≈ logical cores แต่ ≤ 8)

### Step 2 — จำลอง tempdb latch contention (สร้าง temp table ถี่ ๆ จากหลาย session)

```sql
-- รันพร้อมกันหลายหน้าต่าง (4–8 windows)
USE tempdb;
GO
DECLARE @i INT = 0;
WHILE @i < 20000
BEGIN
    CREATE TABLE #t (Id INT IDENTITY, Col CHAR(100) DEFAULT 'x');
    INSERT #t DEFAULT VALUES;
    SELECT @i = @i + 1;
    DROP TABLE #t;
END
```

### Step 3 — ดู wait ที่เกิดขึ้น (มองหา PAGELATCH บน tempdb)

```sql
SELECT wait_type, waiting_tasks_count, wait_time_ms, max_wait_time_ms
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'PAGE%LATCH%' OR wait_type = 'PAGELATCH_EX'
ORDER BY wait_time_ms DESC;

-- ดู allocation contention ระดับ page ของ tempdb แบบสด
SELECT r.session_id, r.wait_type, r.wait_resource, r.wait_time
FROM sys.dm_exec_requests AS r
WHERE r.wait_type LIKE 'PAGE%LATCH%' AND r.wait_resource LIKE '2:%';  -- dbid 2 = tempdb
```

### Step 4 — แก้โดยเพิ่ม tempdb data files (ขนาดเท่ากันทุกไฟล์)

```sql
USE master;
GO
-- ตัวอย่างเพิ่มเป็น 4 ไฟล์ (ปรับ path/ขนาดตามเครื่อง)
ALTER DATABASE tempdb ADD FILE
( NAME = tempdev2, FILENAME = 'D:\SQLData\tempdb2.ndf', SIZE = 512 MB, FILEGROWTH = 256 MB ),
( NAME = tempdev3, FILENAME = 'D:\SQLData\tempdb3.ndf', SIZE = 512 MB, FILEGROWTH = 256 MB ),
( NAME = tempdev4, FILENAME = 'D:\SQLData\tempdb4.ndf', SIZE = 512 MB, FILEGROWTH = 256 MB );
GO
```

> **SQL Server 2025**: พิจารณาเปิด **ADR ใน tempdb** (`ALTER DATABASE tempdb SET ACCELERATED_DATABASE_RECOVERY = ON;` แล้ว restart engine) เพื่อ rollback temp transaction แบบทันที — และใช้ **tempdb space governance** กับ Resource Governor ป้องกัน workload กินพื้นที่ทั้ง instance

### Step 5 (Optional) — ตรวจ Instant File Initialization

```sql
-- ถ้าไฟล์ grow ทันที (ไม่มี delay จากการ zero-out) = IFI ทำงาน
-- ตรวจสิทธิ์ของ service account ใน Local Security Policy:
-- "Perform volume maintenance tasks"
SELECT servicename, service_account
FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server (%)';
```

**Expected:** Step 1 เห็น tempdb data files หลายไฟล์ขนาดเท่ากัน growth เป็น MB (`is_percent_growth = 0`) · Step 2-3 ระหว่าง loop ให้ poll `sys.dm_exec_requests` — contention จริงจะเห็น `PAGELATCH_EX` บน `wait_resource` ขึ้นต้น `2:` (dbid 2 = tempdb) ซึ่งต้องรัน 4-8 หน้าต่างพร้อมกันตามที่ระบุ (1 หน้าต่างเดียวไม่เกิด contention ให้เห็น) และค่าใน `sys.dm_os_wait_stats` เป็นยอดสะสมทั้ง instance ให้ดูเฉลี่ยต่อครั้ง (`wait_time_ms ÷ waiting_tasks_count`) ไม่ใช่ยอดรวม · Step 5 service account ปกติ = `NT Service\MSSQLSERVER`
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: tempdb ตั้งมาถูกต้องแล้ว = 4 data files × 72 MB, growth 64 MB, `is_percent_growth = 0` (log 8 MB growth 64 MB) · loop 20,000 รอบ (1 หน้าต่าง) จบใน < 1 นาที และ polling 45 วินาทีไม่เจอ PAGE%LATCH บน `2:%` เลย (single session ไม่พอ — PAGELATCH_EX สะสมทั้ง instance 40,456 ครั้ง/590 ms ≈ 0.01 ms ต่อครั้ง = ระดับ background ปกติ) · service account = `NT Service\MSSQLSERVER` · (Step 4 ADD FILE ไม่ได้รันบน VM ใช้ร่วม)

---

## Wrap-up: คำถามท้ายแล็บ

1. เพราะอะไร Random GUID ทำให้ log โตเร็ว? (page split ต่อ insert + เขียน log เพิ่ม)
2. VLF เยอะผิดปกติกระทบอะไร? (startup/recovery/restore/AG seed ช้า)
3. tempdb ของเครื่องคุณมี data files กี่ไฟล์ ขนาดเท่ากันหรือไม่ growth ตั้งเป็นอะไร?

## Cleanup

```sql
USE AdventureWorks2025;
DROP TABLE IF EXISTS dbo.BadKeyTable, dbo.GoodKeyTable, dbo.LogBloat;
```

## แหล่งอ้างอิง

- 10987C Lab03 — `Trainer_Docs/10987/Labfiles/Lab03/`
- Microsoft Learn: [tempdb database](https://learn.microsoft.com/sql/relational-databases/databases/tempdb-database) · [sys.dm_db_log_info](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-db-log-info-transact-sql) · [ADR in tempdb (2025)](https://learn.microsoft.com/sql/relational-databases/accelerated-database-recovery-concepts)
- Glenn Berry: [SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
- สคริปต์ของแล็บนี้อยู่ใน `Sections/*/Scripts/` ของโมดูล จัดตามหัวข้อที่เกี่ยวข้อง (ลิงก์ในแต่ละ Exercise)
