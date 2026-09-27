[⬅ Module 6_](../../README.md) | Section 1/3 | ➡ ถัดไป: [Index Internals](../02_Index_Internals/README.md)

## Statistics Internals (Lesson 1)

### 2.1 What are Statistics?

**Statistics** คือ Object ที่ SQL Server สร้างขึ้นเพื่อเก็บข้อมูลสรุปเกี่ยวกับ **การกระจายตัว (Distribution)** ของข้อมูลในColumn Query Optimizer ใช้ Statistics ในการตัดสินใจว่า:
- Query นี้จะได้ข้อมูลประมาณกี่แถว? (**Cardinality Estimation**)
- ควรใช้ Index Seek หรือ Index Scan?
- ควรใช้ Join Algorithm แบบไหน? (Nested Loop / Hash / Merge)

> ถ้า Statistics ไม่ถูกต้อง (Stale/Outdated) → Optimizer เลือก Plan ผิด → Query ช้า

**โครงสร้างของ Statistics (3 ส่วน):**

| Component | หน้าที่ | ใช้เมื่อไร |
|-----------|-------|----------|
| **Header** | Metadata: เวลา Update ล่าสุด, Rows Sampled | ตรวจสอบความเก่า |
| **Density Vector** | ค่า 1/Distinct Values ของColumn | GROUP BY, Multi-column Join |
| **Histogram** | กราฟกระจายข้อมูล (สูงสุด 200 Steps) | WHERE clause, Range Query |

**Histogram Columns:**
*   `RANGE_HI_KEY`: ค่าสูงสุดของช่วง (Step boundary)
*   `EQ_ROWS`: จำนวนแถวที่มีค่าเท่ากับ Key นี้
*   `RANGE_ROWS`: จำนวนแถวที่อยู่ในช่วงระหว่าง Key ก่อนหน้า

### 2.2 Cost-Based Optimization (CBO)
Query Optimizer ทำงานแบบ Cost-Based คือการค้นหา Execution Plan ที่ "ดีเพียงพอ" (Good Enough Plan) และใช้ทรัพยากรน้อยที่สุด (Lowest Cost) ภายในเวลาที่กำหนด
*   **Predicate Selectivity**: อัตราส่วนการคัดกรองข้อมูล
    *   *High Selectivity*: เงื่อนไขที่กรองแล้วเหลือข้อมูลน้อย (Unique/Specific) -> เหมาะกับ Index Seek
    *   *Low Selectivity*: เงื่อนไขที่กรองแล้วเหลือข้อมูลมาก -> อาจเหมาะกับ Index Scan

### 2.3 Cardinality Estimation (CE)

**Cardinality Estimation** คือกระบวนการที่ Optimizer ใช้ "เดา" ว่าแต่ละ Operator จะมีข้อมูลไหลผ่านกี่แถว โดยดูจาก Statistics

> ถ้า CE ผิด → Optimizer เลือก Plan ผิด → Query ช้า

**เปรียบเทียบ CE Versions:**

| Assumption | Legacy CE (< 2014) | New CE (2014+) |
|------------|-------------------|----------------|
| **Independence** | Columnอิสระต่อกัน | เข้าใจ Correlation ระหว่างColumn |
| **Uniformity** | ค่ากระจายสม่ำเสมอ | รองรับ Skewed Data |
| **Containment** | ค้นหาข้อมูลที่มีอยู่เท่านั้น | รองรับ Data ที่ไม่มี |
| **Ascending Key** | ไม่เข้าใจ | เข้าใจว่า Max อาจ > Statistics |

**ผลกระทบของ CE ที่ผิดพลาด:**

| ปัญหา | สาเหตุ | ผลกระทบ |
|-------|-------|---------|
| **Overestimation** | คาดว่าได้ข้อมูลมาก | Memory Grant สูงเกินไป, เลือก Hash Join |
| **Underestimation** | คาดว่าได้ข้อมูลน้อย | Spill to TempDB, เลือก Nested Loop กับ Table ใหญ่ |

**วิธีแก้ไขปัญหา CE:**

```sql
-- 1. ใช้ Legacy CE (Database Level)
ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = ON;

-- 2. ใช้ Legacy CE (Query Level)
SELECT * FROM Orders 
WHERE OrderDate >= '2024-01-01'
OPTION (USE HINT ('FORCE_LEGACY_CARDINALITY_ESTIMATION'));

-- 3. ใช้ Query Store Hint บังคับ CE Model (SQL 2022+)
EXEC sp_query_store_set_hints @query_id = 123, 
     @query_hints = N'OPTION(USE HINT(''FORCE_LEGACY_CARDINALITY_ESTIMATION''))';
```

> [!TIP]
> ใช้ Query Store เปรียบเทียบ Plan ใน Compatibility Level ต่างๆ ก่อน Upgrade

### 2.4 Out of Date Statistics (Stale Stats)
เมื่อข้อมูลในตารางมีการเปลี่ยนแปลง (Insert/Update/Delete) ข้อมูล Histogram ใน Statistics จะเริ่ม "เก่า" (Stale) และไม่สะท้อนความเป็นจริง ทำให้ Optimizer ประเมิน Cardinality ผิดพลาด
*   **Modification Counter (`modification_counter`)**: SQL Server จะนับจำนวนแถวที่เปลี่ยนไปตั้งแต่การทำ Update Stats ครั้งล่าสุด
*   **Thresholds (เกณฑ์การ Auto Update)**:
    *   *Old (SQL 2014 or lower)*: 20% + 500 rows (ต้องเปลี่ยนเยอะมากถึงจะ Update)
    *   *New (SQL 2016+)*: ลดเกณฑ์ลงตามขนาดตาราง (Dynamic Threshold) ทำให้ Update ถี่ขึ้น
*   **Symptoms**: Execution Plan เปลี่ยนจาก Seek เป็น Scan, ประเมินจำนวนแถวต่ำกว่าความเป็นจริง (Underestimation), เกิด Memory Spill

### 2.5 Managing Statistics
*   **Auto Create**: สร้าง Statistics อัตโนมัติสำหรับ Column ที่ถูกอ้างถึงใน Predicate แต่ยังไม่มี Index
*   **Auto Update**: อัปเดตเมื่อข้อมูลมีการเปลี่ยนแปลงถึงเกณฑ์ (Threshold)
    *   *Synchronous* (Default): Query รอการ Update Statistics จนเสร็จจึงจะทำงานต่อ (อาจเกิด Latency ชั่วขณะ)
    *   *Asynchronous*: Query ทำงานต่อด้วย Statistics เดิม และ Background Thread จะทำการ Update ในภายหลัง
    *   **Manual Update**: ควรสั่ง `UPDATE STATISTICS` ตามรอบ Maintenance (เช่น Weekly) หรือเมื่อมีการโหลดข้อมูลก้อนใหญ่ (Bulk Load)

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 6_ README](../../README.md) | ➡ ถัดไป: [Index Internals](../02_Index_Internals/README.md) | [🧪 Labs](../../Labs/README.md)
