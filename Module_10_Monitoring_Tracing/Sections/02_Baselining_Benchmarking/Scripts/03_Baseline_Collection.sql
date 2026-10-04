-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

﻿-- Lab: Creating a Persistent Baseline
-- à¸§à¸±à¸•à¸–à¸¸à¸›à¸£à¸°à¸ªà¸‡à¸„à¹Œ: à¸ªà¸£à¹‰à¸²à¸‡à¸£à¸°à¸šà¸šà¹€à¸à¹‡à¸šà¸‚à¹‰à¸­à¸¡à¸¹à¸¥ Baseline à¸¥à¸‡ Table à¹€à¸žà¸·à¹ˆà¸­à¸”à¸¹à¹à¸™à¸§à¹‚à¸™à¹‰à¸¡à¸£à¸°à¸¢à¸°à¸¢à¸²à¸§ (Trending)

USE [AdventureWorks2025]; -- à¸«à¸£à¸·à¸­ DB Admin à¸‚à¸­à¸‡à¸„à¸¸à¸“
GO

-- 1. à¸ªà¸£à¹‰à¸²à¸‡ Table à¸ªà¸³à¸«à¸£à¸±à¸šà¹€à¸à¹‡à¸š History
IF OBJECT_ID('dbo.WaitStats_History') IS NULL
CREATE TABLE dbo.WaitStats_History (
    CaptureID INT IDENTITY(1,1) PRIMARY KEY,
    CaptureDate DATETIME DEFAULT GETDATE(),
    WaitType NVARCHAR(60),
    Wait_S DECIMAL(16,2),
    Resource_S DECIMAL(16,2),
    Signal_S DECIMAL(16,2),
    WaitCount BIGINT
);
CREATE INDEX IX_CaptureDate ON dbo.WaitStats_History(CaptureDate);
GO

-- 2. à¸ªà¸£à¹‰à¸²à¸‡ Procedure à¸ªà¸³à¸«à¸£à¸±à¸š Capture Data
CREATE OR ALTER PROCEDURE dbo.usp_CaptureWaitStats
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Capture Snapshot à¸¥à¸‡ Table
    -- (à¹ƒà¸™à¸„à¸§à¸²à¸¡à¹€à¸›à¹‡à¸™à¸ˆà¸£à¸´à¸‡ à¹€à¸£à¸²à¸•à¹‰à¸­à¸‡à¹€à¸à¹‡à¸š Delta à¹‚à¸”à¸¢à¹€à¸­à¸²à¸„à¹ˆà¸²à¸›à¸±à¸ˆà¸ˆà¸¸à¸šà¸±à¸™ - à¸„à¹ˆà¸²à¸„à¸£à¸±à¹‰à¸‡à¸à¹ˆà¸­à¸™à¸«à¸™à¹‰à¸²)
    -- (à¹à¸•à¹ˆà¹ƒà¸™ Lab à¸™à¸µà¹‰à¹€à¸à¹‡à¸š Raw Cumulative à¹€à¸žà¸·à¹ˆà¸­à¸„à¸§à¸²à¸¡à¸‡à¹ˆà¸²à¸¢à¹ƒà¸™à¸à¸²à¸£à¸ªà¸²à¸˜à¸´à¸•)
    
	INSERT INTO dbo.WaitStats_History (WaitType, Wait_S, Resource_S, Signal_S, WaitCount)
	SELECT TOP 20
		wait_type
	,	wait_time_ms / 1000.0
	,	(wait_time_ms - signal_wait_time_ms) / 1000.0
	,	signal_wait_time_ms / 1000.0
	,	waiting_tasks_count
	FROM sys.dm_os_wait_stats
	WHERE wait_time_ms > 0
		AND wait_type NOT LIKE '%SLEEP%' -- Filter Ignorable
		AND wait_type NOT LIKE '%QUEUE%'
	ORDER BY wait_time_ms DESC;
    
    PRINT 'Captured at ' + CONVERT(VARCHAR, GETDATE(), 120);
END
GO

-- 3. Simulate Job (Run every 1 minute)
-- à¸¥à¸­à¸‡à¸£à¸±à¸™ 2-3 à¸„à¸£à¸±à¹‰à¸‡
EXEC dbo.usp_CaptureWaitStats;
WAITFOR DELAY '00:00:05';
EXEC dbo.usp_CaptureWaitStats;

-- 4. View Trend
SELECT
	*
FROM dbo.WaitStats_History
ORDER BY CaptureDate DESC;

