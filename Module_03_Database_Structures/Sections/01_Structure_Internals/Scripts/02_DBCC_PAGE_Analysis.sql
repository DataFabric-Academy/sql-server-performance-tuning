/*
    LAB: Module 03 - Deep Dive with DBCC PAGE
    
    DEMO CONTEXT:
        In Demo 01, we talked about 8KB Pages abstractly.
        In this Lab, you use the undocumented DBCC PAGE command to actually *see* the 
        bytes on the disk, verifying the Header, Free Space, and Slot Array concepts.

    OBJECTIVE:
        Visualize internal Page structure to understand Storage Engine overhead.

    INSTRUCTIONS:
        1. Create the 'PageLab' table.
        2. Insert 2 rows (large enough to fit, but consume space).
        3. Use DBCC IND to find the PageID of the data page (PageType=1).
        4. Use DBCC PAGE to inspect the content.
           - CHALLENGE: Find the 'm_freeCnt' (Free Bytes). Calculate if a 3rd row fits.
*/

-- Lab: Deep Dive into Database Pages with DBCC PAGE
-- à¸§à¸±à¸•à¸–à¸¸à¸›à¸£à¸°à¸ªà¸‡à¸„à¹Œ: à¸à¸¶à¸à¹ƒà¸Šà¹‰à¸‡à¸²à¸™ DBCC PAGE à¹€à¸žà¸·à¹ˆà¸­à¸”à¸¹à¹‚à¸„à¸£à¸‡à¸ªà¸£à¹‰à¸²à¸‡à¸‚à¹‰à¸­à¸¡à¸¹à¸¥à¸ à¸²à¸¢à¹ƒà¸™ (Header, Slot Array)
-- à¸„à¸³à¹€à¸•à¸·à¸­à¸™: DBCC PAGE à¹€à¸›à¹‡à¸™ Undocumented Command à¹ƒà¸«à¹‰à¹ƒà¸Šà¹‰à¹ƒà¸™à¸à¸²à¸£à¹€à¸£à¸µà¸¢à¸™à¸£à¸¹à¹‰à¹€à¸—à¹ˆà¸²à¸™à¸±à¹‰à¸™

USE [AdventureWorks2025]; -- à¸«à¸£à¸·à¸­à¹€à¸›à¸¥à¸µà¹ˆà¸¢à¸™à¹€à¸›à¹‡à¸™ Database à¸—à¸µà¹ˆà¸¡à¸µà¸­à¸¢à¸¹à¹ˆ
GO

-- 1. à¸ªà¸£à¹‰à¸²à¸‡à¸•à¸²à¸£à¸²à¸‡à¸—à¸”à¸ªà¸­à¸š
CREATE TABLE dbo.PageLab (
    ID INT IDENTITY(1,1),
    Data CHAR(4000) DEFAULT 'A'
);
GO

-- 2. à¹ƒà¸ªà¹ˆà¸‚à¹‰à¸­à¸¡à¸¹à¸¥ 2 à¹à¸–à¸§ (à¹€à¸žà¸·à¹ˆà¸­à¹ƒà¸«à¹‰à¹€à¸•à¹‡à¸¡ 1 Page à¹€à¸žà¸£à¸²à¸° 4000+4000+Overhead > 8060 bytes)
INSERT INTO dbo.PageLab DEFAULT VALUES;
INSERT INTO dbo.PageLab DEFAULT VALUES;
GO

-- 3. à¸«à¸² Page ID à¸‚à¸­à¸‡à¸•à¸²à¸£à¸²à¸‡à¸™à¸µà¹‰
-- DBCC IND (DatabaseName, TableName, IndexID)
-- IndexID: 0=Heap, 1=Clustered Index
DBCC IND ('AdventureWorks2025', 'dbo.PageLab', 0);
-- à¹ƒà¸«à¹‰à¸ˆà¸”à¸ˆà¸³à¸„à¹ˆà¸² 'PagePID' à¸—à¸µà¹ˆ PageType = 1 (Data Page) à¸¡à¸²

-- 4. à¸ªà¹ˆà¸­à¸‡à¸”à¸¹à¸‚à¹‰à¸­à¸¡à¸¹à¸¥à¸ à¸²à¸¢à¹ƒà¸™ Page
-- DBCC PAGE (DatabaseName, FileID, PageID, PrintOption)
-- PrintOption: 0=Header, 1=Chunks, 2=Whole, 3=Row Details
DBCC TRACEON(3604); -- à¹€à¸›à¸´à¸” Output à¸­à¸­à¸à¸«à¸™à¹‰à¸²à¸ˆà¸­
DBCC PAGE ('AdventureWorks2025', 1, <à¹ƒà¸ªà¹ˆ_PageID_à¸•à¸£à¸‡à¸™à¸µà¹‰>, 3);
DBCC TRACEOFF(3604);

/*
à¸ªà¸´à¹ˆà¸‡à¸—à¸µà¹ˆà¸•à¹‰à¸­à¸‡à¸ªà¸±à¸‡à¹€à¸à¸•à¹ƒà¸™ Output:
- m_type: 1 = Data Page
- m_freeCnt: à¸žà¸·à¹‰à¸™à¸—à¸µà¹ˆà¸§à¹ˆà¸²à¸‡à¸—à¸µà¹ˆà¹€à¸«à¸¥à¸·à¸­à¹ƒà¸™ Page
- Slot Array: à¸•à¸³à¹à¸«à¸™à¹ˆà¸‡à¸‚à¸­à¸‡ Row à¹ƒà¸™ Page (à¸”à¹‰à¸²à¸™à¸¥à¹ˆà¸²à¸‡à¸ªà¸¸à¸”)
*/

-- 5. Cleanup
DROP TABLE dbo.PageLab;
GO

