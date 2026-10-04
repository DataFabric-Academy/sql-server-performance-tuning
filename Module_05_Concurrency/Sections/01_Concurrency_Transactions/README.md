[⬅ Module 05](../../README.md) | Section 1/3 | ➡ ถัดไป: [02 Locking Internals](../02_Locking_Internals/README.md)

# 5.1 Concurrency & Transactions — กฎการใช้ฐานข้อมูล "พร้อมกัน" ให้ไม่เหยียบกัน

> *"Performance problem ที่ผู้ใช้เห็นเป็น 'ระบบค้าง' หลายเคสไม่ใช่ CPU หรือ Disk — แต่คือ session หนึ่งกำลังถือ lock ค้างอยู่เงียบ ๆ"*

> **ต้องรู้มาก่อน**: [Transaction](../../../Glossary.md), [Lock](../../../Glossary.md), [Blocking](../../../Glossary.md), [Wait Type](../../../Glossary.md) (`LCK_M_*` จาก Module 1 Wait Statistics), [TempDB](../../../Glossary.md) (version store — Module 3)
> **Permission ที่ต้องมี**: `VIEW SERVER STATE` (DMV ระดับ server เช่น `sys.dm_exec_requests`) และ `VIEW DATABASE STATE` (DMV ระดับ database เช่น `sys.dm_tran_locks`) — สิทธิ์ `db_datareader` + เจ้าของตารางทดสอบสำหรับเดโมเขียนข้อมูล

---

## ทำไม Section นี้จึงมาก่อนในโมดูล Concurrency

Module 1 เราเคยอ่าน Wait Statistics และเจอกลุ่ม wait `LCK_M_*` — คือ task ที่กำลัง "รอ lock" แล้วเคยจดไว้ว่าให้กลับมาลงลึกในโมดูลนี้ ตอนนั้นเราถามว่า *"รออะไร"* — ใน Section นี้เราจะตอบให้ครบว่า **"ทำไมต้องรอ, ใครเป็นคนทำให้รอ, และเราปรับกติกาได้อย่างไร"**

Concurrency คือความสามารถของระบบในการรองรับผู้ใช้หลายคนเข้าถึงข้อมูลพร้อมกัน **โดยยังถูกต้อง** (Consistency) และ **ยังเร็ว** (Performance) — สองอย่างนี้ดึงรั้งกันเป็นธรรมชาติ ยิ่งเข้มงวดเรื่องถูกต้อง ก็ยิ่งต้อง "ขัง" ข้อมูลไว้ให้คนอื่นรอ ยิ่งปล่อยหลวม ก็ยิ่งเร็วแต่เสี่ยงอ่านค่าผิด Section นี้จึงสอนสองเรื่องคู่กัน:

```
Concurrency = Consistency (ความถูกต้อง)  ⟷  Performance (ความเร็ว)
                     ▲                            ▲
                     │                            │
              Isolation Levels              Locks / Versioning
              (กติกาที่เลือกได้)          (กลไกที่ engine ใช้บังคับกติกา)
```

เส้นทางของ Section:

1. **Transaction คืออะไร** — หน่วยงานที่ต้องจบให้จบ (ACID) และโหมดการเริ่ม/จบ transaction
2. **ความวุ่นวายที่เกิดได้** — Dirty Read, Non-repeatable Read, Phantom Read (เรียกเล่น ๆ ว่า "อาการ 3 หนุมาน")
3. **Isolation Levels** — บันไดกติกาที่เลือกจะกันอาการไหน
4. **RCSI** — ทางแก้ยุคใหม่ที่ใช้ Row Versioning แทนการให้รอ lock ซึ่งเป็นหัวใจของ Section ที่ 3 ด้วย

> **เดโมของ Section นี้** ทดสอบแล้วบน SQL Server 2025 (17.0.1135.8), DB `AdventureWorks` ที่**เปิด RCSI อยู่แล้ว** — ซึ่งเป็นสถานะที่น่าสอนมาก: อาการ blocking แบบคลาสสิกจะ "ไม่เกิดกับ SELECT ปกติ" แล้ว เราต้องจำลองพฤติกรรมเก่าด้วย hint `WITH (READCOMMITTEDLOCK)` จึงจะเห็นเหตุการณ์ตรงตำรา (แล็บคู่ section นี้: [Labs — Exercise 1 & 3](../../Labs/README.md), สคริปต์ที่เกี่ยว: `Scripts/01_Blocking_SessionA.sql`, `02_Blocking_SessionB.sql`, `07_Snapshot_Isolation.sql`)

---

## 1. Transaction — หน่วยงานที่ต้องจบให้จบ

**Transaction** (ธุรกรรม) คือชุดคำสั่งทางตรรกะที่ต้องมองเป็น "หนึ่งเดียว" — ทำสำเร็จทั้งหมด หรือยกเลิกทั้งหมด ไม่มีหยุ่น ๆ ครึ่ง ๆ คุณสมบัติมาตรฐานคือ **ACID**:

| ตัวอักษร | คุณสมบัติ | ความหมาย | กลไกใน SQL Server ที่รับประกัน |
|:---------|:----------|:---------|:-------------------------------|
| **A** | Atomicity | เป็นหนึ่งเดียว — สำเร็จทั้งหมดหรือ rollback ทั้งหมด | Transaction Log (WAL — Module 1) |
| **C** | Consistency | ไม่ละเมิดกฎ (constraint, FK, check) เดิมของข้อมูล | Constraints + Transaction Manager |
| **I** | Isolation | transaction ที่ทำงานขนานกันไม่แอบเห็นงานกันกลางทาง | **Locking / Row Versioning (หัวใจของโมดูลนี้)** |
| **D** | Durability | commit แล้วต้องอยู่จริงแม้ไฟดับ | Log harden ลง disk ก่อน (WAL) |

สังเกตว่า **I (Isolation)** คือตัวที่ทำให้เกิด Lock ทั้งระบบ — ปรับ I ให้หลวมลง/เข้มขึ้นย่อมเปลี่ยนพฤติกรรม performance ทั้งเซิร์ฟเวอร์ได้ ตัวที่เหลือ (A, C, D) คือ "กติกาบังคับ" ที่ไม่ควรลดเลย ยกเว้นเคสพิเศษเช่น **Delayed Durability** หรือ **ADR** ซึ่งจะพูดใน Section 5.3

### โหมดของ Transaction — เริ่มเองหรือให้ engine เริ่มให้

| โหมด | ทำงานอย่างไร | ใครเป็นคน commit |
|:-----|:-------------|:-----------------|
| **Auto-commit** (default) | ทุกคำสั่งแยกเป็น 1 transaction ปิดทันทีที่สำเร็จ | engine ทำให้เอง |
| **Explicit** | นักพัฒนากำหนดเอง: `BEGIN TRAN ... COMMIT/ROLLBACK` | นักพัฒนา |
| **Implicit** (`SET IMPLICIT_TRANSACTIONS ON`) | คำสั่ง DML เปิด tran ให้เอง แต่**ต้องสั่ง COMMIT เอง** — ตกหล่นง่ายที่สุด ต้นตอคลาสสิกของ lock ค้าง | นักพัฒนา (โดยมักลืม) |

> [!WARNING]
> **อาชญากรรมที่พบบ่อยที่สุดของปัญหา blocking**: app เปิด transaction แล้ว "ทิ้งไว้" เพราะ (1) code path บาง branch ไม่ commit, (2) `SET XACT_ABORT OFF` + error กลางทาง, (3) รอ user input ใน tran หรือ (4) `IMPLICIT_TRANSACTIONS` เปิดแล้วลืมปิด — session จะเข้าสถานะ **sleeping พร้อม open transaction** และถือ lock ค้างตลอดไป

### ทดลองด้วยมือ: Auto-commit vs Explicit vs Rollback

```sql
USE AdventureWorks;

-- 0) เตรียมตารางทดสอบ (ลบทิ้งตอนจบ)
DROP TABLE IF EXISTS dbo.DemoTxn;
CREATE TABLE dbo.DemoTxn (ID INT IDENTITY PRIMARY KEY, Amount INT NOT NULL);
INSERT dbo.DemoTxn (Amount) VALUES (100), (200), (300);

-- 1) Auto-commit: คำสั่งเดียว = 1 transaction ปิดทันที
UPDATE dbo.DemoTxn SET Amount = Amount + 1 WHERE ID = 1;

-- 2) Explicit transaction: ทำสำเร็จทั้งหมด หรือยกเลิกทั้งหมด
BEGIN TRANSACTION;
    UPDATE dbo.DemoTxn SET Amount = Amount + 10 WHERE ID = 2;
    UPDATE dbo.DemoTxn SET Amount = Amount - 10 WHERE ID = 3;
COMMIT TRANSACTION;

-- 3) Rollback: ยังไม่ commit = ถอยได้ทั้งหมด
BEGIN TRANSACTION;
    UPDATE dbo.DemoTxn SET Amount = 999 WHERE ID = 1;
    SELECT ID, Amount FROM dbo.DemoTxn ORDER BY ID;   -- เห็น 999 (ภายใน tran เดียวกัน)
ROLLBACK TRANSACTION;

SELECT ID, Amount FROM dbo.DemoTxn ORDER BY ID;       -- กลับค่าเดิมเสมอ

DROP TABLE dbo.DemoTxn;
```

**ผลที่ได้ (รันจริง):** ครั้งแรก query กลาง tran เห็น `1 → 999` (เพราะ session เห็นงานของตัวเองเสมอ) แต่หลัง `ROLLBACK` ตารางกลับเป็น `101, 210, 290` — ไม่มีอะไรตกหล่น

### Nested Transaction กับ @@TRANCOUNT — กับดักที่คนไม่ค่อยดู

`BEGIN TRAN` ซ้อนกันได้ แต่จริง ๆ ไม่มี "transaction ย่อยจริง" — มีแค่ตัวนับ `@@TRANCOUNT` เพิ่ม และ `COMMIT` ที่อยู่ชั้นในแค่ "ลดตัวนับ" เท่านั้น ส่วน `ROLLBACK` ตัวเดียวยกเลิก**ทั้งกอง**:

```sql
SELECT @@TRANCOUNT AS open_transactions;   -- 0 = ปกติไม่มี tran เปิดอยู่
BEGIN TRANSACTION;                          -- @@TRANCOUNT = 1
BEGIN TRANSACTION;                          -- "ซ้อน" → @@TRANCOUNT = 2 (ไม่ได้เกิด tran ใหม่จริง)
SELECT @@TRANCOUNT AS nested_two;
ROLLBACK TRANSACTION;                       -- ยกเลิกทั้งหมดเหลือ 0 (ไม่ว่า rollback ชั้นไหน)
SELECT @@TRANCOUNT AS after_rollback;
```

**ผลที่ได้ (รันจริง):** `0 → 2 → 0` สรุป: `@@TRANCOUNT` คือมิเตอร์ที่ app ควรตรวจก่อน commit; ส่วน `BEGIN TRAN` ที่ซ้อนใน stored procedure เป็นแค่รายงานเจตนา — ยกเว้นจะใช้ savepoint (`SAVE TRAN`) ซึ่งอยู่นอกขอบเขตหลักสูตรนี้

---

## 2. ความวุ่นวายที่เกิดได้เมื่ออ่าน/เขียนพร้อมกัน

เพื่อเลือก isolation level ได้อย่างมีสติ เราต้องรู้ก่อนว่า "อาการเสีย" มีรูปไหนบ้าง — ให้เรียกว่า **Concurrency Anomalies**:

| อาการ | นิยามแบบเห็นภาพ | เช่น |
|:------|:----------------|:-----|
| **Dirty Read** | อ่านค่าที่อีก transaction **ยังไม่ commit** แล้วค่านั้นถูก rollback ทิ้ง — เราใช้ "ค่าที่ไม่เคยมีอยู่จริง" | รายงานยอดขายชั่วคราวโชว์ 10 ล้าน แต่ต้นทาง rollback ไปแล้ว |
| **Non-repeatable Read** | อ่านแถวเดิม 2 ครั้งใน tran เดียวได้ค่า**ต่างกัน** เพราะมีคน commit แก้ไขคั่น | เปิดหน้าจอใบสั่งซื้อ ราคารวมเปลี่ยนเองกลางอากาศ |
| **Phantom Read** | อ่านด้วยเงื่อนไขเดิม 2 ครั้ง ได้**จำนวนแถวต่างกัน** เพราะมีแถวใหม่ถูก INSERT คั่น | คิวรายงาน "order วันนี้" มีแถวเพิ่มระหว่างเดินรายงาน |
| **Lost Update** | สอง tran อ่านค่าเดิมพร้อมกัน แล้วต่างคนต่างเขียนทับ — คำแก้ของคนหนึ่งหายไป | สองจุดขายตัด stock จากค่าเดิมพร้อมกัน |

> สำหรับผู้เริ่มต้น: อย่าจำชื่อ — จาก **"อ่านไปแล้วเปลี่ยน"** (non-repeatable) กับ **"อ่านแล้วมีของใหม่แทรก"** (phantom) และ **"เห็นของที่ถูกยกเลิก"** (dirty) — สามอาการนี้คือเกณฑ์ตัดสินว่า isolation level ไหนพอแล้ว

---

## 3. Isolation Levels — บันไดกติกาตั้งแต่หลวมถึงเข้ม

**Isolation Level** = ระดับที่ transaction หนึ่งจะถูก "แยก" จากอีก transaction — เลือกได้ทั้งระดับ session (`SET TRANSACTION ISOLATION LEVEL ...`) และระดับ query ผ่าน table hint

ยิ่งขึ้นสูง ยิ่งป้องกันอาการมากขึ้น แต่ **ยิ่งถือ lock นานและเยอะ** → blocking ง่ายขึ้น:

| Isolation Level | Dirty Read | Non-repeatable | Phantom | กลไกที่ใช้ (Pessimistic) |
|:----------------|:----------:|:--------------:|:-------:|:--------------------------|
| `READ UNCOMMITTED` (หรือ hint `NOLOCK`) | ✅ เกิด | ✅ | ✅ | ไม่ขอ S lock เลย |
| `READ COMMITTED` **(default)** | ❌ ป้องกัน | ✅ เกิด | ✅ | ขอ S lock เฉพาะระหว่างอ่าน statement นั้น แล้วปล่อยทันที |
| `REPEATABLE READ` | ❌ | ❌ ป้องกัน | ✅ เกิด | ถือ S lock จนจบ transaction |
| `SERIALIZABLE` | ❌ | ❌ | ❌ ป้องกัน | ถือ S lock จนจบ tran + **Key-Range Lock** (Section 5.2) |

คู่แข่งฝั่ง **Optimistic (Row Versioning)** ที่ใช้ version store แทนการรอ:

| Isolation Level | ตัวเลือกเปิดที่ไหน | อ่านจากไหน | อาการที่เหลือ |
|:----------------|:-------------------|:-----------|:--------------|
| `RCSI` (READ_COMMITTED_SNAPSHOT) | Database option — เปลี่ยนพฤติกรรม default ของ READ COMMITTED | เวอร์ชัน commit ล่าสุด **ณ ต้น statement** | non-repeatable ยังเกิดได้ข้าม statement |
| `SNAPSHOT` | Database option + สั่ง per-session | เวอร์ชัน commit ล่าสุด **ณ ต้น transaction** | แก้ไขทับข้อมูลที่เปลี่ยนไป → error 3960 (update conflict) |

> **จุดเชื่อมโยง:** บันไดนี้จะถูกซูมอีกครั้งใน Section 5.2 (กลไก lock ฝั่ง pessimistic) และ Section 5.3 (กลไก versioning ฝั่ง optimistic + ADR)

### ตรวจว่า session เราใช้กติกาไหนอยู่

```sql
DBCC USEROPTIONS;
-- ดูแถว "isolation level" — บน DB ที่เปิด RCSI จะบอกว่า
-- "read committed snapshot" (คือ READ COMMITTED ที่ใช้ versioning)
```

**ผลที่ได้ (รันจริง):** บนเซิร์ฟเวอร์หลักสูตร (DB `AdventureWorks` เปิด RCSI) แถวสำคัญคือ `isolation level  read committed snapshot` — หลายคนเข้าใจผิดว่า "default = read committed แบบ pessimistic เสมอ" แต่ความจริง default ของ *DB* ถูกตั้งได้ผ่าน database option

```sql
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
DBCC USEROPTIONS;   -- เห็น isolation level เปลี่ยนตาม (เฉพาะ session นี้)
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;   -- คืน default ของ session
```

---

## 4. เห็นอาการจริง: เดโม 2 หน้าต่าง (Session A / Session B)

> เตรียม: เปิด SSMS 2 หน้าต่าง query แล้วรัน Session A ก่อน ปล่อยค้างไว้ แล้วค่อยรัน Session B (ระยะรวม ~15 วินาที) — เดโมชุดนี้รันจริงแล้วและคืนค่าข้อมูลให้ตารางเดิมทุกครั้ง (Session A ปิดด้วย ROLLBACK)

### เดโม 1: Dirty Read และการที่ RCSI "ช่วย SELECT ให้รอด"

```sql
-- Session A — เปิด tran เขียนแล้วค้างไว้ 15 วินาที แล้ว rollback
USE AdventureWorks;
BEGIN TRANSACTION;
    UPDATE Production.Product
    SET ListPrice = 123.45
    WHERE ProductID = 514;
    WAITFOR DELAY '00:00:15';
ROLLBACK TRANSACTION;   -- คืนค่าเดิม 133.34
```

```sql
-- Session B — รันหลัง Session A ประมาณ 3 วินาที (ตอน A ยังถือ tran ค้างอยู่)
USE AdventureWorks;
SET LOCK_TIMEOUT 3000;   -- จำกัดเวลารอ lock สูงสุด 3 วินาที/คำสั่ง (กันหน้าต่างค้าง)
SELECT ProductID, ListPrice FROM Production.Product WITH (NOLOCK) WHERE ProductID = 514;
SELECT ProductID, ListPrice FROM Production.Product WHERE ProductID = 514;
SELECT ProductID, ListPrice FROM Production.Product WITH (READCOMMITTEDLOCK) WHERE ProductID = 514;
```

**ผลที่ได้ (รันจริง) — สามบรรทัดสอนสามเรื่อง:**

| คำสั่ง | ผลลัพธ์ | บทเรียน |
|:-------|:---------|:---------|
| `WITH (NOLOCK)` | เห็น **123.45** ทันที | **Dirty Read จริง** — ค่านี้ถูก rollback ทิ้งในเวลาต่อมา ค่าที่เห็นจึง "ไม่เคยมีอยู่จริง" |
| SELECT ปกติ (RCSI) | เห็น **133.34** (ค่า commit ล่าสุด) ทันที ไม่รอ | RCSI อ่านเวอร์ชันเก่าแทนการรอ lock — reader ไม่ block |
| `WITH (READCOMMITTEDLOCK)` | ค้าง 3 วิ แล้วติด **Msg 1222: Lock request time out period exceeded** | จำลอง READ COMMITTED แบบ pessimistic — ต้องรอ X lock → นี่คือที่มาของ wait `LCK_M_S` |

> **ประเด็นสอนสำคัญ:** บน DB ที่เปิด RCSI (รวมถึง Azure SQL Database ที่เปิดเป็น default) SELECT ปกติจะไม่เคยโดน writer บล็อกแล้ว ถ้าจะสอนอาการ blocking คลาสสิกต้อง force ด้วย `READCOMMITTEDLOCK` หรือปิด RCSI ชั่วคราวบน VM ของผู้สอน

### เดโม 2: Non-repeatable Read — และเหตุผลที่ RCSI ≠ REPEATABLE READ

ข้อผิดพลาดที่เจอบ่อย: "เปิด RCSI แล้วข้อมูลนิ่งแล้วสินะ?" — ไม่ใช่ RCSI ให้ consistency **ระดับ statement** ไม่ใช่ระดับ transaction

```sql
-- Session A — อ่านสองรอบเว้นระยะ (ยังไม่ต้องเปิด tran ก็สาธิตได้)
USE AdventureWorks;
SELECT ProductID, ListPrice FROM Production.Product WHERE ProductID = 514;  -- 133.34
WAITFOR DELAY '00:00:06';
SELECT ProductID, ListPrice FROM Production.Product WHERE ProductID = 514;  -- เปลี่ยนแล้ว → non-repeatable read
```

```sql
-- Session B — แก้ไข (auto-commit) แล้วคืนค่าเดิม เพื่อไม่ปล่อยข้อมูลเพี้ยน
USE AdventureWorks;
UPDATE Production.Product SET ListPrice = 150.00 WHERE ProductID = 514;
WAITFOR DELAY '00:00:06';
UPDATE Production.Product SET ListPrice = 133.34 WHERE ProductID = 514;   -- คืนค่าเดิม
```

**ผลที่ได้ (รันจริง):** Session A เห็น `133.34` ครั้งแรก และ `150.00` ครั้งที่สอง — **non-repeatable read เกิดบน RCSI ได้จริง** เพราะแต่ละ statement ได้ snapshot ใหม่ของตัวเอง

ทีนี้ลองปิดทางด้วย `REPEATABLE READ` (ฝั่ง pessimistic ถือ S lock จนจบ tran):

```sql
-- Session A — REPEATABLE READ: ถือ S lock ตลอด transaction
USE AdventureWorks;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;
    SELECT ProductID, ListPrice FROM Production.Product WHERE ProductID = 514;  -- ถือ S lock ตลอด tran
    WAITFOR DELAY '00:00:08';
    SELECT ProductID, ListPrice FROM Production.Product WHERE ProductID = 514;  -- ค่าเดิมเสมอ (repeatable)
COMMIT TRANSACTION;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

```sql
-- Session B — พยายามแก้ระหว่างที่ A ถือ S lock
USE AdventureWorks;
SET LOCK_TIMEOUT 3000;
UPDATE Production.Product SET ListPrice = 150.00 WHERE ProductID = 514;  -- จะโดน S lock ของ Session A บล็อก
```

**ผลที่ได้ (รันจริง):** Session A อ่านสองรอบได้ค่า `133.34` เท่ากัน (repeatable จริง) ส่วน Session B ติด `Msg 1222` ภายใน 3 วิ — **trade-off ชัดเจน**: กัน non-repeatable read ได้ แต่แลกกับ writer ต้องรอ นี่คือเหตุผลที่ระบบ OLTP ส่วนใหญ่เลือก RCSI แล้วจัดการ "ความนิ่ง" ที่ application เอง (เช่น optimistic concurrency ด้วย `rowversion` คอลัมน์)

---

## 5. จับอาการด้วย DMV — มุมมองของผู้วินิจฉัย

เดโมข้างบนคือมุมมองผู้ถูกกระทำ แต่ในงานจริงเราจะมองจาก "Session C" ที่ถามเอนจินว่า **ใครกำลังเปิด transaction ค้าง**

```sql
-- transaction ไหนกำลังเปิดค้าง โดยเรียงจากเก่าสุด (ตัวเก่าสุดคือตัวต้องสงสัยก่อน)
SELECT
    s_tst.session_id,
    s_es.login_name AS [Login Name],
    DB_NAME(s_tdt.database_id) AS [Database],
    s_tdt.database_transaction_begin_time AS [Begin Time],
    s_tdt.database_transaction_log_record_count AS [Log Records],
    s_tdt.database_transaction_log_bytes_used AS [Log Bytes],
    s_tst.is_user_transaction
FROM sys.dm_tran_database_transactions AS s_tdt
INNER JOIN sys.dm_tran_session_transactions AS s_tst
    ON s_tdt.transaction_id = s_tst.transaction_id
INNER JOIN sys.dm_exec_sessions AS s_es
    ON s_tst.session_id = s_es.session_id
ORDER BY s_tdt.database_transaction_begin_time ASC;
```

**ผลที่ได้ (รันจริง):** เมื่อไม่มีใครเปิด tran ค้าง ผลคือ 0 แถว — แต่ถ้า Session A ของเดโมกำลัง `WAITFOR` อยู่ จะเห็นแถวของ session นั้นพร้อม `Log Records` ที่สะสม log ของ UPDATE ค้างไว้ (สังเกตตรงนี้ต่อได้ในหัวข้อ log truncation ของ Module 2/3 — open tran กัก log ไม่ให้ truncate)

ส่วนมุมมอง "ใครรอใครอยู่ตอนนี้" ใช้ `sys.dm_exec_requests` (จะซ้อมกันเต็ม ๆ ใน Section 5.2 กับแล็บ):

```sql
-- คู่ blocking ที่กำลังเกิดในเซิร์ฟเวอร์ตอนนี้ (ถ้าไม่มี = 0 แถว)
SELECT session_id, blocking_session_id, wait_type, wait_time, wait_resource
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0;
```

> [!TIP]
> `wait_time` หน่วยมิลลิวินาที — เจอแถวที่ `wait_type = LCK_M_*` และ `wait_time` สะสมเป็นพัน เป็นหมื่น แปลว่า blocking ยาวผิดปกติ ให้ไล่หา head blocker ด้วยสคริปต์ `05_Analyze_Blocking.sql` (ใน Section 5.2) และจำไว้ว่าตัวเลขนี้ย้อนอดีตไม่ได้ — ถ้าเกิดแล้วผ่านไป ให้ดูค่าสะสมใน `sys.dm_os_wait_stats` (Module 1) แทน

และเครื่องมือคู่ใจของนายพลางกาย: **หา session ที่เปิด tran ค้างแบบนอนหลับ** (sleeping with open transaction) — อาการของ app ที่เปิด tran แล้วลืมปิด สังเกตว่าแถวเหล่านี้ไม่ได้ "รันอะไรอยู่" แต่กุมกุญแจไว้เฉย ๆ:

```sql
-- session ไหนเปิด transaction ค้างอยู่ (มุ่งส่อง is_user_process = 1 คือ app/คน ไม่ใช่ background)
SELECT session_id, login_name, program_name, open_transaction_count, last_request_start_time
FROM sys.dm_exec_sessions
WHERE open_transaction_count > 0
  AND is_user_process = 1
ORDER BY last_request_start_time;
```

**ผลที่ได้ (รันจริง):** เซิร์ฟเวอร์ปกติไม่มีใครเปิด tran → 0 แถว; ระหว่างที่ Session A ของเดโมค้าง `WAITFOR` จะเห็นแถวของมันพร้อมเวลาเริ่ม request ล่าสุด — ใช้ `last_request_start_time` ตัดสินว่า "ค้างมานานเท่าไรแล้ว" และใช้ `program_name` ไปตามรายชื่อ app ที่เขียน code พร่องได้ทันที

---

## 6. เชื่อมต่อกับ Wait Statistics — เมื่อ Section นี้ทำให้เซิร์ฟเวอร์ "รอ"

ทุกอาการของ Section นี้ปรากฏในบัญชีการรอของ engine ตามสมการจาก Module 1 (`Response Time = Service Time + Wait Time`):

| Wait Type | แปลว่า | ที่มาจาก Section นี้ |
|:----------|:--------|:---------------------|
| `LCK_M_S` | รอ Shared lock (อ่าน) | อ่านแถวที่คนอื่นถือ X อยู่ (เดโม 1 บรรทัดที่ 3) |
| `LCK_M_X` | รอ Exclusive lock (เขียน) | เขียนแถวที่คนอื่นถือ X/U อยู่ (เดโม REPEATABLE READ) |
| `LCK_M_U` | รอ Update lock | UPDATE กำลังสแกนหาแถวที่จะแก้ (ลงลึกใน Section 5.2) |
| `LCK_M_SCH_M` | รอ schema modification | DDL ติดคิวหลัง query เก่า (Section 5.2) |
| `WRITELOG` | รอ flush ลง transaction log | commit บ่อย ๆ ทีละแถว — ยิ่ง tran สั้นยิ่งเจอ (Module 2) |

> อย่าลืมว่า wait เป็น "อาการ ไม่ใช่โรค" — `LCK_M_*` สูงบอกว่ามี blocking แต่ไม่บอกว่าใครถือ lock และทำไม นั่นคือเหตุผลที่ Section ถัดไปเราต้องลงไปถึง **Lock Manager** กับ **granularity ของ lock** กันเลย

---

## สรุป Section 5.1

1. **Transaction + ACID** คือสัญญาที่ engine ให้กับเรา — Isolation คือตัวที่เราเลือกระดับได้และแลกกับ performance โดยตรง
2. **อาการเสีย 3 แบบ** (dirty / non-repeatable / phantom) คือเกณฑ์เลือก isolation level — ไม่ต้องเข้มกว่าที่จำเป็น
3. **Pessimistic** (lock) กับ **Optimistic** (row versioning) คือสองโลก — RCSI ทำให้ READ COMMITTED ของเราอยู่ฝั่ง optimistic โดยไม่แตะ code และเป็นตัวเลือกจริงจังสำหรับ OLTP
4. บน DB ที่เปิด RCSI แล้ว SELECT ไม่ถูก writer บล็อก แต่ **writer ยัง block writer** เสมอ — และ RCSI ให้ consistency ระดับ statement เท่านั้น
5. เครื่องมือสังเกตคือ `DBCC USEROPTIONS`, `@@TRANCOUNT`, `sys.dm_exec_requests`, `sys.dm_tran_database_transactions` และ wait `LCK_M_*` จาก Module 1

### ตรวจความเข้าใจ

1. อาการ Dirty Read กับ Non-repeatable Read ต่างกันอย่างไร — และ isolation level ใดเป็นขั้นต่ำที่กันแต่ละอาการ?
2. เปิด RCSI แล้ว SELECT ยังเห็น non-repeatable read ได้หรือไม่ เพราะอะไร? (คำใบ้: consistency ระดับอะไร)
3. `BEGIN TRAN` ซ้อนกันสองชั้นแล้ว `ROLLBACK` ชั้นใน — `@@TRANCOUNT` เป็นเท่าไร และงานของชั้นนอกเป็นอย่างไร?
4. Session ไหนคือ "head blocker" และจะระบุมันได้จาก DMV ตัวใด (ชื่อคอลัมน์อะไร)?
5. แอปรายงานว่าระบบค้างเป็นพัก ๆ แต่ `sys.dm_os_wait_stats` เห็น `LCK_M_X` สูงสุด — เราจะใช้ query ไหนจาก Section นี้หา "รายชื่อผู้ต้องสงสัย" ได้ทันที?
6. เพราะอะไร `NOLOCK` อาจทำให้รายงานแสดงตัวเลขที่ "ไม่เคยมีอยู่จริง"?

**➡ ถัดไป:** [5.2 Locking Internals — กลไก Lock ข้างใน](../02_Locking_Internals/README.md)

---

[⬅ ก่อนหน้า: Module 05 Overview](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [5.2 Locking Internals](../02_Locking_Internals/README.md)
