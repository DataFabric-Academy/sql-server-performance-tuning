-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

-- ============================================================
-- Script: 05_Quick_Wait_Analysis.sql
-- Module: Module 11 - Troubleshooting
-- Purpose: Quick Wait Statistics Analysis for Troubleshooting
-- Source: Adapted from SQLSkills / Paul Randal
-- ============================================================

-- Top Wait Types (filtered for meaningful waits)
WITH [Waits] AS (
	SELECT
		[wait_type]
	,	[wait_time_ms] / 1000.0 AS [WaitS]
	,	([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS]
	,	[signal_wait_time_ms] / 1000.0 AS [SignalS]
	,	[waiting_tasks_count] AS [WaitCount]
	,	100.0 * [wait_time_ms] / SUM([wait_time_ms]) OVER() AS [Percentage]
	FROM sys.dm_os_wait_stats
    WHERE [wait_type] NOT IN (
        -- Filter out benign waits
        N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP',
        N'CHECKPOINT_QUEUE', N'CHKPT', N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT',
        N'CLR_SEMAPHORE', N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE',
        N'DBMIRROR_WORKER_QUEUE', N'DBMIRRORING_CMD', N'DIRTY_PAGE_POLL',
        N'DISPATCHER_QUEUE_SEMAPHORE', N'EXECSYNC', N'FSAGENT',
        N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX', N'HADR_CLUSAPI_CALL',
        N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'HADR_LOGCAPTURE_WAIT',
        N'HADR_NOTIFICATION_DEQUEUE', N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
        N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP', N'LOGMGR_QUEUE',
        N'MEMORY_ALLOCATION_EXT', N'ONDEMAND_TASK_QUEUE',
        N'PARALLEL_REDO_DRAIN_WORKER', N'PARALLEL_REDO_LOG_CACHE',
        N'PARALLEL_REDO_TRAN_LIST', N'PARALLEL_REDO_WORKER_SYNC',
        N'PARALLEL_REDO_WORKER_WAIT_WORK', N'PREEMPTIVE_OS_FLUSHFILEBUFFERS',
        N'PREEMPTIVE_XE_GETTARGETSTATE', N'PWAIT_ALL_COMPONENTS_INITIALIZED',
        N'PWAIT_DIRECTLOGCONSUMER_GETNEXT', N'PWAIT_EXTENSIBILITY_CLEANUP_TASK',
        N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', N'QDS_ASYNC_QUEUE',
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', N'QDS_SHUTDOWN_QUEUE',
        N'REDO_THREAD_PENDING_WORK', N'REQUEST_FOR_DEADLOCK_SEARCH',
        N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH',
        N'SLEEP_DBSTARTUP', N'SLEEP_DCOMSTARTUP', N'SLEEP_MASTERDBREADY',
        N'SLEEP_MASTERMDREADY', N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP',
        N'SLEEP_SYSTEMTASK', N'SLEEP_TASK', N'SLEEP_TEMPDBSTARTUP',
        N'SNI_HTTP_ACCEPT', N'SP_SERVER_DIAGNOSTICS_SLEEP',
        N'SQLTRACE_BUFFER_FLUSH', N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        N'SQLTRACE_WAIT_ENTRIES', N'WAIT_FOR_RESULTS', N'WAITFOR',
        N'WAITFOR_TASKSHUTDOWN', N'WAIT_XTP_RECOVERY', N'WAIT_XTP_HOST_WAIT',
        N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', N'WAIT_XTP_CKPT_CLOSE',
        N'XE_DISPATCHER_JOIN', N'XE_DISPATCHER_WAIT', N'XE_TIMER_EVENT'
    )
    AND [waiting_tasks_count] > 0
)
SELECT TOP 10
	[wait_type] AS [Wait Type]
,	CAST([WaitS] AS DECIMAL(16, 2)) AS [Wait (sec)]
,	CAST([ResourceS] AS DECIMAL(16, 2)) AS [Resource Wait (sec)]
,	CAST([SignalS] AS DECIMAL(16, 2)) AS [Signal Wait (sec)]
,	[WaitCount] AS [Wait Count]
,	CAST([Percentage] AS DECIMAL(5, 2)) AS [Wait %]
,	CASE
		WHEN [wait_type] LIKE 'LCK%' THEN 'Blocking/Locking Issue'
		WHEN [wait_type] LIKE 'PAGEIOLATCH%' THEN 'I/O Issue (Memory/Disk)'
		WHEN [wait_type] LIKE 'PAGELATCH%' THEN 'TempDB Contention'
		WHEN [wait_type] = 'SOS_SCHEDULER_YIELD' THEN 'CPU Pressure'
		WHEN [wait_type] IN ('CXPACKET', 'CXCONSUMER') THEN 'Parallelism'
		WHEN [wait_type] = 'ASYNC_NETWORK_IO' THEN 'Network/Client Issue'
		WHEN [wait_type] = 'WRITELOG' THEN 'Log Write Latency'
		WHEN [wait_type] = 'RESOURCE_SEMAPHORE' THEN 'Memory Grant Issue'
		ELSE 'Investigate Further'
	END AS [Likely Cause]
FROM [Waits]
ORDER BY [Percentage] DESC;

-- Signal Waits Percentage (CPU Pressure Indicator)
SELECT
	SUM(signal_wait_time_ms) * 100.0 / NULLIF(SUM(wait_time_ms), 0) AS [Signal Wait %]
,	CASE
		WHEN SUM(signal_wait_time_ms) * 100.0 / NULLIF(SUM(wait_time_ms), 0) > 20
		THEN 'HIGH - Likely CPU Pressure'
		ELSE 'Normal'
	END AS [Status]
FROM sys.dm_os_wait_stats
WHERE wait_type NOT LIKE 'SLEEP%'
AND wait_time_ms > 0;
