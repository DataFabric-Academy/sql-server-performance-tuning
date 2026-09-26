# Lab 8: Query Store — Regression, Force Plan & Automatic Tuning (บทที่ 8)

> **ที่มา**: ปรับปรุงจาก Microsoft 10987C **Lab08** (Plan cache/Query Store) + [Microsoft Learn — Query Store](https://learn.microsoft.com/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store) + [Query Store Hints](https://learn.microsoft.com/sql/relational-databases/performance/query-store-hints-best-practices)
> รูปแบบ: **Instruction + Code block** — ใช้ SSMS + T-SQL

## Prerequisites

- SQL Server 2019+ (แนะนำ **2025 (17.x)**), database **AdventureWorks2025**
- Permission: `ALTER DATABASE` บน DB ทดสอบ (Lab ทำบน VM)

## Scenario

Stored procedure ตัวหนึ่งเคยเร็วมากแต่ "บางวันช้าตึ้ง" โดยไม่มีใครแก้โค้ด คุณต้องใช้ Query Store หา plan ที่ถดถอย (regressed) แล้วบังคับใช้ plan ที่ดี ทั้งแบบ GUI และ T-SQL พร้อมลอง Query Store Hints / `ABORT_QUERY_EXECUTION` ของ SQL Server 2025

## Objectives

1. เปิดและตั้งค่า Query Store
2. จำลอง performance regression และหา plan ที่ถดถอย
3. Force Plan ผ่าน GUI และ T-SQL
4. ใช้ Query Store Hints + ABORT_QUERY_EXECUTION (2025) และ Automatic Plan Correction

---

## Exercise 1: เปิด Query Store

```sql
ALTER DATABASE AdventureWorks2025 SET QUERY_STORE = ON;
ALTER DATABASE AdventureWorks2025 SET QUERY_STORE
(
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = AUTO,          -- 2025: มี CUSTOM ให้ปรับละเอียดได้
    MAX_STORAGE_SIZE_MB = 1024,
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    MAX_PLANS_PER_QUERY = 200
);
GO
-- ตรวจสถานะ
SELECT actual_state_desc, query_capture_mode_desc, max_storage_size_mb
FROM sys.database_query_store_options;
```

---

## Exercise 2: จำลอง Regression

### Step 1 — สร้าง index ดีและรัน query ให้เกิดประวัติ "ยุคทอง"

```sql
USE AdventureWorks2025;
GO
CREATE INDEX IX_SalesOrderHeader_CustomerID_OrderDate
ON Sales.SalesOrderHeader (CustomerID, OrderDate)
INCLUDE (TotalDue, Status);

-- รัน ~10 รอบ (เก็บประวัติ Good Plan)
EXEC ('SELECT SalesOrderID, OrderDate, TotalDue FROM Sales.SalesOrderHeader WHERE CustomerID = 11091;');
GO 10
```

### Step 2 — ทำลาย index = บังคับให้เกิด regressed plan

```sql
DROP INDEX IX_SalesOrderHeader_CustomerID_OrderDate ON Sales.SalesOrderHeader;
GO
EXEC ('SELECT SalesOrderID, OrderDate, TotalDue FROM Sales.SalesOrderHeader WHERE CustomerID = 11091;');
GO 10   -- ประวัติ Bad Plan (Scan)
```

### Step 3 — สร้าง index กลับ (ทำให้ force plan ทำงานได้ในขั้นถัดไป)

```sql
CREATE INDEX IX_SalesOrderHeader_CustomerID_OrderDate
ON Sales.SalesOrderHeader (CustomerID, OrderDate)
INCLUDE (TotalDue, Status);
```

---

## Exercise 3: วิเคราะห์ Regressed Plan (GUI + T-SQL)

### Step 1 — GUI: รายงาน Regressed Queries

1. Object Explorer → `AdventureWorks2025` → **Query Store** → **Regressed Queries**
2. เลือก query ของเรา — จะเห็น **2 plans**: Plan ID น้อย (duration ต่ำ) vs Plan ID มาก (duration สูง)
3. คลิก plan ที่ดี → ปุ่ม **Force Plan** → สังเกตเครื่องหมายถูกที่ plan

### Step 2 — T-SQL: หา regressed plan ด้วยตัวเอง

```sql
SELECT q.query_id,
       qt.query_sql_text,
       p.plan_id, p.is_forced_plan,
       MIN(CASE WHEN rsi.start_time < DATEADD(DAY, -1, SYSUTCDATETIME())
                THEN rs.avg_duration END) AS avg_duration_old,
       MAX(rs.avg_duration) AS avg_duration_recent
FROM sys.query_store_query AS q
JOIN sys.query_store_query_text AS qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan AS p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats AS rs ON p.plan_id = rs.plan_id
JOIN sys.query_store_runtime_stats_interval AS rsi
    ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE qt.query_sql_text LIKE '%SalesOrderHeader WHERE CustomerID = 11091%'
GROUP BY q.query_id, qt.query_sql_text, p.plan_id, p.is_forced_plan
ORDER BY q.query_id, p.plan_id;
```

### Step 3 — Force Plan ด้วย T-SQL

```sql
DECLARE @good_plan_id BIGINT;
SELECT TOP (1) @good_plan_id = p.plan_id
FROM sys.query_store_query AS q
JOIN sys.query_store_plan AS p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats AS rs ON p.plan_id = rs.plan_id
WHERE q.query_id = <query_id จาก Step 2>
GROUP BY p.plan_id
ORDER BY AVG(rs.avg_duration) ASC;

EXEC sp_query_store_force_plan @query_id = <query_id>, @plan_id = @good_plan_id;

-- ตรวจยืนยัน
SELECT plan_id, is_forced_plan, force_failure_count, last_force_failure_reason_desc
FROM sys.query_store_plan
WHERE query_id = <query_id>;

-- รัน query เดิมซ้ำ แล้วดูใน sys.query_store_plan ว่า forced plan ถูกใช้จริง
```

---

## Exercise 4: Query Store Hints + ABORT_QUERY_EXECUTION (SQL Server 2025)

### Step 1 — บังคับ hint ผ่าน Query Store (แก้ปัญหาโดยไม่แก้โค้ด)

```sql
EXEC sp_query_store_set_hints
    @query_id = <query_id>,
    @query_hints = N'OPTION (MAXDOP 1)';
GO
-- ดู hints ที่ตั้งไว้
SELECT * FROM sys.query_store_query_hints;
```

### Step 2 — บล็อก query มีปัญหาไม่ให้รัน (2025)

```sql
-- ABORT_QUERY_EXECUTION: query ที่ถูก hint จะได้ error 8799 ทันทีที่พยายามรัน
EXEC sp_query_store_set_hints
    @query_id = <query_id>,
    @query_hints = N'OPTION (USE HINT (''ABORT_QUERY_EXECUTION''))';
```

✅ **ใช้เมื่อไร**: ad-hoc query หนักที่ app ยิงมาแต่แก้โค้ดไม่ได้ทัน — บล็อกชั่วคราวเพื่อรักษา server ทั้งตัว

### Step 3 — Automatic Plan Correction (ให้ระบบแก้เอง)

```sql
ALTER DATABASE AdventureWorks2025 SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON);
GO
-- ดูคำแนะนำที่ระบบให้
SELECT reason, score,
       script,
       JSON_VALUE(details, '$.regressedPlanId') AS regressed_plan,
       JSON_VALUE(details, '$.recommendedPlanId') AS recommended_plan
FROM sys.dm_db_tuning_recommendations;
```

---

## Wrap-up: คำถามท้ายแล็บ

1. Force Plan ล้มเหลวได้จากอะไร? (index ที่ plan อ้างถูกลบ, schema เปลี่ยน — ดู `last_force_failure_reason_desc`)
2. Query Store Hints ต่างจากแก้โค้ดใส่ OPTION() ตรงไหน และเหมาะกับสถานการณ์ใด?
3. ทำไม AUTO capture mode ถึงเหมาะกับ production? (เก็บเฉพาะ query ที่ใช้ resource พอสมควร ลด overhead/storage)

## Cleanup

```sql
USE AdventureWorks2025;
EXEC sp_query_store_remove_query @query_id = <query_id>;  -- ลบ hints/force ที่เกี่ยวข้อง
ALTER DATABASE AdventureWorks2025 SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = OFF);
DROP INDEX IF EXISTS IX_SalesOrderHeader_CustomerID_OrderDate ON Sales.SalesOrderHeader;  -- ตามเดิมก่อนแล็บ
```

## แหล่งอ้างอิง

- 10987C Lab08 — `Trainer_Docs/10987/Labfiles/Lab08/`
- Microsoft Learn: [Query Store](https://learn.microsoft.com/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store) · [Query Store hints + ABORT_QUERY_EXECUTION](https://learn.microsoft.com/sql/relational-databases/performance/query-store-hints-best-practices) · [Automatic tuning](https://learn.microsoft.com/sql/relational-databases/automatic-tuning/automatic-tuning)
- ไฟล์ประกอบทั้งหมดอยู่ใน `Scripts/` ของโฟลเดอร์นี้ (`Scripts/01–03`) — โค้ดหลักของทุก Exercise ฝังอยู่ใน README ฉบับนี้แล้ว
