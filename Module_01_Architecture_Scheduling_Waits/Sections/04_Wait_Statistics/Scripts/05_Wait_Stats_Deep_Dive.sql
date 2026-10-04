-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

﻿/*
    LAB: Module 01 - Wait Statistics Deep Dive
    
    DEMO CONTEXT:
        In Demo 02 (Wait Stats Analysis), you learned how to query sys.dm_os_wait_stats.
        This Lab takes it further by creating *specific* wait types (WAITFOR) and tracing them 
        in real-time using sys.dm_os_waiting_tasks (The "Why am I waiting?" DMV).

    OBJECTIVE:
        Understand how to identify performance bottlenecks using Wait Statistics (sys.dm_os_wait_stats)
        and Real-time Waiting Tasks (sys.dm_os_waiting_tasks).

    INSTRUCTIONS:
        1. Run TASK 1 to clear any existing wait statistics (Baseline).
        2. Run TASK 2 to simulate an artificial delay (Wait Type: WAITFOR).
        3. Run TASK 3 to verify that the 'WAITFOR' wait type was captured in the aggregate stats.
        4. Run TASK 4 in a separate window while running a long query to see real-time blocking/waiting.

    PREREQUISITES:
        - AdventureWorks2025 or newer
*/

-- Lab: Analyzing Wait Statistics (Modernized)
-- Adapted from: Lab 01 (Architecture)

USE [AdventureWorks2025];
GO

-- =============================================
-- TASK 1: Clear Wait Stats (Baseline)
-- =============================================
DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);
PRINT 'Wait statistics cleared.';
GO

-- =============================================
-- TASK 2: Simulate a Wait (Simulating Delay)
-- =============================================
PRINT 'Starting a 5-second delay to generate waits...';
WAITFOR DELAY '00:00:05'; -- Generates WAITFOR wait type
GO

-- =============================================
-- TASK 3: Analyze Aggregated Waits (dm_os_wait_stats)
-- =============================================
SELECT TOP 10
	wait_type
,	waiting_tasks_count
,	wait_time_ms / 1000.0 AS wait_time_sec
,	(wait_time_ms - signal_wait_time_ms) / 1000.0 AS resource_wait_sec
,	signal_wait_time_ms / 1000.0 AS signal_wait_sec
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > 0
  AND wait_type NOT IN ('WAITFOR') -- Exclude our simulation for clarity (or keep to see it)
ORDER BY wait_time_ms DESC;

-- =============================================
-- TASK 4: Real-time Waiting Tasks (dm_os_waiting_tasks)
-- =============================================
-- Open another window and run a long query to see this in action
SELECT
	wt.session_id
,	wt.wait_duration_ms
,	wt.wait_type
,	wt.blocking_session_id
,	wt.resource_description
,	es.program_name
,	st.text AS query_text
FROM sys.dm_os_waiting_tasks AS wt
INNER JOIN sys.dm_exec_sessions AS es ON wt.session_id = es.session_id
LEFT JOIN sys.dm_exec_requests AS er ON wt.session_id = er.session_id
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) AS st
WHERE es.is_user_process = 1;
GO

