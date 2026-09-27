-- 04_Index_Analysis_QueryStore.sql
-- Source: Adpated from phakkhaphong/SQL-Server-Performance
-- Purpose: Find Missing Indexes using Query Store data (more reliable than DMV alone).

SELECT TOP 20
	q.query_id
,	q.object_id
,	ISNULL(OBJECT_NAME(q.object_id), 'Ad-Hoc') AS [Object Name]
,	qt.query_sql_text
,	rs.count_executions
,	rs.avg_duration / 1000.0 AS [Avg Duration (ms)]
,	rs.avg_logical_io_reads
,	p.query_plan
FROM sys.query_store_query AS q
JOIN sys.query_store_plan AS p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats AS rs ON p.plan_id = rs.plan_id
JOIN sys.query_store_query_text AS qt ON q.query_text_id = qt.query_text_id
WHERE p.query_plan LIKE '%MissingIndex%'
	AND rs.last_execution_time > DATEADD(DAY, -7, GETDATE()) -- Last 7 days
ORDER BY rs.avg_logical_io_reads DESC;

-- Note: Click on the [query_plan] XML to see the specific Missing Index Hint.
