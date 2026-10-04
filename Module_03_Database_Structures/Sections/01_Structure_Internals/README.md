[⬅ Module 03](../../README.md) | Section 1/4 | ➡ ถัดไป: [02 Data File Internals](../02_Data_File_Internals/README.md)

# 3.1 Structure Internals — Page, Extent และแผนที่การจัดสรรพื้นที่ (Allocation Maps)

> *"SQL Server ไม่เคยอ่าน 'แถว' หรือ 'ตาราง' จากดิสก์ — มันอ่านทีละ Page 8 KB เท่านั้น ใครเห็นโลกในหน่วย Page คนนั้นอ่าน Execution Plan และ Wait Stats ได้ลึกกว่าคนอื่นหนึ่งชั้น"*

> **ต้องรู้มาก่อน**: [Page (8 KB)](../../../Glossary.md), [Buffer Pool](../../../Glossary.md), [Fragmentation](../../../Glossary.md), [DMV / DMF](../../../Glossary.md) — เส้นทางอ่าน page ของ Buffer Manager / Page Manager จาก Module 1 (Storage Engine Layer) และค่า Logical vs Physical Read จาก Module 2 (Section 2.1)
> **Permission ที่ต้องมี**: อ่าน DMV ระดับ database ใช้ `VIEW DATABASE STATE`; บล็อก `DBCC PAGE` / `DBCC TRACEON(3604)` ต้องเป็น `sysadmin` **และใช้กับ VM ทดสอบเท่านั้น** (DBCC PAGE เป็นคำสั่ง undocumented — ใช้แบบอ่านอย่างเดียวเสมอ)

---

## ทำไม Section นี้จึงต้องมาก่อนในโมดูล Database Structures

Module 2 จบลงที่คำถามว่า "I/O วัดกันอย่างไร" — โมดูลนี้จะลงไปอีกชั้น: **ข้อมูลถูกวางอยู่บนดิสก์อย่างไร และรูปแบบการวางนั้นตัดสินความเร็วของ query อย่างไร**

ทุกครั้งที่คุณเห็น logical reads = 3,832 ใน execution plan นั่นคือจำนวน **Page** ที่ query ต้องแตะ — ถ้าลงไปดูในไฟล์จริง แต่ละ page หนึ่งหน้าคือ 8 KB ของไบต์จริง มีหัวจดหมาย (Page Header) มีสารบัญท้ายหน้า (Slot Array) และมี "แผนที่" ชุดหนึ่งคอยบอกว่า page ไหนของใคร ว่างหรือเต็ม การจูน performance ระดับ storage คือการจัดการให้ **query ที่ต้องการข้อมูลเดียวกัน แตะ page น้อยลง และ page ที่แตะต่อเนื่องกันมากขึ้น**

เส้นทางของ Section:

1. **ลำดับชั้นการจัดเก็บ** — Filegroup → Data File → Extent → Page (โครงทั้งโมดูลแขวนอยู่บนนี้)
2. **กายวิภาคของ Page หนึ่งหน้า** — Header / Data / Slot Array / Page Types
3. **Allocation Maps** — PFS, GAM, SGAM, IAM แผนที่ 4 ใบที่ engine ใช้หาที่วางของ
4. **Mixed vs Uniform Extent** — พฤติกรรมจริงบน SQL Server 2025 (ทดสอบให้เห็นต่อหน้า)
5. **Row-Overflow และ LOB** — เมื่อแถวใหญ่กว่าหนึ่ง page ข้อมูลไปอยู่ที่ไหน
6. **อ่าน page จริงด้วย DBCC PAGE** — เปิดฝาเครื่องดูไบต์จริง

> **หมายเหตุสภาพแวดล้อม:** ตัวเลข Expected ทั้งหมดใน section นี้รันจริงบน VM หลักสูตร (SQL Server 2025 RTM-GDR 17.0.1135.8, ฐานข้อมูล `AdventureWorks`, 2026-10-02) — หาก VM ของคุณใช้ชื่อ `AdventureWorks2022`/`AdventureWorks2025` ให้แก้ชื่อในคำสั่ง `USE` และตัวเลขบางค่า (จำนวน page, ObjectId) จะต่างเล็กน้อยตามข้อมูลจริงของ VM นั้น

---

## 1. ลำดับชั้นการจัดเก็บ — Filegroup → Data File → Extent → Page

```
Database (AdventureWorks)
│
├── Filegroup: PRIMARY  ← หน่วยบริหารจัดการ (Admin Unit)
│   ├── Data File 1: AdventureWorks.mdf  (264 MB)  ← ไฟล์หลัก มีได้ไฟล์เดียวต่อ database
│   └── Data File 2: AdventureWorks2.ndf (ตัวเลือก — เพิ่มได้หลายไฟล์)
│         │
│         └── ภายในไฟล์แบ่งเป็น Extent ต่อเนื่องกัน
│               │
│               ├── Extent 0   (64 KB = 8 × 8 KB pages)
│               ├── Extent 8   (page 8–15)
│               ├── Extent 16  (page 16–23)
│               └── ...        (ทุก 8 pages = 1 extent, เริ่มที่ page_id หารด้วย 8 ลงตัว)
│
└── File: AdventureWorks_log.ldf  (136 MB)  ← โครงสร้างคนละโลก (Section 3.3)
```

| หน่วย | ขนาด | บทบาท | เครื่องมือสังเกต |
|:------|:-----|:-------|:----------------|
| **Page** | **8 KB** (8,192 bytes) | หน่วย I/O และจัดเก็บเล็กที่สุด — อ่าน/เขียนทั้งหน้าเสมอ | `sys.dm_db_database_page_allocations`, DBCC PAGE |
| **Extent** | 64 KB (8 pages ต่อเนื่อง) | หน่วย **จัดสรรพื้นที่** (allocation) — engine ให้พื้นที่เป็นก้อน extent | read-ahead อ่านทีละ extent (Module 2) |
| **Data File** | ตาม design | ที่ตั้งจริงของ extents; `.mdf` หลัก 1 ไฟล์ + `.ndf` เสริมได้ | `sys.database_files`, `sys.master_files` |
| **Filegroup** | — | หน่วยบริหาร: สั่ง "ตารางนี้อยู่ filegroup ไหน" แล้ว engine กระจายลงไฟล์ในกลุ่มด้วย proportional fill (Section 3.2) | `sys.filegroups` |

สิ่งที่ต้องจำเป็นข้อ 1 ของโมดูลนี้: **SQL Server ให้พื้นที่เป็น Extent แต่เขียน/อ่านเป็น Page** — ตารางที่มีแถวเดียวก็กินที่อย่างน้อย 1 page และมักถูกจองไว้ใน extent ที่แชร์กับคนอื่น (จะพิสูจน์ในหัวข้อ 4)

### 1.1 ตารางหนึ่งตารางมี "โครง" กี่ชั้น — Partition → Allocation Unit → Pages

ในระดับ catalog แต่ละตาราง (หรือ index) ประกอบจาก:

```
Table / Index
└── Partition (1 ชุดต่อ index; ถ้า partitioned จะมีหลายชุด — เรียน Module 6)
    └── Allocation Unit 3 ชนิด (มีเฉพาะที่ใช้จริง)
        ├── IN_ROW_DATA       ← แถวปกติ (leaf ของ clustered index / heap)
        ├── ROW_OVERFLOW_DATA ← ส่วนแถวที่ล้น 8,060 bytes (หัวข้อ 5)
        └── LOB_DATA          ← varchar(max)/varbinary(max)/xml ที่ใหญ่จริง
```

ตรวจดูของจริง — ตาราง `Person.Person` มี 3 indexes (แปลว่า 3 โครงแยกกัน) และแต่ละโครงมี allocation unit ของตัวเอง:

```sql
USE AdventureWorks;
GO
-- โครงของตาราง: แต่ละ index = partition หนึ่งชุด พร้อมจำนวนแถว
SELECT p.index_id, i.name AS index_name, p.partition_number, p.rows
FROM sys.partitions AS p
JOIN sys.indexes AS i ON i.object_id = p.object_id AND i.index_id = p.index_id
WHERE p.object_id = OBJECT_ID('Person.Person')
ORDER BY p.index_id;
GO
-- พื้นที่จริงต่อ allocation unit (used_pages = ที่ใช้จริง, total_pages = รวมที่จองไว้)
SELECT au.type_desc AS allocation_unit, au.used_pages, au.total_pages
FROM sys.system_internals_allocation_units AS au
JOIN sys.partitions AS p ON au.container_id = p.partition_id
WHERE p.object_id = OBJECT_ID('Person.Person');
GO
```

**Expected (รันจริง, 2026-10-02):**

| index_id | index_name | rows |
|:---------|:-----------|:-----|
| 1 | PK_Person_BusinessEntityID (clustered) | 19,972 |
| 2 | IX_Person_LastName_FirstName_MiddleName | 19,972 |
| 3 | AK_Person_rowguid | 19,972 |

| allocation_unit | used_pages | total_pages |
|:----------------|:-----------|:------------|
| IN_ROW_DATA | 3,847 | 3,893 |
| LOB_DATA | 2 | 9 |
| ROW_OVERFLOW_DATA | 2 | 9 |
| IN_ROW_DATA (NC index ที่ 2) | 110 | 141 |
| IN_ROW_DATA (NC index ที่ 3) | 67 | 81 |

อ่านผลแบบมืออาชีพ:

1. **total_pages > used_pages** ส่วนต่างคือ page ที่ถูกจองแต่ยังว่าง (ยังไม่คืนให้ database) — คู่ 9/9 ของ LOB/OVERFLOW คือ "1 IAM + extent จอยังไม่เต็ม"
2. `IN_ROW_DATA` แถวแรก (3,847 pages) คือตัว clustered index — แถว 19,972 แถวอยู่ใน ~3,800 pages คือเฉลี่ย **5 แถวต่อ page** เพราะ Person มีคอลัมน์กว้างหลายคอลัมน์
3. แต่ละ NC index เป็นโครงแยกที่ "คัดลอก" key + row locator — นี่คือราคาของการมี index หลายตัว (Module 6)

---

## 2. กายวิภาคของ Page หนึ่งหน้า — 8,192 Bytes แบ่งอย่างไร

```
        0                              8,192 bytes
        ┌─────────────────────────────┬──────────────────────┬─┬────────┐
        │  Page Header (96 bytes)     │  Data Rows ...       │▓│ Slot   │
        │  m_type, m_freeCnt,         │  (เรียงจากหัวหน้า     │▓│ Array  │
        │  m_prevPage/m_nextPage,     │   ลงท้ายหน้า)        │▓│ (ท้าย  │
        │  m_lsn, Metadata: ObjectId  │                      │▓│  หน้า) │
        └─────────────────────────────┴──────────────────────┴─┴────────┘
              96 bytes                  ข้อมูลโตจากหน้าไปหลัง   2 bytes/แถว
```

- **Page Header (96 bytes หัวหน้า)** — ทะเบียนของหน้า: ชนิด page, จำนวนไบต์ว่าง, page ก่อน/หน้า (linked list), LSN ของ log ล่าสุดที่แตะหน้านี้, ตารางเจ้าของ
- **Data Rows** — แถวเรียงจาก "หัวหน้าลงท้ายหน้า" — ข้อมูลเต็มพิ้นที่ว่างระหว่าง header กับ slot array
- **Slot Array (ท้ายหน้า)** — ตาราง 2 bytes ต่อแถว ชี้ offset ของแถวแต่ละแถว — **แถวใน page ไม่จำเป็นต้องเรียงลำดับทางกายภาพ** slot array คือสิ่งที่ทำให้ logical order กับ physical order แยกกันได้

Page ที่ใช้งานจริงมีหลาย "ชนิด" — ชนิดที่ต้องรู้จักในหลักสูตรนี้:

| m_type | ชื่อ | บทบาท |
|:-------|:-----|:------|
| 1 | **DATA_PAGE** | แถวข้อมูลจริง (leaf ของ clustered index หรือ heap) |
| 2 | **INDEX_PAGE** | ชั้นบนของ B-Tree (เส้นทาง navigation) |
| 3 / 4 | TEXT_MIX_PAGE / TEXT_TREE_PAGE | ข้อมูล LOB (แบบแชร์ / แบบใหญ่หนึ่งเดียว) |
| 7 | SORT_PAGE | พื้นที่ sort ชั่วคราว (index build, ฯลฯ) |
| 8 / 9 | **GAM / SGAM** | แผนที่จัดสรร extent (หัวข้อ 3) |
| 10 / 11 | IAM / **PFS** | แผนที่ "ของ object" / "ความเต็มของหน้า" (หัวข้อ 3) |
| 6 | Diff Map, 7 BCM/DCM | ติดตาม page ที่แก้ตั้งแต่ backup ล่าสุด (FULL/BULK_LOGGED) |

ส่วน Page พิเศษ 3 หน้าแรกของทุก data file ให้จำติดตัว:

```
File ทุกไฟล์:
  page 0 = File Header (ของไฟล์เอง)
  page 1 = PFS   (Page Free Space)
  page 2 = GAM   (Global Allocation Map)
  page 3 = SGAM  (Shared GAM)
  ... IAM ของแต่ละ object กระจายอยู่ทั่วไฟล์
File ที่ 1 เท่านั้น:
  page 9 = Boot Page (ข้อมูล database หนึ่ง — ดูได้ด้วย DBCC PAGE(..., 1, 9, 3))
```

---

## 3. Allocation Maps — แผนที่ 4 ใบที่ engine ใช้หาที่วางของ

เมื่อ query ต้องการแถวจากตารางที่มี 100,000 pages — engine ห้ามไล่อ่านทุกหน้าเพื่อ "หาของ" มันต้องมีดัชนีบอกตำแหน่ง นั่นคือหน้าที่ของ Allocation Maps 4 ชนิด:

| Map | หน้าที่ | ความละเอียด | ครอบคลุม 1 แผ่น | ตำแหน่งแผ่นแรก (file 1) |
|:----|:--------|:------------|:----------------|:------------------------|
| **PFS** (Page Free Space) | page ไหนว่าง/เต็มแค่ไหน (5 ระดับ: ว่าง, 1–50%, 51–80%, 81–95%, เต็ม) + เป็น IAM page หรือเป็นส่วน mixed extent หรือไม่ | 1 byte ต่อ 1 page | 8,088 pages (~64 MB) | **1:1** (m_type 11) |
| **GAM** (Global Allocation Map) | extent ไหน "ว่าง" (bit 1 = ว่าง, bit 0 = ถูกใช้) | 1 bit ต่อ 1 extent | 64,000 extents (~4 GB) | **1:2** (m_type 8) |
| **SGAM** (Shared GAM) | extent ไหนเป็น **mixed** และยังมี page ว่างให้เช่า (bit 1 = ยังว่าง) | 1 bit ต่อ 1 extent | 64,000 extents (~4 GB) | **1:3** (m_type 9) |
| **IAM** (Index Allocation Map) | object นี้ (per allocation unit ต่อ file) ใช้ extent/page ไหนบ้าง | แผนที่ต่อ object | ของ object นั้น ๆ | กระจาย (1 ใบต่อ ~4 GB ต่อ file) |

อ่านเป็นภาษาพูด: **"PFS ดูความเต็มของหน้า, GAM ดู extent ว่าง, SGAM ดู extent ที่แชร์แล้วยังว่าง, IAM ดูว่า object นี้ได้ที่ไหนบ้าง"**

### 3.1 เปิดดูแผนที่จริงด้วย DBCC PAGE

```sql
DBCC TRACEON(3604);                     -- ส่งผลลัพธ์ DBCC ออกทาง client
GO
DBCC PAGE('AdventureWorks', 1, 1, 3);   -- PFS  → สังเกต m_type = 11
GO
DBCC PAGE('AdventureWorks', 1, 2, 3);   -- GAM  → สังเกต m_type = 8
GO
DBCC PAGE('AdventureWorks', 1, 3, 3);   -- SGAM → สังเกต m_type = 9
GO
DBCC TRACEOFF(3604);
GO
```

**Expected (สรุปจากรันจริง, 2026-10-02 — ดูรายงานในแท็บ Messages):**

```
-- PFS (1:1), m_type 11 — บรรทัดตัวอย่าง:
PFS: Page Alloc Status (1:0) - (1:3)     ALLOCATED 100_PCT_FULL
PFS: Page Alloc Status (1:8)             ALLOCATED   0_PCT_FULL   Mixed Ext
PFS: Page Alloc Status (1:10)            ALLOCATED   0_PCT_FULL   IAM Page  Mixed Ext

-- GAM (1:2), m_type 8 — บรรทัดตัวอย่าง:
GAM: Extent Alloc Status (1:0) - (1:28704)   ALLOCATED
GAM: Extent Alloc Status (1:28712) -         NOT ALLOCATED

-- SGAM (1:3), m_type 9 — บรรทัดตัวอย่าง:
SGAM: Extent Alloc Status (1:256) -          ALLOCATED   ← mixed extent ที่ยังมีหน้าว่าง
SGAM: Extent Alloc Status (1:264) - (1:392)  NOT ALLOCATED
```

ข้อสังเกตที่ต้องจับ:

1. **PFS พูดภาษา "หน้า"** — ระดับ % ความเต็ม + ธงพิเศษ (IAM Page / Mixed Ext) ทุก 8,088 หน้ามี PFS ใหม่หนึ่งแผ่น
2. **GAM พูดภาษา "extent"** — ช่วง ALLOCATED/NOT ALLOCATED อ่านเป็น "แถบว่าง" บนไฟล์ — ไฟล์ที่มีช่วง NOT ALLOCATED ยาว ๆ คือไฟล์ที่มีพื้นที่ว่างต่อเนื่อง (ดีต่อการโตแบบไม่แตกกระจาย)
3. SGAM เกือบว่างทั้งหน้า = แทบไม่มี mixed extent — ปกติมากบนระบบใหม่ (หัวข้อ 4)
4. แผนที่เหล่านี้อยู่ใน Buffer Pool เหมือน page อื่น — การแก้ไขแผนที่คือการแก้ไข page จริง เพราะฉะนั้น **allocation จำนวนมากพร้อมกัน = แย่ง latch บนหน้าเดียวกัน** — ต้นตอของ tempdb contention ที่จะเจาะใน Section 3.4

### 3.2 IAM — สมุดที่ดินของแต่ละ object

PFS/GAM/SGAM เป็น "แผนที่รวมของทั้งไฟล์" — แต่ query ต้องรู้ว่า **object นี้ใช้หน้าไหนบ้าง** โดยไม่ไล่อ่านแผนที่รวมทั้งไฟล์ IAM จึงเป็นสมุดรายชื่อที่ดินของ object หนึ่ง ๆ:

- 1 IAM ต่อ 1 allocation unit ต่อ 1 file — ครอบคลุม ~4 GB (ช่วงเดียวกับ GAM/SGAM หนึ่งแผ่น)
- object ที่กินข้าม 4 GB จะมี IAM หลายใบ — engine ผูกกันเป็น chain
- หน้าแรกที่ object อ่านเสมอคือ **IAM page** ก่อนลงไปถึง DATA_PAGE — ใน `sys.dm_db_database_page_allocations` ดูได้จากคอลัมน์ `is_iam_page = 1`

และ DMF ตัวเดียวกันนี้คือเครื่องมือ "สำรวจโครงตาราง" ที่ใช้ได้จริงบน 2025 (แทน `DBCC IND` ยุคเก่า):

```sql
USE AdventureWorks;
GO
-- สำมะโนประชากร page ของตารางหนึ่ง — แยกตามชนิด
SELECT page_type_desc, is_iam_page, COUNT(*) AS pages
FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('Person.Person'), 1, NULL, 'DETAILED')
WHERE is_allocated = 1
GROUP BY page_type_desc, is_iam_page
ORDER BY pages DESC;
GO
```

**Expected (รันจริง, 2026-10-02):**

| page_type_desc | is_iam_page | pages |
|:---------------|:------------|:------|
| DATA_PAGE | 0 | 3,832 |
| INDEX_PAGE | 0 | 10 |
| IAM_PAGE | 1 | 3 |
| TEXT_MIX_PAGE | 0 | 2 |

อ่านผล:

1. แถวข้อมูล 19,972 แถวอยู่ใน DATA_PAGE 3,832 หน้า + INDEX_PAGE 10 หน้า (ชั้นบนของ B-Tree — B-Tree ลึก 3 ชั้น)
2. IAM_PAGE 3 ใบ = 3 allocation units (IN_ROW, LOB, ROW_OVERFLOW ของ clustered index — ตารางนี้มี LOB และ overflow จองไว้)
3. จำนวน INDEX_PAGE น้อยเตี้ย ๆ แบบนี้คือสัญญาณว่า B-Tree แคบและสุขภาพดี (seek ผ่านชั้นบนได้เร็ว) — ถ้า INDEX_PAGE บวมใหญ่แปลว่า key กว้าง/แถวบางเกิน (Module 6)

> ⚠️ **เทคนิคที่ล้าสมัย:** `DBCC IND` และการดึง `allocated_page_page_id` จาก `sys.system_internals_allocation_units` จะ error `Invalid column name` บน SQL Server 2025 (คอลัมน์ถูกถอดออกแล้ว) — ใช้ `sys.dm_db_database_page_allocations` ตามที่แล็บ Module 03 แก้ไว้เป็นมาตรฐาน

---

## 4. Mixed vs Uniform Extent — ทฤษฎีคลาสสิก vs พฤติกรรมจริงบน 2025

### 4.1 นิยามก่อนใช้

| ชนิด | ความหมาย | ใครใช้ |
|:-----|:---------|:-------|
| **Uniform Extent** | ทั้ง 8 pages เป็นของ object เดียว | object ที่โตแล้ว (> 8 pages) — รูปแบบหลักของระบบใหม่ |
| **Mixed Extent** | extent หนึ่งถูกแบ่ง page ให้หลาย object (แชร์กัน) | page แรก ๆ ของ object เล็ก — ประหยัดพื้นที่ตอนตารางเพิ่งเกิด |

ทฤษฎีคลาสสิก (ก่อน 2016): object ใหม่เช่า page จาก mixed extent ผ่าน SGAM ไปเรื่อย ๆ จนครบ 8 pages ค่อย "ขึ้นบ้านใหม่" เป็น uniform extent

### 4.2 พฤติกรรมใหม่ที่ต้องรู้ — ตั้งแต่ SQL Server 2016

การจัดสรรแบบ uniform-only (พฤติกรรมเดิมของ Trace Flag 1118) กลายเป็น **ค่า default** — ตั้ง/ดูได้ต่อ database ที่ `sys.databases.is_mixed_page_allocation_on` (0 = uniform only ซึ่งเป็นค่า default ของ database ที่สร้างใหม่บน 2016+, 1 = ยอมให้ mixed แบบเดิม) ประโยชน์โดยตรงคือ **ลดการแย่ง SGAM** เพราะ allocation ไม่ต้องไปเสาะหา mixed extent ที่แชร์กันทั้งไฟล์

ทดสอบให้เห็นต่อหน้า — สร้างตารางใหม่ 1 แถว แล้วดูว่า page แรกวางตรงไหนของ extent:

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.ExtentLab2;
CREATE TABLE dbo.ExtentLab2
(
    Id  INT IDENTITY NOT NULL,
    Col CHAR(100)    NOT NULL DEFAULT 'x'
);
CREATE CLUSTERED INDEX CIX_ExtentLab2 ON dbo.ExtentLab2 (Id);
INSERT dbo.ExtentLab2 DEFAULT VALUES;   -- แถวแรกของตารางใหม่
GO
-- page แรกวาง "ตรงขอบ extent" (page_id % 8 = 0) หรือไม่?
SELECT allocated_page_page_id AS page_id,
       allocated_page_page_id % 8 AS offset_in_extent,
       is_mixed_page_allocation,
       page_type_desc
FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('dbo.ExtentLab2'), 1, NULL, 'DETAILED')
WHERE is_allocated = 1;
GO
DROP TABLE dbo.ExtentLab2;   -- ล้างของทดสอบ
GO
```

**Expected (รันจริง, 2026-10-02):**

| page_id | offset_in_extent | is_mixed_page_allocation | page_type_desc |
|:--------|:-----------------|:-------------------------|:---------------|
| 6601 | 1 | 1 | DATA_PAGE |
| 28712 | 0 | 0 | IAM_PAGE |

อ่านผล — ความจริงมีสองชั้น:

1. IAM_PAGE วางชิดขอบ extent (offset 0) เสมอ — IAM มาจากการจัดสรรแบบ extent เต็ม
2. DATA_PAGE แรกอาจถูกวางแบบไม่ชิดขอบ (offset 1) พร้อมธง mixed — แม้ database ตั้ง `is_mixed_page_allocation_on = 0` ก็ตาม: engine ยังเผื่อกลไก "หน้าแรกใน extent ที่แชร์" ไว้ให้ object จิ๋ว สรุปใช้งานได้ว่า **object เล็กกินพื้นที่จริงไม่ถึง extent แต่พอ object โตเกิน 8 pages การจัดสรรจะเป็น uniform ล้วนบนระบบใหม่**

### 4.3 ตารางโตแล้วกระจายยังไง — วัด extent ของจริง

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.ExtentLab;
CREATE TABLE dbo.ExtentLab
(
    Id  INT IDENTITY NOT NULL,
    Col CHAR(100)    NOT NULL DEFAULT 'x'
);
CREATE CLUSTERED INDEX CIX_ExtentLab ON dbo.ExtentLab (Id);
INSERT dbo.ExtentLab DEFAULT VALUES;   -- แถวแรก
GO
SELECT COUNT(*)                       AS pages,
       COUNT(DISTINCT extent_page_id) AS extents
FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('dbo.ExtentLab'), 1, NULL, 'DETAILED')
WHERE is_allocated = 1 AND page_type_desc = 'DATA_PAGE';
GO
DECLARE @i INT = 0;
WHILE @i < 5000
BEGIN
    INSERT dbo.ExtentLab DEFAULT VALUES;
    SET @i += 1;
END
GO
SELECT COUNT(*)                       AS pages,
       COUNT(DISTINCT extent_page_id) AS extents
FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('dbo.ExtentLab'), 1, NULL, 'DETAILED')
WHERE is_allocated = 1 AND page_type_desc = 'DATA_PAGE';
GO
DROP TABLE dbo.ExtentLab;   -- ล้างของทดสอบ
GO
```

**Expected (รันจริง, 2026-10-02):**

| ขั้น | pages | extents |
|:-----|:------|:--------|
| หลัง insert 1 แถว | 1 | 1 |
| หลัง insert รวม 5,001 แถว | 80 | 11 |

5,001 แถว (แถวละ ~111 bytes) กิน 80 pages ≈ 10 extents เต็ม แต่นับได้ 11 extents — เพราะ page แรกยังค้างอยู่ใน extent ที่แชร์กับคนอื่น อีก 79 pages มาจาก uniform extent 10 ก้อน — **การจัดสรรจากจุดนี้ต่อไปจะเป็น "ก้อนทั้งก้อน 64 KB" เสมอ** ซึ่งอธิบายร่วมกับ Module 2 ว่าทำไม read-ahead จึงอ่านทีละ extent ได้อย่างต่อเนื่องเมื่อตารางโต

> **จุดเชื่อมโยง:** รูปแบบ key ของ clustered index กำหนดว่า pages เหล่านี้จะ "เต็มแน่น" หรือ "บวมแตกกระจาย" — GUID สุ่มทำให้ insert แทรกกลาง B-Tree → page split → space_used ต่ำ ผลจริงเทียบกันใน [Labs Exercise 2](../../Labs/README.md) (BadKeyTable frag 98.5% เทียบ GoodKeyTable 1.2%) และเจาะลึกโครง B-Tree ใน Module 6

---

## 5. Row-Overflow และ LOB — เมื่อแถวใหญ่กว่าหนึ่ง page

Page เก็บแถวได้สูงสุด ~**8,060 bytes** (8,192 − header − slot array − ของสำรอง) ถ้านิยามคอลัมน์รวมกันยาวเกินนั้น engine แก้ด้วยสองกลไก ต่างกันที่ "ชนิดคอลัมน์":

| กลไก | ใช้กับ | กลไกทำงาน | ราคาที่ต้องจ่าย |
|:-----|:-------|:----------|:----------------|
| **ROW_OVERFLOW_DATA** | คอลัมน์ variable-length ธรรมดา (`varchar(n)`, `nvarchar(n)`) ที่รวมกันเกิน 8,060 | คอลัมน์ "ตัวท้าย ๆ" ถูกย้ายออกไป page อื่น (แต่หลักการเดิม: ย้ายเฉพาะตอนแถวจริงเกิน ไม่ใช่ตามนิยาม) | อ่านแถวเดียวอาจแตะ ≥ 2 pages — logical read เพิ่ม, PAGEIOLATCH เพิ่ม |
| **LOB_DATA** | `varchar(max)`, `nvarchar(max)`, `varbinary(max)`, `xml`, `text/image` (legacy) | ค่าถูกเก็บใน TEXT_MIX/TEXT_TREE pages โดยแถวเก็บแค่ root pointer (~24 bytes) ถ้าค่าเล็ก (< ~8 KB) อาจอยู่ในแถวหรือ root เลย | อ่านค่า LOB = กระโดดไปอีก chain — scan ที่ไม่ได้ใช้ LOB ไม่โดนราคานี้ (ข้อดีของ `max` ที่เก็บ out-of-row) |

ทดสอบให้เห็นทั้งสาม allocation unit ในตารางเดียว:

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.RowLayoutLab;
CREATE TABLE dbo.RowLayoutLab
(
    Id       INT IDENTITY NOT NULL PRIMARY KEY,
    HotCol   CHAR(4000)    NOT NULL DEFAULT 'H',   -- ติดอยู่ในแถว (in-row)
    ColdCol  VARCHAR(5000) NOT NULL,               -- ถ้าแถวรวมเกิน 8,060 → โดนย้าย
    BlobCol  VARCHAR(MAX)  NOT NULL                -- ใหญ่พอ → LOB pages
);
-- ระวัง: REPLICATE กับ input ที่ไม่ใช่ varchar(max) จะโดนตัดที่ 8,000 bytes
INSERT dbo.RowLayoutLab (ColdCol, BlobCol)
VALUES (REPLICATE('c', 4500), REPLICATE(CAST('B' AS VARCHAR(MAX)), 20000));
GO
-- แถวเดียวกินที่อยู่ allocation unit ไหนบ้าง
SELECT au.type_desc AS allocation_unit, au.used_pages, au.total_pages
FROM sys.partitions AS p
JOIN sys.system_internals_allocation_units AS au ON au.container_id = p.partition_id
WHERE p.object_id = OBJECT_ID('dbo.RowLayoutLab');
GO
-- ประเภท page ที่ถูกใช้จริง
SELECT page_type_desc, COUNT(*) AS pages
FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('dbo.RowLayoutLab'), 1, NULL, 'DETAILED')
WHERE is_allocated = 1
GROUP BY page_type_desc
ORDER BY pages DESC;
GO
DROP TABLE dbo.RowLayoutLab;   -- ล้างของทดสอบ
GO
```

**Expected (รันจริง, 2026-10-02):**

| allocation_unit | used_pages | total_pages |
|:----------------|:-----------|:------------|
| IN_ROW_DATA | 2 | 9 |
| LOB_DATA | 4 | 9 |
| ROW_OVERFLOW_DATA | 2 | 9 |

| page_type_desc | pages |
|:---------------|:------|
| TEXT_MIX_PAGE | 4 |
| IAM_PAGE | 3 |
| DATA_PAGE | 1 |

อ่านผล — **แถวเดียว อยู่ 3 ที่**:

1. `HotCol` (4,000 bytes) + หัวแถวอยู่ใน DATA_PAGE เดียว (IN_ROW_DATA)
2. `ColdCol` (4,500 bytes) ทำให้แถวรวมเกิน 8,060 → ถูกย้ายไป page ใน ROW_OVERFLOW_DATA
3. `BlobCol` (20,000 bytes) แตกเป็น TEXT_MIX_PAGE หลายหน้าใน LOB_DATA
4. แต่ละ allocation unit มี IAM ของตัวเอง (IAM_PAGE 3 ใบ) — โครง catalog ยึดหลัก "ทุก container มีสมุดที่ดิน"

ข้อสรุปเชิง tuning: คอลัมน์กว้างที่ query ต้องอ่านทุกแถว (เช่นใส่ `SELECT *`) จะแตะ page มากขึ้น 2–4 เท่า — ออกแบบให้คอลัมน์ใหญ่แยกตาราง/ใช้ projection เฉพาะที่จำเป็น และเชื่อมกับ Module 7 (ประเมิน logical reads ต่อ plan)

---

## 6. อ่าน Page จริงด้วย DBCC PAGE — เปิดฝาเครื่อง

เครื่องมือราชการของ storage internals คือ `DBCC PAGE(db, file, page, print_option)` — ทุกวิศวกร tuning ควรอ่าน Page Header ออกเหมือนอ่าน label ยา:

```sql
DBCC TRACEON(3604);   -- ส่งผลลัพธ์ DBCC ออกทาง client (ต้อง sysadmin)
GO
DBCC PAGE('AdventureWorks', 1, 736, 3);   -- (database, file 1, page 736, option 3)
GO
DBCC TRACEOFF(3604);
GO
```

> หมายเลข `1:736` อ่านว่า "ไฟล์ที่ 1 หน้าที่ 736" — ได้มาจาก `sys.dm_db_database_page_allocations(... page_type_desc = 'DATA_PAGE' ...)` เรียงตาม page_id แถวแรก (วิธีเดียวกับ [Labs Exercise 1](../../Labs/README.md)) · print_option: 0 = header เท่านั้น, 1–2 = ทั้งหน้าแบบ hex, 3 = header + รายละเอียดแถว

**Expected (สรุปแถวสำคัญจากรันจริง, 2026-10-02):**

```
PAGE HEADER: Page @0x... m_pageId (1:736)
PAGE HEADER: ... m_type 1                    ← Data page
PAGE HEADER: ... m_level 0                   ← ชั้นล่างสุดของ B-Tree (leaf)
PAGE HEADER: ... Metadata: ObjectId 898102240   ← Person.Person
PAGE HEADER: ... Metadata: IndexId 1         ← clustered index
PAGE HEADER: ... m_prevPage (1:1279)         ← หน้าก่อนหน้า (leaf เป็น doubly-linked list)
PAGE HEADER: ... m_nextPage (1:737)
PAGE HEADER: ... m_slotCnt 5                 ← หน้านี้มี 5 แถว
PAGE HEADER: ... m_freeCnt 1162              ← เหลือว่าง 1,162 bytes
PAGE HEADER: ... m_lsn (48:119416:31)        ← log ล่าสุดที่แตะหน้านี้
```

ตีความ Page Header เป็นข้อมูล performance:

| ฟิลด์ | อ่านได้ว่าอะไร | ใช้ตรวจอะไร |
|:------|:---------------|:-------------|
| `m_type` | ชนิดหน้า (1 = data) | ยืนยันว่า dump ถูกหน้า |
| `m_slotCnt` | จำนวนแถวบนหน้า | หน้าที่แถวน้อยผิดปกติ = ผลจาก page split / shrink |
| `m_freeCnt` | ไบต์ว่างเหลือ | หน้าแน่นหรือโหว่ง — ประกอบ `avg_page_space_used_in_percent` (Module 6) |
| `m_prevPage`/`m_nextPage` | linked list ของ leaf | **หากหน้าถัดไปมีหมายเลขน้อยกว่าหน้าปัจจุบัน = physical order สวน logical order = fragmentation** (ในแล็บ: 1:1279 ↔ 1:737 คือร่องรอยการกระจายของ B-Tree จริง) |
| `m_lsn` | log record ล่าสุดของหน้า | โยงหน้ากับ transaction log (Section 3.3) — หัวใจของ WAL |

---

## 7. เชื่อมโยงไปข้างหน้า — โครงหน้าหนึ่งใบ ใช้ทั้งหลักสูตร

| โมดูล | ใช้อะไรจาก section นี้ |
|:------|:------------------------|
| Module 4 (Memory) | "page ที่อ่านมาพักที่ไหน" — Buffer Pool เก็บ Page 8 KB จำนวนมาก พร้อม metadata เดียวกับ Page Header |
| Module 5 (Concurrency) | Latch คุมการเข้าถึง page (รวมแผนที่ allocation) — PAGELATCH/PAGEIOLATCH ที่เราจะเจาะ |
| Module 6 (Statistics & Indexes) | Fragmentation = ความสัมพันธ์ logical↔physical order ที่อ่านจาก `m_prevPage/m_nextPage`, space_used ต่อ page |
| Module 7 (Query Execution) | logical reads ใน plan = จำนวน page ที่ query แตะ — ตัวเลขที่ฝั่งนี้ "โกหกไม่ได้" |
| Module 9 (Extended Events) | event `page_split` จับการแตกหน้าแบบ real-time (แล็บ Exercise 2) |
| Section ถัดไป | 3.2 นำ extent/proportional fill ไปออกแบบไฟล์, 3.3 log แยกโลก, 3.4 tempdb ที่ allocation maps ต้องทำงานหนักที่สุด |

---

## สรุป Section 3.1

1. โครงจัดเก็บ: **Filegroup → Data File → Extent (64 KB) → Page (8 KB)** — SQL ให้พื้นที่เป็น extent, อ่าน/เขียนเป็น page
2. Page หนึ่งหน้า = header (96 bytes) + แถว + slot array ท้ายหน้า — `m_type` บอกชนิด, `m_freeCnt`/`m_slotCnt` บอกความแน่น, `m_prevPage/m_nextPage` บอกความเรียง
3. Allocation Maps 4 ใบ: **PFS** (ความเต็มของหน้า, 8,088 หน้า/แผ่น), **GAM** (extent ว่าง, ~4 GB/แผ่น), **SGAM** (mixed extent ที่ยังว่าง), **IAM** (ที่ดินของ object)
4. ตั้งแต่ 2016 uniform-extent allocation เป็น default (`is_mixed_page_allocation_on = 0`) — mixed extent เหลือบทบาทเฉพาะ page แรก ๆ ของ object; ทดสอบจริงบน 2025 ยังพบ page แรกวางแบบไม่ชิดขอบได้
5. แถวเกิน 8,060 bytes ถูกแยกไป **ROW_OVERFLOW_DATA** (คอลัมน์ variable-length) หรือ **LOB_DATA** (`max` types) — แถวเดียวอยู่ 3 allocation units ได้
6. เครื่องมืออ่านโครง: `sys.dm_db_database_page_allocations` (แทน DBCC IND), `sys.system_internals_allocation_units`, และ `DBCC PAGE` สำหรับดูไบต์จริง

### ตรวจความเข้าใจ

1. `1:736` อ่านว่าอย่างไร และ Page Header ค่าใดบอกว่าหน้านี้เป็น Data page, มีกี่แถว, เหลือที่ว่างเท่าไร?
2. PFS, GAM, SGAM, IAM ต่างกันที่ "ความละเอียด" และ "เจ้าของแผนที่" อย่างไร — แผนที่ใดครอบคลุม 8,088 หน้า และแผนที่ใดเป็นของ object หนึ่งเดียว?
3. ทดสอบในหัวข้อ 4.2 พบ DATA_PAGE แรกของตารางใหม่อยู่ offset 1 ของ extent (ไม่ชิดขอบ) ทั้งที่ database ตั้ง uniform-only — อธิบายว่าเหตุใดข้อสรุป "mixed extent เลิกใช้แล้ว" จึงยังไม่ถูกเสมอไป
4. ตารางมี `HotCol CHAR(4000)`, `ColdCol VARCHAR(5000)` (เก็บ 4,500 bytes), `BlobCol VARCHAR(MAX)` (เก็บ 20,000 bytes) — ระบุว่าแต่ละคอลัมน์อยู่ allocation unit ใด และเมื่อ `SELECT *` ต้องแตะ page อย่างน้อยกี่หน้าต่อแถว
5. เพราะเหตุใด `sys.system_internals_allocation_units` จึงไม่ใช่ที่พึ่งหา first page อีกต่อไปบน SQL Server 2025 และควรใช้ DMF ใดแทน?
6. จาก DBCC PAGE: `m_prevPage (1:1279)` ของหน้า `1:736` — ถ้าคุณไล่ leaf ทั้ง index แล้วพบลำดับหน้า "กระโดดไปมา" อย่างนี้ตลอด จะสรุปสถานะ physical layout ว่าอย่างไร และเกี่ยวโยงกับค่าใดใน `sys.dm_db_index_physical_stats`?

**➡ ถัดไป:** [3.2 Data File Internals — ไฟล์ข้อมูล, Proportional Fill, IFI และ Autogrowth](../02_Data_File_Internals/README.md)

---

[⬅ Module 03](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [02 Data File Internals](../02_Data_File_Internals/README.md)
