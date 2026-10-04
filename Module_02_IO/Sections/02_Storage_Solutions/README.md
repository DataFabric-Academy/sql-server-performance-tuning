[⬅ Module 02](../../README.md) | [2.1 I/O Core Concepts](../01_IO_Core_Concepts/README.md) | Section 2/4 | ➡ ถัดไป: [03 IO Setup Best Practices](../03_IO_Setup_Best_Practices/README.md)

# 2.2 Storage Solutions — เลือกบ้านให้ข้อมูล: DAS, NAS, SAN และ Object Storage

> *"Query แย่ที่สุดในโลกก็ช้าไม่ได้ ถ้าข้อมูลอยู่ใน memory — และ query ดีที่สุดในโลกก็เร็วไม่ได้ ถ้าอยู่บน storage ที่ตอบสนองเป็นนาที"*

> **ต้องรู้มาก่อน**: [IOPS/Throughput/Latency](../../../Glossary.md) (Section 2.1 — ตีความตัวเลขทุกตัวใน section นี้), [Page (8 KB)](../../../Glossary.md), [TempDB](../../../Glossary.md), [Log File / VLF](../../../Glossary.md), [DMV / DMF](../../../Glossary.md)
> **Permission ที่ต้องมี**: `VIEW SERVER STATE` (สำหรับ `sys.dm_os_volume_stats`, `sys.dm_io_virtual_file_stats`) และ `db_owner`/`sysadmin` เฉพาะบล็อก `BACKUP DATABASE` (ซึ่งเขียนลงอุปกรณ์ NUL: เท่านั้น)

---

## ทำไม Section นี้จึงสำคัญ

Section 2.1 สอน "ภาษา" ที่ใช้วัด storage แล้ว — Section นี้สอน **"ตลาดสินค้า"**: เทคโนโลยีเก็บข้อมูลแต่ละชนิดมีเพดาน IOPS/Throughput/Latency ต่างกันมาก ราคาต่างกันมาก และเหมาะกับงานต่างกัน คนจูนที่ดีต้องตอบสองคำถามนี้ได้:

1. workload ของเรา *ต้องการ* อะไรจาก storage (IOPS? Throughput? Latency แบบไหน?)
2. เทคโนโลยีที่มีอยู่/กำลังจะซื้อ *มอบ* อะไรได้ ด้วยเงินเท่าไร

ทั้งสองคำถามต้องมองพร้อมกัน — ซื้อ SAN แพง ๆ แล้ววาง data file บน LUN RAID 5 ก็เหมือนซื้อรถ F1 ไปวิ่งสายที่มีไฟแดงทุก 200 เมตร

เส้นทางของ Section:

1. **ลำดับชั้นสื่อจัดเก็บ** — HDD → SSD → NVMe → PMEM และตัวเลขจริงของแต่ละชั้น
2. **สถาปัตยกรรมการเชื่อมต่อ** — DAS, NAS (SMB), SAN (FC/iSCSI)
3. **RAID เจาะลึก** — write penalty และการเลือก level
4. **Windows Storage Spaces** — software RAID ของ Windows
5. **Cloud & Object Storage** — Azure managed disks และ S3-compatible (SQL Server 2022+: **Backup/Restore เท่านั้น**) พร้อมเดโม ZSTD ของ SQL Server 2025
6. **ตารางตัดสินใจ** — จับคู่ workload กับ storage

---

## 1. ลำดับชั้นของสื่อจัดเก็บ — ความเร็ว, ราคา, ความคงทน

```
เร็ว/แพง  ▲  CPU Registers / L1-L3 Cache
          │  ───────────────────────────────
          │  DRAM (Buffer Pool)             ← SQL Server ทำงานที่นี่ให้มากที่สุด
          │  ───────────────────────────────
          │  PMEM (Persistent Memory)       ← ความเร็วใกล้ DRAM + ข้อมูลอยู่รอด
          │  ───────────────────────────────
          │  NVMe SSD (PCIe, U.2/M.2)       ← ตัวเลือกยอดนิยมของ data/log ปัจจุบัน
          │  ───────────────────────────────
          │  SATA/SAS SSD                   ← เหมาะ data ทั่วไป, tempdb รอง
          │  ───────────────────────────────
          │  HDD 15K/10K (จานหมุน)          ← archive, backup แบบเรียงลำดับ
          │  ───────────────────────────────
ช้า/ถูก    ▼  Tape / Cloud Archive (เช่น S3 Glacier)
```

| สื่อ | Latency โดยทั่วไป (random 4–8 KB) | ลักษณะเด่น | เหมาะกับไฟล์ |
|:-----|:----------------------------------|:-----------|:-------------|
| **HDD** (จานหมุน 10K/15K) | ~5–10 ms | ถูกต่อ TB, sequential ได้ดี, random แย่มาก (มี seek time) | backup, archive |
| **SATA/SAS SSD** | ~0.1–1 ms | ไม่มีชิ้นหมุน, IOPS สูงกว่า HDD หลายสิบเท่า | data ทั่วไป, tempdb |
| **NVMe SSD** (PCIe) | ~0.02–0.1 ms | ต่อตรงกับ PCIe, ข้าม SATA controller, IOPS แสน–ล้าน | data/log ที่เข้มข้น, tempdb |
| **PMEM** (Persistent Memory) | ~0.001 ms (ใกล้ DRAM) | ใช้กับ Hybrid Buffer Pool ของ SQL Server | workload เฉพาะทาง, ฮาร์ดแวร์ล้ำ |

> **สังเกตช่องว่างที่ข้าม 1,000 เท่า:** DRAM → NVMe ต่างกัน ~10–100 เท่า แต่ NVMe → HDD ต่างกันอีก ~100 เท่า นี่คือเหตุผลที่ "ย้ายจาก HDD ไป SSD" ให้ผลกระโดดมากกว่า "อัปเกรด SSD รุ่นใหม่เสมอ" และเป็นที่มาของคำแนะนำ "อ่านค่า latency ให้รู้ว่าอยู่ชั้นไหนของบันได" ใน 2.4

---

## 2. DAS (Direct-Attached Storage) — ติดตรงกับ server

Storage ที่เสียบอยู่กับตัว server โดยตรง (disk ในเคส, การ์ด HBA + shelf ติดกัน, NVMe บนเมนบอร์ด)

| ด้าน | รายละเอียด |
|:-----|:-----------|
| **Pros** | ซับซ้อนต่ำสุด · ไม่มีเครือข่ายมาคั่น → latency ต่ำสุด ควบคุมง่ายสุด · ราคาต่อ IOPS ถูกสุด |
| **Cons** | ขยายยาก (ถูกจำกัดด้วยช่องเสียบ) · แชร์ให้ server อื่นไม่ได้ → ไม่รองรับ Failover Cluster Instance ระดับ shared disk · มองเห็นเฉพาะเจ้าของ |
| **ใช้เมื่อ** | standalone server, VM, ระบบเล็ก–กลางที่เครื่องเดียวพอ |

> **VM ทดสอบของหลักสูตรคือ DAS แบบสุดขั้ว:** มี drive เดียว (C:\) ทั้ง OS, ไฟล์ SQL Server, data, log และ tempdb อยู่บนพื้นที่เดียวกัน — ดีต่อการเรียน (เห็นการแย่งกันของ I/O ได้จริง) แต่เป็นตัวอย่างตรงข้ามของ "file placement" ที่จะสอนใน 2.3

---

## 3. NAS (Network-Attached Storage) — แชร์ผ่าน SMB

File server ที่เปิดพื้นที่ให้เข้าถึงผ่านเครือข่ายแบบ **file-level** (SMB 3.0 ขึ้นไป)

| ด้าน | รายละเอียด |
|:-----|:-----------|
| **รูปแบบ** | SQL Server เห็นเป็น UNC path เช่น `\\fileserver\share\AdventureWorks.mdf` — วาง data/log บน SMB share ได้ (SQL Server 2012+ สำหรับ standalone; รองรับ FCI ด้วย SMB 3.0+ feature Availability) |
| **Pros** | ติดตั้ง/บริหารง่ายกว่า SAN · แชร์พื้นที่ได้ · ราคาย่อมเยา |
| **Cons** | latency รวม network stack เข้าไปด้วย · bandwidth แชร์กับงานอื่นบน LAN · ต้องคุมเวอร์ชัน SMB และสิทธิ์ให้ถูก |
| **ใช้เมื่อ** | เน้น cost-effective, workload ไม่รุนแรง, หรือวางไฟล์ชั่วคราว/backup บน share |

> **ตัววัดสำคัญของ NAS คือ latency ของ SMB ทั้งเส้นทาง** — วัดได้ที่เดียวกับ storage ทั่วไป: `sys.dm_io_virtual_file_stats` จะ "โกหกไม่ได้" แม้ไฟล์จะอยู่บน share (เรียนใน 2.4)

ข้อควรตั้งค่าบนฝั่ง Windows ที่ใช้ SMB เป็นที่วาง data/log:

- **ปิด write cache ฝั่ง client ของ share** (`New-SmbMapping -UseWriteThrough $true` หรือ registry `SmbClientWriteThrough`) — มิฉะนั้น Windows อาจ "ตอบเขียนสำเร็จ" ก่อนข้อมูลถึง server จริง ซึ่งล่อแหลมกับ WAL
- เปิด **SMB Multichannel** ถ้า NIC เยอะ — รวม bandwidth หลายการ์ดได้โดยไม่แตะ SQL ฝั่งใด
- อ่านสเปกและ**ทดสอบจริงเสมอ**: NAS บางรุ่น (เช่นแบบพยุง NAS appliance) ออกแบบมาเพื่อ SQL ได้จริง บางรุ่นเป็น file server ทั่วไปที่ "เห็นเป็น drive ได้" แต่ latency และ consistency ไม่ผ่าน — วัดด้วยเกณฑ์ของ 2.1 ก่อนตัดสิน

---

## 4. SAN (Storage Area Network) — เครือข่ายพิเศษแบบ block-level

เครือข่ายเฉพาะ (Fibre Channel / iSCSI) ที่ server เห็นพื้นที่มาเป็น **LUN = block device** เหมือนมี disk ในเคสตัวเอง

| ด้าน | รายละเอียด |
|:-----|:-----------|
| **Pros** | แชร์พื้นที่หลาย server (รองรับ **Failover Cluster Instance**) · snapshot/replication/DR ระดับอุปกรณ์ · ขยายได้กว้าง · มี QoS/พอร์ตเฉพาะ |
| **Cons** | แพงที่สุด · ซับซ้อน (ต้องจัดการ fabric, zoning, MPIO/multipath) · มักเป็น shared pool → เกิดปัญหา **Noisy Neighbor** ได้ถ้า neighbor บน pool เดียวกันยิง I/O หนัก |
| **ใช้เมื่อ** | ระบบ mission-critical, ต้อง HA/DR ระดับ shared storage, ศูนย์ข้อมูลมีทีม storage จริง |

> **โจทย์คลาสสิกของ SAN:** ค่า latency ที่ SQL เห็น = ผลรวมของ *drive ตัวเอง + fabric + controller + drive ของคนอื่นบน pool* — เมื่อ latency พุ่งโดยที่ workload ของเราไม่เปลี่ยน ให้สงสัย noisy neighbor และยื่นเรื่องกับทีม storage พร้อมหลักฐานจาก `sys.dm_io_virtual_file_stats`

> **ข้อควรรู้เรื่องเส้นทาง:** SAN จริงจังต้องตั้ง **MPIO/multipath** ให้เส้นทางสำรองพร้อมอยู่เสมอ และ iSCSI ที่วิ่งบน LAN ธรรมดาควรแยก VLAN/ NIC เฉพาะ — เพราะเมื่อเส้นทางเดียวหรือแชร์สายกับงานอื่น "SAN เร็ว" ก็แปลงร่างเป็นคอขวดได้ทันที ตรวจเส้นทางที่ฝั่ง OS (แล็บของโมดูลนี้รัน DiskSpd ที่ฝั่ง OS เพื่อแยกปัญหาชั้นเครือข่ายออกจากชั้น SQL — ดู 2.3 หัวข้อสุดท้าย)

---

## 5. RAID เจาะลึก — Write Penalty คือหัวใจ

RAID รวม disk หลายลูกเป็นปริมาตรเดียว ทั้งเพิ่มความเร็ว (แบ่งงาน) และ/หรือความทนทาน (สำรอง/parity) สิ่งที่คนมักข้ามคือ **การเขียนไม่ฟรีเท่าอ่าน**:

```
การเขียน 1 บล็อก บน RAID 5 (read-modify-write):
  1. อ่าน data block เดิม          ┐
  2. อ่าน parity block              ├── 4 I/O จริง แทนที่จะเป็น 1
  3. เขียน data block ใหม่          │   (Write Penalty = 4x)
  4. เขียน parity ใหม่ (คำนวณ XOR)  ┘

RAID 10: เขียน 2 ที่ (mirror สองฝั่ง) → Write Penalty = 2x
```

| RAID Level | Read I/O | Write Penalty | ทนขาดกี่ลูก | ประสิทธิภาพเขียน | ใช้กับ SQL Server |
|:-----------|:--------:|:--------------|:------------|:-----------------|:-------------------|
| **RAID 0** (stripe) | 1 | 1 | 0 (พังลูกเดียวพังทั้งชุด) | ดีสุด | ✅ **TempDB** เท่านั้น — เกิดใหม่ได้ทุก restart |
| **RAID 1** (mirror) | 1 | 2 | 1 | ดี | ✅ OS, SQL binaries |
| **RAID 5** (parity) | 1 | **4** | 1 | แย่ | ⚠️ อ่านเยอะเขียนน้อยเท่านั้น — หลีกเลี่ยงกับ OLTP/log |
| **RAID 6** (double parity) | 1 | **6** | 2 | แย่มาก | ⚠️ archive ขนาดใหญ่เท่านั้น |
| **RAID 10** (mirror+stripe) | 1 | **2** | ต่อ 1 ลูกในแต่ละคู่ | ดี | ✅ **Best practice ของ data/log ที่เขียนหนัก** |

> [!WARNING]
> **RAID 5/6 กับ log file คือคู่ต้องสาป:** log เขียนต่อเนื่องทุก commit และต้อง latency ต่ำ (1–5 ms) — คูณ write penalty 4–6 เท่าบน log แปลว่าทุก transaction จ่าย I/O แพงขึ้นทันที และ latency ก็แย่ตาม ยกเว้นเดียวที่ RAID 0 อนุญาตคือ tempdb เพราะสร้างใหม่ได้เสมอ

> **จุดเชื่อมโยงกับยุคใหม่:** SSD/NVMe เร็วจน write penalty แทบตายช้ากว่าเดิม ระบบใหม่จึงใช้ RAID 5/6 บน SSD สำหรับบางงานได้ — แต่หลักคิดยังเหมือนเดิม: *คำนวณ I/O จริงที่ต้องจ่ายแล้วเทียบกับเพดานของอุปกรณ์* อย่าเชื่อ "SSD แล้วอะไรก็ได้"

### 5.1 Windows Storage Spaces — software RAID ของ Windows

ถ้าไม่มีการ์ด/HW RAID ก็มีทางเลือกระดับ OS:

| แนวคิด | ความหมาย | เทียบเท่า |
|:--------|:---------|:----------|
| **Physical Disks → Storage Pool** | รวม disk หลายลูกเป็นก้อนใหญ่ | เตรียมวัตถุดิบ |
| **Virtual Disk แบบ Simple** | แตกข้าม disk ไม่มีสำรอง | RAID 0 |
| **Virtual Disk แบบ Mirror** | 2-way/3-way mirror | RAID 1/10 |
| **Virtual Disk แบบ Parity** | เก็บ parity แบ่งกระจาย | RAID 5 |

- *Simple* ไม่มี redundancy (เหมาะ tempdb) · *Mirror* ใช้กับ data/log ได้ · *Parity* เหมาะ archive — เหมือนตาราง RAID ด้านบนทุกประการ
- ระดับที่สูงขึ้นคือ **Storage Spaces Direct (S2D)** สำหรับ cluster — นอกขอบเขตหลักสูตรนี้

### 5.2 คำนวณ IOPS Budget ตัวอย่างจบในตัว — จาก workload สู่การออกแบบ

สมมติ OLTP ชั่วโมงเร่ง: 2,000 transaction/วินาที, ทุก transaction เขียน log flush 1 ครั้ง (~16 KB) และแก้ข้อมูล 2 pages (dirty) + อ่าน random 6,000 page/วินาที บน RAID 10 HDD 15K (เพดาน ~200 IOPS ต่อลูก):

```
ฝั่ง log (RAID 10 → penalty 2x):
   2,000 flush × 2 = 4,000 write IOPS  → ต้องการ ~20 ลูก HDD!

ฝั่ง data (RAID 10):
   อ่าน 6,000 (penalty 1x) + เขียน dirty 4,000 × 2 = 14,000 IOPS
   → ต้องการเพิ่มอีก ~70 ลูก HDD (รวมเกือบ 90 ลูก — ไม่จริงได้)

สลับเป็น NVMe (~500,000 IOPS ต่อลูก):
   log 4,000 + data 14,000 = 18,000 IOPS → ลูกเดียวก็จุ (แถม latency ลด 100 เท่า)
```

บทเรียนสามข้อ: (1) **write penalty ทำให้ "จำนวน IOPS ที่ต้องซื้อ" บวมขึ้นทันที** (2) **log คือรายที่แพงที่สุดต่อ transaction** (3) ตัวเลขพวกนี้ตรวจย้อนกลับด้วยการวัดจริง — `sys.dm_io_virtual_file_stats` ให้ num_of_reads/writes ต่อไฟล์ (2.4) และ DiskSpd ยืนยันเพดานของอุปกรณ์ (2.3) — ไม่ต้องเดา

---

## 6. Cloud Storage — Azure Managed Disks และ Object Storage

### 6.1 Block storage บนคลาวด์ (VM disk)

Managed disk ของ Azure คือ block storage แบบ DAS จากมุมมอง SQL Server — แยก tier ตามเพดาน IOPS/MB/s:

| Tier | ตัวลักษณะ | ใช้กับ |
|:-----|:----------|:-------|
| Standard HDD / SSD | ถูก, latency ~ms–สิบ ms | dev/test, งานเบา |
| Premium SSD | IOPS/MB/s จองต่อ disk (เช่น P30 ขึ้นไป) | data/log production |
| Premium SSD v2 / Ultra | ปรับ IOPS/MBps/ขนาด **อิสระจากกัน** latency ต่ำมาก (sub-ms ได้) | log file, workload เข้ม |
| Ephemeral OS/temp disk | บน host เครื่องนั้น ข้อมูลหายเมื่อ move/resize | **tempdb** เท่านั้น |

ข้อพิจารณาเดียวกับ on-prem ทุกประการ: *อ่านเพดานต่อ disk, แยก data/log ให้ได้ IOPS คนละก้อน, และวัด latency จริงจาก `sys.dm_io_virtual_file_stats`* — คลาวด์ไม่เปลี่ยนกฎ

> **PMEM / Hybrid Buffer Pool:** บนฮาร์ดแวร์ที่มี Persistent Memory SQL Server สามารถเปิด **Hybrid Buffer Pool** — เข้าถึง data page ที่อยู่บน PMEM โดยตรงผ่าน bypass เลขคณิตแบบ copy ทุกครั้ง ทำให้ "disk ที่เก็บ data" มีความเร็วระดับ memory เทียบเท่าในเคสจำกัด (วัดสเกลของ workload ก่อนลงทุน — PMEM แพงและค่อย ๆ จำกัดทางเลือกในอนาคต จึงเหมาะกับเคสเฉพาะทางมากกว่าทั่วไป)

### 6.2 S3-Compatible Object Storage (SQL Server 2022+) — ข้อจำกัดสำคัญที่ต้องจำ

SQL Server 2022 เพิ่มการรองรับ **S3-compatible Object Storage** (เช่น AWS S3, MinIO, ผู้ให้บริการที่ยึด S3 API) แต่มีขอบเขตที่ผู้เรียนมักเข้าใจผิด:

> [!IMPORTANT]
> **S3 ใช้กับ Backup/Restore เท่านั้น** — ผ่าน `BACKUP TO URL` / `RESTORE FROM URL` ไปยัง S3-compatible endpoint
> - ❌ ไม่รองรับการวาง **Data/Log file** บน Object Storage ผ่าน S3 API
> - การวาง data file บน Azure Blob เป็นฟีเจอร์ **"SQL Server data files in Azure"** — คนละฟีเฟอร์ ไม่ได้ทำงานผ่าน S3 API
> - Object storage เก็บแบบ object (ไม่มี random page access แบบ block storage) — ธรรมชาติของมันจึงเหมาะกับไฟล์ทั้งก้อน เขียนครั้งเดียว อ่านทีหลัง

**Use case ที่ถูกต้อง:** ที่เก็บ backup ราคาประหยัด, สำเนาสำรองระยะยาว, DR copy ต่างภูมิภาค

รูปแบบคำสั่ง (อ้างอิงเอกสาร Microsoft — รันได้เมื่อมี S3 endpoint จริงและ credential ครบ ไม่ใช่สภาพแวดล้อมแล็บของเรา):

```text
-- สร้าง credential แบบ S3 (สรุปรูปแบบ — ต้องมี endpoint/credential จริง)
CREATE CREDENTIAL [s3://myendpoint:443/backups]
WITH IDENTITY = 'S3 Access Key',
     SECRET = '<access_key_id>:<secret_key>';

BACKUP DATABASE AdventureWorks
TO URL = 's3://myendpoint:443/backups/AdventureWorks_full.bak';
```

### 6.3 SQL Server 2025: ZSTD Backup Compression — ลดภาระ I/O ช่วง backup

SQL Server 2025 เพิ่มอัลกอริทึมบีบอัด **ZSTD** ให้ backup — เร็วกว่าและได้อัตราบีบดีกว่า MS_XPRESS เดิม ช่วยลดข้อมูลที่ต้องผ่านสายพาน I/O/เครือข่ายตอน backup/restore

เดโมนี้ **รันได้บน VM ทดสอบทุกเครื่อง** โดยเขียนลงอุปกรณ์ `NUL:` (Windows discards ข้อมูล — ไม่เกิดไฟล์จริง ไม่ต้อง cleanup) เพื่อวัด throughput ของ backup+compression โดยไม่เปลืองพื้นที่:

```sql
BACKUP DATABASE AdventureWorks
TO DISK = 'NUL:'          -- ทิ้งข้อมูลทันที: ใช้วัด throughput บน VM ทดสอบเท่านั้น
WITH COMPRESSION (ALGORITHM = ZSTD), STATS = 50;
```

**Expected (รันจริง SQL Server 2025 RTM-GDR 17.0.1135.8, 2026-10-02):**

```
50 percent processed.
100 percent processed.
Processed 30488 pages for database 'AdventureWorks', file 'AdventureWorks' on file 1.
Processed 15 pages for database 'AdventureWorks', file 'AdventureWorks_log' on file 1.
BACKUP DATABASE successfully processed 30503 pages in 1.360 seconds (175.221 MB/sec).
```

อ่านผลอย่างเข้าใจ: DB ขนาด ~264 MB (30503 pages × 8 KB) ผ่านสายพาน 175 MB/s ใน 1.36 วินาที — ตัวเลข MB/s นี้คือ *throughput ของ backup engine + storage รวมกัน* ใช้เทียบ "ก่อน/หลังเปลี่ยน ALGORITHM หรือ MAXTRANSFERSIZE/BUFFERCOUNT" ได้ (ทดลองเพิ่ม `ALGORITHM = MS_XPRESS` เทียบกันได้บน VM เดียวกัน)

> [!WARNING]
> `NUL:` คือ **ไม่มีไฟล์ backup จริงเกิดขึ้น** — ห้ามใช้บน production มิฉะนั้นจะเชื่อว่า backup สำเร็จทั้งที่ไม่มีอะไรเก็บไว้เลย ใช้เฉพาะเพื่อการทดสอบวัดประสิทธิภาพบน VM

---

## 7. ตารางตัดสินใจ — เลือกให้เป็น

| เกณฑ์ | DAS | NAS (SMB) | SAN (FC/iSCSI) | Object Storage (S3) |
|:------|:----|:----------|:---------------|:--------------------|
| Latency ที่ SQL เห็น | ต่ำสุด | ต่ำ–กลาง (+LAN) | ต่ำ–กลาง (+fabric) | **สูงมาก (วินาทีระดับ** — ไม่ใช่ page I/O) |
| แชร์ระหว่าง server | ไม่ได้ | ได้ | ได้ (shared LUN → FCI) | ได้ (แต่ backup เท่านั้น) |
| รองรับ FCI | ✖ (บางแบบ ✖) | ✅ (SMB 3.0+) | ✅ | ✖ |
| ราคาต่อ IOPS | ถูกสุด | กลาง | แพงสุด | ถูกต่อ GB แต่ไม่ใช่สำหรับ IOPS |
| งานที่เหมาะสุด | standalone/VM ทั่วไป | budget + งานเบา | mission-critical, HA/DR | backup ระยะยาว |

และจับคู่กับไฟล์ของ SQL Server (ย้ำจาก 2.1):

| ไฟล์ | ที่ควรอยู่ |
|:-----|:-----------|
| Data (.mdf/.ndf) — random read | SSD/NVMe, RAID 10 (หรือ SSD-era RAID ที่คำนวณแล้ว), เส้นทาง latency ต่ำสุด |
| Log (.ldf) — sequential write ทุก commit | **เร็วที่สุดที่ซื้อได้** — NVMe/Ultra disk, RAID 10, ห้าม RAID 5/6 |
| TempDB — เกิดใหม่ได้ | แยกออกจาก data จริง, RAID 0/SSD เร็ว, บนคลาวด์คือ ephemeral disk |
| Backup — เขียนครั้งเดียวอ่านยาก ๆ | HDD/cheap disk/object storage ได้ละหมด |

### 7.1 กรณีศึกษาสั้น 3 บริษัท — คำตอบไม่ซ้ำกัน

**บริษัท A — POS ร้านค้า 40 สาขา (standalone, เขียนไม่หนัก):** DAS SSD เครื่องเดียว RAID 10 + backup ไป NAS ตัวเดียวกันทุกคืน · งบน้อย, ไม่ต้อง FCI — เกินความจำเป็นไปซื้อ SAN

**บริษัท B — E-commerce OLTP 5,000 TPS, ห้ามหยุด:** SAN NVMe แยก LUN data/log, RAID 10 ทั้งคู่, ตั้ง FCI สองโหนด · backup ส่งต่อ S3-compatible endpoint เก็บ 90 วัน (ใช้ ZSTD ประหยัดพื้นที่และเวลา) · จ่ายแพงตรงที่ "ห้ามหยุด" ไม่ใช่ที่ "ห้ามช้า"

**บริษัท C — Data warehouse โหลด batch กลางคืน:** bulk load ใหญ่ทุกคืน (Eager Write — 2.1) + query อ่าน scan หนัก → เน้น **throughput** มากกว่า IOPS: storage sequential แรง, RAID 6 บน SSD รับได้ (เขียนครั้งเดียวต่อ batch), tempdb แยก SSD เร็วเพราะ sort/spill เยอะ

### 7.2 แผนผังตัดสินใจ — ถามตัวเองจากบนลงล่าง

```
เก็บ "ไฟล์ database ที่รันทุกวัน" หรือ "ไฟล์ต้องเก็บนานเขียนครั้งเดียว"?
├── เก็บนาน (backup/archive) ──────────▶ HDD / Object Storage (S3: backup เท่านั้น)
└── ไฟล์รันทุกวัน
    ├── ต้องแชร์พื้นที่ให้หลาย server ไหม?
    │   ├── ไม่ ────▶ DAS ที่เร็วที่งบไหว (NVMe ก่อน, SSD รอง)
    │   └── ต้อง (FCI/cluster)
    │       ├── งบจำกัด + งานไม่หนัก ─▶ NAS SMB 3.0+ (ทดสอบ latency ก่อนซื้อ)
    │       └── mission-critical ─────▶ SAN + RAID 10 + multipath
    └── ไฟล์ที่สร้างใหม่ได้เสมอ (tempdb) ─▶ แยก volume, RAID 0/SSD เร็ว, ephemeral
```

แผนผังนี้ใช้ได้ทั้งตอนออกแบบระบบใหม่และตอนรีวิวระบบเก่า — ทุกกิ่งสุดท้ายจบด้วยหน้าที่เดียวกันคือ **วัด latency จริงและเก็บเป็น baseline** (2.4) เพราะสถาปัตยกรรมที่เลือกดีแต่ตั้งค่าผิดก็แพ้สถาปัตยกรรมธรรมดาที่ตั้งค่าถูก

---

## 8. วัดของจริงบน VM ของเรา

อย่าเชื่อแผ่นพับสินค้า — วัดของจริงด้วย DMV สองตัวนี้ (ทุกคำสั่งอ่านอย่างเดียว):

```sql
-- พื้นที่จริงของ volume ที่ไฟล์ทุก database อาศัยอยู่
SELECT DISTINCT
       vs.volume_mount_point AS drive,
       vs.total_bytes    / 1024 / 1024 / 1024 AS total_gb,
       vs.available_bytes / 1024 / 1024 / 1024 AS free_gb,
       CAST(100.0 * vs.available_bytes / vs.total_bytes AS DECIMAL(5,1)) AS pct_free
FROM sys.master_files AS mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs
ORDER BY drive;
```

**Expected (รันจริง, 2026-10-02):** บน VM ของหลักสูตรจะเห็นแถวเดียว — `C:\` ~49 GB total, free ~7 GB (15.4%) — ยืนยันว่าทุกไฟล์ทุก database อาศัย DAS drive เดียว

```sql
-- ขนาด I/O เฉลี่ยต่อครั้งของแต่ละไฟล์ — บอกว่า "เปลี่ยนนิสัย" ไปทางไหน
SELECT DB_NAME(vfs.database_id) AS database_name,
       mf.type_desc,
       vfs.num_of_reads, vfs.num_of_writes,
       CASE WHEN vfs.num_of_reads = 0 THEN 0
            ELSE vfs.num_of_bytes_read / vfs.num_of_reads / 1024 END AS avg_kb_per_read,
       CASE WHEN vfs.num_of_writes = 0 THEN 0
            ELSE vfs.num_of_bytes_written / vfs.num_of_writes / 1024 END AS avg_kb_per_write
FROM sys.dm_io_virtual_file_stats(DB_ID(N'AdventureWorks'), NULL) AS vfs
JOIN sys.master_files AS mf
    ON mf.database_id = vfs.database_id AND mf.file_id = vfs.file_id;
```

**Expected (รันจริงหลังเดโมชุดของ 2.1, 2026-10-02):**

| type_desc | num_of_reads | num_of_writes | avg_kb_per_read | avg_kb_per_write |
|:----------|:-------------|:--------------|:----------------|:-----------------|
| ROWS (data) | 1,659 | 701 | **204** | 18 |
| LOG | 11 | 1,654 | 101 | **25** |

อ่านผล: ฝั่ง data อ่านเฉลี่ย 204 KB ต่อครั้ง — มากกว่า 8 KB ถึง 25 เท่า นั่นคือ **read-ahead กำลังรวมคำขอเป็นก้อนใหญ่** ตามที่เรียนใน 2.1 (Scatter-Gather) ฝั่ง log เขียนเฉลี่ย 25 KB ต่อ flush — เป็น sequential append ตามทฤษฎี สังเกตว่า *ตัวเลขจริงช่วยยืนยันพฤติกรรมที่ตำราพูดไว้* ซึ่งเป็นวิธีเรียนรู้ที่เราใช้ตลอดหลักสูตร

---

## สรุป Section 2.2

1. บันไดสื่อจัดเก็บ: HDD → SSD → NVMe → PMEM แตกต่างกัน 100 เท่าต่อชั้น — **ย้าย HDD ขึ้น SSD ให้ผลกระโดดที่สุด**
2. **DAS** เร็ว/ถูก/ง่ายแต่ไม่แชร์ · **NAS (SMB)** ประหยัดแต่รวม latency ของ LAN · **SAN** ทรงพลังและแชร์ได้ (FCI) แต่แพงและมีเรื่อง noisy neighbor
3. **RAID: อ่านฟรี เขียนไม่ฟรี** — RAID 5/6 เสีย write penalty 4–6 เท่า (ห้ามกับ log/OLTP เขียนหนัก) · RAID 10 = 2 เท่า · RAID 0 เหลือใช้กับ **TempDB เท่านั้น**
4. **S3-compatible Object Storage (SQL 2022+) รองรับเฉพาะ Backup/Restore ผ่าน `BACKUP TO URL`** — ไม่วาง data/log ผ่าน S3 API ได้ และ Azure Blob data files เป็นคนละฟีเจอร์
5. SQL Server 2025 เพิ่ม **ZSTD backup compression** — เดโมวัด throughput ผ่าน `NUL:` ได้บน VM (175 MB/s บนสภาพแวดล้อมทดสอบ)
6. อย่าเชื่อใบสเปก: วัดจริงด้วย `sys.dm_os_volume_stats` (พื้นที่) และ `sys.dm_io_virtual_file_stats` (latency + ขนาด transfer จริงต่อไฟล์)

### ตรวจความเข้าใจ

1. Workload OLTP เขียนหนักกำลังจะถูกวางบน LUN RAID 6 — อธิบายด้วย write penalty ว่าเกิดอะไรขึ้นกับ latency ของ transaction log
2. เหตุใด RAID 0 จึงอนุญาตให้ใช้กับ TempDB ได้โดยฝ่าฝืนกฎ "ห้ามไม่มี redundancy" — เงื่อนไขคืออะไร?
3. `sys.dm_io_virtual_file_stats` ของไฟล์บน SMB share พุ่งจาก 2 ms เป็น 45 ms โดย workload คงที่ — เส้นทางที่ต้องสงสัยมีอะไรบ้าง?
4. จริงหรือเท็จ: "วาง data file ของ SQL Server 2022 บน AWS S3 ได้เพราะ SQL Server รองรับ S3 แล้ว" — ขอคำอธิบายที่แม่นยำ
5. Backup ด้วย ZSTD ไปที่ `NUL:` ได้ 175 MB/s — ค่านี้ตอบคำถามอะไร และ *ไม่* ตอบคำถามอะไร?
6. Noisy Neighbor บน SAN ทำให้เห็นอาการอย่างไรที่ฝั่ง SQL Server และใช้หลักฐานใดจาก DMV ในการยื่นเรื่องกับทีม storage?

**➡ ถัดไป:** [2.3 I/O Setup & Best Practices — วางไฟล์ ฟอร์แมตดิสก์ และตั้งค่าที่แก้ยากถ้าทำผิด](../03_IO_Setup_Best_Practices/README.md)

---

[⬅ ก่อนหน้า: 2.1 I/O Core Concepts](../01_IO_Core_Concepts/README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [03 IO Setup Best Practices](../03_IO_Setup_Best_Practices/README.md)
