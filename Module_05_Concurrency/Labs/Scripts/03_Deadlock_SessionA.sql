-- Workload: Deadlock (Session A)
 USE AdventureWorks2025;
 GO
 
 -- Step 1: Lock Resource A
 BEGIN TRANSACTION;
 UPDATE Production.Product
 SET Color = 'Blue'
 WHERE ProductID = 800;
 PRINT 'Session A: Acquired Lock on Product 800';
 
 -- Wait for Session B to start...
 WAITFOR DELAY '00:00:10';
 
 -- Step 2: Try to Lock Resource B (Which Session B holds)
 UPDATE Sales.SalesOrderDetail
 SET OrderQty = 5
 WHERE SalesOrderID = 43659;
 PRINT 'Session A: Acquired Lock on SalesOrderID 43659';
 
 COMMIT TRANSACTION;
