# Quiz Bank — Module 11: Troubleshooting (บทที่ 11)

> ครอบคลุม Learning Objectives บทที่ 11 ของ [Course Guide](../../Trainer_Docs/Course_Guide_4Days.md): Top-down framework (Wait Stats → Resource → Query → Index → Config) · CPU Pressure (`SOS_SCHEDULER_YIELD`/`CXPACKET`/MaxDOP) · Memory (`RESOURCE_SEMAPHORE`/PLE) · I/O (`PAGEIOLATCH`/`WRITELOG`) · Concurrency (`LCK_M_*`/Deadlock cycle) · Mitigate vs Root fix · Baseline/Delta · Query Store Regression
> ใช้ทบทวนหลังอ่าน [11.1 Troubleshooting Workflow](Sections/01_Troubleshooting_Workflow/README.md) และ [11.2 Scenarios and Resolution](Sections/02_Scenarios_and_Resolution/README.md) — เฉลยพร้อมคำอธิบายอยู่ท้ายไฟล์

---

## คำถาม

### ชุดที่ 1: กรอบวินิจฉัย (Top-down Framework)

**Q1.** ผู้ใช้โทรแจ้ง "ระบบช้า" ตามกรอบ Top-down ของหลักสูตร สิ่งที่ควรทำ**ก่อน**เปิด DMV คือข้อใด?

- A. รัน `DBCC SQLPERF (sys.dm_os_wait_stats, CLEAR);` เพื่อเริ่มนับใหม่
- B. นิยามปัญหา: Scope (ใคร/ส่วนไหน), Timeline (ช้าเมื่อไร), Impact (เสียอะไร)
- C. เพิ่ม `max server memory` กัน memory ไม่พอ
- D. Restart SQL Server เพื่อล้าง state

**Q2.** ค่าใน `sys.dm_os_wait_stats` เป็นค่า**สะสมตั้งแต่ restart** เหตุใดการวินิจฉัยจึงต้องใช้ **delta** (snapshot 2 จุดลบกัน) และถ้าระบบเปิดมานานหลายเดือน ผลลัพธ์แบบสะสมมักสะท้อนอะไร?

**Q3.** `signal_wait_time_ms` ใน DMV ชี้ไปที่คอขวดประเภทใด และควรอ่านคู่กับ DMV ตัวใดเพื่อยืนยัน?

- A. Disk — คู่กับ `sys.dm_io_virtual_file_stats`
- B. CPU pressure — คู่กับ `runnable_tasks_count` ใน `sys.dm_os_schedulers`
- C. Lock contention — คู่กับ `sys.dm_tran_locks`
- D. Memory — คู่กับ `sys.dm_os_memory_clerks`

### ชุดที่ 2: CPU Pressure

**Q4.** Query ที่ใช้ CPU สูงสุดใน plan cache (`sys.dm_exec_query_stats`) คือ query ที่ `total_worker_time` มากสุด — ข้อใดกล่าวถูกต้องเกี่ยวกับการอ่านค่านี้?

- A. `total_worker_time` เป็นค่าเฉลี่ยต่อ execution อยู่แล้ว
- B. ต้องหารด้วย `execution_count` ก่อน จึงจะได้ต้นทุนต่อการรัน 1 ครั้ง — query ที่รันล้านครั้งด้วย CPU นิดเดียวอาจรวมแล้วโทษกว่า query หนักที่รันครั้งเดียว
- C. หน่วยเป็นวินาที ไม่ต้องแปลง
- D. ต้องลบ `total_elapsed_time` ออกเสมอ

**Q5.** เซิร์ฟเวอร์โชว์ SQL CPU 85% ต่อเนื่อง แต่ delta waits ให้ `ASYNC_NETWORK_IO` เป็นอันดับหนึ่ง และ `signal_wait_pct` เพียง 3% — ข้อสรุปใดถูกต้องที่สุด?

- A. CPU เป็นคอขวด ควร scale-up ทันที
- B. CPU กำลังหมุนรอ client รับ result set — ต้นเหตุอยู่ฝั่ง query ที่ส่งข้อมูลมหาศาล/แอปรับไม่ทัน ซื้อ CPU ไม่แก้ปัญหา
- C. Waits DMV เสีย ต้องใช้ PerfMon
- D. ต้องลด MAXDOP เป็น 1

**Q6.** `SOS_SCHEDULER_YIELD` กับ `CXPACKET`/`CXCONSUMER` ต่างกันอย่างไร และเมื่อเจอ `CXPACKET` เป็น top wait ทำไมต้องกลับไปดู statistics ก่อนปรับ MAXDOP?

### ชุดที่ 3: Memory

**Q7.** เจอ `RESOURCE_SEMAPHORE` โดดขึ้นใน delta waits — ความหมายและชุด query ยืนยันที่ตรงที่สุดคืออะไร?

- A. Buffer pool เล็ก — ดู Page life expectancy
- B. มี query ต่อคิวรอ memory grant — ดู `sys.dm_exec_query_memory_grants` + ตัวนับ `Memory Grants Pending`
- C. Plan cache บวม — ดู `CACHESTORE_SQLCP`
- D. Memory leak ของ OS — ดู `sys.dm_os_sys_memory`

**Q8.** จากเดโม Scenario 4 (sort คอลัมน์กว้าง) — query ได้ grant ~28 MB แต่ใช้จริง ~432 KB ข้อใดเป็นผลร้ายที่แท้จริงของ over-grant ต่อระบบโดยรวม?

- A. ทำให้ query ตัวมันเองช้าขึ้นเท่านั้น
- B. Memory ที่ยืมไปค้างระหว่างรันทำให้ query อื่นรอ grant หรือ buffer pool ถูกกวาด (PLE ตก) — ต้นทุนกระจายทั้ง workload
- C. ทำให้ plan cache เต็ม
- D. ไม่มีผลร้าย ระบบจัดการให้เอง

### ชุดที่ 4: I/O

**Q9.** ไฟล์ LOG ของ database OLTP มี `avg_log_write_ms` = 45 ms ต่อเนื่อง (เกณฑ์อ้างอิง < 5 ms) อธิบายว่าค่านี้สัมพันธ์กับ wait ใด และเพราะกฎ WAL ทำไมทุก transaction จึงต้องจ่ายค่านี้ทุกครั้งที่ commit?

**Q10.** `PAGEIOLATCH_SH` กับ `PAGELATCH_EX` ต่างกันอย่างไร — อันไหนเกี่ยวกับ disk อันไหนเป็นปัญหาใน memory ล้วน ๆ?

### ชุดที่ 5: Concurrency

**Q11.** จากหน้าต่าง A (blocker: `BEGIN TRAN` + `UPDATE` + `WAITFOR` ค้าง) และหน้าต่าง B (victim: `UPDATE` แถวเดียวกัน) — ใน `sys.dm_exec_requests` แถวของหน้าต่าง A มักโชว์รูปแบบใด และแถวของ B โชว์อะไร?

- A. A: `running / SOS_SCHEDULER_YIELD` · B: `running / NULL`
- B. A: `suspended / WAITFOR` พร้อม `open_transaction_count > 0` · B: `suspended / LCK_M_X` โดยมี `blocking_session_id` ชี้ไปที่ A
- C. A: `suspended / LCK_M_X` · B: `suspended / WAITFOR`
- D. A: `runnable / THREADPOOL` · B: `suspended / WRITELOG`

**Q12.** บน database ที่เปิด **RCSI** (อย่าง AdventureWorks ของหลักสูตร) เหตุใด SELECT ธรรมดาจึงไม่ถูก UPDATE block อีกต่อไป และถ้ายังเจอ blocking ในระบบนี้ มาจากคู่ใด?

**Q13.** เกี่ยวกับการ KILL ในหน้างานจริง ข้อใดถูกต้องครบถ้วน?

- A. `KILL @spid` ใช้ตัวแปรได้ตรง ๆ — เขียน `DECLARE @spid INT = 57; KILL @spid;`
- B. ต้องยืนยันตัวตน session ก่อน (ดู text/open transaction) — และบนเวอร์ชันที่ทดสอบ ต้องยิงผ่าน `EXEC(N'KILL ' + @spid)` เพราะ `KILL @spid` เป็น syntax error
- C. KILL ทำให้ transaction ที่ถูก kill กลายเป็น COMMIT อัตโนมัติ
- D. KILL session ใดก็ได้เมื่อเป็น sysadmin

### ชุดที่ 6: Plan Regression และงานทีม

**Q14.** Query Store โชว์ query เดียวมี 2 plan — plan เก่า avg 0.1 ms, plan ใหม่ avg 228 ms เขียนแผนรับมือ: ขั้น mitigate ทันทีคืออะไร (พร้อมข้อควรระวัง) และ root fix ควรตอบคำถามว่าอะไรก่อน?

**Q15.** ทีมคุณไม่เคยเก็บ baseline มาก่อน และเกิด incident "ช้า" ขึ้นเดี๋ยวนี้ — เครื่องมือ/เทคนิคใดที่ยังช่วยได้ทันทีโดยไม่ต้องมีข้อมูลย้อนหลัง (เลือก 2 ข้อ) และเพราะอะไรจึงยังใช้ได้?

- A. Delta waits ภายในหน้าต่างเวลาเดียว (snapshot ตัวเอง 2 จุด)
- B. Query Store ย้อนดู interval ที่แย่สุดและเทียบ plan
- C. เทียบ PLE กับค่าจากเดือนก่อน
- D. อ่านค่าสะสม `sys.dm_os_wait_stats` แล้วสรุปจากอันดับหนึ่งเลย

---

## เฉลยพร้อมคำอธิบาย

### Q1 — ข้อ B

ระบุขอบเขตก่อนเสมอ: Scope/Timeline/Impact ตัดทางเลือกได้มหาศาล (ช้าเฉพาะบางเวลา = ต้องจับตอนเกิดอาการ; ช้าเฉพาะ report ตัวเดียว = โทษ query ไม่ใช่ server) ข้อ A ล้างข้อมูลหลักฐาน (และเป็นสิ่งที่ห้ามทำกับ server ที่ใช้ร่วม), ข้อ C/D คือการแก้โดยไม่มีหลักฐาน — ตรงข้ามกับหลัก Data-driven ของหลักสูตร

### Q2 — ค่าสะสมกลบเหตุการณ์ปัจจุบัน

DMV เก็บรวมทุกอย่างตั้งแต่ restart ถ้าเปิดมาหลายเดือน top waits สะท้อน "ธรรมชาติเฉลี่ยของ workload ทั้งช่วงชีวิต" — เหตุการณ์ที่เกิดวันนี้ถูกเจือจางจนมองไม่เห็น Delta แก้ปัญหานี้: snapshot 2 จุดในหน้าต่างเวลาที่อาการเกิด แล้วลบกัน สิ่งที่ "โตขึ้นกลาย ๆ" ในช่วงนั้นคือตัวปัญหา ไม่ใช่ตัวที่มีค่าสะสมสูงสุด (บล็อก delta waits ทดสอบแล้วอยู่ใน Section 11.1 Step 1.2)

### Q3 — ข้อ B

`signal_wait` = ของ (resource) มาแล้วแต่ยังไม่ได้ CPU — สัญญาณ CPU pressure โดยตรง ยืนยันคู่กับคิว `runnable_tasks_count` ต่อ scheduler (ควร = 0 แทบตลอดเวลา) เกณฑ์เตือน: signal wait ratio > 10–15% ต่อเนื่อง

### Q4 — ข้อ B

`total_worker_time` เป็นค่ารวมของทุก execution ตั้งแต่ compile — หาร `execution_count` จึงได้ต้นทุนต่อครั้ง ทั้งสองมุมมองจำเป็น: รวมมาก = โทษต่อ server ต่อช่วงเวลา, เฉลี่ยสูง = query หนักต่อครั้ง (อาจเป็นทางที่แก้แล้วคุ้มสุด) หน่วยเป็นไมโครวินาที จึงต้องหาร 1000 เป็น ms

### Q5 — ข้อ B

CPU 85% + signal wait แค่ 3% = ไม่มีคิวรอ CPU — เครื่องไม่ได้ "แน่น" แบบ CPU-bound `ASYNC_NETWORK_IO` โดด = engine ผลิตผลลัพธ์เร็วแต่ client รับไม่ทัน (result set ยักษ์ / แอปวนอ่านทีละแถว) ทางแก้อยู่ที่ query (แบ่งหน้า/เลือกคอลัมน์) หรือฝั่ง app — scale-up CPU ยิ่งทำให้ผลิตข้อมูลเร็วขึ้น คอขวดยิ่งชัดขึ้น

### Q6 — Yield คือครบ quantum, CXPACKET คือรอเพื่อนใน parallel plan

`SOS_SCHEDULER_YIELD`: task ใช้ครบ quantum (~4 ms) แล้วต่อคิวให้คนอื่นทำ — สูง = CPU หมุนแท้ ๆ ส่วน `CXPACKET`/`CXCONSUMER` เกิดเมื่อ query แตก parallel แล้ว thread หนึ่งรอเพื่อนที่งานไม่สมส่วน ซึ่งรากมักเป็น **estimate แม่นหรือไม่ (statistics)** — ถ้า stats เก่า row estimate พลาด plan อาจแตก parallel โดยไม่ควร ปรับ MAXDOP/CTFP ก่อนแก้ stats คือการวางยาแปรงอาการทิ้งต้นเหตุไว้

### Q7 — ข้อ B

`RESOURCE_SEMAPHORE` = รอเข้าแถวรับ memory grant (sort/hash) ยืนยันตรงด้วย `sys.dm_exec_query_memory_grants` (ใครถือ grant อะไร ขอไปเท่าไร ใช้จริงเท่าไร) + ตัวนับ `Memory Grants Pending` (> 0 = มีคนต่อคิวจริง) ข้อ A เป็นประเด็น buffer pool ที่มักมาคู่กันแต่ไม่ใช่นิยามของ wait ตัวนี้

### Q8 — ข้อ B

Grant ที่ขอไปแล้วค้างอยู่มือ "ตลอดอายุ query" แม้ใช้จริงแค่ 432 KB — ระหว่างนั้น query อื่นที่ต้องการ grant จะต่อคิว (RESOURCE_SEMAPHORE) และ memory ของ buffer pool โดนตัดจน PLE ตก ต้นทุนจึงกระจายทั้งระบบ ไม่จำกัดที่ตัวเอง (ตัวเลขจริงจากแล็บขนาดเต็ม: ขอ ~700 MB ใช้ ~24 MB)

### Q9 — WRITELOG — WAL บังคับ harden ก่อน commit

45 ms ต่อ flush = storage ที่รับ log write ช้าเกินไป (เกณฑ์ < 5 ms) เพราะกฎ Write-Ahead Logging: **log record ต้องถูกเขียนลง log file จน harden ก่อน transaction จะ commit ได้** — ทุก commit จึงจ่าย "ค่า flush 1 ครั้ง" ไม่มีทางข้าม แอปที่ commit ละนับพันครั้งต่อนาที (micro-transaction storm) จะจ่ายซ้ำ ๆ จนกลายเป็นคอขวดหลัก (เดโมใน Section 11.2 Scenario 6 วัดให้เห็น: ~0.6 ms/commit บน storage ปกติ → ×2,400 บน storage ที่ 45 ms)

### Q10 — PAGEIOLATCH = รอ disk, PAGELATCH = รอ latch ใน memory

`PAGEIOLATCH_SH` — รออ่าน data page **จาก disk เข้า buffer pool** (ปัญหา storage หรือ working set ใหญ่เกิน RAM) `PAGELATCH_EX` — page อยู่ใน memory แล้ว แต่รอ latch เพื่อเขียน (ต้นเฉพาะที่: hot page เช่น last-page insert, tempdb แย่ง allocation) สองตัวแก้คนละทิศ: อันแรกมอง storage/memory/index ลด reads — อันหลังแก้ design (แยก hot range, tempdb files)

### Q11 — ข้อ B

หน้าต่าง A: `status = suspended`, `wait_type = WAITFOR` (กำลังหลับตามคำสั่ง) และ `open_transaction_count > 0` — เครื่องหมาย head blocker เชิงประจักษ์ หน้าต่าง B: `suspended` ด้วย `wait_type = LCK_M_X` และ `blocking_session_id` ชี้หา A (ทดสอบจริงใน Section 11.1 Step 4 — B รอโดยมี A เป็นตัวกั้น)

### Q12 — RCSI อ่านเวอร์ชันเก่าจาก version store

RCSI ทำให้ SELECT อ่าน committed version ล่าสุดจาก version store ใน tempdb — ไม่ต้องขอ S lock จึงไม่โดน writer block (สลับ cost: tempdb รับภาระ versioning) บนระบบนี้ blocking ที่ยังหลงเหลือมาจาก **writer-vs-writer** (UPDATE สองตัวบนแถวเดียว) และ **schema locks** (Sch-M) เช่น DDL — เคส blocking จึงรุนแรงและ "แคบ" กว่ายุคก่อน RCSI

### Q13 — ข้อ B

ทดสอบจริงบน SQL Server 2025 (17.0.1135.8): `KILL @spid` ได้ `Incorrect syntax near '@spid'` — ต้องยิงผ่าน dynamic `EXEC(N'KILL ' + @spid)` พร้อมเงื่อนไขยืนยันตัวตน session (marker text + open transaction + ไม่ใช่ตัวเอง) ก่อนทุกครั้ง ข้อ C ผิด — KILL ทำให้ transaction ถูก **ROLLBACK** (อาจยาวถ้าเขียนมามาก) ข้อ D ผิดเชิงวินัยแม้เป็น sysadmin ก็ตาม

### Q14 — Force plan ก่อน แล้วตอบ "ทำไม plan ใหม่ถึงเกิด"

Mitigate: `EXEC sp_query_store_force_plan @query_id = ..., @plan_id = <plan เร็ว>;` — ได้ผลทันที แต่ควรระวัง: force ผูก plan เดิมไว้ ถ้า workload/data เปลี่ยน อาจกลายเป็นพิษ และต้องมีแผนคืนค่า (`sp_query_store_unforce_plan`) Root fix ต้องตอบก่อนว่า "อะไรทำให้ plan เปลี่ยน" — statistics กระโดด (M6), parameter sniffing (M8), หรือ index/schema ใหม่ แล้วแก้ที่ต้นเหตุ ไม่ใช่ปลอมผลด้วย force เฉย ๆ

### Q15 — A และ B

A (delta ภายในหน้าต่างเดียว): snapshot `sys.dm_os_wait_stats` ตัวเองสองจุดห่าง 15–30 วินาทีตอนที่อาการเกิด — ไม่ต้องมีประวัติ เพราะเทียบกับ "ตัวเองเมื่อครู่" B (Query Store): ถ้าเปิดไว้ก่อนเกิดเหตุ ประวัติ runtime ถูกจดอัตโนมัติแล้ว — ดู interval แย่สุด/plan เทียบได้ย้อนเวลา ส่วน C ต้องมี baseline เก่า, D อ่านสะสมโดยไม่ delta = ตีความไม่ได้บน server ที่เปิดนาน

---

## ลิงก์ทบทวน

- [11.1 Troubleshooting Workflow](Sections/01_Troubleshooting_Workflow/README.md) — กรอบ Top-down + เดโม KILL ที่ทดสอบแล้ว
- [11.2 Scenarios and Resolution](Sections/02_Scenarios_and_Resolution/README.md) — 6 scenarios พร้อม query รันได้
- [Lab 11 — The Broken Server Challenge](Labs/README.md) — ฝึกเองตาม Expected ที่รันจริงไว้
- [Glossary](../Glossary.md) · [Module 05 — Concurrency](../Module_05_Concurrency/README.md) · [Module 08 — Plan Caching](../Module_08_Plan_Caching/README.md)
