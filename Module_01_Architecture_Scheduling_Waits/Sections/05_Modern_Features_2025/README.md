[⬅ Module 01](../../README.md) | [1.4 Wait Statistics](../04_Wait_Statistics/README.md) | Section 5/5 | 🧪 [Labs](../../Labs/README.md)

# 1.5 Modern Features & SQL Server 2025 Checklist — สิ่งที่ต้องอัปเดตในสมอง

> *"ประสบการณ์ 10 ปี อาจกลายเป็น 1 ปี ที่ทำซ้ำ 10 รอบ — ถ้ายังใช้ความรู้ยุค 2012 จัดการ server ยุค 2025"*

## เปิดเรื่อง: อะไรเปลี่ยนไป อะไรยังเหมือนเดิม

แนวคิดพื้นฐานของหลักสูตรนี้ (SQLOS, Scheduling, Waits) ไม่เคยเปลี่ยน แต่รายละเอียดรอบ ๆ เปลี่ยนเร็ว ส่วนนี้สรุป "ของที่ต้องถอดออกจากสมอง" และ "ของใหม่ที่ต้องใส่เข้าไป" ตั้งแต่ SQL Server 2019 ถึง 2025

---

## 1. ถอดออกจากสมอง (Deprecated / ไม่ควรใช้)

| ของเก่า | สถานะใน SQL Server 2025 | ใช้อะไรแทน |
|:--------|:------------------------|:-----------|
| `lightweight pooling` (fiber mode) | **Deprecated** — จะถูกถอดออก | Cooperative scheduling คือโมเดลเดียว |
| Hot Add CPU | **Deprecated** | วางแผน capacity ล่วงหน้า |
| SQL Profiler / SQL Trace | Deprecated สมบูรณ์ | Extended Events (Module 9) |
| สูตร PLE = 300 วินาที | ใช้ไม่ได้กับ RAM ยุคใหม่ | PLE ต่อ NUMA node + trend เทียบ baseline |

---

## 2. ใส่เข้าไปในสมอง (ของใหม่ที่ใช้งานจริง)

### 2.1 Scheduling & Waits
- `sys.dm_exec_query_plan_stats` (2019+, ตั้ง `last_query_plan_stats = 1`) — **Last Actual Plan** จาก plan cache โดยไม่ต้องพึ่ง Query Store
- ตีความ `CXPACKET` คู่กับ `CXCONSUMER` — CXCONSUMER สูงตามหลังมักเป็นพฤติกรรมปกติของ parallel plan
- Soft-NUMA สร้างอัตโนมัติ (2016+) — ตรวจ `sys.dm_os_nodes.node_state_desc = ONLINE AUTOMATIC`

### 2.2 เครื่องมือและสิทธิ์
- บทบาท server **`##MS_ServerPerformanceStateReader##`** (2022+) — ให้ monitoring account อ่าน DMV ได้โดยไม่ต้องเป็น sysadmin
- **Glenn Berry — SQL Server 2025 Diagnostic Queries** — ชุดตรวจสุขภาพมาตรฐาน รันเก็บ baseline ได้ทั้งชุด

### 2.3 เชื่อมโยงกับ Modules ถัดไป
| Module | ของใหม่ที่จะเจอ |
|:-------|:----------------|
| M3 Structures | ADR ใน tempdb, tempdb space governance |
| M5 Concurrency | Optimized Locking (TID + LAQ) |
| M7 Query Processing | OPPO, CE Feedback for Expressions, DOP Feedback (default ON) |
| M8 Plan Caching | Optimized sp_executesql, ABORT_QUERY_EXECUTION |
| M9 XEvents | Time-bound sessions |

---

## 3. Checklist สำหรับ Server ที่เพิ่งขึ้น SQL Server 2025

```sql
-- 1. เก็บ topology baseline (CPU / NUMA / workers)
SELECT cpu_count, socket_count, numa_node_count, max_workers_count,
       sqlserver_start_time
FROM sys.dm_os_sys_info;

-- 2. ให้ monitoring account อ่าน DMV ได้อย่างปลอดภัย
ALTER SERVER ROLE ##MS_ServerPerformanceStateReader##
    ADD MEMBER [ monitoring_login ];

-- 3. ตรวจว่า deprecated settings ไม่ถูกใช้อยู่
SELECT name, value_in_use
FROM sys.configurations
WHERE name IN ('lightweight pooling', 'priority boost');

-- 4. เปิด last actual plan stats สำหรับทุก database ที่สำคัญ
ALTER DATABASE AdventureWorks2025
    SET PARAMETERIZATION FORCED;  -- ตามความเหมาะสมของ workload
ALTER DATABASE SCOPED CONFIGURATION
    SET LAST_QUERY_PLAN_STATS = ON;
```

**หลังจากนั้น:** รัน [Glenn Berry — SQL Server 2025 Diagnostic Queries](https://glennsqlperformance.com/resources/) เก็บเป็น baseline วันแรก — เพราะ "ปกติ" ของแต่ละ server ไม่เหมือนกัน และเราจะไม่มีวันรู้ว่าอะไรผิดปกติ ถ้าไม่เคยบันทึกว่าปกติหน้าตาเป็นอย่างไร

---

## สรุป Section 5 (และจบ Module 1)

1. **ถอด:** lightweight pooling, Hot Add CPU, Profiler, สูตร PLE 300
2. **ใส่:** query_plan_stats, performance reader role, Glenn Berry 2025 queries, NUMA-aware thinking
3. ทั้งโมดูลนี้ให้ "แผนที่" ของ SQL Server — โมดูลถัดไปจะพาเดินทีละเส้นทาง: I/O (Module 2), โครงสร้างไฟล์ (Module 3), Memory (Module 4)

**ตรวจความเข้าใจ:**
1. เพราะอะไร `lightweight pooling` จึงถูกถอดออกใน 2025?
2. role `##MS_ServerPerformanceStateReader##` แก้ปัญหาอะไรที่ sysadmin แก้ไม่ได้อย่างสวยงาม?

**🧪 ลงมือทำ:** [Labs/README.md — Lab 1: Wait Statistics & CPU Pressure](../../Labs/README.md)

---

[⬅ Module 01](../../README.md) | [1.4 Wait Statistics](../04_Wait_Statistics/README.md) | 🧪 [Labs](../../Labs/README.md) | ➡ [Module 02 — I/O](../../Module_02_IO/README.md)
