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

```sql
USE AdventureWorks2025;
GO
-- Ctrl+M แล้วรัน — สังเกต plan
SELECT EmployeeID, NationalIDNumber, JobTitle
FROM HumanResources.Employee
WHERE NationalIDNumber = 112457891;   -- ส่งค่า INT ไปเทียบ NVARCHAR column
```

✅ **สังเกต**: plan เป็น **Index Scan** + Warning `CONVERT_IMPLICIT` — SQL ต้องแปลงค่าใน *column* ทุกแถวเพื่อเทียบกับ INT (type precedence สูงกว่า) จึงใช้ seek ไม่ได้

### Step 2 — แก้ให้ตรง type

```sql
SELECT EmployeeID, NationalIDNumber, JobTitle
FROM HumanResources.Employee
WHERE NationalIDNumber = N'112457891';   -- ส่งเป็น string ตรง type
```

✅ **ผลลัพธ์**: **Index Seek** ทันที — นี่คือหัวใจของ SARGable query

### Step 3 — หา implicit conversion ที่ซุกซ่อนอยู่ทั้ง cache (สไตล์ Glenn Berry)

```sql
SELECT TOP (20) qs.query_id, qt.query_sql_text,
       CAST(qp.query_plan AS XML).value(
           'count(//RelOp/ScalarOperator[@ScalarString[contains(., "CONVERT_IMPLICIT")]])', 'INT'
       ) AS implicit_converts
FROM sys.query_store_query AS qs
JOIN sys.query_store_query_text AS qt ON qs.query_text_id = qt.query_text_id
JOIN sys.query_store_plan AS qp ON qs.query_id = qp.query_id
WHERE qt.query_sql_text LIKE '%CONVERT_IMPLICIT%'
   OR CAST(qp.query_plan AS NVARCHAR(MAX)) LIKE '%CONVERT_IMPLICIT%';
```

---

## Exercise 2: Cardinality ที่คลาดเคลื่อน → หา operator แพง

### Step 1 — อ่าน plan แบบละเอียด

```sql
-- รันแล้วเปิด plan: ชี้ที่แต่ละ operator เทียบ Estimated Rows vs Actual Rows
SELECT soh.SalesOrderID, COUNT(*) AS line_items
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.SalesOrderDetail AS sod ON sod.SalesOrderID = soh.SalesOrderID
WHERE soh.OrderDate >= DATEADD(YEAR, -1, '2014-06-30')
GROUP BY soh.SalesOrderID;
```

✅ **วิธีอ่าน**: operator ที่ Estimated ต่างจาก Actual มาก (>10 เท่า) คือต้นเหตุของ plan แย่ — มักมาจาก stale statistics (Lab 6) หรือ expression ที่ CE เดาไม่ได้

### Step 2 — Non-SARGable แบบ function บน column

```sql
-- แย่: ใส่ function ครอบ column → scan
SELECT SalesOrderID FROM Sales.SalesOrderHeader
WHERE YEAR(OrderDate) = 2014;

-- ดี: เทียบช่วง → seek
SELECT SalesOrderID FROM Sales.SalesOrderHeader
WHERE OrderDate >= '2014-01-01' AND OrderDate < '2015-01-01';
```

---

## Exercise 3: Temp Table vs Table Variable vs CTE

### Step 1 — ทั้งสามรูปแบบพร้อมวัดผล

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

---

## Exercise 4: IQP — Memory Grant Feedback และ OPPO (2025)

### Step 1 — เปิด compat level 170 (SQL Server 2025)

```sql
ALTER DATABASE AdventureWorks2025 SET COMPATIBILITY_LEVEL = 170;
GO
ALTER DATABASE SCOPED CONFIGURATION SET LAST_QUERY_PLAN_STATS = ON;
```

### Step 2 — Optional parameters query: ปัญหาคลาสสิก

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

✅ **สังเกต**: แผนเดียวให้ทั้งสอง pattern เกิด sniffing; บน **SQL Server 2025 (compat 170) ฟีเจอร์ OPPO** จะสร้างหลาย plan ต่อ statement ตามรูปแบบ parameter — ตรวจได้จาก Query Store (`sys.query_store_plan` มีหลาย plan ต่อ query เดียว) หรือ plan XML จะพบ "Optional Parameter Plan Optimization"

### Step 3 — ติดตาม feedback ที่ engine ใช้จริง

```sql
SELECT q.query_id, p.plan_id, p.is_memory_grant_feedback_adjusted,
       p.has_compile_replay_script,   -- IQP feedback มี replay ช่วยความเข้ากันได้
       rs.avg_duration, rs.avg_cpu_time, rs.count_executions
FROM sys.query_store_query AS q
JOIN sys.query_store_plan AS p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats AS rs ON p.plan_id = rs.plan_id
WHERE q.object_id = OBJECT_ID('dbo.usp_SearchOrders')
ORDER BY rs.avg_duration DESC;
```

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
