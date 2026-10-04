-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

﻿-- Lab: Stale Statistics Effect
-- à¸§à¸±à¸•à¸–à¸¸à¸›à¸£à¸°à¸ªà¸‡à¸„à¹Œ: à¹à¸ªà¸”à¸‡à¹ƒà¸«à¹‰à¹€à¸«à¹‡à¸™à¸§à¹ˆà¸² Statistics à¸—à¸µà¹ˆà¹„à¸¡à¹ˆà¸­à¸±à¸›à¹€à¸”à¸•à¸ªà¹ˆà¸‡à¸œà¸¥à¸•à¹ˆà¸­à¸„à¹ˆà¸² Estimated Rows à¸­à¸¢à¹ˆà¸²à¸‡à¹„à¸£

USE [AdventureWorks2025]; -- à¸«à¸£à¸·à¸­ DB Test
GO

-- 1. Setup Table & Data
IF OBJECT_ID('dbo.StatsLab') IS NOT NULL DROP TABLE dbo.StatsLab;
CREATE TABLE dbo.StatsLab (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Val INT
);

-- à¹ƒà¸ªà¹ˆà¸‚à¹‰à¸­à¸¡à¸¹à¸¥ 1,000 à¹à¸–à¸§
INSERT INTO dbo.StatsLab (Val)
SELECT TOP (1000) 100
FROM master.dbo.spt_values;

-- à¸ªà¸£à¹‰à¸²à¸‡ Index à¹€à¸žà¸·à¹ˆà¸­à¹ƒà¸«à¹‰à¹€à¸à¸´à¸” Statistics
CREATE INDEX IX_Val ON dbo.StatsLab(Val);

-- 2. à¸”à¸¹ Stats à¸„à¸£à¸±à¹‰à¸‡à¹à¸£à¸
DBCC SHOW_STATISTICS ('dbo.StatsLab', 'IX_Val');
-- à¸ªà¸±à¸‡à¹€à¸à¸• 'Rows' = 1000

-- 3. à¹ƒà¸ªà¹ˆà¸‚à¹‰à¸­à¸¡à¸¹à¸¥à¹€à¸žà¸´à¹ˆà¸¡à¸­à¸µà¸ 1,000 à¹à¸–à¸§ (Data à¹€à¸›à¸¥à¸µà¹ˆà¸¢à¸™à¹à¸•à¹ˆ Stats à¸¢à¸±à¸‡à¹„à¸¡à¹ˆà¸­à¸±à¸›à¹€à¸”à¸•à¸—à¸±à¸™à¸—à¸µ)
INSERT INTO dbo.StatsLab (Val)
SELECT TOP (1000) 200
FROM master.dbo.spt_values;

-- 4. à¸•à¸£à¸§à¸ˆà¸ªà¸­à¸š Estimated Rows
SET SHOWPLAN_XML ON;
GO
SELECT * FROM dbo.StatsLab WHERE Val = 200;
GO
SET SHOWPLAN_XML OFF;
GO

-- *Task*: à¸„à¸¥à¸´à¸à¸”à¸¹ XML Plan à¸«à¸£à¸·à¸­ Graphic Plan
-- à¸”à¸¹à¸„à¹ˆà¸² 'Estimated Number of Rows' à¹€à¸—à¸µà¸¢à¸šà¸à¸±à¸š 'Actual Number of Rows'
-- à¸–à¹‰à¸² Stats à¹„à¸¡à¹ˆà¸­à¸±à¸›à¹€à¸”à¸• Estimated à¸­à¸²à¸ˆà¸ˆà¸°à¹€à¸›à¹‡à¸™ 1 (à¸«à¸£à¸·à¸­à¸„à¹ˆà¸² Default) à¸—à¸±à¹‰à¸‡à¸—à¸µà¹ˆà¸¡à¸µà¸ˆà¸£à¸´à¸‡ 1000

-- 5. Fix it
UPDATE STATISTICS dbo.StatsLab;
-- à¸¥à¸­à¸‡ Select à¹ƒà¸«à¸¡à¹ˆ à¸ˆà¸°à¹€à¸«à¹‡à¸™ Estimated à¹ƒà¸à¸¥à¹‰à¹€à¸„à¸µà¸¢à¸‡ Actual à¸¡à¸²à¸à¸‚à¸¶à¹‰à¸™

