[⬅ Module 04](../../README.md) | Section 3/4 | ➡ ถัดไป: [04 In-Memory OLTP](../04_In_Memory_OLTP/README.md)

# 4.3 Memory Pressure Diagnostics — วินิจฉัยแรงกดดันหน่วยความจำอย่างเป็นระบบ

> *"Memory pressure ไม่เคยมาคนเดียว — มันส่งตัวแทนมาเป็น PLE ที่ตก, grant ที่ต้องรอ และ plan ที่ spill หน้าเลื่อน หน้าที่ของเราคือสัมภาษณ์ตัวแทนทั้งหมด ไม่ใช่เชื่อใครตัวเดียว"*

> **ต้องรู้มาก่อน**: [Section 4.1 — Windows Memory](../01_Windows_Memory/README.md) (paging, NUMA node) และ [Section 4.2 — SQL Server Memory](../02_SQL_Server_Memory/README.md) (clerks, grants, max server memory) พร้อมสิทธิ์ `VIEW SERVER STATE`
> ศัพท์ใหม่ดู [Glossary](../../../Glossary.md) — PLE, Memory Clerk, Buffer Pool

## ทำไม Section นี้จึงสำคัญ

"Memory pressure" เป็นคำที่ถูกพูดมั่วที่สุดในวงการจูน เพราะมันมี **สองหน้าที่ต่างกันโดยสิ้นเชิง** แต่อาการภายนอกคล้ายกัน:

- **External pressure** — Windows ขาด RAM (ใครก็ตามบนเครื่องกินเกิน) → บีบ SQL Server ให้คืน memory
- **Internal pressure** — SQL Server กดดันตัวเอง (grant แย่งกัน, cache บวม) ทั้งที่ OS ยังเหลือ RAM เหลือเฟือ

เครื่องมือที่ "ใช้เพียงตัวเดียว" แทบทั้งหมดจะโกหกเราในกรณีใดกรณีหนึ่ง — PLE ต่ำอาจเกิดจาก scan ครั้งเดียว, `mem_util_pct = 100` เป็นเรื่องปกติ, BCHR 99% เกิดได้แม้ระบบทรุด Section นี้จึงสอนเป็น **ขั้นตอนการสัมภาษณ์พยานหลายชุด**: clerks → PLE → waits → resource semaphore → feedback → ring buffer → PVS

ศัพท์ที่ใช้ตลอด section (นิยามก่อนใช้):

| ศัพท์ | นิยาม |
|:------|:------|
| **Trim** | การที่ engine (SQL หรือ Windows) เท้าข้อมูล/cache ออกจาก memory เพื่อคืนพื้นที่ |
| **Memory Grant / Workspace** | memory ที่ query จองเพื่อ sort/hash (Section 4.2 หัวข้อ 5) |
| **Spill** | เมื่อ grant ไม่พอ operator ต้องเขียนข้อมูลชั่วคราวลง **tempdb** — แปลง "งานใน RAM" เป็น "งาน I/O" |
| **PLE (Page Life Expectancy)** | ค่าเฉลี่ยวินาทีที่ page ค้างอยู่ใน buffer pool ก่อนถูกไล่ออก |
| **Resource Semaphore** | ประตูคุมคิวการจ่าย memory grant — มีตัวคุม grant เล็ก/ใหญ่ แยกต่อ resource pool |
| **Ring Buffer** | บัฟเฟอร์วน ๆ ที่ engine บันทึกเหตุการณ์ภายใน — เราใช้ชุด `RING_BUFFER_RESOURCE_MONITOR` อ่านสัญญาณ memory จาก Windows |
| **PVS (Persistent Version Store)** | ที่เก็บ row version ใน data file ของ DB เอง (2019+) — พันธุ์ใหม่ของ version store ที่ยุคก่อนอาศัย tempdb/buffer pool |

---

## 1. แผนที่วินิจฉัย — แยกสองหน้าของ Pressure ตั้งแต่มองแรก

```
                       อาการ: ระบบช้า / cache ตก / query รอ
                                      │
                     ┌────────────────┴─────────────────┐
                     ▼                                  ▼
        Windows ขาด RAM หรือไม่?              SQL แย่งกันเองหรือไม่?
        sys.dm_os_sys_memory                  sys.dm_exec_query_resource_semaphores
        system_low_memory_signal_state        waiter_count > 0 ?
        sys.dm_os_process_memory              sys.dm_exec_query_memory_grants
        (process_physical_memory_low)         ตรวจ clerks ใครบวม
                     │                                  │
                     ▼                                  ▼
        ยืนยัน: Ring Buffer                   ยืนยัน: waits (RESOURCE_SEMAPHORE,
        RING_BUFFER_RESOURCE_MONITOR          CMEMTHREAD) + spill ใน plans
        → RESOURCE_MEMPHYSICAL_LOW            + sys.query_store_plan_feedback
                     │                                  │
                     └────────────────┬─────────────────┘
                                      ▼
                 ทั้งคู่เจอพร้อมกันได้! แก้ฝั่ง OS ก่อน (ใครกิน RAM)
                 แล้วจึงจูนฝั่ง SQL (grant, index, statistics)
```

| อาการแรกที่เจอ | เดาไว้ก่อนว่า | ยืนยันด้วย |
|:----------------|:---------------|:-----------|
| ทั้งเครื่องช้า + แอปอื่นก็ช้า | External | `system_low_memory_signal_state`, ring buffer, `Memory: Available MBytes` |
| SQL ช้าอย่างเดียว, query sort/hash หนักช้า | Internal (grant) | `waiter_count`, `RESOURCE_SEMAPHORE`, spill warnings |
| PLE ตกแบบฟันเลื่อย, disk read พุ่ง | Buffer pool ถูก churn | PLE ต่อ node + clerks + `PAGEIOLATCH_*` (Module 2) |

---

## 2. ขั้นที่ 1 — ใครกิน Memory: Clerks และ Cache ต่อ Database

คำถามแรกของการวินิจฉัย internal pressure เสมอ: **"memory หมดไปกับอะไร"** — สองมุมมองคู่กัน: มุม clerk (มองตาม component) และมุม database (มองตามข้อมูลใน cache)

```sql
-- มุมที่ 1: clerk ใดบวมที่สุด
SELECT TOP (10) type,
       pages_kb / 1024.0 AS pages_mb,
       virtual_memory_committed_kb / 1048576.0 AS vm_committed_gb
FROM sys.dm_os_memory_clerks
ORDER BY pages_kb DESC;

-- มุมที่ 2: database ใดกิน data cache มากที่สุด
SELECT CASE database_id WHEN 32767 THEN 'RESOURCE DB' ELSE DB_NAME(database_id) END AS database_name,
       COUNT_BIG(*) AS cached_pages,
       COUNT_BIG(*) * 8 / 1024.0 AS cached_mb
FROM sys.dm_os_buffer_descriptors
GROUP BY database_id
ORDER BY cached_pages DESC;
```

**Expected (รันจริงบนเซิร์ฟเวอร์หลักสูตร):** clerk อันดับ 1 = `MEMORYCLERK_SQLBUFFERPOOL` ~333 MB, อันดับ 2 = `CACHESTORE_SQLCP` ~103 MB; ฝั่ง buffer descriptors — AdventureWorks ~242 MB (30,948 pages), tempdb ~73 MB, RESOURCE DB ~9 MB — เครื่องว่างค่าน้อย ให้อ่าน **สัดส่วน** เสมอ: ถ้า `CACHESTORE_SQLCP` โตจนแย่งอันดับ 1 จาก buffer pool นั่นคือ plan cache bloat จาก ad-hoc workload (แก้ที่ Module 8 — Optimize for Ad hoc Workloads) ไม่ใช่เพิ่ม RAM

> [!TIP]
> เจาะต่อว่า "ตารางไหนกิน cache ใน DB นั้น" ด้วยการ join `sys.dm_os_buffer_descriptors` → `sys.allocation_units` → `sys.partitions` ตาม Lab 4 Exercise 2 Step 2 — เป็นขั้นตอนที่เปลี่ยน "DB ไหน" เป็น "object ไหน ควรทำ index อะไร"

---

## 3. ขั้นที่ 2 — PLE: อ่านให้ถูกยุค ไม่ใช่ตัดสินด้วยเลข 300

**PLE** จาก counter `Page life expectancy` บอกว่า page หนึ่งอยู่ใน buffer pool "โดยเฉลี่ย" ได้นานกี่วินาที เกณฑ์เก่า "ต่ำกว่า 300 วินาที = แย่" มาจากยุค RAM 4–32 GB — บนเครื่องยุคนี้ **ค่าปกติคือหลักพันถึงหลักแสน** เพราะยิ่ง buffer pool ใหญ่ PLE ยิ่งโต และค่า counter ถูกวัด **ต่อ Buffer Node (ต่อ NUMA)** ไม่ใช่รวมทั้ง instance อีกต่อไป

วิธีอ่านที่ถูกต้องมี 3 ข้อ:

1. **อ่านต่อ node** ไม่ใช่ค่ารวม (ค่ารวมปิดบัง node ที่ถูกกดเฉพาะจุด)
2. **ดู trend ไม่ใช่ตัวเลขเดียว** — อาการ pressure คือรูป **ฟันเลื่อย (sawtooth)**: ตกฮวบ (ถูก trim / scan ใหญ่) แล้วไต่กลับ
3. **เทียบ baseline ของเครื่องนั้น** (Module 10) — คำถามคือ "ต่างจากปกติของมันไหม" ไม่ใช่ "เกิน 300 หรือยัง"

```sql
SELECT instance_name AS buffer_node,
       cntr_value AS page_life_expectancy_sec
FROM sys.dm_os_performance_counters
WHERE object_name LIKE '%Buffer Node%'
  AND counter_name = 'Page life expectancy'
ORDER BY instance_name;
```

**Expected (รันจริงบนเซิร์ฟเวอร์หลักสูตร — 1 NUMA node):** ได้แถว `000` เดียวค่า ~11,724–13,273 วินาที (เครื่องว่าง, buffer pool ยังเล็กหลัง restart) — ชี้ให้เห็นชัดว่า "300 วินาที" ไม่มีความหมายกับเครื่องยุคนี้; บนเครื่อง production 2-socket คุณจะได้หลายแถว (000, 001, …) และ node ที่ต่ำผิดปกติคือเบาะแส

> [!IMPORTANT]
> PLE ตกเป็นวงกว้าง "ครั้งเดียวจบ" หลังรัน query scan ตารางใหญ่ = **ปกติ** (ข้อมูลใหม่เข้ามาแทนที่ตามการออกแบบ) — ต้องกังวลเมื่อ PLE **ตกต่อเนื่องไม่กลับ** หรือตกซ้ำเป็นรอบโดยไม่มีเหตุที่รู้จัก และควรยืนยันด้วยพยานข้างล่าง (waits, clerks) ก่อนสรุปว่า pressure

---

## 4. ขั้นที่ 3 — Memory Waits: ฟังเสียงร้องของ engine

`sys.dm_os_wait_stats` คือบัญชีการรอสะสม (อ่านแบบ delta — Module 1.4) ชุด wait ที่เกี่ยวกับ memory:

| Wait | หมายถึง | ทิศทางแก้ |
|:-----|:--------|:----------|
| `RESOURCE_SEMAPHORE` | query รอคิวรับ memory grant | ลด sort/hash ใหญ่, statistics, ตรวจ grant feedback |
| `CMEMTHREAD` | ต่อคิวกันที่ memory object (spinlock) | พบน้อยลงบนรุ่นใหม่ — อัปเดต CU |
| `WRITE_PAGE` | รอเขียน dirty page (หนาแน่นช่วง checkpoint/flush) | ตรวจ I/O ฝั่ง data file (Module 2) |
| `RESERVED_MEMORY_ALLOCATION_EXT` | จอง memory สำหรับ workspace ช่วงตึง | คู่กับ grant pressure |
| `MEMORY_ALLOCATION_EXT` | จอง memory ทั่วไปจาก OS/SQLOS | มัก benign ถ้าเวลารวมน้อย |
| `PAGEIOLATCH_SH/EX` | รออ่าน page จากดิสก์ — ผลปลายทางของ cache ถูกไล่ | index, memory, storage (Module 2) |

```sql
SELECT wait_type, waiting_tasks_count,
       wait_time_ms / 1000.0 AS wait_s,
       max_wait_time_ms,
       signal_wait_time_ms / 1000.0 AS signal_s
FROM sys.dm_os_wait_stats
WHERE wait_type IN ('RESOURCE_SEMAPHORE', 'CMEMTHREAD', 'WRITE_PAGE',
                    'RESERVED_MEMORY_ALLOCATION_EXT', 'MEMORY_ALLOCATION_EXT')
ORDER BY wait_time_ms DESC;
```

**Expected (รันจริงบนเซิร์ฟเวอร์หลักสูตร):** `RESOURCE_SEMAPHORE` = 0 ครั้ง (instance ว่างไม่เคยรอ grant), `CMEMTHREAD` = 42 ครั้งรวม ~0.007 วิ (เบามาก — benign), `MEMORY_ALLOCATION_EXT` เป็นแสนครั้งรวม ~5.2 วิ (จำนวนมากแต่เวลารวมน้อย = ปกติของ engine ที่จอง memory ทั่วไป) — สังเกตว่า "จำนวนครั้งเยอะ" ไม่ใช่ปัญหา ต้องดู **เวลารวมและ max_wait**

---

## 5. ขั้นที่ 4 — Resource Semaphore: หน้าต่างคิวของ Memory Grant

เมื่อสงสัย internal pressure ที่ประตู grant — `sys.dm_exec_query_resource_semaphores` คือหน้าต่างดูคิว (บน SQL Server 2025/17.x คอลัมน์ใช้ชื่อ **`granted_memory_kb` / `used_memory_kb` / `grantee_count` / `waiter_count`** — ชื่อ `total_*` ยุคเก่าถูกถอดแล้ว):

```sql
SELECT resource_semaphore_id, pool_id,
       target_memory_kb / 1048576.0 AS target_gb,
       max_target_memory_kb / 1048576.0 AS max_target_gb,
       granted_memory_kb / 1024.0 AS granted_mb,
       used_memory_kb / 1024.0 AS used_mb,
       grantee_count, waiter_count,
       timeout_error_count, forced_grant_count
FROM sys.dm_exec_query_resource_semaphores
ORDER BY pool_id, resource_semaphore_id;
```

**Expected (รันจริงบนเซิร์ฟเวอร์หลักสูตร ขณะ instance ว่าง):** ได้ **4 แถว** = 2 resource pool (default, internal) × 2 semaphore ต่อ pool — semaphore ตัวใหญ่ (id 0) `target ≈ 8.2 GB` มี `max_target ≈ 9.0 GB`, ตัวเล็ก (id 1) `target ≈ 440 MB` ไม่มี max — ทุกแถว `grantee_count = 0`, `waiter_count = 0` (ไม่มีคนถือ ไม่มีคนรอ)

วิธีอ่านเมื่อเกิดเหตุ:

| คอลัมน์ | ค่าที่ควรระวัง | ความหมาย |
|:--------|:---------------|:----------|
| `waiter_count` | > 0 ค้างนาน | **หลักฐาน `RESOURCE_SEMAPHORE` จริง** — มี query ต่อคิวรอ grant |
| `granted_memory_kb` ≈ `target_memory_kb` | ใช่ และมี waiter | workspace เต็ม — ผู้ถือ grant กินจนหมด |
| `timeout_error_count` | โตขึ้น | มี query รอจน timeout (error 8645) — ผู้ใช้เห็น "หมดเวลา" โดยไม่รู้ต้นเหตุ |
| `forced_grant_count` | > 0 | engine ยอมจ่ายเกินเป้าให้ query ที่จำเป็น — สัญญาณ pressure ชัดเจน |

คู่กันคือ `sys.dm_exec_query_memory_grants` — รายชื่อผู้ถือ/ผู้รอ grant **ณ ขณะนั้น** พร้อมค่า `requested/granted/used/ideal_memory_kb` และ `wait_time_ms` ของผู้รอ (ตัวอย่างการจับสด + ตัวเลขจริงอยู่ใน [Section 4.2 หัวข้อ 5](../02_SQL_Server_Memory/README.md))

---

## 6. Lab เร็ว 60 วินาที — บังคับ Spill และเก็บหลักฐาน

Spill เกิดเมื่อ grant ที่ได้ < ข้อมูลที่ sort/hash ต้องจัดการ วิธีสร้างแบบ deterministic โดยไม่ต้องมี workload คู่ขนาน: ใช้ hint **`MAX_GRANT_PERCENT`** บีบ grant ให้เหลือ 1% ของ workspace

```sql
USE AdventureWorks;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #SpillDemo;
CREATE TABLE #SpillDemo (id INT IDENTITY PRIMARY KEY CLUSTERED, filler NVARCHAR(600) NOT NULL);
INSERT #SpillDemo (filler)
SELECT TOP (300000) REPLICATE(N'x', 580) + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 97 AS NVARCHAR(3))
FROM sys.all_objects AS a CROSS JOIN sys.all_objects AS b;
GO
-- เปิด Ctrl+M (Include Actual Execution Plan) ก่อนรัน — เห็น warning ที่ Sort operator
DECLARE @t DATETIME2 = SYSUTCDATETIME(), @c BIGINT;
SELECT @c = COUNT_BIG(*)
FROM (SELECT TOP (500) id, filler FROM #SpillDemo ORDER BY filler DESC, id) AS s
OPTION (MAX_GRANT_PERCENT = 1, MAXDOP 1);
SELECT DATEDIFF(MILLISECOND, @t, SYSUTCDATETIME()) AS elapsed_ms, @c AS rows_sorted;
GO
-- หลักฐาน spill จากระบบ (ไม่ต้องดูแค่ plan บนจอ)
SELECT TOP (3) qs.execution_count,
       qs.total_worker_time / 1000 AS worker_ms,
       qs.total_spills, qs.max_spills
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE st.text LIKE '%SpillDemo%' AND qs.total_spills > 0
ORDER BY qs.total_spills DESC;
GO
DROP TABLE IF EXISTS #SpillDemo;
GO
```

**Expected (รันจริงบนเซิร์ฟเวอร์หลักสูตร — ข้อมูล 332 MB, grant ถูกบีบเหลือ ~1% ของ workspace):** sort เสร็จใน ~8,900 ms (ช้ากว่า sort ธรรมชาติหลายเท่า) และใน actual plan มี warning สีเหลืองที่ Sort: *"Operator used tempdb to spill data during execution"*; query หลักฐานได้ `total_spills = 50,000`, `max_spills = 50,000` — **50,000 pages × 8 KB ≈ 390 MB ไหลลง tempdb** — นี่คือราคาของ grant ที่ขาด (จากข้อมูล 332 MB ที่ต้องจัดการ)

> [!NOTE]
> ในทางกลับกัน hint `MIN_GRANT_PERCENT` บังคับจ่ายอย่างต่ำ — ใช้ชั่วคราวเมื่อ query เล็กที่สำคัญถูกบีบ grant จนช้า แต่อย่าลืมว่ามันเพิ่มแรงกดที่ resource semaphore ให้คนอื่น

---

## 7. Memory Grant Feedback บน SQL Server 2025 (17.x) — อ่านจากที่เดียวเท่านั้น

กลไก (IQP, 2017+; persisted ลง Query Store ตั้งแต่ 2022) จดผลรอบก่อนแล้วปรับ grant รอบหน้า: **spill → เพิ่ม, overgrant → หด** — และบน build 17.x มีจุดเปลี่ยนที่ต้องรู้:

> [!WARNING]
> คอลัมน์ `sys.query_store_plan.is_memory_grant_feedback_adjusted` **ถูกถอดออกจาก SQL Server 2025 (17.x)** — query เดิมจะ error `Invalid column name 'is_memory_grant_feedback_adjusted'` ช่องทางที่ถูกต้องคือ **`sys.query_store_plan_feedback`** (รวม feedback ทุกตระกูล: Memory Grant, CE, DOP)

```sql
USE AdventureWorks;
GO
SELECT TOP (10) pf.plan_feedback_id, pf.plan_id,
       pf.feature_desc, pf.state_desc, pf.feedback_data
FROM sys.query_store_plan_feedback AS pf
ORDER BY pf.plan_feedback_id DESC;
```

**Expected (รันจริงบนเซิร์ฟเวอร์หลักสูตร):** เห็นแถว `feature_desc = 'Memory Grant Feedback'` พร้อม `state_desc = 'FEEDBACK_VALID'` และ `feedback_data` เป็น JSON ของการปรับ เช่น `{"NodeId":"1","AdditionalMemoryKB":"775416"}` (feedback รอบหนึ่งบนเครื่องหลักสูตรขอเพิ่มถึง ~757 MB ให้ plan ที่ spill) — แถว `CE Feedback` ที่ `NO_RECOMMENDATION` เป็นตระกูลเพื่อนบ้านใน DMV เดียวกัน

อ่านคู่กับประวัติ grant ของ query นั้น (join เต็มเพื่อเห็นข้อความ query):

```sql
USE AdventureWorks;
GO
SELECT TOP (5) pf.plan_feedback_id, pf.feature_desc, pf.state_desc,
       pf.feedback_data,
       LEFT(qt.query_sql_text, 80) AS query_text_sample
FROM sys.query_store_plan_feedback AS pf
JOIN sys.query_store_plan AS qsp ON pf.plan_id = qsp.plan_id
JOIN sys.query_store_query AS qsq ON qsp.query_id = qsq.query_id
JOIN sys.query_store_query_text AS qt ON qsq.query_text_id = qt.query_text_id
WHERE pf.feature_desc = 'Memory Grant Feedback'
ORDER BY pf.plan_feedback_id DESC;
```

**Expected:** แถว feedback พร้อมตัดข้อความ query มาให้เห็นว่า plan ไหนถูกปรับ — ตัวเลขเด่นจาก Lab 4: query sort เดิมได้ grant 682,944 KB (~667 MB) แต่ใช้จริง 12,160 KB (~12 MB) → รอบถัดไป feedback หดเหลือ 18,016 KB (~18 MB) — ประหยัด workspace ~97% โดยไม่แตะ query เลย

---

## 8. Ring Buffer RESOURCE_MONITOR — ยืนยัน External Pressure จากกล้องวงจรปิด

เมื่อสงสัยฝั่ง Windows — แทนที่จะนั่งรอจับ PerfMon ตอนเกิดเหตุ SQL Server บันทึกสัญญาณที่ Resource Monitor ได้รับไว้ใน ring buffer เสมอ:

```sql
SELECT TOP(20)
	DATEADD (ms, -1 * (ts_now - [timestamp]), GETDATE()) AS [EventTime]
,	record.value('(./Record/ResourceMonitor/Notification)[1]', 'varchar(50)') AS [Notification]
,	CASE record.value('(./Record/ResourceMonitor/Notification)[1]', 'varchar(50)')
		WHEN 'RESOURCE_MEMPHYSICAL_HIGH' THEN 'Fine (RAM > High Threshold)'
		WHEN 'RESOURCE_MEMPHYSICAL_LOW' THEN 'Memory Pressure! (RAM < Low Threshold)'
		WHEN 'RESOURCE_MEMPHYSICAL_STEADY' THEN 'Steady'
		ELSE 'Other'
	END AS [Meaning]
,	record.value('(./Record/MemoryNode/TargetMemory)[1]', 'bigint') / 1024 AS [Target_MB]
,	record.value('(./Record/MemoryNode/ReserveMemory)[1]', 'bigint') / 1024 AS [Reserved_MB]
,	record.value('(./Record/MemoryNode/CommittedMemory)[1]', 'bigint') / 1024 AS [Committed_MB]
,	record.value('(./Record/MemoryNode/SharedMemory)[1]', 'bigint') / 1024 AS [Shared_MB]
,	record.value('(./Record/MemoryNode/AWEMemory)[1]', 'bigint') / 1024 AS [AWE_MB]
FROM (
	SELECT
		[timestamp]
	,	CONVERT(XML, record) AS record
	,	(SELECT cpu_ticks / (cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info) AS ts_now
	FROM sys.dm_os_ring_buffers
	WHERE ring_buffer_type = 'RING_BUFFER_RESOURCE_MONITOR'
) AS T
ORDER BY [EventTime] DESC;
```

**Expected (รันจริงบนเซิร์ฟเวอร์หลักสูตร):** รายการล่าสุดเป็น `RESOURCE_MEMPHYSICAL_HIGH` — `Target_MB ≈ 13,574` (สคริปต์รันช่วงหลัง restart: `Committed_MB ≈ 232`) — เครื่องว่างจึงไม่เห็นเหตุการณ์ LOW; เมื่อเกิด external pressure จริง คุณจะเห็นแถว `RESOURCE_MEMPHYSICAL_LOW` เรียงตามเวลาที่เหตุการณ์เกิด พร้อม `Target_MB` ที่ถูกลดลง — ใช้กำหนดเวลาเหตุการณ์คู่กับ baseline

| Notification | แปลว่า | สิ่งที่ SQL Server ตอบสนอง |
|:-------------|:--------|:---------------------------|
| `RESOURCE_MEMPHYSICAL_HIGH` | RAM เหลือเฟือ | ขยาย target ได้เต็มกฎ |
| `RESOURCE_MEMPHYSICAL_STEADY` | ทรงตัว | ใช้ต่อเนื่อง |
| `RESOURCE_MEMPHYSICAL_LOW` | **Windows ขาด RAM** | ลด target + **trim caches** คืน memory |
| `RESOURCE_MEMVIRTUAL_LOW` | ฝั่ง commit limit ตึง | เหมือนกันแต่ต้นเหตุเป็น page file/VAS |

---

## 9. PVS — เมื่อ Version Store ก็มีส่วนในเรื่อง Memory

นิยามก่อนใช้: ฐานข้อมูลที่เปิด **RCSI / Snapshot isolation** ต้องเก็บ **row version** เก่า ๆ ให้ query ที่อ่าน "ภาพของอดีต" — ก่อน SQL Server 2019 version เหล่านี้อาศัย tempdb; **ตั้งแต่ 2019 เป็น PVS (Persistent Version Store)** เก็บใน data file ของ DB เอง และ page ของมันก็อยู่ใน buffer pool เหมือน page ทั่วไป → **transaction ยาวที่ไม่ยอม commit ทำให้ PVS โตและกิน cache ของคนอื่น** และถ้าตั้ง tempdb version store ยุคเก่า ก็จะเห็นเป็น tempdb บวม

```sql
-- ตัวอย่าง: เปิด transaction ค้างให้เกิด version จริง (แล้ว rollback ทันที — ข้อมูลไม่เปลี่ยน)
USE AdventureWorks;
GO
BEGIN TRAN;
UPDATE Person.Person SET Suffix = Suffix WHERE BusinessEntityID BETWEEN 1 AND 5;
SELECT DB_NAME(database_id) AS db_name,
       persistent_version_store_size_kb AS pvs_kb,
       current_aborted_transaction_count AS aborted_tx
FROM sys.dm_tran_persistent_version_store_stats
WHERE database_id = DB_ID();
ROLLBACK TRAN;
GO
SELECT DB_NAME(database_id) AS db_name,
       persistent_version_store_size_kb AS pvs_kb,
       current_aborted_transaction_count AS aborted_tx
FROM sys.dm_tran_persistent_version_store_stats
WHERE database_id = DB_ID();
GO
```

**Expected (รันจริงบนเซิร์ฟเวอร์หลักสูตร — AdventureWorks เปิด RCSI อยู่):** ระหว่าง transaction เปิดอยู่ ได้แถว `AdventureWorks` ปรากฏใน DMV (`pvs_kb = 8` จากแถวที่ถูก version) — ก่อนมี transaction ใดสร้าง version หลัง restart ตารางนี้อาจไม่มีแถวของ DB คุณเลย (เห็นเฉพาะ system DBs ค่า 0) — หลัง ROLLBACK version กลายเป็น aborted และ **background cleaner จะกวาดออกเอง**; ในหน้างานจริงค่าที่ต้องจับตาคือ `persistent_version_store_size_kb` โตต่อเนื่อง + `current_aborted_transaction_count` ค้าง ซึ่งเป็นสัญญาณ transaction ยาว/rollback ใหญ่

> [!TIP]
> จำแผนที่กว้าง ๆ ไว้: **memory ที่หายไปเงียบ ๆ มีตัวการที่พบบ่อย 3 กลุ่ม** — plan cache บวม (Module 8), grant กินเต็ม workspace (หัวข้อ 5 ของ section นี้), และ version store โตจาก transaction ยาว (หัวข้อนี้) — ทั้งสามอ่านออกจาก clerks ได้หมด

---

## 10. เช็คลิสต์วินิจฉัย Memory Pressure ทีละขั้น

1. **จับเวลาเหตุการณ์** — จาก baseline/alert: เกิดเมื่อไร, นานแค่ไหน, workload อะไรรันอยู่
2. **ตัดสิน external ก่อน** — `sys.dm_os_sys_memory` (`system_low_memory_signal_state`), `sys.dm_os_process_memory` (`process_physical_memory_low`) → ถ้าเป็นบวก ไล่ดู ring buffer หาเวลาเหตุการณ์ แล้วไปหาตัวกิน RAM บนเครื่อง
3. **ถ้า internal** — clerks ใครบวม? buffer descriptors DB ไหน? `CACHESTORE_SQLCP` หรือ version store หรือ grant?
4. **ดูคิว grant** — `sys.dm_exec_query_resource_semaphores` (`waiter_count`, `timeout_error_count`) + `sys.dm_exec_query_memory_grants`
5. **ตรวจ spill และ feedback** — spill warnings / `total_spills` + `sys.query_store_plan_feedback` (feedback แก้เองได้หรือยัง)
6. **PLE ต่อ node คู่ trend** — sawtooth หรือตกถาวร? เทียบ baseline
7. **แก้จุดเดียว → วัดซ้ำ** — อย่าแก้หลายอย่างพร้อมกัน ไม่งั้นไม่รู้ว่าอะไรได้ผล

---

## สรุป Section 3

1. Pressure มี **สองหน้า** — external (Windows ขาด RAM) กับ internal (SQL แย่งกันเอง) — เครื่องมือแยกคู่แรกคือ `sys.dm_os_sys_memory` / `sys.dm_os_process_memory` กับ resource semaphore DMVs
2. **PLE ต้องอ่านต่อ Buffer Node, ดู trend, เทียบ baseline** — เกณฑ์ 300 วินาทีใช้กับโลกไม่ได้แล้ว
3. `waiter_count > 0` = `RESOURCE_SEMAPHORE` จริง; `forced_grant_count` / `timeout_error_count` คือปริมาณความเจ็บ
4. **Spill สร้างได้ deterministic ด้วย `MAX_GRANT_PERCENT`** และมีหลักฐานตัวเลขที่ `total_spills` — คู่กับ Memory Grant Feedback ที่อ่านจาก `sys.query_store_plan_feedback` บน 17.x
5. **Ring buffer RESOURCE_MONITOR** คือกล้องบันทึกสัญญาณจาก Windows ย้อนหลังได้ และ **PVS** คือตัวแปรใหม่ (2019+) ที่ transaction ยาวทำให้กิน buffer pool

### ตรวจความเข้าใจ

1. PLE ที่เคยดี 40,000 วินาที ตกไป 2,000 วินาทีแล้วไต่กลับภายใน 5 นาที กับตกไป 2,000 แล้วค้างต่ำตลอด — กรณีไหนต้องลงมือแก้ และเพราะอะไร?
2. `sys.dm_exec_query_resource_semaphores` รายงาน `granted_memory_kb ≈ target_memory_kb` และ `waiter_count = 3` — แปลสถานการณ์นี้เป็นภาษาคน พร้อมระบุ wait type ที่ผู้รอกำลังเจอ
3. ทำไม query ที่ sort ข้อมูล 332 MB ภายใต้ grant บีบ 1% จึงช้า ~9 วินาที ทั้งที่ข้อมูลทั้งก้อน "แค่เรียงแถว" — ราคาที่ซ่อนอยู่คืออะไร และวัดได้จากคอลัมน์ใด?
4. บน SQL Server 2025 คุณรัน query เก่าที่อ่าน `sys.query_store_plan.is_memory_grant_feedback_adjusted` แล้ว error — อธิบายเหตุผลและชี้ query ทดแทนพร้อมคอลัมน์สำคัญ
5. เหตุการณ์ `RESOURCE_MEMPHYSICAL_LOW` ใน ring buffer เมื่อวานตีสาม — ขั้นตอนถัดไปของคุณคืออะไร (ตามเช็คลิสต์) และใครคือผู้ต้องสงสัยเป็นอันดับแรก?
6. DB เปิด RCSI และ `persistent_version_store_size_kb` โตช่วงบ่ายทุกวัน — สัญญาณนี้ชี้ไปที่ pattern การเขียนโค้ดแบบใด และ clerk ใดควรถูกตรวจคู่กัน?

**➡ ถัดไป:** [Section 4.4 — In-Memory OLTP](../04_In_Memory_OLTP/README.md)

---

[⬅ Module 04](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [04 In-Memory OLTP](../04_In_Memory_OLTP/README.md)
