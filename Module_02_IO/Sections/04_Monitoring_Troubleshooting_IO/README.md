[⬅ Module 02](../../README.md) | [2.3 IO Setup Best Practices](../03_IO_Setup_Best_Practices/README.md) | Section 4/4 | ➡ ถัดไป: [Module 03 — Database Structures](../../Module_03_Database_Structures/README.md)

# 2.4 Monitoring & Troubleshooting I/O — วัดของจริงและไล่คอขวด Storage

> *"Latency ไม่เคยโกหก — แต่ค่าเฉลี่ยโกหกได้ทุกวัน คนจูนมืออาชีพจึงไม่ถามว่า 'disk เร็วแค่ไหน' แต่ถามว่า 'I/O ของไฟล์ไหน ช่วงเวลาไหน รอนานแค่ไหน'"*

> **ต้องรู้มาก่อน**: [IOPS/Throughput/Latency](../../../Glossary.md) (Section 2.1), การเลือก storage และค่าที่ตั้งไว้ (Sections 2.2–2.3), [Wait Statistics](../../../Glossary.md) และสมการ Response Time (Section 1.4), [PLE](../../../Glossary.md) (Module 4), [Latch](../../../Glossary.md) (Module 5)
> **Permission ที่ต้องมี**: `VIEW SERVER STATE` (DMV ทุกตัวใน section นี้ระดับ server) และ `db_datareader` บน `AdventureWorks`; บล็อกที่มี `DBCC DROPCLEANBUFFERS` ต้องเป็น `sysadmin` — **VM ทดสอบเท่านั้น**

---

## ทำไม Section นี้จึงปิดท้ายโมดูล

เราเรียน "ภาษา" (2.1), "อุปกรณ์" (2.2), "การตั้งค่า" (2.3) แล้ว — Section นี้คือ **ห้องฉุกเฉิน**: เมื่อผู้ใช้พูดว่า "ระบบช้า" และ wait statistics ชี้ฝั่ง I/O (Module 1) เราต้องไล่ต่อได้ว่า

```
เห็น wait ฝั่ง I/O  ──▶  ไฟล์ไหน?  ──▶  อ่านหรือเขียน?  ──▶  ช่วงเวลาไหน?  ──▶  ต้นเหตุ: index / memory / storage?
```

เครื่องมือหลักสามชั้นที่จะฝึกใช้ตลอด section: **`sys.dm_io_virtual_file_stats`** (สะสม ต่อไฟล์), **delta snapshot** (เฉพาะช่วงเวลา — วิธีมืออาชีพ) และ **wait types ฝั่ง I/O** (เชื่อมกลับบัญชีการรอของ Module 1) ปิดท้ายด้วย playbook การไล่ต้นตอ 3 ทาง และตาราง PerfMon สำหรับ cross-check ที่ฝั่ง OS

---

## 1. เกณฑ์ Latency — จำเป็น "ตารางที่ติดกระเป๋า"

ย้ำจาก 2.1 แต่ครบทั้งช่วง ใช้กับค่าที่จะวัดต่อไปทั้งหมด:

**Data File (.mdf/.ndf):**

| avg latency | ความหมาย | ท่าทีที่ควรทำ |
|:------------|:---------|:--------------|
| < 5 ms | ยอดเยี่ยม (ระดับ SSD/NVMe) | ไม่ต้องทำอะไร — จดเป็น baseline |
| 5–20 ms | ยอมรับได้ | เฝ้าดู trend — กังวลเมื่อแนวโน้มเพิ่ม |
| > 20 ms | เริ่มมีปัญหา | ไล่ต้นตอตาม playbook หัวข้อ 5 |
| > 100 ms | วิกฤต | ผู้ใช้จะเห็น timeout/system freeze — จัดการทันที |

**Log File (.ldf):**

| avg latency (write) | ความหมาย | ท่าทีที่ควรทำ |
|:--------------------|:---------|:--------------|
| 1–5 ms | ประสิทธิภาพสูงสุด (Optimal) | ไม่ต้องทำอะไร |
| 5–10 ms | ยอมรับได้ | วางแผนปรับปรุง — นี่คือขอบเขตบนของ log |
| > 10 ms | เสื่อมสภาพ | transaction commit ช้าลงทั้งระบบ |
| > 50 ms | วิกฤต | timeout/blocking แพร่หลาย |

> [!IMPORTANT]
> ตัวเลขพวกนี้คือ "เข็มทิศ" ไม่ใช่ "กฎหมาย" — ระบบ DW ที่อ่าน scan หนัก 30 ms อาจทำงานสมบูรณ์ แต่ log ที่ 10 ms บน OLTP แฟ้มเดียวกันคือเรื่องใหญ่ จริง ๆ ที่ต้องเทียบคือ **baseline ของระบบคุณเอง** (เรียนเก็บใน Module 10)

---

## 2. `sys.dm_io_virtual_file_stats` — กล้องจุลทรรศน์ต่อไฟล์

### 2.1 โครงของ DMF

`sys.dm_io_virtual_file_stats(database_id, file_id)` — ส่ง NULL = ทุกตัว คอลัมน์ที่ใช้จริง:

| คอลัมน์ | ความหมาย | วิธีใช้ |
|:---------|:----------|:--------|
| `num_of_reads` / `num_of_writes` | จำนวน I/O สะสม | ตัวตั้งของ latency + ชี้ workload หนัก |
| `io_stall_read_ms` / `io_stall_write_ms` | ผลรวม "วินาทีที่รอ" สะสม | หารด้วยจำนวน = avg latency |
| `num_of_bytes_read/written` | จำนวน byte สะสม | หารด้วยจำนวน = **avg transfer size** (พิสูจน์ read-ahead — 2.1) |
| `io_stall` | รวมทุกอย่าง | จัดอันดับไฟล์ที่ "เจ็บที่สุด" |
| `io_stall_queued_read_ms` / `_write_ms` | เวลารอคิวที่ถูกจำกัดโดย Resource Governor I/O | ใช้เมื่อตั้ง RG ฝั่ง disk (2025: ขยายสู่ tempdb space) |
| `size_on_disk_bytes` | ขนาดใช้จริงบน disk | จับไฟล์บวม |

สิ่งที่ต้องจำติดตัว: **ทุกค่าเป็นค่าสะสมตั้งแต่ startup** — เทียบ "ตอนนี้กับเมื่อเช้า" ไม่ได้ ต้องทำ delta (หัวข้อ 3) และ `io_stall` คือผลรวมเวลาที่ task รอ — ไม่ใช่เวลานาฬิกาที่ disk ทำงาน (I/O หลายตัวทำขนานกันได้)

### 2.2 คิวรีมาตรฐาน (สไตล์ Glenn Berry — ใช้ซ้ำในแล็บ)

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

**Expected (รันจริง SQL Server 2025 RTM-GDR 17.0.1135.8, 2026-10-02):** บนสุดคือ `AdventureWorks` (ROWS) ด้วย avg_io_latency ~4 ms (อ่าน ~5 ms, เขียน ~1 ms); ไฟล์อื่นรวมทั้ง tempdb 4 ไฟล์ราว 1–2 ms — เกณฑ์: ทุกไฟล์ < 5 ms = สุขภาพดี สิ่งที่ `NULLIF(x, 0)` ทำคือกันหารศูนย์ (ไฟล์ที่ยังไม่เคยถูกอ่านจะคืน NULL ไม่ใช่ error)

### 2.3 มุมมองระดับ Drive — ตอบคำถาม "volume ไหนพัง"

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

**Expected (รันจริง, 2026-10-02):** มีแถวเดียว `C:\` — ทุกไฟล์อยู่บน DAS drive เดียว avg_latency ~1 ms ตอน idle → ~29 ms ช่วงโหลดเขียนหนักของแล็บ (ค่าโดยประมาณ ช่วงที่ VM มี workload อื่นร่วมด้วย) — บนระบบจริงที่แยก drive แล้ว มุมมองนี้ตอบทันทีว่า "volume ไหนแย่สุด" ก่อนไปเจาะระดับไฟล์

### 2.4 สิ่งที่ DMV ตัวนี้ *ไม่* เห็น — รู้ขอบเขตของเครื่องมือ

| ไม่เห็นอะไร | เหตุผล | ไปวัดที่ไหน |
|:-------------|:--------|:-------------|
| I/O ที่ไม่ผ่าน SQL Server (antivirus, OS backup, index service) | DMV นับเฉพาะของ engine | PerfMon ระดับ disk (หัวข้อ 6) |
| เพดานความสามารถของอุปกรณ์ | วัดได้เฉพาะ I/O ที่ "เคยยื่นไป" | DiskSpd (Section 2.3) |
| ละเอียดระดับ query ว่าคำสั่งใดทำ I/O | ระดับ DMF คือไฟล์ | XEvents (`file_read`/`file_write` — Module 9) |
| ค่าแยกช่วงเวลา | ค่าสะสมตั้งแต่ startup | **delta snapshot — หัวข้อถัดไป** |

ข้อสรุปสั้น ๆ: ตัวเดียวไม่พอ — เครื่องมือแต่ละตัวตอบคนละคำถาม และ "รู้ว่าตัวไหนตอบอะไร" คือความเร็วของการวินิจฉัย

---

## 3. Delta Snapshot — วิธีมืออาชีพที่แท้จริง

### 3.1 ทำไมต้อง delta

ค่าสะสมตั้งแต่ startup เหมือน "ยอดขายสะสมตั้งแต่เปิดร้าน" — บอกทรงรวมได้ แต่เราอยากรู้ "สิบนาทีที่ผ่านมาขายเป็นไง" จึงต้อง snapshot สองจุดแล้วลบกัน เหมือนเทคนิค delta ของ `sys.dm_os_wait_stats` ใน Module 1

### 3.2 สคริปต์ครบวงจร: snapshot → workload จำลอง (ทำความสะอาดตัวเอง) → snapshot → เทียบ

```sql
SET NOCOUNT ON;

/* ===== 1. Snapshot ก่อน ===== */
SELECT file_id, num_of_reads, num_of_writes, io_stall_read_ms, io_stall_write_ms
INTO #before
FROM sys.dm_io_virtual_file_stats(DB_ID(N'AdventureWorks'), NULL);

/* ===== 2. Workload เขียนจำลอง (~10 วินาที): commit ถี่ ๆ ให้เห็น WRITELOG =====
   จดค่า ModifiedDate เดิมไว้ใน #orig ก่อน แล้วคืนค่าท้าย script — ข้อมูลไม่เปลี่ยนถาวร */
SELECT SalesOrderDetailID, ModifiedDate
INTO #orig
FROM Sales.SalesOrderDetail
WHERE SalesOrderDetailID % 500 = 0;

DECLARE @i INT = 0;
WHILE @i < 60
BEGIN
    UPDATE Sales.SalesOrderDetail
    SET ModifiedDate = DATEADD(MINUTE, @i, ModifiedDate)
    WHERE SalesOrderDetailID IN (SELECT SalesOrderDetailID FROM #orig);
    SET @i += 1;
END

/* ===== 3. Snapshot หลัง ===== */
SELECT file_id, num_of_reads, num_of_writes, io_stall_read_ms, io_stall_write_ms
INTO #after
FROM sys.dm_io_virtual_file_stats(DB_ID(N'AdventureWorks'), NULL);

/* ===== 4. Delta — ค่าจริงของช่วงทดสอบเท่านั้น ===== */
SELECT mf.type_desc,
       a.num_of_reads   - b.num_of_reads   AS delta_reads,
       a.num_of_writes  - b.num_of_writes  AS delta_writes,
       CAST((a.io_stall_read_ms - b.io_stall_read_ms)
            / NULLIF(a.num_of_reads - b.num_of_reads, 0) AS DECIMAL(10,2)) AS avg_read_ms,
       CAST((a.io_stall_write_ms - b.io_stall_write_ms)
            / NULLIF(a.num_of_writes - b.num_of_writes, 0) AS DECIMAL(10,2)) AS avg_write_ms
FROM #after AS a
JOIN #before AS b ON a.file_id = b.file_id
JOIN sys.master_files AS mf
    ON mf.database_id = DB_ID(N'AdventureWorks') AND mf.file_id = a.file_id
ORDER BY mf.type_desc;

/* ===== 5. Cleanup: คืนค่า ModifiedDate เดิม + ล้าง temp tables ===== */
UPDATE sod
SET sod.ModifiedDate = o.ModifiedDate
FROM Sales.SalesOrderDetail AS sod
JOIN #orig AS o ON sod.SalesOrderDetailID = o.SalesOrderDetailID;

DROP TABLE #before; DROP TABLE #after; DROP TABLE #orig;
```

**Expected (รันจริง, 2026-10-02 — รวมเวลา ~11 วินาที):**

| type_desc | delta_reads | delta_writes | avg_read_ms | avg_write_ms |
|:----------|:------------|:-------------|:------------|:-------------|
| LOG | 0 | **480** | NULL | **1.00** |
| ROWS | 886 | 169 | 1.00 | 0.00 |

อ่านผลให้เห็นหลักการจาก 2.1 ตรง ๆ:

1. **LOG เขียน 480 ครั้ง** — 60 รอบของ UPDATE ทำให้เกิด flush ~8 ครั้งต่อรอบ (ทุก commit + เมื่อ log buffer เต็ม) และ avg 1 ms = log latency สุขภาพดี
2. **ROWS เขียน 169 ครั้ง** น้อยกว่า log มาก — เพราะ data flush ทำโดย checkpoint/lazywriter รวบก้อน ไม่ได้เขียนทุก statement
3. อ่านเยอะกว่าเขียนฝั่ง data — UPDATE ต้องค้นหาแถวก่อน (seek ผ่าน PK บน page ที่ไม่ได้อยู่ใน cache หมด)

> [!NOTE]
> บน shared server (อย่าง VM แล็บของหลักสูตร) delta อาจมีส่วนของ workload จาก session อื่นปนมา — จริง ๆ นี่คือพฤติกรรมที่อยากให้เห็น: **เมื่อระบบมีหลายผู้ใช้ ค่าที่วัดได้คือค่ารวม** การวัดแบบ isolate ทำในช่วงปิด maintenance

---

## 4. Wait Types ฝั่ง I/O — แปล "อาการรอ" ให้เป็น "ทรัพยากร"

จาก Module 1: wait stats บอกว่า task รออะไร — ตารางนี้คือแผนที่ฉบับ I/O:

| Wait | เกิดเมื่อ | แปลว่า | ท่าแรกที่ต้องทำ |
|:-----|:----------|:-------|:-----------------|
| `PAGEIOLATCH_SH` | รออ่าน data page จาก disk (แชร์ได้หลาย task) | cache miss ที่ต้องลง disk | ไล่ด้วย playbook หัวข้อ 5 |
| `PAGEIOLATCH_EX` | รอ page สำหรับเขียนทับ | เหมือนข้างบน ฝั่ง modification | เหมือนข้างบน |
| `PAGEIOLATCH_UP` | รอ page แบบ update latch (เช่นแก้ header) | พบน้อยกว่า มักพร้อมข้างบน | เหมือนข้างบน |
| `WRITELOG` | รอ flush log buffer ลง .ldf **ทุก commit** | log disk ช้า หรือ commit ถี่เกิน (micro-transactions) | ดูหัวข้อ 5.2 |
| `IO_COMPLETION` | รอ I/O ที่ไม่ใช่ data page (sort บน disk, DBCC) | งานกลุ่มเฉพาะช้า | ดูงานที่รันช่วงนั้น |
| `ASYNC_IO_COMPLETION` | รอ I/O ใหญ่ระดับ bulk (backup, bulk load) | งาน batch ช่วงนั้น | วางเวลา/จูน backup |
| `BACKUPTHREAD` | backup แย่ง I/O กับงานหลัก | backup window ชนงาน | ย้ายเวลา/จูน BUFFERCOUNT |
| `LOGBUFFER` | รอที่ว่างใน log buffer | log disk ตามไม่ทัน — หนักกว่า WRITELOG | จัดการเร็ว |

> [!WARNING]
> **แยก `PAGEIOLATCH_*` (disk จริง) ออกจาก `PAGELATCH_*` (ใน memory ล้วน ๆ)** — หลัง IO ตัวเดียวเท่านั้น! `PAGELATCH_*` สูง = การแย่ง latch ใน memory เช่น last-page insert หรือ tempdb contention (Module 5/6) — เปลี่ยน disk ไม่ช่วย

### 4.1 เห็น wait ที่กำลังเกิดขณะนี้ (ไม่ใช่ค่าสะสม)

```sql
SELECT session_id, status, wait_type, wait_time, wait_resource
FROM sys.dm_exec_requests
WHERE wait_type LIKE 'PAGEIOLATCH%' OR wait_type = 'WRITELOG';
```

**Expected:** ตอน idle คืน 0 แถว — ให้รันซ้ำ ๆ **ขณะ** workload จาก 3.2 กำลังรัน (เปิดสองหน้าต่าง) จะเห็น session ที่กำลัง SUSPENDED พร้อม `wait_resource` ที่บอกตำแหน่ง page รูปแบบ `dbid:fileid:pageid` — นี่คือสายใยเชื่อม wait กลับสู่ file stats

### 4.2 Delta ของ wait stats ฝั่ง I/O (รูปแบบเดียวกับหัวข้อ 3)

```sql
SELECT wait_type, wait_time_ms, waiting_tasks_count
INTO #w1
FROM sys.dm_os_wait_stats
WHERE wait_type IN ('PAGEIOLATCH_SH', 'PAGEIOLATCH_EX', 'PAGEIOLATCH_UP', 'WRITELOG');

WAITFOR DELAY '00:00:10';   -- ช่วงนี้คือ "หน้าต่างวัด" — ให้ workload เกิดช่วงนี้

SELECT w2.wait_type,
       w2.wait_time_ms - w1.wait_time_ms  AS delta_ms,
       w2.waiting_tasks_count - w1.waiting_tasks_count AS delta_count
FROM sys.dm_os_wait_stats AS w2
JOIN #w1 AS w1 ON w2.wait_type = w1.wait_type
WHERE w2.wait_time_ms - w1.wait_time_ms > 0
ORDER BY delta_ms DESC;

DROP TABLE #w1;
```

**Expected (รันจริง idle 10 วินาที, 2026-10-02):** เห็นเฉพาะ `WRITELOG` delta ~1 ms (background flush ราวทุกวินาทีแม้ไม่มี commit) — ค่าเล็กมากเทียบกับช่วงที่มี workload; ลองรันคู่กับ workload 3.2 แล้ว delta จะพุ่งชัด

---

## 5. Playbook การไล่ต้นตอ — สามสายเดินทางจาก wait สู่การแก้

### 5.1 `PAGEIOLATCH_*` สูง — data อ่านจาก disk เยอะหรือช้า

```
PAGEIOLATCH สูง
├── [ทาง 1] Logical reads สูงผิดปกติ?  →  เหมือนปัญหา INDEX/QUERY
│     ตรวจ: SET STATISTICS IO ของ query ร้อง / missing index DMV (M6)
│     แก้ที่: index ที่ครอบคลุม, ลด scan, SARGable — แก้ถาวรที่สุด
├── [ทาง 2] Memory pressure?          →  PLE ต่ำตลอด (M4)
│     ตรวจ: sys.dm_os_buffer_descriptors, PLE trend, lazywriter หนัก
│     แก้ที่: MAX SERVER MEMORY, เพิ่ม RAM — ทำให้ physical read ลดลง
└── [ทาง 3] Storage ช้าจริง?          →  file stats แย่ทั้งระบบแม้ logical สม่ำเสมอ
      ตรวจ: delta ต่อไฟล์ + ระดับ drive + dm_io_pending_io_requests + DiskSpd (2.3)
      แก้ที่: ย้ายไฟล์/อัปเกรด storage — แก้หลังเหลือทางเดียวจริง ๆ
```

เหตุผลที่เรียง "ทาง 1 ก่อนเสมอ": แก้ index = ลด *จำนวน* I/O (ถูกที่สุด), เพิ่ม memory = ลด *ความถี่* ที่ต้องลง disk, อัปเกรด storage = ทำให้ I/O เดิมเร็วขึ้น (แพงสุด) — ซื้อเครื่องเร็วเพื่อรองรับ query แย่ คือต้นทุนลูกค้าที่มักได้ยินเรื่องเก่าของวงการ

### 5.2 `WRITELOG` สูง — คอขวดอยู่ที่ log

| สาเหตุ | วิธียืนยัน | ทางแก้ |
|:--------|:-----------|:--------|
| Log disk ช้า/แชร์กับงานหนัก | avg_write_ms ของไฟล์ LOG (หัวข้อ 3) > 5 ms | ย้าย log ไป volume เร็วสุด (2.3) |
| Micro-transactions — commit ทีละแถว | จำนวน delta_writes ของ LOG สูงมากสัมพัทธ์กับข้อมูลที่เปลี่ยน | รวมงานเป็น batch transaction ใหญ่พอสมควร |
| Log autogrow บ่อย | `sys.dm_db_log_info` + growth settings (2.3) | ขนาดคงที่ ≤ 64 MB เพื่อ IFI (2022+) |
| Log file ถูก shrink ประจำ | งาน maintenance ที่มี SHIRINKFILE | หยุด shrink — ตั้งขนาดคงที่ (M3) |
| Latency สะสมของ .ldf โดนงาน backup ช่วงเดียวกัน | `BACKUPTHREAD` โผล่ร่วม | แยกเวลา/แยก target ของ backup |

ข้อสังเกตจากเดโมของเรา (หัวข้อ 3.2): 60 รอบ × 1 UPDATE ต่อรอบ = 60 commits → 480 log flushes ถ้าเขียนรวมเป็น 1 transaction เดียวจะได้ flush น้อยกว่ามาก — นี่คือสาธิตที่จับต้องได้ของ "micro-transactions เปลือง log I/O"

### 5.3 ใช้ทั้งสองชั้นร่วมกัน — คิวรีตรวจ "ใครกำลังรอ I/O และทำอะไรอยู่"

```sql
SELECT r.session_id, r.status, r.wait_type, r.wait_time,
       t.text AS query_text
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.wait_type LIKE 'PAGEIOLATCH%' OR r.wait_type = 'WRITELOG';
```

รันช่วงมีโหลด แล้วนำ `dbid:fileid:pageid` จาก `wait_resource` มาจับคู่กับผล file stats — ปิดวงจร "wait → ไฟล์ → ต้นเหตุ" ในคลิกเดียว

---

## 6. PerfMon — ชั้นยืนยันที่ฝั่ง OS

SQL มองไม่เห็น "สายพานทั้งเครื่อง" — เมื่อต้องยืนยันว่า storage จริง ๆ เดือด (หรือโดน process อื่นแย่ง) ให้เทียบตัวเลขฝั่ง Windows:

| Counter (PhysicalDisk / LogicalDisk) | ความหมาย | เกณฑ์โดยประมาณ |
|:--------------------------------------|:----------|:----------------|
| `Avg. Disk sec/Read` / `sec/Write` | latency ระดับ OS ต่อ I/O | ต้องสอดคล้องกับ file stats ของ SQL — เทียบกันได้ราว ms |
| `Disk Transfers/sec` | IOPS ระดับ OS | เทียบกับ num_of_reads+writes delta |
| `Disk Bytes/sec` | throughput ระดับ OS | เทียบกับเพดานที่ DiskSpd วัดไว้ (2.3) |
| `Avg. Disk Queue Length` | คิวเฉลี่ย | **อย่าใช้ตัวเดียวตัดสิน** — ค่านี้รวม I/O ขนานที่เป็นเรื่องปกติของ async I/O ด้วย |

> **จุดรอยต่อสำคัญ:** ถ้า SQL รายงาน latency 3 ms แต่ OS รายงาน 30 ms — ส่วนต่างคือ I/O ที่ไม่ผ่าน SQL (antivirus, backup ระดับไฟล์, index service — หัวข้อ 1.3 ของ 2.3) ถ้าสองฝั่งบอกตรงกันว่าแย่ — ปัญหาใน SQL หรือ storage จริง นี่คือเหตุผลที่ playbook หัวข้อ 5 ให้ cross-check ทั้งสองชั้น

**จังหวะการเก็บค่าที่แนะนำ (ฝึกทำต่อใน Module 10 — Baselines):**

| จังหวะ | เก็บอะไร | เพื่ออะไร |
|:--------|:----------|:-----------|
| หลังติดตั้ง / หลังเปลี่ยน storage | DiskSpd 3 สถานการณ์ (2.3) + file stats หนึ่งรอบ | เพดานอ้างอิงของอุปกรณ์ |
| ปกติ (ทุก 15–30 นาที ผ่านตัวเก็บอัตโนมัติ) | delta ของ wait stats + file stats | ทรงของระบบตามเวลา |
| ตอนเกิดอาการ | delta ถี่ ๆ + `sys.dm_exec_requests` | จับตัวร้ายช่วงเหตุการณ์ |

จำหลักการจาก Module 1 ไว้: ค่าเดี่ยวคือเงา, **ค่า delta ร่วมกับเวลาคือเรื่องเล่า** — และเรื่องเล่าต่างหากที่เปลี่ยนการตัดสินใจได้

---

## 7. ศึกษากรณีจบในตัว — "ระบบช้าตอนเช้า"

โจทย์: ผู้ใช้รายงาน "เข้าระบบช้าทุกวันช่วง 9:00–10:00" ทั้งที่ baseline เดิมเร็ว

1. **Module 1 — อ่าน wait ช่วงเวลานั้น:** top wait คือ `PAGEIOLATCH_SH` (ไม่ใช่ CPU/lock) → คอขวดอยู่ฝั่ง I/O อ่าน
2. **หัวข้อ 2–3 ของ section นี้:** delta snapshot ช่วง 9:00 → ไฟล์ `data` ของ DB ขายของ avg_read 58 ms (baseline 4 ms) — ไฟล์เดียว ไม่ใช่ทั้ง volume → ไม่ใช่ hardware ทั้งชุดพัง
3. **หัวข้อ 4.1:** จับ `sys.dm_exec_requests` ช่วงเดียวกัน → query กลุ่มเดียวกัน (report ที่เริ่ม 9:00 ตามตาราง) เป็นผู้รอ
4. **Playbook ทาง 1:** `SET STATISTICS IO` ของ report → logical reads 3.2 ล้าน pages เพราะ index missing → สร้าง covering index (M6)
5. **วัดซ้ำ:** อีกวัน avg_read กลับมา 5 ms, `PAGEIOLATCH_SH` หลุดจาก top 3 — ปิดเคสโดยไม่ซื้อ disk ใหม่แม้แต่ลูกเดียว

ข้อสรุปทางวิธีคิด: **wait บอกทิศ → file stats ชี้เป้า → playbook เลือกทาง → วัดซ้ำยืนยัน** — เดินตามสายนี้ได้ คุณก็ทำงานตาม Top-down framework ที่ Module 11 จะยกระดับต่อไป

---

## สรุป Section 2.4

1. เกณฑ์กระเป๋า: **data > 20 ms = จู่โจม, log > 5–10 ms = จู่โจม** — แต่ตัวเทียบจริงคือ baseline ของระบบเอง
2. `sys.dm_io_virtual_file_stats` ให้ latency + transfer size ต่อไฟล์ — ทุกค่า **สะสมตั้งแต่ startup** จึงต้องทำ **delta snapshot** เสมอ
3. `PAGEIOLATCH_*` = รอ data page จาก disk (ต่างจาก `PAGELATCH_*` ที่อยู่ใน memory); `WRITELOG` = รอ log flush ทุก commit; `IO_COMPLETION`/`ASYNC_IO_COMPLETION`/`BACKUPTHREAD` = งานกลุ่มเฉพาะ
4. Playbook PAGEIOLATCH: **ลด logical reads (index) → เพิ่ม memory (PLE) → อัปเกรด storage** — เรียงตามความคุ้ม
5. WRITELOG สูง: log disk ช้า, micro-transactions, autogrow/shrink รัว ๆ — แก้ที่การออกแบบไม่ใช่ที่ cache
6. ชั้นวัดสองชั้นต้องไปด้วยกัน: DMV ของ SQL (ต่อไฟล์) + PerfMon ของ OS (ทั้งเครื่อง) — ค่าที่ต่างกันบอกเรื่อง "ผู้บุกรุก" ค่าที่ตรงกันบอกเรื่อง storage

### ตรวจความเข้าใจ

1. ทำไมการเทียบ latency กับ "เมื่อเช้านี้" จึงไม่ถูกต้อง และต้องทำอย่างไรแทน?
2. `PAGEIOLATCH_SH` สูงแต่ PLE ปกติดีและ logical reads ต่ำ — ทางไหนของ playbook ที่เหลืออยู่ และจะยืนยันด้วยเครื่องมืออะไร?
3. ระบบเขียน 200 แถว/วินาทีโดยแต่ละแถวเป็น 1 transaction — wait ใดจะสูงและเพราะอะไร? ปรับการเขียนอย่างไรโดยไม่เสีย durability?
4. `PAGELATCH_EX` กับ `PAGEIOLATCH_EX` ต่างกันอย่างไร — ใคร "เปลี่ยน disk แล้วหาย" ใคร "เปลี่ยน disk แล้วเฉย"
5. SQL รายงาน latency 3 ms แต่ PerfMon ฝั่ง OS รายงาน 30 ms บน disk เดียวกัน — ข้อสังเกตนี้ชี้ไปที่ใคร และกลุ่ม process ใดที่มักเป็นตัวปัญหา?
6. ในเดโม delta snapshot (หัวข้อ 3.2) เหตุใด delta_writes ของ LOG (480) จึงมากกว่า ROWS (169) อย่างมีนัยสำคัญ ทั้งที่ workload แก้ข้อมูลเท่ากันทุกครั้ง?

**➡ ถัดไป:** [Module 03 — Database Structures](../../Module_03_Database_Structures/README.md)

---

[⬅ ก่อนหน้า: 2.3 IO Setup Best Practices](../03_IO_Setup_Best_Practices/README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [Module 03](../../Module_03_Database_Structures/README.md)
