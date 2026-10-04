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

> ⚠️ **แก้จากต้นฉบับจากการรันจริง**: (1) `BusinessEntityID` ต้องระบุ alias (`p.` / `e.`) ไม่งั้น error `Ambiguous column name 'BusinessEntityID'`; (2) filter ต้นฉบับ `LastName = N'Anderson'` ถูก cover โดย `IX_Person_LastName_FirstName_MiddleName` ที่มีมากับ AdventureWorks ตั้งแต่ติดตั้ง ทำให้ plan เป็น Index Seek และ**ไม่ขึ้น** Missing Index เลย — จึงเปลี่ยนเป็น `MiddleName = N'J.'` (คอลัมน์ที่ไม่มี index จริง) ตามแนวทางเดียวกับ `Sections/02_Index_Internals/Scripts/01_Missing_Index.sql`

```sql
USE AdventureWorks2025;
GO
SET STATISTICS IO, TIME ON;
SELECT p.BusinessEntityID, p.FirstName, p.LastName, e.EmailAddress
FROM Person.Person AS p
JOIN Person.EmailAddress AS e ON e.BusinessEntityID = p.BusinessEntityID
WHERE p.MiddleName = N'J.';
```

✅ **สังเกต**: plan เป็น Index Scan (บนเครื่องทดสอบ: scan ของ `IX_Person_LastName_FirstName_MiddleName` — optimizer เลือก NC index ที่แคบที่สุดที่พา `MiddleName` ได้ เพราะถูกกว่า scan clustered ทั้งตาราง) และ SSMS ขึ้น **Missing Index (Impact ~92.5%)** — Green text แนะนำ `CREATE INDEX ... (MiddleName) INCLUDE (FirstName, LastName)` ให้ทันที (ยังไม่ต้องเชื่อ 100%)

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

> **หมายเหตุ**: probe เจาะจง 3 คอลัมน์ที่ covering index ใน Step 4 จะ cover ได้ครบ — ถ้าใช้ `SELECT *` จะยังต้อง Key Lookup ทุกแถวอยู่ (ตารางมีคอลัมน์อื่นอีกมาก เช่น XML) และจะไม่เห็นผลลดตามทฤษฎี

```sql
SET STATISTICS IO ON;
SELECT BusinessEntityID, FirstName, LastName FROM Person.Person WHERE MiddleName = N'J.';
-- จดค่า logical reads จากแท็บ Messages
SET STATISTICS IO OFF;
```

### Step 4 — สร้าง Covering Index (key + INCLUDE)

```sql
CREATE NONCLUSTERED INDEX IX_Person_MiddleName_cover
ON Person.Person (MiddleName)
INCLUDE (FirstName, LastName);
```

### Step 5 — รัน query เดิมซ้ำแล้วเทียบ

```sql
SET STATISTICS IO ON;
SELECT BusinessEntityID, FirstName, LastName FROM Person.Person WHERE MiddleName = N'J.';
SET STATISTICS IO OFF;
```

**Expected:** ก่อนสร้าง index แผนเป็น Index Scan กิน logical reads หลักร้อย; หลังสร้าง covering index แผนเปลี่ยนเป็น **Index Seek** ไม่มี Key Lookup และ logical reads ลดลงเหลือหลักหน่วย (ราว 20–30 เท่า) — Missing Index hint หายไปจากแผน
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: ก่อน 106 reads (Index Scan + residual, 132 แถว, Missing Index Impact 92.52 แนะนำ (MiddleName) INCLUDE (FirstName, LastName)); หลังสร้าง IX_Person_MiddleName_cover: Index Seek 4 reads ไม่มี Key Lookup; ตัว query JOIN ใน Step 1 ก็ลดจาก 106 → 4 reads (ฝั่ง EmailAddress คงที่ 18 reads)

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

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): บล็อกนี้ใช้ **correlated subquery** (subquery ที่อ้างคอลัมน์ของแถวภายนอก `i` เพื่อรวมชื่อคอลัมน์ key/include ต่อ 1 index) และ **STRING_AGG ... WITHIN GROUP** (รวมค่าหลายแถวเป็น string เดียว โดยกำหนดลำดับการต่อได้) — อ่านเพิ่มที่ [Glossary](../../Glossary.md)
> ⚠️ **แก้จากต้นฉบับจากการรันจริง**: subquery ต้นฉบับอ้าง `c.name` โดยไม่มี JOIN `sys.columns` ทำให้ error `The multi-part identifier "c.name" could not be bound` — ต้องเพิ่ม JOIN เข้าไปตามด้านล่าง

```sql
SELECT OBJECT_SCHEMA_NAME(object_id) + '.' + OBJECT_NAME(object_id) AS table_name,
       name AS index_name,
       (SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
        FROM sys.index_columns AS ic
        JOIN sys.columns AS c
            ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0) AS key_cols,
       (SELECT STRING_AGG(c.name, ',')
        FROM sys.index_columns AS ic
        JOIN sys.columns AS c
            ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1) AS include_cols
FROM sys.indexes AS i
WHERE index_id > 1 AND OBJECTPROPERTY(object_id, 'IsUserTable') = 1
ORDER BY table_name, key_cols;
```

### Step 3 (Optional) — หา fragmentation ที่ควรจัดการ

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): `sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED')` คือ **table-valued function ที่รับพารามิเตอร์** (scope ของ object, mode การสำรวจ) วางใน FROM ได้เหมือนตาราง — `'LIMITED'` = สำรวจแบบเบา (อ่านโครงสร้าง b-tree ระดับบนเท่านั้น) ใช้แค่ดู % fragmentation หยาบ ๆ — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

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

**Expected:** Step 1 เห็น index เรียงจาก reads น้อย → มาก (บน DB ที่เพิ่งเปิดใช้จะมีแถว reads = 0 เป็นจำนวนมาก) — จดผู้สมัครถูก DROP; Step 2 เห็น key_cols ต่อกันเป็นสายจัดกลุ่มหาซ้ำ/ซ้ำบางส่วน; Step 3 เหลือเฉพาะ index ใหญ่ (>1,000 pages) ที่กระจัดกระจายเกิน 30%
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: Step 1 — reads=0 เป็นร้อยแถว ตัวที่จ่ายแรมรับ เช่น `dbo.DatabaseLog.PK_DatabaseLog_DatabaseLogID` (reads 0 / writes 25); Step 2 — `HumanResources.Employee` มี `IX_Employee_OrganizationNode` (OrganizationNode) ทับ prefix ของ `IX_Employee_OrganizationLevel_OrganizationNode` (OrganizationLevel,OrganizationNode) — ซ้ำบางส่วนต้องวิเคราะห์ก่อนตัดสินใจ; Step 3 — 3 แถว: `Person.XMLPROPERTY_Person_Demographics` 94.4% (2,677 pages), `Person.PXML_Person_Demographics` 51.7% (2,912), `PK_SalesOrderDetail_SalesOrderID_SalesOrderDetailID` 41.3% (1,558)

---

## Exercise 3: Stale Statistics

### Step 1 — หา statistics ที่เก่าและเปลี่ยนแปลงเยอะ (Glenn Berry)

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): `CROSS APPLY sys.dm_db_stats_properties(...)` = เรียก **table-valued function ต่อท้ายแต่ละแถว** ของ `sys.stats` เพื่อดึงพร็อพเพอร์ตี้ล่าสุดของสถิติแต่ละชุด (last_updated, rows, modification_counter) — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

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

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): บล็อกนี้เป็น **DDL + DML** — `CREATE TABLE`/`CREATE INDEX` (สร้างวัตถุ), `INSERT ... SELECT TOP` (แทรกข้อมูลจาก query) และ `GO 100` = สั่งรัน batch ก่อนหน้า **ซ้ำ 100 ครั้ง** (แทรก 100 แถว seed) — ตารางนี้ถูก DROP ใน Cleanup ท้ายแล็บ — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

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

> ⚠️ **แก้จากต้นฉบับจากการรันจริง (สำคัญ)**: บน DB ที่ `AUTO_UPDATE_STATISTICS = ON` (ค่า default) stats ของ `IX_StatsTest_Status` จะถูก **auto-update เองทันที** ตอน compile คิวรี "ก่อน" (วัดจริง: `last_updated` ขยับเป็นเวลาปัจจุบัน, estimated = actual = 50,000 ตั้งแต่ครั้งแรก — ไม่เห็น skew เลย) จึงต้อง `sp_autostats ... 'OFF'` เฉพาะตารางนี้ก่อน และใส่ `OPTION (RECOMPILE)` ทั้งสองคิวรี (เมื่อ autostats ถูกปิด แผนเก่าจะ**ไม่**ถูก invalid หลัง `UPDATE STATISTICS` — วัดจริง: estimated ยังค้าง 223.83 จนใส่ RECOMPILE จึงเป็น 50,000)

```sql
EXEC sp_autostats 'dbo.StatsTest', 'OFF';   -- ปิด auto-update เฉพาะตารางนี้ (ไม่แตะ config ระดับ DB)

-- ก่อน: สังเกต estimated row count ที่คลาดเคลื่อน (Ctrl+M)
SELECT COUNT(*) FROM dbo.StatsTest WHERE Status = 1 OPTION (RECOMPILE);

UPDATE STATISTICS dbo.StatsTest IX_StatsTest_Status WITH FULLSCAN;

-- หลัง: estimated ตรงกับ actual
SELECT COUNT(*) FROM dbo.StatsTest WHERE Status = 1 OPTION (RECOMPILE);
```

**Expected:** คิวรี "ก่อน" estimated rows ต่ำกว่า actual หลายร้อยเท่า (histogram ยังสร้างจาก 100 แถว seed ทั้งหมด Status = 0) ขณะที่ `modification_counter` ≈ 50,000; คิวรี "หลัง" estimated = actual พอดี
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: ก่อน — estimated 223.83 vs actual 50,000 (stats: rows = 100, modification_counter = 50,000, last_updated = เวลาสร้าง index); หลัง `WITH FULLSCAN` + RECOMPILE — estimated 50,000 = actual, rows 50,100, rows_sampled 50,100 (auto-update ที่ยิงเองเมื่อ autostats = ON ให้ estimated ตรง 50,000 ตั้งแต่คิวรีแรก จึงปิดเพื่อโชว์ skew ตามข้างบน)

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

**Expected:** ได้ 1 แถวแสดงชื่อ DB, `compatibility_level` และ `is_query_store_on` — ถ้าเป็น 170 + 1 แล้ว ไม่ต้องรัน `ALTER DATABASE` (บน VM ทดสอบของหลักสูตรตั้งไว้แล้ว); ถ้าต่ำกว่า 170 จึงรันบรรทัด ALTER ตาม code block
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: `AdventureWorks` — compatibility_level = 170, is_query_store_on = 1 (ไม่ต้อง ALTER; ไม่รวมการตรวจ XEvent ในรอบนี้)

---

## Wrap-up: คำถามท้ายแล็บ

1. Missing Index DMV แนะนำ index ใด และคุณปรับปรุงคำแนะนำนั้นอย่างไรก่อนใช้จริง? (จัด key/include ตาม query ที่มีอยู่จริง ตรวจซ้ำซ้อน)
2. index ใดของ database นี้ "จ่ายแรมรับความว่างเปล่า"? (reads = 0, writes สูง)
3. เพราะอะไร stale statistics ทำให้ optimizer เลือก plan ที่แย่? (CE อ่าน histogram เก่า ประเมิน rows ผิด → เลือก join/lookup ผิด)

## Cleanup

```sql
USE AdventureWorks2025;
DROP INDEX IF EXISTS IX_Person_MiddleName_cover ON Person.Person;
DROP TABLE IF EXISTS dbo.StatsTest;
```

## แหล่งอ้างอิง

- 10987C Lab06 — `Trainer_Docs/10987/Labfiles/Lab06/`
- Microsoft Learn: [Missing index DMVs](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-db-missing-index-details-transact-sql) · [Columnstore what's new (2025)](https://learn.microsoft.com/sql/relational-databases/indexes/columnstore-indexes-what-s-new) · [Persisted stats on secondaries (2025)](https://learn.microsoft.com/sql/relational-databases/performance/persisted-stats-secondary-replicas)
- Glenn Berry: [SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
- สคริปต์ของแล็บนี้อยู่ใน `Sections/*/Scripts/` ของโมดูล จัดตามหัวข้อที่เกี่ยวข้อง (ลิงก์ในแต่ละ Exercise)
