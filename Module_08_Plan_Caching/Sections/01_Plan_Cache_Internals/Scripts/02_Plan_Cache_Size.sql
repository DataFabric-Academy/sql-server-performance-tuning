-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

-- 02_Plan_Cache_Size.sql
-- Check Plan Cache Size and Counts
-- Source: SQLSkills

SELECT
	objtype AS [Cache Type]
,	COUNT_BIG(*) AS [Total Plans]
,	SUM(CAST(size_in_bytes AS DECIMAL(18, 2))) / 1024 / 1024 AS [Total Size (MB)]
,	AVG(usecounts) AS [Avg Use Count]
,	SUM(CAST((CASE WHEN usecounts = 1 THEN size_in_bytes ELSE 0 END) AS DECIMAL(18, 2))) / 1024 / 1024 AS [Single-Use Size (MB)]
,	SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS [Single-Use Plans]
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY [Total Size (MB)] DESC;
