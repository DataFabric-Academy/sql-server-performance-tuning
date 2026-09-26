-- 01_Workload_IO_Activity.sql
-- Generate I/O-intensive workload for Demo Script 04_Virtual_File_Stats.sql
-- Run this in a separate session, then run 04_Virtual_File_Stats.sql in another window
-- Stop this script when done: Press Cancel or close the query window

USE AdventureWorks2025;
GO

SET NOCOUNT ON;

DECLARE @Counter INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @Duration INT = 300; -- Run for 5 minutes

PRINT 'Starting I/O-intensive workload...';
PRINT 'Run 04_Virtual_File_Stats.sql in another window to see I/O latency';
PRINT 'Press Cancel to stop this workload';

-- Clear buffer pool first to force physical reads (optional, use with caution)
-- DBCC DROPCLEANBUFFERS; -- Uncomment if you want to force physical I/O

WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @Duration
BEGIN
    SET @Counter = @Counter + 1;
    
    -- Large table scan (forces I/O)
    SELECT 
        COUNT(*) AS TotalRows
    ,	SUM(LineTotal) AS TotalAmount
    ,	AVG(UnitPrice) AS AvgPrice
    ,	MIN(OrderQty) AS MinQty
    ,	MAX(OrderQty) AS MaxQty
    FROM Sales.SalesOrderDetail;
    
    -- Random access pattern (forces I/O)
    SELECT 
        SalesOrderID
    ,	ProductID
    ,	OrderQty
    ,	UnitPrice
    ,	LineTotal
    FROM Sales.SalesOrderDetail
    WHERE SalesOrderDetailID BETWEEN (@Counter * 100) AND ((@Counter * 100) + 1000);
    
    -- Join with multiple tables (forces I/O)
    SELECT 
        soh.SalesOrderID
    ,	soh.OrderDate
    ,	sod.ProductID
    ,	p.Name AS ProductName
    ,	sod.OrderQty
    ,	sod.UnitPrice
    ,	sod.LineTotal
    --,	c.FirstName + ' ' + c.LastName AS CustomerName
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    INNER JOIN Production.Product p ON sod.ProductID = p.ProductID
    INNER JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
    WHERE soh.OrderDate >= DATEADD(MONTH, -6, GETDATE())
    ORDER BY soh.OrderDate DESC;
    
    -- Write operations (forces write I/O)
    BEGIN TRANSACTION;
        UPDATE Sales.SalesOrderDetail
        SET ModifiedDate = GETDATE()
        WHERE SalesOrderDetailID IN (
            SELECT TOP 100 SalesOrderDetailID 
            FROM Sales.SalesOrderDetail 
            ORDER BY NEWID()
        );
    COMMIT TRANSACTION;
    
    -- Aggregation with grouping (forces I/O)
    SELECT 
        ProductID
    ,	COUNT(*) AS OrderCount
    ,	SUM(OrderQty) AS TotalQty
    ,	SUM(LineTotal) AS TotalValue
    ,	AVG(UnitPrice) AS AvgPrice
    FROM Sales.SalesOrderDetail
    GROUP BY ProductID
    HAVING COUNT(*) > 50
    ORDER BY TotalValue DESC;
    
    -- Small delay
    IF @Counter % 10 = 0
    BEGIN
        WAITFOR DELAY '00:00:00.100'; -- 100ms delay
    END
END;

PRINT 'Workload completed.';
GO

