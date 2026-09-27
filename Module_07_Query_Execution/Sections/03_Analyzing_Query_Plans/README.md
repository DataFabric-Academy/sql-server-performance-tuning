[⬅ Module 7_](../../README.md) | Section 3/4 | ➡ ถัดไป: [Intelligent Query Processing](../04_Intelligent_Query_Processing/README.md)

## Analyzing Query Plans (Lesson 3)

### 4.1 Common Operators (Data Access)
*   **Index Seek**: การค้นหาข้อมูลโดยใช้ B-Tree Traversal จะมีประสิทธิภาพสูงสุดเมื่อ Predicate มี Selectivity สูง
*   **Index Scan**: การอ่าน Leaf Page ทั้งหมดของ Index (เหมาะสำหรับ Table ขนาดเล็ก หรือ Low Selectivity)
*   **Table Scan**: การอ่านข้อมูลทั้งหมดใน Heap Table (ควรหลีกเลี่ยงใน Table ขนาดใหญ่)
*   **Key Lookup**: การกลับไปอ่านข้อมูลใน Table หลัก (Clustered Index/Heap) เมื่อ Non-Clustered Index ไม่มี Column ที่ต้องการครบถ้วน (Expensive Operation)

### 4.2 Join Operators
*   **Nested Loops**: มีประสิทธิภาพสูงสำหรับ Input ขนาดเล็ก (Outer Loop จำนวนน้อย)
*   **Merge Join**: มีประสิทธิภาพสูงสุดเมื่อ Input ทั้งสองฝั่งมีการเรียงลำดับ (Sorted) แล้ว
*   **Hash Join**: เหมาะสำหรับ Input ขนาดใหญ่ที่ไม่มีการเรียงลำดับ (ต้องใช้ Memory ในการสร้าง Hash Table)

### 4.3 Warnings
*   **Missing Statistics**: Optimizer ขาด Statistics ในการประเมิน Cost
*   **Missing Index**: คำแนะนำให้สร้าง Index เพิ่มเติมเพื่อลด I/O Cost
*   **Implicit Conversion**: การแปลง Data Type อัตโนมัติซึ่งอาจปิดกั้นการใช้ Index (Prevent Index Seek)
*   **Spill Warning**: Memory Grant ไม่เพียงพอ ทำให้ต้องเขียนข้อมูลชั่วคราวลง TempDB (ส่งผลกระทบต่อประสิทธิภาพสูง)

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 7_ README](../../README.md) | ➡ ถัดไป: [Intelligent Query Processing](../04_Intelligent_Query_Processing/README.md) | [🧪 Labs](../../Labs/README.md)
