# สไลด์ไบล์พรินต์ — Module 5: Concurrency (Locking, Isolation & Optimized Locking)

> **ตามแผนแม่บท:** `Trainer_Docs/Production_Plan_Course_and_Slides.md` หมวด 4 (มาตรฐานสไลด์) — เด็ค M5 = **16 สไลด์** (สูตร 4.2: โครง 4 ใบ + 4 ใบ/section × 3 sections) · Code Lab 2 ใบ (≤4 ตามเพดาน) · งบเวลาโมดูล **195 นาที** (บทเรียน 90 + LAB 5 105 — จาก `Course_Guide_4Days.md:89,95-96` วันที่ 2) · แล็บ **4 Exercise**
> **สรุปครอบคลุม:** เด็คเปิดด้วย Concurrency Models (Pessimistic/Optimistic) และ ACID ต่อด้วยบันได Isolation Levels และ RCSI พร้อม demo จำลอง Blocking Chain หา Head Blocker ด้วย DMV จากสคริปต์จริง — Section 2 ลงลึก Locking Internals: Granularity, Modes, Compatibility Matrix, Lock Escalation, Deadlock (cycle + victim + การป้องกัน) และ Latch/Spinlock — Section 3 ปิดด้วยฟีเจอร์ยุคใหม่: RCSI vs Snapshot, ADR (PVS/sLog) และ Optimized Locking ของ SQL Server 2025 (TID Locking + LAQ) ก่อนเข้าแล็บ 4 Exercise และ quiz ท้ายโมดูล
> **สถานะเนื้อหา repo:** Section 1 (40 บรรทัด) และ Section 3 (99 บรรทัด) เนื้อหายังบาง → สไลด์ออกแบบตาม "เป้าหมายของหัวข้อ" และระบุ **"ต้องเขียนเนื้อหาเพิ่ม"** ใน speaker notes ของสไลด์ที่เกี่ยว; Section 2 (257 บรรทัด) เนื้อหาหนาครอบคลุมแล้ว
> **ช่องว่างที่ต้องปิดก่อนประกอบ .pptx:** (1) ไฟล์ .sql ทั้ง 9 ของโมดูลยังไม่มี header `MinVersion:` (ตรวจด้วย `grep -L "MinVersion" Module_05_Concurrency/Sections/*/Scripts/*.sql` = 9) (2) Section 3 ยังไม่มีโฟลเดอร์ `Scripts/` (ต้องสร้าง 1 จุด ตามช่องว่าง M5 ในแผนแม่บท) (3) glossary กลางยังไม่มีไฟล์ใน repo (เฟส 0 Blocking ของแผน) — notes ที่อ้าง glossary ต้องอัปเดตลิงก์เมื่อไฟล์เกิดขึ้น (4) ภาพ PNG ใหม่ 5 ชิ้น (≥2400px) ยังไม่ถูกวาด — ระบุ path ปลายทางไว้ในแต่ละสไลด์
> **หมายเหตุ:** ไฟล์นี้ถูก `.gitignore:66` (`Trainer_Docs/*`) กลืนเป็น untracked ตามความเสี่ยง #4 ของแผนแม่บท — รอนโยบาย git จากเจ้าของคอร์ส

---

### สไลด์ 1: Module 5 — Concurrency: Locking, Isolation & Optimized Locking

- **Layout:** `title` → potx `01 Cover (dark)`
- **Bullets:**
  1. หลักสูตร SQL Server Performance Tuning (4 วัน / 24 ชม.) — วันที่ 2 ของคอร์ส
  2. กลไกจัดการผู้ใช้งานพร้อมกัน: Locking, Transaction Isolation Levels, Row Versioning
  3. ฟีเจอร์ใหม่ SQL Server 2025: ADR (PVS/sLog) + Optimized Locking (TID Locking / LAQ)
  4. ปูทางสู่ Module 9: จับ Deadlock ด้วย Extended Events (`xml_deadlock_report`)
- **ภาพ/แผนภาพ:** ไม่มี — ใช้งานศิลป์ประจำ layout `01 Cover (dark)`
- **Speaker notes:** เปิดด้วย scenario ของแล็บ: ผู้ใช้บ่นแอป "ค้าง" และ batch กลางคืนล้มด้วย error 1205 — โมดูลนี้ทำให้ผู้เรียนอ่านสาเหตุได้เองด้วย DMV และแก้ได้ทั้งแบบเดิม (isolation) และแบบใหม่ (Optimized Locking) Ref: `Module_05_Concurrency/README.md`, `Module_05_Concurrency/Labs/README.md:13`
- **Scripts:** —

### สไลด์ 2: Module Divider — งบเวลาและเส้นทางของโมดูล

- **Layout:** `section-divider` → potx `02 Module Divider (dark)`
- **Bullets:**
  1. งบเวลาโมดูล: **195 นาที** (บทเรียน 90 นาที + LAB 5 105 นาที — ตารางวันที่ 2)
  2. แล็บ **4 Exercise**: Blocking Chain / Deadlock Graph / RCSI / Optimized Locking (2025)
  3. เป้าหมาย: อ่าน Blocking ด้วย DMV ได้ → วิเคราะห์ Deadlock Graph ได้ → เลือก Isolation/RCSI ให้เหมาะกับ Workload
  4. ⚠️ Exercise 4 ต้องใช้ **SQL Server 2025 (17.x)** เท่านั้น (`OPTIMIZED_LOCKING`) — รุ่นเก่าทำ Exercise 1–3 แล้วข้าม
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ประกาศงบเวลาและจำนวน Exercise ให้ผู้เรียนรับทราบก่อนเริ่ม (เวลาจริงจากการทดสอบผู้เรียนฐาน Admin เฟส 4 ต้องนำมาเทียบกับ 195 นาทีนี้และรายงานเจ้าของหลักสูตร) Ref: `Module_05_Concurrency/Labs/README.md`, `Trainer_Docs/Course_Guide_4Days.md:89,95-96`
- **Scripts:** —

### สไลด์ 3: Concurrency Models — Pessimistic vs Optimistic

- **Layout:** `two-column` → potx `04 Two-Column`
- **Bullets:**
  1. (ซ้าย) **Pessimistic**: สมมติ Conflict เกิดเสมอ → Lock ทันทีที่อ่าน/แก้ไข — *Default ของ SQL Server*
  2. (ซ้าย) ได้ Data Consistency สูงสุด แต่โอกาส Blocking สูงตาม
  3. (ขวา) **Optimistic**: สมมติ Conflict น้อย → ไม่ Lock ตอนอ่าน ใช้ Row Versioning + ตรวจ Validation ตอน Commit
  4. (ขวา) ลด Blocking มาก แต่ต้องมี Retry logic และแบกต้นทุน Version Store (TempDB หรือ PVS)
  5. (แถบล่าง) Transaction = Logical Unit of Work ต้องครบ **ACID**: Atomicity / Consistency / Isolation / Durability
  6. (แถบล่าง) Transaction Modes: Auto-commit (Default) · Explicit (`BEGIN TRAN…COMMIT`) · Implicit
- **ภาพ/แผนภาพ:** ไม่มี — สองคอลัมน์ข้อความ + แถบ ACID ล่าง
- **Speaker notes:** ต้องรู้มาก่อน: คำว่า Transaction, Lock, DMV — ชี้ลิงก์ glossary กลาง (ยังไม่มีไฟล์ใน repo วันนี้ — เฟส 0 ของแผนแม่บท ต้องสร้างก่อนขึ้นเด็คจริง) Ref: `Module_05_Concurrency/Sections/01_Concurrency_Transactions/README.md:5-21` — ต้องเขียนเนื้อหาเพิ่ม: Section 1 (40 บรรทัด) ยังไม่มีตัวอย่าง Workload ประกอบการเลือก model (เช่น OLTP แอบแฟ้ม vs งานรายงาน)
- **Scripts:** —

### สไลด์ 4: Isolation Levels & Read Anomalies

- **Layout:** `bullets+diagram` → potx `03 Content`
- **Bullets:**
  1. **READ UNCOMMITTED**: อ่านข้าม lock → เสี่ยง **Dirty Read** สูงสุด
  2. **READ COMMITTED** (Default): กัน Dirty Read แต่ยังเจอ **Non-Repeatable Read** / **Phantom Read**
  3. **REPEATABLE READ**: ค่าที่อ่านคงเดิมจนจบ Transaction (กัน Non-Repeatable Read)
  4. **SERIALIZABLE**: กัน Phantom ด้วย Key-Range Lock — Blocking/Deadlock สูงสุด
  5. **SNAPSHOT**: อ่านเวอร์ชันก่อนหน้าจาก Version Store แทนการรอ Lock
  6. Trade-off: ยิ่ง Isolation เข้มขึ้น = Concurrency ลดลง — เลือกตาม Workload ไม่ใช่ตั้ง Default แล้วลืม
- **ภาพ/แผนภาพ:** บันได Isolation Levels 5 ขั้น (เรียงความเข้มงวด พร้อม anomaly ที่แต่ละขั้นกันได้) — วาดด้วย native shapes บนสไลด์ (ไม่ต้องใช้ PNG ใหม่)
- **Speaker notes:** ย้ำว่า Default = READ COMMITTED แบบ Pessimistic ที่ใช้ Shared Lock (คำถามข้อ 1 ของ quiz โมดูล) Ref: `Module_05_Concurrency/Sections/01_Concurrency_Transactions/README.md:23-29` — ต้องเขียนเนื้อหาเพิ่ม: ตาราง "anomaly × isolation level" (ระดับใดกันอะไร) ยังไม่มีใน section README
- **Scripts:** —

### สไลด์ 5: RCSI — อ่านไม่รอ Lock ด้วย Row Versioning

- **Layout:** `bullets+diagram` → potx `03 Content`
- **Bullets:**
  1. **RCSI** = ปรับ READ COMMITTED ให้ใช้ Row Versioning แทน Shared Lock: `ALTER DATABASE … SET READ_COMMITTED_SNAPSHOT ON`
  2. Reader อ่านเวอร์ชัน committed ล่าสุดจาก **Version Store** → Reader ไม่ block Writer และไม่ถูก block
  3. Version Store อยู่ใน **TempDB** (เมื่อไม่เปิด ADR) → ต้องมอนิเตอร์พื้นที่ TempDB เสมอ
  4. **Azure SQL Database** เปิด RCSI เป็น Default ตั้งแต่แรก — on-premises ยังปิด
  5. เขียน (Writer) ยัง Lock ปกติ → RCSI แก้ "อ่านชนเขียน" ไม่ใช่ "เขียนชนเขียน"
- **ภาพ/แผนภาพ:** **PNG ใหม่** `rcsi-row-versioning.png` (กว้าง ≥2400px) — Writer UPDATE → เวอร์ชันเก่าไป Version Store → Reader อ่านเวอร์ชันเก่าขนานกัน; เก็บที่ `Module_05_Concurrency/Sections/01_Concurrency_Transactions/images/`
- **Speaker notes:** สไลด์นี้คือพื้นฐานของ Exercise 3 ในแล็บและของ Section 3 Ref: `Module_05_Concurrency/Sections/01_Concurrency_Transactions/README.md:31-34`, `Module_05_Concurrency/Sections/03_ADR_Optimized_Locking_2025/README.md:33-43` — ต้องเขียนเนื้อหาเพิ่ม: ส่วนต้นทุน/การมอนิเตอร์ Version Store ของ Section 1 ยังสั้น (ควรเติม query ดู version store)
- **Scripts:** —

### สไลด์ 6: Demo — จำลอง Blocking Chain และหา Head Blocker

- **Layout:** `demo` → potx `06 Code Lab` (Code Lab 1/2)
- **Bullets:**
  1. Session A: `BEGIN TRAN` + `UPDATE` ค้างไว้ (script 01) → Session B: `SELECT` แถวเดียวกันค้างรอ (script 02)
  2. Session C: `sys.dm_exec_requests` — ดู `blocking_session_id`, `wait_type` (`LCK_M_S`), `wait_time`
  3. หา **Head Blocker**: script 05 (join `sys.dm_exec_connections` + `CROSS APPLY sys.dm_exec_sql_text`) หรือ script 09 (open transaction ที่นอนถือ lock)
  4. ปลดด้วย `COMMIT`/`ROLLBACK` ที่ Session A → Session B รันต่อทันที
  5. **Error ที่พบได้:** ไม่มี error แต่ query ค้าง (wait type `LCK_M_*`) · **รุ่นขั้นต่ำ:** SQL Server 2019+ (ฐานข้อมูล AdventureWorks2025)
- **ภาพ/แผนภาพ:** ไม่มี — แสดง T-SQL จากไฟล์จริง
- **Speaker notes:** ศัพท์ต้องรู้ก่อน: **CROSS APPLY** = เรียก table-valued function ต่อท้ายแต่ละแถว (ใช้จับคู่ request กับ SQL text); **ROW_NUMBER() OVER** = window function สร้างลำดับแถว (ใน script 01); ไฟล์ .sql ทั้ง 9 ของโมดูลยังไม่มี header `MinVersion:` — ต้องเติมก่อนประกอบเด็ค (DoD ข้อ 2) Ref: `Module_05_Concurrency/Labs/README.md` Exercise 1
- **Scripts:** `Module_05_Concurrency/Sections/01_Concurrency_Transactions/Scripts/01_Blocking_SessionA.sql` · `…/02_Blocking_SessionB.sql` · `…/09_Active_Transactions.sql` · `Module_05_Concurrency/Sections/02_Locking_Internals/Scripts/05_Analyze_Blocking.sql`

### สไลด์ 7: Lock Granularity & Lock Modes

- **Layout:** `bullets+diagram` → potx `03 Content`
- **Bullets:**
  1. **Lock Manager** จัดการ lock ทั้งระบบ — **Dynamic Locking** เลือก Granularity ตั้งแต่ตอนสร้าง Plan (Proactive)
  2. Hierarchy: **RID** (Heap) / **KEY** (B-Tree) / **PAGE** (8KB) / **EXTENT** (64KB) / **HoBT** / **TABLE** / **DATABASE**
  3. Modes: **S** (อ่านร่วมกันได้) / **X** (ผู้ขาด) / **U** (กัน deadlock ตอน update: S→U→X)
  4. **IS/IX** = Intent Lock ประกาศเจตนาในระดับแม่; **Sch-M** (DDL) Block ทุกอย่างแม้แต่ NOLOCK
  5. SERIALIZABLE ใช้ **Key-Range Lock** (RangeS-S, RangeI-N, RangeX-X) เพื่อกัน Phantom
  6. อย่าสับสน: Lock ≠ Latch ≠ Spinlock (เจาะลึกในสไลด์ 10)
- **ภาพ/แผนภาพ:** **PNG ใหม่** `lock-granularity-hierarchy.png` (กว้าง ≥2400px) — พีระมิด granularity RID→KEY→PAGE→EXTENT→HoBT→TABLE→DATABASE พร้อม mode ประจำแต่ละระดับ; เก็บที่ `Module_05_Concurrency/Sections/02_Locking_Internals/images/`
- **Speaker notes:** ต้องรู้มาก่อน: wait type และโครงสร้าง page/index จาก Module 1–2 — ชี้ลิงก์ glossary กลาง (ยังไม่มีไฟล์ — เฟส 0) Ref: `Module_05_Concurrency/Sections/02_Locking_Internals/README.md:5-21,79-96,124-139` — Section 2 เนื้อหาหนา (257 บรรทัด) ครอบคลุมหัวข้อนี้แล้ว สไลด์ย่อเฉพาะส่วนที่สอนหน้าชั้น
- **Scripts:** —

### สไลด์ 8: Lock Compatibility Matrix & Lock Escalation

- **Layout:** `bullets+diagram` → potx `03 Content` (เรนเดอร์เมทริกซ์เป็นตาราง — ใช้ layout `05 Table` ได้)
- **Bullets:**
  1. **S+S ✅** อ่านพร้อมกันได้หลายคน | **S+X ❌** อ่านชนเขียน = Blocking เกิดขึ้น
  2. **X** ไม่ compatible กับทุก mode — ต้นเหตุของ Blocking Chain ยาว ๆ
  3. **Lock Escalation**: ยุบ Row/Page → TABLE เมื่อ **≥5,000 locks** ต่อ statement หรือ lock memory เกิน **24%** ของ engine memory
  4. Trade-off: ประหยัด Memory แต่ Concurrency ดิ่ง (คนอื่นใช้ตารางไม่ได้เลย)
  5. ควบคุมได้: `ALTER TABLE … SET LOCK_ESCALATION = AUTO | TABLE | DISABLE`; escalate ไม่สำเร็จจะ retry ทุก 1,250 locks ที่เพิ่มขึ้น
- **ภาพ/แผนภาพ:** ตาราง **Lock Compatibility Matrix 5×5** (IS/S/U/IX/X) จาก README — วาดเป็นตารางบนสไลด์ ไม่ต้องใช้ PNG
- **Speaker notes:** ตัวเลข 5,000 / 24% / 1,250 อ้างจากเอกสาร Microsoft ที่ตกใน README (ยังไม่ใช่ผลรันจริงบน 17.x จึงห้ามขึ้น layout 07 Stat Callout ตามข้อ 4.6) Ref: `Module_05_Concurrency/Sections/02_Locking_Internals/README.md:23-50` — คำถามข้อ 2 ของ quiz โมดูลมาจากสไลด์นี้
- **Scripts:** —

### สไลด์ 9: Deadlock — Cycle, Detection & Prevention

- **Layout:** `bullets+diagram` → potx `03 Content`
- **Bullets:**
  1. **Deadlock** = Transaction สองตัวรอทรัพยากรซึ่งกันและกัน (**Cyclic Dependency**) → Lock Monitor เลือก Victim ฆ่าทิ้ง
  2. Detection: ตรวจทุก 5 วินาที (เร่งเป็นทุก 100ms หลังเจอครั้งแรก) — Victim = ฝั่ง rollback ถูกสุด (log น้อย) → **Error 1205**
  3. จับ **Deadlock Graph** จาก `system_health` XEvent (`xml_deadlock_report`) — อย่าใช้ SQL Profiler
  4. วิธีลดที่ดีที่สุด: **Access Objects in Order** — เข้าถึงตารางตามลำดับเดียวกันทุก Transaction กันวงจร
  5. เสริม: Transaction สั้น, ไม่รอ user input ระหว่าง tran, ใช้ Index ลด Table Scan, ใช้ RCSI แทน Shared Lock
  6. จำลองวงจรในห้อง: Session A lock `Product` ↔ Session B lock `SalesOrderDetail` แล้วสลับขอ (scripts 03/04)
- **ภาพ/แผนภาพ:** **PNG ใหม่** `deadlock-cycle.png` (กว้าง ≥2400px) — วงจร T1 ↔ Row1 ↔ T2 ↔ Row2 (Holds/Wants) จาก mermaid ของ README วาดใหม่; เก็บที่ `Module_05_Concurrency/Sections/02_Locking_Internals/images/`
- **Speaker notes:** ต่อเนื่องกับ Exercise 2 ของแล็บที่อ่าน Deadlock Graph จาก system_health จริง Ref: `Module_05_Concurrency/Sections/02_Locking_Internals/README.md:204-251` — ต้องเขียนเนื้อหาเพิ่ม: แนวทาง "อ่าน Deadlock Graph ทีละส่วน" (victim/resource/process list) ยังไม่มีใน section README
- **Scripts:** `Module_05_Concurrency/Sections/02_Locking_Internals/Scripts/03_Deadlock_SessionA.sql` · `…/04_Deadlock_SessionB.sql` · `…/05_Analyze_Blocking.sql`

### สไลด์ 10: Latches & Spinlocks — กลไกซิงค์ภายใน Engine

- **Layout:** `bullets+diagram` → potx `03 Content` (ตารางเปรียบเทียบ — ใช้ layout `05 Table` ได้)
- **Bullets:**
  1. **Lock** = กุญแจห้องนอน: ปกป้องข้อมูลผู้ใช้ ถือจนจบ Transaction → wait type `LCK_M_*`
  2. **Latch** = กุญแจตู้เย็น: ปกป้อง Buffer Page ถือสั้น → `PAGELATCH_*` / `PAGEIOLATCH_*` (รอ I/O จาก Disk)
  3. **Spinlock** = กุญแจเครื่องชงกาแฟ: ปกป้องโครงสร้างภายใน วนลูปกิน CPU ไม่มี wait type
  4. ทำไมต้องหลายชั้น: ของที่ถือแค่แป๊บเดียว วนรอ CPU ถูกกว่านอนรอแล้วเสีย Context Switch
  5. อาการ Spinlock Contention (เครื่อง 24+ cores): High CPU โดยไม่มี wait ชัดเจน + `SOS_SCHEDULER_YIELD` สูงแต่ Throughput ไม่ขึ้น
  6. วิเคราะห์ด้วย `sys.dm_os_spinlock_stats` — ตัวดัง: `LOCK_HASH`, `LOGCACHE_ACCESS`, `SOS_OBJECT_STORE`
- **ภาพ/แผนภาพ:** ตารางเปรียบเทียบ 3 แถว (Lock/Latch/Spinlock × ปกป้องอะไร / ถือนานแค่ไหน / wait type) จาก README — ตารางบนสไลด์ ไม่ต้องใช้ PNG
- **Speaker notes:** หัวข้อนี้ใช้ syntax เกิน SELECT/JOIN — ให้ผู้เรียนผ่าน glossary (latch/spinlock) ก่อนอ่านโค้ด Ref: `Module_05_Concurrency/Sections/02_Locking_Internals/README.md:146-202` — สคริปต์ใช้ `DBCC SQLPERF … CLEAR` และ `WAITFOR DELAY` ให้รันบน Test/Lab เท่านั้น
- **Scripts:** `Module_05_Concurrency/Sections/02_Locking_Internals/Scripts/08_Latch_Spinlock_Analysis.sql` (demo เสริมถ้าเวลาเหลือ หรือมอบเป็นงานหลังห้อง)

### สไลด์ 11: RCSI vs Snapshot Isolation — เลือกให้ถูก Workload

- **Layout:** `two-column` → potx `04 Two-Column`
- **Bullets:**
  1. (ซ้าย) **RCSI**: Statement-level consistency — อ่าน committed ณ ตอนเริ่ม statement; ไม่มี Update Conflict; เหมาะ OLTP ทั่วไป (Azure SQL ใช้เป็น Default)
  2. (ซ้าย) เปิดระดับ Database: `SET READ_COMMITTED_SNAPSHOT ON` — แล้วใช้ได้ทุก session ทันที
  3. (ขวา) **SNAPSHOT**: Transaction-level consistency — อ่าน committed ณ ตอนเริ่ม Transaction; เหมาะงาน Report ที่ต้องการมุมมองคงเส้นคงวา
  4. (ขวา) เปิด Database + ระดับ Session: `SET TRANSACTION ISOLATION LEVEL SNAPSHOT` — มี **Update Conflict → Error 3960** ต้องมี Retry ใน Application
  5. (ล่าง) Version Store: TempDB (ไม่เปิด ADR) หรือ **PVS ใน User Database** (เปิด ADR) — TempDB เต็ม = การอ่าน version ล้มเหลว
- **ภาพ/แผนภาพ:** ไม่มี — สองคอลัมน์เทียบกัน
- **Speaker notes:** ต้องรู้มาก่อน: RCSI จากสไลด์ 5 และ ACID จากสไลด์ 3 — ชี้ลิงก์ glossary กลาง (ยังไม่มีไฟล์ — เฟส 0) Ref: `Module_05_Concurrency/Sections/03_ADR_Optimized_Locking_2025/README.md:5-43` — ต้องเขียนเนื้อหาเพิ่ม: Section 3 (99 บรรทัด) ยังไม่มีตัวอย่าง Error 3960 จริง/แนวทางเขียน Retry และยังไม่มีบล็อก "ตรวจความเข้าใจ" ตาม DoD
- **Scripts:** —

### สไลด์ 12: ADR — Accelerated Database Recovery

- **Layout:** `bullets+diagram` → potx `03 Content`
- **Bullets:**
  1. Traditional: Undo ขึ้นกับขนาด/จำนวน Uncommitted Transaction — rollback transaction ยักษ์อาจนานนับชั่วโมง; **ADR: Instant Undo ~วินาที**
  2. โครงสร้างใหม่: **sLog** (secondary in-memory log) + **PVS** (Persistent Version Store อยู่ใน User Database แทน TempDB)
  3. **Log Truncation ไม่ต้องรอ Oldest Active Transaction** → transaction log ไม่โตมั่วอีกต่อไป
  4. **ADR = Prerequisite ของ Optimized Locking**; SQL Server 2025 เพิ่ม ADR ใน TempDB (rollback temp table ทันที — ต้อง restart engine)
  5. มอนิเตอร์: `sys.dm_tran_persistent_version_store_stats` — PVS เติบโตเกินควบคุม = จุดตรวจหลังเปิด ADR
- **ภาพ/แผนภาพ:** **PNG ใหม่** `adr-recovery-flow.png` (กว้าง ≥2400px) — เทียบไปป์ไลน์ Traditional (Analysis→Redo→Undo ขึ้นกับขนาด tran) กับ ADR (Analysis→Redo→Instant Undo) จาก mermaid ของ README วาดใหม่; เก็บที่ `Module_05_Concurrency/Sections/03_ADR_Optimized_Locking_2025/images/`
- **Speaker notes:** Ref: `Module_05_Concurrency/Sections/03_ADR_Optimized_Locking_2025/README.md:49-93` — ต้องเขียนเนื้อหาเพิ่ม: sLog ถูกอ้างใน Course Guide (:56) แต่ยังไม่มีคำอธิบายใน section README + ยังไม่มี demo SQL และ "ตรวจความเข้าใจ" ตาม DoD
- **Scripts:** —

### สไลด์ 13: Optimized Locking (SQL Server 2025) — TID Locking & LAQ

- **Layout:** `bullets+diagram` → potx `03 Content`
- **Bullets:**
  1. **TID Locking**: ไม่ถือ Row/Page X lock ค้างจนจบ Transaction ใน READ COMMITTED — เหลือเพียง lock บน **Transaction ID**
  2. **LAQ (Lock After Qualification)**: กรองแถวบนเวอร์ชัน committed ล่าสุดโดยไม่ถือ U lock — ทำงานเมื่อเปิด **RCSI คู่กัน**
  3. ผลลัพธ์: Lock memory ลด · **Lock Escalation แทบไม่เกิด** · `LCK_M_*` waits ลดมากใน OLTP ปกติ
  4. สถานะ: **ปิด Default ใน SQL Server 2025** (ต่างจาก Azure SQL DB ที่เปิดให้ DB ใหม่)
  5. เปิดใช้: `SET ACCELERATED_DATABASE_RECOVERY = ON` ก่อน แล้ว `SET OPTIMIZED_LOCKING = ON` (ต้องไม่มี connection อื่นตอนรัน)
  6. ตรวจสถานะ: `sys.databases` (`is_optimized_locking_on`) — คือ Exercise 4 ของแล็บ (2025-only)
- **ภาพ/แผนภาพ:** **PNG ใหม่** `optimized-locking-tid-laq.png` (กว้าง ≥2400px) — เทียบ Traditional (ถือ row lock ตลอด tran) กับ Optimized (เหลือ TID lock + LAQ); เก็บที่ `Module_05_Concurrency/Sections/03_ADR_Optimized_Locking_2025/images/`
- **Speaker notes:** Ref: `Module_05_Concurrency/README.md:59-73` — ⚠️ ต้องแก้เนื้อหา: `Module_05_Concurrency/Sections/02_Locking_Internals/README.md:52-55` เขียนว่า "ฟีเจอร์ใหม่ใน SQL Server 2022" ซึ่งขัดกับแผนแม่บท (มติ #4: 2025-only มี hard guard) และ `Course_Guide_4Days.md:56` — ต้องเขียนเนื้อหาเพิ่ม: ตัวเลขเทียบ lock ก่อน/หลังต้องรอ sign-off รันจริงบน 17.x ก่อนขึ้น Stat Callout
- **Scripts:** T-SQL จาก `Module_05_Concurrency/Labs/README.md:175-198` (Exercise 4) — **ต้องสร้างไฟล์ script ประจำ Section 3 ก่อนประกอบเด็ค** เพราะ `Sections/03_ADR_Optimized_Locking_2025/` ยังไม่มีโฟลเดอร์ `Scripts/` (กติกา 4.6: ห้ามพิมพ์ T-SQL ลอย)

### สไลด์ 14: Quiz — ตรวจความเข้าใจ Module 5

- **Layout:** `quiz` → potx `03 Content` (เฉลยเก็บใน speaker notes)
- **Bullets:**
  1. Isolation Level ใดเป็น Default ของ SQL Server และมีโอกาสเกิด Blocking สูง?
  2. Lock Escalation คืออะไร และทำไม SQL Server ถึงทำ?
  3. วิธีแก้ Deadlock ที่ดีที่สุดคืออะไร?
  4. (2025) ก่อนเปิด `OPTIMIZED_LOCKING` ต้องเปิดอะไรก่อน และแนะนำเปิดอะไรคู่กัน?
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** เฉลย: (1) READ COMMITTED แบบ Pessimistic (Shared Lock) (2) ยุบ Row/Page lock → Table lock เมื่อ ≥5,000 เพื่อประหยัด Memory แต่ลด Concurrency (3) Access Objects in Order กันวงจร (4) ต้องเปิด ADR ก่อน และแนะนำเปิด RCSI คู่กันเพื่อให้ LAQ ทำงาน — คำถาม 1–3 มาจาก quiz blocks ของโมดูล, ข้อ 4 ผูกกับ Section 3; Ref: `Module_05_Concurrency/README.md:39-51,62-67`
- **Scripts:** —

### สไลด์ 15: Lab 5 — Blocking, Deadlocks & Isolation Levels (4 Exercise)

- **Layout:** `lab` → potx `06 Code Lab` (Code Lab 2/2)
- **Bullets:**
  1. Scenario: แอป "ค้าง" + batch กลางคืนล้ม error 1205 → จำลอง วิเคราะห์ (DMV + XEvent) แล้วทดสอบยาแก้ทั้งแบบเดิมและแบบใหม่
  2. **Exercise 1** — Blocking Chain + หา Head Blocker ด้วย DMV (Scripts 01/02 + 05/09)
  3. **Exercise 2** — จำลอง Deadlock (Scripts 03/04) + อ่าน Deadlock Graph จาก `system_health` (error 1205 ตั้งใจให้เกิด)
  4. **Exercise 3** — เปิด RCSI แล้ว Session B SELECT "ผ่านทันที" + ดู PVS ด้วย `sys.dm_tran_persistent_version_store_stats`
  5. **Exercise 4 (SQL Server 2025 เท่านั้น)** — เปิด ADR + `OPTIMIZED_LOCKING` แล้วเทียบ lock ที่ถือ (เหลือ TID lock); **ทางเลือกสำหรับรุ่นเก่า:** ทำ Exercise 1–3 แล้วข้าม Exercise 4
  6. ทำงาน SSMS 3 หน้าต่าง (Session A/B/C) · Permission: `VIEW SERVER STATE` + สิทธิ์ KILL (แนะนำ sysadmin บน VM)
- **ภาพ/แผนภาพ:** ไม่มี — โค้ดจาก `Labs/README.md` และสคริปต์จริง
- **Speaker notes:** ศัพท์ต้องรู้ก่อน: **CROSS APPLY/OUTER APPLY** (จับคู่ request ↔ SQL text ต่อแถว), **XQuery `.nodes()`** (แตก XML deadlock report ออกเป็นแถว) — อธิบาย 1 บรรทัดก่อนเริ่มแล็บ; **Error ที่พบได้:** 1205 (ตั้งใจจำลองใน Exercise 2) และ `ALTER DATABASE … SET` จะล้มเหลวเมื่อมี connection อื่นค้างต่อ DB (Exercise 3–4 — บันทึกข้อความ/เลข error จริงตอน sign-off บน 17.x); **รุ่นขั้นต่ำ:** 2019+ ยกเว้น Exercise 4 = 17.x; ไฟล์ .sql ทั้ง 9 ยังไม่มี header `MinVersion:` — ต้องเติมก่อนประกอบเด็ค Ref: `Module_05_Concurrency/Labs/README.md`
- **Scripts:** `Module_05_Concurrency/Sections/01_Concurrency_Transactions/Scripts/01_Blocking_SessionA.sql` · `…/02_Blocking_SessionB.sql` · `…/06_Blocking_Simulation.sql` · `…/07_Snapshot_Isolation.sql` · `…/09_Active_Transactions.sql` · `Module_05_Concurrency/Sections/02_Locking_Internals/Scripts/03_Deadlock_SessionA.sql` · `…/04_Deadlock_SessionB.sql` · `…/05_Analyze_Blocking.sql`

### สไลด์ 16: สรุป Module 5 & ทางต่อยอด

- **Layout:** `summary` → potx `08 Closing (dark)`
- **Bullets:**
  1. Concurrency = หาสมดุล Consistency ↔ Concurrency — เลือก Isolation/RCSI ตาม Workload
  2. Blocking อ่านได้สดจาก `sys.dm_exec_requests` — หา Head Blocker ก่อนเสมอ
  3. Deadlock ลดได้เชิงระบบ: Access Order + Short Transaction + RCSI — วิเคราะห์ Graph จาก `system_health`
  4. SQL Server 2025: ADR (PVS/sLog) + Optimized Locking (TID/LAQ) — ตัวเลขประสิทธิภาพต้องรอ sign-off รันจริงบน 17.x
  5. ต่อไป: Module 9 Extended Events — สร้าง XE session จับ Deadlock/Blocking เอง โดยใช้พื้นฐาน lock จากโมดูลนี้
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ย้ำ dependency M5 → M9 (XE deadlock session ต้องเข้าใจ lock จากโมดูลนี้ก่อน) และงานหลังห้อง: ผู้เรียนทดสอบบันทึกเวลาจริงของแล็บมาเทียบงบ 195 นาที Ref: `Module_05_Concurrency/README.md`, `Trainer_Docs/Course_Guide_4Days.md:130`
- **Scripts:** —

---

## ภาคตรวจเด็ค (ตรวจซ้ำก่อนประกอบ .pptx)

| เกณฑ์ (Slide Spec) | ค่าของเด็คนี้ |
|---|---|
| จำนวนสไลด์ตามสูตร 4.2 (M5 = 16) | **16** ✅ (4 โครง + 4×3 sections) |
| Code Lab ≤ 4 ใบ/โมดูล (4.2) | **2 ใบ** (สไลด์ 6, 15) ✅ |
| Layout ⊆ 8 layouts ของ potx / ไม่มี DEFAULT (4.3) | ใช้ 01/02/03/04/05(เสริม)/06/08 — ไม่มี DEFAULT ✅ |
| Notes 100% + token `Ref:` (4.5) | ทุกสไลด์มี notes พร้อม `Ref:` ชี้ path จริง ✅ |
| "ต้องรู้มาก่อน" + glossary บนสไลด์แรกของแต่ละ section (4.5) | สไลด์ 3, 7, 11 ✅ (ลิงก์ glossary รอไฟล์จากเฟส 0) |
| Code Lab ระบุศัพท์ต้องรู้ก่อน + "error ที่พบได้ + รุ่นขั้นต่ำ" (4.5, 4.6) | สไลด์ 6, 15 ✅ |
| Lab slide พิมพ์จำนวน Exercise + Ref แล็บ (4.6) | สไลด์ 15 = **4 Exercise** + `Ref: Module_05_Concurrency/Labs/README.md` ✅ |
| Divider พิมพ์งบเวลา + จำนวน Exercise (4.2) | สไลด์ 2 = **195 นาที + 4 Exercise** ✅ |
| Stat Callout เฉพาะตัวเลขผ่าน sign-off 17.x (4.3, 4.6) | **ไม่ใช้ layout 07** ในเด็คนี้ (ตัวเลข 5,000/24% ยังเป็นค่าจากเอกสาร ไม่ใช่ผลรันจริง) ✅ |
| ภาพเป็น PNG ใหม่ ≥2400px ใน `Module_*/Sections/*/images/` (4.4) | ต้องวาดใหม่ **5 ชิ้น**: `rcsi-row-versioning.png`, `lock-granularity-hierarchy.png`, `deadlock-cycle.png`, `adr-recovery-flow.png`, `optimized-locking-tid-laq.png` (ปัจจุบัน repo มี PNG tracked แค่ 2 ไฟล์ของ M1 — ตรวจด้วย `git ls-files "*.png"`) ⚠️ ยังไม่วาด |
| Code Lab pull T-SQL จากไฟล์จริง + `MinVersion:` (4.6) | สไลด์ทั้งหมดอ้างไฟล์ .sql จริง 9 ไฟล์ — แต่ **0/9 มี header `MinVersion:`** ⚠️ ต้องเติมก่อนประกอบ |
| Section เนื้อหาบาง → ออกแบบตามเป้าหมายหัวข้อ + ระบุ "ต้องเขียนเนื้อหาเพิ่ม" (4.5) | S1 (สไลด์ 3, 4, 5), S3 (สไลด์ 11, 12, 13) ระบุใน notes ✅ |
