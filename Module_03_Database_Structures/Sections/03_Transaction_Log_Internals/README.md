[⬅ Module 3_](../../README.md) | Section 3/4 | ➡ ถัดไป: [TempDB Internals](../04_TempDB_Internals/README.md)

## Transaction Log Internals

### 5.1 Virtual Log Files (VLF)
Transaction Log File ถูกแบ่งโครงสร้างภายในออกเป็นส่วนย่อยเรียกว่า **Virtual Log Files (VLF)**
*   **High VLF Count**: เกิดจากการตั้งค่า Auto-growth ขนาดเล็กเกินไป ทำให้มี VLF จำนวนมาก (Fragmented Log)
*   **Impact**: ส่งผลให้ Database Startup, Restore, และ Replication ทำงานช้าลง
*   **Best Practice**: ควรจองขนาด Log File ล่วงหน้า (Pre-allocate) และกำหนด Auto-growth ในขนาดที่เหมาะสม (เช่น 4GB หรือ 8GB) เพื่อให้ได้ VLF ขนาดใหญ่และจำนวนน้อย

### 5.2 Ghost Cleanup Process

**Ghost Records** คือData Row ที่ถูก DELETE แล้วแต่ยังไม่ถูกลบออกจาก Page จริงๆ:

*   **ทำไมต้องมี Ghost?**: เพื่อเพิ่มประสิทธิภาพการ DELETE และรองรับ Row-level Locking / Snapshot Isolation
*   **Mechanism**: เมื่อ DELETE จะเปลี่ยน Bit ใน Row Header เป็น "Ghost" แทนการลบทันที
*   **Ghost Cleanup Task**: Background process ที่รันเป็นระยะเพื่อลบ Ghost Records ออกจาก Pages

```sql
-- ตรวจสอบจำนวน Ghost Records
SELECT 
    DB_NAME(database_id) AS [Database],
    SUM(ghost_record_count) AS [Ghost Records]
FROM sys.dm_db_index_physical_stats(NULL, NULL, NULL, NULL, 'SAMPLED')
GROUP BY database_id
ORDER BY [Ghost Records] DESC;
```

> [!WARNING]
> **Trace Flag 661** สามารถ Disable Ghost Cleanup ได้ แต่ **ไม่แนะนำ** เพราะจะทำให้:
> - Database files โตขึ้นเรื่อยๆ (Space ไม่ถูก Reclaim)
> - เกิด Page Splits มากขึ้น
> - Index Rebuild เป็นวิธีแก้ไขถ้าปิด Ghost Cleanup ไปแล้ว

---

### Exercise 3: Reconfiguring tempdb
1.  **Setup**: จำลอง Latch Contention (สร้าง Temp Table รัวๆ)
2.  **Monitor**: ใช้ `sys.dm_os_wait_stats` หา `PAGELATCH_*`
3.  **Fix**: เพิ่มไฟล์ TempDB ให้เท่ากับจำนวน CPU Core และสังเกตผลลัพธ์

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 3_ README](../../README.md) | ➡ ถัดไป: [TempDB Internals](../04_TempDB_Internals/README.md) | [🧪 Labs](../../Labs/README.md)
