[⬅ Module 09](../../README.md) | [9.1 XE Core Concepts](../01_XE_Core_Concepts/README.md) | Section 2/2

# 9.2 Working With Extended Events — สร้าง Session จับ Slow Query, Deadlock และ Blocking ด้วยมือตัวเอง

> *"เครื่องมือวัดที่ดีที่สุดคือเครื่องมือที่คุณควบคุมได้ว่าจะเก็บอะไร เก็บเมื่อไร เก็บไว้ที่ไหน — Extended Events session คือความควบคุมนั้น เขียนเป็น T-SQL ได้ทั้งหมด"*

> **ต้องรู้มาก่อน**: ศัพท์ XE ทั้ง 7 คำจาก [Section 9.1](../01_XE_Core_Concepts/README.md) — **Package, Event, Payload, Predicate, Action, Target, Session** — รวมทั้ง [Deadlock](../../../Glossary.md) / [Blocking](../../../Glossary.md) จาก Module 5 (เราจะผลิต deadlock ซ้ำแบบเดิมแต่มีกล้องรออยู่), [DMV](../../../Glossary.md), [XQuery / XML](../../../Glossary.md), [AdventureWorks](../../../Glossary.md)
> **Environment ที่ทุกโค้ดใน section นี้ถูกทดสอบ**: SQL Server 2025 RTM-GDR (17.0.1135.8) + AdventureWorks — หน่วยเวลาใน XEvents เป็น **ไมโครวินาที** เสมอ

---

## แผนที่ของ Section นี้

เราจะเดินตามโจทย์เดียวกับแล็บจุดปิดคอร์ส (Lab 9): หัวหน้าห้ามใช้ Profiler — คุณต้องสร้างระบบติดตาม 3 เรื่องด้วย XEvents คือ (1) query ที่ช้า/กิน resource (2) deadlock (3) blocking ยาว — เลือก target ให้ถูกกับงาน (ring_buffer, histogram, event_counter, event_file) แล้วจบด้วย best practices ระดับ production — ระหว่างทางจะได้ใช้เทคนิคอ่าน XML และ TRACK_CAUSALITY

> [!IMPORTANT]
> ทุก session ใน section นี้ถูกสร้าง → ทดสอบ → **STOP + DROP จนหมดแล้ว** เมื่อคุณทำตาม ให้ทำ Cleanup ในหัวข้อ 8 ทุกครั้ง — session ที่ลืมปิดคือขยะที่กิน memory ของ server ไปเรื่อย ๆ

---

## 1. โครง `CREATE EVENT SESSION` — อ่าน grammar ให้เป็นก่อนพิมพ์

รูปแบบคำสั่ง (ย่อจากเอกสาร Microsoft เหลือเฉพาะส่วนที่ใช้):

```text
CREATE EVENT SESSION [ชื่อ session] ON SERVER
ADD EVENT <event แบบเต็ม> ( ACTION(...) WHERE(...) )     -- ทำซ้ำได้หลาย event
ADD TARGET <target แบบเต็ม> ( SET <ตั้งค่า target> )      -- ทำซ้ำได้หลาย target
WITH ( MAX_MEMORY = ... KB,
       MAX_DISPATCH_LATENCY = ... SECONDS,
       EVENT_RETENTION_MODE = ...,
       TRACK_CAUSALITY = ON|OFF,
       STARTUP_STATE = ON|OFF );
```

| ส่วน | ทำหน้าที่ | ข้อควรรู้ |
|:-----|:----------|:----------|
| `ON SERVER` | session เป็น object ระดับ server | สร้างใน context ไหนก็ได้ (นิยม `USE master`) |
| `ADD EVENT ... WHERE ...` | event + predicate | predicate เขียนเรียงต่อกันด้วย `AND`/`OR` ได้ — กรองเร็วยิ่งเบายิ่งดี |
| `ADD TARGET ... SET ...` | ปลายทาง + ค่าเฉพาะของมัน | อย่าง `max_memory` (KB) ของ ring_buffer, `max_file_size` (MB) ของ event_file |
| `WITH (...)` | นโยบายระดับ session | จาก Section 9.1 หัวข้อ 4 |

> [!WARNING]
> **สิ่งที่ predicate ทำไม่ได้ (พิสูจน์แล้วบน 17.0.1135.8):** เรียกฟังก์ชัน T-SQL — เช่นแบบนี้จะล้มทันที:
>
> ```text
> ADD EVENT sqlserver.sql_batch_completed
> ( WHERE database_id = DB_ID(N'AdventureWorks') )   -- Incorrect syntax near 'DB_ID'
> ```
>
> ทางที่ถูก: ใช้ field ของ engine — `WHERE sqlserver.database_name = N'AdventureWorks'` (ใน session ของเราทุกตัวใช้แบบนี้) หรือใส่ตัวเลข id ตรง ๆ (หาค่าด้วย `SELECT DB_ID('AdventureWorks');` แล้วนำมาเขียนลง predicate)

---

## 2. แล็บที่ 1: จับ Slow Query ลง ring_buffer

โจทย์: จับ statement ที่ทำงานเกิน 500 มิลลิวินาที ใน database AdventureWorks เท่านั้น เก็บข้อความ SQL และชื่อ app ที่ส่งมา

### Step 1 — สร้างและ START session

```sql
CREATE EVENT SESSION [XE_Sec2_SlowQueries] ON SERVER
ADD EVENT sqlserver.sql_statement_completed
(
    ACTION ( sqlserver.sql_text, sqlserver.client_app_name, sqlserver.session_id )
    WHERE ( duration > 500000
            AND sqlserver.database_name = N'AdventureWorks' )
)
ADD TARGET package0.ring_buffer
(
    SET max_memory = 4096
)
WITH ( MAX_DISPATCH_LATENCY = 5 SECONDS,
       STARTUP_STATE = OFF );
GO
ALTER EVENT SESSION [XE_Sec2_SlowQueries] ON SERVER STATE = START;
```

อ่านโครงให้สอดคล้องกับ 9.1: event หนึ่งตัว (`sql_statement_completed`) + predicate สองเงื่อนไข (`duration` หน่วย µs → 500000 = 500 ms; `database_name` กรอง DB) + action สามตัว (ข้อความ SQL, app, session id) + target `ring_buffer` 4096 KB + dispatch ทุก 5 วินาที

### Step 2 — ผลิต workload ที่ช้าเกินเกณฑ์

```sql
USE AdventureWorks;
GO
SELECT TOP (100000) CarrierTrackingNumber, ModifiedDate
FROM Sales.SalesOrderDetail
ORDER BY CarrierTrackingNumber, ModifiedDate;
```

> [!IMPORTANT]
> บรรทัด `USE AdventureWorks;` ไม่ใช่พิธีกรรม — predicate `sqlserver.database_name` อ้าง **database context ของ session ตอนเหตุการณ์เกิด** รัน query จาก context `master` แม้จะอ้างตารางแบบ 3 ส่วน (`AdventureWorks.Sales...`) ก็ถูก predicate กรองทิ้ง (ทดสอบจริง: event หายทั้งหมด ย้ายมา `USE` ก่อนจึงจับได้)

### Step 3 — อ่านผลจาก ring_buffer ด้วย XQuery

รอให้ครบ `MAX_DISPATCH_LATENCY` (5 วินาที) ก่อนอ่าน:

```sql
WAITFOR DELAY '00:00:06';
GO
SELECT
    x.value('(@timestamp)[1]', 'DATETIME2')                            AS event_time,
    x.value('(data[@name="duration"]/value)[1]', 'BIGINT')/1000.0      AS duration_ms,
    x.value('(data[@name="cpu_time"]/value)[1]', 'BIGINT')/1000.0      AS cpu_ms,
    x.value('(data[@name="logical_reads"]/value)[1]', 'BIGINT')        AS logical_reads,
    x.value('(action[@name="sql_text"]/value)[1]', 'NVARCHAR(MAX)')    AS sql_text,
    x.value('(action[@name="client_app_name"]/value)[1]', 'SYSNAME')   AS app_name
FROM (
    SELECT CAST(target_data AS XML) AS buf
    FROM sys.dm_xe_session_targets AS t
    JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
    WHERE s.name = 'XE_Sec2_SlowQueries' AND t.target_name = 'ring_buffer'
) AS d
CROSS APPLY buf.nodes('//event') AS n(x)
ORDER BY event_time DESC;
```

### กติกาการอ่าน XML ของ ring_buffer (โดนกันเยอะที่สุด)

1. `CAST(target_data AS XML)` — ค่า target_data เป็น NVARCHAR ต้องแปลงเป็น XML จึงใช้ XQuery ได้
2. `buf.nodes('//event')` — ฉีก buffer ออกเป็นหลายแถว (แถวละ 1 เหตุการณ์) โดย bind context node ที่ตัว `<event>`
3. เพราะ context node คือ `<event>` แล้ว — **path ต้องเขียนสัมพัทธ์**: `(@timestamp)`, `(data[@name="duration"]/value)` **ห้าม** นำหน้าด้วย `event/` (จะได้ NULL ทุกคอลัมน์)
4. `data[...]` = payload ของ event, `action[...]` = action ที่เราขอไว้ — อ่านค่าลูกด้วย `/value`
5. XQuery **case-sensitive** — ตัวพิมพ์เล็ก/ใหญ่ต้องตรงกับที่ engine เขียนออกมา

### ผลที่ได้จริง (ทดสอบบน 17.0.1135.8, 2026-10-02)

| event_time | duration_ms | cpu_ms | logical_reads | app_name |
|:-----------|------------:|-------:|--------------:|:---------|
| ... | **1309.919** | 296.000 | **1972** | sqlcmd |

สังเกต 3 อย่างที่มีคุณค่า:
1. `duration` = 1310 ms แต่ `cpu` = 296 ms — duration รวมเวลา "ส่ง 100,000 แถวออก network" ที่ SQL ไม่ได้ใช้ CPU นี่คือแบบเดียวกับ wait `ASYNC_NETWORK_IO` จาก Module 1
2. workload ที่จงใจช้าถูกจับ, query สั้น ๆ ไม่ปรากฏ — predicate ทำงานตั้งแต่จุดเกิดเหตุจริง
3. อย่าตกใจถ้าเห็น `WAITFOR DELAY` ของตัวเองถูกจับด้วย (duration ~6000 ms) — session เก็บ **ทุก** statement ที่ผ่านเกณฑ์ รวมถึงของที่เราใช้ทดสอบ

---

## 3. Targets ฝั่ง memory: histogram และ event_counter

ring_buffer เก็บ "ตัวเหตุการณ์" เต็ม ๆ — แต่บางโจทย์แค่อยากรู้ "อะไรเกิดบ่อยสุด" ไม่ต้องการรายละเอียดทั้งก้อน ตัวตอบคำถามนี้คือ histogram (นับแยกกลุ่ม) และ event_counter (นับรวม)

### 3.1 Histogram — นับ error แยกตาม error_number

```sql
CREATE EVENT SESSION [XE_Sec2_ErrorsHist] ON SERVER
ADD EVENT sqlserver.error_reported
(
    ACTION ( sqlserver.database_name )
    WHERE ( severity >= 11 )
)
ADD TARGET package0.histogram
(
    SET filtering_event_name = N'sqlserver.error_reported',
        source = N'error_number',
        source_type = 0,
        slots = 16
)
WITH ( MAX_DISPATCH_LATENCY = 5 SECONDS );
GO
ALTER EVENT SESSION [XE_Sec2_ErrorsHist] ON SERVER STATE = START;
```

อ่าน `SET`: นับเฉพาะ event `error_reported` (`filtering_event_name`), จัดกลุ่มด้วย payload `error_number` (`source_type = 0` คือ "อ้าง payload ของ event"), รับสูงสุด 16 กลุ่ม (`slots`)

ผลิต error สามแบบ:

```sql
USE AdventureWorks;
GO
SELECT 1/0;                                       -- 8134: Divide by zero
GO
SELECT InvalidColumn FROM Sales.SalesOrderHeader; -- 207: Invalid column name
GO
RAISERROR (N'Test user error', 16, 1);            -- 50000: user-defined
GO
WAITFOR DELAY '00:00:06';
GO
```

อ่าน histogram — โครงเดียวกับ ring_buffer แต่ element ของ target นี้ชื่อ `<Slot>` (**ตัวพิมพ์ใหญ่** — XQuery case-sensitive):

```sql
SELECT
    x.value('(value)[1]', 'INT')       AS error_number,
    x.value('(@count)[1]', 'BIGINT')   AS hit_count
FROM (
    SELECT CAST(target_data AS XML) AS buf
    FROM sys.dm_xe_session_targets AS t
    JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
    WHERE s.name = 'XE_Sec2_ErrorsHist' AND t.target_name = 'histogram'
) AS d
CROSS APPLY buf.nodes('//Slot') AS n(x)
ORDER BY hit_count DESC;
```

**ผลจริงจากการทดสอบ:**

| error_number | hit_count |
|-------------:|----------:|
| 18456 (login failed) | 4 |
| 8134 | 1 |
| 50000 | 1 |
| 207 | 1 |

> [!NOTE]
> error 18456 มาจากคนอื่นใน server ที่ใช้ร่วมกันพิมพ์ password ผิด — นี่แหละคุณค่าของ histogram: เปิด session รอบเดียว เห็น "ความจริงของ server" ที่ app ไม่เคยรายงาน ใน production รูปแบบนี้ใช้จับ recompile (`sql_statement_recompile` จัดกลุ่มด้วย `object_id`) หรือ lock escalation ได้เหมือนกัน
### 3.2 Event Counter — นับรวมง่าย ๆ

```sql
CREATE EVENT SESSION [XE_Sec2_Counter] ON SERVER
ADD EVENT sqlserver.sql_batch_completed
(
    ACTION ( sqlserver.database_name )
    WHERE ( sqlserver.database_name = N'AdventureWorks' )
)
ADD TARGET package0.event_counter
WITH ( MAX_DISPATCH_LATENCY = 5 SECONDS );
GO
ALTER EVENT SESSION [XE_Sec2_Counter] ON SERVER STATE = START;
GO
USE AdventureWorks;
GO
SELECT COUNT(*) FROM Sales.SalesOrderHeader;
GO
WAITFOR DELAY '00:00:06';
GO
SELECT
    x.value('(@name)[1]', 'SYSNAME') AS event_name,
    x.value('(@count)[1]', 'BIGINT') AS event_count
FROM (
    SELECT CAST(target_data AS XML) AS buf
    FROM sys.dm_xe_session_targets AS t
    JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
    WHERE s.name = 'XE_Sec2_Counter' AND t.target_name = 'event_counter'
) AS d
CROSS APPLY buf.nodes('//Event') AS n(x);
GO
```

**ผลจริง:** `sql_batch_completed | 4` — element ของ target นี้คือ `<Event name=... count=.../>` (อีกตัวที่ต้องพิมพ์ใหญ่ให้ถูก) — counter เบาที่สุดในทุก target เพราะไม่เก็บเนื้อหา event เลย เหมาะกับ "เช็คว่าเกิดบ่อยแค่ไหน" ก่อนตัดสินใจจับละเอียด

---

## 4. Target ฝั่ง disk: event_file — มาตรฐานของ production

ring_buffer เสียทันทีเมื่อ server restart และเขียนทับของเก่าเมื่อ buffer เต็ม — ข้อมูลที่ต้อง "มีอยู่ครบเมื่อย้อนมาดู" ต้อง event_file

### Step 1 — สร้าง session แบบ event_file (จับ > 3 วินาที)

```sql
CREATE EVENT SESSION [XE_Sec2_LongRunning] ON SERVER
ADD EVENT sqlserver.sql_batch_completed
(
    ACTION ( sqlserver.sql_text, sqlserver.client_hostname, sqlserver.username )
    WHERE ( duration > 3000000
            AND sqlserver.database_name = N'AdventureWorks' )
)
ADD TARGET package0.event_file
(
    SET filename = N'XE_Sec2_LongRunning.xel',
        max_file_size = 25,
        max_rollover_files = 4
)
WITH ( MAX_MEMORY = 4096 KB,
       MAX_DISPATCH_LATENCY = 10 SECONDS,
       STARTUP_STATE = OFF );
GO
ALTER EVENT SESSION [XE_Sec2_LongRunning] ON SERVER STATE = START;
```

อ่านค่า target: `max_file_size` หน่วย **MB** — เมื่อไฟล์โตถึง 25 MB จะ **rollover** สร้างไฟล์ใหม่ต่อท้าย โดยลบไฟล์เก่าสุดทิ้งเมื่อเกิน `max_rollover_files = 4` ไฟล์ — กลไกนี้ทำให้ disk usage ถูกจองขั้นสูงสุดได้ (~25 × 4 = 100 MB) ไม่เคยกินดิสก์ไม่รู้จบ และ `filename` แบบไม่ระบุ path จะเขียนลง **LOG directory ของ instance** (โฟลเดอร์เดียวกับ error log — ตรวจแล้ว: `C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Log\`)

### Step 2 — ผลิต workload + อ่านไฟล์ .xel กลับมา

```sql
USE AdventureWorks;
GO
WAITFOR DELAY '00:00:04';
SELECT COUNT(*) FROM Sales.SalesOrderHeader;
GO
WAITFOR DELAY '00:00:12';   -- รอให้ครบ MAX_DISPATCH_LATENCY (10 วินาที)
GO
SELECT
    x.value('(event/@timestamp)[1]', 'DATETIME2')                          AS event_time,
    x.value('(event/@name)[1]', 'SYSNAME')                                 AS event_name,
    x.value('(event/data[@name="duration"]/value)[1]', 'BIGINT')/1000000.0 AS duration_s,
    x.value('(event/action[@name="username"]/value)[1]', 'SYSNAME')        AS [user],
    x.value('(event/action[@name="sql_text"]/value)[1]', 'NVARCHAR(MAX)')  AS sql_text
FROM sys.fn_xe_file_target_read_file('XE_Sec2_LongRunning*.xel', NULL, NULL, NULL) AS f
CROSS APPLY ( SELECT CAST(f.event_data AS XML) ) AS c(x)
ORDER BY event_time DESC;
GO
```

> [!IMPORTANT]
> **กติกา path ต่างจาก ring_buffer ตรงนี้เดียว:** `sys.fn_xe_file_target_read_file` คืนแถวละ 1 event ที่คอลัมน์ `event_data` (เป็น NVARCHAR) — แปลงเป็น XML แล้ว **root ของ XML คือตัว `<event>` เอง** จึงต้องเขียน path นำหน้าด้วย `event/` (`(event/@timestamp)`, `(event/data[...])`) ต่างจากการอ่านผ่าน `nodes()` ที่ bind ตรง `<event>` แล้ว และ wildcard `*.xel` ทำให้อ่านทุกไฟล์ rollover ในครั้งเดียว

**ผลจริงจากการทดสอบ:** จับได้ 1 event — `sql_batch_completed`, `duration_s = 4.009` (predicate > 3 วินาที ทำงานถูก), `[user] = <test login>`, ข้อความ SQL ตรงกับ batch ที่รัน

> [!TIP]
> ทั้งหมดนี้ทำซ้ำได้ผ่าน GUI: คลิกขวา session → Watch Live Data (ดูสด) หรือ View Target Data (ดู XML ของ target) — แต่ T-SQL เหนือกว่าตอนต้องย้ายข้อมูลมาวิเคราะห์ต่อ (sort, join กับ DMV อื่น, สร้าง report)

---

## 5. จับ Deadlock — สถานการณ์เดิมจาก Module 5 กับกล้องใหม่

Module 5 ผลิต deadlock ด้วย 2 หน้าต่างที่อัปเดตตารางสวนกัน (Product ↔ SalesOrderDetail) และเห็น error 1205 ทางฝั่ง engine — ตอนนั้นเราอธิบายไม่ได้ว่า "ใครถืออะไรอยู่ตอนชนกัน" นอกจาก error message วันนี้เรามี session รออยู่ก่อนแล้ว

### Step 1 — Session จับ deadlock graph

event `sqlserver.xml_deadlock_report` เกิดเมื่อ engine ตัดสินใจเลือก victim แล้ว — payload คือกราฟ deadlock ทั้งใบ:

```sql
CREATE EVENT SESSION [XE_Sec2_Deadlock] ON SERVER
ADD EVENT sqlserver.xml_deadlock_report
ADD TARGET package0.ring_buffer ( SET max_memory = 4096 )
WITH ( MAX_DISPATCH_LATENCY = 5 SECONDS, STARTUP_STATE = OFF );
GO
ALTER EVENT SESSION [XE_Sec2_Deadlock] ON SERVER STATE = START;
```

### Step 2 — ผลิต deadlock (2 หน้าต่าง — สคริปต์เดียวกับ Module 5)

```sql
-- หน้าต่าง A
USE AdventureWorks;
BEGIN TRAN;
UPDATE Production.Product SET ListPrice = ListPrice WHERE ProductID = 1;
WAITFOR DELAY '00:00:03';
UPDATE Sales.SalesOrderDetail SET OrderQty = OrderQty WHERE SalesOrderDetailID = 1;
COMMIT;
```

```sql
-- หน้าต่าง B — รันทันทีหลังหน้าต่าง A ขึ้นคำสั่งแรก
USE AdventureWorks;
BEGIN TRAN;
UPDATE Sales.SalesOrderDetail SET OrderQty = OrderQty WHERE SalesOrderDetailID = 1;
WAITFOR DELAY '00:00:03';
UPDATE Production.Product SET ListPrice = ListPrice WHERE ProductID = 1;
COMMIT;
```

หนึ่งในสองหน้าต่างจะได้ `Msg 1205 — Transaction ... has been chosen as the deadlock victim` (ทดสอบจริง: หน้าต่าง A เป็น victim)

### Step 3 — ดึงกราฟจาก ring_buffer

```sql
WAITFOR DELAY '00:00:06';
GO
SELECT
    x.value('(@timestamp)[1]', 'DATETIME2') AS deadlock_at,
    x.value('(data[@name="xml_report"]/value/deadlock/victim-list/victimProcess/@id)[1]', 'NVARCHAR(64)') AS victim_id,
    x.value('count((data[@name="xml_report"]/value/deadlock/process-list/process))', 'INT') AS process_count
FROM (
    SELECT CAST(target_data AS XML) AS buf
    FROM sys.dm_xe_session_targets AS t
    JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
    WHERE s.name = 'XE_Sec2_Deadlock' AND t.target_name = 'ring_buffer'
) AS d
CROSS APPLY buf.nodes('//event') AS n(x);
```

**ผลจริง:** ได้ 1 แถว — `victim_id = process1e6a...`, `process_count = 2` (สองฝ่ายที่ชนกันอยู่ในกราฟครบ)

เมื่อต้องการกราฟทั้งใบเพื่อเปิดดู (SSMS คลิก XML แล้วจะวาดเป็นภาพ Deadlock Graph ให้เอง) ใช้ `.query()` ซึ่งคืนชิ้น XML ทั้งก้อน ต่างจาก `.value()` ที่คืนค่าเดียว:

```sql
SELECT
    x.value('(@timestamp)[1]', 'DATETIME2') AS deadlock_at,
    x.query('(data[@name="xml_report"]/value/deadlock)[1]') AS deadlock_xml
FROM (
    SELECT CAST(target_data AS XML) AS buf
    FROM sys.dm_xe_session_targets AS t
    JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
    WHERE s.name = 'XE_Sec2_Deadlock' AND t.target_name = 'ring_buffer'
) AS d
CROSS APPLY buf.nodes('//event') AS n(x);
```

โครงกราฟที่ได้ (ส่วนสำคัญ): `<victim-list>` ระบุ victim, `<process-list>` มี 2 `<process>` พร้อม `<executionStack>` (statement ที่แต่ละฝ่ายกำลังรัน) และ `<resource-list>` (resource ที่ถือ/รอ) — ข้อมูลครบพอจะเขียน root cause ได้โดยไม่ต้องเดา

### Step 4 — ย้อนดู deadlock จาก system_health (เมื่อไม่มี session เอง)

จำจาก 9.1: `system_health` จับ deadlock อยู่แล้ว — ลองอ่านจาก ring_buffer ของมันก่อน (เร็ว):

```sql
SELECT
    x.value('(@timestamp)[1]', 'DATETIME2') AS deadlock_at,
    x.value('(data[@name="xml_report"]/value/deadlock/victim-list/victimProcess/@id)[1]', 'NVARCHAR(64)') AS victim_id
FROM (
    SELECT CAST(target_data AS XML) AS buf
    FROM sys.dm_xe_session_targets AS t
    JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
    WHERE s.name = N'system_health' AND t.target_name = 'ring_buffer'
) AS d
CROSS APPLY buf.nodes('//event[@name="xml_deadlock_report"]') AS n(x);
```

**ผลจริง:** 0 แถว — deadlock ของเราเกิดไปหลายนาทีแล้ว และ ring buffer 4 MB ของ system_health บน server ที่ busy ถูกเขียนทับเร็ว นี่คือบทเรียนสด ๆ ของ ring_buffer จาก 9.1 ทางแก้คืออ่านจาก **event_file** ของ system_health (เก็บใน LOG directory เหมือนกัน):

```sql
WITH FileEvents AS
(
    SELECT event_data
    FROM sys.fn_xe_file_target_read_file('system_health*.xel', NULL, NULL, NULL)
    WHERE event_data LIKE N'%xml_deadlock_report%'
)
SELECT
    ev.value('(@timestamp)[1]', 'DATETIME2') AS deadlock_at,
    ev.value('(data[@name="xml_report"]/value/deadlock/victim-list/victimProcess/@id)[1]', 'NVARCHAR(64)') AS victim_id,
    ev.value('count((data[@name="xml_report"]/value/deadlock/process-list/process))', 'INT') AS process_count
FROM FileEvents
CROSS APPLY ( SELECT CAST(event_data AS XML) AS x ) AS c
CROSS APPLY c.x.nodes('//event[@name="xml_deadlock_report"]') AS n(ev)
ORDER BY deadlock_at DESC;
```

**ผลจริงบน server ทดสอบ:** ได้ 7 deadlock ย้อนหลัง 2 วัน — ของเราและของผู้เรียนคนอื่นที่ใช้ server เดียวกัน ยืนยันว่าเทคนิคนี้ "ย้อนเวลา" ได้จริง (query นี้อ่านไฟล์ history ทั้งหมด — บน server ที่ busy อาจใช้เวลา 1–2 นาที จึงเหมาะเป็นงานตรวจย้อนหลัง ไม่ใช่ live watch)

---

## 6. จับ Blocking ยาว — blocked_process_report

โจทย์จาก Module 5: "อยากรู้ว่าใคร block ใคร นานเท่าไร ด้วย statement อะไร" — DMV (`sys.dm_exec_requests`) ให้ดูเฉพาะ "ตอนนี้" ส่วน XE event `blocked_process_report` จะเก็บรายงานทั้งใบ (ข้อมูล victim + blocker) ทุกครั้งที่มี process รอนานเกินค่าที่เรากำหนด

### Step 1 — ตั้งค่า threshold แล้วสร้าง session

event นี้ต้องมีการตั้ง **blocked process threshold** ก่อน (ค่า default = 0 คือปิด) — ตั้ง 3 วินาทีสำหรับเดโม:

```sql
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'blocked process threshold (s)', 3; RECONFIGURE;
GO
CREATE EVENT SESSION [XE_Sec2_Blocking] ON SERVER
ADD EVENT sqlserver.blocked_process_report
(
    ACTION ( sqlserver.sql_text, sqlserver.client_app_name, sqlserver.database_name )
)
ADD TARGET package0.ring_buffer ( SET max_memory = 4096 )
WITH ( MAX_DISPATCH_LATENCY = 5 SECONDS );
GO
ALTER EVENT SESSION [XE_Sec2_Blocking] ON SERVER STATE = START;
```

### Step 2 — ผลิต blocking (writer ต้อง block writer)

> [!IMPORTANT]
> AdventureWorks ใน environment ทดสอบ **เปิด RCSI** (เรื่องจาก Module 5) — SELECT จึงไม่ถูก writer block แล้ว event นี้จะไม่ยิง เดโมที่ทำงานแน่นอนคือ **UPDATE ต่อ UPDATE บนแถวเดียวกัน**

```sql
-- หน้าต่าง A (blocker) — ถือ X lock ค้างไว้ 20 วินาที
USE AdventureWorks;
BEGIN TRAN;
UPDATE Production.Product SET ListPrice = 99.99 WHERE ProductID = 1;
WAITFOR DELAY '00:00:20';
ROLLBACK;
```

```sql
-- หน้าต่าง B (victim) — รันหลัง A ประมาณ 3 วินาที จะค้างรอ
USE AdventureWorks;
UPDATE Production.Product SET ListPrice = 88.88 WHERE ProductID = 1;
```

ระหว่างค้าง ตรวจด้วย DMV แบบ Module 5: `SELECT session_id, blocking_session_id, wait_type, wait_time FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;` — ผลจริง: `wait_type = LCK_M_X` (ตัวเดียวกับตาราง wait ใน Module 1)

### Step 3 — อ่านรายงาน

```sql
SELECT
    x.value('(@timestamp)[1]', 'DATETIME2') AS reported_at,
    x.value('(data[@name="blocked_process"]/value/blocked-process-report/blocked-process/process/@waittime)[1]', 'BIGINT')/1000.0 AS blocked_wait_s,
    x.value('(data[@name="blocked_process"]/value/blocked-process-report/blocked-process/process/inputbuf)[1]', 'NVARCHAR(MAX)') AS blocked_input
FROM (
    SELECT CAST(target_data AS XML) AS buf
    FROM sys.dm_xe_session_targets AS t
    JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
    WHERE s.name = 'XE_Sec2_Blocking' AND t.target_name = 'ring_buffer'
) AS d
CROSS APPLY buf.nodes('//event') AS n(x);
```

**ผลจริง (threshold = 3 วินาที):** ได้ 2 รายงาน — `blocked_wait_s = 3.963` และ `6.975` (report ยิงซ้ำทุกช่วง threshold ตราบใดที่ยังถูก block) และ `blocked_input` โชว์ statement ของ victim เต็ม ๆ ในรายงาน XML ยังมีฝั่ง `<blocking-process>` ระบุ blocker ด้วย

### Step 4 — เก็บกวาดให้กลับสู่สภาพเดิม (สำคัญ!)

```sql
ALTER EVENT SESSION [XE_Sec2_Blocking] ON SERVER STATE = STOP;
DROP EVENT SESSION [XE_Sec2_Blocking] ON SERVER;
GO
EXEC sp_configure 'blocked process threshold (s)', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
```

> การตั้ง threshold ต่ำ (1–5 วิ) ตลอดเวลาบน production มีต้นทุน — lock monitor ต้องทำงานถี่ขึ้น วิธีที่พบบ่อยในงานจริงคือตั้ง threshold = 5 วินาทีค้างไว้กับ session ที่เก็บลง event_file (น้ำหนักเบาพอรับได้) หรือเปิดเฉพาะช่วงสืบสวน

---

## 7. TRACK_CAUSALITY — ร้อยเหตุการณ์ให้เป็นเรื่องเดียวกัน

ปัญหาของการจับเหตุการณ์หลายประเภทพร้อมกัน (เช่น `sql_batch_starting` + `sql_batch_completed` บน parallel plan): เหตุการณ์ของ request เดียวกันอาจถูกบันทึกโดย **thread ต่างกัน** ยากที่จะจับคู่ว่า "starting ตัวไหนจบด้วย completed ตัวไหน"

`TRACK_CAUSALITY = ON` ให้ engine ติด chain id (`attach_activity_id`) กับทุกเหตุการณ์ในสายเดียวกัน — เวลาอ่าน จัดกลุ่มด้วย id นี้ได้เลย:

```sql
CREATE EVENT SESSION [XE_Sec2_Causality] ON SERVER
ADD EVENT sqlserver.sql_batch_completed
(
    WHERE ( sqlserver.database_name = N'AdventureWorks' )
)
ADD TARGET package0.ring_buffer ( SET max_memory = 4096 )
WITH ( TRACK_CAUSALITY = ON, MAX_DISPATCH_LATENCY = 5 SECONDS );
GO
ALTER EVENT SESSION [XE_Sec2_Causality] ON SERVER STATE = START;
GO
USE AdventureWorks;
GO
SELECT COUNT(*) FROM Sales.SalesOrderHeader;
GO
WAITFOR DELAY '00:00:06';
GO
SELECT
    x.value('(@timestamp)[1]', 'DATETIME2')                                  AS event_time,
    x.value('(action[@name="attach_activity_id"]/value)[1]', 'NVARCHAR(64)') AS activity_id
FROM (
    SELECT CAST(target_data AS XML) AS buf
    FROM sys.dm_xe_session_targets AS t
    JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
    WHERE s.name = 'XE_Sec2_Causality' AND t.target_name = 'ring_buffer'
) AS d
CROSS APPLY buf.nodes('//event') AS n(x)
ORDER BY event_time;
GO
```

สองจุดที่ตรวจแล้วต้องระวัง: (1) action ที่ถูกติดมาชื่อ **`attach_activity_id`** — ไม่ใช่ `attached_activity_id` ดังในเอกสารบางที่ พิมพ์ผิดจะได้ NULL (2) แต่ละ batch ได้ chain ของตัวเอง — คุณค่าจริงเห็นเมื่อ request เดียวแตกข้าม thread/parallel หรือข้าม event หลายประเภท: id เดียวจะร้อยทั้งหมดไว้ด้วยกัน

---

## 8. Best Practices ระดับ Production

### 8.1 ควบคุม overhead ให้ต่ำด้วย "กรองให้แคบ"| หลัก | ทำไม |
|:-----|:-----|
| Predicate แคบที่สุดที่โจทย์ยอมให้ (`duration >`, `database_name =`) | กรองตั้งแต่จุดเกิดเหตุ — event ที่ไม่ผ่านไม่มีต้นทุนเก็บเลย |
| Action เอาเฉพาะที่จะใช้ | ทุก action คือการดึงสถานะ engine เพิ่ม ณ จุดเกิดเหตุ |
| เลี่ยง event แพง เช่น `query_post_execution_showplan` (ดึง actual plan ทุก query) | ถ้าต้องการข้อมูล plan ใช้ event ตระกูล lightweight profiling แทน (`query_post_execution_plan_profile` / `query_thread_profile`) |
| 1 session = 1 โจทย์ | แยก session ตามงาน — กรองแคบลง ปิดเมื่อจบ ตรวจสอบได้ง่าย |

### 8.2 ค่าตั้งที่แนะนำ (จากทุก session ใน section นี้)

- `MAX_MEMORY = 4096 KB` — เพดาน buffer ต่อ session ต่ำแต่พอ (server รับได้หลาย session พร้อมกัน)
- `MAX_DISPATCH_LATENCY = 5 SECONDS` (ring_buffer) / `10 SECONDS` (event_file) — ยิ่งต่ำ ยิ่งเสี่ยงสูญน้อยเมื่อ crash แต่ dispatcher ตื่นบ่อยขึ้น
- event_file เสมอระบุ `max_file_size` + `max_rollover_files` — จำกัด disk usage สูงสุดให้คำนวณได้ล่วงหน้า
- `STARTUP_STATE = ON` เฉพาะ session ที่ต้องมีชีวิตข้าม restart (เช่น deadlock monitor ของ production)

### 8.3 เฝ้าสุขภาพ session — รู้ทัน event ที่ถูกทิ้ง

```sql
SELECT
    s.name AS session_name,
    s.total_buffer_size / 1024 AS buffer_kb,
    s.buffer_policy_desc,
    s.dropped_event_count
FROM sys.dm_xe_sessions AS s
WHERE s.name = 'XE_Sec2_SlowQueries';   -- แทนชื่อด้วย session ที่กำลังรัน
GO
SELECT
    t.target_name,
    t.execution_count,
    t.used_memory / 1024 AS used_memory_kb,
    t.failed_buffer_count
FROM sys.dm_xe_session_targets AS t
JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
WHERE s.name = 'XE_Sec2_SlowQueries';
GO
```

อ่านค่า: `dropped_event_count` โต = buffer กดดันจนต้องทิ้ง event (ผลการทดสอบจริง = 0 เพราะ session ของเรากรองแคบ) — แก้ด้วยการกรองแคบลง เพิ่ม MAX_MEMORY หรือลด action ส่วน `failed_buffer_count` ฝั่ง target คือ buffer ที่ส่งไป target ไม่สำเร็จ

### 8.4 Session มีอายุ — "ไม่มี AUTO_STOP" จริง ๆ

XEvents ไม่มีออปชันให้ session "หมดเวลาแล้วปิดเอง" — พิสูจน์แล้วบน 17.0.1135.8 ว่าแบบนี้ล้มทันที:

```text
CREATE EVENT SESSION [XE_Timed] ON SERVER
ADD EVENT sqlserver.sql_batch_completed
ADD TARGET package0.ring_buffer
WITH ( AUTO_STOP = ON );          -- Incorrect syntax near 'AUTO_STOP'
```

วิธีจริงคือคุมอายุด้วย SQL Agent job (หรือคำสั่งปกติเมื่อจบงาน) — สร้าง job ที่รันคำสั่งเดียวนี้ตามเวลาที่กำหนด:

```sql
-- ตัวอย่าง: ปิด session เมื่อหมดช่วงเก็บ (ใส่ไว้ใน SQL Agent job)
ALTER EVENT SESSION [XE_Sec2_SlowQueries] ON SERVER STATE = STOP;
DROP EVENT SESSION [XE_Sec2_SlowQueries] ON SERVER;
```

### 8.5 โน้ตฝั่ง Azure SQL

บน Azure SQL Database ไม่มี drive ท้องถิ่นให้เขียน `.xel` — `filename` ของ event_file ต้องเป็น path ของ **Azure Storage blob** (`https://...blob.core.windows.net/...`) แล้วดาวน์โหลดไฟล์กลับมาเปิดใน SSMS เครื่องเราได้ — โครง session/predicate/action ที่เรียนทั้งหมดใช้ได้เหมือนเดิม

---

## Cleanup — ปิด session ทั้งหมดของ section นี้

```sql
ALTER EVENT SESSION [XE_Sec2_SlowQueries] ON SERVER STATE = STOP;
ALTER EVENT SESSION [XE_Sec2_ErrorsHist]  ON SERVER STATE = STOP;
ALTER EVENT SESSION [XE_Sec2_Counter]     ON SERVER STATE = STOP;
ALTER EVENT SESSION [XE_Sec2_LongRunning] ON SERVER STATE = STOP;
ALTER EVENT SESSION [XE_Sec2_Deadlock]    ON SERVER STATE = STOP;
ALTER EVENT SESSION [XE_Sec2_Blocking]    ON SERVER STATE = STOP;
ALTER EVENT SESSION [XE_Sec2_Causality]   ON SERVER STATE = STOP;
GO
DROP EVENT SESSION [XE_Sec2_SlowQueries] ON SERVER;
DROP EVENT SESSION [XE_Sec2_ErrorsHist]  ON SERVER;
DROP EVENT SESSION [XE_Sec2_Counter]     ON SERVER;
DROP EVENT SESSION [XE_Sec2_LongRunning] ON SERVER;
DROP EVENT SESSION [XE_Sec2_Deadlock]    ON SERVER;
DROP EVENT SESSION [XE_Sec2_Blocking]    ON SERVER;
DROP EVENT SESSION [XE_Sec2_Causality]   ON SERVER;
GO
-- ตรวจว่าเหลือแต่ของระบบ
SELECT s.name FROM sys.dm_xe_sessions AS s ORDER BY s.name;
```

---

## สรุป Section 9.2

1. โครง session = event (+predicate, +action) → target (+SET) → WITH (นโยบาย) — เลือก target ตามโจทย์: ดูสดใช้ `ring_buffer`, ต้อง retention ใช้ `event_file`, นับกลุ่มใช้ `histogram`, นับรวมใช้ `event_counter`
2. การอ่านผลมีสองแบบที่ path ต่างกัน: ผ่าน `nodes()` = path **สัมพัทธ์กับ `<event>`**; ผ่าน `fn_xe_file_target_read_file` = ต้องนำหน้าด้วย `event/` — และ XQuery case-sensitive (`<Slot>`, `<Event>`, `attach_activity_id`)
3. deadlock จับได้ทั้งจาก session เองและจาก `system_health` (ring_buffer เร็วแต่ถูกเขียนทับ / event_file เก็บย้อนหลังได้จริง) — กราฟมี victim, execution stack และ resource ครบ (ปิดโจทย์จาก Module 5)
4. `blocked_process_report` ต้องตั้ง `blocked process threshold (s)` ก่อน และบน DB ที่เปิด RCSI ต้องใช้ writer-writer เท่านั้นจึงจะเห็นการ block
5. Production = กรองแคบ, action น้อย, event_file มี rollover, `STARTUP_STATE` ตามความจำเป็น, คุมอายุ session ด้วย Agent job (ไม่มี AUTO_STOP) และเฝ้า `dropped_event_count` เสมอ

### ตรวจความเข้าใจ

1. Session ในหัวข้อ 2 จับ `WAITFOR DELAY` ของตัวเองด้วย — จะแก้ predicate อย่างไรให้ไม่รวมคำสั่งยูทิลิตี้แบบนี้ (ให้นึกถึง payload `statement` และเงื่อนไข `NOT LIKE`)?
2. ทำไม path `(data[@name="duration"]/value)` ใน ring_buffer ถึงเขียนเป็น `(event/data[...])` ไม่ได้ แต่ตอนอ่านไฟล์ .xel กลับต้องมี `event/` นำหน้า?
3. `duration = 1310 ms` แต่ `cpu_time = 296 ms` — ระยะห่าง 1,000 มิลลิวินาทีนั้น SQL Server กำลังทำอะไรอยู่ และเชื่อมกับ wait type ใดจาก Module 1?
4. เหตุใดการอ่าน deadlock จาก `system_health` แบบ ring_buffer อาจได้ 0 แถว แม้ deadlock เกิดขึ้นจริงเมื่อครู่ — และ event_file ทำอะไรที่ ring_buffer ทำไม่ได้?
5. บน AdventureWorks ที่เปิด RCSI ทำไมเดโม blocking ต้องใช้ UPDATE ต่อ UPDATE — ถ้าอยากให้ SELECT ถูก block จะต้องเปลี่ยนอะไร (เทียบ Module 5)?
6. ค่าตั้งใดบอกว่า session ของคุณ "เริ่มทิ้ง event แล้ว" — และเมื่อเจอแล้วควรแก้ด้วยวิธีใดบ้าง (อย่างน้อย 2 ทาง)?

**➡ ถัดไป:** [Module 10 — Monitoring & Baselines](../../Module_10_Monitoring_Tracing/README.md) · [📋 Quiz Bank](../../Quiz_Bank.md)

---

[⬅ ก่อนหน้า: 9.1 XE Core Concepts](../01_XE_Core_Concepts/README.md) | [🧪 Labs](../../Labs/README.md) | [Module 09 Overview](../../README.md)
