# Module 11: Troubleshooting — สไลด์ไบล์พรินต์รายสไลด์

> เด็ค M11 จาก 12 เด็ค / 196 สไลด์ของหลักสูตร SQL Server Performance Tuning (4 วัน / 24 ชม.) · Template: `Trainer_Docs/Trainocate_SQLPerfTuning_Template.potx` (8 layouts, 16:9, Leelawadee UI) · ร่างตามแผนแม่บท `Trainer_Docs/Production_Plan_Course_and_Slides.md` หมวด 4 (มาตรฐานสไลด์) และหมวด 3 (ช่องว่าง M11: capstone outline 2 sections 24–65 บรรทัด, S2 = สั้นสุดของ capstone + 0 บล็อกโค้ด SQL, Scripts/ ครบ 2/2, แล็บ 3 Exercise มี expected บางส่วน 1 จุด :106, ไม่มี heading เสีย)

**สรุปเด็ค (5 บรรทัด):**
- โครงเด็คตามสูตรมาตรฐาน 4.2 ตายตัว: **12 สไลด์** = โครงโมดูล 4 ใบ (Cover / Module Divider / Lab / Closing) + 4 ใบ × 2 sections (S1 Troubleshooting Workflow, S2 Scenarios & Resolution) · Code Lab **3 ใบ ≤ เพดาน 4 ใบ/โมดูล**
- ทั้งสอง section ยังเป็น outline (ตรวจ `wc -l` = 65/24 บรรทัด, บล็อกโค้ด SQL = 0/0 และไม่มี "ตรวจความเข้าใจ") — สไลด์เนื้อหาทุกใบออกแบบตาม **"เป้าหมายของหัวข้อ"** ตามมาตรฐานเด็คหลักสูตร (S2 รวมสไลด์ Mitigation→Root Fix ที่เนื้อหาวันนี้มีแค่ในแล็บ) และระบุ **"ต้องเขียนเนื้อหาเพิ่ม"** ใน speaker notes ทุกใบ
- ภาพแผนภาพต้อง**วาดใหม่ PNG ≥2400px** ที่ `Module_11_Troubleshooting/Sections/01_Troubleshooting_Workflow/images/` (flowchart + chain-of-pain จาก S1 README:46-59) — ตรวจ `git ls-files "*.png"` แล้ว M11 ยังไม่มีภาพเลย (repo มี tracked PNG แค่ 2 ไฟล์ของ M1) และห้ามดึงจากเด็ค 10987C/9Expert (มติ #8)
- สไลด์ Module Divider พิมพ์**งบเวลาโมดูล 105 นาที** (บรรยาย 14:00–15:00 = 60 นาที + LAB 11 + Case Study 15:00–15:45 = 45 นาที ตาม `Course_Guide_4Days.md:116-117`) และสไลด์ Lab พิมพ์**จำนวน 3 Exercise** ตาม Slide Spec 4.2/4.6 — เด็คนี้ไม่ใช้ layout `07 Stat Callout` เพราะยังไม่มีตัวเลขที่ผ่าน sign-off รันจริง 17.x
- ข้อควรแก้ใน repo ก่อนประกอบเด็คจริง: `02_Broken_Server_Challenge.sql` comment ไทย encoding เพี้ยน (ตรวจด้วย `file` พบ double-encoded UTF-8) · ไฟล์ .sql โมดูลนี้ 0/7 มี header `MinVersion:` · S1 README:23-24 อ้างสคริปต์ข้ามโมดูล (M1 wait stats / M1 Lab Ex3) ทั้งที่โมดูลมี `05_Quick_Wait_Analysis.sql` ของตัวเอง · เลขสคริปต์ไขว้ระหว่าง section (01,03–07 ใน S1 / 02 ใน S2) ควรจัดใหม่ตอนขยายเนื้อหา

---

### สไลด์ 1: Cover — Module 11: Troubleshooting (Capstone)

- **Layout:** `title` → potx `01 Cover (dark)`
- **เนื้อหา bullet:**
  - **Module 11: Troubleshooting** — กระบวนการแก้ปัญหาประสิทธิภาพอย่างเป็นระบบ (Systematic Approach) หา Root Cause ด้วย Data-driven evidence
  - หลักสูตร SQL Server Performance Tuning — Day 4 (Monitoring, Tuning Strategy & Troubleshooting) · **สไลด์ Capstone รวมทุกโมดูล M1–M10**
  - คำโปรย: "การคาดเดาโดยไม่มีหลักฐาน นำไปสู่การแก้ปัญหาที่ผิดจุด"
- **ภาพ/แผนภาพ:** ไม่ใช้ — พื้นหลัง dark ของ layout Cover
- **Speaker notes:** เปิดโมดูลปิดท้ายคอร์ส — ย้ำว่าทุกเครื่องมือที่เรียนมา (Waits, DMVs, XEvents, Query Store, Monitoring) จะถูกรวมเป็น workflow เดียวในโมดูลนี้ `Ref: Module_11_Troubleshooting/README.md:1-3` · `Trainer_Docs/Course_Guide_4Days.md:62`

### สไลด์ 2: Module Divider — Troubleshooting Workflow & Scenarios (งบเวลา + Exercise)

- **Layout:** `section-divider` → potx `02 Module Divider (dark)`
- **เนื้อหา bullet:**
  - **งบเวลาโมดูล: 105 นาที** — บรรยาย 60 นาที (14:00–15:00) + LAB 11 + Case Study 45 นาที (15:00–15:45)
  - **2 Sections:** 1) The Troubleshooting Workflow 2) Common Scenarios & Resolution Strategies
  - **แล็บ 3 Exercise:** จุดชนวน Chaos → Top-down Diagnosis → Mitigate & Root Fix ("The Broken Server" Challenge — capstone ของหลักสูตร)
  - ต้องมี: SQL Server 2019+ (แนะนำ **2025 17.x**) · database **AdventureWorks2025** · permission `sysadmin` (แล็บต้องใช้ `KILL`)
  - เป้าหมายระดับ 1–4 ของโมดูล: คิดแบบ Systematic Troubleshooting → ตัดสินใจจาก DMVs/Waits → เดิน Workflow หาคอขวด (Resource vs Concurrency vs Query Design) → ทำ Runbook/Checklist ให้ทีม
- **ภาพ/แผนภาพ:** ไม่ใช้
- **Speaker notes:** พิมพ์งบเวลา (นาที) และจำนวน Exercise ให้ผู้สอนและผู้เรียนเห็นก่อนเริ่มตาม Slide Spec 4.2 — เวลาจริงจากการทดสอบผู้เรียนเฟส 4 ต้องเทียบกับงบนี้ `Ref: Trainer_Docs/Course_Guide_4Days.md:116-117` · `Module_11_Troubleshooting/README.md:5-13` · `Module_11_Troubleshooting/Labs/README.md:12-21`

### สไลด์ 3: ทำไมต้อง Systematic Troubleshooting — 3 สาเหตุหลัก

- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา bullet:**
  - **Troubleshooting คือการหา Root Cause ด้วยหลักฐาน** ไม่ใช่เดาสุ่ม — ปัญหา Performance มักอยู่ใน **1 ใน 3 กลุ่ม** เท่านั้น
  - **Resource Bottleneck** — CPU / Memory / Disk อิ่มตัว (Saturation)
  - **Concurrency** — Blocking Chains, Deadlocks, Latch Contention
  - **Query Design** — Missing Index, Bad Plan, Parameter Sniffing
  - เชื่อมองรวมกับ M1–M10: Waits (M1) · Lock (M5) · Index/Statistics (M6) · Plan/Cache (M7–M8) · Monitoring (M10) — โมดูลนี้คือจุดที่ทุกอย่างมาบรรจบกัน
- **ภาพ/แผนภาพ:** ไม่บังคับ — วาดไดอะแกรม 3 กลุ่มสาเหตุเป็น PNG ได้ถ้าต้องการ
- **Speaker notes:** **ต้องรู้มาก่อน:** wait type และ DMV จาก Module 1 — ลิงก์ glossary กลางตามแผนเฟส 0 (ไฟล์ glossary ยังไม่มีใน repo ต้องสร้างก่อนเปิดสอน) · **ต้องเขียนเนื้อหาเพิ่ม:** S1 ยังเป็น outline 65 บรรทัด ไม่มี "ตรวจความเข้าใจ" และไม่มีบล็อกโค้ด SQL `Ref:` Module_11_Troubleshooting/Sections/01_Troubleshooting_Workflow/README.md:5-7`

### สไลด์ 4: The Troubleshooting Workflow — 4 Steps + Flowchart

- **Layout:** `bullets+diagram` → potx `03 Content`
- **เนื้อหา bullet:**
  - **Step 1 Define the Problem:** กำหนดขอบเขตก่อนลงมือ — Scope (ใครได้รับผลกระทบ) / Timeline (Consistent vs Intermittent) / Locality (Module/Report ใด)
  - **Step 2 Validate Server Health:** CPU Utilization · Memory Pressure/OS Paging · I/O Latency — ทรัพยากรพื้นฐานผิดปกติหรือไม่
  - **Step 3 Check Wait Statistics:** ค่าสะสมดูภาพรวม + แบบ real-time จาก `sys.dm_exec_requests` ดู Blocking ปัจจุบัน
  - **Step 4 Identify the Root Cause:** จำแนก Index/Query Design vs Concurrency vs Resource Bottleneck แล้วเลือกทางแก้
  - หลักตัดสินจาก Flowchart: Resource เสีย → ไล่ Resource Bottleneck · Resource ปกติ → ดู Waits → Blocking? → Bad Plan? → XEvents
- **ภาพ/แผนภาพ:** **ต้องวาดใหม่ (ยังไม่มีใน repo):** `Module_11_Troubleshooting/Sections/01_Troubleshooting_Workflow/images/troubleshooting-flowchart.png` กว้าง ≥2400px — เรนเดอร์ flowchart จาก mermaid ใน S1 README:46-59 (User Reports Slowness → Resource Health? → Wait Stats → Blocking? → Bad Plan? → XEvents)
- **Speaker notes:** **ต้องรู้มาก่อน:** DMV/wait type (glossary ยังไม่มีไฟล์ — ต้องสร้างก่อนเปิดสอน) · **ต้องเขียนเนื้อหาเพิ่ม:** เกณฑ์ของ capstone ในแผนแม่บทกำหนด "เพิ่ม demo SQL ≥1 บล็อก" — ปัจจุบันทั้ง S1/S2 มี 0 บล็อกโค้ด SQL ต้องขยายพร้อมวาดภาพก่อนประกอบเด็ค `Ref: Module_11_Troubleshooting/Sections/01_Troubleshooting_Workflow/README.md:9-30,46-59`

### สไลด์ 5: Deep Dive — The Hierarchy of Bottlenecks (Chain of Pain)

- **Layout:** `bullets+diagram` → potx `03 Content`
- **เนื้อหา bullet:**
  - ปัญหาประสิทธิภาพ**ส่งต่อผลกระทบเป็นลูกโซ่ (Domino Effect)** — เข้าใจลำดับชั้นช่วยให้แก้ที่ **ต้นเหตุ** ไม่ใช่ปลายเหตุ
  - **Hardware Level (Root):** Disk ช้า → IOPS เต็ม → Response Time สูง
  - **Memory Level (Propagation):** อ่าน Page เข้า Memory ช้า → Thread ต้องรอ (`PAGEIOLATCH`) → ถือ Latch นานขึ้น
  - **Concurrency Level (Symptom):** Latch นาน → ขวาง Thread ที่ต้องการ Page เดียวกัน → Blocking Chain ยาว → User Timeout
  - **"Don't shoot the messenger":** เจอ Blocking อย่าเพิ่งโทษ Locking เสมอ — เช็คก่อนว่าเป็นผลพวงจาก Disk/CPU หรือไม่
- **ภาพ/แผนภาพ:** **ต้องวาดใหม่ (ยังไม่มีใน repo):** `Module_11_Troubleshooting/Sections/01_Troubleshooting_Workflow/images/chain-of-pain.png` กว้าง ≥2400px — ลูกโซ่ 3 ชั้น Hardware → Memory → Concurrency พร้อม wait type ประกอบแต่ละชั้น
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม:** Deep Dive นี้มีใน README แค่ 13 บรรทัด ต้องขยายพร้อมตัวอย่างจริง (เช่น PAGEIOLATCH จาก missing index) และวาดภาพก่อนประกอบเด็ค (M11 ยังไม่มี tracked PNG เลย) `Ref: Module_11_Troubleshooting/Sections/01_Troubleshooting_Workflow/README.md:32-44`

### สไลด์ 6: Demo — Server Health Check + Quick Wait Analysis

- **Layout:** `demo` → potx `06 Code Lab`
- **เนื้อหา bullet:**
  - จำลองปัญหาก่อนด้วย `03_Workload_Mixed_Stress.sql` (stress ผสม CPU+I/O+Memory 5 นาที) แล้ววินิจฉัย
  - รัน `04_Server_Health_Check.sql` — CPU % จาก Ring Buffer (`RING_BUFFER_SCHEDULER_MONITOR`) · Memory จาก `sys.dm_os_sys_memory` · config `min/max server memory` · Error Log 24 ชม.ล่าสุด (`xp_readerrorlog`)
  - รัน `05_Quick_Wait_Analysis.sql` — Top 10 waits กรอง benign waits **72 ตัว** แล้วแปลง wait_type → likely cause (`LCK%`=Blocking, `PAGEIOLATCH%`=I/O, `SOS_SCHEDULER_YIELD`=CPU) + คำนวณ **Signal Wait %** (สูงเกิน ~20% = สัญญาณ CPU Pressure)
  - **ต้องรู้ก่อน (มติ #9):** CTE (`WITH Waits AS`) = ชุดผลลัพธ์ตั้งชื่อชั่วคราว · window function (`SUM() OVER()`) = รวมค่าทั้งชุดโดยไม่ยุบแถว · XQuery `.value()` = อ่านค่าจาก XML ใน ring buffer
  - **error ที่พบได้:** `The VIEW SERVER STATE permission was denied on object 'server'` → ขอสิทธิ์/ใช้บทบาทที่เหมาะสม · **รุ่นขั้นต่ำ:** SQL Server 2019+ (แนะนำ 2025 17.x) — หมายเหตุ: ไฟล์ .sql โมดูลนี้ยังไม่มี header `MinVersion:` (0/7 ไฟล์) ต้องเติมตามเฟส 0 ก่อนขึ้นเด็คจริง
- **ภาพ/แผนภาพ:** screenshot ผลรันจริงบน 17.x (ยังไม่มี — ต้องรัน sign-off ก่อนจึงเอาขึ้นสไลด์ได้)
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม:** S1 README:23-24 ชี้สคริปต์ข้ามโมดูล (M1 `08_Wait_Stats_Analysis.sql`, M1 Lab Ex3) แทนสคริปต์ของโมดูลเอง — ต้องแก้อ้างอิงให้ตรงตอนขยายเนื้อหา · demo walk-through ทีละขั้นยังไม่มีใน README `Ref: Module_11_Troubleshooting/Sections/01_Troubleshooting_Workflow/Scripts/04_Server_Health_Check.sql` · `Scripts/05_Quick_Wait_Analysis.sql` · `Scripts/03_Workload_Mixed_Stress.sql`

### สไลด์ 7: Scenario A — High CPU Utilization

- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา bullet:**
  - **Potential Cause:** Table/Index Scan ขนาดใหญ่ · Compilation ภาระสูง (Plan Bloat) · Spinlock Contention
  - **Investigation:** หา Top CPU Queries ด้วย `Module_07/Sections/03_Analyzing_Query_Plans/Scripts/06_Top_CPU_Queries.sql` (มีจริงใน repo) + Signal Waits % + scheduler queue จาก M10
  - **Resolution:** Tune Query · สร้าง Index เปลี่ยน Scan → Seek · ปรับ Plan Cache Configuration (เชื่อม M8) และ DOP/CTFP (เชื่อมแล็บ M11)
  - ตำแหน่งใน Workflow: อาการนี้มักจบที่ Step 4 สาขา "Resource Bottleneck" หรือ "Query Design"
- **ภาพ/แผนภาพ:** ไม่บังคับ — screenshot Top CPU query result (ถ่ายเองจาก 17.x)
- **Speaker notes:** **ต้องรู้มาก่อน:** plan cache และ execution plan จาก M7–M8 — ลิงก์ glossary กลาง (ยังไม่มีไฟล์) · **ต้องเขียนเนื้อหาเพิ่ม:** S2 = 24 บรรทัด สั้นสุดของ capstone และมี 0 บล็อกโค้ด SQL ทั้ง section ต้องขยายพร้อม demo SQL ตามเกณฑ์ capstone ก่อนสอน `Ref: Module_11_Troubleshooting/Sections/02_Scenarios_and_Resolution/README.md:5-8`

### สไลด์ 8: Scenario B vs C — Blocking/Deadlocks เทียบ I/O Latency

- **Layout:** `two-column` → potx `04 Two-Column`
- **เนื้อหา bullet:**
  - **ซ้าย (Scenario B — High Blocking/Deadlocks):** สาเหตุ Long-running Transactions · Poor Index Design · Application ไม่ปล่อย Lock
  - **ซ้าย (Investigation):** Blocking Chain จาก `sys.dm_exec_requests` + `sys.dm_tran_locks` (Deadlock cycle จาก M5)
  - **ซ้าย (Resolution):** ปรับ Index · พิจารณา RCSI · แก้ Application Code
  - **ขวา (Scenario C — High I/O Latency):** สาเหตุ Working Set > Memory (Buffer Pool Trashing) · Storage Subsystem ไม่เพียงพอ
  - **ขวา (Investigation):** PerfMon `Avg. Disk sec/Read` · Page Life Expectancy ต่ำ
  - **ขวา (Resolution):** เพิ่ม Memory (Scale-up) · Indexing ลด Physical Reads · Optimize Storage IOPS
- **ภาพ/แผนภาพ:** ไม่ใช้ — โครงสองคอลัมน์เทียบ Cause/Investigation/Resolution เป็นตารางเสมือน
- **Speaker notes:** **ต้องรู้มาก่อน:** lock/lock hierarchy จาก M5 — ลิงก์ glossary กลาง · **ต้องเขียนเนื้อหาเพิ่ม:** สอง scenario นี้อยู่ใน README รวมกันแค่ 9 บรรทัด ต้องขยายตัวอย่าง T-SQL จริงและเชื่อมแล็บ `Ref: Module_11_Troubleshooting/Sections/02_Scenarios_and_Resolution/README.md:10-18`

### สไลด์ 9: Demo — Active Blocking & Top Resource Queries

- **Layout:** `demo` → potx `06 Code Lab`
- **เนื้อหา bullet:**
  - จำลอง blocking ด้วย `01_Chaos_Generator.sql` (session สุ่มเป็น Blocker/CPU Hog/IO Hog) แล้วรัน `06_Active_Blocking.sql` — เห็น Blocked Session ↔ Blocking Session พร้อม **text ของทั้งสอง query** + จับ **Head Blocker** (block คนอื่นแต่ตัวเองไม่ได้รอ)
  - รัน `07_Top_Resource_Queries.sql` — Top 10 จาก `sys.dm_exec_query_stats` จัดอันดับได้ 3 แบบ: **by CPU time / by Logical Reads / by Execution Count** (รันจาก `master`)
  - **ต้องรู้ก่อน (มติ #9):** `CROSS APPLY` = เรียก table-valued function ต่อแถวฝั่งซ้าย (ดึง text จาก `sql_handle`) · `OUTER APPLY` = เหมือนกันแต่คืนแถวซ้ายได้แม้ฝั่งขวาว่าง · `SUBSTRING(text, statement_start_offset/2+1, …)` = ตัดเฉพาะ statement ที่รันจาก batch
  - **error ที่พบได้:** subquery หา blocking query คืน `NULL` เมื่อ head blocker จบ transaction ไปแล้ว (รันซ้ำเร็ว ๆ / ใช้ XEvent `blocked_process_report` แทน) · `VIEW SERVER STATE permission was denied` · **รุ่นขั้นต่ำ:** SQL Server 2019+ — header `MinVersion:` ยังไม่ถูกเพิ่ม (เติมตามเฟส 0)
- **ภาพ/แผนภาพ:** screenshot blocking chain + Top resource list จากการรันจริงบน 17.x (ยังไม่มี — ต้อง sign-off ก่อน)
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม:** demo ใช้สคริปต์ของโมดูลโดยตรงแต่ section README ยังไม่มีขั้นตอน walk-through และไม่อ้างสคริปต์เหล่านี้เลย ต้องเติมตอนขยาย `Ref: Module_11_Troubleshooting/Sections/01_Troubleshooting_Workflow/Scripts/06_Active_Blocking.sql` · `Scripts/07_Top_Resource_Queries.sql` · `Scripts/01_Chaos_Generator.sql`

### สไลด์ 10: จาก Mitigation สู่ Root Fix — และการทำ Runbook ให้ทีม

- **Layout:** `bullets` → potx `03 Content` (แทรกตาราง root fix เป็น `05 Table` ได้)
- **เนื้อหา bullet:**
  - **Mitigate เฉพาะหน้า** = ตัดตัวการให้ระบบกลับมาใช้ได้ทันที (`KILL` head blocker / หยุด query) — แต่ยังไม่แก้ต้นเหตุ ปัญหาจะกลับมา
  - **ยืนยันระบบฟื้น:** รัน diagnosis ซ้ำ — `still_blocked = 0` และ waits คืนระดับ baseline
  - **Root fix ต่ออาการ:** Transaction ค้าง → XEvent `blocked_process_report` + `blocked process threshold` · CPU หนัก → index/plan + DOP/CTFP · Result set ยักษ์ → แก้ query ฝั่ง app (`ASYNC_NETWORK_IO`) · Sort spill → index ลด sort + Memory Grant Feedback
  - **Skill ระดับ 4:** สรุปทุก scenario เป็น **Runbook/Checklist** ให้ทีม DBA/DevOps — ทุกคนแก้ปัญหาได้เป็นระบบเดียวกัน
  - ปิดด้วยวงจร: **"Performance Tuning is a journey, not a destination"** — Monitor + Adapt เสมอ
- **ภาพ/แผนภาพ:** ไม่บังคับ — วงจร Monitor → Diagnose → Mitigate → Root Fix → Monitor วาดใหม่เป็น PNG ได้ถ้าต้องการ
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม:** เป้าหมายหัวข้อนี้วันนี้มีอยู่แค่ในแล็บ Exercise 3 (:142-176) และ bullet Skill ระดับ 4 ของ module README — ต้องยกระดับเป็นเนื้อหา section พร้อมตัวอย่างจริงก่อนสอน `Ref: Module_11_Troubleshooting/Labs/README.md:142-176` · `Module_11_Troubleshooting/README.md:12-13,58-61`

### สไลด์ 11: Lab 11 — "The Broken Server" Challenge (3 Exercise)

- **Layout:** `lab` → potx `06 Code Lab`
- **เนื้อหา bullet:**
  - **Lab 11 — 3 Exercise** (แล็บที่ 11 จาก 11 แล็บ / 40 Exercise ทั้งหลักสูตร): เช้าวันจันทร์ 09:00 ผู้ใช้ 200 คนแจ้ง "ระบบช้ามาก" — มีเวลา 20 นาทีหา root cause และฟื้นระบบ ด้วย framework **Wait Stats → Resource → Query → Index → Config**
  - **Ex1** จุดชนวนความโกลาหล 4 หน้าต่าง: blocking (transaction ค้าง 5 นาที) + CPU loop + I/O result set ยักษ์ + memory grant (sort ใหญ่) แล้วสลับบทบาทเป็น DBA ที่เพิ่งเข้ามาใหม่
  - **Ex2** Top-down Diagnosis: ชั้น Waits (สดจาก `sys.dm_exec_requests` + `CROSS APPLY`) → ชั้น Resource (head blocker ลูกโซ่ + scheduler queue) → ชั้น Query (`dm_exec_query_stats` + Query Store) → ชั้น Config (`sys.configurations`) — ✅ คาดหวังจาก chaos: head blocker 1 ตัว + `LCK_M_X` + `SOS_SCHEDULER_YIELD` + `WRITELOG`
  - **Ex3** Mitigate → Root Fix: `KILL` head blocker → ยืนยัน `still_blocked = 0` → เขียน root fix plan ต่อตารางอาการ (+ Optional ทวนสอบ XEvent session จาก Lab 9)
  - **Prereq:** `sysadmin` (ต้องใช้ `KILL`) · AdventureWorks2025 · SQL Server 2019+ (แนะนำ 2025 17.x) · **Cleanup:** เก็บ baseline snapshot ปิดท้ายใน `DBA_Baseline.dbo.CaptureBaselineSnapshot` ที่สร้างไว้จาก Lab 10
- **ภาพ/แผนภาพ:** ไม่บังคับ
- **Speaker notes:** **ต้องรู้ก่อน (มติ #9):** Ex2 ใช้ CTE, window function, `CROSS APPLY` และ Query Store catalog views (`sys.query_store_query` JOIN `query_store_runtime_stats`) — ผู้เรียนระดับ SELECT/JOIN ต้องได้คำอธิบายก่อนอ่านโค้ด · **error ที่พบได้:** `KILL` ต้องใช้สิทธิ์ sysadmin · **ต้องเขียนเนื้อหาเพิ่ม:** แล็บมีบล็อก expected แบบไม่เป็นมาตรฐานแค่ 1 จุด (`:106` "✅ คาดหวังจาก chaos นี้") ต้อง normalize เป็น `**Expected:**` ครบ 3/3 Exercise และเพิ่มบล็อก "ต้องรู้ก่อน" ตาม DoD `Ref: Module_11_Troubleshooting/Labs/README.md` (Ex1 :24, Ex2 :73, expected :106, Ex3 :142, wrap-up :180, cleanup :186-193)

### สไลด์ 12: สรุปโมดูล + Quiz — ปิดหลักสูตร

- **Layout:** `summary` → potx `08 Closing (dark)` (หรือ `03 Content` ถ้าต้องการพื้นที่ quiz มาก)
- **เนื้อหา bullet:**
  - **Workflow 4 Step + 3 สาเหตุหลัก:** Define → Health → Waits → Root Cause — Wait Stats บอกว่า "รออะไร" แล้วตีความเป็นสาเหตุ (CPU/Blocking/I/O/TempDB/Memory Grant)
  - **Chain of Pain:** แก้ต้นเหตุระดับ Hardware/Memory ก่อนโทษ Concurrency — Don't shoot the messenger
  - **Scenario → Investigation → Resolution** ต่อ CPU / Blocking / I/O และ **Mitigate ≠ Root fix**
  - **Quiz 1:** ขั้นตอนแรกของ Troubleshooting คืออะไร? · **Quiz 2:** Server Resource ปกติแต่ยังบ่นช้า ดูอะไรต่อ? · **Quiz 3:** "Performance Tuning is a journey" หมายความว่าอย่างไร?
  - ปิดหลักสูตร: จากวันนี้ต่อไป — **Monitor (เฝ้าระวัง) + Adapt (ปรับตัว)** ให้ทันกับข้อมูลที่เปลี่ยนตลอดเวลา
- **ภาพ/แผนภาพ:** ไม่ใช้
- **Speaker notes:** **ต้องเขียน quiz bank เพิ่ม:** quiz bank รายโมดูลยังไม่มี (0 ไฟล์ทั้งหลักสูตร) — คำถาม 3 ข้อนี้ดึงชั่วคราวจาก FAQ ของ module README ต้องสร้าง quiz bank M11 ก่อนขึ้นเด็คจริง และเป็นสไลด์ปิดท้ายหลักสูตรให้เชื่อมกลับไปยัง Baseline จาก Lab 10 `Ref: Module_11_Troubleshooting/README.md:37-50,58-63`

---

## เช็คลิสต์การผลิตเด็ค M11 (ก่อนประกอบ .pptx)

- [ ] ขยายเนื้อหา S1/S2 ตาม DoD ราย section (เพิ่ม demo SQL ≥1 บล็อกต่อ section ตามเกณฑ์ capstone + "ตรวจความเข้าใจ" + prereq/glossary) แล้วจึงประกอบสไลด์เนื้อหา (สไลด์ 3–10 ผูกกับเนื้อหาที่ขยาย)
- [ ] วาด `troubleshooting-flowchart.png` + `chain-of-pain.png` ≥2400px ลง `Sections/01_Troubleshooting_Workflow/images/` (สไลด์ 4, 5 ใช้ไม่ได้ถ้ายังไม่มีภาพ)
- [ ] แก้ S1 README:23-24 อ้างสคริปต์ข้ามโมดูล → ชี้ `05_Quick_Wait_Analysis.sql` ของโมดูลเอง · จัดเลขสคริปต์ 01–07 ให้เรียงตาม section · แก้ encoding ไทยเพี้ยนใน `02_Broken_Server_Challenge.sql`
- [ ] เติม header `MinVersion:` + hard guard ให้ .sql ที่อ้างในสไลด์ Code Lab (สไลด์ 6, 9, 11 — ปัจจุบัน 0/7 ไฟล์) และ normalize expected เดิม 1 จุด (Labs:106) เป็น `**Expected:**` ครบ 3/3 Exercise พร้อมบล็อก "ต้องรู้ก่อน"
- [ ] สร้าง glossary กลาง + quiz bank M11 (สไลด์ 3, 4, 7, 8 อ้าง glossary; สไลด์ 12 อ้าง quiz bank)
- [ ] รัน demo/lab จริงบน 17.x เพื่อถ่าย screenshot และ sign-off ตัวเลขก่อนใช้ layout `07 Stat Callout` (เด็คนี้ยังไม่ใช้ Stat Callout — ไม่มีตัวเลขที่ผ่าน sign-off; เกณฑ์ Signal Wait >20% ในสไลด์ 6 คือ threshold จากสคริปต์ ไม่ใช่ตัวเลข sign-off)
