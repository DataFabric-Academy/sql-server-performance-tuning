-- 03_Analyze_Blocking.sql
-- Purpose: Identify the "Head Blocker" in a blocking chain.
-- Source: Adapted from Microsoft Tiger Team & Standard DMVs.

SELECT
	Blocker.session_id AS [Blocker SID]
,	BlockerText.text AS [Blocker Query]
,	Victim.session_id AS [Victim SID]
,	Victim.wait_type AS [Wait Type]
,	Victim.wait_time AS [Wait Time (ms)]
,	VictimText.text AS [Victim Query]
FROM sys.dm_exec_requests AS Victim
JOIN sys.dm_exec_connections AS Blocker 
	ON Victim.blocking_session_id = Blocker.session_id
CROSS APPLY sys.dm_exec_sql_text(Blocker.most_recent_sql_handle) AS BlockerText
CROSS APPLY sys.dm_exec_sql_text(Victim.sql_handle) AS VictimText
WHERE Victim.blocking_session_id > 0
ORDER BY Victim.wait_time DESC;

-- Tip: The session with 'blocking_session_id = 0' but appears in the [Blocker SID] column is your Head Blocker.
