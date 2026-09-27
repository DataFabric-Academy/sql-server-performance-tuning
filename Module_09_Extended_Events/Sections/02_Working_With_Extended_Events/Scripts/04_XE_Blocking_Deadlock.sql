-- 02_XE_Blocking_Deadlock.sql
-- Source: Adapted from phakkhaphong/SQL-Server-Performance/XE
-- Purpose: Capture Blocking (>5 sec) and Deadlocks using Extended Events.

-- 1. Check if session exists and drop
IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'XE_Troubleshoot_Blocking')
    DROP EVENT SESSION [XE_Troubleshoot_Blocking] ON SERVER;
GO

-- 2. Create Session
CREATE EVENT SESSION [XE_Troubleshoot_Blocking] ON SERVER 

-- A) Capture Blocking (blocked_process_report)
-- Note: Requires 'sp_configure "blocked process threshold", 5' to be set first.
ADD EVENT sqlserver.blocked_process_report(
    ACTION(sqlserver.client_app_name, sqlserver.database_name, sqlserver.sql_text, sqlserver.session_id)
),

-- B) Capture Deadlocks (xml_deadlock_report)
ADD EVENT sqlserver.xml_deadlock_report(
    ACTION(sqlserver.client_app_name, sqlserver.database_name, sqlserver.sql_text)
)

-- 3. Targets
ADD TARGET package0.ring_buffer (SET max_events_limit = 1000),
ADD TARGET package0.event_file (SET filename = N'C:\Temp\XE_Troubleshoot_Blocking.xel', max_file_size = 50, max_rollover_files = 2)

-- 4. Options
WITH (
    MAX_MEMORY = 4096 KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 30 SECONDS,
    STARTUP_STATE = OFF
);
GO

-- 5. Start Session
ALTER EVENT SESSION [XE_Troubleshoot_Blocking] ON SERVER STATE = START;
PRINT 'Session Started. Remember to set "blocked process threshold" to 5 seconds.';
GO
