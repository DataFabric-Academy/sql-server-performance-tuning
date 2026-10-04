# Quiz Bank — บทที่ 7: Query Execution & Optimization (Pipeline, Plans, Operators, SARGable & IQP 2025)

> ครอบคลุมวัตถุประสงค์การเรียนรู้ของบทที่ 7 ตาม [Course_Guide_4Days.md](../Trainer_Docs/Course_Guide_4Days.md): Query Processing Pipeline, Estimated vs Actual Plan, Operators/Costs/Cardinality, AQP (2017): Adaptive Joins/Memory Grant Feedback/Interleaved, IQP (2019+): PSPO/DOP Feedback/MGF v2, ของใหม่ 2025: OPPO + CE Feedback for Expressions และ Query Tuning Techniques (Rewriting, Hints, Temp Table vs Table Variable/CTE, SARGable) — ใช้คู่กับ [Sections](README.md) และ [Labs](Labs/README.md)
> **รูปแบบ:** ข้อ 1–10 multiple choice · ข้อ 11–15 ตอบสั้น · เฉลยพร้อมคำอธิบายอยู่ท้ายไฟล์ (อย่าเลื่อนดูก่อนตอบ!)

---

## ส่วนที่ 1: Multiple Choice

### Q1. ลำดับ Query Processing Pipeline ที่ถูกต้องคือข้อใด?
- A. Optimization → Parsing → Binding → Execution
- B. Parsing (ตรวจ syntax) → Binding/Algebrizer (resolve ชื่อ object) → Optimization (เลือก plan cost ต่ำสุด) → Execution
- C. Binding → Optimization → Parsing → Execution
- D. Parsing → Optimization → Binding → Execution

### Q2. ข้อใดต่างกัน "อย่างถูกต้อง" ระหว่าง Estimated Plan กับ Actual Plan และวิธีดึง actual plan ที่ถูกต้องบน SQL Server 2019+/2025 คือข้อใด?
- A. Estimated ไม่มี cost เลย ส่วน Actual มี cost คำนวณจริง
- B. Actual Plan = plan เดียวกับ Estimated **+ runtime info** (Actual Rows, Actual Number of Rows read) — ทั้งคู่มาจาก optimizer ตัวเดียวกัน ไม่ใช่แผนคนละใบ; ดึง actual ของรอบล่าสุดได้จาก `sys.dm_exec_query_plan_stats` (ต้องเปิด `LAST_QUERY_PLAN_STATS`) หรือจาก **Query Store** ซึ่งเป็นทางที่ไม่ต้องแก้ config
- C. Estimated ใช้ได้เฉพาะหลังรัน query เสร็จ
- D. Actual Plan สร้างใหม่ตอนรัน อาจต่างจาก Estimated ทุก operator โดยไม่มีสาเหตุ

### Q3. แล็บจริง: `NationalIDNumber` เป็น `NVARCHAR` แต่คิวรีส่ง `WHERE NationalIDNumber = 112457891` (INT) ได้ **Clustered Index Scan + warning CONVERT_IMPLICIT** พอส่งเป็น `N'112457891'` กลายเป็น **Index Seek** — อธิบายกลไกที่ถูกต้องคือข้อใด?
- A. SQL Server หา index ไม่เจอเพราะชนิดข้อมูลต่างกันจึงสแกนทั้งตารางเสมอ
- B. เมื่อ type ต่างกัน **data type precedence** ตัดสิน — NVARCHAR สูงกว่า INT จึงแปลงที่ค่า parameter แต่ INT literal กรณีนี้ทำให้ต้องแปลงค่าใน *column* ทุกแถวเทียบกับ INT (CONVERT_IMPLICIT อยู่บนคอลัมน์) → predicate ไม่ SARGable → seek ไม่ได้; พอส่งตรง type ก็ seek ทันที
- C. INT ใช้ 4 bytes ส่วน NVARCHAR ใช้ 2 bytes ต่อตัวอักษร จึงเร็วกว่า
- D. เพราะ `NationalIDNumber` ไม่มี index ตั้งแต่แรก

### Q4. คิวรี JOIN สองตาราง: ฝั่งหนึ่ง 10 แถว อีกฝั่ง 10 ล้านแถวไม่เรียง — Optimizer มักเลือก join ใดและเพราะอะไร?
- A. Merge Join — เร็วสุดเสมอ
- B. Nested Loops — เหมาะกับ outer ใหญ่
- C. Nested Loops (หรือ Adaptive) เมื่อ input ด้านนอกเล็ก — จิ้ม inner ด้วย seek ทีละแถวจึงถูก; ถ้าสองฝั่งใหญ่ทั้งคู่และไม่เรียง → Hash Join (ใช้ memory สร้าง hash table); Merge เหมาะเมื่อสองฝั่งเรียงอยู่แล้ว
- D. SQL Server สุ่มเลือกตาม seed ของ session

### Q5. แล็บจริงเทียบ 3 รูปแบบเขียนคิวรีเดียวกัน (~2,130 แถว): ผล logical reads ฝั่ง `EmailAddress` ต่างกันมาก — จับคู่ให้ถูก
- A. Temp Table → 4,591 reads / Table Variable → 197 reads / CTE → 200 reads
- B. Temp Table → Hash Match + สแกนรอบเดียว (186+11 reads) / Table Variable → Nested Loops + Seek 2,130 ครั้ง (4,591 reads) / CTE → inline ไม่เขียน tempdb (14+186 reads)
- C. ทั้งสามแบบ reads เท่ากันเสมอเพราะผลลัพธ์เท่ากัน
- D. CTE ทำให้เกิด page split เพราะ materialize ลง tempdb

### Q6. Table Variable Deferred Compilation (2019+) ข้อใดถูกต้อง?
- A. ยกเลิกปัญหา table variable เสมอ — est = actual ทุกกรณี
- B. หน่วงการ compile จนเริ่มรัน จึงรู้จำนวนแถวจริงมาใช้เป็น CE ครั้งแรก (แล็บจริง est 1,917 จากเดิมที่ตายตัว 1) — แต่ **ยังไม่สร้าง statistics** จึงยังเลือก plan ไม่ดีในกรณีแถวเยอะ (4,591 reads)
- C. ทำให้ table variable เขียนลง tempdb เร็วขึ้น
- D. ใช้ได้เฉพาะเมื่อมี Query Store

### Q7. คิวรี `WHERE YEAR(OrderDate) = 2024` กับ `WHERE OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01'` — ข้อใดถูกต้องตามผลแล็บจริง?
- A. แบบ YEAR() เร็วกว่าเพราะ SQL ปรับให้เอง
- B. ทั้งคู่บน AdventureWorks เป็น Clustered Index Scan เพราะไม่มี index บน OrderDate — แต่จุดสำคัญคือแบบ YEAR() เป็น **expression ครอบ column ที่ไม่ SARGable** (จะไม่ seek แม้สร้าง index ให้) ส่วนแบบช่วงเป็น range predicate ที่ SARGable — seek ได้ทันทีเมื่อมี index
- C. แบบช่วงไม่ใช้ index ได้เพราะมีสองเงื่อนไข
- D. สองแบบให้ plan เหมือนกันทุกประการ

### Q8. แล็บจริงบน SQL Server 2025 (compat 170): proc แบบ optional parameters 2 ตัวได้ **Dispatcher Plan + Query Variant Plans** — variant ฝั่ง "มีค่า" (Index Seek + Nested Loops) avg ~212–237.8 µs vs variant ฝั่ง "ไม่กรอก" (Clustered Index Scan) avg ~86,000–303,169 µs — ฟีเจอร์และกลไกคือข้อใด?
- A. PSPO 2022 — แยก plan ตามช่วง cardinality ของค่า parameter และไม่ต้องมี Query Store
- B. **OPPO (Optional Parameter Plan Optimization, 2025)** — สำหรับ pattern `(@p IS NULL OR col = @p)`: Dispatcher ตัดสินตามรูปแบบ parameter แล้วส่งไป query variant ที่เหมาะ (PLAN PER VALUE) — ได้ plan ทั้ง "seek" และ "scan" แยกกันโดยไม่แก้โค้ด; ต้องยืนยันด้วย `plan_type_desc` ใน Query Store เสมอ เพราะ proc ที่มี optional predicate **ตัวเดียว** บน build ที่ทดสอบยังได้ plan เดียว (Compiled Plan)
- C. Query Store Force Plan — บังคับ plan เดิมกลับมา
- D. Adaptive Join 2017 — เลือก hash/loop กลางอากาศ

### Q9. ข้อใดเรียงตระกูล IQP "ต้องมี Query Store (READ_WRITE) เพื่อทำงาน/เก็บ feedback" ได้ถูกต้อง?
- A. Batch Mode on Rowstore, Table Variable Deferred Compilation, Scalar UDF Inlining
- B. Memory Grant Feedback (Persisted), Parameter Sensitive Plan, DOP Feedback, CE Feedback, Optimized Plan Forcing / OPPO
- C. Adaptive Joins และ Interleaved Execution
- D. ทุกฟีเจอร์ IQP ต้องมี Query Store โดยพารามิเตอร์

### Q10. ข้อสังเกตใด "ผิด" เกี่ยวกับแผน Dispatcher ของ PSPO/OPPO เมื่อ query Query Store รายงาน runtime stats?
- A. Dispatcher Plan ไม่มี runtime stats ของตัวเอง (avg_duration เป็น NULL) — ในแล็บจึงต้องใช้ `LEFT JOIN` ไป `sys.query_store_runtime_stats`
- B. Query Variants ถูกเก็บเป็น query_id แยกที่ข้อความมี `PLAN PER VALUE`
- C. `plan_type_desc` แยกค่า `Dispatcher Plan` / `Query Variant Plan`
- D. Dispatcher Plan มี avg_duration เฉลี่ยของทุก variant โดยอัตโนมัติ

---

## ส่วนที่ 2: ตอบสั้น

### Q11. อธิบายภารกิจของ Query Optimizer ในเชิง Cost-Based Optimization: เป้าหมายคือ "Good Enough Plan" ไม่ใช่ "plan ที่ดีที่สุดเท่าที่มีอยู่" — เชื่อมโยงกับ Optimization Phases (Trivial Plan, Search 0/1/2) ว่าเพราะอะไรจึงหยุดเร็วเมื่อ plan พอใช้

### Q12. คุณเปิด plan แล้วเห็น operator หนึ่ง **Estimated Rows = 50, Actual = 50,000** — บอกได้ว่าอะไร ควรตามหาสาเหตุที่ใด (นับ 3 แหล่ง) และเชื่อมโยงกับ Module 6 (statistics) ว่าตัวไหนแก้ที่ต้นเหตุ

### Q13. Parameter Sniffing แบบคลาสสิก: proc ที่มี parameter เดียว ครั้งแรกรันด้วยค่าที่ match 3 แถว แล้วคนอื่นเรียกด้วยค่าที่ match 300,000 แถว — (ก) อธิบายว่าทำไม plan เดียวจึงพังทั้งสองทาง (ข) วิธีจัดการก่อนปี 2025 มีอะไรบ้าง (ค) OPPO 2025 ช่วยได้อย่างไร พร้อมเงื่อนไข

### Q14. แล็บจริงหา implicit conversion ทั้ง plan cache ด้วย XQuery บน `sys.query_store_plan.query_plan` — ระบุข้อผิดพลาด 2 จุดที่ทำให้ query "เงียบผิด ๆ" คืน 0 แถวเสมอ (namespace และ XQuery path) และอธิบายว่าทำไม bug แบบนี้อันตรายต่อการวินิจฉัย เพิ่มเติม: ตอนหา query variants ของ OPPO ด้วย `LIKE '%PLAN PER VALUE%'` มีกับดักอะไรเพิ่ม?

### Q15. เมื่อไรควรเลือก Temp Table / Table Variable / CTE — ยกเกณฑ์ตัดสินจากแล็บ (แถวเยอะ/index/อ้างซ้ำ vs batch เล็ก vs อ่านครั้งเดียว) และอธิบายว่าทำไม CTE จึง "ไม่ได้เร็วกว่า"

---

## เฉลยพร้อมคำอธิบาย

<details>
<summary><b>เฉลย Q1</b> — B</summary>

Pipeline: **Parsing** (syntax → Parse Tree) → **Binding/Algebrizer** (resolve ชื่อ object, ตรวจสิทธิ์ → Query Tree) → **Optimization** (ประเมิน cost ของ plan ที่เป็นไปได้หลายพันแบบ) → **Execution** — อ่านต่อ: [Section 7.1 หัวข้อ 1 — Query Processing Pipeline](Sections/01_Query_Optimizer/README.md)
</details>

<details>
<summary><b>เฉลย Q2</b> — B</summary>

Actual plan คือ plan ใบเดียวกับที่ optimizer สร้าง แต่ถูก **ติด runtime statistics กลับมา** (Actual Rows vs Estimated Rows) — นี่คือเหตุผลที่ "คลาดเคลื่อนของ CE" วัดกันบน actual plan (Ctrl+M) — ทางดึง actual plan ล่าสุด: `sys.dm_exec_query_plan_stats` (ต้องเปิด `LAST_QUERY_PLAN_STATS` — บน VM ใช้ร่วมของหลักสูตรยัง OFF) หรือ Query Store (`sys.query_store_plan.query_plan` + `sys.query_store_runtime_stats`) ซึ่งเปิดอยู่แล้วและย้อนหลังได้; ถ้าอยากเห็น plan ระหว่างวิ่งใช้ Live Query Stats / `sys.dm_exec_query_profiles` (lightweight profiling default ตั้งแต่ 2019) — อ่านต่อ: [Section 7.2 หัวข้อ 1 และ 5](Sections/02_Execution_Plan_Formats/README.md)
</details>

<details>
<summary><b>เฉลย Q3</b> — B</summary>

หัวใจคือ **data type precedence**: เมื่อเทียบ INT กับ NVARCHAR ฝั่งที่ precedence ต่ำกว่าถูกแปลง — ในกรณีนี้เขียน predicate แบบแปลงที่ *คอลัมน์* (`CONVERT_IMPLICIT(int, [NationalIDNumber], 0)`) ทุกแถวต้องถูกแปลงก่อนเทียบ จึงใช้ B-Tree seek ไม่ได้ → Scan การแก้คือส่ง literal/parameter ให้ **ตรง type** (`N'...'`) — แล็บจริงพบ 249 plan ใน cache ที่มี CONVERT_IMPLICIT (ส่วนใหญ่เป็น metadata query ของ SSMS) — อ่านต่อ: [Labs Ex1](Labs/README.md) + [Section 7.3 หัวข้อ 1.1 ไม่ SARGable](Sections/03_Analyzing_Query_Plans/README.md)
</details>

<details>
<summary><b>เฉลย Q4</b> — C</summary>

**Nested Loops** คุ้มเมื่อ outer เล็ก (จิ้ม inner ด้วย seek ทีละแถว), **Hash Join** คุ้มเมื่อ input ใหญ่ไม่เรียง (เสีย memory สร้าง hash table หนึ่งครั้ง), **Merge Join** คุ้มเมื่อสองฝั่งเรียงอยู่แล้ว — และตั้งแต่ 2017 Adaptive Join เลือก loop/hash **กลาง runtime** ตามขนาดจริง — อ่านต่อ: [Section 7.3 หัวข้อ 2 Join Algorithms](Sections/03_Analyzing_Query_Plans/README.md) + [Section 7.4 หัวข้อ Adaptive Joins](Sections/04_Intelligent_Query_Processing/README.md)
</details>

<details>
<summary><b>เฉลย Q5</b> — B</summary>

- **Temp table**: มี statistics เต็ม → optimizer มั่นใจ เลือก **Hash Match** สแกน EmailAddress รอบเดียว (186+11 reads) — ถูกที่สุดเมื่อแถวเยอะ
- **Table variable**: deferred compilation ช่วย est 1,917 แต่ไม่มี stats → ยังเลือก **Nested Loops + Seek 2,130 ครั้ง** = 4,591 reads
- **CTE**: ไม่ materialize (inline) — 14+186 reads, ไม่เขียน tempdb

บทเรียน: ผลลัพธ์เท่ากันแต่ plan/IO ต่างกันมหาศาลตาม "ข้อมูลที่ optimizer เห็น" — อ่านต่อ: [Labs Ex3 Expected](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q6</b> — B</summary>

เดิม table variable ถูกประเมินตายตัว **1 row** → plan พังเมื่อแถวเยอะ — Deferred compilation (2019+) หน่วง compile จนเริ่มรัน ใช้ **จำนวนแถวจริงครั้งแรก** เป็น CE (แล็บจริง est 1,917) แต่ยังไม่มี statistics และไม่รู้ skew ในเชิงลึก จึงยังเลือก Nested Loops จิ้ม 2,130 ครั้ง (4,591 reads) ต่างจาก temp table — อ่านต่อ: [Section 7.4 หัวข้อ 2.3 Table Variable Deferred Compilation](Sections/04_Intelligent_Query_Processing/README.md) + [Labs Ex3](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q7</b> — B</summary>

**SARGable = Search ARGument-able**: predicate ต้องอยู่ในรูปที่ engine ใช้ b-tree เจาะได้ — การครอบ column ด้วย function (`YEAR(OrderDate)`) ทำให้ต้องประมวลผลทุกแถวจึง seek ไม่ได้ **แม้มี index บน OrderDate**; แปลงเป็นช่วงเปิด-ปิด (`>= ... AND < ...`) คือรูปแบบ SARGable มาตรฐาน (แล็บจริงทั้งคู่ scan เพราะไม่มี index บน OrderDate — จุดต่างอยู่ที่ "รูปแบบ predicate" ไม่ใช่ผลวันนี้) — อ่านต่อ: [Labs Ex2 Step 2](Labs/README.md) + [Module README คำถามท้ายบทข้อ 3](README.md)
</details>

<details>
<summary><b>เฉลย Q8</b> — B</summary>

Pattern `(@p IS NULL OR col = @p)` เดิมได้ **plan เดียวแบบ scan-safe** ที่แย่เมื่อส่งค่าจริง — **OPPO (2025, compat 170)** ใช้กลไก multiplan: **Dispatcher Plan** ตรวจรูปแบบ parameter แล้ว route ไป **Query Variant** ที่ optimize เฉพาะเคส (`PLAN PER VALUE` ใน variant XML, ตรวจใน Query Store ด้วย `plan_type_desc`) — แล็บจริง variant seek เร็วกว่า scan ~1,270 เท่า (237.8 µs vs 303,169 µs) — อ่านต่อ: [Labs Ex4 Step 2](Labs/README.md) + [Module README ตาราง IQP](README.md)
</details>

<details>
<summary><b>เฉลย Q9</b> — B</summary>

ตระกูลที่พึ่ง Query Store: **MGF Persisted (2022)**, **PSPO**, **DOP Feedback**, **CE Feedback**, **Optimized Plan Forcing**, **OPPO** — ส่วน Adaptive Joins, Batch Mode on Rowstore, Table Variable Deferred Compilation, Scalar UDF Inlining ทำงานไม่ต้องมี QS (แต่ QS แนะนำให้เปิดไว้วัดผลเสมอ) — อ่านต่อ: [Section 7.4 ตาราง IQP Features](Sections/04_Intelligent_Query_Processing/README.md)
</details>

<details>
<summary><b>เฉลย Q10</b> — D</summary>

**Dispatcher Plan ถูกออกแบบให้เป็น "จุดสลับ" ไม่ใช่ตัวรัน** — จึงไม่มี runtime stats ของตัวเอง (เป็น NULL) สถิติจริงอยู่ที่ Query Variants แต่ละตัว — แล็บจึงเขียน `LEFT JOIN` กับ `sys.query_store_runtime_stats` กันแถว dispatcher หาย — อ่านต่อ: [Labs Ex4 Step 3 ⚠️ + Expected](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q11</b></summary>

Cost-Based Optimization = ประเมิน cost (I/O + CPU) ของ plan ผู้สมัครแล้วหยุดที่ plan **"ดีเพียงพอ"** ภายในเวลา optimize ที่สมเหตุผล — เพราะการหา plan ที่ดีที่สุดเด็ดขาดจากหลายพันแบบใช้เวลามากกว่าที่ query จะรันเอง

Phases สะท้อน "หยุดเร็วเมื่อพอ": **Trivial Plan** (query มีทางเลือกเดียว เช่น SELECT * — จบทันที) → **Search 0** (OLTP ง่าย, cost ต่ำ) → **Search 1** (Quick Plan) → **Search 2** (Full Optimization — พิจารณา parallelism, indexed views, แพงที่สุด) — ขั้นถัดไปจะไม่ถูกใช้ถ้าขั้นก่อนหน้าได้ plan ที่ cost ต่ำพอแล้ว — อ่านต่อ: [Section 7.1 หัวข้อ 2 — Trivial Plan vs Full Optimization](Sections/01_Query_Optimizer/README.md)
</details>

<details>
<summary><b>เฉลย Q12</b></summary>

Estimated 50 vs Actual 50,000 (คลาด 1,000 เท่า) = **Cardinality Estimation ผิดวิธี** — และ CE ผิดคือรากของ plan แย่ (เลือก join/lookup ผิด, grant ผิด)

ตามหาสาเหตุ 3 แหล่ง:
1. **Statistics เก่า** — ตรวจด้วย `sys.dm_db_stats_properties` (last_updated vs modification_counter) — แก้ที่ต้นเหตุด้วย `UPDATE STATISTICS ... WITH FULLSCAN` (Module 6)
2. **Expression ที่ CE เดาไม่ได้ / SARGability** — predicate บิดเบี้ยว เช่น function บน column, implicit conversion (Module 7)
3. **สมมติฐาน CE model** — เช่น correlation ของคอลัมน์ — ใช้ CE Feedback (2022+) หรือ legacy CE แบบเฉพาะจุด

อ่านต่อ: [Labs Ex2 Step 1 ✅](Labs/README.md) + [Section 6.1 — Statistics & CE](../Module_06_Statistics_Index_Internals/Sections/01_Statistics_Cardinality_Estimation/README.md)
</details>

<details>
<summary><b>เฉลย Q13</b></summary>

(ก) **Plan เดียวถูกสร้างจากค่าที่ sniff ครั้งแรก** (3 แถว) — plan แบบ Nested Loops + Seek จะจมเมื่อถูก reuse กับค่าที่ match 300,000 แถว (และทางกลับกัน plan แบบ scan ก็ทรมานค่าเล็ก) — เพราะ plan ถูก reuse โดยไม่ compile ใหม่ตามค่า

(ข) ก่อน 2025: `OPTION (RECOMPILE)` (compile ทุกครั้ง — สละ CPU แลก plan ตรง), `OPTIMIZE FOR` / `OPTIMIZE FOR UNKNOWN`, แยก proc IF/ELSE สองทาง, Query Store force plan

(ค) **OPPO (2025, compat 170)** แก้แบบไม่ต้องแก้โค้ดสำหรับ pattern optional parameters: dispatcher + query variants แยก plan "seek" กับ "scan" — ตรวจยืนยันผ่าน `plan_type_desc` ใน Query Store; บน build ที่ทดสอบ proc ที่มี optional predicate ตัวเดียวยังได้ plan เดียว ส่วนแบบ 2 ตัว (ตามแล็บ) ได้ Dispatcher + 2 variants — variant seek 237.8 µs vs scan 303,169 µs (ต้องมี Query Store READ_WRITE ด้วย) — อ่านต่อ: [Section 7.4 หัวข้อ 3.1 และ 4.1](Sections/04_Intelligent_Query_Processing/README.md) + [Labs Ex4](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q14</b></summary>

Bug จากแล็บ (ตรวจจริงบน 17.0.1135.8):
1. **ไม่ประกาศ namespace** — plan XML ใช้ namespace showplan (`http://schemas.microsoft.com/sqlserver/2004/07/showplan`) ถ้าไม่มี `WITH XMLNAMESPACES (DEFAULT ...)` XQuery มองไม่เห็น node ใดเลย
2. **XQuery path สั้นไป** — ใช้ `//RelOp/ScalarOperator` (ลูกโดยตรงเท่านั้น) จึงเจอ 0 เสมอ เพราะ `CONVERT_IMPLICIT` อยู่ใต้ `<Predicate>` ซึ่งเป็น **grandchild** ของ RelOp — ต้องใช้ `//RelOp//ScalarOperator` (สอง slash)

ความอันตราย: query ไม่ error แต่คืน **0 แถวอย่างสงบ** — ผู้วินิจฉัยจะสรุปผิดว่า "ไม่มี implicit conversion ใน cache เลย" (false negative ที่ดูน่าเชื่อ) — ตรวจเครื่องมือวินิจฉัยด้วยเคสที่รู้คำตอบเสมอ กับดักเพิ่ม: ตอนหา OPPO variants ด้วย `LIKE '%PLAN PER VALUE%'` คำถามวินิจฉัยตัวเองก็มีข้อความนี้ — ถูก capture ข้ามรอบแล้ว match ตัวเอง ให้แปะ marker ในคำถามแล้วกรองด้วย `NOT LIKE` (แบบใน Section 7.4) — อ่านต่อ: [Labs Ex1 Step 3 ⚠️](Labs/README.md) + [Section 7.4 หัวข้อ 4.1](Sections/04_Intelligent_Query_Processing/README.md)
</details>

<details>
<summary><b>เฉลย Q15</b></summary>

เกณฑ์จากแล็บ:
- **Temp Table** — แถวเยอะ / ต้องสร้าง index / อ้างซ้ำหลายรอบ / ต้องการ statistics เต็ม (แล็บ: Hash Match สแกนรอบเดียว 186+11 reads)
- **Table Variable** — แถวน้อย อยู่ใน scope ของ batch, ต้องการ isolation แคบ (น้อยกว่า transaction ปกติ), ไม่ต้องการ stats — ระวังแถวเยอะ (4,591 reads)
- **CTE** — อ่านครั้งเดียว อยากได้โค้ดอ่านง่าย/reusable ใน query เดียว

"CTE เร็วกว่า" เป็นความเข้าใจผิด: **CTE ไม่ materialize** — มันคือชื่อย่อของ query ย่อยที่ถูก inline ทุกครั้งที่อ้าง (อ้างหลายรอบ = คำนวณซ้ำหลายรอบ) จึงเร็ว/ช้าตาม query ที่มัน inline ไม่ใช่ตัวมันเอง — อ่านต่อ: [Labs Ex3 ✅ สรุปเกณฑ์เลือก](Labs/README.md)
</details>

---

**ท้ายชุดข้อสอบ:** ทำคะแนนได้ ≥ 12/15 ถือว่าผ่านมาตรฐานบทที่ 7 — ถ้ายังไม่ถึง ให้ย้อนอ่าน [7.1 Query Optimizer](Sections/01_Query_Optimizer/README.md) → [7.2 Execution Plan Formats](Sections/02_Execution_Plan_Formats/README.md) → [7.3 Analyzing Query Plans](Sections/03_Analyzing_Query_Plans/README.md) → [7.4 Intelligent Query Processing](Sections/04_Intelligent_Query_Processing/README.md) และทำ [Labs](Labs/README.md) ซ้ำอีกรอบ
