/*
    LAB: Module 11 - The "Broken Server" Challenge
    
    DEMO CONTEXT:
        In Demo 03 (Active Blocking) and Demo 04 (Top Resource Queries), you learned identifying tools.
        This Lab is the FINAL TEST: It breaks the server on purpose.
        You must combine ALL your Tools (Waits, Blocking, DMVs) to identify the perpetrators.

    OBJECTIVE:
        Simulate a "Chaos" scenario where multiple problems (Blocking, CPU, I/O) 
        happen simultaneously, and practice isolating each issue using troubleshooting tools.

    INSTRUCTIONS:
        1. Open 4 separate SSMS Query Windows.
        2. Copy the script sections below into each window according to instructions ([WINDOW 1], [WINDOW 2], etc.).
        3. Run Window 1, 2, and 3 to start the chaos.
        4. Go to Window 4 (The DBA). Use your tools (sp_who2, DMVs from Module 10) to:
           - Identify the Blocker (Session ID?).
           - Identify the CPU Consumer.
           - Identify the I/O generator.
        5. Kill the bad sessions or Stop the query execution to resolve.

    PREREQUISITES:
        - AdventureWorks2025 or newer
*/

-- Lab: The "Broken Server" Challenge
-- à¸§à¸±à¸•à¸–à¸¸à¸›à¸£à¸°à¸ªà¸‡à¸„à¹Œ: à¸ˆà¸³à¸¥à¸­à¸‡à¸ªà¸–à¸²à¸™à¸à¸²à¸£à¸“à¹Œà¸«à¸²à¸¢à¸™à¸° (Chaos) à¹€à¸žà¸·à¹ˆà¸­à¸à¸¶à¸à¸§à¸´à¹€à¸„à¸£à¸²à¸°à¸«à¹Œà¸›à¸±à¸à¸«à¸²à¸—à¸µà¹ˆà¹€à¸à¸´à¸”à¸‚à¸¶à¹‰à¸™à¸žà¸£à¹‰à¸­à¸¡à¸à¸±à¸™
-- instructions: à¹€à¸›à¸´à¸” SSMS 3 à¸«à¸™à¹‰à¸²à¸•à¹ˆà¸²à¸‡ à¹à¸¥à¹‰à¸§ Copy Code à¹à¸•à¹ˆà¸¥à¸°à¸ªà¹ˆà¸§à¸™à¹„à¸›à¸£à¸±à¸™

-- ==========================================
-- [WINDOW 1] The Blocker (à¸•à¸±à¸§à¸¥à¹‡à¸­à¸„)
-- ==========================================
USE [AdventureWorks2025];
GO
BEGIN TRAN;
    UPDATE Person.Person 
    SET ModifiedDate = GETDATE(); -- Update à¸—à¸¸à¸à¹à¸–à¸§! (Table Lock)
    -- à¹„à¸¡à¹ˆ Commit/Rollback!
    PRINT 'Window 1: Holding Table Lock on Person.Person...';


-- ==========================================
-- [WINDOW 2] The CPU Hog (à¸à¸´à¸™ CPU)
-- ==========================================
SET NOCOUNT ON;
DECLARE @Start DATETIME = GETDATE();
PRINT 'Window 2: Burning CPU...';
WHILE DATEDIFF(SECOND, @Start, GETDATE()) < 300 -- 5 à¸™à¸²à¸—à¸µ
BEGIN
    DECLARE @x FLOAT = SQRT(RAND() * 10000000);
END


-- ==========================================
-- [WINDOW 3] The IO Storm (à¸­à¹ˆà¸²à¸™à¸«à¸™à¸±à¸)
-- ==========================================
USE [AdventureWorks2025];
GO
PRINT 'Window 3: Generating Random I/O...';
WHILE 1=1
BEGIN
    -- à¸ªà¸¸à¹ˆà¸¡à¸­à¹ˆà¸²à¸™à¸‚à¹‰à¸­à¸¡à¸¹à¸¥à¹à¸šà¸šà¹„à¸¡à¹ˆà¹ƒà¸Šà¹‰ Index (Table Scan)
    SELECT TOP 1 * FROM Production.TransactionHistory 
    WHERE TransactionID = CAST(RAND() * 100000 AS INT); 
END


-- ==========================================
-- [WINDOW 4] The DBA (à¸„à¸¸à¸“!)
-- ==========================================
/*
à¸ à¸²à¸£à¸à¸´à¸ˆà¸‚à¸­à¸‡à¸„à¸¸à¸“:
1. à¹€à¸›à¸´à¸” 01_Server_Health_Check.sql à¸”à¸¹à¸ à¸²à¸žà¸£à¸§à¸¡ (CPU?, Blocking?)
2. à¹€à¸›à¸´à¸” 03_Current_Executing_Requests.sql à¸”à¸¹à¸§à¹ˆà¸²à¹ƒà¸„à¸£à¸—à¸³à¸­à¸°à¹„à¸£
3. à¸«à¸² Root Cause:
   - à¹ƒà¸„à¸£ Block à¹ƒà¸„à¸£? (Window 1 Block Window 3?)
   - à¹ƒà¸„à¸£à¸à¸´à¸™ CPU? (Window 2)
*/

