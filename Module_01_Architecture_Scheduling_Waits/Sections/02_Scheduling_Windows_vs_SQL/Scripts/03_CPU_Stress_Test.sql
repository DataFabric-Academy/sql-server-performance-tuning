-- Lab: CPU Stress Test (Simulate High CPU)
-- วัตถุประสงค์: สร้าง Workload ที่ใช้ CPU สูงเพื่อทดสอบ Scheduler Running/Runnable queues
-- คำแนะนำ: รันสคริปต์นี้ใน New Query Window หลายๆ หน้าต่าง (3-4 Sessions) พร้อมกัน

SET NOCOUNT ON;

DECLARE @StartTime DATETIME = GETDATE();
DECLARE @DurationSeconds INT = 60; -- รันนาน 60 วินาที

PRINT 'Scanning for CPU Pressure... Starting Workload';

-- CPU Burn Loop
WHILE DATEDIFF(SECOND, @StartTime, GETDATE()) < @DurationSeconds
BEGIN
    -- คำนวณทางคณิตศาสตร์ที่ซับซ้อนเพื่อให้ CPU ทำงานหนัก
    DECLARE @i INT = 1;
    DECLARE @MainHash VARBINARY(8000) = 0x;
    
    SELECT @MainHash = HASHBYTES('SHA2_512', CAST(NEWID() AS VARCHAR(36)));
END

PRINT 'Workload Completed.';
