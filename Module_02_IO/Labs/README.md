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

---

## Exercise 2: ทดสอบ Storage ด้วย DiskSpd (Command Prompt)

### Step 1 — สร้างไฟล์ทดสอบ 2 GB

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

---

## Exercise 3: วิเคราะห์ I/O จริงต่อไฟล์ (SSMS)

### Step 1 — เก็บสถิติ latency ต่อไฟล์ทั้ง instance (สไตล์ Glenn Berry)

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
    SET ModifiedDate = DATEADD(MINUTE, @i, OrderDate)
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
- สคริปต์เสริมในโมดูล: `Scripts/01_Virtual_File_Stats.sql`, `Labs/Scripts/03_Diskspd_Stress_Test.sql`
