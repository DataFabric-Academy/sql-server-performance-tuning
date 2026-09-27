SQL เป็นภาษาแบบ Declarative (กำหนดผลลัพธ์ที่ต้องการ ไม่ใช่ขั้นตอนการทำงาน) หน้าที่ของ **Query Optimizer** คือการคำนวณและสร้างแผนการทำงาน (**Execution Plan**) ที่มีประสิทธิภาพสูงสุด (Lowest Cost)

การวิเคราะห์ Execution Plan เป็นทักษะสำคัญที่ช่วยในการตรวจสอบปัญหาประสิทธิภาพ (Performance Tuning) และเข้าใจพฤติกรรมของ Database Engine

### 1.1 Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – อ่าน Execution Plan ได้อย่างถูกต้อง**
  - แยก Logical/Physical Operators, เข้าใจ Seek/Scan/Key Lookup, Join Types, และการอ่าน Estimated vs Actual Rows
- **ระดับ 2 – ระบุปัญหาที่มองเห็นจาก Plan**
  - ตรวจพบ Missing Index, Implicit Conversion, Spill, Parallelism ผิดที่ และเชื่อมโยงกับ I/O/CPU จาก DMV/PerfMon ได้
- **ระดับ 3 – ใช้ Live Query Stats และ IQP ช่วยวิเคราะห์ปัญหา**
  - ใช้ Live Query Statistics, `sys.dm_exec_query_profiles`, และฟีเจอร์ Intelligent Query Processing (เช่น Memory Grant Feedback, Scalar UDF Inlining) เพื่อยืนยันสมมติฐาน
- **ระดับ 4 – ออกแบบแนวทาง Tuning ตาม Best Practice**
  - ปรับปรุง Query/Index ให้สอดคล้องกับแนวทางจาก Query Processing Architecture Guide และ Performance Center (โฟกัสที่ Plan Quality ก่อน Scale Hardware) ได้เป็นขั้นตอน

---

---


## 📚 Sections (สารบัญบทเรียน)

| # | Section |
|---|---------|
| 1 | [Query Optimizer](Sections/01_Query_Optimizer/README.md) |
| 2 | [Execution Plan Formats](Sections/02_Execution_Plan_Formats/README.md) |
| 3 | [Analyzing Query Plans](Sections/03_Analyzing_Query_Plans/README.md) |
| 4 | [Intelligent Query Processing](Sections/04_Intelligent_Query_Processing/README.md) |

---


## 🧪 Labs

คู่มือปฏิบัติแบบ Instruction + Code block: [Labs/README.md](Labs/README.md) — สคริปต์ประกอบอยู่ใน `Sections/*/Scripts/` ตามหัวข้อ

---


## <details>
<summary><b>1. Logical Reads กับ Physical Reads ต่างกันอย่างไร?</b></summary>
Logical Reads คือการอ่านจาก Memory (Buffer Pool) ซึ่งเร็วมาก ส่วน Physical Reads คือการอ่านจาก Disk จริงๆ ซึ่งช้ากว่ามาก
</details>

<details>
<summary><b>2. Key Lookup (Bookmark Lookup) คืออะไร และทำไมถึงส่งผลเสีย?</b></summary>
คือ operations ที่ต้องกระโดดจาก Non-Clustered Index กลับไปอ่านข้อมูลฉบับเต็มที่ Clustered Index (Heap) เนื่องจาก NCI ไม่มี Column ที่ต้องการครบ ถ้าทำเยอะๆ จะเปลือง I/O มหาศาล
</details>

<details>
<summary><b>3. Implicit Conversion คืออะไร?</b></summary>
การแปลง Data Type โดยอัตโนมัติเนื่องจาก Type ไม่ตรงกัน (เช่นเทียบ `VARCHAR` กับ `NVARCHAR`) ซึ่งมักจะทำให้ใช้ Index ไม่ได้ (Index Scan แทน Seek)
</details>


---

---


## | ฟีเจอร์ | รุ่นที่เริ่ม | สาระสำคัญ |
|:--------|:------------|:----------|
| Adaptive Joins | 2017 (DB compat 140) | เลือก join strategy หลัง scan แถวแรก |
| Memory Grant Feedback | 2017 / **persisted ใน 2019+** | ปรับ grant จาก spill/overgrant รอบก่อน |
| Interleaved Execution (MSTVFs) | 2017 | หยุด optimize เพื่อรู้ค่า card จริงก่อน |
| Scalar UDF Inlining | 2019 | UDF สเกลาร์แปลงเป็น relational expressions |
| Batch Mode on Rowstore | 2019 | รับ batch mode ได้แม้ไม่มี columnstore |
| Table Variable Deferred Compilation | 2019 | ใช้ card จริงของ table variable |
| Parameter Sensitive Plan Optimization (PSPO) | 2022 (compat 160) | **หลาย plan ต่อ statement** สำหรับ data ที่เบ้ |
| Degree of Parallelism (DOP) Feedback | 2022 → **เปิด default ใน 2025** | ปรับ DOP อัตโนมัติตาม repeatable query |
| **Optional Parameter Plan Optimization (OPPO)** | **2025 (compat 170)** | ต่อยอด PSPO สำหรับ query แบบ optional parameters (`@p IS NULL OR col = @p`) |
| **CE Feedback for Expressions** | **2025** | เรียนรู้ CE ของ expression ข้าม query |

- ตรวจสอบ/ตั้ง compat level 170 เพื่อเปิดใช้ฟีเจอร์รุ่น 2025:
  ```sql
  ALTER DATABASE AdventureWorks2025 SET COMPATIBILITY_LEVEL = 170;
  ```
- ใช้ `sys.query_store_plan` Column `has_compile_replay_script` / XEvent ของ IQP ติดตามการทำงานของ feedback

> อ้างอิง: [Intelligent Query Processing](https://learn.microsoft.com/sql/relational-databases/performance/intelligent-query-processing), [What's new in SQL Server 2025 — Query Store and IQP](https://learn.microsoft.com/sql/sql-server/what-s-new-in-sql-server-2025)