กระบวนการ Compile Query เพื่อสร้าง Execution Plan เป็นขั้นตอนที่ใช้ทรัพยากร CPU สูง SQL Server จึงมีการจัดเก็บ Plan ไว้ใน Memory ส่วนที่เรียกว่า **Plan Cache** เพื่อนำกลับมาใช้ซ้ำ (Reuse) อย่างไรก็ตาม การจัดการ Plan Cache ที่ไม่มีประสิทธิภาพอาจนำไปสู่ปัญหา Memory Pressure หรือ Plan Regression ได้

ในบทเรียนนี้ ผู้เรียนจะศึกษาโครงสร้างของ Plan Cache, กลไกการ Recompilation, และฟีเจอร์สมัยใหม่อย่าง Query Store

### 1.1 Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – เข้าใจกลไก Plan Cache**
  - อธิบาย Compiled/Executable Plan, Cache Stores, การ Lookup/Eviction และผลของ Ad-hoc Plan Pollution ได้
- **ระดับ 2 – ตรวจสอบปัญหาจาก Plan Cache**
  - ใช้ DMV และ Counters (`SQL Compilations/sec`, `Recompilations/sec`, ขนาด CACHESTORE_SQLCP/OBJCP) เพื่อระบุ Plan Bloat, Recompile สูงผิดปกติ และ Parameter Sniffing ได้
- **ระดับ 3 – ใช้ Query Store ในการวิเคราะห์ย้อนหลัง**
  - เปิด/ตั้งค่า Query Store อย่างปลอดภัย, ใช้รายงาน Top Resource Queries, Regressed Queries, และ Plan Forcing เพื่อแก้ปัญหาเร่งด่วนได้
- **ระดับ 4 – ประยุกต์ Automatic Tuning & Feedback Loops**
  - เปิดใช้ Automatic Plan Correction, Persistent Memory Grant/DOP/CE Feedback ใน SQL Server 2017–2022+ และเชื่อมโยงกับแนวทาง Performance Center ในหัวข้อ Query Performance Options ได้

---

---


## 📚 Sections (สารบัญบทเรียน)

| # | Section |
|---|---------|
| 1 | [Plan Cache Internals](Sections/01_Plan_Cache_Internals/README.md) |
| 2 | [Plan Cache Troubleshooting](Sections/02_Plan_Cache_Troubleshooting/README.md) |
| 3 | [Query Store Automatic Tuning](Sections/03_Query_Store_Automatic_Tuning/README.md) |

---


## 🧪 Labs

คู่มือปฏิบัติแบบ Instruction + Code block: [Labs/README.md](Labs/README.md) — สคริปต์ประกอบอยู่ใน `Sections/*/Scripts/` ตามหัวข้อ

---


## <details>
<summary><b>1. Parameter Sniffing คืออะไร?</b></summary>
ปรากฏการณ์ที่ SQL Server สร้าง Plan ตามค่า Parameter ครั้งแรกที่รัน ซึ่งอาจจะไม่เหมาะกับ Parameter ค่าอื่นในอนาคต (เช่น ครั้งแรก Data น้อย ได้ Nested Loop แต่ครั้งถัดไป Data เยอะ ก็ยังใช้ Nested Loop จนช้า)
</details>

<details>
<summary><b>2. ข้อดีของ Query Store คืออะไร?</b></summary>
เปรียบเสมือนกล่องดำบันทึกการบิน (Flight Recorder) ที่เก็บประวัติ Plan และ Performance ย้อนหลัง ทำให้เราสามารถ Force Plan เก่าที่ดีกว่ากลับมาใช้ได้เมื่อเกิดปัญหา
</details>

<details>
<summary><b>3. ทำไมเราไม่ควรใช้ DBCC FREEPROCCACHE บ่อยๆ?</b></summary>
เพราะการล้าง Cache จะทำให้ CPU Spike เนื่องจากต้อง Compile Query ใหม่ทั้งหมด (Compilation Storm) และเสีย Disk I/O เพื่ออ่าน Metadata ใหม่
</details>


---

---


## ### 7.1 Plan Cache
- **Optimized sp_executesql (ใหม่ใน 2025)** — ทำให้ batch ที่ส่งผ่าน `sp_executesql` เข้าสู่กระบวนการ compile แบบ serialize เหมือน stored procedure ช่วยลด **compilation storms** (โหลด compile พร้อมกันจำนวนมาก เช่น หลัง failover หรือ cache flush) — เปิดผ่าน sp_configure หรือ database scoped configuration
- ยังใช้เกณฑ์เดิม: ดู plan cache bloat ด้วย `sys.dm_os_memory_cache_counters` (CacheType `SQL Plans` vs `Object Plans`), SINGLE_USE vs MULTI_USE plans

### 7.2 Query Store ล่าสุด
- **Query Store สำหรับ readable secondary เปิด default ใน 2025** — วิเคราะห์ workload ฝั่ง AG secondary ได้เลย
- **Query Store Hints (2022+)** + **`ABORT_QUERY_EXECUTION` hint (ใหม่ใน 2025)**: บล็อก query ที่รู้ว่ามีปัญหา (เช่น ad-hoc หนักจาก app) ได้โดยไม่ต้องแก้โค้ด
- Automatic Plan Correction: `ALTER DATABASE ... SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON);`

### 7.3 แนวทางปฏิบัติ
- ตรวจ regressed plan ตาม `avg_duration`/`avg_cpu_time` ต่อช่วงเวลา (ทำใน Lab 8)
- Force Plan ใช้เป็น **ยาฉุกเฉิน** พร้อมวางแผนแก้ query/index ที่ต้นเหตุต่อ

> อ้างอิง: [Query Store hints](https://learn.microsoft.com/sql/relational-databases/performance/query-store-hints-best-practices), [Optimized sp_executesql](https://learn.microsoft.com/sql/relational-databases/system-stored-procedures/sp-executesql-transact-sql), [Automatic tuning](https://learn.microsoft.com/sql/relational-databases/automatic-tuning/automatic-tuning)