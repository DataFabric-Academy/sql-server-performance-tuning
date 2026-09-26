-- Workload: Blocking (Session A - The Blocker)
 USE AdventureWorks2025;
 GO
 
 BEGIN TRANSACTION;
 
 -- Update a row and hold the Exclusive Lock (X)
 UPDATE Production.Product
 SET Color = 'Red'
 WHERE ProductID = 1;
 
 PRINT 'Transaction Started. Lock Held. Waiting... Run Session B now.';
 
 -- WAITFOR DELAY '00:01:00'; -- Optional auto-release
 -- ROLLBACK TRANSACTION; -- Run this manually to release
