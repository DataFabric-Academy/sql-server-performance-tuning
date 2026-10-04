-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

﻿/*
    LAB: Module 05 - Snapshot Isolation vs Locking
    
    DEMO CONTEXT:
        In Demo 03 (Analyze Blocking), you investigated a Blocking Chain.
        In this Lab, you will not only simulate blocking but implements a *solution*:
        Snapshot Isolation (RCSI), allowing readers to access the version store instead 
        of waiting for locks.

    OBJECTIVE:
        Demonstrate how Snapshot Isolation (RCSI/SI) allows readers to read data 
        without being blocked by writers, solving common blocking chains.

    INSTRUCTIONS:
        1. Run PART 1 to setup the 'Proseware.Campaign' table.
        2. Open a NEW QUERY WINDOW (Window 2) and follow instructions in PART 2 to start a Blocking Transaction.
        3. Go back to this window (Window 1) and run PART 3.1 to confirm the blocking is active.
        4. Run PART 3.2 to ENABLE Snapshot Isolation on the database.
        5. Run PART 3.3 to verify that you can now READ the data even while Window 2 is holding a lock.
        6. Commit/Rollback Window 2 when finished.

    PREREQUISITES:
        - AdventureWorks2025 or newer
*/

-- Lab: Legacy Migration - Snapshot Isolation & Locking
-- Adapted from: Lab 05 (Concurrency)
-- Target: AdventureWorks2025 (Using internal setup, no external scripts)

USE [AdventureWorks2025]; -- Or AdventureWorks2025
GO

-- =================================================================
-- PART 1: SETUP (Creating Proseware resources)
-- =================================================================
PRINT '--- Setting up Proseware Schema & Tables ---';
IF SCHEMA_ID('Proseware') IS NULL EXEC('CREATE SCHEMA Proseware');
GO

IF OBJECT_ID('Proseware.Campaign') IS NOT NULL DROP TABLE Proseware.Campaign;
CREATE TABLE Proseware.Campaign (
    CampaignID int IDENTITY PRIMARY KEY,
    CampaignName varchar(20) NOT NULL,
    CampaignTerritoryID int NOT NULL
);

-- Populate Data (10,000 rows)
INSERT Proseware.Campaign (CampaignName, CampaignTerritoryID)
SELECT TOP (10000)
    CAST(1000000 + ROW_NUMBER() OVER (ORDER BY a.name) AS varchar(20)),
    (ROW_NUMBER() OVER (ORDER BY a.name) % 10) + 1
FROM master.dbo.spt_values AS a
CROSS JOIN master.dbo.spt_values AS b;
GO

-- =================================================================
-- PART 2: THE WORKLOAD (Simulating Blocking)
-- =================================================================
-- à¸„à¸³à¹à¸™à¸°à¸™à¸³: à¹€à¸›à¸´à¸”à¸«à¸™à¹‰à¸²à¸•à¹ˆà¸²à¸‡ New Query à¸­à¸µà¸à¸«à¸™à¹‰à¸²à¸•à¹ˆà¸²à¸‡à¸«à¸™à¸¶à¹ˆà¸‡ (Window 2) à¹à¸¥à¹‰à¸§à¸£à¸±à¸™à¸„à¸³à¸ªà¸±à¹ˆà¸‡à¸™à¸µà¹‰:
/*
    USE [AdventureWorks2025];
    BEGIN TRAN
        -- à¸–à¸·à¸­ Lock à¸™à¸²à¸™ 10 à¸§à¸´à¸™à¸²à¸—à¸µ
        UPDATE Proseware.Campaign SET CampaignName = 'LockTest' WHERE CampaignTerritoryID = 1;
        WAITFOR DELAY '00:00:10';
    ROLLBACK
*/

-- =================================================================
-- PART 3: ANALYSIS (Snapshot Isolation)
-- =================================================================

-- 3.1 Check Current Locking (Run while Window 2 is running)
SELECT
	resource_type
,	request_mode
,	request_status
FROM sys.dm_tran_locks
WHERE resource_database_id = DB_ID();

-- 3.2 Enable Snapshot Isolation
-- (Warning: This might block if there are active connections)
ALTER DATABASE [AdventureWorks2025] SET ALLOW_SNAPSHOT_ISOLATION ON;
PRINT 'Snapshot Isolation Enabled.';

-- 3.3 Test Snapshot Isolation
-- (à¸£à¸±à¸™à¸žà¸£à¹‰à¸­à¸¡à¸à¸±à¸š Window 2 à¸—à¸µà¹ˆà¸à¸³à¸¥à¸±à¸‡à¸–à¸·à¸­ Lock)
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;

BEGIN TRAN
    PRINT 'Trying to read data under Snapshot Isolation...';
	SELECT COUNT(*) FROM Proseware.Campaign WHERE CampaignTerritoryID = 1;
    -- Result: à¸„à¸§à¸£à¸­à¹ˆà¸²à¸™à¹„à¸”à¹‰à¸—à¸±à¸™à¸—à¸µ (à¹„à¸¡à¹ˆà¸•à¸´à¸” Block) à¹à¸¥à¸°à¹„à¸”à¹‰à¸„à¹ˆà¸²à¹€à¸”à¸´à¸¡à¸à¹ˆà¸­à¸™ Update
COMMIT

PRINT 'Test Complete. Reverting settings...';
ALTER DATABASE [AdventureWorks2025] SET ALLOW_SNAPSHOT_ISOLATION OFF;
GO

