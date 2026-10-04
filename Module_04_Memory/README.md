หน่วยความจำ (Memory) เป็นทรัพยากรที่สำคัญที่สุดสำหรับ SQL Server เนื่องจากการเข้าถึงข้อมูลใน RAM มีความเร็วกว่า Disk หลายพันเท่า การบริหารจัดการ Memory ที่มีประสิทธิภาพจึงเป็นหัวใจสำคัญของการปรับปรุงประสิทธิภาพระบบ (Performance Tuning)

ในบทเรียนนี้ ผู้เรียนจะศึกษาโครงสร้าง Memory Architecture ของ SQL Server, การตั้งค่าที่เหมาะสม, และการวิเคราะห์ปัญหา Memory Pressure

### 1.1 Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – เข้าใจ Virtual/Physical Memory และ NUMA**
  - อธิบาย Virtual Address Space, Paging, NUMA Node, Local/Remote Memory ได้
- **ระดับ 2 – อ่านโครงสร้าง Memory ภายใน SQL Server**
  - เข้าใจ Buffer Pool, Memory Clerks ต่างๆ, Resource Monitor และ Target/Committed Memory
- **ระดับ 3 – ตั้งค่า Memory ได้อย่างปลอดภัย**
  - คำนวณและกำหนด `max server memory`, ตัดสินใจใช้ LPIM และ Resource Governor ตามแนวทางจาก Performance Center และ Architecture Guide ได้
- **ระดับ 4 – วินิจฉัย Memory Pressure ได้จาก DMVs/Waits**
  - ใช้ `sys.dm_os_process_memory`, `sys.dm_os_memory_clerks`, PLE, และ Wait Types เช่น `RESOURCE_SEMAPHORE` เพื่อหาสาเหตุและออกแบบแนวทางแก้ไขได้อย่างเป็นขั้นตอน

---

---

---


## 📚 Sections (สารบัญบทเรียน)

| # | Section |
|---|---------|
| 1 | [Windows Memory](Sections/01_Windows_Memory/README.md) |
| 2 | [SQL Server Memory](Sections/02_SQL_Server_Memory/README.md) |
| 3 | [Memory Pressure Diagnostics](Sections/03_Memory_Pressure_Diagnostics/README.md) |
| 4 | [In Memory OLTP](Sections/04_In_Memory_OLTP/README.md) |

---


## 🧪 Labs

คู่มือปฏิบัติแบบ Instruction + Code block: [Labs/README.md](Labs/README.md) — สคริปต์ประกอบอยู่ใน `Sections/*/Scripts/` ตามหัวข้อ

---


## <details>
<summary><b>1. Page Life Expectancy (PLE) หมายถึงอะไร?</b></summary>
ค่าเฉลี่ยเวลาที่ Page อยู่ใน Buffer Pool (หน่วยเป็นวินาที) ถ้าค่าลดลงอย่างรวดเร็ว (รูปฟันเลื่อย) บ่งบอก Memory Pressure
</details>

<details>
<summary><b>2. Lock Pages in Memory (LPIM) มีประโยชน์อย่างไร?</b></summary>
ป้องกันไม่ให้ Windows นำ SQL Server Memory ไปทำ Paging ลง Disk ช่วยให้ระบบมีเสถียรภาพมากขึ้น
</details>

<details>
<summary><b>3. RESOURCE_SEMAPHORE wait type บอกอะไร?</b></summary>
บอกว่า Query ต้องรอ Memory Grant สำหรับ Sort/Hash Operation แสดงว่ามี Workload ที่ต้องการ Memory เยอะเกินไป
</details>

---

---


### 7.1 ตัวเลข Memory ปัจจุบัน
- **SQL Server 2025 Standard edition: buffer pool สูงสุด 256 GB** ต่อ instance (เพิ่มจาก 128 GB ใน 2022) — วางแผน edition ตามขนาด working set ได้ง่ายขึ้น
- Standard Developer / Enterprise Developer editions (ฟรี ใช้พัฒนา) ให้ความจุเท่ารุ่นจ่ายเงิน — เหมาะกับการจำลอง Lab

### 7.2 In-Memory OLTP ปี 2025
- ตอนนี้ **ลบ memory-optimized container/filegroup ที่ว่างได้แล้ว (2025)** — แก้ปัญหา "เคยลอง Hekaton แล้วเลิกใช้ แต่ถอดไม่ได้" ปิดจุดอ่อนสุดท้ายของการนำไปใช้จริง
- ยังเหมาะกับ pattern: high-throughput insert + lookup (เช่น ETL staging, session store, IoT ingestion) — ไม่ใช่ยาแครามทุกปัญหา

### 7.3 การวัด Memory Pressure ยุคปัจจุบัน
- **อย่าตัดสินจาก PLE ตัวเดียว**: PLE เป็นค่ารวมทั้ง instance และแปรผันกับขนาด buffer pool — ต้องดูคู่กับ `Page reader/writer sec`, `MEMORYCLERK_SQLBUFFERPAGES`, page faults ของ process, และ wait `RESOURCE_SEMAPHORE` / `WRITE_PAGE` / `RESERVED_MEMORY_ALLOCATION_EXT`
- ดู memory ต่อ NUMA node (`sys.dm_os_memory_nodes`) ไม่ใช่แค่รวม
- PMEM/Hybrid Buffer Pool: เข้าถึง data page บน PMEM โดยตรง กระทบการตีความ `sys.dm_os_buffer_descriptors`

> อ้างอิง: [Memory Management Architecture Guide](https://learn.microsoft.com/sql/relational-databases/memory-management-architecture-guide), [What's new in SQL Server 2025](https://learn.microsoft.com/sql/sql-server/what-s-new-in-sql-server-2025)