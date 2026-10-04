[⬅ Module 03](../../README.md) | [3.2 Data File Internals](../02_Data_File_Internals/README.md) | Section 3/4 | ➡ ถัดไป: [04 TempDB Internals](../04_TempDB_Internals/README.md)

# 3.3 Transaction Log Internals — WAL, VLF และการ Truncate Log

> *"Data file คือคำตอบสุดท้าย — แต่ Transaction Log คือเรื่องราวทั้งหมดที่เกิดขึ้น ทุก commit, ทุก rollback, ทุก recovery ต้องกลับมาอ่านเรื่องราวนี้ จึงไม่มี tuning ตัวไหนแก้ 'log disk ช้า' ได้ถูกกว่าทำให้ log disk เร็ว"*

> **ต้องรู้มาก่อน**: หลัก Write-Ahead Logging จาก Module 1 (Transaction Manager / Log Cache / Log Writer) และ wait `WRITELOG` จาก [Module 2 — Section 2.1](../../../Module_02_IO/Sections/01_IO_Core_Concepts/README.md), [Page (8 KB)](../../../Glossary.md), [Log File / VLF](../../../Glossary.md), [DMV / DMF](../../../Glossary.md)
> **Permission ที่ต้องมี**: `VIEW SERVER STATE` (DMV ระดับ server อย่าง `sys.dm_db_log_info`); บล็อกสาธิตสร้างตารางทดสอบใน `AdventureWorks` ใช้ข้อมูลน้อยที่สุดและ **DROP กลับทุกครั้ง**; บล็อก `DBCC SHRINKFILE` **แสดงไว้เป็นรูปแบบเท่านั้น — ห้ามรันบน production ระหว่างชั่วโมงทำงาน**

---

## ทำไม Transaction Log จึงเป็น Section ของโมดูล Database Structures

เพราะ log file (`.ldf`) เป็นไฟล์ที่ "จัดเก็บแบบคนละโลก" กับ data file: ไม่มี extent allocation แบบ proportional fill, ไม่มี page หลากชนิด, ไม่มี fragmentation ของ B-Tree — มันเขียน **ต่อท้ายเสมอ (append-only)** เป็นลำดับเวลา แล้วถูกจัดระเบียบเป็น **VLF** ที่เติบโต/เริ่มใหม่ตามกฎของมันเอง ความเข้าใจผิดเรื่อง log (grow ทีละน้อย, ย้ายจาก FULL มา SIMPLE ด้วยความหวัง "เคลียร์ log", shrink เป็นงานประจำ) คือสาเหตุอันดับหนึ่งของเหตุการณ์ "log เต็ม 9009" และ restore ที่ช้าเหมือนอัมพาต

เส้นทางของ Section:

1. **WAL ทบทวนแบบลึก** — ทำไม log ต้อง harden ก่อน data, ทำไม log จึง append-only
2. **VLF** — โครงภายในไฟล์ log, กฎการแบ่ง, การอ่านจริงด้วย `sys.dm_db_log_info`
3. **Log Truncation** — "วงจรใช้ซ้ำ" ของ log และเหตุผลที่ขวางอยู่ (`log_reuse_wait_desc`) พร้อมสาธิตวงจรจริง
4. **WRITELOG กับ Micro-transaction** — ราคาของ 1 commit หนึ่งครั้ง วัดด้วย wait stats จริง
5. **Ghost Records** — แถวที่ถูกลบแต่ยังค้าง และ Ghost Cleanup Task
6. **แก้ปัญหา VLF บวม** — ขั้นตอนและข้อควรระวัง

> **หมายเหตุสภาพแวดล้อม:** Expected รันจริงบน VM หลักสูตร (SQL Server 2025 RTM-GDR 17.0.1135.8, `AdventureWorks` recovery model **SIMPLE**, 2026-10-02) — ค่าที่เกี่ยวกับพื้นที่/percent จะต่างตาม workload ที่ VM ผ่านมา แต่โครงคำตอบเหมือนกัน

---

## 1. WAL แบบลึก — เหตุผลที่ log ต้องมาก่อนทุกอย่าง

Module 1 วางกฎไว้แล้ว: **log ต้อง harden (เขียนลง disk จริง) ก่อน dirty page ที่เกี่ยวข้องถูก flush ลง data file** — ทบทวนด้วยมุมของ "ทำไมต้องทำแบบนี้" ผ่านสองเหตุการณ์:

```
ตัวอย่าง: UPDATE แก้ 1 แถว

1) Engine บันทึก log record: "ที่ LSN x — แก้ page P slot 3 จากค่าเดิม A เป็น B"
2) Log record เข้า Log Buffer (memory)
3) COMMIT → Log Writer ต้อง flush log buffer ลง .ldf จริง → เสร็จแล้วจึงตอบ client
4) Dirty page ใน Buffer Pool ยังอยู่เดิม... รอ Checkpoint/Lazy Writer (อาจช้าหลายนาที)

ไฟดับระหว่าง (3)-(4): Recovery อ่าน log → เห็น committed transaction ที่ data file ยังไม่มี
                     → Redo จาก log → ข้อมูลไม่สูญเสีย
```

- ถ้าเขียน data ก่อน log: ไฟดับหลัง data ลง disk แต่ก่อน log → committed? uncommitted? **ตอบไม่ได้** — WAL จึงเป็นสัญญาความถูกต้อง ไม่ใช่ตัวเลือก
- log record มีทั้ง **before-image** และ after-image — จึงรองรับทั้ง redo (recovery) และ undo (rollback) — และเหตุนี้เองที่ page split ยังต้อง log หนัก (แล็บ Exercise 2: GUID บวม log)
- **append-only** เพราะ log คือไทม์ไลน์: เขียนท้ายเสมอ ต่อเนื่อง — จึงเป็นงาน sequential write ที่ต้องการ latency ต่ำที่สุดในทั้งระบบ (เกณฑ์ 1–5 ms ของ Module 2)
- จุดเชื่อม: ทุก commit มี log flush หนึ่งชุด → wait **`WRITELOG`** คือตัวเก็บราคานี้ (หัวข้อ 4)

---

## 2. Virtual Log Files (VLF) — ไฟล์ log ถูกแบ่งเป็นช่วง

### 2.1 นิยามก่อนใช้

**VLF (Virtual Log File)** คือการแบ่งเชิงตรรกะของไฟล์ `.ldf` ออกเป็นช่วง ๆ — จัดการเพื่อให้ log "วนใช้พื้นที่ซ้ำ" ได้ (log ไม่มีที่ว่าง/เต็มแบบ data file: มันมีแค่ "ช่วงที่ใช้แล้วและนำกลับมาใช้ได้" กับ "ช่วง active")

```
ไฟล์ AdventureWorks_log.ldf (136 MB) มองเป็น:

┌────────┬───────┬───────┬───────┬───────┬────────┐
│ VLF 1  │ VLF 2 │ VLF 3 │ VLF 4 │ VLF 5 │ VLF 6  │
│ 64 MB  │1.93 MB│1.93 MB│1.93 MB│2.17 MB│ 64 MB  │  ← ขนาดคละกัน = ร่องรอยอดีต
└────────┴───────┴───────┴───────┴───────┴────────┘
   ขนาด VLF กำหนดตอน "grow" แต่ละครั้ง และไม่เปลี่ยนจนกว่าจะ shrink+regrow
```

**กฎการแบ่ง VLF ต่อ 1 ครั้งของการ grow (SQL Server 2014+):**

| ขนาดการ grow หนึ่งครั้ง | จำนวน VLF ที่ได้ |
|:-------------------------|:-----------------|
| ≤ 64 MB | 4 VLFs |
| > 64 MB และ ≤ 1 GB | 8 VLFs |
| > 1 GB | 16 VLFs |

อ่านกฎนี้ย้อนเวลาได้: log ที่ถูกตั้ง `FILEGROWTH = 1 MB` แล้ว grow 500 รอบ = 2,000 VLF จิ๋ว — นี่คือ "High VLF Count" คลาสสิก

### 2.2 อ่าน VLF จริง — วิธีปัจจุบัน (แทน `DBCC LOGINFO`)

```sql
SELECT vlf_size_mb, vlf_sequence_number, vlf_active, vlf_status
FROM sys.dm_db_log_info(DB_ID('AdventureWorks'))
ORDER BY vlf_sequence_number;
GO
```

**Expected (รันจริง, 2026-10-02):**

| vlf_size_mb | vlf_sequence_number | vlf_active | vlf_status |
|:------------|:--------------------|:-----------|:-----------|
| 64 | 54 | 0 | 0 |
| 1.93 | 55 | 0 | 0 |
| 1.93 | 56 | 0 | 0 |
| 1.93 | 57 | 0 | 0 |
| 2.17 | 58 | 0 | 0 |
| 64 | 59 | **1** | **2** |

อ่านผล:

1. **6 VLFs รวม ~136 MB** — ก้อน 64 MB สองก้อน (จาก grow ครั้งใหญ่ครั้งละ 256 MB → 4 VLFs? ไม่ใช่ ตัวเลขจริงชี้ว่ามี grow แบบใหญ่บ้างเล็กบ้างปนกัน)
2. ก้อน 1.93–2.17 MB คือ **ฟอสซิลของ autogrowth ทีละ ~8 MB ในอดีต** (8 MB ÷ 4 ≈ 2 MB ต่อ VLF) — log ที่ตั้งค่าดีตั้งแต่แรกจะได้ VLF ขนาดค่อนข้างเท่ากันทั้งไฟล์
3. `vlf_active = 1` เฉพาะก้อนสุดท้าย (status 2 = active) — ธรรมชาติของ append-only: เขียนอยู่ท้ายเสมอ
4. `vlf_status`: 0 = inactive (นำกลับมาใช้ได้), 1 = initialized แต่ยังไม่ใช้, 2 = active

### 2.3 สำรวจทั้ง instance — ทำแบบไดนามิก (และกับดักของ `NULL`)

```sql
SET NOCOUNT ON;
CREATE TABLE #VlfLab (db_name SYSNAME, file_id INT, vlf_count INT, total_log_mb DECIMAL(10,2));
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql = @sql + N'INSERT #VlfLab SELECT N''' + name + N''', file_id, COUNT(*), CAST(SUM(vlf_size_mb) AS DECIMAL(10,2)) FROM sys.dm_db_log_info(DB_ID(N''' + name + N''')) GROUP BY file_id;'
FROM sys.databases WHERE state = 0;
EXEC (@sql);
SELECT db_name, file_id, vlf_count, total_log_mb FROM #VlfLab ORDER BY db_name;
DROP TABLE #VlfLab;
GO
```

**Expected (รันจริง, 2026-10-02):**

| db_name | file_id | vlf_count | total_log_mb |
|:--------|:--------|:----------|:-------------|
| AdventureWorks | 2 | **6** | 135.96 |
| master | 2 | 8 | 1.99 |
| model | 2 | 3 | 7.99 |
| msdb | 2 | 15 | 4.10 |
| tempdb | 2 | **4** | 7.96 |

> ⚠️ **ข้อค้นพบจากการรันจริงบน build นี้ (17.0.1135.8):** `sys.dm_db_log_info(NULL)` ซึ่งเอกสารระบุว่า "NULL = ทุก database" กลับคืนเฉพาะ `master` — สคริปต์ที่พึ่ง `NULL` จะได้ผลลวง จึงใช้ลูป `DB_ID(name)` ต่อ database ตามบล็อกข้างบนแทน (รูปแบบเดียวกับที่แล็บ Exercise 3 ใช้)

**เกณฑ์ตัดสิน:** log ที่สุขภาพดีมักมี VLF **ไม่กี่สิบก้อน** ขนาดค่อนข้างเท่ากัน; เกิน ~หลายร้อยก้อนคือสัญญาณแก้ — ผลกระทบของ VLF จำนวนมาก: database startup/recovery ช้า (ต้องไล่ตรวจทุกก้อน), log backup/restore ช้า, AG seeding และ replication log reader ช้า

---

## 3. Log Truncation — log "วนกลับมาใช้ซ้ำ" อย่างไร

### 3.1 กลไก

- Log เดินหน้าแบบ append-only — แต่พื้นที่หลังจุดที่ "ไม่ต้องใช้แล้ว" สามารถ **truncate** (เขียนทับด้วย VLF ใหม่) ได้ — จุดตัดคือ **LSN เก่าสุดที่ยังต้องใช้**
- เหตุการณ์ที่ขยับจุดตัดได้: checkpoint (SIMPLE), log backup (FULL), การจบของ transaction เก่าสุด, การจบ scan/replication
- หากมีอะไรขวาง — พื้นที่ที่ "ควรวนกลับมาใช้" จะไม่ถูกใช้ และ log จะ **grow แทน** จนเต็มดิสก์ → error **9009: The transaction log for database is full**

ตารางที่ต้องจำ — เหตุผลขวาง log และทางแก้ (อ่านจาก `sys.databases.log_reuse_wait_desc`):

| log_reuse_wait_desc | ความหมาย | ทางแก้ |
|:--------------------|:---------|:-------|
| NOTHING | ไม่มีสิ่งขวาง — log วนได้ปกติ | — |
| CHECKPOINT | รอ checkpoint ยังไม่มาก (SIMPLE) | รอ/บังคับ CHECKPOINT |
| LOG_BACKUP | FULL recovery ยังไม่ backup log | จัดตาราง log backup (สำคัญที่สุดของ FULL!) |
| ACTIVE_TRANSACTION | transaction ยังเปิดอยู่ (อาจเป็น session ที่ลืม commit!) | หา head ด้วย `sys.dm_tran_active_transactions`/blocking แล้วปล่อยมัน |
| ACTIVE_BACKUP_OR_RESTORE | backup/restore กำลังรัน | รอ |
| REPLICATION / AG | log reader/secondary ยังตามไม่ทัน | ตรวจ distributor/AG health |
| AVAILABILITY_REPLICA | เหมือนข้างบน (AG) | ดู redone_lsn ของ secondary |

### 3.2 สาธิตวงจรครบหนึ่งรอบ — เปิด tran → ขวาง truncation → ปล่อย → กลับมาใช้ได้

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.LogReuseLab;
CREATE TABLE dbo.LogReuseLab (Id INT, Col CHAR(200) DEFAULT 'x');
GO
CHECKPOINT;   -- ให้ log เริ่มสะอาด
SELECT DB_NAME() AS db, CAST(used_log_space_in_percent AS DECIMAL(5,1)) AS used_pct
FROM sys.dm_db_log_space_usage;
GO
BEGIN TRAN;
INSERT dbo.LogReuseLab (Id)
SELECT TOP (20000) object_id FROM sys.all_objects CROSS JOIN (VALUES(1),(2),(3)) v(x);
CHECKPOINT;   -- บังคับให้ engine พยายาม truncate — จะโดน tran ที่ยังเปิดขวาง
SELECT 'ระหว่าง tran เปิดอยู่' AS phase, log_reuse_wait_desc
FROM sys.databases WHERE database_id = DB_ID();
SELECT 'ระหว่าง tran เปิดอยู่' AS phase,
       CAST(used_log_space_in_percent AS DECIMAL(5,1)) AS used_pct
FROM sys.dm_db_log_space_usage;
COMMIT;
GO
CHECKPOINT;
SELECT 'หลัง commit + checkpoint' AS phase, log_reuse_wait_desc
FROM sys.databases WHERE database_id = DB_ID();
SELECT 'หลัง commit + checkpoint' AS phase,
       CAST(used_log_space_in_percent AS DECIMAL(5,1)) AS used_pct
FROM sys.dm_db_log_space_usage;
GO
DROP TABLE dbo.LogReuseLab;
GO
```

**Expected (รันจริง, 2026-10-02):**

| phase | log_reuse_wait_desc | used_pct |
|:------|:--------------------|:---------|
| ก่อนเริ่ม | NOTHING | 39.6 |
| ระหว่าง tran เปิดอยู่ (+CHECKPOINT) | **ACTIVE_TRANSACTION** | **43.7** |
| หลัง commit + checkpoint | **NOTHING** | 42.0 |

อ่านผลทีละชั้น:

1. แถว 20,000 (~5.6 MB log) ดัน used_pct จาก 39.6 → 43.7 — **log โตเท่าที่ transaction เขียน ไม่ว่าจะ commit หรือยัง**
2. CHECKPOINT กลาง tran ไม่ช่วย: จุดตัดโดน transaction เก่าสุดขวาง → `ACTIVE_TRANSACTION` — นี่คือสิ่งที่เกิดเวลา app ลืม commit หรือ holding scan ค้าง
3. หลัง commit + checkpoint: กลับเป็น NOTHING — พื้นที่ถูก mark ว่า **นำกลับมาใช้ได้** (SIMPLE recovery ตัดที่ checkpoint) — สังเกตว่า % ไม่กลับลงเป๊ะเดิม: truncation ไม่ได้ "ย่อไฟล์" แค่เปิดให้เขียนทับ — **ไฟล์ log ไม่เล็กลงเองเด้ดเดี่ยว**
4. บน FULL recovery คู่ขนาดของ checkpoint คือ log backup — ถ้าลืมตั้ง log backup, `LOG_BACKUP` จะค้างและ log โตไม่หยุด (เหตุ 9009 ยอดฮิตอันดับหนึ่ง)

### 3.3 พื้นที่ log ในมองเดียว

```sql
SELECT DB_NAME() AS db,
       CAST(total_log_size_in_bytes / 1048576.0 AS DECIMAL(10,1)) AS total_log_mb,
       used_log_space_in_percent AS used_pct,
       CAST((total_log_size_in_bytes - used_log_space_in_bytes) / 1048576.0 AS DECIMAL(10,1)) AS free_log_mb
FROM sys.dm_db_log_space_usage;
GO
```

**Expected (รันจริง, 2026-10-02):**

| db | total_log_mb | used_pct | free_log_mb |
|:---|:-------------|:---------|:------------|
| AdventureWorks | 136.0 | 39.3 | 82.6 |

คู่กันด้วยสคริปต์รายงาน log ทุกตัวใน instance ของ `Scripts/05_VLF_Analysis.sql` (STEP 1/STEP 5) เมื่อต้องรายงานผู้บริหาร

---

## 4. WRITELOG และ Micro-transaction — ราคาของ commit หนึ่งครั้ง

ทฤษฎี: **1 commit = 1 ครั้งของการ harden log** — แอปที่ insert ทีละแถวล้านแถวจึงจ่ายค่า flush ล้านครั้ง ขณะที่ insert ชุดเดียวกันใน transaction เดียวจ่ายแค่ครั้งเดียว วัดด้วย wait stats จริง (delta ของ `WRITELOG` — ตามวิธี delta ของ Module 1):

```sql
SET NOCOUNT ON;
DROP TABLE IF EXISTS #WlogLab;
CREATE TABLE #WlogLab (Id INT IDENTITY, Col CHAR(50) DEFAULT 'x');
GO
DECLARE @before_ms BIGINT, @before_cnt BIGINT, @i INT = 0;
SELECT @before_ms = wait_time_ms, @before_cnt = waiting_tasks_count
FROM sys.dm_os_wait_stats WHERE wait_type = 'WRITELOG';
WHILE @i < 500
BEGIN
    INSERT #WlogLab DEFAULT VALUES;   -- 1 insert = 1 transaction = 1 log harden
    SET @i += 1;
END
SELECT 500 AS commits,
       (SELECT wait_time_ms FROM sys.dm_os_wait_stats WHERE wait_type = 'WRITELOG') - @before_ms AS writelog_wait_ms_added,
       (SELECT waiting_tasks_count FROM sys.dm_os_wait_stats WHERE wait_type = 'WRITELOG') - @before_cnt AS writelog_waits_added;
GO
DECLARE @before_ms BIGINT, @before_cnt BIGINT, @i INT = 0;
DELETE FROM #WlogLab;
SELECT @before_ms = wait_time_ms, @before_cnt = waiting_tasks_count
FROM sys.dm_os_wait_stats WHERE wait_type = 'WRITELOG';
BEGIN TRAN;
WHILE @i < 500
BEGIN
    INSERT #WlogLab DEFAULT VALUES;   -- log เข้า Log Buffer — harden ครั้งเดียวตอน COMMIT
    SET @i += 1;
END
COMMIT;
SELECT 1 AS commits,
       (SELECT wait_time_ms FROM sys.dm_os_wait_stats WHERE wait_type = 'WRITELOG') - @before_ms AS writelog_wait_ms_added,
       (SELECT waiting_tasks_count FROM sys.dm_os_wait_stats WHERE wait_type = 'WRITELOG') - @before_cnt AS writelog_waits_added;
GO
DROP TABLE #WlogLab;
GO
```

**Expected (รันจริงบน VM หลักสูตร, 2026-10-02 — ค่าวัดอาจผันตามสภาพขณะรัน):**

| กรณี | writelog_wait_ms_added | writelog_waits_added |
|:-----|:-----------------------|:---------------------|
| 500 autocommit | 3 | **4** |
| 500 แถวใน 1 transaction | 2 | **1** |

อ่านผลอย่างตรงไปตรงมา:

1. **ค่า ms เล็กมาก** เพราะ VM หลักสูตร log อยู่บน storage เร็วมาก — flush แทบไม่มีราคา บน disk ช้ากว่าตัวเลขจะบวมหลายเท่า
2. แต่ **จำนวน waits (4 กับ 1) ยังบอกกลไก**: แม้ 500 commit ก็เห็น harden รวมกลุ่มเหลือ 4 ครั้ง — นี่คือ **Group Commit**: engine รวม flush ของหลาย commit ที่มาพร้อมกัน — disk ยิ่งเร็ว, group ยิ่งใหญ่
3. บน production ที่ WRITELOG นาน (log disk แชร์กับงานอื่น) รูปแบบเดียวกันนี้จะเห็น waits ≈ จำนวน commit — ทางแก้อันดับหนึ่งคือ **รวม micro-transaction เป็น transaction ใหญ่พอสมควร** (กลับไปดู Module 1 ประเด็น WRITELOG) ส่วน **Delayed Durability** เป็นตัวเลือกที่ต้องยอมรับความเสี่ยงข้อมูล ~1 วินาทีตอนไฟดับ — ใช้เฉพาะ workload ที่ยอมรับได้

---

## 5. Ghost Records — แถวที่ถูกลบแล้วแต่ยังอยู่บนหน้า

### 5.1 นิยามก่อนใช้

**Ghost Record** = แถวที่ถูก DELETE แล้วแต่ยังกางอยู่บน page — engine เพียง mark ธงว่า "ลบแล้ว" แทนที่จะเคาะออกทันที ทั้งนี้เพื่อ (1) ลดงานของตัว DELETE (ลบเป็นเรื่องของ background), (2) ให้ scan ที่กำลังอ่านหน้านั้นอยู่มองเห็นสถานะที่สอดคล้องกัน (เชื่อมกับ isolation ใน Module 5)

**Ghost Cleanup Task** คือ background process ที่คอยกวาด ghost ออกจากหน้าเป็นระยะ และสามารถถูกเรียกให้ทำงานเมื่อ page จำเป็นต้องเก็บกวาด

### 5.2 เห็น ghost ด้วยตา

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.GhostLab;
CREATE TABLE dbo.GhostLab (Id INT IDENTITY PRIMARY KEY, Col CHAR(50) DEFAULT 'x');
INSERT dbo.GhostLab (Col) SELECT TOP (3000) 'x' FROM sys.all_objects;
DELETE dbo.GhostLab WHERE Id % 2 = 0;   -- ลบ 1,500 แถว — ghost จะปรากฏบนหน้า
-- สำรวจทันที: หน้าไหนมี ghost?
SELECT SUM(CAST(has_ghost_records AS INT)) AS pages_with_ghosts, COUNT(*) AS pages
FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('dbo.GhostLab'), 1, 1, 'DETAILED')
WHERE is_allocated = 1 AND page_type_desc = 'DATA_PAGE';
DROP TABLE dbo.GhostLab;
GO
```

**Expected (รันจริง, 2026-10-02):**

| pages_with_ghosts | pages |
|:------------------|:------|
| **29** | 29 |

ทุก data page มี ghost ทันทีหลัง DELETE — ถ้ารันคำสั่งสำรวจ "ช้าลงอีกรอบ" (หรือปล่อยไว้หลายวินาที) จะเห็นจำนวนลดลงตาม Ghost Cleanup Task กวาดทัน (ตัวเลขวันไหน ghost หายไวผิดปกติ อ่านค่าตรง ๆ ด้วย `ghost_record_count` จาก `sys.dm_db_index_physical_stats(..., 'DETAILED')` — ที่ระดับ row จะเห็นก็ต่อเมื่อกวาดยังไม่ทัน)

> [!WARNING]
> **Trace Flag 661** ปิด Ghost Cleanup ได้ — อย่าทำ: ghost กองทับกัน → ไฟล์โตไม่คืน, scan ต้องข้ามขยะ, page split เพิ่ม ถ้าปิดไปแล้ว index rebuild คือวิธีเก็บกวาดหนึ่งครั้งจบ

---

## 6. แก้ Log ที่ VLF บวม — ขั้นตอนและข้อควรระวัง

จากแล็บ Exercise 3: log ของ AdventureWorks มี 6 VLFs ขนาดคละกัน (ฟอสซิลของ growth เดิม) — การแก้ `FILEGROWTH` เป็น 256 MB **ไม่ได้ทำให้ VLF เก่าหายไป** (growth ถัดไปแค่สร้างก้อนใหญ่ใหม่เพิ่มเข้ามา) การรีเซ็ตจริงทำได้ด้วย shrink + grow ใหญ่ครั้งเดียว:

```sql
-- รูปแบบอ้างอิงเท่านั้น — ห้ามรันบน production ระหว่างชั่วโมงทำงาน
-- (1) backup log ก่อน เมื่อ recovery model = FULL
-- BACKUP LOG [YourDatabase] TO DISK = N'...\YourDatabase_log.trn';
-- (2) ย่อ log
-- USE [YourDatabase];
-- DBCC SHRINKFILE (N'YourDatabase_log', 1024);   -- เป้าหมาย MB
-- (3) grow ครั้งเดียวใหญ่ ๆ → VLF ชุดใหม่ใหญ่เท่ากัน
-- ALTER DATABASE [YourDatabase] MODIFY FILE (NAME = N'YourDatabase_log', SIZE = 8192 MB);
-- (4) ตรวจซ้ำด้วย sys.dm_db_log_info
```

ข้อควรระวัง 3 ข้อ:

1. SHRINKFILE ของ log ติดขวางเหมือน truncation — ต้องทำหลังแก้เหตุขวาง (log backup ประจำ, ปิด tran ค้าง) ไม่งั้นย่อไม่ลง
2. อย่า shrink ลึกเกินไปแล้วปล่อยให้ grow กลับทีละน้อย — นั่นคือการสร้าง VLF จิ๋วใหม่ตามประสาเดิม
3. ตรวจผลด้วย `sys.dm_db_log_info(DB_ID(...))` หลังทำ — เป้าคือ VLF ไม่กี่สิบก้อนขนาดใกล้เคียงกัน

---

## 7. เชื่อมโยงไปข้างหน้า

| โมดูล/Section | ใช้อะไรจาก section นี้ |
|:--------------|:------------------------|
| Section 3.4 | tempdb ก็มี log ของตัวเอง — ADR ใน tempdb (2025) คุยกับ log โดยตรง |
| Module 5 (Concurrency) | rollback = undo จาก log; ADR/Optimized Locking ยุคใหม่ตัดราคา rollback |
| Module 8 (Plan Cache) | micro-transaction ไม่ได้แพงแค่ log — ยังแพงที่ commit เอง |
| Module 10/11 (Monitoring/Troubleshooting) | 9091/9009 alert, log_reuse_wait เป็นขั้นตอนวินิจฉัยมาตรฐาน |
| Module 2 (I/O) | WRITELOG ↔ latency ของ log volume — เกณฑ์ 1–5 ms |

---

## สรุป Section 3.3

1. **WAL** คือสัญญา: log harden ก่อน data flush — log record มี before/after image จึง redo/undo ได้ และเขียนแบบ append-only ต่อเนื่องเสมอ
2. **VLF** แบ่ง log เชิงตรรกะตามกฎ grow (≤64 MB → 4, >64 MB–1 GB → 8, >1 GB → 16) — อ่านด้วย `sys.dm_db_log_info(DB_ID(...))` (และระวัง `NULL` ที่คืนไม่ครบบน build นี้)
3. **Log truncation** เปิดให้เขียนทับ (ไม่ย่อไฟล์) — สิ่งขวางอ่านจาก `log_reuse_wait_desc` (`LOG_BACKUP` บน FULL คือเหตุ 9009 ยอดฮิต, `ACTIVE_TRANSACTION` มักมาจาก app ลืม commit)
4. ราคา log ปรากฏเป็น wait `WRITELOG` — รวม micro-transaction ก่อนพิจารณา delayed durability; **Group Commit** รวม flush เมื่อ disk เร็ว (500 commit เหลือ 4 waits จากการรันจริง)
5. **Ghost Records** คือแถวที่ถูกลบแต่ยังค้างหน้า — เห็นผ่าน `has_ghost_records` — และ Ghost Cleanup Task กวาดใน background
6. แก้ VLF บวมต้อง shrink + grow ใหญ่ครั้งเดียวใน maintenance window — แก้ `FILEGROWTH` เฉย ๆ ไม่พอ

### ตรวจความเข้าใจ

1. เหตุใด SQL Server จึงตอบ client ได้หลัง log flush แต่ก่อน data page ลง disk — อธิบายด้วยสิ่งที่เกิดขึ้นตอนไฟดับ
2. จากกฎ VLF: log ที่ grow ทีละ 2 MB รวม 400 รอบ จะได้ VLF กี่ก้อน ขนาดเท่าไรต่อก้อน และกระทบอะไรลำดับแรก?
3. `log_reuse_wait_desc = LOG_BACKUP` หมายความว่าอะไร ใครเป็นผู้ขยับจุดตัดบน FULL recovery และต่างจาก SIMPLE อย่างไร?
4. ทดลองในหัวข้อ 3.2: ทำไม CHECKPOINT กลาง transaction ที่ยังเปิดจึงไม่ทำให้ log วนกลับมาใช้ได้? และตัวเลข used_pct ที่ไม่กลับลงเป๊ะหลัง commit อธิบายว่าอะไร?
5. รันแล้วได้ WRITELOG waits เพิ่ม 4 ครั้งจาก 500 commits — ขัดกับทฤษฎี "1 commit = 1 flush" หรือไม่ เพราะอะไร? และสิ่งไหน (wait count หรือ wait ms) จะเจ็บกว่าบน production disk ช้า?
6. Ghost Record คืออะไร ทำไม engine ถึงไม่ลบแถวออกจาก page ทันทีตอน DELETE และเครื่องมือใดใน section นี้บอกว่าหน้าไหนมี ghost อยู่?

**➡ ถัดไป:** [3.4 TempDB Internals — Contention, ADR และ Space Governance](../04_TempDB_Internals/README.md)

---

[⬅ Module 03](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [04 TempDB Internals](../04_TempDB_Internals/README.md)
