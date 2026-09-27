[⬅ Module 3_](../../README.md) | Section 2/4 | ➡ ถัดไป: [Transaction Log Internals](../03_Transaction_Log_Internals/README.md)

## Data File Internals (Lesson 2)

### 3.1 Volume Configuration Best Practices
*   **RAID Configuration**: แนะนำ RAID 10 สำหรับ Log Files เพื่อรองรับ Write Intensive Workload และ RAID 5/10 สำหรับ Data Files
*   **Formatting**: ควรกำหนด *Allocation Unit Size* เป็น **64KB** เพื่อให้สอดคล้องกับขนาดของ Extent
*   **Isolation**: ควรแยก Data Files และ Log Files ออกจากกันในระดับ Physical Disk เพื่อลด I/O contention

### 3.2 Instant File Initialization (IFI)
*   **Concept**: การลดระยะเวลาในการจองพื้นที่ Disk (Allocation) โดยข้ามขั้นตอนการเขียน Zero-filling
*   **Benefit**: เพิ่มความเร็วในการทำงานของคำสั่ง `CREATE DATABASE`, `RESTORE`, และ `Autogrow`
*   **Requirement**: ต้องกำหนดสิทธิ์ `Perform Volume Maintenance Tasks` ให้กับ SQL Server Service Account

### 3.3 Auto Grow & Shrink Strategy
*   **Auto Grow**: ควรพิจารณาเป็นมาตรการสำรอง (Safety Net) เท่านั้น
    *   *Configuration*: ควรกำหนดเป็น Fixed Size (MB) แทน Percentage (%) เพื่อไม่ให้การขยายตัวแต่ละครั้งใช้เวลานานเกินไป
*   **Auto Shrink**: **ไม่แนะนำให้ใช้งาน (Strongly Discouraged)**
    *   ก่อให้เกิด Index Fragmentation ระดับสูง
    *   สิ้นเปลือง CPU และ I/O จากวงจรการ Shrink-then-Grow

### 3.4 Logical vs Physical I/O
*   **Logical I/O**: การอ่านข้อมูลจาก Buffer Pool (RAM) -> มีประสิทธิภาพสูง
*   **Physical I/O**: การอ่านข้อมูลจาก Disk -> มี Latency สูง
*   **Goal**: อัตราส่วน *Buffer Cache Hit Ratio* ควรสูงเกือบ 100% เพื่อลด Physical I/O

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 3_ README](../../README.md) | ➡ ถัดไป: [Transaction Log Internals](../03_Transaction_Log_Internals/README.md) | [🧪 Labs](../../Labs/README.md)
