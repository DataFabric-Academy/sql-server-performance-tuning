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

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): `ALTER DATABASE … SET QUERY_STORE (…)` คือ DDL ระดับฐานข้อมูลที่เปิด/ตั้งค่า Query Store และ `sys.database_query_store_options` คือ catalog view สำหรับอ่านสถานะปัจจุบัน — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

```sql
ALTER DATABASE AdventureWorks2025 SET QUERY_STORE = ON;
ALTER DATABASE AdventureWorks2025 SET QUERY_STORE
(
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = ALL,           -- ⚠️ แล็บนี้ต้องใช้ ALL (ด้านล่าง) / CUSTOM ปรับ policy ละเอียดได้ (มีตั้งแต่ SQL Server 2019+)
    MAX_STORAGE_SIZE_MB = 1024,
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    MAX_PLANS_PER_QUERY = 200
);
GO
-- ตรวจสถานะ
SELECT actual_state_desc, query_capture_mode_desc, max_storage_size_mb
FROM sys.database_query_store_options;
```

> ⚠️ **ทำไมต้อง `QUERY_CAPTURE_MODE = ALL`** (ตรวจรันจริงบน 17.0.1135.8): ต้นฉบับใช้ AUTO — แต่ capture policy เริ่มต้นของ AUTO เก็บเฉพาะ query ที่หนักพอ (default: ≥ 30 executions **และ** exec CPU รวม ≥ 100 ms ภายใน 24 ชม.) — query สาธิตของแล็บนี้เบาเกินเกณฑ์ รัน 10 ครั้งแล้ว**ไม่ถูกเก็บเข้า Query Store เลย** ทำให้ Exercise 3 หา query ไม่เจอ — ใน production ค่อยพิจารณา AUTO/CUSTOM เพื่อลด overhead

**Expected:** `actual_state_desc = READ_WRITE`, `query_capture_mode_desc = ALL`, `max_storage_size_mb = 1024` ตรงกับที่ SET; ถ้า Query Store เปิดค้างจากก่อนหน้า คำสั่ง ALTER รันซ้ำได้เฉย ๆ (idempotent)
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: ได้ READ_WRITE / ALL / 1024 ตามคำสั่ง (VM ทดสอบเปิด Query Store ค้างไว้แล้วที่ ALL / 100 MB — ALTER ซ้ำผ่านเฉย ๆ)

---

## Exercise 2: จำลอง Regression

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): `CREATE INDEX` / `DROP INDEX` คือ DDL จัดการ index และ `sp_executesql` คือระบบ procedure ที่รัน SQL พร้อม**พารามิเตอร์** (`@CustomerID`) — แล็บนี้ตั้งใจใช้พารามิเตอร์เพื่อให้ Query Store มองทุกการรันเป็น query เดียวกัน — อ่านเพิ่มที่ [Glossary](../../Glossary.md)
> ⚠️ **ทำไมไม่ใช้ `EXEC ('SELECT … WHERE CustomerID = 11091;')` แบบ literal ตามต้นฉบับ** (ตรวจรันจริงบน 17.0.1135.8): query แบบ literal ถูก simple parameterization เป็น `(@1 smallint) … WHERE [CustomerID]=@1` เฉพาะชุดแรก — พอ `DROP INDEX` แล้วรันซ้ำ shell plan ที่รอดอยู่จะ compile แบบ ad-hoc ไม่แตกพารามิเตอร์ซ้ำ ทำให้ "ยุคแย่" ถูกเก็บเป็น **query_id อื่น** และ Exercise 3 จะไม่เห็น 2 plans ใน query เดียว — ใช้ `sp_executesql` จึงได้ผลตามที่แล็บออกแบบ

### Step 1 — สร้าง index ดีและรัน query ให้เกิดประวัติ "ยุคทอง"

```sql
USE AdventureWorks2025;
GO
CREATE INDEX IX_SalesOrderHeader_CustomerID_OrderDate
ON Sales.SalesOrderHeader (CustomerID, OrderDate)
INCLUDE (TotalDue, Status);

-- รัน ~10 รอบ (เก็บประวัติ Good Plan)
EXEC sp_executesql N'SELECT SalesOrderID, OrderDate, TotalDue FROM Sales.SalesOrderHeader WHERE CustomerID = @CustomerID;',
     N'@CustomerID int', @CustomerID = 11091;
GO 10
```

### Step 2 — ทำลาย index = บังคับให้เกิด regressed plan

```sql
DROP INDEX IX_SalesOrderHeader_CustomerID_OrderDate ON Sales.SalesOrderHeader;
GO
EXEC sp_executesql N'SELECT SalesOrderID, OrderDate, TotalDue FROM Sales.SalesOrderHeader WHERE CustomerID = @CustomerID;',
     N'@CustomerID int', @CustomerID = 11091;
GO 10   -- ประวัติ Bad Plan (ช้าลง ~2-3 เท่า)
```

### Step 3 — สร้าง index กลับ (ทำให้ force plan ทำงานได้ในขั้นถัดไป)

```sql
CREATE INDEX IX_SalesOrderHeader_CustomerID_OrderDate
ON Sales.SalesOrderHeader (CustomerID, OrderDate)
INCLUDE (TotalDue, Status);
```

**Expected:** ผลลัพธ์ query ได้ 28 แถวทุกรอบ (CustomerID = 11091 มี 28 รายการ); Query Store เก็บเป็น query_id เดียวที่มี 2 plans — plan ยุคทองเร็วกว่า plan ยุคแยกประมาณ 2-3 เท่า (หน่วย `avg_duration` คือ microseconds)
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: query_id 981 — plan 735 (ยุคทอง) 10 execs, avg_duration 63 µs; หลัง DROP INDEX เกิด plan 737 (ยุคแย่) 10 execs, avg_duration 165.4 µs (~2.6 เท่าของ plan ดี)

---

## Exercise 3: วิเคราะห์ Regressed Plan (GUI + T-SQL)

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): query ด้านล่าง JOIN กัน 5 catalog view ของ Query Store (query → query_text → plan → runtime_stats → runtime_stats_interval) ใช้ `CASE WHEN` ภายใน `MIN()`/`MAX()` เพื่อแยกสถิติยุคเก่า/ใหม่ และใช้ `DECLARE` + กำหนดค่าตัวแปรด้วย `SELECT TOP (1)` ใน Step 3 — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

### Step 1 — GUI: รายงาน Regressed Queries

1. Object Explorer → `AdventureWorks2025` → **Query Store** → **Regressed Queries**
2. เลือก query ของเรา — จะเห็น **2 plans**: Plan ID น้อย (duration ต่ำ) vs Plan ID มาก (duration สูง)
3. คลิก plan ที่ดี → ปุ่ม **Force Plan** → สังเกตเครื่องหมายถูกที่ plan

### Step 2 — T-SQL: หา regressed plan ด้วยตัวเอง

> ⚠️ ต้องกรองด้วย text แบบพารามิเตอร์ — Query Store เก็บ query นี้เป็น `(@CustomerID int)SELECT … WHERE CustomerID = @CustomerID` (ไม่มี literal 11091 ให้ค้น) และระวัง `LIKE '%...[]...%'` เพราะวงเล็บเหลี่ยมใน pattern ถูกตีความเป็น character class

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
WHERE qt.query_sql_text LIKE '%SELECT SalesOrderID, OrderDate, TotalDue FROM Sales.SalesOrderHeader WHERE CustomerID = @CustomerID%'
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

-- รัน query เดิมซ้ำ 2-3 ครั้ง แล้วยืนยันว่า executions ไปลง plan ที่ถูก force
EXEC sp_executesql N'SELECT SalesOrderID, OrderDate, TotalDue FROM Sales.SalesOrderHeader WHERE CustomerID = @CustomerID;',
     N'@CustomerID int', @CustomerID = 11091;
GO 3
SELECT p.plan_id, p.is_forced_plan, rs.count_executions
FROM sys.query_store_plan AS p
JOIN sys.query_store_runtime_stats AS rs ON p.plan_id = rs.plan_id
WHERE p.query_id = <query_id>;
```

**Expected:** Step 2 ได้ 2 แถว (2 plans ของ query_id เดียว) — plan เก่า avg_duration ต่ำกว่า ~2-3 เท่า; Step 3 force แล้ว `is_forced_plan = 1`, `force_failure_count = 0`, `last_force_failure_reason_desc = NONE` และหลังรันซ้ำ executions เพิ่มที่ plan ที่ถูก force เท่านั้น
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: plan 735 avg 63 µs vs plan 737 avg 165.4 µs; `avg_duration_old = NULL` ทั้งคู่เพราะทุก runtime interval เกิดภายในวันเดียว (รันแล็บจบใน ~1 ชม. — สถานการณ์จริงที่ยุคทองเก่ากว่า 1 วันจะมีค่า) และมี warning "Null value is eliminated by an aggregate" ติดมาให้เฉย ๆ; force แล้วรันซ้ำ 3 ครั้ง: count_executions ของ plan 735 ไปเพิ่มใน runtime interval ใหม่ (10 → 13) ส่วน plan 737 ค้างที่ 10

---

## Exercise 4: Query Store Hints + ABORT_QUERY_EXECUTION (SQL Server 2025)

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): `sp_query_store_set_hints` รับ hint เป็น Unicode string (`N'…'`) เขียน `OPTION()` แบบเดียวกับใน query; `JSON_VALUE(details, '$…')` คือฟังก์ชันอ่านค่าจาก JSON string ในคอลัมน์ `details` ของ DMV — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

### Step 1 — บังคับ hint ผ่าน Query Store (แก้ปัญหาโดยไม่แก้โค้ด)

> ⚠️ **ต้องปลด forced plan ก่อน** (ตรวจรันจริงบน 17.0.1135.8): ถ้า query ยังมี forced plan จาก Exercise 3 ค้างอยู่ `sp_query_store_set_hints` จะ error **Msg 12457** "Query … has forced plan. No hints can be applied to it while it has forced plan." — เรียก `sp_query_store_unforce_plan` ก่อนตั้ง hints

```sql
EXEC sp_query_store_unforce_plan @query_id = <query_id>, @plan_id = <plan_id ที่ force ไว้ใน Exercise 3>;
GO
EXEC sp_query_store_set_hints
    @query_id = <query_id>,
    @query_hints = N'OPTION (MAXDOP 1)';
GO
-- ดู hints ที่ตั้งไว้
SELECT * FROM sys.query_store_query_hints;
```

### Step 2 — บล็อก query มีปัญหาไม่ให้รัน (2025)

```sql
-- ABORT_QUERY_EXECUTION: query ที่ถูก hint จะได้ error 8778 ทันทีที่พยายามรัน
EXEC sp_query_store_set_hints
    @query_id = <query_id>,
    @query_hints = N'OPTION (USE HINT (''ABORT_QUERY_EXECUTION''))';
```

✅ **ใช้เมื่อไร**: ad-hoc query หนักที่ app ยิงมาแต่แก้โค้ดไม่ได้ทัน — บล็อกชั่วคราวเพื่อรักษา server ทั้งตัว

### Step 3 — Automatic Plan Correction (ให้ระบบแก้เอง)

> ⚠️ **SQL Server 2025 ตัดคอลัมน์ `script` ออกจาก `sys.dm_db_tuning_recommendations`** (ตรวจรันจริงบน 17.0.1135.8 — query แบบเดิม error `Invalid column name 'script'`) และ JSON ในคอลัมน์ `details` ซ้อนอยู่ใต้ `$.planForceDetails.*` — ใช้ query ด้านล่างนี้แทน

```sql
ALTER DATABASE AdventureWorks2025 SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON);
GO
-- ดูคำแนะนำที่ระบบให้
SELECT reason, score,
       JSON_VALUE(details, '$.planForceDetails.queryId') AS query_id,
       JSON_VALUE(details, '$.planForceDetails.regressedPlanId') AS regressed_plan,
       JSON_VALUE(details, '$.planForceDetails.recommendedPlanId') AS recommended_plan
FROM sys.dm_db_tuning_recommendations;
```

**Expected:** Step 1 เห็นแถว `OPTION (MAXDOP 1)` ใน `sys.query_store_query_hints` (source_desc = User); Step 2 รัน query ที่ถูก ABORT แล้ว error **8778** ทันทีโดยไม่ทำงาน; Step 3 `FORCE_LAST_GOOD_PLAN` กลับเป็น ON และ DMV แสดง recommendation ที่ระบบวิเคราะห์แล้ว (อาจยังว่างช่วงแรกหลัง regression เพราะระบบใช้เวลาวิเคราะห์ — รอสักครู่แล้วรันซ้ำ)
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: รัน query ติด ABORT ได้ **Msg 8778** "Query execution has been aborted because the ABORT_QUERY_EXECUTION hint was specified."; DMV ให้ 2 recommendations จาก activity เดิมของ VM (score 56 → query 719, regressed_plan 698, recommended_plan 466 และ score 51 → query 724, regressed_plan 700, recommended_plan 471)

---

## Wrap-up: คำถามท้ายแล็บ

1. Force Plan ล้มเหลวได้จากอะไร? (index ที่ plan อ้างถูกลบ, schema เปลี่ยน — ดู `last_force_failure_reason_desc`)
2. Query Store Hints ต่างจากแก้โค้ดใส่ OPTION() ตรงไหน และเหมาะกับสถานการณ์ใด?
3. ทำไม AUTO capture mode ถึงเหมาะกับ production? (เก็บเฉพาะ query ที่ใช้ resource พอสมควร ลด overhead/storage)

## Cleanup

```sql
USE AdventureWorks2025;
EXEC sp_query_store_clear_hints @query_id = <query_id>;   -- เคลียร์ hints ก่อน — ถ้ามี hint ค้าง remove_query จะ error 12456
EXEC sp_query_store_remove_query @query_id = <query_id>;  -- ลบ force/hint/สถิติที่เกี่ยวข้อง
ALTER DATABASE AdventureWorks2025 SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = OFF);
DROP INDEX IF EXISTS IX_SalesOrderHeader_CustomerID_OrderDate ON Sales.SalesOrderHeader;  -- ตามเดิมก่อนแล็บ
```

## แหล่งอ้างอิง

- 10987C Lab08 — `Trainer_Docs/10987/Labfiles/Lab08/`
- Microsoft Learn: [Query Store](https://learn.microsoft.com/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store) · [Query Store hints + ABORT_QUERY_EXECUTION](https://learn.microsoft.com/sql/relational-databases/performance/query-store-hints-best-practices) · [Automatic tuning](https://learn.microsoft.com/sql/relational-databases/automatic-tuning/automatic-tuning)
- สคริปต์ของแล็บนี้อยู่ใน `Sections/*/Scripts/` ของโมดูล จัดตามหัวข้อที่เกี่ยวข้อง (ลิงก์ในแต่ละ Exercise)
