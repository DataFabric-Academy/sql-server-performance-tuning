-- MinVersion: SQL Server 2019 (15.x) · Database: AdventureWorks2025

-- 04_Virtual_File_Stats.sql
-- Analyze I/O Latency by Database File (modern view)
-- Based on: SQL Server 2025 Diagnostic Information Queries (Glenn Berry)
--   https://glennsqlperformance.com/resources/
-- Used here with attribution for non-commercial training/demo purposes.

SELECT
    DB_NAME(vfs.database_id) AS [Database Name]
,   mf.name AS [Logical File Name]
,   mf.type_desc AS [File Type]
,   CAST(vfs.io_stall_read_ms / NULLIF(vfs.num_of_reads, 0) AS NUMERIC(10, 1)) AS [Avg Read Latency (ms)]
,   CAST(vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) AS NUMERIC(10, 1)) AS [Avg Write Latency (ms)]
,   CAST((vfs.io_stall_read_ms + vfs.io_stall_write_ms)
        / NULLIF(vfs.num_of_reads + vfs.num_of_writes, 0) AS NUMERIC(10, 1)) AS [Avg I/O Latency (ms)]
,   vfs.num_of_reads AS [Total Reads]
,   vfs.num_of_writes AS [Total Writes]
,   vfs.size_on_disk_bytes / 1024 / 1024 AS [Size (MB)]
,   vfs.io_stall_queued_read_ms AS [RG Queued Read Latency (ms)]
,   vfs.io_stall_queued_write_ms AS [RG Queued Write Latency (ms)]
,   mf.physical_name AS [Physical File Path]
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
INNER JOIN sys.master_files AS mf WITH (NOLOCK)
    ON vfs.database_id = mf.database_id
    AND vfs.file_id = mf.file_id
ORDER BY
    [Avg I/O Latency (ms)] DESC
OPTION (RECOMPILE);

-- Guidelines for Latency (general rule of thumb):
-- <  5 ms : Excellent (SSD/NVMe)
-- 5–10 ms: Good
-- 10–20 ms: Acceptable
-- > 20 ms: Potential Bottleneck – investigate storage subsystem
