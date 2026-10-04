# Sign-off รันแล็บจริงครบทั้ง 11 แล็บ (DoD ข้อ 3) — ฉบับรวม

> **ตามเฟส 4 ของแผนแม่บท** · **ผู้รัน:** ทีมผลิต 10 หน่วยงาน (1 หน่วย/แล็บ + 1 ผู้ประสานงาน) · **Environment:** SQL Server 2025 Enterprise Eval บน Windows Server 2025, VM ทดสอบเฉพาะของทีม (รายละเอียด connection เก็บไว้ภายใน ไม่ระบุใน repo), Database `AdventureWorks` (71 ตาราง, เปิด RCSI + Query Store มาแต่ต้น)
> **หมายเหตุ build:** VM เริ่มวันที่ **17.0.1000.7 (RTM)** → ถูก patch เป็น **17.0.1135.8 (RTM-GDR, KB5122770)** กลางวัน — แล็บที่รันตอนเช้า (M1, syntax check M5/M9) อ้าง .1000.7 ตามจริง, แล็บที่เหลืออ้าง .1135.8 ตามจริง

## 1) สรุปต่อแล็บ — ทุกแล็บผ่านการรันจริงบน 17.x

| แล็บ | Ex | ผู้รัน | วันที่/Build | ไฮไลต์ค่าจริงที่จับได้ |
|---|---|---|---|---|
| M1 Wait & CPU | 4 | ผู้ประสานงาน | 10-01 / .1000.7 | `SOS_SCHEDULER_YIELD` 6,689→17,185, runnable=2, ASYNC_NETWORK_IO + blocking chain จริง |
| M2 I/O | 3 | หน่วยงาน M2 | 10-01 / .1135.8 | cold/warm reads 274, log write latency ~1 ms, ROWS latency พุ่ง ~87 ms แล้วเจือจาง |
| M3 Structures | 4 | หน่วยงาน M3 | 10-02 / .1135.8 | DBCC PAGE จริง (1:736), GUID frag 98.5% vs identity 1.2%, VLF 6 ชิ้นมีร่องรอย autogrowth |
| M4 Memory | 4 | หน่วยงาน M4 | 10-02 / .1135.8 | grant 667 MB ใช้จริง 12 MB, feedback หดเหลือ 18 MB (`sys.query_store_plan_feedback`), PLE 13,273 s |
| M5 Concurrency ⭐ | 4 | หน่วยงาน M5 | 10-02 / .1135.8 | blocking `LCK_M_S` 2,123 ms + chain, deadlock จริง victim spid 78 (Msg 1205), RCSI version store เห็นจริง |
| M6 Statistics/Index | 4 | หน่วยงาน M6 | 10-02 / .1135.8 | covering index 106→4 reads (~26×), frag test จริง, stale stats est 223.83 vs actual 50,000 → แก้ด้วย FULLSCAN+RECOMPILE |
| M7 Query Execution | 4 | หน่วยงาน M7 | 10-02 / .1135.8 | `CONVERT_IMPLICIT` 249 plans, **OPPO/Dispatcher + 2 Query Variants จริง** (237 µs vs 303,169 µs), deferred compilation ของ table variable |
| M8 Plan Caching ⭐ | 4 | หน่วยงาน M8 | 10-02 / .1135.8 | Query Store regression จริง: plan 63 µs → 165.4 µs, force สำเร็จ (`last_force_failure_reason_desc=NONE`), QS Hints + Msg 8778, tuning recommendation จริง 2 รายการ |
| M9 Extended Events ⭐ | 3 | หน่วยงาน M9 | 10-01→02 / .1135.8 | ring_buffer จับ batch จริง, **deadlock graph จริง** (`<victim-list>` + 2 process), event_file อ่าน .xel ได้จริง |
| M10 Monitoring ⭐ | 3 | หน่วยงาน M10 | 10-02 / .1135.8 | baseline snapshot 143/19 แถว, delta 90 วิ: WRITELOG +199, `SOS_SCHEDULER_YIELD` +2,581, health check ครบ |
| M11 Troubleshooting ⭐ | 3 | หน่วยงาน M11 | 10-02 / .1135.8 | chaos workload จริง (CPU/I/O/sort grant 700 MB), head blocker ถูก KILL ปลด victim ใน 4 ms, CTFP/MAXDOP จริง |

⭐ = 3 แล็บจุดปิดคอร์สตามแผน (M1 + M5 + M9 ผ่านหมด — ข้อ 6 ของ DoD "ผู้เรียนทดลองเดินเต็มสาย" เป็นเฟสถัดไปที่ต้องมีผู้เรียนจริง)

## 2) ข้อค้นพบจากการรันจริง (แก้ใน md แล้วทั้งหมด พร้อม ⚠️ blockquote)

**Breaking changes บน SQL Server 2025 (17.x):**
1. `r.is_user_process` ถูกถอดจาก `sys.dm_exec_requests` (อยู่ที่ `sys.dm_exec_sessions`) — แก้ M1/M11
2. `sys.system_internals_allocation_units.allocated_page_page_id` ไม่มีแล้ว — แก้ M3 ด้วย `sys.dm_db_database_page_allocations`
3. `is_memory_grant_feedback_adjusted` ถูกถอดจาก `sys.query_store_plan`; resource semaphore columns เปลี่ยนชื่อ (granted_memory_kb/used_memory_kb) — แก้ M4/M7
4. `active_transactions_using_pvs` มีเฉพาะ Azure SQL — แก้ M5 ด้วย `persistent_version_store_size_kb`
5. `sys.dm_db_tuning_recommendations.script` ถูกถอดบน 2025 — แก้ M8 ด้วย JSON path `$.planForceDetails.*`
6. deadlock report บน build นี้อยู่ที่ event_file ไม่ใช่ ring_buffer — แก้ M5 ด้วย `sys.fn_xe_file_target_read_file`

**Bugs ในสคริปต์/แล็บเดิมที่จับได้จากการรัน:**
7. M9: `AUTO_STOP` ไม่มีอยู่จริง (Msg 102) — ลบ claim, ใช้ MAX_DISPATCH_LATENCY + SQL Agent; XEvent predicate ห้ามเรียกฟังก์ชัน (`DB_ID()`) → ใช้ `sqlserver.database_name`; XQuery path ใน ring_buffer คืน NULL → แก้เป็น path สัมพัทธ์
8. M8: `EXEC` แบบแล็บเดิมทำให้ "2 plans ใน query เดียว" ไม่เกิด (แยก query_id) → เปลี่ยนเป็น `sp_executesql`; `QUERY_CAPTURE_MODE = AUTO` ไม่ capture query สาธิต → ALL; เลข error 8799 ผิด → จริงคือ 8778; ต้อง unforce ก่อน set hints (Msg 12457) และเคลียร์ hints ก่อน remove query (Msg 12456)
9. M7: `EmployeeID` ไม่มีในตาราง (BusinessEntityID); query XQuery ขาด XMLNAMESPACES จึงได้ 0 เสมอ; ข้อมูล sample ใหม่เป็นปี 2022–2025 (ไม่ใช่ 2014)
10. M2: `OrderDate` ไม่มีใน SalesOrderDetail → ใช้ `ModifiedDate`; M10: query delta เดิมคืนผลว่างเสมอ (ROW_NUMBER ไม่มี PARTITION BY + เทียบแถวกับตัวเอง) → แก้ logic การเทียบ; M6: scenario Missing Index เดิมไม่เกิดบน DB จริง (มี index ให้ตั้งแต่ติดตั้ง) → ออกแบบ probe ใหม่ให้สาธิตได้จริง; M3: stale stats โดน auto-update กลบทลาย → ใช้ `sp_autostats` ระดับตาราง + RECOMPILE

**หมายเหตุสภาพแวดล้อม (สำหรับผู้สอน):**
- DB บน VM ชื่อ `AdventureWorks` ไม่ใช่ `AdventureWorks2025` (md คงใช้ชื่อมาตรฐาน — รันด้วย -d AdventureWorks; การเปลี่ยนชื่อทั้งหลักสูตรเป็นเรื่องเปิดให้เจ้าของตัดสิน)
- VM เปิด **RCSI** อยู่ — reader ไม่ block writer (แล็บ blocking ต้องใช้ `WITH (READCOMMITTEDLOCK)` จึงเห็น LCK_M_S) — จดใน Expected แล้ว
- SQL Server Agent บน VM = Stopped (แล็บ M2/M10 ที่ต้องใช้ Agent ต้อง START ก่อนตอนสอน)
- workload บางจุดทำย่อ (ลด iteration/เวลา ≤60 วิ ตามข้อจำกัดความปลอดภัยของ VM ใช้ร่วม) — Expected ระบุไว้ชัดว่าผู้เรียนใช้ค่าต้นฉบับจะเห็นหนักกว่า

## 3) สถานะ DoD ข้อ 3 หลังก้อนนี้

| เกณฑ์ | ผล |
|---|---|
| `**Expected:**` ครบ 40/40 Exercise (รูปแบบตายตัว) | ✅ 43 บล็อก / 40 Exercise (M1 Ex3 + M9 Ex3 มี per-step Expected เพิ่ม — ผ่านการตรวจแล้ว) และ "ผลที่คาดหวัง" รูปแบบเก่า = 0 ทุกไฟล์ |
| "ต้องรู้ก่อน" ครบทุก Exercise ที่ใช้ syntax เกิน SELECT/JOIN | ✅ ครบ (36 ที่มี trigger syntax มี blockquote ทุกจุด — ตรวจโดยผู้ตรวจอิสระ ยกเว้น M8 ซึ่งรายงานครบจากหน่วยงาน M8) |
| "ทางเลือกสำหรับรุ่นเก่า" ครบทุกบล็อก 2025-only | ✅ M5 Ex4 + M5 README 8.1 (M9 ถูกเขียนใหม่เป็น version-neutral พร้อมคำเตือน) |
| Hard guard IF…THROW ใน md 2025-only | ✅ M5 Labs Ex4 + M5 README 8.1 (syntax พิสูจน์บน 17.x แล้ว) |
| `MinVersion:` ใน .sql | ✅ 69/69 |
| sign-off รันจริงบน 17.x ทุกแล็บ | ✅ เอกสารฉบับนี้ (11/11 แล็บ) |

**คงเหลือตามแผน:** Module 0 ฉบับขั้นต่ำ · แก้สัญญา Guide :142/:157 · quiz bank 11 โมดูล · ขยายเนื้อหา 31/36 sections (M5→M9→M11) · เด็คเปิดคอร์ส + เด็คเต็มตามคิว · ผู้เรียนทดลองเดิน 3 แล็บเต็มสาย (DoD ข้อ 6) · นโยบาย git สำหรับ artifacts
