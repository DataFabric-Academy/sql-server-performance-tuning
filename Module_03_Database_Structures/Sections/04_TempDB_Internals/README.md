[⬅ Module 03](../../README.md) | [3.3 Transaction Log Internals](../03_Transaction_Log_Internals/README.md) | Section 4/4

# 3.4 TempDB Internals — พื้นที่ส่วนกลาง, Contention, ADR และ Space Governance (2025)

> *"tempdb ไม่ใช่ database ของใคร แต่เป็นสนามแข่งของทุกคน — sort ของ query หนึ่ง, version ของอีก session, temp table ของ app ชั้นสาม ล้วนแบ่งไฟล์ชุดเดียวกัน ใครดูแล tempdb ผิด ทั้ง instance จ่ายราคา"*

> **ต้องรู้มาก่อน**: [TempDB](../../../Glossary.md), [Latch](../../../Glossary.md), [Wait Type](../../../Glossary.md), Allocation Maps (PFS/GAM/SGAM) จาก [Section 3.1](../01_Structure_Internals/README.md), Proportional Fill จาก [Section 3.2](../02_Data_File_Internals/README.md), VLF/log truncation จาก [Section 3.3](../03_Transaction_Log_Internals/README.md)
> **Permission ที่ต้องมี**: `VIEW SERVER STATE` (อ่าน wait stats / DMV ระดับ server); บล็อกสร้าง temp table / ตารางทดสอบใน tempdb ใช้กับ VM ทดสอบ; บล็อก `ALTER DATABASE tempdb ...` และ `ALTER RESOURCE GOVERNOR ...` **แสดงไว้เป็นตัวอย่างพร้อม guard เท่านั้น — ไม่ได้รันระหว่างเรียน**

---

## ทำไม tempdb จึงปิดท้ายโมดูลนี้

เพราะ tempdb คือจุดที่ทฤษฎีทั้งสาม section แรก "หมัก" พร้อมกัน: การจัดสรรพื้นที่แบบ extent (3.1) ผ่านแผนที่ PFS/GAM/SGAM ที่ถูกแย่งจากทุก session ไปพร้อมกัน, ไฟล์หลายไฟล์ที่ต้องเท่ากันเพื่อ proportional fill (3.2) และ log ที่ต้อง truncate เร็วพอสำหรับ transaction ล้านชิ้นต่อนาที (3.3) — อีกทั้ง SQL Server 2025 ยังเปลี่ยนขีดความสามารถของ tempdb สองเรื่องใหญ่: **ADR ใน tempdb** และ **TempDB Space Resource Governance**

เส้นทางของ Section:

1. **tempdb ใช้ทำอะไร** — ผู้ใช้พื้นที่ 3 กลุ่ม (User / Internal / Version Store)
2. **Layout มาตรฐาน** — ไฟล์กี่ไฟล์ ขนาดเท่าไร (ทดสอบบน VM จริง)
3. **อ่านการใช้พื้นที่** — ต่อไฟล์ ต่อ session/task ต่อ object และ version store
4. **Contention** — PAGELATCH บน allocation pages, ตีความ `wait_resource`, และเดโมที่ "ควรจะไม่เห็น"
5. **SQL Server 2025: ADR ใน tempdb** — rollback ทันที + aggressive log truncation
6. **SQL Server 2025: TempDB Space Governance** — สั่งห้าม workload ไหนกิน tempdb เกินโควตา
7. **Best Practice checklist** ฉบับยุค 2025

> **หมายเหตุสภาพแวดล้อม:** Expected รันจริงบน VM หลักสูตร (SQL Server 2025 RTM-GDR 17.0.1135.8, 4 logical CPUs / 15 GB RAM, 2026-10-02) — ฐานข้อมูล `AdventureWorks` เปิด RCSI แล้วซึ่งเป็นตัวอย่างที่ดีของ version store

---

## 1. ใครใช้ tempdb — สามกลุ่มผู้กินพื้นที่

| กลุ่ม | ตัวอย่าง | อยู่ตรงไหน | อ่านค่าที่ไหน |
|:------|:---------|:-----------|:--------------|
| **User Objects** | `#temp` (local), `##temp` (global), table variable (`@t`), table-valued function ที่สร้าง table | catalog ของ tempdb มองเห็นชื่อ (มี `#` นำหน้า) | `sys.dm_db_task_space_usage`, `tempdb.sys.dm_db_partition_stats` |
| **Internal Objects** | worktable/workfile ของ **sort ที่ spill**, hash join/hash aggregate ที่เกิน grant, DBCC CHECKDB, index build (`SORT_IN_TEMPDB`), spool | ซ่อนจาก catalog (บางตัวเห็นเป็น `#SpillSort...` บน 2025) | คอลัมน์ `internal_*` ของ space DMVs |
| **Version Store** | Row versions ที่เกิดจาก **RCSI/Snapshot Isolation**, online index build, MARS, ADR | ซ่อนเชิงโครงสร้าง วัดได้เป็นพื้นที่ | `sys.dm_tran_version_store_space_usage` |

สองข้อจำที่ทำให้ tempdb "พิเศษ":

1. **สร้างใหม่ทุกครั้งที่ restart** — ขนาดเริ่มต้นคือค่าจากตอนปิดล่าสุด (เหตุผลของการ pre-size ตั้งแต่ติดตั้ง: ให้ tempdb ตื่นมาพร้อมขนาดที่ตั้งไว้ ไม่ใช่ตื่นมาเล็กแล้ว grow แย่งกันช่วงเช้า)
2. **เป็น global resource** — พื้นที่/latch/wait ใน tempdb เป็นของคนทั้ง instance จึงแก้ปัญหาของคนอื่นได้ด้วยการตั้งค่าของเรา

> ข้อควรรู้เรื่องขอบเขต: table variable อยู่ใน tempdb เหมือน `#temp` แต่มี scope เฉพาะ batch และมีค่า estimate เดิม ๆ (Module 6/7) — ส่วน "tempdb อยู่ใน RAM" นั้น **ไม่จริง** — มันเป็น disk database ที่ engine เก็บไว้ใน buffer pool เหมือนฐานอื่น

---

## 2. Layout มาตรฐาน — ไฟล์กี่ไฟล์ เท่าไร

```sql
SELECT name,
       CAST(size * 8.0 / 1024 AS DECIMAL(10,1)) AS size_mb,
       CAST(growth * 8.0 / 1024 AS DECIMAL(10,1)) AS growth_mb,
       is_percent_growth, physical_name
FROM tempdb.sys.database_files
ORDER BY file_id;
GO
```

**Expected (รันจริง, 2026-10-02 — สรุปเฉพาะคอลัมน์สำคัญ):**

| name | size_mb | growth_mb | is_percent_growth |
|:-----|:--------|:----------|:------------------|
| tempdev | 72.0 | 64.0 | 0 |
| templog | 8.0 | 64.0 | 0 |
| temp2 | 72.0 | 64.0 | 0 |
| temp3 | 72.0 | 64.0 | 0 |
| temp4 | 72.0 | 64.0 | 0 |

ตีความตามเกณฑ์มาตรฐาน:

1. **4 data files × 72 MB เท่ากัน** — เครื่องมี 4 logical CPUs: เริ่มจำนวนไฟล์ ≈ จำนวน logical cores แต่ **ไม่เกิน 8** ตามแนวทาง Microsoft ปัจจุบัน; ถ้ายังมี contention ให้เพิ่ม **ทีละกลุ่ม 4** จนหาย (ไม่ใช่เพิ่มให้เท่าจำนวน CPU เสมอ — ไฟล์เยอะเกินมีราคาของ metadata/overhead ต่อไฟล์)
2. **growth เป็น MB เท่ากัน (64 MB)** — `is_percent_growth = 0` ทุกไฟล์ — ออกแบบให้ proportional fill แจกงานสมดุลตลอดชีวิตไฟล์ (Section 3.2)
3. ตั้งแต่ SQL Server 2016 การติดตั้งใหม่/สั่ง update ขนาดไฟล์จะตั้ง growth อัตโนมัติเริ่มต้นที่ 64 MB — แต่ **อย่าถือว่าเวลา restore จากเครื่องเก่าจะได้ค่าที่ดี** — ตรวจเสมอด้วยบล็อกข้างบน
4. tempdb log 8 MB — เล็กเพราะ transaction บน tempdb สั้นและ log ถูก truncate รุนแรง (SIMPLE recovery โดยพฤตินัย) สังเกตว่าต้องโตเป็น 64 MB ทีละครั้งเมื่อมี transaction ใหญ่บน tempdb

---

## 3. อ่านการใช้พื้นที่ tempdb — 4 มุมมอง

### 3.1 ต่อไฟล์ — แยก User / Internal / Version Store

```sql
USE tempdb;
GO
SELECT file_id,
       CAST(unallocated_extent_page_count * 8 / 1024.0 AS DECIMAL(10,1)) AS free_mb,
       CAST(user_object_reserved_page_count * 8 / 1024.0 AS DECIMAL(10,1)) AS user_obj_mb,
       CAST(internal_object_reserved_page_count * 8 / 1024.0 AS DECIMAL(10,1)) AS internal_obj_mb,
       CAST(version_store_reserved_page_count * 8 / 1024.0 AS DECIMAL(10,1)) AS version_store_mb,
       CAST(mixed_extent_page_count * 8 / 1024.0 AS DECIMAL(10,1)) AS mixed_mb
FROM sys.dm_db_file_space_usage
ORDER BY file_id;
GO
```

**Expected (รันจริง, 2026-10-02):**

| file_id | free_mb | user_obj_mb | internal_obj_mb | version_store_mb | mixed_mb |
|:--------|:--------|:------------|:----------------|:-----------------|:---------|
| 1 | 69.1 | 1.4 | 0.1 | 0.0 | 1.4 |
| 3 | 71.6 | 0.1 | 0.2 | 0.0 | 0.2 |
| 4 | 71.4 | 0.1 | 0.1 | 0.0 | 0.4 |
| 5 | 71.6 | 0.1 | 0.1 | 0.0 | 0.3 |

สังเกตว่า `mixed_extent_page_count` มีค่าบน tempdb จริง — tempdb เป็นฐานที่ mixed page allocation ยังทำงานหนัก (สร้าง object จิ๋วรัว ๆ) ต่างจาก user database ยุคใหม่ (Section 3.1 หัวข้อ 4) — และนี่คือครึ่งหนึ่งของเหตุผลที่ tempdb ต้องมีหลายไฟล์ (อีกครึ่งคือกระจาย GAM/SGAM/PFS — หัวข้อ 4)

### 3.2 ต่อ session/task — ใครกินเท่าไร

```sql
USE AdventureWorks;
GO
-- สร้าง user object ใน tempdb ชั่วคราวแล้วดูตัวเลขของตัวเอง
SELECT TOP (1000) BusinessEntityID, LastName, FirstName, MiddleName,
       ROW_NUMBER() OVER (ORDER BY LastName) AS rn
INTO #SessionLab
FROM Person.Person;
SELECT session_id, request_id,
       CAST(user_objects_alloc_page_count / 128.0 AS DECIMAL(10,2)) AS user_mb,
       CAST(internal_objects_alloc_page_count / 128.0 AS DECIMAL(10,2)) AS internal_mb
FROM tempdb.sys.dm_db_task_space_usage
WHERE session_id = @@SPID;
DROP TABLE #SessionLab;
GO
```

**Expected (รันจริง, 2026-10-02):**

| session_id | request_id | user_mb | internal_mb |
|:-----------|:-----------|:--------|:------------|
| 51 | 0 | 0.38 | 0.00 |

- 1,000 แถว × ~90 bytes ≈ 7–8 pages ข้อมูล แต่ตัวเลขคือ **0.38 MB = 48 pages** — เพราะตัวนับนับ **page ที่ถูกจัดสรรรวม extent** (การจัดสรรให้เป็นก้อน extent ตาม Section 3.1) และมีงาน sort ของ `ROW_NUMBER()` ปนมาบ้าง
- `dm_db_task_space_usage` นับ **สะสมต่อ task** (request) ภายใน session — เหมาะเป็นภาพ "ระหว่างรัน"; ขณะเดียวกัน `sys.dm_db_session_space_usage` ซึ่งเอกสารว่านับสะสมต่อ session ได้ค่า 0 ตลอดบน build นี้ (17.0.1135.8 — ตรวจจริง) จึงใช้ task-level เป็นหลัก
- สำหรับ "ใครกำลังกินตอนนี้" ใช้ `sys.dm_db_file_space_usage` (สถานะปัจจุบันต่อไฟล์) คู่กัน — ตัวอย่าง internal object ที่มองเห็นได้จริง: รัน sort ใหญ่ที่ spill แล้วไปดู `internal_object_reserved_page_count` และ catalog ของ tempdb จะพบ worktable ซ่อนชื่อ `#SpillSort...` (เจาะ spill ต่อใน Module 7)

### 3.3 ต่อ object — ใครเป็นเจ้าของพื้นที่ user object

```sql
USE tempdb;
GO
SELECT TOP (8) OBJECT_NAME(object_id, DB_ID('tempdb')) AS object_name,
       CAST(SUM(used_page_count) / 128.0 AS DECIMAL(10,2)) AS used_mb,
       SUM(row_count) AS [rows]
FROM sys.dm_db_partition_stats
GROUP BY object_id
HAVING SUM(used_page_count) / 128.0 > 0
ORDER BY used_mb DESC;
GO
```

**Expected (รันจริง, 2026-10-02):**

| object_name | used_mb | rows |
|:------------|:--------|:-----|
| sysschobjs | 8.00 | 11,560 |
| syscolpars | 2.00 | 2,542 |
| sysobjvalues | 1.00 | 267 |
| sysrscols | 1.00 | 1,567 |

บน tempdb ที่ว่างเปล่าตัวเต็มวัย top คือ **system tables ของ tempdb เอง** (sysschobjs = ทะเบียน object) — แถว 11,560 แถวคือประวัติ temp table ที่ถูกสร้าง/ลบสะสม catalog — ถ้าเห็น temp table จริง (`#xxx___...`) นำหน้า ให้จับ session เจ้าของด้วยคอลัมน์ `session_id` ของ task space usage ตามแบบแล็บ

### 3.4 Version Store — ภาษีของ RCSI/Snapshot

AdventureWorks ของหลักสูตรเปิด **RCSI** — ทุก statement ที่อ่านขณะมีคนแก้ จะถูกเซิร์ฟด้วย version เก่าที่เก็บใน tempdb:

```sql
SELECT DB_NAME(database_id) AS database_name,
       CAST(reserved_page_count / 128.0 AS DECIMAL(10,2)) AS version_store_mb
FROM sys.dm_tran_version_store_space_usage;
GO
```

**Expected (รันจริง, 2026-10-02 — ขณะ server ว่าง):**

| database_name | version_store_mb |
|:--------------|:-----------------|
| msdb | 0.00 |
| AdventureWorks | 0.00 |

ว่างเพราะไม่มี transaction ยาวที่สร้าง version ค้าง — บนระบบจริงถ้าค่านี้บวมผิดปกติ แปลว่ามี **transaction ยาว (มักไม่ commit) ที่ RCSI อ่านตามมัน** — กวาดด้วยหา head blocker (Module 5) version store ที่โตคืออาการ ไม่ใช่โรค

---

## 4. TempDB Contention — เมื่อทุก session ชี้แผนที่หน้าเดียวกัน

### 4.1 กลไก

การสร้าง object ใหม่ทุกชิ้น (temp table ทุกใบ) ต้องแตะแผนที่ allocation ของ tempdb — PFS/GAM/SGAM — ซึ่งเป็น **page ชุดเดียวกันของทุก session** Latch คุมหน้าเหล่านี้ให้เขียนทีเดียวคนเดียว จึงเกิดการคิว:

```
session 1: CREATE #t ──┐
session 2: CREATE #t ──┼──▶ ต้องแก้ PFS/GAM/SGAM page เดียวกัน ──▶ PAGELATCH_EX/UP คิวยาว
session N: CREATE #t ──┘
```

- wait ที่เจอ: **`PAGELATCH_EX` / `PAGELATCH_UP`** (latch ใน memory — ต่างจาก `PAGEIOLATCH_*` ที่เป็นเรื่อง disk)
- ตีความ `wait_resource` รูปแบบ `dbid:file_id:page_id` — เช่น `2:1:1` = tempdb (dbid 2) ไฟล์ 1 หน้า 1 = **PFS**; `2:1:2` = GAM, `2:1:3` = SGAM (ตำแหน่งมาตรฐานจาก Section 3.1)
- ทางแก้ตามลำดับ: (1) ไฟล์หลายไฟล์ขนาดเท่ากัน (กระจายแผนที่ — ทำแล้วตาม Section 3.2), (2) ลดการสร้าง/ลบ temp table รัว ๆ (cache แบบ reuse, table type, ฯลฯ), (3) **Memory-Optimized TempDB Metadata** (SQL Server 2019+, opt-in) ย้าย catalog ของ temp table ลง memory ตัด latch ที่ system tables

### 4.2 อ่าน wait ที่เกี่ยว

```sql
SELECT wait_type, waiting_tasks_count,
       wait_time_ms,
       CAST(wait_time_ms / NULLIF(waiting_tasks_count, 0) AS DECIMAL(10,3)) AS avg_wait_ms
FROM sys.dm_os_wait_stats
WHERE wait_type IN ('PAGELATCH_EX', 'PAGELATCH_SH', 'PAGELATCH_UP', 'PAGEIOLATCH_EX')
ORDER BY wait_time_ms DESC;
GO
```

**Expected (รันจริง, 2026-10-02 — ค่าสะสมตั้งแต่ restart):**

| wait_type | waiting_tasks_count | wait_time_ms | avg_wait_ms |
|:----------|:--------------------|:-------------|:------------|
| PAGELATCH_SH | 6,257 | 977 | ~0.16 |
| PAGELATCH_EX | 18,586 | 875 | ~0.05 |
| PAGEIOLATCH_EX | 371 | 552 | ~1.49 |
| PAGELATCH_UP | 0 | 0 | NULL |

อ่านแบบมืออาชีพ: `PAGELATCH_EX` เกิด 18,586 ครั้งแต่รวม 875 ms (~0.05 ms ต่อครั้ง) — คือระดับ **background noise ปกติ** ไม่ใช่ contention — เกณฑ์แยกว่าเป็นปัญหาจริง: **avg_wait_ms สูงผิดปกติ (หลักสิบ ms ขึ้นไป) และเพิ่มขึ้นแบบ delta ระหว่างช่วงที่ app สร้าง temp table รัว** — และต้องดู `wait_resource` เป็น `2:...` เท่านั้นจึงเป็น tempdb

> [!IMPORTANT]
> **บทเรียนจากแล็บ Exercise 4:** วนสร้าง/ลบ temp table 20,000 รอบ "หนึ่งหน้าต่างเดียว" แล้ว poll `sys.dm_exec_requests` 45 วินาที **ไม่เห็น** PAGE%LATCH บน `2:%` เลย — ผลนี้ถูกต้อง เพราะ **contention ต้องมีคู่แข่ง**: ต้องรัน 4–8 หน้าต่างพร้อมกันและ poll ระหว่างรัน — อย่าสรุปจากยอดสะสมหลังจบ

---

## 5. SQL Server 2025: ADR ใน TempDB

### 5.1 นิยามก่อนใช้

**ADR (Accelerated Database Recovery)** = สถาปัตยกรรม recovery ใหม่ที่ใช้ **Persistent Version Store (PVS)** เก็บ version เก่าของแถวอยู่ใน database ทำให้ rollback เป็น "อ่าน version เดิมคืน" แทน "ไล่ undo log ทั้งหน้า" — ใช้ได้ตั้งแต่ SQL Server 2019 แต่ **ห้าม tempdb** มาถึง **SQL Server 2025 จึงเปิดใน tempdb ได้**

ประโยชน์เมื่อเปิดใน tempdb:

1. **Instantaneous rollback ของ transaction บน temp table/table variable** — workload ที่ rollback ก้อนใหญ่บน temp table (ETL, การคำนวณรายงาน) จะไม่ติด undo ยาว
2. **Aggressive log truncation บน tempdb log** — active log สั้นลง ลดโอกาส tempdb log เต็มจาก transaction ยาว/ลืม commit (เหตุ `ACTIVE_TRANSACTION` ใน Section 3.3)
3. ต้นทุน: PVS กินพื้นที่ tempdb เพิ่ม (เห็นเป็น version store ในหัวข้อ 3) — แลกความเร็ว recovery/rollback

### 5.2 ตรวจสถานะและวิธีเปิด

```sql
SELECT name,
       is_read_committed_snapshot_on,
       is_accelerated_database_recovery_on
FROM sys.databases
WHERE name IN ('AdventureWorks', 'tempdb');
GO
```

**Expected (รันจริง, 2026-10-02):**

| name | is_read_committed_snapshot_on | is_accelerated_database_recovery_on |
|:-----|:------------------------------|:------------------------------------|
| tempdb | 0 | **0** |
| AdventureWorks | **1** | 0 |

บน VM หลักสูตร ADR ของ tempdb ยังปิด (0) — การเปิด (ตัวอย่างรูปแบบ — **ไม่ได้รันระหว่างเรียน** เพราะต้อง **restart Database Engine** ทั้งเครื่อง จึงเป็นงานวางแผนของผู้ดูแล):

```sql
-- แสดงเป็นรูปแบบเท่านั้น — หลังรันต้อง RESTART Database Engine จึงมีผล
-- ALTER DATABASE tempdb SET ACCELERATED_DATABASE_RECOVERY = ON;
-- (เช็คกลับด้วย is_accelerated_database_recovery_on ใน sys.databases)
```

เชื่อมโยง: ฝั่ง user database, ADR/Optimized Locking (2025) เจาะเต็มใน Module 5 — หัวข้อ ADR ใน tempdb นี้คือมุมของ storage

---

## 6. SQL Server 2025: TempDB Space Resource Governance

### 6.1 ปัญหาที่แก้

query หนึ่งตัวที่ spill สะสม (sort/hash ใหญ่ผิด plan) หรือ temp table วิ่งหนี สามารถกิน tempdb **ทั้ง instance** จนคนอื่น error 9009 — ก่อน 2025 ไม่มีทาง "จำกัดโควตาต่อ workload" แบบตรง ๆ

**TempDB Space Resource Governance** (SQL Server 2025) ยก Resource Governor มาบังคับพื้นที่ tempdb: กำหนดเพดานต่อ **workload group** ได้ทั้งแบบ MB และ % ของ tempdb — workload ที่เกินโควตาจะโดน error ตามตัวคุม ไม่ลากทั้ง instance (โบนัส: **Resource Governor กลับมาอยู่ใน Standard Edition แล้ว** ตั้งแต่ 2025)

### 6.2 ตรวจสถานะ

```sql
SELECT name AS workload_group,
       group_max_tempdb_data_percent,
       group_max_tempdb_data_mb
FROM sys.resource_governor_workload_groups;
GO
SELECT is_enabled
FROM sys.resource_governor_configuration;
GO
```

**Expected (รันจริง, 2026-10-02):**

| workload_group | group_max_tempdb_data_percent | group_max_tempdb_data_mb |
|:---------------|:------------------------------|:-------------------------|
| internal | NULL | NULL |
| default | NULL | NULL |

| is_enabled |
|:-----------|
| 0 |

- `NULL` = ยังไม่จำกัด (default) และ Resource Governor ทั้งระบบยังปิด (`is_enabled = 0`)
- รูปแบบการตั้ง (ตัวอย่างเท่านั้น — เป็นงานระดับ instance ของผู้ดูแล):

```sql
-- แสดงเป็นรูปแบบเท่านั้น — ตั้งโควตา tempdb ให้ workload group "reports"
-- ALTER RESOURCE GOVERNOR DISABLE;               -- ขั้นเตรียม (ตามตัวอย่าง MS)
-- ALTER WORKLOAD GROUP [reports] SET ( GROUP_MAX_TEMPDB_DATA_MB = 10240 );  -- 10 GB
-- ALTER RESOURCE GOVERNOR RECONFIGURE;           -- ใช้กฎทันที
```

### 6.3 ฟีเจอร์เสริมอื่น ๆ ยุค 2025 ที่ควรรู้ชื่อ

| ฟีเจอร์ | สรุป |
|:--------|:-----|
| **tmpfs สำหรับ tempdb บน Linux (2025)** | วาง tempdb บน memory filesystem ได้ — กรณี Linux ที่ tempdb กิน I/O จนแย่งกับ data |
| **Memory-Optimized TempDB Metadata** (2019+, opt-in) | ยังควรพิจารณาเปิดบน workload ที่สร้าง temp table เป็นพันต่อวินาที — ลด metadata contention (หัวข้อ 4.1) |
| Parallel redo / smart startup | tempdb ตื่นเร็วขึ้นในรุ่นใหม่ — แต่กฎ "pre-size ให้พอ" ยังเป็นหัวใจ |

---

## 7. Best Practice Checklist — ฉบับยุค 2025

1. **จำนวนไฟล์**: เริ่ม = จำนวน logical cores แต่ ≤ 8; ยังมี contention ค่อยเพิ่มทีละกลุ่ม 4 — **ทุกไฟล์ขนาดเท่ากัน**
2. **Pre-size**: ตั้งขนาดไฟล์ให้พอกับ workload ปกติ (tempdb จำขนาดไว้ตอน restart) + IFI เปิดแล้ว grow จะไม่หน่วง (Section 3.2)
3. **Growth**: MB คงที่เท่ากันทุกไฟล์ (64 MB ขึ้นไปตามโตจริง) — ไม่ใช้ PERCENT
4. **Log**: อย่าตั้ง log tempdb เล็กจนต้อง grow บ่อยระหว่าง batch ใหญ่; พิจารณา **ADR ใน tempdb (2025)** เพื่อ aggressive truncation
5. **คุมคนทั้งบ้าน**: ตั้ง **tempdb space governance** ให้ workload กินดุล (2025, RG ใน Standard) — พร้อม alert ก่อนเต็ม
6. **มองตามงาน**: version store โต = หา transaction ยาว (RCSI ภาษี); internal โต = หา query spill (Module 7); user object โต = หา app ทิ้ง temp table ไม่ลง
7. **ทดสอบ contention ให้ถูกวิธี**: หลาย session พร้อมกัน + poll สดระหว่างรัน — ไม่ใช่ดูยอดสะสมหลังจบ (แล็บ Exercise 4)

---

## เชื่อมโยงไปข้างหน้า

| โมดูล | ใช้อะไรจาก section นี้ |
|:------|:------------------------|
| Module 5 (Concurrency) | version store ของ RCSI/Snapshot + Latch ลึก ๆ |
| Module 6 (Indexes) | SORT_IN_TEMPDB ของ index build, ROW_NUMBER ฯลฯ |
| Module 7 (Query Execution) | sort/hash spill คือผู้กิน internal objects รายใหญ่ — ตาม grant ที่ Module 4 ตัดสิน |
| Module 9 (XE) | event ฝั่ง tempdb/page latch สำหรับตรวจแบบ real-time |
| Module 10/11 | alert พื้นที่ tempdb + ขั้นตอนวินิจฉัย 9009 |

---

## สรุป Section 3.4

1. tempdb มีผู้กิน 3 กลุ่ม: **User Objects / Internal Objects / Version Store** — อ่านแยกได้ด้วย `sys.dm_db_file_space_usage` + `dm_db_task_space_usage` + `dm_tran_version_store_space_usage`
2. Layout มาตรฐาน: ไฟล์เท่าจำนวน core (≤ 8, เพิ่มทีละ 4 ถ้ายัง contention) ขนาด/growth เท่ากัน — บน VM หลักสูตร: 4 files × 72 MB, growth 64 MB ✓
3. Contention คือการคิวบน PFS/GAM/SGAM (`PAGELATCH_EX/UP`, `wait_resource 2:...`) — แก้ด้วยไฟล์หลายไฟล์ + ลดการสร้าง temp table รัว + memory-optimized metadata — และต้องพิสูจน์ด้วยหลาย session พร้อมกัน
4. **ADR ใน tempdb (2025)** ให้ rollback ทันทีและ aggressive log truncation — ตรวจ `is_accelerated_database_recovery_on` — เปิดแล้วต้อง restart engine
5. **TempDB Space Governance (2025)** จำกัดโควตา tempdb ต่อ workload group (`GROUP_MAX_TEMPDB_DATA_MB/PERCENT`) — ป้องกัน query ตัวเดียวลากทั้ง instance และ RG อยู่ใน Standard แล้ว
6. อาการบน tempdb ต้องแยกต้นเหตุ: version store โต → transaction ยาว; internal โต → spill; user โต → app ทิ้งของ

### ตรวจความเข้าใจ

1. อธิบายเหตุผลที่ tempdb ต้องมีหลาย data files ในมุมของ Allocation Maps — และเงื่อนไขใดที่ทำให้ "4 ไฟล์" ไม่พอและควรเพิ่ม?
2. `wait_resource = '2:1:1'` หมายถึงหน้าอะไรใน database ใด ต่างจาก `'2:1:3'` อย่างไร (โยงตำแหน่งมาตรฐานจาก Section 3.1)?
3. `PAGELATCH_EX` สะสม 18,586 ครั้ง/875 ms — เป็นปัญหา tempdb contention หรือไม่ ใช้เกณฑ์ใดตัดสิน และต้องออกแบบการทดสอบอย่างไรจึงจะพิสูจน์ได้จริง?
4. Version store ของ tempdb บวมจาก 0.2 MB เป็น 20 GB ภายในชั่วโมง — สมมติฐานแรกของคุณคืออะไร และจะยืนยันด้วย DMV/query ใด?
5. ADR ใน tempdb (2025) ช่วยอะไรสองเรื่อง แลกกับต้นทุนอะไร และเพราะเหตุใดการเปิดจึงต้อง restart Database Engine ให้ถือเป็นงานวางแผน?
6. Workload group "reports" กำลังกิน tempdb 80 GB จนคนอื่น error 9009 — บน SQL Server 2025 คุณจะตั้งเพดานต่อ group นี้ด้วยคำสั่งใด และถ้าเป็น Standard Edition ทำได้หรือไม่?

**➡ จบ Module 03 — กลับไปที่:** [Module 03 README](../../README.md) | ทดสอบความเข้าใจทั้งโมดูล: [Quiz Bank](../../Quiz_Bank.md)

---

[⬅ Module 03](../../README.md) | [🧪 Labs](../../Labs/README.md) | [⬆ Section 3.3](../03_Transaction_Log_Internals/README.md)
