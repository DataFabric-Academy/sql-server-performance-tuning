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

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): คำสั่งวิเคราะห์ใน Step 3 ใช้ **CROSS APPLY / OUTER APPLY** (เรียก table-valued function ต่อท้ายแต่ละแถว เช่น `sys.dm_exec_sql_text` เพื่อดึงข้อความ SQL ของ request) และ **subquery** (`IN (SELECT blocking_session_id ...)`) — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

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

**Expected:** บน DB ที่ยังไม่เปิด RCSI หน้าต่าง B ค้างรอจน Session A ROLLBACK แล้วจึงรันเสร็จทันที; ระหว่างค้าง Session C เห็น blocking pair ที่ `wait_type = LCK_M_S` ชี้ `blocking_session_id` ไปที่ Session A และ query หา head blocker ระบุ session ที่ถือ transaction ค้างได้
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: DB บน VM ชื่อ `AdventureWorks` และ**เปิด RCSI อยู่แล้ว** (`is_read_committed_snapshot_on = 1`) — Step 2 จึง "ผ่านทันที" ไม่ block (อ่านค่า commit ล่าสุด 0.0000 ได้ใน ~0.5 วิ) หมายเหตุการสอน: ต้องจำลอง blocking read ด้วย `WITH (READCOMMITTEDLOCK)` จึงจับได้ `wait_type = LCK_M_S` รอ 2,123 ms ที่ `wait_resource = KEY: 5:72057594054049792 (8194443284a0)` โดย `blocking_session_id = 66` (spid ของ Session A) และถ้า Session B เป็น UPDATE จะ block ด้วย `LCK_M_X` ทำให้เห็น chain 2 ชั้น (spid 67 → 68 → 66) — หลัง A ROLLBACK ทุก session ปลอดและค่าข้อมูลไม่เปลี่ยน (บทเรียน: RCSI ทำให้ reader ไม่ block writer แต่ writer ยัง block writer)

---

## Exercise 2: Deadlock + Deadlock Graph

### Step 1 — Session A: lock ตารางแรกของวงจร

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): คำสั่งดึง Deadlock Graph ใน Step 4 ใช้ **derived table** (subquery ในวงเล็บตั้งชื่อ `AS d`), **CROSS APPLY** และ **XQuery** (`buf.nodes('//event[...]')` = แตก XML ออกเป็นแถวแล้วอ่านค่าด้วย `.value()`) — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

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

**Expected:** หนึ่ง session ได้ error **1205** (victim — transaction ถูก rollback อัตโนมัติ) อีก session ที่ถูก block อยู่รันต่อจนเสร็จและปิด transaction ได้ปกติ; Step 4 ดึง Deadlock Report ล่าสุดจาก `system_health` ได้ timestamp ตรงช่วงทดลอง พร้อม XML ระบุ victim และ resource ที่ชนกัน
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: deadlock เกิดจริง — Session A (spid 78) เป็น victim ได้ `Msg 1205, Level 13: Transaction (Process ID 78) was deadlocked on lock resources with another process and has been chosen as the deadlock victim`, Session B (spid 79) รอดและ ROLLBACK สะอาด (ค่าข้อมูลไม่เปลี่ยน, open transaction = 0) หมายเหตุ 2 ข้อจากการรัน: (1) บน build นี้ query ใน Step 4 ตามต้นฉบับคืน 0 แถวเพราะ `ring_buffer` ไม่เก็บ `xml_deadlock_report` ไว้ — ให้เปลี่ยนไปอ่านจาก event_file ด้วย `sys.fn_xe_file_target_read_file('system_health*.xel', NULL, NULL, NULL)` แล้ว `CROSS APPLY ... nodes('//event[@name="xml_deadlock_report"]')` พบรายงานเวลา 07:14:21.628 (เวลาเซิร์ฟเวอร์) victim = spid 78; (2) `x.value('(event/@timestamp)[1]', ...)` คืน NULL เพราะ path เป็น element ลูกที่ไม่มีจริง — ใช้ `(@timestamp)[1]` (attribute ของ event เอง) จึงจะได้เวลา

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

**Expected:** Session B SELECT ผ่านทันทีระหว่าง Session A ถือ X lock ค้าง โดยได้ค่า commit ล่าสุด (ไม่มี LCK wait); Step 3 เห็น version store ถูกใช้งานขณะ update ยังค้าง ส่วน SNAPSHOT transaction ต้องเปิด `ALLOW_SNAPSHOT_ISOLATION` ก่อนจึงรันได้
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-02: DB บน VM ชื่อ `AdventureWorks` และ**เปิด RCSI อยู่แล้ว** (`is_read_committed_snapshot_on = 1` — Step 1 ข้ามได้ และ**ห้ามรันซ้ำ**บน VM ทดสอบ) — ระหว่าง Session A (spid 65) ถือ update ค้าง Session B SELECT ผ่านใน ~0.7 วิ ได้ค่า 0.0000 (commit ล่าสุด) หมายเหตุจากการรัน: (1) Step 3 ตามต้นฉบับ error `Msg 207 Invalid column name 'active_transactions_using_pvs'` — คอลัมน์นี้มีเฉพาะ Azure SQL ไม่มีใน on-prem 2022/2025 (ตรวจตามเอกสาร Microsoft Learn) ให้ใช้ `SELECT database_id, persistent_version_store_size_kb/1024.0 AS pvs_mb FROM sys.dm_tran_persistent_version_store_stats` แทน ซึ่งคืน pvs_mb = 0 เพราะ ADR ปิด (PVS ใช้เมื่อเปิด ADR — DB นี้ versioning อยู่ที่ tempdb version store: ระหว่าง update ค้าง `sys.dm_tran_active_snapshot_database_transactions` และ `sys.dm_tran_version_store` มี 1 แถวจริง); (2) `ALLOW_SNAPSHOT_ISOLATION` บน VM ยัง OFF — เปิดตอนสอนด้วย `ALTER DATABASE ... SET ALLOW_SNAPSHOT_ISOLATION ON` (ทำบน VM เท่านั้น) แล้วผู้เรียนจะเห็น: `SET TRANSACTION ISOLATION LEVEL SNAPSHOT` + `BEGIN TRAN` แล้วอ่านได้ค่าก่อน update คงเดิมตลอด transaction แม้ Session A จบ tran ไปแล้ว (consistent snapshot — ถ้าพยายาม UPDATE แถวที่ถูกแก้ระหว่างทางจะพบ error 3960 update conflict)

---

## Exercise 4 (SQL Server 2025): Optimized Locking

> **ทางเลือกสำหรับรุ่นเก่า:** Exercise นี้ต้องใช้ SQL Server 2025 (17.x) เท่านั้น — บน 2019/2022 ให้ข้ามไปทำ Wrap-up โดยอ่านผลจาก sign-off ด้านล่าง หรือกลับไปลงลึก Exercise 3 (Snapshot/RCSI) แทน

### Step 1 — เปิดใช้ (ปิด default ใน SQL Server 2025)

```sql
USE master;
GO
-- Hard guard: ฟีเจอร์นี้มีเฉพาะ SQL Server 2025 (17.x) — รุ่นเก่าจะหยุดพร้อมข้อความบอกทาง
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) < 17
    THROW 51000, 'Optimized Locking ต้องใช้ SQL Server 2025 (17.x) — ทางเลือกรุ่นเก่า: ข้าม Exercise 4 นี้ แล้วทำ Exercise 3 (Snapshot/RCSI) ต่อ', 1;
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

**Expected:** ครบทั้ง 3 Step — Step 1: บน 17.x guard ผ่านเงียบ ๆ, `ALTER` สำเร็จ และ query คืน `is_optimized_locking_on = 1` (บนรุ่นเก่ากว่า 17: error 51000 พร้อมข้อความบอกทางเลือก) · Step 2: `sys.dm_tran_locks` ไม่มี row/page X lock ค้างของ Session A ขณะ tran เปิดอยู่ — เหลือแถว resource_type = `TRANSACTION ID` (TID lock) · Step 3: `ALTER ... OFF` สำเร็จ กลับสู่สถานะเดิม
> อ้างอิงรันจริง SQL Server 2025 RTM (17.0.1000.7), 2026-10-01: เปิด ADR + OPTIMIZED_LOCKING สำเร็จ (`is_accelerated_database_recovery_on = 1, is_optimized_locking_on = 1`) และ revert กลับ 0 สะอาด — syntax guard `IF … THROW` ทดสอบแล้วผ่าน; หมายเหตุ: DB บน VM ทดสอบชื่อ `AdventureWorks` (แทนชื่อตามสภาพแวดล้อม) และ Step 2 ตรวจจริงด้วย pattern เดียวกับ Exercise 1 ของแล็บนี้ (สร้าง blocking คู่แล้วอ่าน `sys.dm_tran_locks`)

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
- สคริปต์ของแล็บนี้อยู่ใน `Sections/*/Scripts/` ของโมดูล จัดตามหัวข้อที่เกี่ยวข้อง (ลิงก์ในแต่ละ Exercise)
