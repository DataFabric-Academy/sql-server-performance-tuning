-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

﻿/*
    LAB: Module 08 - Parameter Sniffing & Plan Forcing
    
    DEMO CONTEXT:
        In Demo 01 (Param Sniffing), you saw the concept.
        In this Lab, you are the Victim. A "Golden Query" suddenly slows down because of a 
        small parameter change. You must find the cached plan and "Fix" it using 
        OPTIMIZE FOR or Query Store.

    OBJECTIVE:
        Diagnose and Resolve a Parameter Sniffing issue affecting a stored procedure.
*/

-- Lab: Parameter Sniffing Simulation
-- à¸§à¸±à¸•à¸–à¸¸à¸›à¸£à¸°à¸ªà¸‡à¸„à¹Œ: à¸ˆà¸³à¸¥à¸­à¸‡à¸›à¸±à¸à¸«à¸² Parameter Sniffing à¹à¸¥à¸°à¸à¸²à¸£à¹à¸à¹‰à¹„à¸‚

USE [AdventureWorks2025];
GO

-- 1. Setup Skewed Data (à¸‚à¹‰à¸­à¸¡à¸¹à¸¥à¹„à¸¡à¹ˆà¸ªà¸¡à¸”à¸¸à¸¥)
IF OBJECT_ID('dbo.SniffLab') IS NOT NULL DROP TABLE dbo.SniffLab;
CREATE TABLE dbo.SniffLab (ID INT IDENTITY, CountryCode CHAR(2));

-- à¹ƒà¸ªà¹ˆà¸‚à¹‰à¸­à¸¡à¸¹à¸¥ 'TH' 1 à¹à¸–à¸§, 'US' 10,000 à¹à¸–à¸§
INSERT INTO dbo.SniffLab VALUES ('TH');
INSERT INTO dbo.SniffLab SELECT TOP(10000) 'US' FROM master.dbo.spt_values t1 CROSS JOIN master.dbo.spt_values t2;

CREATE INDEX IX_Country ON dbo.SniffLab(CountryCode);
GO

-- 2. Create Stored Procedure
CREATE OR ALTER PROC dbo.GetCustomerByCountry
    @CountryCode CHAR(2)
AS
BEGIN
	SELECT
		*
	FROM dbo.SniffLab
	WHERE CountryCode = @CountryCode;
END
GO

-- 3. Simulate Sniffing
-- à¸¥à¹‰à¸²à¸‡ Cache à¸à¹ˆà¸­à¸™à¹€à¸žà¸·à¹ˆà¸­à¸„à¸§à¸²à¸¡à¸Šà¸±à¸§à¸£à¹Œ (à¸­à¸¢à¹ˆà¸²à¸—à¸³à¹ƒà¸™ Production!)
DBCC FREEPROCCACHE;

-- Scenario A: Sniff 'TH' (Small Data) -> à¹„à¸”à¹‰ Plan Seek (à¸”à¸µà¸ªà¸³à¸«à¸£à¸±à¸š TH)
EXEC dbo.GetCustomerByCountry 'TH'; 

-- Scenario B: Run 'US' (Large Data) -> à¸¢à¸±à¸‡à¸„à¸‡à¹ƒà¸Šà¹‰ Plan Seek à¸‚à¸­à¸‡ TH (à¸‹à¸¶à¹ˆà¸‡à¹à¸¢à¹ˆà¸ªà¸³à¸«à¸£à¸±à¸š US à¹€à¸žà¸£à¸²à¸°à¸•à¹‰à¸­à¸‡ Lookup 10,000 à¸„à¸£à¸±à¹‰à¸‡!)
EXEC dbo.GetCustomerByCountry 'US'; 

-- *Task*: à¹€à¸Šà¹‡à¸„ Logical Reads à¸‚à¸­à¸‡ 'US' à¸ˆà¸°à¸ªà¸¹à¸‡à¸œà¸´à¸”à¸›à¸à¸•à¸´

-- 4. Solution: Recompile
EXEC dbo.GetCustomerByCountry 'US' WITH RECOMPILE;
-- *Result*: à¹„à¸”à¹‰ Plan Scan à¸—à¸µà¹ˆà¹€à¸«à¸¡à¸²à¸°à¸ªà¸¡à¸à¸±à¸š 'US'

-- à¸«à¸£à¸·à¸­à¹à¸à¹‰à¸—à¸µà¹ˆ Store Proc à¹‚à¸”à¸¢à¹ƒà¸ªà¹ˆ OPTION (RECOMPILE) à¸«à¸£à¸·à¸­ OPTIMIZE FOR UNKNOWN

