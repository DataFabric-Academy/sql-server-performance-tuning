[⬅ Module 02](../../README.md) | [2.2 Storage Solutions](../02_Storage_Solutions/README.md) | Section 3/4 | ➡ ถัดไป: [04 Monitoring Troubleshooting IO](../04_Monitoring_Troubleshooting_IO/README.md)

# 2.3 I/O Setup & Best Practices — วางไฟล์ ฟอร์แมตดิสก์ และตั้งค่าที่ "แก้ยากถ้าทำผิด"

> *"ในโลก performance มีบางการตัดสินใจที่ทำซ้ำได้ทุกวัน — แต่อีกกลุ่มหนึ่งถ้ากด Enter ผิด คุณจะต้องอยู่กับมันทั้งชีวิตของระบบ"*

> **ต้องรู้มาก่อน**: [IOPS/Throughput/Latency](../../../Glossary.md) และ [Page (8 KB)](../../../Glossary.md) (Section 2.1), สถาปัตยกรรม DAS/NAS/SAN + RAID (Section 2.2), [TempDB](../../../Glossary.md), [Log File / VLF](../../../Glossary.md), [DMV / DMF](../../../Glossary.md)
> **Permission ที่ต้องมี**: บล็อก T-SQL ใน section นี้อ่านอย่างเดียว — ใช้ `VIEW SERVER STATE` + `VIEW DATABASE STATE`; คำสั่งระดับ OS (`diskspd`, `fsutil`, Local Security Policy) ต้องเป็น Administrator **บน VM ของคุณโดยตรง**

---

## ทำไม Section นี้จึงเป็น "หมวดที่แก้ยาก"

การจูน query ทำซ้ำได้ทุกวัน แต่หมวดนี้คือการตัดสินใจที่ **ประเภท "Irreversible"** — ทำตอนติดตั้งแล้วเปลี่ยนต้องเจ็บ:

| การตัดสินใจ | แก้ทีหลังต้องทำอะไร |
|:------------|:---------------------|
| Partition alignment / Allocation Unit Size | format volume ใหม่ + restore database ทั้งก้อน |
| วาง data/log/tempdb ที่ volume ไหน | offline database, copy ไฟล์ก้อนเท่าไหร่ก็ได้, online กลับ |
| Instant File Initialization (IFI) | แก้สิทธิ์ OS + **restart SQL Server service** |
| จำนวน/ขนาด tempdb data files | ต้อง restart บางเคส (เพิ่มไฟล์ไม่ต้อง แต่ลด/ปรับจำนวนแรกเริ่มต้อง) |
| ขนาดไฟล์และ file growth setting | แก้ได้ง่าย — **แต่ผลกระทบ (VLF, autogrow stall) สะสมเงียบ ๆ** |

วิธีสอนของ section นี้: เรียงจาก "ชั้นล่างสุด (ฟอร์แมตดิสก์) → ชั้นกลาง (การวางไฟล์) → ชั้นบน (การตั้งค่า SQL)" แล้วปิดท้ายด้วยเครื่องมือพิสูจน์พื้นที่ — **DiskSpd** ซึ่งต้องรันบน VM โดยตรง

---

## 1. ชั้นล่างสุด: Partition Alignment และ Allocation Unit Size

### 1.1 Partition Alignment

- ต้องให้ตำแหน่งเริ่ม partition (offset) ตรงกับขอบ physical sector/stripe ของอุปกรณ์ ไม่งั้นทุก I/O จะ "คร่อม" แถวกายภาพสองแถว → ทุกคำสั่งเปลือง I/O เกินจริง
- ข่าวดี: **Windows Server 2008 ขึ้นไป align ให้เอง (1 MB)** — ระบบใหม่แทบไม่มีปัญหา แต่ต้องรู้จักไว้เพราะดิสก์ที่มาจาก migration เก่า ๆ / disk image คัดลอกมายังตรวจเจอได้

ตรวจบน VM ของคุณ (Command Prompt as Administrator — **รันระดับ OS ตรง ๆ เท่านั้น ไม่ใช่ใน SSMS**):

```bat
fsutil fsinfo ntfsinfo C: | findstr /i "Bytes Per Sector Bytes Per Physical Alignment"
```

ดูค่า `Partition Starting Offset` (จาก PowerShell: `Get-Partition`) ต้องหารด้วย 1,048,576 (1 MB) ได้ลงตัว

### 1.2 Allocation Unit Size (Block Size) — จัดเต็ม 64 KB

- SQL Server ทำ I/O เป็น **extent = 64 KB (8 pages)** ตามที่เรียนใน 2.1 ถ้า NTFS block เล็กกว่า (default 4 KB) หนึ่ง extent จะกระจายเป็น 16 ชิ้นใน file system ก่อนถึง disk
- ฟอร์แมตเป็น **64 KB** ทำให้ 1 extent = 1 block ของ NTFS พอดี ลด overhead ของ file system และเพิ่ม throughput ได้ราว 10–20% ในหลายกรณี (ตัวเลขที่ผู้ติดตั้งใช้เป็นเกณฑ์ยอมรับกัน)
- ข้อยกเว้นที่รู้ไว้: volume ที่เก็บไฟล์ "จิ๋วล้วน" (เช่น home directory) 64 KB จะเปลืองพื้นที่ — แต่ volume ของ SQL Server เต็มไปด้วยไฟล์ใหญ่จึงไม่มีข้อเสียเลย

ฟอร์แมตตอนเตรียม volume (ระวัง — ล้างข้อมูล! ใช้กับ volume ใหม่เท่านั้น):

```bat
format D: /FS:NTFS /Q /A:64K /Y
```

> [!NOTE]
> **VM ทดสอบของหลักสูตรมี drive เดียว (C:) ซึ่งเป็น volume ระบบ** — อย่า reformat! ให้ตรวจค่า AUS ที่มีอยู่ด้วย `fsutil fsinfo ntfsinfo C:` (ดูค่า `Bytes Per Cluster`) เพื่อฝึกอ่าน แล้วเก็บขั้นตอนฟอร์แมตไว้ใช้กับ volume ใหม่จริง

### 1.3 เสียงรบกวนระดับ OS ที่แย่งสายพาน I/O

การตั้งค่า storage ดีแค่ไหนก็ช่วยไม่ได้ ถ้ามี "ผู้ไม่ได้รับเชิญ" มาแย่ง:

| ผู้บุกรุก | ทำอะไร | การจัดการ |
|:----------|:-------|:-----------|
| Antivirus real-time scan | สแกน .mdf/.ldf ทุกครั้งที่เปิด/เขียน — latency พุ่งสุ่ม ๆ | ยกเว้นไฟล์/โฟลเดอร์ของ SQL Server ตามคำแนะนำ Microsoft |
| Windows Search/Indexing | อ่านไฟล์ทั่ว volume เป็นรอบ ๆ | ปิดกับ volume ของ database |
| Backup software ระดับไฟล์ (ตัวอื่น) | snapshot/copy ไฟล์ mdf ขณะร้อน | ให้ใช้ backup ของ SQL Server เป็นทางเดียว |
| Windows Update กลางวัน | ดาวน์โหลด+ติดตั้งแย่ง I/O ทั้งเครื่อง | จัดหน้าต่างเวลา maintenance |

ข้อสังเกตที่เกี่ยวกับ VM ของหลักสูตร: drive เดียวทำให้ผลของ "ผู้บุกรุก" เหล่านี้สะท้อนทันทีใน latency ที่ SQL เห็น — ตอนเราวัดใน 2.4 หากเห็น spike แปลก ๆ ที่ไม่มี workload ของ SQL รองรับ ให้นึกถึงตารางนี้ก่อนสรุปว่า storage ช้า

---

## 2. ชั้นกลาง: File Placement — ใครควรอยู่ house ไหน

### 2.1 ตารางมาตรฐาน

| ไฟล์ | Volume ที่ควรอยู่ | เหตุผล (จาก 2.1) |
|:-----|:------------------|:------------------|
| **Data (.mdf/.ndf)** | SSD/NVMe, RAID 10, แยกจาก log | random read — ต้องการ IOPS + latency ต่ำ |
| **Log (.ldf)** | แยก volume จาก data, เร็วสุด | sequential write **ทุก commit** — latency คือชีวิต |
| **TempDB** | แยกจาก data/log จริง (SSD/RAID 0 ได้) | กิจกรรมถี่และ "ขยะ" — ต้องไม่แย่งสายพานกับข้อมูลจริง |
| **Backup** | อย่างน้อยคนละ volume กับ data, เป้าหมายสุดท้ายคืออีกเครื่อง/คลาวด์ | backup บน volume เดียวกับ data = สูญเสียสองต่อพร้อมกัน |
| **OS + SQL binaries** | แยกจาก data/log (RAID 1 ก็พอ) | ไม่ต้องเร็ว แต่อย่าให้ OS แย่ง I/O กับ database |

ภาพเป้าหมาย (สมมติมีงบพอ):

```
┌─────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐
│ C: (RAID 1) │  │ D: (RAID 10  │  │ E: (NVMe     │  │ F: (RAID 10 │
│ OS +        │  │ SSD)         │  │ RAID 0/10)   │  │ หรือ HDD)   │
│ SQL Binary  │  │ Data .mdf/   │  │ Log .ldf +   │  │ Backup +    │
│             │  │ .ndf         │  │ TempDB       │  │ Archive     │
└─────────────┘  └──────────────┘  └──────────────┘  └─────────────┘
   ความจุเล็ก       IOPS หนักสุด       latency ต่ำสุด       throughput พอ
```

### 2.2 เมื่อมี drive เดียว (สภาพแวดล้อมแล็บ/VM เล็ก)

บน VM ของหลักสูตรทุกอย่างอยู่บน C:\ เดียว — เป็นข้อจำกัดจริง แต่ไม่ใช่ข้ออ้างให้ลืมหลักการ:

1. **ยังคงต้องแยก logical file** อย่างถูกต้อง (data/log ต่างไฟล์, tempdb ต่างฐานข้อมูล) — เพราะเมื่อวันหนึ่งย้าย volume จะต้องทำเพียง `ALTER DATABASE ... MODIFY FILE` ไม่ต้อง rebuild อะไร
2. เข้าใจว่า latency ที่วัดได้คือ **ค่ารวมของทุกผู้ใช้สายพานเดียวกัน** — เวลาเห็น WRITELOG/PAGEIOLATCH สูงตอนมี workload หนัก นั่นคือการแย่งกันจริง ๆ ที่เราจะเห็นใน 2.4
3. เกณฑ์ตัดสินว่า "จำเป็นต้องแยก volume จริงไหม" คือการวัด — ถ้า latency ของ data กับ log ไม่ขัดกัน (ทั้งคู่ต่ำสม่ำเสมอ) การแยกแบบบังคับก็ยังเป็น best practice เพื่อความปลอดภัยในอนาคต ไม่ใช่ยาวิเศษทันที

---

## 3. Multiple Data Files — ให้ตัวเลขก่อนตามกระแส

### 3.1 เมื่อไรถึงควรแยก data file หลายไฟล์

| เหตุผลที่ถูกต้อง | คำอธิบาย |
|:-----------------|:----------|
| Database ใหญ่มาก | ไฟล์หลายตัวกระจายได้หลาย volume → read-ahead ขนานข้ามอุปกรณ์ |
| จัดพื้นที่ทีละขั้น | ขยายเพิ่มไฟล์บน volume ว่างใหม่ ไม่ต้องขยายไฟล์เดิมก้อนโต |
| ข้อจำกัดขนาดไฟล์ยุคเก่า | NTFS เก่า/อุปกรณ์เก่ามีเพดานขนาด — ยุคปัจจุบันแทบไม่เจอ |

### 3.2 กลไกที่ต้องเข้าใจ: Proportional Fill

SQL Server กระจาย allocation ไปยังไฟล์ **ตามสัดส่วนพื้นที่ว่าง** — ไฟล์ใหญ่กว่าได้โอกาสมากกว่า ดังนั้น:

- ทำไฟล์ให้ **ขนาดเท่ากัน** ถ้าตั้งใจให้กระจายเท่า ๆ กัน (ไฟล์ที่เท่ากันถูกใช้เท่ากัน)
- ไฟล์หนึ่งถูกขยาย manual ใหญ่กว่าเพื่อน = มันจะกินงานหนักกว่าโดยดีไซน์

### 3.3 TempDB — กฎที่สถาบันยืนยัน

- เริ่มต้นด้วย **จำนวน data file เท่ากับ logical processor แต่ไม่เกิน 8** — หากเจอ PAGELATCH (not PAGEIO!) contention ต่อให้เพิ่มไฟล์ทีละ 4 จนหาย (คู่กับ trace flag ยุคเก่า ไม่ต้องแล้ว — SQL 2016+ setup จัดการให้: เห็น 8 ไฟล์เริ่มต้นเสมอเมื่อ CPU ≥ 8)
- ไฟล์ทุกตัว **ขนาดเท่ากัน + growth เท่ากัน** — ไม่งั้น proportional fill พัง
- SQL 2019+: เปิด **Memory-Optimized TempDB Metadata** ลด latch contention ของ system tables (cross-ref Module 3); SQL 2025: tempdb space governance ผ่าน Resource Governor, ADR ใน tempdb และ tmpfs บน Linux

ตรวจสอบสภาพจริงทั้งสองระดับ (อ่านอย่างเดียว):

```sql
-- 1) TempDB มี data file กี่ตัว ขนาด/growth เท่ากันหรือไม่
SELECT name, type_desc, (size * 8) / 1024 AS size_mb,
       CASE is_percent_growth WHEN 1 THEN CAST(growth AS VARCHAR(5)) + '%'
                              ELSE CAST(growth * 8 / 1024 AS VARCHAR(10)) + ' MB' END AS growth_setting
FROM tempdb.sys.database_files
ORDER BY file_id;
GO
-- 2) จำนวน data/log file ต่อ database ทั้ง instance (มุมมองการกระจาย)
SELECT DB_NAME(database_id) AS database_name,
       SUM(CASE WHEN type_desc = 'ROWS' THEN 1 ELSE 0 END) AS data_files,
       SUM(CASE WHEN type_desc = 'LOG'  THEN 1 ELSE 0 END) AS log_files
FROM sys.master_files
GROUP BY DB_NAME(database_id)
ORDER BY database_name;
```

**Expected (รันจริง, 2026-10-02):** TempDB มี **4 data files** (tempdev–temp4) ขนาดเท่ากัน **72 MB ทุกไฟล์** growth 64 MB แบบ MB — บน VM 4 vCPU ถือว่าผ่านเกณฑ์ (≤ 8) และ "เท่ากันทุกไฟล์" ทำให้ proportional fill ทำงานถูกต้อง; `AdventureWorks` มี data file ตัวเดียว + log ตัวเดียว ซึ่งเป็นขนาดที่เหมาะสมสำหรับ database 264 MB — อย่าแยกไฟล์เฉพาะเพราะเห็นคนอื่นทำ

### 3.4 ข้อผิดพลาดยอดฮิตในระบบจริง

| อาการที่เจอ | ต้นเหตุ | ทางออกที่ถูก |
|:-------------|:--------|:--------------|
| tempdb มี 16 ไฟล์บนเครื่อง 8 cores | เชื่อคำพูด "ยิ่งเยอะยิ่งดี" | min(CPU, 8) — เพิ่มเมื่อเห็น PAGELATCH contention จริง |
| Autogrowth ทุกไฟล์ 1 MB | ค่า default เดิมของ model รุ่นเก่า | ตั้ง MB คงที่ตามหัวข้อ 5.1 |
| Log file ตั้ง "shrink ทุกคืน" เป็นงาน maintenance | เข้าใจว่า log เล็ก = ดี | shrink ทำให้ VLF แตกและ growth ซ้ำ — ตั้งขนาดคงที่ที่เหมาะกับ peak (M3) |
| Data + log + backup บน volume เดียว | ประหยัดงบ | แยกอย่างน้อย backup ออกก่อน — มิฉะนั้น "ดิสก์พังครั้งเดียว หายทั้งต้นฉบับและสำรอง" |

---

## 4. Instant File Initialization (IFI) — ข้ามการ "เขียนศูนย์" ตอนขยายไฟล์

### 4.1 ปัญหาและกลไก

```
ปกติ (ไม่มี IFI):
  สร้าง/ขยายไฟล์ 10 GB → Windows เขียน 0 ทุกไบต์ (Zeroing) เพื่อกันข้อมูลเก่าหลุด
                       → ใช้เวลานานเท่าการเขียน 10 GB จริง → autogrow ค้าง query ที่ทำให้เกิด

มี IFI:
  SQL Server (service account ที่ได้สิทธิ์) ข้าม zeroing → ไฟล์พร้อมใช้เกือบทันที
  (data file เท่านั้น — จนกระทั่ง SQL 2022 log growth เล็ก ๆ ได้ประโยชน์บางส่วน ดู 4.2)
```

- ต้องให้สิทธิ์ **Perform Volume Maintenance Tasks** แก่ service account (Local Security Policy → User Rights Assignment) แล้ว **restart SQL Server service**
- เครื่องมือ setup รุ่นใหม่ (ตั้งแต่ SQL 2016 Setup เป็นต้นมา และในหน้า "Use recommended settings") เปิดให้ได้ตอนติดตั้ง — เป็นค่า default ในสภาพแวดล้อมปัจจุบัน
- Trade-off ด้าน security เล็กน้อย: ส่วนที่ไม่เคยเขียนจริงของไฟล์อาจมีข้อมูลเก่าค้างบน disk — ทีมส่วนใหญ่ยอมรับได้เพราะประโยชน์ (autogrow ไม่แขวน query) มากกว่า

### 4.2 SQL Server 2022+: ขยาย log ได้ถึง 64 MB ก็เร็วขึ้น

- ธรรมชาติของ log คือต้อง zero เสมอ (เพื่อความถูกต้องของ recovery) — **แต่ SQL 2022+ ให้ autogrowth ของ log ที่ ≤ 64 MB ได้ประโยชน์จาก IFI ด้วย**
- ผลทางปฏิบัติ: ตั้ง log autogrowth เป็น 64 MB (หรือน้อยกว่า) จะไม่โดน stall แรง ๆ ตอนขยาย — ส่วนการขยายก้อนใหญ่กว่านั้นยังต้อง zero เหมือนเดิม

### 4.3 ตรวจว่า IFI เปิดหรือยัง (บน build ที่ทดสอบ)

```sql
SELECT servicename,
       instant_file_initialization_enabled AS ifi_enabled   -- 'Y' / 'N'
FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server (%';                      -- เอาเฉพาะ engine ไม่รวม Agent
```

**Expected (รันจริง SQL Server 2025 RTM-GDR 17.0.1135.8, 2026-10-02):** คืน `Y` — IFI เปิดอยู่

> [!WARNING]
> สูตรเก่า `SERVERPROPERTY('IsInstantFileInitializationEnabled')` **คืนค่า NULL บน build ที่ทดสอบ (17.0.1135.8)** เราทดสอบแล้วพบจริง — ให้ใช้คอลัมน์ `instant_file_initialization_enabled` ของ `sys.dm_server_services` แทน หรือถ้าจะยืนยันท้ายสุดให้ดู error log ตอน restore/สร้างไฟล์ใหญ่ว่ามีข้อความ zeroing หรือไม่

ตรวจฝั่ง OS (บน VM ของคุณ, Administrator): Local Security Policy → Local Policies → User Rights Assignment → **Perform volume maintenance tasks** ต้องมี service account (เช่น `NT Service\MSSQLSERVER`) อยู่ในรายการ — ดูใครเป็น service account ได้จาก `sys.dm_server_services` คอลัมน์ `service_account`

---

## 5. File Growth และ VLF — ตั้งให้ "โตเป็นเหตุการณ์เล็ก"

### 5.1 กฎ

| การตั้งค่า | แนะนำ | เหตุผล |
|:-----------|:------|:-------|
| ขนาดตั้งต้น data/log | ประเมินจาก workload 1–2 ปี ตั้งล่วงหน้า | ไม่ให้ชีวิตเริ่มต้นด้วย autogrow ตั้งแต่วันแรก |
| Autogrowth data | เป็น MB คงที่ (64–256 MB สำหรับ DB ขนาดกลาง) | ตัวเลขทำนายได้, ไม่แขวนนาน |
| Autogrowth log | เป็น MB คงที่ (แนะนำ ≤ 64 MB เพื่อรับประโยชน์ IFI บน 2022+) | หัวข้อ 4.2 |
| Percent growth | **หลีกเลี่ยง** — ไฟล์โตแล้วขยายแบบทวีคูณ (10% ของ 200 GB = 20 GB ต่อครั้ง!) | แต่ละครั้งคือแขวนและ fragmentation ของ VLF |

### 5.2 VLF — ผลพวงของ growth ที่คนมองข้าม

Transaction log ภายในถูกตัดเป็นช่วง ๆ เรียก **VLF** (cross-ref Module 3 — ตรวจด้วย `sys.dm_db_log_info` แทน `DBCC LOGINFO` ที่ถูกเลิก):

- growth ถี่ ๆ ทีละน้อย ๆ → VLF จำนวนมากมากเกินไป → recovery/startup ช้า
- growth ครั้งละมโหฬาร (percent growth บนไฟล์ใหญ่) → VLF ก้อนยักษ์ → log truncation ทำงานไม่คล่อง

ดูของจริง:

```sql
SELECT file_id, COUNT(*) AS vlf_count
FROM sys.dm_db_log_info(DB_ID(N'AdventureWorks'))
GROUP BY file_id;
```

**Expected (รันจริง, 2026-10-02):** log ของ `AdventureWorks` มี **6 VLFs** — สมเหตุผลกับ database ขนาด ~136 MB ที่ growth 64 MB บ่อยครั้งไม่มาก อ่านเกณฑ์การตีความต่อใน Module 3 (บท Database Structures)

ตรวจ growth settings ของฐานข้อมูลหลักที่ใช้เรียน:

```sql
SELECT name, type_desc, (size * 8) / 1024 AS size_mb,
       CASE is_percent_growth WHEN 1 THEN CAST(growth AS VARCHAR(5)) + '%'
                              ELSE CAST(growth * 8 / 1024 AS VARCHAR(10)) + ' MB' END AS growth_setting
FROM sys.database_files;
```

**Expected (รันจริง, 2026-10-02):** ทั้ง data (264 MB) และ log (136 MB) ตั้ง growth แบบ **64 MB** ไม่ใช่ percent — ตรงตาม best practice ของหัวข้อนี้ (data growth 64 MB ต่ำกว่าคำแนะนำ 64–256 MB เล็กน้อยสำหรับ DB ที่โตเร็ว แต่คาดการณ์ได้และไม่เป็นอันตราย)

---

## 6. DiskSpd — พิสูจน์เพดานของ storage ด้วยมือคุณเอง

### 6.1 อะไรที่ DMV ตอบไม่ได้

`sys.dm_io_virtual_file_stats` วัด *I/O ที่ SQL Server เคยยื่นไป* — มันไม่สามารถบอกได้ว่า **เพดานของ storage คือเท่าไร** และไม่สามารถทดสอบ storage ที่ยังไม่ได้ใช้ (ก่อนซื้อ/ก่อน deploy) เครื่องมือมาตรฐานคือ **DiskSpd** (microsoft/diskspd) — SQLIO ถูกยกเลิกทั้งหมดแล้ว ไม่ต้องอ้างอิงอีกต่อไป

> [!IMPORTANT]
> **DiskSpd เป็น EXE ระดับ VM — ต้องรันใน Command Prompt/PowerShell บนเครื่อง VM โดยตรง** รันผ่าน remote session ของเครื่องอื่นไม่ได้ และในสภาพแวดล้อมแล็บของหลักสูตรนี้ ผู้สอนจะไม่รันระหว่าง demo (มันสร้างโหลดจริงบน drive ที่ SQL Server กำลังใช้) — ผู้เรียนรันเองตามขั้นตอนด้านล่าง ตั้งเวลาสั้น ๆ (30–60 วินาที) และเลือกเวลาที่ไม่มีงานอื่น

### 6.2 การเตรียม + คำสั่ง 3 สถานการณ์

DiskSpd ใช้ได้จาก [github.com/microsoft/diskspd](https://github.com/microsoft/diskspd) (หรือตัวที่แนบมากับ 10987 Lab02: `Trainer_Docs/10987/Labfiles/Lab02/Diskspd-v2.0.15/amd64fre/diskspd.exe`) — หลักการ: สร้างไฟล์ทดสอบก่อน (`-c`) เพื่อไม่ให้เวลาสร้างไฟล์ปนมาในผลวัด แล้วรันตาม pattern ของงานจริง:

```bat
:: [0] เตรียมไฟล์ทดสอบ 2 GB (ไฟล์ว่างที่ถูก pre-allocate)
fsutil file createnew C:\Temp\sqltest.dat 2147483648

:: [1] OLTP: 8 KB random, read 70% / write 30%, 2 threads, queue depth 8, 30 วินาที
diskspd -c2G -d30 -r -w30 -t2 -o8 -b8K -Sh -h C:\Temp\sqltest.dat

:: [2] Log / bulk load: 64 KB sequential write 100%
diskspd -c2G -d30 -s -w100 -t1 -o8 -b64K -Sh -h C:\Temp\logtest.dat

:: [3] Data warehouse: 512 KB sequential read 100%
diskspd -c2G -d30 -s -w0 -t2 -o8 -b512K -Sh -h C:\Temp\dwtest.dat

:: ลบไฟล์ทดสอบหลังจบ
del C:\Temp\sqltest.dat C:\Temp\logtest.dat C:\Temp\dwtest.dat
```

| ตัวเลือก | ความหมาย | หมายเหตุ |
|:---------|:---------|:---------|
| `-c2G` | สร้างไฟล์ทดสอบ 2 GB | ควรใหญ่กว่า RAM cache ของ storage |
| `-d30` | ทดสอบ 30 วินาที | ตั้งสั้นไว้ก่อนบน shared VM |
| `-r` / `-s` | Random / Sequential | ตาม pattern จาก 2.1 |
| `-w30` / `-w100` / `-w0` | สัดส่วน write | OLTP ~30%, log 100%, อ่านล้วน 0% |
| `-t2` / `-o8` | จำนวน thread / queue depth ต่อ target | queue depth ต่ำเกิน → IOPS ต่ำกว่าของจริง (2.1 หัวข้อ 1.4) |
| `-b8K` / `-b64K` / `-b512K` | ขนาด block | จับคู่กับ "ใครคือลูกค้า" ของ volume นี้ |
| `-Sh` | ปิด software + hardware write cache | **วัดของจริงที่ SQL จะได้รับ** — ไม่งั้นได้ตัวเลขฝันจาก cache |
| `-h` | ปิด warmup ที่คล้าย SQL Server / ปิด SSE | ใช้คู่กับ -Sh ตามคู่มือ |

### 6.3 อ่านผลลัพธ์

ท้ายรายงานจะมีบล็อก `total` — จับสามค่า: **IOPS, MB/s, avg latency (ms)** และเทียบกับเกณฑ์ของ 2.1. รูปร่างของผล (ย่อจากเอกสารของเครื่องมือ):

```text
Total IO
| thread |  bytes     |     I/Os    |  MiB/s  |  IOPs   |  AvgLat(ms) |
|--------|-----------:|------------:|--------:|--------:|------------:|
| total  |  346030080 |       42240 |   11.00 | 1408.00 |        5.67 |

latency distribution: 25th=2.1  50th=4.3  75th=7.2  90th=12.8  99th=31.5 (ms)
```

สามจุดที่มืออาชีพดูนอกเหนือจากค่าเฉลี่ย: (1) **99th percentile latency** บอก "คนที่โชคร้ายที่สุดรอนานแค่ไหน" — avg ดีแต่ 99th แย่ = เป็นพัก ๆ มี stall (2) **IOPS × block size = MB/s** — เช็คความสอดคล้องของเลขกันเสมอ (3) ถ้า avg latency กระโดดตาม queue depth ที่ตั้ง (`-o`) แปลว่าอุปกรณ์ถึงเพดานแล้ว — ลองลด/เพิ่ม `-o` เทียบภาพ

เกณฑ์ตัดสินผ่าน/ไม่ผ่านต่อสถานการณ์:

| ผลจากสถานการณ์ | ผ่านเกณฑ์เมื่อ |
|:----------------|:---------------|
| [1] 8K random IOPS | > 5,000 (SSD ปกติ) — latency < 5–10 ms |
| [2] 64K seq write latency | < 5 ms (เกณฑ์ log) |
| [3] 512K seq throughput | สูงกว่าสถานการณ์ [1] หลายเท่า (สมบัติของ sequential) |

**เทคนิคพิสูจน์ความเชื่อมโยง:** ขณะที่ DiskSpd กำลังรัน ให้เปิด SSMS อีกหน้าต่างรัน `sys.dm_io_virtual_file_stats` (2.4) ระดับ drive ซ้ำ ๆ — ถ้า DiskSpd รายงาน 5 ms แต่ฝั่ง SQL เห็น 100 ms แปลว่าปัญหาอยู่ที่ **คิว/การแย่งของ SQL** ไม่ใช่ disk หรือถ้าอยากแยกปัญหา network ออกจาก disk ก็รัน diskspd บน UNC path เทียบกับ local path

### 6.4 ตัวสร้างคำสั่งในแล็บ

สคริปต์ `Sections/03_IO_Setup_Best_Practices/Scripts/03_Diskspd_Stress_Test.sql` ของโมดูลนี้เป็น *generator* — รันใน SSMS แล้วมัน `PRINT` คำสั่ง diskspd สามสถานการณ์พร้อม drive/ขนาดที่คุณกำหนด ให้ copy ไปรันที่ VM — เห็นไหมว่าแม้เครื่องมือระดับ OS ก็จัดระเบียบด้วย T-SQL ได้ (เฉพาะส่วน "สร้างข้อความ" เท่านั้น)

---

## 7. Checklist ก่อน Production

- [ ] Volume ของ data/log/tempdb: NTFS **AUS 64 KB**, partition aligned (1 MB)
- [ ] **แยก log ออกจาก data** ใน volume ที่เร็วที่สุด; tempdb แยกเช่นกัน
- [ ] RAID: data/log = 10 (หรือคำนวณ write penalty แล้วยอมรับได้), tempdb = 0/SSD, backup คนละ volume
- [ ] **IFI เปิด** — สิทธิ์ Perform Volume Maintenance Tasks + ตรวจด้วย `sys.dm_server_services`
- [ ] Autogrowth ทุกไฟล์เป็น **MB คงที่** (log ≤ 64 MB บน 2022+), ไม่มี percent growth
- [ ] TempDB: data files = min(CPU, 8), ขนาด/growth เท่ากันทุกไฟล์
- [ ] **DiskSpd benchmark ครบ 3 สถานการณ์ + เก็บเป็น baseline** ก่อนวาง workload จริง
- [ ] เก็บค่า latency ต่อไฟล์ (`sys.dm_io_virtual_file_stats`) ตั้งแต่วันแรกเป็นตัวตั้งต้นของการเปรียบเทียบ

---

## สรุป Section 2.3

1. การตัดสินใจหมวดนี้ **Irreversible** — ฟอร์แมต, การวางไฟล์, IFI: ทำผิดแล้วแก้ด้วยการ restore ทั้งระบบ
2. ฟอร์แมตชั้นล่าง: partition align 1 MB (Windows จัดให้) + **AUS 64 KB** ให้ตรง extent — ลด overhead 10–20%
3. วางไฟล์ตาม pattern: **log = เร็วสุดแยกสายพาน, tempdb = แยกและเกิดใหม่ได้, backup = อยู่คนละบ้านกับ data**; บน drive เดียวก็ยังต้องแยก "logical file" ให้พร้อมย้าย
4. Multiple data files มีเหตุผลจริง แต่อย่าใช้แบบขอโมงเช้า — proportional fill ทำงานตามพื้นที่ว่าง ไฟล์ต้องเท่ากัน; **TempDB = min(CPU, 8) ไฟล์**
5. **IFI ข้ามการ zeroing** — สิทธิ์ Perform Volume Maintenance Tasks; SQL 2022+ log autogrowth ≤ 64 MB ได้ประโยชน์ด้วย; ตรวจด้วย `sys.dm_server_services` (ไม่ใช่ SERVERPROPERTY ที่คืน NULL บน 2025)
6. Growth แบบ MB คงที่ + ดู VLF ด้วย `sys.dm_db_log_info` — ป้องกันทั้ง autogrow stall และ VLF พันลึก
7. **DiskSpd** = เครื่องมือมาตรฐานยืนยันเพดาน storage (SQLIO เลิกใช้แล้ว) — รันบน VM ตรง ๆ 30–60 วินาทีต่อสถานการณ์ ปิด cache ด้วย `-Sh` เพื่อวัดของจริง

### ตรวจความเข้าใจ

1. เพราะเหตุใด Allocation Unit Size 64 KB จึง "เข้าคู่" กับ SQL Server โดยธรรมชาติ — อ้างอิงหน่วย I/O จาก Section 2.1
2. ผู้ดูแลระบบตั้ง tempdb เป็น 12 ไฟล์แต่ไฟล์แรกใหญ่กว่าเพื่อน 11 ไฟล์สองเท่า — กลไกใดทำให้การกระจายงานไม่เท่ากัน และจะแก้อย่างไร?
3. IFI ช่วยเรื่องอะไร "ขณะเกิดเหตุ" — อธิบายว่าเกิดอะไรขึ้นกับ query ที่ trigger autogrow เมื่อไม่มี IFI
4. บน SQL Server 2022+ เหตุใดจึงแนะนำ log autogrowth ≤ 64 MB?
5. ผล DiskSpd แสดง IOPS 120,000 ที่ `-b512K` — คำนวณ throughput (MB/s) และบอกว่างานประเภทใดชอบรูปแบบนี้
6. `SERVERPROPERTY('IsInstantFileInitializationEnabled')` คืน NULL บน VM ทดสอบของหลักสูตร — จะตรวจสถานะ IFI อย่างถูกวิธีบน build นี้ได้อย่างไร?

**➡ ถัดไป:** [2.4 Monitoring & Troubleshooting I/O — วัดของจริงและไล่คอขวด Storage](../04_Monitoring_Troubleshooting_IO/README.md)

---

[⬅ ก่อนหน้า: 2.2 Storage Solutions](../02_Storage_Solutions/README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [04 Monitoring Troubleshooting IO](../04_Monitoring_Troubleshooting_IO/README.md)
