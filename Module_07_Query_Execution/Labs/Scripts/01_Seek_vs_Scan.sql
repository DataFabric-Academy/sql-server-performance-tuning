/*
    LAB: Module 07 - Execution Plan Analysis (Seek vs Scan)
    
    DEMO CONTEXT:
        In Demo 03 (Optimizer Internals), you saw stages of optimization.
        In this Lab, you will compare the two most fundamental operators: SEEK (Precision) vs SCAN (Brute Force).
        You will see how a simple "Implicit Conversion" (Demo 01 concept) can turn a Seek into a Scan.

    OBJECTIVE:
        Identify and fix poor plan choices caused by Data Type Mismatches (Implicit Conversion).

    INSTRUCTIONS:
        1. Run Part 1 to create tables with mismatched types (NVARCHAR vs VARCHAR).
        2. Run Part 2 to query them and observe the "Scan" in the Execution Plan.
        3. Run Part 3 to fix the types and see the "Seek".
*/

-- Lab: Index Seek vs Index Scan Analysis

USE [AdventureWorks2025];
GO

-- 1. Setup Data
IF OBJECT_ID('dbo.SeekScanLab') IS NOT NULL DROP TABLE dbo.SeekScanLab;
CREATE TABLE dbo.SeekScanLab (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Category INT,
    Data CHAR(100) DEFAULT 'A'
);

-- Insert 10,000 rows
-- Category = 1 has only 1% (100 rows) -> High Selectivity (Expect Seek)
-- Category = 2 has 99% (9900 rows) -> Low Selectivity (Expect Scan)
INSERT INTO dbo.SeekScanLab (Category)
SELECT CASE WHEN ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) <= 100 THEN 1 ELSE 2 END
FROM master.dbo.spt_values t1 CROSS JOIN master.dbo.spt_values t2
TOP (10000);

CREATE INDEX IX_Category ON dbo.SeekScanLab(Category);

-- 2. Execute & Compare
SET STATISTICS IO ON;
SET SHOWPLAN_XML ON; -- Ctrl+M in SSMS
GO

PRINT '--- Query 1: High Selectivity (Expect SEEK) ---';
SELECT
	*
FROM dbo.SeekScanLab
WHERE Category = 1;

PRINT '--- Query 2: Low Selectivity (Expect SCAN) ---';
SELECT
	*
FROM dbo.SeekScanLab
WHERE Category = 2;

GO
SET STATISTICS IO OFF;
SET SHOWPLAN_XML OFF;

-- *Task*: Observe Logical Reads and Execution Plan Operator
-- Query 1: Low Reads, Index Seek
-- Query 2: High Reads, Clustered Index Scan (Cost of Key Lookup > Cost of Scan)
