# SQL Server Performance Tuning and Optimizing

<div align="center">

![SQL Server](https://img.shields.io/badge/SQL%20Server-2019%20%7C%202022%20%7C%202025-CC2927?style=for-the-badge&logo=microsoft-sql-server&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)

**คอร์ส SQL Server Performance Tuning ฉบับภาษาไทย**  
*เนื้อหาถูกเรียบเรียงมาจาก Microsoft Course 10987C โดยมีการปรับปรุงเนื้อหาและสคริปต์ให้ทันสมัย*

[📖 เริ่มต้นใช้งาน](#-การใช้งาน) • [📚 โครงสร้างบทเรียน](#-โครงสร้างบทเรียน-course-structure) • [🗓️ ตารางอบรม 4 วัน](Trainer_Docs/Course_Guide_4Days.md) • [🤝 Credits](#-credits)

</div>

---

## 📋 ภาพรวม (Overview)

คอร์สนี้ครอบคลุมการปรับปรุงประสิทธิภาพ SQL Server ตั้งแต่พื้นฐานสถาปัตยกรรมไปจนถึงเทคนิคขั้นสูง โดยเน้นการใช้งาน Dynamic Management Views (DMVs), Extended Events, และเครื่องมือวินิจฉัยสมัยใหม่

> **การจัดอบรมโดย Trainocate**: หลักสูตร 4 วัน (24 ชั่วโมง) ตาม Outline อย่างเป็นทางการ — ดูตารางเวลารายวัน, วัตถุประสงค์ และแผนการสอนฉบับเต็มได้ที่ **[Trainer_Docs/Course_Guide_4Days.md](Trainer_Docs/Course_Guide_4Days.md)**

### ✨ คุณสมบัติหลัก

- ✅ **11 Modules** ตรงตาม Outline หลักสูตร (บทที่ 1–11) ครอบคลุมทุกด้านของ Performance Tuning
- ✅ **Modern Scripts** อัปเดตตาม SQL Server 2025 — Optimized Locking, IQP รุ่นใหม่ (OPPO, CE Feedback), Query Store ล่าสุด, TempDB ADR/Governance
- ✅ **Hands-on Labs** รูปแบบ *Instruction + Code block* — ทุก Step รันได้ทันทีจากเอกสารเดียว
- ✅ **Workload Scripts** สำหรับทดสอบและสาธิต
- ✅ **Best Practices** จาก Microsoft Learn, Course 10987C และ Glenn Berry Diagnostic Queries (SQL Server 2025)

---

## 📚 โครงสร้างบทเรียน (Course Structure)

| Module | หัวข้อ | คำอธิบาย | ระดับ |
|:------:|:------|:---------|:-----:|
| **[01](./Module_01_Architecture_Scheduling_Waits/README.md)** | Architecture, Scheduling, and Waits | เข้าใจการทำงานของ SQLOS, Schedulers และ Wait Stats | ⭐⭐⭐ |
| **[02](./Module_02_IO/README.md)** | I/O Subsystem | การวัดผลและการจัดการ I/O Latency | ⭐⭐⭐ |
| **[03](./Module_03_Database_Structures/README.md)** | Database Structures | Data Files, Log Files, VLFs และ TempDB | ⭐⭐ |
| **[04](./Module_04_Memory/README.md)** | Memory | Buffer Pool, Page Life Expectancy และการตั้งค่า Memory | ⭐⭐⭐ |
| **[05](./Module_05_Concurrency/README.md)** | Concurrency | Locking, Blocking, Isolation Levels และ Deadlocks | ⭐⭐⭐⭐ |
| **[06](./Module_06_Statistics_Index_Internals/README.md)** | Statistics and Indexes | Index Fragmentation, Missing Indexes และ Statistics | ⭐⭐⭐⭐ |
| **[07](./Module_07_Query_Execution/README.md)** | Query Execution | การอ่าน Execution Plan และปัญหา Performance Killers | ⭐⭐⭐⭐ |
| **[08](./Module_08_Plan_Caching/README.md)** | Plan Caching | Plan Bloat, Recompilation และ Parameterization | ⭐⭐⭐ |
| **[09](./Module_09_Extended_Events/README.md)** | Extended Events | การใช้งาน XEvents แทน Profiler | ⭐⭐⭐ |
| **[10](./Module_10_Monitoring_Tracing/README.md)** | Monitoring and Baselines | การทำ Performance Baseline ด้วย PerfMon | ⭐⭐⭐ |
| **[11](./Module_11_Troubleshooting/README.md)** | Troubleshooting | สรุปแนวทางการวิเคราะห์ปัญหา | ⭐⭐⭐⭐⭐ |

### 🗓️ ผังการอบรม 4 วัน (24 ชั่วโมง)

| วัน | หัวข้อ | บทที่ |
|:---:|:-------|:------|
| **วันที่ 1** | Architecture & I/O Foundation | 1–3 |
| **วันที่ 2** | Memory, Concurrency & Index | 4–6 |
| **วันที่ 3** | Query Processing & Plan Management | 7–9 |
| **วันที่ 4** | Monitoring, Tuning Strategy & Troubleshooting | 10–11 + Case Study |

> ตารางเวลาละเอียดรายชั่วโมง → [Trainer_Docs/Course_Guide_4Days.md](Trainer_Docs/Course_Guide_4Days.md)

---

## 🚀 การใช้งาน (Usage)

### โครงสร้างโฟลเดอร์

ทุกสคริปต์สำหรับผู้เรียนอยู่ที่เดียว (ไม่ต้องเปิดสองที่):

```
Module_XX_Topic/
└── Labs/
    ├── README.md          # 📝 คู่มือ Lab แบบ Instruction + Code block (ครบในตัว)
    └── Scripts/           # 🧪 ไฟล์ประกอบ Lab: workload generators + สคริปต์วิเคราะห์เชิงลึก
```

### Prerequisites

| ข้อกำหนด | รายละเอียด |
|:--------|:----------|
| **SQL Server** | 2025 (แนะนำ) หรือ 2019/2022 — ฟีเจอร์เฉพาะรุ่นมีหมายเหตุกำกับ |
| **Database** | **AdventureWorks2025** (แนะนำ) — บน SQL Server 2019/2022 ใช้ AdventureWorks2022 |
| **Permissions** | `VIEW SERVER STATE`, `VIEW DATABASE STATE` |
| **Tools** | SSMS 20/21, DiskSpd, Query Store, Extended Events |

### ขั้นตอนการเริ่มต้น

1. **Clone Repository**
   ```bash
   git clone https://github.com/yourusername/MS-SQL-Server-Performance-Tuning.git
   cd MS-SQL-Server-Performance-Tuning
   ```

2. **Setup Database**
   - ดาวน์โหลด [AdventureWorks2025.bak](https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2025.bak) แล้ว Restore (วิธีทำจาก [Microsoft Learn](https://learn.microsoft.com/sql/samples/adventureworks-install-configure?view=sql-server-ver17&tabs=ssms)) — หากใช้ SQL Server 2019/2022 ให้ใช้ AdventureWorks2022.bak และแก้ชื่อ DB ในสคริปต์
   - Restore database ลงใน SQL Server instance ของคุณ

3. **Verify Setup**
   - ตรวจสอบความพร้อมของระบบก่อนเริ่มเรียน
   - ตรวจความพร้อมด้วย `Module_10_Monitoring_Tracing/Labs/Scripts/04_Daily_Health_Check.sql`

4. **เริ่มเรียน**
   - เริ่มจาก Module 01 เพื่อเข้าใจพื้นฐาน
   - ทำตาม Demo Scripts ก่อน แล้วค่อยทำ Labs

---

## 📖 แนวทางการเรียนรู้ (Learning Path)

### 🎯 สำหรับผู้เริ่มต้น
1. Module 01 → Module 02 → Module 03 → Module 04
2. เน้นทำความเข้าใจพื้นฐานก่อน

### 🎯 สำหรับผู้มีประสบการณ์
1. Module 05 → Module 06 → Module 07
2. เน้นการวิเคราะห์และแก้ไขปัญหาจริง

### 🎯 สำหรับผู้เชี่ยวชาญ
1. Module 08 → Module 09 → Module 10 → Module 11
2. เน้นเทคนิคขั้นสูงและการทำ Baseline

---

## 🛠️ สคริปต์ที่ใช้ (Scripts Overview)

### Lab Scripts (`Labs/Scripts/`) — ที่เดียวสำหรับผู้เรียน
ทุกสคริปต์รวมอยู่ในโฟลเดอร์เดียวต่อโมดูล คู่กับคู่มือ `Labs/README.md` แบบ Instruction + Code block

- **Workload Scripts** (`Workload_*.sql`): สร้างโหลดจำลอง (CPU / I/O / Blocking) เพื่อให้แล็บเห็นปัญหาจริง
- **Diagnostic Scripts**: สคริปต์วิเคราะห์เชิงลึก (หลายไฟล์อ้างอิง Glenn Berry Diagnostic Queries)

- **Hands-on Exercises**: ฝึกปฏิบัติตามสถานการณ์จริง
- **Challenge Scripts**: ทดสอบความเข้าใจด้วยปัญหาที่ซับซ้อน

---

## 📊 สถิติ Repository

- **Total Modules**: 11
- **Total Scripts**: 100+ SQL scripts
- **Workload Scripts**: 15+
- **Lab Exercises**: 50+

---

## 🤝 Credits

### Original Course
- **Microsoft Course 10987C**: Performance Tuning and Optimizing SQL Server

### Additional Resources
- **[Glenn Berry](https://glennsqlperformance.com/)**: SQL Server Diagnostic Information Queries (2025)
- **[SQLSkills](https://www.sqlskills.com/)**: Wait Statistics Library
- **[Microsoft Learn](https://learn.microsoft.com/sql/)**: Performance Center Documentation

### License
This repository is for educational purposes. Scripts are provided as-is with attribution to original authors.

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## ⚠️ Disclaimer

สคริปต์ใน Repository นี้จัดทำขึ้นเพื่อวัตถุประสงค์ทางการศึกษาเท่านั้น  
**กรุณาใช้ความระมัดระวัง** เมื่อรันสคริปต์บน Production Environment

---

<div align="center">

**⭐ ถ้าคุณพบว่าคอร์สนี้มีประโยชน์ กรุณา Star Repository นี้ ⭐**

Made with ❤️ for the SQL Server Community

</div>
