-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025
-- หมายเหตุ: บน SQL Server 2019/2022 ให้แก้ USE เป็น AdventureWorks2022 ก่อนรัน

-- 02_Blocking_SessionB.sql
-- This is the VICTIM session that will be blocked
-- Run this AFTER starting 01_Blocking_SessionA.sql in Session A
-- This will try to read/update the same rows and get blocked

USE AdventureWorks2025;
GO

SET NOCOUNT ON;

DECLARE @Counter INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @Duration INT = 300; -- Run for 5 minutes

PRINT 'Starting victim workload (Session B - The Victim)...';
PRINT 'This session will be blocked by Session A';
PRINT 'Press Cancel to stop this workload';

WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @Duration
BEGIN
    SET @Counter = @Counter + 1;
    
    -- Try to read rows that Session A is updating (will wait for shared lock)
    SELECT 
        ID
    ,	Name
    ,	Value
    ,	ModifiedDate
    FROM DemoBlockingTable
    WHERE ID BETWEEN 1 AND 100;
    
    -- Try to update rows that Session A is updating (will wait for exclusive lock)
    BEGIN TRANSACTION;
        UPDATE DemoBlockingTable
        SET Value = Value - 1
        WHERE ID BETWEEN 50 AND 150;
    COMMIT TRANSACTION;
    
    -- Small delay
    WAITFOR DELAY '00:00:02';
END;

PRINT 'Workload completed.';
GO

