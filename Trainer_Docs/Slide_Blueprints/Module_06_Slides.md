# Module 6 — Statistics & Index Internals: สไลด์ไบล์พรินต์รายสไลด์

> **สรุปครอบคลุม**
> - เด็ค M6 = **16 สไลด์** ตามสูตรตายตัวของแผนแม่บท §4.2 (โครง 4: Cover / Module Divider / Lab / Closing + 4 สไลด์ × 3 sections) บน template `Trainocate_SQLPerfTuning_Template.potx` 8 layouts — ใช้ layouts: 01 Cover, 02 Module Divider, 03 Content, 04 Two-Column, 06 Code Lab (3 ใบ ≤ เพดาน 4), 08 Closing ไม่มี DEFAULT
> - เนื้อหาครอบคลุม 3 sections ตาม `Module_06_Statistics_Index_Internals/README.md`: (1) Statistics & Cardinality Estimation (2) Index Internals — Heap/B-Tree, การออกแบบ Key, Missing/Bad Index (3) Columnstore Indexes — Architecture + Internals + การตัดสินใจเลือกใช้
> - สคริปต์จริงใน repo วันนี้ 10 ไฟล์ .sql (S1 = 3, S2 = 7, S3 = ไม่มี Scripts/) — Code Lab ทุกใบอ้างไฟล์จริง แต่ทั้ง 10 ไฟล์ยังไม่มี header `MinVersion:` (ตรวจด้วย `head -12` ทุกไฟล์เมื่อ 2026-10-01) ต้องเติมตามเฟส 0 ก่อนประกอบเด็ค (DoD สไลด์ข้อ 2c)
> - ภาพต้องวาดใหม่ 3 ชิ้น PNG กว้าง ≥2400px ลง `Module_06_*/Sections/*/images/` — ปัจจุบันโมดูลไม่มีภาพเลย (ตรวจด้วย `find Module_06_Statistics_Index_Internals -type f` เมื่อ 2026-10-01); ห้ามดึงภาพเด็คเก่า 10987C/9Expert (มติ #8)
> - เนื้อหา section ทั้ง 3 ยังเป็น outline (README 93/56/27 บรรทัด ตามลำดับ) — สไลด์ออกแบบตาม **เป้าหมายของหัวข้อ** ไม่ย่อตามความบาง และ speaker notes ของสไลด์ที่เกินเนื้อหาปัจจุบันมีธง **"ต้องเขียนเนื้อหาเพิ่ม"** ทุกจุด; งบเวลาบน Module Divider เป็นค่าประมาณจากเพดาน 7.3 นาที/สไลด์ (≈117 นาที) ยังไม่มีงบทางการ — ตารางเวลาใน `Course_Guide_4Days.md` วันที่ 2 (บรรทัด 85–91) **ไม่มีช่อง บทที่ 6/LAB 6** แม้ตาราง mapping แล็บ (`:131`) ระบุ day 2

---

### สไลด์ 1: Cover — Module 6: Statistics & Index Internals
- **Layout:** `title` → potx `01 Cover (dark)`
- **เนื้อหา:**
  - **Module 6 — Statistics & Index Internals**
  - Statistics · Cardinality Estimation · Index Internals · Columnstore
  - หลักสูตร Microsoft SQL Server Performance Tuning (4 วัน / 24 ชม.) — บทที่ 6/11
  - ผู้สอน: Aj. Phakkhaphong K.
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ (layout dark ใช้ typography เพียงอย่างเดียว — ห้ามดึงภาพเด็คเก่า)
- **Speaker notes:** เปิดโมดูลด้วยคำถามชวนคิด: "Report ช้าลงทั้งที่ index มีอยู่ครบแล้ว — ปัญหาอยู่ที่ index หรือที่สิ่งที่ Optimizer 'เชื่อ' เกี่ยวกับข้อมูล?" `Ref: Module_06_Statistics_Index_Internals/README.md`

### สไลด์ 2: Module Divider — โรดแมปและงบเวลาโมดูล
- **Layout:** `section-divider` → potx `02 Module Divider (dark)`
- **เนื้อหา:**
  - ⏱ **งบเวลาโมดูล: ≈117 นาที** (ประมาณจากเพดาน 7.3 นาที/สไลด์ × 16 สไลด์ — ยังไม่มีงบทางการ ต้องเทียบเวลาจริงจากการทดสอบผู้เรียนเฟส 4)
  - 🧪 **LAB 6 — 4 Exercise** (จาก 40 ของหลักสูตร): Missing/Unused Index + วัดผลก่อน-หลัง + Stale Statistics
  - Section 1 — Statistics & Cardinality Estimation
  - Section 2 — Index Internals
  - Section 3 — Columnstore Indexes
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ (โรดแมปเป็น bullet บน layout divider)
- **Speaker notes:** แจ้งผู้เรียนงบเวลาและจำนวน Exercise ตาม Slide Spec §4.2 และย้ำว่าแล็บท้ายโมดูลเชื่อมกับ demo ในคาบโดยตรง `Ref: Module_06_Statistics_Index_Internals/Labs/README.md` · หมายเหตุผู้สอน: ตารางเวลา `Trainer_Docs/Course_Guide_4Days.md` วันที่ 2 (บรรทัด 85–91) ไม่มีช่อง บทที่ 6 แม้ตาราง mapping แล็บ `:131` ระบุ day 2 — ต้องแก้ guide ก่อนจัดอบรมจริง

### สไลด์ 3: Statistics คืออะไร — ข้างในมี 3 ส่วน
- **Layout:** `bullets+diagram` → potx `03 Content`
- **เนื้อหา:**
  - **Statistics** = object ที่ Optimizer ใช้อ่านการกระจายตัว (Distribution) ของ column เพื่อ **ประมาณจำนวนแถว (Cardinality Estimation)**
  - ตัดสินใจ 3 เรื่อง: แถวโดยประมาณ · Index Seek vs Index Scan · Join Algorithm (Nested Loops / Hash / Merge)
  - **Header** — เวลา update ล่าสุด + Rows Sampled → ใช้ตรวจว่า stats เก่าแค่ไหน
  - **Density Vector** — ค่า 1/Distinct Values → ใช้กับ GROUP BY และ multi-column join
  - **Histogram** — สูงสุด 200 Steps; คอลัมน์สำคัญ `RANGE_HI_KEY` / `EQ_ROWS` / `RANGE_ROWS`
  - Stats ไม่ตรงจริง (Stale) → CE ผิด → Plan แย่ → Query ช้า
- **ภาพ/แผนภาพ:** วาดใหม่ `Module_06_Statistics_Index_Internals/Sections/01_Statistics_Cardinality_Estimation/images/statistics-structure-histogram.png` (≥2400px) — แสดง Header/Density/Histogram + ตัวอย่าง histogram steps
- **Speaker notes:** ต้องรู้มาก่อน: การอ่าน execution plan เบื้องต้น (Estimated vs Actual Rows) และความหมายคำว่า DMV — ลิงก์ glossary กลาง `Trainer_Docs/Glossary.md` (ยังไม่มีไฟล์ ต้องสร้างตามเฟส 0 ก่อนใช้เด็คนี้) `Ref: Module_06_Statistics_Index_Internals/Sections/01_Statistics_Cardinality_Estimation/README.md` · **ต้องเขียนเนื้อหาเพิ่ม:** ตัวอย่างตัวเลข histogram จริงจาก AdventureWorks2025 ยังไม่มีใน README (section เป็น outline 93 บรรทัด)

### สไลด์ 4: Cardinality Estimation — Legacy CE vs New CE
- **Layout:** `two-column` → potx `04 Two-Column`
- **เนื้อหา:**
  - **ฝั่งซ้าย — Legacy CE (< 2014):** สมมติ Independence (column อิสระต่อกัน) + Uniformity (กระจายสม่ำเสมอ) + Containment แบบ "มีอยู่จริงเท่านั้น"; ไม่เข้าใจ Ascending Key
  - **ฝั่งขวา — New CE (2014+):** เข้าใจ Correlation ระหว่าง column · รองรับ Skewed Data · รองรับข้อมูลที่ยังไม่มี (Containment) · เข้าใจ Ascending Key ที่มากกว่า stats
  - **Overestimation:** Memory Grant บวมเกินจำเป็น / เลือก Hash Join ที่ไม่จำเป็น
  - **Underestimation:** Spill to TempDB / เลือก Nested Loops กับตารางใหญ่
  - ทางแก้เมื่อ CE ผิด: `LEGACY_CARDINALITY_ESTIMATION` (DB scoped / `USE HINT`) · Query Store Hint (`sp_query_store_set_hints`, 2022+) · **CE Feedback for Expressions (2025)**
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ (เทียบสองคอลัมน์ด้วย placeholder ของ layout 04)
- **Speaker notes:** เน้นว่าทางแก้ทั้งหมดเป็น "แผงประกัน" ไม่ใช่ค่า default — ต้องมีหลักฐานว่า New CE แย่กว่าจริงจาก Query Store ก่อนใช้ `Ref: Module_06_Statistics_Index_Internals/Sections/01_Statistics_Cardinality_Estimation/README.md` · **ต้องเขียนเนื้อหาเพิ่ม:** ส่วน CE Feedback for Expressions 2025 มีแค่ 1 bullet ใน module README:39 — ต้องขยายตัวอย่าง expression (`DATEDIFF`/`CONVERT` บน predicate) ใน section README

### สไลด์ 5: Stale Statistics และการจัดการ
- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา:**
  - `modification_counter` (จาก `sys.dm_db_stats_properties`) = จำนวนแถวที่เปลี่ยนนับจากการ update ล่าสุด
  - Threshold เก่า (≤ 2014): **20% + 500 rows** — ตารางใหญ่ต้องเปลี่ยนเยอะมากถึงจะ update; **2016+**: Dynamic Threshold ตามขนาดตาราง → update ถี่ขึ้น
  - อาการ stats เก่า: Plan เปลี่ยน Seek → Scan · Underestimation · Memory/TempDB Spill
  - Auto Update สองโหมด: **Synchronous** (default — query รอ update ก่อนแล้วค่อยรัน) vs **Asynchronous** (query รันด้วย stats เก่าไปก่อน, background อัปเดตตามหลัง)
  - Manual: `UPDATE STATISTICS ... WITH FULLSCAN` หลัง Bulk Load หรือตามรอบ maintenance (เช่น Weekly) + Auto Create ครอบ column ที่ถูก filter แต่ยังไม่มี index
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ
- **Speaker notes:** โยงกับ demo ถัดไป: เดี๋ยวเราจะสร้าง skew จริง 50,000 แถวแล้วดูค่า estimated เพี้ยนหน้าตาเป็นอย่างไร `Ref: Module_06_Statistics_Index_Internals/Sections/01_Statistics_Cardinality_Estimation/README.md` (หัวข้อ 2.4–2.5 ครบใน README แล้ว)

### สไลด์ 6: Code Lab — อ่าน Statistics จริงและเห็นผลของ Stale Stats
- **Layout:** `demo` → potx `06 Code Lab`
- **เนื้อหา:**
  - STEP 1: `DBCC SHOW_STATISTICS` — อ่าน Header / Density Vector / Histogram ของ stats จริงบน AdventureWorks2025
  - STEP 2: ตรวจรายการ stats เก่าด้วย `sys.dm_db_stats_properties` + `STATS_DATE` (แนว Glenn Berry SQL Server 2025 Diagnostic Queries, Query 77)
  - STEP 3: สร้างตาราง + index แล้วยัดข้อมูล skew 50,000 แถว → เทียบ **Estimated vs Actual rows** (เปิด Ctrl+M) ก่อน/หลัง `UPDATE STATISTICS ... WITH FULLSCAN`
  - ⚠ error ที่พบได้: `Invalid object name 'AdventureWorks2025'` (DB ยังไม่ restore) · Msg 297 permission (`VIEW DATABASE STATE` ไม่พอ) · **รุ่นขั้นต่ำ: SQL Server 2019+ (แนะนำ 2025 17.x)** ตาม Prerequisites ของแล็บ
- **ภาพ/แผนภาพ:** screenshot ผล `DBCC SHOW_STATISTICS` (ถ่ายจากการรันจริง 17.x ตอน sign-off — ยังไม่มีใน repo)
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน: **DBCC** = Database Console Command; **CROSS APPLY** = เรียก table-valued function ต่อทีละแถว (แล็บ Exercise 3 ใช้กับ `sys.dm_db_stats_properties`) `Ref: Module_06_Statistics_Index_Internals/Sections/01_Statistics_Cardinality_Estimation/Scripts/07_Show_Statistics_Detail.sql` · **Script:** `07_Show_Statistics_Detail.sql`, `03_Check_Stale_Stats.sql`, `04_Stale_Statistics.sql` (โฟลเดอร์เดียวกัน) — ทั้ง 3 ไฟล์ยังไม่มี header `MinVersion:` ต้องเติมตามเฟส 0 ก่อนประกอบเด็ค

### สไลด์ 7: Heap vs B-Tree — โครงสร้างการจัดเก็บข้อมูล
- **Layout:** `bullets+diagram` → potx `03 Content`
- **เนื้อหา:**
  - **Heap**: ตารางไม่มี Clustered Index — เข้าถึงแถวด้วย **RID (Row Identifier)**; เหมาะ Staging Table ที่เน้น Insert Speed แต่ไม่เหมาะกับการ Search
  - **B-Tree (Balanced Tree)**: Root Node → Intermediate Levels → Leaf Nodes — ทุกเส้นทางจาก root ยาวเท่ากัน
  - **Clustered Index**: Leaf เก็บ Data Rows จริง · **Nonclustered**: Leaf เก็บ Pointer/Locator กลับไปหาแถว
  - ผลต่อ tuning: NC Index ที่ครอบไม่ครบ column ที่ query ต้องใช้ → **Key Lookup** ที่แพง — จุดเชื่อมไป Covering Index (สไลด์ถัดไป)
- **ภาพ/แผนภาพ:** วาดใหม่ `Module_06_Statistics_Index_Internals/Sections/02_Index_Internals/images/heap-vs-btree.png` (≥2400px) — วาด heap (unordered + RID lookup) คู่ B-Tree 3 ชั้น
- **Speaker notes:** ต้องรู้มาก่อน: โครงสร้าง Page/Data File จาก Module 3 — ลิงก์ glossary กลาง `Trainer_Docs/Glossary.md` (ยังไม่มีไฟล์ ตามเฟส 0) `Ref: Module_06_Statistics_Index_Internals/Sections/02_Index_Internals/README.md` · **ต้องเขียนเนื้อหาเพิ่ม:** ตัวอย่าง index depth/จำนวน page จริงจาก AdventureWorks2025 (เช่น `sys.dm_db_database_page_allocations`) ยังไม่มีใน section README

### สไลด์ 8: ออกแบบ Index ให้ดี — Key, Covering, Filtered
- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา:**
  - Clustered Key 4 คุณสมบัติ: **Unique / Narrow / Static / Ever-increasing** — หลีกเลี่ยง Uniqueifier 4 bytes, Page Split และ Random I/O
  - **Covering Index**: `INCLUDE` column ที่ SELECT ต้องใช้ลง Leaf Level → กำจัด Key Lookup ออกจาก plan
  - **Filtered Index**: มีเงื่อนไข `WHERE` → index เล็กลง เร็วขึ้นเฉพาะ Subset ของข้อมูล
  - **Sort Order**: `ORDER BY Col1 ASC, Col2 DESC` → ออกแบบ key ตรงทิศเพื่อกำจัด Sort Operator (อ่านย้อนได้เฉพาะทิศเดียวทั้ง index)
  - ตัวเลือก Production: `ONLINE = ON` (Enterprise), `DATA_COMPRESSION = PAGE`, **Resumable Online Index Rebuild (2019+)** เพื่อคุม Maintenance Window
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ (สามารถเสริม mini-diagram Covering Index ในภาพเดียวกับสไลด์ 7 ภายหลัง)
- **Speaker notes:** ย้ำว่า INCLUDE ไม่ใช่ "ใส่ให้ครบทุก column" — เพิ่มเท่าที่ plan ใช้จริง เพราะทุก column ใน index คือภาระ write `Ref: Module_06_Statistics_Index_Internals/Sections/02_Index_Internals/README.md` (หัวข้อ 3.2–3.3, 3.6)

### สไลด์ 9: Missing Index ที่ควรเติม vs Index ขยะที่ควรตัด
- **Layout:** `two-column` → potx `04 Two-Column`
- **เนื้อหา:**
  - **ฝั่งซ้าย — Missing Index (เติมอย่างมีวิจารณญาณ):** อ่านจาก `sys.dm_db_missing_index_details/_groups/_group_stats` + benefit_score และแนว "Index Advantage" (Glenn Berry Query 72)
  - ซ้าย (ต่อ): Query Store ยืนยันด้วย `count_executions` + `avg_duration` ว่า workload จริงใช้จริง
  - ซ้าย (ระวัง): DMV **ไม่คิด INCLUDE/ORDER** และชี้ตารางเดิมซ้ำหลายแถว — ต้อง review และรวม (consolidate) ก่อน `CREATE`
  - **ฝั่งขวา — Index ขยะ (ตัดหลังพิสูจน์):** Unused — `total_reads = 0` แต่ `total_writes` สูง → ผู้สมัคร DROP
  - ขวา (ต่อ): Duplicate (key เหมือนเป๊ะ) / Overlapping (เป็น subset ของ index อื่น)
  - ขวา (กฎ): ยืนยันไม่ใช่ PK/Unique constraint และไม่ใช่ index ที่ batch รายเดือนใช้ + baseline ยาว **≥ 1 business cycle** ก่อน DROP
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ
- **Speaker notes:** อุปสงค์-อุปทานของ index: การเพิ่ม index 1 ตัวคือการเก็บภาษี write ทุกครั้ง — ทั้งสองฝั่งต้องตัดสินจาก workload จริง ไม่ใช่คำแนะนำเดี่ยว `Ref: Module_06_Statistics_Index_Internals/Sections/02_Index_Internals/README.md` + `Labs/README.md` (Exercise 2) · **Script:** `Scripts/01_Missing_Index.sql`, `Scripts/05_Check_Bad_Indexes.sql`, `Scripts/10_Missing_Indexes_Advantage.sql`, `Scripts/02_Index_Analysis_QueryStore.sql` · **ต้องเขียนเนื้อหาเพิ่ม:** แนวคิดวิเคราะห์ missing index ผ่าน Query Store (ไฟล์ 02) ยังไม่มีใน section README

### สไลด์ 10: Code Lab — Missing Index → Covering Index วัดผลก่อน-หลัง
- **Layout:** `demo` → potx `06 Code Lab`
- **เนื้อหา:**
  - STEP 1: รัน query ปัญหาเปิด **Ctrl+M** + `SET STATISTICS IO, TIME ON` → เห็น Scan + **Missing Index (Impact ~99%)** จาก green text ของ SSMS
  - STEP 2: สร้าง `IX_Person_LastName_FirstName_cover ON Person.Person (LastName, FirstName) INCLUDE (BusinessEntityID)`
  - STEP 3: รันซ้ำวัดผล — Scan → **Index Seek ไม่มี Key Lookup**, logical reads ลดหลายเท่าถึงสิบเท่า; ระวังกรณีดึงหลายพันแถว Key Lookup อาจแพงกว่า Scan — ตัดสินจากผลจริง
  - ⚠ error ที่พบได้: `Invalid object name 'Person.Person'` (ไม่มี AdventureWorks2025) · permission CREATE/DROP INDEX ไม่พอ · **รุ่นขั้นต่ำ: SQL Server 2019+ (แนะนำ 2025 17.x)**
- **ภาพ/แผนภาพ:** screenshot แผนก่อน (Scan + Key Lookup) คู่หลัง (Index Seek) — ถ่ายจากการรันจริงตอน sign-off แล็บ
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน: **INCLUDE** = ต่อ column ที่ tail ของ index เพื่อ covering; **STRING_AGG ... WITHIN GROUP** (Exercise 2) = รวมค่าหลายแถวเป็น string พร้อมเรียงลำดับ `Ref: Module_06_Statistics_Index_Internals/Labs/README.md` (Exercise 1) · **Script:** `Module_06_Statistics_Index_Internals/Sections/02_Index_Internals/Scripts/01_Missing_Index.sql`

### สไลด์ 11: Columnstore Index — Architecture: CCI vs NCCI
- **Layout:** `bullets+diagram` → potx `03 Content`
- **เนื้อหา:**
  - **Column-oriented storage**: อ่านเฉพาะ column ที่ query ต้องใช้ → ลด I/O มหาศาลใน scan ขนาดใหญ่
  - **High Compression** ~10x–100x (ตัวเลขจากเอกสาร section README — ห้ามขึ้น Stat Callout จนกว่า sign-off รันจริงบน 17.x)
  - **Batch Mode Execution**: ~900 rows/batch แบบ vectorized → CPU efficiency สูงกว่า row-by-row
  - **CCI (Clustered Columnstore)** = primary storage ของตาราง — มาตรฐาน Fact Table ใน Data Warehouse
  - **NCCI (Nonclustered Columnstore)** บน Rowstore table → Real-time Analytics (HTAP)
- **ภาพ/แผนภาพ:** วาดใหม่ `Module_06_Statistics_Index_Internals/Sections/03_Columnstore_Indexes/images/columnstore-internals.png` (≥2400px) — แผนภาพ Rowgroup/Segment/Deltastore/Tuple Mover (ใช้ซ้ำในสไลด์ 12)
- **Speaker notes:** ต้องรู้มาก่อน: Rowstore/B-Tree จาก section 2 ของโมดูลนี้ + ลิงก์ glossary กลาง `Trainer_Docs/Glossary.md` (ยังไม่มีไฟล์ ตามเฟส 0) `Ref: Module_06_Statistics_Index_Internals/Sections/03_Columnstore_Indexes/README.md` · **ต้องเขียนเนื้อหาเพิ่ม:** ฟีเจอร์ 2025 (ordered nonclustered columnstore, ordered CCI build online, batch mode กับ built-in functions) มีแค่ 3 bullets ใน module README:43–45 — ยังไม่อยู่ใน section README

### สไลด์ 12: ข้างใน Columnstore — Rowgroup, Segment, Deltastore
- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา:**
  - **Rowgroup**: หน่วย logical ของแถว สูงสุดประมาณ 1 ล้านแถวต่อ Rowgroup
  - **Segment**: ข้อมูล 1 column ภายใน Rowgroup = หน่วยอ่านจาก disk (เลือก column น้อย = อ่าน segment น้อย)
  - **Dictionary Encoding**: ค่าซ้ำถูกแทนด้วย Reference ID → อีกชั้นของ compression
  - **Deltastore**: Insert/Update จำนวนน้อยพักในรูป Rowstore รอการบีบอัด
  - **Tuple Mover** (background process) ย้าย Deltastore → Compressed Rowgroup · **Deleted Bitmap** ติดตาม logical delete เพราะ compressed segment แก้ใส่ตรง ๆ ไม่ได้
- **ภาพ/แผนภาพ:** ใช้ภาพเดียวกับสไลด์ 11 (`images/columnstore-internals.png`) — คราวนี้ชี้ประกอบแต่ละองค์ประกอบ
- **Speaker notes:** อธิบายด้วยแอนะลอจี: compressed segments เป็น "หนังสือที่พิมพ์แล้ว" — แก้ไม่ได้ เพิ่มใหม่เข้า deltastore และลบด้วยการขีดฆ่า `Ref: Module_06_Statistics_Index_Internals/Sections/03_Columnstore_Indexes/README.md` (หัวข้อ 4.2) · **ต้องเขียนเนื้อหาเพิ่ม:** section นี้บางสุดของโมดูล (27 บรรทัด — ไม่มีบล็อก ```sql ไม่มี Scripts/ ไม่มี "ตรวจความเข้าใจ") ต้องเพิ่ม demo ด้วย `sys.dm_db_column_store_row_group_physical_stats` + สร้าง Scripts/ ตามช่องว่างในแผนแม่บท §3

### สไลด์ 13: เลือกอย่างไร — Rowstore vs Columnstore
- **Layout:** `two-column` → potx `04 Two-Column`
- **เนื้อหา:**
  - **ฝั่งซ้าย — Rowstore (B-Tree):** OLTP — point lookup/seek ทีละแถว, write ถี่
  - ซ้าย (ต่อ): ออกแบบ Narrow Key + Covering ตาม workload; update/delete ในที่ — ไม่มี deltastore
  - **ฝั่งขวา — Columnstore (CCI/NCCI):** DW/Analytical — scan ใหญ่, aggregation, compression สูง, Batch Mode เร่ง CPU
  - ขวา (ข้อจำกัด): update ผ่าน Deltastore + Deleted Rows → workload แก้ข้อมูลถี่ ๆ ต้องชั่งน้ำหนัก
  - ขวา (ของใหม่ใน 2025): **Ordered Nonclustered Columnstore** · **Ordered CCI build online** (คุณภาพ sort ดีขึ้น) · **SHRINK ทำงานดีขึ้นเมื่อมี CCI**
  - สรุปกลาง: **HTAP** = NCCI คร่อมสองโลก — transactional บน rowstore + analytics บน columnstore ในตารางเดียว
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ
- **Speaker notes:** เกณฑ์ตัดสินใจคือ "รูปแบบการอ่าน" ไม่ใช่ขนาดตารางเพียงอย่างเดียว — ถามว่า query กวาดหลายล้านแถวเพื่อ aggregate หรือหาแถวเดียว `Ref: Module_06_Statistics_Index_Internals/README.md` (หัวข้อ 7.2) + `Sections/03_Columnstore_Indexes/README.md` · **ต้องเขียนเนื้อหาเพิ่ม:** ข้อจำกัดของ Columnstore ฉบับเต็ม (feature limitations) ยังไม่มีใน repo — ต้องเขียน section เพิ่ม

### สไลด์ 14: Quiz — ตรวจความเข้าใจ Module 6
- **Layout:** `quiz` → potx `03 Content`
- **เนื้อหา:**
  - Q1: Query กรอง `Status = 1` ควรได้ 50,000 แถว แต่ Estimated Rows = 100 — วินิจฉัยว่าอะไรเสีย และแก้อย่างไร?
  - Q2: Index บน `(LastName)` มีอยู่แล้ว แต่ plan ยังมี Key Lookup — เพราะอะไร และจะออกแบบ index ใหม่อย่างไร?
  - Q3: หนึ่ง Rowgroup ของ Columnstore จุได้ประมาณกี่แถว และใครเป็นคนย้าย Deltastore → Compressed Rowgroup?
  - Q4: Missing Index DMV ขึ้น "Impact 99%" ให้ทันที — ทำไมยังต้อง review ก่อน CREATE จริง?
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ
- **Speaker notes:** เฉลยย่อใน notes: Q1 stale stats → `UPDATE STATISTICS ... WITH FULLSCAN`; Q2 ขาด INCLUDE → Covering Index; Q3 ≈1 ล้านแถว / Tuple Mover; Q4 DMV ไม่คิด INCLUDE/ORDER ชี้ตารางซ้ำ และไม่รู้ trade-off write `Ref: Module_06_Statistics_Index_Internals/Sections/*/README.md` + `Labs/README.md` (คำถามท้ายแล็บ) · **ต้องเขียนเนื้อหาเพิ่ม:** quiz bank รายโมดูลยังไม่มีไฟล์จริงใน repo (เฟส 3 ของแผน) — ชุดนี้เป็นฐานเริ่มต้น

### สไลด์ 15: LAB 6 — Missing/Unused Index & Statistics (4 Exercise)
- **Layout:** `lab` → potx `06 Code Lab`
- **เนื้อหา:**
  - **Ex 1 — Missing Index → Covering Index**: วัด logical reads ก่อน-หลัง (บล็อก expected ที่ `Labs/README.md:81` ยังต้อง normalize เป็นรูปแบบ `**Expected:**` ตามเฟส 0)
  - **Ex 2 — Unused/Duplicate Index**: วิเคราะห์ reads vs writes ก่อนตัดสินใจ DROP (สไตล์ Glenn Berry Query 71)
  - **Ex 3 — Stale Statistics**: จำลอง data skew + เทียบ estimated ก่อน/หลัง `UPDATE STATISTICS ... WITH FULLSCAN`
  - **Ex 4 (Optional, SQL Server 2025)**: CE Feedback for Expressions (compat level 170) — **ทางเลือกสำหรับรุ่นเก่า: ข้ามไป Ex เทียบเท่าคือ Ex 3** ซึ่งสาธิตผลของ CE ต่อ plan ได้เช่นกัน
  - Environment: **AdventureWorks2025** · Permission: `VIEW DATABASE STATE` + CREATE/DROP INDEX · **Exercise 4/40 ของหลักสูตร** · รุ่นขั้นต่ำ: SQL Server 2019+ (แนะนำ 2025 17.x)
  - ⚠ error ที่พบได้: `Invalid object name 'AdventureWorks2025'` (DB ยังไม่ restore) · Msg 297 permission — `VIEW DATABASE STATE` ไม่พอ ตอน query DMV (`sys.dm_db_missing_index_details` / `sys.dm_db_index_usage_stats`) · permission CREATE/DROP INDEX ไม่พอ (Ex 1) · `SET COMPATIBILITY_LEVEL = 170` fail บนรุ่น < 2025 (Ex 4 — ใช้ทางเลือกข้ามไป Ex 3 ตามด้านบน)
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ (มีรายการ Exercise + ลิงก์สคริปต์)
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน: **CROSS APPLY** (Ex 3 Step 1) = เรียก function ต่อทีละแถว; **GO 100** (Ex 3 Step 2) = รัน batch ซ้ำ 100 รอบเพื่อ seed ข้อมูล; **LEFT JOIN** (Ex 2) = เก็บ index ที่ยังไม่มีสถิติใช้มาแสดงด้วย `Ref: Module_06_Statistics_Index_Internals/Labs/README.md` · **Script:** `Sections/01_Statistics_Cardinality_Estimation/Scripts/` (3 ไฟล์) + `Sections/02_Index_Internals/Scripts/` (7 ไฟล์) — ทุกไฟล์ต้องเติม header `MinVersion:` ตามเฟส 0 ก่อนขึ้นเด็คจริง

### สไลด์ 16: สรุป Module 6 — และทางไปต่อ (Closing)
- **Layout:** `summary` → potx `08 Closing (dark)`
- **เนื้อหา:**
  - **Statistics ถูกต้อง = CE แม่น = Plan ดี** — เฝ้า `modification_counter` / `STATS_DATE` เป็นกิจวัตร
  - **Index คือ trade-off Read vs Write** — เติม missing อย่างมีวิจารณญาณ ตัด unused หลัง baseline ยาว ≥ 1 business cycle
  - **Columnstore คือคำตอบของ Analytical Workload** — เลือก CCI/NCCI ตามรูปแบบการอ่าน (DW/HTAP) และรู้ข้อจำกัด
  - ต่อไป **บทที่ 7: Query Execution & Optimization** — CE ที่เรียนวันนี้คือวัตถุดิบของ Query Processing Pipeline
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ (layout dark ปิดท้ายด้วยข้อความ)
- **Speaker notes:** ปิดด้วยการโยงไปแล็บ: เดินไปที่ LAB 6 เลย — ทุก Exercise ของวันนี้ใช้แนวคิดจาก 3 sections ครบ `Ref: Module_06_Statistics_Index_Internals/README.md` + `Trainer_Docs/Course_Guide_4Days.md` (บทที่ 7, วันที่ 3)

---

**สถานะไฟล์ที่ไบล์พรินต์นี้อ้าง (ตรวจเมื่อ 2026-10-01):**
- สคริปต์จริง 10 ไฟล์: `Sections/01_Statistics_Cardinality_Estimation/Scripts/` = `03_Check_Stale_Stats.sql`, `04_Stale_Statistics.sql`, `07_Show_Statistics_Detail.sql` · `Sections/02_Index_Internals/Scripts/` = `01_Missing_Index.sql`, `02_Index_Analysis_QueryStore.sql`, `05_Check_Bad_Indexes.sql`, `06_Advanced_Index_Analysis.sql`, `08_Workload_Index_Fragmentation.sql`, `09_Workload_Missing_Indexes.sql`, `10_Missing_Indexes_Advantage.sql` · `Sections/03_Columnstore_Indexes/` = ไม่มี Scripts/ (ช่องว่างตามแผน §3 — ต้องเติม 1 จุด)
- ภาพที่ต้องวาดใหม่ 3 ชิ้น: `statistics-structure-histogram.png`, `heap-vs-btree.png`, `columnstore-internals.png` (ทั้งหมด PNG ≥2400px ลง `Sections/*/images/` — ปัจจุบันไม่มีอยู่)
- หัวข้อเสีย `## ###` ที่ `Module_06_Statistics_Index_Internals/README.md:38` และ expected บางส่วนที่ `Labs/README.md:81` เป็นงานเฟส 0 ของแผนแม่บท — ไม่ใช่งานของเด็ค แต่ Code Lab จะขึ้นจริงได้หลังงานสองจุดนี้เสร็จ
