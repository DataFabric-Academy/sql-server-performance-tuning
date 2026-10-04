# Quiz Bank — บทที่ 1: Architecture, Scheduling & Waits (SQLOS, NUMA, Waits & Queues)

> ครอบคลุมวัตถุประสงค์การเรียนรู้ของบทที่ 1 ตาม [Course_Guide_4Days.md](../Trainer_Docs/Course_Guide_4Days.md): องค์ประกอบ SQL Server & SQLOS, Process/Thread Model, Windows vs SQL Scheduling (Non-Preemptive/Cooperative), NUMA (Topology/Memory/Thread Affinity) และพื้นฐาน Wait Statistics (Waits & Queues, Resource vs Signal Waits, Common Wait Types) — ใช้คู่กับ [Sections](README.md) และ [Labs](Labs/README.md)
> **รูปแบบ:** ข้อ 1–10 multiple choice · ข้อ 11–15 ตอบสั้น · เฉลยพร้อมคำอธิบายอยู่ท้ายไฟล์ (อย่าเลื่อนดูก่อนตอบ!)

---

## ส่วนที่ 1: Multiple Choice

### Q1. ความต่างสำคัญระหว่าง Windows Scheduler กับ SQLOS Scheduler คืออะไร?
- A. Windows จัดคิวแบบ Cooperative ส่วน SQL Server จัดคิวแบบ Preemptive
- B. Windows บังคับหยุด thread เมื่อหมด time slice (~15.6 ms) ส่วน SQLOS ให้ thread ยอมเอง (yield) เมื่อหมด quantum ~4 ms หรือต้องรอ resource
- C. SQL Server ไม่มี scheduler ของตัวเอง — ยกทุกอย่างให้ Windows จัด
- D. SQLOS ใช้ quantum ยาวกว่า Windows เพื่อให้ query ใหญ่จบเร็วขึ้น

### Q2. Query หนึ่งแสดง `wait_type = SOS_SCHEDULER_YIELD` สลับกับ `status = running` — กลไกนี้บ่งบอกว่าอะไร?
- A. Query รอ disk อ่านข้อมูลไม่ทัน
- B. Query ถูก lock บล็อกแล้วถอยออกจาก CPU ชั่วคราว
- C. Worker ใช้ CPU ครบ quantum ~4 ms แต่งานยังไม่จบ จึงยอม CPU แล้วต่อท้าย runnable queue
- D. Worker หมดโควตา memory แล้วรอ Resource Monitor จัดสรรใหม่

### Q3. ค่า `runnable_tasks_count` จาก `sys.dm_os_schedulers` มีความหมายอย่างไร?
- A. จำนวน task ที่กำลังรอ resource (เช่น disk, lock)
- B. ความยาวของ Runnable list — task ที่ "ของพร้อมแล้วแต่ยังไม่ได้ CPU" — ค้าง > 0 ต่อเนื่องคือคิว CPU จริง
- C. จำนวน worker threads ที่ถูกสร้างทั้งหมด
- D. จำนวน pending disk I/O ที่ scheduler รับไว้

### Q4. เซิร์ฟเวอร์หนึ่ง CPU utilization เฉลี่ยแค่ 60% แต่ `runnable_tasks_count` ของ scheduler บางตัวค้าง > 0 ตลอดเวลา สาเหตุที่อธิบายได้ดีที่สุดคือข้อใด?
- A. CPU ชำรุด — ต้องเปลี่ยนฮาร์ดแวร์
- B. Query แบบ single-threaded (หรือ MAXDOP = 1) อิ่ม scheduler เดียวจนเต็ม ขณะ scheduler อื่นว่าง — ค่าเฉลี่ยทั้งเครื่องจึงไม่สะท้อนคอขวดราย scheduler
- C. `sys.dm_os_schedulers` รายงานค่าผิดบนระบบหลาย NUMA node
- D. CPU utilization 60% หมายถึง idle 60% — จึงยังเหลือ CPU ให้ query อีกมาก

### Q5. สมการ Signal Wait Ratio และเกณฑ์ตีความที่ถูกต้องคือข้อใด?
- A. `SUM(signal_wait_time_ms) / SUM(wait_time_ms) * 100` — สูงกว่า 10–15% ต่อเนื่อง = CPU pressure
- B. `SUM(wait_time_ms - signal_wait_time_ms) / SUM(wait_time_ms) * 100` — สูงกว่า 50% = ปกติ
- C. `MAX(signal_wait_time_ms) / 60` — สูงกว่า 1 = รอ CPU เกินหนึ่งนาที
- D. `COUNT(runnable_tasks) / COUNT(workers) * 100` — สูงกว่า 20% = worker หมด

### Q6. เห็น wait `THREADPOOL` ปรากฏในระบบ ควรตีความและจัดลำดับความรุนแรงอย่างไร?
- A. รอ cache ของ plan — เรื่องปกติ เกิดได้กับทุก server
- B. Worker threads ถึงเพดาน (`max_workers_count`) แล้ว — เป็นภาวะวิกฤต เพราะ request ใหม่ไม่มี worker รับงานเลย
- C. รอ network buffer — แก้ด้วยเพิ่ม bandwidth
- D. Wait ของงาน backup เท่านั้น — ไม่กระทบ query ผู้ใช้

### Q7. Session ที่รัน `SELECT` ส่งผลลัพธ์ขนาดใหญ่ไปให้ client ที่อยู่ไกล (WAN) ค้างในสถานะ suspended ด้วย `ASYNC_NETWORK_IO` และขณะเดียวกัน session อื่นรอ `ALTER DATABASE` — การตีความที่ถูกคือข้อใด?
- A. Storage ช้า — ต้องอัปเกรด disk ก่อน
- B. SQL Server พร้อมส่งข้อมูลแล้วแต่ client/network กลืนไม่ทัน (ปัญหาฝั่ง app) และเพราะ session นี้ยังถือ lock ค้าง มันกลายเป็น head blocker ไปบล็อกคำสั่งอื่นด้วย
- C. ASYNC_NETWORK_IO หมายถึง NIC เสีย — ตรวจการ์ด network
- D. ต้องเพิ่ม `max_worker_threads` เพื่อให้ส่งข้อมูลได้เร็วขึ้น

### Q8 (เลือกได้หลายข้อ). Wait ใดบ่งบอก "คอขวด CPU" โดยตรง? (เลือก 2 ข้อ)
- A. `WRITELOG`
- B. `SOS_SCHEDULER_YIELD`
- C. `THREADPOOL`
- D. `PAGEIOLATCH_SH`

### Q9. เหตุใด query ตรวจ scheduler จึงต้องกรอง `WHERE scheduler_id < 1048576`?
- A. เพราะ scheduler_id เกินค่านี้เป็น scheduler ที่ซ่อนอยู่สำหรับงานระบบ (เช่น DAC) ไม่ใช่ scheduler ที่รับ workload ผู้ใช้
- B. เพราะ scheduler_id มีค่าสูงสุดแค่ 1,048,575 ทั้ง engine
- C. เพื่อกรองเฉพาะ scheduler ที่ offline
- D. เพราะ query ที่ไม่กรองจะ error division by zero

### Q10. เรื่องใดต่อไปนี้ "เปลี่ยนไป" บน SQL Server 2025 ตามที่หลักสูตรรันตรวจจริง?
- A. Cooperative scheduling ถูกแทนด้วย preemptive scheduling แบบเดียวกับ OS
- B. คอลัมน์ `is_user_process` ถูกถอดออกจาก `sys.dm_exec_requests` — ต้อง join ไปที่ `sys.dm_exec_sessions` แทน (query แบบเก่า error `Invalid column name`)
- C. `sys.dm_os_wait_stats` ถูกถอดออก เหลือแต่ Extended Events
- D. จำนวน scheduler ถูกล็อกให้เท่ากับจำนวน NUMA node เสมอ

---

## ส่วนที่ 2: ตอบสั้น

### Q11. เขียนสมการ Response Time ในแนวคิด Waits & Queues แล้วอธิบายว่าทำไม "ผู้ใช้ร้องช้า" จึงอย่าเพิ่งตัดสินจากกราฟ CPU อย่างเดียว — ทิศทางแก้ที่ผิดที่พบบ่อยคืออะไร?

### Q12. ค่าใน `sys.dm_os_wait_stats` เป็น "ค่าสะสมตั้งแต่ restart" — อธิบายว่าวิธีอ่านที่ถูกต้องทำอย่างไร (delta), benign waits คืออะไร และคำสั่งใดใช้รีเซ็ตค่า (พร้อมข้อห้าม)

### Q13. จากแล็บจริง: หลังจำลอง workload กิน CPU `SOS_SCHEDULER_YIELD` เพิ่มจาก 6,689 → 17,185 ครั้ง (signal 0.89s → 10.48s) แต่ `signal_wait_pct` รวมทั้ง instance ยังอยู่ 3.9% เท่าเดิม — อธิบายเหตุผล และถ้ารันบน localhost ในห้องเรียนผลจะต่างจากนี้อย่างไร?

### Q14. คุณต้องออกแบบ health check ตรวจ CPU pressure ด้วย DMV 3 ตัว: `sys.dm_os_sys_info`, `sys.dm_os_schedulers`, `sys.dm_os_wait_stats` — จะดูคอลัมน์/ค่าใดจากแต่ละตัว และเกณฑ์อ่านคืออะไร (ระบุทั้ง runnable queue และ Signal Wait Ratio)

### Q15. Top-1 wait ของ instance ทดสอบคือ `PREEMPTIVE_OS_CRYPTOPS` (77.1%) — wait ตระกูล `PREEMPTIVE_*` หมายถึงอะไร มักมาจากอะไรบ้าง และควรจัดอยู่ในหมวด "น่ากังวล" หรือ "benign" ของการวิเคราะห์นี้หรือไม่ เพราะเหตุใด?

---

## เฉลยพร้อมคำอธิบาย

<details>
<summary><b>เฉลย Q1</b> — B</summary>

Windows เป็น **Preemptive** (kernel บังคับหยุดเมื่อหมด time slice ~15.6 ms) ส่วน SQL Server สร้าง **SQLOS Scheduler ของตัวเองแบบ Cooperative/Non-Preemptive**: worker ยอม CPU เองเมื่อต้องรอ resource หรือครบ quantum ~4 ms — ลด context switch overhead เพราะ SQL รู้บริบทงานของตัวเองดีกว่า OS อ่านต่อ: [Section 1.2 — Scheduling](Sections/02_Scheduling_Windows_vs_SQL/README.md)
</details>

<details>
<summary><b>เฉลย Q2</b> — C</summary>

`SOS_SCHEDULER_YIELD` คือ wait type ที่ถูกบันทึกเมื่อ **quantum (~4 ms) หมดแต่งานยังไม่จบ** — worker ยอม CPU แล้วต่อท้าย runnable queue เป็นรอบ เจอเยอะ = งาน CPU-bound (สแกนคำนวณหนัก) ไม่ใช่การรอ disk หรือ lock อ่านต่อ: [Section 1.4 — Wait Statistics](Sections/04_Wait_Statistics/README.md)
</details>

<details>
<summary><b>เฉลย Q3</b> — B</summary>

`runnable_tasks_count` = ความยาวของ **Runnable list** (task พร้อมทำงานแต่รอ CPU) — ต่างจาก A ซึ่งเป็น suspended/waiter (ดูจาก `sys.dm_exec_requests` สถานะ suspended คู่ wait_type) ค่าค้าง > 0 ต่อเนื่องบน scheduler เดียวกัน = มีคิว CPU จริง อ่านต่อ: [Section 1.2](Sections/02_Scheduling_Windows_vs_SQL/README.md)
</details>

<details>
<summary><b>เฉลย Q4</b> — B</summary>

Scheduling ของ SQL Server เป็น **ต่อ scheduler (ต่อ CPU)** — query ที่รัน serial ใช้ได้ scheduler เดียว ถ้ามันอิ่มเต็ม คิวค้างจะเกิดเฉพาะตัวนั้น แต่ CPU รวมทั้งเครื่องยังเหลือ (scheduler อื่น idle) จึงต้องดูราย scheduler ไม่ใช่ค่าเฉลี่ย ข้อ D ผิดเพราะ 60% คือการใช้งาน ไม่ใช่ idle — อ่านต่อ: [Section 1.2](Sections/02_Scheduling_Windows_vs_SQL/README.md) + คำถามท้ายแล็บข้อ 3
</details>

<details>
<summary><b>เฉลย Q5</b> — A</summary>

Signal Wait = ของมาแล้วแต่ **รอ CPU ว่าง** (อยู่ใน runnable) — สูงกว่า 10–15% **ต่อเนื่อง** = CPU pressure ส่วนตัวที่เหลือ (`wait_time_ms − signal_wait_time_ms`) คือ Resource Wait (รอ disk/lock/network จริง) อ่านต่อ: [Section 1.4 — Wait Statistics](Sections/04_Wait_Statistics/README.md)
</details>

<details>
<summary><b>เฉลย Q6</b> — B</summary>

`THREADPOOL` = request ต้องรอ "worker ว่าง" เพราะถึงเพดาน `max_workers_count` (ตรวจได้จาก `sys.dm_os_sys_info`) — เมื่อ worker หมด request ใหม่ไม่มีใครรับ ระบบจะอัมพาตทั้ง instance (แม้แต่คำสั่งวินิจฉัย) จัดเป็น **วิกฤต** มักมาจาก blocking ยาวหรือ workload connection จิ๋วจำนวนมาก — อ่านต่อ: [Section 1.4](Sections/04_Wait_Statistics/README.md) หมวด CPU
</details>

<details>
<summary><b>เฉลย Q7</b> — B</summary>

`ASYNC_NETWORK_IO` = SQL **พร้อมส่งแต่ client รับไม่ทัน** — แก้ฝั่ง application (streaming, TOP, chunking) ไม่ใช่แก้ storage และแล็บรันจริงพบ chain สด: session ที่ค้างสตรีมผล **ถือ lock ค้าง** ไป block คำสั่ง `ALTER DATABASE` ของ session อื่น (`LCK_M_X`) — อ่านต่อ: [Labs Ex4](Labs/README.md) + [Section 1.4](Sections/04_Wait_Statistics/README.md)
</details>

<details>
<summary><b>เฉลย Q8</b> — B และ C</summary>

`SOS_SCHEDULER_YIELD` (หมด quantum) และ `THREADPOOL` (worker หมด) คือสัญญาณ CPU/scheduling โดยตรง ส่วน `WRITELOG` = รอเขียน transaction log (storage), `PAGEIOLATCH_SH` = รออ่าน data page จาก disk (storage/memory) — อ่านต่อ: [Section 1.4](Sections/04_Wait_Statistics/README.md) ตารางจัดกลุ่ม wait ตามคอขวด
</details>

<details>
<summary><b>เฉลย Q9</b> — A</summary>

Scheduler ที่มองเห็นสำหรับ workload ผู้ใช้มี `scheduler_id < 1048576` — ตัวที่เกินคือ **hidden schedulers** สำหรับงานระบบ (Ghost Cleanup, Checkpoint, Query Store async และ **DAC** ที่อยู่ node 64) ซึ่งไม่ควรนำมาคิดค่าเฉลี่ย load ของ workload — อ่านต่อ: [Section 1.2 หัวข้อ 6](Sections/02_Scheduling_Windows_vs_SQL/README.md) + [Labs Ex1 Step 3](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q10</b> — B</summary>

ตรวจจริงบน SQL Server 2025 (17.0.1000.7): query ที่อ้าง `r.is_user_process` กับ `sys.dm_exec_requests` error `Invalid column name` — คอลัมน์นี้ยังอยู่ที่ **`sys.dm_exec_sessions`** เท่านั้น (โปรดดูประเด็น A: lightweight pooling กลับถูกประกาศ **deprecated** ใน 2025 — cooperative scheduling คือโมเดลเดียวที่เหลือ ไม่ใช่ถูกแทน) — อ่านต่อ: [Section 1.5 — Modern Features 2025](Sections/05_Modern_Features_2025/README.md) + [SignOff ข้อค้นพบ 1](../Trainer_Docs/SignOff/AllLabs_SignOff.md)
</details>

<details>
<summary><b>เฉลย Q11</b></summary>

**Response Time = Service Time (RUNNING บน CPU) + Resource Wait (SUSPENDED รอ resource) + Signal Wait (RUNNABLE รอ CPU)**

อย่าตัดสินจาก % CPU อย่างเดียว เพราะเวลาที่ผู้ใช้รู้สึกช้าอาจเป็น Resource Wait (disk/lock) หรือ Signal Wait (คิว CPU) ซึ่งแก้คนละทาง — ทิศทางแก้ที่ผิดพบบ่อย: งานรอ **disk** (PAGEIOLATCH) แต่ไปเพิ่ม **CPU** — เสียเงินเปล่าเพราะแก้ผิดจุด ให้แปล wait type อันดับต้น (หลังกรอง benign) เป็น resource ก่อนเสมอ — อ่านต่อ: [Section 1.2 หัวข้อ 3](Sections/02_Scheduling_Windows_vs_SQL/README.md) + [Section 1.4](Sections/04_Wait_Statistics/README.md)
</details>

<details>
<summary><b>เฉลย Q12</b></summary>

- **อ่านแบบ delta**: snapshot ค่าสะสมสองจุดเวลา (เช่นห่างกัน 15 นาที) แล้วลบกันต่อ wait type — ได้ "ตอนนี้" ไม่ใช่ "ตั้งแต่ restart" (วิธีนี้ใช้เต็มรูปแบบใน Module 10)
- **Benign waits** = wait จาก background task ของ engine เอง (`SLEEP_TASK`, `XE_TIMER_EVENT`, `BROKER_*`, `LOGMGR_QUEUE` ฯลฯ) — สะสมนาน ๆ จะบวม Top waits จนปัญหาจริงจมหาย ต้องกรองออกก่อนจัดอันดับ (รายชื่อสไตล์ Glenn Berry อยู่ในแล็บ Ex2)
- **รีเซ็ต**: `DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);` — **ทำเฉพาะ VM ทดสอบ** ห้ามบน production เพราะประวัติสะสมจะหายหมด

อ่านต่อ: [Section 1.4 หัวข้อ 1](Sections/04_Wait_Statistics/README.md) + [Labs Cleanup](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q13</b></summary>

เหตุผล: ตัวเลข `signal_wait_pct` เป็น **สัดส่วนเทียบกับ wait ทั้งหมดของ instance** — การรันแล็บผ่าน WAN ทำให้ `ASYNC_NETWORK_IO` (รอ client รับผล) ถูกเติมเข้าตัวหารจำนวนมาก จึง "เจือจาง" สัดส่วนของ signal wait ลง แม้เวลา signal จริงโตจาก 0.89s → 10.48s (มากกว่า 10 เท่า) ก็ตาม

บน **localhost/LAN ในห้องเรียน** ไม่มี ASYNC_NETWORK_IO มาเจือ จึงจะเห็น `signal_wait_pct` พุ่งชัดเจนตาม workload — บทเรียนคือตีความ ratio ต้องดู **ตัวเลขดิบ (signal seconds) คู่กับสัดส่วน** และรู้บริบท workload — อ่านต่อ: [Labs Ex3 Step 4 — Expected](Labs/README.md)
</details>

<details>
<summary><b>เฉลย Q14</b></summary>

1. **`sys.dm_os_sys_info`** — `cpu_count`, `numa_node_count`, `max_workers_count`, `scheduler_count`, `sqlserver_start_time`: รู้ขนาดเครื่อง/เพดาน worker และความยาวอายุค่าสะสม (เทียบ restart)
2. **`sys.dm_os_schedulers`** (กรอง `scheduler_id < 1048576`, `status = 'VISIBLE ONLINE'`) — `runnable_tasks_count`: **ค้าง > 0 ต่อเนื่อง = มีคิว CPU** (แล็บจริง: รัน 4 loops บน 4 schedulers เห็น runnable = 2 บน scheduler 0)
3. **`sys.dm_os_wait_stats`** — คำนวณ **Signal Wait Ratio > 10–15% ต่อเนื่อง = CPU pressure** และดูว่า `SOS_SCHEDULER_YIELD` ขึ้นอันดับ Top waits หลังกรอง benign หรือไม่

อ่านต่อ: [Labs Ex1–Ex2](Labs/README.md) + [Section 1.4](Sections/04_Wait_Statistics/README.md)
</details>

<details>
<summary><b>เฉลย Q15</b></summary>

`PREEMPTIVE_*` = เวลาที่ SQL Server ต้อง **ออกไปเรียก Windows API นอก SQLOS** (ยอมให้ OS จัดคิวแบบ preemptive ชั่วขณะ) — พบบ่อยจาก Linked Server, xp_cmdshell, CLR, และงานระบบต่าง ๆ (เช่น crypto ของ setup/ตรวจ certificate ตอน restart)

จัดเป็น **benign ในบริบทนี้**: 77.1% เกิดจากกิจกรรม background/preemptive ops ของ instance ทดสอบที่ว่าง ไม่ใช่คอขวด workload — ต่างจากกรณี `PREEMPTIVE_OS_FILEOPS` สูงผิดปกติต่อเนื่องซึ่งต้องตามหา caller (Linked Server ฯลฯ) หลักการเดียวกับ benign waits: กรอง/ตีความตามบริบท อย่าตกใจจากตัวเลขสัมบูรณ์ — อ่านต่อ: [Section 1.2 หัวข้อ 6](Sections/02_Scheduling_Windows_vs_SQL/README.md) + [Labs Ex2 Expected](Labs/README.md)
</details>

---

**ท้ายชุดข้อสอบ:** ทำคะแนนได้ ≥ 12/15 ถือว่าผ่านมาตรฐานบทที่ 1 — ถ้ายังไม่ถึง ให้ย้อนอ่าน [1.1 Engine Architecture & SQLOS](Sections/01_Engine_Architecture_SQLOS/README.md) → [1.2 Scheduling](Sections/02_Scheduling_Windows_vs_SQL/README.md) → [1.3 NUMA](Sections/03_NUMA_Architecture/README.md) → [1.4 Wait Statistics](Sections/04_Wait_Statistics/README.md) → [1.5 Modern Features 2025](Sections/05_Modern_Features_2025/README.md) และทำ [Labs](Labs/README.md) ซ้ำอีกรอบ
