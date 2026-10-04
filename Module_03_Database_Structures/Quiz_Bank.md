# Quiz Bank — บทที่ 3: Database Structures (Pages, Extents, Allocation Maps, VLF & TempDB)

> ครอบคลุมวัตถุประสงค์การเรียนรู้ของบทที่ 3 ตาม [Course_Guide_4Days.md](../Trainer_Docs/Course_Guide_4Days.md): Page/Extent/Allocation Maps (GAM/SGAM/IAM/PFS), Data File Internals (Layout, Auto-grow, IFI), Transaction Log Internals (VLF, Log Truncation, Ghost Records) และ TempDB Internals (DBCC PAGE, sys.dm_db_log_info, TempDB Contention + ADR/Space Governance 2025) — ใช้คู่กับ [Sections](README.md) และ [Labs](Labs/README.md)
> **รูปแบบ:** ข้อ 1–12 multiple choice · ข้อ 13–20 ตอบสั้น · เฉลยพร้อมคำอธิบายอยู่ท้ายไฟล์ (อย่าเลื่อนดูก่อนตอบ!)

---

## ส่วนที่ 1: Multiple Choice

### Q1. เรียงลำดับโครงสร้างการจัดเก็บจากเล็กไปใหญ่ให้ถูกต้อง
- A. Extent → Page → Data File → Filegroup
- B. Page → Extent → Data File → Filegroup
- C. Page → Data File → Extent → Filegroup
- D. Extent → Page → Filegroup → Data File

### Q2. Allocation Map ใด "บอกว่า Page แต่ละหน้ายังมีที่ว่างเท่าไร" และครอบคลุมกี่ page ต่อแผนที่หนึ่ง?
- A. GAM — 64,000 extents (~4 GB)
- B. IAM — ต่อ object เดียว
- C. PFS — 8,088 pages (~64 MB)
- D. SGAM — 64,000 extents (~4 GB)

### Q3. บน SQL Server 2025 คุณต้องการหา "page แรก" ของตาราง `Person.Person` เพื่อไป dump ด้วย `DBCC PAGE` — วิธีใดถูกต้องตามที่รันจริงพิสูจน์แล้ว?
- A. ดึงคอลัมน์ `allocated_page_page_id` จาก `sys.system_internals_allocation_units` เหมือนยุคเก่า
- B. ใช้ `sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('Person.Person'), 1, NULL, 'DETAILED')` แล้วกรอง `page_type_desc = 'DATA_PAGE'`
- C. ใช้ `DBCC IND` ซึ่ง Microsoft ประกาศรองรับอย่างเป็นทางการบน 2025
- D. อ่านจาก `sys.dm_os_buffer_descriptors` แล้วเลือก page_id ต่ำสุดของ database

### Q4. แล็บ insert ทีละแถว 3,000 แถวแล้วได้: `BadKeyTable` (GUID) frag **98.5%**, 132 pages, space_used 67.1% ส่วน `GoodKeyTable` (IDENTITY) frag **1.2%**, 86 pages, space_used 97.8% — อธิบายเชิงกลไกที่ถูกต้องคือข้อใด?
- A. GUID เป็นชนิดข้อมูล 16 bytes จึงทำให้แถวใหญ่กว่า INT และอัด page ได้น้อยกว่า
- B. NEWID() สุ่มค่าใหม่ทุกครั้ง — insert ตกที่ "กลาง index" ตลอด ทำให้เกิด page split ต่อเนื่อง (page เก่าแตกเป็นสองหน้าซึ่งอัดได้เพียงครึ่ง) ส่วน IDENTITY append ท้าย index ตลอดจึงไม่ split
- C. `CHAR(200)` ไม่รองรับ clustered index ที่ key เป็น UNIQUEIDENTIFIER
- D. fragmentation เกิดจาก auto-grow ของไฟล์ ไม่เกี่ยวกับรูปแบบ key

### Q5. Page split จากการ insert กลาง index ส่งผลอย่างไรต่อ transaction log?
- A. ไม่กระทบ — log จดเฉพาะแถวที่ insert
- B. ทุก split ต้อง log ทั้งสองหน้าที่แตก (ไม่ใช่แค่แถวใหม่) — insert จำนวนมากที่ split ตลอดจึงบวม log และเพิ่ม I/O
- C. log ถูกข้ามเมื่อ page split เพราะเป็นการทำงานภายใน engine
- D. split เขียน log เฉพาะเมื่อ database อยู่ใน SIMPLE recovery

### Q6. Proportional Fill Algorithm คือเหตุผลเบื้องหลัง best practice ข้อใด?
- A. ตั้ง `FILEGROWTH` เป็น PERCENT เพื่อให้ไฟล์โตสมส่วนกับตัวเอง
- B. ไฟล์ข้อมูลใน filegroup เดียวกันต้องมีขนาด (และ autogrowth) เท่ากัน — ไม่งั้น SQL เขียนลงไฟล์ใหญ่หนักกว่า (ตามสัดส่วนพื้นที่ว่าง) จนเกิด hotspot
- C. ควรย้าย log ไปรวมกับ data เพื่อให้ fill เท่ากัน
- D. ตารางใหญ่ควรอยู่ใน PRIMARY filegroup เสมอ

### Q7. สาเหตุคลาสสิกของ "VLF จำนวนมาก" และผลกระทบที่สำคัญที่สุดคือข้อใด?
- A. จากการ backup log ถี่เกินไป — กระทบ performance ของ SELECT
- B. จาก autogrowth ของ log ทีละน้อย (เช่น 1 MB) ซ้ำ ๆ หลายพันรอบ — กระทบ Database Startup / Restore / Replication / AG seed ที่ต้องไล่ VLF ทีละก้อน
- C. จาก IFI ที่เปิดใช้ — ทำให้ VLF ตัดกันเอง
- D. จากการเปิด RCSI — version store กิน VLF ทั้งหมด

### Q8. การตั้ง `FILEGROWTH` ที่ถูกต้องสำหรับ transaction log บน SQL Server 2022+ คือข้อใด?
- A. PERCENT 10% เสมอ เพราะโตตามขนาดไฟล์อัตโนมัติ
- B. เป็น MB ที่เหมาะสม (เช่น 64–256 MB หรือใหญ่กว่าตาม workload) — และตั้งแต่ 2022 growth ของ log ที่ไม่เกิน ~64 MB ก็ได้ประโยชน์จาก IFI ด้วย
- C. ปิด autogrowth เสมอ เพื่อกัน log บวม
- D. PERCENT 25% เฉพาะ SIMPLE recovery

### Q9. ข้อใดตรงตามแนวทาง Microsoft ปัจจุบันเรื่องจำนวน tempdb data files?
- A. 1 ไฟล์เดียวเสมอ เพราะ tempdb อยู่ใน RAM
- B. เริ่มเท่ากับจำนวน logical cores แต่ไม่เกิน 8 ไฟล์ — ถ้ายังมี contention ค่อยเพิ่มทีละกลุ่ม 4 — ทุกไฟล์ขนาดเท่ากันและ growth เป็น MB เท่ากัน
- C. เท่ากับจำนวน user databases ต่อ instance
- D. มากเท่าที่ disk รับได้ โดยไม่ต้องเท่ากัน เพราะ tempdb ใช้ proportional fill

### Q10. ระหว่างจำลอง tempdb contention คุณเห็น session ค้างด้วย `PAGELATCH_EX` และ `wait_resource = '2:1:1'` — การตีความและวิธีแก้ที่ถูกคือข้อใด?
- A. รอ lock ระดับ table ใน tempdb — แก้ด้วย isolation level สูงขึ้น
- B. รอ latch บน allocation bitmap (PFS/GAM/SGAM) ของ database id 2 (tempdb) — แก้ด้วยการเพิ่ม tempdb data files ขนาดเท่ากัน เพื่อกระจาย allocation pages (และบน 2025 พิจารณา ADR ใน tempdb + space governance ด้วย Resource Governor)
- C. รออ่าน data page จาก disk ใน tempdb — แก้ด้วยเปลี่ยน storage เป็น NVMe ก็พอ
- D. รอ memory grant — แก้ด้วยเพิ่ม max server memory

### Q11. คุณเปิด Instant File Initialization (IFI) ให้ service account แล้ว คำสั่งใดตรวจสถานะได้จากฝั่ง engine และข้อใดตรงกับขอบเขตของ IFI บน SQL Server 2022+?
- A. `sys.dm_server_services.instant_file_initialization_enabled` — IFI ช่วย data file autogrow/CREATE/RESTORE และ **ช่วย log autogrow ได้เฉพาะขนาด ≤ 64 MB**
- B. `sys.databases.is_read_committed_snapshot_on` — IFI ช่วยทุกไฟล์รวม log ขนาดใหญ่
- C. `DBCC SHOWFILESTATS` — IFI ช่วยเฉพาะตอน CREATE DATABASE เท่านั้น
- D. `sys.master_files.size` — IFI ต้อง restart engine ทุกครั้งหลังเปิดสิทธิ์

### Q12. บน SQL Server 2025 คุณต้องการห้าม workload กลุ่ม "reports" กิน tempdb เกิน 10 GB เพื่อไม่ให้ลากทั้ง instance — วิธีที่ถูกต้องคือข้อใด?
- A. ตั้ง `max server memory` ต่ำลง — tempdb จะถูกจำกัดตาม memory
- B. ใช้ TempDB Space Resource Governance: `ALTER WORKLOAD GROUP [reports] SET (GROUP_MAX_TEMPDB_DATA_MB = 10240);` แล้ว `ALTER RESOURCE GOVERNOR RECONFIGURE;` (ทำได้ตั้งแต่ 2025 รวมถึงบน Standard Edition)
- C. ตั้ง `max_size` ของ tempdb data file เท่ากับ 10 GB — query ที่เกินจะถูก kill อัตโนมัติเฉพาะ session ผู้กระทำ
- D. เปิด ADR ใน tempdb — ADR จะ rollback query ที่กินพื้นที่เกินโควตา

---

## ส่วนที่ 2: ตอบสั้น

### Q13. เขียนขั้นตอน (พร้อมคำสั่ง) เพื่อ dump เนื้อใน data page ของตารางหนึ่ง แล้วบอกว่าหมายเลข `1:736` อ่านว่าอย่างไร และจาก Page Header ค่า `m_type = 1`, `m_slotCnt = 5`, `m_freeCnt = 1162` ตีความได้ว่าอะไรบ้าง?

### Q14. เพราะเหตุใดจึง "ห้ามใช้ Auto Shrink" เป็นค่าตั้งประจำ — อธิบายวงจรที่ทำให้ระบบแย่ลงทั้งสองฝั่ง (fragmentation + I/O)

### Q15. จากแล็บจริง: ตรวจ `sys.dm_db_log_info` พบ log ของ AdventureWorks รวม ~136 MB มีเพียง **6 VLFs** แต่ขนาดคละกัน — มีทั้งก้อน 64 MB และก้อนละ ~1.9–2.2 MB — จากร่องรอยนี้อนุมานประวัติการตั้งค่าได้อย่างไร และถ้าจะ "รีเซ็ต VLF จริงจัง" ต้องทำอย่างไร (และควรทำช่วงไหน)?

### Q16. Mixed Extent กับ Uniform Extent ต่างกันอย่างไร แผนที่ใดติดตาม mixed extent ที่ยังมีหน้าว่าง และเพราะอะไร bitmap ตัวนี้จึงเคยเป็นจุด PAGELATCH contention อันดับหนึ่งของ tempdb ยุคเก่า?

### Q17. แล็บจริง: loop สร้าง/ลบ temp table 20,000 รอบ "หนึ่งหน้าต่างเดียว" แล้ว polling 45 วินาที **ไม่เจอ** `PAGE%LATCH` บน `wait_resource '2:%'` เลย และ `PAGELATCH_EX` สะสมทั้ง instance = 40,456 ครั้ง / 590 ms (~0.01 ms ต่อครั้ง) — อธิบายว่าทำไมผลนี้จึง "ถูกต้องตามธรรมชาติ" และจะออกแบบเดโมให้ contention โผล่จริงต้องปรับอะไร


### Q18. คุณรันสาธิตวงจร log truncation บน database SIMPLE recovery แล้วได้ผลตามลำดับ: ก่อนเริ่ม `used_pct = 39.6` → เปิด transaction + INSERT 20,000 แถว + รัน CHECKPOINT ได้ `log_reuse_wait_desc = ACTIVE_TRANSACTION`, `used_pct = 43.7` → COMMIT + CHECKPOINT ได้ `NOTHING`, `used_pct = 42.0` — อธิบายทั้งสามขั้นว่าเกิดอะไรขึ้น (รวมเหตุที่ CHECKPOINT กลาง tran ไม่ช่วย และเหตุที่ % ไม่กลับลงเป๊ะเดิม)

### Q19. เพื่อนเขียนสคริปต์ตรวจไฟล์ด้วย `SELECT size * 8 / 1024 ... FROM sys.master_files` แล้วพบ error `Arithmetic overflow error converting expression to data type int` บนบางแถว — สาเหตุคืออะไร คอลัมน์ `size`, `growth`, `max_size` ใช้หน่วยอะไรใน DMV นี้ และสคริปต์ที่ถูกต้องควรเขียนอย่างไร

### Q20. หลังรัน `DELETE ... WHERE Id % 2 = 0` (ลบ 1,500 จาก 3,000 แถว) แล้วสำรวจทันทีพบ `has_ghost_records = 29 จาก 29 data pages` แต่ `ghost_record_count` ใน `sys.dm_db_index_physical_stats` กลับเป็น 0 — Ghost Record คืออะไร ทำไม engine ไม่ลบออกจากหน้าทันที และเกณฑ์ใดทำให้สองค่านี้ไม่ตรงกัน

---

## เฉลยพร้อมคำอธิบาย

<details>
<summary><b>เฉลย Q1</b> — B</summary>

**Page (8 KB = 8,192 bytes)** คือหน่วยย่อยที่สุด → จัดกลุ่มเป็น **Extent (64 KB = 8 pages)** → อยู่ใน **Data File (.mdf/.ndf)** → ถูกรวมเป็น **Filegroup** การเข้าใจลำดับนี้สำคัญเพราะ SQL อ่าน/เขียนเป็น "หน่วย Page" ไม่ใช่ Row — อ่านต่อ: [Section 3.1 — Structure Internals](Sections/01_Structure_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q2</b> — C</summary>

**PFS (Page Free Space)** ใช้ 1 byte ต่อ 1 page บอกความแน่น 5 ระดับ ครอบคลุม 8,088 pages (~64 MB) — ส่วน GAM/SGAM ครอบคลุม 64,000 extents (~4 GB) และ IAM เป็นแผนที่ "object นี้ใช้ extent ไหน" (per object) จำแบบคู่กัน: **PFS = หน้าเต็มไหน / GAM = extent ว่างไหน / SGAM = mixed extent ที่ยังว่าง / IAM = ของ object** — อ่านต่อ: [Section 3.1 — Allocation Maps](Sections/01_Structure_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q3</b> — B</summary>

ตรวจจริงบน SQL Server 2025: แบบเก่าที่ดึง `allocated_page_page_id` จาก `sys.system_internals_allocation_units` **error `Invalid column name`** (คอลัมน์ถูกถอด) — ทางปัจจุบันคือ DMF `sys.dm_db_database_page_allocations(...)` กรอง `is_allocated = 1 AND page_type_desc = 'DATA_PAGE'` (แล็บจริงได้ 1:736) ข้อ D ผิดเพราะ buffer descriptors เห็นเฉพาะ page ที่ "อยู่ใน cache ตอนนี้" ไม่ใช่โครงสร้างไฟล์ — อ่านต่อ: [Labs Ex1](Labs/README.md) + [SignOff ข้อค้นพบ 2](../Trainer_Docs/SignOff/AllLabs_SignOff.md)
</details>

<details>
<summary><b>เฉลย Q4</b> — B</summary>

ปัญหาไม่ใช่ขนาด type (A) แต่คือ **รูปแบบการ insert**: GUID สุ่มตำแหน่ง → แถวใหม่ต้องแทรกกลาง B-Tree ที่ตำแหน่งเรียงค่า ทำให้ page เดิม (เต็ม ~100%) ต้อง **แตกเป็นสองหน้าที่อัดได้ครึ่งหนึ่ง** ซ้ำตลอดเวลา → fragmentation สูง, page_count บวม, space_used ต่ำ (67.1%) — ฝั่ง IDENTITY เดินท้าย index เสมอ (ever-increasing) จึง append ไม่ split (frag 1.2%, space_used 97.8%) — อ่านต่อ: [Module 6 — Index Internals](../Module_06_Statistics_Index_Internals/Sections/02_Index_Internals/README.md) + [Labs Ex2](Labs/README.md) + [Section 3.1 หัวข้อ 4](Sections/01_Structure_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q5</b> — B</summary>

Transaction log บันทึกการแก้ไขทางกายภาพ — เมื่อ page split ข้อมูลที่ถูก "ย้าย" ข้ามหน้าก็ต้องเขียน log ด้วย จึงใช้ log **มากกว่าขนาดแถวที่ insert** หลายเท่าในรอบ split — นี่คือเหตุที่ Random GUID ทำให้ log โตเร็วควบคู่กับ fragmentation (คำถามท้ายแล็บข้อ 1) — อ่านต่อ: [Section 3.3 — Transaction Log Internals](Sections/03_Transaction_Log_Internals/README.md) + [Labs Wrap-up](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q6</b> — B</summary>

SQL เขียนลงไฟล์ตาม **สัดส่วนพื้นที่ว่าง** (เช่น A ว่าง 10 GB, B ว่าง 5 GB → เขียน A 2 หน้า สลับ B 1 หน้า) — ไฟล์ที่โตไม่เท่ากันจึงรับ workload ไม่เท่ากัน ไฟล์ใหญ่กลายเป็น hotspot — ทุกไฟล์ต้องขนาด/autogrowth เท่ากันเพื่อกระจาย I/O สมดุล ข้อ A ผิดเพราะ PERCENT ทำให้ growth ต่างกันตามขนาดไฟล์ ยิ่งเบี่ยงเบน — อ่านต่อ: [Section 3.2 หัวข้อ Proportional Fill](Sections/02_Data_File_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q7</b> — B</summary>

ทุกครั้งที่ log grow หนึ่งครั้ง = เกิด VLF ชุดใหม่ — autogrowth ทีละน้อยที่รันหลายพันรอบจึงทำให้เกิด VLF ก้อนจิ๋วจำนวนมาก ตรวจได้ด้วย `sys.dm_db_log_info(file_id)` (แทน `DBCC LOGINFO`) ผลคือ startup/recovery, restore และ replication/AG seeding ช้าลงเพราะต้องไล่ตรวจ VLF ร้อย-พันก้อน — อ่านต่อ: [Section 3.3 หัวข้อ VLF](Sections/03_Transaction_Log_Internals/README.md) + [Labs Ex3](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q8</b> — B</summary>

ตั้งเป็น **MB คงที่ที่เหมาะสม** (64–256 MB หรือมากกว่า) ไม่ใช้ PERCENT — และข่าวดีตั้งแต่ SQL Server 2022: **IFI ช่วย log autogrowth ≤ 64 MB ด้วย** ทำให้ grow ครั้งถัดไปไม่หน่วงเพราะการ zero-out ข้อ C อันตราย (log เต็ม = ฐานข้อมูลหยุดทำงาน) — อ่านต่อ: [Module README 8.2–8.3](README.md) + [Labs Ex3 Step 3](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q9</b> — B</summary>

เริ่มจำนวน = logical cores **สูงสุด 8 ไฟล์**; ถ้ายังเห็น allocation contention ค่อยเพิ่ม **ทีละกลุ่ม 4** ตามแนวทาง MS ปัจจุบัน — เงื่อนไขสำคัญคือ "ขนาดเท่ากันทุกไฟล์ + growth เป็น MB เท่ากัน" เพื่อให้ proportional fill กระจายงานสมดุล (แล็บจริง: tempdb บน VM ตั้งมาถูกต้อง = 4 ไฟล์ × 72 MB, growth 64 MB, `is_percent_growth = 0`) — อ่านต่อ: [Module README 8.3](README.md) + [Section 3.4 — TempDB Internals](Sections/04_TempDB_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q10</b> — B</summary>

รูปแบบ `wait_resource = 'dbid:file_id:page_id'` → `2:1:1` คือ **database id 2 (tempdb), file 1, page 1 = allocation bitmap** — หลาย thread แย่งเขียนหน้า allocation เดียวกันตอนสร้าง temp table พร้อมกัน (PAGELATCH เป็น latch ใน memory ไม่ใช่ lock ข้อมูล และไม่ใช่ disk) — แก้ที่โครงสร้าง: เพิ่ม data files เท่ากัน (กระจาย bitmap) ไม่ใช่แค่เปลี่ยน disk; บน 2025 เสริมด้วย **ADR ใน tempdb** (`ALTER DATABASE tempdb SET ACCELERATED_DATABASE_RECOVERY = ON` + restart engine) และ **tempdb space governance** ผ่าน Resource Governor (ตอนนี้อยู่ใน Standard edition แล้ว) — อ่านต่อ: [Section 3.4](Sections/04_TempDB_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q11</b> — A</summary>

`sys.dm_server_services` มีคอลัมน์ `instant_file_initialization_enabled` ให้อ่านจากฝั่ง engine ตรง ๆ (บน VM หลักสูตร = `Y` กับ service account `NT Service\MSSQLSERVER`) — ขอบเขตของ IFI: ข้ามการ zero-fill ของ **data file** (CREATE DATABASE / RESTORE / autogrow) แต่ **log ต้อง zero-fill เสมอเพื่อ recovery ได้** — ยกเว้นตั้งแต่ SQL Server 2022 ที่ IFI ช่วย **log autogrowth ≤ 64 MB** ได้ — อ่านต่อ: [Section 3.2 หัวข้อ 3](Sections/02_Data_File_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q12</b> — B</summary>

SQL Server 2025 เพิ่มคุมพื้นที่ tempdb ต่อ workload group ผ่าน Resource Governor: `GROUP_MAX_TEMPDB_DATA_MB` หรือ `GROUP_MAX_TEMPDB_DATA_PERCENT` ต่อกลุ่ม แล้ว `ALTER RESOURCE GOVERNOR RECONFIGURE;` — workload ที่เกินโควตาโดนตัดที่ตัวมันเอง ไม่ลากทั้ง instance และ RG อยู่ใน **Standard Edition** แล้ว ข้อ C (`max_size`) ทำให้ tempdb ทั้งตัวเต็มและ error 9009 ใส่ทุกคน ส่วน D ไม่ใช่หน้าที่ของ ADR — อ่านต่อ: [Section 3.4 หัวข้อ 6](Sections/04_TempDB_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q13</b></summary>

```sql
DBCC TRACEON(3604);   -- ส่งผลลัพธ์ DBCC ออกทาง client
DBCC PAGE('AdventureWorks2025', 1, 736, 3);   -- 3 = header + row detail
```
หมายเลข page ได้จาก `sys.dm_db_database_page_allocations` ก่อนหน้า (บน 2025)

- **`1:736` = file_id 1, page 736** (รูปแบบ file:page)
- `m_type = 1` → **Data page** (leaf ของ clustered index/heap)
- `m_slotCnt = 5` → page นี้เก็บ **5 แถว** (slot array ชี้ตำแหน่งแถว)
- `m_freeCnt = 1162` → **เหลือพื้นที่ว่าง 1,162 bytes** ใน page (page หนึ่ง 8,192 bytes เสมอ)
- แล็บจริงยังเห็น page เพื่อนบ้านเชื่อมกัน (1:1279) ↔ (1:737) = linked list ของ leaf level

อ่านต่อ: [Labs Ex1](Labs/README.md) + [Section 3.1 หัวข้อ 6 — DBCC PAGE](Sections/01_Structure_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q14</b></summary>

Shrink ย้ายข้อมูลจากท้ายไฟล์มากองหน้า ทำให้ index เรียงกันใหม่แบบ "ข้ามหน้าสวนทาง" → **fragmentation ระดับสูง**; ต่อมา workload ต้องขยายพื้นที่อีก → ไฟล์ grow ใหม่ → วงจร **Shrink (สร้าง fragmentation + กิน CPU/I/O) → Grow (เสียเวลา + VLF/page allocation)** วนซ้ำทั้งวัน — ค่าใช้จ่ายสองฝั่งโดยไม่ได้อะไรกลับมา ที่ถูกคือวางขนาดไฟล์ให้พอกับ workload + growth เป็น MB ที่เหมาะสม และจัดการพื้นที่ด้วย maintenance ที่วางแผน (คำถามท้ายแล็บข้อ 3 ของ Module 3) — อ่านต่อ: [Module README คำถามท้ายบทข้อ 3](README.md)
</details>

<details>
<summary><b>เฉลย Q15</b></summary>

VLF ขนาดคละกัน = **ฟอสซิลของการตั้งค่า autogrowth ในอดีต**: ก้อน ~64 MB มาจาก growth ใหญ่ครั้งใหญ่ ส่วนก้อน ~1.9–2.2 MB เป็นร่องรอยที่เคยตั้ง growth เล็ก (ทีละ ~2 MB) มาก่อน — ต่างจาก log ที่ตั้งค่าดีตั้งแต่แรกซึ่งจะได้ VLF ไม่กี่สิบก้อนขนาดค่อนข้างเท่ากัน

การรีเซ็ตจริง: เพราะ **VLF เดิมไม่หายเอง** แม้แก้ FILEGROWTH แล้ว (growth ครั้งถัดไปแค่สร้างก้อนใหม่ใหญ่น้อยก้อน) ต้อง `DBCC SHRINKFILE(log, ...)` แล้ว grow ครั้งเดียวใหญ่ ๆ เพื่อได้ชุด VLF ใหม่ใหญ่เท่ากัน — อย่าทำบน production ระหว่างชั่วโมงทำงาน — อ่านต่อ: [Labs Ex3 Expected + หมายเหตุ](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q16</b></summary>

- **Uniform Extent** = ทั้ง 8 pages เป็นของ object เดียว (รูปแบบหลักในเวอร์ชันใหม่)
- **Mixed Extent** = แชร์พื้นที่ร่วมกันหลาย object (ยุคเก่าใช้ประหยัดพื้นที่ให้ตารางเล็ก) — ติดตามด้วย **SGAM** (Shared GAM: bit 1 = mixed extent ที่ยังมีหน้าว่าง)

เพราะการ insert ลง object ใหม่/เล็กต้องหา mixed extent ที่ว่างจาก **bitmap page เดียวกันทั้ง instance** หลายพัน session สร้าง temp table พร้อมกันใน tempdb ยุคเก่าจึงแย่งแก้ SGAM หน้าเดียวกัน → `PAGELATCH_EX/UP` แก้ด้วยการเพิ่ม tempdb data files กระจาย bitmap

**ความลึกยุคใหม่ (ทดสอบจริงบน 2025):** ตั้งแต่ SQL Server 2016 uniform-only allocation (พฤติกรรม TF 1118) เป็น default ของ database ใหม่ — ตรวจได้ที่ `sys.databases.is_mixed_page_allocation_on` (0 = uniform only) — แต่การทดลองสร้างตารางใหม่ 1 แถวยังพบ DATA_PAGE แรกวางแบบไม่ชิดขอบ extent (offset 1) พร้อมธง mixed ขณะ IAM_PAGE ชิดขอบเสมอ สรุป: mixed extent ยังมีบทบาทเฉพาะ "หน้าแรก" ของ object จิ๋ว แต่ object ที่โตเกิน 8 pages จะได้ uniform extent ล้วน — อ่านต่อ: [Section 3.1 หัวข้อ 4](Sections/01_Structure_Internals/README.md) + [Section 3.4](Sections/04_TempDB_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q17</b></summary>

ผลนี้ถูกต้องตามธรรมชาติเพราะ:
1. **Contention ต้องมีคู่แข่ง** — session เดียวไม่มีใครแย่ง bitmap กับมัน ต้องรัน 4–8 หน้าต่างพร้อมกันตามที่แล็บระบุ
2. ตัวเลขสะสม 40,456 ครั้ง / 590 ms ≈ **0.01 ms ต่อครั้ง** คือระดับ background ปกติของ allocation ทั่ว instance — อ่าน `sys.dm_os_wait_stats` ต้องดู **เฉลี่ยต่อครั้ง** ไม่ใช่ยอดรวม

การออกแบบเดโมให้เห็นจริง: รัน loop เดิมจาก 4–8 หน้าต่างพร้อมกัน + poll `sys.dm_exec_requests` แบบสด (`wait_resource LIKE '2:%'`) ในช่วงที่ยังรันอยู่ ไม่ใช่ดูยอดสะสมหลังจบ — อ่านต่อ: [Labs Ex4 Step 2–3 + Expected](Labs/README.md)
</details>

---

<details>
<summary><b>เฉลย Q18</b></summary>

- **ขั้นก่อนเริ่ม (39.6%)**: log อยู่ในสถานะวนใช้ซ้ำได้ปกติ (`NOTHING`)
- **ขั้น tran เปิด + CHECKPOINT (43.7%, ACTIVE_TRANSACTION)**: INSERT เขียน log ~5.6 MB → used% โต ต่อให้สั่ง CHECKPOINT ก็จบ — จุดตัดของ log ถูกขวางด้วย **transaction เก่าสุดที่ยังเปิด** จึงได้ `ACTIVE_TRANSACTION` (สถานการณ์เดียวกับ app ลืม commit / holding scan ค้าง)
- **ขั้นหลัง commit + CHECKPOINT (42.0%, NOTHING)**: truncation เป็นการ **mark ว่าเขียนทับได้** ไม่ใช่การย่อไฟล์ — used% จึงไม่กลับลงเป๊ะเดิม (ส่วนที่เหลือคือเนื้อ log ที่ยังไม่ถูกเขียนทับ ไม่ใช่ "ของที่ลืมลบ")

หลักการรวม: บน SIMPLE recovery truncation ทำที่ checkpoint; บน FULL คือ log backup (`LOG_BACKUP` เป็นเหตุขวางยอดฮิตของ error 9009) — อ่านต่อ: [Section 3.3 หัวข้อ 3](Sections/03_Transaction_Log_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q19</b></summary>

`sys.master_files` เก็บ **หน่วย page (8 KB)** ทั้ง `size` และ `growth` (เมื่อเป็น fixed) และ `max_size` สาเหตุ overflow: ไฟล์ที่ `max_size = 268435456` (เพดาน default 2 TB) เมื่อคูณด้วย int `8` = 2,147,483,648 เกินช่วง int — สคริปต์ที่ถูกต้องใช้ `8.0` หรือ `CAST(... AS BIGINT)`:

```sql
CAST(size * 8.0 / 1024 AS DECIMAL(10,1))                    -- size_mb
CAST(CAST(growth AS BIGINT) * 8 / 1024 AS VARCHAR(20))      -- growth (page → MB)
CASE max_size WHEN -1 THEN 'unlimited'
     ELSE CAST(CAST(max_size AS BIGINT) * 8 / 1024 AS VARCHAR(12)) + ' MB' END
```

แถม: `is_percent_growth = 1` เมื่อ growth เก็บเป็น % (แถวนั้นคือจุดที่ต้องแก้เป็น MB คงที่) — อ่านต่อ: [Section 3.2 หัวข้อ 1](Sections/02_Data_File_Internals/README.md)
</details>

<details>
<summary><b>เฉลย Q20</b></summary>

**Ghost Record** = แถวที่ถูก DELETE แล้วแต่ engine เพียง **mark ธงว่าลบแล้ว** บน page แทนการเคาะออกทันที — เพื่อลดงานตัว DELETE และให้ scan ที่กำลังอ่านหน้านั้นเห็นสถานะสอดคล้อง (รองรับ row-level locking/snapshot) แล้ว **Ghost Cleanup Task** (background) ค่อยกวาดออกเป็นระยะ

สองค่าไม่ตรงกันได้เพราะ: `has_ghost_records` (จาก `sys.dm_db_database_page_allocations`) มาจากข้อมูล per-page ที่สะท้อนสถานะตอน DELETE เพิ่งเกิด (ทดสอบจริง: 29/29 หน้า) ขณะที่ `ghost_record_count` ของ `sys.dm_db_index_physical_stats` คือผล **scan ณ เวลาที่รัน** — บนระบบที่ cleanup กวาดทัน (หรือตัว DELETE เรียกเก็บกวาดเอง) ค่านี้เป็น 0 ได้ — เชื่อม: Trace Flag 661 ปิด Ghost Cleanup ได้แต่ห้ามใช้ (ขยะกองจนไฟล์โตไม่คืน) — อ่านต่อ: [Section 3.3 หัวข้อ 5](Sections/03_Transaction_Log_Internals/README.md)
</details>

**ท้ายชุดข้อสอบ:** ทำคะแนนได้ ≥ 16/20 ถือว่าผ่านมาตรฐานบทที่ 3 — ถ้ายังไม่ถึง ให้ย้อนอ่าน [3.1 Structure Internals](Sections/01_Structure_Internals/README.md) → [3.2 Data File Internals](Sections/02_Data_File_Internals/README.md) → [3.3 Transaction Log Internals](Sections/03_Transaction_Log_Internals/README.md) → [3.4 TempDB Internals](Sections/04_TempDB_Internals/README.md) และทำ [Labs](Labs/README.md) ซ้ำอีกรอบ
