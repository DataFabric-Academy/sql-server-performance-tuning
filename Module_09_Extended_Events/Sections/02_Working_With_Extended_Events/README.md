[⬅ Module 9_](../../README.md) | Section 2/2

## Working with Extended Events (Lesson 2)

### 3.1 Configuring Targets
*   **Event File (.xel)**: บันทึกลง Disk (Asynchronous) เหมาะสำหรับการเก็บข้อมูลระยะยาว (Long-term retention) หรือปริมาณมาก
*   **Ring Buffer**: บันทึกลง Memory แบบ FIFO (First-In, First-Out) เหมาะสำหรับการตรวจสอบเบื้องต้น (Ad-hoc monitoring) *ข้อควรระวัง: ข้อมูลอาจสูญหายได้ง่าย*
*   **Histogram (Bucketing)**: การจัดกลุ่มและนับจำนวนเหตุการณ์ใน Memory (Aggregation) เช่น การนับจำนวน Deadlock แยกตาม Database
*   **Event Pairing**: การจับคู่ Event เริ่มต้นและสิ้นสุดเพื่อค้นหา Incomplete Transactions

### 3.2 The system_health Session
Default Session ที่รันอยู่ตลอดเวลา (Always-on) เพื่อบันทึกข้อมูลสุขภาพของระบบที่สำคัญ:
*   *Deadlocks*: บันทึก Deadlock Graph output
*   *Severe Errors*: บันทึก Error ที่มีความรุนแรง (Severity >= 20)
*   *Long Waits*: การรอทรัพยากรที่นานผิดปกติ (> 15s/30s)
*   *Memory*: ปัญหา Memory Allocation Failures

### 3.3 Usage Scenarios
*   **Execution Time-outs**: ตรวจสอบโดยจับคู่ `sql_statement_starting` และ `completed` หรือใช้ `rpc_completed` ที่มี `result = 2` (Abort)
*   **Errors**: จับ Event `error_reported` เพื่อตรวจสอบ Error ที่อาจถูกละเลยโดย Application (Swallowed Errors)
*   **Recompilations**: จับ `sql_statement_recompile` ร่วมกับ Histogram เพื่อระบุ Object ที่เกิด Recompile บ่อยที่สุด

### 3.4 Modern Extended Events (2017+) (Lesson 3)
เครื่องมือและฟีเจอร์ใหม่ที่เพิ่มความสะดวกในการใช้งาน

#### 1. XEvent Profiler (SSMS 17.3+)
เครื่องมือที่ผสานประสบการณ์ผู้ใช้ (UX) ของ SQL Profiler เข้ากับประสิทธิภาพของ Extended Events
*   *Usage*: SSMS -> Object Explorer -> XE Profiler -> Standard
*   *Benefit*: สามารถดูข้อมูลแบบ Live Stream (Live Watch) ได้โดยมี Overhead ต่ำ

#### 2. Lightweight Query Profiling
โครงสร้างพื้นฐานใหม่สำหรับการติดตาม Query Execution
*   *Legacy*: Event `query_post_execution_showplan` มีผลกระทบต่อประสิทธิภาพสูง (High Performance Overhead)
*   *Modern*: Event `query_thread_profile` ใช้งาน Infrastructure ใหม่ที่มีความเบา (Lightweight)
*   *Live Query Stats*: ช่วยให้สามารถดูความคืบหน้าของ Query ได้แบบ Real-time (เป็น Default ใน SQL Server 2019+)

#### 3. Azure SQL Integration
บน Cloud เราไม่มี Local Drive ให้เขียนไฟล์ .xel
*   *Target*: ต้องเขียนลง **Azure Blob Storage** แทน
*   *Analysis*: โหลดไฟล์ .xel จาก Blob มาเปิดใน SSMS เครื่องเราได้เลย

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 9_ README](../../README.md) | [🧪 Labs](../../Labs/README.md)
