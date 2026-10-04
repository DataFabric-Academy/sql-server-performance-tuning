[⬅ Module 06](../../README.md) | Section 1/3 | ➡ ถัดไป: [02 Index Internals](../02_Index_Internals/README.md)

# 6.1 Statistics & Cardinality Estimation — ข้อมูลสถิติที่ Optimizer ใช้ "เดา" ก่อนรันทุกคิวรี

> *"Optimizer ไม่เคยเห็นข้อมูลจริงก่อนรัน — มันตัดสินใจทุกอย่างจากข้อมูลสถิติที่จดไว้ล่วงหน้า สถิติที่เก่าคือ GPS ที่ใช้แผนที่ปี 2010 นำทาง รถยนต์ปี 2025"*

> **ต้องรู้มาก่อน**: [Cardinality Estimation (CE)](../../../Glossary.md), [Statistics](../../../Glossary.md), [DMV / DMF](../../../Glossary.md), [Execution Plan](../../../Glossary.md) — จุดที่ Optimizer "ดู Statistics แล้วสร้าง Plan" จากแผนภาพ Module 1 (Section 1.1) และการอ่าน plan จาก Module 7 จะง่ายขึ้นมากถ้าผ่าน section นี้ก่อน
> **Permission ที่ต้องมี**: `VIEW DATABASE STATE` สำหรับอ่าน `sys.stats` / `sys.dm_db_stats_properties`; `DBCC SHOW_STATISTICS` ใช้ได้กับสมาชิก `db_owner` หรือเจ้าของวัตถุ

---

## ทำไม Section นี้จึงต้องมาก่อนในโมดูล Statistics & Index

ย้อนไปที่แผนภาพ [Module 1 — Engine Architecture](../../Module_01_Architecture_Scheduling_Waits/Sections/01_Engine_Architecture_SQLOS/README.md): เมื่อคิวรีเข้ามาและ **ไม่มี Plan อยู่ใน Plan Cache** Query Optimizer จะ "วิเคราะห์ (ดู Statistics) แล้วสร้าง Plan ใหม่" คำว่า "ดู Statistics" สามบรรทัดนั้นคือหัวใจทั้งหมดของ section นี้ — เพราะตัวเลขที่ optimizer เดาออกมา (**Cardinality Estimation, CE**) เป็น input ของการเลือกทุกอย่างที่เราจะเรียนใน Module 7:

- **Seek หรือ Scan?** — ตัดสินจากประมาณการว่า predicate จะได้กี่แถว
- **Join แบบไหน?** — Nested Loops (เหมาะกับ input เล็ก), Hash, Merge (เหมาะกับ input ใหญ่) — ตัดสินจาก CE สองฝั่ง
- **Memory Grant เท่าไร?** — sort/hash ต้องกิน workspace memory ตามจำนวนแถวที่ประมาณได้

ถ้า CE ผิด → ทั้งสามการตัดสินใจพลาดไปด้วย แม้ index จะถูกออกแบบมาดีแค่ไหน (Section 6.2) ก็อาจถูก optimizer "เหยียบ" ผ่านหรือไม่ใช้เลย

เส้นทางของ Section:

1. **Statistics ทำหน้าที่อะไร** — สะพานระหว่าง "ข้อมูลบนดิสก์" กับ "การตัดสินใจของ Optimizer"
2. **กายวิภาค 3 ส่วน: Header / Density Vector / Histogram** — อ่านของจริงจาก AdventureWorks
3. **อ่าน Histogram อย่างมืออาชีพ** — ตัวเลขแม่นตรง step, เพี้ยนนอก step (ทดสอบจริงให้เห็น)
4. **Cost-Based Optimization & Selectivity** — ภาษาที่ optimizer คุยกัน
5. **Legacy CE vs New CE** — สมมติฐาน 4 ข้อ + ทดสอบ ascending key + ฟีเจอร์ IQP ปี 2022–2025
6. **Stale Statistics & Auto-Update Thresholds** — เกณฑ์ยิง auto-update แบบเกาะตัวเลขจริง
7. **จัดการ Statistics มืออาชีพ** — UPDATE STATISTICS, sampling ค้างไว้, AUTO_DROP, และการเฝ้าระวัง

> **หมายเหตุสภาพแวดล้อม:** ตัวเลข Expected ทั้งหมดรันจริงบน VM หลักสูตร (SQL Server 2025 RTM-GDR 17.0.1135.8, ฐานข้อมูล `AdventureWorks`, 2026-10-03) — หาก VM ของคุณใช้ชื่อ `AdventureWorks2022`/`AdventureWorks2025` ให้แก้ชื่อในคำสั่ง `USE` และค่า `last_updated` / จำนวนแถวจะต่างเล็กน้อยตามประวัติ workload ของ VM นั้น

---

## 1. Statistics ทำหน้าที่อะไร — สะพานจากข้อมูลสู่การตัดสินใจ

**นิยามก่อนใช้:** **Statistics** คือวัตถุ (object) ที่ SQL Server เก็บ "ข้อมูลสรุปการกระจายตัว (distribution) ของค่าในคอลัมน์หนึ่ง หรือคอลัมน์หลายคอลัมน์เรียงกัน" เพื่อให้ Optimizer ประมาณจำนวนแถวที่ predicate จะคัดได้ โดยไม่ต้องไปอ่านข้อมูลจริง

เกิดขึ้นได้ 3 ทาง:

| ทาง | เมื่อไร | ชื่อที่เจอในระบบ |
|:----|:--------|:----------------|
| ตอน **สร้าง index** | `CREATE INDEX` สร้าง stats ของ key ทันที (แบบ full scan) | ชื่อเดียวกับ index เช่น `IX_SalesOrderDetail_ProductID` |
| **Auto Create** | คิวรีอ้างคอลัมน์ใน predicate ที่ยังไม่มี stats (ต้อง `AUTO_CREATE_STATISTICS = ON` — ค่า default) | `_WA_Sys_0000000B_...` (ชื่ออัตโนมัติจาก column id) |
| **สร้างเอง** | `CREATE STATISTICS` สำหรับคอลัมน์ที่ไม่ใช่ key แต่ถูกกรองบ่อย | ชื่อที่เราตั้ง |

ตรวจดูของจริง — ตาราง `Sales.SalesOrderDetail` (121,317 แถว) มี stats อะไรบ้าง พร้อมข้อมูลสถานะจาก `sys.dm_db_stats_properties` (DMF ที่อ่านพร็อพเพอร์ตี้ล่าสุดของแต่ละ stats — ใช้เป็นเครื่องมือหลักแทน `DBCC SHOW_STATISTICS` เมื่อต้องการค่าเป็นตาราง):

```sql
USE AdventureWorks;
GO
SELECT s.name AS stats_name,
       s.auto_created, s.user_created,
       sp.last_updated, sp.rows, sp.rows_sampled, sp.steps,
       sp.modification_counter, sp.persisted_sample_percent
FROM sys.stats AS s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
WHERE s.object_id = OBJECT_ID('Sales.SalesOrderDetail')
ORDER BY s.stats_id;
GO
```

**Expected (รันจริง, 2026-10-03):**

| stats_name | auto_created | last_updated | rows | rows_sampled | steps | modification_counter |
|:-----------|:-------------|:-------------|-----:|-------------:|------:|---------------------:|
| PK_SalesOrderDetail_SalesOrderID_SalesOrderDetailID | 0 | 2025-11-14 | 121,317 | 121,317 | 155 | 0 |
| AK_SalesOrderDetail_rowguid | 0 | 2025-11-14 | 121,317 | 121,317 | 45 | 0 |
| IX_SalesOrderDetail_ProductID | 0 | 2025-11-14 | 121,317 | 121,317 | 200 | 0 |
| _WA_Sys_00000006_11158940 | 1 | 2025-11-14 | 121,317 | 109,224 | 12 | 0 |
| _WA_Sys_00000002_11158940 | 1 | 2026-10-02 | 121,317 | 114,582 | 84 | 0 |
| _WA_Sys_00000004_11158940 | 1 | 2026-10-02 | 121,317 | 74,305 | 34 | 4 |
| ... (auto-created ตามคอลัมน์ที่ workload เคยกรอง) | | | | | | |

อ่านผลแบบมืออาชีพ:

1. **3 แถวแรก = ของ index** (PK, AK, IX) — ถูกสร้างตอน `CREATE INDEX` ด้วย full scan (`rows_sampled` = `rows` พอดี)
2. **แถว `_WA_Sys_*` = auto-created** — เกิดเองเมื่อ workload กรองคอลัมน์ที่ไม่มี index และถูก **sample** บางส่วน (เช่น 109,224 / 121,317 ≈ 90%) — สังเกตว่าแต่ละตัวถูกอัปเดต "คนละเวลา" ตามที่ workload ใช้มัน (คอลัมน์ id 4 มี `modification_counter = 4` คือมีแถวถูกแก้หลังอัปเดตล่าสุด 4 แถว)
3. `steps` = จำนวน histogram step (สูงสุด 200) — ใช้ต่อในหัวข้อ 3

> **จุดเชื่อมโยง:** `rows_sampled` ต่ำกว่า `rows` เยอะ ๆ คือข้อสังเกตแรกเสมอเมื่อ CE ผิดเพี้ยน — sample เยอะ = มองข้อมูลครบขึ้น (แต่แพงกว่าตอนอัปเดต) — จัดการในหัวข้อ 7

---

## 2. กายวิภาคของ Statistics — Header / Density Vector / Histogram

เครื่องมือดูเนื้อหาภายในแบบตำราเรียนคือ `DBCC SHOW_STATISTICS` — ให้ผล 3 result set ต่อชุดสถิติ:

```sql
USE AdventureWorks;
GO
-- คำสั่งหลัก: ได้ 3 result set (Header, Density Vector, Histogram)
DBCC SHOW_STATISTICS ('Sales.SalesOrderDetail', 'IX_SalesOrderDetail_ProductID');
GO
-- หรือเจาะเฉพาะส่วนที่สนใจ
DBCC SHOW_STATISTICS ('Sales.SalesOrderDetail', 'IX_SalesOrderDetail_ProductID') WITH STAT_HEADER, DENSITY_VECTOR;
GO
```

**Expected — Result Set 1: Header (รันจริง, 2026-10-03):**

| Name | Updated | Rows | Rows Sampled | Steps | Density | Average key length | ... |
|:-----|:--------|-----:|-------------:|------:|--------:|-------------------:|:----|
| IX_SalesOrderDetail_ProductID | Nov 14 2025 1:01PM | 121,317 | 121,317 | 200 | 0.0078125 | 12 | |

**Expected — Result Set 2: Density Vector (รันจริง):**

| All density | Average Length | Columns |
|:------------|---------------:|:--------|
| 0.003759398590 | 4 | ProductID |
| 8.242867806984E-08 | 8 | ProductID, SalesOrderID |
| 8.242867806984E-08 | 12 | ProductID, SalesOrderID, SalesOrderDetailID |

### 2.1 Header — ทะเบียนของชุดสถิติ

| คอลัมน์ | ความหมาย | ใช้วินิจฉัยอะไร |
|:--------|:---------|:----------------|
| `Updated` / `last_updated` | เวลาอัปเดตล่าสุด | จุดเริ่มของทุกการสงสัยว่า "stats เก่าไหม" |
| `Rows` vs `Rows Sampled` | จำนวนแถวตอนอัปเดต / จำนวนที่ถูกสุ่มอ่าน | sample < 100% = มองข้อมูลผ่านกรอบ อาจพลาด skew เล็ก ๆ |
| `Steps` | จำนวน histogram step (สูงสุด **200** เสมอ) | ข้อมูลที่มีค่าไม่ซ้ำ > 200 ต้อง "จัดกลุ่ม" อย่างหลีกเลี่ยงไม่ได้ |
| `Density` (ใน header) | ค่า legacy — **ไม่ถูกใช้แล้วตั้งแต่ SQL 2008** แต่ยังพิมพ์ให้ | อย่าใช้ตัดสิน — ใช้ Density Vector แทน |

### 2.2 Density Vector — ค่า "1 หารด้วยจำนวนค่าไม่ซ้ำ"

**Density** = `1 / (จำนวนค่าที่ไม่ซ้ำ)` — ตีความว่า "ถ้าสุ่มหยิบค่าหนึ่งมา คาดว่าแถวที่มีค่านั้นจะเป็นสัดส่วนเท่าไร"

- `ProductID` density = 0.003759398590 = **1/266** — ตรวจได้จริง: `SalesOrderDetail` มี ProductID ไม่ซ้ำ 266 ค่า → คิวรี `WHERE ProductID = @p` ที่ optimizer หาค่า @p ใน histogram ไม่เจอ จะประมาณ `121,317 × 0.003759398590 ≈ 456 แถว` (ตัวเลขเฉลี่ยต่อ product)
- แถวที่ 2–3 (`ProductID, SalesOrderID` ฯลฯ) ใช้กับคิวรีที่ GROUP BY หรือ join หลายคอลัมน์ — density เล็กมากเพราะคู่คอลัมน์นี้เกือบไม่ซ้ำเลย

### 2.3 Histogram — กราฟการกระจายตัว 200 ช่วง

**Histogram** แบ่งค่าทั้งหมดเรียงจากน้อยไปมากเป็น "steps" สูงสุด 200 ช่วง แต่ละ step เก็บ 5 ค่า:

| คอลัมน์ (ชื่อ DBCC / ชื่อ DMF) | ความหมาย |
|:-------------------------------|:----------|
| `RANGE_HI_KEY` / `range_high_key` | ค่าสูงสุดของช่วงนี้ (ค่าที่ histogram "จำได้ตรง ๆ") |
| `EQ_ROWS` / `equal_rows` | แถวที่มีค่า "เท่ากับ" RANGE_HI_KEY พอดี |
| `RANGE_ROWS` / `range_rows` | แถวที่อยู่ "ระหว่าง" step ก่อนหน้ากับ step นี้ (ไม่รวม HI_KEY) |
| `DISTINCT_RANGE_ROWS` / `distinct_range_rows` | ค่าไม่ซ้ำกี่ค่าในช่วงนั้น |
| `AVG_RANGE_ROWS` / `average_range_rows` | เฉลี่ยแถวต่อ 1 ค่าในช่วง = RANGE_ROWS / DISTINCT_RANGE_ROWS |

อ่าน histogram แบบสั่งเฉพาะส่วนด้วย DMF `sys.dm_db_stats_histogram` (ได้ผลเป็นตาราง จัดการต่อด้วย T-SQL ได้ — ชื่อคอลัมน์เป็น snake_case ต่างจาก DBCC):

```sql
USE AdventureWorks;
GO
-- histogram ของ IX_SalesOrderDetail_ProductID (stats_id = 3) — ดู 5 step แรก
SELECT TOP (5) step_number, range_high_key, equal_rows, range_rows,
       distinct_range_rows, average_range_rows
FROM sys.dm_db_stats_histogram(OBJECT_ID('Sales.SalesOrderDetail'), 3)
ORDER BY step_number;
GO
-- เทียบกับจำนวนแถวจริงของบาง product
SELECT ProductID, COUNT(*) AS actual_rows
FROM Sales.SalesOrderDetail
WHERE ProductID IN (707, 708, 709, 710, 711)
GROUP BY ProductID;
GO
```

**Expected (รันจริง, 2026-10-03):**

| step_number | range_high_key | equal_rows | range_rows | distinct_range_rows | average_range_rows |
|------------:|---------------:|-----------:|-----------:|--------------------:|-------------------:|
| 1 | 707 | 3083 | 0 | 0 | 1 |
| 2 | 708 | 3007 | 0 | 0 | 1 |
| 3 | 709 | 188 | 0 | 0 | 1 |
| 4 | 710 | 44 | 0 | 0 | 1 |
| 5 | 711 | 3090 | 0 | 0 | 1 |

| ProductID | actual_rows |
|----------:|------------:|
| 707 | 3,083 |
| 708 | 3,007 |
| 709 | 188 |
| 710 | 44 |
| 711 | 3,090 |

สังเกตสองอย่างที่ต้องจำ:

1. **EQ_ROWS ตรงกับจำนวนจริงเป๊ะ** ทุกค่า — เพราะข้อมูลชุดนี้มีค่าไม่ซ้ำ 266 ค่า < 200 steps × การกระจาย จน histogram จำได้ครบทุกค่า (แต่ละค่าได้ step ของตัวเอง, `range_rows = 0` ทุก step)
2. **Data skew รุนแรงระหว่าง step ติดกัน**: ProductID 710 มี 44 แถว แต่ 711 มี 3,090 แถว — ต่างกัน 70 เท่า! Histogram คือกลไกเดียวที่ทำให้ optimizer "รู้" ความต่างนี้ — ถ้าคิวรีหาค่า 711 มันจะได้ plan ต่างจากค่า 710 อย่างสิ้นเชิง และนี่คือต้นตอของ [Parameter Sniffing](../../../Glossary.md) ที่จะเจาะใน Module 8

---

## 3. อ่าน Histogram อย่างมืออาชีพ — ตรง step แม่น, นอก step เพี้ยน

หัวใจของการอ่าน histogram: **optimizer แม่นเฉพาะค่าที่เป็น `RANGE_HI_KEY`** ค่าอื่นต้อง "ประมาณเป็นเศษส่วนของช่วง" ลองพิสูจน์ด้วยคิวรีจริงสองตัว (ใช้ `OPTION (RECOMPILE)` เพื่อให้เห็นการประมาณของแต่ละคิวรีสด ๆ ไม่ติด plan เก่า — เจาะลึกการ recompile ใน Module 8):

```sql
USE AdventureWorks;
GO
SET STATISTICS XML ON;
-- (ก) 711 เป็น RANGE_HI_KEY ของ step 5 → อ่าน EQ_ROWS ตรง ๆ
SELECT COUNT(*) FROM Sales.SalesOrderDetail WHERE ProductID = 711 OPTION (RECOMPILE);
-- (ข) 897 ไม่ใช่ boundary ใด ๆ → ประมาณด้วย average_range_rows ของ step ที่ครอบมัน
SELECT COUNT(*) FROM Sales.SalesOrderDetail WHERE ProductID = 897 OPTION (RECOMPILE);
SET STATISTICS XML OFF;
GO
-- ดู step ที่ครอบค่า 897
SELECT step_number, range_high_key, equal_rows, range_rows, distinct_range_rows, average_range_rows
FROM sys.dm_db_stats_histogram(OBJECT_ID('Sales.SalesOrderDetail'), 3)
WHERE range_high_key IN (897, 898);
GO
```

**Expected (รันจริง, 2026-10-03):**

| คิวรี | Estimated Rows (จาก plan XML `EstimateRows`) | Actual Rows |
|:------|--------------------------------------------:|------------:|
| (ก) `ProductID = 711` | **3090** | 3,090 |
| (ข) `ProductID = 897` | **75.6667** | 2 |

step ที่ครอบค่า 897:

| step_number | range_high_key | range_rows | distinct_range_rows | average_range_rows |
|------------:|---------------:|-----------:|--------------------:|-------------------:|
| 131 | 898 | 227 | 3 | 75.6667 |

อ่านผล:

1. **(ก)** ค่าเป็น step boundary → estimate แม่น 100% (3,090 = 3,090) — นี่คือเคสดีสุดของ histogram
2. **(ข)** ค่า 897 ไม่มี step ของตัวเอง — มันหล่น "ใต้" step ที่มี HI_KEY = 898 ซึ่งบอกว่าช่วงนี้มี 227 แถวกระจายใน 3 ค่า → เฉลี่ย 75.67 แถว/ค่า → ประมาณ 75.6667 แต่จริงมีแค่ **2 แถว** (overestimation ~38 เท่า) — ข้อมูลจริง skew หนักจนค่าเฉลี่ย "โกหก" นี่คือข้อจำกัดโครงสร้างของ histogram 200 step ที่ต้องระลึกไว้เสมอ

> **แบบฝึกหัดคิด:** ถ้าคิวรีถูกเขียนเป็น `WHERE ProductID = @p` (parameterized) — CE จะใช้ค่าอะไร? คำตอบ: ค่าแรกที่ compile (parameter sniffing) — และ plan นั้นจะถูก reuse กับค่าอื่นทั้งหมด ถ้าค่าแรกเป็น 711 แต่คิวรีจริงวิ่งด้วย 897 เป็นหลัก อาการจะเป็นทางกลับของตารางข้างบน (Module 8)

---

## 4. Cost-Based Optimization & Selectivity — ภาษาของ Optimizer

Optimizer ทำงานแบบ **Cost-Based**: ไม่ได้หา "plan ที่ดีที่สุดในจักรวาล" แต่หา **"plan ที่ดีพอ (Good Enough Plan) ที่ต้นทุนต่ำสุด ภายในเวลา/ทรัพยากรที่ยอมให้ใช้"** — มันประเมินต้นทุนของ plan ที่เป็นไปได้หลายร้อยแบบโดยอิง "จำนวนแถวที่ไหลผ่านแต่ละ operator" ซึ่งก็คือ CE จาก section นี้

ศัพท์ที่ต้องพูดให้ถูก:

| ศัพท์ | นิยาม | ผลต่อ plan |
|:------|:------|:-----------|
| **Selectivity** | อัตราส่วนแถวที่ predicate คัดได้ต่อแถวทั้งหมด (0–1) | ค่าหลักที่ histogram/density ตอบ |
| **High Selectivity** | กรองแล้วเหลือน้อย (เช่น 0.1%) | เอื้อ Index Seek + Nested Loops |
| **Low Selectivity** | กรองแล้วได้มาก (เช่น 60%) | เอื้อ Index/Clustered Scan + Hash Join |
| **SARGable** | predicate ที่ optimizer ใช้ seek ได้ (`col = x`, `col > x`) | ดูต่อ Module 7 — `WHERE YEAR(col) = 2025` ไม่ SARGable |

สูตรคิดง่าย ๆ: `Estimated Rows = Rows × Selectivity` — โดย Selectivity มาจาก (1) EQ_ROWS ถ้าเจอใน histogram, (2) average_range_rows ถ้าหล่นในช่วง, (3) density × Rows ถ้าค่าไม่อยู่ใน histogram เลย หรือคิวรีเขียนด้วย expression/ตัวแปรที่อ่านตรง ๆ ไม่ได้

---

## 5. Legacy CE vs New CE — สมมติฐาน 4 ข้อและผลจริง

**Cardinality Estimation Model** (เครื่องยนต์เดาแถว) มีสองรุ่นใหญ่:

- **Legacy CE (70)** — รุ่นเดิมตั้งแต่ SQL Server 7.0 ใช้กับ database ที่ compat level ≤ 110
- **New CE (120+)** — เขียนใหม่ทั้งตัวสำหรับ SQL Server 2014 (compat level 120 ขึ้นไป) และมีการปรับต่อเนื่องใน 2017/2019/2022/2025 ผ่าน IQP

SQL Server 2025 ใช้ `CardinalityEstimationModelVersion = 170` — สมมติฐานต่างกัน 4 ข้อ:

| สมมติฐาน | Legacy CE | New CE |
|:---------|:----------|:-------|
| **Independence** | คอลัมน์ต่างกัน "อิสระต่อกัน" — เงื่อนไขซ้อน = คูณ selectivity | เข้าใจ **correlation** — คอลัมน์ที่เกี่ยวเนื่องกันไม่ถูกคูณลดจนเกินไป |
| **Uniformity** | ค่าในช่วง "กระจายสม่ำเสมอ" | รองรับ skewed data ดีขึ้น (แต่ก็ยังประมาณจาก average ของช่วง ดังตัวอย่าง 897) |
| **Containment** | Simple: ถือว่าค่าที่คิวรีค้น "มีอยู่จริง" ในตารางเสมอ | Base: เข้าใจว่า filter บางตัวอาจค้นค่า "ที่ไม่มี" ในข้อมูลจริง |
| **Ascending Key** | ค่าที่เพิ่มใหม่เกินค่า max ใน histogram ถูกประมาณแบบ "ไม่มีแถว" | มีการ "เดา" แถวใหม่ (ascending key adjustment) |

### 5.1 ทดสอบจริง: ปัญหา Ascending Key

ตารางที่ identity เพิ่มทีละแถว (รายการขาย, log) คือเคสคลาสสิก: histogram จำได้แค่ถึง max เก่า แถวใหม่ "อยู่นอกโลก" ของ histogram:

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.CELab;
GO
CREATE TABLE dbo.CELab (Id INT IDENTITY PRIMARY KEY, Val INT, Pad CHAR(50) DEFAULT 'x');
INSERT dbo.CELab (Val)
SELECT TOP (50000) ABS(CHECKSUM(NEWID())) % 10
FROM sys.all_objects AS a CROSS JOIN sys.all_columns AS b;
CREATE INDEX IX_CELab_Id ON dbo.CELab (Id);   -- stats จำ Id ได้ถึงแค่ 50,000
INSERT dbo.CELab (Val) SELECT TOP (1000) 99 FROM sys.all_objects;   -- แถว "อนาคต" Id 50,001–51,000
GO
SET STATISTICS XML ON;
-- Legacy CE: ประมาณแถวนอก histogram = 0 แถว
SELECT COUNT(*) FROM dbo.CELab WHERE Id > 50500
OPTION (RECOMPILE, USE HINT('FORCE_LEGACY_CARDINALITY_ESTIMATION'));
-- New CE (default): มีกลไกเดาแถวนอก histogram
SELECT COUNT(*) FROM dbo.CELab WHERE Id > 50500 OPTION (RECOMPILE);
SET STATISTICS XML OFF;
GO
DROP TABLE dbo.CELab;
GO
```

**Expected (รันจริง, 2026-10-03):**

| CE Model | Estimated Rows (`EstimateRows` ของ Index Scan) | Actual Rows |
|:---------|-----------------------------------------------:|------------:|
| Legacy CE (70) | **1** | 500 |
| New CE (170) | **500.99** | 500 |

Legacy CE ประมาณ 1 แถว (underestimation 500 เท่า) — ในระบบจริงแบบนี้แปลว่า optimizer จะเลือก Nested Loops/จัด memory grant น้อยเกินไป ส่วน New CE เดา 500.99 เกือบตรงเพราะมีกลไกประมาณการแถวนอก histogram ตั้งแต่รุ่น 2014 — ต่างจากยุคก่อนที่ต้องพึ่ง trace flag 2389/2390

### 5.2 เปลี่ยน CE Model ได้ 3 ระดับ

```sql
USE AdventureWorks;
GO
-- ระดับ Database (กลับทั้ง DB เป็น Legacy CE — ใช้เป็นทางแก้ชั่วคราวตอน upgrade เท่านั้น)
-- บน VM หลักสูตร "ไม่ต้องรัน" (ค่า default คือ OFF อยู่แล้ว) — เปิดใช้เฉพาะบน database ทดสอบที่คุณเป็นเจ้าของ:
-- ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = ON;
-- ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = OFF;  -- คืนค่า default
GO
-- ระดับ Query (hint) — รันได้ทันที
SELECT COUNT(*) FROM Sales.SalesOrderDetail
WHERE ProductID = 711
OPTION (USE HINT ('FORCE_LEGACY_CARDINALITY_ESTIMATION'));
GO
-- ระดับ Query Store Hint (SQL 2022+) — บังคับ "เฉพาะ query ที่มีปัญหา" โดยไม่แก้โค้ด
-- EXEC sp_query_store_set_hints @query_id = 123,
--      @query_hints = N'OPTION(USE HINT(''FORCE_LEGACY_CARDINALITY_ESTIMATION''))';
GO
-- สถานะ config ที่เกี่ยวกับ CE บน VM หลักสูตร
SELECT name, CAST(value AS INT) AS value
FROM sys.database_scoped_configurations
WHERE name IN ('CE_FEEDBACK', 'LEGACY_CARDINALITY_ESTIMATION', 'PARAMETER_SNIFFING');
GO
```

**Expected (รันจริง, 2026-10-03):**

| name | value |
|:-----|------:|
| LEGACY_CARDINALITY_ESTIMATION | 0 |
| PARAMETER_SNIFFING | 1 |
| CE_FEEDBACK | 1 |

### 5.3 ฟีเจอร์ CE ยุคใหม่ (IQP) — 2022 ถึง 2025

| ฟีเจอร์ | รุ่น | แก้ปัญหาอะไร |
|:---------|:-----|:--------------|
| **CE Feedback (model variation)** | 2022 (compat 160) | ตรวจว่า CE ประมาณเพี้ยนแบบซ้ำ ๆ ระหว่าง query แล้ว "เรียนรู้" ไปใช้ CE model ที่เหมาะกับ pattern นั้น (feedback object ภายใน, รีเซ็ตเมื่อ stats ถูกอัปเดต) |
| **CE Feedback for Expressions** | **2025** (compat 170) | ขยายไปถึง selectivity ของ **expression** ใน predicate เช่น `DATEDIFF`, `CONVERT` บนคอลัมน์ — เดิม optimizer เดา expression ไม่ได้เลย ต้องใช้ค่า guess คงที่ — 2025 ให้ engine เรียนรู้ค่า CE จริงจากการรันข้าม query แล้วใช้ซ้ำ (ละเอียดระดับ sub-expression ใช้ CE model คนละแบบในคิวรีเดียวกันได้) |
| **Persisted statistics for readable secondaries** | **2025** | เดิม readable secondary ของ Availability Group ใช้ stats ที่ sync จาก primary — workload ฝั่งอ่านที่ predicate คนละแบบได้ plan แย่เพราะ stats "ไม่รู้จัก" การกรองของตัวเอง — 2025 ให้ secondary **สร้าง/เก็บ stats ของฝั่ง read ได้เอง** |

> **จุดเชื่อมโยง:** ทั้งสามฟีเจอร์ทำงานเมื่อ **compat level 170** + `CE_FEEDBACK`/`AUTO_CREATE_STATISTICS` ตามที่เห็นในตาราง config — เงื่อนไขทั้งหมดเช็กได้ด้วยบล็อก SQL ใน 5.2 ส่วนการดู feedback เกิดจริงเจาะลึกด้วย Extended Events ใน Module 9

---

## 6. Stale Statistics — เกณฑ์ Auto-Update และการพิสูจน์ด้วยตัวเลขจริง

**Stale statistics** = histogram ที่ไม่สะท้อนข้อมูลปัจจุบัน เกิดเมื่อข้อมูลถูกแก้ (INSERT/UPDATE/DELETE) แต่ stats ยังไม่ถูกอัปเดต engine นับจำนวนแถวที่แก้ไว้ใน `modification_counter` และ **ยิง auto-update เฉพาะตอน query ถูก compile และใช้ stats นั้น** (ไม่ใช่ยิงเองตอน insert)

### 6.1 เกณฑ์ (Threshold) ของ Auto-Update

| รุ่น | เกณฑ์ | ผลกับตาราง 1 ล้านแถว |
|:-----|:------|:---------------------|
| **Legacy (≤ 2014)** | `20% + 500 แถว` (ตาราง < 500 แถว: แก้ ≥ 1 แถวก็ยิง) | ต้องแก้ ~200,500 แถว — ช้ามากสำหรับตารางใหญ่ |
| **Dynamic (2016+, compat 130+)** | ลดลงตามขนาดตาราง — ค่าที่ community ตรวจวัดพบคือ `SQRT(1000 × rows)` | SQRT(1000 × 1,000,000) = ~31,600 แถว — ยิงเร็วขึ้นหลายเท่า |
| **Temp table** | 6 แถวแรก ๆ (แก้ 6 แถวก็ยิง) — ออกแบบมาเพื่อ temp ที่เติมทีละนิด | ต่างจากตารางปกติสุด ๆ |

และสองกฎที่ต้องจำคู่กัน:

1. **Auto-update ไฟขึ้น "ตอน compile"** — ถ้า plan ถูก reuse (ไม่มีการ compile) แม้ threshold จะผ่านไปแล้วก็ไม่มีการตรวจ
2. **Sync (default) = คิวรีรออัปเดตเสร็จแล้วค่อยรัน** / **Async (`AUTO_UPDATE_STATISTICS_ASYNC = ON`) = คิวรีใช้ stats เก่าไปก่อน ให้ background อัปเดตตามหลัง** — async ลด latency spike แต่แลกกับ plan ที่ยังใช้ stats เก่าอีกรอบ

### 6.2 ทดสอบจริง: วัดเกณฑ์ของ Dynamic Threshold

สร้างตาราง 100,000 แถว (ทั้งหมด Status = 0) แล้วค่อย ๆ เติมแถว Status = 1 เพื่อดูว่า auto-update ยิงเมื่อไร:

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.AutoStatsLab;
GO
CREATE TABLE dbo.AutoStatsLab (Id INT IDENTITY, Status TINYINT, Pad CHAR(30) DEFAULT 'x');
INSERT dbo.AutoStatsLab (Status)
SELECT TOP (100000) 0 FROM sys.all_objects AS a CROSS JOIN sys.all_columns AS b;
CREATE INDEX IX_AutoStatsLab_Status ON dbo.AutoStatsLab (Status);   -- stats สร้างจาก 100,000 แถว
GO
INSERT dbo.AutoStatsLab (Status)
SELECT TOP (9000) 1 FROM sys.all_objects AS a CROSS JOIN sys.all_columns AS b;
SELECT COUNT(*) FROM dbo.AutoStatsLab WHERE Status = 1 OPTION (RECOMPILE);   -- บังคับ compile เพื่อ "ตรวจ" stale
GO
SELECT s.name, sp.rows, sp.modification_counter
FROM sys.stats s CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE s.object_id = OBJECT_ID('dbo.AutoStatsLab');
GO
```

**Expected (รันจริง, 2026-10-03):** estimated rows ของคิวรี = **330.151** ทั้งที่ actual = **9,000** — ส่วนตารางสถิติยังรายงาน `rows = 100,000, modification_counter = 9,000` (**ไม่ถูกอัปเดต**)

อ่านผล: แก้ไป 9,000 แถว — เกิน Legacy เกณฑ์ของตารางเล็กแต่ยังไม่ถึง dynamic threshold (~SQRT(1000 × 110,500) ≈ 10,500) → stats ยังเก่า → CE เดา 330.151 จาก histogram ที่มีแต่ค่า Status = 0 (ค่า 1 ไม่อยู่ใน histogram เลย จึงตกไปใช้ค่าเฉลี่ย) — underestimation ~27 เท่า

จากนั้นข้ามเกณฑ์ แล้ว compile ใหม่:

```sql
INSERT dbo.AutoStatsLab (Status)
SELECT TOP (2000) 1 FROM sys.all_objects AS a CROSS JOIN sys.all_columns AS b;  -- รวม 11,000 mods
GO
SET STATISTICS XML ON;
SELECT COUNT(*) FROM dbo.AutoStatsLab WHERE Status = 1 OPTION (RECOMPILE);
SET STATISTICS XML OFF;
GO
-- ตรวจว่า stats ถูกอัปเดตเอง "ตอน compile" จริง
SELECT s.name, sp.rows, sp.modification_counter
FROM sys.stats s CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE s.object_id = OBJECT_ID('dbo.AutoStatsLab');
GO
DROP TABLE dbo.AutoStatsLab;
GO
```

**Expected (รันจริง, 2026-10-03):** estimated rows = **11,000** = actual — และตารางสถิติรายงาน `rows = 100,000, modification_counter = 11,000` พร้อม `last_updated` = เวลาที่คิวรี compile (plan XML ที่คิวรีใช้จะบอกเอง: `OptimizerStatsUsage ... LastUpdate="เวลา compile" ModificationCount="0"` — หมายความว่า stats ถูกอัปเดตสด ๆ ใน compile นั้นก่อนใช้)

บทเรียนสามข้อจากการทดลอง:

1. **Threshold แบบ dynamic ต่างจาก 20%+500 อย่างมีนัยสำคัญ** — 9,000 แถวบนตารางแสนแถวยัง "เก่าได้" ในสายตา engine; ถ้าเป็น Legacy จะต้องแก้ถึง ~20,500 แถวก่อนยิง
2. **Auto-update ผูกกับ compile** — ในการทดลอง ถ้าเอา `OPTION (RECOMPILE)` ออก คิวรีรอบสองจะ reuse plan เดิม (compile ครั้งแรกที่ stats ยังเก่า) และไม่มีการตรวจ stale เลยจนกว่าจะมีเหตุให้ compile ใหม่
3. **อาการ stale stats ชัดเจนใน plan**: Estimated 330 vs Actual 9,000 — สอดคล้องกับแล็บ [Labs Exercise 3](../../Labs/README.md) ที่ estimated 223.83 vs actual 50,000 (underestimation → ตามมาด้วย spill/grant ไม่พอ)

---

## 7. จัดการ Statistics มืออาชีพ — เครื่องมือและแนวปฏิบัติ

### 7.1 UPDATE STATISTICS — ตัวเลือกที่ต้องรู้

```sql
USE AdventureWorks;
GO
-- อัปเดตแบบอ่านครบทุกแถว (แม่นสุด แพงสุด — เหมาะกับตารางกลาง/เล็ก หรือหลังโหลดข้อมูลก้อนใหญ่)
UPDATE STATISTICS Sales.SalesOrderDetail IX_SalesOrderDetail_ProductID WITH FULLSCAN;
GO
-- อัปเดตแบบสุ่ม 25% และ "จำ" อัตราสุ่มนี้ไว้ใช้ต่อ (SQL 2016 SP1 CU4+)
UPDATE STATISTICS Sales.SalesOrderDetail IX_SalesOrderDetail_ProductID
WITH SAMPLE 25 PERCENT, PERSIST_SAMPLE_PERCENT = ON;
GO
-- ตรวจผล: persisted_sample_percent = 25 ค้างไว้ แม้ auto-update ครั้งถัดไป
SELECT s.name, sp.rows, sp.rows_sampled, sp.persisted_sample_percent,
       CAST(100.0 * sp.rows_sampled / sp.rows AS DECIMAL(5,1)) AS actual_sample_pct
FROM sys.stats s CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE s.object_id = OBJECT_ID('Sales.SalesOrderDetail')
  AND s.name = 'IX_SalesOrderDetail_ProductID';
GO
-- คืนสถานะเดิมของ database (ยกเลิก persist + อัปเดตครบทุกแถว)
UPDATE STATISTICS Sales.SalesOrderDetail IX_SalesOrderDetail_ProductID
WITH SAMPLE 100 PERCENT, PERSIST_SAMPLE_PERCENT = OFF;
GO
```

**Expected (รันจริง, 2026-10-03):**

| stats_name | rows_sampled | persisted_sample_percent | actual_sample_pct |
|:-----------|-------------:|-------------------------:|------------------:|
| IX_SalesOrderDetail_ProductID | 61,415 | 25 | 50.6 |

อ่านผลสองชั้น: `persisted_sample_percent = 25` ถูกจำไว้แล้วตามที่ตั้ง แต่ `actual_sample_pct = 50.6` — engine สุ่มมากกว่าที่ขอ เพราะตาราง 121,317 แถวถือว่าเล็ก engine จะบังคับ **minimum sampling** (~หลายร้อย pages ขึ้นไป) เพื่อคุณภาพ histogram — ตารางใหญ่พอ ค่า actual จะค่อนข้างตรงกับที่ขอ นี่คือเหตุผลที่ "sample แค่ไหน" ต้องดูจาก `rows_sampled` จริง ไม่ใช่ค่าที่สั่งไป

ทางเลือกอื่นที่ควรรู้:

- `sp_updatestats` — รัน `UPDATE STATISTICS` ทุกตารางที่มีการแก้ไขถึงเกณฑ์ (ใช้ใน maintenance plan เก่า ๆ — สุ่มทุกครั้ง, แพงเกินจำเป็นสำหรับระบบใหญ่)
- Ola Hallengren `IndexOptimize @UpdateStatistics = 'ALL'` — มาตรฐานที่แนะนำสำหรับ maintenance จริง (จัดลำดับกับ rebuild index ให้แล้ว)
- ตัวเลือก `WITH AUTO_DROP = ON` (SQL 2022+) ตอน `CREATE STATISTICS` — ให้ stats ถูกทิ้งอัตโนมัติเมื่อตาราง/สคีมาถูกสร้างใหม่ ป้องกัน stats ตกค้างจาก deploy script (ค่า default ของ stats ที่ auto-create):

```sql
USE AdventureWorks;
GO
CREATE STATISTICS st_AutoDrop_Demo ON Sales.SalesOrderDetail (CarrierTrackingNumber)
WITH AUTO_DROP = ON;
GO
SELECT s.name, s.auto_drop FROM sys.stats s
WHERE s.object_id = OBJECT_ID('Sales.SalesOrderDetail') AND s.name = 'st_AutoDrop_Demo';
GO
DROP STATISTICS Sales.SalesOrderDetail.st_AutoDrop_Demo;   -- ล้างของทดสอบ
GO
```

**Expected:** 1 แถวแสดง `st_AutoDrop_Demo` และ `auto_drop = 1`

### 7.2 สคริปต์เฝ้าระวัง stale stats (สไตล์ Glenn Berry)

```sql
USE AdventureWorks;
GO
SELECT TOP (15)
       OBJECT_SCHEMA_NAME(s.object_id) AS schema_name,
       OBJECT_NAME(s.object_id) AS table_name,
       s.name AS stats_name,
       sp.last_updated, sp.rows, sp.modification_counter,
       CAST(100.0 * sp.modification_counter / NULLIF(sp.rows, 0) AS DECIMAL(10,2)) AS pct_changed
FROM sys.stats AS s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
  AND sp.modification_counter > 0
ORDER BY pct_changed DESC;
GO
```

**วิธีใช้เกณฑ์ตัดสิน:** `pct_changed > 20%` + `last_updated` นานแล้ว → อัปเดตด้วยมือ; ตารางที่มี **ascending key** (ขาย/log) → อัปเดตถี่กว่าเกณฑ์ เพราะ "แถวใหม่" ที่คิวรีค้นบ่อยที่สุดอยู่นอก histogram ทั้งหมด (หัวข้อ 5.1); หลังโหลด ETL ก้อนใหญ่ → `UPDATE STATISTICS ... WITH FULLSCAN` ทันที อย่ารอ threshold

> [!IMPORTANT]
> ห้ามลืม: `modification_counter` ไม่รู้เรื่อง "แถวที่ถูกลบจนเหลือ 0" และไม่รู้เรื่องความถี่ — ตารางที่แก้วันละ 10 แถวแต่เป็น "แถวรายได้วันนี้" ที่ทุก dashboard กรอง อาจสำคัญกว่าตารางที่แก้วันละล้านแบบไม่มีใครกรอง — ดู workload ประกอบเสมอ

---

## 8. เชื่อมโยงไปข้างหน้า — Statistics คือ input ของทุก module ถัดไป

| โมดูล / Section | ใช้อะไรจาก section นี้ |
|:-----------------|:------------------------|
| Section 6.2 (Index Internals) | Index ดีแค่ไหนก็ถูกเลือก "ผ่าน" statistics — density/histogram ของ index key คือสิ่งที่ optimizer อ่านตอนตัดสิน seek/scan |
| Module 7 (Query Execution) | Estimated vs Actual Rows ใน execution plan = คู่มือวินิจฉัย CE ผิดพลาด (เปรียบเทียบที่นี่คือ "ภาษา" ที่ใช้) |
| Module 8 (Plan Caching) | Parameter Sniffing, CE Feedback, Query Store Hints — ทั้งหมดคือเรื่องของ "CE เดาไม่ตรงเมื่อค่าเปลี่ยน" |
| Module 9 (Extended Events) | event `query_optimizer_estimate_cardinality` และ CE feedback events — ดูการเดาแบบ real-time |
| Module 11 (Troubleshooting) | ขั้น "ตรวจ statistics" ใน Top-down framework เมื่อเจอ memory grant แปลก / spill / plan เปลี่ยนเอง |

---

## สรุป Section 6.1

1. **Statistics = ข้อมูลสรุปการกระจายค่า** ที่ optimizer ใช้ "เดาจำนวนแถว" (CE) ก่อนเลือก plan — เกิดจาก index, auto create (`_WA_Sys_*`), หรือสร้างเอง
2. โครง 3 ส่วน: **Header** (ความเก่า/ความครบของ sample), **Density Vector** (1/ค่าไม่ซ้ำ — ใช้กับ GROUP BY/join หลายคอลัมน์), **Histogram** (≤ 200 steps — ใช้ตอบ predicate)
3. Histogram แม่น "ตรง boundary" (711 → 3,090 = 3,090) แต่เพี้ยน "นอก boundary" (897 → 75.6667 vs จริง 2) — ความเพี้ยนโครงสร้างที่ต้องออกแบบ workload ให้มองข้ามไม่ได้
4. **Legacy vs New CE** ต่างที่สมมติฐาน 4 ข้อ — พิสูจน์ด้วย ascending key: Legacy เดา 1 แถว, New เดา 500.99 (จริง 500); ปรับได้ 3 ระดับ (DB scoped config / USE HINT / Query Store Hint) และปี 2022–2025 เพิ่ม CE Feedback + Persisted stats on secondaries
5. **Auto-update ยิงตอน compile เมื่อถึง threshold** — legacy `20%+500`, dynamic (2016+) ลดตามขนาดตาราง (~SQRT(1000×rows)), temp table 6 แถว — และ plan reuse ทำให้ "ไม่ตรวจ" ได้เป็นวัน
6. เครื่องมือจัดการ: `UPDATE STATISTICS WITH FULLSCAN / SAMPLE n PERCENT / PERSIST_SAMPLE_PERCENT`, `AUTO_DROP` (2022+), สคริปต์ตรวจ `modification_counter` ตามสัดส่วน

### ตรวจความเข้าใจ

1. `sys.dm_db_stats_properties` ของ stats หนึ่งรายงาน `rows = 121,317, rows_sampled = 109,224` — สิ่งนี้บอกอะไรเกี่ยวกับความน่าเชื่อถือของ histogram และคุณจะขอ sample ครบได้อย่างไร
2. จากผลรันจริง: `WHERE ProductID = 711` ได้ estimate 3,090 ตรงเป๊ะ แต่ `ProductID = 897` ได้ 75.6667 ทั้งที่จริงมี 2 แถว — อธิบายด้วยกลไก histogram ว่าเลข 75.6667 มาจากไหน และเงื่อนไขใดทำให้คิวรีหนึ่ง "แม่น" อีกตัว "เพี้ยน"
3. Data skew ระหว่าง ProductID 710 (44 แถว) กับ 711 (3,090 แถว) เกี่ยวข้องกับ Parameter Sniffing อย่างไร — เกิดอะไรขึ้นถ้า plan ถูก compile จากค่า 711 แต่รันจริงด้วย 711 น้อย 710 บ่อย?
4. การทดสอบ ascending key พบว่า Legacy CE ประมาณ 1 แถว (จริง 500) — ทำไมระบบรายการขายที่ตารางโตวันละแสนแถวจึงเจอปัญหานี้ "ทุกวัน" และมีทางแก้ใดบ้าง อย่างน้อย 3 ทาง (นับทั้งระดับ stats และระดับ CE model)
5. ในการทดลอง threshold: เหตุใดคิวรีรอบสองจึง "ไม่ยิง" auto-update ทั้งที่ modification_counter ผ่านเกณฑ์แล้ว (ก่อนใส่ RECOMPILE) — และตัวเลือกอื่นนอกจาก RECOMPILE ที่ทำให้เกิด compile ใหม่คืออะไร
6. Underestimation กับ Overestimation ต่างกันที่อาการตามมาอย่างไร (memory grant / join algorithm / spill) — และเคสใดที่การทดลองใน section นี้เป็น?

**➡ ถัดไป:** [Section 6.2 — Index Internals: B-Tree, Covering Index, Fragmentation](../02_Index_Internals/README.md)

---

[⬅ Module 06](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [02 Index Internals](../02_Index_Internals/README.md)
