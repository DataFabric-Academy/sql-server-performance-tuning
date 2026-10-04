# Quiz Bank — บทที่ 10: Monitoring & Baselines (DMVs, Baseline Collection, Daily Health Check, Alerting)

> ครอบคลุมวัตถุประสงค์การเรียนรู้ของบทที่ 10 ตาม [Course_Guide_4Days.md](../Trainer_Docs/Course_Guide_4Days.md): DMVs สำคัญ (`sys.dm_exec_*`, `sys.dm_os_*`, `sys.dm_db_*`), วิธีเก็บ Baseline + Key Metrics/Thresholds, Activity Monitor/Performance Dashboard/SSMS Reports, SQL Agent Alerts + Database Mail + dbatools และ Glenn Berry 2025 Diagnostic Queries — ใช้คู่กับ [Sections](README.md) และ [Labs](Labs/README.md)
> **รูปแบบ:** ข้อ 1–10 multiple choice · ข้อ 11–15 ตอบสั้น · เฉลยพร้อมคำอธิบายอยู่ท้ายไฟล์ (อย่าเลื่อนดูก่อนตอบ!)

---

## ส่วนที่ 1: Multiple Choice

### Q1. DMOs (DMVs/DMFs) แบ่งเป็น Snapshot กับ Cumulative — จับคู่ให้ถูก
- A. `sys.dm_exec_requests` = สะสมตั้งแต่ restart / `sys.dm_os_wait_stats` = snapshot
- B. `sys.dm_exec_requests` = snapshot ของ request ที่กำลังวิ่ง / `sys.dm_os_wait_stats` = สะสม (reset เมื่อ restart หรือ `DBCC SQLPERF(..., CLEAR)`)
- C. ทั้งคู่เป็น snapshot และรีเซ็ตเองทุก 15 นาที
- D. ทั้งคู่สะสม และต้อง snapshot ด้วยตัวเอง

### Q2. "Baseline" กับ "Benchmark" ต่างกันอย่างไร?
- A. เหมือนกัน ต่างกันแค่ชื่อเรียก
- B. Baseline = สถิติของ **"สถานะปกติ"** ของระบบช่วงเวลาต่าง ๆ (peak/off-peak) ใช้ตรวจความผิดปกติ / Benchmark = เกณฑ์เป้าหมายหรือขีดจำกัดที่ระบบรับได้จากการ Stress Test
- C. Baseline = ค่าต่ำสุดที่รับได้ / Benchmark = ค่าสูงสุดที่รับได้
- D. Benchmark เก็บอัตโนมัติโดย SQL Server ส่วน Baseline ต้องเก็บเอง

### Q3. แล็บจริง: query delta เดิม (ไม่มี `PARTITION BY` ใน ROW_NUMBER + เทียบแถวกับตัวเอง) **คืนผลว่างเสมอ** — หลักการเขียน query หา delta ระหว่าง snapshot ที่ถูกต้องคืออะไร?
- A. ใช้ `MAX(SnapshotId)` เทียบกับ `MIN(SnapshotId)` ของทั้งตารางโดยไม่ต้องสนใจ WaitType
- B. เทียบ "จับครั้งแรก vs ครั้งล่าสุด **ต่อ WaitType**" — เช่น `ROW_NUMBER() OVER (PARTITION BY WaitType ORDER BY SnapshotId ASC/DESC)` แล้ว self-join คู่แรก-ท้ายของ wait type เดียวกัน แล้วลบค่าสะสม
- C. ใช้ตัวหารตัวหารลบ (negative divisor) เพื่อให้ค่าติดลบเสมอ
- D. รีเซ็ต `sys.dm_os_wait_stats` ทุกครั้งแล้วดูยอดใหม่

### Q4. แล็บจริง (delta 90 วินาที): `WRITELOG +199 ครั้ง (+272 ms ≈ 1 ms/ครั้ง)`, `SOS_SCHEDULER_YIELD +2,581 ครั้ง`, `CXPACKET/CXCONSUMER +139/+1,108` — ตีความ workload ที่ถูกต้องคือข้อใด?
- A. คอขวดหลักคือ disk อ่านช้า ต้องอัปเกรด storage ทันที
- B. Workload เขียน log หลัก (UPDATE) — WRITELOG ~1 ms/ครั้งคือระดับปกติดี; CPU pressure ปรากฏระดับรองจาก scan (SOS_SCHEDULER_YIELD + CX*) — โฟกัสยืนยันต่อด้วยข้อมูลชั้นที่สอง ไม่ใช่รีบตัดสินจาก wait ตัวเดียว
- C. WRITELOG บ่งบอก client รับข้อมูลไม่ทัน
- D. CXCONSUMER สูงแปลว่า parallel plan พัง ต้องปิด parallelism

### Q5. รายชื่อ Top waits ในตาราง baseline ถูกครองด้วย `DISPATCHER_QUEUE_SEMAPHORE`, `LOGMGR_QUEUE`, `SLEEP_TASK` — การจัดการที่ถูกคือข้อใด?
- A. เพิ่ม CPU ทันที เพราะ dispatcher บ่งบอก CPU อิ่ม
- B. จัดเป็น **benign/background waits** — กรองออกก่อนจัดอันดับ (แนวทาง Glenn Berry) แล้วโฟกัสกลุ่มที่ตรงกับ workload ของเรา
- C. ปิด Dispatcher ด้วย sp_configure
- D. ลบแถวเหล่านี้ออกจาก `sys.dm_os_wait_stats` ด้วย DELETE

### Q6. อ่านค่าจาก `sys.dm_os_performance_counters` — ข้อใดถูกต้อง?
- A. ค่า counter ชื่อลงท้าย `/sec` (เช่น `Batch Requests/sec`) อ่านค่าเดียวจบ = ค่าต่อวินาที "ณ ตอนนี้"
- B. ทุกค่าใน DMV นี้เป็น **ค่าสะสมตั้งแต่ restart** — counter แบบ rate ต้อง snapshot 2 จุดห่างกันช่วงเวลาที่รู้ แล้ว (ค่าหลัง − ค่าหน้า) ÷ วินาที จึงได้ rate จริง · เกณฑ์ตั้งต้น: `Avg. Disk sec/Read` > 20 ms = ผิดปกติ (log write ควร < 5 ms) · `% Processor Time` สูงเกิน 80% ต่อเนื่อง = ปัญหา · `Pages/sec` สูงเกิน ~50 = excessive paging
- C. กรองด้วย `instance_name = N'_Total'` ได้กับทุก counter เสมอ
- D. `Available MBytes` ควรอยู่ระดับ 0 MB เพราะ RAM ที่ว่างคือ RAM ที่เสียเปล่า

### Q7. PerfMon counter คู่ใด "จับ missing index" และ "จับ heap fragmentation" ตามลำดับ?
- A. `Buffer Cache Hit Ratio` และ `Page Life Expectancy`
- B. `Full Scans/sec` (Access Methods — สูงผิดปกติ = scan ทั้งตารางบ่อย อาจขาด index) และ `Forwarded Records/sec` (สูง = heap มี forwarding pointers เยอะ)
- C. `SQL Compilations/sec` และ `Lock Waits/sec`
- D. `Batch Requests/sec` และ `Disk Reads/sec`

### Q8. Daily Health Check พบ `memory_utilization_percentage = 100` แต่ `process_physical_memory_low = 0` — สรุปที่ถูกคือข้อใด?
- A. SQL Server อัด RAM เครื่องจน OS อด — ต้องลด max server memory ทันที
- B. SQL ใช้เต็ม **target memory ของตัวเอง** (พฤติกรรมปกติของ dynamic memory) และ **ไม่มี pressure** — ยังไม่ต้องแก้อะไร จับ trend ต่อ
- C. Counter พัง — ต้อง restart SQL Server
- D. ต้องเปิด LPIM เพื่อแก้อาการ

### Q9. สิทธิ์การ monitor ที่แนะนำแทนการให้ sysadmin กับ monitoring account คืออะไร และเครื่องมือ automation ใดตรงกับหลักสูตร?
- A. บทบาท `##MS_ServerPerformanceStateReader##` (SQL Server 2022+) ให้อ่าน DMV ด้าน performance และใช้ dbatools (PowerShell) เช่น `Get-DbaWaitStatistic`, `Test-DbaLastBackup`
- B. สิทธิ์ CONTROL SERVER บน database ผู้ใช้ + สคริปต์ VBScript
- C. sysadmin + SQL Profiler รันตลอด
- D. `##MS_DatabaseConnector##` อย่างเดียวพอสำหรับอ่าน wait stats

### Q10. เรื่อง SQL Server Agent + Database Mail ตามแล็บ — ข้อใดถูกต้อง?
- A. Job เก็บ baseline รันได้แม้ Agent หยุด เพราะ SQL Engine จัดคิวเอง
- B. Snapshot job ("DBA - Baseline Snapshot" ทุก 15 นาที) ต้องอาศัย **SQL Agent** — บน VM ทดสอบพบ Agent อยู่สถานะ Stopped (ตรวจจาก `sys.dm_server_services`) ต้อง START ก่อน และควรผูก Database Mail + Operator (`sp_add_operator`, `@notify_level_email = 2`) เพื่อแจ้งเตือนเมื่อ job fail
- C. Database Mail ใช้ส่ง baseline เป็นแนบไฟล์อัตโนมัติทุก snapshot
- D. Agent ต้องรันภายใต้บัญชี sysadmin ของ SQL เสมอ

---

## ส่วนที่ 2: ตอบสั้น

### Q11. ออกแบบ Baseline Collection สำหรับ instance ใหม่: เก็บอะไร (wait stats, file I/O, ฯลฯ) ด้วยความถี่เท่าไร (PerfMon vs DMV), เก็บไว้นานแค่ไหน และเพราะอะไรต้อง "เก็บ delta" แทนการดูค่าสะสม?

### Q12. Daily Health Check ในแล็บมี 6 result sets (เวอร์ชัน+เวลา restart, สถานะ memory OS, memory utilization, schedulers ที่มีคิวค้าง, DB ที่ Query Store ปิด, last backup) — ระบุว่าค่าแบบไหนถือ "ผิดปกติต้องตามต่อ" อย่างน้อย 3 จุด (อ้างค่าจริงจากแล็บ เช่น last_backup = NULL แปลว่าอะไร)

### Q13. SQL Profiler/Trace กับ Extended Events สถานะปัจจุบันต่างกันอย่างไร และ "Default Trace" มีบทบาทอะไร (จับอะไรไว้แม้ไม่ได้ตั้งค่าอะไรเอง)

### Q14. Glenn Berry Diagnostic Queries คืออะไร ควรใช้ทุกเมื่อไร อย่างไร (Results to File / เทียบ spreadsheet) และเชื่อมโยงกับ baseline ที่สร้างเองว่าครอบกันตรงไหน (baseline อัตโนมัติทุก 15 นาที vs สแนปช็อตเชิงลึกรายวัน)

### Q15. จากแล็บจริง: `FileIOSnapshot` แสดง log ของ AdventureWorks +490 writes, io_stall_write +567 ms ใน 90 วินาที และ delta waits แสดง `WRITELOG +199 (+272 ms)` — คำนวณค่าเฉลี่ย latency ต่อ write จากทั้งสองแหล่ง อธิบายว่าคู่ข้อมูลนี้ยืนยันกันอย่างไร และถ้าค่า latency เด้งเป็น 50+ ms/ครั้งควรตามตรวจอะไรต่อ

---

## เฉลยพร้อมคำอธิบาย

<details>
<summary><b>เฉลย Q1</b> — B</summary>

- **Snapshot**: `sys.dm_exec_requests` (แถว request ที่กำลังวิ่งตอนนี้ — หายไปเมื่อ job จบ) คู่กันคือ `sys.dm_os_schedulers` (สถานะ scheduler ปัจจุบัน)
- **Cumulative**: `sys.dm_os_wait_stats`, `sys.dm_io_virtual_file_stats` (สะสมตั้งแต่ restart — ต้อง snapshot เก็บเองแล้วคำนวณ delta)

จำง่าย: "ของที่วิ่งผ่าน = snapshot / ของที่จดบัญชี = cumulative" — อ่านต่อ: [Section 10.1 หัวข้อ 2 DMOs — Snapshot vs Cumulative](Sections/01_Monitoring_Tracing/README.md)
</details>

<details>
<summary><b>เฉลย Q2</b> — B</summary>

**Baseline** = ภาพ "ปกติของเครื่องนี้" ช่วง peak/off-peak ใช้ตอบว่า "ตอนนี้ผิดปกติไหม" (Anomaly Detection) — **Benchmark** = เป้าหมาย/ขีดจำกัดที่กำหนดไว้ (มักมาจาก stress test) ใช้ตอบว่า "เครื่องนี้รับ workload สูงสุดได้แค่ไหน" — ทำ baseline ก่อนเสมอ ไม่งั้นรู้แค่ว่า "ช้า" แต่ไม่รู้ว่า "ช้ากว่าปกติของมันหรือเปล่า" — อ่านต่อ: [Section 10.2 หัวข้อ 1 Baseline vs Benchmark (นิยาม)](Sections/02_Baselining_Benchmarking/README.md)
</details>

<details>
<summary><b>เฉลย Q3</b> — B</summary>

ค่าใน `sys.dm_os_wait_stats` เป็นสะสม — delta ต้องลบ "snapshot ก่อนออกจาก snapshot หลัง" **ต่อ wait type** — query เดิมผิดสองชั้น: `ROW_NUMBER() OVER (ORDER BY SnapshotId DESC)` ไม่มี `PARTITION BY WaitType` (จัดอันดับข้าม wait type ปนกัน) + เงื่อนไขเทียบแถวล่าสุดกับตัวมันเอง → ผลว่างเสมอ — แก้ด้วย partition ต่อ WaitType แล้ว join คู่ rn_first = 1 กับ rn_last = 1 แล้วลบ — อ่านต่อ: [Labs Ex2 Step 2 ⚠️](Labs/README.md) + [SignOff ข้อค้นพบ 10](../Trainer_Docs/SignOff/AllLabs_SignOff.md)
</details>

<details>
<summary><b>เฉลย Q4</b> — B</summary>

`WRITELOG` = รอเขียน transaction log — +199 ครั้งใน 90 วิ ที่ ~1 ms/ครั้ง = latency ปกติดี (เกณฑ์ log write < 5 ms) จึงไม่ใช่คอขวด; `SOS_SCHEDULER_YIELD` +2,581 = scan หนักใช้ CPU ระดับรอง; `CXPACKET/CXCONSUMER` = parallel plan ปกติ ตามหลัก Waits & Queues: แปล wait → resource → **ยืนยันด้วยข้อมูลชั้นที่สอง** (เช่น `FileIOSnapshot`) ก่อนสรุป — อ่านต่อ: [Labs Ex2 ✅ ตีความ + Expected](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q5</b> — B</summary>

`DISPATCHER_QUEUE_SEMAPHORE`, `LOGMGR_QUEUE`, `SLEEP_TASK` ฯลฯ เป็น **benign waits** — เกิดจาก background task ของ engine เอง สะสมนาน ๆ จะบวม Top waits จนปัญหาจริงจมหาย (รันจริงใน Section 10.2: Top ของตาราง delta ถูกครองด้วย background ทั้งที่ workload ของเราเพิ่งรัน) — จัดการด้วยการกรองออกตอนจัดอันดับ (รายการ NOT IN สไตล์ Glenn Berry) ไม่ใช่ลบค่า (D) — อ่านต่อ: [Labs Ex2 Expected](Labs/README.md) + [Section 10.2 หัวข้อ 4 จุดตัด "ผิดปกติ"](Sections/02_Baselining_Benchmarking/README.md)
</details>

<details>
<summary><b>เฉลย Q6</b> — A</summary>

เกณฑ์ตั้งต้นที่หลักสูตรใช้: `Avg. Disk sec/Read` < 20 ms (> 20 = disk bottleneck), log write < 5 ms, `% Processor Time` < 80% ค่าเฉลี่ย (sustained > 80% = ปัญหา), `Pages/sec` < 50, `Available MBytes` > 500 MB — และ **กับดักที่ทดสอบจริงบน 17.0.1135.8 แล้วเจอ**: ทุกค่าใน `sys.dm_os_performance_counters` เป็นค่าสะสมตั้งแต่ restart (counter `/sec` ต้อง snapshot 2 จุดหารด้วยเวลา) และ counter กลุ่ม SQL Statistics **ไม่มี instance** — ใส่ `instance_name = N'_Total'` จะได้ 0 แถว — ทุกค่าต้องตีความ **เทียบ baseline ของเครื่องนั้น** ไม่ใช่เป็นกฎตายตัวสากล — อ่านต่อ: [Section 10.1 หัวข้อ 4 PerfMon + ตาราง Counters ที่ต้องรู้จัก](Sections/01_Monitoring_Tracing/README.md)
</details>

<details>
<summary><b>เฉลย Q7</b> — B</summary>

`Full Scans/sec` สูงผิดจาก baseline = query สแกนทั้งตารางบ่อย (missing index หรือ workload เปลี่ยน) ส่วน `Forwarded Records/sec` สูง = heap ที่ถูก update ให้แถวใหญ่ขึ้นถูก forward ไปหน้าอื่นตลอด (heap fragmentation — ทางแก้คือสร้าง clustered index หรือ rebuild) — อ่านต่อ: [Section 10.1 หัวข้อ 4 ตาราง Counters ที่ต้องรู้จัก](Sections/01_Monitoring_Tracing/README.md)
</details>

<details>
<summary><b>เฉลย Q8</b> — B</summary>

`memory_utilization_percentage` วัดเทียบ **target memory ของ SQL เอง** — 100% แปลว่า committed = target (จุดจบของ ramp-up) เป็นสภาวะปกติของ dynamic memory; `process_physical_memory_low = 0` ยืนยันว่า **OS ไม่ได้กดดัน** (ถ้าเป็น 1 = Resource Monitor จะเริ่ม trim caches) — แล็บจริง: 100 / 0 / 0 พร้อม available RAM ~9.9 GB — อ่านต่อ: [Labs Ex3 Expected](Labs/README.md) + [Section 4.2 — SQL Server Memory](../Module_04_Memory/Sections/02_SQL_Server_Memory/README.md)
</details>

<details>
<summary><b>เฉลย Q9</b> — A</summary>

หลักสูตรแนะนำหลักการ least privilege: `##MS_ServerPerformanceStateReader##` ให้อ่าน DMV ด้าน performance โดยไม่ต้อง sysadmin (ใช้กับ monitoring account เสมอ) — ส่วน automation ใช้ **dbatools** (PowerShell): `Get-DbaWaitStatistic`, `Test-DbaLastBackup`, `Invoke-DbaDbDbccCheckTable` — อ่านต่อ: [Module README 7.1](README.md) + [Labs Prerequisites](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q10</b> — B</summary>

Snapshot job คือ SQL Agent Job (T-SQL step เรียก `CaptureBaselineSnapshot` ทุก 15 นาที) — Agent หยุด = ไม่มีใครรัน job (แล็บจริง: Agent บน VM = Stopped ตรวจจาก `sys.dm_server_services`) — ผูก alert เมื่อ fail ด้วย Database Mail + Operator (`sp_add_operator` + `sp_update_job @notify_level_email = 2`) — อ่านต่อ: [Labs Ex1 Step 3 + แนะนำเพิ่ม](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q11</b></summary>

- **เก็บอะไร**: delta ของ wait stats, file I/O latency (`sys.dm_io_virtual_file_stats`), memory (clerks/utilization), blocking (`sys.dm_exec_requests` blocking_session_id), ขนาด DB/tempdb growth, Batch Requests/sec (rate จาก snapshot 2 จุด) และ CPU history จาก Ring Buffer (`RING_BUFFER_SCHEDULER_MONITOR` — ได้ฟรีแม้ไม่ตั้งค่าอะไร)
- **ความถี่**: PerfMon ทุก 15–60 วินาที (ระดับ OS ละเอียด) / DMV snapshot ทุก 5–15 นาที (แล็บใช้ 15 นาที ผ่าน SQL Agent Job)
- **Retention**: 3–6 เดือน เพื่อเห็น trend การเติบโต (capacity planning) และครอบ business cycle รายเดือน/รายไตรมาส
- **ทำไมต้อง delta**: ค่าสะสมตั้งแต่ restart ไม่บอก "ตอนนี้" — เครื่องรันมาหกเดือน ค่าเก่าท่วมจนค่าร้อนใหม่จมหาย; delta หารด้วยช่วงเวลาให้ "ค่าเฉลี่ยช่วงนั้น" ที่เทียบกับ baseline ได้ — อ่านต่อ: [Section 10.2 หัวข้อ 1 Methodology](Sections/02_Baselining_Benchmarking/README.md) + [Labs Ex1–Ex2](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q12</b></summary>

สัญญาณ "ผิดปกติต้องตามต่อ" จาก 6 result sets:
1. **last_restart เมื่อไม่กี่วัน/ชั่วโมง** — ระบบรีบ่อย = สงสัย crash/failover (จำไว้: ค่า wait stats สะสมก็ reset ด้วย!)
2. **`runnable_tasks_count > 0` ค้างหลาย scheduler** — คิว CPU (แล็บจริงเจอ 1 ช่วงมี agent อื่นรัน CPU loop — บนเครื่องว่างปกติ = 0)
3. **รายชื่อ DB ที่ Query Store ปิด** — ควรว่างเสมอ (แล็บจริง = ไม่มี = ดี) เพราะ QS คือ baseline ระดับ query ที่ดีที่สุด
4. **`last_backup = NULL`** = **ยังไม่เคย backup เลย** — ความเสี่ยงระดับวิกฤติ ไม่เกี่ยวกับ tuning แต่ต้องแก้ก่อนอะไรอื่น (แล็บจริง: user DB ทุกตัว = NULL!)
5. สถานะ memory ของ OS ไม่ใช่ "Available physical memory is high" หรือ `process_*_memory_low = 1`

6. การตั้งจุดตัดใช้สองชั้นคู่กัน: **absolute threshold** (เกณฑ์สากล เช่น log write > 5 ms) ตอนเริ่มระบบ แล้วเลื่อนเป็น **baseline-relative** (เทียบค่าเฉลี่ยช่วงเวลาเดียวกันของ 2–4 สัปดาห์ก่อน) เมื่อข้อมูลสะสมพอ — อ่านต่อ: [Labs Ex3 Expected](Labs/README.md) + [Section 10.2 หัวข้อ 4.1 หลักคิดสองชั้น](Sections/02_Baselining_Benchmarking/README.md)
</details>

<details>
<summary><b>เฉลย Q13</b></summary>

- **SQL Profiler/Trace** = Legacy — deprecated, overhead สูง ไม่แนะนำบน production อีกต่อไป
- **Extended Events** = ทดแทน — overhead ต่ำ, ยืดหยุ่น (session/event/predicate/target) ครอบ use case เดิมทั้งหมด (query perf, deadlock, blocking, error — ลงรายละเอียดใน Module 9)
- **Default Trace** = trace เบา ๆ ที่ **เปิดมาให้เองตั้งแต่ติดตั้ง** — จับเหตุการณ์จุดสำคัญอัตโนมัติ เช่น Schema Changes, Errors, **Auto-grow events** (ใช้ย้อนหา "ใครทำให้ log grow ร้อยรอบ") แม้ไม่เคยตั้งค่าอะไรเอง — อ่านต่อ: [Section 10.1 หัวข้อ 6 กล่องดำ — Ring Buffers และ Default Trace](Sections/01_Monitoring_Tracing/README.md)
</details>

<details>
<summary><b>เฉลย Q14</b></summary>

**Glenn Berry Diagnostic Queries** (มีรุ่นสำหรับ SQL Server 2025) = ชุด query ตรวจสุขภาพ instance ที่เรียงหมวด (Instance Level, CPU/NUMA, Memory, Index, Wait Stats ฯลฯ) เป็น "ภาพถ่ายเชิงลึก" มาตรฐานของวงการ

วิธีใช้: ดาวน์โหลดจาก glennsqlperformance.com → รันใน SSMS แบบ **Results to File** → เก็บไฟล์รายวัน/รายสัปดาห์ → เทียบกับ spreadsheet เดิม เห็นค่าที่ขยับ

เชื่อมกับ baseline ที่สร้างเอง: **สองชั้นเสริมกัน** — snapshot job ทุก 15 นาทีจับ delta เชิงเวลา (wait/IO) ส่วนชุด Glenn Berry ให้สแนปช็อต "เชิงลึกทั้งระบบ" ที่รวม config, hardware, version ที่ snapshot ง่าย ๆ ไม่ครอบ — ต่างกันที่ความถี่กับความกว้าง ไม่ใช่แทนกัน — อ่านต่อ: [Labs Ex3 Step 2](Labs/README.md) + [Module README 7.1](README.md)
</details>

<details>
<summary><b>เฉลย Q15</b></summary>

คำนวณ:
- จาก waits: 272 ms ÷ 199 ครั้ง ≈ **1.4 ms/ครั้ง**
- จาก file stats: 567 ms ÷ 490 writes ≈ **1.2 ms/ครั้ง**

สองแหล่ง (wait `WRITELOG` = มุมมอง task ที่รอ, `sys.dm_io_virtual_file_stats` = มุมมอง storage) ให้ค่าใกล้กัน (~1–1.4 ms) จึง **ยืนยันกันอย่างสม่ำเสมอ** ว่า log write latency อยู่ระดับปกติดี (เกณฑ์ < 5 ms) — นี่คือหลัก "ยืนยันด้วยข้อมูลชั้นที่สอง" ของ Waits & Queues

ถ้าเด้งเป็น 50+ ms/ครั้ง: ตรวจว่า .ldf อยู่ disk ไหน/แชร์กับอะไร, auto-grow ของ log (ถ้าพร้อมกันทุก 10 นาที = สงสัย growth), งาน VDI/backup log ช่วงนั้น, และเทียบ FileIOSnapshot ของช่วงเวลาเดียวกัน — อ่านต่อ: [Labs Ex2 Expected](Labs/README.md) + [Section 10.1 หัวข้อ 4 ตาราง Counters (Avg. Disk sec/Write)](Sections/01_Monitoring_Tracing/README.md)
</details>

---

**ท้ายชุดข้อสอบ:** ทำคะแนนได้ ≥ 12/15 ถือว่าผ่านมาตรฐานบทที่ 10 — ถ้ายังไม่ถึง ให้ย้อนอ่าน [10.1 Monitoring & Tracing](Sections/01_Monitoring_Tracing/README.md) → [10.2 Baselining & Benchmarking](Sections/02_Baselining_Benchmarking/README.md) และทำ [Labs](Labs/README.md) ซ้ำอีกรอบ
