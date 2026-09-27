/*
    LAB: Module 03 - Fragmentation Analysis (Bad vs Good Key)
    
    DEMO CONTEXT:
        In Demo 01 (File Sizes), you saw how data grows.
        In this Lab, you see how *Key Selection* (GUID vs INT) destroys your performance
        via Page Splits and Fragmentation, linking Logical Design (Keys) to Physical Storage (Pages).

    OBJECTIVE:
        Compare performance and fragmentation between Sequential Keys and Random Keys.

    INSTRUCTIONS:
        1. Run Setup to create tables.
        2. Run Workload and compare "Time Taken" (Random is usually 10x slower).
        3. Run Analysis to see 'avg_fragmentation_in_percent' and 'page_count' difference.
*/

-- Workload: Page Split Demo (Bad vs Good Key)
 IF OBJECT_ID('BadKeyTable') IS NOT NULL DROP TABLE BadKeyTable;
 IF OBJECT_ID('GoodKeyTable') IS NOT NULL DROP TABLE GoodKeyTable;
 
 CREATE TABLE BadKeyTable (
     ID UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
     Payload CHAR(100) DEFAULT 'A'
 );
 
 CREATE TABLE GoodKeyTable (
     ID INT IDENTITY(1,1) PRIMARY KEY,
     Payload CHAR(100) DEFAULT 'A'
 );
 GO
 
 -- 2. Workload (Insert 10,000 rows)
 SET NOCOUNT ON;
 DECLARE @i INT = 0;
 DECLARE @StartTime DATETIME;
 
 PRINT '--- Inserting into BadKeyTable (Random GUID) ---';
 SET @StartTime = GETDATE();
 WHILE @i < 10000
 BEGIN
     INSERT INTO BadKeyTable DEFAULT VALUES;
     SET @i = @i + 1;
 END
 PRINT 'Time Taken (ms): ' + CAST(DATEDIFF(MILLISECOND, @StartTime, GETDATE()) AS VARCHAR(20));
 
 SET @i = 0;
 PRINT '--- Inserting into GoodKeyTable (Sequential INT) ---';
 SET @StartTime = GETDATE();
 WHILE @i < 10000
 BEGIN
     INSERT INTO GoodKeyTable DEFAULT VALUES;
     SET @i = @i + 1;
 END
 PRINT 'Time Taken (ms): ' + CAST(DATEDIFF(MILLISECOND, @StartTime, GETDATE()) AS VARCHAR(20));
 GO
 
 -- 3. Analysis (Check Fragmentation)
SELECT
	OBJECT_NAME(object_id) AS TableName
,	avg_fragmentation_in_percent
,	page_count
,	avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('BadKeyTable'), NULL, NULL, 'DETAILED')
UNION ALL
SELECT
	OBJECT_NAME(object_id) AS TableName
,	avg_fragmentation_in_percent
,	page_count
,	avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('GoodKeyTable'), NULL, NULL, 'DETAILED');
 GO
