[⬅ Module 8_](../../README.md) | Section 2/3 | ➡ ถัดไป: [Query Store Automatic Tuning](../03_Query_Store_Automatic_Tuning/README.md)

## Troubleshooting with Plan Cache (Lesson 2)

### 3.1 Recompilation
กระบวนการสร้าง Plan ใหม่แทนที่ Plan เดิมที่อยู่ใน Cache
*   **Impact**: หากเกิดขึ้นบ่อยเกินไป (Frequent Recompilation) จะส่งผลกระทบต่อ CPU Usage
*   **Causes**: Schema changes, Statistics update, `SET` option changes, หรือการใช้ `OPTION(RECOMPILE)`
*   **Monitoring**: ตรวจสอบ counter `SQL Recompilations/sec` ใน Performance Monitor

### 3.2 Parameter Sniffing
ปรากฏการณ์ที่ Execution Plan ถูกสร้างขึ้นตามค่า Parameter ค่าแรกที่ส่งเข้ามา (Sniffed Value)
*   *Scenario*: Plan ที่เหมาะสมกับ Parameter A (Data น้อย -> Seek) ถูกนำไปใช้กับ Parameter B (Data มาก -> ควรจะเป็น Scan) ทำให้ประสิทธิภาพลดลง
*   *Solution*: การใช้ `OPTION(RECOMPILE)`, `OPTIMIZE FOR UNKNOWN`, หรือการทำ Plan Forcing ผ่าน Query Store

### 3.3 Plan Cache Bloat (Ad-hoc Plan Pollution)
อาการ: Memory ของ `CACHESTORE_SQLCP` มีขนาดใหญ่ผิดปกติ เต็มไปด้วย Single-use Plans
*   *Solution*: ปรับปรุง Application Code ให้ใช้ Parameterized Query หรือเปิดใช้งาน Server Option 'Optimize for Ad-hoc Workloads'

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 8_ README](../../README.md) | ➡ ถัดไป: [Query Store Automatic Tuning](../03_Query_Store_Automatic_Tuning/README.md) | [🧪 Labs](../../Labs/README.md)
