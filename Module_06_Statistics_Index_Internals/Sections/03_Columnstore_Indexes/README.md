[⬅ Module 6_](../../README.md) | Section 3/3

## Columnstore Indexes (Lesson 3)

เทคโนโลยีการจัดเก็บข้อมูลแบบColumn (Columnar Storage) ออกแบบมาเพื่อเพิ่มประสิทธิภาพสำหรับ Data Warehouse และ Analytical Workloads

### 4.1 Architecture
*   **Column-oriented**: การจัดเก็บข้อมูลแยกตามColumn ทำให้สามารถอ่านเฉพาะข้อมูลที่จำเป็นต้องใช้ (ลด I/O)
*   **High Compression**: อัตราการบีบอัดสูง (10x - 100x) เนื่องจากข้อมูลในColumnเดียวกันมักมีความคล้ายคลึงกัน
*   **Batch Mode Processing**: การประมวลผลข้อมูลเป็นชุด (Vector-based, ~900 rows/batch) แทนการประมวลผลทีละแถว ซึ่งเพิ่มประสิทธิภาพ CPU อย่างมาก
*   *Types*:
    *   **Clustered Columnstore Index (CCI)**: ใช้เป็นพื้นที่จัดเก็บหลักของตาราง (Primary Storage)
    *   **Non-Clustered Columnstore Index (NCCI)**: สร้างคู่ขนานไปกับ Rowstore Table เพื่อรองรับ Real-time Analytics (HTAP)

### 4.2 Columnstore Internals
*   **Rowgroup**: หน่วยการจัดเก็บข้อมูล (Logical Group) รองรับสูงสุดประมาณ 1 ล้านแถวต่อ Rowgroup
*   **Segment**: ข้อมูลของหนึ่งColumnภายใน Rowgroup (เป็นหน่วยในการอ่านจาก Disk)
*   **Dictionary Encoding**: เทคนิคการบีบอัดโดยการแทนที่ค่าซ้ำด้วย Reference ID
*   **Deltastore**: พื้นที่ชั่วคราว (Rowstore) สำหรับรองรับการ Insert/Update ข้อมูลจำนวนน้อย ก่อนที่จะถูกบีบอัดรวมเข้าสู่ Rowgroup
*   **Tuple Mover**: Background Process ที่ทำหน้าที่ย้ายข้อมูลจาก Deltastore เข้าสู่ Compressed Rowgroup
*   **Deleted Bitmap**: โครงสร้างสำหรับติดตามแถวที่ถูกลบ (Logical Delete) เนื่องจาก Compressed Segment ไม่สามารถแก้ไขได้โดยตรง

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 6_ README](../../README.md) | [🧪 Labs](../../Labs/README.md)
