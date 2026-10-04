-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025
-- หมายเหตุ: บน SQL Server 2019/2022 ให้แก้ USE เป็น AdventureWorks2022 ก่อนรัน

-- 07_Workload_Mixed_Waits.sql
-- Generate mixed workload to create various wait types for Demo Scripts
-- Run this in a separate session, then run 08_Wait_Stats_Analysis.sql in another window
-- Stop this script when done: Press Cancel or close the query window

USE AdventureWorks2025;
GO

SET NOCOUNT ON;

DECLARE @Counter INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @Duration INT = 300; -- Run for 5 minutes

PRINT 'Starting mixed workload to generate wait statistics...';
PRINT 'Run 08_Wait_Stats_Analysis.sql in another window to see wait types';
PRINT 'Press Cancel to stop this workload';

WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @Duration
BEGIN
    SET @Counter = @Counter + 1;
    
    -- I/O Waits: Large table scans
    SELECT 
        COUNT(*) AS TotalRows
    ,	SUM(LineTotal) AS TotalAmount
    FROM Sales.SalesOrderDetail
    WHERE ProductID BETWEEN 1 AND 1000;
    
    -- CPU Waits: Complex calculations
    SELECT 
        ProductID
    ,	SUM(OrderQty * UnitPrice) AS TotalValue
    ,	AVG(CAST(OrderQty AS FLOAT)) AS AvgQty
    ,	STDEV(UnitPrice) AS PriceStdDev
    FROM Sales.SalesOrderDetail
    GROUP BY ProductID
    HAVING COUNT(*) > 10;
    
    -- Network Waits: Return large result set (simulate slow client)
    SELECT TOP 1000
        soh.SalesOrderID
    ,	soh.OrderDate
    ,	sod.ProductID
    ,	sod.OrderQty
    ,	sod.UnitPrice
    ,	p.Name AS ProductName
    ,	c.FirstName + ' ' + c.LastName AS CustomerName
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    INNER JOIN Production.Product p ON sod.ProductID = p.ProductID
    INNER JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
    WHERE soh.OrderDate >= DATEADD(YEAR, -2, GETDATE());
    
    -- Lock Waits: Update operations
    BEGIN TRANSACTION;
        UPDATE Sales.SalesOrderDetail
        SET ModifiedDate = GETDATE()
        WHERE SalesOrderDetailID = (SELECT TOP 1 SalesOrderDetailID FROM Sales.SalesOrderDetail ORDER BY NEWID());
    COMMIT TRANSACTION;
    
    -- Memory Waits: Large sorts
    SELECT 
        ProductID
    ,	OrderQty
    ,	UnitPrice
    ,	LineTotal
    FROM Sales.SalesOrderDetail
    ORDER BY ProductID, OrderQty DESC, UnitPrice DESC;
    
    -- Yield to allow waits to accumulate
    IF @Counter % 50 = 0
    BEGIN
        WAITFOR DELAY '00:00:00.100'; -- 100ms delay
    END
END;

PRINT 'Workload completed.';
GO

