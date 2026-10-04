# Lab 7: Execution Plan Analysis & Query Tuning (บทที่ 7)

> **ที่มา**: ปรับปรุงจาก Microsoft 10987C **Lab07** (Query execution/plan) + [Microsoft Learn — Intelligent Query Processing](https://learn.microsoft.com/sql/relational-databases/performance/intelligent-query-processing) + [Glenn Berry — SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
> รูปแบบ: **Instruction + Code block** — ใช้ SSMS เปิด **Include Actual Execution Plan (Ctrl+M)** ตลอดแล็บ

## Prerequisites

- SQL Server 2019+ (แนะนำ **2025 (17.x)** — บทส่วน IQP 2025 ต้องใช้ compat 170), database **AdventureWorks2025**
- Permission: `VIEW DATABASE STATE`

## Scenario

Developer บ่นว่า query "ไม่ยอมใช้ index" ทั้งที่กรองด้วย indexed column นอกจากนี้ report ที่มี optional parameters ทำงานเบาบ้างหนักบ้างไม่ทำนายได้ คุณต้องวิเคราะห์ plan, แก้ SARGability และลอง IQP รุ่นใหม่ของ SQL Server 2025

## Objectives

1. อ่าน Estimated vs Actual plan, หา operator แพงและ cardinality ที่คลาดเคลื่อน
2. จำลอง/แก้ Implicit Conversion (SARGable)
3. เทียบ Temp Table vs Table Variable vs CTE
4. ทดลอง IQP: Memory Grant Feedback และ PSPO/OPPO (2022/2025)

---

## Exercise 1: Implicit Conversion (Non-SARGable)

### Step 1 — สร้างปัญหา: กรอง NVARCHAR ด้วยค่า INT

> ⚠️ **ใช้ `BusinessEntityID` ไม่ใช่ `EmployeeID`** — ตาราง `HumanResources.Employee` ไม่มีคอลัมน์ `EmployeeID` (คอลัมน์ PK ชื่อ `BusinessEntityID`) — ตรวจจริงบน SQL Server 2025 (17.0.1135.8) แล้ว query ที่ใช้ `EmployeeID` จะ error `Invalid column name 'EmployeeID'`

```sql
USE AdventureWorks2025;
GO
-- Ctrl+M แล้วรัน — สังเกต plan
SELECT BusinessEntityID, NationalIDNumber, JobTitle
FROM HumanResources.Employee
WHERE NationalIDNumber = 112457891;   -- ส่งค่า INT ไปเทียบ NVARCHAR column
```

✅ **สังเกต**: plan เป็น **Index Scan** + Warning `CONVERT_IMPLICIT` — SQL ต้องแปลงค่าใน *column* ทุกแถวเพื่อเทียบกับ INT (type precedence สูงกว่า) จึงใช้ seek ไม่ได้

### Step 2 — แก้ให้ตรง type

```sql
SELECT BusinessEntityID, NationalIDNumber, JobTitle
FROM HumanResources.Employee
WHERE NationalIDNumber = N'112457891';   -- ส่งเป็น string ตรง type
```

✅ **ผลลัพธ์**: **Index Seek** ทันที — นี่คือหัวใจของ SARGable query

### Step 3 — หา implicit conversion ที่ซุกซ่อนอยู่ทั้ง cache (สไตล์ Glenn Berry)

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): บล็อกนี้ใช้ **`WITH XMLNAMESPACES`** (ประกาศ namespace ของ Showplan XML เพื่อให้ XQuery มองเห็น node ใน plan) และ **XQuery** ผ่าน `.value('count(//...)')` = นับจำนวน node ที่ตรงเงื่อนไขใน plan XML — อ่านเพิ่มที่ [Glossary](../../Glossary.md)
> ⚠️ **ต้องมี `WITH XMLNAMESPACES` และใช้ `//RelOp//ScalarOperator` (สอง slash)** — ตรวจจริงบน 17.0.1135.8: ถ้าไม่ประกาศ namespace หรือใช้ `//RelOp/ScalarOperator` (ลูกโดยตรงเท่านั้น) คอลัมน์ `implicit_converts` จะได้ **0 เสมอ** เพราะ `CONVERT_IMPLICIT` อยู่ใต้ `<Predicate>` ซึ่งเป็น grandchild ของ `RelOp` (แก้จาก query เดิมที่เขียนแบบนี้แล้วเงียบผิด ๆ)

```sql
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT TOP (20) qs.query_id, qt.query_sql_text,
       CAST(qp.query_plan AS XML).value(
           'count(//RelOp//ScalarOperator[@ScalarString[contains(., "CONVERT_IMPLICIT")]])', 'INT'
       ) AS implicit_converts
FROM sys.query_store_query AS qs
JOIN sys.query_store_query_text AS qt ON qs.query_text_id = qt.query_text_id
JOIN sys.query_store_plan AS qp ON qs.query_id = qp.query_id
WHERE CAST(qp.query_plan AS NVARCHAR(MAX)) LIKE '%CONVERT_IMPLICIT%'
ORDER BY implicit_converts DESC;
```

**Expected:** Step 1 ได้ plan เป็น **Index Scan** + predicate `CONVERT_IMPLICIT` (SSMS ขึ้น warning บน plan); Step 2 เปลี่ยนเป็น **Index Seek** ทันที; Step 3 ได้รายการ query ใน cache ที่มี implicit conversion เรียงจากมากไปน้อย
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: Step 1 = Clustered Index Scan + predicate `CONVERT_IMPLICIT(int, [NationalIDNumber], 0)` (actual 1 แถว), Step 2 = Index Seek + Key Lookup ไม่มี warning; Step 3 พบ 249 plan ที่มี CONVERT_IMPLICIT (อันดับต้นมักเป็น metadata query ของ SSMS) และ query จาก Step 1 ถูก capture ด้วย `implicit_converts = 1`

---

## Exercise 2: Cardinality ที่คลาดเคลื่อน → หา operator แพง

### Step 1 — อ่าน plan แบบละเอียด

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): บล็อกนี้ใช้ **`GROUP BY`** (จัดกลุ่มแถวแล้วรวมค่าต่อกลุ่มด้วย `COUNT`) และฟังก์ชันวันที่ **`DATEADD`** — อ่านเพิ่มที่ [Glossary](../../Glossary.md)
> ⚠️ **ข้อมูลใน sample รุ่นใหม่อยู่ช่วงปี 2022–2025** — AdventureWorks ที่มากับ SQL Server 2025 regenerate ข้อมูลใหม่ (`OrderDate` 2022-05-30 → 2025-06-29 ตรวจจริง 17.0.1135.8) จึงแก้จาก `'2014-06-30'` เป็น `'2025-06-30'` — ถ้าใช้ AdventureWorks รุ่นเก่า (ข้อมูล 2011–2014) ให้ใช้วันที่ 2014 ตามเดิม

```sql
-- รันแล้วเปิด plan: ชี้ที่แต่ละ operator เทียบ Estimated Rows vs Actual Rows
SELECT soh.SalesOrderID, COUNT(*) AS line_items
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.SalesOrderDetail AS sod ON sod.SalesOrderID = soh.SalesOrderID
WHERE soh.OrderDate >= DATEADD(YEAR, -1, '2025-06-30')
GROUP BY soh.SalesOrderID;
```

✅ **วิธีอ่าน**: operator ที่ Estimated ต่างจาก Actual มาก (>10 เท่า) คือต้นเหตุของ plan แย่ — มักมาจาก stale statistics (Lab 6) หรือ expression ที่ CE เดาไม่ได้

### Step 2 — Non-SARGable แบบ function บน column

```sql
-- แย่: ใส่ function ครอบ column → scan (ไม่ SARGable)
SELECT SalesOrderID FROM Sales.SalesOrderHeader
WHERE YEAR(OrderDate) = 2024;

-- ดี: เทียบช่วง → SARGable (seek ได้ทันทีเมื่อมี index บน OrderDate)
SELECT SalesOrderID FROM Sales.SalesOrderHeader
WHERE OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01';
```

**Expected:** Step 1 เปิด plan แล้วเทียบ Estimated Rows vs Actual Rows ราย operator — บน statistics ที่สดจะคลาดเคลื่อนน้อย; Step 2 บน AdventureWorks ทั้งสองแบบยังเป็น **Clustered Index Scan** (ไม่มี index บน OrderDate) — จุดสังเกตคือ Predicate แบบ `YEAR()` เป็น expression ที่ไม่ SARGable (จะไม่ seek แม้สร้าง index ให้) ส่วนแบบช่วงเป็น range predicate ที่ SARGable
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: Step 1 (OrderDate >= 2024-06-30) ได้ 23,202 กลุ่ม — header scan est = actual = 23,202, detail scan 121,317 ตรงกัน, มี Stream Aggregate est 31,465 vs actual 23,202 (คลาด ~1.4 เท่า), IO 830 + 1,565 logical reads; Step 2 ทั้งสองแบบ = Clustered Index Scan 830 reads, actual 14,244 แถว (est 14,239–14,241)

---

## Exercise 3: Temp Table vs Table Variable vs CTE

### Step 1 — ทั้งสามรูปแบบพร้อมวัดผล

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): บล็อกนี้ใช้ **temp table** (`SELECT ... INTO #tmp` = สร้างตารางชั่วคราวใน tempdb, ปิดท้ายด้วย `DROP TABLE`), **table variable** (`DECLARE @t TABLE` = ตัวแปรรูปตารางที่อยู่ใน scope ของ batch) และ **CTE** (`WITH ... AS (...)` = ชุดผลลัพธ์ตั้งชื่อที่ไม่ materialize) — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

```sql
USE AdventureWorks2025;
GO
-- (1) Temp Table
SELECT BusinessEntityID, FirstName, LastName
INTO #tmp_person
FROM Person.Person WHERE LastName LIKE N'S%';

SELECT COUNT(*) FROM #tmp_person p
JOIN Person.EmailAddress e ON e.BusinessEntityID = p.BusinessEntityID;
DROP TABLE #tmp_person;
GO
-- (2) Table Variable (2019+ deferred compilation ช่วยให้ CE ดีขึ้น)
DECLARE @var_person TABLE (BusinessEntityID INT, FirstName NVARCHAR(50), LastName NVARCHAR(50));
INSERT @var_person SELECT BusinessEntityID, FirstName, LastName
FROM Person.Person WHERE LastName LIKE N'S%';

SELECT COUNT(*) FROM @var_person v
JOIN Person.EmailAddress e ON e.BusinessEntityID = v.BusinessEntityID;
GO
-- (3) CTE (ไม่ materialize — ใช้ inline ทุกครั้ง)
WITH cte_person AS (
    SELECT BusinessEntityID, FirstName, LastName
    FROM Person.Person WHERE LastName LIKE N'S%'
)
SELECT COUNT(*) FROM cte_person c
JOIN Person.EmailAddress e ON e.BusinessEntityID = c.BusinessEntityID;
GO
```

✅ **สรุปเกณฑ์เลือก**: แถวเยอะ/ต้อง index/อ้างซ้ำหลายรอบ → **temp table**; แถวน้อยใน batch scope → **table variable**; อ่านครั้งเดียวอยากได้โค้ดอ่านง่าย → **CTE** (CTE ไม่ได้ "เร็วกว่า" มันแค่ไม่ materialize)

**Expected:** ทั้งสามแบบได้ COUNT เท่ากัน (~2,130 แถว) แต่ plan/IO ต่างกัน — สังเกตจาก `SET STATISTICS IO` ว่า temp table ได้ stats เต็มจึง join แบบสแกนครั้งเดียว, table variable มักถูกเลือกเป็น Nested Loops จิ้มทีละแถว, CTE inline ไม่เขียนลง tempdb
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: temp table = Hash Match + สแกน `EmailAddress` รอบเดียว (186 + 11 logical reads); table variable = est 1,917 (deferred compilation ช่วยจากเดิม est 1) แต่ optimizer ยังเลือก Nested Loops + Clustered Index Seek 2,130 ครั้ง = `EmailAddress` 4,591 reads; CTE = 14 + 186 reads ไม่มีขั้นเขียน tempdb

---

## Exercise 4: IQP — Memory Grant Feedback และ OPPO (2025)

### Step 1 — เปิด compat level 170 (SQL Server 2025)

> ⚠️ **ขั้นตอนนี้แก้ configuration ระดับฐานข้อมูล** — ต้องใช้สิทธิ์ `ALTER DATABASE` (sysadmin) และทำได้เฉพาะบน VM ทดลองของตัวเอง ห้ามรันบน production — ตรวจค่าปัจจุบันก่อนด้วย `SELECT name, compatibility_level FROM sys.databases WHERE name = N'AdventureWorks2025';` ถ้าเป็น 170 อยู่แล้วให้ข้าม

```sql
ALTER DATABASE AdventureWorks2025 SET COMPATIBILITY_LEVEL = 170;
GO
ALTER DATABASE SCOPED CONFIGURATION SET LAST_QUERY_PLAN_STATS = ON;
```

### Step 2 — Optional parameters query: ปัญหาคลาสสิก

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): บล็อกนี้ใช้ **`CREATE OR ALTER PROCEDURE`** (สร้างหรือแทนที่ stored procedure) และ pattern **optional parameters** `(@p IS NULL OR col = @p)` — เงื่อนไขที่ fold ออกได้ทันทีเมื่อ parameter เป็น NULL — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

```sql
CREATE OR ALTER PROCEDURE dbo.usp_SearchOrders
    @CustomerID INT = NULL,
    @Status TINYINT = NULL
AS
SELECT SalesOrderID, CustomerID, Status, OrderDate, TotalDue
FROM Sales.SalesOrderHeader
WHERE (@CustomerID IS NULL OR CustomerID = @CustomerID)
  AND (@Status IS NULL OR Status = @Status);
GO
-- รันสองแบบ: บางครั้งมี parameter บางครั้งไม่มี
EXEC dbo.usp_SearchOrders @CustomerID = 29825;   -- แถวน้อย
EXEC dbo.usp_SearchOrders;                        -- ทั้งตาราง
```

✅ **สังเกต**: แผนเดียวให้ทั้งสอง pattern เกิด sniffing; บน **SQL Server 2025 (compat 170) ฟีเจอร์ OPPO** จะสร้างหลาย plan ต่อ statement ตามรูปแบบ parameter — ตรวจได้จาก Query Store: `sys.query_store_plan.plan_type_desc` จะมีทั้ง `Dispatcher Plan` และ `Query Variant Plan` (variant ถูกเก็บเป็น query_id แยกที่ข้อความมี `PLAN PER VALUE`) หรือดู `<Dispatcher>` + `QueryVariantID` ใน plan XML

### Step 3 — ติดตาม feedback ที่ engine ใช้จริง

> ⚠️ **`is_memory_grant_feedback_adjusted` ถูกถอดออกจาก `sys.query_store_plan` ใน SQL Server 2025** — ตรวจจริงบน 17.0.1135.8 แล้ว query แบบเดิม error `Invalid column name 'is_memory_grant_feedback_adjusted'` — query ด้านล่างจึงใช้ `plan_type_desc` (แยก Dispatcher/Query Variant Plan ของ OPPO) และเปลี่ยนเป็น `LEFT JOIN` เพราะ Dispatcher Plan ไม่มีแถว runtime stats ของตัวเอง

```sql
SELECT q.query_id, p.plan_id, p.plan_type_desc,   -- Dispatcher Plan / Query Variant Plan (OPPO)
       p.has_compile_replay_script,   -- IQP feedback มี replay ช่วยความเข้ากันได้
       rs.avg_duration, rs.avg_cpu_time, rs.count_executions
FROM sys.query_store_query AS q
JOIN sys.query_store_plan AS p ON q.query_id = p.query_id
LEFT JOIN sys.query_store_runtime_stats AS rs ON p.plan_id = rs.plan_id
JOIN sys.query_store_query_text AS qt ON q.query_text_id = qt.query_text_id
WHERE q.object_id = OBJECT_ID('dbo.usp_SearchOrders')
   OR qt.query_sql_text LIKE '%PLAN PER VALUE%'   -- query variants ที่ OPPO สร้าง
ORDER BY rs.avg_duration DESC;
```

**Expected:** พบ plan มากกว่า 1 ชุดของ proc — 1 `Dispatcher Plan` + หลาย `Query Variant Plan` (แถว Dispatcher มี runtime stats เป็น NULL ตามที่ออกแบบไว้) — variant สำหรับค่า parameter เฉพาะเจาะจง (Index Seek) เร็วกว่า variant ทั้งตาราง (Scan) อย่างชัดเจน
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks (compat 170 อยู่แล้ว, OPPO เปิดตาม default — ไม่ได้ ALTER อะไรบน VM ใช้ร่วม), 2026-10-02: ได้ Dispatcher Plan (query_id 877) + 2 Query Variant Plans — variant XML มี `PLAN PER VALUE(ObjectID = 244195920, QueryVariantID = 1/2, optional_predicate(@CustomerID IS NULL))`; variant 1 = Index Seek + Nested Loops avg_duration 237.8 µs (5 execs) vs variant 2 = Clustered Index Scan avg 303,169 µs / avg_cpu 28,515 µs (3 execs, ส่ง 31,465 แถวกลับ client)

---

## Wrap-up: คำถามท้ายแล็บ

1. ทำไมส่ง parameter type ไม่ตรงทำให้ scan? ใครเป็นคนเลือก type ที่ชนะในการเทียบ? (data type precedence)
2. เมื่อไรใช้ temp table / table variable / CTE?
3. OPPO ช่วย optional-parameter pattern ได้อย่างไร และต้องมีเงื่อนไขอะไร? (SQL Server 2025, compat 170)

## Cleanup

```sql
DROP PROCEDURE IF EXISTS dbo.usp_SearchOrders;
```

## แหล่งอ้างอิง

- 10987C Lab07 — `Trainer_Docs/10987/Labfiles/Lab07/`
- Microsoft Learn: [IQP](https://learn.microsoft.com/sql/relational-databases/performance/intelligent-query-processing) · [Optional parameter optimization (2025)](https://learn.microsoft.com/sql/relational-databases/performance/optional-parameter-optimization) · [CE feedback for expressions (2025)](https://learn.microsoft.com/sql/relational-databases/performance/intelligent-query-processing-ce-feedback-for-expressions)
- Glenn Berry: [SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
- สคริปต์ของแล็บนี้อยู่ใน `Sections/*/Scripts/` ของโมดูล จัดตามหัวข้อที่เกี่ยวข้อง (ลิงก์ในแต่ละ Exercise)
