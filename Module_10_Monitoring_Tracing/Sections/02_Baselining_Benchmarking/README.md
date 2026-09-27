[⬅ Module 0_](../../README.md) | Section 2/2

## Baselining and Benchmarking (Lesson 2)

### 3.1 Understanding Baseline vs Benchmark
*   **Baseline**: ข้อมูลทางสถิติที่แสดง **"สถานะปกติ"** ของระบบในช่วงเวลาต่างๆ (เช่น Peak/Off-peak) ใช้สำหรับเปรียบเทียบเพื่อระบุความผิดปกติ (Anomaly Detection)
*   **Benchmark**: เกณฑ์มาตรฐานหรือเป้าหมายที่กำหนดไว้ (Performance Goal) หรือขีดจำกัดสูงสุดที่ระบบรับได้ (ผ่านการทำ Stress Test)

### 3.2 Methodology & Strategy
*   **Metrics**: เก็บข้อมูล Key Resources (CPU, Memory, Disk), SQL Statistics (Batch Requests/sec), Database Size, และ Wait Statistics
*   **Frequency**: ความถี่ในการเก็บข้อมูล (PerfMon: ทุก 15-60 วินาที, DMVs: ทุก 5-15 นาที)
*   **Retention**: ระยะเวลาการเก็บรักษาข้อมูล (แนะนำ 3-6 เดือน เพื่อวิเคราะห์แนวโน้มการเติบโต - Capacity Planning)

### 3.3 Data Collection Techniques
1.  **Using PerfMon**: สร้าง *Data Collector Sets* เพื่อบันทึกข้อมูลแบบอัตโนมัติ (.blg logs) และวิเคราะห์ด้วยเครื่องมือเช่น PAL (Performance Analysis of Logs)
2.  **Using DMVs**: สร้าง Scheduled Job เพื่อบันทึกค่า Snapshot จาก `sys.dm_os_wait_stats` (Calculate Deltas) เพื่อวิเคราะห์รูปแบบ Wait Profile ในแต่ละช่วงเวลา

#### Recommended PerfMon Counters

**CPU Counters:**
| Counter | Object | Threshold | Notes |
|---------|--------|-----------|-------|
| % Processor Time | Processor | < 80% | ค่าเฉลี่ย, Sustained > 80% = ปัญหา |
| Processor Queue Length | System | < 2 per CPU | > 2 บ่งชี้ CPU bottleneck |

**Memory Counters:**
| Counter | Object | Threshold | Notes |
|---------|--------|-----------|-------|
| Available MBytes | Memory | > 500MB | หน่วยความจำเหลือใช้ขั้นต่ำ (ควร > 100MB เป็นอย่างน้อย) |
| Page Life Expectancy | Buffer Manager | > 300s | ถ้าต่ำกว่านี้แสดงว่า Memory Pressure (ข้อมูลเข้าออก Pool เร็วเกิน) |
| Pages/sec | Memory | < 50 | สูง = Excessive paging |
| Buffer Cache Hit Ratio | Buffer Manager | > 95% | ต่ำ = ต้องเพิ่ม RAM |


**Disk Counters:**
| Counter | Object | Threshold | Notes |
|---------|--------|-----------|-------|
| Avg. Disk sec/Read | LogicalDisk | < 20 ms | > 20 ms = Disk bottleneck |
| Avg. Disk sec/Write | LogicalDisk | < 20 ms | Log file ควร < 5 ms |
| Disk Reads/sec | LogicalDisk | Baseline | เปรียบเทียบกับ Baseline |
| Disk Writes/sec | LogicalDisk | Baseline | เปรียบเทียบกับ Baseline |
| Current Disk Queue Length | LogicalDisk | < 2 | สูง = Disk overloaded |

**SQL Server Counters:**
| Counter | Object | Threshold | Notes |
|---------|--------|-----------|-------|
| Batch Requests/sec | SQLServer:SQL Statistics | Baseline | Workload indicator |
| SQL Compilations/sec | SQLServer:SQL Statistics | < 100 | สูง = Plan not cached |
| SQL Re-Compilations/sec | SQLServer:SQL Statistics | < 10 | สูง = Excessive recompiles |
| Lock Waits/sec | SQLServer:Locks | < 1 | สูง = Blocking issues |
| Full Scans/sec | SQLServer:Access Methods | Baseline | สูง = Missing indexes |
| Forwarded Records/sec | SQLServer:Access Methods | < 10 | สูง = Heap fragmentation |

### 3.4 Load & Stress Testing Tools
*   **Diskspd**: เครื่องมือสำหรับทดสอบประสิทธิภาพ I/O ของ Storage System (Max IOPS/Throughput)
*   **Distributed Replay**: เครื่องมือสำหรับจำลอง Workload โดยการ Replay Trace File จากเครื่อง Client หลายเครื่องพร้อมกัน (ให้ผลลัพธ์ที่ใกล้เคียงความจริงมากกว่า SQL Profiler Replay)

---

---

## Performance Center Strategy (Microsoft Recommendations)

**Performance Center** คือแนวคิดการดูแลระบบแบบองค์รวม (Holistic View) ที่ Microsoft แนะนำ โดยแบ่งเป็น 3 เสาหลักที่ต้อง Monitor และ Tune อย่างสม่ำเสมอ:

### 4.1 Configuration Checklist (สิ่งที่ต้องตระหนัก) (ดูรายละเอียดใน Module 02)
*   **Memory**: ตั้งค่า `Max Server Memory` เสมอ (อย่าปล่อย Default ที่กินหมดเครื่อง)
*   **Parallelism**:
    *   `MAXDOP`: ตั้งค่าตามจำนวน Core (มักไม่เกิน 8) เพื่อป้องกัน Excessive Parallelism
    *   `Cost Threshold for Parallelism`: ปรับขึ้นจาก 5 (System Default) เป็น 25-50 เพื่อกรอง Query เล็กๆ ไม่ให้ใช้ Parallel
*   **TempDB**: แยก Data Files ตามจำนวน Core และวางบน Disk ที่เร็วที่สุด (SSD/NVMe)

### 4.2 Maintenance Checklist (สิ่งที่ต้องทำประจำ) (ดูรายละเอียดใน Module 06)
*   **Statistics**: หัวใจสำคัญของ Query Optimizer ต้อง Update เสมอ (เปิด Auto Update และทำ Manual Update สำหรับ Table ใหญ่)
*   **Fragmentation**: ดูแล Index ให้เรียงตัวสวยงาม (Reorganize/Rebuild) เพื่อลด I/O
*   **Backups**: ตรวจสอบว่า Backup Compression เปิดใช้งานหรือไม่เพื่อประหยัดพื้นที่

### 4.3 Modern Feature Usage (สิ่งที่ควรพิจารณาใช้)
*   **Query Store**: (Module 08) เปิดใช้งานเพื่อ Monitoring ประวัติการทำงาน Query ย้อนหลัง
*   **IQP (Intelligent Query Processing)**: (Module 07) ใช้ Compatibility Level ล่าสุดเพื่อให้ Engine แก้ปัญหา Performance ให้เอง
*   **Data Compression**: ใช้ Row/Page Compression เพื่อลด I/O และ Memory Footprint
*   **Partitioning**: สำหรับ Table ขนาดใหญ่มาก เพื่อจัดการข้อมูลง่ายขึ้น (Manageability) และเร็วขึ้น (Partition Pruning)

> [!NOTE]
> การ Monitoring ที่ดีไม่ใช่แค่ดู "Graph" แต่คือการตรวจสอบว่า Configuration และ Maintenance Plan สอดคล้องกับ Best Practices ของ **Performance Center** หรือไม่

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 0_ README](../../README.md) | [🧪 Labs](../../Labs/README.md)
