[⬅ Module 5_](../../README.md) | Section 1/3 | ➡ ถัดไป: [Locking Internals](../02_Locking_Internals/README.md)

## Concurrency and Transactions (Lesson 1)

### 2.1 Concurrency Models
1.  **Pessimistic Concurrency**: รูปแบบที่เน้นความถูกต้องสูงสุด โดยสันนิษฐานว่าจะเกิดข้อขัดแย้ง (Conflict) ขึ้นเสมอ จึงทำการ Lock ข้อมูลทันทีที่มีการอ่านหรือแก้ไข
    *   *Result*: รับประกัน Data Consistency สูงสุด แต่มีโอกาสเกิด Blocking สูง (เป็น Default Behavior ของ SQL Server)
2.  **Optimistic Concurrency**: รูปแบบที่เน้นประสิทธิภาพ โดยสันนิษฐานว่าจะไม่เกิดข้อขัดแย้ง จึงไม่มีการ Lock ระหว่างอ่าน แต่จะตรวจสอบความถูกต้อง (Validation) เมื่อทำการ Commit โดยใช้ Row Versioning
    *   *Result*: ลด Blocking ได้อย่างมีนัยสำคัญ แต่ต้องมีกลไกจัดการ Conflict หากข้อมูลถูกแก้ไขโดยผู้อื่นในระหว่างนั้น

### 2.2 Transaction Internals
Transaction คือหน่วยของงานทางตรรกะ (Logical Unit of Work) ซึ่งต้องมีคุณสมบัติ **ACID**:
*   **Atomicity**: ความเป็นหนึ่งเดียว (ทำสำเร็จทั้งหมด หรือยกเลิกทั้งหมด)
*   **Consistency**: ความถูกต้องสมบูรณ์ (ต้องไม่ละเมิด Integrity Constraints)
*   **Isolation**: ความเป็นอิสระ (Transaction หนึ่งต้องไม่ส่งผลกระทบต่ออีก Transaction หนึ่งที่ทำงานขนานกัน)
*   **Durability**: ความคงทน (เมื่อ Commit แล้ว ข้อมูลต้องอยู่ถาวรแม้ระบบจะล่ม)

*Transaction Modes*:
1.  **Auto-commit** (Default): แต่ละคำสั่งถือเป็น 1 Transaction และ Commit ทันทีที่สำเร็จ
2.  **Explicit**: กำหนดขอบเขตชัดเจนด้วย `BEGIN TRAN`, `COMMIT`, `ROLLBACK`
3.  **Implicit**: เริ่ม Transaction อัตโนมัติเมื่อมีคำสั่ง DML แต่ต้องสั่ง Commit/Rollback เอง

### 2.3 Isolation Levels
ระดับความเข้มงวดในการแยก Transaction (เรียงจากน้อยไปมาก):
1.  **READ UNCOMMITTED**: อนุญาตให้อ่านข้อมูลที่ยังไม่ Commit (Dirty Read) -> เสี่ยงต่อความผิดพลาดสูง
2.  **READ COMMITTED** (Default): อ่านได้เฉพาะข้อมูลที่ Commit แล้วเท่านั้น (ป้องกัน Dirty Read)
3.  **REPEATABLE READ**: รับประกันว่าค่าที่อ่านแล้วจะยังคงเดิมจนจบ Transaction (ป้องกัน Non-Repeatable Read)
4.  **SERIALIZABLE**: ระดับสูงสุด ป้องกันการแทรกแถวใหม่ในช่วงที่อ่าน (ป้องกัน Phantom Read) -> มีโอกาส Blocking และ Deadlock สูงสุด
5.  **SNAPSHOT**: ใช้ Row Versioning เพื่อให้อ่านข้อมูลเวอร์ชันก่อนหน้าแทนการรอ Lock

### 2.4 Modern Concurrency (RCSI)
**Read Committed Snapshot Isolation (RCSI)** คือการปรับเปลี่ยนพฤติกรรมของ READ COMMITTED ให้ใช้ Row Versioning แทน Locking
*   *Mechanism*: Reader อ่านข้อมูลจาก Version Store (TempDB) แทนการรอ Lock จาก Writer
*   *Benefit*: ลด Blocking ระหว่าง Reader และ Writer อย่างมหาศาล

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 5_ README](../../README.md) | ➡ ถัดไป: [Locking Internals](../02_Locking_Internals/README.md) | [🧪 Labs](../../Labs/README.md)
