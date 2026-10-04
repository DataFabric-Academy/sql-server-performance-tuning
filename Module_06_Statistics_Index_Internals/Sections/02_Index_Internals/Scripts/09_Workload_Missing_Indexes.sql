-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025
-- หมายเหตุ: บน SQL Server 2019/2022 ให้แก้ USE เป็น AdventureWorks2022 ก่อนรัน

-- 09_Workload_Missing_Indexes.sql
-- Generate workload that will trigger missing index recommendations
-- Run this first, then run 10_Missing_Indexes_Advantage.sql to see recommendations
-- Stop this script when done: Press Cancel or close the query window

USE AdventureWorks2025;
GO

SET NOCOUNT ON;

DECLARE @Counter INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @Duration INT = 300; -- Run for 5 minutes

PRINT 'Starting missing index workload...';
PRINT 'Run 10_Missing_Indexes_Advantage.sql in another window to see missing index recommendations';
PRINT 'Press Cancel to stop this workload';

WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @Duration
BEGIN
    SET @Counter = @Counter + 1;
    
    -- Query without index on OrderDate (will suggest index)
    SELECT 
        SalesOrderID
    ,	OrderDate
    ,	CustomerID
    ,	TotalDue
    FROM Sales.SalesOrderHeader
    WHERE OrderDate >= DATEADD(MONTH, -6, GETDATE())
        AND CustomerID BETWEEN 1000 AND 2000;
    
    -- Query without index on ProductID and OrderQty combination
    SELECT 
        ProductID
    ,	SUM(OrderQty) AS TotalQty
    ,	AVG(UnitPrice) AS AvgPrice
    FROM Sales.SalesOrderDetail
    WHERE ProductID BETWEEN 700 AND 800
        AND OrderQty > 10
    GROUP BY ProductID;
    
    -- Query with WHERE and ORDER BY (will suggest index)
    SELECT 
        ProductID
    ,	SalesOrderID
    ,	OrderQty
    ,	UnitPrice
    FROM Sales.SalesOrderDetail
    WHERE ProductID = 750
    ORDER BY OrderQty DESC;
    
    -- Query with JOIN condition that might need index
    SELECT 
        soh.SalesOrderID
    ,	soh.OrderDate
    ,	sod.ProductID
    ,	sod.OrderQty
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.SalesOrderDetail sod 
        ON soh.SalesOrderID = sod.SalesOrderID
    WHERE soh.CustomerID = 1000
        AND sod.ProductID BETWEEN 700 AND 800;
    
    -- Query with multiple WHERE conditions
    SELECT 
        ProductID
    ,	SalesOrderID
    ,	OrderQty
    FROM Sales.SalesOrderDetail
    WHERE ProductID IN (750, 751, 752, 753, 754)
        AND OrderQty > 5
        AND UnitPrice > 100;
    
    -- Small delay
    IF @Counter % 20 = 0
    BEGIN
        WAITFOR DELAY '00:00:00.100'; -- 100ms delay
    END
END;

PRINT 'Workload completed.';
GO

