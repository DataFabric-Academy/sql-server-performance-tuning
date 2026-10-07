# Using DiskSpd ในสภาพแวดล้อม SQL Server (Reference)

> **ที่มา**: แปล/ปรับจาก whitepaper **"Using DiskSpd in SQL Server environments"** — Writer: Robert Beene · Contributors: Jose Barreto, Ramu Konidena · Technical Reviewers: Robert Dorr, Mike Zawadzki, Nitin Verma, Dan Lovinger (Microsoft)
> ต้นฉบับภาษาอังกฤษอยู่ที่ [`UsingDiskspdforSQLServer.docx`](UsingDiskspdforSQLServer.docx) ในโฟลเดอร์เดียวกัน (รุ่นล่าสุดที่ Microsoft เผยแพร่ — แนบมากับ 10987C Lab02) · Applies to: SQL Server ทุกเวอร์ชัน ยกเว้น Azure SQL Database
> **หมายเหตุ**: whitepaper เขียนสมัย DiskSpd 2.0 — คำสั่งทั้งหมดยังใช้ได้กับ **DiskSpd v2.3** ที่ bundled ในโฟลเดอร์นี้ ยกเว้นจุดที่ระบุไว้ใน[ภาคผนวก](#ภาคผนวกการเปลี่ยนแปลงยุค-20--v23) (ที่สำคัญ: ตัว `-h` เดิมถูกแทนด้วย `-Sh`) · ใช้ประกอบ [Lab 2: DiskSpd Benchmark](../README.md)

## สารบัญ

1. [Background — เครื่องมือทดสอบ I/O มีอะไรบ้าง](#1-background)
2. [ข้อมูลทั่วไปและฟีเจอร์ของ DiskSpd](#2-ข้อมูลทั่วไปและฟีเจอร์)
3. [Open Source และการดาวน์โหลด](#3-open-source-และการดาวน์โหลด)
4. [Syntax พื้นฐาน](#4-syntax-พื้นฐาน)
5. [คำเตือนและข้อควรรู้ก่อนใช้](#5-คำเตือนและข้อควรรู้ก่อนใช้)
6. [I/O pattern ของ SQL Server แต่ละ operation](#6-io-pattern-ของ-sql-server-แต่ละ-operation)
7. [ตัวอย่างคำสั่งตาม pattern (data/log files)](#7-ตัวอย่างคำสั่งตาม-pattern)
8. [การอ่านผลลัพธ์ + เกณฑ์ latency + RAID penalty](#8-การอ่านผลลัพธ์)
9. [ภาคผนวก: การเปลี่ยนแปลงยุค 2.0 → v2.3](#ภาคผนวกการเปลี่ยนแปลงยุค-20--v23)

---

## 1. Background

เครื่องมือทดสอบ I/O subsystem มี 2 ประเภท: **validation test** (จำลอง read/write แล้วตรวจความถูกต้องของข้อมูล — เน้นหา root cause ของ corruption/ปัญหา driver) กับ **performance test** (load generator วัด throughput/ความเร็ว — ตรวจว่า hardware รับ workload ตามสเปกที่ออกแบบได้หรือไม่) เอกสารนี้เกี่ยวกับประเภทหลัง

ตารางเปรียบเทียบเครื่องมือที่ใช้ทดสอบ I/O subsystem ในบริบท SQL Server (ต้นฉบับ Table 1):

| Tool | ใช้วัดสิ่งใด | I/O pattern | ผู้ให้บริการ |
|---|---|---|---|
| **DiskSpd.exe** | Performance capacity | ผู้ใช้กำหนด — ผสม I/O types ได้ | Microsoft |
| SQLIO.exe *(deprecated — ใช้ DiskSpd.exe)* | Performance capacity | ผู้ใช้กำหนด — ทีละ I/O type | Microsoft |
| **SQLIOSim** | Functional correctness | จำลอง SQL Server I/O patterns | Microsoft |
| SQLIOStress *(deprecated — ใช้ SQLIOSim)* | Functional correctness | จำลอง SQL Server I/O patterns | Microsoft |

SQLIOSim ตรวจความถูกต้องเชิงฟังก์ชันภายใต้ stress (ทีม support ของ Microsoft ใช้แยกปัญหา corruption ฝั่ง hardware) — แต่เพื่อ **performance tuning แล้ว DiskSpd คือเครื่องมือที่เหมาะสมที่สุด**

## 2. ข้อมูลทั่วไปและฟีเจอร์

DiskSpd.exe เป็น **storage load generator** ของ Microsoft ทดสอบได้ทั้งไฟล์, partition และ physical disk จำลอง SQL Server I/O หรือ pattern ที่ซับซ้อนกว่าได้ ผลลัพธ์ออกเป็น text หรือ XML (สำหรับวิเคราะห์อัตโนมัติ) รันจาก physical host หรือ VM กับ storage ทุกชนิด: local disk, LUN บน SAN, Storage Spaces, SMB file share

ฟีเจอร์สำคัญ:

- รองรับ 64-bit, 32-bit และ ARM
- target ได้ทั้ง physical disk, partition และไฟล์
- กำหนดสัดส่วน read/write (%) ได้
- กำหนด CPU affinity ได้
- ผลลัพธ์แบบ text (default) หรือ XML
- sync/trace หลาย instance พร้อมกันได้ (event-based)
- รันจาก Command Prompt หรือ PowerShell

## 3. Open Source และการดาวน์โหลด

DiskSpd เป็น open source (MIT license) — โค้ดและ release อยู่ที่ [github.com/microsoft/diskspd](https://github.com/microsoft/diskspd) · ดาวน์โหลด binary ล่าสุดจาก [Releases](https://github.com/microsoft/diskspd/releases) (หรือ `aka.ms/diskspd`)

> เครื่องมือให้ใช้ "as is" ไม่มี support ทางการ — ลิขสิทธิ์ดู [`EULA-DiskSpd.txt`](EULA-DiskSpd.txt) · ใน repo นี้ bundled **v2.3** ไว้แล้วที่โฟลเดอร์นี้ ([รายละเอียด/SHA256](README.md))

## 4. Syntax พื้นฐาน

```
DiskSpd [options] target1 [ target2 [ target3 ...] ]
```

- ดู options ทั้งหมดด้วย `DiskSpd -?`
- target เป็นได้ทั้งไฟล์ (`C:\testfile.dat`), partition (`C:`) หรือ physical drive (`#1`)
- กำหนดค่าผ่าน command line หรือ XML profile ก็ได้

ตัวอย่าง: ทดสอบ 15 วินาที, 1 thread, random 8KiB read 100% ที่ queue depth 10:

```bat
DiskSpd -d15 -F1 -w0 -r -b8K -o10 c:\testfile.dat
```

> หมายเหตุการอ่านตัวอักษร: คำสั่งในต้นฉบับ .docx ถูก Word แปลง hyphen `-` เป็น en-dash `–` (เช่น `–d300`) — พิมพ์ตามต้นฉบับจะ error ให้ใช้ `-` ปกติเสมอ คำสั่งทั้งหมดในเอกสารนี้แก้ให้แล้ว

## 5. คำเตือนและข้อควรรู้ก่อนใช้

> **WARNING — load กระทบเครื่องอื่น**: load ที่ DiskSpd สร้างอาจกระทบ VM อื่นบน host เดียวกัน, LUN อื่นบน SAN เดียวกัน หรือ traffic อื่นใน network เดียวกัน

> **WARNING — เขียนทับข้อมูลได้**: ถ้า target เป็น **physical disk/partition** (ไม่ใช่ไฟล์) DiskSpd **จะทำลายข้อมูลบนดิสก์นั้นทันทีโดยไม่ถามยืนยัน**

- **ตัวพิมพ์ใหญ่-เล็กของ parameter มีคนละความหมาย** (`-r` กับ `-R` คนละอย่าง)
- ปิด process อื่นก่อนทดสอบ — process อื่นแย่ง CPU/network/storage ทำให้ผลเพี้ยน
- รันจาก **Command Prompt แบบ elevated (Administrator)** — ไม่งั้นการสร้างไฟล์ทดสอบจะใช้วิธีช้ากว่า
- ยกเลิกระหว่างรันได้ด้วย `CTRL+C` — โปรแกรมจะรายงานข้อมูลที่เก็บได้ก่อนยกเลิก (ถ้าผ่านช่วง warm-up แล้ว)
- หน่วย `KiB/MiB/GiB` = base-2: 1 KiB = 1,024 bytes, 1 MiB = 1,048,576 bytes, 1 GiB = 1,073,741,824 bytes (ต่างจาก KB/MB/GB แบบ base-10)
- **ไฟล์ทดสอบที่สร้างด้วย `-c` จะไม่ถูกลบอัตโนมัติ** — ตัวอย่างในเอกสารสร้างไฟล์ 1000 GiB อย่าลืมลบหลังทดสอบ

## 6. I/O pattern ของ SQL Server แต่ละ operation

เพื่อเลือกค่า parameter ให้ตรง workload จริง ต้องเข้าใจ pattern read/write ของ SQL Server (ทบทวน page = 8KiB, extent = 64KiB — ดู [Understanding Pages and Extents](https://learn.microsoft.com/sql/relational-databases/pages-and-extents-architecture-guide))

> **กฎ**: ทุก operation ที่ขนาดเป็นช่วง (เช่น 8KiB–128KiB) ให้ใช้ขนาดที่เป็น **จำนวนเต็มหลายของ 8KiB**

| ประเภทไฟล์ | Operation | READ pattern | WRITE pattern | Threads ที่ใช้ | ลักษณะ I/O |
|---|---|---|---|---|---|
| Data File | Normal Activity | 8KiB–128KiB | 8KiB–128KiB | ตาม MaxDOP | Random |
| | Checkpoint | — | 64KiB–128KiB | = จำนวน socket ของเครื่อง | Random |
| | LazyWriter | — | 64KiB–128KiB | 1 ต่อ NUMA node | Random |
| | Bulk Insert | — | 8KiB–128KiB | ตาม MaxDOP | Sequential |
| | Backup | 1 MB | 1 MB | ตาม MaxDOP | Sequential |
| | Restore | 64KiB | 64KiB | ตาม MaxDOP | Sequential |
| | DBCC CHECKDB (no repair) | 8KiB–64KiB | — | ตาม MaxDOP | Sequential |
| | Rebuild Index | ดู Read Ahead | 8KiB–128KiB | ตาม MaxDOP | Sequential |
| | Read Ahead | สูงสุด 512KiB | — | ตาม MaxDOP | Sequential |
| Log File | Normal Activity | 512 bytes–64KiB | 512 bytes–64KiB | 1 log writer ต่อ soft-NUMA node (cap 4) | Sequential |

## 7. ตัวอย่างคำสั่งตาม pattern

ค่ากลางที่ตัวอย่างใช้ (ปรับตามเครื่องจริงได้): ไฟล์เดียว 1000 GiB · 8 threads (data) / 4 threads (log) · 300 วินาที · queue depth 32 (data) / 8–116 (log)

ตัวอย่างพร้อมอธิบาย flag — 100% random read 8KiB:

```bat
DiskSpd.exe -c1000G -d300 -r -w0 -t8 -o8 -b8K -h -L F:\testfile.dat
```

| Flag | ความหมาย |
|---|---|
| `-c1000G` | สร้างไฟล์ทดสอบขนาด 1000 GiB |
| `-d300` | ทดสอบนาน 300 วินาที (5 นาที) |
| `-r` | random I/O |
| `-w0` | 0% write = 100% read |
| `-t8` | 8 threads |
| `-o8` | 8 outstanding I/O ต่อ thread (queue depth) |
| `-b8K` | block size 8KiB |
| `-h` | ปิด software caching + hardware write caching (ยุค 2.0 — **v2.3 ใช้ `-Sh`**) |
| `-L` | วัด latency statistics |

### Data file patterns

| Pattern | คำอธิบาย | คำสั่ง |
|---|---|---|
| 100% 8KiB random read | อ่าน random พร้อมกันขนาดใหญ่ ปิดทุก cache | `DiskSpd.exe -c1000G -d300 -r -w0 -t8 -o32 -b8K -h -L F:\testfile.dat` |
| 100% 8KiB random write | เขียน random พร้อมกันขนาดใหญ่ ปิดทุก cache | `DiskSpd.exe -c1000G -d300 -r -w100 -t8 -o32 -b8K -h -L F:\testfile.dat` |
| 60/40 8KiB random read/write | จำลอง OLTP ทั่วไป | `DiskSpd.exe -c1000G -d300 -r -w40 -t8 -o32 -b8K -h -L F:\testfile.dat` |
| 100% 64KiB random read | จำลอง checkpoint ขนาดเล็ก — ตั้ง `-t` = จำนวน socket | `DiskSpd.exe -c1000G -d300 -r -w0 -t8 -o32 -b64K -h -L F:\testfile.dat` |
| 100% 64KiB random write | จำลอง checkpoint ปกติ/ใหญ่ — ตั้ง `-t` = จำนวน socket | `DiskSpd.exe -c1000G -d300 -r -w100 -t8 -o32 -b64K -h -L F:\testfile.dat` |
| 60/40 64KiB random read/write | read/write ผสม block ใหญ่ | `DiskSpd.exe -c1000G -d300 -r -w40 -t8 -o32 -b64K -h -L F:\testfile.dat` |
| 100% 128KiB random write | เขียน random block ใหญ่ | `DiskSpd.exe -c1000G -d300 -r -w100 -t8 -o32 -b128K -h -L F:\testfile.dat` |
| 100% 512KiB random read, `-o5000` | จำลอง Read Ahead 512KiB (Enterprise Edition) | `DiskSpd.exe -c1000G -d300 -r -w0 -t8 -o5000 -b512K -h -L F:\testfile.dat` |
| 100% 512KiB random read, `-o128` | จำลอง Read Ahead 512KiB (Standard Edition) | `DiskSpd.exe -c1000G -d300 -r -w0 -t8 -o128 -b512K -h -L F:\testfile.dat` |

> ทดสอบ pattern LazyWriter: ตั้ง `-t` = จำนวน NUMA node ของเครื่อง แล้วใช้ write 64KiB–128KiB

### Log file patterns

> จำกัด thread สูงสุดของ log = 1 ต่อ NUMA node ไม่เกิน 4 · log มี outstanding I/O ได้ถึง 116

| Pattern | คำอธิบาย | คำสั่ง |
|---|---|---|
| 100% 64KiB sequential read | queue depth 8 | `DiskSpd.exe -c1000G -w0 -b64K -F4 -T1b -s8b -o8 -d300 -h F:\testfile.dat` |
| 100% 64KiB sequential write | queue depth 116 | `DiskSpd.exe -c1000G -w100 -b64K -F4 -T1b -s8b -o116 -d300 -h F:\testfile.dat` |
| 40/60 64KiB sequential read/write | queue depth 8 | `DiskSpd.exe -c1000G -w60 -b64K -F4 -T1b -s8b -o8 -d300 -h F:\testfile.dat` |

flag เสริมของ log patterns: `-F4` = จำนวน thread รวม 4 (conflict กับ `-t`), `-T1b` = จุดเริ่ม I/O ของแต่ละ thread ห่างกัน 1 block, `-s8b` = sequential โดยเว้น stride 8 blocks ระหว่าง operation

### ทดสอบหลายไฟล์พร้อมกัน (synchronized multi-instance)

รัน DiskSpd หลาย instance โดยผูก start/stop ด้วย event — ต้องเปิด Administrator Command Prompt แยก 1 หน้าต่างต่อ 1 ไฟล์ + อีก 1 หน้าต่างสำหรับสั่ง start/stop (ตัวอย่างใช้ 4 หน้าต่าง, ไฟล์ละ 100 GiB — random 60R/40W สองไฟล์ + sequential 40R/60W อีกไฟล์):

```bat
DiskSpd.exe -c100G -r -w40 -t8 -o32 -b64K -yrMyStartEvent -ypMyStopEvent F:\testfile1.dat
DiskSpd.exe -c100G -r -w40 -t8 -o32 -b64K -yrMyStartEvent -ypMyStopEvent F:\testfile2.dat
DiskSpd.exe -c100G -w40 -b64K -F4 -T1b -s8b -o8 -yrMyStartEvent -ypMyStopEvent F:\testfile3.dat

rem หน้าต่างที่ 4 — สั่งเริ่มทุก instance พร้อมกัน
DiskSpd -yeMyStartEvent
rem ... รอสักครู่ ...
DiskSpd -yeMyStopEvent
```

## 8. การอ่านผลลัพธ์

- ผลลัพธ์ default เป็น text (`-Rtext` ระบุชัดเจน) หรือ XML (`-Rxml`) สำหรับ parse อัตโนมัติ
- ก่อนตีความ ต้องรู้ **max throughput** ของ target ก่อน: สเปกของดิสก์/VHD, HBA/I/O card และหัก **RAID penalty** — ไม่งั้นจะไม่รู้ว่าผลที่ได้ "ดี" หรือ "แย่"

### เกณฑ์ Average Disk Sec/Transfer ของ SQL Server (ต้นฉบับ Figure 2)

| Avg Disk Sec/Transfer | ผลต่อ SQL performance |
|---|---|
| ≤ 10 ms | Ideal |
| 11–20 ms | อาจมีผลต่อ performance บ้าง |
| > 20 ms | Performance ถูกกระทบ |

### RAID write penalty

RAID 5 เขียนแบบ **READ → MODIFY → WRITE**: อ่านข้อมูลเดิม 64KiB + parity → XOR → เขียนข้อมูลใหม่ + parity ใหม่ = **เขียน 1 I/O ใช้จริง 4 I/O**

```
MAX_WRITE  ×  NUMBER_OF_DRIVES  /  RAID5_PENALTY  =  WRITE THROUGHPUT จริง
450 MB/s   ×  3 ดิสก์            /  4              =  337.5 MB/s
```

| RAID level | Write penalty |
|---|---|
| RAID 0 (striping) | 1 (แทบไม่มี) |
| RAID 1 (mirroring) | 2 |
| RAID 5 (striping + parity) | 4 |
| RAID 10 (mirroring + striping) | 2 |

### อ่าน output ทีละส่วน

ตัวอย่างผลรันของคำสั่ง `DiskSpd.exe -c1000G -d300 -r -w0 -t8 -o8 -b8K -h -L F:\testfile.dat` (ในที่นี้ `-L` เปิดวัด latency, `-D` ใช้เก็บ IOPS statistics รายช่วง):

1. **Command line** — คำสั่งที่รันซ้ำมาให้ท้ายรายงาน
2. **Input parameters** — สรุปค่าที่ตั้ง (duration, warm-up, block size, thread, queue depth, "software and hardware write cache disabled")
3. **ผลต่อ timespan** — เวลารันจริง, thread count, proc count
4. **ตาราง CPU** — Usage/User/Kernel/Idle ราย core + ค่าเฉลี่ย (ตัวอย่าง: avg 2.43% = CPU ว่างมาก ไม่ใช่ bottleneck)
5. **Total IO ราย thread** — bytes, I/Os, MB/s, I/O per s, **AvgLat** (ms), **LatStdDev**:

```text
total:          44490752 |         5431 |       4.24 |     543.10 |  117.808 |    99.620
```

→ 543.10 IOPS, 4.24 MB/s, **avg latency 117.8 ms (แย่มาก)** — LatStdDev 99.6 แปลว่า latency กระจายตัวสูงด้วย

6. **Read IO / Write IO** — แยกรายทิศทาง (test นี้ 100% read ตัวเลขซ้ำกับ total, write = 0)
7. **ตาราง percentile ของ latency** (ms):

```text
min   |   1.420
25th  |  42.050
50th  |  92.015
75th  | 166.870
90th  | 253.184
95th  | 315.347
99th  | 444.655
max   | 688.090
```

→ ครึ่งหนึ่งของ I/O แย่กว่า 92 ms, 1% แย่กว่า 444 ms — ดู percentile ควบคู่ avg เสมอ เพราะ avg อย่างเดียวบดบัง tail latency

## ภาคผนวก: การเปลี่ยนแปลงยุค 2.0 → v2.3

whitepaper เขียนสมัย DiskSpd 2.0 (ราวปี 2016) — เครื่องมือปัจจุบัน (v2.3, ก.ย. 2026) มีจุดที่ต่างซึ่งเกี่ยวกับเนื้อหาในเอกสารนี้:

| ยุค 2.0 (whitepaper) | ปัจจุบัน (v2.3) |
|---|---|
| `-h` ปิด software + hardware write caching | `-h` เป็น **deprecated** — ใช้ `-Sh` (เท่ากับ `-Suw`: FILE_FLAG_NO_BUFFERING + FILE_FLAG_WRITE_THROUGH, ความหมายเดิมทุกประการ) |
| ผล latency จาก `-L` เทียบข้ามเวอร์ชันได้ | DiskSpd 2.2 เปลี่ยนวิธีวัด latency (batched completions, look-aside I/O) — ตัวเลข latency เก่า/ใหม่ **ต้อง baseline แยก** ดูอธิบายที่ [Windows Server 2025 Storage Performance with Diskspd](https://techcommunity.microsoft.com/blog/filecab/windows-server-2025-storage-performance-with-diskspd/4167713) |
| — | 2.3 เปลี่ยน default 2 จุด: affinity เรียง P-core ก่อน E-core (`-aup` = ปิด) และ buffer แยกตาม PDE cache line (`-bsn` = กลับ default เดิม) — อาจทำให้ผลต่างเล็กน้อยจากรุ่น 2.0.x |
| — | I/O path ใหม่แบบ IoRing (`-u`) สำหรับ throughput สูง ๆ |

แหล่งอ้างอิงเพิ่มเติม (แทนหัวข้อ "Download/Contents in Download" ของต้นฉบับที่ชี้ไป TechNet เดิมซึ่งปิดไปแล้ว): [เอกสาร wiki](https://github.com/microsoft/diskspd/tree/main/docs) และ [DiskSpd 2.3 release notes](https://github.com/microsoft/diskspd/releases/tag/v2.3)
