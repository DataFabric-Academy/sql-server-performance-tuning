[⬅ Module 07](../../README.md) | [2. Execution Plan Formats](../02_Execution_Plan_Formats/README.md) | Section 3/4 | ➡ ถัดไป: [04 Intelligent Query Processing](../04_Intelligent_Query_Processing/README.md)

# 7.3 Analyzing Query Plans — ตั้งคำถามกับ plan ให้เป็น แล้วเครื่องมือจะบอกต้นเหตุเอง

> *"Plan แย่มักไม่ได้เกิดจาก optimizer โง่ — มันเกิดจากเราให้ข้อมูลผิด: คิวรีที่ไม่ SARGable, type ที่ไม่ตรง, statistics ที่เก่า และจากนั้นเราก็โทษมัน"*

> **ต้องรู้มาก่อน**: [SARGable](../../../Glossary.md), [Implicit Conversion](../../../Glossary.md), [Key Lookup](../../../Glossary.md), [Memory Grant / Spill](../../../Glossary.md), [Logical Reads](../../../Glossary.md) — รวมถึง Section 7.1 (CE) และ 7.2 (อ่าน Estimated vs Actual) กับ [Module 6 Section 6.1](../../Module_06_Statistics_Index_Internals/Sections/01_Statistics_Cardinality_Estimation/README.md) (แหล่งที่มาของ CE)
> **สภาพแวดล้อมทดสอบ**: SQL Server 2025 RTM-GDR (17.0.1135.8), ฐานข้อมูล `AdventureWorks` — ตัวเลข logical reads/time ทุกตัวรันจริงด้วย `SET STATISTICS IO/TIME` เมื่อ 2026-10-02 ตามแต่ละบล็อก

---

## เปิดเรื่อง: 4 คำถามที่ถามกับทุก plan

เปิด plan (Ctrl+M) แล้ว "มองอะไรก่อน?" — คำตอบคือชุดคำถาม 4 ข้อที่ลำดับคงที่ ใช้ได้กับทุก plan:

1. **"ตัวจ่ายแพงสุดคือ operator ไหน?"** — ดู subtree cost สูงสุด + ลูกศรหนาสุด
2. **"มันอ่านข้อมูลเท่าที่ต้องหรือเปล่า?"** — Seek กับ Scan, Key Lookup ซ้ำ, และ Actual Number of Rows Read
3. **"มันเดาถูกไหม?"** — Estimated Rows vs Actual Rows (เกณฑ์ข้อสงสัย: ต่างเกิน ~10 เท่า)
4. **"มันมีแห้วหมายทางอ้อมไหม?"** — Warnings (spill, implicit conversion, missing index) ที่ SSMS ขึ้นเตือนบน operator

และก่อนจะเปิด plan ตัวไหน ให้เริ่มจาก "คิวรีไหนควรถูกเปิด" — จาก Query Store ตัวที่กิน logical reads สูงสุดใน 24 ชั่วโมงล่าสุด (ตัวเลข IO ต่อ 1 execution):

```sql
SELECT TOP (8) q.query_id, LEFT(qt.query_sql_text, 55) AS query_text,
       rs.count_executions, rs.avg_logical_io_reads, rs.avg_duration
FROM sys.query_store_runtime_stats AS rs
JOIN sys.query_store_plan AS p ON p.plan_id = rs.plan_id
JOIN sys.query_store_query AS q ON q.query_id = p.query_id
JOIN sys.query_store_query_text AS qt ON qt.query_text_id = q.query_text_id
WHERE rs.last_execution_time > DATEADD(DAY, -1, SYSDATETIME())
ORDER BY rs.avg_logical_io_reads DESC;
```

**Expected (รันจริง, 2026-10-02):** รายการ 8 คิวรีที่กิน IO สูงสุดของวัน — บน VM ใช้ร่วมจะเจอคิวรี sort/spill จาก session ทดลองก่อนหน้ากินอันดับต้น จากนั้นเอา `query_id` เหล่านั้นไปเปิด plan (Module 8 แสดงวิธีคลิกจาก Query Store GUI ได้โดยตรง)

---

## 1. Seek หรือ Scan — คำถามเรื่องการอ่านข้อมูล

**นิยามก่อนใช้:**
- **Seek** = เจาะ B-tree ตรงไปยังช่วง key ที่ predicate ระบุ อ่านเฉพาะที่ต้อง
- **Scan** = อ่าน leaf level ทั้งหมดของ index (หรือทั้ง heap ในกรณี Table Scan)
- **SARGable (Search ARGument able)** = predicate ที่เขียนในรูปที่ engine เจาะ B-tree ได้ เช่น `col = ค่า`, `col > ค่า`, `col BETWEEN a AND b`

ตัวเลขวินิจฉัยที่มือใหม่พลาดบ่อยคือ **Actual Number of Rows Read** (บน actual plan) — ต่างจาก Actual Rows: *Actual Rows* = จำนวนแถวที่ operator **ส่งออก**, *Rows Read* = จำนวนแถวที่ operator **อ่านเข้ามาก่อนคัด** — Scan ของตาราง 121,317 แถวที่คืน 5 แถว มี Actual Rows = 5 แต่ Rows Read = 121,317 — เมื่อไร Rows Read โตมากกว่า Rows ที่คุณต้องการหลายเท่า นั่นคืองาน I/O ที่ถูกทำเปล่า และเป็นตัวชี้หา "ตัวจ่ายแพงสุด" ที่แม่นกว่า subtree cost (ซึ่งเบี้ยวตาม CE)

ทดลองจริง — predicate สามรูปแบบบน index เดียวกัน (`IX_SalesOrderDetail_ProductID`, ตาราง 121,317 แถว):

```sql
SET STATISTICS IO ON;
GO
-- (A) จุดเดียว: SARGable เต็มรูปแบบ
SELECT SalesOrderDetailID, ProductID, OrderQty
FROM Sales.SalesOrderDetail
WHERE ProductID = 897;
GO
-- (B) ช่วงกว้าง: ยัง SARGable (seek ช่วง) แต่ช่วงใหญ่ = อ่านเยอะ
SELECT SalesOrderDetailID, ProductID, OrderQty
FROM Sales.SalesOrderDetail
WHERE ProductID BETWEEN 800 AND 900;
GO
-- (C) ปฏิเสธค่า NULL: ถูกเขียนให้ต้องพิสูจน์ "ทุกแถว" → เท่ากับอ่านทั้ง leaf
SELECT SalesOrderDetailID, ProductID, OrderQty
FROM Sales.SalesOrderDetail
WHERE ProductID IS NOT NULL;
GO
SET STATISTICS IO OFF;
GO
```

**Expected (รันจริง, `Table 'SalesOrderDetail'`, 2026-10-02):**

| กรณี | Plan | แถวจริง | logical reads | อ่านว่า |
|:-----|:-----|--------:|--------------:|:--------|
| (A) `= 897` | Index Seek + Key Lookup | 2 | **10** | เจาะตรงตำแหน่งเดียว + lookup ไม่กี่ครั้ง |
| (B) `BETWEEN 800 AND 900` | Index Seek (range) + Key Lookup | 40,058 | **1,935** | seek ได้และแถวเยอะ — แต่แถววาง "ติดกัน" ใน B-tree จึงอ่านหน้าเฉลี่ยต่ำ (~21 แถว/หน้า) |
| (C) `IS NOT NULL` | Index Scan | 121,317 | **1,935** | พิสูจน์ทุกแถว → scan leaf ทั้ง index (1,935 หน้าเต็ม ๆ) |

บทเรียน: **Seek ไม่ใช่คำตอบเสมอไป** — กรณี (B) กับ (C) กิน logical reads เท่ากันพอดี (1,935 หน้า) ทั้งที่จำนวนแถวต่างกัน 3 เท่า เพราะ (B) อ่านเฉพาะ "ช่วง" ที่แถววางต่อเนื่อง ส่วนตัวเลขที่ต้องจับตาคือ **หน้าที่อ่านต่อหนึ่งคำตอบที่ต้องการ** ไม่ใช่ชื่อ operator ส่วน Key Lookup ที่ซ้ำเป็นพันครั้ง (เคส A/B) คือของขยะที่แก้ด้วย covering index (`INCLUDE`) — เทคนิคละเอียดใน Module 6 Section 6.2

### 1.1 ไม่ SARGable — สองแบบที่พบบ่อยที่สุด

**(1) function ครอบ column:**

```sql
-- แย่: function ครอบ column → ไม่ SARGable (ต้องคำนวณทุกแถวก่อนเทียบ)
SELECT SalesOrderID FROM Sales.SalesOrderHeader
WHERE YEAR(OrderDate) = 2024;

-- ดี: เทียบช่วงเปิด-ปิด → SARGable (seek ได้ทันทีเมื่อมี index บน OrderDate)
SELECT SalesOrderID FROM Sales.SalesOrderHeader
WHERE OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01';
```

**Expected:** บน AdventureWorks ทั้งคู่ยังเป็น **Clustered Index Scan** (830 reads) เพราะไม่มี index บน OrderDate ตั้งแต่แรก — จุดที่ต้องจับคือ **Predicate ใน plan**: แบบ YEAR() จะเห็น `YEAR([AdventureWorks]...[OrderDate])=(2024)` เป็น expression ที่จะไม่ seek **แม้คุณสร้าง index ให้** ส่วนแบบช่วงเป็น range predicate ที่ seek ได้ทันทีเมื่อมี index — อย่าตัดสินจาก "scan วันนี้" แต่ตัดสินจาก "รูปแบบ predicate"

**(2) implicit conversion — type ไม่ตรง:**

```sql
-- (A) ส่ง INT ไปเทียบคอลัมน์ NVARCHAR → CONVERT_IMPLICIT บนคอลัมน์ → Scan
SELECT BusinessEntityID, NationalIDNumber, JobTitle
FROM HumanResources.Employee
WHERE NationalIDNumber = 112457891;

-- (B) ส่งให้ตรง type (N'...' = NVARCHAR) → Seek ทันที
SELECT BusinessEntityID, NationalIDNumber, JobTitle
FROM HumanResources.Employee
WHERE NationalIDNumber = N'112457891';
```

**Expected (จาก Labs Exercise 1 ที่รันจริง):** (A) = **Index Scan** + warning บน plan พร้อม predicate `CONVERT_IMPLICIT(int, [NationalIDNumber], 0)` — SQL ต้องแปลงค่า *ในคอลัมน์* ทุกแถวเพื่อเทียบกับ INT; (B) = **Index Seek** ไม่มี warning

ทำไมฝั่งคอลัมน์ถึงถูกแปลง? เพราะ **data type precedence** — เมื่อเทียบสอง type ต่างกัน ฝั่งที่ precedence **ต่ำกว่า** จะถูกแปลงไปเป็นฝั่งสูงกว่า และ INT สูงกว่า NVARCHAR — จำสั้น ๆ:

| คู่ที่เจอบ่อย | ฝั่งที่ถูกแปลง | ผล |
|:--------------|:---------------|:---|
| คอลัมน์ NVARCHAR = ค่า INT | **คอลัมน์** (NVARCHAR < INT) | ไม่ SARGable → scan |
| คอลัมน์ INT = ค่า NVARCHAR | ค่า (NVARCHAR < INT) | SARGable → seek ได้ |
| คอลัมน์ VARCHAR = ค่า N'...' (NVARCHAR) | **คอลัมน์** (VARCHAR < NVARCHAR) | ไม่ SARGable → อย่าให้ app ส่ง N-prefix โดยไม่จำเป็น |
| คอลัมน์ DATE = ค่า DATETIME | คอลัมน์ (DATE < DATETIME) | ระวังเช่นกัน |

เช็กลิสต์ SARGable สำหรับ code review (จับ 2 ทิศทาง: function ครอบคอลัมน์ และ type ไม่ตรง):

- ❌ `YEAR(col) = 2024`, `LEFT(col,3) = 'ABC'`, `CAST(col AS ...)` → เปลี่ยนเป็นช่วง/รูปเทียบตรง
- ❌ `col + ' ' + col2 = '...'` → เปลี่ยนเป็น `col = '...' AND col2 = '...'`
- ❌ app ส่ง parameter type ต่างจากคอลัมน์ (ส่วนใหญ่เจอใน ORM/driver config) → ตรวจที่ plan (warning) และตรวจที่ cache (Labs Ex1 Step 3)
- ✅ ช่วงวันที่: `col >= @start AND col < @end` — อย่าใช้ `DATEDIFF` ครอบคอลัมน์

ตรวจหา implicit conversion ที่ซุกซ่อนทั้ง Query Store ได้จาก [Labs Exercise 1 Step 3](../../Labs/README.md) (XQuery หา `CONVERT_IMPLICIT` — ครั้งนั้นพบ **249 plan** ใน cache ส่วนใหญ่เป็น metadata query ของ SSMS)

---

## 2. Join Algorithms — รู้จัก 3 อัลกอริทึมและเงื่อนไขของมัน

**นิยามก่อนใช้:** การ join สองชุดข้อมูลมีอัลกอริทึมทางกายภาพ 3 แบบ optimizer เลือกจาก CE + cost model:

| Algorithm | เงื่อนไขที่คุ้ม | ต้นทุนโดยประมาณ | หมายเหตุ |
|:----------|:----------------|:-----------------|:---------|
| **Nested Loops** | outer เล็ก + inner มี index สำหรับ seek | outer × 1 seek/แถว | แย่สุดเมื่อ outer ใหญ่แล้ว inner ต้อง scan ทุกรอบ |
| **Hash Match** | input ใหญ่ทั้งคู่, ไม่เรียง | สร้าง hash table ฝั่ง build + probe รอบเดียว | กิน memory grant (grant ไม่พอ → spill) |
| **Merge Join** | input ทั้งคู่ **เรียงตาม key** อยู่แล้ว | เดินเทียบทีละแถว | อาจเสีย cost ตัว Sort มาก่อน (แล้วคุ้มไม่) |

อ่าน "อาการ" จากรูปร่าง plan ได้ก่อนดูตัวเลข — โครงของแต่ละอัลกอริทึม:

```
Nested Loops (outer เล็ก + inner มี index):
  Outer 3 แถว ──> [Nested Loops] ──> ผลลัพธ์
                     └── 1 seek ต่อ 1 แถว outer  =>  cost ~ outer_rows × seek_cost

Hash Match (input ใหญ่ ไม่เรียง):
  Build (ฝั่งเล็กกว่า) ──> [Hash Match] ──> ผลลัพธ์
  Probe (ฝั่งใหญ่)     ──>       └── ใช้ memory grant สร้าง hash table ก่อน 1 ครั้ง

Merge Join (สองฝั่งเรียงตาม key อยู่แล้ว):
  Sorted A ──> [Merge Join] ──> ผลลัพธ์   (เดินเทียบไปข้างหน้าทีเดียว ไม่มี hash/sort)
  Sorted B ──>
```

สัญญาณที่ "การเลือก algorithm ผิดจากความจริง" ทิ้งไว้บน plan:

- Nested Loops กับ **ลูกศร outer หนามาก** (แสนแถว) + inner เป็น Scan ซ้ำ = หายนะแบบคูณ (และมักมาจาก CE เดาน้อย — ย้อนไปแก้ CE ไม่ใช่ hint)
- Hash Match ที่ **grant จองต่างจาก used มาก** (จองเกิน) หรือ spill (จองน้อยไป) — ต่อที่หัวข้อ 3
- Merge Join ที่มี **Sort ซ้อนอยู่ใต้ทั้งสองฝั่ง** = engine เสียค่าเรียงก่อนจึงจะ merge ได้ — บางครั้ง Hash ถูกกว่า

ทดลองบังคับทั้งสามแบบเทียบกันบนข้อมูลจริง (`OPTION (LOOP/HASH/MERGE JOIN)` เป็น hint สำหรับ **ทดลอง** ไม่ใช่คำตอบถาวร — ความเสี่ยงของ hint ต่อท้าย):

```sql
SET STATISTICS TIME ON;
GO
SELECT COUNT_BIG(*) AS loops
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.SalesOrderDetail AS sod ON sod.SalesOrderID = soh.SalesOrderID
OPTION (LOOP JOIN);
GO
SELECT COUNT_BIG(*) AS hashes
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.SalesOrderDetail AS sod ON sod.SalesOrderID = soh.SalesOrderID
OPTION (HASH JOIN);
GO
SELECT COUNT_BIG(*) AS merges
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.SalesOrderDetail AS sod ON sod.SalesOrderID = soh.SalesOrderID
OPTION (MERGE JOIN);
GO
SET STATISTICS TIME OFF;
GO
```

**Expected (รันจริง, 121,317 join คู่กับ 31,465 — CPU time ฝั่ง execution):** ทั้งสามแบบจบใน ~15–17 ms (LOOP 16 ms, HASH 15–16 ms, MERGE ~15 ms) — ผล "ใกล้กันอย่างน่าผิดหวัง" นี่คือตัวอย่างที่ดีว่า optimizer เลือกแบบไหนก็แทบไม่ต่าง **บนข้อมูลขนาดนี้** — ความต่าง 100 เท่าจะปรากฏเมื่อ input เบ้ (outer 10 แถว vs 10 ล้านแถว) หรือ inner ไม่มี index ให้ seek ซึ่งตอนนั้น cost model จะทำหน้าที่ของมันอยู่แล้ว ไม่ต้อง hint

> [!IMPORTANT]
> เกณฑ์การใช้ join hint: ใช้เพื่อ **ทดลองพิสูจน์สมมติฐาน** ("ถ้าบังคับ hash แล้วเร็ว 100 เท่า → optimizer เดาผิดเพราะอะไร?") แล้วตามหาต้นเหตุ (statistics, CE, โครงสร้าง index) — การเขียน hint แปะถาวรใน code คือการ "ล็อกอนาคต" เมื่อข้อมูลโตขึ้น hint ที่เคยเร็วจะกลายเป็นเพดานที่ไม่มีใครกล้าแก้

ปัจจัยที่ผลักดันการเลือก algorithm จริง ๆ (ลำดับความสำคัญ):

1. **จำนวนแถวที่เดาไว้สองฝั่ง** (จาก CE) — ตัวตั้งของทุกสูตร
2. **มี index บน inner ที่ seek ได้หรือไม่** — ถ้าไม่มี Nested Loops แทบถูกตัดทิ้งทันที
3. **สองฝั่งเรียงอยู่แล้วหรือไม่** (จาก index/Sort ที่จำเป็น) — หน้าต่างของ Merge
4. **memory ที่จะจองได้** — กรณีใหญ่ ๆ hash ที่ grant ไม่พอจะเสียค่า spill จนอาจแพงกว่า loop

ข้อเท็จจริงที่ทำให้งานวิเคราะห์ "ยากเกินจำเป็น": ปัจจัยทั้งสี่ล้วนต่อกันจาก **การเดา** — เมื่อ CE ผิด ทั้ง access path, join algorithm, grant, และ parallelism เบื้องหลังมันเปลี่ยนพร้อมกัน ดังนั้น "แก้ CE ให้ตรง" มักแก้ได้หลายอาการในครั้งเดียว นี่คือเหตุผลที่ตารางในหัวข้อ 5 วาง statistics ไว้ก่อน hint เสมอ

---

## 3. Memory Grant และ Spills — เมื่อ Sort/Hash ไม่มีที่วางข้อมูล

**นิยามก่อนใช้:**
- **Memory Grant** = หน่วยความจำ (workspace) ที่ optimizer "จอง" ให้ operator ที่ต้องแคชข้อมูลชั่วคราว (Sort, Hash) คำนวณจาก **estimate ของแถว × ขนาดแถว**
- **Spill** = grant ไม่พอกับแถวจริง → engine เขียนข้อมูลส่วนเกินลง **tempdb** แล้วค่อยอ่านกลับ — I/O เพิ่มหลายเท่า และทำให้เกิด wait `IO_COMPLETION`/`LATCH` ใน tempdb (Module 4)

เชื่อมโยงตรง ๆ: **CE เดาน้อย → grant เล็ก → spill** — นี่คือหนึ่งในความเสียหายที่จับต้องได้ที่สุดของ "เดาผิด" ตรวจหาจาก plan cache ได้เลย (รวม grant ของคิวรี + spill จริง):

```sql
SELECT TOP (8)
       LEFT(t.text, 60) AS query_text, qs.execution_count,
       qs.total_grant_kb, qs.total_used_grant_kb, qs.total_ideal_grant_kb,
       qs.total_spills
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS t
WHERE qs.total_grant_kb > 0
ORDER BY qs.total_spills DESC, qs.total_grant_kb DESC;
```

**Expected (รันจริง, 2026-10-02 — รายการตาม cache ของแต่ละเวลาจะต่างกัน):**

| query_text | total_grant_kb | total_used_grant_kb | total_ideal_grant_kb | total_spills |
|:-----------|---------------:|--------------------:|---------------------:|-------------:|
| (sort ข้อมูลใหญ่จาก session ทดลอง) | 23,488 | 23,488 | 634,976 | **50,000** |
| `SELECT Id, Pad FROM dbo.M7S3_Spill ORDER BY Pad OPTION (MAX_...` | 23,488 | 23,488 | 144,096 | **39,506** |

อ่านผลแบบมืออาชีพ:

1. `total_spills > 0` = เคย spill เขียนลง tempdb (หน่วย: pages) — 50,000 pages ≈ 390 MB ที่ไหลผ่าน tempdb โดยไม่จำเป็น
2. `total_used_grant_kb` ต่ำกว่า `total_grant_kb` มาก = จองเกิน (overgrant) — เปลือง memory ของคนอื่น
3. `total_ideal_grant_kb` สูงกว่า grant จริงหลายเท่า = engine รู้ว่าต้องใช้เท่าไรแต่สั่งได้แค่นั้น (จำกัดด้วย resource semaphore) — สัญญาณว่า workload นี้ต้องการ memory มากกว่าที่มี
4. ตามแก้: ทำ statistics ให้สด (Module 6) เพื่อให้ estimate ตรง → grant ตรง; คิวรีเก่าที่ plan ค้างให้ compile ใหม่; และรู้จักฟีเจอร์ **Memory Grant Feedback** ที่ engine ปรับเอง (Section 7.4)

แหล่งอื่นที่มอง spill ได้: `sys.query_store_runtime_stats` คอลัมน์ `spill_reads` / `spill_writes` (ต่อ plan ต่อช่วงเวลา — เทียบย้อนหลังได้) และ warning `SpillToTempDb` บน operator Sort/Hash ใน actual plan

เข้าใจกลไกภายในเพิ่มนิดหนึ่งเพื่อจะได้ "ประเมินความเจ็บ" ถูก: sort ใหญ่ที่ spill จะทำงานเป็น **หลายรอบ** — เทียบข้อมูลลง tempdb (run แรก) แล้ว merge กลับ (รอบถัด ๆ) ค่าที่พบใน warning คือ `SpillToTempDb SpillLevel` — level 2 ขึ้นไปแปลว่าต้อง spill ซ้ำหลายชั้น แย่กว่า level 1 หลายเท่า และเพราะทุก spill เขียนผ่าน tempdb อาการจะโผล่ด้วยกันสองที่: เวลาของคิวรี และ **I/O + PAGELATCH ของ tempdb** (Module 4) — จึงต้องแยกให้ออกว่า "tempdb แพงเพราะ spill ของคิวรีนี้" หรือ "คิวรีนี้เป็นเหยื่อของ tempdb ที่แออัดอยู่แล้ว"

---

## 4. Temp Table vs Table Variable — ทางเลือกที่ทำให้ plan ต่างกัน 23 เท่า

กรณีศึกษาเดียวกับ [Labs Exercise 3](../../Labs/README.md) — งานเดียวกัน (ดึงคนนามสกุลขึ้นต้น S ~2,130 แถว แล้ว join หา email) เขียน 3 แบบ:

```sql
SET STATISTICS IO ON;
GO
-- (1) Temp table: มี statistics เต็ม ให้ optimizer มองเห็นขนาดจริง
SELECT BusinessEntityID, FirstName, LastName
INTO #tmp_person
FROM Person.Person WHERE LastName LIKE N'S%';

SELECT COUNT(*) FROM #tmp_person p
JOIN Person.EmailAddress e ON e.BusinessEntityID = p.BusinessEntityID;
DROP TABLE #tmp_person;
GO
-- (2) Table variable: deferred compilation รู้จำนวนแถว แต่ไม่มี statistics
DECLARE @var_person TABLE (BusinessEntityID INT, FirstName NVARCHAR(50), LastName NVARCHAR(50));
INSERT @var_person SELECT BusinessEntityID, FirstName, LastName
FROM Person.Person WHERE LastName LIKE N'S%';
SELECT COUNT(*) FROM @var_person v
JOIN Person.EmailAddress e ON e.BusinessEntityID = v.BusinessEntityID;
GO
SET STATISTICS IO OFF;
GO
```

**Expected (รันจริง, 2026-10-02):** ทั้งสองแบบได้ COUNT = 2,130 เหมือนกัน แต่ IO ต่างกันชัด:

| รูปแบบ | Plan ที่เลือก | `EmailAddress` reads | ทำไม |
|:--------|:--------------|---------------------:|:-----|
| Temp table | Hash Match + **สแกนรอบเดียว** | **186** (+11 ของ #tmp) | stats ของ temp table บอกขนาดจริง → optimizer มั่นใจเลือก hash |
| Table variable | Nested Loops + **Seek 2,130 ครั้ง** | **4,591** | ไม่มี stats (deferred compilation ให้แค่จำนวนแถว ~1,917) → เลือก loop จิ้มทีละแถว |
| CTE | inline เหมือนคิวรีตรง ๆ | 14 + 186 | ไม่ materialize — เร็ว/ช้าตามคิวรีที่มัน inline |

(แบบ CTE อยู่ใน Labs — ใส่ไว้ในตารางเพื่อครบภาพ) เกณฑ์ตัดสินสรุปได้ว่า: แถวเยอะ/ต้อง index/อ้างซ้ำ → temp table; แถวน้อยใน batch scope → table variable; อ่านครั้งเดียว → CTE รายละเอียดกลไก deferred compilation ต่อที่ Section 7.4

ข้อสังเกตเพิ่มสองข้อจากตาราง:

1. **ค่าจริงของ temp table อยู่ที่ statistics ไม่ใช่ชื่อ** — ถ้าคุณ `SELECT INTO` แล้วไม่มี index/stats ก็ยังมีข้อจำกัด (แต่ยังมีจำนวนแถวจริงให้ optimizer ใช้ — ดีกว่า table variable อยู่ดี)
2. **CTE อ้างหลายรอบ = คำนวณหลายรอบ** — CTE ไม่ materialize ดังนั้นการเขียน CTE แล้ว join กับตัวเองอีกชั้นอาจซ้ำงานโดยไม่รู้ตัว (ต่างจาก temp table ที่ "คำนวณครั้งเดียว อ่านหลายครั้ง") — เมื่อไรอ้างซ้ำ ≥ 2 รอบ ให้พิจารณา temp table เสมอ

โบนัสที่มืออาชีพใช้ประโยชน์: **temp table caching** — temp table ขนาดเล็กใน proc ที่ drop/create ซ้ำ ๆ ถูก cache โครงสร้างไว้ เพราะฉะนั้นอย่าเปลืองคำสั่ง `CREATE`/`DROP` ที่ไม่จำเป็นกลาง proc และระวังชื่อ temp table ซ้ำกันใน proc ซ้อนกัน (ชนกันทันที) — จุดเล็ก ๆ เหล่านี้คือเหตุผลที่ "นิสัยการเขียน temp table" มีผลต่อ tempdb contention จริง ๆ ทั้ง module ของมัน (Module 4)

---

## 5. สังเคราะห์: ตั้งคำถาม 4 ข้อ ครบทั้ง 4 อาการ

ย้อนไปที่กรอบต้น section — แผนที่อาการ → ต้นเหตุ → ทิศทางแก้:

| อาการที่เห็นใน plan | คำถามข้อ | ต้นเหตุที่พบบ่อย | ทิศทางแก้ที่ถูกชั้น |
|:--------------------|:---------|:------------------|:---------------------|
| Scan บนตารางใหญ่ทั้งที่มี predicate | 2 | ไม่ SARGable (function บนคอลัมน์ / implicit conversion) | แก้ predicate ให้ SARGable (แก้ที่ code) |
| Scan แต่ statistics เก่า | 2–3 | auto-update ยังไม่ถึง threshold | `UPDATE STATISTICS ... WITH FULLSCAN` (Module 6) |
| Estimated ต่างจาก Actual > 10 เท่า | 3 | stale stats / expression เดาไม่ได้ / ค่า local variable | แก้ตามตาราง 7.1 หัวข้อ 5 |
| Spill warning / `total_spills > 0` | 2 | CE เดาน้อย → grant เล็ก | statistics สด + ดู MGF (7.4) |
| Key Lookup ซ้ำพันครั้ง | 2 | SELECT * ทั้งที่ต้องแค่ไม่กี่คอลัมน์ | covering index / ลดคอลัมน์ |
| Nested Loops กับ outer ใหญ่ | 2 | CE เดาน้อย | ตามหาสาเหตุ CE ก่อน hint |

หัวใจของ section นี้: **อาการบน plan คือทางเข้า ต้นเหตุมักอยู่นอก plan** (code, statistics, โครงสร้าง index) — เครื่องมือแก้ "ที่ปลาย" คือ hint และ IQP ที่ engine ทำเอง ซึ่งเป็นเนื้อหาของ Section ถัดไป

ลำดับการแก้ที่ถูกหลัก (จากต้นเหตุไปหาปลายเหตุ — แก้ขั้นล่างได้ผลก็หยุดที่นั่น):

1. **แก้ predicate/type** ให้ SARGable (เปลี่ยนคิวรี ไม่เปลี่ยนข้อมูล)
2. **สร้าง/อัปเดต statistics** ให้ตรงกับ predicate ที่ใช้จริง (Module 6)
3. **สร้าง/แก้ index** ตาม access path ที่ควรเป็น — covering index แก้ Key Lookup, index บนคอลัมน์กรองแก้ Scan
4. **rewrite** — temp table แทน table variable แถวเยอะ, แยก query, ตัด SELECT *
5. **hint** — ใช้พิสูจน์/กันพลาดรายกรณีเท่านั้น
6. **IQP** — ให้ engine เรียนรู้แทนเรา (Section 7.4) — แต่มันแก้ "ค่าใช้จ่ายของการเดาผิด" ไม่แก้ "เหตุที่ทำให้ต้องเดา"

---

## สรุป Section 7.3

1. เปิด plan ด้วยกรอบ 4 คำถาม: operator แพงสุด → อ่านเท่าที่ต้อง → เดาถูกไหม → มี warning อะไร และเลือก "ตัวป่วย" แรกเริ่มจาก `avg_logical_io_reads` ใน Query Store
2. Seek กับ Scan ตัดสินที่ selectivity — ไม่ใช่ชื่อ operator; predicate ต้อง SARGable (เลี่ยง function บนคอลัมน์) และ type ต้องตรง (implicit conversion ที่แปลงฝั่งคอลัมน์ปิด B-tree ทันที)
3. Join 3 อัลกอริทึม: Loop (outer เล็ก), Hash (ใหญ่ไม่เรียง), Merge (เรียงแล้ว) — hint ใช้พิสูจน์ ไม่ใช่แปะถาวร
4. Spill = ความเสียหายที่จับต้องได้ของ CE ผิด — ตรวจ `total_spills`/`total_ideal_grant_kb` ได้จาก `sys.dm_exec_query_stats`
5. Temp table (มี stats) vs table variable (ไม่มี) ทำให้ plan ต่างกัน 23 เท่าบนงานเดียวกัน (186 vs 4,591 reads)

### ตรวจความเข้าใจ

1. ทำไม `WHERE ProductID IS NOT NULL` ถึงได้ logical reads เท่ากับ `BETWEEN 800 AND 900` พอดี ทั้งที่ plan คนละชนิด (Seek range vs Scan)?
2. `NationalIDNumber = 112457891` (INT) ทำให้ scan แต่ `N'112457891'` seek — กฎ data type precedence ตัดสินว่าฝั่งไหนถูกแปลงอย่างไร และทำไมการแปลงฝั่งคอลัมน์จึงปิดการ seek?
3. คิวรีมี Sort ที่ spill 39,506 pages — จะตรวจพบได้จากที่ใดบ้าง (นับ 2 แหล่ง) และสาเหตุรากมักคืออะไร?
4. ทีมของคุณอยากแปะ `OPTION (HASH JOIN)` ถาวรเพราะ "ทดสอบแล้วเร็วขึ้น" — ให้เหตุผล 2 ข้อว่าทำไมควรชะลอ
5. งานเดียวกัน temp table ใช้ 197 reads แต่ table variable ใช้ 4,591 reads — ความต่างเชิงกลไกคืออะไร (statistics ของใครขาด) และ deferred compilation ช่วยได้ตรงไหน ไม่ช่วยตรงไหน?

**➡ ถัดไป:** [Section 7.4 — Intelligent Query Processing](../04_Intelligent_Query_Processing/README.md)

---

[⬅ Module 07](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [04 Intelligent Query Processing](../04_Intelligent_Query_Processing/README.md)
