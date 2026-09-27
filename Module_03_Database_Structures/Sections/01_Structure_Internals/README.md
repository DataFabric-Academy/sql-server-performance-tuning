[⬅ Module 3_](../../README.md) | Section 1/4 | ➡ ถัดไป: [Data File Internals](../02_Data_File_Internals/README.md)

## Database Structure Internals (Lesson 1)

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

---

[⬅ ก่อนหน้า](../../README.md) | [Module 3_ README](../../README.md) | ➡ ถัดไป: [Data File Internals](../02_Data_File_Internals/README.md) | [🧪 Labs](../../Labs/README.md)
