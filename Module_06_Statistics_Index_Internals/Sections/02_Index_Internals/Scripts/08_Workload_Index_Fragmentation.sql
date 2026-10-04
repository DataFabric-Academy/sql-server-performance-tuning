-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025
-- หมายเหตุ: บน SQL Server 2019/2022 ให้แก้ USE เป็น AdventureWorks2022 ก่อนรัน

-- 08_Workload_Index_Fragmentation.sql
-- Generate workload that causes index fragmentation for Demo Script 01_Index_Fragmentation.sql
-- Run this first, then run 01_Index_Fragmentation.sql to see fragmentation
-- Stop this script when done: Press Cancel or close the query window

USE AdventureWorks2025;
GO

SET NOCOUNT ON;

-- Create test table for fragmentation demo
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DemoFragmentationTable')
BEGIN
    CREATE TABLE DemoFragmentationTable (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        RandomValue INT,
        Name NVARCHAR(100),
        Description NVARCHAR(500),
        CreatedDate DATETIME DEFAULT GETDATE(),
        ModifiedDate DATETIME DEFAULT GETDATE()
    );
    
    -- Create non-clustered index
    CREATE NONCLUSTERED INDEX IX_DemoFragmentationTable_RandomValue 
    ON DemoFragmentationTable(RandomValue);
    
    -- Insert initial data
    INSERT INTO DemoFragmentationTable (RandomValue, Name, Description)
    SELECT 
        ABS(CHECKSUM(NEWID())) % 10000,
        'Name' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(10)),
        'Description ' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(10))
    FROM sys.objects o1
    CROSS JOIN sys.objects o2;
END
GO

DECLARE @Counter INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @Duration INT = 300; -- Run for 5 minutes

PRINT 'Starting index fragmentation workload...';
PRINT 'Run 01_Index_Fragmentation.sql in another window to see fragmentation';
PRINT 'Press Cancel to stop this workload';

WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @Duration
BEGIN
    SET @Counter = @Counter + 1;
    
    -- Insert random values (causes page splits)
    INSERT INTO DemoFragmentationTable (RandomValue, Name, Description)
    SELECT 
        ABS(CHECKSUM(NEWID())) % 10000,
        'Name' + CAST(@Counter AS VARCHAR(10)),
        'Description ' + CAST(@Counter AS VARCHAR(10))
    FROM (SELECT TOP 10 * FROM sys.objects) AS o;
    
    -- Update random rows (causes fragmentation)
    UPDATE DemoFragmentationTable
    SET RandomValue = ABS(CHECKSUM(NEWID())) % 10000,
        ModifiedDate = GETDATE()
    WHERE ID IN (
        SELECT TOP 50 ID 
        FROM DemoFragmentationTable 
        ORDER BY NEWID()
    );
    
    -- Delete random rows (causes fragmentation)
    DELETE FROM DemoFragmentationTable
    WHERE ID IN (
        SELECT TOP 20 ID 
        FROM DemoFragmentationTable 
        WHERE ID > 1000
        ORDER BY NEWID()
    );
    
    -- Small delay
    IF @Counter % 10 = 0
    BEGIN
        WAITFOR DELAY '00:00:00.100'; -- 100ms delay
    END
END;

PRINT 'Workload completed.';
PRINT 'Note: Run ALTER INDEX ALL ON DemoFragmentationTable REBUILD to fix fragmentation';
GO

