# Quiz Bank — บทที่ 6: Statistics & Index Internals (CE, B-Tree, Covering Index, Fragmentation, Columnstore)

> ครอบคลุมวัตถุประสงค์การเรียนรู้ของบทที่ 6 ตาม [Course_Guide_4Days.md](../Trainer_Docs/Course_Guide_4Days.md): Statistics (Header/Density/Histogram) & Cardinality Estimation, Heap vs Clustered/Nonclustered B-Tree, Missing/Bad/Overlapping Index และออกแบบ Index ใหม่ตาม Workload, Fragmentation/Rebuild-Reorganize และ Columnstore (Rowgroup/Segment/Deltastore/Segment Elimination/Batch Mode) — ใช้คู่กับ [Sections](README.md) และ [Labs](Labs/README.md)
> **รูปแบบ:** ข้อ 1–10 multiple choice · ข้อ 11–15 ตอบสั้น · ข้อ 16–18 multiple choice (เชิงลึก Section 6.3/6.1) · เฉลยพร้อมคำอธิบายอยู่ท้ายไฟล์ (อย่าเลื่อนดูก่อนตอบ!)

---

## ส่วนที่ 1: Multiple Choice

### Q1. องค์ประกอบของ Statistics สามส่วนถูกใช้ "ตอนไหน" อย่างถูกต้องคือข้อใด?
- A. Header → ใช้ตอน WHERE เทียบค่า / Density → ตรวจความเก่า / Histogram → ใช้ตอน GROUP BY
- B. Header → ตรวจความเก่า (last_updated, rows sampled) / Density Vector → ช่วย GROUP BY/multi-column join / Histogram (≤ 200 steps) → ตอบ WHERE/range query
- C. ทั้งสามส่วนถูกอ่านเฉพาะตอน `UPDATE STATISTICS` เท่านั้น
- D. Histogram เก็บได้ไม่จำกัดจำนวน step เพื่อความแม่นยำสูงสุด

### Q2. แล็บจริง: คิวรี `WHERE Status = 1` บนตารางที่ histogram ยังสร้างจาก seed 100 แถว (ทั้งหมด Status = 0) แต่ตารางมีจริง 50,100 แถว — plan รายงาน **estimated 223.83 vs actual 50,000** — อาการประเภทใด และผลกระทบที่ตามมาคืออะไร?
- A. Overestimation — จ่าย memory grant มหาศาล และเลือก Hash Join ฟุ่มเฟือย
- B. Underestimation — เสี่ยง Spill to tempdb (grant ไม่พอ) และเลือก Nested Loops จิ้มทีละแถวกับตารางใหญ่
- C. ค่า estimated ผิดแต่ไม่มีผลใดต่อ plan เพราะ optimizer อ่านค่าจริงตอน runtime
- D. Statistics corruption — ต้อง REBUILD INDEX ทุกตัว

### Q3. เกณฑ์ auto-update statistics ข้อใดถูกต้อง?
- A. SQL 2014 ลงไป: 20% + 500 rows — ตั้งแต่ SQL 2016 (compat 130+) เป็น dynamic threshold ตามขนาดตาราง ทำให้ update ถี่ขึ้นโดยเฉพาะตารางใหญ่
- B. เป็น 20% + 500 rows ตลอดมาถึงทุกรุ่น
- C. Auto-update ทำงานทุกคืนตอน 03:00 เสมอ
- D. Auto-update อัปเดตเฉพาะ statistics ที่สร้างด้วย `WITH FULLSCAN` เท่านั้น

### Q4. แล็บสร้าง data skew แล้วพบว่า query "ก่อน" ได้ estimated ตรงจนไม่เห็น skew เลย — ต้องใช้คู่ `sp_autostats ... 'OFF'` + `OPTION (RECOMPILE)` เพราะอะไร?
- A. เพราะ AUTO_UPDATE_STATISTICS ON (default) อัปเดต stats ทันทีตอน compile จึงกลบทลาย skew — พอปิดระดับตารางแล้ว แผนเก่าจะ **ไม่ถูก invalid** เมื่อรัน `UPDATE STATISTICS` จนต้องบังคับ RECOMPILE ให้ compile ใหม่อ่าน histogram ใหม่
- B. เพราะ `sp_autostats` เร่ง `UPDATE STATISTICS` ให้เร็วขึ้นสามเท่า
- C. เพราะ OPTION (RECOMPILE) บังคับอ่าน histogram จาก disk โดยไม่ใช้ cache
- D. เพราะ AUTO_UPDATE_STATISTICS ต้องปิดระดับ database จึงใช้ `sp_autostats` แทน

### Q5. คุณสมบัติ 4 ข้อของ Clustered Index Key (Unique, Narrow, Static, Ever-increasing) — GUID สุ่ม (NEWID) ผิดข้อไหน และผลที่ engine ต้องจ่ายคืออะไร?
- A. ผิดข้อ Narrow — เสีย disk เปล่าเท่านั้น
- B. ผิดข้อ Ever-increasing — insert สุ่มตำแหน่งทำให้เกิด page split ตลอด (แล็บจริง frag 98.5%, 132 pages กับ identity 86 pages) และถ้า key ไม่ unique engine ยังต้องเติม **uniqueifier 4 bytes**
- C. ผิดข้อ Static — GUID เปลี่ยนค่าเองทุกวัน
- D. GUID ผ่านครบทั้งสี่ข้อ เพราะค่าไม่ซ้ำและขนาดคงที่

### Q6. แล็บจริง: คิวรี `SELECT BusinessEntityID, FirstName, LastName ... WHERE MiddleName = N'J.'` ลด logical reads จาก **106 → 4** หลังสร้าง `IX_Person_MiddleName_cover (MiddleName) INCLUDE (FirstName, LastName)` — เหตุใด INCLUDE จึงจำเป็น และทำไมถ้าเปลี่ยนเป็น `SELECT *` ผลจะไม่ลดตามทฤษฎี?
- A. INCLUDE ทำให้ index เรียงตาม FirstName ด้วย; SELECT * ใช้ index ไม่ได้เพราะความยาวชื่อ
- B. INCLUDE ยกคอลัมน์ที่ SELECT ต้องใช้ไปเก็บที่ **leaf level** โดยไม่เข้าเป็น key เรียง — query จึงจบใน index เดียว (Index Seek ไม่ต้อง Key Lookup) แต่ SELECT * ต้องการคอลัมน์อื่นอีกมาก (เช่น XML) จึงยังต้องกลับไปอ่าน table ทุกแถว
- C. INCLUDE บีบอัดข้อมูลให้ page เล็กลง 50%
- D. INCLUDE ใช้ได้เฉพาะ clustered index

### Q7. ข้อควรระวังของ Missing Index DMV/hint ข้อใดถูกต้อง?
- A. คำแนะนำถูกต้อง 100% — สร้างตามได้ทันทีเสมอ
- B. ต้อง review เองเสมอ: ไม่จัดลำดับ key/INCLUDE ให้, ไม่รวมคำแนะนำซ้ำทับซ้อน (consolidate), และ **ไม่ตรวจ index ที่มีอยู่ก่อน** — แล็บจริง: แนะนำเดิม (LastName = 'Anderson') ถูก cover โดย `IX_Person_LastName_FirstName_MiddleName` ที่มากับ DB แล้ว จึงไม่ขึ้น missing index เลย
- C. Missing Index hint รู้จัก filtered index เสมอ
- D. DMV ลบประวัติตัวเองทุกครั้งที่ restart — จึงใช้ได้เฉพาะระหว่างวิ่ง query

### Q8. จากแล็บ: index `dbo.DatabaseLog.PK_DatabaseLog_DatabaseLogID` มี **reads = 0, writes = 25** — จะตัดสินใจอย่างไร และข้อควรระวังคืออะไร?
- A. DROP ทันที — reads 0 แปลว่าไร้ค่าเสมอ ไม่ต้องดูอย่างอื่น
- B. เข้าเครื่องมือตัดสิน (ผู้สมัครถูก DROP) แต่ยืนยันก่อนว่าไม่ใช่ PK/Unique constraint และไม่ใช่ index ที่ batch รายเดือน/ปีใช้ — ต้องมี baseline ยาว ≥ 1 business cycle ก่อนตัดสิน
- C. REBUILD ให้บ่อยขึ้น เพราะ writes สูงทำให้ fragmentation
- D. สร้าง index ที่สองครอบคอลัมน์เดิมเพิ่ม เพื่อแข่งกันให้ optimizer เลือก

### Q9. เกณฑ์จัดการ fragmentation ที่แล็บใช้ ข้อใดถูกต้อง (พร้อมเงื่อนไขขนาด)?
- A. ทุก index ที่เกิน 5% ต้อง REBUILD ทันที
- B. > 30% + ใหญ่พอ (`page_count > 1000`) → REBUILD; 5–30% → REORGANIZE; < 5% ปล่อยไว้ — สำรวจด้วย `sys.dm_db_index_physical_stats(..., 'LIMITED')` แบบเบาเพื่อดู % หยาบ ๆ
- C. REORGANIZE ใช้กับ 30% ขึ้นไป เพราะทำงาน online เสมอ
- D. Fragmentation วัดจากจำนวน row ที่ลบไปแล้ว

### Q10. โครงสร้าง Columnstore ข้อใดเรียงกลไกถูกต้อง?
- A. Rowgroup (~1 ล้านแถวต่อกลุ่ม) ถูกบีบอัดเป็น Segment (หนึ่ง Segment ต่อหนึ่ง column) — insert เล็ก ๆ ไปพักที่ **Deltastore** ก่อน แล้ว **Tuple Mover** (background) ย้ายเข้า compressed rowgroup; ลบใช้ **Deleted Bitmap** เพราะ segment แก้ตรงไม่ได้
- B. Deltastore เก็บข้อมูลหลังบีบอัดแล้ว / Tuple Mover ลบ segment ที่เก่า
- C. Rowgroup รองรับไม่จำกัดจำนวนแถว / Deleted bitmap ใช้กับ rowstore index
- D. Batch mode ประมวลผลทีละ 100 แถว เฉพาะตอน SELECT TOP

### Q16. แล็บจริง (SQL Server 2025): สร้าง CCI จากข้อมูล 2,183,706 แถวที่ `Seq` (identity วิ่งตามลำดับการ insert) ได้ segment map ของคอลัมน์ Seq: rowgroup 0 = min 1 / max 1,048,576 · rowgroup 1 = 1,048,577–2,097,152 · rowgroup 2 = 2,097,153–2,183,706 — คิวรี `SELECT COUNT(*) FROM dbo.CsOrders WHERE Seq > 2100000` จะรายงาน Segment reads / Segment skipped อย่างไร และถ้าเปลี่ยน predicate เป็น `Seq > 1` ล่ะ?
- A. (ก) reads 1 / skipped 2 เพราะเฉพาะ rowgroup 2 ที่ max = 2,183,706 ครอบค่า 2,100,000; (ข) reads 3 / skipped 0 เพราะทุก segment ครอบค่า > 1 — อ่านหมด ไม่มี elimination
- B. (ก) reads 3 / skipped 0 — columnstore อ่านทุก segment เสมอเพราะ metadata ไม่ถูกใช้ตอนรัน
- C. (ก) reads 0 / skipped 3 — engine ตอบจาก metadata โดยไม่อ่านข้อมูลเลย
- D. (ก) reads 2 / skipped 1 — เพราะค่า 2,100,000 อยู่ระหว่าง rowgroup 1 กับ 2 ต้องอ่านทั้งสองก้อน

### Q17. ระบบ DW นำเข้าข้อมูลรายวันแบบ "insert ทีละ 5,000–20,000 แถวหลายรอบต่อวัน" บน CCI แล้วรายงานช้าลงเรื่อย ๆ — จาก `sys.column_store_row_groups` พบ rowgroup สถานะ OPEN จำนวนมากสะสมและ TOMBSTONE หลายก้อน ข้อใดอธิบาย + แก้ถูกต้อง?
- A. ข้อมูลเสียหาย — ต้อง REBUILD ตารางทั้งหมดทุกคืนเพื่อความสะอาด
- B. insert ชุดเล็ก (< ~102,400 แถว/batch) ไปพักที่ deltastore (OPEN) ซึ่งอ่านชาวกว่า compressed และไม่ได้ประโยชน์จาก batch mode เต็มรูปแบบ — แก้ด้วย: จัด batch load ใหญ่ขึ้น / เรียกบีบทันทีหลัง load ด้วย `ALTER INDEX ... REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON)` (2022+) และกวาดแถวที่ลบเมื่อเกิน ~10% ของ rowgroup
- C. OPEN rowgroup ปกติของ columnstore ไม่มีผลต่อประสิทธิภาพ — ปล่อยได้ ไม่ต้องแก้
- D. Tuple Mover ต้องเปิดผ่าน config `TUPLE_MOVER = ON` ระดับ database

### Q18. จากผลรันจริงของ histogram `IX_SalesOrderDetail_ProductID`: `WHERE ProductID = 711` (เป็น RANGE_HI_KEY, EQ_ROWS = 3,090) ได้ **estimated 3,090 = actual 3,090** แต่ `WHERE ProductID = 897` (ไม่เป็น boundary — หล่นใน step ที่ RANGE_ROWS 227 / DISTINCT 3 / AVG 75.6667) ได้ **estimated 75.6667 แต่ actual 2** — สรุปกลไกถูกต้องคือข้อใด?
- A. Histogram แม่นเฉพาะค่าที่เป็น step boundary (อ่าน EQ_ROWS ตรง) — ค่าอื่นถูกประมาณด้วย average_range_rows ของช่วงที่ครอบมัน ซึ่งพังเมื่อข้อมูล skew หนักในช่วง
- B. ตัวเลขเพี้ยนเพราะ statistics ถูกสร้างด้วย SAMPLE ไม่ใช่ FULLSCAN — รัน UPDATE STATISTICS WITH FULLSCAN แล้วทั้งสองกรณีจะแม่นเป๊ะ
- C. 897 เพี้ยนเพราะเป็น ascending key — ปัญหาเดียวกับแถวนอก histogram ที่ New CE แก้ให้แล้ว
- D. Optimizer อ่านค่า actual ตอน runtime แล้วแก้ plan เอง จึงไม่มีผลกระทบจริง

---

## ส่วนที่ 2: ตอบสั้น

### Q11. จากผล `DBCC SHOW_STATISTICS`: อธิบายความหมาย `RANGE_HI_KEY`, `EQ_ROWS`, `RANGE_ROWS` และ optimizer ใช้ค่าไหนอย่างไรเมื่อ (ก) predicate เป็น equality `Status = 1` ที่ 1 เป็น step boundary (ข) predicate เป็น range `Date > '2025-01-01'`

### Q12. เทียบผลกระทบของ CE ผิดพลาดสองกรณี — **Overestimation** กับ **Underestimation** — ว่าแต่ละกรณี optimizer ทำอะไรผิดทิศ (memory grant / join algorithm) และในแล็บจริงกรณีไหนคือกรณีที่เกิด (estimated 223.83 vs actual 50,000)?

### Q13. จากแล็บจริงพบ index ซ้ำบางส่วน: `IX_Employee_OrganizationNode (OrganizationNode)` กับ `IX_Employee_OrganizationLevel_OrganizationNode (OrganizationLevel, OrganizationNode)` — อธิบายว่า "ซ้ำบางส่วน (overlapping)" ต่างจาก "ซ้ำเป๊ะ (duplicate)" อย่างไร และทำไมกรณีนี้จึง "ต้องวิเคราะห์ก่อนตัดสินใจ" มากกว่า DROP ทันที

### Q14. ออกแบบ index สำหรับคิวรี `SELECT BusinessEntityID, FirstName, LastName FROM Person.Person WHERE MiddleName = N'J.'` — เพราะอะไรจึงเลือก key = `(MiddleName)` และ INCLUDE = `(FirstName, LastName)` (ไม่ใช่ใส่ทุกคอลัมน์เป็น key) และอ้างตัวเลขก่อน-หลังจากแล็บจริงประกอบ

### Q15. ฟีเจอร์ใหม่ที่เกี่ยวกับ Statistics บน SQL Server 2025: **CE Feedback for Expressions** และ **Persisted statistics for readable secondaries** — แต่ละตัวแก้ปัญหาใด (ระบุอาการเดิม) และต้องมีเงื่อนไขอะไรจึงทำงาน?

---

## เฉลยพร้อมคำอธิบาย

<details>
<summary><b>เฉลย Q1</b> — B</summary>

**Header** = metadata (last_updated, rows, rows_sampled, modification_counter) ใช้ตรวจว่า stats เก่าแค่ไหน; **Density Vector** = 1/จำนวนค่าไม่ซ้ำ ใช้กับ GROUP BY/join หลายคอลัมน์; **Histogram** = กราฟกระจายสูงสุด **200 steps** ใช้ตอบ predicate ของ WHERE/range — อ่านต่อ: [Section 6.1 — Statistics & CE หัวข้อ 2.1](Sections/01_Statistics_Cardinality_Estimation/README.md)
</details>

<details>
<summary><b>เฉลย Q2</b> — B</summary>

Histogram เก่าบอกว่า "Status = 1 ไม่มีแถวเลย" → CE ประเมินเกือบศูนย์ (223.83) ขณะจริง 50,000 = **Underestimation** — ผลตามมาแบบคลาสสิก: grant จัดน้อยจน **spill to tempdb** และเลือก **Nested Loops** บนตารางใหญ่ (ตรงข้ามกับ overestimation ที่จ่าย grant เยอะและฟุ่มเฟือย) — อ่านต่อ: [Section 6.1 ตารางผลกระทบของ CE](Sections/01_Statistics_Cardinality_Estimation/README.md) + [Labs Ex3](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q3</b> — A</summary>

เกณฑ์เก่าคงที่ (20%+500) ทำให้ตาราง 100 ล้านแถวต้องเปลี่ยน ~20 ล้านแถวก่อนอัปเดต — SQL 2016+ (compat 130+) เปลี่ยนเป็น **dynamic threshold** ขนาดเล็กลงตามขนาดตาราง อัปเดตถี่ขึ้น โดยเฉพาะตารางใหญ่ แต่บาง workload (เช่น monotonically increasing key) ยังต้องจัดการเอง — อ่านต่อ: [Section 6.1 หัวข้อ 2.4 Stale Stats](Sections/01_Statistics_Cardinality_Estimation/README.md) + [Labs Ex3 Step 1 ✅](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q4</b> — A</summary>

หลักบ้านแล็บ: query แรก compile แล้วยิง **auto-update ทันที** (estimated = actual = 50,000 ตั้งแต่ครั้งแรก — กลบทลาย skew) จึงปิด auto-update "เฉพาะตาราง" ด้วย `sp_autostats` — แต่เมื่อ autostats ปิด การ `UPDATE STATISTICS` **จะไม่ invalid แผนเก่า** (วัดจริง: estimated ยังค้าง 223.83) — ต้อง `OPTION (RECOMPILE)` บังคับ compile ใหม่จึงเห็น 50,000 และใช้ `WITH FULLSCAN` ให้ histogram แม่นเต็มร้อย — อ่านต่อ: [Labs Ex3 Step 3 ⚠️ + Expected](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q5</b> — B</summary>

GUID สุ่มทำลายข้อ **Ever-increasing**: แถวใหม่ต้องแทรกกลาง B-Tree ตามลำดับเรียงค่า → page split ต่อเนื่อง → frag 98.5% + page_count บวม (132 vs 86) + log บวมตาม (แต่ละ split ต้อง log ทั้งหน้า) ส่วน uniqueifier เป็นค่าปรับที่ engine เติมเมื่อ key ซ้ำ — อ่านต่อ: [Section 6.2 — Index Internals หัวข้อ 3.1–3.2](Sections/02_Index_Internals/README.md) + [Labs ของ Module 3 Ex2](../Module_03_Database_Structures/Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q6</b> — B</summary>

Key ทำหน้าที่ "เรียง + กรอง" (Seek ได้เพราะ predicate อยู่ที่ MiddleName) — ส่วน FirstName/LastName ถูก SELECT แต่ไม่ใช้กรอง จึงพองเก็บที่ leaf ด้วย **INCLUDE** (แคบกว่า, ไม่กระทบ b-tree ระดับบน) ผลลัพธ์ = **covering index**: จบใน seek เดียว (แล็บจริง 106 → 4 reads ~26 เท่า, Key Lookup หาย, Missing Index hint หายไปจากแผน) — SELECT * ต้องอ่านคอลัมน์ที่ index ไม่มี จึงยัง Key Lookup ทุกแถว บทเรียน: ออกแบบ index ตาม "คอลัมน์ที่ query ใช้จริง" — อ่านต่อ: [Labs Ex1 Step 3–5 + หมายเหตุ](Labs/README.md) + [Section 6.2 หัวข้อ Covering Index](Sections/02_Index_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q7</b> — B</summary>

Missing Index DMV/hint เป็น **จุดเริ่ม ไม่ใช่คำตอบสำเร็จรูป**: ไม่คิดลำดับคอลัมน์, ไม่รวมคำแนะนำทับซ้อน (แต่ Plan Explorer รวมให้ได้), ไม่สนใจ index ที่มีอยู่ — เคสแล็บสอนแรงที่สุด: filter ที่คิดว่าขาด index จริง ๆ ถูก cover อยู่แล้วจึงต้องเปลี่ยนเป็น `MiddleName = 'J.'` (คอลัมน์ที่ไม่มี index จริง) ถึงจะเดโม missing index ได้ — อ่านต่อ: [Module README 7.3](README.md) + [Labs Ex1 ⚠️ แก้จากต้นฉบับ](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q8</b> — B</summary>

"จ่ายแรมรับความว่างเปล่า" = ทุก INSERT/UPDATE/DELETE ต้อง maintain index นี้ (writes) แต่ไม่มีใครอ่าน (reads = 0) — เป็นผู้สมัคร DROP ตัวจริง แต่ก่อนกดปุ่ม: ต้องไม่ใช่ PK/Unique constraint (แล็บเจอ PK ที่ยัง reads 0 เพราะ DB ใหม่!) และต้องมี baseline **ยาว ≥ 1 business cycle** กันพลาดงานรายเดือน/รายปี — อ่านต่อ: [Labs Ex2 Step 1 + ✅ Expected](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q9</b> — B</summary>

เกณฑ์มาตรฐาน: **REBUILD** เมื่อ > 30% (ทั้งหน้าใหม่หมด, แออัดกลับ 100%), **REORGANIZE** เมื่อ 5–30% (กวาดเฉพาะใน page, online เสมอ), **< 5% ปล่อย** — พร้อมเงื่อนไข `page_count > 1000` กันตัดสินจากตารางเล็กที่ "frag สูงแต่ไร้ผล" และใช้ mode `'LIMITED'` สำรวจเบา (แล็บจริงเหลือ 3 แถวเช่น XMLPROPERTY 94.4% บน 2,677 pages) — อ่านต่อ: [Labs Ex2 Step 3](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q10</b> — A</summary>

Columnstore = จัดเก็บแยกคอลัมน์: insert/update เล็ก ๆ วิ่งเข้า **Deltastore** (rowstore ชั่วคราว) → **Tuple Mover** ย้ายเป็น compressed rowgroup (~1 ล้านแถว/กลุ่ม, แต่ละคอลัมน์เป็น segment ที่อ่านจาก disk เป็นหน่วย) — segment **แก้ตรงไม่ได้** ลบจึง mark ด้วย Deleted Bitmap (logical delete) และ **Batch mode (~900 แถว/ชุด)** คือโหมดประมวลผลที่ CPU คุ้มค่า — อ่านต่อ: [Section 6.3 — Columnstore Indexes](Sections/03_Columnstore_Indexes/README.md)
</details>

<details>
<summary><b>เฉลย Q16</b> — A</summary>

Segment elimination ตัดสินจาก min/max ต่อ segment: predicate `Seq > 2100000` ครอบเฉพาะ rowgroup 2 (max 2,183,706) → **Segment reads 1, skipped 2** (รันจริง: lob logical reads 30 เทียบกับคิวรี `Seq > 1` ที่ reads 3 / skipped 0 และ lob 716 — I/O ต่าง ~24 เท่า) — ตัวเลขดูได้จากช่อง `Segment reads / Segment skipped` ของ `SET STATISTICS IO` และ metadata จริงจาก `sys.column_store_segments` (join `sys.columns` ผ่าน column_id — บน SQL Server 2025 ไม่มีคอลัมน์ชื่อ column_name ใน DMF นี้) — อ่านต่อ: [Section 6.3 หัวข้อ 2.1–3](Sections/03_Columnstore_Indexes/README.md)
</details>

<details>
<summary><b>เฉลย Q17</b> — B</summary>

insert ชุดเล็กไม่ถึงเกณฑ์บีบทันที (~102,400 แถว/batch) จึงสะสมเป็น rowgroup **OPEN** (deltastore โครง B-Tree) ที่อ่านแพงกว่า + กวาด TOMBSTONE ไม่ทัน — ทางแก้ตามหลัก: ปรับ ETL เป็น batch ใหญ่, ปิดท้ายด้วย `REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON)` เพื่อเรียกบีบทันที (เก่ากลายเป็น TOMBSTONE แล้ว background เก็บ) และกวาด deleted rows เมื่อถูกลบ ≥ ~10% ของ rowgroup — Tuple Mover ไม่ต้องเปิด config ใด มันทำงานเบื้องหลังเอง — อ่านต่อ: [Section 6.3 หัวข้อ 4–5](Sections/03_Columnstore_Indexes/README.md)
</details>

<details>
<summary><b>เฉลย Q18</b> — A</summary>

Histogram จำค่าได้ "ตรง ๆ" เฉพาะ RANGE_HI_KEY (อ่าน EQ_ROWS) — ค่าที่หล่นกลางช่วงถูกประมาณด้วย average_range_rows (227 / 3 = 75.6667) ซึ่งพังเมื่อการกระจายในช่วง skew หนัก (จริงมีแค่ 2) — FULLSCAN ช่วยเรื่องความครบของ sample แต่**แก้ข้อจำกัดโครงสร้าง 200 steps ไม่ได้**; กรณี 897 ไม่ใช่ ascending key (897 อยู่ใน histogram อยู่แล้ว) และ optimizer ไม่อ่านค่า actual ตอน runtime — อ่านต่อ: [Section 6.1 หัวข้อ 3](Sections/01_Statistics_Cardinality_Estimation/README.md)
</details>

<details>
<summary><b>เฉลย Q11</b></summary>

- `RANGE_HI_KEY` = ค่าสูงสุดของช่วง (step boundary) — ค่าที่ histogram จำได้ตรง ๆ
- `EQ_ROWS` = จำนวนแถวที่ "เท่ากับ" ค่า RANGE_HI_KEY นั้น
- `RANGE_ROWS` = จำนวนแถวที่อยู่ "ระหว่าง" step ก่อนหน้ากับ step นี้ (ไม่รวม boundary)

(ก) equality ที่ค่าเป็น step boundary → optimizer อ่าน **EQ_ROWS ของ step นั้นตรง ๆ** (ถ้าไม่อยู่ใน histogram ใช้ density/เฉลี่ยช่วง) — เคสแล็บที่ 0 ไม่เคยถูกบันทึกใน histogram = EQ_ROWS ไล่มาเป็น 223.83
(ข) range → รวม **RANGE_ROWS + EQ_ROWS ของ steps ที่ overlap** กับช่วงค้นหา (ประมาณเฉลี่ยช่วงเป็นเศษส่วน)

อ่านต่อ: [Section 6.1 หัวข้อ Histogram Columns](Sections/01_Statistics_Cardinality_Estimation/README.md)
</details>

<details>
<summary><b>เฉลย Q12</b></summary>

- **Overestimation** (คิดมากไป): grant ยักษ์แต่ใช้ไม่หมด (แย่ง workspace คนอื่น) และชอบเลือก **Hash Join** ฟุ่มเฟือยกับ input เล็ก
- **Underestimation** (คิดน้อยไป): grant ไม่พอ → **Spill to tempdb**; เลือก **Nested Loops** กับตารางใหญ่ (จิ้มทีละแถวหลายพันครั้ง)

แล็บจริง (estimated 223.83 vs actual 50,000) = **Underestimation** — histogram เก่าจาก 100 แถว seed ทั้งหมด Status = 0 ทำให้ CE คิดว่า Status = 1 แทบไม่มีแถว — อ่านต่อ: [Section 6.1 ตารางผลกระทบของ CE ที่ผิดพลาด](Sections/01_Statistics_Cardinality_Estimation/README.md) + [Labs Ex3](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q13</b></summary>

- **Duplicate** = key column เหมือนกันเป๊ะ (ซ้ำ 100%) — ตัดตัวใดตัวหนึ่งได้เกือบเสมอ
- **Overlapping** = key ของตัวหนึ่งเป็น **prefix** ของอีกตัว (OrganizationNode ⊂ OrganizationLevel, OrganizationNode) — ตัวสั้นอาจยังมีประโยชน์: แคบกว่า (maintenance ถูกกว่า), อาจถูก seek ด้วยคิวรีที่กรองแค่ OrganizationNode เพียงเดี่ยว, หรือมี INCLUDE ต่างกัน

จึงต้องวิเคราะห์ "ใครถูกใช้จริง" จาก `sys.dm_db_index_usage_stats` + workload จริงก่อนรวม/ลบ ไม่ใช่ตัดทันทีแบบ duplicate — อ่านต่อ: [Section 6.2 หัวข้อ 3.4 Bad Non-Clustered Indexes](Sections/02_Index_Internals/README.md) + [Labs Ex2 Step 2 ✅](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q14</b></summary>

- **Key = `(MiddleName)`**: คอลัมน์เดียวที่ predicate ใช้ — b-tree เรียงตาม MiddleName ทำให้ `Index Seek` เจาะตรงช่วงค่า และ key แคบ = b-tree ระดับบนเล็ก
- **INCLUDE = `(FirstName, LastName)`**: คอลัมน์ที่ SELECT ต้องใช้แต่ไม่ใช้กรอง — พอเก็บที่ leaf ทำให้เป็น covering โดยไม่บวม key (BusinessEntityID เป็น clustered key ติดมาใน leaf เอง จึงไม่ต้องใส่เพิ่ม)
- ตัวเลขจริง (SQL Server 2025, AdventureWorks): ก่อน = **106 logical reads** (Index Scan + residual, 132 แถว, Missing Index Impact 92.52) → หลัง = **Index Seek 4 reads, ไม่มี Key Lookup** (~26 เท่า) — และ hint `CREATE INDEX ... (MiddleName) INCLUDE (FirstName, LastName)` ที่ SSMS แนะนำก็ตรงกับแนวคิดนี้พอดี (เคสนี้โชคดี — ปกติต้อง review เอง ดู Q7)

อ่านต่อ: [Labs Ex1](Labs/README.md) + [Section 6.2 หัวข้อ Covering Index](Sections/02_Index_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q15</b></summary>

- **CE Feedback for Expressions (2025)**: เดิม query ที่ predicate มี expression (เช่น `DATEDIFF`, `CONVERT` บน column) ให้ CE ผิดเพี้ยนซ้ำ ๆ เพราะ optimizer เดา selectivity ของ expression ไม่ได้ — ฟีเจอร์นี้ให้ engine **เรียนรู้ค่า CE ที่เหมาะกับ expression จากการรันจริงข้าม query** (ละเอียดระดับ sub-expression ใช้ CE model คนละแบบใน query เดียวกันได้) — เงื่อนไข: **compat level 170**
- **Persisted statistics for readable secondaries (2025)**: เดิม readable secondary ของ Availability Group ใช้ stats ที่ถูก sync จาก primary — workload ฝั่ง read ที่พรีดิเคตคนละแบบจึงได้ plan แย่เพราะ stats "ไม่รู้จัก" predicate ของตัวเอง — 2025 ให้ secondary **สร้าง/เก็บ stats ของ workload ฝั่ง read ได้เอง** — เงื่อนไข: AG readable secondary บน SQL Server 2025

อ่านต่อ: [Module README 7.1](README.md) + [Section 6.1 หัวข้อ 2.3](Sections/01_Statistics_Cardinality_Estimation/README.md) + [Labs Ex4](Labs/README.md)
</details>

---

**ท้ายชุดข้อสอบ:** ทำคะแนนได้ ≥ 14/18 ถือว่าผ่านมาตรฐานบทที่ 6 — ถ้ายังไม่ถึง ให้ย้อนอ่าน [6.1 Statistics & Cardinality Estimation](Sections/01_Statistics_Cardinality_Estimation/README.md) → [6.2 Index Internals](Sections/02_Index_Internals/README.md) → [6.3 Columnstore Indexes](Sections/03_Columnstore_Indexes/README.md) และทำ [Labs](Labs/README.md) ซ้ำอีกรอบ
