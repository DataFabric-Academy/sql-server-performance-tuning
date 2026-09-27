[⬅ Module 4_](../../README.md) | Section 4/4

## In-Memory OLTP (Hekaton) (Lesson 3)

เทคโนโลยีการจัดเก็บและประมวลผลข้อมูลในหน่วยความจำหลัก (Main Memory) เพื่อประสิทธิภาพสูงสุด

### 5.1 Architecture Highlights
*   **Lock-free / Latch-free Data Structures**: ใช้เทคโนโลยี *Optimistic Concurrency Control (MVCC)* ขจัดปัญหา Blocking/Locking
*   **Native Compilation**: แปลง Stored Procedure เป็น **DLL (Machine Code)** เพื่อลด CPU Instructions ในการประมวลผล

### 5.2 Natively Compiled Stored Procedures
คือ Stored Procedure ที่ถูก Compile เป็น Machine Code (C) ทันทีที่สร้าง (Create Time) แทนที่จะ Interpreted ตอนรัน

**ข้อกำหนด (Requirements):**
1.  **SCHEMABINDING**: ต้องผูกติดกับ Table (ห้ามแก้ Table ถ้าไม่ Drop Proc)
2.  **EXECUTE AS OWNER**: ต้องระบุ Context ผู้รัน
3.  **ATOMIC WITH**: ทั้งบล็อกถือเป็น Transaction เดียว (Atomic)

```sql
CREATE PROCEDURE dbo.usp_InsertData 
    @ID INT, 
    @Name NVARCHAR(50)
WITH NATIVE_COMPILATION, SCHEMABINDING
AS BEGIN ATOMIC WITH
(
    TRANSACTION ISOLATION LEVEL = SNAPSHOT, 
    LANGUAGE = N'us_english'
)
    INSERT INTO dbo.MyMemoryTable (ID, Name) 
    VALUES (@ID, @Name);
END;
```

> [!NOTE]
> ประสิทธิภาพสูงกว่า T-SQL ปกติ **10x - 100x** สำหรับ Logic ที่ซับซ้อนและการคำนวณ (Math/String)

### 5.3 Table Types
1.  **Durable (SCHEMA_AND_DATA)**: ข้อมูลคงอยู่ถาวร (มี Checkpoint File Pairs บน Disk)
2.  **Non-Durable (SCHEMA_ONLY)**: ข้อมูลอยู่ใน Memory เท่านั้น (สูญหายเมื่อ Restart) เหมาะสำหรับ ETL Staging หรือ Session State

### 5.4 Index Types for Memory-Optimized
*   **Hash Index**: เหมาะสำหรับการค้นหาแบบเท่ากับ (Equality Search)
*   **Memory-Optimized Non-Clustered Index (Bw-Tree)**: เหมาะสำหรับการค้นหาแบบช่วง (Range Scan)

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 4_ README](../../README.md) | [🧪 Labs](../../Labs/README.md)
