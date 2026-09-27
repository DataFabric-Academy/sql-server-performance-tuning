[⬅ Module 7_](../../README.md) | Section 4/4

## Intelligent Query Processing (IQP) (Lesson 4)

**Intelligent Query Processing** คือกลุ่มฟีเจอร์ที่ช่วยปรับปรุง Query Performance **โดยอัตโนมัติ** โดยไม่ต้องแก้ไข Code (Minimal Implementation Effort)

> เปิดใช้งาน IQP โดยตั้งค่า **Compatibility Level** ให้สูงพอ

```sql
-- เปิดใช้ IQP ทั้งหมด (SQL 2022+)
ALTER DATABASE [YourDB] SET COMPATIBILITY_LEVEL = 160;

-- SQL 2025
ALTER DATABASE [YourDB] SET COMPATIBILITY_LEVEL = 170;
```

> [!NOTE]
> **Query Store Requirement**: หลาย Feature ใน IQP ต้องเปิด Query Store (READ_WRITE mode) เพื่อเก็บ Feedback ลง Disk

### 5.1 IQP Features by SQL Server Version

| Feature | 2017 | 2019 | 2022 | 2025 | ต้อง Query Store |
|---------|:----:|:----:|:----:|:----:|:----------------:|
| **Batch Mode Adaptive Joins** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Batch Mode Memory Grant Feedback** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Interleaved Execution (MSTVF)** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Row Mode Memory Grant Feedback** | | ✅ | ✅ | ✅ | ❌ |
| **Table Variable Deferred Compilation** | | ✅ | ✅ | ✅ | ❌ |
| **Scalar UDF Inlining** | | ✅ | ✅ | ✅ | ❌ |
| **Batch Mode on Rowstore** | | ✅ | ✅ | ✅ | ❌ |
| **Approximate Count Distinct** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Memory Grant Feedback (Persisted)** | | | ✅ | ✅ | ✅ |
| **Parameter Sensitive Plan (PSP)** | | | ✅ | ✅ | ✅ |
| **DOP Feedback** | | | ✅ | ✅ | ✅ |
| **CE Feedback** | | | ✅ | ✅ | ✅ |
| **Optimized Plan Forcing** | | | ✅ | ✅ | ✅ |
| **Optional Parameter Plan (OPPO)** 🆕 | | | | ✅ | ✅ |
| **CE Feedback for Expressions** 🆕 | | | | ✅ | ✅ |

### 5.2 Feature Deep Dive (How it works)

**1. Batch Mode on Rowstore (SQL 2019+)**
*   *Concept*: นำ **Batch Mode Execution** (ประมวลผลทีละ 900 rows) มาใช้กับ Rowstore Index (B-Tree/Heap) ปกติ
*   *Legacy*: เดิมต้องสร้าง Columnstore Index เท่านั้นจึงจะได้ Batch Mode
*   *Benefit*: เร่งความเร็ว Analytical Query (Big Scan + Aggregate) บน OLTP Table ได้โดยไม่ต้องแก้ Index

**2. Scalar UDF Inlining (SQL 2019+)**
*   *Problem*: Scalar UDF ทำงานแบบ **Iterative** (เรียก 1 ครั้งต่อ 1 แถว) และ Optimization ต่ำ
*   *Solution*: SQL Server แปลง UDF เป็น **Relational Expression** หรือ Subquery เพื่อให้ทำงานแบบ **Set-based**
*   *Result*: เร็วขึ้นหลายเท่าตัว และสามารถใช้ Parallelism ได้

**3. Table Variable Deferred Compilation (SQL 2019+)**
*   *Problem*: Table Variable (`@table`) มักถูกประเมินว่ามีแค่ **1 Row** (Fixed Estimate) ทำให้เลือก Plan ผิด
*   *Solution*: ไม่ Compile ทันที แต่รอจนเริ่ม Run (Deferred) เพื่อนับจำนวนแถวจริง (Actual Row Count) ก่อนสร้าง Plan
*   *Note*: ไม่ได้สร้าง Statistics (ต่างจาก Temp Table) แต่ใช้ Cardinality จริงในการ Compile ครั้งแรก

**4. Batch Mode Adaptive Joins (SQL 2017+)**
*   *Concept*: เลือก Join Method (Hash vs Nested Loop) **ในขณะ Runtime**
*   *Mechanism*: สร้าง Plan ที่มี 2 ทางเลือก ถ้าข้อมูลที่ Scan จริง < Threshold → ไป Nested Loop, ถ้า > Threshold → ไป Hash Join

**5. Parameter Sensitive Plan (PSP) (SQL 2022+)**
*   *Problem*: **Parameter Sniffing** ที่ Data Skew สูง (ค่าหนึ่งมี 10 แถว อีกค่ามี 1 ล้านแถว) ทำให้ Plan เดียวไม่พอ
*   *Mechanism*: ใช้ **Dispatcher** ลงใน Plan Cache เพื่อตรวจสอบค่า Parameter ตอน Runtime (Dispatcher Expression)
*   *Query Variants*: สร้าง Plan ย่อย (Variants) แยกตามช่วงข้อมูล (Low, Medium, High Cardinality Ranges)
*   *Result*: Query เดียวกันจะมี **Multiple Cached Plans** ที่เหมาะสมกับแต่ละช่วงข้อมูลโดยอัตโนมัติ

**6. Memory Grant Feedback**
*   *Basic (2017/2019)*: จำว่า Query รอบที่แล้วใช้ Memory **เกิน** (Wasted) หรือ **ขาด** (Spill) และปรับขนาด Grant ในรอบถัดไป (Cached Plan)
*   *Persistence (2022)*: บันทึกข้อมูล Grant ลง **Query Store** ทำให้จำค่าได้แม้ Plan ถูก Cache Evict หรือ Restart Server
*   *Percentile (2022)*: ใช้ข้อมูล **Percentile** จากประวัติหลายๆ ครั้ง เพื่อหาค่า Grant ที่เหมาะสมที่สุดสำหรับ Workload ที่แกว่ง (Oscillating Data Size) ไม่ใช่แค่ดูครั้งล่าสุด

**7. Optional Parameter Plan (OPPO) (SQL 2025)**
*   *Problem*: Pattern `WHERE (@p IS NULL OR col = @p)` มักได้ Plan แบบ **Index Scan** ตลอดเวลา แม้จะระบุค่า @p
*   *Solution*: ใช้กลไก **Multiplan** (Dispatcher) แยก 2 Plan:
    1. กรณี `@p IS NULL` → ใช้ Scan Plan
    2. กรณี `@p IS NOT NULL` → ใช้ Seek Plan
*   *Benefit*: ได้ประสิทธิภาพสูงสุดทั้งสองกรณีโดยไม่ต้องแก้ Code เป็น `IF/ELSE` หรือใช้ `OPTION(RECOMPILE)`

**8. DOP Feedback (SQL 2022+)**
*   *Mechanism*: ตรวจจับ Query ที่มี Parallelism สูงเกินไป (Excessive Parallelism) โดยดูจาก Wait Types
*   *Adjustment*: หากพบปัญหา จะค่อยๆ ลดค่า DOP ลงในการรันครั้งถัดไป (Step-down) และตรวจสอบว่า Performance ดีขึ้นหรือไม่
*   *Validation*: จะหยุดลดเมื่อ Performance เริ่มคงที่ (Stabilized) หรือแย่ลง (Reverted)
*   *Note*: Minimum DOP คือ 2 (ไม่ลดจนเป็น Serial) และเพิกเฉยต่อ Waits ภายนอกเช่น Buffer Latch, Network I/O

**9. CE (Cardinality Estimation) Feedback (SQL 2022+)**
*   *Problem*: CE Model ที่ใช้อาจไม่เหมาะกับข้อมูล (เช่น คาดว่าColumnสัมพันธ์กันแต่จริงๆ อิสระต่อกัน)
*   *Mechanism*: ตรวจสอบผลลัพธ์จริงเทียบกับที่เดาไว้ (Actual vs Estimated Rows)
*   *Adjustment*: ทดลองเปลี่ยนสมมติฐาน (Model Assumption) ผ่าน **Query Store Hints** เช่น `ASSUME_MIN_SELECTIVITY_FOR_FILTER_ESTIMATES`
*   *Scenarios*: ปรับเรื่อง Correlation (Independence vs Full Correlation) และ Join Containment

**10. CE Feedback for Expressions (SQL 2025)**
*   *Concept*: ขยาย CE Feedback ให้ละเอียดระดับ **Sub-expression** (ไม่ได้เหมาทั้ง Query)
*   *Benefit*: รองรับ Query ที่ไม่ซ้ำ (Ad-hoc) แต่มี **Pattern ของ Expression ซ้ำๆ** (เช่น Join คู่เดิม)
*   *Advanced*: สามารถใช้ CE Model คนละแบบใน Query เดียวกันได้ (เช่น Part A ใช้ Base Containment, Part B ใช้ Simple Containment)

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 7_ README](../../README.md) | [🧪 Labs](../../Labs/README.md)
