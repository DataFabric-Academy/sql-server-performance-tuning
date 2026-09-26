/*
    Lab: Monitoring and Fixing Performance Regressions with Query Store
    Based on MS Learn: Monitoring Performance By Using the Query Store

    Requirements: SQL Server 2016+ or Azure SQL Database
    Database: AdventureWorks (Any version)
*/

USE [AdventureWorks2025];
GO

-- 1. Setup Environment: Ensure Query Store is ON and Clear
ALTER DATABASE [AdventureWorks2025] SET QUERY_STORE = ON;
ALTER DATABASE [AdventureWorks2025] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, INTERVAL_LENGTH_MINUTES = 10);
ALTER DATABASE [AdventureWorks2025] SET QUERY_STORE CLEAR; -- Start fresh for lab
GO

-- 2. Create Helper Procedure to generate regressions
CREATE OR ALTER PROCEDURE dbo.usp_GetTransactionHistory
    @ProductID INT
AS
BEGIN
    SELECT * 
    FROM Production.TransactionHistory
    WHERE ProductID = @ProductID;
END;
GO

-- 3. Simulate "Good Plan" (Scenario: Index Seek)
-- We force a seek by creating an optimal index first (if not exists)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_TransactionHistory_ProductID' AND object_id = OBJECT_ID('Production.TransactionHistory'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_TransactionHistory_ProductID]
    ON [Production].[TransactionHistory] ([ProductID]);
END
GO

-- Run the query 20 times to generate history
EXEC dbo.usp_GetTransactionHistory @ProductID = 712; -- Common product
GO 20

-- 4. Simulate "Regression" (Scenario: Force Scan via Schema Change or Index Drop)
-- Let's pretend someone dropped the critical index!
DROP INDEX [IX_TransactionHistory_ProductID] ON [Production].[TransactionHistory];
GO

-- Clean cache to ensure new plan is compiled
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- Run the query again 20 times (Now it will likely scan)
EXEC dbo.usp_GetTransactionHistory @ProductID = 712;
GO 20

/*
    ============================================================
    LAB EXERCISE INSTRUCTIONS (SSMS)
    ============================================================

    1. Open Object Explorer > Management > Query Store.
    2. Open "Top Resource Consuming Queries".
       - Find the query for usp_GetTransactionHistory.
       - You should see 2 Plans: 
         - Plan A (Index Seek) -> Short duration
         - Plan B (Clustered Index Scan) -> Longer duration

    3. Open "Regressed Queries".
       - This report specifically highlights queries that got worse.
       - You will see our query listed here because Duration increased.

    4. Fix the Regression (Plan Forcing - *Simulated*).
       - Note: In this specific lab, we dropped the index, so you CANNOT force the Seek plan (it's invalid).
       - But in a real scenario (e.g., Parameter Sniffing or Stat change), both plans would be valid.
       
    5. *Alternative Fix*: Recreate the index and observe.
*/
CREATE NONCLUSTERED INDEX [IX_TransactionHistory_ProductID]
ON [Production].[TransactionHistory] ([ProductID]);
GO
