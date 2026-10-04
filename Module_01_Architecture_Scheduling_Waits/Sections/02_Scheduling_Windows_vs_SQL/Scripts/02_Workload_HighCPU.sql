-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025
-- หมายเหตุ: บน SQL Server 2019/2022 ให้แก้ USE เป็น AdventureWorks2022 ก่อนรัน

-- Workload: Simulate High CPU / SOS_SCHEDULER_YIELD
-- Instructions: Run multiple instances of this script to saturate CPU.

USE AdventureWorks2025;
GO

SET NOCOUNT ON;

DECLARE @StartTime DATETIME = GETDATE();
DECLARE @DurationSeconds INT = 60; -- Run for 60 seconds
DECLARE @i INT = 0;
DECLARE @Dummy FLOAT;

PRINT 'Starting CPU Stress Test...';

WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @DurationSeconds
BEGIN
    -- Heavy math calculation to burn CPU cycles
    SET @Dummy = SQRT(RAND() * 10000000) * SIN(RAND() * 10000000) + COS(RAND() * 10000000);
    
    SET @i = @i + 1;
END

PRINT 'CPU Stress Test Completed.';
GO
