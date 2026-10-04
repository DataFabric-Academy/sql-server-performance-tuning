[⬅ Module 10](../../README.md) | Section 1/2 | ➡ ถัดไป: [02 Baselining & Benchmarking](../02_Baselining_Benchmarking/README.md)

# 10.1 Monitoring & Tracing — มองให้เห็นว่าข้างในเกิดอะไรขึ้น

> *"SQL Server เปิดข้อมูลภายในของตัวเองให้อ่านฟรีทุกวินาที — ปัญหามักไม่ใช่ข้อมูลไม่มี แต่คือเราไม่รู้ว่าต้องดูที่ไหน และดูตอนไหน"*

> **ต้องรู้มาก่อน**: [Section 1.4 — Wait Statistics](../../../Module_01_Architecture_Scheduling_Waits/Sections/04_Wait_Statistics/README.md) (อ่าน `sys.dm_os_wait_stats`, Resource vs Signal wait, benign waits) และ [Module 9 — Extended Events](../../../Module_09_Extended_Events/Sections/01_XE_Core_Concepts/README.md) (เบื้องต้นพอ) · ต้องมีสิทธิ์ `VIEW SERVER STATE` (หรือบทบาท `##MS_ServerPerformanceStateReader##` บน SQL Server 2022+)
> ศัพท์ใหม่ดู [Glossary](../../../Glossary.md)

---

## ทำไม Monitoring จึงต้องมาก่อนการแก้ปัญหา

เมื่อผู้ใช้เดินมาบอกว่า "ระบบช้า" คำถามแรกของ DBA มืออาชีพไม่ใช่ "แก้ยังไง" แต่คือ **"มีข้อมูลอะไรยืนยันสาเหตุบ้าง"** เครื่องมือ Monitoring ทั้งหมดของ SQL Server มีอยู่เพื่อตอบคำถาม 3 ชั้นนี้:

| คำถาม | ภาษาของมืออาชีพ | เครื่องมือหลักของ section นี้ |
|:------|:------------------|:------------------------------|
| **"ตอนนี้เกิดอะไรขึ้น?"** | Live / Real-time monitoring | `sys.dm_exec_requests`, Activity Monitor |
| **"ช่วงที่ผ่านมาเกิดอะไรขึ้น?"** | Window / Interval monitoring | Delta waits, PerfMon, Ring Buffers, XEvents |
| **"ปกติของเครื่องนี้หน้าตาเป็นอย่างไร?"** | Baselining | ตารางเก็บ snapshot (Section 10.2 + Lab 10) |

ถ้าตอบสองข้อแรกไม่ได้ เราจะเดา และถ้าไม่มีข้อสาม เราจะไม่มีวันรู้ว่าค่าที่วัดได้เป็น "ปกติ" หรือ "ผิดปกติ" — Section นี้จัดระเบียบเครื่องมือทั้งหมดให้อยู่ในแผนที่เดียว แล้ว Section 10.2 จะเอาไปสร้าง Baseline จริง

---

## 1. แผนที่เครื่องมือ — Monitoring Stack ของ SQL Server

```
                 ข้อมูลสถานะของ SQL Server ไหลออกมา 5 ทาง
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  ① DMOs (DMV/DMF)          ② PerfMon           ③ Ring Buffers      │
│  อ่านตรงจาก memory         ค่าผ่าน Shared       "กล่องดำ" วนทับ      │
│  สดที่สุด แบ่ง 2 ชนิด:      Memory ของ Windows   ใน memory (เก่าหาย) │
│   - Snapshot (ณ ตอนนี้)     ราคา overhead ต่ำมาก                     │
│   - Cumulative (สะสม)                          ④ Default Trace      │
│                            ⑤ Query Store /      ไฟล์ .trc ที่เปิด     │
│  ⑥ XEvents (Module 9)        XEvents (Module 9)  มาให้เองตั้งแต่ติดตั้ง│
│  เหตุการณ์ราย event       เก็บประวัติระดับ DB                        │
│  ละเอียดสุด ควบคุมได้สุด  (Query Store = ลืมไม่ได้)                     │
└─────────────────────────────────────────────────────────────────────┘
              ↓ ทั้งหมดนี้จะ "หายวับ" ถ้าไม่มีใครเก็บเป็นระบบ ↓
              ⑦ ตาราง Baseline + Job เก็บทุก 15 นาที (Section 10.2)
```

เลือกเครื่องมืออย่างมืออาชีพ = เลือกให้ตรงกับ **คำถาม + ความละเอียดที่ต้องการ + ราคา overhead ที่ยอมจ่าย**:

| เครื่องมือ | คำถามที่ตอบได้ | อยู่ได้นานแค่ไหน | Overhead |
|:-----------|:----------------|:------------------|:---------|
| Snapshot DMVs | ตอนนี้ใครทำอะไรอยู่ | หายทันทีที่ request จบ | ต่ำมาก |
| Cumulative DMVs | ธรรมชาติ workload ตั้งแต่ restart | จนกว่า restart | ต่ำมาก (แต่ต้องคำนวณ delta เอง) |
| PerfMon | ทรัพยากร OS/SQL ช่วงเวลา | เท่าที่เราเก็บ log (.blg) | ต่ำมาก |
| Ring Buffers | เหตุการณ์ย้อนหลังเสี้ยวเดียว | วนทับใน memory — ไม่กี่พัน record | ต่ำมาก |
| Default Trace | เหตุการณ์ระดับไฟล์/DDL | ไฟล์ .trc วน ~20 MB | ต่ำ |
| Query Store | ประวัติ query + plan ต่อ database | ถาวรตามค่ากำหนด | ต่ำ–กลาง |
| XEvents | เหตุการณ์เจาะจงแม่นยำ | ตาม target ที่ตั้ง | ต่ำถ้าตั้งถูก |
| SQL Profiler/Trace (Legacy) | — | — | **สูง — deprecated อย่าใช้บน production** |

> [!IMPORTANT]
> สองบรรทัดล่างสุดคือหัวใจที่ผูกทั้งหลักสูตร: **Query Store** (ลึกใน [Module 8](../../../Module_08_Plan_Caching/Sections/03_Query_Store_Automatic_Tuning/README.md)) คือ baseline ที่ดีที่สุด *ระดับ query* ส่วน **XEvents** ([Module 9](../../../Module_09_Extended_Events/Sections/01_XE_Core_Concepts/README.md)) คือเครื่องมือ tracing ทดแทน SQL Profiler ที่ถูกถอดไปแล้ว — Section นี้เสริมให้เหลือชิ้นเดียวที่ยังขาด: **การเก็บค่าระดับ instance ให้เป็น baseline (Section 10.2)**

---

## 2. DMOs — หัวใจสองชนิด: Snapshot vs Cumulative

**นิยามก่อนใช้** (ศัพท์ชุดนี้จะเจอทั้งหลักสูตร):

- **DMO (Dynamic Management Object)** = ชื่อกลางของ DMV (view) + DMF (function) ที่ระบบเปิดให้อ่านสถานะภายใน ต้องใช้สิทธิ์ `VIEW SERVER STATE` หรือ `VIEW DATABASE STATE`
- **Snapshot DMO** = ภาพ "ณ ขณะนั้น" — ข้อมูลอยู่เท่าที่ object ยังมีชีวิต (เช่น request กำลังรัน) จบแล้วหาย
- **Cumulative DMO** = บัญชีสะสมตั้งแต่ startup — ค่าเดิมไม่ลดลง ไม่รีเซ็ตเอง วิธีเดียวที่ดู "ช่วงเวลา" ได้คือ **Delta** (นิยาม: ค่าสะสมล่าสุด − ค่าสะสมจุดก่อน หารด้วยช่วงเวลา)
- **Benign waits** = wait type พื้นหลังของ engine (SLEEP_*, *_QUEUE, XE_TIMER ฯลฯ) ที่สะสมนาน ๆ แล้วบวมจนกลบปัญหาจริง — ต้องกรองทิ้งก่อนจัดอันดับ

จำง่าย: **"ของที่วิ่งผ่าน = snapshot / ของที่จดบัญชี = cumulative"**

| DMO ที่ใช้บ่อยที่สุด | ชนิด | ตอบคำถาม | Reset เมื่อไร |
|:----------------------|:-----|:----------|:--------------|
| `sys.dm_exec_requests` | Snapshot | ใครกำลังรัน/รออะไร | — (ตามอายุ request) |
| `sys.dm_os_schedulers` | Snapshot | คิว CPU ตอนนี้ | — |
| `sys.dm_exec_sessions` | Snapshot | ใครต่ออยู่บ้าง | — (ตามอายุ session) |
| `sys.dm_os_wait_stats` | Cumulative | รออะไรมาบ้าง (M1) | Restart / `DBCC SQLPERF(..., CLEAR)` |
| `sys.dm_io_virtual_file_stats` | Cumulative | I/O latency ต่อไฟล์ (M2) | Restart |
| `sys.dm_os_performance_counters` | Cumulative | PerfMon ผ่าน T-SQL | Restart |
| `sys.dm_db_index_physical_stats` (DMF) | On-demand | Fragmentation (M6) | — (คำนวณสด) |

### ทดลอง: เห็นความต่างของสองชนิดในหน้าเดียว

```sql
-- Snapshot DMO: สถานะ "ณ เวลานี้" — ตัวเลขเปลี่ยนทุกครั้งที่รันตาม activity จริง
SELECT scheduler_id, cpu_id, current_tasks_count, runnable_tasks_count,
       work_queue_count, pending_disk_io_count
FROM sys.dm_os_schedulers
WHERE scheduler_id < 1048576 AND status = N'VISIBLE ONLINE';

-- Cumulative DMO: บัญชีสะสมตั้งแต่ restart — ค่าเดิมไม่เคยลดลง รันกี่ครั้งก็โตขึ้นอย่างเดียว
SELECT TOP (5) wait_type, waiting_tasks_count,
       wait_time_ms / 1000.0 AS wait_s,
       signal_wait_time_ms / 1000.0 AS signal_s
FROM sys.dm_os_wait_stats
WHERE waiting_tasks_count > 0
ORDER BY wait_time_ms DESC;
```

**อ้างอิงรันจริง** บน server หลักสูตร (SQL Server 2025 RTM-GDR 17.0.1135.8): snapshot บล็อกแรกได้ 4 schedulers, `runnable_tasks_count = 0` ทุกตัว (เครื่องว่าง) ส่วน top waits สะสมถูกครองด้วย `SOS_WORK_DISPATCHER`, `SLEEP_TASK`, `LOGMGR_QUEUE` — ค่าสะสมนับแสนวินาทีซึ่ง **ตีความอะไรไม่ได้เลย** ถ้าไม่ทำ delta (จะจัดการในหัวข้อ 5)

> **จุดเชื่อมโยง:** `SOS_SCHEDULER_YIELD`/signal wait จาก [M1](../../../Module_01_Architecture_Scheduling_Waits/Sections/04_Wait_Statistics/README.md) อ่านจากตารางนี้, `PAGEIOLATCH_*`/WRITELOG ยืนยันต่อด้วย file stats จาก [M2](../../../Module_02_IO/Sections/04_Monitoring_Troubleshooting_IO/README.md) — ตอนนี้เรากำลังจัด "ที่อยู่" ของทุกตัวให้เป็นระบบ

---

## 3. มอง "ตอนนี้" — Live Monitoring ด้วย dm_exec_requests

นี่คือ query แรกที่มืออาชีพรันเมื่อมีคนบอกว่า "ระบบช้าตอนนี้" — บางคนเรียกแนวคิดนี้ว่า *Mini-WhoIsActive* (สคริปต์เต็มอยู่ที่ `Scripts/02_Monitor_Queries.sql`):

```sql
-- "ตอนนี้" — request ที่กำลังรัน/รอ ณ ขณะนั้น (snapshot DMO ทั้งหมด)
SELECT r.session_id,
       r.status,
       r.start_time,
       r.command,
       r.cpu_time AS cpu_ms,
       r.total_elapsed_time AS elapsed_ms,
       r.logical_reads,
       r.wait_type,
       r.wait_time AS wait_ms,
       r.blocking_session_id AS blocker,
       DB_NAME(r.database_id) AS database_name,
       LEFT(t.text, 80) AS running_sql
FROM sys.dm_exec_requests AS r
JOIN sys.dm_exec_sessions AS s
    ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.session_id <> @@SPID
  AND s.is_user_process = 1
ORDER BY r.total_elapsed_time DESC;
```

อ่านผลอย่างมืออาชีพ:

- `status = running` → กำลังใช้ CPU · `status = suspended` + `wait_type` → กำลังรอของ (แปลตามตาราง wait ของ M1)
- `blocker <> 0` → มีลูกโซ่ blocking (ลงลึกต่อใน [Section 11.1](../../../Module_11_Troubleshooting/Sections/01_Troubleshooting_Workflow/README.md))
- `elapsed_ms สูงแต่ cpu_ms ต่ำ` = ส่วนใหญ่เป็นการ "รอ" ไม่ใช่ "ทำงาน" — ดู wait_type เป็นตัวชี้ทิศ
- `s.is_user_process = 1` กรอง background ของ engine ออก — และจำไว้ว่า **คอลัมน์ `is_user_process` ต้องอ่านจาก `sys.dm_exec_sessions` เท่านั้นบน SQL Server 2025** (ถูกถอดออกจาก `dm_exec_requests` แล้ว — สคริปต์เก่าที่อ้าง `r.is_user_process` จะ error `Invalid column name`)

**อ้างอิงรันจริง** บน server หลักสูตร (ช่วงว่าง): ผลลัพธ์ว่าง 0 แถว — ถูกต้อง เพราะไม่มี user request กำลังรัน รู้ว่า query ใช้การได้เพราะรันแล้ว error ไม่เกิด และตอนที่รัน workload ใน Section 10.2 หน้าต่างที่สองจะเห็น session ของ workload โผล่มาทันที

### เครื่องมือ "พร้อมใช้" ที่อ่านค่าชุดเดียวกัน

| เครื่องมือ | อยู่ตรงไหน | เหมาะกับ | ข้อจำกัด |
|:-----------|:------------|:----------|:----------|
| **Activity Monitor** | SSMS → คลิกขวา server | ดูภาพรวมเร็ว ๆ (Process/Waits/I/O) | เปิดค้างแล้วหนัก — อย่าเปิดทิ้งไว้บน production |
| **Performance Dashboard** | SSMS → Reports → Standard Reports → Performance Dashboard | ภาพรวม waits/missing index/การแบ่ง CPU แบบ report | เป็นภาพสะสม — ยังต้องเข้าใจเรื่อง delta |
| **Query ของเราเอง** | หน้าต่าง query | ควบคุมได้ทุกคอลัมน์ เก็บเป็น baseline ได้ | ต้องเขียนเอง (แต่คุณกำลังทำอยู่) |

ทั้งสามอ่านจากแหล่งเดียวกัน — เครื่องมือ GUI แค่ "พร้อมหุ่น" ส่วน query ของเราคือ "โรงงานผลิตเอง" ซึ่งเป็นทางเดียวที่ไปต่อถึง baseline อัตโนมัติได้

---

## 4. PerfMon — ตัวเลขระดับ OS อ่านผ่าน T-SQL ได้

**PerfMon (Windows Performance Monitor)** เก็บตัวเลขที่ SQL Server เขียนทิ้งไว้บน **Shared Memory ของ Windows** — เราจึงอ่านค่าโดยแทบไม่กวน engine (overhead ต่ำมาก) ใช้ผ่าน GUI (`perfmon` → Performance Monitor) หรืออ่านผ่าน DMV `sys.dm_os_performance_counters` ซึ่งสะดวกตอนเก็บเป็น baseline:

```sql
-- ค่าดิบของ counters สำคัญ (PerfMon ผ่าน T-SQL — ทุกค่าเป็น "สะสมตั้งแต่ restart")
SELECT object_name, counter_name, instance_name, cntr_value
FROM sys.dm_os_performance_counters
WHERE (object_name LIKE N'%Buffer Manager%'   AND counter_name = N'Page life expectancy')
   OR (object_name LIKE N'%Buffer Node%'      AND counter_name = N'Page life expectancy')
   OR (object_name LIKE N'%Memory Manager%'   AND counter_name IN (N'Memory Grants Pending', N'Total Server Memory (KB)'))
   OR (object_name LIKE N'%SQL Statistics%'   AND counter_name IN (N'Batch Requests/sec', N'SQL Compilations/sec', N'SQL Re-Compilations/sec'))
   OR (object_name LIKE N'%Access Methods%'   AND counter_name IN (N'Full Scans/sec', N'Forwarded Records/sec'))
ORDER BY object_name, counter_name;
```

**อ้างอิงรันจริง** บน server หลักสูตร: PLE ≈ 19,875 วินาที, Memory Grants Pending = 0, Batch Requests/sec (สะสม) = 2,371, Full Scans/sec (สะสม) = 16,473 — สังเกตว่า counter ชื่อ "/sec" **ไม่ใช่ค่าต่อวินาทีตอนนี้** แต่เป็นยอดสะสม (cntr_type เป็น rate counter) ต้องเอาไปคำนวณเอง:

```sql
-- แปลง rate counter เป็นค่าจริง "ต่อวินาทีช่วงนี้": snapshot 2 จุดห่างกัน 10 วินาที
DECLARE @t0 TABLE (cntr_value BIGINT);
INSERT @t0 SELECT cntr_value FROM sys.dm_os_performance_counters
WHERE counter_name = N'Batch Requests/sec'
  AND object_name LIKE N'%SQL Statistics%';

WAITFOR DELAY '00:00:10';

SELECT CAST((c.cntr_value - t0.cntr_value) / 10.0 AS DECIMAL(10,1)) AS batch_requests_per_sec
FROM sys.dm_os_performance_counters AS c
CROSS JOIN @t0 AS t0
WHERE c.counter_name = N'Batch Requests/sec'
  AND c.object_name LIKE N'%SQL Statistics%';
```

> ⚠️ กับดักที่พบบ่อย: counter กลุ่ม SQL Statistics **ไม่มี instance** (`instance_name` เป็นค่าว่าง) — ถ้าใส่เงื่อนไข `instance_name = N'_Total'` ตามสัญชาตญาณจะได้ **0 แถว** (ทดสอบจริงแล้วเป็นเช่นนั้น) — กรองแค่ object_name + counter_name พอ

**อ้างอิงรันจริง** บน server หลักสูตร (ช่วงว่าง): `batch_requests_per_sec = 0.0` — สมเหตุสมผล นี่คือ baseline ระดับ "workload เข้ามาเท่าไร" ที่คุณจะเทียบหา load ตอนระบบช้า

### Counters ที่ต้องรู้จัก (รวมเกณฑ์ตั้งต้น)

| Object | Counter | เกณฑ์ตั้งต้น | ชี้ปัญหาอะไร |
|:-------|:--------|:--------------|:--------------|
| Processor (_Total) | % Processor Time | < 80% ค่าเฉลี่ย | CPU อิ่ม (ดูคู่ signal wait ของ M1) |
| System | Processor Queue Length | < 2 ต่อ CPU | คิว CPU ที่ OS เห็น |
| Memory | Available MBytes | > 500 MB | OS เริ่มขาด RAM |
| Memory | Pages/sec | < 50 | OS paging (SQL ควรถูกจำกัดด้วย Max Server Memory — M4) |
| Buffer Manager / Buffer Node | Page life expectancy | เทียบ **baseline ของเครื่องนี้** | Buffer pool ถูกกวาด (อย่าใช้ 300s เดิมเป็นกฎตายตัว) |
| PhysicalDisk / LogicalDisk | Avg. Disk sec/Read | < 20 ms | Storage อ่านช้า |
| PhysicalDisk / LogicalDisk | Avg. Disk sec/Write | < 20 ms (log ไฟล์ < 5 ms) | Storage เขียนช้า |
| SQL Statistics | Batch Requests/sec | เทียบ baseline | ปริมาณ workload ต่อวินาที |
| SQL Statistics | SQL Re-Compilations/sec | < 10% ของ Compilations | Plan ถูก compile ซ้ำ (M8) |
| Access Methods | Full Scans/sec | เทียบ baseline | Scan ระดม (missing index — M6) |
| Access Methods | Forwarded Records/sec | ต่ำ | Heap ถูก update ให้แถวเตลิด (M6) |
| Locks | Lock Waits/sec | ต่ำ | Blocking เรื้อรัง (M5) |

เกณฑ์ในตารางเป็น "จุดตั้งต้นของวงการ" — คำตัดสินจริงคือ **เทียบกับ baseline ของเครื่องนั้น** (Section 10.2)

---

## 5. อ่าน Waits แบบ Delta — หน้าต่างวินิจฉัย 15 วินาที

จาก M1: `sys.dm_os_wait_stats` เป็นค่าสะสม การเก็บ delta = **snapshot 2 จุด แล้วลบกัน** — นี่คือเทคนิคที่ทั้ง Section 10.2 และ Lab 10 สร้างขึ้นเป็นระบบ:

```sql
-- Delta wait stats: 15 วินาทีที่ผ่านมา server รออะไร (ไม่ใช่ค่าสะสมตั้งแต่ restart)
SELECT wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms
INTO #waits_t0
FROM sys.dm_os_wait_stats;

WAITFOR DELAY '00:00:15';   -- หน้าต่างวัด 15 วินาที

SELECT w.wait_type,
       w.waiting_tasks_count - t0.waiting_tasks_count AS delta_count,
       CAST((w.wait_time_ms - t0.wait_time_ms) / 1000.0 AS DECIMAL(10,1)) AS delta_wait_s,
       CAST((w.signal_wait_time_ms - t0.signal_wait_time_ms) / 1000.0 AS DECIMAL(10,1)) AS delta_signal_s,
       CASE WHEN w.waiting_tasks_count - t0.waiting_tasks_count > 0
            THEN CAST((w.wait_time_ms - t0.wait_time_ms) * 1.0
                      / (w.waiting_tasks_count - t0.waiting_tasks_count) AS DECIMAL(10,1))
            ELSE 0 END AS avg_wait_ms
FROM #waits_t0 AS t0
JOIN sys.dm_os_wait_stats AS w
    ON w.wait_type = t0.wait_type
WHERE w.wait_time_ms - t0.wait_time_ms > 0
  AND w.wait_type NOT IN (N'CHECKPOINT_QUEUE', N'DIRTY_PAGE_POLL', N'LAZYWRITER_SLEEP',
        N'LOGMGR_QUEUE', N'REQUEST_FOR_DEADLOCK_SEARCH', N'BROKER_TO_FLUSH',
        N'MEMORY_ALLOCATION_EXT', N'SLEEP_TASK', N'SLEEP_SYSTEMTASK', N'SLEEP_BPOOL_FLUSH',
        N'XE_TIMER_EVENT', N'WAITFOR', N'BROKER_TASK_STOP', N'BROKER_EVENTHANDLER',
        N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'HADR_WORK_QUEUE', N'HADR_TIMER_TASK',
        N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', N'SOS_WORK_DISPATCHER',
        N'SP_SERVER_DIAGNOSTICS_SLEEP', N'DISPATCHER_QUEUE_SEMAPHORE',
        N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', N'QDS_ASYNC_QUEUE', N'KSOURCE_WAKEUP',
        N'XE_DISPATCHER_WAIT')
  AND w.wait_type NOT LIKE N'PREEMPTIVE_%'
ORDER BY delta_wait_s DESC;

DROP TABLE #waits_t0;
```

**อ้างอิงรันจริง** บน server หลักสูตร (ช่วงว่าง): ได้เพียง 1 แถว — `WRITELOG` 1 ครั้ง ~1 ms จาก background — **นี่คือสิ่งที่ baseline ที่ดีดูเป็นแบบนี้** ต่อมาใน Section 10.2 เราจะรัน workload จริงแล้วเห็น `WRITELOG`/`SOS_SCHEDULER_YIELD` โดดขึ้นมาในรูปแบบเดียวกัน

วิธีอ่าน delta แบบมืออาชีพ (ต่อยอดจาก M1):

1. `delta_wait_s` สูงสุดอยู่กลุ่มไหน → คอขวดผู้สมควรถูกสงสัย (I/O / CPU / Lock / Memory)
2. `avg_wait_ms` สูงแต่ `delta_count` น้อย = เจอปัญหา **latency ต่อครั้ง** (เช่น log ช้า)
3. `avg_wait_ms` ต่ำแต่ `delta_count` มหาศาล = ปัญหา **ความถี่** (เช่น micro-transaction รัว log writes)
4. `delta_signal_s` กินสัดส่วน > 10–15% ของ delta_wait → CPU pressure ชัดเจน

> [!TIP]
> หน้าต่าง 15 วินาทีเหมาะกับการวินิจฉัย "สด" หน้างาน — แต่การเก็บเป็นระบบต้องใช้ snapshot ทุก 15 **นาที** ผ่าน Job (Section 10.2 / Lab 10) เพราะอาการจริงมักเกิดเป็นวงรอบ ไม่ได้เกิดตอนที่เรายืนจ้องอยู่

---

## 6. กล่องดำของ SQL Server — Ring Buffers และ Default Trace

### 6.1 Ring Buffers — ประวัติ CPU ที่มีให้ฟรีแม้ไม่เคยตั้งค่าอะไร

SQL Server บันทึกเหตุการณ์สำคัญลง **Ring Buffer** (หน่วยความจำแบบวนทับ — เก่าสุดถูกแทนที่เมื่อเต็ม) ที่ใช้ประโยชน์ที่สุดคือ `RING_BUFFER_SCHEDULER_MONITOR` ซึ่ง engine จด **%CPU ของตัวเองทุก ~60 วินาที** ให้เราย้อนดูได้เป็นชั่วโมง:

```sql
-- CPU history ย้อนหลังจาก Ring Buffer (engine จดให้เองทุก ~60 วินาที)
SELECT TOP (10)
       DATEADD(ms, -1 * (rb.[timestamp] - fi.ms_ticks), GETDATE()) AS event_time_approx,
       rb.sql_cpu_pct,
       100 - rb.system_idle_pct - rb.sql_cpu_pct AS other_process_cpu_pct
FROM (
    SELECT record.value('(./Record/@id)[1]', 'int') AS record_id,
           record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS sql_cpu_pct,
           record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS system_idle_pct,
           [timestamp]
    FROM (
        SELECT CONVERT(xml, record) AS record, [timestamp]
        FROM sys.dm_os_ring_buffers
        WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
          AND record LIKE N'%<SystemHealth>%'
    ) AS x
) AS rb
CROSS JOIN sys.dm_os_sys_info AS fi
ORDER BY rb.record_id DESC;
```

> ⚠️ สังเกต `CROSS JOIN sys.dm_os_sys_info` — เวลาเหตุการณ์ต้องคำนวณจาก `ms_ticks` ของ **`sys.dm_os_sys_info`** เท่านั้น (`cpu_ticks`/`ms_ticks` ไม่ใช่คอลัมน์ของ `sys.dm_os_ring_buffers` — สคริปต์เก่าบนอินเทอร์เน็ตที่ SELECT ตรง ๆ จะ error `Invalid column name` ทันที ทดสอบจริงบน 17.0.1135.8)

**อ้างอิงรันจริง** บน server หลักสูตร: ได้ 10 จุดย้อนหลังทีละ ~60 วินาที SQL process CPU = 2–3% (เครื่องว่างจริง) และมี 1 จุดที่ `other_process_cpu_pct = 18%` — หลักฐานว่า **มี process อื่นในเครื่องทำงาน** ซึ่ง PerfMon SQL จะไม่เห็นเอง — นี่คือเหตุผลที่ DBA ต้องดูทั้ง SQL CPU และ Other Process CPU คู่กัน

### 6.2 Default Trace — trace ที่เปิดมาให้เองตั้งแต่ติดตั้ง

นอกจากกล่องดำใน memory ยังมีไฟล์ trace เบา ๆ (`log_NNN.trc` วนรอบใน Log folder) จับเหตุการณ์จุดสำคัญโดยอัตโนมัติ — เช่น Auto Grow ของไฟล์, Schema Changes, Errors:

```sql
-- Default Trace ทำงานอยู่ไหม และไฟล์อยู่ตรงไหน (property 2 = path)
SELECT traceid, property, value FROM fn_trace_getinfo(DEFAULT);

-- เหตุการณ์ Auto Grow ล่าสุด (92 = Data File Auto Grow, 93 = Log File Auto Grow)
SELECT TOP (10) t.DatabaseName, t.FileName, t.EventClass, t.StartTime,
       t.IntegerData * 8 / 1024.0 AS growth_mb
FROM fn_trace_gettable(
       (SELECT CONVERT(NVARCHAR(260), value) FROM fn_trace_getinfo(DEFAULT)
        WHERE property = 2), DEFAULT) AS t
WHERE t.EventClass IN (92, 93)
ORDER BY t.StartTime DESC;
```

**อ้างอิงรันจริง** บน server หลักสูตร: ไฟล์ trace อยู่ที่ `C:\...\MSSQL\Log\log_7.trc` และเจอ Auto Grow จริง 10 เหตุการณ์ — ส่วนใหญ่เป็น `AdventureWorks_log` โตวันละ 64 MB ตามการทดลองเขียนของหลักสูตร ถ้าใน production คุณเห็น log auto-grow ถี่ ๆ ทุก 10 นาที นั่นคือตัวชี้ว่า log ถูกจัดขนาดผิดตั้งแต่ต้น (ดู VLF ต่อใน M3) — Default Trace จับไว้ให้ **แม้ตอนที่ไม่มีใคร monitor อยู่เลย**

---

## 7. ทำให้เป็นอัตโนมัติ — Polling, SQL Agent Job และทางเลือก

ทุกอย่างใน section นี้เป็นข้อมูล "จุดเวลา" — การได้มาเป็น "ประวัติ" ต้องมีใครสักคนรัน query ซ้ำ ๆ ตามตารางเวลา (polling) ทางเลือกในโลกจริง:

| ทางเลือก | ทำงานอย่างไร | หมายเหตุ |
|:----------|:--------------|:----------|
| **SQL Server Agent Job** | T-SQL job step เรียก procedure เก็บ snapshot ทุก 15 นาที (ตาม Lab 10) | มาตรฐานของหลักสูตร — ต้อง START Agent ก่อน และควรผูก Database Mail + Operator แจ้งเตือนเมื่อ fail |
| **PowerShell + Task Scheduler** | `Invoke-Sqlcmd` ตามด้วย Task ทุก 15 นาที | ไม่พึ่ง Agent — ใช้เมื่องานติดข้อจำกัดด้าน policy |
| **dbatools (PowerShell)** | `Get-DbaWaitStatistic`, `Get-DbaIoLatency`, `Test-DbaLastBackup` ฯลฯ | ชุดคำสั่งสำเร็จรูปของชุมชน — เขียนสคริปต์เองให้น้อยลงมาก |
| **เครื่องมือ monitoring ภายนอก** | Redgate SQL Monitor, Quest Spotlight, Grafana/Zabbix ฯลฯ | อ่านค่าชุดเดียวกันนี้ผ่าน DMV ทั้งนั้น — ความเข้าใจจากหลักสูตรใช้ได้กับทุกตัว |

### ก่อนตั้ง Job อะไร — เช็คสถานะบริการของ SQL Server ก่อนเป็นเรื่องแรก

```sql
-- เวลา restart + สถานะบริการ (SQL Server / Agent) — สิ่งแรกที่ Daily Health Check ต้องดู
SELECT @@SERVERNAME AS server_name, sqlserver_start_time AS last_restart
FROM sys.dm_os_sys_info;

SELECT servicename, status_desc, startup_type_desc
FROM sys.dm_server_services;
```

**อ้างอิงรันจริง** บน VM ทดสอบของหลักสูตร: SQL Server = Running (Automatic) แต่ **SQL Server Agent = Stopped (Manual)** — จำนวน restart ล่าสุดบอกเป็นนัยว่าค่า cumulative ทั้งหมด (wait stats, file stats, PerfMon) ถูกรีเซ็ตไปด้วย ทำให้ baseline เก่าเทียบไม่ได้ทันที

> [!CAUTION]
> **Agent = Stopped แปลว่า Job ไม่เคยรัน** — snapshot ทุก 15 นาทีที่ออกแบบไว้จะเงียบไปตลอดโดยไม่มี error ให้เห็น ขั้นตอนสร้าง job จริงจึงกำหนดให้ **รันตอนสอนบน VM** (START Agent → สร้าง job ตาม [Lab 10 Exercise 1](../../Labs/README.md) → View History) เพื่อไม่ทิ้ง job/schedule ค้างบนเครื่องทดสอบร่วม

จำโครงการทำงานไว้ให้ขึ้นใจ: **procedure เก็บ snapshot (SQL ล้วน) → ตัวจัดการตารางเวลา (Agent/Task Scheduler) → ตารางปลายทาง (baseline) → ตัวเทียบค่า (delta/anomaly)** — สี่ชิ้นนี้คือทั้ง Section 10.2

---

## สรุป Section 10.1

1. เครื่องมือ monitoring ตอบ 3 คำถาม: **ตอนนี้** (snapshot DMV), **ช่วงที่ผ่านมา** (delta + PerfMon + Ring Buffer + Default Trace), **ปกติเป็นอย่างไร** (baseline — Section 10.2)
2. DMOs แบ่ง **Snapshot** (วิ่งผ่าน — `dm_exec_requests`) กับ **Cumulative** (จดบัญชี — `dm_os_wait_stats`, `dm_io_virtual_file_stats`, `dm_os_performance_counters`) — ของสะสมต้องทำ delta เสมอ
3. Counter ชื่อ "/sec" ใน `sys.dm_os_performance_counters` เป็นค่าสะสมด้วย — ต้อง snapshot 2 จุดหารด้วยเวลาจึงได้ rate จริง
4. Delta waits + กรอง benign waits คือเทคนิควินิจฉัยหลัก — หน้าต่าง 15 วินาทีสำหรับ "สด" และ snapshot ทุก 15 นาทีสำหรับระบบ
5. Ring Buffer ให้ CPU history ฟรี, Default Trace จับ auto-grow/DDL อัตโนมัติ — ทั้งคู่มีมาให้แม้ไม่เคยตั้งค่าอะไร
6. Automation ต้องพึ่งตัวจัดการตารางเวลา (SQL Agent หรือ Task Scheduler) — Agent หยุด = monitoring เงียบโดยไม่มี error

**ตรวจความเข้าใจ:**

1. `sys.dm_exec_requests` กับ `sys.dm_os_wait_stats` ต่างกันตรงไหน — และทำไมตัวหลังจึงต้องมี "delta" เสมอ?
2. ทำไม counter `Batch Requests/sec` ที่อ่านจาก `sys.dm_os_performance_counters` จึงไม่ใช่ค่าต่อวินาที "ตอนนี้" — คำนวณใหม่อย่างไร?
3. สคริปต์เก่าใช้ `r.is_user_process` จาก `sys.dm_exec_requests` — บน SQL Server 2025 ต้องแก้อย่างไร?
4. Ring Buffer CPU history แสดง `other_process_cpu_pct = 40%` ต่อเนื่องหลายชั่วโมง — ปัญหาอยู่ที่ SQL Server หรือไม่ จะยืนยันอย่างไร?
5. เจอ `WRITELOG` delta 500 ครั้งใน 15 วินาที ที่ avg 8 ms/ครั้ง — แปลว่าอะไร และจะยืนยันด้วยข้อมูลชั้นที่สองใด?
6. เพราะอะไร Job เก็บ baseline จึงต้องเช็คสถานะ SQL Server Agent ก่อนเป็นอย่างแรก — และถ้า Agent หยุด อาการที่เห็นคืออะไร?

**➡ ถัดไป:** [Section 10.2 — Baselining & Benchmarking](../02_Baselining_Benchmarking/README.md) — เอาทุกอย่างใน section นี้ไปสร้าง baseline จริง วัด workload และตั้งจุดตัด "ผิดปกติ"

---

[⬅ Module 10](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [02 Baselining & Benchmarking](../02_Baselining_Benchmarking/README.md)
