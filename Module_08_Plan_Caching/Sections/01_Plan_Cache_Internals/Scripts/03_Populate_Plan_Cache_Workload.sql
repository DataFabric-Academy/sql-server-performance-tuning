-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

-- 03_Populate_Plan_Cache_Workload.sql
-- Populate the plan cache with a mixed workload so sys.dm_exec_cached_plans /
-- sys.dm_exec_query_stats demos have data to show:
--   1. Simple ad-hoc queries (run TWICE each -> full plans, not stubs)
--   2. Single-use ad-hoc queries (run once -> compiled plan stubs, shows 'optimize for ad hoc workloads')
--   3. Complex parameterized queries via sp_executesql (objtype = Prepared)
--   4. Stored procedures with varied parameters (objtype = Proc)
-- Safe on the shared lab server: NO DBCC FREEPROCCACHE / DROPCLEANBUFFERS here.
-- Cleanup (after class): see the commented block at the bottom.

USE AdventureWorks2025;
SET NOCOUNT ON;

-- ============================================================
-- 0. Baseline snapshot (compared against at the end)
-- ============================================================
IF OBJECT_ID('tempdb..#before') IS NOT NULL DROP TABLE #before;

SELECT objtype, COUNT_BIG(*) AS entries, SUM(CAST(size_in_bytes AS BIGINT)) AS bytes
INTO #before
FROM sys.dm_exec_cached_plans
GROUP BY objtype;

-- ============================================================
-- 1. Simple ad-hoc (400 distinct queries, each run twice => full plans)
-- ============================================================
DECLARE @i INT = 1, @sql NVARCHAR(600);

WHILE @i <= 400
BEGIN
    SELECT @sql = CASE @i % 5
        WHEN 1 THEN N'SELECT SalesOrderID, OrderDate, CustomerID, TotalDue FROM Sales.SalesOrderHeader WHERE SalesOrderID = ' + CAST(43659 + @i AS NVARCHAR(10)) + N';'
        WHEN 2 THEN N'SELECT SalesOrderDetailID, OrderQty, LineTotal FROM Sales.SalesOrderDetail WHERE SalesOrderDetailID = ' + CAST(@i * 70 AS NVARCHAR(10)) + N';'
        WHEN 3 THEN N'SELECT ProductID, Name, ListPrice FROM Production.Product WHERE ProductID = ' + CAST(1 + (@i % 500) AS NVARCHAR(10)) + N';'
        WHEN 4 THEN N'SELECT BusinessEntityID, FirstName, LastName FROM Person.Person WHERE BusinessEntityID = ' + CAST(1 + (@i % 20000) AS NVARCHAR(10)) + N';'
        ELSE N'SELECT WorkOrderID, OrderQty, DueDate FROM Production.WorkOrder WHERE WorkOrderID = ' + CAST(1 + (@i % 70000) AS NVARCHAR(10)) + N';'
    END;

    EXEC (@sql); EXEC (@sql);
    SET @i += 1;
END;

-- ============================================================
-- 2. Single-use ad-hoc (800 one-shot queries => stubs only)
-- ============================================================
SET @i = 1;

WHILE @i <= 800
BEGIN
    SELECT @sql = CASE @i % 4
        WHEN 1 THEN N'SELECT COUNT_BIG(*) FROM Sales.SalesOrderHeader WHERE CustomerID = ' + CAST(11000 + @i AS NVARCHAR(10)) + N';'
        WHEN 2 THEN N'SELECT Name, ListPrice FROM Production.Product WHERE StandardCost > ' + CAST(@i * 100 AS NVARCHAR(10)) + N';'
        WHEN 3 THEN N'SELECT TOP (5) SalesOrderID, TotalDue FROM Sales.SalesOrderHeader WHERE TerritoryID = ' + CAST((@i % 10) + 1 AS NVARCHAR(10)) + N' AND OnlineOrderFlag = ' + CAST(@i % 2 AS NVARCHAR(1)) + N' ORDER BY TotalDue DESC;'
        ELSE N'SELECT TransactionID, ProductID, Quantity FROM Production.TransactionHistory WHERE ProductID = ' + CAST(1 + (@i % 504) AS NVARCHAR(10)) + N';'
    END;

    EXEC (@sql);
    SET @i += 1;
END;

-- ============================================================
-- 3. Complex parameterized queries (24 distinct texts x 2 => Prepared)
--    All texts use exactly two parameters: @a INT, @b DATE
-- ============================================================
DECLARE @texts TABLE (id INT IDENTITY PRIMARY KEY, txt NVARCHAR(MAX));

INSERT INTO @texts (txt) VALUES
(N'SELECT TerritoryID, COUNT_BIG(*) AS Cnt, SUM(TotalDue) AS Revenue FROM Sales.SalesOrderHeader WHERE TerritoryID = @a AND OrderDate >= @b GROUP BY TerritoryID;'),
(N'SELECT TOP (@a) SalesOrderID, OrderDate, TotalDue FROM Sales.SalesOrderHeader WHERE OrderDate >= @b ORDER BY TotalDue DESC;'),
(N'SELECT SalesOrderID, OrderDate, TotalDue FROM Sales.SalesOrderHeader WHERE CustomerID = 11000 + @a AND OrderDate <= @b;'),
(N'SELECT Status, COUNT_BIG(*) AS Cnt FROM Sales.SalesOrderHeader WHERE TerritoryID = @a AND OrderDate >= @b GROUP BY Status;'),
(N'SELECT AVG(TotalDue) AS AvgDue, MAX(TotalDue) AS MaxDue, MIN(TotalDue) AS MinDue FROM Sales.SalesOrderHeader WHERE TerritoryID = @a AND OrderDate >= @b;'),
(N'SELECT TOP (@a) soh.SalesOrderID, SUM(sd.LineTotal) AS LineTotal FROM Sales.SalesOrderHeader soh JOIN Sales.SalesOrderDetail sd ON sd.SalesOrderID = soh.SalesOrderID WHERE soh.OrderDate >= @b GROUP BY soh.SalesOrderID ORDER BY SUM(sd.LineTotal) DESC;'),
(N'SELECT sd.ProductID, SUM(sd.OrderQty) AS Qty, SUM(sd.LineTotal) AS Revenue FROM Sales.SalesOrderDetail sd WHERE sd.ModifiedDate >= @b GROUP BY sd.ProductID HAVING SUM(sd.OrderQty) > @a ORDER BY Revenue DESC;'),
(N'SELECT p.Name, SUM(sd.OrderQty) AS Qty FROM Sales.SalesOrderHeader soh JOIN Sales.SalesOrderDetail sd ON sd.SalesOrderID = soh.SalesOrderID JOIN Production.Product p ON p.ProductID = sd.ProductID WHERE soh.TerritoryID = @a AND soh.OrderDate >= @b GROUP BY p.Name;'),
(N'SELECT ProductID, Name, ListPrice FROM Production.Product WHERE ListPrice > @a AND SellStartDate < @b ORDER BY ListPrice DESC;'),
(N'SELECT ProductID, COUNT_BIG(*) AS Txn, SUM(Quantity) AS Qty, SUM(ActualCost) AS Cost FROM Production.TransactionHistory WHERE TransactionDate >= @b GROUP BY ProductID HAVING COUNT_BIG(*) > @a ORDER BY Txn DESC;'),
(N'SELECT WorkOrderID, ProductID, OrderQty, DueDate FROM Production.WorkOrder WHERE DueDate BETWEEN @b AND DATEADD(DAY, @a, @b) ORDER BY DueDate;'),
(N'SELECT ProductID, SUM(OrderQty) AS Planned, SUM(ScrappedQty) AS Scrapped FROM Production.WorkOrder WHERE StartDate >= @b GROUP BY ProductID HAVING SUM(ScrappedQty) > @a;'),
(N'SELECT TOP (@a) BusinessEntityID, FirstName, LastName FROM Person.Person WHERE ModifiedDate >= @b ORDER BY LastName, FirstName;'),
(N'SELECT CustomerID, TerritoryID, StoreID FROM Sales.Customer WHERE TerritoryID = @a AND ModifiedDate < @b;'),
(N'SELECT t.CountryRegionCode, SUM(soh.TotalDue) AS Revenue FROM Sales.SalesOrderHeader soh JOIN Sales.SalesTerritory t ON t.TerritoryID = soh.TerritoryID WHERE soh.OrderDate >= @b GROUP BY t.CountryRegionCode HAVING SUM(soh.TotalDue) > @a * 1000;'),
(N'SELECT SalesOrderID, COUNT_BIG(*) AS Lines, SUM(LineTotal) AS Total FROM Sales.SalesOrderDetail WHERE ModifiedDate >= @b GROUP BY SalesOrderID HAVING COUNT_BIG(*) >= @a;'),
(N'SELECT TOP (@a) SalesOrderDetailID, OrderQty, LineTotal FROM Sales.SalesOrderDetail WHERE ProductID = @a AND ModifiedDate >= @b ORDER BY LineTotal DESC;'),
(N'SELECT BusinessEntityID, FirstName, LastName FROM Person.Person WHERE PersonType = ''IN'' AND ModifiedDate >= @b AND BusinessEntityID % 7 = @a % 7;'),
(N'SELECT YEAR(OrderDate) AS Yr, MONTH(OrderDate) AS Mo, SUM(TotalDue) AS Revenue FROM Sales.SalesOrderHeader WHERE OrderDate >= @b AND TerritoryID <= @a GROUP BY YEAR(OrderDate), MONTH(OrderDate) ORDER BY Yr, Mo;'),
(N'SELECT ps.Name AS Subcategory, COUNT_BIG(p.ProductID) AS Products FROM Production.Product p JOIN Production.ProductSubcategory ps ON ps.ProductSubcategoryID = p.ProductSubcategoryID WHERE p.ListPrice >= @a AND p.SellStartDate < @b GROUP BY ps.Name;'),
(N'SELECT soh.SalesOrderID, soh.OrderDate, soh.TotalDue FROM Sales.SalesOrderHeader soh JOIN Sales.Customer c ON c.CustomerID = soh.CustomerID WHERE c.StoreID IS NOT NULL AND c.TerritoryID = @a AND soh.OrderDate >= @b;'),
(N'SELECT ProductID, Name, StandardCost, ListPrice FROM Production.Product WHERE ListPrice - StandardCost > @a AND ModifiedDate < @b ORDER BY ListPrice DESC;'),
(N'SELECT ShipMethodID, COUNT_BIG(*) AS Orders, SUM(Freight) AS FreightCost FROM Sales.SalesOrderHeader WHERE TerritoryID = @a AND OrderDate >= @b GROUP BY ShipMethodID;'),
(N'SELECT TransactionType, COUNT_BIG(*) AS Txn, SUM(ActualCost) AS Cost FROM Production.TransactionHistory WHERE TransactionDate >= @b AND Quantity >= @a GROUP BY TransactionType;');

DECLARE @txt NVARCHAR(MAX), @a INT, @b DATE, @pass INT = 1;

WHILE @pass <= 2   -- two passes: 1st caches plan, 2nd bumps usecounts
BEGIN
    SET @i = 1;
    WHILE @i <= 24
    BEGIN
        SELECT @txt = txt FROM @texts WHERE id = @i;
        SELECT @a = (@i * 13) % 90 + 5,
               @b = DATEADD(DAY, -(@i * 61), '2014-06-01');
        EXEC sp_executesql @txt, N'@a INT, @b DATE', @a = @a, @b = @b;
        SET @i += 1;
    END;
    SET @pass += 1;
END;

GO

-- ============================================================
-- 4. Stored procedures (objtype = Proc)
--    All demo procs are prefixed usp_DemoPC_ (easy to find & drop)
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_DemoPC_GetSalesOrder @SalesOrderID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT soh.SalesOrderID, soh.OrderDate, soh.Status, soh.TotalDue,
           sd.OrderQty, sd.UnitPrice, sd.LineTotal
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sd ON sd.SalesOrderID = soh.SalesOrderID
    WHERE soh.SalesOrderID = @SalesOrderID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_DemoPC_GetOrdersByCustomer @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SalesOrderID, OrderDate, Status, TotalDue
    FROM Sales.SalesOrderHeader
    WHERE CustomerID = @CustomerID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_DemoPC_SalesByTerritory @TerritoryID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT YEAR(OrderDate) AS OrderYear, COUNT_BIG(*) AS Orders, SUM(TotalDue) AS Revenue
    FROM Sales.SalesOrderHeader
    WHERE TerritoryID = @TerritoryID
    GROUP BY YEAR(OrderDate);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_DemoPC_ProductSearch @NameLike NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ProductID, Name, ProductNumber, ListPrice
    FROM Production.Product
    WHERE Name LIKE @NameLike + N'%';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_DemoPC_OrderDetailReport @StartDate DATE, @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT soh.TerritoryID, COUNT_BIG(DISTINCT soh.SalesOrderID) AS Orders,
           SUM(sd.OrderQty) AS Items, SUM(sd.LineTotal) AS Revenue
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sd ON sd.SalesOrderID = soh.SalesOrderID
    WHERE soh.OrderDate >= @StartDate AND soh.OrderDate < @EndDate
    GROUP BY soh.TerritoryID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_DemoPC_TopCustomers @N INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@N) c.CustomerID, SUM(soh.TotalDue) AS LifetimeValue
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.Customer c ON c.CustomerID = soh.CustomerID
    GROUP BY c.CustomerID
    ORDER BY LifetimeValue DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_DemoPC_WorkOrderStatus @DaysBack INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.Name, SUM(wo.OrderQty) AS Planned, SUM(wo.ScrappedQty) AS Scrapped
    FROM Production.WorkOrder wo
    JOIN Production.Product p ON p.ProductID = wo.ProductID
    WHERE wo.StartDate >= DATEADD(DAY, -@DaysBack, (SELECT MAX(StartDate) FROM Production.WorkOrder))
    GROUP BY p.Name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_DemoPC_MultiStep @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT WorkOrderID, ProductID, OrderQty, ScrappedQty, DueDate
    INTO #wo
    FROM Production.WorkOrder
    WHERE ProductID = @ProductID;

    SELECT ProductID, SUM(OrderQty) AS Planned, SUM(ScrappedQty) AS Scrapped
    FROM #wo GROUP BY ProductID;

    SELECT COUNT_BIG(*) AS BatchCount FROM #wo;
END;
GO

-- 30 generated one-liner procs (usp_DemoPC_L01..L30) to fatten the Proc bucket
DECLARE @n INT = 1, @ddl NVARCHAR(MAX);

WHILE @n <= 30
BEGIN
    SELECT @ddl = CASE @n % 5
        WHEN 1 THEN N'CREATE OR ALTER PROCEDURE dbo.usp_DemoPC_L' + RIGHT('0' + CAST(@n AS VARCHAR(2)), 2) + N' @id INT AS SELECT SalesOrderID, OrderDate, TotalDue FROM Sales.SalesOrderHeader WHERE SalesOrderID = @id;'
        WHEN 2 THEN N'CREATE OR ALTER PROCEDURE dbo.usp_DemoPC_L' + RIGHT('0' + CAST(@n AS VARCHAR(2)), 2) + N' @id INT AS SELECT SalesOrderDetailID, OrderQty, LineTotal FROM Sales.SalesOrderDetail WHERE SalesOrderDetailID = @id;'
        WHEN 3 THEN N'CREATE OR ALTER PROCEDURE dbo.usp_DemoPC_L' + RIGHT('0' + CAST(@n AS VARCHAR(2)), 2) + N' @id INT AS SELECT ProductID, Name, ListPrice FROM Production.Product WHERE ProductID = @id;'
        WHEN 4 THEN N'CREATE OR ALTER PROCEDURE dbo.usp_DemoPC_L' + RIGHT('0' + CAST(@n AS VARCHAR(2)), 2) + N' @id INT AS SELECT BusinessEntityID, FirstName, LastName FROM Person.Person WHERE BusinessEntityID = @id;'
        ELSE N'CREATE OR ALTER PROCEDURE dbo.usp_DemoPC_L' + RIGHT('0' + CAST(@n AS VARCHAR(2)), 2) + N' @id INT AS SELECT WorkOrderID, OrderQty, DueDate FROM Production.WorkOrder WHERE WorkOrderID = @id;'
    END;

    EXEC (@ddl);
    SET @n += 1;
END;
GO

-- Execute the handwritten procs with varied (and deliberately skewed) parameters
EXEC dbo.usp_DemoPC_GetSalesOrder @SalesOrderID = 43659;
EXEC dbo.usp_DemoPC_GetSalesOrder @SalesOrderID = 44444;
EXEC dbo.usp_DemoPC_GetSalesOrder @SalesOrderID = 50000;
EXEC dbo.usp_DemoPC_GetSalesOrder @SalesOrderID = 60000;
EXEC dbo.usp_DemoPC_GetSalesOrder @SalesOrderID = 43659;   -- repeat -> usecounts up

EXEC dbo.usp_DemoPC_GetOrdersByCustomer @CustomerID = 30118;  -- huge internet customer -> parameter sniffing setup
EXEC dbo.usp_DemoPC_GetOrdersByCustomer @CustomerID = 11001;  -- tiny customer
EXEC dbo.usp_DemoPC_GetOrdersByCustomer @CustomerID = 29818;
EXEC dbo.usp_DemoPC_GetOrdersByCustomer @CustomerID = 29821;
EXEC dbo.usp_DemoPC_GetOrdersByCustomer @CustomerID = 11002;

EXEC dbo.usp_DemoPC_SalesByTerritory @TerritoryID = 1;
EXEC dbo.usp_DemoPC_SalesByTerritory @TerritoryID = 2;
EXEC dbo.usp_DemoPC_SalesByTerritory @TerritoryID = 6;
EXEC dbo.usp_DemoPC_SalesByTerritory @TerritoryID = 9;

EXEC dbo.usp_DemoPC_ProductSearch @NameLike = N'Ball';
EXEC dbo.usp_DemoPC_ProductSearch @NameLike = N'Bear';
EXEC dbo.usp_DemoPC_ProductSearch @NameLike = N'Bike';
EXEC dbo.usp_DemoPC_ProductSearch @NameLike = N'Sp';

EXEC dbo.usp_DemoPC_OrderDetailReport @StartDate = '2011-06-01', @EndDate = '2012-06-01';
EXEC dbo.usp_DemoPC_OrderDetailReport @StartDate = '2012-06-01', @EndDate = '2013-06-01';
EXEC dbo.usp_DemoPC_OrderDetailReport @StartDate = '2013-06-01', @EndDate = '2014-06-01';
EXEC dbo.usp_DemoPC_OrderDetailReport @StartDate = '2013-07-01', @EndDate = '2013-07-02';  -- narrow window

EXEC dbo.usp_DemoPC_TopCustomers @N = 5;
EXEC dbo.usp_DemoPC_TopCustomers @N = 10;
EXEC dbo.usp_DemoPC_TopCustomers @N = 25;

EXEC dbo.usp_DemoPC_WorkOrderStatus @DaysBack = 30;
EXEC dbo.usp_DemoPC_WorkOrderStatus @DaysBack = 90;
EXEC dbo.usp_DemoPC_WorkOrderStatus @DaysBack = 180;

EXEC dbo.usp_DemoPC_MultiStep @ProductID = 706;
EXEC dbo.usp_DemoPC_MultiStep @ProductID = 707;
EXEC dbo.usp_DemoPC_MultiStep @ProductID = 708;
GO

-- Execute the 30 generated procs, 3 calls each
DECLARE @p SYSNAME, @n INT = 1, @id INT;

WHILE @n <= 30
BEGIN
    SET @p = N'dbo.usp_DemoPC_L' + RIGHT('0' + CAST(@n AS VARCHAR(2)), 2);
    SET @id = 43659 + @n;
    EXEC @p @id = @id;
    EXEC @p @id = @id;
    EXEC @p @id = @id;
    SET @n += 1;
END;
GO

-- ============================================================
-- 5. Verification: before/after delta + demo evidence
-- ============================================================
SELECT b.objtype,
       b.entries AS [Before],
       COALESCE(a.entries, b.entries) AS [After],
       COALESCE(a.entries, b.entries) - b.entries AS [Delta],
       CAST((COALESCE(a.bytes, b.bytes) - b.bytes) / 1048576.0 AS DECIMAL(10,1)) AS [Delta MB]
FROM #before b
LEFT JOIN (SELECT objtype, COUNT_BIG(*) AS entries, SUM(CAST(size_in_bytes AS BIGINT)) AS bytes
           FROM sys.dm_exec_cached_plans GROUP BY objtype) a ON a.objtype = b.objtype
ORDER BY b.objtype;

SELECT objtype, COUNT_BIG(*) AS [Plans],
       CAST(SUM(CAST(size_in_bytes AS DECIMAL(18,2))) / 1024 / 1024 AS DECIMAL(10,1)) AS [Size MB],
       AVG(CAST(usecounts AS DECIMAL(10,2))) AS [Avg Use Count]
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY [Size MB] DESC;

-- Demo procs in cache, busiest first
SELECT TOP (15) ps.execution_count, cp.usecounts, p.name AS proc_name
FROM sys.dm_exec_procedure_stats ps
JOIN sys.procedures p ON p.object_id = ps.object_id
JOIN sys.dm_exec_cached_plans cp ON cp.plan_handle = ps.plan_handle
WHERE p.name LIKE 'usp_DemoPC[_]%'
ORDER BY ps.execution_count DESC;

-- Top ad-hoc statements in dm_exec_query_stats (payoff query for the demo)
SELECT TOP (15) qs.execution_count, qs.total_logical_reads,
       LEFT(st.text, 80) AS sample_statement
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE st.dbid = DB_ID() AND qs.execution_count > 1
ORDER BY qs.execution_count DESC;

-- ============================================================
-- Cleanup (run AFTER class, on purpose NOT included above):
--
-- DECLARE @s NVARCHAR(MAX);
-- SELECT @s = STRING_AGG(N'DROP PROCEDURE ' + QUOTENAME(name), N'; ')
-- FROM sys.procedures WHERE name LIKE 'usp_DemoPC[_]%';
-- EXEC (@s);
--
-- Optionally flush only this DB's plan cache (careful: shared server):
-- DBCC FLUSHPROCINDB(DB_ID('AdventureWorks2025'));
-- ============================================================
