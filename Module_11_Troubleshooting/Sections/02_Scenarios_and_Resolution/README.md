[⬅ Module 11](../../README.md) | [⬅ ก่อนหน้า: 01 Troubleshooting Workflow](../01_Troubleshooting_Workflow/README.md) | Section 2/2

# 11.2 Scenarios and Resolution — 6 สถานการณ์จริงจากหน้างาน

> *"ปัญหาทุกเคสเล่าเรื่องเดียวกัน: อาการที่ผู้ใช้เห็น กับสาเหตุที่ server เจอ มักไม่ได้อยู่ชั้นเดียวกัน — หน้าที่เราคือไต่จากอาการลงสู่สาเหตุด้วยหลักฐาน"*

> **ต้องรู้มาก่อน**: Section นี้ใช้กรอบ Top-down จาก [Section 11.1](../01_Troubleshooting_Workflow/README.md) และความรู้จาก Module 1–10 ทุก query ในหน้านี้ **ทดสอบรันจริง** บน SQL Server 2025 (17.0.1135.8) + AdventureWorks (เปิด RCSI + Query Store) ตามเงื่อนไขแล็บของหลักสูตร
> ศัพท์เทคนิคที่ไม่คุ้นเปิดดูได้จาก [Glossary](../../../Glossary.md)

---

## วิธีอ่าน Section นี้

ทุก scenario เล่าด้วยโครงเดียวกัน: **อาการ (ที่ผู้แจ้งเห็น) → วินิจฉัย (query รันได้) → แก้ (mitigate + root fix) → วัดซ้ำ (พิสูจน์ว่าดีขึ้น)** จำโครงนี้ให้ขึ้นใจ — ตอนเกิด incident จริง คุณจะไม่มีเวลาคิดว่า "เริ่มจากอะไรดี"

| # | Scenario | Wait ตัวร้ายหลัก | บทเรียนจากโมดูล |
|:--|:---------|:------------------|:------------------|
| 1 | ช้าเฉพาะบางเวลา | (ต้องพิสูจน์) | Query Store — M8/M10 |
| 2 | CPU สูง แต่ waits บอกอย่างอื่น | ขึ้นกับผลจริง | Waits/CPU — M1 |
| 3 | Blocking ตีน้ำแข็ง | `LCK_M_*` | Concurrency — M5 |
| 4 | Memory pressure | `RESOURCE_SEMAPHORE` | Memory — M4 |
| 5 | Plan regression (เคยเร็ว วันนี้ช้า) | ตัวใดก็ได้ | Plans/QS — M7/M8 |
| 6 | I/O latency + micro-transactions | `PAGEIOLATCH_*` / `WRITELOG` | I/O + WAL — M2/M3 |

> ทุกตัวเลข "อ้างอิงรันจริง" ด้านล่างมาจากเซิร์ฟเวอร์หลักสูตร (มีคนอื่นใช้ร่วมด้วย เลขจะไม่ตรงเป๊ะเมื่อคุณรันเอง แต่**รูปแบบของผลลัพธ์**คือสิ่งที่ต้องจำ)

---

## Scenario 1: ช้าเฉพาะบางเวลา (Intermittent Slowness)

### อาการ

"ระบบช้าเฉพาะตอนเช้า ๆ บ่ายก็ปกติ" — คุณเปิด `sys.dm_exec_requests` ตอนบ่ายว่าง: ไม่มีอะไรผิดปกติ ปิด ticket? **ไม่ได้** — ปัญหาชนิดนี้พิสูจน์ไม่ได้ด้วยการมอง "ตอนนี้" ต้องใช้ข้อมูล**ย้อนเวลา** และเครื่องมือที่จดประวัติไว้ให้แล้วคือ Query Store (Module 8/10)

### วินิจฉัย

ขั้น 1: ถาม Query Store ว่า "ช่วงเวลาไหนแย่สุด" — จัดอันดับ interval:

```sql
-- Query Store: ช่วงเวลา (interval) ที่ระบบแย่สุด — ตอบคำถาม "ช้าเฉพาะบางเวลา"
SELECT TOP (5)
       rsi.start_time, rsi.end_time,
       CAST(AVG(rs.avg_duration) / 1000.0 AS DECIMAL(10,1)) AS avg_duration_ms,
       SUM(rs.count_executions) AS executions
FROM sys.query_store_runtime_stats AS rs
JOIN sys.query_store_runtime_stats_interval AS rsi
    ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
GROUP BY rsi.start_time, rsi.end_time
ORDER BY AVG(rs.avg_duration) DESC;
```

อ้างอิงรันจริง: interval แย่สุดคือ `06:00–06:30` (avg_duration ~3,019 ms จาก 46 executions) ขณะที่ช่วงว่างอื่นเหลือร้อยถึงหลักร้อย ms — เห็นไหมว่า "บางเวลา" กลายเป็นตัวเลขที่พิสูจน์ได้แล้ว

ขั้น 2: จับตัวร้ายใน interval นั้น:

```sql
-- Query Store: ในช่วงเวลาที่แย่สุด — query ใดโทษมากสุด
DECLARE @worst_start DATETIME2 =
(
    SELECT TOP (1) rsi.start_time
    FROM sys.query_store_runtime_stats AS rs
    JOIN sys.query_store_runtime_stats_interval AS rsi
        ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
    GROUP BY rsi.start_time
    ORDER BY AVG(rs.avg_duration) DESC
);

SELECT TOP (5)
       q.query_id, LEFT(qt.query_sql_text, 70) AS query_text,
       CAST(AVG(rs.avg_duration) / 1000.0 AS DECIMAL(10,1)) AS avg_duration_ms,
       CAST(AVG(rs.avg_cpu_time) / 1000.0 AS DECIMAL(10,1)) AS avg_cpu_ms,
       SUM(rs.count_executions) AS executions
FROM sys.query_store_runtime_stats AS rs
JOIN sys.query_store_runtime_stats_interval AS rsi
    ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
JOIN sys.query_store_plan AS p ON p.plan_id = rs.plan_id
JOIN sys.query_store_query AS q ON q.query_id = p.query_id
JOIN sys.query_store_query_text AS qt ON qt.query_text_id = q.query_text_id
WHERE rsi.start_time = @worst_start
GROUP BY q.query_id, LEFT(qt.query_sql_text, 70)
ORDER BY AVG(rs.avg_duration) DESC;
```

อ้างอิงรันจริง: ผู้ร้ายใน interval แย่สุดคือ query `SELECT * FROM Sales.SalesOrderDetail CROSS JOIN (VALUES ...)` (avg ~50 วินาที) — คือ chaos query ของแล็บนี้เอง ที่สตรีมผลใหญ่ผ่าน WAN

### แก้

- **Mitigate**: ตามชนิดของตัวร้าย (ดู scenario ที่เกี่ยวข้องด้านล่าง)
- **Root fix ของ "ช้าเป็นช่วง"**: หาสิ่งที่มาตารงเวลากับช่วงช้า — job รายงาน, batch คำนวณยอด, backup schedule, auto-grow ของไฟล์ แล้วย้ายเวลา/แยก workload หรือจูน query ตัวนั้นโดยเฉพาะ

### วัดซ้ำ

รัน query ขั้น 1 ซ้ำในอีกสองสามวัน — interval ที่เคยแย่ต้องกลับมาใกล้ baseline (เก็บเทียบด้วย `DBA_Baseline` จาก Lab 10 ถ้ามี)

---

## Scenario 2: CPU สูง แต่ Waits บอกอย่างอื่น

### อาการ

Task Manager โชว์ CPU 90%+ ฝ่าย Infra ทวงให้ scale-up ทันที แต่คุณ (จาก Module 1) รู้ว่า **CPU สูงไม่ได้แปลว่า CPU คือคอขวด** — signal wait อาจต่ำ (CPU ว่างพอ) และ top wait อาจชี้ไปที่ I/O หรือ client

### วินิจฉัย

ขั้น 1: ดู CPU ย้อนหลังจาก ring buffer — ไม่ต้องติดตั้งอะไร:

```sql
-- CPU ย้อนหลัง ~5 นาที จาก ring buffer (ไม่ต้องติดตั้งอะไร)
SELECT TOP (10)
       DATEADD(ms, -1 * (ts_now - [timestamp]), GETDATE()) AS event_time,
       SQLProcessUtilization AS sql_cpu_pct,
       100 - SystemIdle - SQLProcessUtilization AS other_cpu_pct
FROM
(
    SELECT CONVERT(xml, record) AS record,
           [timestamp],
           cpu_ticks / (cpu_ticks / ms_ticks) AS ts_now
    FROM sys.dm_os_ring_buffers
    CROSS JOIN sys.dm_os_sys_info
    WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
      AND record LIKE '%<SystemHealth>%'
) AS x
CROSS APPLY
(
    SELECT x.record.value('(./Record/@id)[1]', 'int') AS record_id,
           x.record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS SystemIdle,
           x.record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS SQLProcessUtilization
) AS y
ORDER BY y.record_id DESC;
```

อ้างอิงรันจริง: SQL CPU ~2–6% ทั้ง 10 นาที (`other_cpu_pct` ราว 3–11% คือกระบวนการอื่นของ OS) — ตัวเลขนี้บอกได้ทันทีว่า "CPU สูง" ที่แจ้งมาคือช่วงไหน และเป็นฝั่ง SQL หรือ OS

ขั้น 2: เทียบกับ delta waits (บล็อก delta 15 วินาที ใน Section 11.1 Step 1.2) และตัวร้ายระดับ statement:

```sql
-- ชั้น Query: top plan cache ตาม CPU + logical reads
SELECT TOP (10)
       qs.total_worker_time / 1000 AS cpu_ms,
       qs.total_logical_reads AS logical_reads,
       qs.execution_count,
       LEFT(st.text, 80) AS query_text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY qs.total_worker_time DESC;
```

### ตีความ — 3 แบบที่เจอบ่อย

| ผลที่ได้ | แปลว่า | ทิศทาง |
|:----------|:--------|:--------|
| SQL CPU สูง + `SOS_SCHEDULER_YIELD` โดด + signal wait > 10–15% | CPU pressure จริง — query เปลือง (scan ยักษ์, คำนวณหนัก) หรือ concurrency แย่ | จูน top CPU query (M7) · เช็ค MAXDOP/CTFP (M8) · ค่อยพูดเรื่อง scale-up |
| SQL CPU ต่ำ/ปานกลาง แต่ OS CPU สูง | ความดันอยู่นอก SQL (backup AV scan, กระบวนการอื่น) | ไม่ใช่หน้าที่จูน query — แจ้งฝั่ง Infra พร้อมหลักฐานตารางนี้ |
| Top wait เป็น `ASYNC_NETWORK_IO` / `PAGEIOLATCH_*` แทน | CPU แค่ "ทำงานหนักเพราะส่ง/อ่านข้อมูลมหาศาล" — ต้นเหตุอยู่ที่ result set ยักษ์หรือ logical reads | ไปตาม scenario 1/4/6 — ซื้อ CPU จะไม่แก้ |

> [!IMPORTANT]
> นี่คือเคสที่หลักสูตรอยากฝังให้แนบสมอง: **"CPU สูง" เป็นอาการ ไม่ใช่การวินิจฉัย** — waits เท่านั้นที่บอกว่า CPU นั้นทำงานเพื่ออะไร

### แก้ + วัดซ้ำ

แก้ตามทิศทางในตาราง แล้วรัน ring buffer ซ้ำ + delta waits ซ้ำ: SQL CPU % และ signal ratio ต้องลดลง ส่วน `other_cpu_pct` ถ้ายังสูง = โทษไม่ใช่ SQL

---

## Scenario 3: Blocking ตีน้ำแข็ง (Head Blocker)

### อาการ

หน้าจอธุรกรรมขาย "หมุนวน" ทั้งแผนก — log ของ app โชว์ timeout เพิ่มขึ้นพร้อมกัน เปิด Activity Monitor: "Head Blocker" มีตัวเดียว ลากรายงานได้หลายสิบ session นี่คือลูกโซ่ blocking (Module 5) ในรูปแบบแย่สุด

### วินิจฉัย

ขั้น 1: ดูแถวที่ถูก block — ใครรอนานสุด รอ resource อะไร:

```sql
-- แถวที่ถูก block ตอนนี้: ใครรอนานสุด รอ resource อะไรอยู่
SELECT r.session_id, r.blocking_session_id, r.wait_type,
       r.wait_time / 1000.0 AS wait_s,
       r.wait_resource, r.command, r.status,
       LEFT(t.text, 60) AS running_sql
FROM sys.dm_exec_requests AS r
JOIN sys.dm_exec_sessions AS s
    ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.blocking_session_id <> 0
ORDER BY r.wait_time DESC;
```

ขั้น 2: ยืนยันว่า lock นั้นถือจริงโดยใคร (ระดับ resource):

```sql
-- Lock ที่ถือ/รออยู่จริง ต่อ resource (ของผู้เกี่ยวข้องในลูกโซ่เท่านั้น)
SELECT l.request_session_id,
       DB_NAME(l.resource_database_id) AS database_name,
       l.resource_type, l.request_mode, l.request_status
FROM sys.dm_tran_locks AS l
WHERE l.request_session_id IN
      (SELECT blocking_session_id
       FROM sys.dm_exec_requests WHERE blocking_session_id <> 0
       UNION
       SELECT session_id
       FROM sys.dm_exec_requests WHERE blocking_session_id <> 0)
ORDER BY l.request_session_id, l.resource_type;
```

อ่านผล: session ที่มี `request_status = GRANT` พร้อม `request_mode = X` และไม่ได้ถูกใคร block คือ **head blocker ตัวจริง** — จับคู่กับผลขั้น 1 และเช็ค `open_transaction_count` ของมัน

### แก้

- **Mitigate**: KILL head blocker ด้วยบล็อกที่ผ่านการทดสอบแล้วใน [Section 11.1 — Step 4](../01_Troubleshooting_Workflow/README.md) (ระบุ session จาก marker + open transaction ก่อนเสมอ) — ลูกโซ่คลายทันที, victim ทุกตัวรันต่อจนเสร็จ, transaction ค้างถูก rollback อัตโนมัติ (อ้างอิงรันจริง: victim ที่รอ `LCK_M_X` ~20.7 วินาทีเสร็จภายใน 4 ms หลัง KILL, `still_blocked = 0`, ข้อมูลไม่เสียหาย)
- **Root fix** — ตามสาเหตุเชิงลึก:
  - app เปิด tran แล้วลืม COMMIT / idle connection ถือ lock → แก้ pattern ของ app, ตั้ง connection timeout, พิจารณา `blocked process threshold` + XEvent `blocked_process_report` (วิธีติดตั้งอยู่ใน Module 9 — แล็บนี้ไม่แตะ XE session)
  - query ของ head blocker ช้าเพราะ plan/index → จูนตัวมัน (Scenario 5) ให้ "ถือ lock สั้นลง"
  - reader/writer ขัดกันรุนแรง → พิจารณา RCSI (AdventureWorks ของหลักสูตรเปิดอยู่แล้ว — จำไว้ว่า SELECT ธรรมดาไม่ถูก block จึงเหลือแต่ writer-vs-writer กับ schema locks)

### วัดซ้ำ

รันขั้น 1 ซ้ำ: `still blocked = 0` และทวนรอบหา open transaction ค้าง (บล็อกลูกโซ่ใน Section 11.1 Step 2a) — ถ้าเกิดซ้ำเป็นจังหวะ ใช้ Scenario 1 หาตารงเวลา

---

## Scenario 4: Memory Pressure / RESOURCE_SEMAPHORE

### อาการ

Query รายงานบางตัว "ช้าแบบไม่มีเหตุผล" — plan เหมือนเดิม, data เท่าเดิม แต่ duration โดดขึ้น เปิด waits เจอ `RESOURCE_SEMAPHORE` โดดขึ้นเป็นอันดับต้น (จาก delta waits ใน Section 11.1) แปลว่า: query ต่อคิว**รอ memory grant** เพราะตัวอื่นกินไปก่อน

### วินิจฉัย

ขั้น 1: ดู grant ค้างและสถานะ buffer pool (ชุดเครื่องมือจาก Section 11.1 Step 2b — `Memory Grants Pending` > 0 คือหลักฐานตรง) ขั้น 2: พิสูจน์ด้วยเดโมเรันได้ — sort แบบ "กว้าง" (CAST เป็น `NVARCHAR(MAX)`) กับแบบ "เล็ก" แล้วเทียบ grant จาก plan cache:

```sql
-- ตัวแสดงพฤติกรรม (A): sort คอลัมน์กว้าง — ขอ grant ยักษ์
USE AdventureWorks;
SELECT SalesOrderDetailID,
       CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS NVARCHAR(MAX)) AS pad
FROM Sales.SalesOrderDetail
WHERE SalesOrderDetailID <= 5000
ORDER BY pad DESC;   -- M11MEMDEMO_A
```

```sql
-- ตัวแสดงพฤติกรรม (B): ส่งค่าเลขเดิม — ไม่แตะ NVARCHAR(MAX)
USE AdventureWorks;
SELECT SalesOrderDetailID,
       ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
FROM Sales.SalesOrderDetail
WHERE SalesOrderDetailID <= 5000
ORDER BY rn DESC;   -- M11MEMDEMO_B
```

```sql
-- เทียบ memory grant ของสองเวอร์ชัน จาก plan cache
SELECT LEFT(st.text, 46) AS query_text,
       qs.execution_count,
       qs.total_grant_kb / qs.execution_count AS avg_grant_kb,
       qs.total_used_grant_kb / qs.execution_count AS avg_used_kb
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE st.text LIKE '%M11MEMDEMO' + '_%'
  AND st.text LIKE '%FROM Sales.SalesOrderDetail%'
ORDER BY avg_grant_kb DESC;
```

อ้างอิงรันจริง: เวอร์ชัน A ได้ grant ~28,296 KB แต่ใช้จริง ~432 KB (**over-grant สิบกว่าเท่า**) ส่วน B ได้ ~1,104 KB ใช้ ~296 KB — รุ่นเต็ม (ทั้งตาราง 121k แถว) ของแล็บขอ grant ถึง ~700,960 KB โดยใช้จริง ~24,320 KB ตาม Expected ของ Lab 11 และทุก KB ที่ A ยืมไปคือ buffer pool ที่ query อื่นเสียสิทธิ์

### แก้

- **Mitigate**: หยุด/จำกัด query grant ยักษ์หน้างาน (resource governor ถ้ามี, กั้น schedule)
- **Root fix**: ลด "ความกว้าง" ที่ต้อง sort — เลือกเฉพาะคอลัมน์ที่ใช้, ไม่ CAST เป็น MAX โดยไม่จำเป็น, สร้าง index ที่ทำให้ Sort operator หายไปเลย (M6), อัปเดต statistics ให้ estimate แม่น (M6) — และถ้า over-grant จาก parameter sniffing ให้เข้า Scenario 5

### วัดซ้ำ

รันบล็อกเทียบ grant ซ้ำ: grant ของ query หลังแก้ต้องเข้าใกล้ `used` มากขึ้น และ delta waits ต้องไม่มี `RESOURCE_SEMAPHORE` โดดอีก

---

## Scenario 5: Plan Regression — เคยเร็ว วันนี้ช้า

### อาการ

"อัปเดตเวอร์ชันแล้ว/พอดี ๆ ไม่ได้แตะอะไร แต่ query ช้าลง 10 เท่า" — สงสัยได้เลยว่า **Plan เปลี่ยน** (สถิติ auto-update, parameter sniffing, new plan จาก data ใหม่) Query Store คือกล้องส่องทางไกลของเคสนี้ (Module 8)

### วินิจฉัย

ขั้น 1: หา query ที่มีมากกว่าหนึ่ง plan และช่วงช้า-เร็วต่างกันมาก:

```sql
-- Query Store: query ที่มีหลาย Plan และทำงานช้าลง (ผู้สงสัยหลักของ plan regression)
SELECT TOP (5)
       q.query_id,
       COUNT(DISTINCT p.plan_id) AS plan_count,
       SUM(rs.count_executions) AS total_executions,
       CAST(MIN(rs.avg_duration) / 1000.0 AS DECIMAL(10,1)) AS best_avg_ms,
       CAST(MAX(rs.avg_duration) / 1000.0 AS DECIMAL(10,1)) AS worst_avg_ms
FROM sys.query_store_query AS q
JOIN sys.query_store_plan AS p ON p.query_id = q.query_id
JOIN sys.query_store_runtime_stats AS rs ON rs.plan_id = p.plan_id
GROUP BY q.query_id
HAVING COUNT(DISTINCT p.plan_id) > 1
ORDER BY MAX(rs.avg_duration) - MIN(rs.avg_duration) DESC;
```

ขั้น 2: เจาะ query_id ที่สงสัย — เทียบ plan ต่อ plan:

```sql
-- เจาะ query_id ที่สงสัย: เทียบ Plan ต่อ Plan (รันทับ query_id จริงที่ได้จากขั้นก่อน)
DECLARE @qid BIGINT =
(
    SELECT TOP (1) q.query_id
    FROM sys.query_store_query AS q
    JOIN sys.query_store_plan AS p ON p.query_id = q.query_id
    JOIN sys.query_store_runtime_stats AS rs ON rs.plan_id = p.plan_id
    GROUP BY q.query_id
    HAVING COUNT(DISTINCT p.plan_id) > 1
    ORDER BY MAX(rs.avg_duration) - MIN(rs.avg_duration) DESC
);

SELECT p.plan_id, p.is_forced_plan,
       CAST(AVG(rs.avg_duration) / 1000.0 AS DECIMAL(10,1)) AS avg_duration_ms,
       CAST(AVG(rs.avg_cpu_time) / 1000.0 AS DECIMAL(10,1)) AS avg_cpu_ms,
       SUM(rs.count_executions) AS executions,
       p.last_compile_start_time
FROM sys.query_store_plan AS p
JOIN sys.query_store_runtime_stats AS rs ON rs.plan_id = p.plan_id
WHERE p.query_id = @qid
GROUP BY p.plan_id, p.is_forced_plan, p.last_compile_start_time
ORDER BY avg_duration_ms;
```

อ้างอิงรันจริง: query 977 มี 2 plan — ตัวเร็ว avg 0.1 ms รัน 7 ครั้ง ตัวช้า 228.3 ms รัน 1 ครั้ง (compile เวลาเดียวกัน) — ภาพ regression ชัดเจนว่า "plan ใหม่แพ้ plan เก่า"

### แก้

- **Mitigate (ทันทีแต่ควรระวัง)**: force plan เร็วด้วย `EXEC sp_query_store_force_plan @query_id, @plan_id;` — คำสั่งนี้แก้ catalog ของ Query Store จริง จึง**ไม่รันในหน้านี้** ให้ฝึกใน Lab 8 (และมี `sp_query_store_unforce_plan` สำหรับคืนค่าเสมอ)
- **Root fix**: เข้าใจว่าทำไม plan ใหม่ถึงเกิด — statistics กระโดด (อัปเดตแบบคุม), parameter sniffing (OPTION(RECOMPILE) เฉพาะ query / OPTIMIZE FOR), หรือ index ใหม่/ใหม่หมด (M6–M8) แล้วแก้ที่ต้นเหตุแทนการปลอมด้วย force เฉย ๆ

### วัดซ้ำ

หลังแก้: รันขั้น 1 ซ้ำ — `worst_avg_ms` ของ query ที่จูนต้องลด; ถ้าใช้ force plan เฝ้าดู `is_forced_plan = 1` ว่ายังชี้ plan ที่ถูกและติดตามว่า workload ใหม่ไม่ทำให้ force กลายเป็นพิษ

---

## Scenario 6: I/O Latency + Micro-transactions (WRITELOG)

### อาการ

ระบบ OLTP "สะดุด" ตอนคีย์ข้อมูลถี่ ๆ — แต่ละ transaction เล็กมากแต่ duration มีค่า log flush รวมกันแพง Waits โชว์ `WRITELOG` (รอ log harden) หรือ `PAGEIOLATCH_*` (รอหน้าจาก disk)

### วินิจฉัย

ขั้น 1: latency ต่อไฟล์ (ชุดเต็มอยู่ Section 11.1 Step 2b) — เจาะเฉพาะไฟล์ LOG สำหรับ WRITELOG:

```sql
-- I/O latency เฉพาะไฟล์ LOG — WRITELOG ชี้มาที่นี่ (เกณฑ์: log write < 5 ms)
SELECT DB_NAME(vfs.database_id) AS database_name,
       mf.name AS logical_name,
       vfs.num_of_writes,
       CAST(vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) AS DECIMAL(10,1)) AS avg_log_write_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
JOIN sys.master_files AS mf
    ON mf.database_id = vfs.database_id AND mf.file_id = vfs.file_id
WHERE mf.type_desc = N'LOG'
ORDER BY avg_log_write_ms DESC;
```

ขั้น 2: พิสูจน์ผลของ micro-transaction ด้วยเดโมจริง (ไม่เกิน ~2 วินาที, ไม่เปลี่ยนข้อมูล):

```sql
-- จำลอง micro-transaction storm: commit ถี่ ๆ = log flush ถี่ ๆ = WRITELOG
-- (อัปเดต "ค่าเดิม" — ไม่เปลี่ยนข้อมูล; ใช้เวลาไม่เกิน ~30 วินาที)
SET NOCOUNT ON;
DECLARE @i INT = 0, @t0 BIGINT, @t1 BIGINT;
SELECT @t0 = wait_time_ms FROM sys.dm_os_wait_stats WHERE wait_type = N'WRITELOG';

WHILE @i < 1500
BEGIN
    UPDATE Production.ProductInventory
    SET Quantity = Quantity          -- ค่าเดิม: สาธิตเฉพาะ log flush
    WHERE ProductID = 1;
    SET @i += 1;
END

SELECT @t1 = wait_time_ms FROM sys.dm_os_wait_stats WHERE wait_type = N'WRITELOG';
SELECT @t1 - @t0 AS writelog_ms_added,
       CAST((@t1 - @t0) / 1500.0 AS DECIMAL(10,2)) AS avg_flush_ms;
```

อ้างอิงรันจริง: `writelog_ms_added` ~902 ms / 1500 commits = **~0.6 ms ต่อ flush** — นี่คือ "ราคา" ของ transaction เดียว บน storage ช้าที่ avg 50 ms ต่อ flush, การคีย์แบบนี้จะกลายเป็น 75 วินาทีต่อรอบ 1,500 รายการ — นั่นคือเหตุผลที่ WAL บังคับให้ log ต้อง harden ก่อน commit ทุกครั้ง (Module 3)

### แก้

- **Mitigate**: ระบุ query/app ที่ commit ถี่ผิดปกติ (top by execution count จาก Section 11.1 Step 3) แล้วตามลงไป
- **Root fix**: รวม transaction ย่อย ๆ ที่เป็นหน่วยงานเดียวกันเป็นก้อน (`BEGIN TRAN ... COMMIT` ครั้งเดียว) — เทคนิค batching · ย้าย log ไป storage latency ต่ำ (M2) · ลดสิ่งที่บังคับ flush ที่ไม่จำเป็น (delayed durability พิจารณาเป็นกรณี — เสียการรับประกัน durability จึงต้องมีเหตุผล busines รองรับ)
- **ฝั่ง `PAGEIOLATCH_*`**: ลด logical reads ด้วย index (M6) หรือเพิ่ม memory ให้ working set อยู่ใน buffer pool (M4) — ดู Scenario 4 ควบคู่

### วัดซ้ำ

รันเดโมซ้ำหลังแก้ storage/ปรับ pattern — `avg_flush_ms` ต้องลดตามที่ปรับ และ file stats ของ log ต้องไม่เกินเกณฑ์ ~5 ms

---

## Quick Reference: อาการ → Wait → มาตรการ

| อาการหน้างาน | Wait ที่ควรเจอ | Mitigate ทันที | Root fix |
|:--------------|:----------------|:----------------|:----------|
| ช้าเฉพาะบางเวลา | ต้องพิสูจน์ด้วย Query Store interval | — | ย้าย/จูน workload ที่ตารงเวลา |
| CPU 90% ฝั่ง SQL | `SOS_SCHEDULER_YIELD` + signal สูง | หยุด query ยักษ์ | จูน top CPU + MAXDOP/CTFP |
| หน้าจอหมุนวนทั้งแผนก | `LCK_M_*` | KILL head blocker อย่างมีวินัย | app commit สั้น / RCSI / จูน query ที่ถือ lock |
| รายงานช้าแบบไม่มีเหตุผล | `RESOURCE_SEMAPHORE` | จำกัด query grant ยักษ์ | ลด sort/hash, index, statistics |
| เคยเร็ว วันนี้ช้า | ตัวใดก็ได้ — ดู plan เปลี่ยน | force plan (ระวัง) | แก้ต้นเหตุ plan ใหม่ |
| คีย์ข้อมูลสะดุด | `WRITELOG` / `PAGEIOLATCH_*` | — | batch transaction / storage / index |

---

## สรุป Section 11.2

1. ทุก scenario เดินด้วยโครงเดียว: **อาการ → วินิจฉัยด้วย query → แก้สองระดับ → วัดซ้ำ** — จำโครง แล้วเคสไหนก็เดินได้
2. "CPU สูง" ไม่ใช่การวินิจฉัย — waits และ ring buffer บอกความจริงก่อนตัดสินใจซื้อฮาร์ดแวร์
3. Memory grant และ log flush คือต้นทุนแฝงที่ query "ปกติ" จ่ายโดยไม่รู้ตัว — วัด grant ต่อ execution และ ms ต่อ flush เสมอ
4. Query Store คือหลักฐานย้อนเวลาสำหรับเคส "บางเวลา" และ "เคยเร็ว" — ตราบใดที่เปิดไว้ คุณไม่เคยสูญหลักฐาน

**ตรวจความเข้าใจ:**

1. เจอ `RESOURCE_SEMAPHORE` ใน delta waits — บล็อก query ใดใน Section นี้ที่ยืนยันผู้กระทำได้ตรงที่สุด และดูคอลัมน์ใด?
2. Scenario 2: Task Manager โชว์ CPU 92% แต่ ring buffer บอก SQL CPU 3% — ควรเดินไปทางไหน และใครคือเจ้าของปัญหา?
3. ในเดโม Scenario 4 เหตุใดเวอร์ชัน A ถึงได้ grant มหาศาลทั้งที่แถวมีแค่ 5,000 แถว?
4. ถ้า force plan แก้เคสได้ทันที เหตุใดจึงถือว่าเป็นเพียง mitigate และควรทำอะไรต่อ?
5. เดโม WRITELOG ทำไมจึงต้องใช้ autocommit ทีละคำสั่ง แทนการครอบด้วย BEGIN TRAN เดียว?
6. บน AdventureWorks ที่เปิด RCSI เหตุใดจึงยังเจอ blocking ได้ และมาจาก lock ชนิดใด?

**➡ ก่อนหน้า:** [Section 11.1 — Troubleshooting Workflow](../01_Troubleshooting_Workflow/README.md) | **ทบทวนรวม:** [Quiz Bank บทที่ 11](../../Quiz_Bank.md)

---

[⬅ Module 11](../../README.md) | [🧪 Labs](../../Labs/README.md) | [Quiz Bank](../../Quiz_Bank.md)
