-- Lab: Capture Wait Stats with Extended Events
-- วัตถุประสงค์: สร้าง XEvent Session เพื่อจับ Wait Info ที่นานเกิน 500ms

-- 1. Create Session
IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='CaptureWaits')
    DROP EVENT SESSION [CaptureWaits] ON SERVER;
GO

CREATE EVENT SESSION [CaptureWaits] ON SERVER 
ADD EVENT sqlos.wait_info(
    ACTION(sqlserver.sql_text, sqlserver.database_name)
    WHERE ([duration] > (500)) -- จับเฉพาะที่รอนานกว่า 500ms
    AND ([wait_type] <> 0) -- ไม่เอา Wait=0 (System)
)
ADD TARGET package0.ring_buffer
WITH (MAX_MEMORY=4096 KB, EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS);
GO

-- 2. Start Session
ALTER EVENT SESSION [CaptureWaits] ON SERVER STATE = START;
PRINT 'Session Started. Waiting for workloads...';

-- 3. Generate Workload
-- (ไปรัน Lab Blocking ใน Module 05)
-- WAITFOR DELAY '00:00:01';

-- 4. View Data from Ring Buffer
/*
SELECT 
    target_data = CAST(target_data AS XML)
FROM sys.dm_xe_session_targets t
JOIN sys.dm_xe_sessions s ON s.address = t.event_session_address
WHERE s.name = 'CaptureWaits';
*/

-- 5. Stop Session
-- ALTER EVENT SESSION [CaptureWaits] ON SERVER STATE = STOP;
