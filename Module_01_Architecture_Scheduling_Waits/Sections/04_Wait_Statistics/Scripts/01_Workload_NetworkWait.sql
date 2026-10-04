-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025
-- หมายเหตุ: บน SQL Server 2019/2022 ให้แก้ USE เป็น AdventureWorks2022 ก่อนรัน

-- Workload: Simulate ASYNC_NETWORK_IO
-- Instructions: Run this in SSMS. Ensure "Results to Grid" is selected.
-- Analysis: Check sys.dm_os_wait_stats for ASYNC_NETWORK_IO

USE AdventureWorks2025;
GO

-- Select a large amount of data
-- SSMS will take time to render this, causing SQL Server to wait on the client (Network IO)
SELECT TOP (500000)
	A.*
,	B.*
,	C.*
FROM Sales.SalesOrderDetail A
CROSS JOIN Production.Product B
CROSS JOIN Sales.SpecialOfferProduct C
WHERE A.SalesOrderID % 10 = 0 -- Filter some data to avoid crashing SSMS completely if memory is low
OPTION (MAXDOP 1); -- Force single thread to make it clear
GO
