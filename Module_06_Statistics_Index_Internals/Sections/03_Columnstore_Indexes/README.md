[⬅ Module 06](../../README.md) | [6.2 Index Internals](../02_Index_Internals/README.md) | Section 3/3

# 6.3 Columnstore Indexes — โครงสร้างแบบคอลัมน์สำหรับ Workload วิเคราะห์

> *"Rowstore เก็บข้อมูลเป็น 'ประวัติของลูกค้าหนึ่งคน' ต่อหน้า — Columnstore เก็บเป็น 'ช่องเดียวกันของคนหนึ่งล้านคน' ต่อ segment คิวรีวิเคราะห์ที่สนใจแค่ 3 คอลัมน์จาก 50 จึงแตะข้อมูลแค่ 6% ของที่ Rowstore ต้องอ่าน"*

> **ต้องรู้มาก่อน**: [Columnstore Index](../../../Glossary.md), [Page (8 KB)](../../../Glossary.md), [Execution Plan](../../../Glossary.md) — โครง B-Tree/Page split/Fragmentation จาก [Section 6.2](../02_Index_Internals/README.md) (columnstore แก้ปัญหาคนละแบบ) และค่า logical reads ที่ใช้วัดตลอดหลักสูตร
> **Permission ที่ต้องมี**: สิทธิ์ CREATE/DROP INDEX + พื้นที่ tempdb/data สำหรับตารางทดสอบ ~12 MB (ทุกตารางทดสอบถูก DROP กลับใน section) — การ build CCI ใช้เวลา ~20-25 วินาทีบน VM หลักสูตร

---

## ทำไม Section นี้จึงต้องมาท้ายโมดูล

Section 6.2 จบที่ "Rowstore จัดการแถวอย่างฉลาด" — section นี้เปลี่ยนสมมติฐานทั้งหมด: **analytics workload ไม่อ่าน "แถว" แต่อ่าน "คอลัมน์จากแถวหลายล้านแถว"** เมื่อ dashboard รวมยอดขาย 3 คอลัมน์จากตาราง 50 คอลัมน์ที่มีแถวหลายสิบล้าน Rowstore ต้องอ่าน "ทุกคอลัมน์ทุกแถว" มาแล้วทิ้ง Columnstore อ่านเฉพาะ 3 segments ที่ต้องใช้ + บีบอัดข้อมูลให้เล็กลงระดับ 10 เท่า + ประมวลผลเป็นชุด (batch mode) ระดับ CPU vector

เส้นทางของ Section (ทุกข้อมีตารางทดสอบจริง `dbo.CsOrders` 2.2 ล้านแถว ที่สร้างและทำลายใน section เดียวกัน):

1. **Rowstore vs Columnstore + CCI vs NCCI** — โครงหลักและการเลือกใช้
2. **กายวิภาค: Rowgroup / Segment / Deltastore** — สร้างของจริงแล้วมาดูกัน
3. **Segment Elimination** — กลไก "ข้ามข้อมูลที่ไม่เกี่ยว" ที่อ่าน min/max ต่อ segment
4. **Deltastore & Tuple Mover** — เมื่อ insert ทีละน้อย ข้อมูลไปพักที่ไหน
5. **การลบ/อัปเดต & Deleted Bitmap** — segment แก้ตรงไม่ได้แล้ว engine จัดการยังไง
6. **Batch Mode Execution** — โหมด CPU ที่ทำงานคู่กับ columnstore
7. **Compression** — ทำไมจึงเล็กลงหลายเท่า (ทดสอบจริง 101.6 → 11.3 MB)
8. **ข้อจำกัด + ฟีเจอร์ใหม่ SQL Server 2025**

> **หมายเหตุสภาพแวดล้อม:** ตัวเลข Expected รันจริงบน VM หลักสูตร (SQL Server 2025 RTM-GDR 17.0.1135.8, ฐานข้อมูล `AdventureWorks`, 2026-10-03) — จำนวน rowgroup/ขนาดบีบอัดจะเปลี่ยนตามข้อมูลและ MAXDOP ของเครื่องคุณ ให้ยึด "รูปแบบพฤติกรรม" เป็นหลัก

---

## 1. Rowstore vs Columnstore — สองวิธีเก็บข้อมูลเดียวกัน

```
Rowstore (B-Tree จาก Section 6.2)          Columnstore (CCI)
หน้า 1: [แถว1 แถว2 แถว3 ...]               Segment1: [Seq ของ 1M แถว]
หน้า 2: [แถว1001 แถว1002 ...]              Segment2: [OrderDate ของ 1M แถว]
อ่าน 1 แถว = อ่าน "ทุกคอลัมน์ของแถวนั้น"    Segment3: [ProductID ของ 1M แถว]
รวม 5 คอลัมน์ = อ่านทุกหน้าที่พาแถวมา       อ่าน 1 คอลัมน์ = อ่าน segment เดียว
```

| ประเด็น | Rowstore (B-Tree) | Columnstore |
|:---------|:-------------------|:------------|
| หน่วยจัดเก็บ | Page 8 KB เก็บหลายแถว | **Rowgroup** (~1,048,576 แถว) แตกเป็น **Segment ต่อคอลัมน์** |
| อ่าน 3 คอลัมน์จาก 50 | ต้องอ่านทุก page ที่พาแถวมา | อ่านเฉพาะ 3 segments |
| การบีบอัด | PAGE/ROW compression (ระดับ 2-4 เท่า) | Dictionary + RLE + bit-packing (ระดับ ~10 เท่า) |
| โหมดประมวลผล | Row mode (ทีละแถว) | **Batch mode** (~900 แถว/ชุดต่อ operator) |
| การแก้ข้อมูล | แก้ตรงจุดได้ | แก้ผ่าน deltastore + deleted bitmap (แพงกว่า) |
| เหมาะกับ | OLTP: ค้นหา 1 แถว, แก้ทีละแถว | DW/Analytics: รวมยอด, scan หลายล้านแถว |

### 1.1 CCI vs NCCI — เลือก "บ้านหลัก" หรือ "แว่นขยาย"

| ชนิด | ตำแหน่ง | การใช้งาน |
|:-----|:---------|:-----------|
| **Clustered Columnstore Index (CCI)** | เป็น **พื้นที่จัดเก็บหลัก** ของตาราง (leaf ของ index คือข้อมูลจริง แบบเดียวกับ clustered rowstore) | Fact table ของ Data Warehouse — มีได้ 1 ต่อตาราง |
| **Nonclustered Columnstore Index (NCCI)** | โครง columnstore **แยก** ที่สร้างทับ rowstore table | **HTAP / Real-time operational analytics** — ระบบทำธุรกรรมตามปกติ (rowstore) แต่รายงานวิเคราะห์บนตารางเดียวกันได้ทันที |

ทดสอบสร้าง NCCI บนตารางจริง (และเจอข้อจำกัดเชิงปฏิบัติตัวแรก):

```sql
USE AdventureWorks;
GO
-- LineTotal เป็น computed column → error 35307: "Columnstore index cannot include
-- a computed column implicitly or explicitly" — ต้องเลือกเฉพาะคอลัมน์ปกติ
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_SalesOrderDetail
ON Sales.SalesOrderDetail (ProductID, OrderQty, UnitPrice);
GO
SELECT i.name, i.type_desc, i.index_id
FROM sys.indexes AS i
WHERE i.object_id = OBJECT_ID('Sales.SalesOrderDetail') AND i.type = 6;   -- type 6 = NCCI
GO
-- 121,317 แถวถูกบีบเป็น compressed rowgroup ทันที (ต่ำกว่า 1M ก็บีบได้ ตอน CREATE เท่านั้น)
SELECT rg.row_group_id, rg.state_description, rg.total_rows
FROM sys.column_store_row_groups AS rg
WHERE rg.object_id = OBJECT_ID('Sales.SalesOrderDetail')
  AND rg.index_id = (SELECT MAX(index_id) FROM sys.indexes
                     WHERE object_id = OBJECT_ID('Sales.SalesOrderDetail') AND type = 6);
GO
DROP INDEX NCCI_SalesOrderDetail ON Sales.SalesOrderDetail;   -- คืนสถานะเดิม
GO
```

**Expected (รันจริง, 2026-10-03):** 1 แถวแสดง `NCCI_SalesOrderDetail | NONCLUSTERED COLUMNSTORE | 9` และ 1 แถว rowgroup `0 | COMPRESSED | 121,317` — ข้อจำกัดที่เจอจริง: **คอลัมน์ computed (เช่น LineTotal) ใส่ columnstore ไม่ได้** (error 35307)

---

## 2. กายวิภาค: Rowgroup / Segment / Deltastore

**นิยามก่อนใช้:**

| ศัพท์ | นิยาม |
|:------|:------|
| **Rowgroup** | กลุ่มแถว "เรียงกันตามการ insert" จำนวนสูงสุด **1,048,576 แถว (TM 1M)** — หน่วยที่ engine บีบอัด/ลบ/อ่านร่วมกัน |
| **Segment** | ข้อมูล **คอลัมน์เดียว** ของ rowgroup หนึ่ง (บีบอัดแล้ว) — หน่วย I/O ที่เล็กที่สุดของ columnstore; rowgroup 1M แถว × 4 คอลัมน์ = 4 segments |
| **Deltastore** | "ห้องรอ" แบบ B-Tree สำหรับแถวที่มาทีละน้อย (น้อยกว่า ~102,400 แถวต่อ batch) — rowgroup สถานะ **OPEN** รอการบีบ |
| **Tuple Mover** | background process ที่ย้าย rowgroup OPEN ที่เต็ม (ถึง 1,048,576) ไปบีบเป็น COMPRESSED |
| **Deleted bitmap** | แถวที่ลบจาก compressed rowgroup ถูก mark ใน bitmap (logical delete) — segment แก้ตรงไม่ได้ |

สร้างตารางทดสอบ 2.2 ล้านแถวจาก SalesOrderDetail (คูณ multiplier) พร้อม CCI แบบ MAXDOP 1 เพื่อให้ rowgroup เรียงตามการ insert พอดี:

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.CsOrders;
GO
CREATE TABLE dbo.CsOrders
(
    Seq        BIGINT IDENTITY NOT NULL,
    OrderDate  DATE NOT NULL,
    ProductID  INT  NOT NULL,
    OrderQty   SMALLINT NOT NULL,
    LineTotal  MONEY NOT NULL
);
GO
INSERT dbo.CsOrders (OrderDate, ProductID, OrderQty, LineTotal)
SELECT TOP (2200000)
    DATEADD(DAY, (sod.SalesOrderDetailID * m.m % 1125), CAST('2013-05-31' AS DATE)),
    sod.ProductID, sod.OrderQty, sod.LineTotal
FROM Sales.SalesOrderDetail AS sod
CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),(7),(9),(10),(11),(12),(13),(14),(15),(16),(17),(18),(19)) AS m(m)
ORDER BY sod.SalesOrderDetailID * m.m;
GO
CREATE CLUSTERED COLUMNSTORE INDEX CCI_CsOrders ON dbo.CsOrders WITH (MAXDOP = 1);
GO
SELECT rg.row_group_id, rg.state_description, rg.total_rows, rg.deleted_rows,
       rg.size_in_bytes / 1048576.0 AS size_mb
FROM sys.column_store_row_groups AS rg
WHERE rg.object_id = OBJECT_ID('dbo.CsOrders')
ORDER BY rg.row_group_id;
GO
```

**Expected (รันจริง, 2026-10-03 — build รวม ~20 วินาที):**

| row_group_id | state_description | total_rows | deleted_rows | size_mb |
|-------------:|:------------------|-----------:|-------------:|--------:|
| 0 | COMPRESSED | 1,048,576 | 0 | 4.36 |
| 1 | COMPRESSED | 1,048,576 | 0 | 4.26 |
| 2 | COMPRESSED | 86,554 | 0 | 0.39 |

อ่านผล:

1. **2,183,706 แถว (~2.2 ล้าน) = 2 rowgroup เต็ม 1,048,576 + เศษ 86,554** — เศษถูกบีบเลยตอน CREATE (แถวจาก `CREATE`/bulk insert มากกว่า 102,400 ต่อ batch จะ "บีบทันที" ไม่ไป deltastore)
2. แถวจุสูงสุดของ rowgroup คือ **TM 1M** — ตัวเลข 1,048,576 = 2²⁰ ตรง ๆ ทุก rowgroup เต็ม
3. size_mb ~4.3 ต่อ 1M แถว (ข้อมูล 4 คอลัมน์) — เทียบกับ rowstore ในหัวข้อ 7

### 2.1 Segment ต่อคอลัมน์ — แผนที่ min/max

```sql
USE AdventureWorks;
GO
-- แผนที่ segment ของคอลัมน์ Seq — หมายเหตุ: sys.column_store_segments ไม่มีคอลัมน์ชื่อ
-- ต้อง join sys.columns ผ่าน column_id (และต้องมี VIEW DATABASE STATE)
SELECT rg.row_group_id, c.name AS column_name,
       cs.min_data_id, cs.max_data_id, cs.row_count,
       cs.on_disk_size / 1024 AS segment_kb
FROM sys.column_store_segments AS cs
JOIN sys.partitions AS p ON p.partition_id = cs.partition_id
JOIN sys.columns AS c ON c.object_id = p.object_id AND c.column_id = cs.column_id
JOIN sys.column_store_row_groups AS rg
    ON rg.object_id = p.object_id AND rg.partition_number = p.partition_number
   AND rg.row_group_id = cs.segment_id
WHERE p.object_id = OBJECT_ID('dbo.CsOrders') AND c.name = 'Seq'
ORDER BY rg.row_group_id;
GO
```

**Expected (รันจริง, 2026-10-03):**

| row_group_id | column_name | min_data_id | max_data_id | row_count | segment_kb |
|-------------:|:------------|------------:|------------:|----------:|-----------:|
| 0 | Seq | 1 | 1,048,576 | 1,048,576 | 2,731 |
| 1 | Seq | 1,048,577 | 2,097,152 | 1,048,576 | 2,731 |
| 2 | Seq | 2,097,153 | 2,183,706 | 86,554 | 226 |

แผนที่นี้คือ "หัวใจ" ของ section ถัดไป — แต่ละ segment บันทึกค่า min/max ของคอลัมน์ตัวเอง และ `Seq` (identity ที่วิ่งตามลำดับการ insert) ทำให้ช่วงของแต่ละ rowgroup **ไม่ซ้อนกันเลย**

---

## 3. Segment Elimination — ข้ามข้อมูลที่ไม่เกี่ยวโดยไม่อ่าน

เมื่อ predicate กรองด้วยคอลัมน์ที่มี min/max ใน segment metadata — engine ตรวจ "ช่วงค้น อยู่ใน [min, max] ของ segment นี้ไหม" ถ้าไม่อยู่ → **ข้ามทั้ง segment โดยไม่อ่าน I/O เลย**:

```sql
USE AdventureWorks;
GO
SET STATISTICS IO ON;
-- (ก) Seq > 2,100,000 → มีเฉพาะ rowgroup 2 (2,097,153–2,183,706) ที่เกี่ยว
SELECT COUNT(*) FROM dbo.CsOrders WHERE Seq > 2100000;
-- (ข) Seq > 1 → ทุก rowgroup เกี่ยวหมด = ไม่มี elimination
SELECT COUNT(*) FROM dbo.CsOrders WHERE Seq > 1;
SET STATISTICS IO OFF;
GO
```

**Expected (รันจริง, 2026-10-03):**

| คิวรี | Actual Rows | Segment reads | Segment skipped | lob logical reads |
|:------|------------:|--------------:|----------------:|------------------:|
| (ก) `Seq > 2100000` | 83,706 | **1** | **2** | 30 |
| (ข) `Seq > 1` | 2,183,705 | 3 | 0 | 716 |

อ่านผล:

1. คิวรี (ก) อ่าน segment เดียว (ของ rowgroup 2) ข้ามอีก 2 — I/O ลดลง ~24 เท่า (30 vs 716 "lob logical reads" — columnstore นับ segment I/O ในช่อง LOB เพราะ segment อยู่ใน allocation unit LOB_DATA)
2. ช่อง `Segment reads / Segment skipped` ใน `SET STATISTICS IO` คือ "อากาศยานตรวจการ" ของ elimination — ถ้าคิวรี analytics หลักของระบบรายงาน skipped = 0 ตลอด แปลว่า "ข้อมูลไม่เรียงตามที่กรอง" — ออกแบบใหม่
3. คอลัมน์ที่ eliminate ได้ดี = คอลัมน์ที่ "ค่าเรียงตามเวลา/การ insert" (วันที่รายงาน, ID ที่เพิ่มขึ้น, partition key) — **ลำดับการ load สำคัญกว่าชนิดข้อมูล** (ถ้า load แบบสุ่ม แต่ละ rowgroup จะมี min/max ซ้อนกันหมด elimination พังทันที) — ทางแก้เชิงโครงสร้างคือ **ORDERED CLUSTERED COLUMNSTORE INDEX** (2019 ขึ้นไป — build แบบ sort ก่อนบีบ; ปี 2025 สร้าง ONLINE ได้)

> **จุดเชื่อมโยง:** นี่คือ "pruning" ระดับตารางใหญ่ คู่กับ **Partition Elimination** ที่ตัดตาม partition (Module 3) — columnstore elimination ละเอียดกว่า (ระดับ segment ~1M แถว) และตัดสินจาก "ค่าจริงในข้อมูล" ไม่ใช่นิยาม partition

---

## 4. Deltastore & Tuple Mover — ข้อมูลที่มาทีละน้อย

แถวที่ insert เป็น "ชุดเล็ก" (< ~102,400 แถวต่อ batch) ไม่ได้ถูกบีบทันที — มันเข้า **deltastore** (โครง B-Tree ซ่อนอยู่ใน CCI, rowgroup สถานะ OPEN) รอสะสมจนถึง 1,048,576 แถว Tuple Mover จะบีบเป็น COMPRESSED:

```sql
USE AdventureWorks;
GO
-- insert เล็ก ๆ หลังสร้าง CCI → ไปพักที่ deltastore
INSERT dbo.CsOrders (OrderDate, ProductID, OrderQty, LineTotal)
SELECT TOP (20000) DATEADD(DAY, sod.SalesOrderDetailID % 1125, '2013-05-31'),
       sod.ProductID, sod.OrderQty, sod.LineTotal
FROM Sales.SalesOrderDetail AS sod
ORDER BY sod.SalesOrderDetailID;
GO
SELECT rg.row_group_id, rg.state_description, rg.total_rows
FROM sys.column_store_row_groups AS rg
WHERE rg.object_id = OBJECT_ID('dbo.CsOrders')
ORDER BY rg.row_group_id;
GO
-- บังคับ Tuple Mover ทำงานทันที: ปิด OPEN rowgroup ให้เป็น COMPRESSED (SQL 2022+)
ALTER INDEX CCI_CsOrders ON dbo.CsOrders REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON);
GO
SELECT rg.row_group_id, rg.state_description, rg.total_rows
FROM sys.column_store_row_groups AS rg
WHERE rg.object_id = OBJECT_ID('dbo.CsOrders')
ORDER BY rg.row_group_id;
GO
```

**Expected (รันจริง, 2026-10-03):**

| หลัง INSERT | row_group_id | state_description | total_rows |
|:------------|-------------:|:------------------|-----------:|
| | 0–2 | COMPRESSED | (เหมือนเดิม) |
| | **3** | **OPEN** | 20,000 |

| หลัง REORGANIZE | row_group_id | state_description | total_rows |
|:----------------|-------------:|:------------------|-----------:|
| | 0–2 | COMPRESSED | (เหมือนเดิม) |
| | 3 | **TOMBSTONE** | 20,000 |
| | **4** | **COMPRESSED** | 20,000 |

อ่านผล:

1. **OPEN** = deltastore (B-Tree) — อ่านข้อมูลจากที่นี่ช้ากว่า compressed และไม่เข้าร่วม batch mode เต็มรูปแบบ — ระบบ DW ที่ load ทีละน้อยทั้งวันจะมี OPEN rowgroup จำนวนมากจนกระทบประสิทธิภาพ
2. `COMPRESS_ALL_ROW_GROUPS = ON` (2022+) คือ "เรียก Tuple Mover มาทำทันที" — เก่าเปลี่ยนเป็น **TOMBSTONE** (ป้าย "รอถูกลบจริงโดย background") และก้อนใหม่บีบเสร็จทันที — ใช้หลัง ETL ที่ load ได้เศษ ๆ รอบสุดท้าย
3. ปกติ (ไม่บังคับ) Tuple Mover บีบเมื่อ deltastore เต็ม 1,048,576 แถว หรือตามงาน background — ไม่ต้องตั้งเวลาเอง

---

## 5. การลบ/อัปเดต — Deleted Bitmap และเกณฑ์ Reclaim

Compressed segment **แก้ตรงไม่ได้** — การลบแถวจึงเป็น "mark" ใน deleted bitmap (logical delete) และการ update = delete + insert ใหม่ผ่าน deltastore นี่คือเหตุผลที่ CCI **ไม่ใช่** สำหรับตารางที่แก้รายแถวรัว ๆ (เช่น master data) แต่สำหรับ fact table ที่ load ทีละก้อน + ลบทีละก้อน มันจัดการได้ดี:

```sql
USE AdventureWorks;
GO
-- ลบแถวทั้งหมดของ rowgroup เล็ก (20,000 แถวที่เพิ่ง insert — Seq 2,183,707+)
DELETE dbo.CsOrders WHERE Seq > 2183706;
GO
SELECT rg.row_group_id, rg.state_description, rg.total_rows, rg.deleted_rows
FROM sys.column_store_row_groups AS rg
WHERE rg.object_id = OBJECT_ID('dbo.CsOrders')
ORDER BY rg.row_group_id;
GO
-- REORGANIZE = defragment แบบ online: นำ rowgroup ที่ถูกลบ 100% ออกจริง
ALTER INDEX CCI_CsOrders ON dbo.CsOrders REORGANIZE;
GO
SELECT rg.row_group_id, rg.state_description, rg.total_rows, rg.deleted_rows
FROM sys.column_store_row_groups AS rg
WHERE rg.object_id = OBJECT_ID('dbo.CsOrders')
ORDER BY rg.row_group_id;
GO
```

**Expected (รันจริง, 2026-10-03):**

หลัง DELETE (จากสถานะหัวข้อ 4):

| row_group_id | state_description | total_rows | deleted_rows |
|-------------:|:------------------|-----------:|-------------:|
| 0 | COMPRESSED | 1,048,576 | 0 |
| 1 | COMPRESSED | 1,048,576 | 0 |
| 2 | COMPRESSED | 86,554 | 0 |
| 3 | TOMBSTONE | 20,000 | — |
| 4 | COMPRESSED | 20,000 | **20,000** |

หลัง REORGANIZE:

| row_group_id | state_description | total_rows | deleted_rows |
|-------------:|:------------------|-----------:|-------------:|
| 0 | COMPRESSED | 1,048,576 | 0 |
| 1 | COMPRESSED | 1,048,576 | 0 |
| 2 | TOMBSTONE | 86,554 | 0 |
| 3 | TOMBSTONE | 20,000 | — |
| 5 | **COMPRESSED** | 86,554 | 0 |

อ่านผล:

1. **RG4 ที่ถูกลบ 100% หายไปจริง** หลัง REORGANIZE — ความจุ I/O คืนทันที
2. RG2 (86,554 แถว ไม่มีการลบเลย) ถูก "บีบใหม่" เป็น RG5 และของเก่ากลายเป็น TOMBSTONE — REORGANIZE บน CCI ไม่ได้แค่เก็บศพ แต่จัด rowgroup ให้แน่นขึ้นด้วย (TOMBSTONE ถูกเคลียร์โดย background process)
3. เกณฑ์ที่ต้องจำ: REORGANIZE จะกวาด "แถวที่ถูกลบ" ออกจาก rowgroup เมื่อถูกลบ **≥ ~10% ของ rowgroup** (ลบหลักสิบ ๆ แถวจากก้อน 1M อย่างเราในการทดลองก่อนหน้า ยังค้างอยู่ใน bitmap ได้) — ถ้าตารางถูกลบหนักทั้งปี วางแผน `REORGANIZE` ตามรอบหรือใช้ `REBUILD` ครั้งใหญ่รายช่วง

> [!IMPORTANT]
> แนวปฏิบัติ: ลบ fact table แบบ "ทั้ง rowgroup/partition" ตลอดเท่าที่ออกแบบได้ (เช่น ลบข้อมูลเกิน 5 ปี = ลบทับช่วง rowgroup) — แทนที่จะลบแถวกระจายทั้งตารางแล้วไล่เก็บ bitmap

---

## 6. Batch Mode Execution — CPU ทำงานเป็น "เวกเตอร์"

Row mode ประมวลผลแถวทีละแถว (แต่ละ operator เรียกต่อกันทีละ 1 แถว — overhead ระดับ instruction สูง) — **Batch mode** ประมวลผลทีละชุด ~**900 แถว** เป็น vector ต่อคอลัมน์ ค่า overhead ต่อแถวลดลงมาก เหมาะกับ operator ที่นิยามได้แบบคอลัมน์ (Scan, Hash Join, Hash Aggregate, Filter, Sort...)

ตรวจด้วยคิวรีเดียวกับที่สาธิตทั่วหลักสูตร:

```sql
USE AdventureWorks;
GO
SET STATISTICS IO, TIME ON;
SELECT ProductID, COUNT_BIG(*) AS cnt, SUM(OrderQty) AS total_qty
FROM dbo.CsOrders
WHERE OrderDate >= '2016-01-01'
GROUP BY ProductID;
SET STATISTICS IO, TIME OFF;
GO
```

**Expected (รันจริง, 2026-10-03):**

```
Table 'CsOrders'. Segment reads 3, segment skipped 0.
Table 'CsOrders'. lob logical reads 466, ...
 CPU time = 16 ms,  elapsed time = 16 ms.
```

รวม 2.2 ล้านแถว, filter + group by — **16 ms** ทั้งคิวรี เพราะสามกลไกซ้อนกัน: (1) segment elimination + บีบอัดทำให้ I/O รวม 466 "lob reads" (เทียบตาราง rowstore เดียวกันจะหลักหมื่น), (2) batch mode ทำ aggregate ทีละ ~900 แถว, (3) dictionary encoding ทำ SUM/COUNT บน "ตัวเลขเล็ก" แทนค่าจริง

เปิดดูใน SSMS (Ctrl+M): แต่ละ operator ของ plan นี้รายงาน **Actual Execution Mode = Batch** — ตรวจจาก plan XML ก็ได้ (`EstimatedExecutionMode="Batch"` ในแท็ก operator ทุกตัว) — ถ้าคิวรีของคุณที่ลงบน CCI ยังรายงาน Row ตลอด ตรวจ: (1) rowgroup ส่วนใหญ่ยัง OPEN? (2) operator ที่ไม่รองรับ batch mode? (3) ปิด batch mode ด้วย hint/compat หรือเปล่า?

---

## 7. Compression — ทำไม 101.6 MB กลายเป็น 11.3 MB

เทคนิคหลักสามชั้นที่ทำงานร่วมกัน:

| เทคนิค | แนวคิด | เหมาะกับ |
|:--------|:--------|:----------|
| **Dictionary Encoding** | ค่าซ้ำ ๆ ถูกแทนด้วย "รหัสสั้น" ที่ชี้ลง dictionary ของ segment | ProductID, OrderDate (ค่าไม่ซ้ำน้อยกว่าแถว) |
| **Run-Length (RLE)** | ค่าซ้ำ "ต่อเนื่องกัน" ถูกเก็บเป็น (ค่า, จำนวน) | คอลัมน์ที่เรียง/เก็บแบบกลุ่ม |
| **Bit-packing** | จำนวนเต็มเก็บเท่ากับจำนวน bit ที่จำเป็นจริง | รหัส dictionary, ค่า range เล็ก |

วัดจริง — คัดลอกข้อมูล 2.2 ล้านแถวเดียวกันลง rowstore (heap) แล้วเทียบขนาด:

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.CsOrders_Rowstore;
GO
SELECT * INTO dbo.CsOrders_Rowstore FROM dbo.CsOrders;   -- ข้อมูลชุดเดียวกัน แบบ rowstore
GO
SELECT OBJECT_NAME(object_id) AS table_name,
       (SUM(in_row_used_page_count) + SUM(lob_used_page_count)
        + SUM(row_overflow_used_page_count)) * 8 / 1024.0 AS total_mb
FROM sys.dm_db_partition_stats
WHERE object_id IN (OBJECT_ID('dbo.CsOrders'), OBJECT_ID('dbo.CsOrders_Rowstore'))
GROUP BY object_id;
GO
DROP TABLE dbo.CsOrders_Rowstore;
GO
```

**Expected (รันจริง, 2026-10-03):**

| table_name | total_mb |
|:-----------|---------:|
| CsOrders (CCI) | 11.31 |
| CsOrders_Rowstore | 101.59 |

~**9 เท่า** — สอดคล้องช่วง 10x ที่เอกสาร Microsoft ระบุ (ข้อมูลที่ค่าซ้ำหนาแน่นมากอาจถึง 100x; ข้อมูลสุ่มจริง ๆ ลดลงน้อยกว่า) — สิ่งที่ "แถม" มาจากการบีบอัด: ข้อมูลเล็กลง = อ่าน I/O น้อยลง = buffer pool จุข้อมูลได้เยอะขึ้น (Module 4) — นี่คือเหตุผลที่ columnstore เร็วไม่ใช่แค่เรื่อง CPU

จบการทดลอง — ล้างตารางทดสอบ (คืนสถานะเดิมของ database):

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.CsOrders;   -- ตารางทดสอบของ section นี้ (2.2 ล้านแถว)
GO
```

> [!TIP]
> ต้องการประหยัดไฟล์สุด ๆ สำหรับ archive: `COLUMNSTORE_ARCHIVE` compression (บีบเพิ่ม อืดกว่าตอนถอด) ใช้กับ partition เก่าที่อ่านนาน ๆ ครั้ง

---

## 8. ข้อจำกัด & ฟีเจอร์ใหม่ใน SQL Server 2025

### 8.1 ข้อจำกัดที่เจอจริงบ่อยที่สุด

| ข้อจำกัด | ผล / ทางเลือก |
|:----------|:----------------|
| **PK/FK บังคับ unique บน CCI ไม่ได้** | สร้าง PK แบบ **nonclustered** คู่กับ CCI (ทำงานแบบ B-Tree เล็ก ๆ พา key) — referential integrity ยังใช้ได้ |
| **คอลัมน์ computed ใส่ไม่ได้** | error 35307 (เจอจริงในหัวข้อ 1.1 กับ `LineTotal`) |
| คอลัมน์ string segment คงที่นาน (min/max เก่า) จัดการยากก่อน 2019 | ใช้ **string/varchar min-max** จาก 2019+ และ ORDERED CCI |
| แก้ทีละแถวบ่อย = deltastore + bitmap บวม | แยก hot table เก็บ rowstore, ใช้ NCCI สำหรับ analytics (HTAP) |
| จำนวนคอลัมน์สูงสุด 1,024 ต่อ rowgroup | เกินจริงไม่ถึง — แต่คอลัมน์ที่ไม่เคยใช้กรอง/สรุป ยังทำ segment ขยายโดยไม่จำเป็น |

### 8.2 ฟีเจอร์ 2025 ที่เกี่ยวกับ Columnstore

- **Ordered Nonclustered Columnstore Index** — เทคนิคเรียง segment เพื่อ elimination มาถึงฝั่ง NCCI (ก่อนหน้ามีเฉพาะ CCI)
- **Ordered CCI build แบบ ONLINE** — สร้าง/สลับ ordered CCI บนตารางที่ทำงานอยู่ได้ พร้อมคุณภาพ sort ที่ดีขึ้น — ปิดช่องว่างเดิมที่ build ordered ต้องออฟไลน์
- **Batch mode กับ built-in functions เพิ่มขึ้น** (เช่น math functions, DATETRUNC) — คิวรีที่เคย "ตกลง Row mode" ตรงจุด expression เริ่มคง Batch mode ได้ทั้ง plan
- SHRINK ทำงานดีขึ้นเมื่อ database มี CCI อยู่ (ก่อนหน้านี้เสี่ยงชนกับ segment บีบอัด)

อ้างอิง: [Columnstore indexes — what's new](https://learn.microsoft.com/sql/relational-databases/indexes/columnstore-indexes-what-s-new) · [What's new in SQL Server 2025](https://learn.microsoft.com/sql/sql-server/what-s-new-in-sql-server-2025)

---

## 9. เชื่อมโยงไปข้างหน้า

| โมดูล / Section | ใช้อะไรจาก section นี้ |
|:-----------------|:------------------------|
| Module 7 (Query Execution) | อ่าน plan ของ CCI: Columnstore Index Scan (Batch mode) vs Row mode, และ Estimated/Actual ของ segment scan |
| Module 8 (Plan Caching) | Batch mode + memory grant ของ hash aggregate บน CCI — grant ผิดจะ spill ต่างจาก rowstore |
| Module 10 (Monitoring) | `sys.column_store_row_groups` (OPEN/TOMBSTONE สะสม) เป็นสัญญาณของ maintenance ที่ต้องทำ |
| Module 11 (Troubleshooting) | คิวรี DW ช้า → เช็กลิสต์: rowgroup เต็มไหม, segment skipped = 0 ไหม, batch mode ตกไหน, deleted_rows สะสมแค่ไหน |

---

## สรุป Section 6.3

1. **CCI = บ้านหลักของตาราง (DW)** / **NCCI = ชั้น analytics ทับ rowstore (HTAP)** — ข้อจำกัดจริง: computed column ใส่ไม่ได้ (error 35307)
2. โครง: **Rowgroup (≤ 1,048,576 แถว = TM 1M) → Segment ต่อคอลัมน์** พร้อม metadata min/max; insert เล็กเข้า **deltastore (OPEN)** รอ **Tuple Mover** บีบ (บังคับได้ด้วย `REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON)` 2022+, เก่าเป็น TOMBSTONE)
3. **Segment elimination** อ่านเฉพาะ segment ที่ min/max ครอบ predicate (ทดสอบจริง: 1 read / 2 skipped, I/O ลด ~24 เท่า) — ลำดับการ load กำหนดคุณภาพ elimination
4. ลบ = deleted bitmap; REORGANIZE นำ rowgroup ที่ลบ 100% ออกจริงและกวาดแถวที่ลบเมื่อ ≥ ~10%
5. **Batch mode (~900 แถว/ชุด)** ทำ aggregate 2.2 ล้านแถวใน 16 ms เมื่อรวมกับ compression (101.59 → 11.31 MB ≈ 9 เท่า)
6. 2025: Ordered NCCI, ordered CCI build online, batch mode รองรับ function เพิ่ม

### ตรวจความเข้าใจ

1. ตาราง 2,200,000 แถวสร้าง CCI แล้วได้ rowgroup 1,048,576 + 1,048,576 + 86,554 — อธิบายทั้งเรื่อง TM 1M และเหตุที่ "เศษ" ถูกบีบทันทีตอน CREATE แต่ insert 20,000 แถวหลังจากนั้นกลับไป OPEN (deltastore)
2. จาก segment map ของ Seq (1–1,048,576 / 1,048,577–2,097,152 / 2,097,153–2,183,706) — คิวรี `WHERE Seq BETWEEN 2100000 AND 2150000` จะ read กี่ segment skip กี่ segment และเพราะอะไร
3. เพื่อนนำเข้าข้อมูลรายวันแบบ "insert ทีละ 5,000 แถวทั้งวัน" บน CCI และ complaint ว่าคิวรีรายงานช้าลงเรื่อย ๆ — ระบุสาเหตุจากสถานะ rowgroup และ 3 ทางแก้ (ระบุคำสั่งจริง)
4. ลบ 10,000 แถวจาก rowgroup 1 ล้านแถว แล้วรัน REORGANIZE แต่ `deleted_rows` ยังค้าง — อธิบายด้วยกลไก deleted bitmap + เกณฑ์ ~10% ว่าทำไม และแนวปฏิบัติที่ถูกต้องคืออะไร
5. เทียบ CCI กับ NCCI: ตารางออเดอร์ของระบบขายหน้าร้าน (แก้ทีละแถวบ่อย + มีรายงานวิเคราะห์ทุกชั่วโมง) ควรใช้โครงใด เพราะอะไร — และข้อจำกัดเรื่อง PK ของ CCI แก้ด้วยวิธีใด
6. คิวรีที่ลง CCI แต่รายงาน Actual Execution Mode = Row — ระบุ 3 สาเหตุที่ควรเช็กตามลำดับ

**➡ ถัดไป:** [Module 07 — Query Execution](../../Module_07_Query_Execution/README.md)

---

[⬅ Module 06](../../README.md) | [🧪 Labs](../../Labs/README.md) | [🧩 Quiz Bank](../../Quiz_Bank.md) | ➡ [Module 07](../../Module_07_Query_Execution/README.md)
