# Module 02 — I/O Subsystem: Quiz Bank

> คลังข้อสอบประกอบบทที่ 2 (Course Guide 4 วัน): Sequential vs Random · Read/Write · Log I/O vs Data I/O · IOPS/Throughput/Latency และความสัมพันธ์ · RAID 0/1/5/10 trade-offs · การทดสอบ I/O ด้วย DiskSpd (SQLIO ถูกเลิกใช้) · การตีความ `sys.dm_io_virtual_file_stats`
> ระดับข้อสอบ: Intermediate–Advanced (300–400) — อ้างอิงเนื้อหา Sections 2.1–2.4 และ Labs ของโมดูล

---

## คำถาม

### ข้อ 1 — IOPS กับ Throughput (ความสัมพันธ์)

Server A วัดได้ 10,000 IOPS ที่ block size 8 KB ส่วน Server B วัดได้ 2,000 IOPS ที่ block size 512 KB

- A. Server A มี throughput สูงกว่า (~80 MB/s เทียบ ~16 MB/s)
- B. Server B มี throughput สูงกว่า (~1,000 MB/s เทียบ ~80 MB/s)
- C. ทั้งคู่ throughput เท่ากันเพราะ IOPS สมดุลกับขนาด block
- D. เปรียบเทียบไม่ได้ เพราะ IOPS กับ MB/s เป็นคนละหน่วยที่ไม่เกี่ยวข้องกัน

### ข้อ 2 — Latency ของ Transaction Log

ระบบ OLTP วัด avg write latency ของไฟล์ .ldf ได้ 12 ms ต่อเนื่อง ข้อสรุปใดถูกต้องที่สุด

- A. ยอมรับได้ — log เป็น sequential write จึงทน latency สูงได้กว่า data
- B. มีปัญหา — เพราะทุก transaction ที่ commit ต้องรอ log flush (WAL) latency นี้จึงโดนตรงกับผู้ใช้ทุกคนที่เขียน
- C. ไม่มีผล — การเขียน log ทำโดย Checkpoint/Lazy Writer ในเบื้องหลัง ผู้ใช้ไม่รอ
- D. เป็นเรื่องปกติของ HDD — เกณฑ์ log เท่ากับ data (< 20 ms) เสมอ

### ข้อ 3 — Logical vs Physical Read

รัน `SELECT COUNT(*) FROM Sales.SalesOrderDetail` รอบแรกหลัง `DBCC DROPCLEANBUFFERS` ได้ logical reads 274, physical reads 1, read-ahead 272; รอบที่สองได้ logical reads 274, physical reads 0 ข้อสรุปใดผิด

- A. Logical reads คงที่ทั้งสองรอบเพราะเป็น "งานของ query" ไม่ขึ้นกับ cache
- B. Physical read ในรอบแรกคือ 273 pages จริง แต่ถูกยื่นเป็น read-ahead เป็นก้อนใหญ่
- C. Logical reads เท่ากันแสดงว่า query ใช้ index ที่แคบที่สุด (ไม่ได้สแกน clustered index ทั้งต้น)
- D. Physical reads = 0 ในรอบสองแปลว่า query ไม่มีการอ่าน page เกิดขึ้นเลย

### ข้อ 4 — Random vs Sequential

จับคู่งานกับ pattern และตัวชี้วัดที่ถูกต้อง

1. Index seek หาแถวเดียวใน OLTP
2. Backup database ทั้งก้อน
3. Transaction log flush ของ transaction ปกติ
4. Data warehouse scan ตารางใหญ่

- A. 1-random read/IOPS, 2-sequential write/throughput, 3-sequential write/latency, 4-sequential read/throughput
- B. 1-sequential read/throughput, 2-sequential write/throughput, 3-random write/IOPS, 4-random read/IOPS
- C. 1-random read/IOPS, 2-random write/latency, 3-sequential write/throughput, 4-sequential read/IOPS
- D. ทั้งหมดเป็น random I/O เพราะ SQL Server เขียนเป็น page 8 KB เสมอ

### ข้อ 5 — RAID Write Penalty

จะย้าย OLTP เขียนหนัก (5,000 log writes ต่อวินาที) จาก RAID 10 ไป RAID 6 ผลต่อ I/O จริงของฝั่ง log เป็นอย่างไร

- A. ไม่เปลี่ยน — parity คำนวณใน cache แล้ว
- B. เพิ่มจาก ~10,000 เป็น ~30,000 IOPS จริง (penalty จาก 2x เป็น 6x) — latency ของทุก commit แย่ตาม
- C. ลดลง — RAID 6 มี disk เยอะกว่าจึงยิงคู่ขนานได้มากกว่า
- D. เพิ่มเฉพาะตอนอ่าน — การเขียน log บน parity RAID ไม่ต้องอ่าน parity

### ข้อ 6 — TempDB กับ RAID 0

เหตุผลใดทำให้ RAID 0 (ไม่มี redundancy) ใช้กับ TempDB ได้แม้ฝ่าฝืนกฎ "ข้อมูลสำคัญห้ามไม่มีสำรอง"

- A. TempDB เขียนน้อยจนไม่มีความเสี่ยง
- B. TempDB ถูกสร้างใหม่ทั้งหมดทุกครั้งที่ restart SQL Server — ไม่มีข้อมูลถาวรให้สูญหาย
- C. SQL Server ทำ mirror ของ TempDB ให้เองในระดับ engine
- D. RAID 0 ไม่ได้ลดความเสี่ยง เพราะ parity แทน mirror ทำหน้าที่คุ้มครองแล้ว

### ข้อ 7 — ความเข้าใจเรื่อง S3/Object Storage (SQL Server 2022+)

ข้อความใดถูกต้องแม่นยำที่สุด

- A. SQL Server 2022 วาง data file บน AWS S3 ได้ผ่าน S3 API
- B. S3-compatible Object Storage ใช้กับ Backup/Restore ได้เท่านั้น (BACKUP TO URL / RESTORE FROM URL) — การวาง data file บน Azure Blob เป็นฟีเจอร์ "SQL Server data files in Azure" คนละฟีเจอร์ ไม่ได้ทำงานผ่าน S3 API
- C. Object storage ให้ random page access เร็วระดับ NVMe จึงเหมาะกับ data file
- D. S3 ใช้กับ transaction log ได้เพราะ log เขียน append เท่านั้น

### ข้อ 8 — Instant File Initialization (IFI)

ระบบเพิ่งติดตั้ง SQL Server 2022 พบว่าขยาย log file ช้ามาก แต่ขยาย data file เร็วระดับวินาที คำอธิบายที่ถูกต้อง

- A. IFI เสีย — ต้อง restart service
- B. IFI ครอบคลุม data file เสมอ แต่ฝั่ง log จะได้ประโยชน์เฉพาะ autogrowth ที่ ≤ 64 MB (SQL Server 2022+) — ก้อนใหญ่กว่านั้นยังต้อง zeroing
- C. Log file ไม่เคยได้ประโยชน์จาก IFI ในทุกรุ่น
- D. ควรตั้ง log growth เป็น percent เพื่อลดจำนวนครั้งที่ต้อง zeroing

### ข้อ 9 — ตีความ sys.dm_io_virtual_file_stats

คิวรี file stats ระบุไฟล์ X มี avg_io_latency 4 ms (ค่าสะสมตั้งแต่ startup) ข้อสรุปใดถูกต้อง

- A. ระบบตอนนี้ช้า — 4 ms บอก latency ปัจจุบันเสมอ
- B. ค่า 4 ms คือเฉลี่ยตลอดชีพ server — ต้องทำ delta snapshot สองจุดเวลาเพื่อดูช่วงเวลาที่ต้องการจริง
- C. io_stall คือเวลานาฬิกาที่ disk ทำงาน ไม่ควรหารด้วยจำนวน I/O
- D. ต้องเพิ่ม RAM ทันทีเมื่อเห็นค่าเกิน 1 ms

### ข้อ 10 — Delta Snapshot

ในเดโม delta snapshot (Section 2.4) จาก workload 60 รอบ UPDATE ผลออกมา: LOG delta_writes = 480, ROWS delta_writes = 169 เหตุใด LOG เขียนมากกว่ามาก

- A. Log เขียนข้อมูลซ้ำสามเท่าเพื่อความปลอดภัย
- B. ทุก commit ต้อง flush log buffer ลง .ldf (60 transactions → หลาย flush) ส่วน data file ถูกเขียนโดย Checkpoint/LazyWriter รวบก้อนในเบื้องหลัง
- C. Checkpoint ทำงานทุกวินาทีจึงเขียน data น้อยกว่า
- D. เพราะ RCSI ทำให้ data file เขียนน้อยลงสามเท่า

### ข้อ 11 — แยก PAGEIOLATCH กับ PAGELATCH

Session A รอด้วย wait `PAGELATCH_EX` นาน 800 ms มือใหม่เสนอ "อัปเกรด disk เป็น NVMe" ประเมินที่ถูกต้อง

- A. ถูกต้อง — PAGELATCH คือการรอ disk
- B. ผิด — `PAGELATCH_*` (ไม่มี IO) คือการรอ latch ใน memory เช่น last-page insert หรือ tempdb contention; เปลี่ยน disk ไม่ช่วย ต้องแก้ design
- C. `PAGELATCH_EX` เกิดเฉพาะไฟล์ log — ควรย้าย log แทน
- D. ควรเพิ่ม max worker threads ก่อนแก้อย่างอื่น

### ข้อ 12 — DiskSpd (วิธีทดสอบ)

คำสั่ง `diskspd -c2G -d60 -r -w30 -t2 -o8 -b8K -Sh -h C:\Temp\test.dat` — ข้อใดอธิบายถูกต้องครบ

- A. จำลอง OLTP: 8 KB random, write 30% / read 70%, 2 threads, queue depth 8, 60 วินาที โดย `-Sh` ปิด software+hardware cache เพื่อวัดของจริง
- B. จำลอง log: 8 KB sequential write 30 วินาที — `-Sh` เปิด cache ให้ได้ตัวเลขดีที่สุด
- C. จำลอง DW: 512 KB sequential read — ใช้เทียบกับขนาด backup
- D. รันได้ทั้งใน SSMS และ Command Prompt — เครื่องมือทำงานผ่าน T-SQL โดยตรง

### ข้อ 13 — File Placement

ระบบมีงบจัด 3 volumes: NVMe RAID 0, SSD RAID 10 (2 ชุด), HDD RAID 1 วางอย่างไรดีที่สุด

- A. OS บน NVMe, data บน SSD, log+tempdb บน HDD, backup บน NVMe
- B. log+tempdb บน NVMe, data บน SSD RAID 10, OS บน SSD อีกชุด, backup บน HDD
- C. backup บน NVMe เพราะเร็วสุดทำ backup เสร็จเร็ว, ที่เหลือวนกันไป
- D. วางทุกไฟล์รวมกันบน SSD RAID 10 เพื่อให้ทุกอย่างเร็วเท่ากัน

### ข้อ 14 — Cross-check SQL กับ OS

SQL รายงาน avg latency ของ data file 3 ms ตลอด แต่ PerfMon `Avg. Disk sec/Transfer` รายงาน 28 ms — ข้อสรุปใดเป็นไปได้มากที่สุด

- A. DMV ของ SQL ผิดพลาด — ควรเชื่อ PerfMon เสมอ
- B. มี I/O ผู้บุกรุกที่ไม่ผ่าน SQL Server (เช่น antivirus real-time scan, backup ระดับไฟล์) มาแย่ง disk — ส่วนต่างคือของ process อื่น
- C. Disk เกิด cache hit ตลอดจึง SQL เห็นเร็วกว่าจริง
- D. ต้องรัน `DBCC SQLPERF` เพื่อ reset ค่า แล้ววัดใหม่

### ข้อ 15 — Playbook การแก้ PAGEIOLATCH

`PAGEIOLATCH_SH` สูงเป็น top wait ทางใดที่ควรตรวจ "ก่อน" ตัดสินใจอัปเกรด storage

- A. ตรวจ logical reads ของ query ร้อน (SET STATISTICS IO / missing index) และ PLE — เพราะการลดจำนวน I/O ที่ต้นทาง (index) และการลดความถี่ที่ต้องลง disk (memory) ถูกกว่าและแก้ถาวรกว่าการเปลี่ยนอุปกรณ์
- B. อัปเกรด storage ก่อนเสมอ — ทุก PAGEIOLATCH แปลว่า disk ไม่พอ
- C. ตั้ง MAXDOP = 1 เพื่อลด I/O ขนาน
- D. เปลี่ยน recovery model เป็น SIMPLE เพื่อลดการเขียน log

---

## เฉลยและคำอธิบาย

**ข้อ 1 — B** · Throughput = IOPS × ขนาด I/O ÷ 1024 → A = 10,000 × 8/1024 ≈ 78 MB/s, B = 2,000 × 512/1024 = 1,000 MB/s งาน sequential (backup/scan) จะชอบ B; งาน OLTP random ที่ทำทีละ 8 KB จะสนใจ IOPS+latency ของ A (Section 2.1 หัวข้อ 1.2)

**ข้อ 2 — B** · ตามหลัก WAL ทุก transaction ต้องรอ log flush จบก่อนตอบ client — latency log จึงโดนทุก writer ตรง ๆ เกณฑ์ log จึงเข้มกว่า data (1–5 ms optimal, > 10 ms เรื่องต้องแก้) ข้อ C ผิดเพราะปนกันระหว่าง log กับ data flush (data ต่างหากเป็นหน้าที่ของ Checkpoint/LazyWriter) (Section 2.1 หัวข้อ 1.3, 5)

**ข้อ 3 — D** · Physical reads = 0 หมายถึง *ไม่ต้องลง disk* ไม่ใช่ไม่มีการอ่าน — 274 logical reads เกิดขึ้นทุกรอบเพียงแต่อ่านจาก Buffer Pool ทั้งหมด ข้อ A, B, C ล้วนถูกตามที่วัดจริงบนสภาพแวดล้อมหลักสูตร (Section 2.1 หัวข้อ 3)

**ข้อ 4 — A** · Seek หาแถวเดียว = random 8 KB ดู IOPS; backup = sequential write ก้อนใหญ่ดู throughput; log flush = sequential write ที่ชี้ชะตาด้วย *latency*; DW scan = sequential read ดู throughput (Section 2.1 หัวข้อ 1.1, 2.3)

**ข้อ 5 — B** · RAID 10 penalty = 2x, RAID 6 = 6x — 5,000 writes/วินาที บวมจาก 10,000 เป็น 30,000 IOPS จริงและ latency ของทุก commit แย่ตาม ทางออกคือ RAID 10/ที่ไม่ใช้ parity กับ log (Section 2.2 หัวข้อ 5)

**ข้อ 6 — B** · TempDB ไม่เก็บข้อมูลถาวร — restart แล้วสร้างใหม่จาก model จึงเสี่ยงสูญเสีย "ข้อมูล" ไม่ได้ ประโยชน์ที่ได้คือประสิทธิภาพเต็มที่ (Section 2.2 หัวข้อ 5)

**ข้อ 7 — B** · ข้อจำกัดที่ต้องพูดให้แม่น: S3 (SQL 2022+) = backup/restore เท่านั้น; data file บน Azure Blob = ฟีเจอร์คนละชุด ไม่ผ่าน S3 API; object storage ไม่มี random page access จึงตอบโจทย์ "ไฟล์ทั้งก้อน เขียนครั้งเดียว" (Section 2.2 หัวข้อ 6.2)

**ข้อ 8 — B** · กฎของ SQL Server 2022+: IFI ครอบ data file เสมอ (เมื่อได้สิทธิ์ Perform Volume Maintenance Tasks) และครอบ log autogrowth ได้เฉพาะ ≤ 64 MB ทางแก้คือตั้ง log growth เป็น MB คงที่ไม่เกิน 64 MB (Section 2.3 หัวข้อ 4.2, 5.1)

**ข้อ 9 — B** · ค่าทั้งหมดใน DMF นี้เป็นค่าสะสมตั้งแต่ startup — ตัวเลขเดี่ยวอ่านเป็น "ทรงรวม" ได้ แต่การวินิจฉัยช่วงเวลาต้อง delta snapshot ข้อ C ผิดเพราะ io_stall คือผลรวมเวลาที่ *task* รอ (I/O ขนานทำให้ไม่เท่าเวลานาฬิกา) แต่หารด้วยจำนวน I/O ก็คือวิธีคำนวณ avg latency ที่ถูกต้อง (Section 2.4 หัวข้อ 2.1–2.2, 3.1)

**ข้อ 10 — B** · หัวใจของโมดูล: log flush ผูกกับ transaction (ทุก commit ต้องเกิด) ส่วน data flush เป็นงานเบื้องหลังที่รวบก้อน — 60 commits จึงเกิด flush ~480 ครั้ง ขณะ checkpoint เขียน dirty pages รวบ ๆ เพียง 169 ครั้ง (Section 2.4 หัวข้อ 3.2; ย้ำจาก 2.1 หัวข้อ 5)

**ข้อ 11 — B** · ต่างกันที่คำ IO คั่นกลาง: `PAGEIOLATCH_*` = รอ page จาก disk, `PAGELATCH_*` = รอ latch ใน memory (short-term synchronization) แก้ด้วยการออกแบบ เช่น last-page insert hot spot หรือ tempdb มีไฟล์น้อย/ไม่เท่ากัน — ไม่ใช่เรื่องอุปกรณ์ (Section 2.4 หัวข้อ 4; Latch ลงลึกใน Module 5)

**ข้อ 12 — A** · `-r` random, `-w30` write 30%, `-b8K` ตรงกับ page ของ SQL Server, `-t2/-o8` thread × queue depth, `-Sh` ปิดทั้ง software และ hardware write cache เพื่อไม่ให้ได้ตัวเลขฝันจาก cache และ DiskSpd เป็น EXE ระดับ VM ต้องรันใน Command Prompt/PowerShell บน VM ตรง ๆ ห้ามรันระหว่าง demo บน shared VM (Section 2.3 หัวข้อ 6.2; Labs Exercise 2)

**ข้อ 13 — B** · เรียงตาม "ความอดทนต่อ latency": log+tempdb (ต้องเร็วที่สุด — log เพราะทุก commit, tempdb เพราะเกิดใหม่ได้จึง RAID 0 ได้) บน NVMe; data (IOPS หนัก ต้อง redundancy) บน SSD RAID 10; OS (ไม่ต้องเร็ว) บน SSD อีกชุด; backup (throughput ก็พอ) บน HDD — และ backup ห้ามอยู่ volume เดียวกับ data (Section 2.2 หัวข้อ 7; 2.3 หัวข้อ 2.1)

**ข้อ 14 — B** · DMV ของ SQL นับเฉพาะ I/O ของ engine ส่วน PerfMon นับทั้ง volume เมื่อ OS เห็นแย่กว่า SQL มาก แปลว่ามีผู้อื่นใช้ disk — antivirus real-time scan, backup ระดับไฟล์, indexing service เป็นตัวเอกเสมอ ทางแก้คือ exclusion list และการจัดหน้าต่างเวลา (Section 2.4 หัวข้อ 6; 2.3 หัวข้อ 1.3)

**ข้อ 15 — A** · ลำดับความคุ้ม: ลดจำนวน I/O (index/query) → ลดความถี่ที่ต้องลง disk (memory/PLE) → อัปเกรดอุปกรณ์ (แพงสุด) — ซื้อ disk เร็วเพื่อรองรับ query แย่คือทางที่แพงและแก้ไม่จบ ยกเว้นเมื่อตรวจแล้วสองทางแรกเป็นปกติจริง (Section 2.4 หัวข้อ 5.1, 7)

---

## เกณฑ์การให้คะแนน (สำหรับผู้สอน)

| คะแนน (จาก 15) | การประเมิน |
|:----------------|:------------|
| 13–15 | ผ่านระดับออกแบบ/รีวิว storage ได้ — พร้อมเริ่ม Module 3 |
| 10–12 | เข้าใจแนวคิดครบ ควรทวน delta snapshot + playbook ใน 2.4 อีกครั้ง |
| < 10 | กลับไปทำ Lab 2 ให้จบ (DiskSpd + file stats) แล้วอ่านซ้ำ Section 2.1 (ความสัมพันธ์ของสามตัวชี้วัด) กับ 2.4 (playbook) |
