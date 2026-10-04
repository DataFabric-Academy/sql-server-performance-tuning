-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

-- ============================================================
-- Script: 07_Top_Resource_Queries.sql
-- Module: Module 11 - Troubleshooting
-- Purpose: Find Top N Queries by various resource consumption
-- Source: Glenn Berry / Microsoft Learn
-- ============================================================

USE master;
GO

-- ============================================================
-- TOP 10 QUERIES BY CPU TIME
-- ============================================================


SELECT TOP 10
	qs.total_worker_time / 1000 AS [Total CPU Time (ms)]
,	qs.execution_count AS [Execution Count]
,	qs.total_worker_time / qs.execution_count / 1000 AS [Avg CPU Time (ms)]
,	qs.total_elapsed_time / 1000 AS [Total Duration (ms)]
,	qs.total_logical_reads AS [Total Logical Reads]
,	qs.total_physical_reads AS [Total Physical Reads]
,	SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
		((CASE qs.statement_end_offset
			WHEN -1 THEN DATALENGTH(st.text)
			ELSE qs.statement_end_offset
		END - qs.statement_start_offset)/2)+1) AS [Query Text]
,	DB_NAME(st.dbid) AS [Database]
,	qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY qs.total_worker_time DESC;

-- ============================================================
-- TOP 10 QUERIES BY LOGICAL READS (I/O)
-- ============================================================

SELECT TOP 10
	qs.total_logical_reads AS [Total Logical Reads]
,	qs.execution_count AS [Execution Count]
,	qs.total_logical_reads / qs.execution_count AS [Avg Logical Reads]
,	qs.total_worker_time / 1000 AS [Total CPU (ms)]
,	qs.total_elapsed_time / 1000 AS [Total Duration (ms)]
,	SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
		((CASE qs.statement_end_offset
			WHEN -1 THEN DATALENGTH(st.text)
			ELSE qs.statement_end_offset
		END - qs.statement_start_offset)/2)+1) AS [Query Text]
,	DB_NAME(st.dbid) AS [Database]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.total_logical_reads DESC;

-- ============================================================
-- TOP 10 QUERIES BY EXECUTION COUNT
-- ============================================================

SELECT TOP 10
	qs.execution_count AS [Execution Count]
,	qs.total_worker_time / 1000 AS [Total CPU (ms)]
,	qs.total_logical_reads AS [Total Logical Reads]
,	qs.total_elapsed_time / 1000 AS [Total Duration (ms)]
,	SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
		((CASE qs.statement_end_offset
			WHEN -1 THEN DATALENGTH(st.text)
			ELSE qs.statement_end_offset
		END - qs.statement_start_offset)/2)+1) AS [Query Text]
,	DB_NAME(st.dbid) AS [Database]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.execution_count DESC;

-- ============================================================
-- TOP 10 QUERIES BY AVERAGE DURATION (Slow Queries)
-- ============================================================

SELECT TOP 10
	qs.total_elapsed_time / qs.execution_count / 1000 AS [Avg Duration (ms)]
,	qs.execution_count AS [Execution Count]
,	qs.total_elapsed_time / 1000 AS [Total Duration (ms)]
,	qs.total_worker_time / 1000 AS [Total CPU (ms)]
,	qs.total_logical_reads AS [Total Logical Reads]
,	SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
		((CASE qs.statement_end_offset
			WHEN -1 THEN DATALENGTH(st.text)
			ELSE qs.statement_end_offset
		END - qs.statement_start_offset)/2)+1) AS [Query Text]
,	DB_NAME(st.dbid) AS [Database]
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE qs.execution_count > 1  -- Filter out single-run queries
ORDER BY (qs.total_elapsed_time / qs.execution_count) DESC;

-- ============================================================
-- STORED PROCEDURES: TOP BY CPU
-- ============================================================

SELECT TOP 10
	DB_NAME(ps.database_id) AS [Database]
,	OBJECT_NAME(ps.object_id, ps.database_id) AS [Procedure Name]
,	ps.execution_count AS [Execution Count]
,	ps.total_worker_time / 1000 AS [Total CPU (ms)]
,	ps.total_worker_time / ps.execution_count / 1000 AS [Avg CPU (ms)]
,	ps.total_logical_reads AS [Total Logical Reads]
,	ps.total_elapsed_time / 1000 AS [Total Duration (ms)]
,	ps.cached_time AS [Cached Time]
,	ps.last_execution_time AS [Last Execution]
FROM sys.dm_exec_procedure_stats ps
ORDER BY ps.total_worker_time DESC;
