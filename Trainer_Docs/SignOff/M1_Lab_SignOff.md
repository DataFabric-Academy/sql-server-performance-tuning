# Sign-off รันแล็บจริง — Module 1 + พิสูจน์ syntax 2025-only (M5/M9)

> **ตามเฟส 4 ของแผนแม่บท** (Definition of Done ข้อ 3: sign-off รันจริงบน 17.x ทุกแล็บ)
> **ผู้รัน:** ทีมผลิต (ZCode agent) · **Environment:** SQL Server 2025 RTM **17.0.1000.7** (X64, Enterprise Evaluation) บน Windows Server 2025 · Database: `AdventureWorks` (compat 170, 71 user tables) · 4 vCPU / 1 NUMA node / max_workers 512
> **วันที่รันจริง:** 2026-10-01 · ผลดิบทั้งหมดอยู่ในไฟล์เดียวกันโฟลเดอร์นี้ (`M1_Ex*.txt`, `M5_M9_syntax_2025.txt`)

## 1) ผลรัน Lab 1 (M1) ราย Exercise — ผ่านทั้ง 4

| Exercise | ผลจริงที่จับได้ | บล็อก `**Expected:**` ใน `Module_01.../Labs/README.md` |
|---|---|---|
| Ex1 CPU/NUMA Topology | 4 logical CPUs, 1 socket, cores/socket 2, 1 NUMA node, max_workers 512, scheduler_count 4; node 0 `ONLINE` + node 64 DAC | ✅ เพิ่มแล้ว |
| Ex2 Signal Wait Ratio | ก่อน workload: `signal_wait_pct = 3.9%` (ต่ำกว่าเกณฑ์ 10–15%), Top-1 = `PREEMPTIVE_OS_CRYPTOPS` 77.1% | ✅ เพิ่มแล้ว (พร้อมคำอธิบาย benign waits ตามมติ #9) |
| Ex3 CPU Pressure | รัน 4 loops บน 4 schedulers: `runnable_tasks_count = 2` (คิวจริง); `SOS_SCHEDULER_YIELD` 6,689 → **17,185 ครั้ง** (signal 0.89s → 10.48s) = quantum exhaustion | ✅ เพิ่มแล้ว |
| Ex4 ASYNC_NETWORK_IO | จับได้ session `suspended / ASYNC_NETWORK_IO` ขณะสตรีม `sys.all_objects CROSS JOIN sys.all_columns` | ✅ เพิ่มแล้ว |

**ข้อจำกัดที่วัดได้จากเส้น WAN:** `signal_wait_pct` รวมไม่ขยับ (3.9% → 3.87%) เพราะ `ASYNC_NETWORK_IO` สะสม 2,598 วินาทีเจือในตัวเศษ — บนเครื่อง localhost ของห้องเรียนจะเห็น signal พุ่งชัด จดไว้ใน Expected ของ Ex2/Ex3 แล้ว

## 2) ข้อค้นพบจากการรันจริง (แก้หมดแล้ว)

1. **`r.is_user_process` ล่มบน SQL Server 2025** — คอลัมน์ถูกถอดออกจาก `sys.dm_exec_requests` (ยังอยู่ที่ `sys.dm_exec_sessions`) ตรวจยืนยันด้วย `sys.all_columns` + ผล `Invalid column name 'is_user_process'` → แก้แล้ว 2 จุด (M1 Labs, M11 Labs) ด้วยการ `JOIN sys.dm_exec_sessions`
2. **M9 `AUTO_STOP` ไม่มีอยู่จริง** — `CREATE EVENT SESSION ... WITH (AUTO_STOP = ON)` ได้ `Incorrect syntax near 'AUTO_STOP'` บน 17.0.1000.7 → ลบ claim ออกจาก 3 จุด (M9 Labs Objective/Step3, M9 module README) แทนด้วย MAX_DISPATCH_LATENCY + ปิดด้วย SQL Agent + คำเตือน "ห้ามสอน" พร้อม "ทางเลือกสำหรับรุ่นเก่า: รูปแบบรันได้ตั้งแต่ 2008+" ตามมติ #9
3. **M5 `OPTIMIZED_LOCKING` ✅ ผ่าน** — `ALTER DATABASE ... SET ACCELERATED_DATABASE_RECOVERY = ON; SET OPTIMIZED_LOCKING = ON` สำเร็จ, `sys.databases.is_optimized_locking_on = 1`, revert กลับ 0 สะอาด
4. **แล็บ Ex3 ขาด `SET NOCOUNT ON`** — loop ที่ไม่ปิด NOCOUNT ส่ง DONE token ทุก iteration → session ติด `ASYNC_NETWORK_IO` แทนการกิน CPU (พิสูจน์ด้วย cpu_time สะสมต่ำกว่า wall clock มาก) → เพิ่ม `SET NOCOUNT ON` + คำอธิบายในแล็บแล้ว
5. **loop NOCOUNT-ON ไม่รู้ว่า client หลุด** — รันต่อจนจบเงียบ ๆ → เพิ่มขั้น `KILL` ใน Cleanup ของแล็บ
6. **ASYNC_NETWORK_IO นำไปสู่ blocking ได้จริง** — session สตรีมผลใหญ่ถือ lock ค้างและ block `ALTER DATABASE` ของ session อื่น (LCK_M_X รอ 271 วินาที, แก้ด้วย `KILL 69`) — จดเป็นตัวอย่างสดใน Expected ของ Ex4

## 3) สถานะ Blocking DoD ที่ปิดได้ในรอบนี้

| ข้อ | สถานะ |
|---|---|
| Heading เสีย 8 ไฟล์ (`grep "^## ###"`) | ✅ 0 ผลลัพธ์ |
| `**Expected:**` แล็บ M1 (4/4 Exercise) | ✅ (เหลือ normalize อีก 36 จุดใน 10 แล็บ) |
| "ต้องรู้ก่อน" แล็บ M1 (CTE/window/CROSS APPLY/CROSS JOIN/benign waits) | ✅ ครบทุก Exercise ที่เกี่ยว |
| Sign-off รันจริง M1 + syntax M5/M9 | ✅ เอกสารนี้ |
| Glossary กลาง | ✅ `Glossary.md` (repo root) — ฉบับฐาน M1 + ศัพท์ความถี่สูง |
| Version guard .sql 69 ไฟล์ | ⬜ ยังไม่ทำ (งานก้อนถัดไป) |
| Module 0 ฉบับขั้นต่ำ | ⬜ ยังไม่ทำ |
| สัญญาไม่จริงใน Guide (:142, :157) | ⬜ ยังไม่ทำ |

## 4) ข้อควรรู้เรื่อง environment

- DB บน server นี้ชื่อ **`AdventureWorks`** ไม่ใช่ `AdventureWorks2025` ตามที่สคริปต์อ้าง — รันสคริปต์/แล็บต้องแทนชื่อ (หรือสร้าง synonym) — จะรวมไว้ในงาน version guard ก้อนถัดไป
- ปล่อย server ในสถานะสะอาด: wait stats ถูก clear ตาม Cleanup, ADR/Optimized Locking ปิดแล้ว, ไม่มี session ค้าง, ไม่มี XEvent session ค้าง
