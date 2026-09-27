-- Workload: Read XE Data
 USE master;
 GO
 
 -- Query Ring Buffer
SELECT
	xed.event_data.value('(timestamp)[1]', 'datetime') AS Time
,	xed.event_data.query('.') AS XmlReport
FROM (
	SELECT CAST(target_data AS XML) AS TargetData
	FROM sys.dm_xe_session_targets st
	JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
	WHERE s.name = 'XE_Deadlock_Monitor' AND st.target_name = 'ring_buffer'
) AS Data
CROSS APPLY TargetData.nodes ('RingBufferTarget/event') AS xed (event_data);
 GO
