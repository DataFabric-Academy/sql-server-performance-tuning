ในบทเรียนแรกนี้ ผู้เรียนจะได้รับความรู้พื้นฐานเกี่ยวกับสถาปัตยกรรมของ SQL Server ซึ่งเป็นรากฐานสำคัญสำหรับการปรับปรุงประสิทธิภาพ (Performance Tuning) เนื้อหาจะมุ่งเน้นความเข้าใจในกลไกการทำงานของ **SQLOS** และการบริหารจัดการทรัพยากรระหว่าง Database Engine และ Operating System

หลักการทำงาน: SQL Server ทำหน้าที่เป็น Application Server ที่มีการจัดการหน่วยความจำ (Memory) และการประมวลผล (CPU Scheduling) ด้วยตนเอง เพื่อให้เกิดประสิทธิภาพสูงสุดและลด Overhead จากการพึ่งพา OS มากเกินไป

### 1.1 Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – เข้าใจภาพรวมสถาปัตยกรรม**
  - อธิบายส่วนประกอบหลักของ SQL Server Engine, SQLOS, Scheduler, Tasks/Workers ได้
- **ระดับ 2 – อ่านและแปลความ Wait Statistics ได้**
  - แยกประเภท Resource Wait vs Signal Wait, ระบุ Wait Type หลักที่พบบ่อย และเชื่อมโยงกับอาการในระบบได้
- **ระดับ 3 – ใช้ DMVs เพื่อวิเคราะห์ปัญหาได้จริง**
  - ใช้ `sys.dm_os_schedulers`, `sys.dm_os_wait_stats`, `sys.dm_exec_requests` เพื่อหาคอขวดด้าน CPU / Waits ได้อย่างเป็นขั้นตอน
- **ระดับ 4 – ออกแบบแนวทาง Tuning ตาม Best Practice ของ Microsoft**
  - เชื่อมโยงแนวคิดจาก Module นี้เข้ากับแนวทางจาก Performance Center ของ Microsoft SQL Server และ Azure SQL Database เช่น การโฟกัสที่ CPU, Waits, และ Scheduling เป็นลำดับแรกในการ Tuning (อ้างอิงแนวคิดจาก [Performance Center for SQL Server Database Engine and Azure SQL Database](https://learn.microsoft.com/en-us/sql/relational-databases/performance/performance-center-for-sql-server-database-engine-and-azure-sql-database?view=sql-server-ver17))

---

---


## 📚 Sections (สารบัญบทเรียน)

| # | Section |
|---|---------|
| 1 | [Engine Architecture SQLOS](Sections/01_Engine_Architecture_SQLOS/README.md) |
| 2 | [Scheduling Windows vs SQL](Sections/02_Scheduling_Windows_vs_SQL/README.md) |
| 3 | [NUMA Architecture](Sections/03_NUMA_Architecture/README.md) |
| 4 | [Wait Statistics](Sections/04_Wait_Statistics/README.md) |
| 5 | [Modern Features 2025](Sections/05_Modern_Features_2025/README.md) |

---


## 🧪 Labs

คู่มือปฏิบัติแบบ Instruction + Code block: [Labs/README.md](Labs/README.md) — สคริปต์ประกอบอยู่ใน `Sections/*/Scripts/` ตามหัวข้อ

---


## <details>
<summary><b>1. ถ้าพบว่า Wait Type สูงสุดคือ CXPACKET และ CXCONSUMER คู่กัน แปลว่าอะไร?</b></summary>
ส่วนใหญ่เป็นเรื่องปกติของ Parallel Execution แต่ถ้า CXPACKET สูงโดดๆ อาจต้องจูน Cost Threshold for Parallelism หรือ MAXDOP
</details>

<details>
<summary><b>2. ความแตกต่างระหว่าง Signal Wait และ Resource Wait คืออะไร?</b></summary>
Resource Wait คือรอของ (เช่น Disk/Lock) แต่ Signal Wait คือของมาแล้ว "รอ CPU ว่าง" (บ่งบอก CPU Pressure)
</details>

<details>
<summary><b>3. สถานะ SUSPENDED หมายถึง Thread กำลังทำอะไร?</b></summary>
Thread หยุดทำงานเพราะต้องรอทรัพยากรบางอย่าง (เช่น รออ่านข้อมูลจาก Disk หรือรอปลด Lock)
</details>


---

---


## ### 7.1 Scheduling — สิ่งที่เปลี่ยนใน SQL Server 2025
- **`lightweight pooling` (fiber mode) ถูกประกาศ deprecated ใน SQL Server 2025** และจะถูกถอดออกในรุ่นถัดไป — โมเดล Cooperative/Non-Preemptive Scheduling บน Worker Thread คือทางเดียวที่ Microsoft สนับสนุน อย่าเสียเวลาตั้งค่านี้บน production อีกต่อไป
- **Hot Add CPU ถูก deprecated เช่นกัน** — วางแผนขนาด CPU ตั้งแต่ต้น (แนะนำใช้ Glenn Berry's diagnostic query "CPU/NUMA" เพื่อบันทึก topology ตั้งแต่วันแรกของระบบ)
- Soft-NUMA ถูกสร้างอัตโนมัติตั้งแต่ SQL Server 2016+ เมื่อจำนวน logical core ต่อ NUMA node เกิน 8 — ตรวจสอบผลกระทบด้วย `sys.dm_os_nodes` (`node_state_desc` จะระบุ `ONLINE AUTOMATIC`)

### 7.2 Waits — เทคนิคปัจจุบัน
- ยังใช้ **Waits & Queues methodology** เป็นแกนหลัก (Resource Waits + Signal Waits) — Signal Wait Ratio > 10–15% ต่อเนื่อง = CPU pressure
- ตั้งแต่ SQL Server 2019+ ใช้ `sys.dm_exec_query_plan_stats` (เปิดด้วย `last_query_plan_stats = 1`) เพื่อดึง **Last Actual Plan** ได้จาก `sys.dm_exec_query_stats` โดยไม่ต้องพึ่ง Query Store เสมอ
- ตีความ `CXPACKET` ร่วมกับ `CXCONSUMER`: ถ้า `CXCONSUMER` สูงตามหลัง มักเป็นพฤติกรรมปกติของ parallel plan; ให้โฟกัสที่ ratio ของ `CXPACKET` เทียบกับ wait รวม
- SQL Server 2025 บน Linux ใช้โมเดล SQLOS เดียวกัน — wait types และ DMVs ทั้งหมดใช้ได้เหมือนกัน

### 7.3 สิ่งที่ควรทำใหม่เมื่อขึ้น SQL Server 2025
1. เก็บ **Scheduler/NUMA baseline** ด้วย [Glenn Berry — SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/) (หมวด Instance Level)
2. ใช้บทบาทใหม่ `##MS_ServerPerformanceStateReader##` (แนะนำตั้งแต่ SQL Server 2022) ให้สิทธิ์อ่าน DMV แทนการยกระดับเป็น sysadmin
3. ตรวจ `max_worker_percent` / `max_workers_count` ใน `sys.dm_os_sys_info` — Workload ยุคใหม่ (หลาย connection เล็ก ๆ จาก API/microservices) ทำให้ Worker exhaustion พบบ่อยขึ้น

> อ้างอิง: [Thread and Task Architecture Guide](https://learn.microsoft.com/sql/relational-databases/thread-and-task-architecture-guide), [What's new in SQL Server 2025](https://learn.microsoft.com/sql/sql-server/what-s-new-in-sql-server-2025)