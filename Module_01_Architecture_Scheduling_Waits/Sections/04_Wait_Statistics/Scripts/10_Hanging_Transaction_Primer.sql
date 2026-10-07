-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

/*
    LAB: Module 01 - Hanging Transaction Primer (เห็น Wait แรกผ่านการแขวนของ Transaction)

    DEMO CONTEXT:
        ก่อนอ่านสถิติรวมจาก sys.dm_os_wait_stats ผู้เรียนควร "เห็น" wait ที่ง่ายที่สุดก่อน
        — Session A ถือ transaction ค้าง (ยังไม่ COMMIT/ROLLBACK) แล้ว Session B มาแตะแถวเดียวกัน
        จะแขวนทันทีด้วย wait type LCK_M_X พร้อม blocking_session_id ชี้ไปที่ Session A
        (Adapted from 10987C Demofiles Mod01 Demo2: Create hanging transaction /
        Start blocked transaction / DMV queries)

    OBJECTIVE:
        สัมผัส "การรอ" จาก 2 มุม: มุมผู้ใช้ (query แขวนไปเอง) และมุม engine
        (sys.dm_exec_requests + sys.dm_os_wait_stats) เพื่อปูพื้นก่อนอ่าน Top waits

    INSTRUCTIONS:
        ใช้ SSMS 2 หน้าต่าง (Window A = ผู้ถือ lock, Window B = ผู้โดน block)
        1. TASK 1 (Window A): เปิด transaction แล้ว UPDATE ค้างไว้ — ยังไม่รัน ROLLBACK
        2. TASK 2 (Window B): รัน UPDATE แถวเดียวกัน — จะแขวน (ทิ้งไว้ ~30 วินาที พอ)
        3. TASK 3 (หน้าต่างใหม่ Window C): ดูสถานะการรอแบบ real-time
        4. TASK 4 (Window A): ROLLBACK ปลดแขวน — Window B จะรันจบทันที
        5. TASK 5: ตรวจว่า LCK_M_X ขึ้นในสถิติรวมจริง

    NOTES:
        - ใช้ UPDATE -> UPDATE โดยเจตนา: บน DB ที่เปิด RCSI (เช่น VM ห้องเรียน) SELECT ธรรมดา
          จะไม่โดน block แต่ UPDATE ทับแถวเดิมยังต้องได้ X lock เสมอ จึงเดโมได้ทุกเครื่อง
        - ห้ามทิ้ง transaction ค้าง: ถ้าปิด SSMS ทั้งที่ยังถือ lock session ฝั่ง server จะค้าง
          ถือ lock ต่อไป (sleeping + open transaction) และ block คนอื่นต่อ — ดู Cleanup
        - ตัวเต็มเรื่อง lock chain/deadlock อยู่ Module 05 (Lab 5 Exercise 1)
*/

USE [AdventureWorks2025];
GO

-- =============================================
-- TASK 1 (Window A): เปิด transaction ค้าง — ผู้ถือ lock
-- =============================================
-- รัน 2 คำสั่งนี้แล้ว "ปล่อยค้างไว้" (ยังไม่รัน TASK 4)
BEGIN TRANSACTION;

UPDATE Person.Person
SET ModifiedDate = ModifiedDate        -- ค่าเดิม (no-op) แต่ได้ X lock ครบตามต้องการ
WHERE BusinessEntityID = 235;

-- ROLLBACK;   -- ยังห้ามรัน — ให้รันตอน TASK 4 เท่านั้น
GO

-- =============================================
-- TASK 2 (Window B): มาแตะแถวเดียวกัน — จะแขวน
-- =============================================
-- รันใน Window B — query จะไม่จบ (แขวน) ทิ้งไว้ ~30 วินาที แล้วไปรัน TASK 3
UPDATE Person.Person
SET ModifiedDate = ModifiedDate
WHERE BusinessEntityID = 235;

-- =============================================
-- TASK 3 (Window C): มองการแขวนจากมุม engine (real-time)
-- =============================================
SELECT r.session_id,
       r.status,                       -- suspended = กำลังรอ
       r.wait_type,                    -- LCK_M_X = ขอ X lock ไม่ได้
       r.wait_time,                    -- มิลลิวินาทีที่รอมาแล้ว (เดินขึ้นเรื่อย ๆ)
       r.blocking_session_id,          -- ชี้ Session A = head blocker
       r.wait_resource
FROM sys.dm_exec_requests AS r
WHERE r.blocking_session_id <> 0;

-- เสริม: หา "ผู้ถือ transaction ค้าง" จากอีกมุม (sleeping + open transaction)
SELECT s.session_id, s.status, s.program_name,
       s.open_transaction_count
FROM sys.dm_exec_sessions AS s
WHERE s.open_transaction_count > 0
  AND s.is_user_process = 1;

-- =============================================
-- TASK 4 (Window A): ปลดแขวน
-- =============================================
-- รันใน Window A — Window B จะรันจบทันที
ROLLBACK;

-- =============================================
-- TASK 5: ตรวจว่าการแขวนขึ้นในสถิติรวมจริง
-- =============================================
-- ทำเพิ่มเติม: ถ้าอยากได้ค่าสะอาด ให้ DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);
-- ก่อนวนกลับไปทำ TASK 1-4 อีกรอบสั้น ๆ (~10 วินาที) แล้วค่อยรัน query นี้
SELECT wait_type, waiting_tasks_count,
       wait_time_ms / 1000.0 AS total_wait_s,
       wait_time_ms / NULLIF(waiting_tasks_count, 0) / 1000.0 AS avg_wait_s
FROM sys.dm_os_wait_stats
WHERE wait_type = 'LCK_M_X';
-- Expected: waiting_tasks_count >= 1 และ avg_wait_s ~= ระยะเวลาที่ Window B แขวน
