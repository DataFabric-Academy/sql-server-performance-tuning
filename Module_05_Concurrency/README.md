Concurrency คือความสามารถของระบบฐานข้อมูลในการรองรับการเข้าถึงข้อมูลจากผู้ใช้งานหลายคนพร้อมกัน โดยยังคงรักษาความถูกต้อง (Consistency) และประสิทธิภาพ (Performance) ไว้ได้ กลไกหลักที่ SQL Server ใช้ในการจัดการ Concurrency คือ **Locking**, **Transaction Isolation Levels** และ (ยุคใหม่) **Row Versioning**

ในบทเรียนนี้ ผู้เรียนจะศึกษาเกี่ยวกับ Concurrency Models, Transaction Properties (ACID), การจัดการ Isolation Levels เพื่อลดปัญหา Blocking กลไก Lock ภายใน (Granularity, Modes, Escalation, Deadlock, Latch/Spinlock) ไปจนถึงฟีเจอร์ยุคใหม่ — **RCSI/SNAPSHOT, ADR และ Optimized Locking ของ SQL Server 2025 (TID/LAQ)**

### 1.1 Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – เข้าใจ ACID และ Isolation Levels**
  - อธิบาย Pessimistic/Optimistic Concurrency, Isolation Level ต่างๆ และผลข้างเคียง เช่น Dirty/Non-repeatable/Phantom Reads ได้
- **ระดับ 2 – อ่านและวิเคราะห์ Lock/Blocking ได้**
  - ใช้ DMV เช่น `sys.dm_tran_locks`, `sys.dm_exec_requests` และสคริปต์แล็บเพื่อดู Blocking Chain, Lock Modes/Granularity ได้
- **ระดับ 3 – ออกแบบ/เลือก Concurrency Model ให้เหมาะกับระบบ**
  - เลือกใช้ READ COMMITTED, RCSI, SNAPSHOT ให้เหมาะกับ Workload, เข้าใจข้อดีข้อเสีย/ผลกระทบต่อ TempDB และ Version Store
- **ระดับ 4 – แก้ปัญหา Deadlock และ Contention ขั้นสูง**
  - ใช้ XEvents/`system_health`, วิเคราะห์ Deadlock Graph, และออกแบบแนวทางลด Deadlock, Lock Escalation, Latch/Spinlock Contention ได้อย่างเป็นขั้นตอน

---

## 📚 Sections (สารบัญบทเรียน)

| # | Section |
|---|---------|
| 1 | [Concurrency Transactions](Sections/01_Concurrency_Transactions/README.md) — ACID, โหมด transaction, อาการเสีย 3 แบบ, Isolation Levels, RCSI |
| 2 | [Locking Internals](Sections/02_Locking_Internals/README.md) — Lock Manager, Granularity/Modes/Escalation, Key-Range, Deadlock, Latch/Spinlock, Hints |
| 3 | [ADR & Optimized Locking 2025](Sections/03_ADR_Optimized_Locking_2025/README.md) — Row Versioning, PVS/sLog, Optimized Locking (TID/LAQ) |

## 📝 แบบทดสอบ

| ไฟล์ | เนื้อหา |
|------|---------|
| [Quiz_Bank.md](Quiz_Bank.md) | 15 ข้อ (multiple choice + ตอบสั้น) พร้อมเฉลยอธิบาย — ครอบวัตถุประสงค์การเรียนรู้บทที่ 5 ทั้งหมด |

---

## 🧪 Labs

คู่มือปฏิบัติแบบ Instruction + Code block: [Labs/README.md](Labs/README.md) — สคริปต์ประกอบอยู่ใน `Sections/*/Scripts/` ตามหัวข้อ (Blocking Chain, Deadlock + XEvents, Snapshot Isolation, Optimized Locking)

---

## <details>
<summary><b>1. Isolation Level ใดที่เป็น Default ของ SQL Server และมีโอกาสเกิด Blocking สูง?</b></summary>
Read Committed (แบบ Pessimistic ซึ่งใช้ Shared Lock ในการอ่าน — บน DB ที่เปิด RCSI พฤติกรรมจะเปลี่ยนเป็นอ่านจาก version store แทน)
</details>

<details>
<summary><b>2. Lock Escalation คืออะไร และทำไม SQL Server ถึงทำ?</b></summary>
คือการรวม Lock ระดับแถว/หน้าจำนวนมาก (เกินเกณฑ์ ~5,000 ต่อ statement หรือ memory threshold) เป็น Table Lock เพื่อประหยัด Memory แต่อาจทำให้คนอื่นใช้งาน Table นั้นไม่ได้เลย
</details>

<details>
<summary><b>3. วิธีแก้ไข Deadlock ที่ดีที่สุดคืออะไร?</b></summary>
จัดลำดับการเข้าถึงตารางให้เหมือนกันในทุก Transaction (Access Objects in Order) เพื่อไม่ให้เกิดวงจรอุบาทว์ (Cycle) + ทำ transaction สั้น และ app ฝั่ง victim ต้องมี retry รองรับ Error 1205
</details>

---

> **หมายเหตุ (2025):** เนื้อหา Optimized Locking (TID/LAQ), ADR รวมถึง code สลับ database options พร้อม hard guard รุ่น ย้ายไปอยู่ใน [Section 3 — ADR & Optimized Locking 2025](Sections/03_ADR_Optimized_Locking_2025/README.md) ฉบับเต็มแล้ว (ตรวจสอบสถานะ database ด้วย `sys.databases` — คอลัมน์ `is_optimized_locking_on`, `is_accelerated_database_recovery_on`, `is_read_committed_snapshot_on`)

> อ้างอิง: [Optimized locking](https://learn.microsoft.com/sql/relational-databases/performance/optimized-locking), [Transaction locking and row versioning guide](https://learn.microsoft.com/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide), [ADR](https://learn.microsoft.com/sql/relational-databases/accelerated-database-recovery-concepts)
