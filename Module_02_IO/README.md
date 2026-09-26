# Module 2: SQL Server I/O

## 1. บทนำ (Introduction)
ระบบฐานข้อมูล (Database System) มีหน้าที่หลักในการจัดเก็บข้อมูลอย่างถาวร (Persistence) ดังนั้นระบบ Input/Output (I/O) จึงเป็นองค์ประกอบที่สำคัญที่สุดที่มีผลต่อประสิทธิภาพ แม้ว่าในปัจจุบันจะมีเทคโนโลยี In-Memory แต่ท้ายที่สุดข้อมูลยังต้องถูกเขียนลงสื่อบันทึกข้อมูล (Storage Media)

ในบทเรียนนี้ ผู้เรียนจะศึกษาพฤติกรรมของ I/O ใน SQL Server และเทคนิคการวัดผลประสิทธิภาพของ Storage Subsystem เพื่อให้มั่นใจว่าระบบสามารถรองรับ Workload ได้อย่างมีประสิทธิภาพ

### 1.1 Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – เข้าใจพื้นฐาน I/O Metrics**
  - อธิบาย IOPS, Throughput, Latency และค่ามาตรฐาน (เช่น ค่า Latency สำหรับ Log/Data) ได้
- **ระดับ 2 – อ่านค่าจาก DMVs/PerfMon ได้**
  - ใช้ `sys.dm_io_virtual_file_stats` และ Performance Counter เช่น `Avg. Disk sec/Read`, `Avg. Disk sec/Write` เพื่อประเมินสุขภาพ Storage ได้
- **ระดับ 3 – ออกแบบและรีวิวโครงสร้าง Disk/RAID ได้**
  - เลือก RAID Level, Allocation Unit Size, การแยก Data/Log ตามแนวทาง Best Practice และเชื่อมโยงกับแนวคิดใน Performance Center เรื่อง Disk/TempDB/Data-Log Configuration ได้
- **ระดับ 4 – ทดสอบและยืนยันสมมติฐานด้วย Benchmark**
  - ใช้เครื่องมือเช่น Diskspd และสคริปต์ในแล็บเพื่อสร้าง Baseline ว่าระบบ I/O ปัจจุบันรองรับ Workload ได้ตามเป้าหมายหรือไม่ และสามารถเปรียบเทียบกับแนวทางของ Microsoft ได้อย่างมีเหตุผล

---

## 2. Core Concepts (Lesson 1)

### 2.1 Performance Metrics

**I/O Performance** เป็นปัจจัยสำคัญที่สุดของ SQL Server เพราะข้อมูลทั้งหมดอยู่บน Disk ทุก Query ต้องผ่าน I/O Subsystem

> **หลักการสำคัญ:** SQL Server จะพยายามเก็บข้อมูลไว้ใน Memory (Buffer Pool) มากที่สุด แต่เมื่อ Memory ไม่พอ หรือ Query ต้องการข้อมูลใหม่ ก็ต้องอ่านจาก Disk

การวัดประสิทธิภาพ Storage ต้องพิจารณา 3 ปัจจัยหลักที่มีความสัมพันธ์กัน:
1.  **IOPS (I/O Per Second)**: จำนวนคำสั่งอ่าน/เขียนต่อวินาที
    *   *Random R/W*: สำคัญมากสำหรับระบบ OLTP (Transaction Processing)
    *   *Sequential R/W*: สำคัญสำหรับระบบ OLAP (Reporting) และ Transaction Log
2.  **Throughput (MB/s)**: ปริมาณข้อมูลที่รับส่งได้ต่อวินาที
    *   *Sustained Throughput*: ความเร็วเฉลี่ยต่อเนื่อง (ไม่ใช่ Burst Speed) เป็นค่าที่ SQL Server ต้องการ
3.  **Latency (Response Time)**: ระยะเวลาตั้งแต่เริ่มส่งคำสั่งจนได้รับข้อมูล (เป็นค่าที่สำคัญที่สุด)
    *   *Microsoft Recommendations*:
        *   **Log File**: 1-5 ms (ประสิทธิภาพสูงสุด/Optimal)
        *   **Data File (OLTP)**: 4-20 ms (10ms ถือว่าดีมาก)
        *   **DSS/OLAP**: <= 30 ms (ยอมรับได้สูงสุด)
### 2.2 Disk Technology & RAID
*   **HDD (Magnetic)**: จานหมุน ราคาถูก แต่ Latency สูง
*   **SSD (Solid State)**: Flash Memory ไม่มีจานหมุน Latency ต่ำมาก เหมาะกับ Database
*   **RAID Levels**:
    *   *RAID 0 (Striping)*: เร็วสุด แต่พังแล้วข้อมูลหาย (ห้ามใช้กับ Prod)
    *   *RAID 1 (Mirroring)*: ปลอดภัย เขียนช้านิดหน่อย
    *   *RAID 5 (Striping with Parity)*: อ่านดี แต่ **เขียนช้ามาก** (ต้องคำนวณ Parity) ห้ามใช้กับ DB ที่เขียนหนักๆ
    *   *RAID 10 (Mirroring + Striping)*: **Best Practice** สำหรับ SQL Server (เร็วและชัวร์)

#### RAID Write Penalty (I/O Multiplier)

| RAID Level | Read I/O | Write I/O (Penalty) | Use Case | Recommendation |
|:-----------|:--------:|:-------------------:|:---------|:--------------|
| **RAID 0** | 1 | 1 | TempDB | ✅ เหมาะสำหรับ TempDB (เร็วสุด, ไม่ต้อง Redundancy เพราะสร้างใหม่ทุก Restart) |
| **RAID 1** | 1 | **2x** | OS, SQL Binaries | ✅ เหมาะสำหรับ OS/Binaries (ไม่ต้องเร็ว แต่ต้อง Mirror) |
| **RAID 5** | 1 | **4x** | ❌ ไม่แนะนำสำหรับ Write-heavy | ⚠️ หลีกเลี่ยงสำหรับ Database |
| **RAID 6** | 1 | **6x** | ❌ ไม่แนะนำสำหรับ Database | ⚠️ หลีกเลี่ยงสำหรับ Database |
| **RAID 10** | 1 | **2x** | Data files, Log files | ✅ **Best Practice** (เร็ว + Redundancy) |

> [!WARNING]
> **RAID 5/6 Write Penalty**: ทุกๆ 1 Write จริง ต้องใช้ 4-6 I/O operations (อ่าน data, อ่าน parity, เขียน data, เขียน parity)
> ส่งผลให้ประสิทธิภาพการเขียนลดลงมาก ไม่เหมาะกับ OLTP workloads

### 2.3 Windows Storage Spaces
Software RAID ที่จัดการโดย Windows:
*   **Physical Disks** ถูกจัดกลุ่มเป็น **Storage Pools**
*   สร้าง **Virtual Disks** จาก Storage Pools ได้หลายแบบ:
    *   *Simple*: คล้าย RAID 0 (No redundancy)
    *   *Mirror*: คล้าย RAID 1 (2-way หรือ 3-way mirror)
    *   *Parity*: คล้าย RAID 5 (เหมาะกับ Archive, ไม่เหมาะกับ Database)

### 2.4 Deep Dive: I/O Architecture Internals (Microsoft Guide)

1.  **Async I/O (Asynchronous Input/Output)**:
    *   SQL Server ใช้ **Async I/O** เกือบทั้งหมด (ยกเว้น Log Hardening ในบางกรณี)
    *   *How it works*: Thread ส่งคำสั่ง I/O แล้ว **ไม่รอ** (Return ทันที) เพื่อไปทำอย่างอื่นหรือ Yield เมื่อ I/O เสร็จ Windows จะส่ง Signal (Interrupt) กลับมาบอก
    *   *Benefit*: รองรับ I/O concurrency มหาศาลโดยไม่ต้องใช้ Thread จำนวนมาก

2.  **Scatter-Gather I/O**:
    *   เทคนิคการอ่าน/เขียนข้อมูลทีละหลายๆ Page (เช่น 1 Extent = 8 Pages) ในครั้งเดียว
    *   **Scatter Read**: อ่านข้อมูลจาก Disk (ต่อเนื่อง) -> กระจายลง Memory (ไม่ต่อเนื่องกันได้)
    *   **Gather Write**: รวบรวมข้อมูลจาก Memory (ไม่ต่อเนื่อง) -> เขียนลง Disk (ต่อเนื่อง)
    *   *Benefit*: ลดจำนวน I/O Request ต่อวินาที (IOPS) และเพิ่ม Throughput

3.  **Instant File Initialization (IFI)**:
    *   *Normal Behavior*: เมื่อสร้าง/ขยายไฟล์ OS จะเขียน 0 ลงไปทุก byte (Zeroing) เพื่อความปลอดภัย -> ช้ามาก
    *   *IFI Behavior*: SQL Server ขอ OS ให้ข้ามขั้นตอน Zeroing -> **เร็วระดับวินาที** (เสี่ยงSecurity เล็กน้อยถ้ามีคนกู้ข้อมูลจาก Disk แต่ยอมรับได้)
    *   *Requirement*: ต้องให้สิทธิ์ `Perform volume maintenance tasks` แก่ Service Account



## 3. Storage Solutions (Lesson 2)

### 3.1 Common Storage Architectures
1.  **DAS (Direct-Attached Storage)**: การเชื่อมต่อพื้นที่จัดเก็บข้อมูลโดยตรงกับ Server
    *   *Pros*: ความซับซ้อนต่ำ, ได้ Bandwidth สูงสุด (Dedicated)
    *   *Cons*: ขยายตัวยาก (Scalability), ไม่สามารถแชร์ทรัพยากรได้
2.  **SAN (Storage Area Network)**: เครือข่ายจัดเก็บข้อมูลผ่าน Fiber Channel หรือ iSCSI
    *   *Pros*: แชร์พื้นที่ได้, รองรับ Snapshot/DR ระดับ Hardware
    *   *Cons*: ต้นทุนสูง, ต้องมีการบริหารจัดการ Bandwidth (QoS) เพื่อป้องกันปัญหา Noisy Neighbor
3.  **S3-Compatible Object Storage (SQL 2022+)**:
    *   SQL Server 2022 รองรับการ Backup/Restore หรือวาง Data File ลงบน Object Storage (เช่น AWS S3, Azure Blob) ผ่าน S3 API
    *   *Use Case*: เหมาะสำหรับการเก็บข้อมูลขนาดใหญ่ (Data Lake) หรือ Backup Storage ราคาประหยัด

---

## 4. I/O Setup & Best Practices (Lesson 3)

### 4.1 Disk Structure & Formatting
การเตรียม Disk เป็นขั้นตอนที่ไม่สามารถย้อนกลับได้ (Irreversible) หากทำผิดพลาด
*   **Partition Alignment**: ตรวจสอบ Offset ของ Partition ให้ตรงกับ Physical Sector (Windows รุ่นใหม่จัดการให้อัตโนมัติ)
*   **Allocation Unit Size (Block Size)**:
    *   แนะนำให้ Format เป็น **64KB**
    *   *Reasoning*: SQL Server ทำการ I/O ในหน่วย Extent (64KB = 8 Pages) การตั้งค่านี้จะช่วยลด I/O Overhead ของ OS file system และเพิ่ม Throughput ได้ 10-20%

### 4.2 RAID Selection
*   **RAID 0**: ประสิทธิภาพสูงสุด แต่มีความเสี่ยงสูงต่อข้อมูลสูญหาย (ไม่แนะนำสำหรับ Production)
*   **RAID 10**: **Recommended** สำหรับ Database Workload เนื่องจากมี Write Penalty ต่ำ (2x) และป้องกันข้อมูลสูญหายได้ดี
*   **RAID 5/6**: ประหยัดพื้นที่ แต่มี Write Penalty สูง (4x-6x) ไม่เหมาะสมสำหรับ Log File หรือ TempDB

### 4.3 I/O Pattern Analysis
การเข้าใจพฤติกรรม I/O ช่วยให้เลือก Storage ได้เหมาะสม:
1.  **Data File (.mdf)**:
    *   *Pattern*: **Random Read/Write**
    *   *Requirement*: ต้องการ IOPS สูง และ Latency ต่ำ (แนะนำ SSD/NVMe)
2.  **Log File (.ldf)**:
    *   *Pattern*: **Sequential Write** (Append-only)
    *   *Requirement*: ต้องการ Write Latency ต่ำที่สุด (แนะนำแยก Disk เพื่อลด Contention)

### 4.4 Advanced Configuration
*   **Instant File Initialization (IFI)**: ช่วยลดเวลาในการสร้างหรือขยายไฟล์ (Skip Zeroing) ควรเปิดใช้งาน (ค่าเริ่มต้นใน Setup ปัจจุบัน)
*   **Memory-Optimized TempDB Metadata (SQL 2019+)**: ลดการแย่งชิงทรัพยากร (Latch Contention) ใน System Table ของ TempDB ช่วยแก้ปัญหาคอขวดเมื่อมี Concurrent Temp Data สูง



## 5. Monitoring & Troubleshooting

### 5.1 Measuring Performance (Latency is King)
ดัชนีชี้วัดที่สำคัญที่สุดคือ **Avg. Disk sec/Transfer** (PerfMon) หรือ `io_stall` (DMVs)

**Log File (.ldf) Latency:**
*   **1-5 ms**: ประสิทธิภาพสูงสุด (Optimal) - Log File ต้องการ Latency ต่ำที่สุดเพราะเป็น Sequential Write ที่สำคัญต่อ Transaction Performance
*   **5-10 ms**: ยอมรับได้ (Acceptable) แต่ควรพิจารณา Optimize
*   **> 10 ms**: เริ่มพบปัญหาประสิทธิภาพ (Degraded) - Transaction Commit อาจช้าลง
*   **> 50 ms**: วิกฤต (Critical) - ผู้ใช้งานจะพบปัญหา Timeout หรือ Transaction Blocking

**Data File (.mdf) Latency:**
*   **< 5 ms**: ประสิทธิภาพสูง (SSD/NVMe level)
*   **10-20 ms**: ยอมรับได้ (Acceptable) สำหรับ Data File
*   **> 20 ms**: เริ่มพบปัญหาประสิทธิภาพ (Degraded)
*   **> 100 ms**: วิกฤต (Critical) ผู้ใช้งานจะพบปัญหา Timeout หรือ System Freeze

### 5.2 DMVs: `sys.dm_io_virtual_file_stats`
DMV นี้ให้ข้อมูลประสิทธิภาพระดับไฟล์ (Granular level) ช่วยระบุได้ว่าไฟล์ใดมี response time สูงสุด

---

## 6. Lab: Testing Storage Performance

### Scenario
**Adventure Works** วางแผนติดตั้ง Server ใหม่สำหรับระบบ **Proseware Inc.** ท่านได้รับมอบหมายให้ตรวจสอบประสิทธิภาพ Storage ว่าเพียงพอต่อ Workload ที่มีการเขียน Transaction Log หนาแน่น (Write Intensive) หรือไม่

### Exercise 1: Configuring and Executing Diskspd
1.  **Prepare Environment**: สร้างไฟล์ทดสอบ (Dummy File) ขนาด 2GB
2.  **Execute Diskspd**: จำลอง Workload แบบผสม (Mixed Workload)
    *   *Command Logic*: จำลอง Random Read 60% / Write 40% ที่ Block Size 64KB (จำลอง SQL Server Standard Workload)
3.  **Analyze Results**:
    *   **Total IOPS**: เปรียบเทียบกับ Spec ของ Storage (SSD ควรทำได้ > 5,000 IOPS)
    *   **AvgLat**: ค่าเฉลี่ย Latency ไม่ควรเกิน 10-20ms
    *   **MB/sec**: Throughput เพียงพอต่อปริมาณข้อมูลหรือไม่?

---

## 7. Review Quiz (Knowledge Check)

<details>
<summary><b>1. Latency ที่ดีสำหรับ Log File ควรอยู่ในช่วงเท่าไหร่?</b></summary>
1-5 ms ถือว่าดีมาก (Optimal) สำหรับ Log File เนื่องจากเป็น Sequential Write ที่ต้องการความเร็วสูง
</details>

<details>
<summary><b>2. ทำไม RAID 5 ไม่เหมาะกับ Database ที่มีการเขียนหนัก?</b></summary>
เพราะ RAID 5 มี Write Penalty สูง (4x-6x) ต้องคำนวณ Parity ทุกครั้งที่เขียน ทำให้ช้ากว่า RAID 10
</details>

<details>
<summary><b>3. Allocation Unit Size ที่แนะนำสำหรับ SQL Server คือเท่าไหร่?</b></summary>
64KB เพราะ SQL Server ทำ I/O เป็น Extent (64KB = 8 Pages) การตั้งค่านี้ช่วยลด Overhead ของ File System
</details>

---

## 8. 🆕 Modernization Notes: SQL Server 2019 → 2025 (อัปเดตตาม Microsoft Learn)

### 8.1 เครื่องมือทดสอบ I/O
- **SQLIO ถูกยกเลิกแล้วทั้งหมด** — ใช้ **DiskSpd** (microsoft/diskspd) เป็นเครื่องมือมาตรฐานเดียว สอดคล้องกับ Lab ของ 10987C ที่แนบ DiskSpd 2.0.15 มาให้พร้อมใช้
- ทางเลือกเสริมยุคใหม่: VM Fleet / storage benchmark ของ hardware vendor แต่หลักการตีความผล (IOPS vs Throughput vs Latency) เหมือนเดิม

### 8.2 ฟีเจอร์ใหม่ที่กระทบ I/O Profile
- **ZSTD backup compression (ใหม่ใน SQL Server 2025)** — อัลกอริทึมบีบอัด backup เร็วกว่าและได้อัตราดีกว่าเดิม ลดภาระ I/O ช่วง backup/restore อย่างมาก (ตั้งได้ผ่าน `BACKUP ... WITH COMPRESSION (ALGORITHM = ZSTD)`)
- **tmpfs สำหรับ tempdb บน SQL Server on Linux (2025)** — วาง tempdb บน memory filesystem ได้
- Instant File Initialization: ตั้งแต่ SQL Server 2022 log growth สูงสุด 64 MB ก็ได้ประโยชน์จาก IFI เช่นกัน (เดิมเฉพาะ data file)
- **Hybrid Buffer Pool / PMEM** ยังคงมีบทบาทบนฮาร์ดแวร์ที่มี persistent memory

### 8.3 การตีความค่า Latency (ยังคงเป็นเกณฑ์เดิม)
| ประเภทไฟล์ | ดีเยี่ยม | ยอมรับได้ | แก้ด่วน |
|:---|:---|:---|:---|
| Data file (read) | < 5 ms | 5–20 ms | > 20 ms |
| Data file (write) | < 5 ms | 5–20 ms | > 20 ms |
| Log file (write) | < 2 ms | 2–5 ms | > 5 ms |

> อ้างอิง: [DiskSpd](https://github.com/microsoft/diskspd), [What's new in SQL Server 2025](https://learn.microsoft.com/sql/sql-server/what-s-new-in-sql-server-2025), [sys.dm_io_virtual_file_stats](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-io-virtual-file-stats-transact-sql)
