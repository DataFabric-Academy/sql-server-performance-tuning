-- 04_Database_File_Sizes.sql
-- File sizes, growth settings and locations for all databases
-- Inspired by: SQL Server 2025 Diagnostic Information Queries (Glenn Berry)
--   https://glennsqlperformance.com/resources/
-- Used here with attribution for non-commercial training/demo purposes.

SELECT
    DB_NAME(mf.database_id) AS [Database Name]
,   mf.file_id
,   mf.name AS [Logical Name]
,   mf.type_desc AS [File Type]
,   CAST(mf.size * 8.0 / 1024.0 AS DECIMAL(18, 2)) AS [Size (MB)]
,   mf.max_size
,   mf.is_percent_growth
,   mf.growth
,   CASE
        WHEN mf.is_percent_growth = 1
            THEN CAST(mf.growth AS VARCHAR(12)) + N' %'
        ELSE CAST(mf.growth * 8.0 / 1024.0 AS VARCHAR(12)) + N' MB'
     END AS [Growth Setting]
,   mf.physical_name AS [Physical Path]
FROM sys.master_files AS mf WITH (NOLOCK)
WHERE mf.database_id > 4 -- exclude system DBs if desired
ORDER BY
    [Database Name]
,   mf.file_id
OPTION (RECOMPILE);

-- Recommendations:
-- - Avoid percentage growth for data and log files; use fixed MB growth (e.g. 512 MB, 1 GB, 4 GB)
-- - Ensure data and log files are on appropriate storage and sized correctly for expected workload
