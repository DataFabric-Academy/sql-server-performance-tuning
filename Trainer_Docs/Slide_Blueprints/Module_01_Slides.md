# สไลด์ไบล์พรินต์ — Module 01: Architecture, Scheduling & Waits (เด็คนำร่อง 24 สไลด์)

> **โครงเด็ค 24 สไลด์ตามสูตรแผนแม่บท 4.2 (4 โครง + 4 สไลด์/section × 5 sections):** Cover(1) · Module Divider(2) · S1(3-6) · S2(7-10) · S3(11-14) · S4(15-18) · S5(19-22) · Lab(23) · Closing(24) — map token→layout ตาม 4.3: title→01 Cover (dark), section-divider→02 Module Divider (dark), bullets/bullets+diagram/quiz→03 Content, two-column→04 Two-Column, demo/lab→06 Code Lab, summary→08 Closing (dark)
> **Code Lab 3 ใบ (สไลด์ 10, 18, 23) ≤ เพดาน 4** · ทุกสไลด์มี Speaker notes พร้อม token `Ref:` 100%
> **สไลด์ 02 Module Divider พิมพ์งบเวลาโมดูล 150 นาที (บรรยาย 90 + LAB 60 — ตารางวันที่ 1 ใน Course_Guide_4Days.md) + จำนวน Exercise = 4** · สไลด์ Lab พิมพ์จำนวน Exercise + `Ref:` แล็บ
> **ภาพ:** มีจริงใน repo 2 ไฟล์ (`git ls-files "*.png"`) — engine-architecture.png 2431×1373 (ผ่าน ≥2400px) และ thread-life-cycle.png **1484×1158 (ต่ำกว่าเกณฑ์ ต้อง re-export)** + ต้องวาดใหม่ 1 ชิ้น (numa-topology.png)
> **ช่องว่างที่ไบล์พรินต์พึ่งพา (แจ้งใน notes ของสไลด์ที่เกี่ยว):** glossary ยังไม่มีใน repo (`find . -iname "*glossary*"` = 0 ไฟล์ — สร้างเฟส 0) · Scripts/ ยังขาด 3 sections (S1, S3, S5 — S2 มี 4 ไฟล์, S4 มี 4 ไฟล์) · .sql ทั้ง 8 ไฟล์ยังไม่มี header `MinVersion:` · เนื้อหา section M1 ครบมาตรฐาน 5/5 ตามแผนแม่บท จึงไม่มี section ใด "บาง" — จุดที่ติด "ต้องเขียนเนื้อหาเพิ่ม" คือ asset ประกอบ (ภาพ/สคริปต์) เท่านั้น

---

### สไลด์ 1: Cover — Module 01: Architecture, Scheduling & Waits
- **Layout:** title → potx `01 Cover (dark)`
- **Bullets:**
  - SQL Server Performance Tuning — หลักสูตร 4 วัน / 24 ชั่วโมง
  - Module 01: Architecture, Scheduling & Waits — เด็คนำร่องของหลักสูตร
  - วันที่ 1 · บรรยาย 09:30–11:00 + LAB 11:00–12:00
  - ผู้สอน / วันที่อบรม: (เติมก่อนประกอบเด็คจริง)
- **ภาพ/แผนภาพ:** ไม่มี — ใช้พื้นหลังของ layout 01 จาก template (ฟอนต์ Leelawadee UI ผ่าน placeholder เท่านั้น)
- **Speaker notes:** เปิดโมดูลแรกด้วยประโยคเดียว — โมดูลนี้คือ "แผนที่" ที่โมดูลถัดไป (I/O, Memory, Concurrency, Query) จะซูมเข้าไปทีละส่วน **Ref:** Module_01_Architecture_Scheduling_Waits/README.md

### สไลด์ 2: Module Divider — แผนที่โมดูล และงบเวลา
- **Layout:** section-divider → potx `02 Module Divider (dark)`
- **Bullets:**
  - งบเวลาโมดูล: **150 นาที** (บรรยาย 90 นาที + LAB 60 นาที)
  - LAB 1: Wait Statistics & CPU Pressure — **4 Exercise**
  - เส้นทาง 5 sections: Engine/SQLOS → Scheduling → NUMA → Wait Statistics → Modern Features 2025
  - เป้าหมายปลายทาง: อ่านคอขวดจาก DMV ได้เอง ไม่เดาจาก Task Manager
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** พิมพ์งบเวลาและจำนวน Exercise ให้ผู้เรียนเห็นก่อนเริ่มตาม Slide Spec 4.2 — เวลาจริงจากการทดสอบผู้เรียน (เฟส 4) ต้องนำมาเทียบงบนี้ **Ref:** Trainer_Docs/Course_Guide_4Days.md (ตารางวันที่ 1) + Module_01_Architecture_Scheduling_Waits/Labs/README.md

### สไลด์ 3: Section Divider — 1.1 Engine Architecture & SQLOS
- **Layout:** section-divider → potx `02 Module Divider (dark)`
- **Bullets:**
  - "ระบบช้า" — query หนึ่งคำสั่งเดินทางผ่านชั้นไหน และคอขวดซ่อนอยู่ชั้นไหนได้บ้าง?
  - แผนที่ 5 ชั้น: Protocol → Query Execution → Buffer Pool → Storage Engine → SQLOS
  - เป้าหมาย: เล่าเส้นทางของ query ได้ครบทุกชั้น + รู้ว่าแต่ละชั้นวัดอะไรได้
- **ภาพ/แผนภาพ:** ไม่มี (แผนภาพจริงอยู่สไลด์ถัดไป)
- **Speaker notes:** **ต้องรู้มาก่อน:** นิยาม DMV / scheduler / wait type อยู่ที่ Trainer_Docs/Glossary.md (สร้างในเฟส 0 — วันนี้ยังไม่มีไฟล์ใน repo) คู่กับ Module 0 ฉบับขั้นต่ำ — เพื่อกันกำแพงผู้เรียนจุดที่ section ใช้ `sys.dm_os_schedulers` โดยยังไม่เคยนิยาม DMV (README:108) **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/01_Engine_Architecture_SQLOS/README.md

### สไลด์ 4: แผนที่ SQL Server Database Engine — 5 ชั้น
- **Layout:** bullets+diagram → potx `03 Content`
- **Bullets:**
  - Protocol layer: TDS/SNI — Shared Memory / Named Pipes / TCP/IP; TDS 8.0 (2022+) บังคับ TLS 1.3 ก่อน TDS session
  - Query execution layer: Command Parser → Query Optimizer (Cost-based ดู Statistics) → Query Executor
  - จุดตัดสินใจสำคัญที่สุดของ diagram: **"มี Plan อยู่ใน Plan Cache หรือไม่?"** — hit = ข้าม compile, miss = สร้าง plan ใหม่แล้วเก็บ
  - Storage engine layer: Access Methods → Buffer/Page/Transaction/Lock Manager + เส้นทาง Log Cache → Log Writer (Write-Ahead Logging)
  - SQLOS layer: Thread Scheduling (cooperative, quantum ~4 ms) + Memory Management — ฐานรองรับทุกชั้น
  - แผนภาพนี้คือแผนที่หลักของหลักสูตร — M2 I/O, M3 โครงสร้าง, M4 Memory, M7/M8 Query + Plan Cache จะซูมทีละส่วน
- **ภาพ/แผนภาพ:** `Sections/01_Engine_Architecture_SQLOS/images/engine-architecture.png` (มีจริงใน repo — ตรวจขนาดจาก IHDR ได้ 2431×1373 ผ่านเกณฑ์ ≥2400px)
- **Speaker notes:** เดินภาพจากบนลงล่างชั้นละ 1 ประโยค ยังไม่ลงลึก Optimizer — ให้ผู้เรียนถ่ายรูปแผนภาพนี้เก็บไว้ทั้งคอร์ส **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/01_Engine_Architecture_SQLOS/README.md (หัวข้อ 1–5)

### สไลด์ 5: Buffer Pool — Plan Cache vs Data Cache
- **Layout:** two-column → potx `04 Two-Column`
- **Bullets:**
  - ซ้าย — **Plan Cache:** เก็บ compiled execution plans; ใช้ซ้ำเมื่อ query/parameter เดิม; บวมผิดปกติ = ad-hoc workload pollution (ลึกที่ M8)
  - ขวา — **Data Cache:** เก็บ data pages (8 KB) ที่อ่านจาก disk; page อยู่ในนี้ = Logical Read ไม่ต้องแตะ disk
  - Logical Read vs Physical Read — ตัวชี้วัดแรกที่แยก "ช้าเพราะ CPU/Plan" ออกจาก "ช้าเพราะ Storage"
  - อายุเฉลี่ยของ page ใน Data Cache = PLE (Page Life Expectancy) — ต้องอ่านต่อ NUMA node (ต่อยอด M4)
- **ภาพ/แผนภาพ:** ไม่มี (จะซูมกล่อง Buffer Pool ฝั่งขวาของ engine-architecture.png ประกอบได้)
- **Speaker notes:** ชี้ว่าทั้งสองที่พักอยู่ในก้อน memory เดียวกัน (Buffer Pool) ต่างกันแค่ "เก็บอะไร ใครใช้" **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/01_Engine_Architecture_SQLOS/README.md (หัวข้อ 3)

### สไลด์ 6: เดินทางของ Query — 8 ขั้นตามลูกศรในแผนภาพ
- **Layout:** bullets → potx `03 Content`
- **Bullets:**
  - ขั้น 1–2: TDS packet ผ่าน SNI (TCP/IP) → Command Parser ตรวจ syntax
  - ขั้น 3–4: Optimizer ถาม "มี Plan หรือไม่?" (ครั้งแรกสร้าง + เก็บ cache / ครั้งถัดไป reuse) → Executor สั่งงาน Access Methods ทีละ operator
  - ขั้น 5: Buffer Manager / Page Manager — page ใน Data Cache = Logical Read, ไม่มี = อ่านจาก Data Files จริง
  - ขั้น 6: Transaction Manager เขียน Transaction Log ก่อนเสมอ (WAL — ต้นตอ wait `WRITELOG`) + Lock Manager กัน transaction เหยียบกัน
  - ขั้น 7–8: SQLOS จัดคิว CPU ตลอดทาง → ผลลัพธ์กลับ client — client รับไม่ทัน = `ASYNC_NETWORK_IO`
  - คำถามชวนคิด: query เดียว "ช้า" ได้จากกี่จุด? — ตอบได้ทุกจุด = ต้องวัดด้วย DMVs (`sys.dm_os_*`) ไม่เดา — Task Manager ของ Windows ไม่พอ
- **ภาพ/แผนภาพ:** engine-architecture.png แบบมีเลขกำกับ 1–8 (ใช้ซ้ำจากสไลด์ 4 หรือแสดงลิสต์เลขอย่างเดียว)
- **Speaker notes:** ทำ "แบบฝึกหัดคิด" จาก README หัวข้อ 6 กับผู้เรียนสด — ให้แต่ละคนเดาจุดที่ query ช้าได้ก่อน แล้วค่อยเฉลยครบ 6 จุด **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/01_Engine_Architecture_SQLOS/README.md (หัวข้อ 6 + สรุป)

### สไลด์ 7: Section Divider — 1.2 Scheduling: Windows vs SQL Server
- **Layout:** section-divider → potx `02 Module Divider (dark)`
- **Bullets:**
  - ทำไม DBA ต้องเข้าใจ Scheduler — CPU scheduling เป็นคอขวดอันดับต้น ๆ ไม่ใช่แค่ disk/index
  - SQL Server ไม่ปล่อยให้ Windows จัดคิว — สร้างระบบจัดคิวของตัวเอง: **SQLOS Scheduler**
  - จำรูปเดียวให้ได้: Thread Life Cycle (State Machine) — แล้วอ่านต่อได้ทั้ง section
  - ปลายทาง: อ่านสัญญาณ CPU pressure จาก runnable queue + Signal Wait Ratio ได้ก่อนคนอื่นหลายก้าว
- **ภาพ/แผนภาพ:** ไม่มี (ภาพจริงอยู่สไลด์ 9)
- **Speaker notes:** **ต้องรู้มาก่อน:** Section 1.1 (SQLOS, task/worker/scheduler) + ศัพท์ scheduler/wait type ใน Trainer_Docs/Glossary.md **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/02_Scheduling_Windows_vs_SQL/README.md

### สไลด์ 8: Preemptive (Windows) vs Cooperative (SQL Server)
- **Layout:** two-column → potx `04 Two-Column`
- **Bullets:**
  - ซ้าย — **Windows (Preemptive):** OS สั่งหยุด thread เมื่อหมด Time Slice; quantum ~15.6 ms; context switch OS-managed (overhead สูง); ผู้ควบคุม = Windows Kernel
  - ขวา — **SQL Server (Non-Preemptive/Cooperative):** worker Yield เองเมื่อทำงานเสร็จหรือต้องรอ; quantum ~4 ms; context switch เบากว่ามาก; ผู้ควบคุม = SQLOS
  - เหตุผลที่เลือก Cooperative: SQL Server รู้บริบทของงานดีกว่า OS (รอ I/O/Lock → ยอมแพ้ CPU ทันที) + คุม fairness ของคิวเอง
  - ⚠ **lightweight pooling (fiber mode) deprecated ใน SQL Server 2025** — cooperative scheduling คือโมเดลเดียวที่ Microsoft สนับสนุน อย่าตั้งค่านี้บน production
- **ภาพ/แผนภาพ:** ไม่มี (mermaid sequence ใน README ใช้เป็นแนววาดเพิ่มได้ — ไม่บังคับ)
- **Speaker notes:** ให้ผู้เรียนจำเลขคู่ 15.6 ms vs 4 ms — เลข 4 ms จะกลับมาผูกกับ `SOS_SCHEDULER_YIELD` ใน Section 1.4 **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/02_Scheduling_Windows_vs_SQL/README.md (หัวข้อ 1)

### สไลด์ 9: Thread Life Cycle — State Machine ของ Worker
- **Layout:** bullets+diagram → potx `03 Content`
- **Bullets:**
  - เส้นทางหลัก: task ใหม่ → **RUNNABLE** (ต่อคิว) → **RUNNING ON CPU** → **COMPLETED**
  - รอ I/O/resource (ไม่ใช่ CPU) → **SUSPENDED** (เข้า Waiter list) → resource พร้อม → กลับ **RUNNABLE**
  - ครบ quantum ~4 ms แต่งานยังไม่จบ → Yield กลับ RUNNABLE — บันทึกเป็น wait `SOS_SCHEDULER_YIELD`
  - **State** = worker กำลังทำอะไร / **Scheduler lists** (Worker, Runnable, Waiter, I-O, Timer) = worker กำลังรออะไร — อ่านคู่กันตามแผนภาพ
  - Response Time = Service Time (RUNNING) + Resource Wait (SUSPENDED) + Signal Wait (RUNNABLE)
  - ความยาว Runnable list = `runnable_tasks_count` จาก `sys.dm_os_schedulers`
- **ภาพ/แผนภาพ:** `Sections/02_Scheduling_Windows_vs_SQL/images/thread-life-cycle.png` (มีจริงใน repo — **ตรวจขนาดจาก IHDR ได้ 1484×1158 ต่ำกว่าเกณฑ์ ≥2400px ของ Slide Spec 4.4/DoD สไลด์ข้อ 4 ต้อง re-export ก่อนประกอบเด็ค**)
- **Speaker notes:** เล่า state machine เป็นเรื่องราวตามลูกศร (task เข้าคิว → ได้ CPU → ต้องรอ → กลับคิว) แล้วโยงกลับสมการ Response Time — กติกา 2 ข้อ: หนึ่ง scheduler ให้ CPU ได้ครั้งละหนึ่ง worker, worker ที่รอ resource ต้องออกจาก CPU **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/02_Scheduling_Windows_vs_SQL/README.md (หัวข้อ 2–4)

### สไลด์ 10: Demo — จำลอง CPU Pressure และเห็น SOS_SCHEDULER_YIELD สด
- **Layout:** demo → potx `06 Code Lab`
- **Bullets:**
  - Window B: รัน `03_CPU_Stress_Test.sql` พร้อมกัน 3–4 หน้าต่าง (~60 วินาที) — เวอร์ชันทางเลือก `02_Workload_HighCPU.sql`
  - Window C: ดู scheduler แบบ real-time ด้วย `04_Yield_Mechanism.sql` — `yield_count` / `runnable_tasks_count` ต่อ scheduler
  - ผลที่คาด: `runnable_tasks_count` ค้าง > 0 และ `last_wait_type = SOS_SCHEDULER_YIELD` (quantum exhaustion)
  - **Error ที่พบได้:** "VIEW SERVER STATE permission was denied" → ต้องได้สิทธิ์ VIEW SERVER STATE หรือ role `##MS_ServerPerformanceStateReader##`
  - **รุ่นขั้นต่ำ:** SQL Server 2019+ (แนะนำ 2025 17.x) — ไฟล์ .sql ยังไม่มี header `MinVersion:` ต้องเติมตามเฟส 0
- **ภาพ/แผนภาพ:** ไม่มี (โค้ดบน body ของ layout 06 แบบ monospace)
- **Scripts:** `Module_01_Architecture_Scheduling_Waits/Sections/02_Scheduling_Windows_vs_SQL/Scripts/03_CPU_Stress_Test.sql` · `04_Yield_Mechanism.sql` · `02_Workload_HighCPU.sql`
- **Speaker notes:** **ศัพท์/syntax ต้องรู้ก่อน:** WHILE loop (T-SQL procedural loop ใช้วนคำนวณเพื่อเผา CPU จำลอง workload) และคอลัมน์ `runnable_tasks_count`/`yield_count` ของ `sys.dm_os_schedulers` — อธิบาย 1 บรรทัดก่อนรัน; ย้ำเส้นเชื่อม quantum 4 ms ↔ `SOS_SCHEDULER_YIELD` **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/02_Scheduling_Windows_vs_SQL/README.md (หัวข้อ 4) + Labs/README.md (Exercise 3)

### สไลด์ 11: Section Divider — 1.3 NUMA Architecture
- **Layout:** section-divider → potx `02 Module Divider (dark)`
- **Bullets:**
  - คำถามสถาปัตยกรรมแรกเมื่อ CPU หลาย socket: "memory ตัวไหนอยู่ใกล้ CPU ตัวไหน?"
  - SMP แชร์ bus เดียว — CPU ยิ่งเยอะ bus ยิ่งแน่น → NUMA แบ่ง CPU + Memory เป็น **Node**
  - Local Access เร็ว / Foreign Access ช้ากว่า — "การเดินไปเอา memory ข้าม node มีค่าใช้จ่าย"
  - ปลายทาง: อ่านค่า performance ระดับ node ไม่ใช่ค่ารวมทั้ง instance
- **ภาพ/แผนภาพ:** ไม่มี (ภาพจริงอยู่สไลด์ 12)
- **Speaker notes:** **ต้องรู้มาก่อน:** Section 1.1–1.2 (scheduler/worker) + ศัพท์ NUMA/scheduler ใน Trainer_Docs/Glossary.md **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/03_NUMA_Architecture/README.md

### สไลด์ 12: SMP vs NUMA — Node คือหน่วยความจำใกล้ตัว
- **Layout:** bullets+diagram → potx `03 Content`
- **Bullets:**
  - SMP (Symmetric Multiprocessing): ทุก CPU แชร์ bus เดียวไป memory เดียว — bus เป็นคอขวดของสถาปัตยกรรมเอง
  - NUMA (Non-Uniform Memory Access): Node = กลุ่ม CPU + Local Memory; ข้าม node ผ่าน interconnect — latency สูงกว่าชัดเจน
  - SQL Server จัดการให้อัตโนมัติ: memory node แบ่งตาม NUMA node, scheduler ผูกกับ CPU ใน node ตัวเอง, connection จับคู่ node แบบ round-robin
  - **Hot Add CPU deprecated ใน SQL Server 2025** — วางแผนขนาด CPU ตั้งแต่ต้น อย่าคาดหวังเพิ่ม CPU ระหว่างใช้งาน
- **ภาพ/แผนภาพ:** `numa-topology.png` (Node 0 / Node 1 + interconnect + เส้น Foreign Access) — **ยังไม่มีใน repo (README มีแค่ ASCII diagram) ต้องวาดใหม่เป็น PNG ≥2400px ที่ Sections/03_NUMA_Architecture/images/**
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม:** วาดแผนภาพ `numa-topology.png` (กติกาภาพ Slide Spec 4.4) ก่อนประกอบเด็ค และพิจารณาเติม `Sections/03_NUMA_Architecture/Scripts/` ให้ section นี้ (แผนแม่บท M1: "เติม Scripts/ อีก 3 sections") **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/03_NUMA_Architecture/README.md

### สไลด์ 13: Hardware NUMA vs Software (Soft) NUMA
- **Layout:** two-column → potx `04 Two-Column`
- **Bullets:**
  - ซ้าย — **Hardware NUMA:** มากับ socket ของ mainboard; SQL Server ตรวจพบและใช้อัตโนมัติ; `node_state_desc = ONLINE`
  - ขวา — **Software (Soft) NUMA:** SQLOS สร้างอัตโนมัติ (2016+) เมื่อ logical core ต่อ node เกิน 8; `node_state_desc = ONLINE AUTOMATIC`
  - ตรวจจริง: `SELECT node_id, node_state_desc, online_scheduler_count, active_worker_count, avg_load_balance FROM sys.dm_os_nodes;`
  - เกือบทุก server ยุคใหม่ (core ต่อ socket > 8) จะเห็น `ONLINE AUTOMATIC` — เป็นพฤติกรรมปกติ ไม่ใช่ความผิดปกติ
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ให้ผู้เรียนรัน query บน VM ของตัวเองแล้วอ่าน `node_state_desc` ดัง ๆ — ใช้ประโยชน์จากแล็บ Exercise 1 Step 2 **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/03_NUMA_Architecture/README.md (หัวข้อ 1) + Labs/README.md (Exercise 1)

### สไลด์ 14: ทำไม NUMA จึงสำคัญกับ Performance Tuning
- **Layout:** bullets → potx `03 Content`
- **Bullets:**
  - PLE ต้องอ่าน **ต่อ NUMA node** — ค่ารวมทั้ง instance อ่านไม่ได้ (ต่อยอด Module 4)
  - Parallel query ข้าม node มีต้นทุนสูง — MAXDOP ที่เกินจำนวน core ต่อ node ทำให้ query ข้าม node มากขึ้น
  - Soft-NUMA + Resource Governor = workload isolation ได้ละเอียดขึ้น
  - เก็บ NUMA topology baseline ตั้งแต่วันแรก: `sys.dm_os_sys_info` + `sys.dm_os_nodes` (Glenn Berry diagnostic queries มีหมวด NUMA พร้อมรัน)
  - ห้าม set processor affinity เองโดยไม่มีเหตุผลชัดเจน — ปล่อยให้ SQLOS balance
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** โยงไปหาแล็บ Exercise 1 ที่เก็บทุกค่านี้ — ย้ำว่า baseline วันแรกคือตั๋วเข้างาน troubleshooting ทุกครั้ง เพราะ "ปกติ" ของแต่ละ server ไม่เหมือนกัน **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/03_NUMA_Architecture/README.md (หัวข้อ 2–3)

### สไลด์ 15: Section Divider — 1.4 Wait Statistics
- **Layout:** section-divider → potx `02 Module Divider (dark)`
- **Bullets:**
  - ปรัชญา **Waits & Queues**: ไม่เดา — อ่านบัญชีการรอที่ engine จดไว้ให้เอง คอขวดจริงจัดอันดับให้อยู่แล้ว
  - `sys.dm_os_wait_stats` บันทึกทุกครั้งที่ task หยุดรอ: รออะไร / นานแค่ไหน / กี่ครั้ง
  - สมการที่ต้องจำ: Response Time = Service Time (CPU) + Wait Time (รอ resource)
  - ปลายทาง: จัดอันดับ top waits → แปล wait → resource → แก้ถูกจุด
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** **ต้องรู้มาก่อน:** Section 1.2 (SUSPENDED vs RUNNABLE, Signal Wait) + นิยาม wait type/DMV ใน Trainer_Docs/Glossary.md; Exercise ฝั่งนี้ต้องมีสิทธิ์ VIEW SERVER STATE **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/04_Wait_Statistics/README.md

### สไลด์ 16: อ่าน Wait Statistics อย่างมืออาชีพ
- **Layout:** bullets → potx `03 Content` (แทรกตาราง wait→resource ตามกติกา 4.3)
- **Bullets:**
  - ค่าใน DMV = **สะสมตั้งแต่ restart** → เปรียบเทียบต้องใช้ **delta ระหว่าง snapshot** (เก็บ baseline ทุก 15 นาที — ต่อยอด Module 10)
  - กรอง **benign waits** ~80 รายการ (สไตล์ Glenn Berry) ก่อนจัดอันดับ — benign = การรอปกติของระบบ เช่น `SLEEP_*`, `XE_TIMER_EVENT`
  - Wait map ตามคอขวด: CPU (`SOS_SCHEDULER_YIELD`, `CXPACKET`/`CXCONSUMER`, `THREADPOOL`) · I/O (`PAGEIOLATCH_SH/EX`, `WRITELOG`) · Memory (`RESOURCE_SEMAPHORE`) · Lock (`LCK_M_*`, `PAGELATCH_*`) · Network (`ASYNC_NETWORK_IO`, `PREEMPTIVE_OS_*`)
  - ขั้นตอนวินิจฉัย 5 ขั้น: เก็บ delta → จัดอันดับ top waits → แปล wait → ยืนยันด้วยข้อมูลชั้นที่สอง (file stats / blocking chain) → แก้แล้ววัดซ้ำ
  - อย่าแก้หลายอย่างพร้อมกัน — แก้ทีละอย่างแล้ววัดผล
- **ภาพ/แผนภาพ:** ตาราง wait types จัดกลุ่มตามคอขวด (แทรกตารางบน Content หรือใช้ layout `05 Table` — ไม่แก้ potx)
- **Speaker notes:** อธิบาย "ทำไมต้องกรอง benign waits" ให้ชัดก่อนโชว์โค้ด — ไม่งั้นผู้เรียนจะตกใจเห็น `LAZYWRITER_SLEEP` ติดอันดับ **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/04_Wait_Statistics/README.md (หัวข้อ 1–3)

### สไลด์ 17: Resource Wait vs Signal Wait
- **Layout:** two-column → potx `04 Two-Column`
- **Bullets:**
  - ซ้าย — **Resource Wait:** รอ "ของจริง" — disk, lock, network; คำนวณ = `wait_time_ms − signal_wait_time_ms` (คู่กับ state SUSPENDED)
  - ขวา — **Signal Wait:** ของมาแล้วแต่ "รอ CPU ว่าง" = สัญญาณ CPU pressure (คู่กับ state RUNNABLE)
  - SQL: `SELECT SUM(signal_wait_time_ms)*1.0/SUM(wait_time_ms)*100 AS signal_wait_pct FROM sys.dm_os_wait_stats WHERE wait_time_ms > 0;`
  - เกณฑ์: `signal_wait_pct > 10–15%` ต่อเนื่อง = CPU pressure — ย้อนไปแก้ที่ Scheduling (Section 1.2) ไม่ใช่ disk
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ผูกกลับ State Machine ของ Section 1.2 — SUSPENDED = Resource Wait, RUNNABLE = Signal Wait; ผู้เรียนที่จำแผนภาพได้จะต่อสมการนี้ได้ทันที **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/04_Wait_Statistics/README.md (หัวข้อ 1)

### สไลด์ 18: Demo — จำลอง ASYNC_NETWORK_IO และวิเคราะห์ Top Waits
- **Layout:** demo → potx `06 Code Lab`
- **Bullets:**
  - Window B: รัน `01_Workload_NetworkWait.sql` (SELECT 500,000 แถว ทิ้งไว้ให้ grid ค้าง) — ทางเลือก workload ผสมหลาย wait: `07_Workload_Mixed_Waits.sql`
  - Window C: ตรวจ wait สดจาก `sys.dm_exec_requests` แล้ววิเคราะห์ Top waits ด้วย `08_Wait_Stats_Analysis.sql` (Glenn Berry 2016–2025)
  - เจาะลึก real-time: `05_Wait_Stats_Deep_Dive.sql` — `sys.dm_os_waiting_tasks` (DMV ตอบคำถาม "ทำไมฉันกำลังรอ?")
  - ผลที่คาด: `ASYNC_NETWORK_IO` = SQL Server พร้อมส่งข้อมูลแต่ client/network รับไม่ทัน — แก้ฝั่ง application ไม่ใช่ storage
  - **Error ที่พบได้:** permission denied on VIEW SERVER STATE; `ASYNC_NETWORK_IO` ปรากฏเฉพาะตอน result set ยังส่งไม่จบ — ต้องทิ้งหน้าต่าง results ค้างไว้
  - **รุ่นขั้นต่ำ:** SQL Server 2019+ (แนะนำ 17.x) — ต้องเติม header `MinVersion:` ตามเฟส 0
- **ภาพ/แผนภาพ:** ไม่มี
- **Scripts:** `Module_01_Architecture_Scheduling_Waits/Sections/04_Wait_Statistics/Scripts/01_Workload_NetworkWait.sql` · `05_Wait_Stats_Deep_Dive.sql` · `07_Workload_Mixed_Waits.sql` · `08_Wait_Stats_Analysis.sql`
- **Speaker notes:** **ศัพท์/syntax ต้องรู้ก่อน:** CTE (`WITH Waits AS …` — ตั้งชื่อ result set ชั่วคราวใน query เดียว), window function `SUM(wait_s) OVER ()` (คิดสัดส่วน % โดยไม่ต้อง GROUP BY), `CROSS APPLY` (เรียก table-valued function ต่อหนึ่งแถว เช่น `sys.dm_exec_sql_text`) — อธิบายทั้ง 3 ก่อนเปิดโค้ด + ทำไมต้องกรอง benign waits ~80 รายการ **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/04_Wait_Statistics/README.md + Labs/README.md (Exercise 2, 4)

### สไลด์ 19: Section Divider — 1.5 Modern Features & 2025 Checklist
- **Layout:** section-divider → potx `02 Module Divider (dark)`
- **Bullets:**
  - แนวคิดฐาน (SQLOS, Scheduling, Waits) ไม่เคยเปลี่ยน — แต่รายละเอียดรอบ ๆ เปลี่ยนเร็ว
  - "ประสบการณ์ 10 ปี อาจเป็น 1 ปี ที่ทำซ้ำ 10 รอบ — ถ้ายังใช้ความรู้ยุค 2012 จัดการ server ยุค 2025"
  - แผนของ section นี้: ถอดของเก่าออกจากสมอง ใส่ของใหม่เข้าไป (2019 → 2025) + Checklist วันแรกของ server 2025
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** **ต้องรู้มาก่อน:** เนื้อหาทั้งโมดูล + ศัพท์ deprecated/DMV ใน Trainer_Docs/Glossary.md **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/05_Modern_Features_2025/README.md

### สไลด์ 20: ถอดออกจากสมอง vs ใส่เข้าไปในสมอง
- **Layout:** two-column → potx `04 Two-Column`
- **Bullets:**
  - ซ้าย — **ถอดออก:** `lightweight pooling` (deprecated 2025) · Hot Add CPU (deprecated) · SQL Profiler / SQL Trace → Extended Events (M9) · สูตร PLE = 300 วินาที (ใช้ไม่ได้กับ RAM ยุคใหม่)
  - ขวา — **ใส่เข้าไป:** `sys.dm_exec_query_plan_stats` (2019+, ตั้ง `LAST_QUERY_PLAN_STATS = ON`) — Last Actual Plan จาก plan cache โดยไม่ต้องพึ่ง Query Store
  - ขวา (ต่อ): server role `##MS_ServerPerformanceStateReader##` (2022+) — monitoring account อ่าน DMV ได้โดยไม่ต้อง sysadmin · Glenn Berry 2025 Diagnostic Queries
  - ตีความใหม่: ดู `CXPACKET` คู่กับ `CXCONSUMER` เสมอ — CXCONSUMER สูงตามหลังมักเป็นพฤติกรรมปกติของ parallel plan
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** สไลด์นี้คือ "รายการถอน–ฝาก" ของ DBA ยุคเปลี่ยนรุ่น — ให้ผู้เรียนเช็กว่า production ของตัวเองยังมีของฝั่งซ้ายอยู่หรือไม่ **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/05_Modern_Features_2025/README.md (หัวข้อ 1–2)

### สไลด์ 21: Checklist สำหรับ Server ที่เพิ่งขึ้น SQL Server 2025
- **Layout:** bullets → potx `03 Content`
- **Bullets:**
  - 1. เก็บ topology baseline: `sys.dm_os_sys_info` — `cpu_count`, `socket_count`, `numa_node_count`, `max_workers_count`, `sqlserver_start_time`
  - 2. ให้สิทธิ์ monitoring อย่างปลอดภัย: `ALTER SERVER ROLE ##MS_ServerPerformanceStateReader## ADD MEMBER [monitoring_login];`
  - 3. ตรวจ deprecated settings: `sys.configurations` — `lightweight pooling`, `priority boost`
  - 4. เปิด Last Actual Plan: `ALTER DATABASE SCOPED CONFIGURATION SET LAST_QUERY_PLAN_STATS = ON;`
  - ปิดท้าย: รัน Glenn Berry 2025 Diagnostic Queries เก็บ baseline วันแรก — "ปกติ" ของแต่ละ server ไม่เหมือนกัน
  - ทางไปต่อ: M3 ADR/tempdb governance · M5 Optimized Locking (TID+LAQ) · M7 OPPO + DOP Feedback · M8 Optimized sp_executesql · M9 time-bound XE sessions
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม:** สร้าง `Sections/05_Modern_Features_2025/Scripts/` (เช่น `09_2025_Checklist.sql`) เพื่อยกระดับเช็กลิสต์นี้เป็น Code Lab ได้ตาม Slide Spec 4.6 (ตอนนี้ T-SQL อยู่ใน README เท่านั้น) พร้อม header `MinVersion:` **Ref:** Module_01_Architecture_Scheduling_Waits/Sections/05_Modern_Features_2025/README.md (หัวข้อ 3)

### สไลด์ 22: Quiz — ตรวจความเข้าใจรวบยอด Module 01
- **Layout:** quiz → potx `03 Content`
- **Bullets:**
  - 1. Top waits สูงสุดคือ `CXPACKET` และ `CXCONSUMER` คู่กัน — แปลว่าอะไร?
  - 2. ความแตกต่างระหว่าง Signal Wait และ Resource Wait คืออะไร?
  - 3. สถานะ SUSPENDED หมายถึง worker กำลังทำอะไร?
  - 4. `PAGEIOLATCH_SH` กับ `PAGELATCH_EX` — ตัวไหนเกี่ยวกับ disk ตัวไหนเกี่ยวกับ memory?
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** เฉลย: (1) ส่วนใหญ่เป็นพฤติกรรมปกติของ Parallel Execution — ถ้า CXPACKET สูงโดดจึงจูน Cost Threshold for Parallelism / MAXDOP (2) Signal = ของมาแล้วรอ CPU ว่าง (CPU pressure), Resource = รอของจริง (3) หยุดรอ resource เช่น disk หรือ lock (4) PAGEIOLATCH = disk, PAGELATCH = latch ใน memory (hot page) **Ref:** Module_01_Architecture_Scheduling_Waits/README.md (คำถามท้ายโมดูล) + Sections/04_Wait_Statistics/README.md (ตรวจความเข้าใจ)

### สไลด์ 23: Lab 1 — Wait Statistics & CPU Pressure (4 Exercise)
- **Layout:** lab → potx `06 Code Lab`
- **Bullets:**
  - Lab 1: Wait Statistics & CPU Pressure — **4 Exercise** (งบแล็บ 60 นาที) · Scenario: Proseware Inc. ร้อง "ระบบช้า" แต่ Infrastructure ปฏิเสธเพิ่ม CPU เพราะกราฟแสดง CPU ~60% — พิสูจน์ด้วย DMV
  - Ex1: CPU/NUMA topology — `sys.dm_os_sys_info`, `sys.dm_os_nodes`, `sys.dm_os_schedulers` (Window A)
  - Ex2: วัด Signal Wait Ratio + Top waits แบบกรอง benign waits (Window A)
  - Ex3: จำลอง CPU pressure (Window B) + ตาม runnable queue real-time (Window C)
  - Ex4: จำลอง `ASYNC_NETWORK_IO` — ลูกค้ารับข้อมูลไม่ทัน
  - เตรียม: AdventureWorks2025 + VIEW SERVER STATE (หรือ role `##MS_ServerPerformanceStateReader##`) + SSMS 3 หน้าต่าง query
- **ภาพ/แผนภาพ:** ไม่มี
- **Scripts:** `Module_01_Architecture_Scheduling_Waits/Labs/README.md` — สคริปต์ประกอบ: `Sections/02_Scheduling_Windows_vs_SQL/Scripts/02_Workload_HighCPU.sql`, `03_CPU_Stress_Test.sql`, `04_Yield_Mechanism.sql`, `06_Workload_Active_Queries.sql` + `Sections/04_Wait_Statistics/Scripts/01_Workload_NetworkWait.sql`, `05_Wait_Stats_Deep_Dive.sql`, `07_Workload_Mixed_Waits.sql`, `08_Wait_Stats_Analysis.sql`
- **Speaker notes:** แจ้งจำนวน Exercise = 4 ให้ผู้เรียนวางแผนเวลา; **syntax ต้องรู้ก่อน:** CTE, `SUM() OVER ()`, `CROSS APPLY` (อธิบายก่อนเปิด Ex2 ตามมติ #9) และ `DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR)` เป็น cleanup เฉพาะ VM ทดสอบ — ห้ามรันบน production; error ที่พบได้: permission denied → ใช้ role `##MS_ServerPerformanceStateReader##`; รุ่นขั้นต่ำ SQL Server 2019+ (แนะนำ 17.x) **Ref:** Module_01_Architecture_Scheduling_Waits/Labs/README.md

### สไลด์ 24: Closing — สรุป Module 01 และทางไปต่อ
- **Layout:** summary → potx `08 Closing (dark)`
- **Bullets:**
  - แผนที่ 5 ชั้น + Buffer Pool 2 ที่พัก (Plan Cache / Data Cache) + จุดตัดสินใจ "มี Plan อยู่หรือไม่?"
  - Cooperative Scheduling quantum ~4 ms — **RUNNABLE → RUNNING → SUSPENDED** คือภาษากลางของการวินิจฉัย
  - อ่าน performance ระดับ NUMA node เสมอ ไม่ใช่ค่ารวม (PLE, workers)
  - Waits & Queues: อ่านแบบ delta + กรอง benign waits + แยก Resource vs Signal (>10–15% = CPU pressure)
  - 2025: ถอด lightweight pooling / Hot Add CPU / Profiler / สูตร PLE 300 — ใส่ query_plan_stats / performance reader role / baseline Glenn Berry
  - ถัดไป: Module 02 — I/O Subsystem (เดิน Storage engine layer ต่อ)
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ปิดโมดูลด้วยการทวน "แผนที่" รอบสั้น ๆ แล้วชวนผู้เรียนที่ยังไม่จบแล็บกลับไปจบก่อนเข้า Module 2 **Ref:** Module_01_Architecture_Scheduling_Waits/README.md + Sections/05_Modern_Features_2025/README.md (สรุปท้าย section)
