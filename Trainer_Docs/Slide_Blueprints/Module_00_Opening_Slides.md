# สไลด์ไบล์พรินต์ — เด็คเปิดคอร์ส (Opening Deck 8 สไลด์)

> **โครงเด็ค 8 สไลด์ตามสูตรแผนแม่บท 4.2:** Cover(1) · เหมาะกับใคร/ต้องรู้อะไรก่อน(2) · ผัง 4 วัน(3) · แผนที่ 11 โมดูล(4) · Glossary นำ(5) · Environment Setup(6) · กติกาการเรียน/แล็บ(7) · Closing(8) — map token→layout ตาม 4.3
> **ทุกสไลด์มี Speaker notes พร้อม token `Ref:`** · ไม่มีภาพประกอบที่ต้องวาด (ใช้ layout/template ล้วน)

---

### สไลด์ 1: Cover — SQL Server Performance Tuning
- **Layout:** title → potx `01 Cover (dark)`
- **Bullets:**
  - SQL Server Performance Tuning and Optimizing — หลักสูตร 4 วัน / 24 ชั่วโมง
  - วินิจฉัยด้วยข้อมูลจริง: DMVs · Extended Events · Query Store — ไม่เดาจาก Task Manager
  - ผู้สอน / วันที่อบรม: (เติมก่อนสอน)
- **ภาพ/แผนภาพ:** ไม่มี — ใช้พื้นหลัง layout 01
- **Speaker notes:** เปิดคอร์สด้วยคำสัญญาเดียว: "จบคอร์สแล้วคุณจะอ่านคอขวดจากข้อมูลภายใน SQL Server ได้เอง" **Ref:** README.md

### สไลด์ 2: เหมาะกับใคร / ต้องรู้อะไรก่อน
- **Layout:** bullets → potx `03 Content`
- **Bullets:**
  - เหมาะกับ: DBA / Developer ที่ใช้ SQL Server อยู่แล้วและอยากแก้ปัญหา "ระบบช้า" อย่างเป็นระบบ
  - ต้องรู้ก่อน: การ admin เบื้องต้น (install, backup, SSMS) + `SELECT`/`JOIN` — ไม่ต้องเคยใช้ DMV
  - เริ่มจากศูนย์ได้: Module 00 สอนศัพท์แกน (DMV / Wait Type / Scheduler / Plan) ก่อนเข้า Module 1
  - ตลอดคอร์ส: ศัพท์ใหม่ทุกตัวมีนิยาม + ลิงก์ Glossary กลางในทุก section และสไลด์
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ให้ผู้เรียนประเมินตัวเองตาม 3 ข้อแรก — ใครไม่แน่ใจ ให้เปิด Module 00 อ่าน 15 นาทีก่อนวันสอนวันที่ 2 **Ref:** Module_00_Getting_Started/README.md + README.md (Learning Path)

### สไลด์ 3: ผังการอบรม 4 วัน / 24 ชั่วโมง
- **Layout:** bullets → potx `05 Table` (ตาราง 4 แถว)
- **Bullets:**
  - วันที่ 1: Architecture & I/O Foundation — Module 1–3
  - วันที่ 2: Memory, Concurrency & Index — Module 4–6
  - วันที่ 3: Query Processing & Plan Management — Module 7–9
  - วันที่ 4: Monitoring, Tuning Strategy & Troubleshooting — Module 10–11 + Case Study
- **ภาพ/แผนภาพ:** ตาราง (วัน/หัวข้อ/บท) จาก Course Guide
- **Speaker notes:** ย้ำว่าแต่ละโมดูลมีงบเวลาพิมพ์บนสไลด์ Divider ของโมดูลนั้น — เวลาจริงจากผู้เรียนทดสอบจะนำมาเทียบ **Ref:** Trainer_Docs/Course_Guide_4Days.md

### สไลด์ 4: แผนที่ 11 โมดูล + เส้นทางการเรียน
- **Layout:** bullets → potx `03 Content`
- **Bullets:**
  - สายพื้นฐาน: M1 Architecture/Waits → M2 I/O → M3 Structures → M4 Memory
  - สายปะทะจริง: M5 Concurrency → M6 Statistics/Index → M7 Query Execution
  - สายควบคุม: M8 Plan Caching → M9 Extended Events → M10 Monitoring → M11 Troubleshooting (capstone)
  - ทุกโมดูลจบด้วยแล็บที่รันได้จริง + Quiz Bank วัดความเข้าใจ
- **ภาพ/แผนภาพ:** ไม่มี (แผนที่เป็น bullet 3 สายชัดกว่าตาราง)
- **Speaker notes:** ชี้ว่า M5/M9 คือแล็บจุดปิดคอร์ส (ยากสุด) — M11 รวมทุกอย่าง **Ref:** README.md (Learning Path) + Trainer_Docs/Production_Plan_Course_and_Slides.md

### สไลด์ 5: ศัพท์แกนที่ต้องติดตัวก่อนเริ่ม
- **Layout:** bullets → potx `03 Content`
- **Bullets:**
  - **DMV** — หน้าต่างอ่านสถานะภายในของ SQL Server (ต้องมีสิทธิ์ VIEW SERVER STATE)
  - **Wait Type** — ชื่อเหตุผลที่งานต้อง "รอ" (คอขวดแท้จัดอันดับให้เอง)
  - **Scheduler** — ผู้จัดคิว CPU ของ SQL Server (1 ตัวต่อ 1 CPU)
  - **Execution Plan** — แผนที่ optimizer เลือกก่อนรัน query ของคุณ
  - นิยามเต็ม + ศัพท์อื่นทั้งหมด: `Glossary.md` ที่ root ของ repo (ใช้ตลอดคอร์ส)
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ให้ผู้เรียนถ่ายรูปสไลด์นี้ — 4 คำนี้จะถูกใช้ภายใน 30 นาทีแรกของ Module 1 **Ref:** Glossary.md + Module_00_Getting_Started/README.md

### สไลด์ 6: Environment Setup — เตรียมเครื่องให้พร้อม
- **Layout:** demo → potx `06 Code Lab`
- **Bullets:**
  - SQL Server 2025 (17.x) — **รุ่นต่ำสุดของคอร์ส** (แล็บ M5/M9 ใช้ฟีเจอร์ 2025 จริง)
  - Restore AdventureWorks2025 (2019/2022 ใช้ AdventureWorks2022)
  - สิทธิ์ `VIEW SERVER STATE` หรือบทบาท `##MS_ServerPerformanceStateReader##`
  - ตรวจพร้อม: รัน `SELECT HAS_PERMS_BY_NAME(NULL,NULL,'VIEW SERVER STATE')` ต้องได้ 1
  - **Error ที่พบได้:** permission denied → ให้สิทธิ์ตามข้างบนก่อน (query ไม่ผิด)
  - **รุ่นขั้นต่ำ:** SQL Server 2025 (17.x) — Exercise ที่มี guard จะหยุดพร้อมข้อความแนะทางเลือกบนรุ่นเก่า
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ให้ผู้เรียนรัน query ตรวจสิทธิ์สด ๆ ในห้อง — ใครได้ 0 ให้จัดการสิทธิ์ก่อนพัก **Ref:** Trainer_Docs/Course_Guide_4Days.md (Environment Setup) + Module_00_Getting_Started/README.md

### สไลด์ 7: กติกาการเรียน — แล็บ, Quiz, และวิธีเดินตาม
- **Layout:** bullets → potx `03 Content`
- **Bullets:**
  - ทุกโมดูล: บรรยาย → Demo → Lab (รวม 40 Exercise) — ทุก Exercise มีบล็อก **Expected:** ให้เทียบผลจริง
  - เจอ query error / ผลไม่ตรง: อ่าน ⚠️ หมายเหตุในแล็บ (จากการรันจริง) ก่อนถาม
  - จบแต่ละโมดูล: ทำ Quiz Bank (15–20 ข้อ เฉลยอธิบาย) เกณฑ์ผ่านตามที่ระบุท้ายไฟล์
  - ศัพท์ติดขัดทันที: เปิด Glossary.md — อย่าสะสมความงงข้ามโมดูล
  - ห้ามรันสิ่งที่แล็บห้ามบน production (เช่น `DBCC SQLPERF CLEAR`) — เตือนไว้ในตัวแล็บทุกจุด
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ย้ำสัญญาของหลักสูตร: ทุกโค้ดในเอกสารรันจริงบน SQL Server 2025 RTM-GDR แล้ว — ถ้าเจออะไรต่างจาก Expected แจ้งผู้สอนทันที **Ref:** README.md (Usage) + Trainer_Docs/SignOff/AllLabs_SignOff.md

### สไลด์ 8: Closing — พร้อมเริ่มแล้ว
- **Layout:** summary → potx `08 Closing (dark)`
- **Bullets:**
  - 4 วันนี้: จาก "ระบบช้า" ไม่รู้ต้นเหตุ → วินิจฉัยด้วย DMV/XE แล้วแก้ด้วยหลักฐาน
  - เครื่องมือติดตัว: Wait Statistics · DMVs · Query Store · Extended Events · Baseline
  - ทบทวน: Quiz Bank ทุกโมดูล + Glossary กลาง + แล็บรันซ้ำได้ทุกเมื่อ
  - เริ่มเลย: Module 01 — Architecture, Scheduling & Waits
- **ภาพ/แผนภาพ:** ไม่มี
- **Speaker notes:** ปิดด้วยการชี้ว่า Module 1 จะเริ่มจากคำถาม "ระบบช้า" ของ Proseware Inc. ทันที — ไปพักแล้วเจอกัน 09:30 **Ref:** Module_01_Architecture_Scheduling_Waits/README.md
