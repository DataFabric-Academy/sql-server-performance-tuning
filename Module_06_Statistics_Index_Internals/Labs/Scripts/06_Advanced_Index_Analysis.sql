/*
    LAB: Module 06 - Advanced Index Analysis & Maintenance
    
    DEMO CONTEXT:
        In Demo 01 (Missing Index) and Demo 03 (Stale Stats), you saw individual problems.
        This Lab combines these concepts to perform a holistic "Index Health Check":
        analyzing Cardinality (Histograms) and cleaning up tech debt (Unused Indexes).

    OBJECTIVE:
        Analyze Index Statistics (Histogram) to understand Cardinality Estimation 
        and identify Unused Indexes for cleanup.

    INSTRUCTIONS:
        1. Run PART 1.1 to list all statistics on 'Person.Person'.
        2. Run PART 1.2 to view the DBCC SHOW_STATISTICS output.
           - Observation: Look at the 'Histogram' to see data distribution.
        3. Run PART 2.1 to find "Missing Indexes" that SQL Server suggests.
        4. Run PART 2.2 to find "Unused Indexes" (Seeks=0, Scans=0) that are wasting space/resources.

    PREREQUISITES:
        - AdventureWorks2025 or newer
*/

-- Lab: Legacy Migration - Indexing & Statistics Analysis
-- Adapted from: Lab 06 (Indexing & Statistics)
-- Target: AdventureWorks2025

USE [AdventureWorks2025]; -- Or AdventureWorks2025
GO

-- =================================================================
-- PART 1: STATISTICS ANALYSIS
-- =================================================================

-- 1.1 List Statistics for a Table
SELECT
	OBJECT_NAME(s.object_id) AS TableName
,	s.name AS StatsName
,	STATS_DATE(s.object_id, s.stats_id) AS LastUpdated
,	s.auto_created
FROM sys.stats s
WHERE s.object_id = OBJECT_ID('Person.Person');

-- 1.2 View Histogram (Deep Dive)
-- à¸”à¸¹à¸à¸²à¸£à¸à¸£à¸°à¸ˆà¸²à¸¢à¸•à¸±à¸§à¸‚à¸­à¸‡à¸‚à¹‰à¸­à¸¡à¸¹à¸¥à¹ƒà¸™ Column 'LastName'
DBCC SHOW_STATISTICS ('Person.Person', 'IX_Person_LastName_FirstName_MiddleName');

-- =================================================================
-- PART 2: INDEXING ANALYSIS
-- =================================================================

-- 2.1 View Missing Indexes (Cached Plans)
-- à¸•à¸£à¸§à¸ˆà¸ªà¸­à¸šà¸§à¹ˆà¸²à¸¡à¸µ Query à¹„à¸«à¸™à¸šà¹ˆà¸™à¸§à¹ˆà¸²à¸‚à¸²à¸” Index à¸šà¹‰à¸²à¸‡
SELECT
	migs.group_handle
,	mid.statement AS TableName
,	mid.equality_columns
,	mid.inequality_columns
,	mid.included_columns
,	migs.avg_user_impact -- % Performance Improvement
,	migs.user_seeks
FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
ORDER BY migs.avg_user_impact DESC;

-- 2.2 Index Usage Stats (Cleaning up unused indexes)
-- Index à¹„à¸«à¸™à¸ªà¸£à¹‰à¸²à¸‡à¹„à¸§à¹‰à¹à¸¥à¹‰à¸§à¹„à¸¡à¹ˆà¹„à¸”à¹‰à¹ƒà¸Šà¹‰ (User Seeks = 0, User Scans = 0)
SELECT
	OBJECT_NAME(i.object_id) AS TableName
,	i.name AS IndexName
,	s.user_seeks
,	s.user_scans
,	s.user_lookups
,	s.user_updates -- Cost of maintenance
FROM sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE OBJECTPROPERTY(s.object_id,'IsUserTable') = 1
	AND s.database_id = DB_ID()
ORDER BY s.user_updates DESC;

PRINT 'Analysis Complete.';

