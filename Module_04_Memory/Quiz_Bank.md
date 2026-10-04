# Quiz Bank — บทที่ 4: Memory Management (Windows Memory, Buffer Pool, Memory Grants, PLE, Pressure & In-Memory OLTP)

> ครอบคลุมวัตถุประสงค์การเรียนรู้ของบทที่ 4 ตาม [Course_Guide_4Days.md](../Trainer_Docs/Course_Guide_4Days.md): Windows Memory (VAS/Paging/NUMA), Buffer Pool, Non-Buffer Pool (Memory Clerks), Memory Grants, Page Lifecycle (Checkpoint/Lazy Writer), PLE และ thresholds, Memory Pressure Indicators (รวม ring buffer, PVS) และ In-Memory OLTP (Hekaton, Natively Compiled, Memory-Optimized Tables) — ใช้คู่กับ [Sections](README.md) และ [Labs](Labs/README.md)
> **รูปแบบ:** ข้อ 1–13 multiple choice · ข้อ 14–19 ตอบสั้น · เฉลยพร้อมคำอธิบายอยู่ท้ายไฟล์ (อย่าเลื่อนดูก่อนตอบ!)

---

## ส่วนที่ 1: Multiple Choice

### Q1. แล็บจริงบน SQL Server 2025: query sort รอบแรกได้ memory grant **682,944 KB (~667 MB)** แต่ใช้จริง `max_used_grant_kb = 12,160 KB (~12 MB)` — ปรากฏการณ์และกลไกที่แก้ให้เองคือข้อใด?
- A. Memory leak — ต้อง restart service ทันที
- B. Overgrant ทั่วไปของ CE ที่ประเมินแถวเยอะเกิน — Memory Grant Feedback จะหด grant ลงในรอบถัดไป (จริง: เหลือ ~18 MB)
- C. Grant ใหญ่ผิดปกติเพราะ `max server memory` ตั้งต่ำเกินไป
- D. Resource Governor จอง memory ไว้ให้ workload group อื่น

### Q2. บน SQL Server 2025 คุณต้องการพิสูจน์ว่า "feedback แก้ grant ให้แล้ว" — ช่องทางใดถูกต้องตามที่รันจริงพิสูจน์?
- A. อ่านคอลัมน์ `is_memory_grant_feedback_adjusted` จาก `sys.query_store_plan`
- B. อ่านแถวจาก `sys.query_store_plan_feedback` (เช่น `feature_desc = 'Memory Grant Feedback'`, `state = 'FEEDBACK_VALID'`)
- C. ดู PerfMon counter `Granted Workspace Memory` ครั้งเดียวก็จบ
- D. เปิด `DBCC MEMORYSTATUS` แล้วหาหัวข้อ Feedback

### Q3. Session เปิดอยู่เยอะ คุณเห็น wait `RESOURCE_SEMAPHORE` ปรากฏต่อเนื่อง — ตีความและตรวจยืนยันอย่างไร?
- A. รอ lock — ตรวจ `sys.dm_tran_locks`
- B. Query รอ **memory grant** สำหรับ sort/hash — ยืนยันด้วย `sys.dm_exec_query_resource_semaphores` (`waiter_count > 0`) และดูคิวจาก `sys.dm_exec_query_memory_grants`
- C. รอ worker thread — ตรวจ `max_workers_count`
- D. รอ log flush — ตรวจ latency ของ .ldf

### Q4. จุดต่างของ **Checkpoint** กับ **Lazy Writer** ข้อใดถูกต้องที่สุด?
- A. ทั้งคู่เขียน dirty page ลง disk เหมือนกันทุกอย่าง ต่างกันแค่ชื่อ
- B. Checkpoint เขียน dirty pages ลง disk เป็นระยะเพื่อลด recovery time (ไม่ปล่อย page ออกจาก cache) ส่วน Lazy Writer ทำงานเมื่อ memory เริ่มเต็ม — เขียนและ **เท้าออก (evict)** page ที่ไม่ได้ใช้ (LRU) เพื่อคืนพื้นที่
- C. Lazy Writer เขียนเฉพาะ clean page ส่วน Checkpoint เขียนเฉพาะ dirty page
- D. Checkpoint ทำงานเฉพาะตอน shutdown เท่านั้น

### Q5. แล็บจริงวัดได้ **PLE = 13,273 วินาที** บนเครื่อง 16 GB (1 NUMA node) — การตีความ PLE ที่ถูกต้องคือข้อใด?
- A. ต่ำกว่า 300 วินาที = แย่ สูงกว่า = ดีเสมอ — 13,273 ถือว่าผิดปกติ
- B. PLE เป็นค่ารวมที่แปรผันกับขนาด buffer pool ต้องดู **trend ตกฮวบ เทียบ baseline และอ่านต่อ Buffer Node (ต่อ NUMA)** ไม่ใช่ตัดสินด้วยเลข 300 วินาทียุคเก่า — 13,273 บนเครื่องว่างคือปกติ
- C. PLE วัดเวลาเฉลี่ยที่ query ทำงานเสร็จ
- D. PLE ต้องอ่านจาก `sys.dm_os_memory_clerks` เท่านั้น

### Q6. เซิร์ฟเวอร์ RAM 128 GB รัน SQL Server เดี่ยว + Windows — หลักคำนวณ `max server memory` ที่ถูกต้องคือข้อใด?
- A. ปล่อย default (2,147,483,647 MB) เพราะ SQL รู้จักแบ่งเองเสมอ
- B. Total RAM − (ความต้องการของ OS + process อื่น ๆ เช่น backup, antivirus, SQL Agent) — และจำว่าค่านี้ไม่ครอบคลุม thread stacks และ CLR allocations บางส่วน
- C. Total RAM × 100% เพื่อไม่เสีย RAM สักไบต์
- D. ตั้งเท่ากับ Min Server Memory เพื่อให้ค่าคงที่

### Q7. เกี่ยวกับ **LPIM (Lock Pages in Memory)** ข้อใดถูกต้อง?
- A. ป้องกัน SQL Server ใช้ memory เกิน `max server memory`
- B. ป้องกัน Windows นำ memory ของ SQL Server ไป paging ลง disk — เพิ่มเสถียรภาพ แต่ไม่ได้ป้องกัน SQL กดดันตัวเองภายใน และการตั้ง `max server memory` ยังจำเป็น
- C. ทำให้ buffer pool ใช้ large pages เสมอโดยอัตโนมัติ
- D. เป็นฟีเจอร์เฉพาะ Azure SQL Database

### Q8. ต้องการดู "database ไหนกิน cache มากที่สุด" — query ใดใช้ได้จริง และหน่วยที่ต้องแปลงคืออะไร?
- A. `sys.dm_os_memory_clerks` — หน่วย KB ต่อ clerk
- B. `sys.dm_os_buffer_descriptors` จัดกลุ่มด้วย `database_id` นับ `COUNT_BIG(*)` แล้วคูณ 8 KB ต่อ page (แล็บจริง: AdventureWorks ~218 MB = 27,961 pages)
- C. `sys.databases` — คอลัมน์ `cached_size_mb`
- D. `sys.dm_io_virtual_file_stats` — จำนวน read ต่อไฟล์

### Q9. Memory clerk ใด "ควรเป็นขาใหญ่ที่สุด" และถ้า `CACHESTORE_SQLCP` บวมขึ้นมาเป็นอันดับหนึ่งควรสงสัยอะไร?
- A. `MEMORYCLERK_SQLQUERYEXEC` — สงสัย sort หนัก; SQLCP บวม = memory grant รั่ว
- B. `MEMORYCLERK_SQLBUFFERPOOL` — สงสัย plan cache บวมจาก ad-hoc workload จำนวนมาก (แล็บจริง: BUFFERPOOL 327 MB, SQLCP ~140 MB ตามมาเป็นสอง)
- C. `OBJECTSTORE_LOCK_MANAGER` — สงสัย blocking; SQLCP = lock รั่ว
- D. `MEMORYCLERK_XTP` — สงสัย In-Memory OLTP; SQLCP = columnstore

### Q10. พยายามสร้าง `CREATE TABLE ... WITH (MEMORY_OPTIMIZED = ON)` แล้วได้ **Msg 41337** — สาเหตุและทางแก้คืออะไร?
- A. Edition ไม่รองรับ — ต้องใช้ Enterprise ขึ้นไปเท่านั้น
- B. Database ยังไม่มี MEMORY_OPTIMIZED_DATA filegroup ที่ online — ต้อง `ALTER DATABASE ... ADD FILEGROUP ... CONTAINS MEMORY_OPTIMIZED_DATA` ก่อน (และบน 2025 ถ้าเลิกใช้แล้วลบ filegroup ที่ว่างออกได้แล้ว)
- C. ตารางมี PRIMARY KEY — ตาราง memory-optimized ห้ามมี key
- D. BUCKET_COUNT ตั้งต่ำเกินไป

### Q11. เซิร์ฟเวอร์เปิด **LPIM** แล้ว — Task Manager โชว์ `sqlservr.exe` ใช้ memory 1 GB แต่ DBA คนเดิมยืนยันว่า SQL ใช้ RAM ~100 GB จริง ๆ — ข้อสรุปและวิธีตรวจที่ถูกต้องคือข้อใด?
- A. Task Manager ถูก — DMV รายงานเกินจริงเสมอ
- B. Memory ที่ถูกล็อกด้วย LPIM **ไม่ถูกนับใน working set ของ Task Manager** — ต้องตรวจด้วย `sys.dm_os_process_memory` (`locked_page_allocations_kb`) หรือ `DBCC MEMORYSTATUS` (AWEAllocated)
- C. SQL Server มี memory leak — ต้อง restart ทันที
- D. LPIM ทำให้ buffer pool หดตัว — ควรถอด LPIM ออก

### Q12. Ring buffer `RING_BUFFER_RESOURCE_MONITOR` บันทึกแถว `RESOURCE_MEMPHYSICAL_LOW` ไว้เมื่อคืนก่อนเวลา 03:00 — ตีความและขั้นตอนถัดไปที่ถูกต้องคือข้อใด?
- A. SQL Server หมด memory ภายใน — เพิ่ม `max server memory` ทันที
- B. Windows ขาด RAM ณ เวลานั้น (external pressure) SQL ถูกบีบให้ trim caches — ให้หาว่า **process ใดบนเครื่องกิน RAM ช่วงนั้น** (backup/antivirus/app อื่น) แล้วคุม `max server memory` ให้เหลือ headroom ให้ OS
- C. สัญญาณปกติของทุกเครื่องทุกคืน — ไม่ต้องสนใจ
- D. Query ต้องรอ memory grant — ตรวจ `sys.dm_exec_query_resource_semaphores`

### Q13. เครื่อง 2-socket (2 NUMA node) — PLE ค่ารวม instance ดูดี แต่ query ช้าเป็นระยะ — ข้อสรุปที่ถูกหลักคือข้อใด?
- A. PLE รวม = ตัวชี้วัดสุดท้าย ไม่ต้องดูต่อ node
- B. ต้องอ่าน PLE **ต่อ Buffer Node** (`object_name LIKE '%Buffer Node%'`) — ค่ารวมปิดบัง node ที่ถูกกด; node ที่ต่ำผิดจาก baseline คือจุดที่ต้องสืบต่อ (คู่กับ `foreign_committed_kb` ของ memory node)
- C. PLE อ่านได้จาก `sys.dm_os_buffer_descriptors` เท่านั้น
- D. เครื่อง 2-socket ไม่มีผลจาก NUMA เพราะ Windows รวม memory เป็นก้อนเดียว

---

## ส่วนที่ 2: ตอบสั้น

### Q14. Memory Spill คืออะไร เกิดตอนไหน สังเกตเห็นได้จากอะไรใน execution plan และ Memory Grant Feedback ช่วยได้ทั้งสองทิศทางอย่างไร (spill → เพิ่ม, overgrant → ลด)?

### Q15. จากแล็บจริง: `sys.dm_os_process_memory` รายงาน `memory_utilization_percentage = 100`, `process_physical_memory_low = 0`, `process_virtual_memory_low = 0` — ค่าชุดนี้ตีความว่าอย่างไร และต่างจากกรณี "OS เริ่มขาด memory" (Resource Monitor ยิง `RESOURCE_MEMPHYSICAL_LOW`) อย่างไร?

### Q16. คุณได้รับเซิร์ฟเวอร์ใหม่ที่ PLE รายงาน 40,000 วินาที แต่ผู้ใช้บ่นว่า report หนักวิ่งแล้วระบบทั้งเครื่องช้าลงชั่วคราว — จะออกแบบการวัด memory pressure ให้จับอาการนี้ได้อย่างไร (ระบุ DMV/counter ที่ใช้ และรูปแบบอาการ PLE แบบ sawtooth)

### Q17. เปรียบเทียบ Large Page Memory Model กับ Conventional: ขนาด page, ประโยชน์ (TLB) และข้อเสีย (static allocation ตอน startup) — ในสถานการณ์ใดจึงคุ้ม และ LPIM ต่างจากมันตรงไหน?

### Q18. จากแล็บจริงขั้น In-Memory OLTP: loop insert 10,000 แถวทีละแถว (autocommit) บนตาราง disk-based ใช้ ~503 ms และคาดว่า memory-optimized จะเร็วกว่านี้ — อธิบายว่าเพราะเหตุใด `DURABILITY = SCHEMA_ONLY` จึงได้เปรียบด้าน log โดยเฉพาะ และ pattern งานแบบไหนที่ Hekaton เหมาะ (พร้อมข้อควรระวัง BUCKET_COUNT)

### Q19. DB เปิด RCSI และคุณพบว่า `persistent_version_store_size_kb` ของ `sys.dm_tran_persistent_version_store_stats` โตต่อเนื่องช่วงบ่ายทุกวัน — PVS คืออะไร (และต่างจาก version store ยุคก่อน 2019 อย่างไร) เพราะเหตุใด transaction ยาวจึงทำให้มันโต ควรอ่านค่าคู่กับตัวใด และทิศทางแก้คืออะไร?

---

## เฉลยพร้อมคำอธิบาย

<details>
<summary><b>เฉลย Q1</b> — B</summary>

CE ประเมินข้อมูลขาเข้ากว้างกว่าความจริง (121,317 แถวที่ sort เป็น NVARCHAR(MAX)) จึงจ่าย grant 667 MB แต่ใช้จริง ~12 MB และ `total_spills = 0` — นี่คือ **overgrant**: ไม่พัง แต่กิน workspace ของคนอื่น Memory Grant Feedback (ตระกูล IQP) จดผลรอบก่อนแล้ว **หด grant รอบถัดไป** (จริง: 667 → 18 MB) อ่านต่อ: [Labs Ex3 Expected](Labs/README.md) + [Section 4.3 — Memory Pressure Diagnostics หัวข้อ Memory Grant Feedback](Sections/03_Memory_Pressure_Diagnostics/README.md)
</details>

<details>
<summary><b>เฉลย Q2</b> — B</summary>

ตรวจจริงบน 17.0.1135.8: คอลัมน์ `is_memory_grant_feedback_adjusted` **ถูกถอดออกจาก `sys.query_store_plan`** แล้ว (query เดิม error `Invalid column name`) — ช่องทางปัจจุบันคือ `sys.query_store_plan_feedback` ซึ่งรายงาน feedback ทุกตระกูลที่ engine ใช้จริง (แล็บจริงพบแถว `Memory Grant Feedback / FEEDBACK_VALID`) อ่านต่อ: [Labs Ex3 Step 2 + ⚠️](Labs/README.md) + [SignOff ข้อค้นพบ 3](../Trainer_Docs/SignOff/AllLabs_SignOff.md)
</details>

<details>
<summary><b>เฉลย Q3</b> — B</summary>

`RESOURCE_SEMAPHORE` = query จ่าย grant ไม่ได้เพราะ workspace memory ของ instance ถูกใช้หมด → เข้าคิวรอ ตรวจคู่กัน: `sys.dm_exec_query_resource_semaphores` (บน 2025 คอลัมน์ชื่อ **`granted_memory_kb` / `used_memory_kb` / `grantee_count` / `waiter_count`** — ชื่อเดิม `total_*` ถูกเปลี่ยน) — `waiter_count > 0` คือหลักฐานคิวรอ — อ่านต่อ: [Section 4.3](Sections/03_Memory_Pressure_Diagnostics/README.md) + [Labs Ex3 Step 3 ⚠️](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q4</b> — B</summary>

**Checkpoint** = ล้าง backlog ของ dirty page เป็นระยะ ป้องกัน recovery ยาวตอน restart — page ยังค้างใน buffer pool ให้ใช้ต่อ **Lazy Writer** = ทำงานเมื่อ SQL กดดัน memory ตัวเอง — เขียน dirty page แล้ว **evict ออก** (LRU) เพื่อหา page เปล่าให้ request ใหม่ อ่านต่อ: [Section 4.2 หัวข้อ Buffer Pool](Sections/02_SQL_Server_Memory/README.md)
</details>

<details>
<summary><b>เฉลย Q5</b> — B</summary>

PLE เกณฑ์ 300 วินาทีมาจากยุค RAM 4–32 GB — บนเครื่องที่ buffer pool หลายสิบ GB ค่าปกติอาจหลักหมื่น (แล็บจริง 13,273 s บนเครื่องว่าง) — วิธีอ่านที่ถูก: ดู **trend (Sawtooth = pressure)** เทียบ baseline และ query ต่อ **Buffer Node** (`object_name LIKE '%Buffer Node%'`) เพราะค่ารวม instance ปิดบัง node ที่กดดันเฉพาะจุด — อ่านต่อ: [Labs Ex2 Step 3 ✅](Labs/README.md) + [Section 4.3 หัวข้อ PLE](Sections/03_Memory_Pressure_Diagnostics/README.md)
</details>

<details>
<summary><b>เฉลย Q6</b> — B</summary>

`max server memory` ควบคุม "เกือบทั้งหมด" ของ memory SQL (2012+ รวม multi-page/CLR allocator) แต่ **ไม่ครอบคลุม thread stacks** — ปล่อย default บน Windows ทำให้ SQL แย่ง RAM กับ OS จน paging ถล่ม (อาการแบบ Bogeys ในห้องเรียน) สูตรตั้งต้น: Total RAM − (OS + กระบวนการอื่น) — อ่านต่อ: [Section 4.2 หัวข้อ Configuration Best Practices](Sections/02_SQL_Server_Memory/README.md)
</details>

<details>
<summary><b>เฉลย Q7</b> — B</summary>

LPIM เป็น **สิทธิ์ Windows** ("Perform volume maintenance tasks"/Lock pages) ที่ทำให้หน้า memory ของ SQL ไม่ถูก OS paging ลง disk — มักแนะนำบน production เพื่อเสถียรภาพ แต่ไม่ได้หยุด **memory pressure ภายใน** SQL (grant แย่งกัน, cache บวม) และถ้าไม่ตั้ง `max server memory` LPIM กลับอาจ "ล็อก" RAM จน OS อด — อ่านต่อ: [Section 4.2 หัวข้อ Memory Models (LPIM)](Sections/02_SQL_Server_Memory/README.md) + [Module README คำถามท้ายบทข้อ 2](README.md)
</details>

<details>
<summary><b>เฉลย Q8</b> — B</summary>

`sys.dm_os_buffer_descriptors` = หนึ่งแถวต่อ **page ใน cache** — จัดกลุ่มด้วย `database_id` (โดย `32767` = RESOURCE DB) หรือ join ต่อ `sys.allocation_units → sys.partitions` เพื่อดูราย object และแปลงเป็น MB ด้วย `COUNT_BIG(*) * 8 / 1024.0` (page = 8 KB เสมอ) — อ่านต่อ: [Labs Ex2](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q9</b> — B</summary>

ปกติ `MEMORYCLERK_SQLBUFFERPOOL` ต้องเป็นขาใหญ่สุด (cache ข้อมูลหลัก) — ถ้า `CACHESTORE_SQLCP` (plan cache ของ ad-hoc/parameterized statements) โตขึ้นจนแซง ควรสงสัย **plan cache pollution** จาก workload ad-hoc (คู่กับ Optimize for Ad hoc Workloads) หลักการทั่วไปจากแล็บ: ดู **สัดส่วน "ใครใหญ่ที่สุด"** มากกว่าค่าสัมบูรณ์ — อ่านต่อ: [Labs Ex1 Step 3 ✅](Labs/README.md) + [Section 4.2 หัวข้อ Other Memory Clerks](Sections/02_SQL_Server_Memory/README.md)
</details>

<details>
<summary><b>เฉลย Q10</b> — B</summary>

Msg 41337 = "Cannot create memory optimized tables. To create memory optimized tables, the database must have a **MEMORY_OPTIMIZED_FILEGROUP** that is online and has at least one container." — เติมด้วย `ALTER DATABASE CURRENT ADD FILEGROUP ... CONTAINS MEMORY_OPTIMIZED_DATA` และข่าวใหม่บน **2025: ลบ memory-optimized filegroup ที่ว่างได้แล้ว** — แก้จุดอ่อน "ลองแล้วถอดไม่ได้" ของ Hekaton — อ่านต่อ: [Labs Ex4 Expected](Labs/README.md) + [Module README 7.2](README.md)
</details>

<details>
<summary><b>เฉลย Q11</b> — B</summary>

LPIM ล็อกหน้า memory ของ SQL ไว้กับ RAM จริง — หน้าเหล่านั้นถูกนับออกจาก working set ของ process ที่ Task Manager โชว์ ทำให้ตัวเลขบนจอ "หายไป" หลายสิบ GB — วิธีตรวจจริง: `SELECT locked_page_allocations_kb FROM sys.dm_os_process_memory` (จะขึ้นแทบทั้งก้อนที่ SQL ใช้) หรือ `DBCC MEMORYSTATUS` หัวข้อ Memory Manager/AWEAllocated — อ่านต่อ: [Section 4.1 หัวข้อเครื่องมือฝั่ง Windows](Sections/01_Windows_Memory/README.md) + [Section 4.2 หัวข้อ Memory Models](Sections/02_SQL_Server_Memory/README.md)
</details>

<details>
<summary><b>เฉลย Q12</b> — B</summary>

`RESOURCE_MEMPHYSICAL_LOW` คือสัญญาณที่ **Windows ยิงหา SQL** ("ขาด RAM แล้ว") — ต้นเหตุอยู่ "นอก" SQL Server เสมอก่อน: ไล่หา process อื่นบนเครื่องในช่วงเวลานั้น (agent backup, antivirus, app รั่ว) แล้วจึงป้องกันซ้ำด้วย `max server memory` ที่เหลือ headroom ให้ OS การเพิ่ม `max server memory` ทันที (ข้อ A) คือสวนทาง — ยิ่งจุก OS หนักขึ้น — อ่านต่อ: [Section 4.3 หัวข้อ Ring Buffer](Sections/03_Memory_Pressure_Diagnostics/README.md) + [Section 4.1 หัวข้อ 6 สัญญาณจาก Windows](Sections/01_Windows_Memory/README.md)
</details>

<details>
<summary><b>เฉลย Q13</b> — B</summary>

counter `Page life expectancy` ถูกวัด **ต่อ Buffer Node (ต่อ NUMA)** บนรุ่นปัจจุบัน — ค่ารวม instance ไม่มีให้เชื่อ และ node ที่ถูกกดเฉพาะจุดจะถูกค่าเฉลี่ยกลบหาย วิธีที่ถูก: query แยกตาม `instance_name` (node 000, 001 …) เทียบ baseline ต่อ node คู่กับ `sys.dm_os_memory_nodes.foreign_committed_kb` ว่า node ไหนถูกยืมข้าม — อ่านต่อ: [Section 4.1 หัวข้อ NUMA](Sections/01_Windows_Memory/README.md) + [Section 4.3 หัวข้อ PLE](Sections/03_Memory_Pressure_Diagnostics/README.md)
</details>

<details>
<summary><b>เฉลย Q14</b></summary>

**Spill** = operator sort/hash ได้ grant ไม่พอจนต้องเขียนข้อมูลชั่วคราวลง **tempdb** — เห็น warning สีเหลืองใน actual plan: "Operator used tempdb to spill data during execution" ที่ Sort/Hash operator

Memory Grant Feedback แก้สองทิศ: **spill** (ขาด) → จด `max_used_grant_kb`/spill แล้วเพิ่ม grant รอบถัดไป, **overgrant** (เหลือเฟือ) → หด grant ลง (แล็บจริง: 667 → 18 MB) — ตั้งแต่ 2022 feedback **persisted ลง Query Store** ทำให้จำค่าได้แม้ plan ถูก evict/restart (ดูผลที่ `sys.query_store_plan_feedback` บน 2025) — อ่านต่อ: [Labs Ex3](Labs/README.md) + [Section 4.3 หัวข้อ Memory Grant Feedback บน SQL Server 2025](Sections/03_Memory_Pressure_Diagnostics/README.md)
</details>

<details>
<summary><b>เฉลย Q15</b></summary>

`memory_utilization_percentage = 100` = SQL ใช้ memory ที่ตัวเองตั้งเป้า (target) เต็มแล้ว — เป็น **สภาวะปกติ** ของ dynamic memory (ramp-up จน Committed = Target) และ `*_memory_low = 0` ทั้งคู่หมายว่า **ไม่มี pressure** — SQL ไม่ได้อัด OS

ต่างจากกรณี OS กดดัน: Resource Monitor (background thread) รับสัญญาณ `RESOURCE_MEMPHYSICAL_LOW` จาก Windows แล้วจะ **trim caches** คืน memory ให้ OS (จะเห็น target ลดลง/cache ถูกเท้า) — อ่านต่อ: [Section 4.2 หัวข้อ Target vs Committed](Sections/02_SQL_Server_Memory/README.md) + [Labs Ex1 Step 2](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q16</b></summary>

อย่าตัดสินจาก PLE ตัวเลขเดียว — ออกแบบดังนี้:
1. **เก็บ PLE ต่อ Buffer Node (ต่อ NUMA)** จาก `sys.dm_os_performance_counters` เป็น series → report หนักควรเห็น **PLE ตกฮวบแบบ Sawtooth** (โดนเท้าออกแล้วคืนสถานะ) ไม่ใช่ค่าเฉลี่ยสวย
2. คู่กัน: Buffer Cache Hit Ratio (> 90–95%), `sys.dm_os_memory_clerks` (ใครโตขึ้นช่วงนั้น), page faults ของ process, และ wait `RESOURCE_SEMAPHORE` / `WRITE_PAGE` / `RESERVED_MEMORY_ALLOCATION_EXT`
3. เทียบกับ **baseline ก่อนเกิดเหตุ** (Lab 10) — คำถามคือ "ต่างจากปกติของเครื่องนี้หรือไม่" ไม่ใช่ "ต่ำกว่า 300 วินาทีหรือยัง"

อ่านต่อ: [Module README 7.3](README.md) + [Labs Ex2 Step 3 ✅](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q17</b></summary>

- **Conventional**: page 4 KB ปกติ, OS ยัง paging ได้, จัดการง่าย แต่เสี่ยง degradation เมื่อ OS กดดัน
- **Large Page**: ใช้ page **2 MB** — ลดจำนวน entry ใน TLB (บน CPU ที่ RAM เยอะ TLB miss แพง) แต่ต้อง **จองทั้งก้อนตั้งแต่ startup (static allocation)** — เปิด service ช้าลง และเหมาะกับ buffer pool ขนาดมหาศาล
- **LPIM** ต่างมิติ: ไม่เกี่ยวกับขนาด page แต่เป็นการ **ล็อกหน้าไม่ให้ OS paging** — ใช้เพื่อเสถียรภาพ

คุ้มเมื่อ: machine RAM ใหญ่มาก + workload เน้น scan ข้อมูลกว้าง (buffer pool ใหญ่) — อ่านต่อ: [Section 4.2 หัวข้อ Memory Models 1–3](Sections/02_SQL_Server_Memory/README.md)
</details>

<details>
<summary><b>เฉลย Q18</b></summary>

แต่ละ INSERT แบบ autocommit ต้อง **flush transaction log ก่อน commit ทุกครั้ง** (durability ต้องมีหลักฐานใน log) — disk-based SCHEMA_ONLY ไม่มีข้อยกเว้น ส่วน memory-optimized table ที่ประกาศ **`DURABILITY = SCHEMA_ONLY` ไม่ต้องเขียน log เลยตอน commit** (เก็บเฉพาะโครงสร้าง schema ตอน restart ข้อมูลหายได้) — จึงเหมาะกับ data ชั่วคราวที่สามารถสร้างใหม่ได้

Pattern ที่เหมาะ: **high-throughput insert + lookup** เช่น ETL staging, session store, IoT ingestion — ไม่ใช่ยาแครามทุกปัญหา และ `BUCKET_COUNT` ของ hash index ควรตั้งพอสำหรับจำนวนแถวที่คาด (ต่ำเกิน → bucket chain ยาว ช้าลง) — อ่านต่อ: [Section 4.4 — In-Memory OLTP](Sections/04_In_Memory_OLTP/README.md) + [Labs Ex4](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q19</b></summary>

**PVS (Persistent Version Store)** — ตั้งแต่ SQL Server 2019 ที่เปิด RCSI/Snapshot isolation row version ถูกเก็บ **ใน data file ของฐานข้อมูลเอง** (ไม่ใช่ tempdb แบบยุคก่อน) — page ของ PVS อยู่ใน buffer pool เหมือน page ทั่วไป จึงแย่ง cache กับข้อมูลจริง

ทำไม transaction ยาวทำให้โต: version เก่าต้องรอจนกว่า transaction เก่าที่สุดที่ "อาจมองเห็น" จะจบก่อน ถ้า transaction ค้าง (ลืม commit / session หลุดค้าง) version สะสมจนกวาดไม่ออก — ตรวจคู่กันด้วย `sys.dm_tran_persistent_version_store_stats` (`persistent_version_store_size_kb`, `current_aborted_transaction_count`, `oldest_active_transaction_id`) และ clerk `MEMORYCLERK_SQLVERSIONSTORE` — ทางแก้คือหา transaction ยาว (Module 5) ไม่ใช่ DBCC SHRINK — อ่านต่อ: [Section 4.3 หัวข้อ PVS](Sections/03_Memory_Pressure_Diagnostics/README.md)
</details>

---

**ท้ายชุดข้อสอบ:** ทำคะแนนได้ ≥ 15/19 ถือว่าผ่านมาตรฐานบทที่ 4 — ถ้ายังไม่ถึง ให้ย้อนอ่าน [4.1 Windows Memory](Sections/01_Windows_Memory/README.md) → [4.2 SQL Server Memory](Sections/02_SQL_Server_Memory/README.md) → [4.3 Memory Pressure Diagnostics](Sections/03_Memory_Pressure_Diagnostics/README.md) → [4.4 In-Memory OLTP](Sections/04_In_Memory_OLTP/README.md) และทำ [Labs](Labs/README.md) ซ้ำอีกรอบ
