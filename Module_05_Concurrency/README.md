Concurrency คือความสามารถของระบบฐานข้อมูลในการรองรับการเข้าถึงข้อมูลจากผู้ใช้งานหลายคนพร้อมกัน โดยยังคงรักษาความถูกต้อง (Consistency) และประสิทธิภาพ (Performance) ไว้ได้ กลไกหลักที่ SQL Server ใช้ในการจัดการ Concurrency คือ **Locking** และ **Transaction Isolation Levels**

ในบทเรียนนี้ ผู้เรียนจะศึกษาเกี่ยวกับ Concurrency Models, Transaction Properties (ACID), และการจัดการ Isolation Levels เพื่อลดปัญหา Blocking

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

---


## 📚 Sections (สารบัญบทเรียน)

| # | Section |
|---|---------|
| 1 | [Concurrency Transactions](Sections/01_Concurrency_Transactions/README.md) |
| 2 | [Locking Internals](Sections/02_Locking_Internals/README.md) |
| 3 | [ADR Optimized Locking 2025](Sections/03_ADR_Optimized_Locking_2025/README.md) |

---


## 🧪 Labs

คู่มือปฏิบัติแบบ Instruction + Code block: [Labs/README.md](Labs/README.md) — สคริปต์ประกอบอยู่ใน `Sections/*/Scripts/` ตามหัวข้อ

---


## <details>
<summary><b>1. Isolation Level ใดที่เป็น Default ของ SQL Server และมีโอกาสเกิด Blocking สูง?</b></summary>
Read Committed (แบบ Pessimistic ซึ่งใช้ Shared Lock ในการอ่าน)
</details>

<details>
<summary><b>2. Lock Escalation คืออะไร และทำไม SQL Server ถึงทำ?</b></summary>
คือการเปลี่ยนจาก Row Lock เป็น Table Lock เมื่อมีการ Lock มากเกินไป (เกิน 5,000) เพื่อประหยัด Memory แต่อาจทำให้คนอื่นใช้งาน Table นั้นไม่ได้เลย
</details>

<details>
<summary><b>3. วิธีแก้ไข Deadlock ที่ดีที่สุดคืออะไร?</b></summary>
จัดลำดับการเข้าถึงตารางให้เหมือนกันในทุก Transaction (Access Objects in Order) เพื่อไม่ให้เกิดวงจรอุบาทว์ (Cycle)
</details>


---

---


## ### 8.1 Optimized Locking (ฟีเจอร์ใหม่ใน SQL Server 2025)
- **TID Locking**: เมื่อเปิดใช้ จะไม่ถือ row/page locks จนจบ transaction ใน READ COMMITTED — เหลือ lock เดียวคือ **Transaction ID (TID) lock** ลด lock memory และโอกาส lock escalation มาก
- **Lock After Qualification (LAQ)**: ตรวจ predicate บน row เวอร์ชันล่าสุดที่ committed **โดยไม่ต้องถือ U Lock** ทำให้ concurrency ดีขึ้น (ทำงานเมื่อเปิด RCSI)
- สถานะ: **ปิด default ใน SQL Server 2025** (ต่างจาก Azure SQL DB ที่เปิดให้ DB ใหม่) — เปิดด้วย:
  ```sql
  -- ต้องเปิด ADR ก่อน และแนะนำเปิด RCSI คู่กัน
  ALTER DATABASE [AdventureWorks2025] SET ACCELERATED_DATABASE_RECOVERY = ON;
  ALTER DATABASE [AdventureWorks2025] SET OPTIMIZED_LOCKING = ON;  -- ต้องไม่มี connection อื่นตอนรัน
  ```
- ตรวจสอบสถานะ:
  ```sql
  SELECT name, is_accelerated_database_recovery_on,
         is_read_committed_snapshot_on, is_optimized_locking_on
  FROM sys.databases;
  ```

### 8.2 Accelerated Database Recovery (ADR) ล่าสุด
- 2025 เพิ่ม **ADR ใน tempdb** — rollback temp table/table variable ทันที และ truncate tempdb log อย่างรุนแรงขึ้น (ต้อง restart engine)
- ระวัง: ADR ทำให้ Persistent Version Store เติบโต — มอนิเตอร์ `sys.dm_tran_persistent_version_store_stats`

### 8.3 แนวทางวินิจฉัยปี 2025
- ตรวจ blocking ด้วย `sys.dm_exec_requests` + `blocked_process_report` (XEvents) เหมือนเดิม แต่ถ้าเปิด Optimized Locking จะสังเกตได้ว่า LCK_M_* waits ลดลงมากสำหรับ OLTP ปกติ — ปัญหาที่เหลือมักเป็น long-running write transaction จริง ๆ
- SQL Profiler อย่าใช้ — จับ deadlock ด้วย XEvent `xml_deadlock_report` เสมอ (ดู Lab 9)

> อ้างอิง: [Optimized locking](https://learn.microsoft.com/sql/relational-databases/performance/optimized-locking), [Transaction locking and row versioning guide](https://learn.microsoft.com/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide), [ADR](https://learn.microsoft.com/sql/relational-databases/accelerated-database-recovery-concepts)