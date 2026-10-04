-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025
-- หมายเหตุ: บน SQL Server 2019/2022 ให้แก้ USE เป็น AdventureWorks2022 ก่อนรัน

/*
    LAB: Module 04 - Memory Grant Spills (Sort Warnings)
    
    DEMO CONTEXT:
        In Demos 01-03, you monitored memory usage (Buffers, Clerks).
        In this Lab, you will generate a "Memory Spill" (Sort Warning) by forcing 
        a large sort that exceeds the allocated Memory Grant.

    OBJECTIVE:
        Simulate a spill to TempDB and observe the performance impact (and the Warning in Execution Plan).
*/

-- Lab: Memory Spill Simulation
 USE AdventureWorks2025;
 GO
 -- Ensure we are using a compat level that supports Feedback (140 = 2017, 150 = 2019, 160 = 2022)
 ALTER DATABASE AdventureWorks2025 SET COMPATIBILITY_LEVEL = 150; 
 GO
 
 -- Clean buffer/procedure cache to reset feedback
 DBCC FREEPROCCACHE;
 GO
 
-- Step 1: Run the query (First Execution -> Spill)
-- We cast a column to huge width to trick the optimizer or force data movement
PRINT '--- 1st Execution (Likely Spill) ---';
SELECT
	SalesOrderID
,	OrderDate
,	CAST(Comment AS CHAR(5000)) AS PaddingData
FROM Sales.SalesOrderHeader
ORDER BY PaddingData DESC
OPTION (MAXDOP 1);
 -- Note: Ensure "Include Actual Execution Plan" is ON.
 -- Look for yellow bang on "Sort" operator.
 GO
 
-- Step 2: Run again (Feedback kicks in)
PRINT '--- 2nd Execution (Feedback Adjusted) ---';
SELECT
	SalesOrderID
,	OrderDate
,	CAST(Comment AS CHAR(5000)) AS PaddingData
FROM Sales.SalesOrderHeader
ORDER BY PaddingData DESC
OPTION (MAXDOP 1);
 -- Warning should be gone if Memory Grant Feedback works.
 GO
