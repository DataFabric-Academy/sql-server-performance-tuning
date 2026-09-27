/*
    LAB: Module 02 - Storage Stress Testing with Diskspd
    
    DEMO CONTEXT:
        In Demo 02 (Drive Latency), you queried sys.dm_io_virtual_file_stats to see latency.
        But how do you verify if the *Disk itself* is the bottleneck vs SQL Server?
        In this Lab, you use 'Diskspd' (Microsoft's I/O generator) to stress the SUBSYSTEM 
        independent of SQL Server.

    OBJECTIVE:
        Generate realistic I/O patterns (OLTP vs Logging vs DW) to validate storage performance.

    INSTRUCTIONS:
        1. Run the script to generate Diskspd commands.
        2. Open a Command Prompt (Admin) and run the generated command (Scenario 1 or 2).
        3. [CRITICAL STEP] While Diskspd is running, go back to SSMS and run 
           Demo 02 (Drive Latency) or PerfMon.
           - Observation: Does 'Avg_Write_Latency_ms' spike? 
           - If Diskspd reports 5ms but SQL reports 100ms, the issue is Queuing/SQL.
           - If Diskspd reports 100ms, the Disk is physically slow.

    PREREQUISITES:
        - diskspd.exe (Downloaded from GitHub)
*/

-- Lab: Diskspd Command Generator
-- Scenario: Generate 3 common SQL Patterns to benchmark your storage.

DECLARE @TargetDrive CHAR(1) = 'C'; -- เปลี่ยนเป็น Drive ที่ต้องการทดสอบ (เช่น Data Drive)
DECLARE @FileSize VARCHAR(10) = '2G'; -- ขนาดไฟล์ทดสอบ
DECLARE @Duration VARCHAR(10) = '30'; -- ระยะเวลาทดสอบ (วินาที)

-- 1. SQL Server Pattern (8KB Random Read 70% / Write 30%)
PRINT '--- Scenario 1: OLTP Workload (8KB Random R/W) ---';
PRINT 'diskspd.exe -b8K -d' + @Duration + ' -h -L -o32 -t4 -r -w30 -c' + @FileSize + ' ' + @TargetDrive + ':\io_test.dat';
PRINT '';

-- 2. Log File Pattern (64KB Sequential Write)
PRINT '--- Scenario 2: Transaction Log Workload (64KB Seq Write) ---';
PRINT 'diskspd.exe -b64K -d' + @Duration + ' -h -L -o32 -t1 -s -w100 -c' + @FileSize + ' ' + @TargetDrive + ':\log_test.dat';
PRINT '';

-- 3. Data Warehouse Pattern (512KB Sequential Read)
PRINT '--- Scenario 3: Data Warehouse Workload (512KB Seq Read) ---';
PRINT 'diskspd.exe -b512K -d' + @Duration + ' -h -L -o8 -t2 -s -w0 -c' + @FileSize + ' ' + @TargetDrive + ':\dw_test.dat';
PRINT '';

PRINT 'คำแนะนำ: Copy Command ไปรันใน Command Prompt (Admin)';
