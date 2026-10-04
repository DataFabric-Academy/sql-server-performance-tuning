ในอดีตนิยมใช้ SQL Profiler ในการตรวจสอบการทำงานของ Database แต่เนื่องจากข้อจำกัดด้าน Performance (High Overhead) และความยืดหยุ่น ปัจจุบัน Microsoft แนะนำให้ใช้งาน **Extended Events (XEvents)** ซึ่งเป็นสถาปัตยกรรม Lightweight Tracing System ที่ฝังอยู่ใน SQLOS โดยตรง

บทเรียนนี้จะอธิบายโครงสร้างพื้นฐานของ Extended Events และเปรียบเทียบกับเครื่องมือรุ่นเก่า

### 1.1 Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – เข้าใจ Architecture ของ XEvents**
  - อธิบายความแตกต่าง Profiler vs XEvents, Components หลัก (Event/Action/Predicate/Target/Session) ได้
- **ระดับ 2 – สร้าง Session พื้นฐานได้**
  - สร้าง XEvent Session เพื่อจับ Long-running Queries, Errors, Deadlocks, Wait Info ลง Ring Buffer หรือ File ตาม Scenario
- **ระดับ 3 – ใช้ XEvents ในการแก้ปัญหาจริง**
  - อ่าน/แปลไฟล์ `.xel`, ใช้ XEvent Profiler/SSMS UI และ DMV (`sys.dm_xe_sessions`, `sys.dm_xe_session_targets`) เพื่อติดตามเหตุการณ์ในระบบได้อย่างปลอดภัย
- **ระดับ 4 – ออกแบบ Tracing Strategy ตามแนวทาง Microsoft**
  - วางแผน Session ระยะยาว/เฉพาะกิจให้สอดคล้องกับ Best Practices ด้าน Monitoring & Tracing ที่อ้างถึงใน Performance Center และ Monitoring Guides (ลด Overhead, เน้น Early Filtering)

---

---


## 📚 Sections (สารบัญบทเรียน)

| # | Section |
|---|---------|
| 1 | [XE Core Concepts](Sections/01_XE_Core_Concepts/README.md) |
| 2 | [Working With Extended Events](Sections/02_Working_With_Extended_Events/README.md) |
| 📋 | [Quiz Bank — ทบทวน 15 คำถามพร้อมเฉลย](Quiz_Bank.md) |

---


## 🧪 Labs

คู่มือปฏิบัติแบบ Instruction + Code block: [Labs/README.md](Labs/README.md) — สคริปต์ประกอบอยู่ใน `Sections/*/Scripts/` ตามหัวข้อ

---


## <details>
<summary><b>1. ข้อดีหลักของ XEvents เมื่อเทียบกับ SQL Profiler คืออะไร?</b></summary>
Lightweight และ Scalable กว่า มีผลกระทบต่อเครื่องน้อยกว่ามาก เพราะมีสถาปัตยกรรมแบบ Asynchronous และ Buffering
</details>

<details>
<summary><b>2. Predicate คืออะไร และทำไมถึงสำคัญ?</b></summary>
คือเงื่อนไขการกรอง (Filter) ที่ทำงานก่อนเก็บข้อมูล (Early Filtering) ช่วยลด Overhead และลดขนาดข้อมูลที่ไม่จำเป็นต้องบันทึกได้อย่างมหาศาล
</details>

<details>
<summary><b>3. target แบบ Ring Buffer มีข้อควรระวังคืออะไร?</b></summary>
ข้อมูลเก็บใน Memory แบบวงกลม (FIFO) ถ้ามี Event เข้ามาเยอะ ข้อมูลเก่าจะถูกเขียนทับหายไป จึงไม่เหมาะกับการเก็บข้อมูลระยะยาว
</details>


---

---


- **การจำกัดอายุ session กันลืมปิด** — XEvents ไม่มี `AUTO_STOP` ในตัว (ตรวจจริงบน 17.0.1000.7: `WITH (AUTO_STOP = ON)` ได้ `Incorrect syntax near 'AUTO_STOP'`) วิธีจริงคือจำกัดขนาด target + ปิดตามเวลาด้วย SQL Agent job:
  ```sql
  CREATE EVENT SESSION [XE_Timed] ON SERVER
  ADD EVENT sqlserver.sql_batch_completed
  ADD TARGET package0.ring_buffer ( SET max_memory = 2048 )
  WITH ( MAX_DISPATCH_LATENCY = 5 SECONDS );
  -- ปิดตามเวลาด้วย SQL Agent job:
  ALTER EVENT SESSION [XE_Timed] ON SERVER STATE = STOP;
  ```
- SQL Profiler / SQL Trace: **อย่าใช้** — deprecated มายาวนาน และถูกถอดออกจากเครื่องมือหลักแล้ว มาตรฐานปัจจุบันคือ XEvents 100%
- `ring_buffer` ใช้ดูสด/แก้ปัญหาจุดเดียว แต่ production capture จริงควรใช้ **event_file** + `MAX_FILE_SIZE` + `MAX_DISPATCH_LATENCY` ต่ำ ๆ เพื่อไม่สูญข้อมูลช่วง crash
- จับ workload overhead ได้ละเอียดกว่าเดิมด้วย event `query_post_execution_plan_profile` (lightweight profiling) แทน `query_post_execution_showplan` ที่แพงกว่ามาก

> อ้างอิง: [Extended Events sessions (2025)](https://learn.microsoft.com/sql/relational-databases/extended-events/sql-server-extended-events-sessions), [Extended Events architecture](https://learn.microsoft.com/sql/relational-databases/extended-events/extended-events)