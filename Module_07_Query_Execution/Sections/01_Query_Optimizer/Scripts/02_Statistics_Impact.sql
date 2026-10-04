-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

﻿/*
    LAB: Module 07 - Statistics Impact on Query Plans
    
    DEMO CONTEXT:
        In Demo 02 (Live Query Stats), you saw query execution in real-time.
        In this Lab, you will manipulate the "Brains" of the optimizer (Statistics) 
        to force it to make bad decisions (Scanning small tables vs Seeking large ones),
        illustrating why maintenance is critical.

    OBJECTIVE:
        Demonstrate how stale statistics can lead to poor plan choices (Scan vs Seek) 
        using skewed data distribution.

    INSTRUCTIONS:
        1. Run TASK 1 to create a table with skewed data (10,000 'US' vs 10 'TH').
        2. Run TASK 2 to artificially corrupt statistics to mislead the optimizer.
        3. Run TASK 3 to run queries and observe the "Bad Plan" behavior (e.g. Scanning for 'TH').
           - Note: Enable "Include Actual Execution Plan" (Ctrl+M) to see details.
        4. Run TASK 4 to fix statistics using FULLSCAN and verify the "Good Plan" returns.

    PREREQUISITES:
        - AdventureWorks2025 or newer
*/

-- Lab: Statistics Impact on Query Plans (Modernized)
-- Adapted from: Lab 07 (Query Execution)
-- Target: AdventureWorks2025/2022

USE [AdventureWorks2025];
GO

-- =============================================
-- TASK 1: CREATE SKEWED DATA (Simulation)
-- =============================================
-- Create a table with skewed data to demonstrate Statistics importance
IF OBJECT_ID('dbo.SalesStatsDemo') IS NOT NULL DROP TABLE dbo.SalesStatsDemo;
CREATE TABLE dbo.SalesStatsDemo (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    CountryCode CHAR(2),
    Amount DECIMAL(10,2)
);

-- Insert 10,000 rows for 'US'
INSERT INTO dbo.SalesStatsDemo (CountryCode, Amount)
SELECT TOP 10000 'US', RAND() * 100
FROM master.dbo.spt_values a CROSS JOIN master.dbo.spt_values b;

-- Insert 10 rows for 'TH'
INSERT INTO dbo.SalesStatsDemo (CountryCode, Amount)
SELECT TOP 10 'TH', RAND() * 100
FROM master.dbo.spt_values;

CREATE INDEX IX_CountryCode ON dbo.SalesStatsDemo(CountryCode);
GO

-- =============================================
-- TASK 2: FORCE STALE STATISTICS
-- =============================================
-- Manually update statistics to lie to SQL Server
UPDATE STATISTICS dbo.SalesStatsDemo WITH ROWCOUNT = 1, PAGECOUNT = 1;
DBCC FREEPROCCACHE;
PRINT 'Statistics corrupted manually.';
GO

-- =============================================
-- TASK 3: OBSERVE BAD PLAN
-- =============================================
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- "TH" has only 10 rows. A Seek is expected.
-- But if stats say table is empty, it might Scan or choose poorly.
SELECT
	*
FROM dbo.SalesStatsDemo
WHERE CountryCode = 'TH';

-- "US" has 10,000 rows. A Scan is expected.
SELECT
	*
FROM dbo.SalesStatsDemo
WHERE CountryCode = 'US';

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

-- =============================================
-- TASK 4: FIX STATISTICS
-- =============================================
UPDATE STATISTICS dbo.SalesStatsDemo WITH FULLSCAN;
PRINT 'Statistics updated.';

-- Re-run queries to see improved plans
SELECT
	*
FROM dbo.SalesStatsDemo
WHERE CountryCode = 'TH';
SELECT
	*
FROM dbo.SalesStatsDemo
WHERE CountryCode = 'US';
GO

