# Quiz Bank — Module 09: Extended Events (บทที่ 9)

> ครอบคลุม Learning Objectives บทที่ 9 ของ [Course Guide](../../Trainer_Docs/Course_Guide_4Days.md): สถาปัตยกรรม Session/Event/Action/Predicate/Target · Profiler vs XEvents · สร้าง session ด้วย SSMS Wizard vs T-SQL · Ring Buffer vs File Target · Use cases (query perf, deadlock, blocking, error) · Time-bound sessions · การอ่านผลด้วย XQuery
> ใช้ทบทวนหลังอ่าน [9.1 XE Core Concepts](Sections/01_XE_Core_Concepts/README.md) และ [9.2 Working With Extended Events](Sections/02_Working_With_Extended_Events/README.md) — เฉลยพร้อมคำอธิบายอยู่ท้ายไฟล์

---

## คำถาม

### ชุดที่ 1: สถาปัตยกรรมและแนวคิด

**Q1.** องค์ประกอบใดของ Extended Events ทำหน้าที่ "กรองเหตุการณ์ตั้งแต่จุดเกิดเหตุ ก่อนเขียนลง buffer" — ซึ่งเป็นกลไกหลักที่ลด overhead ได้มากที่สุด?

- A. Action
- B. Predicate
- C. Target
- D. Dispatcher

**Q2.** เหตุใด Extended Events จึงมี overhead ต่ำกว่า SQL Trace / SQL Server Profiler อย่างมีนัยสำคัญ?

- A. XEvents เก็บข้อมูลน้อยกว่าเพราะไม่มี payload
- B. XEvents ส่งข้อมูลแบบ asynchronous — thread ของ query เขียนลง memory buffer แล้วทำงานต่อทันที โดยไม่รอ I/O
- C. XEvents รันบน CPU แยกของตัวเอง
- D. XEvents เก็บข้อมูลเป็น text file ที่เล็กกว่า

**Q3.** ข้อใดกล่าวถูกต้องเกี่ยวกับ SQL Trace / SQL Server Profiler?

- A. ยังเป็นเครื่องมือที่ Microsoft แนะนำสำหรับ production
- B. มี overhead ต่ำกว่า XEvents เมื่อ workload หนัก
- C. ถูกประกาศ deprecated มานานและถูกถอดออกจาก SSMS รุ่นใหม่ — ตัวแทนคือ XEvents
- D. ยังจำเป็นสำหรับการจับ Deadlock Graph

**Q4.** เรียงลำดับการไหลของข้อมูลใน XEvents ให้ถูกต้อง:

- A. Event → Target → Buffer → Predicate → Action
- B. Event → Predicate → Action → Buffer → Dispatcher → Target
- C. Predicate → Target → Event → Dispatcher → Buffer
- D. Buffer → Event → Action → Predicate → Dispatcher

**Q5.** `ACTION` ใน event session คืออะไร และมีข้อแลกเปลี่ยน (trade-off) อย่างไร?

---

### ชุดที่ 2: การเขียน Session และหน่วยค่าต่าง ๆ

**Q6.** ค่า `duration` ใน payload ของ `sql_statement_completed` มีหน่วยเป็นอะไร และต้องเขียน predicate อย่างไรเพื่อจับ query ที่ใช้เวลาเกิน 2 วินาที?

- A. หน่วยมิลลิวินาที — `WHERE duration > 2000`
- B. หน่วยไมโครวินาที — `WHERE duration > 2000000`
- C. หน่วยวินาที — `WHERE duration > 2`
- D. หน่วย tick — `WHERE duration > 200`

**Q7.** เขียน predicate ดังนี้:

```text
WHERE database_id = DB_ID(N'AdventureWorks')
```

ผลลัพธ์เมื่อ CREATE EVENT SESSION บน SQL Server 2025 คืออะไร และทางที่ถูกคืออะไร?

**Q8.** รัน query จาก window ที่ context เป็น `master` โดยอ้างตารางแบบ 3 ส่วน (`AdventureWorks.Sales.SalesOrderDetail`) และ session ตั้ง predicate `sqlserver.database_name = N'AdventureWorks'` — event จะถูกจับหรือไม่ เพราะเหตุใด?

---

### ชุดที่ 3: Targets

**Q9.** จับคู่ target ให้เหมาะกับโจทย์:

| โจทย์ | ตัวเลือก target |
|:------|:----------------|
| (a) นับจำนวน error แยกตาม error_number ว่าตัวไหนเกิดบ่อยสุด | 1. ring_buffer |
| (b) เก็บสถานการณ์ deadlock ไว้ตรวจสอบย้อนหลังหลัง server restart | 2. event_file |
| (c) ดูสด statement ที่ช้าในช่วงแก้ปัญหาจุดเดียว (ไม่ต้องการเก็บถาวร) | 3. histogram |
| (d) รู้ว่า event เกิดกี่ครั้ง โดยไม่สนเนื้อหา | 4. event_counter |

**Q10.** ข้อใดกล่าวถูกต้องเกี่ยวกับ `ring_buffer` และ `event_file`?

- A. ring_buffer ใหญ่ได้ไม่จำกัด จึงไม่ต้องระวัง memory
- B. event_file เต็มแล้วจะหยุดเก็บข้อมูลจนกว่าจะ DROP session
- C. ring_buffer เก็บใน memory แบบ FIFO เขียนทับของเก่า ข้อมูลหายเมื่อ restart — ส่วน event_file เขียนลงดิสก์พร้อม rollover โดยจำกัดพื้นที่ด้วย `max_file_size` + `max_rollover_files`
- D. ทั้งสองตัวเขียนลงดิสก์แบบ synchronous

---

### ชุดที่ 4: Use cases — Deadlock / Blocking / Error

**Q11.** ต้องการดู Deadlock Graph ที่เกิดขึ้นเมื่อคืนวานตอนตีสาม แต่ยังไม่เคยสร้าง XEvent session ใด ๆ เอง — แหล่งข้อมูลแรกที่ควรไปดูคืออะไร?

- A. `sys.dm_exec_requests` — ดู blocking ปัจจุบัน
- B. Event `xml_deadlock_report` จาก session **system_health** (ring_buffer หรือ event_file)
- C. SQL Server Profiler
- D. `sys.dm_os_wait_stats`

**Q12.** สร้าง session จับ `blocked_process_report` แล้วแต่ทำการทดสอบ SELECT บน DB ที่เปิด **RCSI** โดยมี UPDATE ค้างอยู่ — เหตุใด event จึงไม่ยิง และแก้อย่างไร (สองเรื่อง: ค่า config ที่ต้องตั้ง และลักษณะการทดสอบที่ถูก)

---

### ชุดที่ 5: การอ่านผลและ Best Practices

**Q13.** สอง query ต่อไปนี้อ่านข้อมูลจาก ring_buffer กับจากไฟล์ .xel — อธิบายว่าทำไม path ของ XQuery จึงต่างกันที่คำว่า `event/`:

```sql
-- (A) อ่าน ring_buffer หลัง CROSS APPLY buf.nodes('//event') AS n(x)
x.value('(data[@name="duration"]/value)[1]', 'BIGINT')

-- (B) อ่านจาก sys.fn_xe_file_target_read_file หลัง CAST(event_data AS XML)
x.value('(event/data[@name="duration"]/value)[1]', 'BIGINT')
```

**Q14.** สร้าง session สำหรับ production capture แล้วต้องการให้: (1) ข้อมูลอยู่รอดเมื่อ server restart (2) ไม่กินดิสก์เกินที่คำนวณได้ (3) รู้ทันเมื่อ buffer กดดันจนต้องทิ้ง event — จะกำหนดค่าใดและดูคอลัมน์ใด?

**Q15.** ข้อใดเป็นวิธีที่ถูกต้องในการ "จำกัดอายุ" ของ XEvent session บน SQL Server 2025 (เพราะไม่มี AUTO_STOP)?

- A. ตั้ง `WITH (AUTO_STOP = ON)` — engine ปิดให้เองเมื่อไฟล์เต็ม
- B. ตั้ง `max_memory` น้อย ๆ แล้วหวังว่า session จะเลิกทำงานเอง
- C. จำกัดขนาด target (max_file_size / max_memory) แล้วปิดตามเวลาด้วย SQL Agent job ที่รัน `ALTER EVENT SESSION ... STATE = STOP` (หรือ DROP)
- D. รอผู้ดูแลระบบ restart server — session จะถูกลบเอง

---

---

## เฉลยพร้อมคำอธิบาย

### Q1 — ข้อ B (Predicate)

Predicate คือเงื่อนไขที่ engine ประเมิน **ณ จุดเกิดเหตุ** — เหตุการณ์ที่ไม่ผ่านเงื่อนไขไม่ถูกเขียนลง buffer เลย (Early Filtering) จึงไม่กิน memory และ dispatch ทรัพยากร ต่างจาก Action (เพิ่มข้อมูลให้ event ที่ผ่านแล้ว — มีต้นทุน) และ Target (ผู้รับปลายทาง)

### Q2 — ข้อ B

หัวใจคือสถาปัตยกรรม asynchronous: thread ที่รัน query แค่ "ยัดข้อมูลลง memory buffer" แล้วกลับไปทำงานต่อ — ส่วน Dispatcher (background thread) ค่อยดึงไป target ทุก MAX_DISPATCH_LATENCY SQL Trace ทำตรงข้าม (synchronous — engine รอระบบ trace) จึงต้องแบกต้นทุนของผู้ติดตามไปกับ workload ทั้งหมด ข้อสังเกต D ผิดเพราะ event_file เป็น binary format (.xel) ไม่ใช่ text และขนาดข้อมูลไม่ใช่ปัจจัยหลักของ overhead

### Q3 — ข้อ C

SQL Trace/Profiler ถูกประกาศ deprecated ตั้งแต่ยุค 2012 และถูกถอดออกจาก SSMS รุ่นใหม่แล้ว (SSMS ยังมี XEvent Profiler ที่ให้ UX คล้ายเดิมแต่เป็น XE session ข้างใน) Deadlock Graph จับได้จาก XEvents (`xml_deadlock_report`) โดยไม่ต้องพึ่ง Profiler

### Q4 — ข้อ B

ลำดับจริง: engine เกิดเหตุการณ์ → ประเมิน predicate (ไม่ผ่าน = จบที่นี่) → รวม action (ถ้ากำหนด) → เขียนลง buffer → dispatcher thread ส่งต่อ target ตาม MAX_DISPATCH_LATENCY ทิศทางผิด ๆ ที่เหลือสับสนระหว่าง "ผู้ตัดสินใจก่อน" (predicate) กับ "ปลายทาง" (target)

### Q5 — Action = ข้อมูลเสริมจากสถานะร่วมของ engine

Action (global fields) เช่น `sql_text`, `client_app_name`, `username`, `session_id` คือข้อมูลที่ event ไม่แจกเอง ต้อง "ดึงเพิ่ม" จากสภาพแวดล้อมของ engine ณ จุดเกิดเหตุ Trade-off: ทุก action มีต้นทุนการประมวลผลเพิ่มใน hot path ของ query จึงควรขอเฉพาะที่จะใช้วิเคราะห์จริง — ไม่ใช่เก็บถัวเฉลี่ยกันลืม

### Q6 — ข้อ B (ไมโครวินาที — `duration > 2000000`)

XEvents วัดเวลาเป็นไมโครวินาที (µs) ตลอด — 2 วินาที = 2,000,000 µs หน่วยนี้ยืนยันจาก `sys.dm_xe_object_columns` (description ระบุ "in microseconds") ข้อผิดพลาดคลาสสิกคือเขียน `> 2000` จะกลายเป็นจับทุกอย่างที่เกิน 2 ms และตอนอ่านผลต้องหาร 1,000 ก่อนรายงานเป็นมิลลิวินาที

### Q7 — ล้มด้วย syntax error / ใช้ field ของ engine แทน

Predicate ของ XEvents **ห้ามเรียกฟังก์ชัน T-SQL** — ทดสอบจริงบน SQL Server 2025 (17.0.1135.8) ได้ `Incorrect syntax near 'DB_ID'` ทางที่ถูกคือใช้ field ที่ engine จัดให้:

```sql
WHERE sqlserver.database_name = N'AdventureWorks'
```

หรือใส่ตัวเลข id ตรง ๆ (หาด้วย `SELECT DB_ID('AdventureWorks');` ก่อนแล้วค่อยนำมาเขียน)

### Q8 — ไม่ถูกจับ เพราะ database_name อ้าง context ของ session ตอนเกิดเหตุ

predicate `sqlserver.database_name` วัดจาก database context (ผลของ `USE`) ของ session ขณะนั้น — ไม่ใช่ database ที่ตารางที่อ้างถึงอยู่ ทดสอบจริง: รันจาก context `master` ด้วยชื่อตาราง 3 ส่วน event หายทั้งหมด ย้ายไป `USE AdventureWorks;` ก่อนจึงจับได้ จุดนี้สำคัญตอน deploy session จริง เพราะ application แต่ละตัวต่อเข้า default database ต่างกัน

### Q9 — (a)=3, (b)=2, (c)=1, (d)=4

- (a) histogram — จัดกลุ่มด้วย `source = N'error_number'` (`source_type = 0` = อ้าง payload) แล้วนับจำนวนต่อกลุ่ม
- (b) event_file — เก็บถาวรลงดิสก์ รอดจาก restart และอ่านย้อนหลังได้ด้วย `sys.fn_xe_file_target_read_file`
- (c) ring_buffer — ดูสดเร็ว แต่ข้อมูลชั่วคราว (เขียนทับ/หายเมื่อ restart) พอดีกับงานแก้ปัญหาจุดเดียว
- (d) event_counter — นับอย่างเดียว ไม่เก็บเนื้อหา จึงเบาที่สุด

### Q10 — ข้อ C

ring_buffer: memory วงกลม (FIFO) จำกัดด้วย `max_memory` (KB) เต็มแล้วเขียนทับของเก่า และหายทั้งหมดเมื่อ restart event_file: ดิสก์ จำกัดด้วย `max_file_size` (MB) ต่อไฟล์ — เต็มแล้ว rollover สร้างไฟล์ใหม่และลบไฟล์เก่าสุดเมื่อเกิน `max_rollover_files` จึงผูกเพดานพื้นที่ได้ ไม่ใช่หยุดเก็บ (ข้อ B ผิด)

### Q11 — ข้อ B (system_health)

`system_health` เป็น Always-on session ที่ server สร้างให้เอง (`STARTUP_STATE = ON`) และจับ `xml_deadlock_report` ทุกครั้งอยู่แล้ว ทั้งใน ring_buffer (ล่าสุด — อาจถูกเขียนทับบน server ที่ busy) และ event_file (`system_health*.xel` ใน LOG directory — เก็บย้อนหลังได้จริง) วิธีอ่าน: filter `event[@name="xml_deadlock_report"]` แล้วดึง `victim-list` / `process-list` จาก `xml_report` `sys.dm_exec_requests` เห็นเฉพาะ "ตอนนี้" จึงไม่ตอบโจทย์ย้อนเวลา

### Q12 — สองเรื่องที่ขาด

1. **Config**: event นี้ทำงานเมื่อตั้ง `blocked process threshold (s)` ก่อน (default 0 = ปิด) เช่น `EXEC sp_configure 'blocked process threshold (s)', 3; RECONFIGURE;` — event จะยิงเมื่อ process ถูก block นานเกิน threshold และยิงซ้ำทุกช่วงตราบที่ยัง block
2. **ลักษณะการทดสอบ**: DB ที่เปิด RCSI — SELECT ไม่ถูก writer block (อ่าน version เก่า) ต้องทดสอบแบบ **writer-writer** เช่น UPDATE สองหน้าต่างบนแถวเดียวกัน ผู้รอจะได้ wait `LCK_M_X` แล้ว report จะยิง และเมื่อจบเดโมคืนค่า threshold = 0 ด้วย

### Q13 — ต่างกันที่ context node ของ XQuery

- (A) อ่านผ่าน `buf.nodes('//event')` — ฟังก์ชันนี้ bind context node ที่ตัว `<event>` แล้ว ดังนั้น path ที่เหลือต้องเป็น **สัมพัทธ์** ต่อ `<event>` (`data[...]`, `@timestamp`) — ใส่ `event/` นำหน้าจะได้ NULL ทุกคอลัมน์
- (B) อ่านจาก `fn_xe_file_target_read_file` — แต่ละแถวคือค่า `event_data` ที่ CAST เป็น XML แล้ว **root ของ XML คือตัว `<event>` เอง** จึงต้องประกาศชื่อ element จาก root: `(event/data[...])`, `(event/@timestamp)`

กฎจำง่าย: "nodes() แล้วจบที่ event — CAST ทั้งแถวแล้วต้องเริ่มที่ event" (และอย่าลืม XQuery case-sensitive: `<Slot>`, `<Event>`, `attach_activity_id`)

### Q14 — STARTUP_STATE + rollover + dropped_event_count

1. `WITH (STARTUP_STATE = ON)` — server restart แล้ว session START กลับมาเอง
2. event_file พร้อม `max_file_size` (MB ต่อไฟล์) + `max_rollover_files` (จำนวนไฟล์) — เพดาน disk ≈ ทั้งสองค่าคูณกัน
3. เฝ้า `sys.dm_xe_sessions.dropped_event_count` (และ `buffer_policy_desc`) — ถ้าโตแสดงว่า buffer กดดันจนทิ้ง event จริง ต้องกรองให้แคบลง / ลด action / เพิ่ม MAX_MEMORY ร่วมกับ `sys.dm_xe_session_targets` (`failed_buffer_count`, `used_memory`)

### Q15 — ข้อ C

XEvents ไม่มีออปชัน AUTO_STOP — ทดสอบจริงบน 17.0.1135.8: `WITH (AUTO_STOP = ON)` ได้ `Incorrect syntax near 'AUTO_STOP'` วิธีจริง: จำกัดขนาด target กันดิสก์/memory บวม แล้วคุมอายุด้วย SQL Agent job (หรือคำสั่งเมื่อจบงาน): `ALTER EVENT SESSION [ชื่อ] ON SERVER STATE = STOP;` — และถ้าไม่ต้องการใช้อีกให้ `DROP EVENT SESSION` (ข้อ D ผิด: restart ไม่ลบ session — นิยามยังอยู่ใน catalog และจะ START กลับถ้า STARTUP_STATE = ON)
