[⬅ Module 6_](../../README.md) | Section 2/3 | ➡ ถัดไป: [Columnstore Indexes](../03_Columnstore_Indexes/README.md)

## Index Internals (Lesson 2)

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
    *   การระบุ `ASC` หรือ `DESC` ใน Index Key มีผลเมื่อ Query มีการ `ORDER BY` หลายColumnในทิศทางต่างกัน
    *   *Example*: `ORDER BY Col1 ASC, Col2 DESC` -> ควรสร้าง Index `(Col1 ASC, Col2 DESC)` เพื่อกำจัด **Sort Operator** (ราคาแพง) ออกจาก Plan
    *   *Note*: SQL Server สามารถอ่าน Index ย้อนกลับได้ (Bi-directional) ดังนั้น Index `ASC` สามารถรองรับ `ORDER BY DESC` ได้ (ถ้าทิศทางเหมือนกันทั้ง Index)
3.  **Operation Options**:
    *   **ONLINE = ON**: ควรใช้เสมอสำหรับ Production เพื่อไม่ให้ User ถูก Block ระหว่างสร้าง Index (Enterprise Ed.)
    *   **DATA_COMPRESSION**: พิจารณาเปิด `PAGE` Compression สำหรับ Index ขนาดใหญ่เพื่อลด I/O และ Memory usage

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 6_ README](../../README.md) | ➡ ถัดไป: [Columnstore Indexes](../03_Columnstore_Indexes/README.md) | [🧪 Labs](../../Labs/README.md)
