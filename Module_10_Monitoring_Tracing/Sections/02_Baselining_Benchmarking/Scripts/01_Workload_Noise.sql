-- Workload: Background Noise (Random Activity)
 USE AdventureWorks2025;
 GO
 SET NOCOUNT ON;
 
 DECLARE @EndTime DATETIME = DATEADD(MINUTE, 2, GETDATE()); -- Run for 2 minutes
 
 WHILE GETDATE() < @EndTime
 BEGIN
     -- 1. Random Read
	SELECT TOP 1
		*
	FROM Sales.SalesOrderDetail
	WHERE SalesOrderID = CAST(RAND() * 70000 AS INT);
     
     -- 2. Random CPU Math
     DECLARE @x FLOAT = SQRT(RAND() * 1000);
     
     -- 3. Small Wait
     WAITFOR DELAY '00:00:00.100';
 END
