-- Lab: Blocking Chain Simulation & Analysis
-- à¸§à¸±à¸•à¸–à¸¸à¸›à¸£à¸°à¸ªà¸‡à¸„à¹Œ: à¸ˆà¸³à¸¥à¸­à¸‡à¸ªà¸–à¸²à¸™à¸à¸²à¸£à¸“à¹Œ Blocking à¹à¸¥à¸°à¸à¸¶à¸à¹ƒà¸Šà¹‰ Script à¸•à¸£à¸§à¸ˆà¸ªà¸­à¸šà¸«à¸² Head Blocker
-- à¸•à¹‰à¸­à¸‡à¹ƒà¸Šà¹‰ 2 Session à¹ƒà¸™à¸à¸²à¸£à¸£à¸±à¸™

-- === [Session 1] - The Blocker (à¸œà¸¹à¹‰à¸£à¹‰à¸²à¸¢) ===
USE [AdventureWorks2025]; -- à¸«à¸£à¸·à¸­ DB à¸­à¸·à¹ˆà¸™
GO

CREATE TABLE dbo.BlockTest (ID INT, Name CHAR(10));
INSERT INTO dbo.BlockTest VALUES (1, 'A');
GO

BEGIN TRAN;
    -- Update à¹à¸¥à¸°à¸–à¸·à¸­ Lock à¸„à¹‰à¸²à¸‡à¹„à¸§à¹‰ (à¹„à¸¡à¹ˆ Commit)
    UPDATE dbo.BlockTest SET Name = 'X' WHERE ID = 1;

    PRINT 'Session 1: à¸–à¸·à¸­ Transaction à¸„à¹‰à¸²à¸‡à¹„à¸§à¹‰... (à¸£à¸±à¸™ Session 2 à¹€à¸žà¸·à¹ˆà¸­à¹ƒà¸«à¹‰à¹€à¸à¸´à¸” Block)';
    -- WAITFOR DELAY '00:01:00'; -- (Optional) à¸«à¸£à¸·à¸­à¸ˆà¸°à¸£à¸­ User à¸ªà¸±à¹ˆà¸‡ Rollback à¹€à¸­à¸‡
    
-- à¹€à¸¡à¸·à¹ˆà¸­à¸§à¸´à¹€à¸„à¸£à¸²à¸°à¸«à¹Œà¹€à¸ªà¸£à¹‡à¸ˆà¹à¸¥à¹‰à¸§ à¹ƒà¸«à¹‰à¸à¸¥à¸±à¸šà¸¡à¸²à¸—à¸µà¹ˆà¸™à¸µà¹ˆà¹€à¸žà¸·à¹ˆà¸­:
-- ROLLBACK TRAN;


-- === [Session 2] - The Victim (à¸œà¸¹à¹‰à¸–à¸¹à¸à¸à¸£à¸°à¸—à¸³) ===
/*
USE [AdventureWorks2025];
GO

PRINT 'Session 2: à¸žà¸¢à¸²à¸¢à¸²à¸¡à¸­à¹ˆà¸²à¸™à¸‚à¹‰à¸­à¸¡à¸¹à¸¥... (à¸ˆà¸°à¸„à¹‰à¸²à¸‡)';
SELECT * FROM dbo.BlockTest WHERE ID = 1;
*/

-- === [Session 3] - The Detective (à¸œà¸¹à¹‰à¸•à¸£à¸§à¸ˆà¸ªà¸­à¸š) ===
/*
-- à¸£à¸±à¸™ Script 01_Blocking_Analysis.sql à¹€à¸žà¸·à¹ˆà¸­à¸«à¸²à¸§à¹ˆà¸²à¹ƒà¸„à¸£ Block à¹ƒà¸„à¸£
-- à¸ªà¸±à¸‡à¹€à¸à¸• blocking_session_id à¹à¸¥à¸° wait_type (LCK_M_*)
*/

