-- 04_Latch_Spinlock_Analysis.sql
-- Source: Adapted from phakkhaphong/SQL-Server-Performance/Lock
-- Purpose: Advanced troubleshooting for Latch (Memory protection) and Spinlock (Low-level structure) contention.
-- WARNING: This script uses DBCC SQLPERF to clear stats and WAITFOR DELAY. Use in Test/Lab only.

/* ================================================================================================
   PART 1: LATCH ANALYSIS
   Latches protect internal memory structures (Buffer Pages, Hash Tables).
   High latch waits often indicate "Hot Pages" (e.g., PFS/GAM contention in TempDB).
   ================================================================================================ */

PRINT 'Starting Latch Analysis...';

-- Reset stats (Optional: specific to session/lab environment)
-- DBCC SQLPERF('sys.dm_os_latch_stats', CLEAR); 

IF OBJECT_ID('tempdb..#LatchStats_Snapshot1') IS NOT NULL DROP TABLE #LatchStats_Snapshot1;

-- Snapshot 1
SELECT
	latch_class
,	waiting_requests_count
,	wait_time_ms
,	max_wait_time_ms
,	GETDATE() AS capture_time
INTO #LatchStats_Snapshot1
FROM sys.dm_os_latch_stats;

-- Wait 5 Seconds (Reduced from 5 mins for Lab purpose)
WAITFOR DELAY '00:00:05';

-- Snapshot 2 & Compare
WITH LatchStats_Snapshot2 AS (
	SELECT
		latch_class
	,	waiting_requests_count
	,	wait_time_ms
	,	max_wait_time_ms
	FROM sys.dm_os_latch_stats
)
SELECT TOP 10
	s2.latch_class
,	(s2.waiting_requests_count - s1.waiting_requests_count) AS delta_waits
,	(s2.wait_time_ms - s1.wait_time_ms) AS delta_wait_time_ms
,	CASE WHEN (s2.waiting_requests_count - s1.waiting_requests_count) > 0
		THEN (s2.wait_time_ms - s1.wait_time_ms) * 1.0 / (s2.waiting_requests_count - s1.waiting_requests_count)
		ELSE 0 END AS avg_wait_time_ms
,	s2.max_wait_time_ms AS current_max_wait_time_ms
FROM #LatchStats_Snapshot1 s1
INNER JOIN LatchStats_Snapshot2 s2 ON s1.latch_class = s2.latch_class
WHERE (s2.wait_time_ms - s1.wait_time_ms) > 0
ORDER BY delta_wait_time_ms DESC;
GO

/* ================================================================================================
   PART 2: SPINLOCK ANALYSIS
   Spinlocks are lightweight locks for CPU-level protection.
   High collisions indicate CPU pressure and hot code paths (e.g., LOCK_HASH, OPT_IDX_STATS).
   ================================================================================================ */

PRINT 'Starting Spinlock Analysis...';

IF OBJECT_ID('tempdb..#SpinlockStats_Snapshot1') IS NOT NULL DROP TABLE #SpinlockStats_Snapshot1;

-- Snapshot 1
SELECT
	name
,	collisions
,	spins
,	spins_per_collision
,	sleep_time
,	backoffs
,	GETDATE() AS capture_time
INTO #SpinlockStats_Snapshot1
FROM sys.dm_os_spinlock_stats;

-- Wait 5 Seconds
WAITFOR DELAY '00:00:05';

-- Snapshot 2 & Compare
WITH SpinlockStats_Snapshot2 AS (
	SELECT
		name
	,	collisions
	,	spins
	,	spins_per_collision
	,	sleep_time
	,	backoffs
	FROM sys.dm_os_spinlock_stats
)
SELECT TOP 10
	s2.name AS spinlock_name
,	(s2.collisions - s1.collisions) AS delta_collisions
,	(s2.spins - s1.spins) AS delta_spins
,	(s2.backoffs - s1.backoffs) AS delta_backoffs
FROM #SpinlockStats_Snapshot1 s1
INNER JOIN SpinlockStats_Snapshot2 s2 ON s1.name = s2.name
WHERE (s2.collisions - s1.collisions) > 0
ORDER BY delta_backoffs DESC, delta_collisions DESC;
GO
