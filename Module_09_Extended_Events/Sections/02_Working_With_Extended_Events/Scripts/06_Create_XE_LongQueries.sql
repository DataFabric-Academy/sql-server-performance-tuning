/*
    SCRIPT: 06_Create_XE_LongQueries.sql
    [CRITICAL]: EXECUTE IN MASTER context (XE Sessions are Server Objects)
*/
USE [master];
GO

/*
    DEMO: Extended Events Basics
    Create a session to capture queries running longer than 1 second.
*/
-- 06_Create_XE_LongQueries.sql
-- Create Extended Events Session for Long Running Queries
-- captures queries taking > 5 seconds

CREATE EVENT SESSION [CaptureLongQueries] ON SERVER 
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.database_name,sqlserver.sql_text,sqlserver.client_app_name,sqlserver.username)
    WHERE ([duration]>(5000000))) -- Duration is in microseconds (5 sec)
ADD TARGET package0.event_file(SET filename=N'C:\Temp\LongQueries.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF);
GO

-- Start Session
-- ALTER EVENT SESSION [CaptureLongQueries] ON SERVER STATE = START;
