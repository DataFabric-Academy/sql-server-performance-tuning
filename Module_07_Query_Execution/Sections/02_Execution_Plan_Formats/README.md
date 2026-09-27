[⬅ Module 7_](../../README.md) | Section 2/4 | ➡ ถัดไป: [Analyzing Query Plans](../03_Analyzing_Query_Plans/README.md)

## Query Execution Plans (Lesson 2)

### 3.1 Plan Types
*   **Estimated Plan**: แผนการทำงานที่ Optimizer คาดการณ์ (ยังไม่มีการประมวลผลจริง) ใช้สำหรับการตรวจสอบโครงสร้าง Plan
*   **Actual Plan**: แผนการทำงานจริงที่ได้หลังจากการประมวลผล ประกอบด้วย Runtime Statistics (เช่น Actual Rows vs Estimated Rows)

### 3.2 Live Query Statistics (Real-time Plan Analysis)

**Live Query Statistics** คือความสามารถในการดู Execution Plan **ขณะที่ Query กำลังทำงาน** พร้อม Animation แสดง Data Flow แบบ Real-time

> เหมาะสำหรับการติดตาม **Long-running Queries** เพื่อดูว่า Query "ติด" อยู่ที่ Operator ไหน

**วิธีใช้งาน:**

| วิธี | ขั้นตอน |
|------|--------|
| **SSMS Query Window** | คลิก "Include Live Query Statistics" ก่อนรัน Query |
| **Activity Monitor** | คลิกขวาที่ Session → "Show Live Execution Plan" |
| **DMV** | Query `sys.dm_exec_query_profiles` |

```sql
-- ดู Live Statistics ผ่าน DMV
SELECT 
    session_id,
    node_id,
    physical_operator_name,
    row_count,
    estimate_row_count,
    elapsed_time_ms
FROM sys.dm_exec_query_profiles
WHERE session_id = <target_session_id>;
```

> [!NOTE]
> **Lightweight Query Profiling** (SQL 2019+) เปิดใช้งานเป็น Default ทำให้ `sys.dm_exec_query_profiles` มี Overhead ต่ำมาก

### 3.3 Plan Formats
*   **Graphical**: รูปแบบกราฟิก (มาตรฐานใน SSMS) อ่านลำดับการทำงานจากขวาไปซ้าย
*   **XML**: รูปแบบข้อความที่มีความละเอียดสูงสุด (สามารถบันทึกเป็นไฟล์ `.sqlplan`)
*   **Text**: รูปแบบข้อความ (Legacy) ปัจจุบันไม่นิยมใช้เนื่องจากอ่านยาก

### 3.4 Advanced Query Processing Architecture (Microsoft Guide)

1.  **Parallel Query Processing**:
    *   **Exchange Operators**: เมื่อ Query รันแบบ Parallel จะมี Operator พิเศษชื่อ **Exchange** (`Distribute Streams`, `Repartition Streams`, `Gather Streams`) แทรกเข้ามาใน Plan เพื่อจัดการ Data Flow ระหว่าง Threads
    *   **DOP Dynamics**: SQL Server สามารถลด DOP อัตโนมัติได้หาก Thread ไม่พอ (ดู Available Worker Threads)
    *   **Inhibitors**: สิ่งที่ขัดขวาง Parallelism เช่น *Scalar UDFs* (ก่อน 2019), *Recursive CTEs*, *MSTVFs*, *TOP* keyword

2.  **Batch Mode Execution Internals**:
    *   **Vector-based**: ประมวลผลทีละ Batch (Vector) ไม่ใช่ทีละ Row ทำให้ CPU Efficiency สูงมาก (ใช้ CPU Cache ได้คุ้มค่า)
    *   **Hardware Friendly**: ออกแบบมาเพื่อ Modern Multi-Core CPU
    *   *Evolution*: เดิมผูกกับ Columnstore Index แต่ปัจจุบันใช้กับ Rowstore ได้แล้ว (SQL 2019+)

3.  **Distributed Query Architecture**:
    *   SQL Server ใช้ **OLE DB** เป็นสื่อกลางในการคุยกับ External Data Sources (Linked Server)
    *   **Relational Engine** จะแตก Query ออกเป็น operations ย่อยๆ ส่งให้ OLE DB Provider (เช่นอ่าน Rowset)
    *   *Ad-hoc Connector*: ใช้ `OPENROWSET` หรือ `OPENDATASOURCE` สำหรับการเชื่อมต่อชั่วคราว (แต่ต้องระวัง Security และอาจถูกปิดโดย `DisallowAdhocAccess`)

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 7_ README](../../README.md) | ➡ ถัดไป: [Analyzing Query Plans](../03_Analyzing_Query_Plans/README.md) | [🧪 Labs](../../Labs/README.md)
