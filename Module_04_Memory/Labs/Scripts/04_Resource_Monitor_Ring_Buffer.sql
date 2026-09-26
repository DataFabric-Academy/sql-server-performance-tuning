/*
    Script: Monitor Resource Monitor Activity (Ring Buffer)
    Module: 04 - Memory
    
    Description:
    This script queries the internal 'Ring Buffers' to see the history of 
    Resource Monitor notifications (e.g., Low Memory signals from Windows).
    
    Use this to verify if SQL Server is under external memory pressure.
*/

SELECT TOP(20)
	DATEADD (ms, -1 * (ts_now - [timestamp]), GETDATE()) AS [EventTime]
,	record.value('(./Record/ResourceMonitor/Notification)[1]', 'varchar(50)') AS [Notification]
,	CASE record.value('(./Record/ResourceMonitor/Notification)[1]', 'varchar(50)')
		WHEN 'RESOURCE_MEMPHYSICAL_HIGH' THEN 'Fine (RAM > High Threshold)'
		WHEN 'RESOURCE_MEMPHYSICAL_LOW' THEN 'Memory Pressure! (RAM < Low Threshold)'
		WHEN 'RESOURCE_MEMPHYSICAL_STEADY' THEN 'Steady'
		ELSE 'Other'
	END AS [Meaning]
,	record.value('(./Record/MemoryNode/TargetMemory)[1]', 'bigint') / 1024 AS [Target_MB]
,	record.value('(./Record/MemoryNode/ReserveMemory)[1]', 'bigint') / 1024 AS [Reserved_MB]
,	record.value('(./Record/MemoryNode/CommittedMemory)[1]', 'bigint') / 1024 AS [Committed_MB]
,	record.value('(./Record/MemoryNode/SharedMemory)[1]', 'bigint') / 1024 AS [Shared_MB]
,	record.value('(./Record/MemoryNode/AWEMemory)[1]', 'bigint') / 1024 AS [AWE_MB]
FROM (
	SELECT
		[timestamp]
	,	CONVERT(XML, record) AS record
	,	(SELECT cpu_ticks / (cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info) AS ts_now
	FROM sys.dm_os_ring_buffers
	WHERE ring_buffer_type = 'RING_BUFFER_RESOURCE_MONITOR'
) AS T
ORDER BY [EventTime] DESC;
