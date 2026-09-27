# Lab 6: Missing/Unused Index, Covering Index & Statistics (บทที่ 6)

> **ที่มา**: ปรับปรุงจาก Microsoft 10987C **Lab06** (Indexes/Statistics) + [Microsoft Learn — Missing index DMVs](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-db-missing-index-details-transact-sql) + [Glenn Berry — SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/) (หมวด Index & Statistics)
> รูปแบบ: **Instruction + Code block** — ทุก Step รันได้ทันทีใน SSMS

## Prerequisites

- SQL Server 2019+ (แนะนำ **2025 (17.x)**), database **AdventureWorks2025**
- Permission: `VIEW DATABASE STATE`, สิทธิ์ CREATE/DROP INDEX บน DB ทดสอบ

## Scenario

Report ค้นหาลูกค้าช้ามาก ทั้งที่กรองเพียงบางส่วน คุณสงสัยว่าขาด index ที่เหมาะสม มี Key Lookup ที่แพง และ statistics เก่าจน optimizer ตัดสินใจผิด

## Objectives

1. ระบุ Missing Index จาก execution plan และ DMV
2. สร้าง Covering Index เพื่อกำจัด Key Lookup และวัดผลก่อน-หลัง
3. วิเคราะห์ unused/duplicate index ก่อนตัดสินใจ DROP
4. ตรวจ stale statistics และอัปเดตอย่างถูกวิธี

---

## Exercise 1: Missing Index → Covering Index

### Step 1 — หา query ที่ไม่มี index รองรับ (เปิด Ctrl+M ก่อนรัน)

```sql
USE AdventureWorks2025;
GO
SET STATISTICS IO, TIME ON;
SELECT BusinessEntityID, FirstName, LastName, EmailAddress
FROM Person.Person AS p
JOIN Person.EmailAddress AS e ON e.BusinessEntityID = p.BusinessEntityID
WHERE p.LastName = N'Anderson'
  AND p.FirstName LIKE N'%K%';
```

✅ **สังเกต**: plan เป็น Index Scan/Clustered Scan และ SSMS ขึ้น **Missing Index (Impact ~99%)** — สังเกตว่า Green text แนะนำ CREATE INDEX ให้ทันที (ยังไม่ต้องเชื่อ 100%)

### Step 2 — ดูคำแนะนำสะสมจาก DMV

```sql
SELECT id.statement AS target_table,
       id.equality_columns,
       id.inequality_columns,
       id.included_columns,
       gs.user_seeks, gs.user_scans,
       gs.avg_total_user_cost * gs.avg_user_impact * (gs.user_seeks + gs.user_scans) AS benefit_score
FROM sys.dm_db_missing_index_details AS id
JOIN sys.dm_db_missing_index_groups AS g ON id.index_handle = g.index_handle
JOIN sys.dm_db_missing_index_group_stats AS gs ON g.index_group_handle = gs.group_handle
ORDER BY benefit_score DESC;
```

### Step 3 — วัด Baseline ที่ยังไม่มี index (บันทึก logical reads)

```sql
SET STATISTICS IO ON;
SELECT * FROM Person.Person WHERE LastName = N'Anderson';
-- จดค่า logical reads จากแท็บ Messages
SET STATISTICS IO OFF;
```

### Step 4 — สร้าง Covering Index (key + INCLUDE)

```sql
CREATE NONCLUSTERED INDEX IX_Person_LastName_FirstName_cover
ON Person.Person (LastName, FirstName)
INCLUDE (BusinessEntityID);
```

### Step 5 — รัน query เดิมซ้ำแล้วเทียบ

```sql
SET STATISTICS IO ON;
SELECT * FROM Person.Person WHERE LastName = N'Anderson';
SET STATISTICS IO OFF;
```

✅ **ผลที่คาดหวัง**: plan เปลี่ยนเป็น **Index Seek** ไม่มี Key Lookup, logical reads ลดลงหลายเท่าถึงสิบเท่า

> **ระวัง**: ถ้า query ดึงหลายพันแถว Key Lookup แบบเก่าอาจแพงกว่า scan — ตัดสินจากผลจริงเสมอ

---

## Exercise 2: Unused / Duplicate Index วิเคราะห์ก่อนทิ้ง

### Step 1 — รวมสถิติอ่าน vs เขียนต่อ index (สไตล์ Glenn Berry)

```sql
SELECT OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
       OBJECT_NAME(i.object_id) AS table_name,
       i.name AS index_name,
       i.type_desc,
       COALESCE(us.user_seeks, 0) + COALESCE(us.user_scans, 0)
           + COALESCE(us.user_lookups, 0) AS total_reads,
       COALESCE(us.user_updates, 0) AS total_writes,
       us.last_user_seek, us.last_user_update
FROM sys.indexes AS i
LEFT JOIN sys.dm_db_index_usage_stats AS us
    ON i.object_id = us.object_id AND i.index_id = us.index_id
    AND us.database_id = DB_ID()
WHERE i.index_id > 1          -- ข้าม heap/clustered
  AND OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
ORDER BY total_reads ASC, total_writes DESC;
```

✅ **เกณฑ์ตัดสินใจ**: `total_reads = 0` แต่ `total_writes` สูง → ผู้สมัครถูก DROP (ยืนยันว่าไม่ใช่ PK/Unique constraint และไม่ใช่ index ที่ batch รายเดือนใช้ — ต้องมี baseline ยาว ≥ 1 business cycle)

### Step 2 — หา duplicate index (Column key ซ้ำกัน)

```sql
SELECT OBJECT_SCHEMA_NAME(object_id) + '.' + OBJECT_NAME(object_id) AS table_name,
       name AS index_name,
       (SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
        FROM sys.index_columns AS ic
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0) AS key_cols,
       (SELECT STRING_AGG(c.name, ',')
        FROM sys.index_columns AS ic
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1) AS include_cols
FROM sys.indexes AS i
WHERE index_id > 1 AND OBJECTPROPERTY(object_id, 'IsUserTable') = 1
ORDER BY table_name, key_cols;
```

### Step 3 (Optional) — หา fragmentation ที่ควรจัดการ

```sql
SELECT OBJECT_NAME(ps.object_id) AS table_name,
       i.name AS index_name,
       ps.avg_fragmentation_in_percent,
       ps.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ps
JOIN sys.indexes AS i ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE ps.avg_fragmentation_in_percent > 30 AND ps.page_count > 1000
ORDER BY ps.avg_fragmentation_in_percent DESC;
-- > 30% + ใหญ่พอ → REBUILD; 5-30% → REORGANIZE; < 5% ปล่อยไว้
```

---

## Exercise 3: Stale Statistics

### Step 1 — หา statistics ที่เก่าและเปลี่ยนแปลงเยอะ (Glenn Berry)

```sql
SELECT OBJECT_SCHEMA_NAME(s.object_id) AS schema_name,
       OBJECT_NAME(s.object_id) AS table_name,
       s.name AS stats_name,
       sp.last_updated,
       sp.rows, sp.modification_counter,
       CAST(100.0 * sp.modification_counter / NULLIF(sp.rows, 0) AS DECIMAL(10,2)) AS pct_changed
FROM sys.stats AS s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
  AND sp.modification_counter > 0
ORDER BY pct_changed DESC;
```

✅ **เกณฑ์พอสมควร**: `pct_changed > 20%` และ `last_updated` นาน → ควรอัปเดต (ตั้งแต่ SQL Server 2016+ threshold dynamic อยู่แล้วสำหรับ DB compat 130+ แต่บาง workload ยังต้องจัดการเอง)

### Step 2 — สร้าง data skew แล้วทดสอบผลของ stale stats

```sql
USE AdventureWorks2025;
GO
-- จำลอง: เพิ่มแถวจำนวนมากโดยไม่อัปเดต stats
CREATE TABLE dbo.StatsTest (Col1 INT IDENTITY, Status TINYINT DEFAULT 0, Pad CHAR(50) DEFAULT 'x');
INSERT dbo.StatsTest (Status) VALUES (0);      -- seed row
GO 100
CREATE INDEX IX_StatsTest_Status ON dbo.StatsTest (Status);
INSERT dbo.StatsTest (Status)
SELECT TOP (50000) 1 FROM sys.all_objects a CROSS JOIN sys.all_columns b;
GO
```

### Step 3 — เทียบ estimated rows ก่อน/หลัง UPDATE STATISTICS

```sql
-- ก่อน: สังเกต estimated row count ที่คลาดเคลื่อน (Ctrl+M)
SELECT COUNT(*) FROM dbo.StatsTest WHERE Status = 1;

UPDATE STATISTICS dbo.StatsTest IX_StatsTest_Status WITH FULLSCAN;

-- หลัง: estimated ตรงกับ actual
SELECT COUNT(*) FROM dbo.StatsTest WHERE Status = 1;
```

---

## Exercise 4 (Optional, SQL Server 2025): CE Feedback for Expressions

```sql
-- ตรวจว่า IQP features ทำงานอยู่หรือไม่ (compat level 170)
SELECT name, compatibility_level, is_query_store_on
FROM sys.databases WHERE database_id = DB_ID();
ALTER DATABASE AdventureWorks2025 SET COMPATIBILITY_LEVEL = 170;  -- SQL Server 2025
-- CE feedback for expressions จะเรียนรู้ CE ของ expression เช่น DATEDIFF/CONVERT จากการรันจริง
-- ดู XEvent ที่เกี่ยวข้อง: query_optimizer_estimate_cardinality / CE feedback events
```

---

## Wrap-up: คำถามท้ายแล็บ

1. Missing Index DMV แนะนำ index ใด และคุณปรับปรุงคำแนะนำนั้นอย่างไรก่อนใช้จริง? (จัด key/include ตาม query ที่มีอยู่จริง ตรวจซ้ำซ้อน)
2. index ใดของ database นี้ "จ่ายแรมรับความว่างเปล่า"? (reads = 0, writes สูง)
3. เพราะอะไร stale statistics ทำให้ optimizer เลือก plan ที่แย่? (CE อ่าน histogram เก่า ประเมิน rows ผิด → เลือก join/lookup ผิด)

## Cleanup

```sql
USE AdventureWorks2025;
DROP INDEX IF EXISTS IX_Person_LastName_FirstName_cover ON Person.Person;
DROP TABLE IF EXISTS dbo.StatsTest;
```

## แหล่งอ้างอิง

- 10987C Lab06 — `Trainer_Docs/10987/Labfiles/Lab06/`
- Microsoft Learn: [Missing index DMVs](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-db-missing-index-details-transact-sql) · [Columnstore what's new (2025)](https://learn.microsoft.com/sql/relational-databases/indexes/columnstore-indexes-what-s-new) · [Persisted stats on secondaries (2025)](https://learn.microsoft.com/sql/relational-databases/performance/persisted-stats-secondary-replicas)
- Glenn Berry: [SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
- สคริปต์ของแล็บนี้อยู่ใน `Sections/*/Scripts/` ของโมดูล จัดตามหัวข้อที่เกี่ยวข้อง (ลิงก์ในแต่ละ Exercise)
