-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

-- 06_Top_CPU_Queries.sql
-- Top worker time queries for entire instance (CPU-intensive)
-- Based on: SQL Server 2025 Diagnostic Information Queries (Glenn Berry), Query 48
--   https://glennsqlperformance.com/resources/
-- Used here with attribution for non-commercial training/demo purposes.

SELECT TOP (50)
    DB_NAME(t.[dbid]) AS [Database Name]
,   REPLACE(REPLACE(LEFT(t.[text], 255), CHAR(10), N''), CHAR(13), N'') AS [Short Query Text]
,   qs.total_worker_time AS [Total Worker Time]
,   qs.min_worker_time AS [Min Worker Time]
,   qs.total_worker_time / NULLIF(qs.execution_count, 0) AS [Avg Worker Time]
,   qs.max_worker_time AS [Max Worker Time]
,   qs.min_elapsed_time AS [Min Elapsed Time]
,   qs.total_elapsed_time / NULLIF(qs.execution_count, 0) AS [Avg Elapsed Time]
,   qs.max_elapsed_time AS [Max Elapsed Time]
,   qs.min_logical_reads AS [Min Logical Reads]
,   qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS [Avg Logical Reads]
,   qs.max_logical_reads AS [Max Logical Reads]
,   qs.execution_count AS [Execution Count]
,   CASE
        WHEN CONVERT(NVARCHAR(MAX), qp.query_plan) COLLATE Latin1_General_BIN2
             LIKE N'%<MissingIndexes>%' THEN 1
        ELSE 0
     END AS [Has Missing Index]
,   qs.creation_time AS [Creation Time]
-- , t.[text] AS [Query Text], qp.query_plan AS [Query Plan] -- Uncomment for full text/plan
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) AS t
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
ORDER BY
    qs.total_worker_time DESC
OPTION (RECOMPILE);
