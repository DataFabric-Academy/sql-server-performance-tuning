# สไลด์ไบล์พรินต์ — Module 9: Extended Events (M09)

- **จำนวนสไลด์:** 12 ตามสูตรตายตัวของแผนแม่บท §4.2 = โครง 4 ใบ (Cover / Module Divider / Lab / Closing) + 4 ใบ × 2 sections — อยู่ในช่วงที่อนุญาต 12–24; Code Lab 2 ใบ (สไลด์ 10, 11) ≤ เพดาน 4 ใบ/โมดูล
- **งบเวลาโมดูล:** สอน 60 นาที (Day 3 15:45–16:00 = 15 นาที + Day 4 09:00–09:45 = 45 นาที) + LAB 9 = 45 นาที (Day 4 09:45–10:30) — อ้าง `Trainer_Docs/Course_Guide_4Days.md:104,111-112`
- **สถานะเนื้อหา:** ทั้ง 2 sections ยังเป็น outline (S1 = 98 บรรทัด, S2 = 46 บรรทัด; `grep "ตรวจความเข้าใจ" Module_09_Extended_Events/Sections/*/README.md` = ไม่พบ — รันจริง 2026-10-01) จึงออกแบบสไลด์ตาม "เป้าหมายของหัวข้อ" และระบุ **"ต้องเขียนเนื้อหาเพิ่ม"** ใน speaker notes ของทุกสไลด์เนื้อหา (สไลด์ 3–10)
- **Dependency:** เนื้อหาโมดูลขยายหลัง M5 เสรี (XE deadlock session ต้องเข้าใจ lock จาก M5 — แผน §3 แถว M9); Code Lab ทุกใบรอ `MinVersion:` header ของ .sql (เฟส 0 — ปัจจุบัน 0/69 ไฟล์) และ glossary กลางยังไม่มีไฟล์จริง (เฟส 0) — ลิงก์ glossary ใน notes ต้องอัปเดต path เมื่อไฟล์เกิด; `AUTO_STOP` ยังไม่เคยพิสูจน์ syntax บน instance จริง (ความเสี่ยง #7) — ห้าม sign-off ก่อนรันบน 17.x
- **ภาพ:** ต้องวาดใหม่ 1 ใบบังคับ (`xe-architecture.png` ≥2400px) + 1 ใบเลือกได้ — ห้ามดึงภาพจากเด็ค 10987C/9Expert (มติ #8); ไฟล์นี้ถูก `.gitignore:66` (`Trainer_Docs/*`) กลืน — ดูคำถามเปิด #3 ของแผน

การ map layout → potx: `title`→01 Cover (dark) [โครงสไลด์ Cover ตาม §4.2], `section-divider`→02, `bullets`/`bullets+diagram`/`quiz`→03 Content, `two-column`→04, ตาราง→05, `demo`/`lab`→06 Code Lab, `summary`→08 Closing (dark) — ห้ามเกิด layout `DEFAULT`

---

### สไลด์ 1: Cover — Module 9: Extended Events (Lightweight Tracing แทน Profiler)
- **Layout:** `title` → potx `01 Cover (dark)`
- **Bullets:**
  1. Module 9: Extended Events — ระบบ Lightweight Tracing ที่ฝังใน SQLOS โดยตรง
  2. แทนที่ SQL Profiler / SQL Trace ที่ deprecated ทั้งหมดแล้ว
  3. จุดขาย: Asynchronous + Early Filtering = Overhead ต่ำมาก
  4. สอนข้าม 2 วัน: Day 3 แนะนำ concept, Day 4 เจาะลึก + Lab 9
- **ภาพ/แผนภาพ:** ไม่ต้องมี (ใช้หน้าปกของเทมเพลต)
- **Speaker notes:** เปิดด้วยสถานการณ์จากแล็บ — "หัวหน้าห้ามใช้ SQL Profiler เด็ดขาด" แล้วโมดูลนี้คือทางรอด Ref: Module_09_Extended_Events/README.md:1-3, Module_09_Extended_Events/Labs/README.md:14

### สไลด์ 2: Module Divider — เป้าหมายโมดูล + งบเวลา
- **Layout:** `section-divider` → potx `02 Module Divider (dark)`
- **Bullets (บังคับพิมพ์งบเวลา + จำนวน Exercise ตาม spec §4.2):**
  1. งบเวลา: สอน 60 นาที (Day 3: 15 นาที + Day 4: 45 นาที) + Lab 9: 45 นาที
  2. แล็บมี **3 Exercise**: query performance / deadlock / long-running + 2025 feature
  3. 2 sections: XE Core Concepts → Working With Extended Events
  4. เป้าทักษะ 4 ระดับ: เข้าใจ Architecture → สร้าง Session → ใช้แก้ปัญหาจริง → ออกแบบ Tracing Strategy
  5. ต้องรู้มาก่อน: Lock & Deadlock จาก Module 5 + พื้นฐาน DMV (ดู glossary กลาง)
- **ภาพ/แผนภาพ:** ไม่ต้องมี
- **Speaker notes:** ประกาศงบเวลาและจำนวน Exercise ให้ผู้เรียนรู้ก่อนเริ่ม — เวลาจริงจากการทดสอบเฟส 4 ต้องนำมาเทียบงบนี้ Ref: Module_09_Extended_Events/README.md:5-13, Trainer_Docs/Course_Guide_4Days.md:104,111-112

### สไลด์ 3: [S1-1] SQL Profiler vs Extended Events — ทำไมต้องเปลี่ยน
- **Layout:** `two-column` → potx `04 Two-Column` (สไลด์แรกของ Section 1)
- **Bullets:**
  1. ซ้าย — SQL Trace/Profiler: Synchronous, Overhead สูง (อาจถึง 30%), กรองข้อมูล **หลัง** เก็บ, Target มี Trace File เดียว, **Deprecated**
  2. ขวา — Extended Events: Asynchronous, Overhead ต่ำมาก (<1%), Early Filtering กรอง **ก่อน** เก็บ, Targets หลากหลาย (Ring Buffer / File / Histogram), Recommended
  3. มาตรฐานปัจจุบันของ Microsoft คือ XEvents 100% — ห้ามเริ่มงาน tracing ใหม่ด้วย Profiler
  4. เชื่อมจาก Module 5: เคยเจอ blocking/deadlock แล้ว — โมดูลนี้จะ "จับมัน" ด้วย XEvents เอง
- **ภาพ/แผนภาพ:** ไม่ต้องมี (เทียบข้อความสองคอลัมน์)
- **Speaker notes:** ต้องรู้มาก่อน: Module 5 (Lock/Deadlock) และคำว่า DMV — ชี้ลิงก์ glossary กลาง (ไฟล์ตามแผนเฟส 0 ยังไม่มีใน repo ณ วันเขียน ต้องอัปเดต path เมื่อสร้างแล้ว) · **ต้องเขียนเนื้อหาเพิ่ม**: S1 ยังเป็น outline — ต้องเติมบรรทัด "ต้องรู้มาก่อน" + ลิงก์ glossary + คำถาม "ตรวจความเข้าใจ" ตาม DoD ราย section Ref: Module_09_Extended_Events/Sections/01_XE_Core_Concepts/README.md:7-18

### สไลด์ 4: [S1-2] XEvents Architecture — 6 องค์ประกอบ
- **Layout:** `bullets+diagram` → potx `03 Content`
- **Bullets:**
  1. **Packages** — คอนเทนเนอร์ Metadata (`package0` system, `sqlserver` engine, `sqlos` scheduler) พร้อม **Types** (ชนิดข้อมูล field) และ **Maps** (แปลง internal ID → ข้อความ เช่น WaitType=120 → ชื่อ wait type)
  2. **Events** — จุดตรวจ (Instrumentation Points) ใน engine เช่น `sql_statement_completed`, `lock_acquired`, `wait_info`
  3. **Predicates** — เงื่อนไขกรองที่ทำงานระดับ engine *ก่อน* เก็บข้อมูล (Early Filtering) = คีย์ลด Overhead
  4. **Actions** — ข้อมูลเสริมจาก Global State (`sql_text`, `plan_handle`) — มี Cost เพิ่ม ใช้เท่าที่จำเป็น
  5. **Targets + Sessions** — ปลายทางจัดเก็บ (Consumers) และการประกอบ Event/Predicate/Target เป็น session เดียว
- **ภาพ/แผนภาพ:** **วาดใหม่เป็น PNG ความกว้าง ≥2400px** ที่ `Module_09_Extended_Events/Sections/01_XE_Core_Concepts/images/xe-architecture.png` — data flow: CodePoint → Event → Predicate → Action → Buffer → Target → (File .xel / RingBuffer) จาก mermaid เดิมใน README; ปัจจุบัน repo ยังไม่มีไฟล์ PNG นี้ (ตรวจ `git ls-files "*.png"` = มีแค่ 2 ไฟล์ของ M1)
- **Speaker notes:** ย้ำลำดับการไหล: กรองให้เร็วที่สุด → เก็บเท่าที่จำเป็น → ค่อย dispatch ออก target Ref: Module_09_Extended_Events/Sections/01_XE_Core_Concepts/README.md:20-27,58-60,80-90 · **ต้องเขียนเนื้อหาเพิ่ม**: แปลง mermaid (README:80-90) เป็น PNG ตาม spec §4.4 และเติม "ตรวจความเข้าใจ" ท้าย section

### สไลด์ 5: [S1-3] Dispatcher & Event Loss Policy — หัวใจความ Lightweight
- **Layout:** `bullets` → potx `03 Content`
- **Bullets:**
  1. **Dispatcher**: thread ที่รัน query แค่ "เขียนข้อมูลลง Memory Buffer" แล้วกลับไปทำงานต่อทันที — ไม่ต้องรอ I/O (Asynchronous)
  2. Dispatcher Thread พื้นหลังค่อยดึงจาก Buffer ไปเขียนลง Target ภายหลัง — คุมความหน่วงด้วย `MAX_DISPATCH_LATENCY`
  3. **Event Loss Policy**: Single Event Loss (default, ปลอดภัยสุด) / Multiple Event Loss (ทิ้งทั้ง buffer) / **No Event Loss** (บังคับ user thread รอ — อันตราย! ช้าเหมือน SQL Trace เดิม)
  4. Global State Data (Actions เช่น `sql_text`, `username`) แพงกว่า payload ปกติ — เลือกเฉพาะที่จำเป็น
- **ภาพ/แผนภาพ:** ไม่ต้องมีเพิ่ม — ใช้ภาพจากสไลด์ 4 ชี้ตำแหน่ง Buffer → Target ซ้ำได้
- **Speaker notes:** No Event Loss คือกับดักที่ทำให้ XEvents กลายเป็น Profiler อีกแบบ — สอนให้คง default ไว้เว้นแต่มีเหตุผลจริง Ref: Module_09_Extended_Events/Sections/01_XE_Core_Concepts/README.md:62-77 · **ต้องเขียนเนื้อหาเพิ่ม**: ควรเติมบล็อก ```sql สั้น ๆ เทียบ `EVENT_RETENTION_MODE` ทั้ง 3 ค่าใน section README

### สไลด์ 6: [S1-4] Events ที่ใช้ Tuning จริง + กับดัก High-Overhead
- **Layout:** ตาราง (`bullets` + shape Table) → potx `05 Table`
- **ตาราง (Event / Purpose / Use case) — หยิบ 6 แถวที่ใช้บ่อย:**
  1. `sql_statement_completed` — Query execution finished — Query performance analysis
  2. `rpc_completed` — Stored procedure call finished — SP performance analysis
  3. `lock_acquired` / `lock_deadlock` — Locking events — Blocking/Deadlock analysis
  4. `sql_statement_recompile` — Plan recompilation — Recompile troubleshooting
  5. `wait_info` (package `sqlos`) — Wait statistics — Real-time wait analysis
  6. `error_reported` — Error occurred — Error monitoring
- **Bullets (กับดัก — วางใต้ตาราง):**
  1. ⚠️ `query_post_execution_showplan` ดึง Actual Plan ทุก query — **แพงมาก ห้ามใช้ร่มบน production**
  2. ใช้ lightweight profiling แทน: `query_plan_profile` (SQL 2019+) / `query_post_execution_plan_profile`
- **ภาพ/แผนภาพ:** ไม่ต้องมี (ตาราง)
- **Speaker notes:** ให้ผู้เรียนจำ 3–4 events เริ่มต้นพอ — ตัวอื่นค้นตอนทำแล็บได้ Ref: Module_09_Extended_Events/Sections/01_XE_Core_Concepts/README.md:30-56, Module_09_Extended_Events/README.md:66 · **ต้องเขียนเนื้อหาเพิ่ม**: ยังไม่มีตัวอย่าง SQL ค้น event catalog ด้วย `sys.dm_xe_objects` ใน section README

### สไลด์ 7: [S2-1] Targets — เลือกปลายทางให้ถูกงาน
- **Layout:** ตาราง (`bullets` + shape Table) → potx `05 Table` (สไลด์แรกของ Section 2)
- **ตาราง (Target / เก็บที่ไหน / เหมาะกับ / ข้อควรระวัง):**
  1. `event_file` (.xel) — Disk (Asynchronous) — เก็บระยะยาว / production — ตั้ง `MAX_FILE_SIZE` + `max_rollover_files`
  2. `ring_buffer` — Memory แบบ FIFO — ดูสด / Ad-hoc monitoring — ข้อมูลเก่าถูกเขียนทับหาย ไม่เหมาะเก็บระยะยาว
  3. `histogram` (Bucketing) — Memory แบบนับกลุ่ม (Aggregation) — เช่น นับ Deadlock แยกตาม Database
  4. Event Pairing — จับคู่ Event เริ่มต้น–สิ้นสุด — ค้นหา Incomplete Transactions
- **Bullets:**
  1. กติกา: `ring_buffer` = troubleshooting จุดเดียว/ดูสด, `event_file` = production capture จริง (ตาม module README)
  2. Azure SQL ไม่มี local drive — target ต้องเป็น Azure Blob Storage (เชื่อมสไลด์ 9)
- **ภาพ/แผนภาพ:** เลือกได้ — ถ้าทำ วาด `targets-overview.png` (≥2400px) แสดง 4 targets แตกจาก Session; ถ้าไม่ทำใช้ตารางพอ
- **Speaker notes:** ต้องรู้มาก่อน: อ่านโครงสร้าง CREATE EVENT SESSION ออกจากสไลด์ 4; ลิงก์ glossary (path ตามเฟส 0) · **ต้องเขียนเนื้อหาเพิ่ม**: S2 README สั้นมาก (46 บรรทัด) — ต้องเติม "ต้องรู้มาก่อน" + ลิงก์ glossary + "ตรวจความเข้าใจ" + ตัวอย่างการวางแผนขนาดไฟล์ .xel Ref: Module_09_Extended_Events/Sections/02_Working_With_Extended_Events/README.md:5-9, Module_09_Extended_Events/README.md:65

### สไลด์ 8: [S2-2] system_health + สถานการณ์ใช้งานจริง
- **Layout:** `bullets` → potx `03 Content`
- **Bullets:**
  1. **`system_health`** — Always-on session ที่รันอยู่แล้วทุก instance: เก็บ Deadlock Graph, Error severity ≥ 20, Long Waits (> 15s/30s), Memory allocation failures
  2. สถานการณ์ **Execution Time-outs**: จับคู่ `sql_statement_starting` / `sql_statement_completed` หรือดู `rpc_completed` ที่ result = 2 (Abort)
  3. สถานการณ์ **Swallowed Errors**: จับ `error_reported` — เห็น Error ที่ Application กลืนหาย
  4. สถานการณ์ **Recompilations**: `sql_statement_recompile` + Histogram → ระบุ Object ที่ Recompile บ่อยสุด
  5. สอนลำดับใช้งาน: เปิดดู `system_health` ก่อนเสมอ — บางทีไม่ต้องสร้าง session ใหม่เอง
- **ภาพ/แผนภาพ:** ไม่ต้องมี
- **Speaker notes:** system_health คือ "XE session ฟรี" ที่แล็บ M5 เคยใช้จับ deadlock มาแล้ว — เชื่อมโมดูลได้ทันที Ref: Module_09_Extended_Events/Sections/02_Working_With_Extended_Events/README.md:11-21 · **ต้องเขียนเนื้อหาเพิ่ม**: ยังไม่มีบล็อก ```sql แสดงวิธีอ่าน event_file ของ system_health ใน section README

### สไลด์ 9: [S2-3] Modern XEvents — XE Profiler, Lightweight Profiling, Azure & 2025
- **Layout:** `two-column` → potx `04 Two-Column`
- **Bullets:**
  1. ซ้าย — **XEvent Profiler (SSMS 17.3+)**: UX แบบ Profiler บนเครื่องยนต์ XEvents, ดู Live Stream ด้วย overhead ต่ำ — Object Explorer → XE Profiler → Standard
  2. ซ้าย — **Lightweight Query Profiling**: `query_thread_profile` (infrastructure ใหม่) แทน `query_post_execution_showplan` ที่แพง + Live Query Stats เป็น default ใน SQL 2019+
  3. ขวา — **Azure SQL Integration**: ไม่มี local drive → target เป็น **Azure Blob Storage**, โหลด .xel จาก Blob มาเปิดใน SSMS ได้
  4. ขวา — **Time-bound Sessions (2025)**: `AUTO_STOP = ON` หยุด session อัตโนมัติ — กันลืมเปิดค้างจนกิน resource
  5. (2025-only) บน 2019/2022 จะ error ที่ `AUTO_STOP` — ต้องมี hard guard + ทางเลือก: ใช้ session ปกติแทน
- **ภาพ/แผนภาพ:** ไม่ต้องมี (screenshot XE Profiler ที่ถ่ายเองเป็นทางเลือก — ห้ามใช้ภาพจากเด็ค 10987C/9Expert)
- **Speaker notes:** เตือนผู้สอน: `AUTO_STOP` ยังไม่เคยพิสูจน์ syntax บน instance จริง (ความเสี่ยง #7 ของแผน) — ห้ามนำขึ้น Code Lab จนกว่าจะ sign-off บน 17.x Ref: Module_09_Extended_Events/Sections/02_Working_With_Extended_Events/README.md:23-40, Module_09_Extended_Events/README.md:58-63, Module_09_Extended_Events/Labs/README.md:201 · **ต้องเขียนเนื้อหาเพิ่ม**: S2 ควรเพิ่มตัวอย่าง AUTO_STOP พร้อมหมายเหตุรุ่นต่ำสุด + "ทางเลือกสำหรับรุ่นเก่า" ใน README

### สไลด์ 10: [S2-4] Code Lab Demo — สร้าง Session และอ่านข้อมูลสดจาก ring_buffer
- **Layout:** `demo` → potx `06 Code Lab`
- **Bullets:**
  1. `CREATE EVENT SESSION [XE_Deadlock_Monitor] ON SERVER` + `ADD EVENT sqlserver.xml_deadlock_report` → `ADD TARGET package0.ring_buffer (max_events_limit=10, max_memory=4096)` (DROP ก่อนถ้ามีอยู่ — มีในสคริปต์แล้ว)
  2. START session → จุดชนวน event → อ่าน `target_data` จาก `sys.dm_xe_session_targets` JOIN `sys.dm_xe_sessions` แล้ว `CAST(... AS XML)`
  3. `CROSS APPLY TargetData.nodes('RingBufferTarget/event')` → ได้ timestamp + XML ราย event (SSMS คลิก XML ดูได้ทันที)
  4. ตัวแปรในแล็บ: จับ wait_info (สคริปต์ 02), จับ long-running ลง event_file (สคริปต์ 06)
- **error ที่พบได้ + รุ่นขั้นต่ำ:**
  1. รุ่นขั้นต่ำ: SQL Server 2019+ (ตัวอย่างนี้ไม่ใช้ฟีเจอร์ 2025 — ตาม Lab Prerequisites)
  2. "CREATE EVENT SESSION permission denied" → ต้องมีสิทธิ์ `ALTER ANY EVENT SESSION`
  3. Session เป็น server object — ต้องรันใน context `master`
- **T-SQL ต้นทาง (ห้ามพิมพ์ลอย ๆ):** `Module_09_Extended_Events/Sections/02_Working_With_Extended_Events/Scripts/01_Create_XE_Session.sql` + `Scripts/03_Read_XE_Data.sql` (คู่ที่ชื่อ session ตรงกัน = `XE_Deadlock_Monitor`, รันต่อกันได้ทันที)
- **ภาพ/แผนภาพ:** เลือกได้ — screenshot Watch Live Data ที่ถ่ายเอง
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน (เกิน SELECT/JOIN): `CROSS APPLY` + XQuery `.nodes()`/`.query()` — ไล่ XML ทีละ node ของ event — และ `CAST(target_data AS XML)` Ref: Module_09_Extended_Events/Sections/02_Working_With_Extended_Events/Scripts/01_Create_XE_Session.sql, Scripts/03_Read_XE_Data.sql, Module_09_Extended_Events/Labs/README.md:83-139 · **ต้องเขียนเนื้อหาเพิ่ม**: .sql ทั้ง 2 ไฟล์ยังไม่มี `MinVersion:` header (เฟส 0) และสคริปต์ 06 อ่านคู่กับ 03 ไม่ได้ตรง ๆ (คนละ session/target) — ต้องแก้ให้เป็นคู่หรือเขียน read script ของ event_file ก่อนประกอบเด็ค

### สไลด์ 11: Lab 9 — Query Performance, Deadlocks & Long-Running Queries
- **Layout:** `lab` → potx `06 Code Lab`
- **Bullets (บังคับพิมพ์จำนวน Exercise ตาม spec §4.6):**
  1. แล็บนี้มี **3 Exercise** — บน AdventureWorks2025, สิทธิ์ `ALTER ANY EVENT SESSION`, SSMS → Management → Extended Events
  2. Exercise 1: `XE_SlowQueries` — predicate `duration > 500000` µs (500 ms) + `ring_buffer` → อ่าน duration/cpu_time/logical_reads ด้วย XQuery ("Profiler แบบเบา")
  3. Exercise 2: `XE_DeadlockMonitor` — ทำ deadlock 2 หน้าต่าง → **error 1205** → ดึง Deadlock Graph จาก `xml_deadlock_report` + Watch Live Data
  4. Exercise 3: `XE_LongRunning` — `rpc_completed` + `sql_batch_completed` > 3 s กรอง database_id → `event_file` + อ่านด้วย `sys.fn_xe_file_target_read_file`; Step 3 (SQL Server 2025) ใช้ `AUTO_STOP`
  5. จบแล็บ: Wrap-up 3 คำถาม + Cleanup (STOP/DROP session ทุกตัว)
- **error ที่พบได้ + รุ่นขั้นต่ำ:**
  1. Exercise 1–2: SQL Server 2019+ · Exercise 3 Step 3 (`AUTO_STOP`): **SQL Server 2025 (17.x) เท่านั้น** — บนรุ่นเก่าจะ error syntax
  2. ทางเลือกสำหรับรุ่นเก่า: ข้าม Step 3 ของ Exercise 3 — Step 1–2 (event_file) ยังทำได้ครบบน 2019+
- **ภาพ/แผนภาพ:** ไม่ต้องมี (screenshot Deadlock Graph ที่ถ่ายเองเป็นทางเลือก)
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน: อ่าน XML ด้วย `CROSS APPLY` + `.value()`/`.nodes()` และหน่วย `duration` = ไมโครวินาที (เผลอมักชน 1,000 เท่า) Ref: Module_09_Extended_Events/Labs/README.md:25-223 (สคริปต์ประกอบ: Sections/01_XE_Core_Concepts/Scripts/05_Page_Splits_Tracking.sql, Sections/02_Working_With_Extended_Events/Scripts/01_Create_XE_Session.sql, 02_Wait_Stats_Capture.sql, 03_Read_XE_Data.sql, 04_XE_Blocking_Deadlock.sql, 06_Create_XE_LongQueries.sql) · **ต้องเขียนเนื้อหาเพิ่ม**: แล็บยังไม่มีบล็อก `**Expected:**` ต่อ Exercise + ไม่มี "ต้องรู้ก่อน" + ไม่มี sign-off รันจริงบน 17.x (รวมยืนยัน syntax AUTO_STOP) ตาม DoD

### สไลด์ 12: สรุปโมดูล — สิ่งที่ต้องจำ + ทางต่อไป
- **Layout:** `summary` → potx `08 Closing (dark)` (สรุปท้ายโมดูลใช้ 08 ได้ตาม spec §4.3)
- **Bullets:**
  1. XEvents คือมาตรฐาน tracing เดียวของ SQL Server ปัจจุบัน — SQL Profiler/Trace deprecated ห้ามใช้
  2. Overhead ต่ำเพราะ 2 อย่าง: **Early Filtering** (predicate ก่อนเก็บ) + **Asynchronous** dispatch
  3. เลือก Target ตามงาน: `ring_buffer` ดูสด / `event_file` เก็บจริง / `histogram` นับกลุ่ม
  4. `system_health` คือแหล่งข้อมูลดิบที่มีอยู่แล้ว — เปิดดูก่อนสร้าง session ใหม่เสมอ
  5. 2025: Time-bound session (`AUTO_STOP`) กันลืมปิด — โมดูลถัดไป: Module 10 Monitoring & Baselines (DMVs)
- **ภาพ/แผนภาพ:** ไม่ต้องมี
- **Speaker notes:** ปิดด้วย quiz เช็คความเข้าใจ 3 ข้อจากท้าย module README (ข้อดี XEvents เทียบ Profiler / Predicate คืออะไรทำไมสำคัญ / ring_buffer ข้อควรระวัง) Ref: Module_09_Extended_Events/README.md:37-50 · **ต้องเขียนเนื้อหาเพิ่ม**: quiz bank รายโมดูลยังไม่มี (เฟส 3 ของแผน) — ต้องสร้างก่อนใช้สไลด์นี้เป็นการวัดผลจริง

---

## เช็คลิสต์ก่อนประกอบ .pptx (อ้าง DoD "สไลด์สมบูรณ์" §5)
1. ใช้เฉพาะ 8 layouts ของ `Trainocate_SQLPerfTuning_Template.potx` — ห้าม `DEFAULT` (ตรวจ python-pptx)
2. Notes 12/12 พร้อม token `Ref:` ชี้ path จริงทุกใบ; สไลด์แรกของแต่ละ section (3, 7) มี "ต้องรู้มาก่อน" + ลิงก์ glossary
3. Code Lab 2 ใบ (10, 11) ≤ 4 — ทุกใบอ้างไฟล์ .sql จริง + คู่ "error ที่พบได้ + รุ่นขั้นต่ำ"; **เงื่อนไขก่อนขึ้นเด็คจริง: เติม `MinVersion:` header ให้ .sql ที่อ้าง (เฟส 0)**
4. สไลด์ 2 (Divider) พิมพ์งบเวลา 60+45 นาที; สไลด์ 11 (Lab) พิมพ์จำนวน Exercise = 3 + `Ref: Module_09_Extended_Events/Labs/README.md`
5. ภาพบังคับ 1 ชิ้น: `xe-architecture.png` ≥2400px ที่ `Sections/01_XE_Core_Concepts/images/` — ตรวจได้ด้วย `git ls-files "*.png"`; ห้ามใช้ภาพจากเด็ค 10987C/9Expert
6. Stat Callout: ไม่มีในเด็คนี้ — ตัวเลข overhead 30% / <1% อยู่ใน bullets ที่อ้างจาก S1 README:9 เท่านั้น (ยังไม่ผ่าน sign-off รันจริง 17.x จึงไม่ทำ Stat Callout)
