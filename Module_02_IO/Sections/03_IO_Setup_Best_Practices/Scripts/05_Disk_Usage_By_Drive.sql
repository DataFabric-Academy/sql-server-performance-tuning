-- 05_Disk_Usage_By_Drive.sql
-- Check Disk Space Availability
-- Source: Standard DMVs

SELECT DISTINCT
	vs.volume_mount_point AS [Drive]
,	vs.logical_volume_name AS [Volume Name]
,	vs.total_bytes / 1024 / 1024 / 1024 AS [Total Size (GB)]
,	vs.available_bytes / 1024 / 1024 / 1024 AS [Free Space (GB)]
,	CAST(vs.available_bytes AS FLOAT) / CAST(vs.total_bytes AS FLOAT) * 100 AS [Percent Free]
FROM sys.master_files AS mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs
ORDER BY [Drive];
