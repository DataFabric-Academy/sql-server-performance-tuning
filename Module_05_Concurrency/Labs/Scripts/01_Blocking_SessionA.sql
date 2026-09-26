-- 01_Blocking_SessionA.sql
-- Generate blocking scenario for Demo Scripts
-- Run this in Session A, then run 01_Blocking_SessionB.sql in Session B
-- Then run 01_Blocking_Analysis.sql and 09_Active_Transactions.sql in Session C
-- Stop this script when done: Press Cancel or close the query window

USE AdventureWorks2025;
GO

SET NOCOUNT ON;

-- Create test table if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DemoBlockingTable')
BEGIN
    CREATE TABLE DemoBlockingTable (
        ID INT PRIMARY KEY,
        Name NVARCHAR(50),
        Value INT,
        ModifiedDate DATETIME DEFAULT GETDATE()
    );
    
    -- Insert test data
    INSERT INTO DemoBlockingTable (ID, Name, Value)
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
        'Name' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(10)),
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) * 10
    FROM sys.objects;
END
GO

DECLARE @Counter INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @Duration INT = 300; -- Run for 5 minutes

PRINT 'Starting blocking workload (Session A - The Blocker)...';
PRINT 'Run 01_Blocking_SessionB.sql in another session to create blocking';
PRINT 'Then run 01_Blocking_Analysis.sql and 09_Active_Transactions.sql in a third session';
PRINT 'Press Cancel to stop this workload';

WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @Duration
BEGIN
    SET @Counter = @Counter + 1;
    
    -- Long-running transaction that holds locks
    BEGIN TRANSACTION;
        
        -- Update multiple rows (holds exclusive locks)
        UPDATE DemoBlockingTable
        SET Value = Value + 1,
            ModifiedDate = GETDATE()
        WHERE ID BETWEEN 1 AND 100;
        
        -- Simulate work (this is where blocking occurs)
        WAITFOR DELAY '00:00:05'; -- Hold lock for 5 seconds
        
        -- More updates
        UPDATE DemoBlockingTable
        SET Name = 'Updated' + CAST(ID AS VARCHAR(10))
        WHERE ID BETWEEN 101 AND 200;
        
        WAITFOR DELAY '00:00:03'; -- Hold lock for 3 more seconds
        
    COMMIT TRANSACTION;
    
    -- Small delay between transactions
    WAITFOR DELAY '00:00:01';
END;

PRINT 'Workload completed.';
GO

