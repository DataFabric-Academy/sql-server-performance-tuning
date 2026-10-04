# Quiz Bank — บทที่ 5: Concurrency (Blocking, Locking, Isolation, ADR & Optimized Locking)

> ครอบคลุมวัตถุประสงค์การเรียนรู้ของบทที่ 5 ตาม [Course_Guide_4Days.md](../../Trainer_Docs/Course_Guide_4Days.md): Lock Modes (S, U, X, IS, IX), Lock Granularity, Latches vs Locks, Isolation Levels ครบทุกระดับ, Deadlock Analysis & Prevention, ADR (PVS, sLog, Instant Recovery) และ Optimized Locking (TID/LAQ) — ใช้คู่กับ [Sections](README.md) และ [Labs](Labs/README.md)
> **รูปแบบ:** ข้อ 1–9 multiple choice · ข้อ 10–15 ตอบสั้น · เฉลยพร้อมคำอธิบายอยู่ท้ายไฟล์ (อย่าเลื่อนดูก่อนตอบ!)

---

## ส่วนที่ 1: Multiple Choice

### Q1. คุณสมบัติ ACID ข้อใดที่ "เราเลือกระดับได้" และเป็นตัวกำหนดปริมาณ lock ของระบบโดยตรง?
- A. Atomicity
- B. Consistency
- C. Isolation
- D. Durability

### Q2. Session A เปิด transaction แก้ราคาสินค้าแล้วค้างไว้ (ยังไม่ commit) Session B รัน `SELECT ... WITH (NOLOCK)` และเห็นราคาใหม่ ต่อมา Session A ROLLBACK — Session B อ่านค่าที่ "ไม่เคยมีอยู่จริง" อาการนี้เรียกว่าอะไร?
- A. Phantom Read
- B. Dirty Read
- C. Non-repeatable Read
- D. Lost Update

### Q3. Isolation Level ใดเป็นขั้นต่ำที่ป้องกันทั้ง Dirty Read และ Non-repeatable Read (แต่ยังปล่อย Phantom Read)?
- A. READ UNCOMMITTED
- B. READ COMMITTED
- C. REPEATABLE READ
- D. SERIALIZABLE

### Q4. บน database ที่เปิด RCSI แล้ว ข้อใดถูกต้องที่สุด?
- A. ไม่มี blocking เกิดขึ้นบน database นี้อีกเลย
- B. SELECT ไม่ถูก writer บล็อก แต่ writer ยัง block writer ได้
- C. SELECT กับ writer ยัง block กันเหมือนเดิม แต่ใช้ tempdb แทน lock
- D. RCSI ทำให้ทุก statement ใน transaction เดียวเห็นภาพข้อมูลชุดเดียวกัน

### Q5. UPDATE แถวเดียวใน clustered table ทำไม `sys.dm_tran_locks` ถึงแสดง lock หลายระดับ เช่น `DATABASE (S)`, `OBJECT (IX)`, `PAGE (IX)`, `KEY (X)`?
- A. เพราะ engine ครุ่นคิดไม่ทัน จึงล็อกซ้ำหลายชั้นเพื่อกันพลาด
- B. เพราะ KEY (X) คือ lock ของจริง ส่วน IX บน PAGE/OBJECT คือ Intent Lock ประกาศเจตนาให้ระดับแม่ตัดสินใจได้เร็ว
- C. เพราะ PAGE (IX) ล็อกทั้งหน้าไว้ไม่ให้ใครแก้
- D. เพราะ DATABASE (S) บังคับให้ session อื่นอ่านอย่างเดียว

### Q6. โหมด U (Update) Lock มีจุดประสงค์หลักคืออะไร?
- A. อนุญาตให้หลาย session UPDATE แถวเดียวกันพร้อมกัน
- B. ขั้นสแกนของ UPDATE ขอ U ซึ่ง "แชร์กับ S ได้ แต่ไม่แชร์กับ U/X" — กัน deadlock จากการที่สอง UPDATE ต่างถือ S แล้วชิงแปลงเป็น X พร้อมกัน
- C. บังคับให้ UPDATE เร็วขึ้นโดยข้าม version store
- D. แทน X lock ตลอด transaction เพื่อประหยัด memory

### Q7. Lock Escalation เกิดเมื่อใด และผลที่ตามมาคืออะไร?
- A. เมื่อ lock เกิน ~5,000 ตัวต่อ statement (หรือ memory เกินโควตา) — รวมเป็น table-level X lock ประหยัด memory แต่ concurrency ตกหนัก
- B. เมื่อ transaction ยาวเกิน 60 วินาที — เปลี่ยน row lock เป็น page lock
- C. เมื่อจำนวน connection เกิน max worker threads — ปล่อย lock ทั้งหมด
- D. เมื่อเปิด RCSI — engine ล็อกเฉพาะ page แทนแถวเพื่อคุม tempdb

### Q8. กลไกใดที่ SERIALIZABLE ใช้ป้องกัน Phantom Read ซึ่งการล็อก "แถวที่มีอยู่" ทั้งหมดไม่พอ?
- A. Intent Lock บนระดับ TABLE
- B. Key-Range Lock ล็อก "ช่องว่าง" ระหว่างค่าใน index (เช่น `RangeS-S`, `RangeI-N`)
- C. Spinlock บน lock hash bucket
- D. Sch-M lock บนตาราง

### Q9. เกี่ยวกับ Deadlock ข้อใด "ไม่ถูกต้อง"?
- A. Lock Monitor สำรวจวงจรเป็นระยะ และเร่งความถี่เมื่อเจอ deadlock แล้ว
- B. Victim ถูกเลือกโดยดูต้นทุน rollback (โดยประมาณจาก log record) — app ตั้ง `DEADLOCK_PRIORITY` ได้
- C. Victim ได้ Error 1205 และ transaction ถูก rollback เอง — app ควรมี retry
- D. Deadlock แก้รากที่สุดด้วยการเพิ่ม CPU ให้เซิร์ฟเวอร์

### Q10 (เลือกได้หลายข้อ). กลุ่ม wait ใดที่เกี่ยวกับ "การแย่งชิง" แบบไม่ผูกกับ transaction ของผู้ใช้? (เลือก 2 ข้อ)
- A. `LCK_M_X`
- B. `PAGELATCH_EX`
- C. `SOS_SCHEDULER_YIELD`
- D. `PAGEIOLATCH_SH`

---

## ส่วนที่ 2: ตอบสั้น

### Q11. แยกความต่าง Lock / Latch / Spinlock ด้วยสามมิติ: ปกป้องอะไร, ถือนานแค่ไหน, และวิธี "รอ" ของ thread

### Q12. `PAGEIOLATCH_SH` กับ `PAGELATCH_EX` ต่างกันอย่างไร — อาการแบบไหนแก้ด้วย storage แบบไหนแก้ด้วย schema/design?

### Q13. คุณต้องสอนเดโม deadlock แล้วดึง Deadlock Graph มาโชว์บนจอ — จะดึงจากที่ใด ด้วย query รูปแบบใด และมีข้อสังเกตอะไรจาก build ใหม่ (เช่น SQL Server 2025) เกี่ยวกับ `ring_buffer`?

### Q14. ADR มี 4 ชิ้นส่วนหลัก — อธิบายสั้น ๆ ว่าแต่ละชิ้น (PVS, Logical Revert, sLog, Cleaner) ทำอะไร และเพราะอะไร rollback ของ tran ยักษ์จึง "เกือบทันที" ภายใต้ ADR?

### Q15. Optimized Locking (SQL Server 2025): (ก) ต้องเปิดอะไรก่อนถึงจะเปิดได้ และควรเปิดคู่กับอะไร (ข) TID Lock เปลี่ยนพฤติกรรม lock อย่างไรจากเดิม (ค) LAQ ข้ามอะไรไป และเมื่อแถวถูกแก้ไปหลังตรวจ predicate แล้ว engine ทำอะไร?

---

## เฉลยพร้อมคำอธิบาย

<details>
<summary><b>เฉลย Q1</b> — C. Isolation</summary>

A/C/D เป็น "สัญญาบังคับ" ที่ engine รักษาด้วย Transaction Log (WAL) ส่วน **Isolation** คือระดับที่เลือกได้ผ่าน isolation level — ยิ่งเข้ม ยิ่งถือ lock มาก/นาน (หรือใช้ versioning) จึงเป็นตัวหมุนสมดุล Consistency ↔ Performance ของโมดูลนี้
</details>

<details>
<summary><b>เฉลย Q2</b> — B. Dirty Read</summary>

NOLOCK (READ UNCOMMITTED) อ่านค่าที่ยังไม่ commit — ค่าที่เห็นถูก rollback ทิ้งจึง "ไม่เคยมีอยู่จริง" (Non-repeatable read คืออ่านแถวเดิมสองรอบได้ค่าต่างกัน; Phantom คือจำนวนแถวเปลี่ยน)
</details>

<details>
<summary><b>เฉลย Q3</b> — C. REPEATABLE READ</summary>

READ COMMITTED ปิด dirty read แต่ non-repeatable ยังเกิดได้ (ปล่อย S lock ทันทีจบ statement) REPEATABLE READ ถือ S lock จนจบ transaction จึงกันทั้งสองอย่าง แต่ phantom ยังเกิด (ต้อง SERIALIZABLE + Key-Range)
</details>

<details>
<summary><b>เฉลย Q4</b> — B</summary>

RCSI ทำให้ reader อ่านเวอร์ชัน commit ล่าสุดจาก version store แทนการรอ lock (reader ไม่ block) — แต่การเขียนยังใช้ lock ปกติ ดังนั้น writer ยัง block writer เสมอ ข้อ D ผิดเพราะนั่นคือ SNAPSHOT (transaction-level) ไม่ใช่ RCSI (statement-level)
</details>

<details>
<summary><b>เฉลย Q5</b> — B</summary>

Hierarchy: ล็อกแถวจริงด้วย KEY (X) แล้ว "ประกาศเจตนา" ขึ้นแม่ด้วย IX — ทำให้ใครที่ต้องการล็อกระดับหยาบ (เช่น DDL) ตัดสินใจจาก OBJECT ตัวเดียว โดยไม่ต้องไล่เช็กทุกแถว (DATABASE S มีตลอด ไม่ได้ห้ามใคร)
</details>

<details>
<summary><b>เฉลย Q6</b> — B</summary>

หาก UPDATE ใช้ S ระหว่างสแกน: สอง UPDATE อาจถือ S ทับกันแล้ว "ชิง" แปลง X พร้อมกัน → deadlock คลาสสิก U แก้เพราะ U ยอมให้แชร์กับ reader (S) แต่ไม่ยอมแชร์กับ U อีกตัว — ตัวใดได้ก่อน อีกตัวรอตั้งแต่คิวสแกน
</details>

<details>
<summary><b>เฉลย Q7</b> — A</summary>

เกณฑ์ตำราคือ ~5,000 locks ต่อ statement (หรือ memory threshold) — รันจริงบน SQL Server 2025 พบ 6,000 แถวยังไม่ escalate แต่ 10,000 escalate เป็น OBJECT (X) เหลือ ~3 locks: ตัวเลขจริงเป็นค่าประมาณที่ขึ้นกับ memory/build ผลข้างเคียงคือทั้งตารางเป็นของคนเดียว → blocking เดือด ควบคุมด้วย `ALTER TABLE ... SET (LOCK_ESCALATION = ...)`
</details>

<details>
<summary><b>เฉลย Q8</b> — B</summary>

แถวใหม่ "ยังไม่มีตัวตน" จึงล็อกไม่ได้ — ต้องล็อกช่องระหว่างค่า (รวม next-key boundary) ทำให้ INSERT ช่วงนั้นรอ โหมดที่เจอ: `RangeS-S` (อ่าน), `RangeI-N` (แทรก), `RangeX-X` (แก้)
</details>

<details>
<summary><b>เฉลย Q9</b> — D</summary>

Deadlock เป็นปัญหา "ลำดับการเข้าถึง/ระยะเวลาถือ lock" ไม่ใช่ขากำลัง — แก้ด้วย access order เดียวกัน, tran สั้น, ไม่รอ user input, RCSI, index ที่ดี A/B/C ล้วนถูกต้อง
</details>

<details>
<summary><b>เฉลย Q10</b> — B และ C</summary>

`PAGELATCH_*` คือ latch (ผูกกับ thread สั้น ๆ ไม่ใช่ transaction) และ `SOS_SCHEDULER_YIELD` คือหมด quantum แล้วยอมเสีย CPU — ทั้งคู่ไม่เกี่ยวกับ transaction ของผู้ใช้ ส่วน `LCK_M_X`/`PAGEIOLATCH_SH` เกี่ยวกับ lock ข้อมูลและ I/O ของ page จริง (PAGEIOLATCH ก็เป็น latch แต่บริบทคือการรอ disk เพื่อให้ reader ใช้ข้อมูล)
</details>

<details>
<summary><b>เฉลย Q11</b></summary>

- **Lock** — ปกป้อง "ข้อมูลผู้ใช้" (row/page/table) · ถือนาน **ตลอด transaction** · รอโดย **นอน** (blocking, wait `LCK_M_*`) และผูกกับ transaction
- **Latch** — ปกป้อง **page ใน buffer pool ขณะ engine กำลังจัดการมัน** · ถือสั้น (ไม่ถึงจบ statement) · นอนรอเช่นกัน (wait `PAGELATCH_*`, `PAGEIOLATCH_*`) ผูกกับ thread
- **Spinlock** — ปกป้อง **โครงสร้าง internal** (lock hash, memory clerk list) · สั้นมาก · **ไม่นอน — วนลูปกิน CPU** (ไม่มี wait type ตรง ๆ เห็นเป็น CPU สูง + `sys.dm_os_spinlock_stats`)
</details>

<details>
<summary><b>เฉลย Q12</b></summary>

`PAGEIOLATCH_SH` = รอ **อ่าน page จาก disk เข้า memory** (แปลว่าข้อมูลยังไม่อยู่ใน buffer) → แก้ด้วยฝั่ง **storage/สถาปัตยกรรม I/O** (ลด logical reads ด้วย index, storage เร็ว, memory เพียงพอ) `PAGELATCH_EX` = page **อยู่ใน memory แล้ว** แต่หลาย thread ต่อแถวจอง page เดียว (hot page เช่น last-page insert, ยุคเก่า: tempdb allocation) → แก้ด้วย **design**: partition/cluster key, invert index, แยกตาราง hot cold
</details>

<details>
<summary><b>เฉลย Q13</b></summary>

ดึงจาก XEvent session มาตรฐาน `system_health` (event `xml_deadlock_report`) — อ่านจาก **event_file target**:

```sql
SELECT TOP (10)
    x.value('(@timestamp)[1]', 'DATETIME2') AS deadlock_at,
    CAST(x.query('(event/data[@name="xml_report"]/value)[1]').value('.','nvarchar(max)') AS XML) AS deadlock_graph
FROM (
    SELECT CAST(event_data AS XML) AS event_data
    FROM sys.fn_xe_file_target_read_file('system_health*.xel', NULL, NULL, NULL)
    WHERE object_name = 'xml_deadlock_report'
) AS ed
CROSS APPLY ed.event_data.nodes('event') AS n(x)
ORDER BY deadlock_at DESC;
```

คลิก XML ใน SSMS = ได้ Deadlock Graph แบบภาพ (วง ✗ คือ victim) ข้อสังเกตจากการรันจริงบน build ใหม่: `ring_buffer` ของ system_health **ไม่เก็บ** xml_deadlock_report — ต้องอ่านจาก event_file (`sys.fn_xe_file_target_read_file('system_health*.xel', ...)`) และ timestamp เป็น attribute ของ event (`(@timestamp)[1]`) ไม่ใช่ element ลูก
</details>

<details>
<summary><b>เฉลย Q14</b></summary>

- **PVS** — เก็บเวอร์ชันแถว **ใน user database** (แทน tempdb) ทั้ง on-row และ off-row internal table
- **Logical Revert** — process พื้นหลังทำ undo แบบตรรกะทีละแถวจาก PVS: rollback/KILL จบ "ทันที" ในเชิง availability (transaction ถูกตัดธง aborted reader ข้ามเวอร์ชันของมัน) และปล่อย lock ทันที
- **sLog** — สตรีม log รองใน memory เก็บเฉพาะ **non-versioned operations** (cache invalidation, lock acquisition ฯลฯ) เบาและถูก checkpoint/truncate รอบตัว → redo/undo เร็วและ log หลัก truncate ก้าวร้าวได้
- **Cleaner** — กวาดเวอร์ชันที่ไม่มีใครอ้างออกจาก PVS (2022+: ทำ multi-thread ได้)

เหตุผลที่ undo ทันที: การแก้แบบ versioned **ไม่ต้องเดิน log ย้อน** — แค่ตัดธง tran เป็น aborted แล้วให้ logical revert ค่อย ๆ จัดตามหลัง ส่วน undo ที่เหลือมีแค่ non-versioned ops ซึ่งจำกัดและอยู่ใน sLog จึงจบในเวลาคงที่ ไม่ขึ้นกับขนาด tran
</details>

<details>
<summary><b>เฉลย Q15</b></summary>

(ก) **ต้องเปิด ADR ก่อน** (ปิด ADR ต้องปิด OL ก่อน) และ **แนะนำให้เปิด RCSI คู่กัน** — LAQ ทำงานเฉพาะเมื่อ RCSI เปิด; บน SQL Server 2025 ฟีเจอร์ **ปิด default** (ต่างจาก Azure SQL ที่เปิดตลอด) เปิดด้วย `ALTER DATABASE ... SET OPTIMIZED_LOCKING = ON`

(ข) **TID Lock** — แต่ละแถวประทับ TID ของผู้แก้ล่าสุด DML ยังใช้ row/page lock ชั่วขณะตอนแก้ **แต่ปล่อยทันทีที่แถวนั้นแก้จบ** เหลือ X lock คู่ TID ตัวเดียวถือจนจบ transaction (คนรอมาขอ S บน TID) — lock memory ลดมาก, lock escalation แทบไม่เกิด, deadlock บางรูปแบบหาย (schema lock ยังเดิม)

(ค) **LAQ** — ข้ามการขอ U lock ระหว่างสแกน: ตรวจ predicate บนเวอร์ชัน commit ล่าสุดโดยไม่ล็อก แถวไม่ตรงข้ามเฉย ๆ ถ้าแถวถูกแก้ไปหลังตรวจ → engine **requalify (ตรวจซ้ำ)** ก่อนแก้จริง — ไม่มี error โผล่หา user; ถ้า operator requalify ไม่ได้ → abort ภายในแล้วรันใหม่แบบไม่ใช้ LAQ (XEvent `lock_after_qual_stmt_abort`) — ผลข้างเคียงที่ต้องรู้: workload ที่พึ่งลำดับเข้มงวดอาจได้ผลลัพธ์ต่างจากเดิม ต้องใช้ isolation เข้มขึ้นเฉพาะจุด
</details>

---

**ท้ายชุดข้อสอบ:** ทำคะแนนได้ ≥ 12/15 ถือว่าผ่านมาตรฐานบทที่ 5 — ถ้ายังไม่ถึง ให้ย้อนอ่าน [5.1 Concurrency & Transactions](Sections/01_Concurrency_Transactions/README.md) → [5.2 Locking Internals](Sections/02_Locking_Internals/README.md) → [5.3 ADR & Optimized Locking 2025](Sections/03_ADR_Optimized_Locking_2025/README.md) และทำ [Labs](Labs/README.md) ซ้ำอีกรอบ
