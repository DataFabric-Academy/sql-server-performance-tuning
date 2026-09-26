# Lab 5: Blocking, Deadlocks & Isolation Levels (บทที่ 5)

> **ที่มา**: ปรับปรุงจาก Microsoft 10987C **Lab05** (Isolation/Blocking/Deadlock) + [Microsoft Learn — Transaction locking and row versioning guide](https://learn.microsoft.com/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide) + [Optimized locking (2025)](https://learn.microsoft.com/sql/relational-databases/performance/optimized-locking)
> รูปแบบ: **Instruction + Code block** — ใช้ SSMS 3 หน้าต่าง (Session A, B, C)

## Prerequisites

- SQL Server 2019+ (แนะนำ **2025 (17.x)**), database **AdventureWorks2025**
- Permission: `VIEW SERVER STATE` + สิทธิ์ KILL (แนะนำ sysadmin บน VM)

## Scenario

ผู้ใช้บ่นว่าแอป "ค้าง" บ่อย และ batch กลางคืนล้มด้วย error "Transaction was deadlocked" (1205) คุณต้องจำลองปัญหา วิเคราะห์ด้วย DMV + Extended Events และทดสอบยาแก้ทั้งแบบเดิม (isolation levels) และแบบใหม่ (Optimized Locking — SQL Server 2025)

## Objectives

1. จำลอง Blocking Chain และหา head blocker
2. จำลอง Deadlock และอ่าน Deadlock Graph จาก `system_health`
3. เทียบผลกระทบ isolation levels (RCSI / Snapshot)
4. (2025) เปิด Optimized Locking แล้วสังเกตความต่างของ lock/waits

---

## Exercise 1: Blocking Chain

### Step 1 — Session A: เปิด transaction แล้ว update โดยไม่ commit

```sql
-- Session A
USE AdventureWorks2025;
BEGIN TRANSACTION;
UPDATE Production.Product
SET StandardCost = StandardCost * 1.01
WHERE ProductID = 1;
-- อย่าเพิ่ง COMMIT — ปล่อยค้างไว้
```

### Step 2 — Session B: พยายามอ่านแถวเดียวกัน (จะหยุดรอ)

```sql
-- Session B: คำสั่งนี้จะค้าง
SELECT ProductID, StandardCost
FROM Production.Product
WHERE ProductID = 1;
```

### Step 3 — Session C: วิเคราะห์ blocking แบบสด

```sql
-- Session C
SELECT r.session_id,
       r.blocking_session_id,
       r.wait_type,
       r.wait_time,
       r.wait_resource,
       LEFT(t.text, 60) AS waiting_sql
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.blocking_session_id <> 0;

-- หา head blocker ที่ถือ transaction ค้าง
SELECT s.session_id, s.login_time, s.host_name, s.program_name,
       t.text AS open_transaction_sql
FROM sys.dm_exec_sessions AS s
JOIN sys.dm_exec_requests AS r ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE s.session_id IN (
    SELECT blocking_session_id FROM sys.dm_exec_requests
    WHERE blocking_session_id <> 0
);
```

### Step 4 — ปลดล็อกและสังเกตผล

```sql
-- Session A
ROLLBACK TRANSACTION;   -- Session B จะรันเสร็จทันที
```

---

## Exercise 2: Deadlock + Deadlock Graph

### Step 1 — Session A: lock ตารางแรกของวงจร

```sql
-- Session A
USE AdventureWorks2025;
BEGIN TRANSACTION;
UPDATE Production.Product SET ListPrice = ListPrice * 1.01 WHERE ProductID = 1;
-- อย่าเพิ่งรันคำสั่งต่อไป (จะรันใน Step 3)
```

### Step 2 — Session B: lock ตารางที่สอง

```sql
-- Session B
USE AdventureWorks2025;
BEGIN TRANSACTION;
UPDATE Sales.SalesOrderDetail SET OrderQty = OrderQty WHERE SalesOrderDetailID = 1;
-- อย่าเพิ่งรันคำสั่งต่อไป
```

### Step 3 — สลับกันขอ resource = เกิดวงจร

```sql
-- Session A: รันต่อ — จะค้างรอ Session B
UPDATE Sales.SalesOrderDetail SET OrderQty = OrderQty + 1 WHERE SalesOrderDetailID = 1;

-- แล้วรีบไป Session B รัน:
UPDATE Production.Product SET StandardCost = StandardCost * 1.01 WHERE ProductID = 1;
```

✅ **ผลลัพธ์**: หนึ่ง session ได้ error **1205**: "Transaction (Process ID xx) was deadlocked on lock resources with another process and has been chosen as the deadlock victim."

### Step 4 — ดึง Deadlock Graph ล่าสุดจาก system_health XEvent

```sql
SELECT
    x.value('(event/@timestamp)[1]', 'DATETIME2') AS deadlock_at,
    x.query('(event/data[@name="xml_report"]/value)[1]') AS deadlock_xml
FROM (
    SELECT CAST(target_data AS XML) AS buf
    FROM sys.dm_xe_session_targets AS t
    JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
    WHERE s.name = 'system_health' AND t.target_name = 'ring_buffer'
) AS d
CROSS APPLY buf.nodes('//event[@name="xml_deadlock_report"]') AS n(x)
ORDER BY deadlock_at DESC;
```

✅ **วิธีอ่าน**: คลิก XML link → SSMS แสดง **Deadlock Graph แบบภาพ** ระบุ victim (วงกลมมี ✗) และ resource ที่ชนกัน (List Price vs OrderQty ของ process ต่างคน)

---

## Exercise 3: Isolation Levels — RCSI ลด blocking

### Step 1 — ตรวจ/เปิด RCSI (สั้น ๆ บน VM)

```sql
ALTER DATABASE AdventureWorks2025 SET READ_COMMITTED_SNAPSHOT ON
    WITH ROLLBACK IMMEDIATE;   -- ⚠️ ทำบน VM เท่านั้น (เทียบเท่าเปลี่ยนระหว่างทำงาน)
```

### Step 2 — ทำซ้ำ Exercise 1 แล้วสังเกต

```sql
-- Session A: update ค้างไว้
USE AdventureWorks2025;
BEGIN TRANSACTION;
UPDATE Production.Product SET StandardCost = StandardCost * 1.01 WHERE ProductID = 1;

-- Session B: SELECT ตอนนี้ "ผ่านทันที" — อ่านเวอร์ชันก่อน update จาก version store
SELECT ProductID, StandardCost FROM Production.Product WHERE ProductID = 1;
```

### Step 3 — ตรวจ version store ที่ถูกใช้

```sql
SELECT DB_NAME(database_id) AS database_name,
       persistent_version_store_size_kb / 1024.0 AS pvs_mb,
       active_transactions_using_pvs
FROM sys.dm_tran_persistent_version_store_stats
WHERE database_id = DB_ID('AdventureWorks2025');
```

✅ **สรุปแนวคิด**: RCSI = reader ไม่ block writer / writer ไม่ block reader โดยใช้ row versioning — เหมาะกับ OLTP ทั่วไป; Snapshot Isolation ใช้เมื่อต้องการ consistency ระดับ transaction

---

## Exercise 4 (SQL Server 2025): Optimized Locking

### Step 1 — เปิดใช้ (ปิด default ใน SQL Server 2025)

```sql
USE master;
GO
-- ต้องเปิด ADR ก่อน / ตอนรันต้องไม่มี connection อื่นต่อ DB นี้
ALTER DATABASE AdventureWorks2025 SET ACCELERATED_DATABASE_RECOVERY = ON;
ALTER DATABASE AdventureWorks2025 SET OPTIMIZED_LOCKING = ON;
GO
SELECT name, is_accelerated_database_recovery_on, is_optimized_locking_on
FROM sys.databases WHERE name = 'AdventureWorks2025';
```

### Step 2 — ทำซ้ำ Exercise 1 แล้วเทียบ lock ที่ถืออยู่

```sql
-- Session A: update ค้างไว้เหมือนเดิม
BEGIN TRANSACTION;
UPDATE Production.Product SET StandardCost = StandardCost * 1.01 WHERE ProductID = 1;

-- Session C: ดู lock ที่ถือจริง
SELECT request_session_id, resource_type, resource_description,
       request_mode, request_status
FROM sys.dm_tran_locks
WHERE request_session_id = <Session A spid>;
```

✅ **สังเกต**: จะไม่พบ row/page X locks ค้างจนจบ transaction — เหลือเพียง **TID lock** (resource_type = TRANSACTION ID... ปรากฏเป็น `resource_associated_entity_id` ของ X lock ระดับ TID) — lock memory ลด, โอกาส escalation ลด

### Step 3 — ย้อนคืน (ถ้าต้องการ)

```sql
ALTER DATABASE AdventureWorks2025 SET OPTIMIZED_LOCKING = OFF;
```

---

## Wrap-up: คำถามท้ายแล็บ

1. จาก Deadlock Graph — victim ถูกเลือกอย่างไร และจะลด deadlock ด้วยการจัดลำดับ access ตารางให้เหมือนกันได้จริงไหม?
2. RCSI แก้ blocking ด้านไหน และมีต้นทุนอะไร? (tempdb version store, update conflict ใน snapshot)
3. Optimized Locking ต่างจากเดิมตรงไหน และต้องเปิดอะไรก่อน? (ADR; แนะนำ RCSI คู่กันสำหรับ LAQ)

## Cleanup

```sql
ALTER DATABASE AdventureWorks2025 SET READ_COMMITTED_SNAPSHOT OFF WITH ROLLBACK IMMEDIATE;
ALTER DATABASE AdventureWorks2025 SET OPTIMIZED_LOCKING = OFF;  -- ตามต้องการ
```

## แหล่งอ้างอิง

- 10987C Lab05 — `Trainer_Docs/10987/Labfiles/Lab05/`
- Microsoft Learn: [Optimized locking](https://learn.microsoft.com/sql/relational-databases/performance/optimized-locking) · [Row versioning guide](https://learn.microsoft.com/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide) · [ADR](https://learn.microsoft.com/sql/relational-databases/accelerated-database-recovery-concepts)
- Glenn Berry: [SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
- สคริปต์เสริมในโมดูล: `Labs/Scripts/01–08` (blocking/deadlock/snapshot/latch)
