[⬅ Module 1_](../../README.md) | Section 2/2

## Common Scenarios & Resolution Strategies

### Scenario A: High CPU Utilization
*   *Potential Cause*: มักเกิดจาก Table Scan, Index Scan ขนาดใหญ่, Compilation ภาระสูง (Plan Bloat), หรือ Spinlock Contention
*   *Investigation*: ใช้ `Module_07/Sections/03_Analyzing_Query_Plans/Scripts/06_Top_CPU_Queries.sql` เพื่อหา Query ที่ใช้ CPU สูงสุด
*   *Resolution*: ปรับปรุง Query (Tuning), สร้าง Index เพื่อเปลี่ยน Scan เป็น Seek, หรือปรับ Plan Cache Configuration

### Scenario B: High Blocking/Deadlocks
*   *Potential Cause*: Long-running Transactions, Poor Index Design, หรือ Application ที่ไม่ปล่อย Lock
*   *Investigation*: ตรวจสอบ Blocking Chain ด้วย `sys.dm_exec_requests` และ `sys.dm_tran_locks`
*   *Resolution*: ปรับปรุง Index, พิจารณา RCSI, หรือแก้ไข Application Code

### Scenario C: High I/O Latency
*   *Potential Cause*: ปริมาณข้อมูล (Working Set) มากกว่า Memory ที่มี (Buffer Pool Trashing) หรือ Storage Subsystem มีประสิทธิภาพไม่เพียงพอ
*   *Investigation*: ตรวจสอบ PerfMon (Avg Disk sec/Read), ค่า Page Life Expectancy (PLE) ต่ำ
*   *Resolution*: เพิ่ม Memory (Hardware Scale-up), ปรับปรุง Indexing เพื่อลด Physical Reads, หรือ Optimize Storage IOPS

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 1_ README](../../README.md) | [🧪 Labs](../../Labs/README.md)
