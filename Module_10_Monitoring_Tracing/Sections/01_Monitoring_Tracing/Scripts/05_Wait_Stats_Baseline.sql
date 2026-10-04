-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

/*
    SCRIPT: 05_Wait_Stats_Baseline.sql
    [CRITICAL]: EXECUTE IN MASTER (Server Scope DMV)
*/
USE [master];
GO

-- Capture Wait Stats Baseline
-- Based on Paul Randal (SQLSkills) and Glenn Berry (Dr. DMV) methodologies.
-- Valid for SQL Server 2016 through 2022+
-- Purpose: Captures Wait Stats "Delta" over a specific period, filtering out benign (ignorable) waits.

SET NOCOUNT ON;

-- 1. Parameters
DECLARE @Duration CHAR(8) = '00:00:30'; -- Duration to capture (HH:MM:SS)

PRINT 'Capturing Wait Stats Baseline... Duration: ' + @Duration;

IF OBJECT_ID('tempdb..#WaitStats_Start') IS NOT NULL DROP TABLE #WaitStats_Start;
IF OBJECT_ID('tempdb..#WaitStats_End') IS NOT NULL DROP TABLE #WaitStats_End;

-- 2. List of Benign Waits (Ignorable)
-- Source: Paul Randal (SQLskills) / Glenn Berry 
-- Updated: 2025 Standard
IF OBJECT_ID('tempdb..#IgnorableWaits') IS NOT NULL DROP TABLE #IgnorableWaits;
CREATE TABLE #IgnorableWaits (wait_type NVARCHAR(256) PRIMARY KEY);

INSERT INTO #IgnorableWaits (wait_type)
VALUES
    ('BROKER_EVENTHANDLER'), ('BROKER_RECEIVE_WAITFOR'), ('BROKER_TASK_STOP'), ('BROKER_TO_FLUSH'), ('BROKER_TRANSMITTER'),
    ('checkpoint_queue'), ('chkpt'), ('clr_auto_event'), ('clr_manual_event'), ('clr_semaphore'),
    ('DBMIRROR_DBM_EVENT'), ('DBMIRROR_EVENTS_QUEUE'), ('DBMIRROR_WORKER_QUEUE'), ('DBMIRRORING_CMD'),
    ('DIRTY_PAGE_POLL'), ('DISPATCHER_QUEUE_SEMAPHORE'), ('EXECSYNC'), ('FSAGENT'), ('FT_IFTS_SCHEDULER_IDLE_WAIT'),
    ('FT_IFTSHC_MUTEX'), ('HADR_CLUSAPI_CALL'), ('HADR_FILESTREAM_IOMGR_IOCOMPLETION'), ('HADR_LOGCAPTURE_WAIT'),
    ('HADR_NOTIFICATION_DEQUEUE'), ('HADR_TIMER_TASK'), ('HADR_WORK_QUEUE'), ('KSOURCE_WAKEUP'), ('LAZYWRITER_SLEEP'),
    ('LOGMGR_QUEUE'), ('MEMORY_ALLOCATION_EXT'), ('ONDEMAND_TASK_QUEUE'), ('PARALLEL_REDO_DRAIN_WORKER'),
    ('PARALLEL_REDO_LOG_CACHE'), ('PARALLEL_REDO_TRAN_TURN'), ('PARALLEL_REDO_WORKER_SYNC'),
    ('PARALLEL_REDO_WORKER_WAIT_WORK'), ('PREEMPTIVE_OS_FLUSHFILEBUFFERS'), ('PREEMPTIVE_XE_GETTARGETSTATE'),
    ('PWAIT_ALL_COMPONENTS_INITIALIZED'), ('PWAIT_DIRECTLOGCONSUMER_GETNEXT'), ('QDS_PERSIST_TASK_MAIN_LOOP_SLEEP'),
    ('QDS_ASYNC_QUEUE'), ('QDS_CLEANUP_STALE_LOGGING_TASK_MAIN_LOOP_SLEEP'), ('QDS_SHUTDOWN_QUEUE'),
    ('REDO_THREAD_PENDING_WORK'), ('REQUEST_FOR_DEADLOCK_SEARCH'), ('RESOURCE_QUEUE'), ('SERVER_IDLE_CHECK'),
    ('SLEEP_BPOOL_FLUSH'), ('SLEEP_DBSTARTUP'), ('SLEEP_DCOMSTARTUP'), ('SLEEP_MASTERDBREADY'), ('SLEEP_MASTERMDREADY'),
    ('SLEEP_masterMDREADY'), ('SLEEP_MSDBSTARTUP'), ('SLEEP_SYSTEMTASK'), ('SLEEP_TASK'), ('SLEEP_TEMPDBSTARTUP'),
    ('SNI_HF_SLEEP'), ('SNI_HTTP_ACCEPT'), ('SOS_WORK_DISPATCHER'), ('SP_SERVER_DIAGNOSTICS_SLEEP'),
    ('SQLTRACE_BUFFER_FLUSH'), ('SQLTRACE_INCREMENTAL_FLUSH_SLEEP'), ('SQLTRACE_WAIT_ENTRIES'),
    ('VDI_CLIENT_OTHER'), ('WAIT_FOR_RESULTS'), ('WAITFOR'), ('WAITFOR_TASKSHUTDOWN'), ('WAIT_XTP_RECOVERY'),
    ('WAIT_XTP_HOST_WAIT'), ('WAIT_XTP_OFFLINE_CKPT_NEW_LOG'), ('WAIT_XTP_CKPT_CLOSE'), ('XE_DISPATCHER_JOIN'),
    ('XE_DISPATCHER_WAIT'), ('XE_TIMER_EVENT');

-- 3. Capture Start Snapshot (Filtering Benign)
SELECT wait_type, waiting_tasks_count, wait_time_ms, max_wait_time_ms, signal_wait_time_ms
INTO #WaitStats_Start
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (SELECT wait_type FROM #IgnorableWaits);

-- 4. Wait
WAITFOR DELAY @Duration;

-- 5. Capture End Snapshot
SELECT wait_type, waiting_tasks_count, wait_time_ms, max_wait_time_ms, signal_wait_time_ms
INTO #WaitStats_End
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (SELECT wait_type FROM #IgnorableWaits);

-- 6. Calculate Delta
SELECT TOP 10
	E.wait_type AS [Wait Type]
,	(E.waiting_tasks_count - S.waiting_tasks_count) AS [Wait Count]
,	CAST((E.wait_time_ms - S.wait_time_ms) / 1000.0 AS DECIMAL(10, 2)) AS [Total Wait (s)]
,	CAST(((E.wait_time_ms - S.wait_time_ms) - (E.signal_wait_time_ms - S.signal_wait_time_ms)) / 1000.0 AS DECIMAL(10, 2)) AS [Resource Wait (s)]
,	CAST((E.signal_wait_time_ms - S.signal_wait_time_ms) / 1000.0 AS DECIMAL(10, 2)) AS [Signal Wait (s)]
,	CASE WHEN (E.waiting_tasks_count - S.waiting_tasks_count) > 0
		 THEN CAST((E.wait_time_ms - S.wait_time_ms) / (E.waiting_tasks_count - S.waiting_tasks_count) AS DECIMAL(10, 1))
		 ELSE 0 END AS [Avg Wait (ms)]
,	CASE WHEN (E.wait_time_ms - S.wait_time_ms) > 0
		 THEN CAST((100.0 * (E.signal_wait_time_ms - S.signal_wait_time_ms) / (E.wait_time_ms - S.wait_time_ms)) AS DECIMAL(5, 1))
		 ELSE 0 END AS [% Signal (CPU)]
FROM #WaitStats_End AS E
JOIN #WaitStats_Start AS S ON E.wait_type = S.wait_type
WHERE (E.wait_time_ms - S.wait_time_ms) > 0 -- Only show active waits
ORDER BY [Total Wait (s)] DESC;

-- Cleanup
DROP TABLE #WaitStats_Start;
DROP TABLE #WaitStats_End;
DROP TABLE #IgnorableWaits;
GO
