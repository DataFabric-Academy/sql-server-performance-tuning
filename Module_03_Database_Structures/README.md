ความเข้าใจในโครงสร้างการจัดเก็บข้อมูลทางกายภาพ (Physical Storage Structure) เป็นสิ่งจำเป็นสำหรับการบริหารจัดการพื้นที่ (Space Management) และประสิทธิภาพของระบบ (Performance) โดยเฉพาะอย่างยิ่งการออกแบบโครงสร้างไฟล์และการตั้งค่า TempDB ซึ่งมักเป็นจุดคอขวด (Bottleneck) ของระบบที่มีการใช้งานสูง

ในบทเรียนนี้ ผู้เรียนจะศึกษาโครงสร้างภายในของ Database Files, Page Allocation, และแนวทางปฏิบัติที่ดีที่สุด (Best Practices) สำหรับการวางแผน Storage

### 1.1 Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – เข้าใจโครงสร้าง Page/Extent/Allocation Maps**
  - อธิบายความแตกต่างของ Page Types, Extents, PFS/GAM/SGAM/IAM ได้
- **ระดับ 2 – วิเคราะห์ผลกระทบของการตั้งค่าไฟล์และ Auto-grow ได้**
  - อ่านค่าจาก DMV/สคริปต์เพื่อตรวจ VLF, File Layout, TempDB Layout และอธิบายผลกระทบต่อ Startup, Restore, TempDB Contention ได้
- **ระดับ 3 – ออกแบบโครงสร้างไฟล์ตาม Best Practice**
  - วางแผนจำนวน Data Files, Log Files, TempDB Files ให้สอดคล้องกับแนวคิดใน Performance Center (แยก Data/Log, TempDB Tuning) และข้อจำกัดของ Storage จริง
- **ระดับ 4 – ปรับจูนโครงสร้างให้รองรับการเติบโตระยะยาว**
  - สร้างสคริปต์ตรวจสอบ VLF, TempDB และเสนอแผนปรับขนาดไฟล์/Auto-growth ที่เหมาะสมกับ Workload ขององค์กร

---

---


## 📚 Sections (สารบัญบทเรียน)

| # | Section |
|---|---------|
| 1 | [Structure Internals](Sections/01_Structure_Internals/README.md) |
| 2 | [Data File Internals](Sections/02_Data_File_Internals/README.md) |
| 3 | [Transaction Log Internals](Sections/03_Transaction_Log_Internals/README.md) |
| 4 | [TempDB Internals](Sections/04_TempDB_Internals/README.md) |

---


## 🧪 Labs

คู่มือปฏิบัติแบบ Instruction + Code block: [Labs/README.md](Labs/README.md) — สคริปต์ประกอบอยู่ใน `Sections/*/Scripts/` ตามหัวข้อ

---


## <details>
<summary><b>1. ทำไมไม่ควรมี VLF จำนวนมาก?</b></summary>
VLF จำนวนมากเกิดจากการตั้งค่า Auto-growth ขนาดเล็ก ส่งผลให้ Database Startup, Restore และ Replication ทำงานช้าลง
</details>

<details>
<summary><b>2. จำนวน TempDB Data Files ที่แนะนำเบื้องต้นคือเท่าไหร่?</b></summary>
เท่ากับจำนวน CPU Core แต่ไม่เกิน 8 ไฟล์ในเบื้องต้น และทุกไฟล์ต้องมีขนาดเท่ากัน
</details>

<details>
<summary><b>3. ทำไมไม่ควรใช้ Auto Shrink?</b></summary>
เพราะทำให้เกิด Index Fragmentation ระดับสูง และสิ้นเปลือง CPU/I/O จากวงจร Shrink-then-Grow
</details>


---

---


## ### 8.1 TempDB บน SQL Server 2025
- **ADR ใน tempdb (ใหม่ใน 2025)** — เปิดได้เพื่อให้ transaction บน temp table/table variable ได้ประโยชน์จาก *Instantaneous rollback* และ *Aggressive log truncation* ลดปัญหา tempdb log เต็ม (ต้อง restart Database Engine หลังเปิด)
  ```sql
  ALTER DATABASE tempdb SET ACCELERATED_DATABASE_RECOVERY = ON;  -- 2025, ต้อง restart engine
  ```
- **TempDB space resource governance (2025)** — Resource Governor จัดการพื้นที่ tempdb ต่อ workload group ได้ ป้องกัน runaway query กินพื้นที่ tempdb ทั้ง instance (Resource Governor ตอนนี้อยู่ใน **Standard edition** แล้ว)
- **Memory-optimized tempdb metadata** (แนะนำใน 2019) ยังเป็น opt-in และยังแนะนำให้เปิด — ลด metadata contention บนระบบหลายพัน temp table ต่อวินาที
- **tmpfs สำหรับ tempdb บน Linux (2025)** — วาง tempdb บน memory filesystem ได้

### 8.2 Transaction Log / VLF
- ตรวจ VLF ด้วย `sys.dm_db_log_info(file_id)` (แทน `DBCC LOGINFO`) และดูรวมกับ `sys.dm_db_log_space_usage`
- IFI ตั้งแต่ SQL Server 2022: log autogrow ≤ 64 MB ได้ประโยชน์จาก Instant File Initialization ด้วย

### 8.3 Best Practice ปัจจุบันจาก Microsoft Learn (tempdb)
1. ใช้ IFI + preallocate ขนาดไฟล์ให้พอกับ workload ปกติ
2. แบ่งเป็นหลาย data file ขนาด/autogrowth เท่ากัน (เริ่มจำนวน = logical core สูงสุด 8 ไฟล์, เพิ่มทีละกลุ่ม 4 หากยังมี contention — ตามแนวทาง MS ปัจจุบัน)
3. ตั้ง autogrowth เป็น MB ที่เหมาะสม (เช่น 64–256 MB) ไม่ใช้ PERCENT

> อ้างอิง: [tempdb database](https://learn.microsoft.com/sql/relational-databases/databases/tempdb-database), [ADR in tempdb (2025)](https://learn.microsoft.com/sql/relational-databases/accelerated-database-recovery-concepts), [TempDB space resource governance](https://learn.microsoft.com/sql/relational-databases/resource-governor/tempdb-space-resource-governance)