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

---


## 📚 Sections (สารบัญบทเรียน)

| # | Section |
|---|---------|
| 1 | [IO Core Concepts](Sections/01_IO_Core_Concepts/README.md) |
| 2 | [Storage Solutions](Sections/02_Storage_Solutions/README.md) |
| 3 | [IO Setup Best Practices](Sections/03_IO_Setup_Best_Practices/README.md) |
| 4 | [Monitoring Troubleshooting IO](Sections/04_Monitoring_Troubleshooting_IO/README.md) |

---


## 🧪 Labs

คู่มือปฏิบัติแบบ Instruction + Code block: [Labs/README.md](Labs/README.md) — สคริปต์ประกอบอยู่ใน `Sections/*/Scripts/` ตามหัวข้อ

---


## <details>
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

---


## ### 8.1 เครื่องมือทดสอบ I/O
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