# อภิธานศัพท์ (Glossary) — SQL Server Performance Tuning

> **วิธีใช้:** ก่อนเริ่มแต่ละ section ให้สแกนศัพท์ในบรรทัด "ต้องรู้มาก่อน" ที่หัว section — ถ้ายังไม่คุ้น ให้กลับมาอ่านนิยามที่นี่ก่อน (ศัพท์เรียงตามตัวอักษร · 📚 = โมดูลที่สอนลึก)

---

## A–C

**AdventureWorks** — ฐานข้อมูลตัวอย่างของ Microsoft ที่ใช้ทั้งหลักสูตร (รุ่น 2025 = AdventureWorks2025) 📚M0

**ASYNC_NETWORK_IO** — wait type ที่เกิดเมื่อ SQL Server พร้อมส่งผลลัพธ์ แต่ client/network รับไม่ทัน — ปัญหาอยู่ฝั่ง application ไม่ใช่ storage (เห็นจริงในแล็บ M1 Ex4) 📚M1

**Batch** — ชุดคำสั่ง T-SQL ที่ส่งไปประมวลผลพร้อมกันหนึ่งครั้ง (คั่นด้วย `GO` ใน SSMS)

**Blocking** — ปรากฏการณ์ session หนึ่งถือ lock ค้าง ทำให้อีก session ต้องรอ 📚M5

**Buffer Pool** — พื้นที่หน่วยความจำหลักของ SQL Server ที่แคชหน้าข้อมูล (data pages) จากดิสก์ 📚M4

**Cardinality Estimation (CE)** — การประมาณจำนวนแถวของ Query Optimizer ใช้เลือกแผนการรัน 📚M6/M7

**Columnstore Index** — index แบบเก็บข้อมูลเป็นคอลัมน์ เร็วมากกับ workload วิเคราะห์ 📚M6

**Cooperative Scheduling (Non-Preemptive)** — โมเดลการจัดคิวของ SQL Server: task ยอมสละ CPU เองเมื่อหมด quantum หรือรอ resource ไม่ถูก OS หยุดกลางคัน (ต่างจาก Windows Scheduling) 📚M1

**CTE (Common Table Expression)** — ชุดผลลัพธ์ชั่วคราวที่ตั้งชื่อ (`WITH Waits AS (...)`) ใช้ใน query เดียวกัน — ใช้บ่อยในแล็บจัดอันดับ wait stats

**Cross Apply** — เรียก table-valued function ต่อท้ายแต่ละแถว เช่น `CROSS APPLY sys.dm_exec_sql_text(sql_handle)` เพื่อดึงข้อความ SQL ของ request 📚M7

## D–E

**DMV / DMF (Dynamic Management View / Function)** — view/function ระบบที่ให้อ่านสถานะภายในของ SQL Server (เช่น `sys.dm_os_wait_stats`) — ต้องมีสิทธิ์ `VIEW SERVER STATE`; เครื่องมือหลักของทั้งหลักสูตร

**Deadlock** — สอง session รอ lock ของกันและกันเป็นวง SQL Server เลือก victim หนึ่งตัว rollback 📚M5

**Execution Plan** — แผนที่ optimizer เลือกว่าจะรัน query อย่างไร (seek หรือ scan, join แบบไหน, เรียงที่ไหน) 📚M7

**Extended Events (XEvents / XE)** — ระบบติดตามเหตุการณ์ภายในน้ำหนักเบา ตัวแทน SQL Profiler ที่ถอดไปแล้ว 📚M9

## F–L

**Fragmentation** — การที่หน้าข้อมูลใน index เรียงไม่ต่อเนื่อง/เต็มไม่พอ ทำให้ I/O เปลือง 📚M6

**Latch** — lock ระดับภายใน (internal) ที่ SQL Server ใช้ป้องกันความถูกต้องของโครงสร้างข้อมูลช่วงสั้น ๆ เช่นตอนอ่าน page — ต่างจาก lock ที่มองจาก logic ธุรกิจ 📚M5

**Lock** — กลไกกันข้อมูลเปลี่ยนพร้อมกันในระดับ row/page/table ที่ผูกกับ transaction 📚M5

**Log File / VLF (Virtual Log File)** — ไฟล์ transaction log ถูกจัดการเป็นช่วง ๆ ชื่อ VLF; จำนวน/ขนาด VLF ที่แปลก ๆ กระทบ startup/recovery 📚M3

## M–P

**Memory Clerk** — ตัวบัญชีที่จัดสรรหน่วยความจำตามองค์ประกอบ (ดูได้จาก `sys.dm_os_memory_clerks`) 📚M4

**NUMA (Non-Uniform Memory Access)** — สถาปัตยกรรมที่แบ่ง CPU กับ memory เป็นก้อน (node) — เข้า memory ของ node ตัวเองเร็วกว่า 📚M1

**Page (8 KB)** — หน่วย I/O และจัดเก็บเล็กที่สุดของ SQL Server; ตาราง/ดัชนีประกอบจาก pages 📚M3

**Plan Cache** — แคชเก็บ execution plan ที่ compile แล้ว เพื่อไม่ต้อง compile ซ้ำ 📚M8

**Parameter Sniffing** — ปัญหาที่ plan ถูกสร้างจาก parameter แรกที่เจอ แล้วไม่เหมาะกับค่าอื่น 📚M8

**PLE (Page Life Expectancy)** — ค่าบ่งชี้ว่า page หนึ่งอยู่ใน buffer pool ได้นานแค่ไหน (วินาที) ใช้สังเกตแรงกดดัน memory 📚M4

**Preemptive Wait** — ช่วงที่ SQL Server ต้องออกไปใช้บริการ OS (เช่นเรียก Windows API) — เห็นเป็น wait type นำหน้า `PREEMPTIVE_*`

## Q–S

**Quantum (4 ms)** — เวลา CPU ที่ task หนึ่งได้ใช้ต่อรอบใน cooperative scheduling; ครบ quantum จะ "yield" 📚M1

**Query Store** — คลังเก็บประวัติ query + plan ต่อ database ใช้วิเคราะห์ regression 📚M8

**Runnable Queue** — คิว task ที่พร้อมรันแต่ยังไม่ได้ CPU (`runnable_tasks_count > 0` = มีคิวรอ) 📚M1

**Scheduler** — วัตถุระดับ SQLOS ที่จับคู่กับ CPU หนึ่งตัว (ประมาณ logical CPU count) จัดคิว task 📚M1

**Signal Wait vs Resource Wait** — resource wait = รอ resource (ดิสก์/lock); signal wait = พร้อมรันแล้วแต่รอคิว CPU — signal สูง = CPU pressure 📚M1

**SQLOS** — ชั้นระบบปฏิบัติการย่อยใน SQL Server ที่จัดการ scheduler/worker/memory เอง 📚M1

**Statistics** — ข้อมูลสถิติการกระจายค่าของคอลัมน์/index ที่ optimizer ใช้ประมาณแถว 📚M6

## T–Z

**TempDB** — ฐานข้อมูลชั่วคราวร่วมกันทั้ง instance (temp table, sort spill, version store) 📚M3

**TID Lock** — lock รูปแบบใหม่ของ Optimized Locking (SQL Server 2025) ที่ล็อก transaction ID แทน row/page ลด lock memory 📚M5

**Wait Type** — ชื่อเหตุการณ์ที่ task กำลังรอ (เช่น `SOS_SCHEDULER_YIELD`, `PAGEIOLATCH_SH`, `LCK_M_X`) อ่านจาก `sys.dm_os_wait_stats` 📚M1

**Wait Statistics** — ข้อมูลสะสมว่าระบบเคยรออะไรมาก่อน นานเท่าไร — จุดเริ่มของการวินิจฉัยสมรรถนะ 📚M1

**Worker Thread** — เธรดที่ SQLOS สร้างเพื่อรัน task (เพดาน = `max_workers_count` เกินจะเจอ `THREADPOOL` wait) 📚M1

---

> ศัพท์ฉบับนี้เป็นฐานร่วมทั้งหลักสูตร — แต่ละโมดูลจะเพิ่มศัพท์เฉพาะของตัวเองในบรรทัด "ต้องรู้มาก่อน" ของ section
