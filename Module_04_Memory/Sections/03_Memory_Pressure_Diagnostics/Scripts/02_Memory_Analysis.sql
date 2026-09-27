/*
    LAB: Module 04 - Advanced Memory Analysis
    
    DEMO CONTEXT:
        In Demo 03 (Memory Clerks), you saw how to list Clerks.
        In this Lab, you use that knowledge to diagnose *Where* the memory is going 
        after running the Spill workload in Lab 01 (e.g. OBJECTSTORE_LOCK_MANAGER vs MEMORYCLERK_SQLBUFFERPOOL).

    OBJECTIVE:
        Deep dive into Memory Clerks and Buffer Descriptors to troubleshoot pressure.
*/

-- Lab: Advanced Memory Analysis Walkthrough
-- วัตถุประสงค์: สำรวจการใช้ Memory ของ SQL Server ผ่าน DMVs
-- Data Driven Analysis: ใช้ตัวเลขจริงในการตัดสินใจ

-- 1. ตรวจสอบ "Memory Overall" ของ Instance
-- ดูว่า SQL กิน RAM ไปเท่าไหร่ (Target vs Total)
SELECT
	(physical_memory_in_use_kb/1024) AS Memory_Used_MB
,	(large_page_allocations_kb/1024) AS Large_Pages_MB
,	(locked_page_allocations_kb/1024) AS Locked_Pages_MB
,	(virtual_address_space_committed_kb/1024) AS Total_Committed_MB
,	process_physical_memory_low
,	process_virtual_memory_low
FROM sys.dm_os_process_memory;

-- 2. ตรวจสอบ "Who is eating Memory?" (Memory Clerks)
-- ดูว่า Component ไหนกิน RAM สูงสุด (Buffer Pool, Plan Cache, หรืออื่นๆ)
SELECT TOP(10)
	[type] AS Clerk_Type
,	pages_kb/1024 AS Size_MB
,	awe_allocated_kb/1024 AS AWE_Size_MB
,	shared_memory_reserved_kb/1024 AS Shared_Mem_MB
FROM sys.dm_os_memory_clerks
ORDER BY pages_kb DESC;

-- MEMORYCLERK_SQLBUFFERPOOL = ข้อมูลใน Data Cache (ปกติจะเยอะสุด)
-- MEMORYCLERK_SQLQUERYPLAN = Plan Cache (ถ้าเยอะผิดปกติ อาจเกิด Plan Bloat)

-- 3. ตรวจสอบ Buffer Pool Usage แยกตาม Database
-- Database ไหนกิน RAM เยอะสุด?
SELECT
	CASE WHEN database_id = 32767 THEN 'ResourceDb' ELSE DB_NAME(database_id) END AS Database_Name
,	COUNT(*) * 8 / 1024 AS Cached_Size_MB
FROM sys.dm_os_buffer_descriptors
GROUP BY DB_NAME(database_id), database_id
ORDER BY Cached_Size_MB DESC;
