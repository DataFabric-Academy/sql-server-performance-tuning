[⬅ Module 2_](../../README.md) | Section 1/4 | ➡ ถัดไป: [Storage Solutions](../02_Storage_Solutions/README.md)

## Core Concepts (Lesson 1)

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

---

[⬅ ก่อนหน้า](../../README.md) | [Module 2_ README](../../README.md) | ➡ ถัดไป: [Storage Solutions](../02_Storage_Solutions/README.md) | [🧪 Labs](../../Labs/README.md)
