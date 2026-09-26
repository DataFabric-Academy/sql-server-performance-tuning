# Lab 4: Memory Pressure & Buffer Pool Analysis (บทที่ 4)

> **ที่มา**: ปรับปรุงจาก Microsoft 10987C **Lab04** (Monitor Memory) + [Microsoft Learn — Memory Management Architecture](https://learn.microsoft.com/sql/relational-databases/memory-management-architecture-guide) + [Glenn Berry — SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
> รูปแบบ: **Instruction + Code block** — ทุก Step รันได้ทันทีใน SSMS

## Prerequisites

- SQL Server 2019+ (แนะนำ **2025 (17.x)**), database **AdventureWorks2025**
- Permission: `VIEW SERVER STATE`
- SSMS 2 หน้าต่าง query

## Scenario

Report query หนึ่งช้าลงและมี Warning ใน execution plan ขณะเดียวกันผู้ใช้บ่นว่าระบบทั้งเครื่อง "จำอะไรไม่ค่อยได้" (cache hit ratio ตก) คุณต้องแยกแยะว่าปัญหาอยู่ที่ **memory pressure**, **memory spill**, หรือการตั้งค่า max server memory

## Objectives

1. ตรวจสุขภาพ memory ของ OS และ SQL Server
2. วิเคราะห์ buffer pool ต่อ database และ memory clerks
3. จำลอง memory spill และสังเกต Memory Grant Feedback

---

## Exercise 1: สุขภาพ Memory ภาพรวม

### Step 1 — ตรวจ memory ฝั่ง OS

```sql
SELECT total_physical_memory_kb / 1048576.0 AS total_ram_gb,
       available_physical_memory_kb / 1048576.0 AS available_ram_gb,
       system_memory_state_desc      -- AVAILABLE = ปกติ
FROM sys.dm_os_sys_memory;
```

### Step 2 — ตรวจการจัดสรร memory ของ SQL Server

```sql
SELECT physical_memory_in_use_kb / 1048576.0 AS sql_in_use_gb,
       locked_page_allocations_kb / 1048576.0 AS locked_pages_gb,
       memory_utilization_percentage AS mem_util_pct,   -- ควร > 90
       process_physical_memory_low AS os_pressure_low,   -- ต้องเป็น 0
       process_virtual_memory_low AS vmem_pressure_low
FROM sys.dm_os_process_memory;
```

### Step 3 — Memory clerks ตัวการหลัก

```sql
SELECT TOP (10) type,
       pages_kb / 1024.0 AS pages_mb,
       virtual_memory_reserved_kb / 1048576.0 AS vm_reserved_gb,
       virtual_memory_committed_kb / 1048576.0 AS vm_committed_gb
FROM sys.dm_os_memory_clerks
ORDER BY pages_kb DESC;
```

✅ **สังเกต**: `MEMORYCLERK_SQLBUFFERPOOL` ควรเป็นขาใหญ่ที่สุด — ถ้า clerk อื่น (เช่น `MEMORYCLERK_SQLQUERYEXEC`, `OBJECTSTORE_LOCK_MANAGER`) บวมผิดปกติ ให้ตามต่อ

---

## Exercise 2: Buffer Pool ต่อ Database (ใครกิน cache มากสุด)

### Step 1 — นับ cached pages ต่อ database

```sql
SELECT CASE database_id WHEN 32767 THEN 'RESOURCE DB' ELSE DB_NAME(database_id) END AS database_name,
       COUNT_BIG(*) AS cached_pages,
       COUNT_BIG(*) * 8 / 1024.0 AS cached_mb
FROM sys.dm_os_buffer_descriptors
GROUP BY database_id
ORDER BY cached_pages DESC;
```

### Step 2 — ดู object ที่ cache หนักสุดใน AdventureWorks

```sql
USE AdventureWorks2025;
GO
SELECT TOP (15) OBJECT_NAME(p.object_id) AS object_name,
       COUNT_BIG(*) AS cached_pages,
       COUNT_BIG(*) * 8 / 1024.0 AS cached_mb
FROM sys.dm_os_buffer_descriptors AS bd
JOIN sys.allocation_units AS au
    ON bd.allocation_unit_id = au.allocation_unit_id
JOIN sys.partitions AS p
    ON au.container_id = p.partition_id
WHERE bd.database_id = DB_ID()
GROUP BY p.object_id
ORDER BY cached_pages DESC;
```

### Step 3 — PLE แบบต่อ NUMA node (วิธีอ่านที่ถูกต้อง)

```sql
SELECT instance_name AS numa_node, cntr_value AS page_life_expectancy_sec
FROM sys.dm_os_performance_counters
WHERE object_name LIKE '%Buffer Node%'
  AND counter_name = 'Page life expectancy';
```

✅ **เตือน**: อย่าใช้ PLE 300 วินาทีเป็นสายฟ้าแลบ — บนเครื่อง RAM หลายสิบ GB ค่าปกติอาจหลักหมื่นวินาที ให้ดู **trend ตกฮวบ** เทียบ baseline (Lab 10)

---

## Exercise 3: จำลอง Memory Spill + Memory Grant Feedback

### Step 1 — บังคับ sort ที่ต้อง spill ลง tempdb

```sql
USE AdventureWorks2025;
GO
-- เปิด Ctrl+M (Include Actual Execution Plan) ก่อนรัน
SELECT CarrierTrackingNumber, CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS NVARCHAR(MAX)) AS big_text
FROM Sales.SalesOrderDetail
ORDER BY big_text DESC;
```

✅ **สังเกต**: Warning สีเหลืองที่ Sort operator — "Operator used tempdb to spill data during execution" = memory grant ไม่พอ

### Step 2 — รันซ้ำและดู Memory Grant Feedback ทำงาน

```sql
-- รันคำสั่งเดิมอีก 1–2 ครั้ง แล้วเช็ค grant ที่ปรับตัว
SELECT qst.query_id, qsp.plan_id,
       qsp.is_memory_grant_feedback_adjusted,   -- 1 = feedback แก้ grant ให้แล้ว (2017+/2022 persisted)
       qsp.is_parallel_plan
FROM sys.query_store_plan AS qsp
JOIN sys.query_store_query AS qst ON qsp.query_id = qst.query_id
JOIN sys.query_store_query_text AS qt ON qst.query_text_id = qt.query_text_id
WHERE qt.query_sql_text LIKE '%big_text%';
```

✅ **สังเกต**: `is_memory_grant_feedback_adjusted = 1` — engine เรียนรู้จาก spill รอบก่อนและปรับ grant ให้เอง (คุณสมบัติ IQP ตระกูล Memory Grant Feedback)

### Step 3 — ดู resource semaphore (คิวรอ memory grant)

```sql
SELECT resource_semaphore_id, total_granted_kb, total_used_kb,
       total_grantee_count, total_waiter_count,   -- waiter > 0 = มี query รอ grant (RESOURCE_SEMAPHORE)
       timeout_error_count, forced_grant_count
FROM sys.dm_exec_query_resource_semaphores;

SELECT session_id, requested_memory_kb, granted_memory_kb,
       required_memory_kb, used_memory_kb, wait_time_ms
FROM sys.dm_exec_query_memory_grants;
```

---

## Exercise 4 (Optional): In-Memory OLTP สั้น ๆ

### Step 1 — สร้าง memory-optimized table (ต้องมี filegroup)

```sql
USE AdventureWorks2025;
GO
IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE type = 'FX')
    ALTER DATABASE CURRENT ADD FILEGROUP AdventureWorks2025_mod
    CONTAINS MEMORY_OPTIMIZED_DATA;
GO
CREATE TABLE dbo.MO_Sessions
(
    SessionId  UNIQUEIDENTIFIER NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 100000),
    CreatedAt  DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    Payload    NVARCHAR(256) NOT NULL
) WITH ( MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_ONLY );
GO
```

### Step 2 — วัดผล insert ความเร็วสูง

```sql
DECLARE @t DATETIME2 = SYSUTCDATETIME(), @i INT = 0;
WHILE @i < 10000
BEGIN
    INSERT dbo.MO_Sessions (SessionId, Payload)
    VALUES (NEWID(), N'session-' + CAST(@i AS NVARCHAR(10)));
    SET @i += 1;
END
SELECT DATEDIFF(MILLISECOND, @t, SYSUTCDATETIME()) AS insert_10k_ms;
```

> **SQL Server 2025**: ถ้าเลิกใช้ Hekaton สามารถลบ memory-optimized filegroup ที่ว่างออกได้แล้ว (ฟีเจอร์ใหม่ใน 2025)

---

## Wrap-up: คำถามท้ายแล็บ

1. PLE ต่อ NUMA node ของเครื่องคุณเท่าไร และควรใช้เกณฑ์แบบไหนตัดสิน memory pressure?
2. Memory spill เกิดตอนไหน และ Memory Grant Feedback ช่วยได้อย่างไร?
3. ถ้า `total_waiter_count > 0` ที่ resource semaphore บ่งบอกปัญหาอะไร และ wait type ที่เกี่ยวข้องคืออะไร? (`RESOURCE_SEMAPHORE`)

## Cleanup

```sql
USE AdventureWorks2025;
DROP TABLE IF EXISTS dbo.MO_Sessions;
```

## แหล่งอ้างอิง

- 10987C Lab04 — `Trainer_Docs/10987/Labfiles/Lab04/`
- Microsoft Learn: [sys.dm_os_buffer_descriptors](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-os-buffer-descriptors-transact-sql) · [Memory Grant Feedback](https://learn.microsoft.com/sql/relational-databases/performance/intelligent-query-processing-memory-grant-feedback)
- Glenn Berry: [SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
- สคริปต์เสริมในโมดูล: `Scripts/01_Buffer_Usage_By_DB.sql`, `Scripts/03_Memory_Clerks.sql`
