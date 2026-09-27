[⬅ Module 3_](../../README.md) | Section 4/4

## TempDB Internals (Lesson 3)

### 4.1 TempDB Usage and Importance
TempDB เป็น Global Resource ที่ใช้งานร่วมกันทั้ง Instance สำหรับ:
1.  **User Objects**: Temporary tables (`#Local`, `##Global`), Table variables
2.  **Internal Objects**: Workfiles สำหรับ Sort/Hash operations
3.  **Version Store**: เก็บ Row Versions สำหรับ Snapshot Isolation และ Online Index Build

### 4.2 TempDB Contention & Optimization

เมื่อหลาย Session พยายามสร้าง Temp Table พร้อมกัน SQL Server ต้องอัปเดต "แผนที่" ของ Database (Allocation Pages) ซึ่งอยู่บน Page เดียวกัน ทำให้เกิดการ "แย่งกันเขียน" หน้าเดียวกัน

**PAGELATCH Contention คืออะไร?**
- **Latch** = กลไก Lock ภายในที่ปกป้อง Data Page ขณะอ่าน/เขียน Memory
- เมื่อ Thread หลายตัวต้องการเขียน Page เดียวกัน → ต้องรอ Latch → เกิด Wait Type `PAGELATCH_EX` หรือ `PAGELATCH_UP`
- ใน TempDB ปัญหานี้มักเกิดที่ **PFS/GAM/SGAM Pages** (Allocation Bitmaps)

**วิธีแก้ไข:**
*   **Multiple Data Files**: สร้าง Data File ให้เท่ากับจำนวน CPU Core (สูงสุด 8 ไฟล์ในเบื้องต้น) → กระจาย Allocation Pages ออก
*   **Equal Size**: กำหนดขนาดและ Auto-growth ให้เท่ากันทุกไฟล์ เพื่อให้ *Proportional Fill Algorithm* ทำงานได้อย่างสมดุล
*   **Memory-Optimized TempDB Metadata (SQL 2019+)**: ย้าย System Catalog บางส่วนลง Memory เพื่อไม่ต้อง Latch บน Disk Pages

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 3_ README](../../README.md) | [🧪 Labs](../../Labs/README.md)
