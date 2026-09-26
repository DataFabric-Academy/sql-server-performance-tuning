-- 03_Workload_Mixed_Stress.sql
-- Generate mixed stress workload for all Troubleshooting Demo Scripts
-- Run this first, then run other demo scripts to see various issues
-- Stop this script when done: Press Cancel or close the query window

USE AdventureWorks2025;
GO

SET NOCOUNT ON;

DECLARE @Counter INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @Duration INT = 300; -- Run for 5 minutes

PRINT 'Starting mixed stress workload...';
PRINT 'Run other demo scripts in separate windows to see various performance issues';
PRINT 'Press Cancel to stop this workload';

WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @Duration
BEGIN
    SET @Counter = @Counter + 1;
    
    -- CPU-intensive operations
    SELECT 
        SUM(CAST(ProductID AS BIGINT) * OrderQty * UnitPrice) AS TotalValue
    ,	COUNT(*) AS RowCount
    ,	CHECKSUM_AGG(CAST(ProductID AS INT)) AS ChecksumValue
    FROM Sales.SalesOrderDetail
    WHERE ProductID BETWEEN 700 AND 800
    GROUP BY ProductID % 10;
    
    -- I/O-intensive operations
    SELECT 
        COUNT(*) AS TotalRows
    ,	SUM(LineTotal) AS TotalAmount
    FROM Sales.SalesOrderDetail;
    
    -- Memory-intensive operations (large sorts)
    SELECT 
        ProductID
    ,	OrderQty
    ,	UnitPrice
    ,	LineTotal
    FROM Sales.SalesOrderDetail
    ORDER BY ProductID, OrderQty DESC, UnitPrice DESC;
    
    -- Complex joins
    SELECT 
        soh.SalesOrderID
    ,	soh.OrderDate
    ,	sod.ProductID
    ,	p.Name AS ProductName
    ,	sod.OrderQty
    ,	sod.UnitPrice
    ,	c.FirstName + ' ' + c.LastName AS CustomerName
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    INNER JOIN Production.Product p ON sod.ProductID = p.ProductID
    INNER JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
    WHERE soh.OrderDate >= DATEADD(MONTH, -6, GETDATE());
    
    -- Write operations
    BEGIN TRANSACTION;
        UPDATE Sales.SalesOrderDetail
        SET ModifiedDate = GETDATE()
        WHERE SalesOrderDetailID IN (
            SELECT TOP 50 SalesOrderDetailID 
            FROM Sales.SalesOrderDetail 
            ORDER BY NEWID()
        );
    COMMIT TRANSACTION;
    
    -- Aggregations
    SELECT 
        ProductID
    ,	COUNT(*) AS OrderCount
    ,	SUM(OrderQty) AS TotalQty
    ,	AVG(UnitPrice) AS AvgPrice
    FROM Sales.SalesOrderDetail
    GROUP BY ProductID
    HAVING COUNT(*) > 10;
    
    -- Small delay
    IF @Counter % 25 = 0
    BEGIN
        WAITFOR DELAY '00:00:00.100'; -- 100ms delay
    END
END;

PRINT 'Workload completed.';
GO

