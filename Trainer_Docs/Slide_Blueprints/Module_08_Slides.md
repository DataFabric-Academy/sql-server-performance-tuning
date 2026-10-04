# Slide Blueprint — Module 8: Plan Caching & Query Store (16 สไลด์)

> **ที่มาของไบล์พรินต์:** ออกแบบตามมาตรฐานสไลด์ใน `Trainer_Docs/Production_Plan_Course_and_Slides.md` (หมวด 4 "มาตรฐานสไลด์" — Slide Spec)
> **สถานะไฟล์:** untracked — `git check-ignore -v` ระบุ `.gitignore:66:Trainer_Docs/*` (นโยบาย git สำหรับ artifacts รอตัดสิน: คำถามเปิด #3 ของแผนแม่บท / ความเสี่ยง #4)

## สรุปครอบคลุม

- เด็ค M8 ตามสูตรตายตัวของแผนแม่บท (มติ #5): **16 สไลด์ = โครง 4 (Cover / Module Divider / Lab / Closing) + 4 สไลด์ × 3 sections** — อยู่ในช่วงที่อนุญาต 12–24; **Code Lab 3 ใบ (สไลด์ 6, 9, 15) ≤ เพดาน 4 ใบ**
- ทุกสไลด์ใช้ layout จาก `Trainocate_SQLPerfTuning_Template.potx` 8 layouts เท่านั้น (ห้าม DEFAULT), ฟอนต์ Leelawadee UI ผ่าน placeholder, 16:9 — map token ตาม Slide Spec 4.3: `title`→01, `section-divider`→02, `bullets`/`bullets+diagram`/`quiz`→03, `two-column`→04, `demo`/`lab`→06, `summary` (ท้ายโมดูล)→08
- งบเวลาโมดูล (พิมพ์บนสไลด์ 2 Module Divider): **165 นาที = บรรยาย 90 นาที (13:00–14:30) + LAB 8 75 นาที (14:30–15:45), วันที่ 3** ตาม `Trainer_Docs/Course_Guide_4Days.md:102-103`; แล็บ = **4 Exercise**
- ภาพใหม่ที่ต้องวาด (PNG กว้าง ≥2400px เก็บที่ `Module_08_Plan_Caching/Sections/*/images/` — ปัจจุบันโฟลเดอร์ images ยังไม่มี): `plan-cache-lookup-flow.png`, `parameter-sniffing-skew.png`, `query-store-architecture.png`, `automatic-plan-correction-loop.png`
- ช่องว่างเนื้อหาที่ตรวจแล้วด้วยคำสั่ง (ดูภาคผนวกตอนท้ายไฟล์): Section 2 = 24 บรรทัด สั้นและไม่มีบล็อก ```sql เลย → สไลด์ 7–10 ออกแบบตาม "เป้าหมายของหัวข้อ" และระบุ **"ต้องเขียนเนื้อหาเพิ่ม"** ใน speaker notes; สคริปต์ `01_Parameter_Sniffing.sql` comment ภาษาไทย double-encoded; ทุก .sql ยังไม่มี header `MinVersion:` (0/69 ทั้ง repo); glossary กลางและ quiz bank M8 ยังไม่มีไฟล์ใน repo

| สไลด์ | Layout token | potx | หัวข้อ |
|---|---|---|---|
| 1 | title | 01 Cover (dark) | ปกโมดูล |
| 2 | section-divider | 02 Module Divider (dark) | โรดแมป + งบเวลา + 4 Exercise |
| 3–6 | bullets+diagram / two-column / bullets / demo | 03 / 04 / 03 / 06 | Section 1: Plan Cache Internals |
| 7–10 | bullets / bullets+diagram / demo / quiz | 03 / 03 / 06 / 03 | Section 2: Plan Cache Troubleshooting |
| 11–14 | bullets+diagram / two-column / bullets / bullets | 03 / 04 / 03 / 03 | Section 3: Query Store & Automatic Tuning |
| 15 | lab | 06 Code Lab | Lab 8 (4 Exercise) |
| 16 | summary | 08 Closing (dark) | สรุป + เชื่อม Module 9 |

---

## Section 0: เปิดโมดูล

### สไลด์ 1: ปกโมดูล — Plan Caching & Query Store
- **Layout:** `title` → potx 01 Cover (dark)
- **Bullets:**
  - **Module 8: Plan Caching & Query Store** — "Compile ใช้ CPU แพงเสมอ การใช้ Plan ซ้ำ (Plan Reuse) จึงเป็นหัวใจของ Performance"
  - วันที่ 3 · 13:00–15:45 (บรรยาย 90 นาที + Lab 75 นาที)
  - สภาพแวดล้อม: SQL Server 2025 (17.x) · ฐานข้อมูล AdventureWorks2025
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพเนื้อหา — ใช้ศิลป์ประจำ layout 01 ของ template
- **Speaker notes:** เปิดด้วยประโยคว่า "ทุก query ที่รันมีต้นทุน compile อยู่เบื้องหลัง และ Plan Cache คือที่ที่คุณจ่ายหรือประหยัดต้นทุนนั้น" Ref: `Module_08_Plan_Caching/README.md`

### สไลด์ 2: Module Divider — โรดแมป 3 Sections + งบเวลา
- **Layout:** `section-divider` → potx 02 Module Divider (dark)
- **Bullets:**
  - Section 1 — Plan Cache Internals: โครงสร้าง cache, cache stores, eviction
  - Section 2 — Plan Cache Troubleshooting: Recompilation, Parameter Sniffing, Plan Bloat
  - Section 3 — Query Store & Automatic Tuning: Regression, Plan Forcing, Feedback Loop
  - **งบเวลาโมดูล: 165 นาที** (บรรยาย 90 + Lab 75) · **Lab 8 = 4 Exercise**
  - ต้องรู้มาก่อน: Execution Plan และตัวชี้วัดพื้นฐานจาก Module 7 (เรียนเช้าวันเดียวกัน) + permission `ALTER DATABASE` บน VM
- **ภาพ/แผนภาพ:** ไม่ใช้ — ใช้ layout 02 dark พร้อม bullet โรดแมป
- **Speaker notes:** ประกาศงบเวลาและจำนวน Exercise ให้ผู้เรียนวางแผนเวลาแล็บตั้งแต่ต้น; Ref: `Trainer_Docs/Course_Guide_4Days.md:102-103` · `Module_08_Plan_Caching/Labs/README.md` · `Module_08_Plan_Caching/README.md`

---

## Section 1: Plan Cache Internals

### สไลด์ 3: Plan Cache คืออะไร — Plan Lookup Flow
- **Layout:** `bullets+diagram` → potx 03 Content
- **Bullets:**
  - Plan Cache = พื้นที่ Memory ที่เก็บ Execution Plan ที่ compile แล้ว เพื่อ Reuse — เพราะการ Compile ใช้ CPU สูง
  - Flow: Query เข้ามา → Hash Query Text → Cache Bucket → พบ Plan = Cache Hit (ใช้ซ้ำ) / ไม่พบ = Optimize & Compile แล้วเก็บลง Cache
  - **Compiled Plan** = โครงสร้างต้นแบบแชร์ข้าม Users ได้ / **Executable Plan (Context)** = instance ผูกกับ User/Parameter นั้น ๆ
  - Query Hash = fingerprint ของ query text, Query Plan Hash = fingerprint ของ plan — query เดียวกันแต่ plan_hash ต่าง = สัญญาณ Parameter Sniffing
- **ภาพ/แผนภาพ:** `plan-cache-lookup-flow.png` — **วาดใหม่** ≥2400px ที่ `Module_08_Plan_Caching/Sections/01_Plan_Cache_Internals/images/` จาก flow diagram ของ section (README :13–40: hash → bucket → สแกน plan list → hit/compile)
- **Speaker notes:** ต้องรู้มาก่อน: execution plan และ compile pipeline จาก Module 7 + ศัพท์ DMV — ชี้ glossary กลางของหลักสูตร (ไฟล์สร้างในเฟส 0 Blocking; วันนี้ยังไม่มีไฟล์ใน repo ต้องเติมลิงก์ก่อนประกอบเด็ค) Ref: `Module_08_Plan_Caching/Sections/01_Plan_Cache_Internals/README.md`

### สไลด์ 4: Cache Stores — Compiled vs Executable และประเภท Store
- **Layout:** `two-column` → potx 04 Two-Column
- **Bullets (ซ้าย):**
  - Compiled Plan: generic structure, ใช้ร่วมได้ → ประหยัด memory เมื่อ reuse สูง
  - Executable Plan: per-session context (runtime state) → หลายใบต่อ 1 compiled plan
- **Bullets (ขวา):**
  - Object Plans (**CACHESTORE_OBJCP**) — Stored Procedures, Functions, Triggers
  - SQL Plans (**CACHESTORE_SQLCP**) — Ad-hoc queries, Prepared statements
  - Bound Trees (**CACHESTORE_PHDR**) — algebra tree ของ Views/Constraints · Extended SP (**CACHESTORE_XPROC**)
  - ดูขนาดจริงด้วย `sys.dm_os_memory_cache_counters` (เทียบ SQL Plans vs Object Plans)
- **ภาพ/แผนภาพ:** ไม่ใช้ PNG — ใช้ two-column + แถว cache stores เป็นตารางข้อความ 4 แถว
- **Speaker notes:** เน้นว่า OBJCP มัก reuse สูงเพราะเป็น proc ส่วน SQLCP คือที่ที่ Plan Bloat ซุกตัว Ref: `Module_08_Plan_Caching/Sections/01_Plan_Cache_Internals/README.md` · `Module_08_Plan_Caching/README.md:61`

### สไลด์ 5: Eviction, Plan Bloat และ Parameterization
- **Layout:** `bullets` → potx 03 Content
- **Bullets:**
  - Memory Pressure (local store / global server) เป็นตัวกระตุ้น Eviction Loop
  - Cost-based Eviction (Clock Hand): plan ที่ไม่ถูกใช้ cost ลดลงจน 0 แล้วถูกขับออก
  - `DBCC FREEPROCCACHE` = ล้างทั้ง cache: CPU spike จาก compile ใหม่ทั้งหมด (Compilation Storm) + เสีย I/O อ่าน Metadata — ห้ามใช้เล่นใน Production
  - Auto-parameterization ทำเฉพาะ Simple Query / Forced Parameterization: compile น้อยลงแต่เสี่ยง Parameter Sniffing รุนแรง
  - **Optimize for Ad-hoc Workloads**: รันครั้งแรกเก็บแค่ Compiled Plan Stub ขนาดเล็ก รันซ้ำจึงเก็บ Full Plan — ลด Single-use plan มหาศาล
- **ภาพ/แผนภาพ:** ไม่ใช้ PNG (กลไก eviction เล่าด้วยข้อความ — ภาพสำรองถ้าต้องการ: `plan-cache-eviction-clock.png` วาดใหม่ ≥2400px แบบ optional)
- **Speaker notes:** จุดพลิกของสไลด์นี้คือ "Optimize for Ad-hoc Workloads คือวาล์วปิดต้นทุน Plan Bloat ที่แค่เปิด config" Ref: `Module_08_Plan_Caching/Sections/01_Plan_Cache_Internals/README.md`

### สไลด์ 6: Code Lab — สำรวจ Plan Cache ด้วย sys.dm_exec_cached_plans
- **Layout:** `demo` → potx 06 Code Lab
- **Bullets:**
  - รัน query จัดกลุ่มด้วย `objtype` (Adhoc / Prepared / Proc) ด้วย `COUNT_BIG`, `SUM(size_in_bytes)`, `AVG(usecounts)`
  - โฟกัสคอลัมน์ **Single-Use Plans** และ **Single-Use Size (MB)** — ตัวชี้วัด Plan Bloat โดยตรง
  - อ่านผลลัพธ์: objtype ไหนกิน memory มากสุด / usecounts เฉลี่ยต่ำแค่ไหน
  - ต่อยอด: เปิด `optimize for ad hoc workloads` แล้วรันซ้ำเทียบ single-use size
- **ภาพ/แผนภาพ:** ไม่ใช้ PNG — โค้ด T-SQL บน body ของ layout 06 + ตารางผลลัพธ์จำลอง 4–5 แถว (Cache Type / Total Plans / Size MB / Avg usecounts / Single-Use)
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน: aggregate + `GROUP BY` และ `SUM(CASE WHEN usecounts = 1 THEN size_in_bytes ELSE 0 END)` (conditional sum ใน aggregate), `CAST AS DECIMAL` เพื่อหารเป็น MB; error ที่พบได้ + รุ่นขั้นต่ำ: DMV นี้ใช้ได้ตั้งแต่รุ่นเก่า ไม่มี syntax 2025-only (แล็บทั้งโมดูลขั้นต่ำ SQL Server 2019+ แนะนำ 2025/17.x) — แต่ไฟล์ยังไม่มี header `MinVersion:` (0/69 ทั้ง repo) ต้องเติมก่อนประกอบเด็ค; **ต้องเขียนเนื้อหาเพิ่ม:** Section 1 ยังไม่มีบล็อก ```sql อธิบาย DMV ใน README — ต้องเติมคำอธิบาย demo นี้ลง section ด้วย. Ref: `Module_08_Plan_Caching/Sections/01_Plan_Cache_Internals/README.md` · Script: `Module_08_Plan_Caching/Sections/01_Plan_Cache_Internals/Scripts/02_Plan_Cache_Size.sql`

---

## Section 2: Plan Cache Troubleshooting (เนื้อหา repo บาง — 24 บรรทัด, 0 บล็อก ```sql)

### สไลด์ 7: Recompilation & Compilation Storm
- **Layout:** `bullets` → potx 03 Content
- **Bullets:**
  - Recompilation = สร้าง Plan ใหม่ทับ Plan เดิมใน Cache — เกิดถี่ = CPU ถูกกัดเงียบ ๆ
  - สาเหตุ: Schema changes, Statistics update, SET option changes, `OPTION(RECOMPILE)`
  - วัด: Perfmon counter **`SQL Recompilations/sec`** (คู่กับ `SQL Compilations/sec`)
  - Compilation Storm = โหลด compile พร้อมกันจำนวนมาก เช่น หลัง failover หรือ cache flush
  - ใหม่ใน 2025: **Optimized sp_executesql** — batch ผ่าน `sp_executesql` compile แบบ serialize เหมือน stored procedure ช่วยลด storm
- **ภาพ/แผนภาพ:** ไม่ใช้ PNG (optional: screenshot Perfmon ถ่ายเองจาก VM หลัง sign-off 17.x)
- **Speaker notes:** ต้องรู้มาก่อน: cache stores และ lookup flow จาก Section 1 + ศัพท์ plan cache/counter — ชี้ glossary กลาง (ไฟล์เฟส 0 ยังไม่มีใน repo); **ต้องเขียนเนื้อหาเพิ่ม:** README ของ Section 2 มีเพียง 5 บรรทัดสำหรับหัวข้อนี้ — ต้องขยายเนื้อหาเชิงลึก (threshold recompile ต่อ plan, กรณี temp table) ก่อนสอน. Ref: `Module_08_Plan_Caching/Sections/02_Plan_Cache_Troubleshooting/README.md` · `Module_08_Plan_Caching/README.md:60`

### สไลด์ 8: Parameter Sniffing — Plan ที่ดีครั้งแรก อาจช้าครั้งต่อไป
- **Layout:** `bullets+diagram` → potx 03 Content
- **Bullets:**
  - Sniffed Value: SQL Server compile plan ตามค่า Parameter ของ "การรันครั้งแรก" แล้วเก็บใช้รวมกับทุกค่า
  - Scenario ข้อมูลเบ้ (Skew): ค่าที่มี 1 แถว ได้ **Index Seek** (เร็ว) → ค่าที่มี 10,000 แถว ยังถูกบังคับใช้ Seek + Key Lookup ซ้ำ 10,000 ครั้ง (ควรเป็น Scan)
  - ตรวจจับ: query_hash เดียวกันแต่ plan_hash ต่าง / Logical Reads พุ่งเฉพาะบางค่า
  - ทางแก้: `OPTION(RECOMPILE)`, `OPTIMIZE FOR UNKNOWN`, หรือ Plan Forcing ผ่าน Query Store
- **ภาพ/แผนภาพ:** `parameter-sniffing-skew.png` — **วาดใหม่** ≥2400px ที่ `Module_08_Plan_Caching/Sections/02_Plan_Cache_Troubleshooting/images/` (เทียบเส้นทาง plan 2 ทางบนข้อมูลเบ้: Seek เหมาะกับแถวน้อย vs Scan สำหรับแถวมาก)
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม:** Section 2 อธิบาย sniffing ไว้เพียง 4 บรรทัด — ต้องเติมตัวอย่างอ่าน plan/estimated rows ใน README. Ref: `Module_08_Plan_Caching/Sections/02_Plan_Cache_Troubleshooting/README.md`

### สไลด์ 9: Code Lab — จำลอง Parameter Sniffing บนข้อมูลเบ้
- **Layout:** `demo` → potx 06 Code Lab
- **Bullets:**
  - Setup: ตาราง `dbo.SniffLab` — 'TH' 1 แถว vs 'US' 10,000 แถว + Index `IX_Country` (ข้อมูลเบ้จงใจ)
  - สร้าง proc `dbo.GetCustomerByCountry` แล้วล้าง cache ด้วย `DBCC FREEPROCCACHE` (เฉพาะ VM ทดสอบ — ห้าม Production)
  - Scenario A: รัน 'TH' ก่อน → compile ได้ Seek; Scenario B: รัน 'US' ตาม → ยังใช้ Seek ของ TH, Logical Reads พุ่งผิดปกติ
  - แก้เฉพาะหน้า: `EXEC ... WITH RECOMPILE` → ได้ Scan ที่เหมาะกับ US
- **ภาพ/แผนภาพ:** ไม่ใช้ PNG — โค้ดบน layout 06 + ตารางเทียบ Logical Reads ของ TH vs US
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน: `CREATE OR ALTER PROC` (syntax แทน drop+create, รุ่นขั้นต่ำ SQL Server 2016 SP1+), `CROSS JOIN master.dbo.spt_values` (ตาราง helper ยิงแถวจำนวนมาก), `DBCC FREEPROCCACHE` (ล้าง plan cache ทั้ง instance); error ที่พบได้ + รุ่นขั้นต่ำ: บนรุ่น < 2016 SP1 `CREATE OR ALTER` พัง "Incorrect syntax near 'OR'" — แล็บโมดูลนี้ขั้นต่ำ 2019+ แนะนำ 17.x; **ต้องเขียนเนื้อหาเพิ่ม/ต้องแก้ไฟล์:** comment ภาษาไทยในสคริปต์ double-encoded (มองเห็นเป็น "à¸§à¸±à¸•à¸–à¸¸...") ต้องแก้ encoding ก่อนใช้สอน. Ref: `Module_08_Plan_Caching/Sections/02_Plan_Cache_Troubleshooting/README.md` · Script: `Module_08_Plan_Caching/Sections/02_Plan_Cache_Troubleshooting/Scripts/01_Parameter_Sniffing.sql`

### สไลด์ 10: Quiz — วินิจฉัย 3 อาการจาก Plan Cache
- **Layout:** `quiz` → potx 03 Content
- **Bullets (คำถาม):**
  - Q1: Perfmon ขึ้น `SQL Recompilations/sec` สูงผิดปกติช่วงสั้น ๆ — สงสัยสาเหตุกลุ่มไหน และดูอะไรต่อ?
  - Q2: `CACHESTORE_SQLCP` กิน memory ระดับ GB และ single-use plan เป็นส่วนใหญ่ — วินิจฉัยอะไร และทางแก้ "เร่งด่วน" กับ "ต้นเหตุ" ต่างกันอย่างไร?
  - Q3: Proc เดิมเร็วเฉพาะบางค่า parameter — วิธีระงับอาการแบบไม่แก้โค้ด application?
  - (เฉลยอยู่ใน speaker notes)
- **ภาพ/แผนภาพ:** ไม่ใช้ — โจทย์เป็น scenario ข้อความ
- **Speaker notes:** เฉลย: Q1 กลุ่มสาเหตุ recompile (schema/statistics/SET option) — ไล่ event plan_generation; Q2 Ad-hoc Plan Pollution → เร่งด่วน: `optimize for ad hoc workloads` + ต้นเหตุ: แก้ application เป็น Parameterized Query; Q3 Query Store Hints `sp_query_store_set_hints` (2022+) หรือ `OPTIMIZE FOR UNKNOWN`; **ต้องเขียนเนื้อหาเพิ่ม:** หัวข้อ Plan Cache Bloat ใน Section 2 มีเพียง 3 บรรทัด — ขยายเป็นคำอธิบายเต็มใน README. Ref: `Module_08_Plan_Caching/Sections/02_Plan_Cache_Troubleshooting/README.md` · `Module_08_Plan_Caching/Labs/README.md:174`

---

## Section 3: Query Store & Automatic Tuning

### สไลด์ 11: Query Store — Flight Data Recorder ของ Database
- **Layout:** `bullets+diagram` → potx 03 Content
- **Bullets:**
  - Query Store บันทึก Query Plans + Runtime Statistics ลง Database โดยอัตโนมัติ — วิเคราะห์ย้อนหลังและจับ Plan Regression ได้
  - โครงสร้าง 3 ส่วน: Query Text (`sys.query_store_query_text`), Plans (`sys.query_store_plan`), Runtime Stats แยกตาม interval + Wait Stats (2017+) และ Query Store Hints (2022+)
  - เปิดใช้งาน: `ALTER DATABASE ... SET QUERY_STORE = ON` + `OPERATION_MODE = READ_WRITE`, `QUERY_CAPTURE_MODE = AUTO`, `MAX_STORAGE_SIZE_MB`
  - Capture mode: `AUTO` เหมาะ Production (เก็บเฉพาะ query ที่ใช้ resource พอสมควร) — `CUSTOM` ปรับ capture policy ละเอียดได้ (มีตั้งแต่ SQL Server 2019+; 2022 แก้เฉพาะค่า default ของ `QUERY_CAPTURE_POLICY`)
  - Query Store เป็น **Foundation** ของ Automatic Tuning และ Intelligent Query Processing — เปิดก่อนเสมอ
- **ภาพ/แผนภาพ:** `query-store-architecture.png` — **วาดใหม่** ≥2400px ที่ `Module_08_Plan_Caching/Sections/03_Query_Store_Automatic_Tuning/images/` (จาก ASCII architecture ของ section README :14–28)
- **Speaker notes:** ต้องรู้มาก่อน: Parameter Sniffing/Recompilation จาก Section 2 + permission `ALTER DATABASE` — ชี้ glossary กลาง (ไฟล์เฟส 0 ยังไม่มีใน repo); Ref: `Module_08_Plan_Caching/Sections/03_Query_Store_Automatic_Tuning/README.md` · `Module_08_Plan_Caching/Labs/README.md:24-40` หมายเหตุการแก้ (technical review): bullet เดิมเคยระบุ "`CUSTOM` เพิ่มใน 2025" ผิดรุ่น — Microsoft Learn ระบุ `QUERY_CAPTURE_MODE = CUSTOM` "Applies to: SQL Server 2019 (15.x) and later versions" ต้นทางคือ comment ใน `Module_08_Plan_Caching/Labs/README.md:31` (แก้คู่กันในชุดแก้นี้)

### สไลด์ 12: จับ Plan Regression & Plan Forcing — GUI vs T-SQL
- **Layout:** `two-column` → potx 04 Two-Column
- **Bullets (ซ้าย — GUI):**
  - Object Explorer → Database → Query Store → **Regressed Queries**
  - เลือก query เห็น 2 plans: Plan ดี (duration ต่ำ) vs Plan ช้า (duration สูง) → ปุ่ม **Force Plan**
- **Bullets (ขวา — T-SQL):**
  - JOIN `sys.query_store_query` / `query_text` / `plan` / `runtime_stats` เทียบ `avg_duration` ช่วงเก่า vs ล่าสุด
  - `EXEC sp_query_store_force_plan @query_id, @plan_id` (ยกเลิกด้วย `sp_query_store_unforce_plan`) → ตรวจ `is_forced_plan` + `last_force_failure_reason_desc`
- **Bullets (ล่าง):**
  - คำเตือน: Plan Forcing = **ยาฉุกเฉิน** — ต้องตามแก้ต้นเหตุ (Statistics / Index) ต่อ
- **ภาพ/แผนภาพ:** ไม่ใช้ PNG — สองคอลัมน์ข้อความ (optional: screenshot หน้า Regressed Queries ถ่ายเองจาก VM หลัง sign-off 17.x)
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม:** T-SQL บังคับ force plan ปัจจุบันฝังใน markdown (Labs และ section README) ไม่มีไฟล์ใน `Scripts/` — พิจารณาแยกเป็นไฟล์ใหม่พร้อม header `MinVersion:` ก่อนประกอบเด็ค. Ref: `Module_08_Plan_Caching/Sections/03_Query_Store_Automatic_Tuning/README.md` · `Module_08_Plan_Caching/Labs/README.md:79-127`

### สไลด์ 13: Automatic Plan Correction — FORCE_LAST_GOOD_PLAN
- **Layout:** `bullets` → potx 03 Content
- **Bullets:**
  - เปิด: `ALTER DATABASE ... SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON)` — ระบบเรียนรู้ plan ที่ดีจาก Query Store
  - เงื่อนไข force อัตโนมัติ: CPU Gain > 10 วินาที + Plan ใหม่ error มากกว่า Plan เดิม
  - Verification loop: Detect Regression → Force Last Good Plan → ดีกว่า = คงไว้ / แย่กว่า = Unforce อัตโนมัติแล้ว compile ใหม่
  - ดูคำแนะนำ: `sys.dm_db_tuning_recommendations` (มี script พร้อมแก้)
  - Best use case: เปิดหลัง Database Compatibility Level Upgrade เพื่อลดความเสี่ยง Regression
  - Automatic Index Management (create/drop) = **Azure SQL Database only** — on-prem ใช้ได้เฉพาะ Plan Correction
- **ภาพ/แผนภาพ:** `automatic-plan-correction-loop.png` — **วาดใหม่** ≥2400px ที่ `Module_08_Plan_Caching/Sections/03_Query_Store_Automatic_Tuning/images/` (จาก mermaid verification loop ของ section README :100–109)
- **Speaker notes:** ย้ำว่า "อัตโนมัติ" ไม่ได้แปลว่าไม่ต้องดู — ต้อง monitor รายการ recommendations ประกบทุกวันจริงการใช้งาน; Ref: `Module_08_Plan_Caching/Sections/03_Query_Store_Automatic_Tuning/README.md`

### สไลด์ 14: Feedback Loop ยุค 2022–2025 + Query Store Hints
- **Layout:** `bullets` → potx 03 Content
- **Bullets:**
  - Feedback ที่ Persist ลง Disk: **Memory Grant** (2019+, persist 2022+) / **DOP Feedback** (2022+) / **CE Feedback** (2022+) / **Optimized Plan Forcing** (2022+)
  - Query Store Hints: `sp_query_store_set_hints` ใส่ hint ต่อ query **โดยไม่แก้โค้ด** (2022+)
  - **`ABORT_QUERY_EXECUTION` hint (2025)**: บล็อก query ที่รู้ว่ามีปัญหา — ได้ error 8799 ทันที เหมาะกับ ad-hoc หนักที่แก้ app ไม่ทัน
  - Query Store สำหรับ readable secondary เปิด default ใน 2025 — วิเคราะห์ workload ฝั่ง AG secondary ได้เลย
  - **Optimized sp_executesql (2025)**: ลด Compilation Storm (เชื่อมกับสไลด์ 7)
- **ภาพ/แผนภาพ:** ไม่ใช้ — จัดกลุ่มเป็น bullet ตาม feedback type (4 แถว)
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม:** ฟีเจอร์ 2025 กลุ่มนี้ปัจจุบันอยู่ในบล็อก outline ท้าย module README ที่ heading เสีย (`## ### 7.x` ที่บรรทัด 59) — ต้องย้าย/ขยายเป็นเนื้อหา Section 3 จริง; ระวัง syntax `ABORT_QUERY_EXECUTION` ยังไม่เคยพิสูจน์บน instance จริง (ความเสี่ยง #7 ของแผนแม่บท) ห้ามสอนแบบรันสดก่อน sign-off 17.x. Ref: `Module_08_Plan_Caching/README.md:59-66` · `Module_08_Plan_Caching/Labs/README.md:131-166`

---

## ปิดโมดูล

### สไลด์ 15: Lab 8 — Query Store: Regression, Force Plan & Automatic Tuning
- **Layout:** `lab` → potx 06 Code Lab
- **Bullets:**
  - Scenario: proc เคยเร็วมาก แต่ "บางวันช้าตึ้ง" โดยไม่มีใครแก้โค้ด — ใช้ Query Store หา plan ที่ถดถอยแล้วบังคับใช้ plan ที่ดี
  - **4 Exercise:** (1) เปิด/ตั้งค่า Query Store (2) จำลอง Regression ด้วยการ drop index (3) วิเคราะห์ Regressed Plan + Force Plan ทั้ง GUI และ T-SQL (4) Query Store Hints + `ABORT_QUERY_EXECUTION` (2025) + Automatic Plan Correction
  - เครื่องมือ: SSMS + T-SQL บน AdventureWorks2025, permission `ALTER DATABASE` บน VM — รุ่นขั้นต่ำ 2019+ (แนะนำ 2025/17.x; Exercise 4 ต้องมี 17.x)
  - ปิดท้าย: Cleanup — `sp_query_store_remove_query`, ปิด AUTOMATIC_TUNING, คืน index ตามเดิม
- **ภาพ/แผนภาพ:** ไม่ใช้ PNG — ตาราง 4 Exercise ในตัวสไลด์
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน: `ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE` (ล้าง plan cache ระดับ database), `GO 20` (รัน batch ซ้ำ 20 รอบ), `JSON_VALUE` อ่าน recommendations; error ที่พบได้ + รุ่นขั้นต่ำ: Exercise 4 เป็นบล็อก 2025-only — `sp_query_store_set_hints` บนรุ่น < 2022 ได้ "Could not find stored procedure", `ABORT_QUERY_EXECUTION` ต้องมี 17.x (error 8799) — **ทางเลือกสำหรับรุ่นเก่า:** ข้าม Exercise 4 ไปทำ Wrap-up และ Cleanup; hard guard `IF…THROW` ใน md ยังไม่มี — ต้องเติมก่อน sign-off. Ref: `Module_08_Plan_Caching/Labs/README.md` · Script: `Module_08_Plan_Caching/Sections/03_Query_Store_Automatic_Tuning/Scripts/03_Query_Store_Regression_Lab.sql`

### สไลด์ 16: สรุปโมดูล + เชื่อม Module 9
- **Layout:** `summary` → potx 08 Closing (dark)
- **Bullets:**
  - Plan Cache = การเทรด "ต้นทุน compile" กับ "พื้นที่ memory" — เป้าหมายคือ Reuse สูงและ Bloat ต่ำ
  - อาการป่วย 3 แบบที่วินิจฉัยได้ด้วย DMV + Counter: Recompile สูง / Parameter Sniffing / Ad-hoc Plan Bloat
  - Query Store เปิดก่อนเสมอ: จับ Regression, Force Plan เป็นยาฉุกเฉิน, Automatic Tuning ให้ระบบเยียวยาเอง
  - ถัดไป: **Module 9 — Extended Events** (Session/Event/Target — เครื่องมือจับพฤติกรรมเซิร์ฟเวอร์แบบละเอียด)
  - Quiz bank โมดูลนี้: มอบหมายตอบหลังเรียน (สร้างในเฟส 3 ของแผนผลิต)
- **ภาพ/แผนภาพ:** ไม่ใช้ — layout 08 dark
- **Speaker notes:** ทบทวนคำตอบ quiz สไลด์ 10 ถ้ายังไม่เคลียร์ ก่อนเปิด Module 9; Ref: `Module_08_Plan_Caching/README.md` · `Trainer_Docs/Course_Guide_4Days.md:104`

---

## ภาคผนวก: การตรวจข้อเท็จจริงที่รันระหว่างเขียนไบล์พรินต์ (2026-10-01)

| การตรวจ | คำสั่ง (ย่อ) | ผล |
|---|---|---|
| โครงโมดูล | `ls Module_08_Plan_Caching` + `ls Sections/*/Scripts` | 3 sections, Scripts/ ครบ 3/3: `01_Plan_Cache_Internals/Scripts/02_Plan_Cache_Size.sql`, `02_Plan_Cache_Troubleshooting/Scripts/01_Parameter_Sniffing.sql`, `03_Query_Store_Automatic_Tuning/Scripts/03_Query_Store_Regression_Lab.sql` |
| ความยาวเนื้อหา | `wc -l README.md Labs/README.md Sections/*/README.md` | README 71 · Labs 189 · S1 82 · **S2 24 (บางสุด, ไม่มีบล็อก ```sql)** · S3 140 |
| จำนวน Exercise | `grep -n "^## Exercise" Labs/README.md` | 4 จุด (บรรทัด 24, 44, 79, 131) |
| งบเวลาโมดูล | `grep -n "บทที่ 8\|LAB 8" Trainer_Docs/Course_Guide_4Days.md` | :102 บรรยาย 13:00–14:30 (90 นาที) · :103 LAB 8 14:30–15:45 (75 นาที) → รวม 165 นาที, วันที่ 3 |
| Encoding สคริปต์ Section 2 | `sed -n '15p' .../01_Parameter_Sniffing.sql \| od -c` | comment ไทย double-encoded (ไบต์ `303 240 302 270...` แสดงเป็น "à¸§à¸±...") — ต้องแก้ก่อนใช้สอน |
| โฟลเดอร์ images | `ls Sections/01_Plan_Cache_Internals/images` | ไม่มีโฟลเดอร์ — ภาพ 4 ชิ้นในไบล์พรินต์ต้องสร้างใหม่ทั้งหมด (PNG ≥2400px) |
| สไลด์ต่อไป | `ls -d Module_09*` | `Module_09_Extended_Events` (ใช้อ้างในสไลด์ 16) |
| สถานะ git ของไฟล์นี้ | `git check-ignore -v Trainer_Docs/Slide_Blueprints/Module_08_Slides.md` | `.gitignore:66:Trainer_Docs/*` — untracked (คำถามเปิด #3 ของแผน) |
