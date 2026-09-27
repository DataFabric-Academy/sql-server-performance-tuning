-- 03_Workload_Buffer_Pool.sql
-- Generate workload to populate Buffer Pool for Demo Scripts
-- Run this in a separate session, then run 01_Buffer_Usage_By_DB.sql and 02_Page_Life_Expectancy.sql
-- Stop this script when done: Press Cancel or close the query window

USE AdventureWorks2025;
GO

SET NOCOUNT ON;

DECLARE @Counter INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @Duration INT = 300; -- Run for 5 minutes

PRINT 'Starting Buffer Pool workload...';
PRINT 'Run 01_Buffer_Usage_By_DB.sql and 02_Page_Life_Expectancy.sql in another window';
PRINT 'Press Cancel to stop this workload';

WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @Duration
BEGIN
    SET @Counter = @Counter + 1;
    
    -- Read large tables to populate buffer pool
    SELECT 
        COUNT(*) AS TotalRows
    ,	SUM(LineTotal) AS TotalAmount
    FROM Sales.SalesOrderDetail;
    
    -- Read from multiple tables
    SELECT 
        soh.SalesOrderID
    ,	soh.OrderDate
    ,	sod.ProductID
    ,	p.Name AS ProductName
    ,	sod.OrderQty
    ,	sod.UnitPrice
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    INNER JOIN Production.Product p ON sod.ProductID = p.ProductID
    WHERE soh.OrderDate >= DATEADD(YEAR, -2, GETDATE());
    
    -- Read from Person tables
    SELECT 
        p.BusinessEntityID
    ,	p.FirstName
    ,	p.LastName
    ,	e.EmailAddress
    ,	pp.PhoneNumber
    FROM Person.Person p
    LEFT JOIN Person.EmailAddress e ON p.BusinessEntityID = e.BusinessEntityID
    LEFT JOIN Person.PersonPhone pp ON p.BusinessEntityID = pp.BusinessEntityID
    WHERE p.BusinessEntityID % 100 = @Counter % 100;
    
    -- Read from Production tables
    SELECT 
        p.ProductID
    ,	p.Name AS ProductName
    ,	p.ProductNumber
    ,	psc.Name AS SubcategoryName
    ,	pc.Name AS CategoryName
    FROM Production.Product p
    INNER JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    INNER JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
    WHERE p.ProductID BETWEEN 700 AND 900;
    
    -- Aggregations to keep pages in memory
    SELECT 
        ProductID
    ,	COUNT(*) AS OrderCount
    ,	SUM(OrderQty) AS TotalQty
    ,	AVG(UnitPrice) AS AvgPrice
    FROM Sales.SalesOrderDetail
    GROUP BY ProductID
    HAVING COUNT(*) > 10;
    
    -- Small delay
    IF @Counter % 20 = 0
    BEGIN
        WAITFOR DELAY '00:00:00.050'; -- 50ms delay
    END
END;

PRINT 'Workload completed.';
GO

