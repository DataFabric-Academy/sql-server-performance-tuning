-- Workload: Blocking (Session B - The Victim)
 USE AdventureWorks2025;
 GO
 
 PRINT 'Attempting to read blocked data...';
 
 -- This will wait because Session A holds an X Lock
SELECT
	ProductID
,	Name
,	Color
FROM Production.Product
WHERE ProductID = 1;
 
 PRINT 'Read Complete.';
