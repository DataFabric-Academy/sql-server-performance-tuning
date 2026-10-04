[⬅ Module 01](../../README.md) | [1.3 NUMA](../03_NUMA_Architecture/README.md) | Section 4/5 | ➡ ถัดไป: [05 Modern Features](../05_Modern_Features_2025/README.md)

# 1.4 Wait Statistics — ภาษาที่ SQL Server ใช้บอกว่ากำลังรออะไร

> *"SQL Server ไม่เคยเงียบ — มันบันทึกทุกวินาทีที่ต้องรอ ไว้ให้เราอ่าน"*

> **ต้องรู้มาก่อน**: [Section 1.2 — Scheduling](../02_Scheduling_Windows_vs_SQL/README.md) (สถานะ RUNNABLE / RUNNING / SUSPENDED และ Signal Wait) พร้อมสิทธิ์ `VIEW SERVER STATE` สำหรับอ่าน `sys.dm_os_wait_stats`
> ศัพท์ใหม่ดู [Glossary](../../../Glossary.md)

## เปิดเรื่อง: Waits & Queues Methodology

ทุกครั้งที่ task ต้องหยุดรอ (SUSPENDED) SQL Server บันทึกว่า "รออะไร นานแค่ไหน กี่ครั้ง" ไว้ใน `sys.dm_os_wait_stats` ปรัชญา **Waits & Queues** คือ: แทนที่จะเดาว่าระบบช้าเพราะอะไร ให้อ่านบัญชีการรอที่ engine จดไว้ให้เอง — คอขวดจริงจะจัดอันดับให้อยู่แล้ว

สมการที่ต้องจำ:

```
Response Time = Service Time (CPU) + Wait Time (รอ resource)
```

และ Wait Time แบ่งเป็น:
- **Resource Wait** — รอของจริง: disk, lock, network
- **Signal Wait** — ของมาแล้ว แต่ CPU ยังไม่ว่าง (= สัญญาณ CPU pressure)

---

## 1. อ่าน Wait Statistics อย่างมืออาชีพ

### ค่าที่ DMV เก็บเป็น "ค่าสะสมตั้งแต่ restart" — จึงต้องทำ Delta

```sql
-- Top waits แบบกรอง benign waits (สไตล์ Glenn Berry)
WITH Waits AS
(
    SELECT wait_type, wait_time_ms / 1000.0 AS wait_s,
           (wait_time_ms - signal_wait_time_ms) / 1000.0 AS resource_s,
           signal_wait_time_ms / 1000.0 AS signal_s,
           waiting_tasks_count
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN ( /* benign waits: SLEEP_*, XE_TIMER, ... */
          ) AND waiting_tasks_count > 0
)
SELECT TOP (25) wait_type, wait_s,
       CAST(100.0 * wait_s / SUM(wait_s) OVER () AS DECIMAL(10,1)) AS pct_total,
       resource_s, signal_s
FROM Waits ORDER BY wait_s DESC;
```

### Signal Wait Ratio — ตัวชี้วัด CPU pressure

```sql
SELECT SUM(signal_wait_time_ms) * 1.0 / SUM(wait_time_ms) * 100 AS signal_wait_pct
FROM sys.dm_os_wait_stats WHERE wait_time_ms > 0;
-- > 10-15% ต่อเนื่อง = CPU pressure
```

> [!IMPORTANT]
> ค่าใน DMV เป็นค่าสะสม — เปรียบเทียบต้องใช้ **delta ระหว่าง snapshot** (เก็บ baseline ทุก 15 นาที ดูต่อ Module 10)

---

## 2. Wait Types ที่ต้องรู้จัก — จัดกลุ่มตามคอขวด

### CPU
| Wait | ความหมาย | ทิศทางแก้ |
|:-----|:---------|:----------|
| `SOS_SCHEDULER_YIELD` | ครบ quantum 4ms แล้วยังทำไม่จบ | ลดงาน CPU / จูน MAXDOP+CTFP / เพิ่ม core |
| `CXPACKET` / `CXCONSUMER` | รอ thread อื่นใน parallel plan | ดู statistics, MAXDOP, Cost Threshold |
| `THREADPOOL` | worker หมด | **วิกฤต** — ลด concurrency / ตรวจ blocking ยาว |

### I/O
| Wait | ความหมาย | ทิศทางแก้ |
|:-----|:---------|:----------|
| `PAGEIOLATCH_SH/EX` | รออ่าน data page จาก disk | ลด logical reads (index) / storage / memory |
| `WRITELOG` | รอเขียน transaction log | log ลง storage เร็วสุด / รวม micro-transactions |
| `ASYNC_IO_COMPLETION`, `IO_COMPLETION` | รอ I/O อื่น (backup, sort) | ตรวจ storage ของงานนั้น |

### Memory
| Wait | ความหมาย | ทิศทางแก้ |
|:-----|:---------|:----------|
| `RESOURCE_SEMAPHORE` | รอ memory grant | ลด sort/hash ใหญ่, ตรวจ statistics |
| `CMEMTHREAD` | memory object contention | พบน้อยลงในรุ่นใหม่ — อัปเดต CU |

### Lock / Blocking
| Wait | ความหมาย | ทิศทางแก้ |
|:-----|:---------|:----------|
| `LCK_M_S/X/...` | รอ Lock ขัดกัน | หา head blocker / RCSI / transaction สั้น |
| `PAGELATCH_*` | รอ Latch ใน memory (hot page) | แก้ design — เช่น tempdb files, last-page insert |

### Network / อื่น ๆ
| Wait | ความหมาย |
|:-----|:---------|
| `ASYNC_NETWORK_IO` | client รับข้อมูลไม่ทัน (แก้ฝั่ง app) |
| `PREEMPTIVE_OS_*` | รอ Windows API (Linked Server, CLR) |
| `LOGBUFFER`, `BACKUPTHREAD` | log buffer เต็ม / backup กำลังทำงาน |

> รายการเต็มอ่านได้ที่ [SQLskills wait type library](https://www.sqlskills.com/help/waits/)

---

## 3. ขั้นตอนการวินิจฉัยด้วย Waits

1. **เก็บ delta** — snapshot `sys.dm_os_wait_stats` สองจุดเวลา ลบกัน
2. **จัดอันดับ top waits** หลังกรอง benign waits
3. **แปล wait → resource** ด้วยตารางด้านบน
4. **ยืนยันด้วยข้อมูลชั้นที่สอง** — เช่น PAGEIOLATCH → ดู file stats; LCK_M → ดู blocking chain
5. **แก้ → วัดซ้ำ** — อย่าแก้หลายอย่างพร้อมกัน

---

## สรุป Section 4

1. `sys.dm_os_wait_stats` = บัญชีการรอสะสมของทั้ง server — อ่านแบบ **delta**
2. แยก Resource Wait (รอของ) กับ Signal Wait (รอ CPU) ตั้งแต่มองแรก
3. แต่ละ wait type ชี้ไปคนละทิศ — ตารางใน section นี้คือแผนที่ประจำตัว

**ตรวจความเข้าใจ:**
1. `PAGEIOLATCH_SH` กับ `PAGELATCH_EX` ต่างกันอย่างไร — ใครเกี่ยวกับ disk ใครเกี่ยวกับ memory?
2. เจอ top wait เป็น `SOS_SCHEDULER_YIELD` — สิ่งแรกที่จะดูคืออะไร?

**➡ ถัดไป:** [Section 1.5 — Modern Features & 2025 Checklist](../05_Modern_Features_2025/README.md)

---

[⬅ Module 01](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [05 Modern Features](../05_Modern_Features_2025/README.md)
