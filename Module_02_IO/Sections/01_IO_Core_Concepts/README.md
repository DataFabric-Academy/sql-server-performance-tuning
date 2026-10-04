[⬅ Module 02](../../README.md) | Section 1/4 | ➡ ถัดไป: [02 Storage Solutions](../02_Storage_Solutions/README.md)

# 2.1 I/O Core Concepts — ภาษาพื้นฐานของ Storage: IOPS, Throughput, Latency

> *"CPU คือคนที่ตัดสินใจ, Memory คือโต๊ะทำงาน — แต่ Disk คือคลังที่ทุกคนต้องวิ่งไปเอาของ เมื่อคลังไกล ทุกคนก็ช้าลง ไม่ว่าตัดสินใจเก่งแค่ไหน"*

> **ต้องรู้มาก่อน**: [Page (8 KB)](../../../Glossary.md), [Buffer Pool](../../../Glossary.md), [Latch](../../../Glossary.md), [Wait Type](../../../Glossary.md), [DMV / DMF](../../../Glossary.md) — โครงสร้าง Buffer Manager / Page Manager / Transaction Log จาก Section 1.1 (Storage Engine Layer)
> **Permission ที่ต้องมี**: `VIEW SERVER STATE` (อ่าน DMV ระดับ server) และสิทธิ์รันคำสั่งใน `AdventureWorks` ระดับ `db_datareader`; บล็อกที่มี `DBCC DROPCLEANBUFFERS` ต้องเป็น `sysadmin` **และใช้กับ VM ทดสอบเท่านั้น**

---

## ทำไม Section นี้จึงต้องมาก่อนในโมดูล I/O

Module 1 เราลากเส้นทางของ query ผ่าน Storage Engine แล้วหยุดที่ **Buffer Manager** ซึ่งตัดสินใจคำถามเดียว: *"page ที่ต้องการอยู่ใน Data Cache แล้วหรือยัง?"*

```
                       ┌──────────────────────────────┐
                       │        Buffer Pool           │
  Query ──▶ Buffer ───▶│  page อยู่ใน cache?          │
           Manager     │  ├── ใช่  → Logical Read     │  เร็วระดับ nanosecond
                       │  └── ไม่ใช่ → Physical Read  │──▶ Disk (I/O Subsystem)
                       └──────────────────────────────┘        ▲
                                                               │
                                        ช้าระดับ 0.1–10 ms (ช้ากว่า memory 1,000–100,000 เท่า)
```

ถ้าคำตอบคือ "อยู่ใน cache" — จบงานเร็วมาก ไม่มีอะไรต้องจูน แต่ทันทีที่ต้องลงไปถึง disk ความเร็วของงานจะถูกกำหนดโดย **I/O Subsystem** ทั้งหมด — สิ่งที่เราควบคุมได้ยากที่สุดและวัดผลได้ยากที่สุดในสามชั้น (CPU, Memory, Storage) Section นี้จึงสอน **"ภาษาที่ใช้คุยกับ storage"** ให้คล่องก่อน แล้วค่อยเรียนเลือกอุปกรณ์ (2.2), ตั้งค่า (2.3) และวินิจฉัย (2.4)

เส้นทางของ Section:

1. **สามตัวชี้วัด** — IOPS, Throughput, Latency และความสัมพันธ์ทางคณิตศาสตร์ระหว่างกัน
2. **พฤติกรรม I/O ของ SQL Server** — 8 KB page, 64 KB extent, random vs sequential
3. **Logical vs Physical Read** — เห็นด้วยตาตัวเองว่า cache ช่วยอะไร
4. **เส้นทางของ Read** — PAGEIOLATCH เกิดตรงไหน, Async I/O, Scatter-Gather
5. **เส้นทางของ Write** — Checkpoint, Lazy Writer, Eager Write, Log Writer และ WRITELOG
6. **อ่านค่ารอ I/O ครั้งแรก** — เชื่อมกลับไปที่ Wait Statistics ของ Module 1

---

## 1. IOPS, Throughput, Latency — สามตัวชี้วัดที่ต้องตีความ "พร้อมกันเสมอ"

การวัดประสิทธิภาพ storage มีสามตัวชี้วัดหลัก และกับดักอันดับหนึ่งของมือใหม่คือ **มองตัวเดียวแล้วสรุป**

### 1.1 ความหมาย

| ตัวชี้วัด | หน่วย | ตอบคำถามว่าอะไร | เทียบเชิงภาพ |
|:----------|:------|:----------------|:-------------|
| **IOPS** (I/O Per Second) | ops/sec | แขนหยิบของได้กี่ครั้งต่อวินาที | ความคล่องตัว |
| **Throughput** (MB/s) | MB/sec | ขนส่งของได้กี่กิโลไบต์ต่อวินาที | ความจุรถบรรทุก |
| **Latency** (ms) | ms ต่อ 1 I/O | ส่งคำสั่งไปแล้วรอของกลับนานแค่ไหน | เวลารอหน้าเคาน์เตอร์ |

- **Random I/O** (ข้ามไปข้ามมาไม่เรียงตำแหน่ง): ตัวชี้วัดสำคัญคือ **IOPS + Latency** — สถานการณ์ OLTP
- **Sequential I/O** (เรียงตำแหน่งต่อเนื่อง): ตัวชี้วัดสำคัญคือ **Throughput** — สถานการณ์ backup, bulk load, อ่าน report ใหญ่
- *Sustained Throughput* คือค่าที่รักษาได้ **ต่อเนื่อง** ไม่ใช่ burst ระยะสั้น — disk หลายตัวเอา burst จาก cache มาโชว์ แต่ทำต่อเนื่องไม่ได้ ซึ่งเป็นค่าที่ SQL Server ต้องการจริง

### 1.2 สมการที่ผูกทั้งสามเข้าด้วยกัน

```
Throughput (MB/s) = IOPS × ขนาด transfer ต่อครั้ง (KB) ÷ 1024
```

ตัวอย่างชุดเดียวกัน คำนวณให้เห็นชัด:

| สถานการณ์ | ขนาด I/O | IOPS | Throughput ที่ได้ |
|:----------|:---------|:-----|:------------------|
| OLTP random read | 8 KB | 5,000 | ~39 MB/s |
| Read-ahead แบบ extent | 64 KB | 5,000 | ~312 MB/s |
| Backup / bulk | 512 KB | 1,000 | ~500 MB/s |

**ข้อสรุปสำคัญ:** IOPS ตัวเดียวกัน แต่ขนาด I/O ใหญ่ขึ้น 10 เท่า → throughput เพิ่ม 10 เท่า — นี่คือเหตุผลที่งาน sequential (64–512 KB) "ขนได้" มากกว่างาน random (8 KB) หลายเท่า และเป็นหัวใจของการตีความ DiskSpd ใน Section 2.3

### 1.3 Latency — ตัวชี้วัดที่สำคัญที่สุด

IOPS กับ Throughput ตอบว่า "ทำได้แค่ไหน" แต่ **Latency ตอบว่า "ผู้ใช้รอนานแค่ไหน"** — และมันคือค่าที่ SQL Server ต้องจ่ายจริงทุกครั้งที่ page หลุดจาก cache เกณฑ์อ้างอิงของ Microsoft (แยกตามชนิดไฟล์):

| ประเภท | เป้าหมาย (Optimal) | ยอมรับได้ | ควรแก้ |
|:-------|:-------------------|:----------|:-------|
| **Transaction Log (write)** | **1–5 ms** | 5–10 ms | > 10 ms |
| **Data File OLTP** | **< 10 ms** (ดีมาก ~4 ms) | 10–20 ms | > 20 ms |
| **Data Warehouse / DSS** | < 20 ms | ≤ 30 ms | > 30 ms |

> [!IMPORTANT]
> ตารางเกณฑ์ฉบับ "ยุค SSD" ที่ใช้ตลอดโมดูลนี้ (และใช้ซ้ำใน 2.4) จะแคบกว่าเดิม: **Data < 5 ms = ยอดเยี่ยม, 5–20 ms = ยอมรับได้, > 20 ms = จู่โจมทันที; Log write < 2 ms = ยอดเยี่ยม, 2–5 ms = ยอมรับได้, > 5 ms = จู่โจมทันที** เกณฑ์ของคุณควรตั้งจาก baseline ของระบบตัวเอง (เรียนเก็บ baseline ใน Module 10) ไม่ใช่ตัวเลขลอย ๆ

ทำไม log ต้องเข้มงวดกว่า data มาก? เพราะทุก transaction ที่ commit **ต้องรอ log flush ลง disk จริง** ก่อนตอบ client (หลัก Write-Ahead Logging จาก Module 1) — log ช้า = *ทุก transaction ช้า* ตรง ๆ ไม่มีทางเบี่ยง

### 1.4 Queue Depth — สิ่งที่มักถูกลืม

IOPS ที่วัดได้ขึ้นกับ **ความลึกของคิว** (จำนวน I/O ที่ยื่นคำขอค้างไว้พร้อมกัน):

```
คิวลึก 1  (ทำทีละครั้ง)   : latency 1 ms → ได้สูงสุด 1,000 IOPS
คิวลึก 32 (ยื่น 32 คำขอ)  : latency 1 ms → อาจได้ถึง 32,000 IOPS
```

SQL Server ยื่น I/O แบบ asynchronous จำนวนมากพร้อมกัน (เรียนต่อในหัวข้อ 4) จึง "เบียร์" ความลึกคิวออกมาเป็น IOPS ได้ — ตอนทดสอบด้วย DiskSpd ถ้าตั้ง queue depth ต่ำเกิน จะได้ IOPS ต่ำกว่าของจริงเยอะ (เห็น flag `-o8` ในสคริปต์แล็บ)

---

## 2. SQL Server พูดกับ Disk อย่างไร — 8 KB, 64 KB, Random vs Sequential

### 2.1 หน่วย I/O ของ SQL Server

| หน่วย | ขนาด | ใช้ทำอะไร |
|:------|:-----|:----------|
| **Page** | **8 KB** | หน่วยเล็กที่สุดของการอ่าน/เขียน page เดียว (เช่น seek หาแถวเดียว) |
| **Extent** | 64 KB (8 pages) | หน่วยจัดสรรพื้นที่; read-ahead อ่านทีละ extent |
| **Read-ahead chunk** | สูงสุด ~512 KB ต่อ 1 คำสั่ง I/O | table scan / index scan อ่านล่วงหน้าเป็นก้อนใหญ่ |
| **Log write** | ตามจำนวน log records ที่รอ flush (โดยทั่วไป < 64 KB) | เขียนต่อท้ายไฟล์ log เสมอ |

### 2.2 แยกตามชนิดไฟล์ — ตารางที่ต้องจำติดตัว

| ไฟล์ | Pattern หลัก | อ่านเมื่อไร | เขียนเมื่อไร | สิ่งที่ต้องการจาก storage |
|:-----|:-------------|:-----------|:-------------|:--------------------------|
| **Data (.mdf/.ndf)** | **Random Read** เป็นหลัก + เขียนเป็นช่วง ๆ | cache miss, scan | checkpoint, lazy writer flush | IOPS สูง + latency ต่ำ (SSD/NVMe) |
| **Transaction Log (.ldf)** | **Sequential Write** ต่อเนื่อง | rollback, recovery, replication | **ทุกครั้งที่ commit**, log buffer เต็ม | **write latency ต่ำที่สุด** — เหนือกว่าทุกอย่าง |
| **tempdb** | หลากหลายมาก (sort, spill, version store) | ตลอด | ตลอด | IOPS + latency ทั้งคู่, อย่าให้แย่งกับ data จริง |

> **จุดเชื่อมโยง:** ตารางนี้คือข้อตกลงเบื้องหลังคำแนะนำ "แยก log ออกจาก data" ใน Section 2.3 และเป็นตัวชี้ทางเมื่อเห็น wait ใน Section 2.4 — data ช้าจะเจอ `PAGEIOLATCH_*`, log ช้าจะเจอ `WRITELOG`

### 2.3 Pattern ตามชนิดคำสั่ง — query ใหญ่ทำให้ disk "เปลี่ยนนิสัย"

ไฟล์เดียวกันสามารถโดนแบบ random หรือ sequential ก็ได้ ขึ้นกับคำสั่งที่รัน:

| คำสั่ง / งาน | Pattern ที่เกิดกับ data file | ขนาด I/O เด่น |
|:-------------|:----------------------------|:---------------|
| Index seek หาแถวเดียว | Random read (ทีละ page) | 8 KB |
| Table/index scan, รายงานใหญ่ | Read-ahead อ่านล่วงหน้าแบบต่อเนื่อง | 64–512 KB |
| `DBCC CHECKDB`, backup | อ่าน/เขียน sequential เป็นช่วงยาว | 512 KB–1 MB |
| Index rebuild | อ่านก้อนใหญ่ + เขียนก้อนใหญ่ (ถ้า offline = ปิด cache ระหว่างสร้าง) | 64–512 KB |
| OLTP UPDATE ประปราย | อ่าน random น้อย ๆ + log flush ต่อ commit | 8 KB / < 64 KB (log) |

ผลที่ตามมาในทางปฏิบัติ: ระบบ OLTP ที่ "สุขภาพดี" ควรเห็น avg transfer size เล็ก (ทำงานผ่าน cache และ seek เป็นหลัก) ส่วนช่วง maintenance window จะเห็น transfer size ใหญ่แบบ sequential เป็นพัก ๆ — ถ้าเห็น transfer ใหญ่ตลอดเวลาในช่วงทำงานปกติ อาจแปลว่ามี scan หนัก ๆ หลุดมา (ปัญหา index — Module 6) ไม่ใช่ปัญหา storage

### 2.4 Logical vs Physical Read — สองคำที่ต้องแยกให้ขาด

| ชนิด | อ่านจากไหน | ตีความอย่างไร |
|:-----|:-----------|:--------------|
| **Logical Read** | Buffer Pool (ไม่แตะ disk เลย) | **ตัววัด "งานของ query"** — เท่ากันทุกครั้งไม่ว่า cache ร้อนหรือเย็น |
| **Physical Read** | Disk จริง ผ่าน I/O Subsystem | ตัววัด "ความสัมพันธ์กับ cache" — เท่ากับจำนวน page ที่ยังไม่อยู่ใน memory |

Logical read สูง = query ทำงานหนัก (มักแก้ที่ index/query — Module 6–7) · Physical read สูง = ข้อมูลไม่อยู่ใน cache (มองที่ memory pressure — Module 4 และ storage — Module นี้)

---

## 3. เห็นด้วยตาตัวเอง: Cold Cache vs Warm Cache

> **หมายเหตุสภาพแวดล้อม:** สภาพแวดล้อมทดสอบของหลักสูตร (2026-10) ใช้ชื่อฐานข้อมูล `AdventureWorks` — หาก VM ของคุณ restore เป็น `AdventureWorks2022`/`AdventureWorks2025` ให้แก้ชื่อในคำสั่ง `USE` ทุกจุด

```sql
USE AdventureWorks;
GO
SET STATISTICS IO, TIME ON;
GO
CHECKPOINT;               -- บังคับเขียน dirty pages ลง disk ก่อน เพื่อให้ล้าง cache ได้
DBCC DROPCLEANBUFFERS;    -- ⚠️ ล้าง clean pages ออกจาก buffer pool = จำลอง cold cache — ห้ามรันบน Production
GO
SELECT COUNT(*) FROM Sales.SalesOrderDetail;   -- รอบที่ 1: cold
GO
SELECT COUNT(*) FROM Sales.SalesOrderDetail;   -- รอบที่ 2: warm
GO
SET STATISTICS IO, TIME OFF;
```

ดูผลที่แท็บ **Messages**:

**Expected (รันจริง SQL Server 2025 RTM-GDR 17.0.1135.8, AdventureWorks, 2026-10-02):**

| รอบ | logical reads | physical reads | read-ahead reads | elapsed time |
|:----|:--------------|:---------------|:-----------------|:-------------|
| Cold (หลัง DROPCLEANBUFFERS) | 274 | **1** | **272** | ~23 ms |
| Warm (รอบสอง) | 274 | **0** | **0** | ~17 ms |

สังเกต 3 อย่าง:

1. **logical reads เท่ากันทุกรอบ (274)** — นั่นคือ "งานของ query" ไม่ผันแปรตาม cache
2. รอบ cold มี physical + read-ahead — 274 pages น้อยกว่าที่คิด เพราะ optimizer เลือกอ่าน NC index ที่แคบที่สุด (~274 pages) แทน clustered index (~1,245 pages) — `COUNT(*)` ไม่ต้องการคอลัมน์อื่น
3. `physical reads = 1` แต่ `read-ahead = 272` — อ่านจริง 273 pages แต่ถูก "ยื่นล่วงหน้า" เป็นก้อนใหญ่แล้ว ผู้อ่านแทบไม่ต้องรอทีละ 8 KB

---

## 4. เส้นทางของ Read หนึ่งครั้ง — PAGEIOLATCH เกิดตรงไหน

เมื่อ thread ต้องการ page ที่ยังไม่อยู่ใน Buffer Pool:

```
Thread A ต้องการ page 100
   │
   ├─ 1. ตรวจ Buffer Pool → ไม่มี (cache miss)
   ├─ 2. ต้อง "จองที่" ใน Buffer Pool + ครอบ page ด้วย LATCH ก่อน
   ├─ 3. ยื่นคำขอ ASYNC READ ไปที่ OS แล้วเข้าสถานะ SUSPENDED
   │      └── ช่วงรอนี้ถูกนับเป็น wait:  PAGEIOLATCH_SH  (อ่าน) / PAGEIOLATCH_EX (เขียนทับ)
   ├─ 4. OS/Storage คืน page มา (เช่น อีก 1–20 ms)
   └─ 5. Page ลง Buffer Pool → ปลด LATCH → Thread กลับมาทำงานต่อ
```

สามข้อสรุปจากแผนภาพ:

1. **SQL Server ใช้ Async I/O เกือบทั้งหมด** — ยื่นคำขอแล้วปล่อย thread ไปนอน (SUSPENDED) ไม่เปลือง CPU รอ — thread เดียวจึง "รอได้หลายเรื่องพร้อมกัน" และ server รองรับ I/O concurrency มหาศาลโดยไม่ต้องมี thread เยอะ
2. **PAGEIOLATCH คือ "รอ page จาก disk"** — ต่างจาก `PAGELATCH_*` (รอ latch ใน memory ไม่เกี่ยว disk) ซึ่งจะแยกให้ชัดใน Section 2.4 และเจาะลึก latch ใน Module 5
3. **Scatter-Gather I/O** — SQL Server ยื่นคำขออ่าน/เขียน "หลายก้อนในคำสั่งเดียว" (เช่น อ่าน 8 extents ต่อเนื่องบน disk → กระจายลง memory ที่ไม่ต่อเนื่องกัน) ช่วยลดจำนวนคำสั่ง I/O และเพิ่ม throughput — เห็นผลเป็นค่า avg transfer size ใหญ่ใน Section 2.2 (ต่อไป)

> **แบบฝึกหัดคิด:** ถ้า query เดิมเพิ่ม logical reads จาก 274 เป็น 270,000 — PAGEIOLATCH จะสูงขึ้นกี่เท่า ถ้า cache ขนาดเท่าเดิม? (คำใบ้: physical read เพิ่มตาม *จำนวน page ที่ไม่เคยอยู่ใน cache* — นี่คือเหตุผลที่ "แก้ index" มักแก้ PAGEIOLATCH ได้ถาวรกว่า "เปลี่ยน disk")

---

## 5. เส้นทางของ Write — สี่ตัวละครที่ล้าง Dirty Pages

Read มีทางเดียว แต่ **เขียนลง data file มีหลายผู้กระทำ** ทั้งหมดทำงานเบื้องหลัง ผู้ใช้ไม่รอโดยตรง:

```
   UPDATE แก้ข้อมูลใน Buffer Pool (in-place)
        │  พร้อมกันนี้: log record ถูกเขียนลง Log Buffer แล้ว flush ลง .ldf ทันทีที่ commit (WAL)
        ▼
   ┌─────────────────── Buffer Pool ───────────────────┐
   │  Dirty Pages (แก้แล้ว ยังไม่ลง disk)               │
   └───────┬──────────────┬───────────────┬────────────┘
           │              │               │
     Checkpoint       Lazy Writer     Eager Write
     ทุก ~1 นาที /     ต้องการ memory    คำสั่งที่ต้อง
     เกิดเองตาม recovery   ว่าง ขับ page     เขียนทันที
     interval เขียนทั้ง     แก่ออก ก่อนล้าง    (เช่น bulk load,
     ที่เป็น dirty        (minimally logged)
           ▼              ▼               ▼
   ─────────────────── Data File (.mdf) ───────────────────
```

| ตัวละคร | ทริกเกอร์ | เขียนอะไรลง data file | ผลต่อระบบถ้าขาด/ช้า |
|:--------|:----------|:----------------------|:---------------------|
| **Checkpoint** | ตาม recovery interval (เริ่มต้น ~1 นาที) หรือ `CHECKPOINT` ด้วยมือ | flush dirty pages ทั้งหมดเพื่อลดเวลา recovery | recovery หลังไฟดับยาว, ระเบิด I/O ช่วง checkpoint ถ้า dirty เยอะสะสม |
| **Lazy Writer** | Buffer Pool ต้องการ free pages (memory pressure) | ขับ page เก่า/แปลกหน้าออก — dirty ต้องเขียนก่อนทิ้ง | ถ้าเห็นทำงานหนักตลอด = memory เล็กเกิน workload (Module 4) |
| **Eager Write** | คำสั่งแบบ minimally logged ใหญ่ ๆ (bulk insert, `SELECT INTO`, index build) | เขียนก้อนงานลง disk ทันทีขณะทำงาน | burst เขียนรุนแรงช่วง bulk — วางแผนหน้าต่างเวลา |
| **Log Writer** | commit / log buffer เต็ม (~ทุก ๆ 1 วินาที แม้ไม่มี commit) | log records ลง .ldf ตามลำดับ | ช้า = ทุก transaction ช้า — wait `WRITELOG` |

และเส้นทาง log แยกจาก data โดยสิ้นเชิง ตามหลัก **WAL**:

```
UPDATE → log record เข้า Log Buffer ──(ทุก commit)──▶ flush ลง .ldf จบก่อน! ──▶ ตอบ client ได้
              (memory)                                              │
                                                                    ▼
                                    Dirty pages ยังค้างใน Buffer Pool...
                                    รอ Checkpoint / Lazy Writer ค่อยลง .mdf ภายหลัง
```

ข้อสรุป: **log flush คือความรับผิดชอบของ transaction, data flush คือความรับผิดชอบของเบื้องหลัง** — เพราะฉะนั้น wait `WRITELOG` สูงโดน *ทุก query ที่เขียน* ทันที ส่วน I/O ของ data file มักแสดงอาการเป็น `PAGEIOLATCH_*` ฝั่งอ่านและกระจุกตัวช่วง checkpoint ฝั่งเขียน

> **ทางออกของ "เร่ง log flush" ที่ห้ามลืมราคา:** มีตัวเลือกที่ "เลื่อน" การรอออกไปได้จริง เช่น **Delayed Durability** (ยอมเสี่ยงข้อมูลสูญเสียไม่เกินวินาทีตอนไฟดับ) และ **ADR** ที่ทำให้ rollback เร็วขึ้น (เรียนใน Module 5) — แต่ทั้งหมดเป็นการเทรดความถูกต้อง/ความยืดหยุ่น ทางแก้ที่ไม่มีราคาแฝงคือทำให้ log disk เร็ว และทำให้ transaction ใหญ่พอสมควร (รวม micro-transactions) ไม่ flush ถี่เกินไป

---

## 6. อ่านค่ารอ I/O ครั้งแรก — เชื่อมกลับสู่ Wait Statistics

Module 1 สอนว่า wait stats คือบัญชีการรอที่ engine จดไว้เอง มากรองเฉพาะกลุ่ม I/O:

```sql
SELECT wait_type, waiting_tasks_count,
       wait_time_ms / 1000.0 AS wait_s,
       CAST(100.0 * wait_time_ms / SUM(wait_time_ms) OVER ()
            AS DECIMAL(10,1)) AS pct_total
FROM sys.dm_os_wait_stats
WHERE wait_type IN ('PAGEIOLATCH_SH', 'PAGEIOLATCH_EX', 'PAGEIOLATCH_UP',
                    'WRITELOG', 'IO_COMPLETION', 'ASYNC_IO_COMPLETION',
                    'BACKUPTHREAD', 'LOGBUFFER')
  AND wait_time_ms > 0
ORDER BY wait_time_ms DESC;
```

**Expected (รันจริง, 2026-10-02 — ค่าจะต่างตาม workload ที่ server ผ่านมา):**

| wait_type | waiting_tasks_count | wait_s | pct_total |
|:----------|:--------------------|:-------|:----------|
| WRITELOG | 1,070 | 0.954 | 35.3 |
| PAGEIOLATCH_SH | 797 | 0.908 | 33.6 |
| IO_COMPLETION | 830 | 0.545 | 20.1 |
| ASYNC_IO_COMPLETION | 2 | 0.154 | 5.7 |
| PAGEIOLATCH_EX | 66 | 0.125 | 4.6 |
| PAGEIOLATCH_UP | 21 | 0.019 | 0.7 |

อ่านค่าแบบมืออาชีพ:

1. ค่าเหล่านี้เป็น **ค่าสะสมตั้งแต่ restart** — อย่าสรุปจากตัวเลขเดียว ต้องดูเป็น delta (เรียนแบบเต็มใน Section 2.4)
2. `WRITELOG` มักติด top ของกลุ่ม I/O บนระบบที่เขียนบ่อย — บน VM ของหลักสูตร (drive เดียว) มันสะท้อนว่า log flush แบ่งแถวบนสายพานเดียวกับ data
3. ถ้า `PAGEIOLATCH_SH` ติดอันดับของ *ทั้ง server* (ไม่ใช่แค่กลุ่ม I/O) แปลว่า storage กำลังเป็นคอขวดจริง

และฝั่ง "ที่กำลังรออยู่ขณะนี้" (ไม่ใช่ค่าสะสม) ดูได้จาก `sys.dm_io_pending_io_requests`:

```sql
SELECT TOP (5) io_type, io_pending, io_pending_ms_ticks
FROM sys.dm_io_pending_io_requests
ORDER BY io_pending_ms_ticks DESC;
```

**Expected:** ตอน server ว่างมักคืน 0 แถว — ปกติ คำสั่งนี้มีค่าเมื่อรัน *ขณะ* มีโหลด (เช่นระหว่างรัน workload ใน Section 2.4) มันบอกว่า "คำขอ I/O กี่รายการค้างรอ completion อยู่"

ปิดท้ายด้วยมุมมองต่อไฟล์ — ตารางเดียวที่จะกลับมาใช้ตลอดโมดูล (จากแล็บ Module 02, สไตล์ Glenn Berry):

```sql
SELECT DB_NAME(vfs.database_id) AS database_name,
       mf.name AS logical_file_name,
       mf.type_desc,                       -- ROWS = data, LOG = log
       vfs.num_of_reads, vfs.num_of_writes,
       vfs.io_stall_read_ms  / NULLIF(vfs.num_of_reads, 0)  * 1.0 AS avg_read_latency_ms,
       vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) * 1.0 AS avg_write_latency_ms,
       (vfs.io_stall_read_ms + vfs.io_stall_write_ms)
           / NULLIF(vfs.num_of_reads + vfs.num_of_writes, 0) * 1.0 AS avg_io_latency_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
ORDER BY avg_io_latency_ms DESC;
```

**Expected (รันจริง, 2026-10-02):** ไฟล์ `AdventureWorks` (ROWS) อยู่บนสุดด้วย avg_io_latency สะสม ~4 ms (อ่าน ~5 ms, เขียน ~1 ms) ไฟล์อื่นทั้ง instance ราว 1–2 ms — ตัวเลขนี้คือค่าเฉลี่ยสะสมตั้งแต่ startup ของ VM เดียว drive C:\ สายพานเดียว เหมาะใช้เป็น **baseline ตั้งต้น** ให้เทียบหลังรัน workload

---

## 7. เชื่อมโยงไปข้างหน้า — แนวคิดของ section นี้กลับมาอีกที่ไหน

แนวคิด I/O ไม่ได้จบในโมดูลนี้ — มันคือคำศัพท์พื้นฐานที่ทุกโมดูลข้างหน้าใช้ต่อ:

| โมดูล | ใช้อะไรจาก section นี้ |
|:------|:------------------------|
| Module 3 (Database Structures) | extent/allocation, VLF และการเขียน log ที่เราอธิบายในหัวข้อ 5 |
| Module 4 (Memory) | physical read ที่ลดลงเมื่อ Buffer Pool กว้างขึ้น, PLE กับ page lifecycle |
| Module 5 (Concurrency) | Latch ที่ผูกกับ PAGEIOLATCH, WRITELOG ของ transaction สั้น/ยาว |
| Module 6 (Statistics & Indexes) | logical reads ที่ลดได้ด้วย index, Fragmentation ที่ทำให้ random I/O เพิ่ม |
| Module 9 (Extended Events) | เหตุการณ์ `file_read`/`file_write` ที่ให้รายละเอียดระดับ query |
| Module 11 (Troubleshooting) | สายไล่ PAGEIOLATCH → file stats → index/memory/storage ฉบับเต็ม |

เมื่อเจอคำเหล่านี้อีกครั้งในโมดูลข้างหน้า คุณจะมีสองคำถามติดตัวเสมอ: *"ค่านี้อยู่บนสายพานไหน (data/log/tempdb)?"* และ *"เป็นค่างาน (logical) หรือค่ารอ (latency)?"* — สองคำถามนี้แยกปัญหาได้เกือบครึ่งทางทุกครั้ง

---

## สรุป Section 2.1

1. **IOPS / Throughput / Latency ต้องอ่านพร้อมกัน** — ผูกกันด้วยสมการ `Throughput = IOPS × ขนาด I/O ÷ 1024`; งาน random ดู IOPS+latency, งาน sequential ดู throughput, ส่วน **latency คือตัวที่ผู้ใช้จ่ายจริง**
2. เกณฑ์ latency: **Log 1–5 ms เป้าหมายสูงสุด** (เพราะทุก commit ต้องรอ flush), Data OLTP < 10 ms ดีมาก, > 20 ms ต้องจู่โจม
3. SQL Server พูดกับ disk ด้วย **8 KB page / 64 KB extent** แบบ **asynchronous** และรวมคำขอเป็นก้อนใหญ่ด้วย read-ahead และ Scatter-Gather
4. **Logical read = งานของ query (คงที่), Physical read = ส่วนที่ต้องลง disk** — ลด logical read ด้วย index ลด physical read ด้วย memory + storage
5. การเขียน data file ทำโดยเบื้องหลัง (Checkpoint / Lazy Writer / Eager Write) แต่ **log flush เกิดทุก commit** — จึงเป็นตัวกำหนดเพดานของ throughput แบบเขียน และปรากฏเป็น wait `WRITELOG`
6. เครื่องมืออ่านค่าชุดแรก: `sys.dm_os_wait_stats` (กรองกลุ่ม I/O), `sys.dm_io_pending_io_requests` (กำลังค้าง), `sys.dm_io_virtual_file_stats` (ต่อไฟล์ — เจาะลึกใน 2.4)

### ตรวจความเข้าใจ

1. Server A ได้ 10,000 IOPS ที่ block 8 KB, Server B ได้ 2,000 IOPS ที่ block 512 KB — ตัวใด throughput สูงกว่า และ workload แบบใดจะชอบตัวใด?
2. `PAGEIOLATCH_SH` กับ `PAGELATCH_EX` ต่างกันอย่างไร — ใครเกี่ยวกับ disk, ใครเกี่ยวกับ memory?
3. ทำไมเกณฑ์ latency ของ log file จึงเข้มกว่า data file มาก? อธิบายด้วยหลัก WAL ที่เรียนใน Module 1
4. รัน `SELECT COUNT(*)` รอบที่สองได้ `physical reads = 0` — logical reads เปลี่ยนไหม เพราะอะไร และค่าไหนใช้ตัดสินว่า query หนัก?
5. Checkpoint, Lazy Writer และ Eager Write ต่างกันที่ "ทริกเกอร์" อย่างไร — เหตุการณ์ใดทำให้เห็น Lazy Writer ทำงานหนักตลอดเวลา?
6. ทำไมการยื่น I/O แบบ asynchronous จึงทำให้ SQL Server รองรับ I/O concurrency สูงโดยไม่ต้องมี thread จำนวนมาก?

**➡ ถัดไป:** [2.2 Storage Solutions — เลือกบ้านให้ข้อมูล: DAS, NAS, SAN, Object Storage](../02_Storage_Solutions/README.md)

---

[⬅ Module 02](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [02 Storage Solutions](../02_Storage_Solutions/README.md)
