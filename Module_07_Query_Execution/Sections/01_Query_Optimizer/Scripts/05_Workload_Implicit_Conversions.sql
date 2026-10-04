-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025
-- หมายเหตุ: บน SQL Server 2019/2022 ให้แก้ USE เป็น AdventureWorks2022 ก่อนรัน

-- 05_Workload_Implicit_Conversions.sql
-- Generate queries with implicit conversions for Demo Script 02_Find_Implicit_Conversions.sql
-- Run this first, then run 02_Find_Implicit_Conversions.sql to see conversion warnings
-- Stop this script when done: Press Cancel or close the query window

USE AdventureWorks2025;
GO

SET NOCOUNT ON;

DECLARE @Counter INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @Duration INT = 300; -- Run for 5 minutes

PRINT 'Starting implicit conversion workload...';
PRINT 'Run 02_Find_Implicit_Conversions.sql in another window to see conversion warnings';
PRINT 'Press Cancel to stop this workload';

WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @Duration
BEGIN
    SET @Counter = @Counter + 1;
    
    -- Implicit conversion: VARCHAR to NVARCHAR
    SELECT 
        ProductID
    ,	Name
    ,	ProductNumber
    FROM Production.Product
    WHERE ProductNumber = 'BK-R68B-44'; -- VARCHAR literal vs NVARCHAR column
    
    -- Implicit conversion: INT to BIGINT
    SELECT 
        SalesOrderID
    ,	OrderDate
    ,	CustomerID
    FROM Sales.SalesOrderHeader
    WHERE SalesOrderID = 43659; -- INT literal vs BIGINT column (if exists)
    
    -- Implicit conversion: VARCHAR to INT (string to number)
    DECLARE @ProductNumber VARCHAR(25) = 'BK-R68B-44';
    SELECT 
        ProductID
    ,	Name
    FROM Production.Product
    WHERE ProductNumber = @ProductNumber;
    
    -- Implicit conversion in JOIN
    DECLARE @CustomerIDStr VARCHAR(10) = '1000';
    SELECT 
        soh.SalesOrderID
    ,	soh.OrderDate
    ,	c.CustomerID
    FROM Sales.SalesOrderHeader soh
    INNER JOIN Sales.Customer c ON soh.CustomerID = CAST(@CustomerIDStr AS INT);
    
    -- Implicit conversion with date/time
    DECLARE @OrderDateStr VARCHAR(20) = '2011-05-31';
    SELECT 
        SalesOrderID
    ,	OrderDate
    FROM Sales.SalesOrderHeader
    WHERE OrderDate >= @OrderDateStr; -- VARCHAR to DATETIME conversion
    
    -- Implicit conversion in WHERE with different types
    SELECT 
        ProductID
    ,	StandardCost
    ,	ListPrice
    FROM Production.Product
    WHERE StandardCost = '10.00'; -- VARCHAR to MONEY conversion
    
    -- Small delay
    IF @Counter % 20 = 0
    BEGIN
        WAITFOR DELAY '00:00:00.100'; -- 100ms delay
    END
END;

PRINT 'Workload completed.';
GO

