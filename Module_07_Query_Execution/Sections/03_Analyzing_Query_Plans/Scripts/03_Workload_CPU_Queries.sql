-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025
-- หมายเหตุ: บน SQL Server 2019/2022 ให้แก้ USE เป็น AdventureWorks2022 ก่อนรัน

-- 03_Workload_CPU_Queries.sql
-- Generate CPU-intensive queries for Demo Script 06_Top_CPU_Queries.sql
-- Run this first, then run 06_Top_CPU_Queries.sql to see CPU usage
-- Stop this script when done: Press Cancel or close the query window

USE AdventureWorks2025;
GO

SET NOCOUNT ON;

DECLARE @Counter INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @Duration INT = 300; -- Run for 5 minutes

PRINT 'Starting CPU-intensive workload...';
PRINT 'Run 06_Top_CPU_Queries.sql in another window to see CPU usage';
PRINT 'Press Cancel to stop this workload';

WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @Duration
BEGIN
    SET @Counter = @Counter + 1;
    
    -- Complex mathematical calculations
    SELECT 
        ProductID
    ,	SUM(CAST(OrderQty AS BIGINT) * CAST(UnitPrice AS BIGINT)) AS TotalValue
    ,	SQRT(SUM(CAST(OrderQty AS FLOAT) * OrderQty)) AS SqrtSum
    ,	POWER(COUNT(*), 2.5) AS PowerCount
    ,	STDEV(UnitPrice) AS PriceStdDev
    FROM Sales.SalesOrderDetail
    GROUP BY ProductID
    HAVING COUNT(*) > 10;
    
    -- String operations and calculations
    SELECT 
        p.FirstName + ' ' + p.LastName AS FullName
    ,	LEN(p.FirstName) + LEN(p.LastName) AS NameLength
    ,	REVERSE(p.FirstName) AS ReversedFirstName
    ,	CHECKSUM(p.FirstName, p.LastName) AS NameHash
    ,	SUBSTRING(p.FirstName, 1, LEN(p.FirstName) / 2) + 
        SUBSTRING(p.LastName, LEN(p.LastName) / 2 + 1, LEN(p.LastName)) AS ProcessedName
    FROM Person.Person p
    WHERE p.BusinessEntityID % 100 = @Counter % 100;
    
    -- Complex aggregations with window functions
    SELECT 
        ProductID
    ,	OrderQty
    ,	UnitPrice
    ,	LineTotal
    ,	SUM(LineTotal) OVER (PARTITION BY ProductID ORDER BY SalesOrderDetailID) AS RunningTotal
    ,	AVG(UnitPrice) OVER (PARTITION BY ProductID) AS AvgPriceByProduct
    ,	RANK() OVER (PARTITION BY ProductID ORDER BY LineTotal DESC) AS PriceRank
    ,	PERCENT_RANK() OVER (PARTITION BY ProductID ORDER BY LineTotal) AS PercentRank
    FROM Sales.SalesOrderDetail
    WHERE ProductID BETWEEN 700 AND 900;
    
    -- Nested calculations
    SELECT 
        SalesOrderID
    ,	SUM(OrderQty * UnitPrice) AS OrderTotal
    ,	COUNT(*) AS ItemCount
    ,	AVG(UnitPrice) AS AvgPrice
    ,	MAX(OrderQty) AS MaxQty
    ,	MIN(OrderQty) AS MinQty
    ,	STDEV(UnitPrice) AS PriceStdDev
    FROM Sales.SalesOrderDetail
    GROUP BY SalesOrderID
    HAVING SUM(OrderQty * UnitPrice) > 1000;
    
    -- Small delay
    IF @Counter % 50 = 0
    BEGIN
        WAITFOR DELAY '00:00:00.010'; -- 10ms delay
    END
END;

PRINT 'Workload completed.';
GO

