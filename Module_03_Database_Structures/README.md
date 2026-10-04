# Module 03 — Database Structures

ความเข้าใจในโครงสร้างการจัดเก็บข้อมูลทางกายภาพ (Physical Storage Structure) เป็นสิ่งจำเป็นสำหรับการบริหารจัดการพื้นที่ (Space Management) และประสิทธิภาพของระบบ (Performance) โดยเฉพาะอย่างยิ่งการออกแบบโครงสร้างไฟล์และการตั้งค่า TempDB ซึ่งมักเป็นจุดคอขวด (Bottleneck) ของระบบที่มีการใช้งานสูง

ในบทเรียนนี้ ผู้เรียนจะศึกษาโครงสร้างภายในของ Database Files, Page Allocation, และแนวทางปฏิบัติที่ดีที่สุด (Best Practices) สำหรับการวางแผน Storage

---

## เส้นทางการเรียนของโมดูล

```
Section 1            Section 2           Section 3              Section 4
Structure Internals  Data File Internals Transaction Log        TempDB Internals
Page/Extent/         ไฟล์+Proportional   WAL/VLF/Truncation     Contention/
Allocation Maps      Fill/IFI/Autogrowth /Ghost Records         ADR 2025/
(DBCC PAGE)          (Storage design)    (ตัวชี้วัด WRITELOG)     Governance 2025
```

ทั้งสี่ section ใช้เครื่องมือตัวเดียวกัน — อ่านของจริงจาก DMV/DBCC แล้วเทียบกับ Expected ที่รันจริงบน SQL Server 2025

### Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – เข้าใจโครงสร้าง Page/Extent/Allocation Maps** — อธิบายความแตกต่างของ Page Types, Extents, PFS/GAM/SGAM/IAM ได้ และอ่าน Page Header จาก `DBCC PAGE` ออก ([Section 1](Sections/01_Structure_Internals/README.md))
- **ระดับ 2 – วิเคราะห์ผลกระทบของการตั้งค่าไฟล์และ Auto-grow ได้** — อ่านค่าจาก DMV/สคริปต์เพื่อตรวจ VLF, File Layout, TempDB Layout และอธิบายผลกระทบต่อ Startup, Restore, TempDB Contention ได้ ([Section 2](Sections/02_Data_File_Internals/README.md))
- **ระดับ 3 – ออกแบบโครงสร้างไฟล์ตาม Best Practice** — วางแผนจำนวน Data Files, Log Files, TempDB Files ให้สอดคล้องกับแนวคิดใน Performance Center (แยก Data/Log, TempDB Tuning) และข้อจำกัดของ Storage จริง ([Sections 2, 4](Sections/02_Data_File_Internals/README.md))
- **ระดับ 4 – ปรับจูนโครงสร้างให้รองรับการเติบโตระยะยาว** — สร้างสคริปต์ตรวจสอบ VLF, TempDB และเสนอแผนปรับขนาดไฟล์/Auto-growth ที่เหมาะสมกับ Workload ขององค์กร รวมถึงใช้ฟีเจอร์ 2025 (ADR ใน tempdb, Space Governance) ในจุดที่เหมาะสม ([Sections 3, 4](Sections/03_Transaction_Log_Internals/README.md))

---

## 📚 Sections (สารบัญบทเรียน)

| # | Section | หัวใจหลัก |
|---|---------|-----------|
| 1 | [Structure Internals](Sections/01_Structure_Internals/README.md) | Page (8 KB) / Extent (64 KB) / PFS-GAM-SGAM-IAM / DBCC PAGE / Row-Overflow & LOB |
| 2 | [Data File Internals](Sections/02_Data_File_Internals/README.md) | ทะเบียนไฟล์ / Proportional Fill / IFI / Autogrowth / Auto Shrink |
| 3 | [Transaction Log Internals](Sections/03_Transaction_Log_Internals/README.md) | WAL / VLF / Log Truncation (`log_reuse_wait_desc`) / WRITELOG / Ghost Records |
| 4 | [TempDB Internals](Sections/04_TempDB_Internals/README.md) | User/Internal/Version Store / Contention / ADR ใน tempdb (2025) / Space Governance (2025) |

---

## 🧪 Labs

คู่มือปฏิบัติแบบ Instruction + Code block: [Labs/README.md](Labs/README.md) — สคริปต์ประกอบอยู่ใน `Sections/*/Scripts/` ตามหัวข้อ:

| Section | Scripts |
|:--------|:--------|
| 1 | `01_Bad_vs_Good_Structure.sql` (GUID vs IDENTITY → fragmentation), `02_DBCC_PAGE_Analysis.sql` |
| 2 | `03_IFI_and_TempDB_Config.sql`, `04_Database_File_Sizes.sql` |
| 3 | `05_VLF_Analysis.sql` |
| 4 | แล็บ Exercise 4 (tempdb layout + contention) ใน Labs README |

**ค่าอ้างอิงจากการรันจริง (SQL Server 2025 RTM-GDR 17.0.1135.8, 2026-10-02):** first DATA_PAGE ของ `Person.Person` = **1:736** · BadKeyTable frag **98.5%** เทียบ GoodKeyTable **1.2%** · log AdventureWorks = **6 VLFs** (~136 MB) · tempdb = **4 data files** × 72 MB (growth 64 MB)

---

## ❓ คำถามที่พบบ่อยท้ายโมดูล

<details>
<summary><b>1. ทำไมไม่ควรมี VLF จำนวนมาก?</b></summary>
VLF จำนวนมากเกิดจากการตั้งค่า Auto-growth ขนาดเล็ก ส่งผลให้ Database Startup, Restore และ Replication ทำงานช้าลง — อ่านกลไกและวิธีแก้ใน [Section 3.3](Sections/03_Transaction_Log_Internals/README.md)
</details>

<details>
<summary><b>2. จำนวน TempDB Data Files ที่แนะนำเบื้องต้นคือเท่าไร?</b></summary>
เท่ากับจำนวน CPU Core แต่ไม่เกิน 8 ไฟล์ในเบื้องต้น (ยังมี contention ค่อยเพิ่มทีละกลุ่ม 4) และทุกไฟล์ต้องมีขนาด/growth เท่ากัน — อ่านต่อใน [Section 3.4](Sections/04_TempDB_Internals/README.md)
</details>

<details>
<summary><b>3. ทำไมไม่ควรใช้ Auto Shrink?</b></summary>
เพราะทำให้เกิด Index Fragmentation ระดับสูง และสิ้นเปลือง CPU/I/O จากวงจร Shrink-then-Grow — วงจรครบใน [Section 3.2](Sections/02_Data_File_Internals/README.md)
</details>

<details>
<summary><b>4. ตารางที่ใช้ Random GUID เป็น clustered key มีผลต่อโครงสร้างอย่างไร?</b></summary>
Insert แทรกกลาง B-Tree ตลอด → page split ต่อเนื่อง → fragmentation สูง + page_count บวม + log โตเร็ว (แล็บจริง: frag 98.5% เทียบ IDENTITY 1.2%) — พิสูจน์ใน [Labs Exercise 2](Labs/README.md)
</details>

<details>
<summary><b>5. ตั้งแต่ SQL Server 2025 tempdb มีอะไรใหม่?</b></summary>
ADR ใน tempdb (rollback ทันที + aggressive log truncation, ต้อง restart engine หลังเปิด) และ TempDB Space Resource Governance (จำกัดโควตาต่อ workload group; Resource Governor อยู่ใน Standard แล้ว) — ตรวจ/ตั้งค่าใน [Section 3.4](Sections/04_TempDB_Internals/README.md)
</details>

---

## 🔗 อ้างอิงหลัก

- [tempdb database — Microsoft Learn](https://learn.microsoft.com/sql/relational-databases/databases/tempdb-database) · [ADR in tempdb (2025)](https://learn.microsoft.com/sql/relational-databases/accelerated-database-recovery-concepts) · [TempDB space resource governance](https://learn.microsoft.com/sql/relational-databases/resource-governor/tempdb-space-resource-governance)
- [sys.dm_db_log_info](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-db-log-info-transact-sql) · [Pages and Extents](https://learn.microsoft.com/sql/relational-databases/pages-and-extents-architecture-guide)
- Glenn Berry: [SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)

**แบบทดสอบ:** [Quiz Bank](Quiz_Bank.md) — 15 ข้อ (multiple choice + ตอบสั้น) ครอบคลุมทั้ง 4 sections
