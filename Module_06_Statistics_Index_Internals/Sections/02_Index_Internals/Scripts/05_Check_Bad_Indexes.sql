-- 05_Check_Bad_Indexes.sql
-- Possible bad nonclustered indexes (writes > reads) – based on Glenn Berry 2025, Query 71
--   https://glennsqlperformance.com/resources/
-- Used here with attribution for non-commercial training/demo purposes.

SELECT
    SCHEMA_NAME(o.[schema_id]) AS [Schema Name]
,   OBJECT_NAME(s.[object_id]) AS [Table Name]
,   i.name AS [Index Name]
,   i.index_id
,   i.is_disabled
,   i.is_hypothetical
,   i.has_filter
,   i.fill_factor
,   s.user_updates AS [Total Writes]
,   s.user_seeks + s.user_scans + s.user_lookups AS [Total Reads]
,   s.user_updates - (s.user_seeks + s.user_scans + s.user_lookups) AS [Write-Read Difference]
FROM sys.dm_db_index_usage_stats AS s WITH (NOLOCK)
INNER JOIN sys.indexes AS i WITH (NOLOCK)
    ON s.[object_id] = i.[object_id]
    AND i.index_id = s.index_id
INNER JOIN sys.objects AS o WITH (NOLOCK)
    ON i.[object_id] = o.[object_id]
WHERE OBJECTPROPERTY(s.[object_id], 'IsUserTable') = 1
  AND s.database_id = DB_ID()
  AND s.user_updates > (s.user_seeks + s.user_scans + s.user_lookups)
  AND i.index_id > 1
  AND i.[type_desc] = N'NONCLUSTERED'
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND i.is_unique = 0
ORDER BY
    [Write-Read Difference] DESC
,   [Total Writes] DESC
,   [Total Reads] ASC
OPTION (RECOMPILE);

-- แนวทางใช้ผลลัพธ์:
-- - Index ที่ Writes สูงมากแต่ Reads ต่ำหรือศูนย์ → ผู้ต้องสงสัย “Index ขยะ”
-- - ตรวจดู workload ทั้งระบบและอายุ instance ก่อน DROP (ระวังกรณี Report/Night jobs)
