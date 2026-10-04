-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025
-- หมายเหตุ: บน SQL Server 2019/2022 ให้แก้ USE เป็น AdventureWorks2022 ก่อนรัน

-- 04_Workload_IO_Queries.sql
-- Generate I/O-intensive queries for Demo Script 07_High_IO_Queries.sql
-- Run this first, then run 07_High_IO_Queries.sql to see I/O usage
-- Stop this script when done: Press Cancel or close the query window

USE AdventureWorks2025;
GO

SET NOCOUNT ON;

DECLARE @Counter INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @Duration INT = 300; -- Run for 5 minutes

PRINT 'Starting I/O-intensive workload...';
PRINT 'Run 07_High_IO_Queries.sql in another window to see I/O usage';
PRINT 'Press Cancel to stop this workload';

WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @Duration
BEGIN
    SET @Counter = @Counter + 1;
    
    -- Large table scans (high logical reads)
    SELECT 
        COUNT(*) AS TotalRows
    ,	SUM(LineTotal) AS TotalAmount
    ,	AVG(UnitPrice) AS AvgPrice
    ,	MIN(OrderQty) AS MinQty
    ,	MAX(OrderQty) AS MaxQty
    FROM Sales.SalesOrderDetail;
    
    -- Multiple table joins (high logical reads)
    SELECT 
        soh.SalesOrderID
    ,	soh.OrderDate
    ,	sod.ProductID
    ,	p.Name AS ProductName
    ,	sod.OrderQty
    ,	sod.UnitPrice
    ,	sod.LineTotal
    ,	c.FirstName + ' ' + c.LastName AS CustomerName
    ,	psc.Name AS SubcategoryName
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    INNER JOIN Production.Product p ON sod.ProductID = p.ProductID
    INNER JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
    INNER JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    WHERE soh.OrderDate >= DATEADD(MONTH, -6, GETDATE());
    
    -- Aggregations with grouping (high logical reads)
    SELECT 
        ProductID
    ,	COUNT(*) AS OrderCount
    ,	SUM(OrderQty) AS TotalQty
    ,	SUM(LineTotal) AS TotalValue
    ,	AVG(UnitPrice) AS AvgPrice
    ,	STDEV(UnitPrice) AS PriceStdDev
    FROM Sales.SalesOrderDetail
    GROUP BY ProductID
    HAVING COUNT(*) > 50
    ORDER BY TotalValue DESC;
    
    -- Write operations (high logical writes)
    BEGIN TRANSACTION;
        UPDATE Sales.SalesOrderDetail
        SET ModifiedDate = GETDATE()
        WHERE SalesOrderDetailID IN (
            SELECT TOP 100 SalesOrderDetailID 
            FROM Sales.SalesOrderDetail 
            ORDER BY NEWID()
        );
    COMMIT TRANSACTION;
    
    -- Sorts and aggregations (high logical reads)
    SELECT 
        ProductID
    ,	OrderQty
    ,	UnitPrice
    ,	LineTotal
    FROM Sales.SalesOrderDetail
    WHERE ProductID BETWEEN 700 AND 900
    ORDER BY ProductID, OrderQty DESC, UnitPrice DESC;
    
    -- Small delay
    IF @Counter % 10 = 0
    BEGIN
        WAITFOR DELAY '00:00:00.100'; -- 100ms delay
    END
END;

PRINT 'Workload completed.';
GO

