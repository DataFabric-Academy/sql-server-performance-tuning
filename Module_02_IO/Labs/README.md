# Lab 2: DiskSpd Benchmark & I/O Latency Analysis (บทที่ 2)

> **ที่มา**: ปรับปรุงจาก Microsoft 10987C **Lab02** (DiskSpd) + [Microsoft Learn — sys.dm_io_virtual_file_stats](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-io-virtual-file-stats-transact-sql) + [Glenn Berry — SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
> รูปแบบ: **Instruction + Code block** — ทุก Step รันได้ทันที (DiskSpd bundled อยู่ที่ `Trainer_Docs/10987/Labfiles/Lab02/Diskspd-v2.0.15/amd64fre/diskspd.exe`)

## Prerequisites

- SQL Server 2019+ (แนะนำ **2025 (17.x)**), database **AdventureWorks2025**
- **DiskSpd.exe** (ดาวน์โหลดจาก [github.com/microsoft/diskspd](https://github.com/microsoft/diskspd) หรือใช้ตัวใน 10987 Lab02)
- Command Prompt / PowerShell แบบ Administrator
- Permission: `VIEW SERVER STATE`, `sysadmin` (สำหรับ `DBCC DROPCLEANBUFFERS`)

## Scenario

Adventure Works จะติดตั้ง server ใหม่ให้ Proseware Inc. ซึ่งมี workload เขียน transaction log หนัก คุณต้องพิสูจน์ว่า storage ผ่านเกณฑ์ และหาไฟล์ใดใน instance ปัจจุบันที่ latency แย่ที่สุด

## Objectives

1. วัด I/O (Logical vs Physical) ด้วย `SET STATISTICS IO`
2. ทดสอบ storage ด้วย DiskSpd แบบ random (OLTP) และ sequential (log/bulk)
3. วิเคราะห์ I/O จริงต่อไฟล์ด้วย `sys.dm_io_virtual_file_stats`

---

## Exercise 1: วัด Logical vs Physical Reads ใน SQL Server

### Step 1 — เปิดโหมดวัดผล I/O และ Execution Plan

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): `SET STATISTICS IO, TIME ON` สั่งให้ SQL Server รายงานจำนวน page ที่อ่านและเวลา CPU ท้ายแท็บ **Messages**; `CHECKPOINT` = บังคับเขียน dirty pages ลงดิสก์ และ `DBCC DROPCLEANBUFFERS` = คำสั่งตระกูล **DBCC** (ต้องเป็น sysadmin) ล้าง clean pages ออกจาก buffer pool เพื่อจำลอง cold cache — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

```sql
USE AdventureWorks2025;
GO
SET STATISTICS IO, TIME ON;
```

### Step 2 — Cold cache: บังคับอ่านจาก disk (⚠️ VM ทดสอบเท่านั้น)

```sql
CHECKPOINT;
DBCC DROPCLEANBUFFERS;  -- ห้ามรันบน Production
GO
SELECT COUNT(*) FROM Sales.SalesOrderDetail;
GO
```

✅ **สังเกต** แท็บ Messages: `physical reads` สูง, `logical reads` เท่าเดิมทุกครั้ง

### Step 3 — Warm cache: รันซ้ำเพื่ออ่านจาก memory

```sql
SELECT COUNT(*) FROM Sales.SalesOrderDetail;
GO
```

✅ **สังเกต**: `physical reads = 0` แต่ `logical reads` เท่าเดิม — logical reads คือตัวชี้วัดงานของ query ไม่ใช่ disk

**Expected:** cold run หลัง `DBCC DROPCLEANBUFFERS` ต้องเห็น `physical reads` + `read-ahead reads` สูงในแท็บ Messages ส่วน warm run ต้องได้ `physical reads = 0` และ `read-ahead reads = 0` โดย `logical reads` เท่าเดิมทุกครั้ง — logical reads วัดงานของ query ไม่ผันแปรตาม cache
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-01: cold = logical reads 274, physical reads 1, read-ahead reads 272 (`COUNT(*)` เลือกอ่าน NC index ที่แคบที่สุด ~274 pages ไม่ใช่ clustered index ~1,245 pages), warm = logical reads 274, physical reads 0, read-ahead reads 0

---

## Exercise 2: ทดสอบ Storage ด้วย DiskSpd (Command Prompt)

### Step 1 — สร้างไฟล์ทดสอบ 2 GB

> **ต้องรู้ก่อน** (ไม่ใช่ T-SQL — รันระดับ OS): `fsutil` และ `diskspd` เป็น command-line utility ของ Windows รันใน Command Prompt/PowerShell บนเครื่อง VM โดยตรงเท่านั้น (รันใน SSMS ไม่ได้); `fsutil file createnew` สร้างไฟล์ว่างขนาดที่กำหนดล่วงหน้า เพื่อไม่ให้เวลาสร้างไฟล์ปนมาในผลวัด — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

```bat
fsutil file createnew D:\Temp\sqltest.dat 2147483648
```

> เปลี่ยน `D:\Temp` เป็น drive ที่ต้องการวัด (ควรเป็น drive เดียวกับ data/log จริง)

### Step 2 — Random Read/Write 8KB (จำลอง OLTP)

```bat
diskspd -c2G -d60 -r -w30 -t2 -o8 -b8K -Sh -h D:\Temp\sqltest.dat
```

| ตัวเลือก | ความหมาย |
|:---------|:---------|
| `-c2G` | สร้างไฟล์ทดสอบ 2 GB |
| `-d60` | ทดสอบ 60 วินาที |
| `-r` | Random access |
| `-w30` | Write 30% / Read 70% |
| `-t2` / `-o8` | 2 threads / queue depth 8 |
| `-b8K` | Block size 8 KB (ขนาด page ของ SQL Server) |
| `-Sh` | ปิด software + hardware caching (วัดของจริง) |

### Step 3 — Sequential Write 64KB (จำลอง log write / bulk load)

```bat
diskspd -c2G -d60 -s -w100 -t1 -o8 -b64K -Sh -h D:\Temp\sqltest.dat
```

✅ **เกณฑ์ตีความผลลัพธ์**:

| ตัววัด | ผ่านเกณฑ์ |
|:-------|:----------|
| 8K random IOPS | > 5,000 (SSD ปกติ) |
| avg latency (OLTP) | < 5–10 ms |
| avg latency (log write) | < 5 ms |
| 64K sequential MB/s | สูงกว่า random หลายเท่า |

**Expected:** อ่านแถว `total` ท้ายรายงาน diskspd — จับ IOPS, MB/s และ avg latency (ms) ไปเทียบตารางเกณฑ์ด้านบน; 8K random ต้องได้ IOPS สูงแต่ MB/s ต่ำ ส่วน 64K sequential ต้องได้ MB/s สูงกว่า random หลายเท่า — **DiskSpd ต้องรันบน VM ตรง ๆ ตอนสอน** (เป็น EXE ระดับ VM รันผ่าน remote session ไม่ได้)
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-01: ไม่ได้รัน DiskSpd — ใช้ `sys.dm_io_virtual_file_stats` ของ storage เดียวกัน (VM มี drive C:\ เดียว) เป็นค่าอ้างแทน: avg latency ~1 ms ตอน idle → ~29 ms ช่วงโหลดเขียนหนักของ Exercise 3 (ค่าโดยประมาณ ช่วงที่ VM มี workload อื่นร่วมด้วย)

---

## Exercise 3: วิเคราะห์ I/O จริงต่อไฟล์ (SSMS)

### Step 1 — เก็บสถิติ latency ต่อไฟล์ทั้ง instance (สไตล์ Glenn Berry)

> **ต้องรู้ก่อน** (ใช้ syntax เกิน SELECT/JOIN): `sys.dm_io_virtual_file_stats(NULL, NULL)` คือ DMF ที่รับ (database_id, file_id) โดย NULL = ทุก database/ทุกไฟล์ และต้อง JOIN `sys.master_files` เพื่อแปลง id เป็นชื่อไฟล์; `NULLIF(x, 0)` คืน NULL เมื่อ x = 0 เพื่อกันหารด้วยศูนย์; Step 2 ยังใช้ `WHILE` loop + `UPDATE TOP (100)` สร้างโหลดเขียน — อ่านเพิ่มที่ [Glossary](../../Glossary.md)

```sql
SELECT DB_NAME(vfs.database_id) AS database_name,
       mf.name AS logical_file_name,
       mf.type_desc,                       -- ROWS = data, LOG = log
       vfs.num_of_reads, vfs.num_of_writes,
       vfs.io_stall_read_ms  / NULLIF(vfs.num_of_reads, 0)  * 1.0 AS avg_read_latency_ms,
       vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) * 1.0 AS avg_write_latency_ms,
       vfs.io_stall_read_ms + vfs.io_stall_write_ms AS total_io_stall_ms,
       (vfs.io_stall_read_ms + vfs.io_stall_write_ms)
           / NULLIF(vfs.num_of_reads + vfs.num_of_writes, 0) * 1.0 AS avg_io_latency_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
ORDER BY avg_io_latency_ms DESC;
```

### Step 2 — สร้างโหลดจริงเขียนลง log (รันทิ้งไว้ ~1 นาที)

```sql
USE AdventureWorks2025;
GO
DECLARE @i INT = 0;
WHILE @i < 200
BEGIN
    UPDATE TOP (100) Sales.SalesOrderDetail
    SET ModifiedDate = DATEADD(MINUTE, @i, ModifiedDate)  -- แก้จาก OrderDate (ไม่มีใน SalesOrderDetail — อยู่ที่ SalesOrderHeader)
    WHERE SalesOrderDetailID % 500 = (@i % 500);
    SET @i += 1;
END
```

### Step 3 — เฝ้า latency ของไฟล์ database นี้ระหว่างโหลด (รันซ้ำ 3–4 ครั้ง)

```sql
SELECT mf.type_desc,
       vfs.num_of_writes,
       vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) * 1.0 AS avg_write_latency_ms,
       vfs.io_stall_read_ms / NULLIF(vfs.num_of_reads, 0) * 1.0 AS avg_read_latency_ms
FROM sys.dm_io_virtual_file_stats(DB_ID('AdventureWorks2025'), NULL) AS vfs
JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id;
```

✅ **สังเกต**: ค่าเป็นค่าเฉลี่ย **สะสมตั้งแต่ startup** — ถ้าจะดูรายช่วง ให้เก็บ snapshot เทียบกัน (จะได้ทำต่อใน Lab 10)

### Step 4 (ขั้นสูง) — รวม latency ระดับ drive เพื่อหา drive ที่มีปัญหา

```sql
SELECT UPPER(LEFT(mf.physical_name, 3)) AS drive,
       SUM(vfs.num_of_reads + vfs.num_of_writes) AS total_ios,
       SUM(vfs.io_stall_read_ms + vfs.io_stall_write_ms)
           / NULLIF(SUM(vfs.num_of_reads + vfs.num_of_writes), 0) * 1.0 AS avg_latency_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
GROUP BY UPPER(LEFT(mf.physical_name, 3))
ORDER BY avg_latency_ms DESC;
```

**Expected:** ระหว่าง/หลังโหลด `num_of_writes` ของไฟล์ LOG ต้องเพิ่มเร็วที่สุด (เขียน log ทุกครั้งที่ commit) ส่วนไฟล์ ROWS ถูกเขียนทีหลังตอน checkpoint/lazywriter; ค่า latency เป็นค่าเฉลี่ยสะสมตั้งแต่ startup จึงพุ่งชัดตอนโหลดแล้วค่อย ๆ เจือจาง — และ Step 4 ต้องเห็น latency รวมระดับ drive เรียงจากแย่สุด
> อ้างอิงรันจริง SQL Server 2025 RTM-GDR (17.0.1135.8), AdventureWorks, 2026-10-01: workload (200 รอบ) ใช้เวลา 22 วินาที — ก่อนโหลด ROWS 194 writes / LOG 743 writes (avg write ~0–1 ms); หลังโหลด LOG 1,759 writes (+1,016, avg write ~1 ms), ROWS 2,257 writes (+2,063) avg write latency สะสมของ ROWS พุ่ง ~87 ms แล้วเหลือ ~78 ms หลังผ่านไป ~1 นาที, latency ระดับ drive C:\ ~1 → ~29 ms (ค่าโดยประมาณ ช่วงที่ VM มี workload อื่นร่วมด้วย)

---

## Wrap-up: คำถามท้ายแล็บ

1. DiskSpd ได้ IOPS/latency เท่าไร และเพียงพอกับ workload OLTP ที่คาดการณ์หรือไม่?
2. ไฟล์ใดมี latency แย่สุด เป็น data หรือ log? จะเริ่มแก้จากตรงไหน?
3. ทำไมต้องใส่ `-Sh` ปิด cache ตอนทดสอบ? (วัดของจริงที่ SQL Server จะได้รับ ไม่ใช่ของ disk cache)

## Cleanup

```bat
del D:\Temp\sqltest.dat
```

## แหล่งอ้างอิง

- 10987C Lab02 — `Trainer_Docs/10987/Labfiles/Lab02/`
- Microsoft Learn: [sys.dm_io_virtual_file_stats](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-io-virtual-file-stats-transact-sql) · [ZSTD backup compression (2025)](https://learn.microsoft.com/sql/relational-databases/backup-restore/backup-compression-sql-server)
- Glenn Berry: [SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/)
- สคริปต์ของแล็บนี้อยู่ใน `Sections/*/Scripts/` ของโมดูล จัดตามหัวข้อที่เกี่ยวข้อง (ลิงก์ในแต่ละ Exercise)
