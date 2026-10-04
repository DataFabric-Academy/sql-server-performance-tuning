# สไลด์ไบล์พรินต์รายสไลด์ — Module 3: Database Structures (เด็ค 3/12 · 20 สไลด์)

**สรุปครอบคลุม**
- ออกแบบตามสูตรตายตัวของแผนแม่บท 4.2: **20 สไลด์ = โครง 4 (Cover / Module Divider / Lab / Closing) + 4 สไลด์ × 4 sections** — อยู่ในช่วง 12–24 ที่อนุญาต, Code Lab บน layout 06 จำกัดที่ 4 ใบ (สไลด์ 6, 9, 13, 19) พอดีเพดาน
- วัตถุดิบที่อ่านจริง: `Module_03_Database_Structures/README.md` + section README ทั้ง 4 + `Labs/README.md` (4 Exercise) + สคริปต์ 5 ไฟล์ใน `Sections/*/Scripts/` — ทุก speaker notes มี token `Ref:` ชี้ path จริง
- สไลด์ที่กำกับ **"ต้องเขียนเนื้อหาเพิ่ม"** ใน notes = concept slides ของ section ที่ยังบาง (S2 = 31 บรรทัด, S3 = 46, S4 = 29 บรรทัด) + quiz ทั้ง 4 ใบ (quiz bank รายโมดูลยัง = 0 ใน repo) — ออกแบบตามเป้าหมายของหัวข้อ ไม่ย่อตามความบาง
- งานที่ต้องปิดก่อนประกอบ .pptx (ตรวจแล้วด้วยคำสั่งใน session นี้): `.sql` ทั้ง 5 ไฟล์ยังไม่มี header `MinVersion:` (`grep -L MinVersion Sections/*/Scripts/*.sql` = 5/5 ขาด), Section 4 ยังไม่มี `Scripts/`, glossary กลางยังไม่มีไฟล์ (สไลด์เปิด section ทั้ง 4 อ้างล่วงหน้า), ภาพใหม่ 3 ชิ้นต้องวาด PNG ≥2400px (`git ls-files "*.png"` = มีเฉพาะ 2 ไฟล์ของ M1), heading เสีย `## ###` ที่ `Module_03_Database_Structures/README.md:60`
- แผนผัง layout ตามมาตรฐาน 4.3: `title`/`bullets`/`bullets+diagram`/`quiz`/`summary` → potx 03 Content (summary ท้ายโมดูลใช้ 08 Closing), `two-column` → 04, `section-divider` → 02, `demo`/`lab` → 06 Code Lab — ห้ามเกิด layout DEFAULT

---

### สไลด์ 1: ปกเด็ค — Module 3: Database Structures
- **Layout:** `title` (→ potx 01 Cover (dark))
- **Bullets:**
  - **Module 3: Database Structures** — โครงสร้างการจัดเก็บข้อมูล: Database Files, Pages & TempDB
  - จาก Page 8 KB ถึงการตั้งค่า TempDB — รากฐานของ Space Management และ Performance
  - 4 Sections + Lab 3 (4 Exercise) — SQL Server 2025 (17.x) + AdventureWorks2025
  - สอนวันที่ 1 ของหลักสูตร (ตามแผนที่โมดูลของ Course Guide)
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — ใช้ placeholder ของ layout 01 (ห้ามวาง textbox ลอยนอก master)
- **Speaker notes:** สไลด์เปิดเด็ค — วางกรอบว่าโมดูลนี้มองลง "ใต้ผิว" ของ database ไปถึงระดับ Page 8 KB ก่อนไปต่อ Memory ในโมดูลถัดไป `Ref: Module_03_Database_Structures/README.md`

### สไลด์ 2: Module Divider — Database Structures
- **Layout:** `section-divider` (→ potx 02 Module Divider (dark))
- **Bullets:**
  - Section 1 Structure Internals → Section 2 Data File Internals → Section 3 Transaction Log Internals → Section 4 TempDB Internals
  - **งบเวลาโมดูล ≈150 นาที** (ข้อเสนอจากสูตร 7.3 นาที/สไลด์ × 20 สไลด์ ≈ 146 นาที — ยังไม่มีตัวเลขในตารางสอน ต้องยืนยันกับเจ้าของหลักสูตร)
  - **Lab 3: Pages, VLF & TempDB Internals — 4 Exercise** (รันใน VM ผู้เรียนทุกคน)
  - Prerequisite แล็บ: `sysadmin` + AdventureWorks2025 + SSMS 2 หน้าต่าง query
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — จัด roadmap เป็น text list บน layout 02
- **Speaker notes:** พิมพ์งบเวลา + จำนวน Exercise ให้ผู้เรียนรู้งบก่อนเริ่ม — ระวัง: ตารางสอนรายชั่วโมง Day 1 (`Trainer_Docs/Course_Guide_4Days.md:71-81`) ยังไม่มีช่วงเวลาของบทที่ 3 แม้แผนที่โมดูล `:128` ระบุ M3 อยู่วันที่ 1 — ต้องยืนยันงบเวลาจริงกับเจ้าของหลักสูตรก่อนประกอบเด็ค `Ref: Trainer_Docs/Course_Guide_4Days.md:124-136`

### สไลด์ 3: Structure Internals — SQL Server อ่าน/เขียนเป็น Page ไม่ใช่ Row
- **Layout:** `title` (→ potx 03 Content — สไลด์เปิด Section 1)
- **Bullets:**
  - ทุก Row/Index สุดท้ายถูกเก็บใน **Page** ขนาด 8 KB (8,192 bytes คงที่) — หน่วยย่อยที่สุดของ Data File
  - **หลักการสำคัญ:** SQL Server อ่าน/เขียนเป็นหน่วย Page ไม่ใช่ Row — Query ที่อ่านหลาย Pages จึงช้ากว่าที่อ่านน้อย Pages
  - เส้นทางของ Section นี้: Page → Extent → Data File → Filegroup → Page Types → Allocation Maps แล้วจบด้วยการ "เปิดดู Page จริง" ด้วย DBCC PAGE
  - **ต้องรู้มาก่อน:** SELECT/JOIN พื้นฐาน + แนวคิด Buffer Pool คร่าว ๆ — ศัพท์ Page / Extent / IAM ดู Glossary กลาง (ไฟล์ยังต้องสร้างตามแผนเฟส 0)
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพในสไลด์นี้ (ภาพหลักอยู่สไลด์ถัดไป)
- **Speaker notes:** สไลด์แรกของ Section 1 — ทบทวนว่าทำไม Page 8 KB คือหน่วย I/O จริง ต้องรู้มาก่อน: SELECT/JOIN + ศัพท์ Page/Extent/IAM — ชี้ลิงก์ Glossary กลาง (`Trainer_Docs/Glossary.md` ยังไม่มีใน repo ต้องสร้างตามแผนเฟส 0) `Ref: Module_03_Database_Structures/Sections/01_Structure_Internals/README.md:5-7`

### สไลด์ 4: โครงสร้างลำดับชั้น: Page → Extent → Data File → Filegroup
- **Layout:** `bullets+diagram` (→ potx 03 Content)
- **Bullets:**
  - **Page (8 KB)** — หน่วยเก็บข้อมูลย่อยที่สุด
  - **Extent (64 KB = 8 Pages)** — *Uniform Extent* ทั้ง 8 pages เป็นของ Object เดียว (รูปแบบหลักปัจจุบัน) vs *Mixed Extent* แชร์หลาย Object (พบในเวอร์ชันเก่า)
  - **Data File (`.mdf` เสมอ 1 ไฟล์ / `.ndf` หลายไฟล์)** — หลายไฟล์ใน Filegroup เดียวช่วยกระจาย I/O ลด GAM/SGAM contention
  - **Filegroup** — หน่วย Admin/Performance Planning มี PRIMARY เสมอ แยก Data/Index ตามประเภทข้อมูลหรือ Storage Tier ได้
  - **Proportional Fill Algorithm** — เขียนลงไฟล์ตามสัดส่วน Free Space ไฟล์ไม่เท่ากัน = IO hotspot จึงต้อง **Equal File Size** เสมอ
- **ภาพ/แผนภาพ:** `page-extent-filegroup-hierarchy.png` — **ต้องวาดใหม่** PNG ≥2400px เก็บที่ `Module_03_Database_Structures/Sections/01_Structure_Internals/images/` (ยังไม่มีใน repo; ต้นแบบโครง = ASCII tree ที่ `01_Structure_Internals/README.md:17-45`, อ้างสไตล์ภาพต้นแบบ `engine-architecture.png` 2431×1373 ของ M1)
- **Speaker notes:** ใช้แผนภาพลำดับชั้นเป็นแกนเล่า ย้ำตัวเลข 8 KB / 64 KB / 8 Pages และที่มาของกฎ "ไฟล์เท่ากัน" จาก Proportional Fill `Ref: Module_03_Database_Structures/Sections/01_Structure_Internals/README.md:13-51, 94-99`

### สไลด์ 5: Page Types & Allocation Maps (GAM / SGAM / IAM / PFS)
- **Layout:** `bullets` (→ potx 03 Content; ตารางวางบน potx 05 Table ได้ — แทรก shape ยอมรับได้ตามแผน 4.3)
- **Bullets:**
  - Page 8,192 bytes = Header + Data + Row Offset — Page Types สำคัญ: **Data (1)** ข้อมูล leaf level / **Index (2)** โครง B-Tree / **Text-Image (3, 4)** LOB
  - **GAM** ติดตาม Extent ว่าง · **SGAM** ติดตาม Mixed Extent ที่ยังมีหน้าว่าง — ละ 64,000 extents (~4 GB)
  - **IAM** แผนที่ Extent ของแต่ละ Object · **PFS** ติดตาม Free Space ระดับ Page — ละ 8,088 pages (~64 MB)
  - PFS Byte บอกความแน่น 5 ระดับ / GAM bit (1 = Extent ว่าง) / SGAM bit — **SGAM คือจุดเกิด Latch Contention บ่อยสุดใน TempDB ยุคเก่า**
  - เกิน ~8,060 bytes ต่อแถว: **Row-Overflow** ย้ายส่วนเกินไป `ROW_OVERFLOW_DATA` vs **LOB** ย้ายไป `LOB_DATA` เหลือ Pointer 16–24 bytes ใน Data Page หลัก
- **ภาพ/แผนภาพ:** ตาราง Allocation Maps (จาก `01_Structure_Internals/README.md:85-90`) บน layout 05 Table; optional: `page-anatomy-allocation-maps.png` วาดใหม่ ≥2400px (ยังไม่มีใน repo)
- **Speaker notes:** ตาราง 4 แผนที่นี้จะกลับมาอีกครั้งตอนอธิบาย tempdb contention (สไลด์ 16) — ให้ผู้เรียนจำหน้าที่แบบ "ใครจดอะไร" `Ref: Module_03_Database_Structures/Sections/01_Structure_Internals/README.md:76-109`

### สไลด์ 6: Demo — เปิดดู Page จริง + GUID vs Sequential Key
- **Layout:** `demo` (→ potx 06 Code Lab)
- **Bullets:**
  - หา page แรกของ `Person.Person` ด้วย `sys.system_internals_allocation_units` → `DBCC TRACEON(3604)` → `DBCC PAGE(..., 3)` อ่าน Page Header (`m_type = 1`, `m_freeCnt`)
  - สร้าง `BadKeyTable` (NEWID()) คู่ `GoodKeyTable` (IDENTITY) insert จับเวลาด้วย `SET STATISTICS TIME`
  - เทียบ `avg_fragmentation_in_percent` / `page_count` ด้วย `sys.dm_db_index_physical_stats`
  - ผลที่คาดหวัง: BadKey fragmentation ~99% + page_count บวม / GoodKey < 1% (จากบล็อก "ผลที่คาดหวัง" ของแล็บ)
  - **error ที่พบได้:** "User does not have permission to run DBCC PAGE" — ต้อง `sysadmin` · **รุ่นขั้นต่ำ: SQL Server 2019+**
- **สคริปต์อ้างอิง:** `Module_03_Database_Structures/Sections/01_Structure_Internals/Scripts/01_Bad_vs_Good_Structure.sql` + `02_DBCC_PAGE_Analysis.sql` (Labs Exercise 1–2)
- **ภาพ/แผนภาพ:** screenshot ผล DBCC PAGE ใน SSMS — ถ่ายเองจากการรันจริงบน 17.x (ยังไม่มีใน repo)
- **Speaker notes:** ศัพท์ที่ต้องรู้ก่อน: DBCC = Database Console Commands, `TRACEON(3604)` ส่งผลลัพธ์ DBCC ออกทาง client, CTE/`GO n` พบในสคริปต์แล็บ — โค้ดบนสไลด์ต้อง pull จากสคริปต์จริง 2 ไฟล์ข้างต้น ซึ่งยังไม่มี header `MinVersion:` (ตรวจด้วย `grep -L MinVersion` = ขาด 5/5 ทั้งโมดูล) ต้องเติมก่อนขึ้นสไลด์ Code Lab `Ref: Module_03_Database_Structures/Labs/README.md:24-56, 60-126`

### สไลด์ 7: Data File Internals — ตั้งค่าไฟล์ให้ถูกตั้งแต่วันแรก
- **Layout:** `title` (→ potx 03 Content — สไลด์เปิด Section 2)
- **Bullets:**
  - **Volume Configuration:** RAID 10 สำหรับ Log Files (write-intensive) / RAID 5 หรือ 10 สำหรับ Data Files, Format ด้วย Allocation Unit Size **64 KB** ให้ตรงกับ Extent
  - **Isolation:** แยก Data Files และ Log Files คนละ Physical Disk ลด I/O contention
  - **IFI (Instant File Initialization)** — ข้ามขั้นตอน zero-filling ตอนจองพื้นที่: `CREATE DATABASE` / `RESTORE` / Autogrow เร็วขึ้น ต้องสิทธิ์ "Perform Volume Maintenance Tasks" ให้ service account
  - **Logical vs Physical I/O** — Logical อ่านจาก Buffer Pool เร็ว / Physical อ่านจาก Disk latency สูง — เป้าหมาย Buffer Cache Hit Ratio สูงเกือบ 100%
  - **ต้องรู้มาก่อน:** I/O Subsystem จาก Module 2 (IOPS / Latency / RAID) — ศัพท์ IFI / Autogrowth ดู Glossary กลาง (ยังต้องสร้าง)
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — จัด 3 หมวดเป็น text stack; ห้ามดึงภาพ RAID/ดิสก์จากเด็คเก่า (สิทธิ์ยังไม่มีคำตอบ)
- **Speaker notes:** สไลด์แรกของ Section 2 — เชื่อมจาก Module 2 สู่ระดับการตั้งค่าไฟล์ ต้องรู้มาก่อน: IOPS/Latency/RAID + ศัพท์ IFI — ชี้ลิงก์ Glossary กลาง (ยังไม่มีไฟล์) · **ต้องเขียนเนื้อหาเพิ่ม:** Section 2 README ยังเป็น outline 31 บรรทัด ต้องขยาย 3.1–3.4 ตาม DoD ก่อนถือว่า section จบ `Ref: Module_03_Database_Structures/Sections/02_Data_File_Internals/README.md:5-25`

### สไลด์ 8: Auto Grow vs Auto Shrink
- **Layout:** `two-column` (→ potx 04 Two-Column)
- **Bullets:**
  - ซ้าย **Auto Grow**: ใช้เป็น **Safety Net** เท่านั้น — pre-allocate ขนาดไฟล์ให้พอกับ workload ปกติ
  - ซ้าย: ตั้ง Fixed Size (MB) เช่น 64–256 MB — **ห้าม PERCENT** เพื่อไม่ให้ grow แต่ละครั้งนานเกินไป
  - ซ้าย: Log growth ต้องใหญ่พอให้ได้ VLF น้อย (โยง Section 3)
  - ขวา **Auto Shrink**: **Strongly Discouraged** — ทำให้เกิด Index Fragmentation ระดับสูง
  - ขวา: วงจร Shrink-then-Grow สิ้นเปลือง CPU และ I/O
  - ขวา: ทางแก้ที่ถูกคือจัดขนาดไฟล์ + จัดการ space ไม่ใช่ shrink
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — two-column ของ layout 04 พอ
- **Speaker notes:** ย้ำว่า FAQ ข้อ 3 ของโมดูลถามเรื่องนี้ตรง ๆ (ทำไมไม่ควรใช้ Auto Shrink) — ให้ผู้เรียนตอบได้ก่อนจบ section · **ต้องเขียนเนื้อหาเพิ่ม:** README 3.3 ยังสั้น 6 บรรทัด ต้องขยายเหตุผล/หลักฐาน (เช่น fragmentation ก่อน–หลัง shrink) ตาม DoD `Ref: Module_03_Database_Structures/Sections/02_Data_File_Internals/README.md:15-20, Module_03_Database_Structures/README.md:50-52`

### สไลด์ 9: Demo — ตรวจ IFI และทบทวน File Sizes/Growth ทั้ง Instance
- **Layout:** `demo` (→ potx 06 Code Lab)
- **Bullets:**
  - ตรวจ IFI: ดู service account จาก `sys.dm_server_services` + เช็คสิทธิ์ "Perform volume maintenance tasks" ใน Local Security Policy
  - ทบทวนขนาด/growth ทุก database ด้วย `sys.master_files` (แบบ Glenn Berry Diagnostic Queries) — ไฟล์ที่ `is_percent_growth = 1` คือ flag แดง
  - สร้าง config script ให้ TempDB ตามจำนวน CPU (PART 2 ของสคริปต์ — **อ่านก่อนรัน ห้าม execute โดยไม่ดู**)
  - **error ที่พบได้:** "VIEW SERVER STATE permission denied" ถ้าไม่มีสิทธิ์ · **รุ่นขั้นต่ำ: SQL Server 2019+** (2022+: log autogrow ≤ 64 MB ได้ประโยชน์จาก IFI ด้วย)
- **สคริปต์อ้างอิง:** `Module_03_Database_Structures/Sections/02_Data_File_Internals/Scripts/03_IFI_and_TempDB_Config.sql` + `04_Database_File_Sizes.sql`
- **ภาพ/แผนภาพ:** screenshot ผล query จากสคริปต์ 04 — ถ่ายเองจากการรันจริงบน 17.x (ยังไม่มีใน repo)
- **Speaker notes:** ศัพท์ที่ต้องรู้ก่อน: `sys.master_files` = catalog view ของไฟล์ database ทั้ง instance, IFI = Instant File Initialization (ข้ามการเขียน zero ตอนสร้าง/grow ไฟล์) — สคริปต์ทั้งสองไฟล์ยังไม่มี header `MinVersion:` ต้องเติมก่อนขึ้นสไลด์ `Ref: Module_03_Database_Structures/Sections/02_Data_File_Internals/Scripts/03_IFI_and_TempDB_Config.sql, 04_Database_File_Sizes.sql; Module_03_Database_Structures/README.md:71`

### สไลด์ 10: ตรวจความเข้าใจ — Data File Internals
- **Layout:** `quiz` (→ potx 03 Content)
- **Bullets (คำถาม):**
  - ทำไมไม่ควรใช้ Auto Shrink? (Index Fragmentation สูง + วงจร Shrink-then-Grow กิน CPU/I/O)
  - IFI ต้องขอสิทธิ์อะไรให้ SQL Server Service Account และช่วยเร่งคำสั่งใดบ้าง?
  - Growth ควรตั้งเป็น MB หรือ PERCENT เพราะอะไร?
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ
- **Speaker notes:** ให้ผู้เรียนตอบก่อนเฉลยจาก README 3.3–3.4 · **ต้องเขียนเนื้อหาเพิ่ม:** quiz bank รายโมดูลยังไม่มีใน repo (แผนเฟส 3) — คำถามชุดนี้ร่างจาก FAQ ของ module README ต้องย้ายเข้า quiz bank พร้อมเฉลย `Ref: Module_03_Database_Structures/README.md:50-52, Sections/02_Data_File_Internals/README.md:15-25`

### สไลด์ 11: Transaction Log Internals — VLF และราคาของ Autogrowth
- **Layout:** `bullets+diagram` (→ potx 03 Content — สไลด์เปิด Section 3)
- **Bullets:**
  - Transaction Log (`.ldf`) ถูกแบ่งโครงสร้างภายในเป็น **Virtual Log Files (VLF)** — หน่วยบริหารของ log
  - **High VLF Count** เกิดจาก Auto-growth ขนาดเล็กเกินไป (เช่น 1 MB) → Fragmented Log
  - **Impact:** Database Startup / Restore / Replication ทำงานช้าลง
  - **Best Practice:** Pre-allocate Log File + Auto-growth เป็นก้อนใหญ่ (เช่น 4 GB หรือ 8 GB) — ตรวจด้วย `sys.dm_db_log_info` (แทน `DBCC LOGINFO`)
  - **ต้องรู้มาก่อน:** แนวคิด autogrowth จาก Section 2 — ศัพท์ VLF / Log Truncation ดู Glossary กลาง (ยังต้องสร้าง)
- **ภาพ/แผนภาพ:** `vlf-structure.png` — **ต้องวาดใหม่** PNG ≥2400px ที่ `Module_03_Database_Structures/Sections/03_Transaction_Log_Internals/images/` (ยังไม่มีใน repo): แถบ log file ตัดเป็น VLF เล็กจำนวนมาก เทียบกับ VLF ใหญ่จำนวนน้อย + ช่วง active/inactive
- **Speaker notes:** สไลด์แรกของ Section 3 — ต้องรู้มาก่อน: autogrowth (Section 2) + ศัพท์ VLF ชี้ลิงก์ Glossary · **ต้องเขียนเนื้อหาเพิ่ม:** README 5.1 ครอบแค่ VLF ต้องเขียนเพิ่มเรื่อง Log Truncation / Checkpoint เพื่อให้เห็นว่า log วนใช้พื้นที่อย่างไร `Ref: Module_03_Database_Structures/Sections/03_Transaction_Log_Internals/README.md:5-9, Module_03_Database_Structures/README.md:70`

### สไลด์ 12: Ghost Cleanup Process
- **Layout:** `bullets` (→ potx 03 Content)
- **Bullets:**
  - **Ghost Records** = Data Row ที่ถูก DELETE แล้วแต่ยังไม่ถูกลบออกจาก Page จริง — เปลี่ยน bit ใน Row Header แทนการลบทันที
  - ทำไมต้องมี Ghost: เพิ่มประสิทธิภาพ DELETE + รองรับ Row-level Locking / Snapshot Isolation
  - **Ghost Cleanup Task** = background process รันเป็นระยะเก็บ Ghost Records ออกจาก Pages
  - ตรวจนับได้ด้วย `ghost_record_count` จาก `sys.dm_db_index_physical_stats` (โค้ดมีใน README แล้ว)
  - **Trace Flag 661** ปิด Ghost Cleanup ได้แต่**ไม่แนะนำ**: ไฟล์โตเรื่อย ๆ (space ไม่ถูก reclaim), page splits เพิ่มขึ้น, ต้องพึ่ง Index Rebuild แทน
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — ใช้ flow ข้อความ DELETE → ghost bit → cleanup task (เพิ่มภาพภายหลักเมื่อขยาย README)
- **Speaker notes:** อ่านโค้ดตรวจนับ ghost ตามสไลด์ได้ทันทีเพราะมีใน README · **ต้องเขียนเนื้อหาเพิ่ม:** ขยาย 5.2 ตาม DoD เช่น ผลต่อ space reclaim และความสัมพันธ์กับ version store ที่โยงไป Section 4 `Ref: Module_03_Database_Structures/Sections/03_Transaction_Log_Internals/README.md:11-33`

### สไลด์ 13: Demo — VLF Analysis: นับ VLF และแก้ Log Bloat
- **Layout:** `demo` (→ potx 06 Code Lab)
- **Bullets:**
  - นับ VLF ทุก database ด้วย `sys.dm_db_log_info` JOIN `sys.master_files` — สคริปต์มี threshold ในตัว: >1000 Critical / >500 Warning / >100 Moderate
  - จำลอง VLF ระเบิด (VM ทดสอบเท่านั้น): `FILEGROWTH = 1 MB` แล้วทำ transaction เขียน log หลายรอบ แล้วตรวจซ้ำเทียบจำนวน VLF
  - แก้กลับสู่ค่าที่ดี: `FILEGROWTH = 256 MB` (MB ไม่ใช่ PERCENT) — ลด VLF จริงจังด้วย `DBCC SHRINKFILE` + grow ก้อนใหญ่ครั้งเดียว
  - **error ที่พบได้:** `sys.dm_db_log_info` ไม่มีบนรุ่นเก่า — ต้อง **SQL Server 2016 SP2+** (รุ่นเก่าใช้ `DBCC LOGINFO`) · ห้าม shrink log บน production ระหว่างชั่วโมงทำงาน
- **สคริปต์อ้างอิง:** `Module_03_Database_Structures/Sections/03_Transaction_Log_Internals/Scripts/05_VLF_Analysis.sql` (Labs Exercise 3)
- **ภาพ/แผนภาพ:** screenshot ผล VLF count พร้อมสถานะ Critical/Warning — ถ่ายเองจากการรันจริงบน 17.x (ยังไม่มีใน repo)
- **Speaker notes:** ศัพท์ที่ต้องรู้ก่อน: `sys.dm_db_log_info` = DMV แสดง VLF ทั้ง log file (ต้อง 2016 SP2+), `DBCC SHRINKFILE` = คำสั่งหดขนาดไฟล์ — สคริปต์ 05 ยังไม่มี header `MinVersion:` ต้องเติมก่อนขึ้นสไลด์ `Ref: Module_03_Database_Structures/Labs/README.md:149-189, Sections/03_Transaction_Log_Internals/Scripts/05_VLF_Analysis.sql`

### สไลด์ 14: ตรวจความเข้าใจ — Transaction Log Internals
- **Layout:** `quiz` (→ potx 03 Content)
- **Bullets (คำถาม):**
  - ทำไมไม่ควรมี VLF จำนวนมาก? (Startup / Restore / Replication ช้าลง)
  - VLF เยอะผิดปกติเกิดจากการตั้งค่าอะไร? (Auto-growth ขนาดเล็ก)
  - Trace Flag 661 ทำอะไร และทำไมจึงไม่แนะนำ?
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ
- **Speaker notes:** เฉลยจาก README 5.1–5.2 · **ต้องเขียนเนื้อหาเพิ่ม:** quiz bank ยังไม่มี — คำถามข้อ 1–2 ร่างจาก FAQ ของ module README ข้อ 1, ข้อ 3 จาก README 5.2 ต้องย้ายเข้า quiz bank พร้อมเฉลย `Ref: Module_03_Database_Structures/README.md:40-42, Sections/03_Transaction_Log_Internals/README.md:5-33`

### สไลด์ 15: TempDB Internals — Global Resource ที่ทุก Session แชร์
- **Layout:** `title` (→ potx 03 Content — สไลด์เปิด Section 4)
- **Bullets:**
  - TempDB = **Global Resource** ของทั้ง Instance — ทุก database/session ใช้ร่วมกัน และถูกสร้างใหม่ทุกครั้งที่ restart Database Engine
  - **User Objects:** Temporary tables (`#Local`, `##Global`) และ Table variables
  - **Internal Objects:** Workfiles/Worktables สำหรับ Sort / Hash operations
  - **Version Store:** เก็บ Row Versions สำหรับ Snapshot Isolation และ Online Index Build
  - **ต้องรู้มาก่อน:** Allocation Maps (GAM/SGAM/PFS) จาก Section 1 + wait statistics พื้นฐานจาก M1 — ศัพท์ PAGELATCH / Version Store ดู Glossary กลาง (ยังต้องสร้าง)
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — จัด 3 ประเภท object เป็น text grouping
- **Speaker notes:** สไลด์แรกของ Section 4 — ต้องรู้มาก่อน: GAM/SGAM/PFS (สไลด์ 5) + waits เบื้องต้น (M1) ศัพท์ PAGELATCH/Version Store ชี้ลิงก์ Glossary กลาง (ยังไม่มีไฟล์) · **ต้องเขียนเนื้อหาเพิ่ม:** README 4.1 มีแค่ 4 บรรทัด ต้องขยายเช่น tempdb rebuild ตอน startup และการวางแผนขนาด `Ref: Module_03_Database_Structures/Sections/04_TempDB_Internals/README.md:5-9`

### สไลด์ 16: TempDB Contention — PAGELATCH บน PFS / GAM / SGAM
- **Layout:** `bullets+diagram` (→ potx 03 Content)
- **Bullets:**
  - หลาย Session สร้าง Temp Table พร้อมกัน → SQL Server ต้องอัปเดต Allocation Pages เดียวกัน → เกิดการ "แย่งกันเขียน" หน้าเดียว
  - **Latch** = กลไก lock ภายในที่ปกป้อง Data Page ขณะอ่าน/เขียนใน Memory — ต้องรอ Latch จึงเกิด Wait Type `PAGELATCH_EX` / `PAGELATCH_UP` (ต่างจาก `PAGEIOLATCH_*` ที่รอ Disk)
  - จุดเกิดใน TempDB: **PFS / GAM / SGAM Pages** (Allocation Bitmaps) — dbid 2
  - วินิจฉัย: `sys.dm_os_wait_stats` กรอง `PAGE%LATCH%` + `sys.dm_exec_requests` ดู `wait_resource LIKE '2:%'`
  - วิธีแก้: Multiple Data Files (เริ่ม ≈ logical cores แต่ ≤ 8 ไฟล์) ขนาด/Auto-growth เท่ากันทุกไฟล์ (ให้ Proportional Fill สมดุล) + Memory-Optimized TempDB Metadata (2019+)
- **ภาพ/แผนภาพ:** `tempdb-contention-pagelatch.png` — **ต้องวาดใหม่** PNG ≥2400px ที่ `Module_03_Database_Structures/Sections/04_TempDB_Internals/images/` (ยังไม่มีใน repo): เส้นจากหลาย session ชนกันที่ PFS/GAM/SGAM เดียว → queue `PAGELATCH_EX` เทียบกับภาพแยกหลายไฟล์แล้วกระจาย
- **Speaker notes:** สไลด์นี้คือหัวใจของ Lab Exercise 4 — ให้ผู้เรียนเห็นสายเดียวกันจาก Section 1 (allocation maps) → อาการ (waits) → ทางแก้ (ไฟล์เท่ากัน) `Ref: Module_03_Database_Structures/Sections/04_TempDB_Internals/README.md:11-23, Labs/README.md:193-247`

### สไลด์ 17: TempDB บน SQL Server 2025
- **Layout:** `bullets` (→ potx 03 Content)
- **Bullets:**
  - **ADR ใน tempdb (ใหม่ 2025):** `ALTER DATABASE tempdb SET ACCELERATED_DATABASE_RECOVERY = ON;` → Instantaneous rollback ของ temp table/table variable + Aggressive log truncation (ต้อง **restart Database Engine** หลังเปิด)
  - **TempDB Space Resource Governance (2025):** Resource Governor จำกัดพื้นที่ tempdb ต่อ workload group ป้องกัน runaway query — ตอนนี้อยู่ใน **Standard edition** แล้ว
  - **Memory-Optimized TempDB Metadata (2019+, opt-in):** ยังแนะนำเปิด — ลด metadata contention บน workload หลายพัน temp table ต่อวินาที
  - **tmpfs สำหรับ tempdb บน Linux (2025):** วาง tempdb บน memory filesystem ได้
  - Best Practice จาก Microsoft Learn: IFI + preallocate · หลาย data file ขนาด/autogrowth เท่ากัน (เริ่ม ≤ 8 ไฟล์ เพิ่มทีละกลุ่ม 4) · autogrowth เป็น MB 64–256 ไม่ใช้ PERCENT
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — text bullets (ห้ามใช้ layout 07 Stat Callout เพราะยังไม่มีตัวเลข sign-off รันจริง 17.x)
- **Speaker notes:** เนื้อหาชุดนี้อยู่ท้าย module README หัวข้อ 8.1–8.3 ซึ่งมี heading เสีย `## ###` ที่บรรทัด 60 — ต้องแก้ heading ก่อนตามแผนเฟส 0 · **ต้องเขียนเนื้อหาเพิ่ม:** ย้าย/ขยายเนื้อหา 8.1–8.3 ลงใน section 4 README ให้เป็นเนื้อหาปกติของ section `Ref: Module_03_Database_Structures/README.md:60-76, Trainer_Docs/Course_Guide_4Days.md:54`

### สไลด์ 18: ตรวจความเข้าใจ — TempDB Internals
- **Layout:** `quiz` (→ potx 03 Content)
- **Bullets (คำถาม):**
  - จำนวน TempDB Data Files ที่แนะนำเบื้องต้นคือเท่าไร และมีเงื่อนไขอะไร? (≈ CPU core ไม่เกิน 8 ไฟล์ ขนาดเท่ากันทุกไฟล์)
  - `PAGELATCH_EX` ต่างจาก `PAGEIOLATCH_EX` อย่างไร?
  - เปิด ADR ใน tempdb บน SQL Server 2025 แล้วต้องทำอะไรต่อ? (restart Database Engine)
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ
- **Speaker notes:** เฉลยจาก README 4.2 + module README 8.1 · **ต้องเขียนเนื้อหาเพิ่ม:** quiz bank ยังไม่มี — คำถามข้อ 1 ร่างจาก FAQ ของ module README ข้อ 2 อีกสองข้อเพิ่มใหม่ ต้องย้ายเข้า quiz bank พร้อมเฉลย `Ref: Module_03_Database_Structures/README.md:45-47, 60-64, Sections/04_TempDB_Internals/README.md:11-23`

### สไลด์ 19: Lab 3 — Pages, VLF & TempDB Internals (4 Exercise)
- **Layout:** `lab` (→ potx 06 Code Lab)
- **Bullets:**
  - **Exercise 1 — DBCC PAGE:** ดู Page จริงของ `Person.Person` (Page Header `m_type`/`m_freeCnt` + allocation units)
  - **Exercise 2 — Random GUID vs Sequential Key:** เทียบ fragmentation/page_count + จับ page split แบบ real-time ด้วย Extended Events
  - **Exercise 3 — VLF:** นับด้วย `sys.dm_db_log_info` ทำ VLF ระเบิด (FILEGROWTH 1 MB) แล้วแก้กลับ 256 MB
  - **Exercise 4 — TempDB:** ตรวจค่า → จำลอง contention จากหลายหน้าต่าง → เพิ่ม data files ขนาดเท่ากัน (+ Optional: ตรวจ IFI / พิจารณา ADR ใน tempdb บน 2025)
  - Prerequisite: `sysadmin` (จำเป็นสำหรับ `DBCC PAGE` / `DBCC TRACEON(3604)` / ALTER tempdb) + AdventureWorks2025 + SSMS 2 หน้าต่าง
  - **error ที่พบได้ + รุ่นขั้นต่ำ:** "User does not have permission to run DBCC PAGE" ถ้าไม่ใช่ `sysadmin` · `sys.dm_db_log_info` ไม่มีบนรุ่นเก่า — ต้อง **SQL Server 2016 SP2+** (รุ่นเก่าใช้ `DBCC LOGINFO`) · แล็บใช้ได้ **SQL Server 2019+** (แนะนำ 2025/17.x) — Optional ADR ใน tempdb ต้องมี **17.x** เท่านั้น · จำลอง VLF ระเบิด / จำลอง tempdb contention / แก้ tempdb ทำบน VM ทดสอบเท่านั้น (ห้าม Production)
  - Wrap-up 3 คำถามท้ายแล็บ + Cleanup ปลายไฟล์ (`DROP TABLE BadKeyTable, GoodKeyTable, LogBloat`)
- **สคริปต์อ้างอิง:** `Sections/01_Structure_Internals/Scripts/01_Bad_vs_Good_Structure.sql`, `02_DBCC_PAGE_Analysis.sql` · `Sections/02_Data_File_Internals/Scripts/03_IFI_and_TempDB_Config.sql`, `04_Database_File_Sizes.sql` · `Sections/03_Transaction_Log_Internals/Scripts/05_VLF_Analysis.sql` — Section 4 ยังไม่มี `Scripts/` ของตัวเอง
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — ใช้ layout 06 เป็นสไลด์กำกับแล็บ
- **Speaker notes:** พิมพ์จำนวน Exercise (4) ให้ผู้สอนรู้ล่วงหน้าว่าต้องรันกี่จุด · **งาน normalize:** แล็บมีบล็อก "ผลที่คาดหวัง" เพียง 1 จุด (บรรทัด 110) ต้องทำเป็นรูปแบบ `**Expected:**` ครบ 4/4 Exercise ตามแผนเฟส 0 และต้องเพิ่ม `Scripts/` ให้ Section 4 อีก 1 จุดตามช่องว่าง M3 `Ref: Module_03_Database_Structures/Labs/README.md:24-282`

### สไลด์ 20: สรุปโมดูล 3 — Database Structures
- **Layout:** `summary` (→ potx 08 Closing (dark))
- **Bullets:**
  - SQL Server อ่าน/เขียนเป็น **Page 8 KB** — โครงสร้าง Page/Extent/File/Filegroup คือเหตุผลเบื้องหลังกฎ "ไฟล์เท่ากัน"
  - ตั้งค่าไฟล์ตั้งแต่วันแรก: pre-allocate + growth เป็น MB + เปิด IFI + **ห้าม Auto Shrink**
  - Log bloat มาจาก autogrowth เล็ก → **VLF เยอะ** — ตรวจด้วย `sys.dm_db_log_info`
  - TempDB คือ global resource: หลายไฟล์ขนาดเท่ากัน ≤ 8 ไฟล์ + ดู `PAGELATCH` บน allocation bitmaps (+ ฟีเจอร์ 2025: ADR ใน tempdb, space governance)
  - ต่อไป: Module 4 Memory — ต่อเนื่องจาก Logical vs Physical I/O ที่เห็นใน Section 2
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — ใช้ layout 08 Closing (dark)
- **Speaker notes:** สรุป 4 ประเด็นโยงกลับไปที่แผนภาพลำดับชั้นในสไลด์ 4 แล้วส่งมอบต่อ Module 4 (Buffer Pool) — ให้ผู้เรียนลองตอบ wrap-up 3 คำถามของแล็บอีกครั้ง `Ref: Module_03_Database_Structures/Labs/README.md:264-268, Sections/02_Data_File_Internals/README.md:22-25`
