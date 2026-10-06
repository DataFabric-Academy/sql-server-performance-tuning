-- ============================================================================
-- 09_Parallelism_CTFP_MAXDOP.sql
-- Section 1.4 Wait Statistics — หัวข้อ 4: Parallel Execution (CTFP & MAXDOP)
-- ตัวอย่างบน AdventureWorks2025 (ทดสอบจริงบน SQL Server 2025 RTM 17.0.1000.7,
-- 8 vCPU / 1 NUMA node, instance: MAXDOP = 2, CTFP = 5)
--
-- ⚠️ ข้อควรระวัง:
--  * ขั้นที่เปลี่ยน sp_configure กระทบ "ทั้ง instance" — ทำบน VM/lab ของตัวเอง
--    สคริปต์นี้บันทึกค่าเดิมและคืนค่าให้เสมอ (save & restore)
--  * ห้ามใช้ DBCC FREEPROCCACHE (instance เดียวใช้ร่วมกัน) — แทนด้วยการ
--    "รันซ้ำ" เพื่อให้ plan เต็มถูกแคช (optimize for ad hoc workloads = 1)
-- ============================================================================

USE AdventureWorks2025;
GO

-- ============================================================================
-- Step 1: ดูค่าตั้งต้นของ Instance — ประตู (CTFP) และเพดาน (MAXDOP)
-- ============================================================================
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

SELECT name, value_in_use, description
FROM sys.configurations
WHERE name IN ('cost threshold for parallelism', 'max degree of parallelism');

-- ✅ สังเกต (lab server ของคอร์ส): CTFP = 5 (default), MAXDOP = 2
--    (ตั้งตาม baseline ของคอร์ส: 8 cores ใช้ร่วม 20 คน จึงจำกัด DOP = 2)
GO

-- ============================================================================
-- Step 2: Query "จริง" บน AdventureWorks2025 — ต้นทุนไม่ถึงเกณฑ์ จึงวิ่ง Serial
-- ============================================================================
-- เปิด "Include Actual Execution Plan" (Ctrl+M) แล้วรัน 2 ครั้ง
-- (ครั้งแรก optimize for ad hoc workloads เก็บแค่ plan stub)
SELECT soh.TerritoryID,
       COUNT_BIG(*)   AS OrderLines,
       SUM(sod.LineTotal) AS LineTotal
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.SalesOrderDetail AS sod
     ON sod.SalesOrderID = soh.SalesOrderID
GROUP BY soh.TerritoryID;

-- ✅ สังเกต (รันจริง): Estimated Subtree Cost = 0.94 < CTFP 5
--    -> Optimizer ไม่พิจารณา parallel เลย แผนเป็น Serial
--    (ไม่มี Parallelism operator, Degree of Parallelism = 1)
--    บทเรียน: AdventureWorks มาตรฐาน "เล็กมาก" — ส่วนใหญ่ไม่ข้ามเกณฑ์
GO

-- ============================================================================
-- Step 3: ทำตารางขยายใน tempdb (×8 ≈ 970k แถว) เพื่อดัน cost ข้ามเกณฑ์
--         (วิธีเดียวกับบทความตัวอย่างที่ใช้ AdventureWorks Enlarged —
--          แต่ใช้ #temp ใน session ตัวเอง ไม่แตะตารางจริง ปิด window แล้วหาย)
-- ============================================================================
IF OBJECT_ID('tempdb..#OrderDetailEnlarged') IS NOT NULL
    DROP TABLE #OrderDetailEnlarged;

SELECT sod.SalesOrderID, sod.SalesOrderDetailID, sod.ProductID,
       sod.OrderQty, sod.UnitPrice, sod.UnitPriceDiscount,
       sod.LineTotal, sod.CarrierTrackingNumber
INTO #OrderDetailEnlarged
FROM Sales.SalesOrderDetail AS sod
CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),(7),(8)) AS e(x);

CREATE CLUSTERED INDEX IX_ENL ON #OrderDetailEnlarged (SalesOrderID);
GO

-- ============================================================================
-- Step 4: CTFP 5 (default) -> Parallel Plan เองโดยไม่ต้องใส่ hint
-- ============================================================================
-- เปิด Include Actual Execution Plan (Ctrl+M) แล้วรัน
SELECT sod.ProductID,
       SUM(sod.LineTotal)          AS TotalsOfLine,
       SUM(sod.UnitPrice)          AS TotalsOfPrice,
       SUM(sod.UnitPriceDiscount)  AS TotalsOfDiscount
FROM #OrderDetailEnlarged AS sod
GROUP BY sod.ProductID;

-- ✅ สังเกต (รันจริง): Estimated Subtree Cost = 7.74 > CTFP 5
--    -> ได้ Parallel Plan: Parallelism (Gather Streams)
--    -> Degree of Parallelism = 2 (โดน MAXDOP instance = 2 จำกัด ทั้งที่มี 8 cores)
--    -> เวลาจริง: CPU 109 ms / elapsed 63 ms (elapsed < CPU = ขนานจริง)
GO

-- ============================================================================
-- Step 5: พลิก CTFP เป็น 100 -> Query เดิมกลายเป็น Serial (บันทึก/คืนค่าให้เอง)
-- ============================================================================
DECLARE @ctfp_orig INT = (SELECT CAST(value_in_use AS INT)
                          FROM sys.configurations
                          WHERE name = 'cost threshold for parallelism');

EXEC sp_configure 'cost threshold for parallelism', 100;
RECONFIGURE;

SELECT sod.ProductID,
       SUM(sod.LineTotal)          AS TotalsOfLine,
       SUM(sod.UnitPrice)          AS TotalsOfPrice,
       SUM(sod.UnitPriceDiscount)  AS TotalsOfDiscount
FROM #OrderDetailEnlarged AS sod
GROUP BY sod.ProductID;

EXEC sp_configure 'cost threshold for parallelism', @ctfp_orig;  -- คืนค่าเดิม (5)
RECONFIGURE;

-- ✅ สังเกต (รันจริง): Serial plan cost = 10.29 < CTFP 100
--    -> parallel ไม่ถูกพิจารณาเลย -> แผน Serial, elapsed 113 ms
--    Query เดียวกัน เครื่องเดียวกัน: parallel 63 ms vs serial 113 ms
--    นี่คือเหตุผลที่ "ยก CTFP สูงเกิน" ทำให้ query กลาง ๆ เสียโอกาสขนาน
GO

-- ============================================================================
-- Step 6: MAXDOP — เพดานจำนวน thread ต่อ query (ใส่ระดับ query ไม่ต้องแตะ instance)
-- ============================================================================
-- 6a) บังคับ Serial ด้วย MAXDOP 1 -> เห็น NonParallelPlanReason = MaxDOPSetToOne
SELECT sod.ProductID,
       SUM(sod.LineTotal) AS TotalsOfLine
FROM #OrderDetailEnlarged AS sod
GROUP BY sod.ProductID
OPTION (USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'), MAXDOP 1);

-- ✅ สังเกต (รันจริง): Degree of Parallelism = 0 (serial)
--    NonParallelPlanReason = MaxDOPSetToOne

-- 6b) MAXDOP 4 ใน hint "ชนะ" MAXDOP ของ instance (= 2) -> ได้ DOP 4 จริง
SELECT sod.ProductID,
       SUM(sod.LineTotal) AS TotalsOfLine
FROM #OrderDetailEnlarged AS sod
GROUP BY sod.ProductID
OPTION (USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'), MAXDOP 4);

-- ✅ สังเกต (รันจริง): Degree of Parallelism = 4
--    ลำดับความสำคัญ: hint ระดับ query > database scoped configuration > instance
--
-- ระดับอื่น ๆ ของ MAXDOP:
--   ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 4;  -- ระดับ database
--   (ตั้งระดับ instance: sp_configure 'max degree of parallelism')
GO

-- ============================================================================
-- Step 7: เห็น CXPACKET / CXCONSUMER ด้วยตา — วัด delta รอบการรัน parallel
-- ============================================================================
SELECT wait_type, waiting_tasks_count, wait_time_ms
INTO #w0
FROM sys.dm_os_wait_stats
WHERE wait_type IN ('CXPACKET', 'CXCONSUMER', 'SOS_SCHEDULER_YIELD');

DECLARE @i INT = 0, @c BIGINT;
WHILE @i < 50
BEGIN
    /* pxloop */ SELECT @c = COUNT_BIG(*)
    FROM Sales.SalesOrderHeader s1
    CROSS JOIN Sales.SalesOrderHeader s2
    GROUP BY s1.TerritoryID
    OPTION (USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'), MAXDOP 4);
    SET @i += 1;
END

SELECT w.wait_type,
       w.waiting_tasks_count - d.waiting_tasks_count AS tasks_delta,
       w.wait_time_ms       - d.wait_time_ms         AS ms_delta
FROM sys.dm_os_wait_stats AS w
JOIN #w0 AS d ON d.wait_type = w.wait_type
ORDER BY ms_delta DESC;

-- ✅ สังเกต (รันจริง 50 รอบ): CXCONSUMER +1,246 ครั้ง (662 ms), CXPACKET +971 ครั้ง (257 ms)
--    -> งาน parallel สั้น ๆ ผ่าน exchange สร้าง wait คู่นี้ตามธรรมชาติ
--    -> CXCONSUMER สูงอย่างเดียว "ไม่ใช่" ปัญหา — ต้องอ่านเป็นคู่กับ CXPACKET
--       และดูว่า query จบตาม SLA หรือไม่ (ดูหัวข้อ 4 ใน README)
GO

-- ============================================================================
-- Cleanup: ตาราง #temp หายเองเมื่อปิด query window
-- ตรวจว่าคืนค่าแล้ว (ต้องได้ค่าเดิมก่อนรันสคริปต์ — ค่า baseline ของคอร์สคือ 5)
-- ============================================================================
SELECT name, value_in_use
FROM sys.configurations
WHERE name IN ('cost threshold for parallelism', 'max degree of parallelism');
