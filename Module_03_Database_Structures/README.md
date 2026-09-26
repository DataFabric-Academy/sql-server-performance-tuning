# Module 3: Database Structures

## 1. บทนำ (Introduction)
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

## 2. Database Structure Internals (Lesson 1)

**Database Structure** เป็นพื้นฐานสำคัญในการทำ Performance Tuning เพราะข้อมูลทั้งหมดถูกจัดเก็บในรูปแบบ **Pages** (8KB) ภายใน Data Files

> **หลักการสำคัญ:** SQL Server อ่าน/เขียนข้อมูลเป็นหน่วย **Page** ไม่ใช่ Row ดังนั้น Query ที่ต้องอ่านหลาย Pages จะช้ากว่า Query ที่อ่านน้อย Pages

### 2.1 Database Components (Data Files Structure)

ฐานข้อมูลใน SQL Server ประกอบด้วย **Data Files** (`.mdf`, `.ndf`) ซึ่งเก็บข้อมูลจริงและโครงสร้างของอ็อบเจ็กต์ (Tables, Indexes ฯลฯ) โครงสร้างฝั่ง Data Files ไล่จากหน่วยที่เล็กไปใหญ่ดังนี้:

#### โครงสร้างลำดับชั้น: Page → Extent → File → Filegroup

**โครงสร้างแบบลำดับชั้น:**

```
Filegroup (PRIMARY)
│
├── Data File 1 (.mdf)
│   │
│   ├── Extent 1 (64KB)
│   │   ├── Page 1 (8KB)
│   │   ├── Page 2 (8KB)
│   │   ├── Page 3 (8KB)
│   │   ├── ...
│   │   └── Page 8 (8KB)
│   │
│   ├── Extent 2 (64KB)
│   │   └── ...
│   │
│   └── Extent N (64KB)
│
├── Data File 2 (.ndf)
│   │
│   ├── Extent 1 (64KB)
│   │   ├── Page 1 (8KB)
│   │   ├── Page 2 (8KB)
│   │   └── ...
│   │
│   └── Extent N (64KB)
│
└── Data File N (.ndf)
    └── ...
```

**สรุปโครงสร้าง:**
- **Filegroup** → ประกอบด้วย **Data Files** หลายไฟล์
- **Data File** → ประกอบด้วย **Extents** จำนวนมาก
- **Extent** (64KB) → ประกอบด้วย **Pages** 8 หน้า
- **Page** (8KB) → หน่วยย่อยที่สุดในการจัดเก็บข้อมูล

**1. Pages (8KB)**  
   - หน่วยย่อยที่สุดในการจัดเก็บข้อมูลใน Data File  
   - ทุก Row/Index สุดท้ายจะถูกเก็บอยู่ใน Page เหล่านี้  
   - ขนาดคงที่ 8,192 bytes (8KB)

**2. Extents (64KB = 8 Pages)**  
   - หน่วยการจองพื้นที่ขนาดใหญ่ขึ้น ประกอบด้วย 8 Pages ที่ต่อเนื่องกัน  
   - *Uniform Extent*: ทั้ง 8 Pages เป็นของ Object เดียว (รูปแบบหลักในเวอร์ชันใหม่)  
   - *Mixed Extent*: แชร์พื้นที่ร่วมกันหลาย Object (พบบ่อยในเวอร์ชันเก่าเพื่อประหยัดพื้นที่เริ่มต้นสำหรับตารางเล็ก)

**3. Data Files (.mdf/.ndf)**  
   - ประกอบด้วย Extents จำนวนมาก  
   - `.mdf` = Primary Data File (มี 1 ไฟล์เสมอ)  
   - `.ndf` = Secondary Data Files (สามารถมีหลายไฟล์)  
   - การออกแบบให้มีหลายไฟล์ (ใน Filegroup เดียวกัน) ช่วยกระจาย I/O และลด Allocation Contention (`GAM`/`SGAM` contention)

**4. Filegroups**  
   - กลุ่มของ Data Files ที่ใช้เป็นหน่วยบริหารจัดการ (Admin Unit) และหน่วยวางแผน Performance  
   - มีอย่างน้อย 1 กลุ่มเสมอคือ **PRIMARY Filegroup**  
   - สามารถสร้าง Secondary Filegroups เพื่อแยก Data/Index ตามประเภทข้อมูล, อายุข้อมูล หรือ Storage Tier ได้

> **หมายเหตุ:** Transaction Log Files (`.ldf`) จะอธิบายใน [หัวข้อ 5. Transaction Log Internals](#5-transaction-log-internals)

### 2.2 Page Types & Structure
Page ขนาด 8192 bytes ประกอบด้วยส่วน Header, Data, และ Row Offset โดยมีประเภทที่สำคัญดังนี้:
*   **Data Page (1)**: เก็บข้อมูลในระดับ Leaf Level ของ Clustered Index หรือ Heap
*   **Index Page (2)**: เก็บโครงสร้าง B-Tree
*   **Text/Image Page (3,4)**: เก็บข้อมูล LOB (Large Object)
*   **Allocation Maps (GAM, SGAM, IAM, PFS)**: แผนที่สำหรับติดตามการใช้งาน Space และ Extent

#### Allocation Maps (รายละเอียด)

| Map Type | ชื่อเต็ม | หน้าที่ | ครอบคลุม |
|----------|---------|--------|----------|
| **GAM** | Global Allocation Map | ติดตามว่า Extent ใดว่างอยู่ (Free) | 64,000 extents (~4GB) |
| **SGAM** | Shared Global Allocation Map | ติดตาม Mixed Extents ที่ยังมีหน้าว่างอยู่ | 64,000 extents (~4GB) |
| **IAM** | Index Allocation Map | ติดตามว่า Object นั้นๆ ใช้ Extent ไหนบ้าง | Per Object |
| **PFS** | Page Free Space | ติดตาม Free Space ในแต่ละ Page (% ที่เหลือ) | 8,088 pages (~64MB) |

> - **แก้ไข**: เพิ่มจำนวน TempDB Data Files ให้เท่ากับ CPU Cores (สูงสุด 8 ไฟล์เบื้องต้น)

### 2.4 Advanced Pages & Extents Architecture (Microsoft Guide)

1.  **Proportional Fill Algorithm**:
    *   SQL Server จะเขียนข้อมูลลง Data Files โดยดูจาก **Free Space Ratio**
    *   *Scenario*: ถ้า File A ว่าง 10GB และ File B ว่าง 5GB -> SQL จะเขียนลง A 2 หน้า สลับกับ B 1 หน้า (2:1 Ratio)
    *   *Impact*: ถ้าขนาดไฟล์ไม่เท่ากัน จะทำให้ไฟล์ใหญ่ทำงานหนักกว่า (IO hotspot) จึงแนะนำให้ทำ **Equal File Size** เสมอ

2.  **Row-Overflow vs LOB Pages**:
    *   SQL Server 1 Page เก็บได้ ~8060 bytes ถ้าข้อมูลเกินจะเกิดอะไรขึ้น?
    *   **Row-Overflow**: (Variable width columns เช่น `varchar(8000)`) ถ้าแถวรวมกันเกิน 8060 bytes ส่วนที่เกินจะถูกย้ายไป page อื่น (แต่ยังถือเป็น `IN_ROW_DATA` allocation unit ในบางมุมมอง หรือ `ROW_OVERFLOW_DATA`)
    *   **LOB Data**: (`text`, `image`, `varchar(max)`) ถ้าข้อมูลใหญ่มาก จะถูกเก็บแยกใน `LOB_DATA` allocation unit โดยใน Data Page หลักจะเก็บแค่ Pointer (16-24 bytes)

3.  **Space Tracking Internals**:
    *   **PFS Byte**: 1 Byte ต่อ 1 Page บอกความแน่น 5 ระดับ (Empty, 1-50%, 51-80%, 81-95%, Full)
    *   **GAM Bit**: 1 = Extent ว่าง (Free), 0 = เต็ม
    *   **SGAM Bit**: 1 = Mixed Extent ที่ยังมีหน้าว่าง (ใช้สำหรับ object เล็กๆ) -> นี่คือจุดที่เกิด Latch Contention บ่อยสุดใน TempDB ยุคเก่า

### 2.3 SQL Server 2022 Feature: Ledger
*   **Ledger Tables**: ตารางชนิดพิเศษที่ใช้ Blockchain technology ภายในเพื่อรับรองความถูกต้องของข้อมูล (Immutability & Tamper-evidence)
*   **Structure**: ประกอบด้วย Updatable Ledger Table และ History Table ที่เชื่อมโยงกันด้วย Cryptographic Hash

---

## 3. Data File Internals (Lesson 2)

### 3.1 Volume Configuration Best Practices
*   **RAID Configuration**: แนะนำ RAID 10 สำหรับ Log Files เพื่อรองรับ Write Intensive Workload และ RAID 5/10 สำหรับ Data Files
*   **Formatting**: ควรกำหนด *Allocation Unit Size* เป็น **64KB** เพื่อให้สอดคล้องกับขนาดของ Extent
*   **Isolation**: ควรแยก Data Files และ Log Files ออกจากกันในระดับ Physical Disk เพื่อลด I/O contention

### 3.2 Instant File Initialization (IFI)
*   **Concept**: การลดระยะเวลาในการจองพื้นที่ Disk (Allocation) โดยข้ามขั้นตอนการเขียน Zero-filling
*   **Benefit**: เพิ่มความเร็วในการทำงานของคำสั่ง `CREATE DATABASE`, `RESTORE`, และ `Autogrow`
*   **Requirement**: ต้องกำหนดสิทธิ์ `Perform Volume Maintenance Tasks` ให้กับ SQL Server Service Account

### 3.3 Auto Grow & Shrink Strategy
*   **Auto Grow**: ควรพิจารณาเป็นมาตรการสำรอง (Safety Net) เท่านั้น
    *   *Configuration*: ควรกำหนดเป็น Fixed Size (MB) แทน Percentage (%) เพื่อไม่ให้การขยายตัวแต่ละครั้งใช้เวลานานเกินไป
*   **Auto Shrink**: **ไม่แนะนำให้ใช้งาน (Strongly Discouraged)**
    *   ก่อให้เกิด Index Fragmentation ระดับสูง
    *   สิ้นเปลือง CPU และ I/O จากวงจรการ Shrink-then-Grow

### 3.4 Logical vs Physical I/O
*   **Logical I/O**: การอ่านข้อมูลจาก Buffer Pool (RAM) -> มีประสิทธิภาพสูง
*   **Physical I/O**: การอ่านข้อมูลจาก Disk -> มี Latency สูง
*   **Goal**: อัตราส่วน *Buffer Cache Hit Ratio* ควรสูงเกือบ 100% เพื่อลด Physical I/O

---

## 4. TempDB Internals (Lesson 3)

### 4.1 TempDB Usage and Importance
TempDB เป็น Global Resource ที่ใช้งานร่วมกันทั้ง Instance สำหรับ:
1.  **User Objects**: Temporary tables (`#Local`, `##Global`), Table variables
2.  **Internal Objects**: Workfiles สำหรับ Sort/Hash operations
3.  **Version Store**: เก็บ Row Versions สำหรับ Snapshot Isolation และ Online Index Build

### 4.2 TempDB Contention & Optimization

เมื่อหลาย Session พยายามสร้าง Temp Table พร้อมกัน SQL Server ต้องอัปเดต "แผนที่" ของ Database (Allocation Pages) ซึ่งอยู่บน Page เดียวกัน ทำให้เกิดการ "แย่งกันเขียน" หน้าเดียวกัน

**PAGELATCH Contention คืออะไร?**
- **Latch** = กลไก Lock ภายในที่ปกป้อง Data Page ขณะอ่าน/เขียน Memory
- เมื่อ Thread หลายตัวต้องการเขียน Page เดียวกัน → ต้องรอ Latch → เกิด Wait Type `PAGELATCH_EX` หรือ `PAGELATCH_UP`
- ใน TempDB ปัญหานี้มักเกิดที่ **PFS/GAM/SGAM Pages** (Allocation Bitmaps)

**วิธีแก้ไข:**
*   **Multiple Data Files**: สร้าง Data File ให้เท่ากับจำนวน CPU Core (สูงสุด 8 ไฟล์ในเบื้องต้น) → กระจาย Allocation Pages ออก
*   **Equal Size**: กำหนดขนาดและ Auto-growth ให้เท่ากันทุกไฟล์ เพื่อให้ *Proportional Fill Algorithm* ทำงานได้อย่างสมดุล
*   **Memory-Optimized TempDB Metadata (SQL 2019+)**: ย้าย System Catalog บางส่วนลง Memory เพื่อไม่ต้อง Latch บน Disk Pages

---

## 5. Transaction Log Internals

### 5.1 Virtual Log Files (VLF)
Transaction Log File ถูกแบ่งโครงสร้างภายในออกเป็นส่วนย่อยเรียกว่า **Virtual Log Files (VLF)**
*   **High VLF Count**: เกิดจากการตั้งค่า Auto-growth ขนาดเล็กเกินไป ทำให้มี VLF จำนวนมาก (Fragmented Log)
*   **Impact**: ส่งผลให้ Database Startup, Restore, และ Replication ทำงานช้าลง
*   **Best Practice**: ควรจองขนาด Log File ล่วงหน้า (Pre-allocate) และกำหนด Auto-growth ในขนาดที่เหมาะสม (เช่น 4GB หรือ 8GB) เพื่อให้ได้ VLF ขนาดใหญ่และจำนวนน้อย

### 5.2 Ghost Cleanup Process

**Ghost Records** คือData Row ที่ถูก DELETE แล้วแต่ยังไม่ถูกลบออกจาก Page จริงๆ:

*   **ทำไมต้องมี Ghost?**: เพื่อเพิ่มประสิทธิภาพการ DELETE และรองรับ Row-level Locking / Snapshot Isolation
*   **Mechanism**: เมื่อ DELETE จะเปลี่ยน Bit ใน Row Header เป็น "Ghost" แทนการลบทันที
*   **Ghost Cleanup Task**: Background process ที่รันเป็นระยะเพื่อลบ Ghost Records ออกจาก Pages

```sql
-- ตรวจสอบจำนวน Ghost Records
SELECT 
    DB_NAME(database_id) AS [Database],
    SUM(ghost_record_count) AS [Ghost Records]
FROM sys.dm_db_index_physical_stats(NULL, NULL, NULL, NULL, 'SAMPLED')
GROUP BY database_id
ORDER BY [Ghost Records] DESC;
```

> [!WARNING]
> **Trace Flag 661** สามารถ Disable Ghost Cleanup ได้ แต่ **ไม่แนะนำ** เพราะจะทำให้:
> - Database files โตขึ้นเรื่อยๆ (Space ไม่ถูก Reclaim)
> - เกิด Page Splits มากขึ้น
> - Index Rebuild เป็นวิธีแก้ไขถ้าปิด Ghost Cleanup ไปแล้ว

---

### Exercise 3: Reconfiguring tempdb
1.  **Setup**: จำลอง Latch Contention (สร้าง Temp Table รัวๆ)
2.  **Monitor**: ใช้ `sys.dm_os_wait_stats` หา `PAGELATCH_*`
3.  **Fix**: เพิ่มไฟล์ TempDB ให้เท่ากับจำนวน CPU Core และสังเกตผลลัพธ์

---

## 6. Lab: Database Structures

**[ไปยังคำแนะนำแล็บ](Labs/README.md)**

ในแล็บนี้ คุณจะวิเคราะห์จำนวน VLF, กำหนดค่า TempDB files และทำความเข้าใจพฤติกรรม Page Split

---

## 7. Review Quiz (Knowledge Check)

<details>
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

## 8. 🆕 Modernization Notes: SQL Server 2019 → 2025 (อัปเดตตาม Microsoft Learn)

### 8.1 TempDB บน SQL Server 2025
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
