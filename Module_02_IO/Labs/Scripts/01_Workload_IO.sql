-- Workload: IO Simulation
 USE AdventureWorks2025;
 GO
 SET STATISTICS IO ON;
 SET STATISTICS TIME ON;
 
 -- Step 1: Cold Cache (Force Physical Read)
 -- WARNING: Do not run on Production!
 CHECKPOINT;
 DBCC DROPCLEANBUFFERS;
 GO
 
 PRINT '--- Table Scan (Cold Cache) ---';
 SELECT * 
 FROM Sales.SalesOrderDetail
 WHERE CarrierTrackingNumber LIKE '1%';
 GO
 
 -- Step 2: Warm Cache (Logical Read Only)
 PRINT '--- Table Scan (Warm Cache) ---';
 SELECT * 
 FROM Sales.SalesOrderDetail
 WHERE CarrierTrackingNumber LIKE '1%';
 GO
 
 -- Step 3: Index Seek (Efficient IO)
 -- Picking a column that is likely indexed or Primary Key
 PRINT '--- Index Seek ---';
 SELECT * 
 FROM Sales.SalesOrderDetail
 WHERE SalesOrderID = 43659;
 GO
