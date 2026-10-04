-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

-- 10_Missing_Indexes_Advantage.sql
-- Missing index recommendations for current database (ranked by Index Advantage)
-- Based on: SQL Server 2025 Diagnostic Information Queries (Glenn Berry), Query 72
--   https://glennsqlperformance.com/resources/
-- Used here with attribution for non-commercial training/demo purposes.

SELECT
    CONVERT(DECIMAL(18, 2), migs.user_seeks * migs.avg_total_user_cost * (migs.avg_user_impact * 0.01)) AS [Index Advantage]
,   CONVERT(NVARCHAR(25), migs.last_user_seek, 20) AS [Last User Seek]
,   mid.[statement] AS [Database.Schema.Table]
,   COUNT(1) OVER (PARTITION BY mid.[statement]) AS [Missing Indexes For Table]
,   COUNT(1) OVER (PARTITION BY mid.[statement], mid.equality_columns) AS [Similar Missing Indexes For Table]
,   mid.equality_columns
,   mid.inequality_columns
,   mid.included_columns
,   migs.user_seeks
,   CONVERT(DECIMAL(18, 2), migs.avg_total_user_cost) AS [Avg Total User Cost]
,   CONVERT(DECIMAL(18, 2), migs.avg_user_impact) AS [Avg User Impact]
,   REPLACE(REPLACE(LEFT(st.[text], 512), CHAR(10), N''), CHAR(13), N'') AS [Short Query Text]
,   OBJECT_NAME(mid.[object_id]) AS [Table Name]
FROM sys.dm_db_missing_index_groups AS mig WITH (NOLOCK)
INNER JOIN sys.dm_db_missing_index_group_stats_query AS migs WITH (NOLOCK)
    ON mig.index_group_handle = migs.group_handle
CROSS APPLY sys.dm_exec_sql_text(migs.last_sql_handle) AS st
INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK)
    ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY
    [Index Advantage] DESC
OPTION (RECOMPILE);

-- Notes:
-- - Do NOT blindly create every index shown here.
-- - Use [Index Advantage], [Last User Seek], and [Short Query Text] to prioritize.
-- - Always review workload, existing indexes, and maintenance overhead before creating new indexes.
