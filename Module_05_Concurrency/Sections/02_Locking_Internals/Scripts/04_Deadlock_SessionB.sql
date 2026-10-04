-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025
-- หมายเหตุ: บน SQL Server 2019/2022 ให้แก้ USE เป็น AdventureWorks2022 ก่อนรัน

-- Workload: Deadlock (Session B)
 USE AdventureWorks2025;
 GO
 
 -- Step 1: Lock Resource B
 BEGIN TRANSACTION;
 UPDATE Sales.SalesOrderDetail
 SET OrderQty = 2
 WHERE SalesOrderID = 43659;
 PRINT 'Session B: Acquired Lock on SalesOrderID 43659';
 
 -- Wait for Session A to start...
 WAITFOR DELAY '00:00:10';
 
 -- Step 2: Try to Lock Resource A (Which Session A holds)
 UPDATE Production.Product
 SET Color = 'Yellow'
 WHERE ProductID = 800;
 PRINT 'Session B: Acquired Lock on Product 800';
 
 COMMIT TRANSACTION;
