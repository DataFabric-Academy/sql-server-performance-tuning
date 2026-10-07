# หลักสูตร Microsoft SQL Server Performance Tuning (4 วัน / 24 ชั่วโมง)

> **เอกสารสำหรับผู้สอน (Trainer Guide) — จัดฝึกอบรมโดย Trainocate**
> ปรับปรุงจาก Outline หลักสูตร (`หลักสูตร Microsoft SQL Server Performance Tuning.docx`) และ Microsoft Course **10987C** — Performance Tuning and Optimizing SQL Server
> **อัปเดตเนื้อหาให้ทันสมัยใช้ได้ถึง Microsoft SQL Server 2025 (17.x)** โดยอ้างอิงจาก Microsoft Learn และ Glenn Berry's Diagnostic Queries

---

## 1. ภาพรวมหลักสูตร (Course Overview)

เปลี่ยนการแก้ปัญหาแบบลองผิดลองถูก สู่การเป็นมืออาชีพด้าน SQL Server Performance Tuning อย่างเป็นระบบ เพราะในวันที่ Performance คือหัวใจของธุรกิจ การเดาไม่ใช่ทางเลือก หลักสูตรนี้จะติดอาวุธให้ผู้เรียนด้วย **Top-down Analysis Framework** เพื่อวินิจฉัย Root Cause ได้อย่างแม่นยำ รวดเร็ว และเป็นมืออาชีพ

| รายการ | รายละเอียด |
|:-------|:-----------|
| **ระยะเวลา** | 4 วัน (24 ชั่วโมง — 6 ชั่วโมง/วัน) |
| **รุ่น SQL Server ที่รองรับ** | 2019 / 2022 / **2025 (17.x)** — เนื้อหาและ Lab อ้างอิง SQL Server 2025 เป็นหลัก |
| **รูปแบบ** | บรรยาย + Demo + Hands-on Lab (รูปแบบ *Instruction + Code block*) |
| **ฐานข้อมูลหลัก** | **AdventureWorks2025** — [AdventureWorks2025.bak](https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2025.bak) (หากใช้ SQL Server 2019/2022 ให้ restore AdventureWorks2022 และแก้ชื่อ DB ในสคริปต์) |
| **เครื่องมือหลัก** | SSMS 20/21, DiskSpd, ostress, Query Store, Extended Events, Glenn Berry Diagnostic Queries |
| **ระดับ** | Intermediate – Advanced (300–400) |

### วัตถุประสงค์ของหลักสูตร (Course Objectives)

เมื่อสำเร็จหลักสูตรนี้ ผู้เข้าอบรมจะมีความสามารถดังนี้:

1. วิเคราะห์คอขวดของระบบผ่าน **Wait Statistics** ได้อย่างแม่นยำ พร้อมกำหนด **Performance Baselines** และเกณฑ์การวัด (Metrics) ของทรัพยากรต่าง ๆ ได้ด้วยตนเอง
2. เข้าใจกลไกภายในของ **SQL Server Scheduling** (Schedulers, Workers, Tasks) อย่างลึกซึ้ง เพื่อการจัดสรรและบริหารจัดการทรัพยากรระดับ Engine
3. ออกแบบและปรับแต่ง **Indexes และ Statistics** อย่างมีกลยุทธ์ เพื่อสนับสนุนการประมวลผล Query และรีดประสิทธิภาพให้ถึงขีดสุด
4. ประยุกต์ใช้เครื่องมือสมัยใหม่อย่าง **Query Store** เพื่อตรวจจับและแก้ไข **Performance Regression** ได้อย่างรวดเร็ว
5. วิเคราะห์และจัดการปัญหา **Concurrency** ขั้นสูง ทั้ง Locking, Blocking, Deadlocks และการออกแบบ Transaction Isolation Levels ให้เหมาะกับ Workload
6. วินิจฉัยและสืบสวนปัญหาประสิทธิภาพด้วย **Extended Events** อย่างเป็นระบบ แทนเครื่องมือ Monitoring แบบดั้งเดิม

### กลุ่มเป้าหมาย

- SQL Server DBA, Developer และ Consultant
- ผู้ดูแลระบบฐานข้อมูลที่ต้องการแก้ปัญหา Performance

### พื้นฐานที่ต้องมี (Prerequisites)

- ประสบการณ์ดูแลระบบหรือพัฒนาระบบบน Microsoft SQL Server
- เข้าใจ OS Basics, Storage I/O และ Write-ahead Logging (WAL)
- เข้าใจโครงสร้างข้อมูลแบบ Tree และ Heap รวมถึงความต่างของฐานข้อมูลแบบ Row-based และ Columnar

---

## 2. การปรับปรุงเนื้อหาให้ทันสมัย (Modernization สู่ SQL Server 2025)

หลักสูตรเดิม (10987C) ออกแบบสำหรับ SQL Server 2016/2017 เนื้อหานี้ได้รับการปรับปรุงตามหัวข้อสำคัญต่อไปนี้ โดยติดตามจาก Microsoft Learn:

| บท | หัวข้อเดิม 10987 | การปรับปรุงให้ทันสมัย (2019 → 2025) |
|:--:|:----------------|:-----------------------------------|
| 1 | SQLOS, Schedulers, Waits | ยืนยันโมเดล Cooperative Scheduling ล่าสุด — **lightweight pooling (fiber mode) ถูก deprecated ใน SQL Server 2025**; ใช้ Waits & Queues + **sys.dm_exec_query_plan_stats**; Soft-NUMA automatic |
| 2 | I/O Subsystem | SQLIO **ยกเลิกแล้ว → ใช้ DiskSpd** (รวมอยู่ใน Lab ของ 10987 Lab02 แล้ว); ตีความ `sys.dm_io_virtual_file_stats`; Columnstore/segment elimination ที่กระทบ I/O |
| 3 | Database Structures | TempDB memory-optimized metadata (2019+, opt-in), **ADR ใน tempdb (ใหม่ใน 2025, ต้อง restart engine)**, **tempdb space resource governance (2025 — Resource Governor รองรับ Standard edition แล้ว)**, tmpfs สำหรับ tempdb บน Linux; ตรวจ VLF ด้วย `sys.dm_db_log_info` แทน `DBCC LOGINFO` |
| 4 | Memory | Buffer Pool / PLE แบบระวังกับดัก PLE เดี่ยว; In-Memory OLTP อัปเดต (2025 ลบ memory-optimized filegroup ที่ว่างได้); Hybrid Buffer Pool |
| 5 | Concurrency | **Optimized Locking (2025 — TID lock + Lock-after-Qualification; ปิด default เปิดด้วย `ALTER DATABASE SET OPTIMIZED_LOCKING = ON`, ต้องเปิด ADR ก่อน)**, ADR (Persistent Version Store, sLog) + **ADR ใน tempdb (2025)**, RCSI/Snapshot, Deadlock analysis ด้วย XEvents |
| 6 | Statistics & Indexes | **CE feedback for expressions (2025)**, Columnstore ใหม่ใน 2025 (ordered nonclustered columnstore, online build), IQP รวม 2017→2025, Missing/Unused index จาก DMV ของ Glenn Berry |
| 7 | Query Execution | IQP ครบวง (PSPO 2022, **OPPO 2025**, **DOP feedback เปิด default ใน 2025**, **CE feedback for expressions 2025**), T-SQL ใหม่, SARGable patterns |
| 8 | Plan Caching & Query Store | **Optimized sp_executesql (2025) แก้ compilation storm**, Query Store hints + **ABORT_QUERY_EXECUTION (2025)**, **Query Store สำหรับ readable secondary เปิด default ใน 2025**, Automatic tuning |
| 9 | Extended Events | **Time-bound XEvent sessions (2025)**, แทน Profiler/SQL Trace ที่ถูกถอดออกทั้งหมดแล้ว |
| 10 | Monitoring & Baselines | Glenn Berry **SQL Server 2025 Diagnostic Queries**, DBATools/PowerShell, บทบาท server ใหม่ `##MS_ServerPerformanceStateReader##`, PerfMon counters ปัจจุบัน |
| 11 | Troubleshooting | Top-down framework ครบวงจร + Case Study ที่ใช้ทุกเครื่องมือข้างต้นบน SQL Server 2025 |

---

## 3. ตารางเวลาอบรม 4 วัน (24 ชั่วโมง)

> เวลาต่อวัน 6 ชั่วโมงสุทธิ (เช่น 09:00–16:00 พักกลางวัน 1 ชม. + พักเช้า/บ่าย 15 นาที)
> ทุกบทมี **LAB** แบบ *Instruction + Code block* อยู่ใน `Module_XX_*/Labs/README.md`

### 📅 วันที่ 1: Architecture & I/O Foundation

| เวลา | หัวข้อ | เนื้อหาหลัก / Lab |
|:-----|:-------|:------------------|
| 09:00–09:30 | แนะนำหลักสูตร | เป้าหมาย, Top-down framework, เตรียม Environment (AdventureWorks + ตรวจ DMV permission) |
| 09:30–11:00 | **บทที่ 1: สถาปัตยกรรม SQL Server และ SQLOS** | องค์ประกอบ SQL Server, SQL OS Architecture, Process/Thread Model, Windows vs SQL Scheduling, Non-Preemptive/Cooperative Scheduling, NUMA (Topology/Memory/Thread Affinity), พื้นฐาน Wait Statistics (Waits & Queues, Resource vs Signal Waits, Common Wait Types) |
| 11:00–12:00 | **LAB 1** | ใช้ `sys.dm_os_wait_stats`, `sys.dm_os_schedulers` วิเคราะห์ wait pattern — วัด Signal Wait Ratio, จำลอง CPU pressure |
| 12:00–13:00 | พักกลางวัน | |
| 13:00–14:15 | **บทที่ 2: ประสิทธิภาพ I/O Subsystem** | Sequential vs Random, Read/Write, Log I/O vs Data I/O, IOPS/Throughput/Latency และความสัมพันธ์, RAID 0/1/5/10 trade-offs, ทดสอบ I/O ด้วย DiskSpd (SQLIO ถูกเลิกใช้) |
| 14:15–15:45 | **LAB 2** | รัน DiskSpd benchmark + วิเคราะห์ `sys.dm_io_virtual_file_stats` ตีความ latency |
| 15:45–16:00 | สรุปวันที่ 1 (ตอนที่ 1) | Q&A, ทบทวน wait และ I/O metrics |

### 📅 วันที่ 2: Memory, Concurrency & Index

| เวลา | หัวข้อ | เนื้อหาหลัก / Lab |
|:-----|:-------|:------------------|
| 09:00–10:30 | **บทที่ 4: Memory Management** | Buffer Pool, Non-Buffer Pool, Memory Grants, Page Lifecycle, Lazy Writer, PLE และ thresholds, Memory pressure indicators, In-Memory OLTP (Hekaton, Natively Compiled, Memory-Optimized Tables) |
| 10:30–11:30 | **LAB 4** | วิเคราะห์ memory pressure ด้วย `sys.dm_os_sys_memory`, `sys.dm_os_buffer_descriptors` |
| 11:30–12:00 | **บทที่ 5: Concurrency & Transactions (ตอนที่ 1)** | Lock Modes (S, U, X, IS, IX), Lock Granularity, Latches vs Locks, Internal/External synchronization |
| 12:00–13:00 | พักกลางวัน | |
| 13:00–14:00 | **บทที่ 5 (ตอนที่ 2)** | Isolation Levels ครบทุกระดับ, Deadlock Analysis & Prevention, **ADR (Persistent Version Store, sLog, Instant Recovery) + การปรับปรุงใน SQL Server 2025**, **Optimized Locking (TID/LAQ)** |
| 14:00–15:45 | **LAB 5** | จำลอง Blocking + Deadlock และวิเคราะห์ด้วย Extended Events Deadlock Graph |
| 15:45–16:00 | สรุปวันที่ 2 | Q&A |

### 📅 วันที่ 3: Query Processing & Plan Management

| เวลา | หัวข้อ | เนื้อหาหลัก / Lab |
|:-----|:-------|:------------------|
| 09:00–10:30 | **บทที่ 7: Query Execution & Optimization** | Query Processing Pipeline, Estimated vs Actual Plan, Operators/Costs/Cardinality, AQP (2017): Adaptive Joins/Memory Grant Feedback/Interleaved, IQP (2019+): PSPO/DOP Feedback/MGF v2, และของใหม่ **2025: OPPO + CE Feedback for Expressions** |
| 10:30–12:00 | **บทที่ 7 (ต่อ) + LAB 7** | Query Tuning Techniques (Rewriting, Hints, Temp Table vs Table Variable/CTE, SARGable) + วิเคราะห์ execution plan จริง หา bottleneck และแก้ query |
| 12:00–13:00 | พักกลางวัน | |
| 13:00–14:30 | **บทที่ 8: Plan Caching & Query Store** | Parameterization, Cache Lookup, Plan Reuse, Plan Cache Pollution, Recompilation, Query Store (history/regression/force plan), Automatic Tuning, **Optimized sp_executesql (2025)** |
| 14:30–15:45 | **LAB 8** | เปิด Query Store, หา regressed plans, force plan ด้วย GUI และ T-SQL, ลอง Query Store Hints / ABORT_QUERY_EXECUTION |
| 15:45–16:00 | **บทที่ 9: Extended Events (เริ่มต้น)** | Concept: Session/Event/Action/Predicate/Target |
| 16:00 | (ต่อวันที่ 4) | |

### 📅 วันที่ 4: Monitoring, Tuning Strategy & Troubleshooting

| เวลา | หัวข้อ | เนื้อหาหลัก / Lab |
|:-----|:-------|:------------------|
| 09:00–09:45 | **บทที่ 9: Extended Events (ต่อ)** | สร้าง session ด้วย SSMS Wizard vs T-SQL, Ring Buffer vs File Target, Use cases (query perf, deadlock, blocking, error), Time-bound sessions (2025) |
| 09:45–10:30 | **LAB 9** | สร้าง XEvents session สำหรับ query performance, deadlocks, long-running queries |
| 10:30–12:00 | **บทที่ 10: Monitoring & Baselines** | DMVs สำคัญ (`sys.dm_exec_*`, `sys.dm_os_*`, `sys.dm_db_*`), วิธีเก็บ Baseline + Key Metrics/Thresholds, Activity Monitor/Performance Dashboard/SSMS Reports, SQL Agent Alerts + Database Mail + dbatools, Glenn Berry 2025 Diagnostic Queries |
| 12:00–13:00 | พักกลางวัน | |
| 13:00–14:00 | **LAB 10** | สร้าง monitoring script ด้วย DMVs + ตั้ง baseline สำหรับ instance |
| 14:00–15:00 | **บทที่ 11: Troubleshooting Methodology** | Top-down: Wait Stats → Resource → Query → Index → Config; CPU Pressure (SOS_SCHEDULER_YIELD/CXPACKET/MaxDOP), Memory (RESOURCE_SEMAPHORE/PLE), I/O (PAGEIOLATCH/WRITELOG), Concurrency (LCKM\*/Deadlock cycle) |
| 15:00–15:45 | **LAB 11 + Case Study** | จำลอง "SQL Server ที่ช้า" — หา root cause ด้วย DMVs, XEvents, Query Store (End-to-End Case Study) |
| 15:45–16:00 | สรุปหลักสูตร | ทบทวน Top-down framework, แหล่งเรียนรู้ต่อยอด, ประเมินผล |

---

## 4. แผนที่โมดูลใน Repository ↔ หัวข้อ Outline

| วัน | บท | โฟลเดอร์ | Lab (Instruction + Code block) |
|:---:|:--:|:---------|:-------------------------------|
| 1 | 1 | `Module_01_Architecture_Scheduling_Waits/` | Wait Statistics & CPU Pressure |
| 1 | 2 | `Module_02_IO/` | DiskSpd + File I/O Latency |
| 1 | 3 | `Module_03_Database_Structures/` | Pages/VLF/TempDB internals (DBCC PAGE, DBCC LOGINFO) |
| 2 | 4 | `Module_04_Memory/` | Memory Pressure & Buffer Pool |
| 2 | 5 | `Module_05_Concurrency/` | Blocking/Deadlock + XEvents Deadlock Graph |
| 2 | 6 | `Module_06_Statistics_Index_Internals/` | Missing/Unused Index + วัดผลก่อน-หลัง |
| 3 | 7 | `Module_07_Query_Execution/` | Execution Plan Analysis + แก้ query |
| 3 | 8 | `Module_08_Plan_Caching/` | Query Store Regression + Force Plan |
| 3 | 9 | `Module_09_Extended_Events/` | สร้าง XEvents session 3 รูปแบบ |
| 4 | 10 | `Module_10_Monitoring_Tracing/` | Baseline Collection + Daily Health Check |
| 4 | 11 | `Module_11_Troubleshooting/` | "Broken Server" Challenge (capstone) |

---

## 5. การเตรียมสภาพแวดล้อม (Environment Setup)

1. **SQL Server 2025 (17.x)** Developer Edition — **17.x คือรุ่นต่ำสุดของคอร์ส** (แล็บบทที่ 5 และ 9 พิสูจน์ฟีเจอร์เฉพาะ 2025 จริง; Exercise ที่มี guard จะหยุดพร้อมข้อความแนะ "ทางเลือกสำหรับรุ่นเก่า" ให้ผู้เรียนที่ใช้ 2019/2022 ทำต่อได้) + **SSMS 21**
2. Restore **AdventureWorks2025** (ตัวเลือกหลักสำหรับ SQL Server 2025 — ไฟล์ .bak ที่ build บนรุ่นใหม่ restore บนรุ่นเก่าไม่ได้ หากใช้ 2019/2022 ให้ใช้ AdventureWorks2022):
   [AdventureWorks2025.bak](https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2025.bak) · [วิธี restore จาก Microsoft Learn](https://learn.microsoft.com/sql/samples/adventureworks-install-configure?view=sql-server-ver17&tabs=ssms)
   ```sql
   USE [master];
   GO
   RESTORE DATABASE [AdventureWorks2025]
   FROM DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Backup\AdventureWorks2025.bak'
   WITH FILE = 1, NOUNLOAD, STATS = 5;
   GO
   ```
3. เครื่องมือเสริม:
   - **DiskSpd** — <https://github.com/microsoft/diskspd> (bundled v2.3 ใน `Module_02_IO/Labs/Tools/`)
   - **ostress** (RML Utilities) สำหรับ replay workload
4. Permission สำหรับผู้เรียน: `VIEW SERVER STATE`, `VIEW DATABASE STATE` (หรือบทบาท `##MS_ServerPerformanceStateReader##` ที่มาใหม่ใน SQL Server 2022+)
5. ทดสอบความพร้อม: รัน Query แรกในแต่ละ Lab แล้วเทียบบล็อก **Expected:** ท้ายแต่ละ Exercise — ทุก Exercise มีเกณฑ์ผ่านจากการรันจริงบน SQL Server 2025 (17.x) พร้อมระบุ build/วันที่ที่ sign-off

## 6. Slide Decks & Template (ประกอบการสอน)

| ไฟล์ | สำหรับ | รายละเอียด |
|:-----|:-------|:-----------|
| `Trainocate_SQLPerfTuning_Template.potx` | **เทมเพลตมาตรฐาน** | Slide master + 8 layouts (Cover, Module Divider, Content, Two-Column, Table, Code Lab, Stat Callout, Closing) — branding Trainocate ในตัว, ธีมสี navy/orange + ฟอนต์ Leelawadee UI ใช้สร้างสไลด์ใหม่ได้ทันทีจาก PowerPoint (New Slide → เลือก layout) |
| `Trainocate_MSSQL_Performance_Tuning_4Days.pptx` | **Trainocate Thailand** | 78 สไลด์ branding ของ Trainocate (navy/orange) — cover, objectives, roadmap 4 วัน, 11 โมดูล (divider + เนื้อหา + สไลด์เจาะลึกดัดแปลงจาก 9Expert/10987C + สไลด์ LAB ต่อโมดูล) พร้อม **ภาพประกอบต้นฉบับ 17 จุด** (HDD/SSD/RAID, lock hierarchy, columnstore, IQP screenshots, XEvents ฯลฯ) และ snippet จาก Labs ใน repo |
| `Microsoft SQL Server Performance Tuning-Aj-Pakkapong-Updated-SQL2025.pptx` | 9Expert (เดิม) | 227 สไลด์ — ปรับเนื้อหาเดิม 15 จุดให้ทันสมัย (Profiler/SQL Trace deprecated, IQP timeline ถึง 2025, Query Store default ฯลฯ) + เพิ่มส่วนเสริม "Modernization สู่ SQL Server 2025" 12 สไลด์ท้ายไฟล์ ตรงตาม Modernization Notes ของทั้ง 11 โมดูล |

> **Workflow การเก็บเกี่ยวเนื้อหาเพิ่มเติม:** เปิดสไลด์ต้นทาง (9Expert/10987C) คู่กับไฟล์ที่ใช้เทมเพลต .potx แล้ว "เทเนื้อหา" (copy ข้อความ/ตาราง) ลง layout ที่เหมาะสม — อย่า copy สไลด์ข้ามเทมเพลตโดยตรง เพราะ placeholder จะอ้าง master เดิมและหน้าตาเพี้ยน

## 7. แหล่งอ้างอิงหลักของหลักสูตร

- **Microsoft Learn** — SQL Server Performance Center: <https://learn.microsoft.com/sql/relational-databases/performance/performance-center>
- **What's new in SQL Server 2025**: <https://learn.microsoft.com/sql/sql-server/what-s-new-in-sql-server-2025>
- **Glenn Berry — Diagnostic Queries (รวม SQL Server 2025)**: <https://glennsqlperformance.com/resources/>
- **Microsoft Course 10987C** — Trainer Handbook, Slides, Demofiles และ Labfiles (อยู่ใน `Trainer_Docs/10987/`)
- Waits & Queues methodology: SQLskills / Paul Randal & Glenn Berry wait type library

> **รูปแบบ Lab ทุกบท:** เขียนเป็น *Instruction + Code block* — แต่ละ Step มีคำสั่งสั้น ๆ + โค้ด T-SQL ฉบับเต็มที่รันได้ทันทีใน SSMS โดยไม่ต้องเปิดไฟล์สคริปต์อื่น (สคริปต์ประกอบอยู่คู่หัวข้อใน `Sections/*/Scripts/`)
