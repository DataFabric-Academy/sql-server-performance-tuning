# สไลด์ไบล์พรินต์ — Module 7: Query Execution (Execution Plan Analysis)

> เด็ค **20 สไลด์** ตามสูตรแผนแม่บท: โครง 4 สไลด์ (Cover / Module Divider / Lab / Closing) + 4 สไลด์ × 4 sections
> (`Trainer_Docs/Production_Plan_Course_and_Slides.md:79` — "M2, M3, M4, M7 = 20 ต่อเด็ค (4 + 4×4)")
> ที่มาเนื้อหา: `Module_07_Query_Execution/README.md` (78 บรรทัด) + 4 section READMEs (61/65/26/100 บรรทัด) + `Module_07_Query_Execution/Labs/README.md` (4 Exercise) + 7 ไฟล์ .sql ใน Sections/*/Scripts/

**สรุปครอบคลุมของเด็ค:** เด็คนี้สอนตั้งแต่สมองของ engine — Query Optimizer เลือก Plan อย่างไร (Logical vs Physical, Pipeline Parsing→Binding→Optimization→Execution, Optimization Phases) — ต่อด้วยการอ่าน Plan จริง (Estimated vs Actual, Plan Formats, Live Query Statistics, Parallelism/Batch Mode), การวิเคราะห์ Operator และ Warnings (Seek/Scan/Key Lookup, 3 Join types, Implicit Conversion/Spill), และปิดท้ายด้วย Intelligent Query Processing รุ่น 2017→2025 (PSP, OPPO, DOP Feedback) พร้อม Lab 7 จำนวน 4 Exercise บน AdventureWorks2025
- **การใช้ layout (potx 8 layouts):** 01 Cover ×1 · 02 Module Divider ×1 · 03 Content ×12 (incl. quiz) · 04 Two-Column ×2 · 06 Code Lab ×3 (สไลด์ 6, 14, 19 — ≤4 ตามมติ #5) · 08 Closing ×1 — ไม่มี DEFAULT
- **ไม่ใช้ 05 Table / 07 Stat Callout:** ยังไม่มีตัวเลข M7 ใดที่ผ่าน sign-off รันจริงบน 17.x (Slide Spec 4.3/4.6 — ตัวเลขทุกตัวบน Stat Callout ต้องผ่านการรันจริงก่อน)
- **ภาพที่ต้องวาดใหม่ 3 ชิ้น** (PNG กว้าง ≥2400px, เก็บที่ `Module_07_Query_Execution/Sections/*/images/`): ปัจจุบัน M7 ไม่มีไฟล์ภาพเลย (ตรวจด้วย `find Module_07_Query_Execution -name "*.png" -o -type d -name images` = 0 ผลลัพธ์; ภาพ tracked ทั้ง repo มีแค่ 2 ไฟล์ของ M1)
- **สคริปต์ทั้ง 7 ไฟล์ของ M7 ยังไม่มี header `MinVersion:`** (ตรวจด้วย `grep -L "MinVersion" Module_07_Query_Execution/Sections/*/Scripts/*.sql` — ไฟล์ทั้ง 7 ถูกแสดง = ไม่มีใครผ่าน) — ต้องเติมก่อนประกอบ Code Lab ทุกใบ (เฟส 0 Blocking, Slide Spec 4.6)
- **งบเวลาโมดูล (นาที) ยังไม่มีตัวเลขใน repo** — ค่า ~146 นาทีบนสไลด์ 2 เป็นค่าประมาณจากสูตร 7.3 นาที/สไลด์ × 20 สไลด์ (`Trainer_Docs/Production_Plan_Course_and_Slides.md:84`) ต้อง sign-off ก่อนประกอบเด็ค
- **Glossary กลาง (`Trainer_Docs/Glossary.md`) ยังไม่มีใน repo** — ทุกบรรทัด "ต้องรู้มาก่อน" อ้าง path นี้ไว้ก่อนตามมติ #3 (Blocking เฟส 0); เมื่อไฟล์จริงถูกสร้างแล้วให้แทนลิงก์ตรงตามหัวข้อ

---

## โครงเด็ค (4 สไลด์)

### สไลด์ 1: Cover — Module 7 Query Execution
- **Layout:** `title` → potx `01 Cover (dark)`
- **เนื้อหา:**
  - Module 7 — Query Execution: Execution Plan Analysis
  - Day 3 ของหลักสูตร — ต่อจาก Statistics & Index Internals (M6) ก่อน Plan Caching (M8)
  - แท็กไลน์: "อ่าน Execution Plan ให้เป็น = หาต้นตอ Performance ได้"
- **ภาพ/แผนภาพ:** ไม่มี — ใช้ branding ของ layout Cover
- **Speaker notes:** เปิดด้วยคำถามปัญหา "query ชุดเดิม ทำไมวันนี้ช้าขึ้นร้อยเท่า" แล้วบอกผู้เรียนว่าคำตอบทั้งหมดซ่อนอยู่ใน Execution Plan ที่จะเรียนถอดรหัสไปทั้งโมดูล Ref: `Module_07_Query_Execution/README.md:1-3`

### สไลด์ 2: Module Divider — งบเวลาและภาพรวมโมดูล
- **Layout:** `section-divider` → potx `02 Module Divider (dark)`
- **เนื้อหา:**
  - งบเวลาโมดูล: ~146 นาที (ประมาณจาก 7.3 นาที/สไลด์ × 20 สไลด์ — **ต้อง sign-off ตัวเลขจริงก่อนประกอบเด็ค**)
  - Lab 7: **4 Exercise** บน AdventureWorks2025 (ตรวจแล้วจาก `Module_07_Query_Execution/Labs/README.md` — Exercise 1–4)
  - เส้นทาง 4 sections: Query Optimizer → Execution Plan Formats → Analyzing Query Plans → Intelligent Query Processing
  - เงื่อนไข: SQL Server 2019+ (แนะนำ 2025/17.x สำหรับ IQP compat 170) + สิทธิ์ `VIEW DATABASE STATE`
- **ภาพ/แผนภาพ:** ไม่มี (dark divider)
- **Speaker notes:** แจ้งงบเวลาและจำนวน Exercise ให้ผู้เรียนรู้ก่อนเริ่มตาม Slide Spec 4.2 และย้ำว่าแล็บต้องใช้ database AdventureWorks2025 Ref: `Module_07_Query_Execution/README.md`, Ref: `Module_07_Query_Execution/Labs/README.md:6-9`

---

## Section 1: Query Optimizer (สไลด์ 3–6)

### สไลด์ 3: Query Optimizer — Logical vs Physical Processing
- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา:**
  - SQL เป็นภาษาแบบ Declarative — ผู้เขียนบอก "อะไร" ไม่ใช่ "อย่างไร"; Query Optimizer คือ component ที่เลือก Execution Plan ที่ Cost ต่ำสุดจากหลายพัน Plan ที่เป็นไปได้
  - Logical Processing = ความหมายตามที่เขียน (JOIN/WHERE) vs Physical Processing = ขั้นตอนจริงที่ engine เลือกทำ (Index Seek vs Scan, Nested Loops vs Hash Join)
  - Query เดียวกันมีได้หลาย Plan — Optimizer เลือกผิด → ช้า 100x–1000x
  - การ Tuning ที่ยั่งยืนเริ่มจากตอบ "ทำไม Optimizer ถึงเลือก Plan นี้" ก่อนพิจารณาบังคับด้วย Hint
  - Skill เป้าหมายระดับ 1 ของโมดูล: อ่าน Execution Plan ได้อย่างถูกต้อง (Logical/Physical Operators, Seek/Scan/Key Lookup, Estimated vs Actual Rows)
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ต้องรู้มาก่อน: execution plan, index, statistics, cardinality — ดูอภิธานศัพท์กลาง `Trainer_Docs/Glossary.md` (ยังไม่มีใน repo — งาน Blocking เฟส 0) และ Module 0 ฉบับขั้นต่ำ Ref: `Module_07_Query_Execution/README.md:1-3,6-7`, Ref: `Module_07_Query_Execution/Sections/01_Query_Optimizer/README.md:5-9`

### สไลด์ 4: Query Processing Pipeline — Parsing → Binding → Optimization → Execution
- **Layout:** `bullets+diagram` → potx `03 Content`
- **เนื้อหา:**
  - Parsing: ตรวจ Syntax ของ SQL → ได้ Parse Tree
  - Binding (Algebrizer): ผูกชื่อ Object กับ Metadata → ได้ Query Tree
  - Optimization: คำนวณ Cost และเลือก Plan ดีที่สุด → ได้ Execution Plan
  - Execution: ทำงานตาม Plan → Result Set; Plan ที่ compile แล้วถูกเก็บใน Plan Cache (ประเด็นของ Module 8)
- **ภาพ/แผนภาพ:** `query-processing-pipeline.png` — วาดใหม่ ≥2400px จาก mermaid diagram ที่ `Module_07_Query_Execution/Sections/01_Query_Optimizer/README.md:36-55` (บล็อก Parser/Algebrizer/Optimizer พร้อมกิ่ง Simplification → TrivialPlan/FullOptimization) เก็บที่ `Module_07_Query_Execution/Sections/01_Query_Optimizer/images/` (โฟลเดอร์ยังไม่มี — ต้องสร้าง)
- **Speaker notes:** เดินไดอะแกรมจากซ้ายไปขวาทีละกล่อง แล้วเน้นว่า optimization เองก็มีต้นทุน CPU เวลา compile — จึงมีทางลัด Trivial Plan ในสไลด์ถัดไป Ref: `Module_07_Query_Execution/Sections/01_Query_Optimizer/README.md:19-24`

### สไลด์ 5: Optimization Phases — Good Enough Plan อย่างรวดเร็ว
- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา:**
  - เป้าหมายของ Optimizer ไม่ใช่ "Perfect Plan" แต่คือ Good Enough Plan ที่หาเจอเร็วพอ
  - Simplification: ลดรูป Query — เปลี่ยน Subquery เป็น Join, ตัด Join ที่ไม่จำเป็น
  - Trivial Plan: Query ที่มีทางเลือกเดียว (เช่น SELECT ง่าย ๆ) ข้าม Cost-based Optimization ได้ทันที
  - Full Optimization: Search 0 (Transaction Processing) → Search 1 (Quick Plan) → Search 2 (เต็มรูปแบบ พิจารณา Parallelism และ Indexed Views) — ยิ่ง Search ลึกยิ่งกิน CPU ตอน compile
- **ภาพ/แผนภาพ:** ไม่มี (ใช้ภาพ pipeline จากสไลด์ 4 อ้างอิงซ้ำใน speaker notes)
- **Speaker notes:** ยกตัวอย่าง `SELECT * FROM Table` ที่ได้ Trivial Plan ทันที เทียบกับ query ที่ต้องขึ้นถึง Search 2 เพื่อให้เห็นช่วงต้นทุนของ optimizer Ref: `Module_07_Query_Execution/Sections/01_Query_Optimizer/README.md:26-33`

### สไลด์ 6: Demo — Statistics หลอก Optimizer (Scan vs Seek)
- **Layout:** `demo` → potx `06 Code Lab`
- **เนื้อหา:**
  - TASK 1: สร้างตาราง `dbo.SalesStatsDemo` แบบ data skew — 10,000 แถว 'US' vs 10 แถว 'TH' + Index บน CountryCode
  - TASK 2: หลอก Statistics ด้วย `UPDATE STATISTICS ... WITH ROWCOUNT = 1, PAGECOUNT = 1` + `DBCC FREEPROCCACHE` (ล้าง Plan Cache)
  - TASK 3: เปิด Ctrl+M + `SET STATISTICS IO/TIME ON` รัน query กรอง 'TH' และ 'US' — สังเกต Plan ที่เลือกผิดจากความจริงของข้อมูล
  - TASK 4: แก้ด้วย `UPDATE STATISTICS ... WITH FULLSCAN` แล้วยืนยันว่า Plan กลับมาถูกต้อง
  - ประเด็นสอน: Optimizer ตัดสินใจจาก Statistics เท่านั้น — คุณภาพของ Statistics = คุณภาพของ Plan (เชื่อมโยงกับ M6)
- **ภาพ/แผนภาพ:** ไม่มี (screenshot plan จากการรันจริงทำภายหลังและต้องเก็บเป็นไฟล์ใน repo ก่อนใช้)
- **Script:** `Module_07_Query_Execution/Sections/01_Query_Optimizer/Scripts/02_Statistics_Impact.sql`
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน (มติ #9): `DBCC FREEPROCCACHE` = ล้าง Plan Cache ทั้ง instance (ต้องสิทธิ์ ALTER SERVER STATE); `UPDATE STATISTICS WITH ROWCOUNT/PAGECOUNT` = สั่งแก้ metadata ให้ engine เชื่อว่าตารางมี 1 แถว; `SET STATISTICS IO/TIME` = วัด logical reads และ elapsed time ต่อ statement error ที่พบได้ + รุ่นขั้นต่ำ: ใช้ได้ SQL Server 2019+ และต้องมี database AdventureWorks2025 (ไม่งั้น error "Database 'AdventureWorks2025' does not exist"); ไฟล์สคริปต์ยังไม่มี header `MinVersion:` — ต้องเติมก่อนประกอบเด็ค ต้องเขียนเนื้อหาเพิ่ม: section 1 ไม่มีเนื้อหาเรื่อง Statistics/CE รองรับ demo นี้ (61 บรรทัด ไม่พูดถึง statistics เลย) — ต้องขยายก่อนถือว่าสไลด์มีวัตถุดิบครบ Ref: `Module_07_Query_Execution/Sections/01_Query_Optimizer/README.md`, Ref: `Module_07_Query_Execution/Sections/01_Query_Optimizer/Scripts/02_Statistics_Impact.sql`

---

## Section 2: Execution Plan Formats (สไลด์ 7–10)

### สไลด์ 7: Plan Types — Estimated vs Actual
- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา:**
  - Estimated Plan: แผนที่ Optimizer คาดการณ์โดยยังไม่ประมวลผลจริง — ใช้ตรวจโครงสร้าง Plan ได้เร็ว เหมาะกับ query หนัก/รันนานที่ยังไม่ควรรันจริง
  - Actual Plan: แผนจริงหลังประมวลผล มี Runtime Statistics — Actual Rows, Actual Elapsed Time (SSMS: Ctrl+M Include Actual Execution Plan)
  - จุดวิเคราะห์หลัก: เทียบ Estimated Rows vs Actual Rows — ต่างกันมาก (>10 เท่า) = cardinality คลาดเคลื่อน คือต้นเหตุ Plan แย่ (มักจาก stale statistics หรือ expression ที่ CE เดาไม่ได้)
  - เลือกใช้ให้ถูกจังหวะ: ตรวจเร็วไม่รบกวนระบบ = Estimated, ต้องการความจริง = Actual (แลกกับการรัน query จริง)
- **ภาพ/แผนภาพ:** ไม่มี (screenshot คู่ Estimated/Actual จาก SSMS ทำภายหลัง — ห้ามดึงจากเด็คเก่า 10987C/9Expert)
- **Speaker notes:** ต้องรู้มาก่อน: operator, cardinality, statistics — อภิธานศัพท์กลาง `Trainer_Docs/Glossary.md` (pending) Ref: `Module_07_Query_Execution/Sections/02_Execution_Plan_Formats/README.md:5-7`, Ref: `Module_07_Query_Execution/Labs/README.md:65-78`

### สไลด์ 8: Plan Formats — Graphical / XML / Text
- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา:**
  - Graphical: มาตรฐานใน SSMS — อ่านลำดับการไหลข้อมูลจากขวาไปซ้าย, Operator ที่กินทรัพยากรมากสุดแสดงตัวหนา/ใหญ่สุด
  - XML: ละเอียดสูงสุด — บันทึกเป็นไฟล์ `.sqlplan` เก็บ/แชร์/เปิดกลับใน SSMS ได้ ใช้วิเคราะห์เชิงลึกและส่งต่อทีม
  - Text (Legacy): รูปแบบข้อความรุ่นเก่า — อ่านยาก ปัจจุบันไม่นิยมใช้
  - เกณฑ์เลือกใช้: สอนและรีวิวเร็ว = Graphical, วิเคราะห์ลึก/เก็บหลักฐานเทียบก่อน-หลัง = XML `.sqlplan`
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ต้องเขียนเนื้อหาเพิ่ม: เนื้อหา formats ใน section เดิมมีแค่ 3 bullet (S2 README:39-42) — ต้องขยายวิธีบันทึก/เปิด `.sqlplan` และการดึง plan จาก Query Store ก่อนประกอบเด็ค Ref: `Module_07_Query_Execution/Sections/02_Execution_Plan_Formats/README.md:39-42`

### สไลด์ 9: Live Query Statistics — ดู Plan ขณะทำงานจริง
- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา:**
  - ดู Execution Plan ขณะ Query กำลังทำงาน พร้อม Animation ของ Data Flow — ชี้ได้ทันทีว่า Query "ติด" ที่ Operator ไหน เหมาะกับ Long-running Queries
  - 3 ทางเปิดใช้: SSMS "Include Live Query Statistics" · Activity Monitor → Show Live Execution Plan · ผ่าน DMV
  - DMV: `sys.dm_exec_query_profiles` — ดู `node_id`, `physical_operator_name`, `row_count` เทียบ `estimate_row_count`, `elapsed_time_ms` ต่อ session
  - Lightweight Query Profiling (SQL 2019+) เปิดเป็น Default — overhead ต่ำมาก ใช้ได้บน production
- **ภาพ/แผนภาพ:** ไม่มี (screenshot animation ของ LQS ทำภายหลัง)
- **Speaker notes:** ต้องเขียนเนื้อหาเพิ่ม: Section 2 ยังไม่มี `Scripts/` (Scripts 2/4 ของโมดูลตามแผน) — ต้องสร้างสคริปต์ประกอบ demo Live Query Stats (รวมถึง `02_Find_Implicit_Conversions.sql` ที่ `05_Workload_Implicit_Conversions.sql` อ้างถึงใน header แต่ยังไม่มีใน repo) ก่อนทำ Code Lab ของ section นี้ Ref: `Module_07_Query_Execution/Sections/02_Execution_Plan_Formats/README.md:9-37`, Ref: `Module_07_Query_Execution/Sections/01_Query_Optimizer/Scripts/05_Workload_Implicit_Conversions.sql:1-4`

### สไลด์ 10: Parallel Query Processing vs Batch Mode Execution
- **Layout:** `two-column` → potx `04 Two-Column`
- **เนื้อหา (ซ้าย — Parallelism):**
  - Exchange Operators: `Distribute Streams` / `Repartition Streams` / `Gather Streams` แทรกใน Plan เพื่อจัดการ Data Flow ระหว่าง Threads
  - DOP Dynamics: engine ลด DOP อัตโนมัติได้หาก Available Worker Threads ไม่พอ
  - Inhibitors ของ Parallelism: Scalar UDFs (ก่อน 2019), Recursive CTEs, MSTVFs, TOP
- **เนื้อหา (ขวา — Batch Mode):**
  - Vector-based: ประมวลผลทีละ Batch (~900 rows) ไม่ใช่ทีละ Row — CPU Efficiency สูงเพราะใช้ CPU Cache คุ้มค่า
  - Evolution: เดิมผูกกับ Columnstore Index เท่านั้น — SQL 2019+ ใช้กับ Rowstore (B-Tree/Heap) ได้แล้ว
  - เร่ง Analytical Query แบบ Big Scan + Aggregate บน OLTP Table โดยไม่ต้องแก้ Index
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ปิดท้ายด้วย Distributed Query Architecture (OLE DB Provider, OPENROWSET/OPENDATASOURCE) แบบสั้นถ้าเวลาเหลือ — เป็นเกราะเสริม ไม่ใช่ปลายทางของการ tuning Ref: `Module_07_Query_Execution/Sections/02_Execution_Plan_Formats/README.md:44-59`

---

## Section 3: Analyzing Query Plans (สไลด์ 11–14)

### สไลด์ 11: Data Access Operators — Seek / Scan / Key Lookup
- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา:**
  - Index Seek: เดิน B-Tree Traversal ตาม Predicate — ประสิทธิภาพสูงสุดเมื่อ Selectivity สูง
  - Index Scan: อ่าน Leaf Page ทั้งหมดของ Index — เหมาะกับตารางเล็กหรือ Low Selectivity
  - Table Scan: อ่าน Heap Table ทั้งตาราง — ควรหลีกเลี่ยงในตารางขนาดใหญ่
  - Key Lookup: Non-Clustered Index ไม่มี Column ที่ต้องการครบ → กระโดดกลับ Clustered Index/Heap ทีละแถว — Expensive เมื่อเกิดจำนวนมาก
  - ทางแก้ Key Lookup ที่พบบ่อย: ออกแบบ Covering Index (INCLUDE columns) เพื่อตัดการเดินทางกลับตารางหลัก
- **ภาพ/แผนภาพ:** ไม่มี (ใช้ plan จริงจาก demo สไลด์ 14 ประกอบตอนสอน)
- **Speaker notes:** ต้องรู้มาก่อน: B-Tree, clustered/non-clustered index (จาก M6) — อภิธานศัพท์กลาง `Trainer_Docs/Glossary.md` (pending) ต้องเขียนเนื้อหาเพิ่ม: Section 3 เป็น section ที่บางที่สุดของโมดูล (26 บรรทัด ไม่มี sql block ไม่มี "ตรวจความเข้าใจ") — ต้องขยายตาม DoD ราย section ก่อนถือว่าสไลด์ชุดนี้มีวัตถุดิบครบ Ref: `Module_07_Query_Execution/Sections/03_Analyzing_Query_Plans/README.md:5-9`, Ref: `Module_07_Query_Execution/README.md:44-47`

### สไลด์ 12: Join Operators — Nested Loops / Merge / Hash
- **Layout:** `bullets+diagram` → potx `03 Content`
- **เนื้อหา:**
  - Nested Loops: ประสิทธิภาพสูงเมื่อ Outer Input ขนาดเล็ก และ Inner หาได้ด้วย Seek
  - Merge Join: เก่งสุดเมื่อ Input ทั้งสองฝั่ง Sorted อยู่แล้ว
  - Hash Join: เหมาะกับ Input ขนาดใหญ่ที่ไม่ Sorted — แลกด้วย Memory เพื่อสร้าง Hash Table
  - Memory Grant ไม่พอ → Hash Spill ลง TempDB — สัญญาณเตือนที่จะเรียนในสไลด์ถัดไป
- **ภาพ/แผนภาพ:** `join-operators-decision.png` — วาดใหม่ ≥2400px (Decision flow เลือก Join Strategy ตามขนาด Input และการเรียงลำดับ) เก็บที่ `Module_07_Query_Execution/Sections/03_Analyzing_Query_Plans/images/` (โฟลเดอร์ยังไม่มี — ต้องสร้าง)
- **Speaker notes:** ต้องเขียนเนื้อหาเพิ่ม: เดิมมีแค่ 3 bullet (S3 README:11-14) — ต้องเพิ่มตัวอย่าง plan จริงของ join ทั้ง 3 แบบและวิธีอ่านว่า operator ไหนแพงก่อนประกอบเด็ค Ref: `Module_07_Query_Execution/Sections/03_Analyzing_Query_Plans/README.md:11-14`

### สไลด์ 13: Plan Warnings — สัญญาณเตือนบน Plan
- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา:**
  - Missing Index: คำแนะนำสร้าง Index ที่ขึ้นบน Plan (สีเขียว) — ใช้เป็น "ใบแนะนำ" พิจารณาต่อ ไม่ใช่คำสั่งเด็ดขาด เพราะมี Overhead ฝั่ง DML
  - Implicit Conversion: Data Type ไม่ตรงกัน → `CONVERT_IMPLICIT` ครอบ Column → ปิดกั้น Index Seek
  - Spill Warning: Memory Grant ไม่พอ → เขียนข้อมูลชั่วคราวลง TempDB — ผลกระทบต่อประสิทธิภาพสูง
  - Missing Statistics: Optimizer ขาด Statistics สำหรับประเมิน Cost
  - ล่าสัญญาณระดับเซิร์ฟเวอร์: Top CPU (`06_Top_CPU_Queries.sql`) และ High IO (`07_High_IO_Queries.sql`) เชื่อม Plan กับ Resource จริง (สไตล์ Glenn Berry diagnostic queries)
- **ภาพ/แผนภาพ:** ไม่มี (จับ warning icon จาก plan ของ demo สไลด์ 14)
- **Speaker notes:** ต้องเขียนเนื้อหาเพิ่ม: ขยายวิธีจับ warning จาก plan XML และวิธีใช้คู่ workload generator (`03_Workload_CPU_Queries.sql` / `04_Workload_IO_Queries.sql` รันก่อน แล้วค่อยดู top queries) ก่อนประกอบเด็ค Ref: `Module_07_Query_Execution/Sections/03_Analyzing_Query_Plans/README.md:16-20`, Ref: `Module_07_Query_Execution/Sections/03_Analyzing_Query_Plans/Scripts/06_Top_CPU_Queries.sql:1-4`, Ref: `Module_07_Query_Execution/Sections/03_Analyzing_Query_Plans/Scripts/07_High_IO_Queries.sql:1-4`

### สไลด์ 14: Demo — Seek vs Scan: ให้ Seek กลายเป็น Scan ได้อย่างไร
- **Layout:** `demo` → potx `06 Code Lab`
- **เนื้อหา:**
  - เทียบ 2 แนวทางพื้นฐานสุด: SEEK (Precision) vs SCAN (Brute Force) บนตารางทดสอบที่มี Index
  - รัน query แบบ SARGable → Index Seek; เปลี่ยน Predicate ให้เกิด Implicit Conversion → Plan กลายเป็น Scan + Warning `CONVERT_IMPLICIT`
  - เทียบ Logical Reads (`SET STATISTICS IO`) และ Estimated vs Actual Rows ระหว่างสอง Plan
  - เชื่อมโยง workload จริง: รัน `05_Workload_Implicit_Conversions.sql` generate traffic แล้วล่า conversion จาก Query Store (สไตล์ Exercise 1 Step 3 ของแล็บ)
  - ประเด็นสอน: SARGability อยู่ในมือคนเขียน query — แก้ที่ Type/Pattern ถูกกว่าบังคับด้วย Hint
- **ภาพ/แผนภาพ:** ไม่มี
- **Script:** `Module_07_Query_Execution/Sections/03_Analyzing_Query_Plans/Scripts/01_Seek_vs_Scan.sql` (สนับสนุน: `Module_07_Query_Execution/Sections/01_Query_Optimizer/Scripts/05_Workload_Implicit_Conversions.sql`)
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน (มติ #9): SARGable = predicate ที่ seek ได้ (ไม่มี function ครอบ column); Implicit Conversion = การแปลง Data Type อัตโนมัติเมื่อเทียบคนละ type; Ctrl+M = Include Actual Execution Plan error ที่พบได้ + รุ่นขั้นต่ำ: ใช้ได้ SQL Server 2019+ บน AdventureWorks2025; ไฟล์สคริปต์ยังไม่มี header `MinVersion:` — เติมก่อนประกอบเด็ค ต้องเขียนเนื้อหาเพิ่ม: Section 3 ยังบาง (26 บรรทัด) — ดูหมายเหตุสไลด์ 11 Ref: `Module_07_Query_Execution/Sections/03_Analyzing_Query_Plans/Scripts/01_Seek_vs_Scan.sql:1-8`, Ref: `Module_07_Query_Execution/Labs/README.md:49-61`

---

## Section 4: Intelligent Query Processing (สไลด์ 15–18)

### สไลด์ 15: Intelligent Query Processing — ให้ Engine แก้ Plan เอง
- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา:**
  - IQP = กลุ่มฟีเจอร์ปรับปรุง Query Performance โดยอัตโนมัติ แก้ Code น้อยที่สุด (Minimal Implementation Effort)
  - เงื่อนไขหลัก: Compatibility Level ต้องสูงพอ — `160` (SQL 2022) / `170` (SQL 2025)
  - หลายฟีเจอร์ต้องเปิด Query Store (READ_WRITE mode) เพื่อเก็บ Feedback ลง Disk
  - มุมการสอน: IQP ไม่ใช่ทดแทน query ที่เขียนดี — มันช่วยเคสที่ CE/Plan เดาผิดซ้ำ ๆ ของ Workload จริง
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ต้องรู้มาก่อน: cardinality estimation, plan cache, query store — อภิธานศัพท์กลาง `Trainer_Docs/Glossary.md` (pending) Ref: `Module_07_Query_Execution/Sections/04_Intelligent_Query_Processing/README.md:5-18`

### สไลด์ 16: IQP Features ต่อรุ่น 2017 → 2025
- **Layout:** `bullets+diagram` → potx `03 Content`
- **เนื้อหา:**
  - 2017: Batch Mode Adaptive Joins, Memory Grant Feedback, Interleaved Execution (MSTVF)
  - 2019: Row Mode Memory Grant Feedback, Table Variable Deferred Compilation, Scalar UDF Inlining, Batch Mode on Rowstore
  - 2022 (compat 160): MGF Persisted, Parameter Sensitive Plan (PSP), DOP Feedback, CE Feedback, Optimized Plan Forcing — กลุ่มหลังต้องมี Query Store
  - 2025 (compat 170): Optional Parameter Plan Optimization (OPPO) + CE Feedback for Expressions; DOP Feedback เปิด Default
  - ติดตาม Feedback ที่ engine ใช้จริง: column `has_compile_replay_script` บน `sys.query_store_plan`
- **ภาพ/แผนภาพ:** `iqp-features-timeline.png` — วาดใหม่ ≥2400px (Timeline 4 รุ่น 2017/2019/2022/2025 พร้อมป้ายกำกับ "ต้อง Query Store" ต่อกลุ่ม) เก็บที่ `Module_07_Query_Execution/Sections/04_Intelligent_Query_Processing/images/` (โฟลเดอร์ยังไม่มี — ต้องสร้าง)
- **Speaker notes:** ใช้ตารางเต็มใน section README เป็นแผนที่ แต่บนสไลด์แสดงเฉพาะ timeline — ตารางเต็มให้ผู้เรียนกลับไปอ่าน Ref: `Module_07_Query_Execution/Sections/04_Intelligent_Query_Processing/README.md:20-38`, Ref: `Module_07_Query_Execution/README.md:60-77`

### สไลด์ 17: PSP vs OPPO — หลาย Plan ต่อ Statement
- **Layout:** `two-column` → potx `04 Two-Column`
- **เนื้อหา (ซ้าย — PSP, SQL 2022 / compat 160):**
  - ปัญหา: Parameter Sniffing บน Data Skew — ค่าหนึ่งมี 10 แถว อีกค่ามี 1 ล้านแถว Plan เดียวไม่พอ
  - กลไก: Dispatcher ใน Plan Cache ตรวจค่า Parameter ตอน Runtime → แตก Query Variants ตามช่วง Cardinality (Low/Medium/High)
  - ผล: Query เดียวมี Multiple Cached Plans ที่เหมาะกับแต่ละช่วงข้อมูลโดยอัตโนมัติ
- **เนื้อหา (ขวา — OPPO, SQL 2025 / compat 170):**
  - ปัญหา: Pattern `WHERE (@p IS NULL OR col = @p)` ได้ Index Scan ตลอดเวลาแม้ระบุค่า `@p`
  - กลไก: Multiplan แยก 2 ทาง — `@p IS NULL` → Scan Plan, `@p IS NOT NULL` → Seek Plan
  - ผล: ไม่ต้องเขียน IF/ELSE หรือ `OPTION(RECOMPILE)` — ประสิทธิภาพดีทั้งสองกรณี
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ยก Lab Exercise 4 (`usp_SearchOrders`) เป็นตัวอย่างรูปธรรมทันทีหลังสไลด์นี้ Ref: `Module_07_Query_Execution/Sections/04_Intelligent_Query_Processing/README.md:61-77`, Ref: `Module_07_Query_Execution/Labs/README.md:132-172`

### สไลด์ 18: ตรวจความเข้าใจ — Query Execution
- **Layout:** `quiz` → potx `03 Content`
- **เนื้อหา:**
  - 1) Logical Reads กับ Physical Reads ต่างกันอย่างไร — ตัวไหนบ่งชี้ Disk ช้า?
  - 2) Key Lookup คืออะไร ทำไมถึงเปลือง I/O และแก้ด้วยแนวทางใด?
  - 3) Implicit Conversion ทำให้ Plan แย่อย่างไร — ต้องแก้ที่จุดไหนของ query?
  - 4) OPPO ต้องมีเงื่อนไขอะไรจึงทำงาน? (SQL Server 2025 / compat 170 + Query Store)
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** 3 คำถามแรกมีเฉลยใน module README (บล็อก details) ส่วนข้อ 4 จาก Wrap-up ท้ายแล็บ; quiz bank รายโมดูลของหลักสูตรยังไม่มี (ช่องว่างตามแผน — เฟส 3) จึงต้องเขียน quiz bank เพิ่มก่อนถือว่าชุดนี้จบ Ref: `Module_07_Query_Execution/README.md:39-52`, Ref: `Module_07_Query_Execution/Labs/README.md:176-181`

---

## แล็บและปิดโมดูล (สไลด์ 19–20)

### สไลด์ 19: Lab 7 — Execution Plan Analysis & Query Tuning (4 Exercise)
- **Layout:** `lab` → potx `06 Code Lab`
- **เนื้อหา:**
  - Prerequisites: SQL Server 2019+ (แนะนำ 2025/17.x), database AdventureWorks2025, สิทธิ์ `VIEW DATABASE STATE`, เปิด Ctrl+M ตลอดแล็บ
  - Exercise 1: Implicit Conversion (Non-SARGable) — จำลองปัญหา/แก้ให้ตรง type/ล่า conversion ทั้ง cache ด้วย Query Store
  - Exercise 2: Cardinality คลาดเคลื่อน → หา operator แพง (Estimated vs Actual) + SARGable แบบ function บน column
  - Exercise 3: Temp Table vs Table Variable vs CTE — วัดผลและเกณฑ์เลือกใช้
  - Exercise 4: IQP — Memory Grant Feedback + OPPO (compat 170) + ติดตาม feedback จาก Query Store
  - Cleanup: `DROP PROCEDURE IF EXISTS dbo.usp_SearchOrders;`
- **ภาพ/แผนภาพ:** ไม่มี
- **Script:** Ref: `Module_07_Query_Execution/Labs/README.md` (4 Exercise, ตรวจแล้ว); สคริปต์ประกอบใน `Module_07_Query_Execution/Sections/01_Query_Optimizer/Scripts/` และ `Module_07_Query_Execution/Sections/03_Analyzing_Query_Plans/Scripts/`
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน (มติ #9): CTE = `WITH ... AS` ตั้งชื่อ result set ชั่วคราวที่ inline ทุกครั้ง ไม่ materialize; Temp Table ต่างจาก Table Variable ที่ scope/Statistics; Query Store DMV JOIN 3 ตาราง (`sys.query_store_query` + `query_store_plan` + `query_store_runtime_stats`); Exercise 1 Step 3 ใช้ `CAST(query_plan AS XML).value('count(...)', 'INT')` (XQuery นับ node ใน plan XML) error ที่พบได้ + รุ่นขั้นต่ำ: Exercise 4 Step 1 ต้องใช้ SQL Server 2025 (17.x) เพราะ `SET COMPATIBILITY_LEVEL = 170` จะ error บนรุ่นเก่าและฟีเจอร์ OPPO ไม่มี — บน 2022 ให้ข้าม Exercise 4 และทำ Ex 1–3; ไฟล์ .sql ทั้ง 7 ยังไม่มี header `MinVersion:` — เติมก่อนประกอบเด็ค Ref: `Module_07_Query_Execution/Labs/README.md:6-9,132-172,182-186`

### สไลด์ 20: สรุป Module 7 + ก้าวต่อไป
- **Layout:** `summary` → potx `08 Closing (dark)`
- **เนื้อหา:**
  - SQL เป็นภาษา Declarative — คุณภาพ Plan มาจาก Statistics และเป้าหมาย "Good Enough Plan" ของ Optimizer
  - อ่าน Plan: ไหลขวา→ซ้าย, เทียบ Estimated vs Actual Rows, จับ 4 Warnings (Missing Index / Implicit Conversion / Spill / Missing Statistics)
  - SARGability อยู่ในมือผู้เขียน query — แก้ที่ตัว query/type ก่อนแตะ Hardware
  - IQP (PSP / OPPO / DOP Feedback) ช่วยอัตโนมัติบน compat 160/170 โดยมี Query Store เป็นพยาน
  - ก้าวต่อไป: Module 8 Plan Caching — Plan ที่ดีถูก cache อย่างไร และเน่า (regression) ได้อย่างไร
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ปิดโมดูลด้วยการโยงตรงไปแล็บ M8 (Query Store Regression + Force Plan) เพื่อให้ผู้เรียนเห็นว่า plan ที่วิเคราะห์วันนี้จะถูก cache และถูกจัดการต่อในโมดูลหน้า Ref: `Module_07_Query_Execution/README.md:1-13`, Ref: `Module_08_Plan_Caching/README.md`
