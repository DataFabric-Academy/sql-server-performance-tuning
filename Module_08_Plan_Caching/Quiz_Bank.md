# Quiz Bank — Module 08: Plan Caching & Query Store

> ครอบคลุม learning objectives ของบทที่ 8 (Course_Guide_4Days.md): Parameterization, Cache Lookup, Plan Reuse, Plan Cache Pollution, Recompilation, Query Store (history/regression/force plan), Automatic Tuning, Optimized sp_executesql (2025), Query Store Hints + ABORT_QUERY_EXECUTION
> ระดับ: ★ = จำความรู้ · ★★ = ประยุกต์ · ★★★ = วิเคราะห์หน้างาน
> เฉลยพร้อมคำอธิบายอยู่ท้ายไฟล์

---

## ส่วนที่ 1: กลไก Plan Cache

**Q1 (★)** — ลำดับขั้นการ compile ที่ถูกต้องคือข้อใด?
- A) Optimizer → Parser → Algebrizer → Codegen
- B) Parser → Algebrizer → Optimizer → Codegen
- C) Algebrizer → Parser → Codegen → Optimizer
- D) Parser → Optimizer → Algebrizer → Codegen

**Q2 (★)** — ข้อใด **ไม่ใช่** เงื่อนไขที่ plan จะถูก reuse ได้ (cache match)?
- A) ข้อความ query เหมือนกันทุกตัวอักษร
- B) SET options ของ session ตรงกัน
- C) CPU ของ server ว่างพอ
- D) ฐานข้อมูลที่ execute เป็นฐานข้อมูลเดียวกัน

**Q3 (★★)** — รัน query แบบ literal สองครั้ง (`WHERE SalesOrderID = 43669` แล้ว `= 43670`) บนฐานที่ Simple Parameterization ทำงาน ผลใน `sys.dm_exec_cached_plans` จะเป็นอย่างไร?
- A) มี plan แบบ Prepared หนึ่งตัวแชร์กัน + shell plan Adhoc ต่อค่า
- B) มี plan Adhoc สองตัวแยกกันสมบูรณ์ ไม่มีการแชร์
- C) ไม่มีอะไรถูก cache เลยเพราะเป็น ad-hoc
- D) มี plan Prepared สองตัว — หนึ่งตัวต่อค่า

**Q4 (★)** — Cache store ใดเก็บ plan ของ stored procedures?
- A) `CACHESTORE_SQLCP` (SQL Plans)
- B) `CACHESTORE_OBJCP` (Object Plans)
- C) `CACHESTORE_PHDR` (Bound Trees)
- D) `CACHESTORE_XPROC`

**Q5 (★★)** — จากการทดลองข้อมูลเบ้ (TH = 1 แถว, US = 10,000 แถว): รัน proc ด้วย `'TH'` ก่อน (ได้ plan Seek + Key Lookup, 4 logical reads) แล้วรันด้วย `'US'` ตามมา — เกิดอะไรขึ้นกับการรัน `'US'`?
- A) Compile plan ใหม่เพราะค่าต่างจากครั้งแรก
- B) ใช้ plan เดิม → ~20,017 logical reads จาก Key Lookup ทีละแถว 10,001 ครั้ง
- C) Error เพราะ plan ใช้กับค่าอื่นไม่ได้
- D) SQL Server สร้าง plan ที่สองแยกสำหรับ 'US' อัตโนมัติ

**Q6 (★★)** — `query_hash` ของสอง statement ตรงกัน แต่ `query_plan_hash` ไม่ตรงกัน สรุปได้อย่างไร?
- A) ข้อความ query ต่างกัน แต่ plan เหมือนกัน
- B) ข้อความ query เหมือนกัน แต่ถูก optimize เป็น plan คนละรูปแบบ
- C) query_hash ตรงกันแสดงว่าเป็น query เดียวกันใน cache เดียวกันเสมอ
- D) มีบั๊กของ engine — ปกติสองค่านี้ต้องตรงกัน

---

## ส่วนที่ 2: Troubleshooting

**Q7 (★★★)** — สรุป plan cache ของ server แสดง `Adhoc: 431 plans, single-use 400 plans (62.2/65.4 MB), avg_usecounts 1.68` — การวินิจฉัยและทางแก้ที่ถูกต้องตามลำดับคือ?
- A) CPU ไม่พอ — เพิ่ม core
- B) Ad-hoc plan pollution — แก้ app ให้ส่งพารามิเตอร์ เสริมด้วย `optimize for ad hoc workloads`
- C) Memory leak — restart service
- D) Statistics เน่า — รัน `sp_updatestats` ทั้ง DB

**Q8 (★★)** — การเปิด `optimize for ad hoc workloads` ทำงานด้วยกลไกใด?
- A) ห้าม ad-hoc query รันเกินครั้งเดียว
- B) ครั้งแรกเก็บเฉพาะ Compiled Plan Stub ขนาดเล็ก — รันซ้ำจึงเก็บ plan เต็ม
- C) บังคับ parameterize ทุก literal ทันที
- D) ล้าง plan cache อัตโนมัติทุกคืน

**Q9 (★)** — `SQL Re-Compilations/sec` สูงผิดปกติ แปลว่าอะไร?
- A) ไม่เคยมี plan ให้ใช้เลย
- B) Plan เดิมถูกสร้างใหม่ทั้งที่เคยมี (invalidate / hint) — เช่น schema/statistics เปลี่ยน
- C) Server restart บ่อย
- D) Buffer pool เล็กเกินไป

**Q10 (★★)** — เทียบผลทดสอบ 4 ทางเลือกบนข้อมูลเบ้ชุดเดียวกัน (รัน 'TH' แล้ว 'US') ข้อใดจับคู่ผลลัพธ์ถูกต้อง?
- A) Default 4/20,017 · OPTIMIZE FOR UNKNOWN 101/101 · OPTIMIZE FOR 'US' 101/101 · OPTION(RECOMPILE) 4/101
- B) Default 101/101 · OPTIMIZE FOR UNKNOWN 4/20,017 · OPTIMIZE FOR 'US' 4/101 · OPTION(RECOMPILE) 101/101
- C) ทั้ง 4 ตัวให้ผลเหมือนกันหมดเพราะข้อมูลชุดเดียวกัน
- D) Default 4/101 · OPTION(RECOMPILE) 4/20,017

**Q11 (★★★)** — ต้องการรีเซ็ต plan ของ stored procedure ตัวเดียวบน production โดยไม่กระทบ workload อื่น วิธีใดถูกต้อง?
- A) `DBCC FREEPROCCACHE;` ล้างทั้งหมด
- B) `DBCC FREEPROCCACHE (@plan_handle);` เฉพาะ plan_handle ของ proc นั้น
- C) `ALTER DATABASE ... SET PARAMETERIZATION SIMPLE;`
- D) Restart SQL Server service

---

## ส่วนที่ 3: Query Store & Automatic Tuning

**Q12 (★)** — ข้อใดเป็นข้อดีหลักของ Query Store ที่ Plan Cache ให้ไม่ได้?
- A) ทำให้ query รันเร็วขึ้นโดยตรง
- B) เก็บประวัติ plan + สถิติรายช่วงเวลา (interval) — ย้อนวิเคราะห์ regression ได้แม้ plan จะถูก evict ไปแล้ว
- C) แทนที่ execution plan ทุกตัวด้วย trivial plan
- D) ลด logical reads ของ query

**Q13 (★★)** — ต้องการให้ query ที่ app ส่งมา (แก้โค้ดไม่ได้) ใช้ `MAXDOP 1` — เครื่องมือที่เหมาะที่สุดและข้อจำกัดที่ต้องระวังคือ?
- A) Plan Forcing — ต้องมี plan ที่ใช้ MAXDOP 1 อยู่แล้ว
- B) Query Store Hints (`sp_query_store_set_hints`) — ต้องปลด forced plan ของ query นั้นก่อน (ไม่งั้น Msg 12457)
- C) แก้ `max degree of parallelism` ระดับ server เป็น 1
- D) ใช้ `DBCC FREEPROCCACHE` แล้ว hint จะถูกนำไปใช้เอง

**Q14 (★★)** — รัน query ที่ถูกตั้ง hint `ABORT_QUERY_EXECUTION` (SQL Server 2025) ผลลัพธ์คือ?
- A) รันสำเร็จแต่ล็อก warning ไว้ใน Query Store
- B) ได้ Msg 8778 ทันทีโดยไม่มีการทำงานเกิดขึ้น
- C) รันได้บน primary เท่านั้น
- D) ถูกย้ายไปคิวรอโดยอัตโนมัติ

**Q15 (★★★)** — Automatic Plan Correction (`FORCE_LAST_GOOD_PLAN`) ทำงานเมื่อพบ regression — ถ้าหลัง force แล้วประสิทธิภาพ "ไม่ดีขึ้นจริง" ระบบจะทำอย่างไร และเมื่อไรควรเปิดฟีเจอร์นี้?
- A) คง force ไว้ตลอด เพราะ plan เก่าดีกว่าเสมอ — เปิดตลอดเวลา
- B) ปลด force เองแล้วรอ compile ใหม่ — เหมาะเปิดช่วงหลัง upgrade compatibility level
- C) Restart Query Store — เปิดเฉพาะช่วง end of month
- D) เปลี่ยนไปใช้ OPPO โดยอัตโนมัติ — เปิดเฉพาะ Azure SQL

---

## เฉลย

**Q1 — B.** Pipeline ถูกต้อง: Parser (ตรวจ syntax) → Algebrizer (resolve ชื่อ/ผูก metadata ได้ Query Processor Tree) → Optimizer (Trivial Plan หรือ Full Optimization แบบ cost-based ตามขั้น) → Codegen (สร้างคำสั่งให้ Executor) — ถ้าผิดในขั้นใดก่อนหน้า Optimizer ก็จะไม่เสียเวลา optimize

**Q2 — C.** เงื่อนไขการ match ตรวจที่ข้อความ query, SET options (ผ่าน `set_options` bitmask ใน `sys.dm_exec_plan_attributes`), ฐานข้อมูล และ user context — "CPU ว่าง" ไม่เกี่ยวกับการ match plan เลย (มันเกี่ยวกับ scheduling ใน Module 1)

**Q3 — A.** Simple Parameterization หลุด literal เป็น `@1` → เก็บ **Prepared** plan หนึ่งตัวที่แชร์กันทุกค่า (usecounts เพิ่มตามการใช้) พร้อม **shell plan Adhoc** ต่อค่าที่พิมพ์เข้ามา (usecounts=1) — จากการรันจริง: `(@1 int)SELECT ... WHERE [SalesOrderID]=@1 | Prepared | usecounts รวมทุกค่า` + shell `Adhoc 16 KB`

**Q4 — B.** Object Plans (`CACHESTORE_OBJCP`) เก็บ plan ของ proc/function/trigger; SQL Plans (`CACHESTORE_SQLCP`) เก็บ ad-hoc/prepared — ซึ่งเป็นแหล่ง pollution ที่พบบ่อยที่สุด

**Q5 — B.** นี่คือ Parameter Sniffing เชิงกลไก: plan ถูกหล่อหลอมจากค่าแรก ('TH' = 1 แถว → Seek + Lookup) และถูก reuse กับ 'US' → 10,001 ครั้งของ Key Lookup = ~20,017 logical reads (จากการรันจริง 17.0.1135.8) ทั้งที่ plan ที่ compile สดจาก 'US' ใช้เพียง 101 reads (Scan) — พิสูจน์ด้วย usecounts=2 และ `StatementEstRows = 1` ใน plan XML

**Q6 — B.** `query_hash` = fingerprint ของ **ข้อความ statement** (query เดียวกัน) — `query_plan_hash` = fingerprint ของ **รูปร่าง plan** — ต่างกันแปลว่า query รูปแบบเดียวกันวิ่งด้วยหลาย plan (อาการ sniffing/plan change) — จากการรันจริง: สอง proc statement เหมือนกัน compile ต่างค่า → query_hash เดียว 2 plan_hash

**Q7 — B.** single-use ratio = 400/431 ≈ 93% และ 95% ของพื้นที่ Adhoc เป็นขยะ — ตรงเกณฑ์ Ad-hoc Plan Pollution — ทางแก้รากคือ parameterization ฝั่ง app; `optimize for ad hoc workloads` ช่วยแปลง plan รันครั้งเดียวเป็น stub (จากผลจริง: Adhoc 431 plans / single-use 400 / 62.2 จาก 65.4 MB)

**Q8 — B.** Stub (~8 KB) แทน plan เต็มสำหรับ batch ที่ "รันครั้งเดียว" — ถ้าถูกรันซ้ำจึง compile เต็มและเก็บ plan จริง — ประหยัด memory จาก single-use ad-hoc มหาศาลโดยไม่ต้องแก้ app

**Q9 — B.** Re-Compilations = สร้าง plan ใหม่ "ทั้งที่เคยมี" — เหตุหลัก: schema เปลี่ยน, statistics อัปเดต, SET options ต่าง, temp table, hint RECOMPILE — ต่างจาก Compilations ที่หมายถึง compile ครั้งแรก (cache miss)

**Q10 — A.** ผลรันจริงบน 17.0.1135.8: Default 4→20,017 (victim), UNKNOWN 101/101 (estimate จาก density → Scan ทั้งคู่), OPTIMIZE FOR 'US' 101/101 (สมมุติค่าหนัก), RECOMPILE 4/101 (compile สดถูกทุกครั้ง แลก compile cost) — เลือกตามสถานการณ์: รันถี่มากอย่าใช้ RECOMPILE

**Q11 — B.** `DBCC FREEPROCCACHE (@plan_handle)` ลบเฉพาะ plan ที่ระบุ — ค้นหา plan_handle ของ proc จาก `sys.dm_exec_cached_plans` + `sys.dm_exec_sql_text` — ล้างทั้ง instance (A) ทำให้ทุก query compile ใหม่พร้อมกัน = compilation storm; ทางเลือกอื่นที่ละเอียด: เฉพาะ store (`DBCC FREEPROCCACHE('SQL Plans')`) หรือเฉพาะ DB (`ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE`)

**Q12 — B.** Plan Cache เป็น "snapshot ปัจจุบัน" และ plan หายได้ทุกเมื่อ — QS เก็บทุก plan ที่เคยใช้ + สถิติแยก interval ลงตารางระบบของ DB — จึงตอบได้ว่า "เมื่อวาน query นี้ใช้ plan ไหน ช้ากว่าวันนี้กี่เท่า" และยังตอบได้หลัง restart

**Q13 — B.** QS Hints ออกแบบมาเพื่อเคสนี้พอดี: ใส่ `OPTION()` ให้ query โดยไม่แก้โค้ด (ข้อจำกัด: ถ้า query ยังมี forced plan ต้อง `sp_query_store_unforce_plan` ก่อน — ไม่งั้น Msg 12457) — C กระทบทั้ง server, A ล็อกทั้ง plan ไม่จำเป็น, D ไม่เกี่ยวกับ hint

**Q14 — B.** Msg 8778: "Query execution has been aborted because the ABORT_QUERY_EXECUTION hint was specified." — ใช้บล็อก query หนักที่ app ยิงมาแต่แก้โค้ดไม่ได้ทัน (พิสูจน์รันจริงบน 17.0.1135.8) — เหมาะใช้ชั่วคราวพร้อมแจ้งเจ้าของระบบ

**Q15 — B.** วงจรของมันคือ: จับ regression → force plan เก่า → ทดสอบยืนยันต่อเนื่อง → ถ้าไม่ดีขึ้นจริงปลด force เองแล้วรอ plan ใหม่ — Best case คือเปิดหลัง upgrade compat level (เช่น 150→170) เพื่อรั้ง plan ที่ดีไว้ระหว่างช่วงสังเกตการณ์ แล้วทบทวน `sys.dm_db_tuning_recommendations` (บน 2025 ใช้ JSON path `$.planForceDetails.*` — คอลัมน์ `script` ถูกถอด) ตามระยะ

---

## ตารางคะแนนแนะนำ

| คะแนน | แปลผล |
|:---|:---|
| 13–15 | พร้อมไป Module 9 — ครอบคลุมทั้งกลไกและหน้างาน |
| 10–12 | ผ่าน — ทบทวนหัวข้อที่ผิด (โดยเฉพาะ Q10, Q13 ฝั่งเครื่องมือแก้) |
| < 10 | กลับไปอ่าน Section 8.1 (กลไก) และทำ Lab 8 ซ้ำก่อนขึ้น Module 9 |
