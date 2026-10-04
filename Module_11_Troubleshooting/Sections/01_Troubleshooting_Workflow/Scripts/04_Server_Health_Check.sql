-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

-- ============================================================
-- Script: 04_Server_Health_Check.sql
-- Module: Module 11 - Troubleshooting
-- Purpose: Quick Server Health Check - First step in troubleshooting
-- Source: Compiled from Microsoft Learn & Best Practices
-- ============================================================

-- Step 1: Check CPU Usage
SELECT
	record_id
,	DATEADD(ms, -1 * (ts_now - [timestamp]), GETDATE()) AS [Event Time]
,	SQLProcessUtilization AS [SQL CPU %]
,	SystemIdle AS [Idle %]
,	100 - SystemIdle - SQLProcessUtilization AS [Other CPU %]
FROM (
	SELECT
		record.value('(./Record/@id)[1]', 'int') AS record_id
	,	record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS SystemIdle
	,	record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS SQLProcessUtilization
	,	timestamp
	,	ts_now
	FROM (
		SELECT
			timestamp
		,	CONVERT(xml, record) AS record
		,	cpu_ticks / (cpu_ticks/ms_ticks) AS ts_now
		FROM sys.dm_os_ring_buffers
		CROSS JOIN sys.dm_os_sys_info
		WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
		AND record LIKE '%<SystemHealth>%'
	) AS x
) AS y
ORDER BY record_id DESC;

-- Step 2: Check Memory Status
SELECT
	total_physical_memory_kb / 1024 AS [Total Physical Memory (MB)]
,	available_physical_memory_kb / 1024 AS [Available Memory (MB)]
,	system_memory_state_desc AS [Memory State]
FROM sys.dm_os_sys_memory;

-- Step 3: Check SQL Server Memory Configuration
SELECT
	name
,	value
,	value_in_use
,	description
FROM sys.configurations
WHERE name IN ('min server memory (MB)', 'max server memory (MB)');

-- Step 4: Check for Recent Errors
-- Note: sys.dm_exec_errorlog doesn't exist. Use xp_readerrorlog instead.
-- Create temp table to store error log results
IF OBJECT_ID('tempdb..#ErrorLog') IS NOT NULL DROP TABLE #ErrorLog;
CREATE TABLE #ErrorLog (
    LogDate DATETIME,
    ProcessInfo VARCHAR(50),
    [Text] VARCHAR(MAX)
);

-- Read error log (0 = current log, 1 = error log type)
INSERT INTO #ErrorLog (LogDate, ProcessInfo, [Text])
EXEC xp_readerrorlog 0, 1;

-- Filter for last 24 hours and show top 10
SELECT TOP 10
	LogDate
,	ProcessInfo
,	[Text]
FROM #ErrorLog
WHERE LogDate > DATEADD(HOUR, -24, GETDATE())
ORDER BY LogDate DESC;

DROP TABLE #ErrorLog;
