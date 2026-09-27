/*
    LAB: Module 03 - Instant File Initialization & TempDB
    
    DEMO CONTEXT:
        In Demo 01 (Bad vs Good Structure), you saw how Page Splits fragment data.
        In this Lab, you will look at the *infrastructure* level: verifying IFI to speed up 
        file growth and configuring TempDB to prevent allocation contention (GAM/SGAM/PFS).

    OBJECTIVE:
        Verify if Instant File Initialization (IFI) is enabled and generate a best-practice 
        configuration script for TempDB based on CPU count.

    INSTRUCTIONS:
        1. Run PART 1 to check if IFI is enabled (critical for Restore/Growth performance).
        2. Run PART 2 to generate a T-SQL script for configuring TempDB.
        3. Review the generated script (in Messages tab) but DO NOT execute it blindly.
           It suggests adding multiple data files to reduce allocation contention (PFS/GAM/SGAM).

    PREREQUISITES:
        - SQL Server Service Account permissions
*/

-- Lab: Instant File Initialization & TempDB Configuration (Modernized)
-- Adapted from: Lab 03 (Database Structures)

USE [master];
GO

-- =============================================
-- PART 1: Check Instant File Initialization (IFI)
-- =============================================
-- Modern way (SQL 2014 SP2+ / SQL 2022+): sys.dm_server_services
SELECT
	servicename
,	service_account
,	instant_file_initialization_enabled
FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server (%)';

-- =============================================
-- PART 2: TempDB Best Practice Configuration
-- =============================================
-- Script to generate standard TempDB files based on CPU count
-- (Does NOT execute, only generates script for safety)

DECLARE @CpuCount INT;
SELECT @CpuCount = cpu_count FROM sys.dm_os_sys_info;

PRINT '-- Suggested TempDB Configuration for ' + CAST(@CpuCount AS VARCHAR(5)) + ' CPUs';
PRINT 'USE [master];';
PRINT 'ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N''tempdev'', SIZE = 128MB, FILEGROWTH = 64MB );'; -- Modify Primary

DECLARE @i INT = 2;
WHILE @i <= @CpuCount AND @i <= 8 -- Cap at 8 files usually
BEGIN
    PRINT 'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''temp' + CAST(@i AS VARCHAR(2)) + ''', FILENAME = N''<Current_Data_Path>\temp' + CAST(@i AS VARCHAR(2)) + '.ndf'', SIZE = 128MB, FILEGROWTH = 64MB );';
    SET @i = @i + 1;
END
GO
