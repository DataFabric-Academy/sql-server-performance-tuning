# สไลด์ไบล์พรินต์ — Module 2: ประสิทธิภาพ I/O Subsystem (20 สไลด์)

> **สรุปครอบคลุม:** เด็ค M2 ออกแบบตามสูตรตายตัวของแผนแม่บท (มติ #5): 20 สไลด์ = โครง 4 ใบ (Cover / Module Divider / Lab / Closing) + 4 ใบ/section × 4 sections ครอบคลุม 4 หัวข้อ — IO Core Concepts, Storage Solutions, IO Setup Best Practices, Monitoring & Troubleshooting IO
> งบเวลาโมดูล **165 นาที** (บทเรียน 75 นาที 13:00–14:15 + LAB 2 90 นาที 14:15–15:45 ตาม `Trainer_Docs/Course_Guide_4Days.md:79-80`), แล็บ **3 Exercise** ตาม `Module_02_IO/Labs/README.md`
> Code Lab (layout demo/lab → potx 06) = **3 ใบ** (สไลด์ 14, 17, 19) ≤ เพดาน 4 ใบ/โมดูล — ไม่ต้อง swap กับ Content
> ภาพ/แผนภาพทั้ง 5 ชิ้นยัง**ไม่มีใน repo** (ตรวจ `ls Module_02_IO/Sections/*/images` = No such file; `git ls-files "*.png"` = 2 ไฟล์เป็นของ M1) — ทุกชิ้นระบุ "ต้องวาดใหม่ PNG ≥2400px" ตามมติ #8 และ**ไม่ดึงภาพจาก 10987C/9Expert**
> เด็คนี้ออกแบบตาม "เป้าหมายของหัวข้อ" ไม่ใช่ย่อตามความบางของเนื้อหาปัจจุบัน — สไลด์ที่ section ต้นทางยังบาง (S2 = 20 บรรทัด, S4 = 27, S3 = 32, S1 = 73 บรรทัด ตรวจด้วย `wc -l`) มีคำว่า **"ต้องเขียนเนื้อหาเพิ่ม"** ใน Speaker notes

**แผนที่ token → potx layout** (ตาม Slide Spec 4.3 ของแผนแม่บท): `title`→01 Cover · `section-divider`→02 Module Divider · `bullets`/`bullets+diagram`/`quiz`/`summary`→03 Content · `two-column`→04 Two-Column · `demo`/`lab`→06 Code Lab — ตารางในสไลด์ 4/5/19 นำเสนอด้วย shape ตารางบน 03/04 (แทรก shape ยอมรับได้) หรือเลื่อนไป 05 Table ตอนประกอบเด็ค

---

### สไลด์ 1: Cover — Module 2: ประสิทธิภาพ I/O Subsystem
- **Layout:** `title` (potx 01 Cover dark)
- **Bullets:**
  - หลักสูตร Microsoft SQL Server Performance Tuning — 4 วัน / 24 ชม.
  - วันที่ 1 · 13:00–15:45 (บทเรียน 75 นาที + LAB 2 90 นาที)
  - จาก IOPS / Throughput / Latency สู่ DiskSpd Benchmark และ DMV Analysis
  - ฐานข้อมูลฝึก: AdventureWorks2025 · เครื่องมือ: DiskSpd, SSMS, PerfMon
- **ภาพ/แผนภาพ:** ไม่ต้องเพิ่ม — ใช้ art ของ layout 01
- **Speaker notes:** เปิดโมดูลด้วยประเด็นว่าทุก query สุดท้ายต้องผ่าน I/O Subsystem ไม่ว่า In-Memory จะเก่งแค่ไหน — ข้อมูลยังต้องถูกเขียนลง Storage Media `Ref: Module_02_IO/README.md:1-3`

### สไลด์ 2: Module Divider — แผนที่โมดูลและงบเวลา
- **Layout:** `section-divider` (potx 02 Module Divider dark)
- **Bullets:**
  - งบเวลาโมดูล: **165 นาที** (บทเรียน 75 + LAB 2 90 นาที)
  - แล็บของโมดูล: **3 Exercise** (Lab 2 — DiskSpd Benchmark & I/O Latency Analysis)
  - เส้นทาง 4 sections: Core Concepts → Storage Solutions → IO Setup Best Practices → Monitoring & Troubleshooting
  - Skill Progression ระดับ 1–4: เข้าใจ metrics → อ่านค่าจาก DMVs/PerfMon → ออกแบบ Disk/RAID → ยืนยันด้วย Benchmark
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — ใช้ roadmap text บน layout
- **Speaker notes:** ประกาศงบเวลาและจำนวน Exercise ให้ผู้เรียนรู้ก่อนเริ่มตามข้อบังคับ Slide Spec 4.2 — เวลาจริงหลังทดสอบผู้เรียนต้องเทียบกับงบ 165 นาทีนี้ `Ref: Module_02_IO/README.md:5-13` · `Ref: Trainer_Docs/Course_Guide_4Days.md:79-80`

### สไลด์ 3: IOPS · Throughput · Latency — สามตัวชี้วัดของ Storage (Section 1 เริ่มต้น)
- **Layout:** `bullets+diagram` (potx 03 Content)
- **Bullets:**
  - **IOPS** — จำนวนคำสั่งอ่าน/เขียนต่อวินาที: Random R/W สำคัญกับ OLTP, Sequential R/W สำคัญกับ OLAP และ Transaction Log
  - **Throughput (MB/s)** — ต้องดูค่า Sustained ต่อเนื่อง ไม่ใช่ Burst Speed
  - **Latency (Response Time)** — ตัวชี้วัดที่สำคัญที่สุดของ Storage Subsystem
  - ความสัมพันธ์: IOPS × ขนาด Block = Throughput — ปรับตัวไหน อีกตัวขยับตาม
- **ภาพ/แผนภาพ:** `Module_02_IO/Sections/01_IO_Core_Concepts/images/io-metrics-relationship.png` — **ต้องวาดใหม่ PNG ≥2400px** (แผนภาพสามเหลี่ยม IOPS/Throughput/Latency พร้อมตัวอย่าง workload OLTP vs OLAP)
- **Speaker notes:** ต้องรู้มาก่อน: Buffer Pool และ DMV (นิยามใน Module 0 ฉบับขั้นต่ำ + glossary กลาง — ลิงก์จะใส่เมื่อเฟส 0 ปิด) — SQL Server เก็บข้อมูลใน Memory ให้มากที่สุด อ่าน Disk เมื่อจำเป็น `Ref: Module_02_IO/Sections/01_IO_Core_Concepts/README.md:7-21` ต้องเขียนเนื้อหาเพิ่ม: section นี้ยังไม่มีบล็อก ```sql ของตัวเองและไม่มี Scripts/ (ขาดตาม DoD ราย section)

### สไลด์ 4: เกณฑ์ Latency ตามชนิดไฟล์ — Microsoft Recommendations
- **Layout:** `bullets` (potx 03; นำเสนอเป็นตาราง 3 แถว — ใช้ 05 Table ได้ตอนประกอบ)
- **Bullets:**
  - **Log File:** 1–5 ms = ประสิทธิภาพสูงสุด (Sequential Write ที่ผูกกับ Transaction Commit)
  - **Data File (OLTP):** 4–20 ms ยอมรับได้ — 10 ms ถือว่าดีมาก
  - **DSS/OLAP:** ≤ 30 ms เป็นเพดานยอมรับได้
  - วัดจาก PerfMon `Avg. Disk sec/Transfer` หรือ `io_stall` จาก DMVs
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — ตารางตัวเลข
- **Speaker notes:** ย้ำว่า Log อ่อนไหวสุดเพราะทุก commit ต้อง harden ลง log ก่อน `Ref: Module_02_IO/Sections/01_IO_Core_Concepts/README.md:17-21` ต้องเขียนเนื้อหาเพิ่ม: ตาราง latency ใน README โมดูล (`Module_02_IO/README.md:69-74`: log write > 5 ms = แก้ด่วน) ขัดกับเกณฑ์เสื่อมสภาพใน S4 (`Sections/04_Monitoring_Troubleshooting_IO/README.md:8-12`: > 10 ms = Degraded) — ต้อง normalize ก่อนขึ้นตัวเลขบน Stat Callout

### สไลด์ 5: HDD/SSD และ RAID — Write Penalty คือตัวตัดสิน
- **Layout:** `two-column` (potx 04; คอลัมน์ขวาเป็นตาราง Write Penalty)
- **Bullets:**
  - ซ้าย — **HDD**: จานหมุน ราคาถูก แต่ Latency สูง / **SSD (Flash)**: ไม่มีจานหมุน Latency ต่ำมาก เหมาะกับ Database
  - ขวา — Write Penalty: RAID 0 = 1x · RAID 1 = 2x · RAID 5 = 4x · RAID 6 = 6x · RAID 10 = 2x
  - RAID 5/6: ทุก 1 Write จริงต้องใช้ 4–6 I/O (อ่าน data + อ่าน parity + เขียน data + เขียน parity) — หลีกเลี่ยงกับ Write-heavy
  - Best Practice: **RAID 10** สำหรับ Data/Log · RAID 0 เฉพาะ TempDB (สร้างใหม่ทุก Restart) · RAID 1 สำหรับ OS/Binaries
- **ภาพ/แผนภาพ:** ตาราง Write Penalty (shape) — ไม่ต้องวาด PNG
- **Speaker notes:** คำถามคลาสสิกที่ออกสอบคือ "ทำไม RAID 5 ไม่เหมาะกับเขียนหนัก" — ตอบด้วย Write Penalty 4x จากตาราง `Ref: Module_02_IO/Sections/01_IO_Core_Concepts/README.md:22-43`

### สไลด์ 6: I/O Architecture Internals — Async I/O, Scatter-Gather, IFI
- **Layout:** `bullets+diagram` (potx 03)
- **Bullets:**
  - **Async I/O** — Thread ส่งคำสั่ง I/O แล้ว Return ทันที รองรับ I/O concurrency มหาศาลโดยไม่ต้องใช้ Thread จำนวนมาก
  - **Scatter Read / Gather Write** — อ่าน/เขียนทีละหลาย Page (1 Extent = 8 Pages) ในครั้งเดียว → ลด IOPS ที่ต้องใช้ เพิ่ม Throughput
  - **Instant File Initialization (IFI)** — ข้ามการ Zeroing ตอนสร้าง/ขยายไฟล์ → เร็วระดับวินาที; ต้องให้สิทธิ์ `Perform volume maintenance tasks`
  - ตั้งแต่ SQL Server 2022: log growth ≤ 64 MB ก็ได้ประโยชน์จาก IFI (เดิมเฉพาะ data file)
- **ภาพ/แผนภาพ:** `Module_02_IO/Sections/01_IO_Core_Concepts/images/io-architecture-internals.png` — **ต้องวาดใหม่ PNG ≥2400px** (flow: SQL Thread → Windows I/O → Signal กลับ + Scatter/Gather buffer diagram)
- **Speaker notes:** เชื่อมกับ M1: thread ที่รอ I/O จะปรากฏเป็น wait type ฝั่ง I/O ซึ่งจะลงลึกในสไลด์ 15 `Ref: Module_02_IO/Sections/01_IO_Core_Concepts/README.md:53-69` · `Ref: Module_02_IO/README.md:66`

### สไลด์ 7: DAS vs SAN vs S3 — เลือกสถาปัตยกรรม Storage (Section 2 เริ่มต้น)
- **Layout:** `bullets+diagram` (potx 03)
- **Bullets:**
  - **DAS (Direct-Attached Storage)** — ต่อตรงกับ Server: Bandwidth เฉพาะตัวสูงสุด แต่ขยายตัวยาก แชร์ทรัพยากรไม่ได้
  - **SAN (Storage Area Network)** — Fiber Channel / iSCSI: แชร์พื้นที่ + Snapshot/DR ระดับ Hardware แต่ต้นทุนสูง
  - **S3-Compatible Object Storage (SQL Server 2022+)** — รองรับเฉพาะ **Backup/Restore to S3-compatible object storage** (`BACKUP TO URL` / `RESTORE FROM URL`) — ไม่รองรับการวาง Data/Log File ผ่าน S3 API
  - เป้าหมายหัวข้อ: เลือกให้ตรง Workload ไม่ใช่เลือกของแพงที่สุด
- **ภาพ/แผนภาพ:** `Module_02_IO/Sections/02_Storage_Solutions/images/storage-architectures.png` — **ต้องวาดใหม่ PNG ≥2400px** (ไดอะแกรม 3 สถาปัตยกรรม: server↔disk ตรง / server↔FC-iSCSI↔SAN fabric / server↔S3 API↔object store เป็นปลายทาง backup to URL)
- **Speaker notes:** ต้องรู้มาก่อน: ศัพท์ Storage พื้นฐาน (LUN, Fiber Channel, iSCSI) — ดู glossary กลางเมื่อเฟส 0 ปิด `Ref: Module_02_IO/Sections/02_Storage_Solutions/README.md:5-14` ต้องเขียนเนื้อหาเพิ่ม: README ของ section นี้ยาวเพียง 20 บรรทัด (สั้นสุดของหลักสูตร ตรวจ `wc -l`) ไม่มีบล็อก ```sql และไม่มี Scripts/ — ต้องขยายตาม DoD หมายเหตุการแก้ (technical review): bullet เดิมเคยระบุ "Backup/Restore หรือวาง Data File บน Object Storage ผ่าน S3 API" เกินความจริง — S3-compatible object storage ใน SQL Server 2022+ รองรับเฉพาะ BACKUP/RESTORE TO/FROM URL (Microsoft Learn, view=sql-server-ver17) ต้นทางข้อความผิดคือ `Module_02_IO/Sections/02_Storage_Solutions/README.md:13-14` (แก้คู่กันในชุดแก้นี้)

### สไลด์ 8: DAS vs SAN — Trade-off ระหว่าง Performance กับ Enterprise Capability
- **Layout:** `two-column` (potx 04)
- **Bullets:**
  - ซ้าย **DAS** — Pros: ความซับซ้อนต่ำ ได้ Bandwidth เต็ม (Dedicated) / Cons: Scalability ต่ำ แชร์ไม่ได้
  - ขวา **SAN** — Pros: แชร์ได้ Snapshot/DR ระดับ Hardware / Cons: ต้นทุนสูง ต้องบริหาร Bandwidth (QoS)
  - ความเสี่ยงบน SAN: **Noisy Neighbor** — workload ของ server อื่นแย่ง Bandwidth ร่วม fabric
  - เกณฑ์เลือก: workload เดี่ยวเน้น Latency → DAS/NVMe local · enterprise หลาย instance ต้องการ DR → SAN
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — ใช้โครง two-column ของ layout
- **Speaker notes:** ถามผู้เรียนว่าระบบที่ทำอยู่เป็น DAS หรือ SAN และเคยเจอ Noisy Neighbor ไหม — เชื่อมกับการตีความ latency ที่แกว่งโดยไม่มีสาเหตุใน SQL `Ref: Module_02_IO/Sections/02_Storage_Solutions/README.md:6-11` ต้องเขียนเนื้อหาเพิ่ม: เพิ่มกรณีศึกษา/ตัวเลขเทียบ latency ระหว่างสถาปัตยกรรม (ตัวเลขต้องรอ sign-off รันจริง 17.x ก่อนขึ้น Stat Callout)

### สไลด์ 9: S3-Compatible Object Storage และฟีเจอร์ I/O ใหม่ใน SQL Server 2025
- **Layout:** `bullets` (potx 03)
- **Bullets:**
  - SQL Server 2022+: **Backup/Restore to S3-compatible object storage เท่านั้น** (`BACKUP TO URL` / `RESTORE FROM URL`) — ไม่รองรับการวาง Data/Log File ผ่าน S3 API (Data File บน Azure Blob เป็นฟีเจอร์ "SQL Server data files in Azure" คนละฟีเจอร์ ไม่ได้ทำงานผ่าน S3 API)
  - Use Case: Backup Storage ราคาประหยัด — เก็บไฟล์ backup/สำเนาสำรองระยะยาว
  - **ZSTD Backup Compression (ใหม่ใน 2025)** — บีบอัดเร็วขึ้นอัตราดีขึ้น ลดภาระ I/O ช่วง backup/restore (`BACKUP ... WITH COMPRESSION (ALGORITHM = ZSTD)`)
  - **tmpfs สำหรับ tempdb บน SQL Server on Linux (2025)** — วาง tempdb บน memory filesystem ได้
  - **Hybrid Buffer Pool / PMEM** — ยังมีบทบาทบนฮาร์ดแวร์ persistent memory
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — bullets + ไอคอน "2025" ของ template
- **Speaker notes:** เน้นว่า ZSTD และ tmpfs เป็นฟีเจอร์ที่กระทบ I/O Profile โดยตรงและต้องรันบน 17.x จึงจะเห็นจริง `Ref: Module_02_IO/README.md:59-67` ต้องเขียนเนื้อหาเพิ่ม: section นี้ยังไม่มี demo script เป็นของตัวเอง (ไม่มี Scripts/ ภายใต้ `Sections/02_Storage_Solutions/`) — เติมสคริปต์ Backup to S3 เมื่อขยายเนื้อหา หมายเหตุการแก้ (technical review): bullet เดิมเคยระบุ "วาง Data File บน Object Storage (AWS S3, Azure Blob) ผ่าน S3 API" เกินความจริง — แก้ให้เหลือเฉพาะ Backup/Restore to S3-compatible object storage แล้ว ต้นทางข้อความผิดคือ `Module_02_IO/Sections/02_Storage_Solutions/README.md:13-14` (แก้คู่กันในชุดแก้นี้)

### สไลด์ 10: Quiz Checkpoint — Storage Fundamentals
- **Layout:** `quiz` (potx 03)
- **Bullets:**
  - Q1: Latency ที่ดีสำหรับ Log File ควรอยู่ช่วงเท่าไร และเพราะอะไร?
  - Q2: ทำไม RAID 5 ไม่เหมาะกับ Database ที่เขียนหนัก?
  - Q3: Allocation Unit Size ที่แนะนำสำหรับ SQL Server คือเท่าไร และเกี่ยวข้องกับ Extent อย่างไร?
  - (เฉลยซ่อนอยู่ใน README ของโมดูล — ให้ผู้เรียนอ้างเหตุผลก่อนเปิด)
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ
- **Speaker notes:** ใช้เป็น checkpoint ครึ่งเด็คครอบคลุม S1+S2 ก่อนเข้าสู่ส่วน Best Practices `Ref: Module_02_IO/README.md:40-52` ต้องเขียนเนื้อหาเพิ่ม: quiz bank รายโมดูลยังไม่มีทั้งหลักสูตร (ช่องว่างตามแผน §3) — ขยายจาก 3 คำถามนี้เป็นชุดวัด learning objectives ของ M2

### สไลด์ 11: เตรียม Disk — Partition Alignment และ Allocation Unit Size 64KB (Section 3 เริ่มต้น)
- **Layout:** `bullets` (potx 03)
- **Bullets:**
  - การ Format Disk เป็นขั้นตอน **Irreversible** — ทำผิดตอน install คือต้นทุนแก้สูงสุดของโมดูลนี้
  - **Partition Alignment** — จัด Offset ของ Partition ให้ตรง Physical Sector (Windows รุ่นใหม่จัดการให้อัตโนมัติ)
  - **Allocation Unit Size = 64KB** — เพราะ SQL Server ทำ I/O เป็น Extent (64KB = 8 Pages) ลด I/O Overhead ของ File System
  - ผลลัพธ์ตามเอกสาร section: เพิ่ม Throughput ได้ 10–20% (ตัวเลขอ้างจาก README — ต้องผ่าน sign-off รันจริงก่อนขึ้น Stat Callout)
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — แสดงภาพประกอบ alignment ภายหลังเมื่อวาดชุดถัดไป
- **Speaker notes:** ต้องรู้มาก่อน: โครงสร้าง Page/Extent ระดับพื้นฐาน (glossary กลาง) — Q3 ของสไลด์ 10 มาจากหัวข้อนี้ `Ref: Module_02_IO/Sections/03_IO_Setup_Best_Practices/README.md:5-10` ต้องเขียนเนื้อหาเพิ่ม: README ยาวเพียง 32 บรรทัด — เพิ่มวิธีตรวจ Allocation Unit Size จริงด้วย `fsutil fsinfo ntfsinfo <drive>` และบล็อก ```sql ประกอบ

### สไลด์ 12: I/O Pattern → เลือก Disk ต่อชนิดไฟล์ (Data / Log / TempDB)
- **Layout:** `two-column` (potx 04)
- **Bullets:**
  - ซ้าย **Data File (.mdf)** — Pattern: Random Read/Write → ต้องการ IOPS สูง + Latency ต่ำ → SSD/NVMe + RAID 10
  - ขวา **Log File (.ldf)** — Pattern: Sequential Write (Append-only) → ต้องการ Write Latency ต่ำที่สุด → แยก Disk ลด Contention
  - **TempDB** — RAID 0 ใช้ได้เพราะไม่ต้อง Redundancy (สร้างใหม่ทุก Restart)
  - RAID 5/6 ประหยัดพื้นที่แต่ Write Penalty 4x–6x — ไม่เหมาะกับ Log และ TempDB
- **ภาพ/แผนภาพ:** `Module_02_IO/Sections/03_IO_Setup_Best_Practices/images/data-log-io-patterns.png` — **ต้องวาดใหม่ PNG ≥2400px** (เทียบ random head movement กับ sequential append)
- **Speaker notes:** ย้ำหลักคิด "ดู Pattern ก่อนเลือก RAID/สื่อ" ซึ่งจะกลายเป็นเกณฑ์ตีความผล DiskSpd ในสไลด์ 14 `Ref: Module_02_IO/Sections/03_IO_Setup_Best_Practices/README.md:12-24` ต้องเขียนเนื้อหาเพิ่ม: เพิ่มตารางตัดสินใจ (ไฟล์ × RAID × สื่อ) ให้ครบเป้าหมายหัวข้อระดับ 3 ของ Skill Progression

### สไลด์ 13: Advanced Configuration — IFI, TempDB Metadata, แนวทางปี 2025
- **Layout:** `bullets` (potx 03)
- **Bullets:**
  - **Instant File Initialization** — เปิดใช้เสมอ (ค่าเริ่มต้นใน Setup ปัจจุบัน) ลดเวลาสร้าง/ขยายไฟล์
  - **Memory-Optimized TempDB Metadata (SQL Server 2019+)** — ลด Latch Contention ใน System Table ของ TempDB เมื่อ Concurrent Temp Data สูง
  - โมเดิร์นไอโอ: tempdb บน tmpfs (Linux, 2025) และ PMEM/Hybrid Buffer Pool สำหรับฮาร์ดแวร์เฉพาะทาง
  - เชื่อมโยง Performance Center: Disk / TempDB / Data-Log Configuration
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ
- **Speaker notes:** หัวข้อ tempdb เชื่อมตรงกับ Module 3 (Database Structures) ซึ่งจะลงลึก tempdb อีกครั้ง `Ref: Module_02_IO/Sections/03_IO_Setup_Best_Practices/README.md:26-28` · `Ref: Module_02_IO/README.md:63-67` ต้องเขียนเนื้อหาเพิ่ม: เพิ่ม checklist ตรวจ IFI และ metadata optimization ด้วย DMV จริงเพื่อให้ section มีบล็อก ```sql ของตัวเอง

### สไลด์ 14: Demo — DiskSpd Command Generator และเช็กพื้นที่ Drive
- **Layout:** `demo` (potx 06 Code Lab)
- **Bullets:**
  - รัน generator → ได้คำสั่ง DiskSpd 3 แบบ: **OLTP** (8KB Random R/W 70/30), **Log** (64KB Sequential Write 100%), **DW** (512KB Sequential Read)
  - Copy คำสั่งไปรันใน **Command Prompt (Admin)** บน drive ที่วาง data/log จริง
  - [จุดสำคัญ] ระหว่าง DiskSpd ทำงาน ให้เปิด SSMS รัน Demo Drive Latency พร้อมกัน — เฝ้าว่า `Avg_Write_Latency_ms` กระโดดไหม
  - เช็กพื้นที่คงเหลือต่อ drive ด้วย `sys.dm_os_volume_stats` (Percent Free)
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — พื้นที่ code ของ layout 06
- **Script:** `Module_02_IO/Sections/03_IO_Setup_Best_Practices/Scripts/03_Diskspd_Stress_Test.sql` (generator: `PRINT` 3 scenarios :34-46) · `Module_02_IO/Sections/03_IO_Setup_Best_Practices/Scripts/05_Disk_Usage_By_Drive.sql` (CROSS APPLY `sys.dm_os_volume_stats` :12)
- **Speaker notes:** ต้องรู้ก่อน: `CROSS APPLY` = เรียก table-valued function ต่อทุกแถวฝั่งซ้าย (คนระดับ SELECT/JOIN ไม่เคยเจอ) — อ่านโค้ดในสไลด์ได้ด้วยประโยคนี้; error ที่พบได้ + รุ่นขั้นต่ำ: `diskspd.exe` ไม่พบใน PATH หรือไม่ได้รัน cmd แบบ Admin จะสร้างไฟล์ทดสอบไม่ได้ — ใช้ได้ SQL Server 2019+ แต่ทั้งสองไฟล์ยัง**ไม่มี header `MinVersion:`** (ตรวจจากการอ่านไฟล์ — 0/69 ทั้ง repo) ต้องเติมก่อนขึ้นเด็คจริงตามเกณฑ์ 4.6 `Ref: Module_02_IO/Labs/README.md:58-97`

### สไลด์ 15: Latency is King — เกณฑ์ตัดสินระดับ Log และ Data (Section 4 เริ่มต้น)
- **Layout:** `bullets+diagram` (potx 03)
- **Bullets:**
  - ตัวชี้วัดหลัก: PerfMon `Avg. Disk sec/Transfer` หรือ `io_stall` จาก DMVs
  - **Log (.ldf):** 1–5 ms Optimal · 5–10 ms Acceptable · > 10 ms Degraded (Commit ช้าลง) · > 50 ms Critical (Timeout/Blocking)
  - **Data (.mdf):** < 5 ms สูง (SSD/NVMe level) · 10–20 ms Acceptable · > 20 ms Degraded · > 100 ms Critical (System Freeze)
  - เกณฑ์นี้คือมาตรวัดเดียวกับที่ใช้ตีความผลแล็บและ demo ของโมดูล
- **ภาพ/แผนภาพ:** `Module_02_IO/Sections/04_Monitoring_Troubleshooting_IO/images/io-latency-thresholds.png` — **ต้องวาดใหม่ PNG ≥2400px** (แถบสีเขียว/เหลือง/แดง 2 แถว: Log กับ Data)
- **Speaker notes:** ต้องรู้มาก่อน: wait type ฝั่ง I/O (PAGEIOLATCH*, WRITELOG) ที่จะเชื่อมกับ M1 และ M11 — ดู glossary กลาง `Ref: Module_02_IO/Sections/04_Monitoring_Troubleshooting_IO/README.md:5-18` ต้องเขียนเนื้อหาเพิ่ม: ตัวเลขช่วง Log ใน README โมดูล (`Module_02_IO/README.md:69-74`) ยังต่างจากที่นี่ — ต้อง normalize เนื้อหาก่อนประกอบเด็ค

### สไลด์ 16: `sys.dm_io_virtual_file_stats` — อ่านค่าระดับไฟล์ให้เป็น
- **Layout:** `bullets` (potx 03)
- **Bullets:**
  - DMV นี้ให้ข้อมูล **ระดับไฟล์ (Granular)** — ระบุได้ว่าไฟล์ใด Response Time สูงสุดของ instance
  - ค่าเป็น **สะสมตั้งแต่ Startup** — ดูรายช่วงต้องเก็บ Snapshot เทียบกัน (ต่อยอดใน Lab 10)
  - จับคู่ `sys.master_files` ด้วย `database_id + file_id` — ใช้ `type_desc` แยก ROWS (data) / LOG (log)
  - หารเฉลี่ย latency ต้องกันหารศูนย์ด้วย `NULLIF(num_of_reads, 0)`
  - คอลัมน์ `io_stall_queued_*` ชี้คิวรอของ Resource Governor (ถ้าใช้)
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — แสดง code snippet บนพื้นที่ body
- **Speaker notes:** เช็กลิสต์อ่านผลลัพธ์: เรียงตาม `Avg I/O Latency` DESC แล้วดู 3 ไฟล์แรกก่อนเสมอ `Ref: Module_02_IO/Sections/04_Monitoring_Troubleshooting_IO/README.md:20-21` ต้องเขียนเนื้อหาเพิ่ม: README ของ section ยาวเพียง 27 บรรทัดและไม่มีบล็อก ```sql — ฝัง query ตัวอย่าง (มีอยู่แล้วใน Scripts/) ลง README ตาม DoD

### สไลด์ 17: Demo — จับ Latency ต่อไฟล์และต่อ Drive ระหว่าง Workload จริง
- **Layout:** `demo` (potx 06 Code Lab)
- **Bullets:**
  - Session 1: รัน workload generator ทิ้งไว้ ~5 นาที (table scan + random access + join + UPDATE ทุก 100 รอบ)
  - Session 2: วัด latency ต่อไฟล์ทั้ง instance แบบ Glenn Berry — เรียง `Avg I/O Latency` DESC
  - รวมเป็นระดับ drive ด้วย `GROUP BY LEFT(UPPER(physical_name), 2)` — หา drive ที่มีปัญหา
  - ตีความตามเกณฑ์ในสคริปต์: < 5 ms Excellent (SSD/NVMe) · 5–10 Good · 10–20 Acceptable · > 20 Potential Bottleneck
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — พื้นที่ code ของ layout 06
- **Script:** `Module_02_IO/Sections/04_Monitoring_Troubleshooting_IO/Scripts/01_Workload_IO_Activity.sql` (ลูป WHILE 300 วินาที :22-90) · `.../Scripts/04_Virtual_File_Stats.sql` (ต่อไฟล์ :7-27) · `.../Scripts/02_Drive_Latency.sql` (ต่อ drive :8-50)
- **Speaker notes:** ต้องรู้ก่อน: `NULLIF` (คืน NULL เมื่อตัวหาร = 0 กัน divide-by-zero) และ `OPTION (RECOMPILE)` (บังคับคอมไพล์ใหม่ทุกรัน เพื่อ plan ตรงกับข้อมูลจริง); error ที่พบได้ + รุ่นขั้นต่ำ: ไม่มีสิทธิ์ `VIEW SERVER STATE` จะได้ Msg 300 level 21 และต้อง restore **AdventureWorks2025** ก่อน — ใช้ได้ SQL Server 2019+ (ไม่มี syntax 2025-only ในสคริปต์ชุดนี้) แต่ทั้ง 3 ไฟล์ยังไม่มี header `MinVersion:` ต้องเติมก่อนขึ้นเด็ค `Ref: Module_02_IO/Labs/README.md:101-162`

### สไลด์ 18: วินิจฉัย — Disk ช้าจริง หรือ SQL/Queuing?
- **Layout:** `two-column` (potx 04)
- **Bullets:**
  - ซ้าย **DiskSpd** — วัดขีดจำกัดของ Subsystem **อิสระจาก SQL Server** (ผ่าน cache ด้วย `-Sh`)
  - ขวา **DMV/PerfMon** — latency ที่ SQL Server รู้สึกจริงรวมคิวทุกชั้น
  - DiskSpd ~5 ms แต่ SQL รายงาน ~100 ms → ปัญหาอยู่ที่ **Queuing/SQL** (ไม่ใช่ disk ช้า)
  - DiskSpd เองรายงาน ~100 ms → **Disk ช้าจริง** — ต้องแก้ที่ Storage Subsystem
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — ใช้โครง two-column เป็น decision fork
- **Speaker notes:** นี่คือ decision tree ที่ผู้เรียนต้องจำจากโมดูลนี้ — แยก "ของดีแต่ต่อคิวผิด" ออกจาก "ของช้าจริง" `Ref: Module_02_IO/Sections/03_IO_Setup_Best_Practices/Scripts/03_Diskspd_Stress_Test.sql:16-20`

### สไลด์ 19: Lab 2 — DiskSpd Benchmark & I/O Latency Analysis
- **Layout:** `lab` (potx 06 Code Lab)
- **Bullets:**
  - **3 Exercise**: (1) วัด Logical vs Physical Reads ด้วย `SET STATISTICS IO` + `DBCC DROPCLEANBUFFERS` (2) ทดสอบ Storage ด้วย DiskSpd — random 8KB จำลอง OLTP + sequential 64KB จำลอง log (3) วิเคราะห์ I/O จริงต่อไฟล์ด้วย `sys.dm_io_virtual_file_stats` + สร้างโหลด UPDATE
  - เกณฑ์ผ่าน: 8K random IOPS > 5,000 · latency OLTP < 5–10 ms · log write < 5 ms · 64K sequential MB/s สูงกว่า random หลายเท่า
  - Prerequisites: SQL Server 2019+ (แนะนำ 2025 (17.x)) · AdventureWorks2025 · DiskSpd.exe · สิทธิ์ `VIEW SERVER STATE` + `sysadmin` (สำหรับ DROPCLEANBUFFERS)
  - ⚠️ `DBCC DROPCLEANBUFFERS` ห้ามรันบน Production — VM ทดสอบเท่านั้น · Cleanup: `del D:\Temp\sqltest.dat`
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ — ตาราง Exercise × Step บนพื้นที่ body
- **Script:** `Module_02_IO/Labs/README.md` (Exercise 1 :25-54, Exercise 2 :58-97, Exercise 3 :101-162) — สคริปต์ประกอบอยู่ใน `Sections/03_*/Scripts/` และ `Sections/04_*/Scripts/` ของโมดูล
- **Speaker notes:** ต้องรู้ก่อน: `DECLARE`/`WHILE` (ลูป T-SQL สร้างโหลด), `NULLIF`, `CROSS APPLY` — ผู้เรียนระดับ SELECT/JOIN ต้องอ่านโค้ด Exercise 3 ออกก่อนลงมือ; error ที่พบได้ + รุ่นขั้นต่ำ: ไม่ใช่ sysadmin จะรัน `DBCC DROPCLEANBUFFERS` ไม่ได้ และแล็บใช้ได้ 2019+ แต่ยังไม่มี header `MinVersion:` ในไฟล์สคริปต์ `Ref: Module_02_IO/Labs/README.md:6-15` ต้องเขียนเนื้อหาเพิ่ม: แล็บยังไม่มีบล็อก `**Expected:**` ต่อ Exercise (ทั้งหลักสูตร 0/11 ตามมติ #7 — ปัจจุบันมีเพียงบล็อก "✅ สังเกต" ที่ :45 :54 :90 :148) ต้อง normalize ก่อนเปิดคลาส

### สไลด์ 20: Closing — สรุป Module 2 และทางต่อไป
- **Layout:** `summary` (potx 03; ปิดโมดูลใช้ 08 Closing dark ได้)
- **Bullets:**
  - สามตัวชี้วัด IOPS / Throughput / Latency — และ **Latency คือ King** พร้อมเกณฑ์ Log 1–5 ms / Data < 5–20 ms
  - RAID Write Penalty กำหนดทางเลือก: RAID 10 สำหรับ Data/Log · RAID 0 เฉพาะ TempDB
  - เตรียม Disk ให้ถูกตั้งแต่วันแรก: Partition Alignment + Allocation Unit Size 64KB + แยก Data/Log
  - วัดของจริงสองชั้น: DMV (`sys.dm_io_virtual_file_stats`) บอกความรู้สึกของ SQL · DiskSpd บอกขีดจำกัดของ Disk
  - ต่อไป: **Module 3 — Database Structures** (TempDB metadata, VLF ตรวจด้วย `sys.dm_db_log_info`) ซึ่งต่อยอด I/O Profile ของไฟล์ฐานข้อมูล
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ
- **Speaker notes:** ปิดด้วยการโยงว่า I/O ที่ช้าจะโผล่เป็น wait type ฝั่ง I/O ในโมดูลถัด ๆ ไป และเตือนผู้เรียนเก็บผล DiskSpd เป็น Baseline ส่วนตัว `Ref: Module_02_IO/README.md` · `Ref: Trainer_Docs/Course_Guide_4Days.md:54`

---

## เช็กลิสต์ความครบถ้วนของไบล์พรินต์ (ตรวจแล้วระหว่างเขียน)

| เกณฑ์ (Slide Spec) | สถานะ |
|---|---|
| จำนวนสไลด์ตามสูตร 4.2: M2 = 20 (4 + 4×4) | ✅ 20 สไลด์ — อยู่ในช่วง 12–24 ที่อนุญาต |
| Code Lab ≤ 4 ใบ/โมดูล | ✅ 3 ใบ (สไลด์ 14 demo, 17 demo, 19 lab) |
| งบเวลา + จำนวน Exercise บน Module Divider (สไลด์ 2) | ✅ 165 นาที + 3 Exercise |
| สไลด์ Lab ระบุจำนวน Exercise + `Ref: Module_*/Labs/README.md` (สไลด์ 19) | ✅ 3 Exercise |
| Notes 100% พร้อม token `Ref:` | ✅ ทุกสไลด์มี `Ref:` ชี้ path จริง |
| "ต้องรู้มาก่อน" + glossary บนสไลด์แรกของแต่ละ section (สไลด์ 3, 7, 11, 15) | ✅ — ลิงก์ glossary รอเฟส 0 (glossary ยังไม่มีไฟล์ทั้งหลักสูตร) |
| Code Lab ทุกใบ: ศัพท์/syntax ต้องรู้ก่อน + คู่ "error ที่พบได้ + รุ่นขั้นต่ำ" | ✅ สไลด์ 14, 17, 19 |
| ภาพทุกชิ้นเป็นไฟล์ใน repo | ⚠️ M2 ยังไม่มี PNG — ระบุ path เป้าหมาย 5 ชิ้นพร้อมคำว่า "ต้องวาดใหม่ ≥2400px" (สไลด์ 3, 6, 7, 12, 15) |
| Stat Callout เฉพาะตัวเลข sign-off รันจริง 17.x | ✅ เด็คนี้ไม่มีสไลด์ 07 Stat Callout — ตัวเลข README (เช่น +10–20% สไลด์ 11) ใช้เป็น bullet พร้อมหมายเหตุ sign-off |
| T-SQL บน Code Lab มีไฟล์ต้นทางจริงใน `Sections/*/Scripts/` | ✅ สไลด์ 14 (2 ไฟล์), 17 (3 ไฟล์), 19 (Labs README) — แต่ทุกไฟล์ยัง**ไม่มี header `MinVersion:`** (ตรวจจากการอ่าน 5/5 ไฟล์ — ค้างรอเฟส 0 ตามแผน) |

**หมายเหตุ:** ไฟล์นี้อยู่ภายใต้ `.gitignore` บรรทัด 66 (`Trainer_Docs/*`) จึงเป็น untracked — เป็นคำถามเปิด #3 ของแผนแม่บทให้เจ้าของคอร์สตัดสินนโยบาย git
