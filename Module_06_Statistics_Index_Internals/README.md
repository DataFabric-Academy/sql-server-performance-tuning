Index เปรียบเสมือนเครื่องมือช่วยค้นหาข้อมูลที่มีประสิทธิภาพสูงสุดในระบบฐานข้อมูล ปัญหาประสิทธิภาพส่วนใหญ่ (Performance Issues) มักเกิดจากการออกแบบ Index ที่ไม่เหมาะสม หรือขาด Index ที่จำเป็นสำหรับการตอบสนอง Query (SARGable Predicates)

ในบทเรียนนี้ ผู้เรียนจะศึกษาโครงสร้างภายในของ Statistics, Index B-Tree, และ Columnstore Index

### 1.1 Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – เข้าใจ Statistics และ Cardinality Estimation**
  - อ่าน/อธิบาย Header, Density, Histogram จาก `DBCC SHOW_STATISTICS` ได้ และเข้าใจผลของ CE ต่อ Plan
- **ระดับ 2 – วิเคราะห์และดูแล Index ให้เหมาะกับ Workload**
  - แยกแยะ Heap vs Clustered/Nonclustered B-Tree, ระบุ Missing/Bad/Overlapping Index และออกแบบ Index ใหม่ที่สอดคล้องกับ Workload ได้
- **ระดับ 3 – ใช้ DMV/เครื่องมือช่วยออกแบบ Index อย่างมีวิจารณญาณ**
  - ใช้ `sys.dm_db_missing_index_*`, `sys.dm_db_index_usage_stats`, และเครื่องมือภายนอกเช่น Plan Explorer เพื่อปรับโครงสร้าง Index ให้สมดุลระหว่าง Read และ Write ตามแนวทางจาก Index Design Guide ของ Microsoft
- **ระดับ 4 – ใช้เทคโนโลยี Columnstore และฟีเจอร์ใหม่ๆ**
  - ตัดสินใจเลือกใช้ Clustered/Nonclustered Columnstore ใน DW/HTAP Scenario, เข้าใจ Rowgroup/Segment/Deltastore และข้อจำกัดของ Columnstore Index

---

---


## 📚 Sections (สารบัญบทเรียน)

| # | Section |
|---|---------|
| 1 | [Statistics Cardinality Estimation](Sections/01_Statistics_Cardinality_Estimation/README.md) |
| 2 | [Index Internals](Sections/02_Index_Internals/README.md) |
| 3 | [Columnstore Indexes](Sections/03_Columnstore_Indexes/README.md) |

---


## 🧪 Labs

คู่มือปฏิบัติแบบ Instruction + Code block: [Labs/README.md](Labs/README.md) — สคริปต์ประกอบอยู่ใน `Sections/*/Scripts/` ตามหัวข้อ

---


### 7.1 Statistics & Cardinality Estimation
- **CE Feedback for Expressions (ใหม่ใน 2025)**: engine เรียนรู้ค่า CE ที่เหมาะกับ expression (เช่น `DATEDIFF`, `CONVERT` บน predicate) จากการรันจริงข้าม query แล้วใช้ซ้ำ — ลดปัญหา CE ผิดเพี้ยนซ้ำ ๆ
- **Persisted statistics for readable secondaries (2025)**: AG readable secondary สร้าง/เก็บ stats ของ workload ฝั่ง read ได้เอง ไม่ต้องรอ stats จาก primary — แก้ปัญหา plan แย่บน secondary
- Auto update statistics async / auto drop statistics (`AUTO_DROP` — 2022) ยังเป็น default best practice

### 7.2 Columnstore ล่าสุด
- **2025**: Ordered **nonclustered** columnstore index, ordered CCI **build online** ได้ พร้อมคุณภาพ sort ที่ดีขึ้น และ SHRINK ทำงานดีขึ้นเมื่อมี CCI อยู่
- Batch mode execution ทำงานกับ built-in functions เร็วขึ้นอีกใน 2025 (เช่น math functions, DATETRUNC)

### 7.3 Index Tuning Strategy ปี 2025
- Missing Index DMVs ยังใช้ได้แต่ต้อง **review ด้วยตัวเองเสมอ** (ไม่คิด INCLUDE/ORDER, ชี้ตารางซ้ำ) — ใช้คู่กับ Query Store และ [Glenn Berry diagnostic queries สำหรับ SQL Server 2025](https://glennsqlperformance.com/resources/) หมวด Index
- Unused/duplicate index analysis ควรอิงช่วงเวลายาว ≥ 1 business cycle ก่อน DROP

> อ้างอิง: [Columnstore indexes — what's new](https://learn.microsoft.com/sql/relational-databases/indexes/columnstore-indexes-what-s-new), [IQP feature list](https://learn.microsoft.com/sql/relational-databases/performance/intelligent-query-processing), [Persisted stats on secondaries](https://learn.microsoft.com/sql/relational-databases/performance/persisted-stats-secondary-replicas)