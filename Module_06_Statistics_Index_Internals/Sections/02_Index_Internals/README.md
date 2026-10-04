[⬅ Module 06](../../README.md) | [6.1 Statistics & CE](../01_Statistics_Cardinality_Estimation/README.md) | Section 2/3 | ➡ ถัดไป: [03 Columnstore Indexes](../03_Columnstore_Indexes/README.md)

# 6.2 Index Internals — กายวิภาค B-Tree, Covering Index และศิลปะการเลี้ยงดู Index

> *"Index ทุกตัวในระบบมี 'ค่าเช่ารายเดือน' — มันเก็บสำเนาข้อมูล กินพื้นที่ และเสียค่า maintenance ทุกครั้งที่คุณแก้ข้อมูล คนที่จูนเก่งไม่ใช่คนสร้าง index เยอะ แต่คือคนรู้ว่า index ตัวไหน 'จ่ายค่าเช่าคุ้ม'"*

> **ต้องรู้มาก่อน**: [Page (8 KB)](../../../Glossary.md), [Fragmentation](../../../Glossary.md), [Statistics](../../../Glossary.md), [DMV / DMF](../../../Glossary.md) — โครง Page/Extent/Allocation Unit จาก [Module 3 Section 3.1](../../Module_03_Database_Structures/Sections/01_Structure_Internals/README.md) (INDEX_PAGE, m_prevPage/m_nextPage, INDEX_PAGE บวม = key กว้าง) และ Statistics จาก Section 6.1
> **Permission ที่ต้องมี**: `VIEW DATABASE STATE` สำหรับ DMV, สิทธิ์ CREATE/DROP INDEX บน database ทดสอบ (ทุกตารางทดสอบใน section นี้ถูก DROP กลับในบล็อกเดียวกัน)

---

## ทำไม Section นี้จึงต้องมาต่อจาก Statistics

Section 6.1 จบที่ "optimizer ตัดสินใจด้วยจำนวนแถวที่เดาได้" — section นี้ตอบคำถามต่อ: **"เมื่อมันเลือก Seek แล้ว Seek นั้นทำงานอย่างไร และทำไมบางครั้งมันถึงปฏิเสธ index ที่เราตั้งใจสร้างไว้ให้"**

ปัญหา performance ส่วนใหญ่ที่ไม่ใช่ config ล้วนมาจาก index ไม่ถูกออกแบบ: ขาด index (ทุกคิวรี scan ทั้งตาราง), index ซ้ำซ้อน (เขียนสามสี่รอบต่อแถวที่แก้), หรือ index แตกกระจาย (frag สูงจนอ่าน page ฟุ่มเฟือย) และทั้งหมดนี้วัดได้ด้วยตัวเลข logical reads ที่เราเริ่มใช้จริงใน section นี้

เส้นทางของ Section:

1. **Heap vs Clustered vs Nonclustered** — สามโครงพื้นฐานและ Row Locator
2. **กายวิภาค B-Tree** — Root/Intermediate/Leaf อ่านจาก DMV จริง + จุดที่ Key Lookup แพง
3. **4 คุณสมบัติของ Clustered Key** — พิสูจน์ด้วย GUID vs Identity (frag 98.86% vs 0.44%)
4. **Covering Index & INCLUDE** — ทดสอบ 3 สถานะ: ไม่มี index → key-only → covering (106 → 105 → 4 reads)
5. **Missing Index DMV** — ใช้และ "ไม่เชื่อ" มันอย่างถูกวิธี
6. **Index ขยะ: Unused / Duplicate / Overlapping** — เกณฑ์คุณค่าและเครื่องมือตรวจ
7. **Fragmentation & การจัดการ** — เกณฑ์ 5/30% + REORGANIZE vs REBUILD (รวม RESUMABLE)
8. **Columnstore คืออีกโลก** — สะพานไป Section 6.3

> **หมายเหตุสภาพแวดล้อม:** ตัวเลข Expected รันจริงบน VM หลักสูตร (SQL Server 2025 RTM-GDR 17.0.1135.8, ฐานข้อมูล `AdventureWorks`, 2026-10-03) — ค่าจาก DMV ที่นับ usage/fragmentation จะ "เปลี่ยนตามเวลา" บน VM ของคุณ ให้ยึดรูปแบบผลลัพธ์เป็นหลัก

---

## 1. Heap vs Clustered vs Nonclustered — สามโครงที่ข้อมูลหนึ่งตารางอยู่ได้

**นิยามก่อนใช้:**

| ศัพท์ | นิยาม |
|:------|:------|
| **Heap** | ตารางที่ **ไม่มี clustered index** — แถวถูกวาง "ที่ที่ว่างก่อน" โดยไม่มีลำดับ; ระบุตำแหน่งแถวด้วย **RID** (Row Identifier = file:page:slot) |
| **Clustered Index** | โครงที่ **leaf level คือข้อมูลจริง** เรียงตาม key — หนึ่งตารางมีได้ตัวเดียวเพราะข้อมูลเรียงได้ทางเดียว |
| **Nonclustered (NC) Index** | โครงแยกที่เก็บ "สำเนา key + Row Locator" — ทำได้หลายตัวต่อตาราง |
| **Row Locator** | สิ่งที่ NC index พกเพื่อกลับไปหาแถวจริง: heap → RID; มี clustered → **clustered key** |

| สิ่งที่ NC index ชี้กลับ | โครงสร้างที่พัก | ผลต่อ Lookup |
|:------------------------|:----------------|:--------------|
| RID (file:page:slot) | Heap | ต้องอ่านอีก 1 page ขึ้นไปที่ "ตำแหน่งไม่แน่นอน" — ยิ่งแถวย้าย (page split/forwarding) ยิ่งเสียเปรียบ |
| Clustered key | Clustered index | กลับไปหาได้ด้วย "Seek" บน B-Tree เดียวกัน — เป็นเหตุผลที่ clustered key ควร **แคบ** (มันถูกพกซ้ำในทุก NC index) |

Heap มีที่ยืนของตัวเอง (staging table เน้น insert เร็วสุด, ตารางที่หยิบเฉพาะทีละก้อนแบบไม่กรอง) แต่ workload ทั่วไปที่มีการกรอง/เรียง — clustered index ให้ลำดับทางกายภาพที่ seek/read-ahead คุ้มค่า ส่วนข้อควรระวังของ heap (forwarding pointers, ความไม่เรียงที่โตขึ้นเรื่อย ๆ) จะเห็นผลชัดเมื่อตารางใหญ่

### 1.1 ตรวจโครงของตารางจริง — key อะไรอยู่ที่ไหน

```sql
USE AdventureWorks;
GO
SELECT i.index_id, i.name AS index_name, i.type_desc, i.is_primary_key,
       ic.key_ordinal, c.name AS column_name, ic.is_included_column
FROM sys.indexes AS i
JOIN sys.index_columns AS ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE i.object_id = OBJECT_ID('Sales.SalesOrderDetail')
  AND i.index_id = 3   -- IX_SalesOrderDetail_ProductID
ORDER BY ic.key_ordinal, ic.index_column_id;
GO
```

**Expected (รันจริง):**

| index_id | index_name | key_ordinal | column_name | is_included_column |
|:---------|:-----------|------------:|:------------|-------------------:|
| 3 | IX_SalesOrderDetail_ProductID | 1 | ProductID | 0 |

ข้อสังเกตที่หลายคนพลาด: `sys.index_columns` **ไม่แสดง** clustered key ที่ engine เติมให้โดยอัตโนมัติ — NC index นี้ไม่ unique ดังนั้น engine พก `SalesOrderID, SalesOrderDetailID` (clustered key) ต่อท้ายทุกแถวเงียบ ๆ เพื่อให้ row locator ไม่ซ้ำ — มันถูกใช้เป็น key ระดับ leaf จริง แต่มองไม่เห็นจาก metadata นี่คือ "น้ำหนักซ่อนเร้น" ที่ทำให้ clustered key กว้างเป็นเรื่องแพง (แต่ละ NC index บวมขึ้นตาม)

---

## 2. กายวิภาคของ B-Tree — อ่านโครงจริงจาก DMV

```
                         ┌───────────────────────┐
                         │  Root (index_level 2) │   1 page
                         │  key → ชี้ลงล่าง      │
                         └──────────┬────────────┘
                    ┌───────────────┼───────────────┐
             ┌──────┴─────┐   ┌─────┴──────┐  ┌─────┴──────┐
             │ Intermediate│   │ Intermediate│  │ Intermediate│
             │ (level 1)   │   │ (level 1)   │  │ (level 1)   │   รวม 9 pages
             └──────┬─────┘   └─────┬──────┘  └─────┬──────┘
        ┌───────────┼── ... ────────┼───────────────┤
   ┌────┴────┐ ┌────┴────┐     ┌────┴────┐
   │  Leaf   │ │  Leaf   │ ... │  Leaf   │     3,832 pages —
   │ (level 0│ │ (level 0│     │ (level 0│     ข้อมูลจริง 19,972 แถว
   └────┬────┘ └────┬────┘     └────┬────┘
        └───────────┴── doubly-linked list ────┘
                     (m_prevPage / m_nextPage)
```

- **Root + Intermediate (INDEX_PAGE, m_type 2)** — แผนที่ navigation อ่านจากบนลงล่าง
- **Leaf** — clustered: **DATA_PAGE ที่มีแถวจริง**; nonclustered: แถวเล็ก ๆ ที่มี key + Row Locator
- **Doubly-linked list ระดับ leaf** — scan/seek range เดินต่อกันได้ (อ่านค่าจริงด้วย `DBCC PAGE` ใน [Module 3 Section 3.1](../../Module_03_Database_Structures/Sections/01_Structure_Internals/README.md#6-อ่าน-page-จริงด้วย-dbcc-page--เปิดฝาเครื่อง))
- ทุกคำค้น "แตะ tree เท่ากันเสมอ" (Balanced) — ต้นทุน seek = depth ของ tree

วัดโครงจริงของ `PK_Person_BusinessEntityID` (clustered) ด้วย `sys.dm_db_index_physical_stats` โหมด DETAILED (แยกผลตามระดับ):

```sql
USE AdventureWorks;
GO
SELECT ips.index_level, ips.page_count, ips.record_count,
       CAST(ips.avg_page_space_used_in_percent AS DECIMAL(5,1)) AS avg_fill_pct,
       ips.index_type_desc
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('Person.Person'), 1, NULL, 'DETAILED') AS ips
WHERE ips.alloc_unit_type_desc = 'IN_ROW_DATA'
ORDER BY ips.index_level DESC;
GO
```

**Expected (รันจริง, 2026-10-03):**

| index_level | page_count | record_count | avg_fill_pct |
|------------:|-----------:|-------------:|-------------:|
| 2 (root) | 1 | 9 | 1.4 |
| 1 (intermediate) | 9 | 3,832 | 68.4 |
| 0 (leaf) | 3,832 | 19,972 | 85.4 |

อ่านผลเป็นภาษา performance:

1. **B-Tree ลึก 3 ระดับ** — seek หนึ่งครั้งอ่านสูงสุด 3 pages (root → intermediate → leaf) — logical reads 3-4 ต่อคำค้นที่เราเห็นบ่อยมาจากตรงนี้
2. **1 root หน้า** ชี้ลง 9 intermediate หน้า ชี้ลง 3,832 leaf หน้า — อัตราส่วนพุ่งเป็นพื้น ๆ เพราะ leaf จุแถวได้เป็นพัน (แถว Person กว้าง ~150 bytes → หน้าละ ~50 แถว) ส่วน intermediate จุ "ตัวชี้" ได้หลายพันต่อหน้า
3. `avg_fill_pct` leaf 85% = หน้ายังมีที่ว่างพอสำหรับแถวใหม่ (fillfactor default 0 = ~100% ในตอน build แต่แก้ไขไปแล้วตาม workload)

### 2.1 Page Split — จุดที่ B-Tree "เสียหาย"

เมื่อแถวใหม่ต้องแทรกลง leaf ที่ **เต็มแล้ว** engine แก้โดยแบ่งหน้าออกเป็นสองหน้า (~50/50):

- เขียน page เพิ่ม 2 หน้า + log ทั้งหน้า + อัปเดตตัวชี้ระดับบน → **I/O และ log เพิ่มต่อการ insert 1 แถว**
- หน้าใหม่จุได้แค่ครึ่งเดียว → **avg_page_space_used_in_percent ลดลง** = **Internal Fragmentation**
- ลำดับหน้าบนดิสก์เริ่มไม่ตรงกับลำดับ logical → **External Fragmentation** (วัดในหัวข้อ 7)

---

## 3. 4 คุณสมบัติของ Clustered Key — Unique, Narrow, Static, Ever-increasing

| คุณสมบัติ | เหตุผล | ราคาเมื่อฝ่าฝืน |
|:----------|:--------|:----------------|
| **Unique** | clustered key ใช้เป็น row locator — ต้องระบุแถวได้เฉพาะเจาะจง | key ซ้ำ → engine เติม **uniqueifier 4 bytes** ให้แถวที่ซ้ำทุกแถว (NC index ทุกตัวบวมตาม) |
| **Narrow** | ถูกพกในทุก NC index (ทั้งใน key และ leaf) | key กว้าง × จำนวน NC index = พื้นที่และ I/O บวมแบบทบต้น |
| **Static** | ค่าไม่เปลี่ยน | แก้ค่า key = ย้ายแถวทั้งแถว (ลบ+เขียนใหม่ + split) |
| **Ever-increasing** | แถวใหม่แทรก "ท้ายสุด" ของ tree เสมอ | insert สุ่มตำแหน่ง → page split ตลอดเวลา → frag + log บวม |

### 3.1 พิสูจน์: GUID สุ่ม vs Identity

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.FragLab;
GO
CREATE TABLE dbo.FragLab
(
    Id UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY CLUSTERED,   -- GUID สุ่ม = ฝ่าฝืน ever-increasing
    Val INT, Pad CHAR(200) DEFAULT 'x'
);
GO
DECLARE @i INT = 0;
WHILE @i < 8000
BEGIN
    INSERT dbo.FragLab (Val) VALUES (@i);
    SET @i += 1;
END
GO
SELECT 'GUID สุ่ม' AS key_type, avg_fragmentation_in_percent, page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.FragLab'), 1, NULL, 'LIMITED');
GO
DROP TABLE dbo.FragLab;
GO
CREATE TABLE dbo.FragLab
(
    Id INT IDENTITY PRIMARY KEY CLUSTERED,                       -- Identity = ever-increasing
    Val INT, Pad CHAR(200) DEFAULT 'x'
);
GO
DECLARE @i INT = 0;
WHILE @i < 8000
BEGIN
    INSERT dbo.FragLab (Val) VALUES (@i);
    SET @i += 1;
END
GO
SELECT 'Identity' AS key_type, avg_fragmentation_in_percent, page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.FragLab'), 1, NULL, 'LIMITED');
GO
DROP TABLE dbo.FragLab;
GO
```

**Expected (รันจริง, 2026-10-03):**

| key_type | avg_fragmentation_in_percent | page_count |
|:---------|-----------------------------:|-----------:|
| GUID สุ่ม | **98.86** | **351** |
| Identity | **0.44** | **229** |

ข้อมูลเท่ากัน 8,000 แถว — แต่ GUID สุ่มแตกหน้า (page split) จน frag 98.86% และกิน page มากกว่า 53% (351 vs 229) เพราะทุกหน้าถูก "แยกครึ่ง" ทิ้งช่องว่างครึ่งหน้า ถ้ามี NC index คู่อยู่ด้วย มันจะบวมตาม clustered key ที่พก uniqueifier/16-byte GUID ทุกแถว — ทางแก้เมื่อต้องใช้ GUID: `NEWSEQUENTIALID()` หรือ GUID + identity คู่กัน — สอดคล้องผลแล็บ [Module 3 Labs Exercise 2](../../Module_03_Database_Structures/Labs/README.md) (BadKeyTable frag 98.5% เทียบ GoodKeyTable)

> [!TIP]
> `avg_page_space_used_in_percent` ได้ค่าเฉพาะโหมด SAMPLED/DETAILED — โหมด LIMITED (ที่ใช้ตรวจ frag ประจำวัน) จะได้แค่ `avg_fragmentation_in_percent` + `page_count` เป็น NULL ไม่ใช่ bug

---

## 4. Covering Index & INCLUDE — จาก 106 เหลือ 4 Logical Reads

**นิยามก่อนใช้:**

| ศัพท์ | นิยาม |
|:------|:------|
| **Covering Index** | NC index ที่มี "ทุกคอลัมน์ที่คิวรีต้องใช้" — คิวรีจบใน index เดียว ไม่ต้องกลับไปหาตารางจริง |
| **INCLUDE columns** | คอลัมน์ที่เก็บ "เฉพาะ leaf level" ไม่เข้าไปรบ key ระดับบน — ใช้ "พอง" index ให้ครอบคลุมโดยไม่บวม B-Tree ระดับบน |
| **Key Lookup** | การวิ่งจาก NC index กลับไปหาตารางจริง "ทีละแถว" เมื่อ index ยังขาดคอลัมน์ที่ SELECT ต้องการ |

ทดสอบ 3 สถานะบนคิวรีเดียวกัน — filter ด้วย `MiddleName` (ไม่มี index รองรับใน AdventureWorks):

```sql
USE AdventureWorks;
GO
SET STATISTICS IO ON;
-- สถานะ 1: ยังไม่มี index ที่เราสร้าง (optimizer scan ของเดิมที่แคบสุดซึ่งพา MiddleName ได้)
SELECT BusinessEntityID, FirstName, LastName FROM Person.Person WHERE MiddleName = N'J.';
GO
-- สถานะ 2: สร้าง index แบบ key-only
CREATE NONCLUSTERED INDEX IX_Person_MiddleName_key ON Person.Person (MiddleName);
GO
SELECT BusinessEntityID, FirstName, LastName FROM Person.Person WHERE MiddleName = N'J.';
GO
-- สถานะ 3: เปลี่ยนเป็น covering index (key + INCLUDE)
DROP INDEX IX_Person_MiddleName_key ON Person.Person;
CREATE NONCLUSTERED INDEX IX_Person_MiddleName_cover ON Person.Person (MiddleName)
INCLUDE (FirstName, LastName);
GO
SELECT BusinessEntityID, FirstName, LastName FROM Person.Person WHERE MiddleName = N'J.';
GO
SET STATISTICS IO OFF;
-- ล้างของทดสอบ (คืนสถานะเดิมของ AdventureWorks)
DROP INDEX IX_Person_MiddleName_cover ON Person.Person;
GO
```

**Expected (รันจริง, 2026-10-03):**

| สถานะ | Plan ที่เลือก | Table 'Person' logical reads |
|:------|:--------------|-----------------------------:|
| 1. ไม่มี index ของเรา | Index Scan (NC index ที่พา MiddleName ได้ที่แคบสุด + residual predicate) | **106** |
| 2. key-only `(MiddleName)` | **ยัง Index Scan ของ index ใหม่** | **105** |
| 3. covering `(MiddleName) INCLUDE (FirstName, LastName)` | **Index Seek** ไม่มี Key Lookup | **4** |

อ่านผล — สามบทเรียนที่แรงกว่าทฤษฎี:

1. **สถานะ 2 คือกับดักคลาสสิก**: สร้าง index บน MiddleName แล้ว logical reads แทบไม่ลด (105 เทียบ 106) เพราะ optimizer **ปฏิเสธ** Seek + Key Lookup — 132 แถวที่ต้อง Lookup ต่างกันราคากว่า Scan ทั้ง index (Key Lookup ~2-4 reads ต่อแถว × 132 แถว ≈ 400) — "มี index บนคอลัมน์ที่กรอง" ไม่พอ ต้อง "ครอบคอลัมน์ที่ SELECT" ด้วย
2. **สถานะ 3 คือคำตอบ**: INCLUDE ยก FirstName/LastName ไปเก็บที่ leaf — Seek เจาะเข้าช่วง `MiddleName = 'J.'` แล้วอ่านคอลัมน์ที่เหลือจาก leaf โดยตรง → 4 reads (~26 เท่า) ตรงกับ [Labs Exercise 1](../../Labs/README.md)
3. **BusinessEntityID ไม่ต้อง INCLUDE เพิ่ม** — clustered key ถูกพกใน leaf ของ NC index ทุกตัวอยู่แล้ว (หัวข้อ 1.1)

เกณฑ์คิดแบบมืออาชีพ:

| คอลัมน์ที่คิวรีใช้ | บทบาท | ไปที่ไหนใน index |
|:-------------------|:-------|:------------------|
| คอลัมน์ใน `WHERE / JOIN / ORDER BY` | กรอง + เรียง | **Key** (เรียงได้, seek ได้) |
| คอลัมน์ใน `SELECT` ที่ไม่ใช้กรอง | แค่ "ต้องการค่า" | **INCLUDE** (leaf เท่านั้น) |

> **ระวัง:** ถ้า predicate คืนหลายพันแถว Key Lookup แบบเก่าอาจแพงกว่า scan ทั้งตาราง — covering index "ชนะเสมอ" ก็ต่อเมื่อ key ที่ seek เจาะได้คืนแถวจำนวนพอเหมาะ และ INCLUDE จำกัดไม่เกิน "คอลัมน์ที่ workload ใช้จริง" (index กว้าง = ค่าเช่าแพง — หัวข้อ 6)

**Filtered Index** (ทางเลือกเสริม) — index ที่มี `WHERE` ของตัวเอง เช่น `CREATE INDEX ... ON Orders(CustomerID) WHERE Status = 'OPEN'` — เล็กลงและแม่นขึ้นสำหรับ subset ที่ถูกกรองบ่อย แลกกับข้อจำกัด (predicate ของคิวรีต้อง "อยู่ใน" filter ของ index, ไม่รองรับ parameter แบบกว้าง ๆ)

---

## 5. Missing Index DMV — ใช้ให้เป็น แต่อย่าเชื่อ 100%

ระหว่าง optimize คิวรี ถ้า optimizer เจอความจำเป็นที่ไม่มี index ตอบ มันจะ (1) ติดคำแนะนำ (Missing Index hint — ข้อความเขียวใน plan ของ SSMS เมื่อเปิด Ctrl+M) และ (2) บันทึกสะสมไว้ใน 3 DMVs ที่ join กันได้:

```sql
USE AdventureWorks;
GO
-- จัดอันดับคำแนะนำสะสมด้วย benefit score (จาก Labs Ex1)
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
GO
```

**หมายเหตุ:** บน VM สะอาด (เพิ่ง restart) DMV ชุดนี้ว่างเปล่าจนกว่าคิวรีที่ "ขาด index" จะถูกรัน — รันคิวรีจาก [Labs Exercise 1 Step 1](../../Labs/README.md) (`WHERE p.MiddleName = N'J.'` คู่กับ JOIN EmailAddress) ก่อน แล้ว query นี้จะขึ้นแถวแนะนำ `(MiddleName) INCLUDE (FirstName, LastName)` ตรงกับที่เราสร้างในหัวข้อ 4

### 5.1 ข้อจำกัด 7 ข้อที่ต้อง review เองเสมอ

1. **ไม่จัดลำดับ key ให้** — แนะนำแค่ "ชุดคอลัมน์" ลำดับ equality มาก่อน inequality ต้องคิดเอง
2. **ไม่รวมคำแนะนำซ้ำทับซ้อน** (consolidate) — คิวรี 10 ตัวอาจแนะนำ index เดียวกันสิบรูป
3. **ไม่สน index ที่มีอยู่แล้ว** — เคสแล็บ: กรอง `LastName = 'Anderson'` ถูก cover โดย `IX_Person_LastName_FirstName_MiddleName` ที่มากับ DB ตั้งแต่ติดตั้ง จึงไม่ขึ้น hint เลย (ต้องเปลี่ยนเดโมเป็น `MiddleName`)
4. **ไม่คิด INCLUDE** — แนะนำมาเป็น key ล้วนบ่อยครั้ง
5. **สถิติหายเมื่อ restart** — DMV เก็บตั้งแต่ last restart เท่านั้น (ไม่ persist)
6. **มีเพดาน** — จำคำแนะนำได้ ~600 รายการต่อคิวรี / ~10,000 ต่อตาราง
7. **ไม่รู้แลกเปลี่ยนฝั่ง write** — มันเห็นแต่ "อ่านจะเร็วขึ้นเท่าไร" ไม่เห็นค่า insert/update/delete ที่จะเพิ่ม

ทางเสริมที่ดีกว่า: สืบจาก **Query Store** คิวรีจริงที่แผนมี MissingIndex ฝังอยู่ (สคริปต์ `02_Index_Analysis_QueryStore.sql` ใน [Scripts](../Scripts/02_Index_Analysis_QueryStore.sql)) หรือ Plan Explorer ที่รวมคำแนะนำให้ — และหลังสร้าง index จริง อย่าลืมบันทึกไว้เทียบก่อน-หลัง (STATISTICS IO ตามหัวข้อ 4)

---

## 6. Index ขยะ — Unused / Duplicate / Overlapping

การมี index เกินจำเป็นไม่ได้แค่เปลืองดิสก์ — **ทุก INSERT/UPDATE/DELETE ต้อง maintain ทุก NC index ที่พาคอลัมน์นั้น** และ index ที่ไม่มีใครอ่านคือ "จ่ายค่าเช่าเฉย ๆ" ตารางเปรียบเทียบ:

| ประเภท | นิยาม | การตัดสินใจ |
|:--------|:------|:-------------|
| **Unused** | `reads = 0` (seek+scan+lookup) แต่ `writes > 0` ตลอด baseline | ผู้สมัคร DROP ตัวจริง — ยืนยันก่อนว่าไม่ใช่ PK/Unique และไม่ใช่งานรายเดือน/รายปี |
| **Duplicate** | key columns **เหมือนกันเป๊ะ** ตามลำดับ | ตัดตัวใดตัวหนึ่งได้เกือบเสมอ (เช็ก INCLUDE ก่อน) |
| **Overlapping** | key ของตัวหนึ่งเป็น **prefix** ของอีกตัว | **ต้องวิเคราะห์** — ตัวสั้นแคบกว่า (maintenance ถูกกว่า) และอาจถูก seek ด้วยกรองสั้น ๆ หรือมี INCLUDE ต่างกัน |

### 6.1 สแกนหา "จ่ายค่าเช่าเฉย ๆ" (สไตล์ Glenn Berry)

```sql
USE AdventureWorks;
GO
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
GO
```

**Expected (รันจริง, 2026-10-03 — ตัดมาแถวบนสุด):**

| schema_name | table_name | index_name | total_reads | total_writes |
|:------------|:-----------|:-----------|------------:|-------------:|
| dbo | DatabaseLog | PK_DatabaseLog_DatabaseLogID | 0 | 226 |
| Production | TransactionHistory | IX_TransactionHistory_ProductID | 0 | 4 |
| Purchasing | PurchaseOrderHeader | IX_PurchaseOrderHeader_EmployeeID | 0 | 0 |

อ่านผล: `PK_DatabaseLog_DatabaseLogID` ถูกเขียน 226 ครั้ง (ทุก DDL บน database นี้ไหม log) แต่ไม่เคยถูกอ่านเลย — เป็น **PK** จึงลบไม่ได้ (ต้องเปลี่ยนเป็น clustered ที่ต่างกันถ้าอยากจูน) ส่วน NC ที่ reads = 0 / writes สูงคือผู้สมัคร DROP ตัวจริง — แต่ต้องมี baseline ยาว ≥ 1 business cycle ก่อนกดปุ่ม

### 6.2 สแกนหา duplicate/overlapping ด้วย key columns ต่อเป็นสาย

```sql
USE AdventureWorks;
GO
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
GO
```

**Expected (รันจริง, 2026-10-03 — ตาราง HumanResources.Employee):**

| table_name | index_name | key_cols |
|:-----------|:-----------|:---------|
| HumanResources.Employee | IX_Employee_OrganizationLevel_OrganizationNode | OrganizationLevel,OrganizationNode |
| HumanResources.Employee | IX_Employee_OrganizationNode | OrganizationNode |

เคสจริงใน AdventureWorks: `IX_Employee_OrganizationNode (OrganizationNode)` เป็น **prefix** ของ `IX_Employee_OrganizationLevel_OrganizationNode (OrganizationLevel, OrganizationNode)` — แต่ไม่ใช่ duplicate (ลำดับต่างกัน!) — คิวรีที่กรองเฉพาะ OrganizationNode ใช้ได้ทั้งคู่ (ตัวสั้นแคบกว่าจึงถูกกว่า) แต่คิวรีที่กรอง OrganizationLevel **ก่อนแล้ว** OrganizationNode ใช้ได้เฉพาะตัวยาว — ตัดสินจาก `sys.dm_db_index_usage_stats` ว่าตัวไหนถูกใช้จริง แล้วค่อยรวม/ลบ

---

## 7. Fragmentation — วัด ตีความ และจัดการตามเกณฑ์

**นิยามก่อนใช้:**

| ชนิด | ความหมาย | ตัวชี้วัดใน DMF |
|:------|:----------|:----------------|
| **External (Logical) Fragmentation** | ลำดับ logical ของหน้า (ตาม m_prevPage/m_nextPage) ไม่ตรงกับลำดับกายภาพบนไฟล์ | `avg_fragmentation_in_percent` |
| **Internal Fragmentation** | หน้า "โหว่ง" — เต็มไม่ถึง fillfactor จาก split/shrink | `avg_page_space_used_in_percent` (ต้องโหมด SAMPLED/DETAILED) |

ผลกระทบหลักอยู่ฝั่ง **range scan** (อ่านต่อเนื่องหลายหน้า) — หน้ากระจัดกระจาย = I/O กระโดดมากขึ้น ขณะที่ **single-row seek** แทบไม่สะทกสะท้าน จึงต้องดู "fragmentation × รูปแบบการอ่าน" คู่กันเสมอ

### 7.1 เกณฑ์มาตรฐาน (Index Reorganize Guide ของ Microsoft)

| avg_fragmentation_in_percent | คำสั่ง | หมายเหตุ |
|------------------------------:|:--------|:----------|
| **5 – 30%** | `ALTER INDEX ... REORGANIZE` | online เสมอ, ใช้ทีละหน้า, ไม่ lock นาน, ย่อ log น้อย — ไม่อัปเดต statistics |
| **> 30%** | `ALTER INDEX ... REBUILD` | สร้างโครงใหม่ทั้ง tree (หน้าแน่นกลับ) — อัปเดต statistics ตามไปด้วย, ใช้ `ONLINE = ON` ได้ (Enterprise) |
| **< 5%** | ปล่อยไว้ | แก้แล้วไม่เห็นผล — คุ้มไม่คุ้มไม่ต้องคิด |

พร้อมเงื่อนไข "ขนาดมีความหมาย": สำรวจด้วยโหมด `LIMITED` (เบาที่สุด — อ่านเฉพาะโครงระดับบน) และให้เกณฑ์ `page_count > 1,000` กันตัดสินจากตารางเล็กที่ "frag สูงแต่ไร้ผล" — และ **ห้ามลืม: shrink database เป็นตัวสร้าง fragmentation ระดับแมส** (ทิ้งหน้าใหม่แบบกระจายทั้งไฟล์) — อ่านต่อ [Module 3 Section 3.2](../../Module_03_Database_Structures/Sections/02_Data_File_Internals/README.md)

### 7.2 พิสูจน์: สร้าง frag → REORGANIZE → REBUILD

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.FragFixLab;
GO
CREATE TABLE dbo.FragFixLab
(
    Id UNIQUEIDENTIFIER DEFAULT NEWID(),
    Pad CHAR(200) DEFAULT 'x',
    CONSTRAINT PK_FragFixLab PRIMARY KEY CLUSTERED (Id)
);
GO
DECLARE @i INT = 0;
WHILE @i < 4000
BEGIN
    INSERT dbo.FragFixLab DEFAULT VALUES;
    SET @i += 1;
END
GO
SELECT N'ก่อนแก้' AS phase, avg_fragmentation_in_percent, page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.FragFixLab'), 1, NULL, 'LIMITED');
GO
ALTER INDEX ALL ON dbo.FragFixLab REORGANIZE;
GO
SELECT N'หลัง REORGANIZE' AS phase, avg_fragmentation_in_percent, page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.FragFixLab'), 1, NULL, 'LIMITED');
GO
ALTER INDEX PK_FragFixLab ON dbo.FragFixLab
REBUILD WITH (RESUMABLE = ON, ONLINE = ON, MAXDOP = 1);   -- SQL 2019+: หยุด/ทำต่อได้ (2022+ ทำได้แม้คนละ session)
GO
SELECT N'หลัง REBUILD (RESUMABLE)' AS phase, avg_fragmentation_in_percent, page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.FragFixLab'), 1, NULL, 'LIMITED');
GO
DROP TABLE dbo.FragFixLab;
GO
```

**Expected (รันจริง, 2026-10-03):**

| phase | avg_fragmentation_in_percent | page_count |
|:------|-----------------------------:|-----------:|
| ก่อนแก้ | 98.84 | 172 |
| หลัง REORGANIZE | **0.82** | **122** |
| หลัง REBUILD (RESUMABLE) | **1.64** | **122** |

อ่านผล:

1. GUID สุ่ม 4,000 แถว split หน้าจน frag 98.84% และกิน 172 หน้า
2. **REORGANIZE ไม่ได้แค่ "จัดลำดับหน้า"** — มันกวาดแถวให้แน่นขึ้นด้วย (172 → 122 หน้า, frag 0.82%) ทั้งที่ยังไม่ REBUILD
3. REBUILD สร้าง tree ใหม่ให้ frag ~0 (ตัวเลข 1.64% มาจากหน้าเศษท้าย tree) พร้อมตัวเลือก **RESUMABLE = ON** — แผนที่ไปเป็นช่วง ๆ หยุด-ต่อได้ ทน maintenance window สั้น ๆ และ **ต้องระบุ index เจาะจง — `ALTER INDEX ALL ... RESUMABLE` ไม่รองรับ** (ทดสอบจริง: error 11433 "ALTER INDEX ALL with RESUMABLE option is not supported")

### 7.3 สคริปต์ triage ประจำวัน

```sql
USE AdventureWorks;
GO
SELECT OBJECT_NAME(ps.object_id) AS table_name,
       i.name AS index_name,
       ps.avg_fragmentation_in_percent,
       ps.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ps
JOIN sys.indexes AS i ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE ps.avg_fragmentation_in_percent > 30 AND ps.page_count > 1000
ORDER BY ps.avg_fragmentation_in_percent DESC;
GO
```

**Expected (รันจริง, 2026-10-03 — ค่าเปลี่ยนตาม workload ของ VM):**

| table_name | index_name | avg_fragmentation_in_percent | page_count |
|:-----------|:-----------|-----------------------------:|-----------:|
| Person | XMLPROPERTY_Person_Demographics | 97.8 | 2,790 |
| SalesOrderDetail | PK_SalesOrderDetail_SalesOrderID_SalesOrderDetailID | 71.1 | 1,927 |
| Person | PXML_Person_Demographics | 70.4 | 3,333 |

รายการแรกคือ XML index (สาเหตุจากการ restore) — เคสนี้สอนว่า "frag > 30% + page_count > 1,000" ยังต้องตัดสิน "คุ้มแก้ไหม" — XML index ใหญ่ที่ scan นาน ๆ ครั้ง อาจ REBUILD ตอน window ว่าง ส่วน clustered PK ของ SalesOrderDetail ถูกกรอง/seek บ่อยจึงคุ้มดูแลจริง

---

## 8. Columnstore คืออีกโลก — สะพานไป Section 6.3

ทุกอย่างใน section นี้ (B-Tree, page split, fragmentation, INCLUDE) พูดถึง **Rowstore** — จัดเก็บ "แถว" ต่อเนื่อง สำหรับ workload อ่านทีละแถว (OLTP) เมื่อ workload เป็น "สรุปตัวเลขจากหลายสิบล้านแถว" (DW/Analytics) โครงที่จัดเก็บ **แยกตามคอลัมน์ + บีบอัด + ประมวลผลเป็นชุด (batch mode)** จะเร็วกว่าหลายเท่าถึงสิบเท่า — รายละเอียดโครงสร้าง Rowgroup/Segment/Deltastore/Tuple Mover และการทดสอบจริงทั้งชุด อยู่ใน [Section 6.3 — Columnstore Indexes](../03_Columnstore_Indexes/README.md)

---

## สรุป Section 6.2

1. **Heap** (RID), **Clustered** (leaf = ข้อมูลจริง, มีได้ตัวเดียว), **Nonclustered** (สำเนา key + row locator = clustered key ที่ engine พกให้เงียบ ๆ)
2. B-Tree ของ Person.Person ลึก 3 ระดับ (root 1 → intermediate 9 → leaf 3,832 pages / 19,972 แถว) — seek หนึ่งครั้ง = ~3 reads
3. **Clustered key 4 คุณสมบัติ**: Unique (ซ้ำ = uniqueifier 4 bytes), Narrow, Static, Ever-increasing — GUID สุ่ม frag 98.86% / 351 pages เทียบ identity 0.44% / 229 pages
4. **Covering index ชนะกับดัก key-only**: 106 (scan) → 105 (scan ของ index ใหม่ — optimizer ปฏิเสธ Seek+Lookup ที่แพงกว่า) → 4 (Seek จบใน index เดียว)
5. Missing Index DMV ใช้เป็น "เบาะแส" — ต้อง review ลำดับ/INCLUDE/ซ้ำซ้อน/index เดิม/ค่าเช่าฝั่ง write เองเสมอ
6. Index ขยะสามแบบ (unused/duplicate/overlapping) ตรวจด้วย `sys.dm_db_index_usage_stats` + key columns เป็นสาย — overlapping ต้องวิเคราะห์ก่อนตัด
7. Fragmentation: วัดด้วย `LIMITED`, เกณฑ์ **5–30% REORGANIZE / >30% REBUILD / <5% ปล่อย** + `page_count > 1,000`; REORGANIZE บีบหน้าให้แน่นได้จริง (172 → 122 pages); RESUMABLE REBUILD ใช้กับ per-index เท่านั้น

### ตรวจความเข้าใจ

1. เพราะเหตุใด `sys.index_columns` ของ `IX_SalesOrderDetail_ProductID` จึงแสดงแค่ ProductID ทั้งที่ engine พก `SalesOrderID, SalesOrderDetailID` ในทุกแถว — และผลต่อการออกแบบ clustered key คืออะไร
2. จากการทดสอบ 3 สถานะ: index `(MiddleName)` แบบ key-only ทำให้ logical reads แทบไม่ลด (105 เทียบ 106) — อธิบายด้วย "ราคา Key Lookup" ว่าทำไม optimizer ถึงปฏิเสธ Seek
3. GUID สุ่มทำให้ frag 98.86% — ระบุว่าผลกระทบวิ่งไปที่ "แถวใหม่ต้องแทรกกลาง tree" อย่างไร และเชื่อมโยงสามผลตามมา: page split, internal fragmentation, log บวม
4. คิวรีแบบไหนที่ REORGANIZE ช่วยได้จริง และคิวรีแบบไหนที่ frag สูงก็ตามแต่ "ไม่คุ้มแก้" — อ้างเกณฑ์ 5/30% + page_count + รูปแบบการอ่าน
5. `IX_Employee_OrganizationNode` กับ `IX_Employee_OrganizationLevel_OrganizationNode` เป็น duplicate หรือ overlapping — ทำไมจึง "ต้องวิเคราะห์ก่อนตัดสินใจ" แทนที่จะ DROP ตัวสั้นทันที
6. คำสั่ง `ALTER INDEX ALL ON T REBUILD WITH (RESUMABLE = ON)` จะ error บน SQL Server 2025 — บอกสาเหตุและวิธีเขียนที่ถูก

**➡ ถัดไป:** [Section 6.3 — Columnstore Indexes: Rowgroup, Segment Elimination, Batch Mode](../03_Columnstore_Indexes/README.md)

---

[⬅ Module 06](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [03 Columnstore Indexes](../03_Columnstore_Indexes/README.md)
