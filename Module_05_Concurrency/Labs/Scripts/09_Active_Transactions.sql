-- 09_Active_Transactions.sql
-- Check Active Transactions
-- Useful for finding "Sleeping" transactions that are holding locks.

SELECT
	[s_tst].[session_id]
,	[s_es].[login_name] AS [Login Name]
,	DB_NAME (s_tdt.database_id) AS [Database]
,	[s_tdt].[database_transaction_begin_time] AS [Begin Time]
,	[s_tdt].[database_transaction_log_record_count] AS [Log Records]
,	[s_tdt].[database_transaction_log_bytes_used] AS [Log Bytes]
,	[s_tst].[is_user_transaction]
FROM sys.dm_tran_database_transactions AS [s_tdt]
INNER JOIN sys.dm_tran_session_transactions AS [s_tst]
	ON [s_tdt].[transaction_id] = [s_tst].[transaction_id]
INNER JOIN sys.dm_exec_sessions AS [s_es]
	ON [s_tst].[session_id] = [s_es].[session_id]
ORDER BY [s_tdt].[database_transaction_begin_time] ASC;
