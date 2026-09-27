-- 02_Monitor_Queries.sql
-- Optimized Monitor: "Mini-WhoIsActive"
-- Purpose: See what is currently running on the server.

SELECT
	r.session_id
,	r.status
,	r.start_time
,	r.command
,	r.cpu_time AS [CPU (ms)]
,	r.total_elapsed_time AS [Duration (ms)]
,	r.reads AS [Reads]
,	r.writes AS [Writes]
,	r.logical_reads AS [Logical Reads]
,	r.wait_type
,	r.wait_time AS [Wait (ms)]
,	r.blocking_session_id AS [Blocker]
,	SUBSTRING(t.text, (r.statement_start_offset/2)+1, 
		((CASE r.statement_end_offset 
		  WHEN -1 THEN DATALENGTH(t.text)
		  ELSE r.statement_end_offset
		  END - r.statement_start_offset)/2) + 1) AS [Statement]
,	DB_NAME(r.database_id) AS [Database]
FROM sys.dm_exec_requests r
INNER JOIN sys.dm_exec_sessions es ON r.session_id = es.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id <> @@SPID AND es.is_user_process = 1 -- Filter user processes only
ORDER BY r.cpu_time DESC;
GO
