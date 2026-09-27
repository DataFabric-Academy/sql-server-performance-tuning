-- Workload: Create XEvent Session
 USE master;
 GO
 
 -- Drop if exists
 IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'XE_Deadlock_Monitor')
     DROP EVENT SESSION [XE_Deadlock_Monitor] ON SERVER;
 GO
 
 -- Create Session
 CREATE EVENT SESSION [XE_Deadlock_Monitor] ON SERVER 
 ADD EVENT sqlserver.xml_deadlock_report
 ADD TARGET package0.ring_buffer(SET max_events_limit=(10), max_memory=(4096))
 WITH (STARTUP_STATE=OFF);
 GO
 
 -- Start Session
 ALTER EVENT SESSION [XE_Deadlock_Monitor] ON SERVER STATE = START;
 GO
 
 PRINT 'Session XE_Deadlock_Monitor Started.';
