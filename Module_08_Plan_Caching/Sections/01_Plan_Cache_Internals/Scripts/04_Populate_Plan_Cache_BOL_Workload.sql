-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

-- 04_Populate_Plan_Cache_BOL_Workload.sql
-- 34 SELECT queries taken from the Microsoft Docs T-SQL examples for AdventureWorks
--   Source: https://learn.microsoft.com/sql/t-sql/queries/select-examples-transact-sql
--   Packaged as a workload by: https://github.com/Matticusau/SqlWorkloadGenerator
--   (only the SELECT-only blocks are kept here — no DML reaches course data)
-- Purpose: fatten and diversify the plan cache with realistic, varied queries
--   (joins, GROUP BY, DISTINCT, UNION/EXCEPT/INTERSECT, CTEs, OPTION hints).
-- Usage: run TWICE — pass 1 compiles + caches, pass 2 bumps usecounts.
--   Safe on the shared lab server: read-only, NO DBCC FREEPROCCACHE.
-- Setup: creates tiny demo tables (dbo.Gloves, dbo.ProductResults,
--   dbo.EmployeeOne/Two/Three) required by the UNION/EXCEPT examples.

USE AdventureWorks2025;
SET NOCOUNT ON;

-- ---- setup demo tables (guarded, from the BOL examples themselves) ----
IF OBJECT_ID('dbo.Gloves', 'U') IS NULL
BEGIN
    SELECT ProductModelID, Name
    INTO dbo.Gloves
    FROM Production.ProductModel
    WHERE ProductModelID IN (3, 4);
END;
GO

IF OBJECT_ID('dbo.ProductResults', 'U') IS NULL
BEGIN
    SELECT ProductModelID, Name
    INTO dbo.ProductResults
    FROM Production.ProductModel
    WHERE ProductModelID NOT IN (3, 4)
    UNION
    SELECT ProductModelID, Name
    FROM dbo.Gloves;
END;
GO

-- small employee subsets required by the UNION ALL examples (BOL inserts them
-- via INSERT..SELECT — done here as guarded SELECT..INTO to keep setup DDL-only)
IF OBJECT_ID('dbo.EmployeeOne', 'U') IS NULL
    SELECT LastName, FirstName, JobTitle INTO dbo.EmployeeOne
    FROM HumanResources.vEmployee WHERE JobTitle = 'Production Technician - WC40';
GO
IF OBJECT_ID('dbo.EmployeeTwo', 'U') IS NULL
    SELECT LastName, FirstName, JobTitle INTO dbo.EmployeeTwo
    FROM HumanResources.vEmployee WHERE JobTitle = 'Production Technician - WC10';
GO
IF OBJECT_ID('dbo.EmployeeThree', 'U') IS NULL
    SELECT LastName, FirstName, JobTitle INTO dbo.EmployeeThree
    FROM HumanResources.vEmployee WHERE JobTitle LIKE 'Production';
GO

-- === BOL query 1 ===
SELECT *
FROM Production.Product
ORDER BY Name ASC;


GO

-- === BOL query 2 ===
SELECT p.*
FROM Production.Product AS p
ORDER BY Name ASC;


GO

-- === BOL query 3 ===
SELECT Name, ProductNumber, ListPrice AS Price
FROM Production.Product 
ORDER BY Name ASC;


GO

-- === BOL query 4 ===
SELECT Name, ProductNumber, ListPrice AS Price
FROM Production.Product 
WHERE ProductLine = 'R' 
AND DaysToManufacture < 4
ORDER BY Name ASC;


GO

-- === BOL query 5 ===
SELECT p.Name AS ProductName, 
NonDiscountSales = (OrderQty * UnitPrice),
Discounts = ((OrderQty * UnitPrice) * UnitPriceDiscount)
FROM Production.Product AS p 
INNER JOIN Sales.SalesOrderDetail AS sod
ON p.ProductID = sod.ProductID 
ORDER BY ProductName DESC;


GO

-- === BOL query 6 ===
SELECT 'Total income is', ((OrderQty * UnitPrice) * (1.0 - UnitPriceDiscount)), ' for ',
p.Name AS ProductName 
FROM Production.Product AS p 
INNER JOIN Sales.SalesOrderDetail AS sod
ON p.ProductID = sod.ProductID 
ORDER BY ProductName ASC;


GO

-- === BOL query 7 ===
SELECT DISTINCT JobTitle
FROM HumanResources.Employee
ORDER BY JobTitle;


GO

-- === BOL query 8 ===
SELECT DISTINCT Name
FROM Production.Product AS p 
WHERE EXISTS
    (SELECT *
     FROM Production.ProductModel AS pm 
     WHERE p.ProductModelID = pm.ProductModelID
           AND pm.Name LIKE 'Long-Sleeve Logo Jersey%');


GO

-- === BOL query 9 ===
SELECT DISTINCT Name
FROM Production.Product
WHERE ProductModelID IN
    (SELECT ProductModelID 
     FROM Production.ProductModel
     WHERE Name LIKE 'Long-Sleeve Logo Jersey%');


GO

-- === BOL query 10 ===
SELECT DISTINCT p.LastName, p.FirstName 
FROM Person.Person AS p 
JOIN HumanResources.Employee AS e
    ON e.BusinessEntityID = p.BusinessEntityID WHERE 5000.00 IN
    (SELECT Bonus
     FROM Sales.SalesPerson AS sp
     WHERE e.BusinessEntityID = sp.BusinessEntityID);


GO

-- === BOL query 11 ===
SELECT p1.ProductModelID
FROM Production.Product AS p1
GROUP BY p1.ProductModelID
HAVING MAX(p1.ListPrice) >= ALL
    (SELECT AVG(p2.ListPrice)
     FROM Production.Product AS p2
     WHERE p1.ProductModelID = p2.ProductModelID);


GO

-- === BOL query 12 ===
SELECT DISTINCT pp.LastName, pp.FirstName 
FROM Person.Person pp JOIN HumanResources.Employee e
ON e.BusinessEntityID = pp.BusinessEntityID WHERE pp.BusinessEntityID IN 
(SELECT SalesPersonID 
FROM Sales.SalesOrderHeader
WHERE SalesOrderID IN 
(SELECT SalesOrderID 
FROM Sales.SalesOrderDetail
WHERE ProductID IN 
(SELECT ProductID 
FROM Production.Product p 
WHERE ProductNumber = 'BK-M68B-42')));


GO

-- === BOL query 13 ===
SELECT SalesOrderID, SUM(LineTotal) AS SubTotal
FROM Sales.SalesOrderDetail
GROUP BY SalesOrderID
ORDER BY SalesOrderID;


GO

-- === BOL query 14 ===
SELECT ProductID, SpecialOfferID, AVG(UnitPrice) AS [Average Price], 
    SUM(LineTotal) AS SubTotal
FROM Sales.SalesOrderDetail
GROUP BY ProductID, SpecialOfferID
ORDER BY ProductID;


GO

-- === BOL query 15 ===
SELECT ProductModelID, AVG(ListPrice) AS [Average List Price]
FROM Production.Product
WHERE ListPrice > $1000
GROUP BY ProductModelID
ORDER BY ProductModelID;


GO

-- === BOL query 16 ===
SELECT AVG(OrderQty) AS [Average Quantity], 
NonDiscountSales = (OrderQty * UnitPrice)
FROM Sales.SalesOrderDetail
GROUP BY (OrderQty * UnitPrice)
ORDER BY (OrderQty * UnitPrice) DESC;


GO

-- === BOL query 17 ===
SELECT ProductID, AVG(UnitPrice) AS [Average Price]
FROM Sales.SalesOrderDetail
WHERE OrderQty > 10
GROUP BY ProductID
ORDER BY AVG(UnitPrice);


GO

-- === BOL query 18 ===
SELECT ProductID 
FROM Sales.SalesOrderDetail
GROUP BY ProductID
HAVING AVG(OrderQty) > 5
ORDER BY ProductID;


GO

-- === BOL query 19 ===
SELECT SalesOrderID, CarrierTrackingNumber 
FROM Sales.SalesOrderDetail
GROUP BY SalesOrderID, CarrierTrackingNumber
HAVING CarrierTrackingNumber LIKE '4BD%'
ORDER BY SalesOrderID ;


GO

-- === BOL query 20 ===
SELECT ProductID 
FROM Sales.SalesOrderDetail
WHERE UnitPrice < 25.00
GROUP BY ProductID
HAVING AVG(OrderQty) > 5
ORDER BY ProductID;


GO

-- === BOL query 21 ===
SELECT ProductID, AVG(OrderQty) AS AverageQuantity, SUM(LineTotal) AS Total
FROM Sales.SalesOrderDetail
GROUP BY ProductID
HAVING SUM(LineTotal) > $1000000.00
AND AVG(OrderQty) < 3;


GO

-- === BOL query 22 ===
SELECT ProductID, Total = SUM(LineTotal)
FROM Sales.SalesOrderDetail
GROUP BY ProductID
HAVING SUM(LineTotal) > $2000000.00;


GO

-- === BOL query 23 ===
SELECT ProductID, SUM(LineTotal) AS Total
FROM Sales.SalesOrderDetail
GROUP BY ProductID
HAVING COUNT(*) > 1500;


GO

-- === BOL query 24 ===
SELECT pp.FirstName, pp.LastName, e.NationalIDNumber
FROM HumanResources.Employee AS e WITH (INDEX(AK_Employee_NationalIDNumber))
JOIN Person.Person AS pp on e.BusinessEntityID = pp.BusinessEntityID
WHERE LastName = 'Johnson';


GO

-- === BOL query 25 ===
-- Force a table scan by using INDEX = 0.
SELECT pp.LastName, pp.FirstName, e.JobTitle
FROM HumanResources.Employee AS e WITH (INDEX = 0) JOIN Person.Person AS pp
ON e.BusinessEntityID = pp.BusinessEntityID
WHERE LastName = 'Johnson';


GO

-- === BOL query 26 ===
SELECT ProductID, OrderQty, SUM(LineTotal) AS Total
FROM Sales.SalesOrderDetail
WHERE UnitPrice < $5.00
GROUP BY ProductID, OrderQty
ORDER BY ProductID, OrderQty
OPTION (HASH GROUP, FAST 10);


GO

-- === BOL query 27 ===
SELECT BusinessEntityID, JobTitle, HireDate, VacationHours, SickLeaveHours
FROM HumanResources.Employee AS e1
UNION
SELECT BusinessEntityID, JobTitle, HireDate, VacationHours, SickLeaveHours
FROM HumanResources.Employee AS e2
OPTION (MERGE UNION);


GO

-- === BOL query 28 ===
-- Here is the simple union.
SELECT ProductModelID, Name
FROM Production.ProductModel
WHERE ProductModelID NOT IN (3, 4)
UNION
SELECT ProductModelID, Name
FROM dbo.Gloves
ORDER BY Name;


GO

-- === BOL query 29 ===
SELECT ProductModelID, Name 
FROM dbo.ProductResults;


GO

-- === BOL query 30 ===
/* Union */
SELECT ProductModelID, Name
FROM Production.ProductModel
WHERE ProductModelID NOT IN (3, 4)
UNION
SELECT ProductModelID, Name
FROM dbo.Gloves
ORDER BY Name;


GO

-- === BOL query 31 ===
-- Union ALL
SELECT LastName, FirstName, JobTitle
FROM dbo.EmployeeOne
UNION ALL
SELECT LastName, FirstName ,JobTitle
FROM dbo.EmployeeTwo
UNION ALL
SELECT LastName, FirstName,JobTitle 
FROM dbo.EmployeeThree;


GO

-- === BOL query 32 ===
-- Union ALL 2
SELECT LastName, FirstName,JobTitle
FROM dbo.EmployeeOne
UNION 
SELECT LastName, FirstName, JobTitle 
FROM dbo.EmployeeTwo
UNION 
SELECT LastName, FirstName, JobTitle 
FROM dbo.EmployeeThree;


GO

-- === BOL query 33 ===
-- Union ALL 3
SELECT LastName, FirstName,JobTitle 
FROM dbo.EmployeeOne
UNION ALL
(
SELECT LastName, FirstName, JobTitle 
FROM dbo.EmployeeTwo
UNION
SELECT LastName, FirstName, JobTitle 
FROM dbo.EmployeeThree
);



GO

-- === BOL query 34 ===
/*******************************************************************************
Scripts from http://msdn.microsoft.com/en-us/library/bb510625.aspx
*******************************************************************************/


GO


-- ============================================================
-- Cleanup (after class):
-- DROP TABLE IF EXISTS dbo.Gloves, dbo.ProductResults, dbo.EmployeeOne,
--   dbo.EmployeeTwo, dbo.EmployeeThree;
-- (the 34 queries are plan-cache entries only — no course data changes)
-- ============================================================
