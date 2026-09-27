-- 04_Yield_Mechanism.sql
-- Source: Adpated from phakkhaphong/SQL-Server-Performance
-- Purpose: Analyze SOS_SCHEDULER_YIELD mechanism (Runnable -> Running cycle).

-- Checks the internal yield count of schedulers
SELECT
	scheduler_id
,	cpu_id
,	current_tasks_count
,	runnable_tasks_count
,	work_queue_count
,	yield_count -- Number of times Worker Thread Yielded CPU
,	last_timer_activity -- Last Yield Timestamp
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255; -- Only User Schedulers
