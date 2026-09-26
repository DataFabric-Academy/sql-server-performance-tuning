-- Workload: Chaos Generator (Blocking + CPU + IO)
 USE AdventureWorks2025;
 GO
 
 -- 1 in 3 chance of being a Blocker, CPU Hog, or IO Hog
 DECLARE @Role INT = CAST(RAND() * 3 AS INT);
 
 IF @Role = 0
 BEGIN
     PRINT 'I am a BLOCKER';
     BEGIN TRAN;
     UPDATE Top(1) Production.Product SET Color = 'Red';
     WAITFOR DELAY '00:01:00'; -- Block for 1 min
     ROLLBACK;
 END
 ELSE IF @Role = 1
 BEGIN
     PRINT 'I am a CPU HOG';
     DECLARE @i INT = 0;
     WHILE @i < 500000
     BEGIN
         SET @i = @i + 1;
         DECLARE @x FLOAT = SQRT(@i);
     END
 END
 ELSE
 BEGIN
	PRINT 'I am an IO HOG';
	SELECT
		*
	FROM Sales.SalesOrderDetail
	WHERE CarrierTrackingNumber LIKE '%';
 END
