-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025
-- หมายเหตุ: บน SQL Server 2019/2022 ให้แก้ USE เป็น AdventureWorks2022 ก่อนรัน

-- ============================================================
-- Script: 05_Show_Statistics_Detail.sql
-- Module: Module 06 - Statistics & Index Internals
-- Purpose: Demonstrate DBCC SHOW_STATISTICS output interpretation
-- Source: Microsoft Learn / Course 10987C
-- ============================================================

USE AdventureWorks2025;
GO

-- ============================================================
-- STEP 1: View Statistics Information
-- ============================================================

-- Show all 3 result sets: Header, Density Vector, Histogram
DBCC SHOW_STATISTICS ('Sales.SalesOrderDetail', 'IX_SalesOrderDetail_ProductID');
GO

-- ============================================================
-- STEP 2: Interpret Each Result Set
-- ============================================================

/*
=== RESULT SET 1: HEADER ===
- Name: ชื่อ Statistics Object
- Updated: วันเวลาที่อัปเดตล่าสุด (สำคัญมาก! ถ้านานเกินไปอาจ Stale)
- Rows: จำนวนแถวตอน Statistics ถูกสร้าง
- Rows Sampled: จำนวนแถวที่ Sample (ถ้าไม่ครบ 100% อาจไม่แม่นยำ)
- Steps: จำนวน Histogram Steps (สูงสุด 200)
- Density: ความหนาแน่นโดยรวม (1/Distinct Values)
- Average Key Length: ขนาดเฉลี่ยของ Key

=== RESULT SET 2: DENSITY VECTOR ===
- All Density: ความหนาแน่นของ Column Combination
- สูตร: 1 / (จำนวน Distinct Values)
- ใช้สำหรับ Estimate แถวเมื่อ Query มี GROUP BY หรือ DISTINCT

=== RESULT SET 3: HISTOGRAM ===
- RANGE_HI_KEY: ค่าสูงสุดของช่วง (Bucket)
- RANGE_ROWS: จำนวนแถวระหว่าง HI_KEY ก่อนหน้ากับปัจจุบัน (ไม่รวม HI_KEY)
- EQ_ROWS: จำนวนแถวที่มีค่า = RANGE_HI_KEY พอดี
- DISTINCT_RANGE_ROWS: จำนวน Distinct Values ในช่วง
- AVG_RANGE_ROWS: ค่าเฉลี่ยแถวต่อ Distinct Value ในช่วง
*/

-- ============================================================
-- STEP 3: View Only Specific Result Sets
-- ============================================================

-- View only Header
DBCC SHOW_STATISTICS ('Sales.SalesOrderDetail', 'IX_SalesOrderDetail_ProductID') 
WITH STAT_HEADER;
GO

-- View only Density Vector
DBCC SHOW_STATISTICS ('Sales.SalesOrderDetail', 'IX_SalesOrderDetail_ProductID') 
WITH DENSITY_VECTOR;
GO

-- View only Histogram
DBCC SHOW_STATISTICS ('Sales.SalesOrderDetail', 'IX_SalesOrderDetail_ProductID') 
WITH HISTOGRAM;
GO

-- ============================================================
-- STEP 4: Check Statistics Freshness (via DMV)
-- ============================================================

SELECT
	OBJECT_NAME(s.object_id) AS TableName
,	s.name AS StatisticsName
,	s.auto_created
,	s.user_created
,	sp.last_updated
,	sp.rows
,	sp.rows_sampled
,	sp.modification_counter -- จำนวนแถวที่เปลี่ยนแปลงหลังอัปเดตล่าสุด
,	CAST(100.0 * sp.modification_counter / NULLIF(sp.rows, 0) AS DECIMAL(5,2)) AS [Change %]
FROM sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE OBJECT_NAME(s.object_id) = 'SalesOrderDetail'
ORDER BY sp.modification_counter DESC;

/*
=== วิธีตีความ ===
- modification_counter สูง + last_updated นานแล้ว = Statistics อาจ Stale
- SQL Server มี Auto Update Statistics แต่ต้องรอจนถึง Threshold (~20% ของแถว)
- SQL Server 2016+ มี Threshold ใหม่ที่ SQRT(1000 * rows) สำหรับตารางใหญ่

=== วิธีแก้ไข ===
-- Manual Update Statistics
UPDATE STATISTICS Sales.SalesOrderDetail IX_SalesOrderDetail_ProductID WITH FULLSCAN;
*/
