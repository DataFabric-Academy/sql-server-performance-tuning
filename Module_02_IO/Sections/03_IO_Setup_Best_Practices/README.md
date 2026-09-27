[⬅ Module 2_](../../README.md) | Section 3/4 | ➡ ถัดไป: [Monitoring Troubleshooting IO](../04_Monitoring_Troubleshooting_IO/README.md)

## I/O Setup & Best Practices (Lesson 3)

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

---

[⬅ ก่อนหน้า](../../README.md) | [Module 2_ README](../../README.md) | ➡ ถัดไป: [Monitoring Troubleshooting IO](../04_Monitoring_Troubleshooting_IO/README.md) | [🧪 Labs](../../Labs/README.md)
