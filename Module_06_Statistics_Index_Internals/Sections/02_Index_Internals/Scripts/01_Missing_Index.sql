-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025
-- หมายเหตุ: บน SQL Server 2019/2022 ให้แก้ USE เป็น AdventureWorks2022 ก่อนรัน

-- Workload: Missing Index & Key Lookup
 USE AdventureWorks2025;
 GO
 
 -- Step 1: The Problem Query
 -- We search by MiddleName (often not indexed) and ask for other columns
 SET STATISTICS IO ON;
 
PRINT '--- Baseline: Clustered Index Scan (Missing Index) ---';
SELECT
	BusinessEntityID
,	FirstName
,	LastName
,	EmailPromotion
FROM Person.Person
WHERE MiddleName = 'J.';
 -- Look for Green Text "Missing Index" in Execution Plan
 GO
 
 -- Step 2: Poor Index (Causes Key Lookup)
 CREATE NONCLUSTERED INDEX IX_Person_MiddleName ON Person.Person(MiddleName);
 GO
 
PRINT '--- Test: Key Lookup (Index Seek + Lookup) ---';
SELECT
	BusinessEntityID
,	FirstName
,	LastName
,	EmailPromotion
FROM Person.Person
WHERE MiddleName = 'J.';
 -- Check Logical Reads. If 'J.' returns many rows, this is expensive.
 GO
 
 -- Step 3: Fixing with Covering Index
 DROP INDEX IX_Person_MiddleName ON Person.Person;
 CREATE NONCLUSTERED INDEX IX_Person_MiddleName_Covering 
 ON Person.Person(MiddleName) 
 INCLUDE (FirstName, LastName, EmailPromotion);
 GO
 
PRINT '--- Fixed: Index Seek (Covering) ---';
SELECT
	BusinessEntityID
,	FirstName
,	LastName
,	EmailPromotion
FROM Person.Person
WHERE MiddleName = 'J.';
 -- Logical Reads should be very low.
 GO
 
 -- Cleanup
 DROP INDEX IX_Person_MiddleName_Covering ON Person.Person;
 GO
