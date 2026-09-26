# Module 6: Statistics and Index Internals

## 1. บทนำ (Introduction)
ดัชนี (Index) เปรียบเสมือนเครื่องมือช่วยค้นหาข้อมูลที่มีประสิทธิภาพสูงสุดในระบบฐานข้อมูล ปัญหาประสิทธิภาพส่วนใหญ่ (Performance Issues) มักเกิดจากการออกแบบ Index ที่ไม่เหมาะสม หรือขาด Index ที่จำเป็นสำหรับการตอบสนอง Query (SARGable Predicates)

ในบทเรียนนี้ ผู้เรียนจะศึกษาโครงสร้างภายในของ Statistics, Index B-Tree, และ Columnstore Index

### 1.1 Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – เข้าใจ Statistics และ Cardinality Estimation**
  - อ่าน/อธิบาย Header, Density, Histogram จาก `DBCC SHOW_STATISTICS` ได้ และเข้าใจผลของ CE ต่อ Plan
- **ระดับ 2 – วิเคราะห์และดูแล Index ให้เหมาะกับ Workload**
  - แยกแยะ Heap vs Clustered/Nonclustered B-Tree, ระบุ Missing/Bad/Overlapping Index และออกแบบ Index ใหม่ที่สอดคล้องกับ Workload ได้
- **ระดับ 3 – ใช้ DMV/เครื่องมือช่วยออกแบบ Index อย่างมีวิจารณญาณ**
  - ใช้ `sys.dm_db_missing_index_*`, `sys.dm_db_index_usage_stats`, และเครื่องมือภายนอกเช่น Plan Explorer เพื่อปรับโครงสร้าง Index ให้สมดุลระหว่าง Read และ Write ตามแนวทางจาก Index Design Guide ของ Microsoft
- **ระดับ 4 – ใช้เทคโนโลยี Columnstore และฟีเจอร์ใหม่ๆ**
  - ตัดสินใจเลือกใช้ Clustered/Nonclustered Columnstore ใน DW/HTAP Scenario, เข้าใจ Rowgroup/Segment/Deltastore และข้อจำกัดของ Columnstore Index

---

## 2. Statistics Internals (Lesson 1)

### 2.1 What are Statistics?

**Statistics** คือ Object ที่ SQL Server สร้างขึ้นเพื่อเก็บข้อมูลสรุปเกี่ยวกับ **การกระจายตัว (Distribution)** ของข้อมูลในคอลัมน์ Query Optimizer ใช้ Statistics ในการตัดสินใจว่า:
- Query นี้จะได้ข้อมูลประมาณกี่แถว? (**Cardinality Estimation**)
- ควรใช้ Index Seek หรือ Index Scan?
- ควรใช้ Join Algorithm แบบไหน? (Nested Loop / Hash / Merge)

> ถ้า Statistics ไม่ถูกต้อง (Stale/Outdated) → Optimizer เลือก Plan ผิด → Query ช้า

**โครงสร้างของ Statistics (3 ส่วน):**

| Component | หน้าที่ | ใช้เมื่อไร |
|-----------|-------|----------|
| **Header** | Metadata: เวลา Update ล่าสุด, Rows Sampled | ตรวจสอบความเก่า |
| **Density Vector** | ค่า 1/Distinct Values ของคอลัมน์ | GROUP BY, Multi-column Join |
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
| **Independence** | คอลัมน์อิสระต่อกัน | เข้าใจ Correlation ระหว่างคอลัมน์ |
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

## 3. Index Internals (Lesson 2)

### 3.1 Heap & B-Tree
*   **Heap**: ตารางที่ไม่มี Clustered Index ข้อมูลถูกจัดเก็บโดยไม่มีลำดับเฉพาะ (Unordered) เข้าถึงโดยใช้ **RID (Row Identifier)**
    *   *Usecase*: เหมาะสำหรับ Staging Table ที่เน้น Insert Speed สูงสุด แต่ไม่เหมาะกับการ Search
*   **B-Tree (Balanced Tree)**: โครงสร้างข้อมูลแบบ Tree ที่มีความสมดุล
    *   *Root Node*: จุดเริ่มต้นของการค้นหา
    *   *Intermediate Levels*: ระดับกลางที่ชี้ไปยัง Page ถัดไป
    *   *Leaf Nodes*: ระดับล่างสุด (ถ้าเป็น Clustered Index จะเก็บ Data Rows จริง, ถ้าเป็น Non-Clustered จะเก็บ Pointer)

### 3.2 Index Key Best Practices
หลักการเลือก Clustered Index Key ที่เหมาะสม:
1.  **Unique**: ค่าไม่ซ้ำกัน (หากซ้ำ SQL Server จะต้องเพิ่ม Uniqueifier ขนาด 4 bytes ภายใน)
2.  **Narrow**: ขนาดเล็ก (เนื่องจาก Key นี้จะถูกนำไปเป็น Lookup Key ในทุก Non-Clustered Index)
3.  **Static**: ไม่มีการเปลี่ยนแปลงค่าบ่อย (เพื่อลด Overhead ในการย้ายตำแหน่งข้อมูล - Page Split)
4.  **Ever-increasing**: ค่าเพิ่มขึ้นตามลำดับ (Sequential) เช่น Identity/Sequence เพื่อลด Random I/O และ Page Split

### 3.3 Advanced Indexing Strategies
*   **Covering Index**: การใช้ `INCLUDE` เพื่อเพิ่ม Column ที่จำเป็นเข้าไปใน Leaf Level ของ Non-Clustered Index (ช่วยลด Key Lookup)
*   **Filtered Index**: Index ที่มีเงื่อนไข `WHERE` เพื่อลดขนาด Index และเพิ่มความเร็วสำหรับ Subset ของข้อมูล
*   **Resumable Online Index Rebuild (SQL 2019+)**: ความสามารถในการหยุดและทำต่อ (Pause/Resume) กระบวนการ Rebuild Index ได้ เพื่อความยืดหยุ่นในการจัดการ Maintenance Window
*   **Missing Indexes**: สามารถวิเคราะห์ได้จาก DMV `sys.dm_db_missing_index_details` หรือคำแนะนำใน Execution Plan

### 3.4 Bad Non-Clustered Indexes (Index ขยะ)
การมี Index มากเกินไป (Over-indexing) ส่งผลเสียต่อการ Write (Insert/Update/Delete) และเปลืองพื้นที่ Disk
*   **Unused Indexes**: สร้างไว้แต่ไม่มีใครใช้ (Read Count = 0) เป็นภาระในการ Maintenance
*   **Duplicate Indexes**: Index ที่มี Key Column เหมือนกันเป๊ะ (ซ้ำซ้อน 100%)
*   **Overlapping Indexes**: Index ที่เป็น Subset ของ Index อื่น (เช่น Index A เก็บ Col1, Index B เก็บ Col1+Col2 -> Index A คือส่วนเกินเพราะ Index B ครอบคลุมแล้ว)

### 3.5 Tool Recommendation: SentryOne Plan Explorer
แม้ว่า SSMS จะมี Missing Index Hint แต่เครื่องมือที่ผู้เชี่ยวชาญแนะนำคือ **SolarWinds (SentryOne) Plan Explorer** (Free) โดยเฉพาะฟีเจอร์ **Index Analysis**:
*   **Index Analysis Score**: ช่วยคำนวณ Score ว่า Index ที่มีอยู่มีประสิทธิภาพแค่ไหน และ Index ที่แนะนำจะช่วยลด I/O ได้กี่เปอร์เซ็นต์
*   **Aggregated Missing Indexes**: มันจะรวม Missing Index ที่คล้ายกันให้เป็น Index เดียวที่ครอบคลุม (Consolidated) ต่างจาก SSMS ที่อาจแนะนำ Index ซ้ำซ้อน
*   **Visualizing Includes**: แสดงภาพชัดเจนว่า Column ไหนถูกใช้ใน `WHERE`, `JOIN` หรือ `OC (Output Column)` ช่วยให้ตัดสินใจเลือก Key vs Include ได้แม่นยำยิ่งขึ้น

### 3.6 Microsoft Index Design Guidelines
แนวทางปฏิบัติล่าสุดจาก Microsoft Design Guide:

1.  **Workload Type**:
    *   **OLTP**: เน้น **Narrow Index** (Column น้อยๆ) เพื่อลด Overhead ตอน Insert/Update และพิจารณา *Memory-Optimized Tables* หากต้องการ Throughput สูงจัด
    *   **OLAP**: พิจารณาใช้ **Columnstore Index** เสมอสำหรับ Fact Table ขนาดใหญ่
2.  **Sort Order (ASC/DESC)**:
    *   การระบุ `ASC` หรือ `DESC` ใน Index Key มีผลเมื่อ Query มีการ `ORDER BY` หลายคอลัมน์ในทิศทางต่างกัน
    *   *Example*: `ORDER BY Col1 ASC, Col2 DESC` -> ควรสร้าง Index `(Col1 ASC, Col2 DESC)` เพื่อกำจัด **Sort Operator** (ราคาแพง) ออกจาก Plan
    *   *Note*: SQL Server สามารถอ่าน Index ย้อนกลับได้ (Bi-directional) ดังนั้น Index `ASC` สามารถรองรับ `ORDER BY DESC` ได้ (ถ้าทิศทางเหมือนกันทั้ง Index)
3.  **Operation Options**:
    *   **ONLINE = ON**: ควรใช้เสมอสำหรับ Production เพื่อไม่ให้ User ถูก Block ระหว่างสร้าง Index (Enterprise Ed.)
    *   **DATA_COMPRESSION**: พิจารณาเปิด `PAGE` Compression สำหรับ Index ขนาดใหญ่เพื่อลด I/O และ Memory usage

---

## 4. Columnstore Indexes (Lesson 3)
เทคโนโลยีการจัดเก็บข้อมูลแบบคอลัมน์ (Columnar Storage) ออกแบบมาเพื่อเพิ่มประสิทธิภาพสำหรับ Data Warehouse และ Analytical Workloads

### 4.1 Architecture
*   **Column-oriented**: การจัดเก็บข้อมูลแยกตามคอลัมน์ ทำให้สามารถอ่านเฉพาะข้อมูลที่จำเป็นต้องใช้ (ลด I/O)
*   **High Compression**: อัตราการบีบอัดสูง (10x - 100x) เนื่องจากข้อมูลในคอลัมน์เดียวกันมักมีความคล้ายคลึงกัน
*   **Batch Mode Processing**: การประมวลผลข้อมูลเป็นชุด (Vector-based, ~900 rows/batch) แทนการประมวลผลทีละแถว ซึ่งเพิ่มประสิทธิภาพ CPU อย่างมาก
*   *Types*:
    *   **Clustered Columnstore Index (CCI)**: ใช้เป็นพื้นที่จัดเก็บหลักของตาราง (Primary Storage)
    *   **Non-Clustered Columnstore Index (NCCI)**: สร้างคู่ขนานไปกับ Rowstore Table เพื่อรองรับ Real-time Analytics (HTAP)

### 4.2 Columnstore Internals
*   **Rowgroup**: หน่วยการจัดเก็บข้อมูล (Logical Group) รองรับสูงสุดประมาณ 1 ล้านแถวต่อ Rowgroup
*   **Segment**: ข้อมูลของหนึ่งคอลัมน์ภายใน Rowgroup (เป็นหน่วยในการอ่านจาก Disk)
*   **Dictionary Encoding**: เทคนิคการบีบอัดโดยการแทนที่ค่าซ้ำด้วย Reference ID
*   **Deltastore**: พื้นที่ชั่วคราว (Rowstore) สำหรับรองรับการ Insert/Update ข้อมูลจำนวนน้อย ก่อนที่จะถูกบีบอัดรวมเข้าสู่ Rowgroup
*   **Tuple Mover**: Background Process ที่ทำหน้าที่ย้ายข้อมูลจาก Deltastore เข้าสู่ Compressed Rowgroup
*   **Deleted Bitmap**: โครงสร้างสำหรับติดตามแถวที่ถูกลบ (Logical Delete) เนื่องจาก Compressed Segment ไม่สามารถแก้ไขได้โดยตรง

---

## 5. Lab: Statistics and Index Internals

**[ไปยังคำแนะนำแล็บ](Labs/README.md)**

ในแล็บนี้ คุณจะระบุ Missing Indexes, ปรับแต่ง Query โดยกำจัด Key Lookups, ตรวจหา Stale Statistics และทำความสะอาด Bad Indexes


---

## 7. 🆕 Modernization Notes: SQL Server 2019 → 2025 (อัปเดตตาม Microsoft Learn)

### 7.1 Statistics & Cardinality Estimation
- **CE Feedback for Expressions (ใหม่ใน 2025)**: engine เรียนรู้ค่า CE ที่เหมาะกับ expression (เช่น `DATEDIFF`, `CONVERT` บน predicate) จากการรันจริงข้าม query แล้วใช้ซ้ำ — ลดปัญหา CE ผิดเพี้ยนซ้ำ ๆ
- **Persisted statistics for readable secondaries (2025)**: AG readable secondary สร้าง/เก็บ stats ของ workload ฝั่ง read ได้เอง ไม่ต้องรอ stats จาก primary — แก้ปัญหา plan แย่บน secondary
- Auto update statistics async / auto drop statistics (`AUTO_DROP` — 2022) ยังเป็น default best practice

### 7.2 Columnstore ล่าสุด
- **2025**: Ordered **nonclustered** columnstore index, ordered CCI **build online** ได้ พร้อมคุณภาพ sort ที่ดีขึ้น และ SHRINK ทำงานดีขึ้นเมื่อมี CCI อยู่
- Batch mode execution ทำงานกับ built-in functions เร็วขึ้นอีกใน 2025 (เช่น math functions, DATETRUNC)

### 7.3 Index Tuning Strategy ปี 2025
- Missing Index DMVs ยังใช้ได้แต่ต้อง **review ด้วยตัวเองเสมอ** (ไม่คิด INCLUDE/ORDER, ชี้ตารางซ้ำ) — ใช้คู่กับ Query Store และ [Glenn Berry diagnostic queries สำหรับ SQL Server 2025](https://glennsqlperformance.com/resources/) หมวด Index
- Unused/duplicate index analysis ควรอิงช่วงเวลายาว ≥ 1 business cycle ก่อน DROP

> อ้างอิง: [Columnstore indexes — what's new](https://learn.microsoft.com/sql/relational-databases/indexes/columnstore-indexes-what-s-new), [IQP feature list](https://learn.microsoft.com/sql/relational-databases/performance/intelligent-query-processing), [Persisted stats on secondaries](https://learn.microsoft.com/sql/relational-databases/performance/persisted-stats-secondary-replicas)
