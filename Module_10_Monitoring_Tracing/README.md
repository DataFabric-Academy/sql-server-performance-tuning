การเฝ้าระวัง (Monitoring) และการสร้างฐานข้อมูลเปรียบเทียบ (Baselining) เป็นขั้นตอนพื้นฐานที่สำคัญที่สุดในการบริหารจัดการประสิทธิภาพ หากปราศจาก Baseline ที่ดี ผู้ดูแลระบบจะไม่สามารถระบุได้ว่าพฤติกรรมปัจจุบันของระบบนั้น "ผิดปกติ" หรือไม่

### 1.1 Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – เข้าใจเครื่องมือและ DMVs สำคัญสำหรับ Monitoring**
  - แยก Snapshot DMV vs Cumulative DMV, เข้าใจบทบาทของ PerfMon, Ring Buffers, Activity Monitor, XEvents เบื้องต้น
- **ระดับ 2 – สร้างและอ่าน Baseline ได้**
  - ออกแบบ Data Collector/Job ที่เก็บ CPU/Memory/Disk/Waits ตามช่วงเวลา, อ่านค่าเทียบ Baseline เพื่อแยก “ปกติ” กับ “ผิดปกติ” ได้
- **ระดับ 3 – ใช้ Performance Center ของ Microsoft เป็น Checklist**
  - เชื่อมโยงสิ่งที่ Monitor กับหมวดหมู่ใน [Performance Center for SQL Server Database Engine and Azure SQL Database](https://learn.microsoft.com/en-us/sql/relational-databases/performance/performance-center-for-sql-server-database-engine-and-azure-sql-database?view=sql-server-ver17) เช่น Configuration, Query Performance Options, Monitoring/Tuning Guides ได้
- **ระดับ 4 – ออกแบบ Monitoring & Alerting Strategy สำหรับองค์กร**
  - เลือก Metrics/Threshold ที่เหมาะกับ Workload ของตนเอง, ผูกกับเครื่องมือภายนอก (เช่น SCOM, Azure Monitor, Grafana/Prometheus) และกำหนด Runbook การตอบสนองเมื่อเกิด Alert อย่างเป็นระบบ

---

---


## 📚 Sections (สารบัญบทเรียน)

| # | Section |
|---|---------|
| 1 | [Monitoring Tracing](Sections/01_Monitoring_Tracing/README.md) |
| 2 | [Baselining Benchmarking](Sections/02_Baselining_Benchmarking/README.md) |

---


## 🧪 Labs

คู่มือปฏิบัติแบบ Instruction + Code block: [Labs/README.md](Labs/README.md) — สคริปต์ประกอบอยู่ใน `Sections/*/Scripts/` ตามหัวข้อ

---


## <details>
<summary><b>1. Baseline กับ Benchmark ต่างกันอย่างไร?</b></summary>
Baseline คือข้อมูลสถิติที่แสดง "สถานะปกติ" ของระบบ ส่วน Benchmark คือเกณฑ์มาตรฐานหรือเป้าหมายที่กำหนดไว้
</details>

<details>
<summary><b>2. DMV ตัวไหนใช้ตรวจสอบ Active Queries?</b></summary>
sys.dm_exec_requests ใช้ตรวจสอบคำสั่งที่กำลังทำงานอยู่และสถานะการ Blocking
</details>

<details>
<summary><b>3. ค่า Avg. Disk sec/Read เท่าไหร่ถือว่าเริ่มมีปัญหา?</b></summary>
มากกว่า 20ms เริ่มมีปัญหาคอขวด (Potential Bottleneck) และควรตรวจสอบ Storage Subsystem
</details>

---

---


### 7.1 ชุดเครื่องมือปัจจุบัน
- **Glenn Berry — SQL Server 2025 Diagnostic Queries** คือ baseline suite มาตรฐาน (ดาวน์โหลดจาก [glennsqlperformance.com/resources](https://glennsqlperformance.com/resources/)) — รันทั้งชุดแล้วเก็บผลเป็นไฟล์/spreadsheet เทียบเดือนต่อเดือน
- บทบาท server ใหม่ (SQL Server 2022+) `##MS_ServerPerformanceStateReader##` ให้สิทธิ์อ่าน DMV ด้าน performance โดยไม่ต้อง sysadmin — ใช้กับ monitoring account เสมอ
- **Query Store** คือ baseline ที่ดีที่สุดระดับ query (ต่อเวลา อัตโนมัติ) — ใช้คู่กับ wait stats ระดับ instance
- dbatools (PowerShell): `Test-DbaLastBackup`, `Get-DbaWaitStatistic`, `Invoke-DbaDbDbccCheckTable` ฯลฯ สำหรับ automation

### 7.2 Key Metrics ที่ยังใช้ได้ (และข้อควรระวัง)
| Metric | แหล่ง | ข้อควรระวัง |
|:-------|:------|:-----------|
| Wait stats (top, per interval) | `sys.dm_os_wait_stats` | ค่าสะสม — เก็บ delta เทียบ snapshot |
| CPU % / Scheduler queue | PerfMon `% Processor Time`, `sys.dm_os_schedulers` | ดู signal wait คู่กัน |
| Page life expectancy | PerfMon Buffer Node | อย่าใช้ 300s เดิม — ดู trend ต่อ NUMA |
| File I/O latency | `sys.dm_io_virtual_file_stats` | ค่าเฉลี่ยสะสม — snapshot เทียบ |
| Long-running / regressed query | Query Store | เปิด READ_WRITE ทุก production DB |

### 7.3 Alerting Threshold ตัวอย่างที่แนะนำตอนเริ่ม
- CPU > 80% นาน > 15 นาที · `SIGNAL_WAIT%` > 10% ต่อเนื่อง · log file latency > 5 ms · tempdb growth > 80% · lock waits > 5,000 ms บ่อย ๆ · Query Store regressed query ใหม่

> อ้างอิง: [Performance Monitoring and Tuning Tools](https://learn.microsoft.com/sql/relational-databases/performance/performance-monitoring-and-tuning-tools), [dbatools](https://dbatools.io/)