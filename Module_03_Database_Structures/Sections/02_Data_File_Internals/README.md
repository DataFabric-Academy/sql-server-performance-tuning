[⬅ Module 03](../../README.md) | [3.1 Structure Internals](../01_Structure_Internals/README.md) | Section 2/4 | ➡ ถัดไป: [03 Transaction Log Internals](../03_Transaction_Log_Internals/README.md)

# 3.2 Data File Internals — ไฟล์ข้อมูล, Proportional Fill, IFI และ Autogrowth

> *"การตั้งค่าไฟล์ที่ดีไม่ทำให้ query เร็วขึ้นเด่นชัดในวันเดียว แต่การตั้งผิดจะทำให้ทุกอย่างช้าลงเป็นระลอก ๆ — ตอน grow, ตอน restore, ตอน tempdb แย่งกัน และตอนที่ไฟล์โตไม่เท่ากัน"*

> **ต้องรู้มาก่อน**: [Page (8 KB)](../../../Glossary.md), Extent และ Allocation Maps จาก [Section 3.1](../01_Structure_Internals/README.md), [DMV / DMF](../../../Glossary.md), ค่า IOPS/Throughput/Latency จาก [Module 2 — I/O Core Concepts](../../../Module_02_IO/Sections/01_IO_Core_Concepts/README.md)
> **Permission ที่ต้องมี**: อ่าน DMV ระดับ server ใช้ `VIEW SERVER STATE`; บล็อก `DBCC SHOWFILESTATS` ต้องเป็น `sysadmin`; บล็อก `ALTER DATABASE ... MODIFY FILE` **แสดงไว้เป็นตัวอย่างเท่านั้น — ห้ามรันบน production และควรรันบน VM ทดสอบของตนเอง**

---

## ทำไม Section นี้จึงอยู่ตรงนี้

Section 3.1 เราเห็นแล้วว่าข้อมูลอยู่ในรูป Page/Extent ภายใน Data File — คำถามชั้นถัดไปของผู้ดูแลระบบคือ **"ไฟล์ควรมีกี่ไฟล์ โตอย่างไร วางที่ไหน และเมื่อไรที่การตั้งค่าไฟล์กลายเป็นคอขวด"** ทั้งหมดนี้ตัดสินกันที่สามกลไก: **Proportional Fill** (กระจายงานระหว่างไฟล์), **Instant File Initialization** (ตัดราคาการเปิดพื้นที่ใหม่) และ **Autogrowth** (เครื่องยางยามฉุกเฉิน ไม่ใช่กลยุทธ์เติบโต)

เส้นทางของ Section:

1. **ทะเบียนไฟล์ของ database** — อ่าน `sys.database_files` และตัดสินคุณภาพการตั้งค่า
2. **Proportional Fill** — กฎเหล็ก "ไฟล์เท่ากัน" พิสูจน์ด้วยการทดลองจริง
3. **Instant File Initialization (IFI)** — ตัดราคา zero-filling และข้อแลกเปลี่ยนด้านความปลอดภัย
4. **Autogrowth ที่ถูกต้อง** — MB ไม่ใช่ %, ขนาดที่เหมาะสม, เหตุการณ์ grow ที่มองอย่างไร
5. **พื้นที่ว่างและ latency ต่อไฟล์** — `DBCC SHOWFILESTATS` + `sys.dm_io_virtual_file_stats`
6. **การจัดวาง storage และข้อห้าม (Auto Shrink)**

> **หมายเหตุสภาพแวดล้อม:** Expected รันจริงบน VM หลักสูตร (SQL Server 2025 RTM-GDR 17.0.1135.8, `AdventureWorks`, 2026-10-02) — หาก VM ของคุณใช้ชื่อ `AdventureWorks2025` ให้แก้ในคำสั่ง `USE`

---

## 1. ทะเบียนไฟล์ของ Database — จุดเริ่มของทุกการตรวจ

ทุก database มี **log file อย่างน้อย 1 ไฟล์** (โครงต่างจาก data โดยสิ้นเชิง — Section 3.3) และ **data file อย่างน้อย 1 ไฟล์**: `.mdf` (หลัก, มีได้ไฟล์เดียว) + `.ndf` (เสริม, ได้หลายไฟล์ — เก็บได้ทั้งใน filegroup PRIMARY และ filegroup ที่สร้างเพิ่ม)

```sql
USE AdventureWorks;
GO
-- ทะเบียนไฟล์ + ตัดสินคุณภาพการตั้งค่า growth ตั้งแต่มองแรก
SELECT file_id, name, type_desc,
       CAST(size * 8.0 / 1024 AS DECIMAL(10,1)) AS size_mb,
       CASE WHEN is_percent_growth = 1
            THEN CAST(growth AS VARCHAR(10)) + ' %  (แก้: ใช้ MB คงที่แทน)'
            ELSE CAST(CAST(growth * 8.0 / 1024 AS DECIMAL(10,1)) AS VARCHAR(10)) + ' MB'
       END AS growth_setting,
       CASE max_size WHEN -1 THEN 'unlimited'
            ELSE CAST(CAST(max_size AS BIGINT) * 8 / 1024 AS VARCHAR(12)) + ' MB'
       END AS max_size
FROM sys.database_files
ORDER BY type_desc, file_id;
GO
```

**Expected (รันจริง, 2026-10-02):**

| file_id | name | type_desc | size_mb | growth_setting | max_size |
|:--------|:-----|:----------|:--------|:---------------|:---------|
| 1 | AdventureWorks | ROWS | 264.0 | 64 MB | unlimited |
| 2 | AdventureWorks_log | LOG | 136.0 | 64 MB | 2097152 MB |

ตัวเลขที่ต้องอ่านเป็น:

| คอลัมน์ | หน่วยจริงใน DMV | แปลง |
|:--------|:----------------|:-----|
| `size` | จำนวน **page** (8 KB) | × 8 ÷ 1024 = MB |
| `growth` | **page** เมื่อ `is_percent_growth = 0` (เช่น 8192 = 64 MB) / **%** เมื่อ = 1 | × 8 ÷ 1024 = MB |
| `max_size` | page; `-1` = unlimited, `268435456` = เพดาน default 2 TB | ระวัง: `max_size * 8` บนค่าเพดานจะ **overflow int** — ใช้ `CAST(... AS BIGINT)` เสมอ |

> [!IMPORTANT]
> กับดักความเขียนสคริปต์ยอดฮิต: `size * 8 / 1024` บน int พังกับไฟล์ใหญ่/ค่า max 2 TB (arithmetic overflow) — ทุกสคริปต์ตรวจไฟล์ในหลักสูตรนี้ใช้ `8.0` หรือ `CAST AS BIGINT` ให้คุณ copy แล้วเจ็บตัวน้อยที่สุด

และเพื่อมองทั้ง instance ในภาพเดียว (ตรวจทุก database ว่าใครยังใช้ PERCENT growth):

```sql
-- ตรวจทุก database ใน instance ในครั้งเดียว (สไตล์ Glenn Berry)
SELECT DB_NAME(mf.database_id) AS database_name, mf.name AS logical_name, mf.type_desc,
       CAST(mf.size * 8.0 / 1024 AS DECIMAL(10,1)) AS size_mb,
       CASE WHEN mf.is_percent_growth = 1
            THEN CAST(mf.growth AS VARCHAR(20)) + ' %'
            ELSE CAST(CAST(mf.growth * 8.0 / 1024 AS DECIMAL(10,1)) AS VARCHAR(20)) + ' MB'
       END AS growth_setting
FROM sys.master_files AS mf
WHERE mf.database_id > 4          -- ข้าม system databases ถ้าต้องการเฉพาะ user DBs
ORDER BY database_name, mf.type_desc;
GO
```

**Expected (รันจริง, 2026-10-02):** บน VM หลักสูตรได้ 2 แถวของ AdventureWorks (ROWS 264 MB, LOG 136 MB ทั้งคู่ growth 64 MB) — เกณฑ์ตัดสิน: **แถวไหนโชว์ `%` = จุดที่ต้องแก้**, growth < 64 MB คือจุดเสี่ยง VLF/latency (Section 3.3), ไฟล์ที่ max_size ตั้งแคบเกิน = ระเบิดวันหนึ่งเมื่อเต็ม

### 1.1 Database ใหม่ได้ "โครงไฟล์" จากใคร — model database

CREATE DATABASE ทุกครั้ง **คัดลอกไฟล์จาก `model`** มาเป็นจุดตั้งต้น — ขนาดไฟล์, growth, recovery model และ option หลายตัวของ database ใหม่จึง "ได้มาจาก model" โดยอัตโนมัติ:

```sql
SELECT name, type_desc,
       CAST(size * 8.0 / 1024 AS DECIMAL(10,1)) AS size_mb,
       CAST(growth * 8.0 / 1024 AS DECIMAL(10,1)) AS growth_mb
FROM sys.master_files
WHERE database_id = DB_ID('model');
GO
```

**Expected (รันจริง, 2026-10-02):**

| name | type_desc | size_mb | growth_mb |
|:-----|:----------|:--------|:----------|
| modeldev | ROWS | 8.0 | 64.0 |
| modellog | LOG | 8.0 | 64.0 |

ในทางปฏิบัติ: องค์กรที่มี database ใหม่เกิดบ่อย ควรปรับขนาด/growth ของ `model` ให้สอดคล้องกับมาตรฐานของตัวเอง (เช่น data เริ่ม 1024 MB / growth 512 MB) — แต่ระวังผลข้างเคียง: model ที่ใหญ่เกินจะทำให้ CREATE DATABASE, tempdb (ซึ่งสร้างใหม่ตอน restart จาก model ในรุ่นเก่า) และการ restore ระบบ ช้าลงโดยไม่ตั้งใจ

---

## 2. Proportional Fill — เหตุผลเบื้องหลังกฎ "ไฟล์ทุกไฟล์ต้องเท่ากัน"

### 2.1 กลไก

เมื่อ database ต้องการ page ใหม่ใน filegroup ที่มีหลายไฟล์ SQL Server ไม่ได้เขียน "รอบวง" แบบ round-robin ธรรมดา แต่ใช้ **Proportional Fill Algorithm**: เลือกไฟล์ตาม **สัดส่วนพื้นที่ว่าง** — ไฟล์ที่มีที่ว่างเหลือมากจะรับงานเขียนมากกว่า

```
ไฟล์ A ว่าง 10 GB ┐
                  ├─ สัดส่วนว่าง 2:1 → เขียนลง A ประมาณ 2 หน้า สลับกับ B 1 หน้า
ไฟล์ B ว่าง 5 GB  ┘
```

เจตนาของกลไกนี้ดี: ไฟล์ใหญ่ (กินพื้นที่มากกว่า) ควรรับส่วนแบ่งงานมากกว่า เพื่อให้ "ทุกไฟล์หมดอายุพร้อมกัน" แต่ผลเสียคือ **ถ้าไฟล์โตไม่เท่ากัน (หรือโตด้วย growth ไม่เท่ากัน) ระบบจะเอนไปโยนงานให้ไฟล์ใหญ่ตลอด** — ไฟล์เดียวกลายเป็น hotspot ทั้งที่มีไฟล์ 8 ไฟล์

### 2.2 พิสูจน์ด้วยการทดลองจริง — กระจายงานลง 4 ไฟล์ tempdb

AdventureWorks ของเรามี data file เดียว จึงยืม "ห้องแล็บ" ที่มี 4 ไฟล์ขนาดเท่ากันตามธรรมชาติ — **tempdb ของ VM นี้ (4 data files × 72 MB)** — มาดูว่า proportional fill กระจายจริงหรือไม่ เราสร้างตารางถาวรชั่วคราวใน tempdb แล้ววัดจำนวน page ที่เพิ่มขึ้น **ต่อไฟล์** ด้วย `sys.dm_db_file_space_usage`:

```sql
USE tempdb;
GO
-- snapshot จำนวน page ของ user objects ต่อไฟล์ ก่อนทดลอง
SELECT file_id, user_object_reserved_page_count AS pages_before
INTO #FillSnap
FROM sys.dm_db_file_space_usage;
GO
-- workload: ตาราง 2,740 แถว × ~507 bytes ≈ 190+ pages
DROP TABLE IF EXISTS dbo.ProportionalFillLab;
CREATE TABLE dbo.ProportionalFillLab
(
    Id  INT IDENTITY NOT NULL,
    Col CHAR(500)    NOT NULL DEFAULT 'x'
);
INSERT dbo.ProportionalFillLab (Col)
SELECT 'x' FROM sys.all_objects;
GO
-- เทียบก่อน/หลัง: แต่ละไฟล์ได้งานเท่าไร?
SELECT s.file_id,
       f.user_object_reserved_page_count - s.pages_before AS pages_added
FROM #FillSnap AS s
JOIN sys.dm_db_file_space_usage AS f ON f.file_id = s.file_id
ORDER BY s.file_id;
GO
DROP TABLE dbo.ProportionalFillLab;   -- ล้างของทดสอบ
GO
```

**Expected (รันจริง, 2026-10-02):**

| file_id | pages_added |
|:--------|:------------|
| 1 | 40 |
| 3 | 48 |
| 4 | 56 |
| 5 | 48 |

รวม ~192 pages กระจายเกือบเท่ากัน 4 ไฟล์ — และความไม่เท่ากันเล็กน้อย (40 กับ 56) คือ **หลักฐานว่ากลไกทำงานตามสัดส่วนพื้นที่ว่างจริง**: ตอนทดลองไฟล์ 1 มีพื้นที่ว่างเหลือน้อยกว่าเพื่อนจึงได้งานน้อยกว่า หาก 4 ไฟล์นี้โตไม่เท่ากัน ตัวเลขจะเอนออกมากกว่านี้มาก

> [!IMPORTANT]
> **ทำไมจึงใช้ `sys.dm_db_file_space_usage` แทน `sys.dm_db_database_page_allocations`?** เพราะ DMF ที่ใช้ได้ดีใน Section 3.1 **ไม่รายงาน page ของตารางชั่วคราว และไม่รายงาน object ที่สร้างใน tempdb** — ใน tempdb ให้ใช้ตัวนับระดับไฟล์ (`dm_db_file_space_usage`) หรือระดับ session/task (`dm_db_task_space_usage`) แทน (เจาะต่อใน Section 3.4)

### 2.3 กฎที่ตามมา

1. **ขนาดไฟล์เท่ากัน** ทุกไฟล์ใน filegroup เดียวกัน
2. **Autogrowth เท่ากัน** เป็น MB คงที่ (growth ไม่เท่า = วันหนึ่งไฟล์จะโตไม่เท่า)
3. ใช้ `.ndf` หลายไฟล์ใน filegroup เดียวเมื่อตารางใหญ่และเขียนหนัก — เพื่อกระจาย allocation และเพิ่ม parallelism ฝั่ง I/O (จำกัด: ไฟล์เท่ากันเสมอ)
4. เข้าใจว่า proportional fill ใช้กับ **data** — log file ใช้กลไกคนละอย่าง (เขียนต่อท้ายเสมอ — Section 3.3)

---

## 3. Instant File Initialization (IFI) — ตัดราคา "เปิดพื้นที่ใหม่"

### 3.1 ปัญหาและกลไก

ปกติเมื่อ SQL Server ขอพื้นที่ใหม่ (CREATE DATABASE, restore, autogrow) Windows ต้อง **zero-fill** ไบต์ทั้งหมดก่อนคืนพื้นที่ให้ process — เพราะเหตุผลด้านความปลอดภัย (ข้อมูลเก่าจากไฟล์อื่นต้องไม่รั่ว) ไฟล์ 100 GB ที่ grow ครั้งใหญ่ = เขียนศูนย์ 100 GB ก่อนใช้งานจริง

**IFI** คือสิทธิ์ Windows *Perform Volume Maintenance Tasks* ที่ให้ SQL Server ได้พื้นที่ **โดยข้ามการ zero-fill** — grow ครั้งใหญ่เสร็จในไม่กี่วินาทีแทนที่จะเป็นนาที

| เงื่อนไข | ผล |
|:---------|:---|
| สิทธิ์ *Perform Volume Maintenance Tasks* ให้ service account (SQL Server Configuration Manager หรือ Local Security Policy) | CREATE DATABASE / RESTORE / **data file autogrow** เร็วขึ้นมหาศาล |
| **ตั้งแต่ SQL Server 2022** | IFI ช่วย **log autogrow ≤ 64 MB** ด้วย (ก่อนหน้านี้ log ต้อง zero-fill เสมอ — เพราะ log ต้อง recover ได้) |
| ข้อแลกเปลี่ยน | ไฟล์ที่เพิ่ง grow อาจมีข้อมูลเก่าตกค้างในไฟล์ (ลบได้ด้วย backup/restore เต็มหรือ DBCC SHRINKFILE+grow) — จุดสำคัญตอนตรวจ compliance |

### 3.2 ตรวจว่าเปิดหรือยัง — จากฝั่ง engine เลย

```sql
SELECT servicename, service_account, instant_file_initialization_enabled
FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server (%)';
GO
```

**Expected (รันจริง, 2026-10-02):**

| servicename | service_account | instant_file_initialization_enabled |
|:------------|:----------------|:------------------------------------|
| SQL Server (MSSQLSERVER) | NT Service\MSSQLSERVER | **Y** |

> ตรวจรายละเอียดปลีกย่อยได้อีกชั้นด้วย trace flag 3004/3605 (log การ zero-fill ออก errorlog) หรือจับ event ฝั่ง XE — ในหลักสูตรนี้ใช้คอลัมน์ข้างบนเป็นตัวตัดสินพอ

---

## 4. Autogrowth — เครื่องยางยาม ไม่ใช่กลยุทธ์

### 4.1 หลักคิด

- **Pre-allocate ให้พอกับ workload ปกติเสมอ** — ขนาดไฟล์ตั้งต้นควรรองรับการทำงานหลายเดือนโดยไม่ grow
- Autogrowth เป็น **Safety Net** เมื่อประเมินผิด — ไม่ใช่วิธีโตไปตามรอย
- ทุกครั้งที่ grow: query ที่กำลังใช้พื้นที่ถูก **ระงับ (stall)** จน grow เสร็จ + บน data file ทั้ง extent ที่ขยายต้องถูกจัดสรร + log ต้องเขียนเหตุการณ์ — grow ขนาดใหญ่บน storage ช้า = ความช้าที่ผู้ใช้เห็นเป็น "ระบบค้างเป็นพัก ๆ"

### 4.2 ตั้งอย่างไร

| ตั้งค่า | คำแนะนำ |
|:--------|:--------|
| ชนิด | **MB คงที่** เสมอ — ห้าม PERCENT (ไฟล์ 200 GB ที่ grow 10% = 20 GB ต่อครั้ง ทั้งยาวและพา VLF ไปไกล; ไฟล์เล็ก grow 10% = ไร้ความหมาย) |
| ขนาด (data) | 64–1024 MB ตามอัตราโตจริง — ใหญ่พอไม่ให้ grow บ่อย เล็กพอไม่ให้ grow ครั้งละนาน |
| ขนาด (log) | 64–2048 MB — เข้าใจว่าทุก grow = VLF ชุดใหม่ (คณิตศาสตร์ VLF ใน Section 3.3) |
| ให้เท่ากัน | ไฟล์ทุกไฟล์ใน filegroup เดียวกัน — เพื่อ proportional fill (หัวข้อ 2) |

ตัวอย่างการแก้ไข — **แสดงไว้เป็นรูปแบบเท่านั้น อย่ารันบน production** (เปลี่ยน `NAME`/`SIZE` ตามจริงก่อนใช้):

```sql
-- แก้ growth จาก PERCENT เป็น MB คงที่ — รันเฉพาะเครื่องทดสอบของคุณเอง
USE master;
GO
ALTER DATABASE [YourDatabase]
MODIFY FILE (NAME = N'YourDatabase_data', FILEGROWTH = 512 MB);
GO
ALTER DATABASE [YourDatabase]
MODIFY FILE (NAME = N'YourDatabase_log', FILEGROWTH = 256 MB);
GO
```

> การเปลี่ยน `FILEGROWTH` ไม่ได้แก้ขนาดปัจจุบัน และไม่ได้แก้ VLF เก่าที่สะสมมา — สำหรับ log ที่ VLF บวม ให้ดูขั้นตอน SHRINKFILE + grow ใหม่ใน [Section 3.3](../03_Transaction_Log_Internals/README.md)

### 4.3 มองเหตุการณ์ grow ที่เกิดจริงอย่างไร

- แหล่งประวัติยุคเก่า: Default Trace (`fn_trace_gettable(...log.trc)`) — **deprecated แล้ว** อย่าลงทุนใหม่
- ทางปัจจุบัน: Extended Events — event `sqlserver.database_file_growth` (รวม event เพื่อนบ้านเรื่อง I/O) เก็บเป็น session ถาวรตัวเล็ก ๆ เพื่อจับ "grow บ่อยเกิน" — เราจะตั้ง XE session จริงใน Module 9
- ตัวชี้วัดทางอ้อมที่ใช้ได้ทันที: ถ้าไฟล์โตขึ้นเป็นขั้นบันไดเท่า ๆ กันหลายร้อยขั้น (ดูจาก VLF ขนาดคละกัน — แล็บ Exercise 3) นั่นคือประวัติ autogrowth ที่เล็กเกินไป

---

## 5. พื้นที่ว่างและ Latency ต่อไฟล์ — สองคำสั่งที่ควรมีติดกระเป๋า

### 5.1 DBCC SHOWFILESTATS — พื้นที่ว่างจริงใน data file

```sql
USE AdventureWorks;
GO
DBCC SHOWFILESTATS;   -- ระดับ database ปัจจุบัน (ต้อง sysadmin)
GO
```

**Expected (รันจริง, 2026-10-02):**

| Fileid | FileGroup | TotalExtents | UsedExtents | Name |
|:-------|:----------|:-------------|:------------|:-----|
| 1 | 1 | 4,224 | 3,844 | AdventureWorks |

ไฟล์ 264 MB = 4,224 extents (คูณ 8 = 33,792 pages ✓ ตรงกับ `size` ในหัวข้อ 1) ใช้ไป 3,844 extents — จบภาพ "พื้นที่ว่างระดับ extent" ที่ proportional fill ใช้ตัดสิน โดยไม่ต้องคำนวณจากการรวมตารางทั้งหมด

### 5.2 sys.dm_io_virtual_file_stats — latency สะสมต่อไฟล์

```sql
-- เฉพาะไฟล์ของ database ปัจจุบัน (ค่าสะสมตั้งแต่ startup — เทียบต้องเป็น delta)
SELECT mf.name AS logical_name, mf.type_desc,
       vfs.num_of_reads, vfs.num_of_writes,
       CAST(vfs.io_stall_read_ms  / NULLIF(vfs.num_of_reads, 0)  AS DECIMAL(10,2)) AS avg_read_ms,
       CAST(vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) AS DECIMAL(10,2)) AS avg_write_ms
FROM sys.dm_io_virtual_file_stats(DB_ID(), NULL) AS vfs
JOIN sys.database_files AS mf
    ON vfs.file_id = mf.file_id;
GO
```

**Expected (รันจริง, 2026-10-02):** บน VM หลักสูตร (drive เดียว) ทั้งไฟล์ ROWS และ LOG มีค่าเฉลี่ยระดับหลักหน่วย ms — ตัวเลขวันนี้ไม่สำคัญเท่า **วิธีใช้**: เก็บ snapshot ก่อน/หลัง workload ที่สงสัย ถ้า avg_write_ms ของ log พุ่งระหว่าง batch เขียนหนัก = WRITELOG ใน wait stats ของ Module 1 กำลังบอกเรื่องเดียวกัน (เกณฑ์ตัดสินครบใน Module 2 — Section 2.4)

---

## 6. การจัดวาง Storage และข้อห้าม

### 6.1 Checklist การจัดวาง

| หัวข้อ | คำแนะนำ | เหตุผลย่อ |
|:-------|:--------|:-----------|
| แยก Data / Log | คนละ volume (อย่างน้อยคนละ LUN/ดิสก์เชิงตรรกะ) | data เป็น random read/write, log เป็น sequential write ที่ commit ทุกครั้ง — แยกกันจะไม่แย่งแขนของกัน (Module 2) |
| Allocation Unit Size | format volume ที่ **64 KB** | ตรงกับ extent — ลด fragmentation ฝั่ง file system กับ I/O ก้อนใหญ่ (read-ahead, backup) |
| RAID/Storage ยุคปัจจุบัน | ยุค SAN/SSD ให้คิดที่ IOPS+latency ต่อ volume มากกว่าชนิด RAID — log ต้องการ write latency ต่ำสุด | เกณฑ์ ms ต่อชนิดไฟล์อยู่ใน Module 2 (1–5 ms สำหรับ log) |
| tempdb | ไฟล์หลายไฟล์เท่ากัน — เจาะใน Section 3.4 | allocation contention |
| Filegroup เสริม | ใช้แยกประเภทข้อมูล (ตารางใหญ่/archive/readable secondary) | บริหารพื้นที่และ backup แบบเลือกได้ |

### 6.2 Auto Shrink — ข้อห้ามที่ต้องพูดด้วยเสียงดัง

**ปิด `AUTO_SHRINK` เสมอ** (`ALTER DATABASE ... SET AUTO_SHRINK OFF` — ค่า default ก็ปิดอยู่ อย่าเปิด) และอย่าใช้ `DBCC SHRINKFILE` เป็นงานประจำ:

```
Auto Shrink → ย้าย page มากองหน้าไฟล์ → index เรียงกันใหม่แบบสวนทาง
            → fragmentation สูงขึ้นทันที (Module 6)
     ┌──────────────────────────────────────────────┘
 workload โตต่อ → ไฟล์ต้อง grow ใหม่ → เสียเวลา grow + VLF/extent ใหม่
     └──────────────→ ตัวจับเวลาเห็นไฟล์ว่างก็ shrink อีก → วนไม่รู้จบ
```

- ราคาที่จ่าย: CPU + I/O ของตัว shrink เอง, fragmentation ที่ทุก query ต้องจ่ายต่อ, และวงจร grow ที่กิน log/VLF
- จุดเดียวที่ SHRINKFILE มีที่ยืน: หนึ่งครั้งจบ หลังลบข้อมูลมหาศาล หรือรีเซ็ต VLF ของ log (Section 3.3) — แล้วตามด้วย index rebuild ทันที

---

## 7. เชื่อมโยงไปข้างหน้า

| โมดูล/Section | ใช้อะไรจาก section นี้ |
|:--------------|:------------------------|
| Section 3.3 | log file ไม่ใช้ proportional fill, VLF จากการ grow, IFI กับ log ≤ 64 MB บน 2022+ |
| Section 3.4 | tempdb 4 ไฟล์เท่ากันคือ proportional fill และ allocation contention ที่หมักไว้ |
| Module 4 (Memory) | พื้นที่ว่างในไฟล์ ≠ พื้นที่ว่างใน buffer pool — คนละภาพ |
| Module 6 (Indexes) | AUTO_SHRINK คือเพื่อนซี้ของ fragmentation — ตรวจ avg_fragmentation_in_percent หลังใครไป shrink |
| Module 10 (Monitoring) | เก็บ file stats + growth settings เป็น baseline ประจำ |
| Module 2 (I/O) | เกณฑ์ latency ต่อชนิดไฟล์และการอ่าน `sys.dm_io_virtual_file_stats` แบบเต็ม |

---

## สรุป Section 3.2

1. ทะเบียนไฟล์อ่านจาก `sys.database_files`/`sys.master_files` — หน่วย `size` คือ page (8 KB) และระวัง overflow กับ `max_size`
2. **Proportional Fill** แจกงานตามสัดส่วนพื้นที่ว่าง — จึงต้องมีไฟล์ขนาด/growth เท่ากัน ไม่งั้นไฟล์ใหญ่กลายเป็น hotspot (พิสูจน์แล้ว: 192 pages ลง 4 ไฟล์ tempdb ได้ 40/48/56/48)
3. **IFI** ข้าม zero-fill ทำให้ CREATE/RESTORE/autogrow ของ data file เร็วมาก — ตรวจด้วย `sys.dm_server_services.instant_file_initialization_enabled`; ตั้งแต่ 2022 log autogrow ≤ 64 MB ก็ได้ราคา IFI
4. **Autogrowth คือ safety net** — MB คงที่ ขนาดเหมาะสม เท่ากันทุกไฟล์; มองประวัติ grow ด้วย XE (ไม่ใช่ Default Trace)
5. `DBCC SHOWFILESTATS` + `sys.dm_io_virtual_file_stats` คือคู่ตรวจ "พื้นที่เหลือ + ความเจ็บต่อไฟล์"
6. **ห้าม AUTO_SHRINK** — วงจร shrink→fragmentation→grow คือต้นทุนสองชั้นโดยไม่ได้อะไรกลับมา

### ตรวจความเข้าใจ

1. `size = 33,792` ใน `sys.database_files` แปลงเป็น MB ได้เท่าไร และเหตุใดสคริปต์จึงควรเขียน `size * 8.0` มากกว่า `size * 8`?
2. Filegroup มีไฟล์ A (ว่าง 20 GB) และ B (ว่าง 5 GB) — Proportional Fill จะแจกงานเขียนสัดส่วนเท่าไร และสถานการณ์นี้ดีหรือเสีย พร้อมวิธีแก้?
3. ทำไม IFI จึงไม่ช่วย transaction log autogrowth ขนาดใหญ่ (เกิน 64 MB) แม้เปิดสิทธิ์แล้ว — เชื่อมกับหน้าที่ของ log ในการ recovery?
4. ผลทดลองในหัวข้อ 2.2 ได้ pages_added = 40/48/56/48 ต่อ 4 ไฟล์ — ทำไมจึงไม่เท่ากันเป๊ะ และสิ่งนี้สอนอะไรเรื่องการตั้งขนาดไฟล์?
5. เพื่อนร่วมงานตั้ง `FILEGROWTH = 10%` ให้ log ไฟล์ 100 GB — ประเมินผลสองชั้น: ระยะเวลา grow แต่ละครั้ง และผลต่อจำนวน VLF (ดูคณิตศาสตร์ใน Section 3.3)
6. AUTO_SHRINK ทำให้ไฟล์ "เล็กลง" — แล้วเพราะอะไรจึงเป็นการเร่งความเสียหายแทนการประหยัดพื้นที่? อธิบายด้วยวงจร shrink-grow และ fragmentation

**➡ ถัดไป:** [3.3 Transaction Log Internals — WAL, VLF และการ Truncate Log](../03_Transaction_Log_Internals/README.md)

---

[⬅ Module 03](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [03 Transaction Log Internals](../03_Transaction_Log_Internals/README.md)
