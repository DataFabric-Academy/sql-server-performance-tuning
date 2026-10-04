# Module 10: Monitoring & Tracing — สไลด์ไบล์พรินต์รายสไลด์

> เด็ค M10 จาก 12 เด็ค / 196 สไลด์ของหลักสูตร SQL Server Performance Tuning (4 วัน / 24 ชม.) · Template: `Trainer_Docs/Trainocate_SQLPerfTuning_Template.potx` (8 layouts, 16:9, Leelawadee UI) · ตรวจร่างจากแผนแม่บท `Trainer_Docs/Production_Plan_Course_and_Slides.md` หมวด 4 (มาตรฐานสไลด์) และหมวด 3 (ช่องว่าง M10: outline 2 sections 89–91 บรรทัด, Scripts/ ครบ 2/2, แล็บ 3 Exercise, heading เสีย :55)

**สรุปเด็ค (5 บรรทัด):**
- โครงเด็คตามสูตรมาตรฐาน 4.2 ตายตัว: **12 สไลด์** = โครงโมดูล 4 ใบ (Cover / Module Divider / Lab / Closing) + 4 ใบ × 2 sections (S1 Monitoring & Tracing, S2 Baselining & Benchmarking) · Code Lab **3 ใบ ≤ เพดาน 4 ใบ/โมดูล**
- ทั้งสอง section ยังเป็น outline (89/91 บรรทัด, `grep "ตรวจความเข้าใจ"` = 0) — สไลด์เนื้อหาทุกใบออกแบบตาม **"เป้าหมายของหัวข้อ"** ตามมาตรฐานเด็คหลักสูตร และระบุ **"ต้องเขียนเนื้อหาเพิ่ม"** ใน speaker notes
- ภาพสถาปัตยกรรมต้อง**วาดใหม่ PNG ≥2400px** ที่ `Module_10_Monitoring_Tracing/Sections/01_Monitoring_Tracing/images/` — ตรวจ `git ls-files "*.png"` แล้ว M10 ยังไม่มีภาพเลย (repo มี tracked PNG แค่ 2 ไฟล์ของ M1) และห้ามดึงจากเด็ค 10987C/9Expert (มติ #8)
- สไลด์ Module Divider พิมพ์**งบเวลาโมดูล 150 นาที** (บรรยาย 90 นาที + LAB 10 60 นาที ตามตาราง Day 4 `Course_Guide_4Days.md:113,115`) และสไลด์ Lab พิมพ์**จำนวน 3 Exercise** ตาม Slide Spec 4.2/4.6
- ข้อควรแก้ใน repo ก่อนประกอบเด็คจริง: heading เสีย `## ###` ที่ module README:55 (ตรวจด้วย `grep -n "^## ###"` = 1 ผลลัพธ์) · `03_Baseline_Collection.sql` comment ไทย encoding เพี้ยน (ตรวจด้วย `file` พบ double-encoded UTF-8) · threshold disk latency ขัดกันระหว่าง S1 README:40 (10–15ms) กับ S2 README:38/FAQ (20ms) · ไฟล์ .sql ยังไม่มี header `MinVersion:` (0/69 ไฟล์ทั้ง repo)

---

### สไลด์ 1: Cover — Module 10: Monitoring & Tracing

- **Layout:** `title` → potx `01 Cover (dark)`
- **เนื้อหา bullet:**
  - **Module 10: Monitoring & Tracing** — เฝ้าระวังประสิทธิภาพ (Monitoring) และสร้าง Performance Baseline
  - หลักสูตร SQL Server Performance Tuning — Day 4 (Monitoring, Tuning Strategy & Troubleshooting)
  - คำโปรย: "ไม่มี Baseline ที่ดี = บอกไม่ได้ว่าพฤติกรรมปัจจุบันของระบบ 'ผิดปกติ' หรือไม่"
- **ภาพ/แผนภาพ:** ไม่ใช้ — พื้นหลัง dark ของ layout Cover
- **Speaker notes:** เปิดโมดูลด้วยประโยคจาก README ของโมดูล — Monitoring และ Baselining เป็นขั้นพื้นฐานสำคัญที่สุดของการบริหารประสิทธิภาพ ผู้ดูแลระบบที่ไม่มี Baseline จะระบุไม่ได้ว่าอะไร "ผิดปกติ" `Ref: Module_10_Monitoring_Tracing/README.md:1`

### สไลด์ 2: Module Divider — Monitoring & Baselines (งบเวลา + Exercise)

- **Layout:** `section-divider` → potx `02 Module Divider (dark)`
- **เนื้อหา bullet:**
  - **งบเวลาโมดูล: 150 นาที** — บรรยาย 90 นาที (10:30–12:00) + LAB 10 60 นาที (13:00–14:00)
  - **2 Sections:** 1) Monitoring & Tracing 2) Baselining & Benchmarking
  - **แล็บ 3 Exercise:** สร้างโครงสร้าง Baseline → จำลอง Workload แล้วอ่าน Delta → Daily Health Check
  - ต้องมี: SQL Server 2019+ (แนะนำ **2025 17.x**) · database **AdventureWorks2025** · permission `VIEW SERVER STATE`
  - เป้าหมายระดับ 1–4 ของโมดูล: เข้าใจเครื่องมือ/DMVs → สร้างและอ่าน Baseline → ใช้ Performance Center เป็น Checklist → ออกแบบ Monitoring & Alerting Strategy
- **ภาพ/แผนภาพ:** ไม่ใช้
- **Speaker notes:** พิมพ์งบเวลา (นาที) และจำนวน Exercise ให้ผู้สอนและผู้เรียนเห็นก่อนเริ่มตาม Slide Spec 4.2 — เวลาจริงจากการทดสอบผู้เรียนเฟส 4 ต้องเทียบกับงบนี้ `Ref: Trainer_Docs/Course_Guide_4Days.md:113,115` · `Module_10_Monitoring_Tracing/Labs/README.md:6-21` · `Module_10_Monitoring_Tracing/README.md:3-11`

### สไลด์ 3: DMOs — Snapshot vs Cumulative

- **Layout:** `bullets` → potx `03 Content` (ตาราง DMO แทรกเป็น `05 Table` ได้)
- **เนื้อหา bullet:**
  - **DMOs (Dynamic Management Objects)** = System Views/Functions ที่ให้สถานะ Real-time ว่า "ตอนนี้เกิดอะไรขึ้นใน Engine"
  - **Snapshot DMVs** — สถานะปัจจุบัน: `sys.dm_exec_requests` (active query + wait status + blocking)
  - **Cumulative DMVs** — สะสมตั้งแต่ restart: `sys.dm_os_wait_stats` (reset ด้วย `DBCC SQLPERF`) · `sys.dm_io_virtual_file_stats` (I/O latency ต่อไฟล์)
  - On-demand: `sys.dm_db_index_physical_stats` (Index Fragmentation)
  - ค่า Cumulative ต้อง**เก็บ Delta เทียบ snapshot** จึงบอกได้ว่า "ตอนนี้" มีปัญหาอะไร — ค่าสะสมดิบไม่ใช้ตัดสิน
- **ภาพ/แผนภาพ:** ไม่บังคับ — ใช้ตาราง 4 แถว (DMO / หน้าที่ / Reset เมื่อไร) จาก section README
- **Speaker notes:** **ต้องรู้มาก่อน:** ผู้เรียนต้องรู้ว่า DMV คืออะไรก่อน — ลิงก์ glossary กลางตามแผนเฟส 0 (ไฟล์ glossary ยังไม่มีใน repo ต้องสร้างก่อนเปิดสอน) · **ต้องเขียนเนื้อหาเพิ่ม:** S1 ยังเป็น outline 89 บรรทัด ไม่มี "ตรวจความเข้าใจ" และตารางใน README มีแถวซ้ำ (`sys.dm_db_index_physical_stats` สองจุด) ต้องแก้ตอนขยาย `Ref: Module_10_Monitoring_Tracing/Sections/01_Monitoring_Tracing/README.md:5-20`

### สไลด์ 4: Monitoring Architecture — ข้อมูลถูกเก็บจากไหน

- **Layout:** `bullets+diagram` → potx `03 Content`
- **เนื้อหา bullet:**
  - **SQLOS DMV** (เช่น `sys.dm_os_schedulers`) — อ่านตรงจาก Memory Structure ของ SQL Server (User Mode, เร็วมาก)
  - **Kernel DMV** (เช่น `sys.dm_io_virtual_file_stats`) — ต้องขอข้อมูลจาก Windows (Context Switch → Kernel Mode → มี overhead เล็กน้อยถ้าเรียกถี่เกิน)
  - **PerfMon** — SQL เขียนค่า counter ลง **Shared Memory** ของ Windows เป็นระยะ → PerfMon อ่านจาก memory ไม่กวน Engine (Low Overhead)
  - **Ring Buffers** — "กล่องดำ" ใน memory บันทึกเหตุการณ์สำคัญแบบวนทับ (Error, Memory Broker, Scheduler Monitor) — ดูย้อนหลังได้แม้ไม่เปิด trace แต่ข้อมูลหายเร็วถ้า Event หนาแน่น
- **ภาพ/แผนภาพ:** **ต้องวาดใหม่ (ยังไม่มีใน repo):** `Module_10_Monitoring_Tracing/Sections/01_Monitoring_Tracing/images/monitoring-architecture.png` กว้าง ≥2400px — แผนภาพ SQL Server (DMOs / Ring Buffer) ↔ Windows Shared Memory ↔ PerfMon
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม:** หัวข้อ Deep Dive นี้มีใน README แค่ ~10 บรรทัด ต้องขยายพร้อมวาดภาพก่อนประกอบเด็ค (M10 ยังไม่มี tracked PNG เลย) `Ref: Module_10_Monitoring_Tracing/Sections/01_Monitoring_Tracing/README.md:22-34`

### สไลด์ 5: เครื่องมือ Monitoring — Legacy vs Modern

- **Layout:** `two-column` → potx `04 Two-Column`
- **เนื้อหา bullet:**
  - **ซ้าย (Legacy):** SQL Profiler / Trace — สถานะ **Deprecated**, overhead สูง ไม่แนะนำบน Production
  - **ซ้าย (Legacy):** The Default Trace — ทำงานเบื้องหลัง (Schema Changes, Errors, Auto-grow Events)
  - **ขวา (Modern):** Extended Events (XEvents) — Low Overhead / High Flexibility, เครื่องมือ Tracing หลัก (เจาะลึกใน Module 9)
  - **ขวา (Modern):** Activity Monitor และ Performance Dashboard (SSMS → Reports → Standard Reports) — ภาพรวมเบื้องต้นก่อนลงลึก DMVs/XEvents
  - วิเคราะห์ต่อ: **DTA** (Database Engine Tuning Advisor — แนะนำ index จาก workload) + **Distributed Replay** (จำลอง workload จากหลาย client ก่อน Upgrade)
- **ภาพ/แผนภาพ:** ไม่บังคับ — screenshot Performance Dashboard (ถ่ายเองจาก 17.x ห้ามใช้ภาพเด็คเก่า)
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม:** README มี duplicate heading `### 2.3` สองจุด (PerfMon และ Other Tools) ต้องแก้ตอนขยาย และโยงให้ชัดว่า XEvents จะลงลึกใน Module 9 `Ref: Module_10_Monitoring_Tracing/Sections/01_Monitoring_Tracing/README.md:36-57`

### สไลด์ 6: Demo — Mini-WhoIsActive: ดู Active Queries สด

- **Layout:** `demo` → potx `06 Code Lab`
- **เนื้อหา bullet:**
  - รัน `02_Monitor_Queries.sql` — `sys.dm_exec_requests` JOIN `sys.dm_exec_sessions` + **CROSS APPLY** `sys.dm_exec_sql_text`
  - เห็นต่อ query ที่กำลังรัน: status, `cpu_time`, `wait_type`, `blocking_session_id`, statement text — เรียงตาม CPU (กรองเฉพาะ user process)
  - ใช้เป็น "Mini-WhoIsActive" ทุกครั้งที่มีคนแจ้งว่า "เครื่องช้า" — ตอบได้ทันทีว่าตอนนี้มีอะไรรันอยู่
  - **error ที่พบได้:** `The VIEW SERVER STATE permission was denied on object 'server'` → ใช้บทบาท `##MS_ServerPerformanceStateReader##` (SQL Server 2022+) แทนการให้ sysadmin
  - **รุ่นขั้นต่ำ:** SQL Server 2019+ — หมายเหตุ: ไฟล์ .sql ทั้ง repo ยังไม่มี header `MinVersion:` (0/69) ต้องเติมตามเฟส 0 ก่อนขึ้นเด็คจริง
- **ภาพ/แผนภาพ:** screenshot ผลรันจริงบน 17.x (ยังไม่มี — ต้องรัน sign-off ก่อนจึงจะเอาขึ้นสไลด์)
- **Speaker notes:** **ต้องรู้ก่อน:** `CROSS APPLY` = เรียก table-valued function ต่อแถวด้านซ้าย (ที่นี่ใช้ดึง text ของ query จาก `sql_handle`) — ผู้เรียนระดับ SELECT/JOIN ต้องได้คำอธิบายบรรทัดนี้ก่อนอ่านโค้ด · **ต้องเขียนเนื้อหาเพิ่ม:** ขั้นตอน demo walk-through ยังไม่มีใน section README `Ref: Module_10_Monitoring_Tracing/Sections/01_Monitoring_Tracing/Scripts/02_Monitor_Queries.sql` · `Module_10_Monitoring_Tracing/Labs/README.md:9`

### สไลด์ 7: Baseline vs Benchmark

- **Layout:** `two-column` → potx `04 Two-Column`
- **เนื้อหา bullet:**
  - **Baseline** = สถานะปกติของระบบตามช่วงเวลา (Peak/Off-peak) — ใช้เทียบเพื่อ **Anomaly Detection**
  - **Benchmark** = เป้าหมายหรือขีดจำกัดที่กำหนดไว้ (Performance Goal) พิสูจน์ผ่าน Stress Test
  - **Metrics ที่เก็บ:** Key Resources (CPU / Memory / Disk) + SQL Statistics (`Batch Requests/sec`) + Database Size + **Wait Statistics**
  - **Frequency:** PerfMon ทุก 15–60 วินาที · DMV snapshot ทุก 5–15 นาที
  - **Retention:** 3–6 เดือน เพื่อดูแนวโน้มการเติบโต (Capacity Planning)
- **ภาพ/แผนภาพ:** ไม่บังคับ — กราฟ trend "ปกติ vs ผิดปกติ" วาดใหม่เป็น PNG ได้ถ้าต้องการ
- **Speaker notes:** **ต้องรู้มาก่อน:** wait stats จาก Module 1 — ลิงก์ glossary กลาง (ยังไม่มีไฟล์) · **ต้องเขียนเนื้อหาเพิ่ม:** S2 ยังเป็น outline 91 บรรทัด ไม่มี "ตรวจความเข้าใจ" ต้องขยายตาม DoD ก่อนเปิดเทอม `Ref: Module_10_Monitoring_Tracing/Sections/02_Baselining_Benchmarking/README.md:5-12`

### สไลด์ 8: PerfMon Counters & Thresholds

- **Layout:** `bullets` (เป็นตาราง) → potx `05 Table`
- **เนื้อหา bullet:**
  - **CPU:** `% Processor Time` < 80% (ค่าเฉลี่ย) · `Processor Queue Length` < 2 ต่อ core
  - **Memory:** `Available MBytes` > 500MB · `Page Life Expectancy` — อย่าตัดสินที่ 300s เดิม ให้ดู trend ต่อ NUMA node
  - **Disk:** `Avg. Disk sec/Read` < 20 ms (log file ควร < 5 ms) · `Current Disk Queue Length` < 2
  - **SQL Server:** `Batch Requests/sec` (workload indicator) · `SQL Compilations/sec` < 100 · `Re-Compilations/sec` < 10 · `Lock Waits/sec` < 1 · `Full Scans/sec` เทียบ Baseline
  - รายชื่อ 12 counters หลักที่เก็บจริงอยู่ใน `06_Key_PerfMon_Counters.txt`
  - Threshold เหล่านี้คือ "ค่าเริ่มต้นที่แนะนำ" — ต้องชูกับ Baseline ของเครื่องตัวเองเสมอ
- **ภาพ/แผนภาพ:** ตาราง 4 กลุ่ม (CPU / Memory / Disk / SQL Server) จาก section README
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม** + พบ inconsistency ใน repo ที่ต้อง align ก่อนขึ้นสไลด์: S1 README:40 บอก disk latency "10–15ms" แต่ S2 README:38 และ FAQ ของโมดูลบอก 20ms · threshold เหล่านี้ห้ามใช้ layout `07 Stat Callout` จนกว่าจะผ่าน sign-off รันจริงบน 17.x `Ref: Module_10_Monitoring_Tracing/Sections/02_Baselining_Benchmarking/README.md:18-52` · `Sections/01_Monitoring_Tracing/Scripts/06_Key_PerfMon_Counters.txt` · `Module_10_Monitoring_Tracing/README.md:46-48,61-68`

### สไลด์ 9: เก็บ Baseline อย่างไร + Alerting Strategy

- **Layout:** `bullets` → potx `03 Content`
- **เนื้อหา bullet:**
  - **PerfMon:** สร้าง *Data Collector Sets* บันทึก `.blg` อัตโนมัติ แล้ววิเคราะห์ด้วย PAL (Performance Analysis of Logs)
  - **DMVs:** Scheduled Job (SQL Agent) เก็บ snapshot ของ `sys.dm_os_wait_stats` แล้วคำนวณ **Delta** เพื่อวิเคราะห์ Wait Profile ต่อช่วงเวลา
  - **Load & Stress Testing:** Diskspd (วัด Max IOPS/Throughput ของ storage) · Distributed Replay (replay trace หลาย client — ใกล้เคียงจริงกว่า Profiler Replay)
  - **Alerting threshold เริ่มต้น:** CPU > 80% นาน > 15 นาที · `SIGNAL_WAIT%` > 10% ต่อเนื่อง · log file latency > 5 ms · tempdb growth > 80% · Query Store regressed query ใหม่
  - ผูกเครื่องมือภายนอก: SCOM / Azure Monitor / Grafana-Prometheus + SQL Agent Alerts + Database Mail (+ dbatools สำหรับ automation)
- **ภาพ/แผนภาพ:** ไม่บังคับ
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม:** หัวข้อ alerting และเครื่องมือภายนอกมีอยู่แค่ bullet สั้น ๆ ใน module README (Skill Progression ระดับ 4 + Alerting Threshold) และในตาราง Day 4 ของ Guide ต้องขยายใน section ก่อนสอน `Ref: Module_10_Monitoring_Tracing/Sections/02_Baselining_Benchmarking/README.md:14-16,54-56` · `Module_10_Monitoring_Tracing/README.md:10-11,70-72` · `Trainer_Docs/Course_Guide_4Days.md:113`

### สไลด์ 10: Demo — Persistent Baseline (Wait Stats History)

- **Layout:** `demo` → potx `06 Code Lab`
- **เนื้อหา bullet:**
  - รัน `03_Baseline_Collection.sql`: สร้างตาราง `dbo.WaitStats_History` + proc `usp_CaptureWaitStats` เก็บ TOP 20 waits ลง Table (กรอง `%SLEEP%` / `%QUEUE%`)
  - รัน `01_Workload_Noise.sql` สร้าง background noise 2 นาที (random read + CPU math) แล้วเก็บ snapshot ซ้ำ — เห็น trend ต่อเวลา
  - เทียบกับ delta แบบ 30 วินาทีจาก `05_Wait_Stats_Baseline.sql` (กรอง benign waits **76 ตัว** แล้วแยก Resource Wait / Signal Wait)
  - **error ที่พบได้:** `Invalid object name 'Sales.SalesOrderDetail'` = ยังไม่มี AdventureWorks2025 หรือลืม `USE` database ก่อนรัน
  - **รุ่นขั้นต่ำ:** SQL Server 2019+ (header `MinVersion:` ยังไม่ถูกเพิ่มในไฟล์ — เติมตามเฟส 0)
- **ภาพ/แผนภาพ:** screenshot ตาราง `WaitStats_History` แสดง trend ข้าม snapshot (ต้องรันจริงก่อน)
- **Speaker notes:** **ต้องรู้ก่อน:** `INSERT … SELECT TOP (20) … ORDER BY wait_time_ms DESC` = เก็บเฉพาะ Top waits ต่อรอบ snapshot · **ต้องเขียนเนื้อหาเพิ่ม** + **คำเตือนการผลิต:** `03_Baseline_Collection.sql` comment ภาษาไทยเพี้ยน (ตรวจด้วย `file` แล้วเป็น double-encoded UTF-8 ไม่ใช่ UTF-8 ปกติ) — ต้องแก้ encoding ก่อนใช้สอน `Ref: Module_10_Monitoring_Tracing/Sections/02_Baselining_Benchmarking/Scripts/03_Baseline_Collection.sql` · `Scripts/01_Workload_Noise.sql` · `Sections/01_Monitoring_Tracing/Scripts/05_Wait_Stats_Baseline.sql`

### สไลด์ 11: Lab 10 — Baseline Collection & Daily Health Check (3 Exercise)

- **Layout:** `lab` → potx `06 Code Lab`
- **เนื้อหา bullet:**
  - **Lab 10 — 3 Exercise** (แล็บที่ 10 จาก 11 แล็บ / 40 Exercise ทั้งหลักสูตร): รับช่วง server ที่ไม่มีใครรู้ "ปกติของมัน" → สร้าง Performance Baseline เก็บทุก 15 นาที
  - **Ex1** สร้างโครงสร้าง Baseline: DB `DBA_Baseline` + ตาราง `WaitSnapshot`/`FileIOSnapshot` + proc `CaptureBaselineSnapshot` + SQL Agent Job ทุก 15 นาที (+ Database Mail/Operator เมื่อ job fail)
  - **Ex2** จำลอง workload แล้วจับ snapshot 2 ครั้งคำนวณ Delta — อ่าน wait type: `SOS_SCHEDULER_YIELD`=CPU · `PAGEIOLATCH_*`=disk read · `WRITELOG`=log write · `LCK_M_*`=blocking
  - **Ex3** Daily Health Check สไตล์ Glenn Berry: CPU จาก Ring Buffer, PLE/Buffer Pool, I/O latency, schedulers ที่มี runnable queue, Query Store ที่ยังปิด, last backup (+ รันชุด SQL Server 2025 Diagnostic Queries เต็ม)
  - **Prereq:** `VIEW SERVER STATE` (แนะนำบทบาท `##MS_ServerPerformanceStateReader##`) · AdventureWorks2025 · SQL Server 2019+ (แนะนำ 2025 17.x) · Cleanup: เก็บ `DBA_Baseline` ไว้ใช้ต่อใน Lab 11
- **ภาพ/แผนภาพ:** ไม่บังคับ
- **Speaker notes:** **ต้องรู้ก่อน (มติ #9):** Ex2 ใช้ **CTE** (`WITH FirstSnap AS (…)` = ชุดผลลัพธ์ตั้งชื่อชั่วคราวสำหรับ query ถัดไป) และ **window function** (`ROW_NUMBER() OVER (ORDER BY …)` = จัดอันดับแถวภายในชุดผลลัพธ์) — ผู้เรียนระดับ SELECT/JOIN ต้องอ่านโค้ดออกก่อนลงมือ · **error ที่พบได้:** `VIEW SERVER STATE permission was denied` · **ต้องเขียนเนื้อหาเพิ่ม:** แล็บยังไม่มีบล็อก `**Expected:**` ต่อ Exercise (ตรวจ `grep -c "Expected"` = 0) และไม่มีบล็อก "ต้องรู้ก่อน" — ต้อง normalize ตาม DoD ก่อนถือว่าแล็บพร้อม `Ref: Module_10_Monitoring_Tracing/Labs/README.md` (Exercise 2 delta query ที่ :135-149, คำถามท้ายแล็บ :201-205)

### สไลด์ 12: สรุปโมดูล + Quiz

- **Layout:** `summary` → potx `08 Closing (dark)` (หรือ `03 Content` ถ้าต้องการพื้นที่ quiz มาก)
- **เนื้อหา bullet:**
  - DMOs แบ่งเป็น **Snapshot vs Cumulative** — ค่าสะสมไม่บอก "ตอนนี้" ต้องเก็บ **Delta เทียบ snapshot** เสมอ
  - ชุดเครื่องมือปัจจุบัน: XEvents + Query Store + Glenn Berry Diagnostic Queries + dbatools (Profiler = Deprecated)
  - **Baseline ≠ Benchmark** — เก็บ Metrics / Frequency / Retention (3–6 เดือน) ให้ครบจึงแยก "ปกติ" กับ "ผิดปกติ" ได้
  - **Quiz 1:** Baseline กับ Benchmark ต่างกันอย่างไร? · **Quiz 2:** DMV ตัวไหนใช้ตรวจ Active Queries? · **Quiz 3:** `Avg. Disk sec/Read` เท่าไหร่ถือเริ่มมี Bottleneck?
  - ต่อไป: **Module 11 Troubleshooting (capstone)** — ใช้ `DBA_Baseline` ที่สร้างไว้ในแล็บนี้ต่อ
- **ภาพ/แผนภาพ:** ไม่ใช้
- **Speaker notes:** **ต้องเขียน quiz bank เพิ่ม:** quiz bank รายโมดูลยังไม่มี (0 ไฟล์ทั้งหลักสูตร) — คำถาม 3 ข้อนี้ดึงชั่วคราวจาก FAQ ของ module README ต้องสร้าง quiz bank M10 ก่อนขึ้นเด็คจริง `Ref: Module_10_Monitoring_Tracing/README.md:35-48` · `Module_10_Monitoring_Tracing/Labs/README.md:207-215`

---

## เช็คลิสต์การผลิตเด็ค M10 (ก่อนประกอบ .pptx)

- [ ] ขยายเนื้อหา S1/S2 ตาม DoD ราย section แล้วจึงประกอบสไลด์เนื้อหา (สไลด์ 3–10 ผูกกับเนื้อหาที่ขยาย)
- [ ] วาด `monitoring-architecture.png` ≥2400px ลง `Sections/01_Monitoring_Tracing/images/` (สไลด์ 4 ใช้ไม่ได้ถ้ายังไม่มีภาพ)
- [ ] แก้ module README heading เสีย `## ###` (:55) · แก้ encoding `03_Baseline_Collection.sql` · align threshold disk latency (10–15ms vs 20ms)
- [ ] เติม header `MinVersion:` + hard guard ให้ .sql ที่อ้างในสไลด์ Code Lab (สไลด์ 6, 10, 11) และ normalize `**Expected:**` 3 จุดในแล็บ
- [ ] สร้าง glossary กลาง + quiz bank M10 (สไลด์ 3, 7 อ้าง glossary; สไลด์ 12 อ้าง quiz bank)
- [ ] รัน demo/lab จริงบน 17.x เพื่อถ่าย screenshot และ sign-off ตัวเลขก่อนใช้ layout `07 Stat Callout` (เด็คนี้ยังไม่ใช้ Stat Callout — ไม่มีตัวเลขที่ผ่าน sign-off)
