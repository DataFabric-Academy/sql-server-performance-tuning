[⬅ Module 09](../../README.md) | Section 1/2 | ➡ ถัดไป: [9.2 Working With Extended Events](../02_Working_With_Extended_Events/README.md)

# 9.1 Extended Events Core Concepts — สถาปัตยกรรมของ "กล้องติดตาม" ที่เบาที่สุดใน SQL Server

> *"Wait Statistics บอกว่าระบบ 'รออะไร' — แต่ Extended Events คือกล้องถ่ายทุกเหตุการณ์ที่เกิดขึ้นจริง ตัวต่อตัว เมื่อคุณต้องการเห็นภาพละเอียดถึงระดับ statement"* 

> **ต้องรู้มาก่อน**: [Extended Events](../../../Glossary.md), [Wait Statistics](../../../Glossary.md) (`sys.dm_os_wait_stats` จาก Section 1.4 — XE คือขั้นถัดไปจากการอ่านค่ารวม), [Blocking](../../../Glossary.md) / [Deadlock](../../../Glossary.md) (Module 5 — เราจะจับเหตุการณ์เหล่านี้ด้วย XE), [DMV](../../../Glossary.md), [AdventureWorks](../../../Glossary.md)
> **สิทธิ์ที่ต้องมี**: `VIEW SERVER STATE` สำหรับอ่าน DMV ของ XE · การสร้าง session ต้องใช้สิทธิ์ `ALTER ANY EVENT SESSION` (sysadmin ได้อัตโนมัติ)

---

## ทำไมหลักสูตรนี้จึงสอน Extended Events

ตลอดหลักสูตร เราวินิจฉัยด้วย **ตัวเลขสะสม**: `sys.dm_os_wait_stats` (Module 1) เป็นบัญชีการรอ "รวมทั้งเซิร์ฟเวอร์ตั้งแต่ restart", file stats (Module 2) เป็นค่าเฉลี่ยต่อไฟล์ ตัวเลขเหล่านี้บอก "บริเวณที่เป็นปัญหา" ได้ดี แต่ตอบคำถามระดับหนึ่งต่อหนึ่งไม่ได้ เช่น:

- "Statement ไหนเป็นคนสร้าง wait `WRITELOG` เหล่านี้?"
- "deadlock เกิดตอนตีสามคืนนี้ — ใครอ่านใครเขียนอะไร?" 
- "ระบบนี้มี query ที่วิ่งเกิน 3 วินาทีคืนนี้กี่ตัว เขียนว่าอะไร?"

**Extended Events (XEvents / XE)** คือระบบติดตามเหตุการณ์ (event tracing framework) ที่ฝังอยู่ในตัว engine — มันคือ "กล้องซูม" ที่บันทึกเหตุการณ์ทีละเหตุการณ์ พร้อมข้อมูลประกอบ (ใคร รันอะไร กินเวลาเท่าไร) โดยมี overhead ต่ำมาก และตั้งเงื่อนไขกรองตั้งแต่จุดเกิดเหตุได้

โมดูลนี้เป็น 1 ใน 3 แล็บจุดปิดคอร์ส: ผู้เรียนจะสร้าง session จับ slow query + deadlock (ต่อยอด Module 5) + long-running query ด้วยตัวเอง และนำไปใช้ต่อใน Module 10–11 (Monitoring & Troubleshooting)

---

## 1. Profiler ยุคเก่า vs Extended Events — เหตุผลที่ต้องเปลี่ยนเครื่องมือ

### 1.1 SQL Trace / SQL Server Profiler คืออะไร (เพื่อรู้ว่ากำลังเลิกใช้อะไร)

**SQL Trace** คือเทคโนโลยี tracing รุ่นเก่า (ตั้งแต่ยุค SQL Server 7) ที่ถูกออกแบบให้ส่งเหตุการณ์ **แบบ synchronous** — ทุกเหตุการณ์ที่ engine สร้าง จะต้องรอระบบ trace รับก่อน แล้ว engine จึงทำงานต่อ ส่วน **SQL Server Profiler** คือโปรแกรมหน้าจอ (GUI) ที่ใช้เปิดดู trace แบบสด

ปัญหาเกิดเมื่อ server รับ workload หนัก: การบังคับ engine รอ GUI แสดงผลทีละเหตุการณ์ = ต้นทุนทับซ้อน (overhead) ที่วัดกันมาแล้วว่า **อาจสูงถึงระดับสิบเปอร์เซ็นต์ของ throughput** — บนระบบ production นี่คือการทำให้ระบบช้าลงเพื่อตรวจว่าทำไมช้า

> [!IMPORTANT]
> SQL Trace และ SQL Server Profiler ถูกประกาศ **deprecated** (แนะนำให้เลิกใช้) มาตั้งแต่ยุค SQL Server 2012 และถูกถอดออกจากเครื่องมือมาตรฐานรุ่นใหม่แล้ว — SSMS รุ่นปัจจุบัน (21+) ไม่มี Profiler ของ relational engine อีกต่อไป แนวทางทางการของ Microsoft คือ XEvents **100%**

### 1.2 ตารางเทียบ — ทำไม XEvents เบากว่า

| มิติ | SQL Trace / Profiler | Extended Events |
|:-----|:---------------------|:----------------|
| โมเดลส่งข้อมูล | Synchronous — engine รอ trace รับข้อมูล | **Asynchronous** — engine เขียนลง memory buffer แล้วทำงานต่อทันที |
| Overhead กับ workload | สูง (กรณีแย่อาจถึงระดับสิบเปอร์เซ็นต์) | ต่ำมากเมื่อออกแบบ session ถูก (กรองให้แคบ) |
| การกรองข้อมูล | Filter ทำงานหลังเก็บเหตุการณ์ | **Predicate กรองตั้งแต่จุดเกิดเหตุ** (Early Filtering) |
| ตัวเลือกปลายทาง | Trace file ชนิดเดียว | ring_buffer, event_file, histogram, event_counter ฯลฯ (Section 9.2) |
| ความลึกของข้อมูล | Event classes ชุดเดิม ไม่ขยาย | เหตุการณ์เพิ่มตาม engine ทุกรุ่น — จับได้ลึกถึงระดับ internals |
| สถานะ | **Deprecated** | Recommended — เครื่องมือหลักของ Microsoft |

> **จุดเชื่อมโยง:** SSMS ยังมีเมนู **XEvent Profiler** (Object Explorer → เชื่อมต่อ server → ล่างสุด) ที่ให้ UX คล้าย Profiler เดิมแต่สร้างเป็น XE session จริง ๆ ข้างใน — เหมาะกับ "ดูสดแบบเร็ว" ส่วนงานจริงในหลักสูตรนี้เราเขียน T-SQL เพื่อควบคุม predicate และ target ละเอียดกว่า (และเก็บเป็นสคริปต์ได้)

---

## 2. สถาปัตยกรรม XEvents — 7 คำที่ต้องนิยามให้แม่น

ก่อนเขียน session ใด ๆ ต้องผ่านศัพท์ 7 คำนี้ก่อน — ทุกคำสั่ง `CREATE EVENT SESSION` ใน Section 9.2 จะประกอบจากศัพท์เหล่านี้ทั้งหมด

### 2.1 Package — คลังส่วนประกอบ

**Package** คือหน่วยบรรจุ (container) ของ metadata: events, actions, types, targets, maps ถูกจัดกลุ่มไว้ข้างใน ตัวที่ใช้บ่อย:

| Package | บรรจุอะไร | ตัวอย่าง |
|:--------|:----------|:---------|
| `package0` | ของระบบส่วนกลาง — targets ทั้งหมดอยู่นี่ | target `ring_buffer`, `event_file` |
| `sqlserver` | เหตุการณ์ของ Database Engine (ส่วนใหญ่ที่เราใช้) | `sql_statement_completed`, `error_reported` |
| `sqlos` | เหตุการณ์ของ SQLOS | `wait_info` (จาก Module 1) |
| `qds` | Query Store | เหตุการณ์ฝั่ง Query Store (Module 8) |
| `SecAudit` | เหตุการณ์ audit (เป็น private package) | audit events ของ SQL Audit |
| `XtpEngine` | In-Memory OLTP (Hekaton) | เหตุการณ์ฝั่ง memory-optimized table |

> สังเกตรูปแบบการเรียกชื่อเต็ม: `sqlserver.sql_statement_completed` = เหตุการณ์ `sql_statement_completed` จาก package `sqlserver` และ target ทุกตัวเริ่มด้วย `package0.` เสมอ

### 2.2 Event — จุด instrument ใน engine

**Event** คือจุดตรวจ (instrumentation point) ที่ทีมพัฒนา engine ฝังไว้ใน code — เมื่อ flow ของงานผ่านจุดนั้น ข้อมูลบริบทจะถูกเตรียมให้ session ที่สนใจ ตัวอย่างที่ใช้ในหลักสูตร:

| Event | เกิดเมื่อไร | ใช้ตรวจอะไร |
|:------|:-----------|:------------|
| `sqlserver.sql_statement_completed` | statement จบการทำงาน | ความช้า/ค่า read ของแต่ละ statement |
| `sqlserver.rpc_completed` | stored proc (RPC call) จบ | ประสิทธิภาพฝั่ง application |
| `sqlserver.sql_batch_completed` | batch จบ | workload ที่ส่งมาจาก sqlcmd/SSMS |
| `sqlserver.error_reported` | error ถูกรายงานไปยังผู้เรียก | error ที่ app กลืนหาย |
| `sqlserver.xml_deadlock_report` | deadlock เกิด (engine เลือก victim แล้ว) | **Deadlock Graph** (ต่อจาก Module 5) |
| `sqlserver.blocked_process_report` | process ถูก block นานเกินค่าที่ตั้ง | Blocking ยาว (ต่อจาก Module 5) |
| `sqlos.wait_info` | task เริ่ม/จบการรอ wait | แยก wait ต่อ statement (ต่อจาก Module 1) |

ข้อมูลที่ event แจกมาให้เองเรียกว่า **Payload** (event fields) — เช่น payload ของ `sql_statement_completed` มี `duration`, `cpu_time`, `logical_reads`, `row_count` รู้ลึกได้ด้วย catalog query ในหัวข้อ 3

### 2.3 Predicate — ด่านกรองที่จุดเกิดเหตุ

**Predicate** คือเงื่อนไขที่ engine ประเมิน **ก่อน** เขียนเหตุการณ์ลง buffer — ไม่ผ่านเงื่อนไข = เหตุการณ์นั้นไม่เกิดต้นทุนเก็บข้อมูลเลย นี่คือหัวใจของ "overhead ต่ำ": จับเฉพาะที่สนใจ เช่น `WHERE duration > 500000` (ช้ากว่า 500 มิลลิวินาที)

> [!WARNING]
> ข้อจำกัดจากการทดสอบจริงบน SQL Server 2025 (17.0.1135.8): **predicate ห้ามเรียกฟังก์ชัน T-SQL เช่น `DB_ID()`** — จะได้ `Incorrect syntax near 'DB_ID'` ให้ใช้ field ที่ engine จัดมาให้ เช่น `sqlserver.database_name = N'AdventureWorks'` หรือใส่ตัวเลข `database_id` ตรง ๆ

### 2.4 Action — ข้อมูลเสริมที่ "ดึงมาจากสภาพแวดล้อม"

**Action** คือข้อมูลเสริม (เรียกอีกอย่างว่า global fields เพราะดึงจากสถานะร่วมของ engine) ที่เราสั่งเพิ่มให้เหตุการณ์ เช่น `sql_text` (ข้อความ SQL), `client_app_name`, `username`, `session_id`, `database_name`

ข้อแลกเปลี่ยน: action **มีต้นทุน** — เพราะต้องไปดึงข้อมูลจากสถานะของ engine ที่จุดเกิดเหตุ เลือกเฉพาะที่จะใช้วิเคราะห์จริง อย่าขอเก็บถัวเฉลี่ย

### 2.5 Target — ปลายทางของข้อมูล

**Target** คือผู้บริโภคข้อมูล (consumer) ที่รับเหตุการณ์จาก buffer ไปเก็บ/รวมผล บน SQL Server 2025 มีให้ใช้:

| Target | เก็บที่ไหน | เหมาะกับ | เจาะลึก |
|:-------|:----------|:---------|:--------|
| `ring_buffer` | Memory แบบวงกลม (FIFO — เต็มแล้วเขียนทับของเก่า) | ดูสด แก้ปัญหาจุดเดียว ไม่ต้องการ retention | 9.2 หัวข้อ 3 |
| `event_file` | ไฟล์ `.xel` บนดิสก์ + rollover | Production ระยะยาว ข้อมูลต้องไม่หาย | 9.2 หัวข้อ 4 |
| `histogram` | Memory — จัดกลุ่มแล้วนับจำนวน | ใครเกิดบ่อยสุด (error ไหน, object ไหน) | 9.2 หัวข้อ 3 |
| `event_counter` | Memory — นับจำนวนอย่างเดียว | รู้ว่าเกิดกี่ครั้ง ไม่สนเนื้อหา | 9.2 หัวข้อ 3 |
| `pair_matching` | Memory — จับคู่เหตุการณ์เริ่ม/จบ | หาเหตุการณ์ที่เริ่มแล้วไม่จบ (orphan) | หมายเหตุ |
| `event_stream` | สตรีมสดแบบ asynchronous | ตัวกลางให้เครื่องมืออ่านสด | หมายเหตุ |
| `compressed_history` | ประวัติเหตุการณ์แบบ compressed (**ใหม่ใน 2025**) | เก็บสตรีมเหตุการณ์ย้อนหลังกินพื้นที่ต่ำ | หมายเหตุ |

> [!NOTE]
> หัวข้อ 9.2 จะใช้จริง 4 ตัวหลัก: `ring_buffer`, `event_file`, `histogram`, `event_counter` — ส่วน `pair_matching` (ต้องกำหนดคู่ begin/end event ละเอียด), `event_stream` และ `compressed_history` (ใช้กับเครื่องมือระดับสูง) รู้จักไว้ก่อน ไม่ใช่ในแล็บ

### 2.6 Session — รวมทุกอย่างเป็นระบบที่สั่ง START ได้

**Event Session** คือนิยาม (definition) ที่ผูก event + predicate + action + target เข้าด้วยกัน พร้อมนโยบาย memory และเวลา dispatch — session เป็น **object ระดับ server** (สร้างที่ไหนก็ได้ ไม่ต้องอยู่ DB ไหนเป็นการเฉพาะ) และมีสถานะ CREATE = ยังไม่ทำงาน / START = เริ่มเก็บ / STOP = หยุดเก็บ (นิยามยังอยู่) / DROP = ลบ

### 2.7 Types & Maps — แปลเลขให้คนอ่านได้

- **Type** = ประเภทข้อมูลของแต่ละ field (`int64`, `uint32`, `unicode_string`, `binary_data` ...) — สำคัญตอน `.value()` ระบุ SQL type ให้ตรง
- **Map** = ตารางแปลงค่าตัวเลขภายในเป็นข้อความ — เช่น payload `wait_type` ของ `sqlos.wait_info` เป็นตัวเลข, map `wait_types` แปลง `4` → `LCK_M_S`

---

## 3. แผนที่แรก: ค้นหา components ด้วย catalog queries

เครื่องมือสำรวจของ XEvents คือ DMV ตระกูล `sys.dm_xe_*` — ก่อนเขียน session ให้คุ้นกับการ "ถาม catalog" ว่ามีอะไรให้ใช้บ้าง ทุก query ต่อไปนี้ทดสอบแล้วบน SQL Server 2025 (17.0.1135.8)

### 3.1 มี package อะไรบ้าง

```sql
SELECT p.name, p.capabilities_desc
FROM sys.dm_xe_packages AS p
ORDER BY p.name;
```

> [!NOTE]
> จะเห็นชื่อซ้ำได้ (เช่น `sqlserver` มีหลายแถว) เพราะ catalog เก็บ "ชุด metadata" หลายชุดที่ใช้ชื่อเดียวกัน — จึง join ด้วย `guid` เสมอ ไม่ใช่ชื่อ และเห็น `SecAudit` ที่ระบุ `capabilities_desc = private` (ออกแบบไว้ให้ SQL Audit ใช้เอง)

### 3.2 มี event อะไรใน package ที่สนใจ (ค้นด้วยชื่อ)

```sql
SELECT p.name AS package_name, o.name, o.description
FROM sys.dm_xe_objects AS o
JOIN sys.dm_xe_packages AS p ON p.guid = o.package_guid
WHERE p.name = N'sqlserver' AND o.object_type = N'event'
  AND o.name LIKE N'%deadlock%'
ORDER BY o.name;
```

เปลี่ยน `LIKE` ตามสิ่งที่หา — `'%completed%'`, `'%lock%'`, `'%wait%'` ได้ตามต้องการ คอลัมน์ `object_type` ยังใช้กรองได้อีกหลายแบบ: `event`, `action`, `target`, `type`, `map`

### 3.3 Event หนึ่งตัวมี payload อะไรบ้าง (ตัวอย่าง sql_statement_completed)

```sql
SELECT c.column_type, c.name, c.type_name, c.description
FROM sys.dm_xe_object_columns AS c
WHERE c.object_package_guid = (SELECT TOP (1) guid FROM sys.dm_xe_packages WHERE name = N'sqlserver')
  AND c.object_name = N'sql_statement_completed'
  AND c.column_type = N'data'
ORDER BY c.column_id;
```

ผลจริงบน 2025 ให้ payload 14 ฟิลด์ เช่น:

| Field | Type | ความหมาย (จาก description จริง) |
|:------|:-----|:-------------------------------|
| `duration` | int64 | เวลาที่ statement ใช้ — **หน่วยไมโครวินาที** (µs) |
| `cpu_time` | uint64 | CPU ที่ใช้จริง (µs) |
| `logical_reads` | uint64 | จำนวน logical page reads |
| `physical_reads` | uint64 | จำนวน physical page reads |
| `writes` | uint64 | จำนวน page writes |
| `row_count` | uint64 | จำนวนแถวที่แตะ |
| `spills` | uint64 | จำนวน page ที่ spill ลง tempdb |
| `statement` | unicode_string | ข้อความของ statement |

> [!IMPORTANT]
> **จำหน่วยให้ขึ้นใจ: เวลาใน XEvents เป็นไมโครวินาที (µs)** — 500 มิลลิวินาที = `500000` เผลอเขียน `500` คือจับเกือบทุก event ในระบบ และอ่านผลแล้วลืมหาร 1,000 ก็จะคิดว่า query ช้าพันเท่า

### 3.4 มี action อะไรให้ขอได้บ้าง

```sql
SELECT p.name AS package_name, o.name, o.description
FROM sys.dm_xe_objects AS o
JOIN sys.dm_xe_packages AS p ON p.guid = o.package_guid
WHERE p.name = N'sqlserver' AND o.object_type = N'action'
  AND o.name IN (N'sql_text', N'client_app_name', N'username',
                 N'client_hostname', N'session_id', N'database_name', N'plan_handle')
ORDER BY o.name;
```

### 3.5 มี target อะไรบ้างบนรุ่นนี้

```sql
SELECT p.name AS package_name, o.name, o.description
FROM sys.dm_xe_objects AS o
JOIN sys.dm_xe_packages AS p ON p.guid = o.package_guid
WHERE p.name = N'package0' AND o.object_type = N'target'
ORDER BY o.name;
```

บน 17.0.1135.8 ได้ 8 ตัว: `compressed_history`, `etw_classic_sync_target`, `event_counter`, `event_file`, `event_stream`, `histogram`, `pair_matching`, `ring_buffer`

### 3.6 Maps — แปลรหัสเป็นข้อความ (ตัวอย่าง wait_types)

```sql
SELECT TOP (10) mv.map_key, mv.map_value
FROM sys.dm_xe_map_values AS mv
JOIN sys.dm_xe_packages AS p ON p.guid = mv.object_package_guid
WHERE p.name = N'sqlos' AND mv.name = N'wait_types'
ORDER BY mv.map_key;
```

ผลแรก ๆ จะเป็น `1 → LCK_M_S`, `2 → LCK_M_SCH_M` ... นี่คือรายชื่อ wait เดียวกับที่เราอ่านจาก `sys.dm_os_wait_stats` ใน Module 1 — เวลาจับ event `sqlos.wait_info` payload `wait_type` เป็นตัวเลข ต้อง join กับ map นี้จึงอ่านได้

---

## 4. กลไกที่ทำให้ "เบา": Buffer + Dispatcher + Event Loss Policy

นี่คือหัวใจของสถาปัตยกรรม — เข้าใจแล้วจะเข้าใจทุกตัวเลือก (option) ใน `CREATE EVENT SESSION ... WITH (...)` ใน Section 9.2

```
        Thread ที่รัน Query (hot path — ต้องเร็วที่สุด)
        ─────────────────────────────────────────────
        Event เกิด → ประเมิน Predicate → ผ่าน? → รวม Action
                                   │
                                   ▼  (เขียนลง memory เท่านั้น — เร็วมาก)
                      ┌──────────────────────┐
                      │  Session Buffer      │  (จัดสรรจาก MAX_MEMORY)
                      │  ┌────┬────┬────┐    │
                      │  │ E1 │ E2 │ E3 │    │
                      │  └────┴────┴────┘    │
                      └─────────┬────────────┘
                                │  Dispatcher thread (background)
                                │  ดึงไป target ทุก MAX_DISPATCH_LATENCY
                                ▼
                   ┌─────────────────────────────┐
                   │ Target: ring_buffer (RAM)   │
                   │ Target: event_file (.xel)   │
                   │ Target: histogram / counter │
                   └─────────────────────────────┘
```

1. **Thread ของ query ไม่รอ I/O เลย** — ทำหน้าที่แค่ "ยัดข้อมูลเหตุการณ์ลง buffer" แล้วกลับไปทำงานต่อ ต่างจาก SQL Trace ที่ thread ต้องรอระบบ trace รับ
2. **Dispatcher** คือ background thread ที่ตื่นมาดึง buffer ส่งต่อ target — `MAX_DISPATCH_LATENCY` คือ "สัญญาว่าข้อมูลจะถึง target ภายในกี่วินาที" (ค่าที่เราตั้งในแล็บคือ 5–10 วินาที) — อ่านผลระหว่างรอจะยังไม่เห็น event ล่าสุด
3. **Event Loss Policy (`EVENT_RETENTION_MODE`)** — ถ้า event ไหลเข้าเร็วกว่า dispatcher ระบาย ต้องเลือกว่าจะเสียอะไร:

| Option | พฤติกรรมเมื่อ buffer กดดัน | เหมาะกับ |
|:-------|:--------------------------|:---------|
| `ALLOW_SINGLE_EVENT_LOSS` (default) | ทิ้ง event เดี่ยว ๆ ที่เก่าสุด | ระบบ production ทั่วไป — ปลอดภัยกับ workload |
| `ALLOW_MULTIPLE_EVENT_LOSS` | ทิ้งทั้ง buffer เมื่อเต็ม | workload หนักมาก ยอมเสียข้อมูลแลกความเบาสุด |
| `NO_EVENT_LOSS` | **บังคับ thread ของ query รอ** (block) จน buffer ว่าง | กรณีที่ข้อมูลขาดแม้แต่ event เดียวไม่ได้ — **ใช้ระวัง** เพราะความช้าย้อนกลับไปทำร้าย workload เหมือน SQL Trace ยุคเดิม |

> [!TIP]
> ดูพฤติกรรมจริงได้จาก DMV — ตอนอ่าน session ที่กำลังรัน คอลัมน์ `buffer_policy_desc` จะโชว์ policy ที่ตกลงไว้ (`drop_event` เมื่อ ALLOW_SINGLE_EVENT_LOSS, `block` เมื่อ NO_EVENT_LOSS) และ `dropped_event_count` คือจำนวน event ที่ถูกทิ้งไปแล้ว — ถ้าตัวเลขนี้โต แปลว่า session ออกแบบบางเกิน (หรือ workload หนักเกิน) ต้องกรองให้แคบลงหรือลด action

### ตัวเลือกเวลาที่ต้องรู้ก่อนเข้า 9.2

| Option | ควบคุมอะไร | ค่าที่ใช้บ่อยในหลักสูตร |
|:-------|:-----------|:------------------------|
| `MAX_MEMORY` | งบ memory ทั้ง session สำหรับ buffer | 4096 KB |
| `MAX_DISPATCH_LATENCY` | เวลาสูงสุดก่อน buffer ถูกส่งต่อ target | 5–10 SECONDS |
| `EVENT_RETENTION_MODE` | นโยบายเมื่อ buffer กดดัน (ตารางด้านบน) | default |
| `STARTUP_STATE` | ให้ session START เองตอน server restart หรือไม่ | ON สำหรับ production capture |
| `TRACK_CAUSALITY` | ติด chain id ให้ event ชุดเดียวกัน (ดูข้าม thread/parallel) | ON เมื่อวิเคราะห์รอบการทำงานหนึ่ง ๆ |

---

## 5. Session ของระบบที่รันอยู่แล้ว — และ DMV สองมุม

### 5.1 สองมุมมอง: "นิยาม" กับ "กำลังรัน"

สับสนกันบ่อย — XEvents มี 2 กลุ่ม view ที่ตอบคนละคำถาม:

| View | ตอบคำถามว่า | มีเมื่อไร |
|:-----|:------------|:---------|
| `sys.server_event_sessions` (catalog) | มี session "นิยาม" ไว้ใน server หรือไม่ (รวมที่ STOP อยู่) | ตั้งแต่ CREATE ถึง DROP |
| `sys.dm_xe_sessions` (DMV) | ตอนนี้ session "กำลังรัน" อะไรอยู่ + สถิติ buffer | เฉพาะตอน START |

### 5.2 ดูของจริงบน server ของเรา

```sql
SELECT s.name AS session_name,
       s.total_buffer_size / 1024 AS buffer_kb,
       s.buffer_policy_desc,
       s.dropped_event_count
FROM sys.dm_xe_sessions AS s
ORDER BY s.name;

SELECT s2.name AS session_name,
       s2.startup_state,
       s2.event_retention_mode_desc
FROM sys.server_event_sessions AS s2
ORDER BY s2.name;
```

ผลจริงบน server ทดสอบ (2025, ยังไม่ได้สร้าง session ของเราเอง): ฝั่ง "กำลังรัน" มี `system_health`, `sp_server_diagnostics session`, `telemetry_xevents`, `hkenginexesession` — ทั้งหมดเป็นของระบบ

### 5.3 system_health — session ฟรีที่มากับ server

**system_health** คือ Always-on session ที่ SQL Server สร้างและ START ให้เอง (`startup_state = 1` เสมอ) มันจับสิ่งที่คนทำ performance tuning ต้องใช้บ่อยที่สุดอยู่แล้ว:

- **Deadlock** — เก็บ deadlock graph ทุกครั้ง (`xml_deadlock_report`)
- **Error รุนแรง** — severity ≥ 20, error ที่เกี่ยว CLR, error ประเภท network ขาด
- **การรอที่ยาวผิดปกติ** — lock นาน > 30 วินาที, latch นาน > 15 วินาที ฯลฯ
- **Memory** — allocation ล้มเหลว, ring buffer ของ sp_server_diagnostics

> [!TIP]
> ก่อนจะเขียน session จับ deadlock เอง ให้จำไว้ว่า **system_health จับไว้ให้แล้ว** (มี target ทั้ง ring_buffer และ event_file) — session เฉพาะงานของเราใน 9.2 เหมาะเมื่อต้องการเก็บเฉพาะที่และต่ออายุไฟล์นานกว่า การอ่าน deadlock จาก system_health จะมีใน Section 9.2 หัวข้อ 5

---

## 6. เชื่อมโยงกับโมดูลก่อนหน้า: XE คือชั้นถัดไปของ Wait Stats และ Lock/Deadlock

### 6.1 จาก Wait Stats (Module 1) ไป Wait Info ต่อ statement

Module 1 อ่าน `sys.dm_os_wait_stats` — ค่าสะสมของทั้ง server ไม่รู้ว่า "query ไหนรอ" — แต่ event `sqlos.wait_info` ให้รายการการรอ "ต่อ task" พร้อม action อย่าง `sql_text` จับคู่กลับไปที่ statement ต้นทางได้ — นี่คือเหตุผลที่หลักสูตรจัด XE ไว้หลัง M1: ต้องรู้ว่า wait type คืออะไรก่อน จึงจะรู้ว่ามันสำคัญแค่ไหนเมื่อเห็นใน session

### 6.2 จาก Lock / Deadlock (Module 5) ไปกราฟสดของ deadlock

Module 5 ผลิต deadlock ด้วย 2 session อัปเดตสวนกันและเห็น **error 1205** — ตอนนั้นเราวิเคราะห์ผ่าน DMV (`sys.dm_tran_locks`, `sys.dm_exec_requests`) ที่ให้ข้อมูล "ตอนนี้" เท่านั้น ส่วน XE เปิดมิติที่ DMV ไม่มี:

| โจทย์จาก Module 5 | คำตอบแบบ DMV | คำตอบแบบ XE |
|:------------------|:--------------|:-------------|
| ตอนนี้ใคร block ใคร | `sys.dm_exec_requests.blocking_session_id` | event `blocked_process_report` + รายละเอียดเต็มของทั้ง victim และ blocker |
| deadlock เมื่อวานเกิดอะไรขึ้น | ไม่ได้ (DMV ดูได้เฉพาะตอนนี้) | `xml_deadlock_report` จาก system_health / session เอง — มี graph ของทุกครั้ง |
| victim เป็น process ไหน | อ่านจาก error log | field `xml_report` มี victim id + execution stack ของทุก process |

ใน Section 9.2 เราจะทำซ้ำสถานการณ์ deadlock เดิมจาก Module 5 แต่คราวนี้มี session รอจับ — เห็น "หน้าต่างเดิมกับกล้องใหม่"

---

## สรุป Section 9.1

1. XEvents คือระบบ tracing มาตรฐานปัจจุบัน — SQL Trace/Profiler ถูก deprecated และถอดออกแล้ว ประเด็นสำคัญคือโมเดล **asynchronous** (buffer + dispatcher) ที่ thread ของ query ไม่รอ I/O
2. ศัพท์ที่ต้องแม่น: **Package → Event → Payload / Predicate / Action → Target → Session** — ทุกคำสั่ง `CREATE EVENT SESSION` ประกอบจากชิ้นเหล่านี้
3. เวลาหน่วย **ไมโครวินาที** และ predicate กรองได้เฉพาะ field ที่ engine ให้ (**ห้าม `DB_ID()`** — ใช้ `sqlserver.database_name` แทน)
4. Event Loss Policy กำหนดว่าเมื่อ buffer กดดันจะเสียอะไร — default `ALLOW_SINGLE_EVENT_LOSS` ปลอดภัยที่สุดสำหรับ production, `NO_EVENT_LOSS` เสี่ยง block workload
5. Catalog DMVs (`sys.dm_xe_packages`, `sys.dm_xe_objects`, `sys.dm_xe_object_columns`, `sys.dm_xe_map_values`) = แผนที่สำรวจของใหม่ทุกครั้งที่เจอ engine รุ่นใหม่
6. `system_health` จับ deadlock/error รุนแรง/การรอยาวไว้ให้อยู่แล้ว — เช็คมันก่อนสร้าง session ใหม่เสมอ

### ตรวจความเข้าใจ

1. โมเดล asynchronous ของ XEvents ต่างจาก SQL Trace ตรงจุดไหน — และเพราะอะไรจึงทำให้ overhead ต่ำกว่า?
2. Predicate กับ Action ต่างกันอย่างไร — ตัวไหนลด overhead ได้จริง และตัวไหน "เพิ่มต้นทุน" ให้เหตุการณ์ที่ผ่านด่าน?
3. `ring_buffer` กับ `event_file` ต่างกันที่ลักษณะการเก็บอย่างไร — ถ้าเกิด failover/crash ตัวไหนยังมีข้อมูลอยู่?
4. เวลา 500 มิลลิวินาที เขียนเป็นค่า predicate ของ `duration` ต้องเป็นเท่าไร และหน่วยนี้มาจากไหน?
5. เหตุใด predicate จึงเขียน `WHERE database_id = DB_ID(N'AdventureWorks')` ไม่ได้ และทางเลือกที่ถูกคืออะไร?
6. `sys.server_event_sessions` กับ `sys.dm_xe_sessions` ตอบคำถามต่างกันอย่างไร — และ `system_health` จะปรากฏใน view ไหนบ้าง?

**➡ ถัดไป:** [9.2 Working With Extended Events — สร้าง Session ใช้งานจริง](../02_Working_With_Extended_Events/README.md)

---

[⬅ Module 09](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [9.2 Working With Extended Events](../02_Working_With_Extended_Events/README.md)
