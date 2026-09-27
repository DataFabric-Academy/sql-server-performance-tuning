/*
    LAB: Module 10 - Daily Health Check & Baseline
    
    DEMO CONTEXT:
        In Demo 02 (Monitor Queries), you watched the "Now".
        In this Lab, you build a "Daily Routine" script to check the "History" (CPU) and 
        "Overall Health" (PLE, Latency), replacing external tools like PerfMon for 
        quick situational awareness.

    OBJECTIVE:
        Perform a comprehensive "Daily Health Check" using T-SQL and DMVs, 
        replacing the need for external PerfMon counters for quick diagnosis.

    INSTRUCTIONS:
        1. Run SECTION 1 to check CPU History (last 10-20 minutes).
           - Look for 'SQL Process' vs 'Other Process' spikes.
        2. Run SECTION 2 to check Memory Health.
           - Key Metric: Page Life Expectancy (PLE) > 300s (or higher on big RAM).
        3. Run SECTION 3 to check I/O Latency/Stall.
           - Warning: Average Write Latency > 20ms usually indicates disk bottlenecks.
        4. Run SECTION 4 to check Top Cumulative Waits.
           - Identifies what the server has been waiting for the most since restart.

    PREREQUISITES:
        - VIEW SERVER STATE permission
*/

-- Lab: Daily Health Check & Baseline (Modernized)
-- Adapted from: Lab 10 (Monitoring)
-- Objective: Quick Health Check using Standard DMVs (Replacements for PerfMon)

USE [master];
GO

-- =============================================
-- 1. CPU USAGE (System vs SQL)
-- =============================================
SELECT TOP(10)
	record_id
,	[SQLProcessUtilization] AS [SQL_CPU_Percent]
,	[SystemIdle] AS [System_Idle_Percent]
,	100 - [SystemIdle] - [SQLProcessUtilization] AS [Other_Process_CPU]
,	DATEADD(ms, -1 * (ts_now - [timestamp]), GETDATE()) AS [Event_Time]
FROM (
	SELECT
		record.value('(./Record/@id)[1]', 'int') AS record_id
	,	record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS [SystemIdle]
	,	record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS [SQLProcessUtilization]
	,	[timestamp]
	,	cpu_ticks / (cpu_ticks/ms_ticks) AS [ts_now]
	FROM (
		SELECT
			[timestamp]
		,	CONVERT(xml, record) AS [record]
		,	cpu_ticks
		,	ms_ticks
		FROM sys.dm_os_ring_buffers
		WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
		AND record LIKE N'%<SystemHealth>%'
	) AS x
) AS y
ORDER BY record_id DESC;

-- =============================================
-- 2. MEMORY USAGE (PLE & Buffer Pool)
-- =============================================
SELECT
	object_name
,	counter_name
,	cntr_value
FROM sys.dm_os_performance_counters
WHERE counter_name IN ('Page life expectancy', 'Free Memory (KB)', 'Target Server Memory (KB)', 'Total Server Memory (KB)')
	AND (object_name LIKE '%Buffer Manager%' OR object_name LIKE '%Memory Manager%');

-- =============================================
-- 3. I/O LATENCY (Stall)
-- =============================================
SELECT TOP 10
	DB_NAME(database_id) AS [Database]
,	[file_id]
,	io_stall_read_ms / NULLIF(num_of_reads, 0) AS [Avg_Read_Latency_ms]
,	io_stall_write_ms / NULLIF(num_of_writes, 0) AS [Avg_Write_Latency_ms]
FROM sys.dm_io_virtual_file_stats(NULL, NULL)
ORDER BY (io_stall_read_ms + io_stall_write_ms) DESC;

-- =============================================
-- 4. WAITS (Top 5 Cumulative)
-- =============================================
SELECT TOP 5
	wait_type
,	wait_time_ms / 1000.0 AS [Wait_S]
,	waiting_tasks_count
FROM sys.dm_os_wait_stats
WHERE wait_type NOT LIKE '%SLEEP%'
ORDER BY wait_time_ms DESC;
