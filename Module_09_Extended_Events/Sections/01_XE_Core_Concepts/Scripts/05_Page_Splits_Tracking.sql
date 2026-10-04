-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

﻿/*
    LAB: Module 09 - Tracking Page Splits with Extended Events
    
    DEMO CONTEXT:
        In Demo 02 (Wait Stats Capture), you aimed for Waits.
        In this Lab, you aim for a specific "Anti-Pattern" (Page Splits) using XEvents.
        This reinforces the Lesson that XEvents can be surgical instruments, not just 
        blunt monitoring tools.

    OBJECTIVE:
        Use Extended Events to capture 'Page Splits' in real-time, often caused by 
        INSERTs into full pages or updates expanding variable columns.

    INSTRUCTIONS:
        1. Run TASK 1 to Create/Reset the 'CapturePageSplits' XEvent Session.
        2. Run TASK 2 to Start the Session.
        3. Run TASK 3 to simulate Page Splits.
           - We insert 1, 3, 5 then try to insert 2.
           - Since the page is full (simulated by large CHAR column), fitting '2' requires a split.
        4. Run TASK 4 to view the Ring Buffer target and confirm the 'page_split' event was captured.
        5. (Optional) Stop the session when finished.

    PREREQUISITES:
        - AdventureWorks2025 or newer
*/

-- Lab: Tracking Page Splits with Extended Events (Modernized)
-- Adapted from: Lab 09 (Existing XEvents)
-- Objective: Detect Page Splits caused by INSERT/UPDATE

USE [master];
GO

-- =============================================
-- TASK 1: CREATE EVENT SESSION
-- =============================================
-- Monitor 'page_split' event.
-- 'LOP_DELETE_SPLIT' in Transaction Log also indicates splits.

IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'CapturePageSplits')
    DROP EVENT SESSION [CapturePageSplits] ON SERVER;
GO

CREATE EVENT SESSION [CapturePageSplits] ON SERVER 
ADD EVENT sqlserver.page_split(
    ACTION(sqlserver.database_name, sqlserver.sql_text, sqlserver.client_app_name)
    WHERE ([sqlserver].[database_name]=N'AdventureWorks2025') -- filter target DB
)
ADD TARGET package0.ring_buffer(SET max_events_limit=(1000))
WITH (MAX_MEMORY=4096 KB, EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY=5 SECONDS);
GO

-- =============================================
-- TASK 2: START SESSION
-- =============================================
ALTER EVENT SESSION [CapturePageSplits] ON SERVER STATE = START;
PRINT 'XEvent Session Started.';
GO

-- =============================================
-- TASK 3: GENERATE PAGE SPLITS (Simulation)
-- =============================================
USE [AdventureWorks2025];
GO
IF OBJECT_ID('dbo.PageSplitDemo') IS NOT NULL DROP TABLE dbo.PageSplitDemo;
CREATE TABLE dbo.PageSplitDemo (
    ID INT PRIMARY KEY, -- Clustered Index on ID
    Data CHAR(4000)     -- Large Row (~4KB, so 2 rows per page)
);

-- Insert 1, 3, 5 (Gap filling will force splits)
INSERT INTO dbo.PageSplitDemo VALUES (1, 'A'), (3, 'C'), (5, 'E');

-- INSERT 2 (Must fit between 1 and 3. If page is full -> Split!)
INSERT INTO dbo.PageSplitDemo VALUES (2, 'B'); 
PRINT 'Page Split Generation Attempted.';
GO

-- =============================================
-- TASK 4: VIEW RESULTS
-- =============================================
SELECT
	xed.event_data.value('(action[@name="database_name"]/value)[1]', 'sysname') AS [Database]
,	xed.event_data.value('(data[@name="file_id"]/value)[1]', 'int') AS [FileID]
,	xed.event_data.value('(data[@name="page_id"]/value)[1]', 'int') AS [PageID]
,	xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS [Query]
,	DATEADD(hh, 7, xed.event_data.value('(@timestamp)[1]', 'datetime2')) AS [Time(Local)] -- Adjust +7 for TH
FROM (
	SELECT CAST(target_data AS XML) AS target_data
	FROM sys.dm_xe_sessions_targets st
	JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
	WHERE s.name = 'CapturePageSplits'
		AND st.target_name = 'ring_buffer'
) AS t
CROSS APPLY target_data.nodes('RingBufferTarget/event') AS xed(event_data);
GO

-- Cleanup
-- ALTER EVENT SESSION [CapturePageSplits] ON SERVER STATE = STOP;

