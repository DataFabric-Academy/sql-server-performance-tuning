-- 06_Workload_Active_Queries.sql
-- Generate active queries for Demo Script 03_Current_Executing_Requests.sql
-- Run this in a separate session, then run 03_Current_Executing_Requests.sql in another window
-- Stop this script when done: Press Cancel or close the query window

USE AdventureWorks2025;
GO

SET NOCOUNT ON;

DECLARE @Counter INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @Duration INT = 300; -- Run for 5 minutes

PRINT 'Starting active query workload...';
PRINT 'Run 03_Current_Executing_Requests.sql in another window to see active requests';
PRINT 'Press Cancel to stop this workload';

WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @Duration
BEGIN
    SET @Counter = @Counter + 1;
    
    -- Long-running query 1: Complex join with calculations
    SELECT 
        soh.SalesOrderID
    ,	soh.OrderDate
    ,	SUM(sod.LineTotal) AS OrderTotal
    ,	COUNT(DISTINCT sod.ProductID) AS ProductCount
    ,	AVG(sod.UnitPrice) AS AvgPrice
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    INNER JOIN Production.Product p ON sod.ProductID = p.ProductID
    INNER JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    WHERE soh.OrderDate >= DATEADD(YEAR, -3, GETDATE())
    GROUP BY soh.SalesOrderID, soh.OrderDate
    HAVING SUM(sod.LineTotal) > 1000
    ORDER BY soh.OrderDate DESC;
    
    -- Long-running query 2: Aggregations with window functions
    SELECT 
        ProductID
    ,	OrderQty
    ,	UnitPrice
    ,	LineTotal
    ,	SUM(LineTotal) OVER (PARTITION BY ProductID ORDER BY SalesOrderDetailID) AS RunningTotal
    ,	AVG(UnitPrice) OVER (PARTITION BY ProductID) AS AvgPriceByProduct
    ,	RANK() OVER (PARTITION BY ProductID ORDER BY LineTotal DESC) AS PriceRank
    FROM Sales.SalesOrderDetail
    WHERE ProductID BETWEEN 700 AND 900;
    
    -- Long-running query 3: String operations
    SELECT 
        p.FirstName + ' ' + p.LastName AS FullName
    ,	LEN(p.FirstName) + LEN(p.LastName) AS NameLength
    ,	REVERSE(p.FirstName) AS ReversedFirstName
    ,	UPPER(LEFT(p.LastName, 3)) AS LastNamePrefix
    FROM Person.Person p
    WHERE p.BusinessEntityID % 100 = @Counter % 100;
    
    -- Short delay to allow queries to be visible
    WAITFOR DELAY '00:00:00.050'; -- 50ms delay
END;

PRINT 'Workload completed.';
GO

