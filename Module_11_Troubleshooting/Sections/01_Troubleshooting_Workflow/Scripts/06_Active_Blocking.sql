-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

-- ============================================================
-- Script: 06_Active_Blocking.sql
-- Module: Module 11 - Troubleshooting
-- Purpose: Identify Active Blocking Chains
-- Source: Compiled from Microsoft Learn & Community Best Practices
-- ============================================================

-- View currently blocked/blocking sessions
SELECT
	r.session_id AS [Blocked Session]
,	r.blocking_session_id AS [Blocking Session]
,	r.wait_type
,	r.wait_time / 1000.0 AS [Wait Time (sec)]
,	r.wait_resource
,	r.status
,	DB_NAME(r.database_id) AS [Database]
,	t.text AS [Blocked Query]
,	(SELECT text FROM sys.dm_exec_sql_text(
		(SELECT sql_handle FROM sys.dm_exec_requests WHERE session_id = r.blocking_session_id)
	)) AS [Blocking Query]
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id <> 0
ORDER BY r.wait_time DESC;

-- Head Blockers (sessions that are blocking others but not blocked themselves)
SELECT
	s.session_id
,	s.login_name
,	s.host_name
,	s.program_name
,	s.status
,	s.last_request_start_time
,	(SELECT COUNT(*) 
	 FROM sys.dm_exec_requests 
	 WHERE blocking_session_id = s.session_id) AS [Sessions Blocked]
,	t.text AS [Current Query]
FROM sys.dm_exec_sessions s
LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE s.session_id IN (
	SELECT DISTINCT blocking_session_id 
	FROM sys.dm_exec_requests 
	WHERE blocking_session_id <> 0
)
AND s.session_id NOT IN (
	SELECT session_id 
	FROM sys.dm_exec_requests 
	WHERE blocking_session_id <> 0
);

-- Detailed Lock Information
SELECT
	l.request_session_id AS [Session ID]
,	DB_NAME(l.resource_database_id) AS [Database]
,	l.resource_type
,	l.resource_description
,	l.request_mode
,	l.request_status
,	CASE l.request_status
		WHEN 'WAIT' THEN 'Waiting for Lock'
		WHEN 'GRANT' THEN 'Lock Granted'
		ELSE l.request_status
	END AS [Status Description]
FROM sys.dm_tran_locks l
WHERE l.request_session_id IN (
	SELECT session_id FROM sys.dm_exec_requests WHERE blocking_session_id <> 0
	UNION
	SELECT blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id <> 0
)
ORDER BY l.request_session_id, l.resource_type;
