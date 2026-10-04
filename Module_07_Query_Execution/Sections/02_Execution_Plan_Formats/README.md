[⬅ Module 07](../../README.md) | [1. Query Optimizer](../01_Query_Optimizer/README.md) | Section 2/4 | ➡ ถัดไป: [03 Analyzing Query Plans](../03_Analyzing_Query_Plans/README.md)

# 7.2 Execution Plan Formats — อ่าน "แผนผังการทำงาน" ได้ทุกรูปแบบ ตั้งแต่กราฟิกใน SSMS ถึง XML ใน Query Store

> *"Execution plan ไม่ใช่ภาพ — มันคือเอกสารเทคนิคที่ engine เขียนให้คุณอ่าน กราฟิกเป็นแค่ผิว ข้างในคือ XML ที่บอกทุกความลับ ตั้งแต่ memory grant ไปจนถึงเหตุผลที่ optimizer เลือกทางนั้น"*

> **ต้องรู้มาก่อน**: [Execution Plan](../../../Glossary.md), [Plan Cache](../../../Glossary.md), [Query Store](../../../Glossary.md), [DMV / DMF](../../../Glossary.md) — และ Section 7.1 (pipeline: plan เกิดที่ขั้น Optimization ก่อน Execution) รวมถึงสิทธิ์ `VIEW DATABASE STATE` สำหรับอ่าน `sys.query_store_plan`
> **สภาพแวดล้อมทดสอบ**: SQL Server 2025 RTM-GDR (17.0.1135.8), ฐานข้อมูล `AdventureWorks` (compat 170, Query Store เปิด, `LAST_QUERY_PLAN_STATS = 0`) — ตัวเลข Expected รันจริงเมื่อ 2026-10-02

---

## เปิดเรื่อง: Plan เดียว มีหลาย "ฉบับ" — ใช้ฉบับไหนเมื่อไร

Plan ที่ optimizer สร้างขึ้นคือชุดข้อมูลเดียว แต่คุณเรียกดูได้หลาย **format** และหลาย **เวลา** — เลือกผิดฉบับก็ได้ข้อสรุปผิด:

| คำถาม | ฉบับที่ใช้ | เครื่องมือ |
|:------|:-----------|:-----------|
| "ถ้ารัน จะทำงานอย่างไร?" | **Estimated plan** | Ctrl+L / `SET SHOWPLAN_XML ON` |
| "พึ่งรันไป มันทำงานอย่างไรจริง?" | **Actual plan** | Ctrl+M / `SET STATISTICS XML ON` |
| "ตอนนี้กำลังทำงานถึงไหน?" | **Live plan** | Live Query Statistics / `sys.dm_exec_query_profiles` |
| "เมื่อวานรันแล้วเป็นอย่างไร?" | **Plan ใน Query Store** | `sys.query_store_plan` |
| "คิวรีรันซ้ำทุกวัน เปรียบเทียบ plan เก่า/ใหม่?" | **Plan ใน Query Store** + Plan Comparison | Module 8 |

เส้นทางของ Section:

1. **Estimated vs Actual** — ต่างกันตรงไหน และความเชื่อผิดที่พบบ่อย
2. **รูปแบบการแสดงผล** — กราฟิก / XML / `.sqlplan` / JSON (และข้อควรรู้เรื่อง "plan แบบ JSON")
3. **Operators สำคัญ** — คลัง operator ที่จะเจอบ่อยสุดใน OLTP
4. **Plan Properties** — ข้อมูลเชิงลึกที่กราฟิกซ่อนไว้ อ่านจาก XML ได้ทั้งหมด
5. **Live Query Statistics** — มอง plan ตอนกำลังรัน

> **หมายเหตุสภาพแวดล้อม:** บล็อกที่ต้องเห็นกราฟิก (Ctrl+M / Ctrl+L) ให้ทำใน SSMS — บล็อก SQL ทุกตัวรันผ่าน sqlcmd จริงบน VM หลักสูตร และไม่แก้ configuration ใด ๆ

---

## 1. Estimated Plan vs Actual Plan — plan ใบเดียวกัน แค่ติด "ผลจริง" กลับมา

**นิยามก่อนใช้:**
- **Estimated Plan** = ผลจากขั้น Optimization ยังไม่รัน ไม่มีตัวเลข runtime ใช้ตรวจโครงสร้าง/ตรวจคิวรีที่แพงเกินก่อนรันจริง
- **Actual Plan** = plan **ใบเดียวกัน** ที่ถูกติด runtime statistics กลับมา (Actual Rows, Actual Number of Rows for Each Execution, Actual Rebinds ฯลฯ)

> [!IMPORTANT]
> ความเชื่อผิดที่พบบ่อยที่สุด: "Actual plan = plan ใหม่ที่รันจริงแล้วต่างจาก estimated" — **ไม่ใช่** SQL Server ไม่ recompile ระหว่างรัน (กรณีปกติ) — actual plan คือ plan เดิม + ตัวเลขจริง ดังนั้นช่องว่างระหว่าง **Estimated Rows กับ Actual Rows** คือความคลาดเคลื่อนของ **Cardinality Estimation** ซึ่งเป็นสัญญาณวินิจฉัยชั้นแรกของการวิเคราะห์ plan (ใช้จริงใน Section 7.3)

### 1.1 Estimated Plan — ดูก่อนรัน

ใน SSMS: `Ctrl+L` (Display Estimated Execution Plan) หรือผ่าน T-SQL ด้วย `SET SHOWPLAN_XML ON` — โหมดนี้คิวรี **จะไม่ถูกรันจริง** มีแต่คืน plan เป็น XML:

```sql
SET SHOWPLAN_XML ON;
GO
SELECT TOP (10) SalesOrderID, OrderDate
FROM Sales.SalesOrderHeader
WHERE CustomerID = 29825;
GO
SET SHOWPLAN_XML OFF;
GO
```

**Expected:** คืนเอกสาร XML ชื่อ `<ShowPlanXML ...>` ใน result แทนแถวข้อมูล — ประหยัดสุดเมื่อคิวรีจะแพงมาก (รู้ก่อนว่าจะ scan ทั้งตารางไหม โดยไม่ต้อง scan จริง) ข้อจำกัด: ต้องเป็น statement เดียวต่อ batch ในโหมดนี้และ query ที่อ้าง temp table ข้าม batch จะ compile ไม่ได้

กับดักเชิงปฏิบัติที่ควรรู้ก่อนใช้ estimated plan: คิวรีที่อ้าง **temp table ที่สร้างไว้ตั้งแต่ batch ก่อน** จะ compile ไม่ผ่านในโหมด SHOWPLAN (`Could not find object '#tmp...'`) เพราะแต่ละ batch ถูก compile แยก — วิธีเลี่ยง: ประเมินเฉพาะ statement ที่ไม่อ้าง temp table ข้าม batch หรือเปลี่ยนมาใช้ actual plan (Ctrl+M) ซึ่ง compile รวมทั้ง session ได้ นอกจากนี้ estimated plan **ไม่ได้รัน statement** จึงไม่ทำ side effect (ปลอดภัยกับ INSERT/DELETE — เห็น plan ได้โดยไม่แตะข้อมูล) แต่ก็แลกมาด้วย "ไม่มีตัวเลขจริง" ทั้งหมด

### 1.2 Actual Plan — ดูหลังรัน (พร้อมตัวเลขจริง)

ใน SSMS: `Ctrl+M` (Include Actual Execution Plan) หรือผ่าน T-SQL:

```sql
SET STATISTICS XML ON;
GO
SELECT TOP (10) soh.SalesOrderID, soh.OrderDate, COUNT_BIG(*) AS items
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.SalesOrderDetail AS sod ON sod.SalesOrderID = soh.SalesOrderID
WHERE soh.CustomerID = 29825
GROUP BY soh.SalesOrderID, soh.OrderDate;
GO
SET STATISTICS XML OFF;
GO
```

**Expected:** ได้ผลลัพธ์แถวข้อมูล 1 ชุด + แถว XML ของ plan ต่อ statement — ใน XML จะมี attribute คู่เทียบอย่าง `StatementEstRows` (เดา) และบน operator จะมี `<RunTimeInformation><RunTimeCountersPerThread ActualRows="..." ActualRowsRead="..." ActualElapsedms="..." />` ซึ่งเป็นส่วนที่ estimated plan ไม่มี

### 1.3 Actual Plan ของการรันล่าสุดโดยไม่ต้อง Ctrl+M — `sys.dm_exec_query_plan_stats`

**นิยามก่อนใช้:** `sys.dm_exec_query_plan_stats` (2019+) คือ DMF ที่คืน **actual plan ของการรันครั้งล่าสุด** ของ plan handle ใด ๆ — แต่ทำงานได้เฉพาะเมื่อเปิด database scoped configuration `LAST_QUERY_PLAN_STATS = ON` เอาไว้ก่อน

```sql
SELECT name, value, value_for_secondary
FROM sys.database_scoped_configurations
WHERE name IN ('LAST_QUERY_PLAN_STATS', 'LIGHTWEIGHT_QUERY_PROFILING');
```

**Expected (VM หลักสูตร, 2026-10-02):** `LAST_QUERY_PLAN_STATS` = **0** (ยังไม่เปิด), `LIGHTWEIGHT_QUERY_PROFILING` = **1** (เปิด default ตั้งแต่ 2019) — บน VM ใช้ร่วม **ห้ามสลับเป็น ON เอง** (ต้องใช้สิทธิ์ ALTER DATABASE SCOPED CONFIGURATION และกระทบทุก session) ให้ทำใน VM ทดลองของตัวเอง; วิธีที่ "เปิดมาแล้ว" และไม่ต้องตั้งค่าอะไรคือ Query Store ในหัวข้อ 1.4

### 1.4 Plan ของการรันจริงจาก Query Store — เส้นทางที่ไม่ต้อง Ctrl+M เลย

เมื่อ Query Store เปิด (READ_WRITE) ทุก plan ที่ถูกใช้ถูกเก็บไว้เป็น XML ใน `sys.query_store_plan.query_plan` พร้อม runtime stats รวมใน `sys.query_store_runtime_stats` — นี่คือ "actual plan แบบย้อนหลัง" ที่ใช้ตรวจได้แม้คิวรีรันไปแล้วหลายวัน (จึงเป็นเสาหลักของ Module 8):

```sql
SELECT TOP (10) q.query_id, p.plan_id, p.plan_type_desc,
       p.last_execution_time, rs.count_executions,
       rs.avg_logical_io_reads, rs.avg_duration
FROM sys.query_store_plan AS p
JOIN sys.query_store_query AS q ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats AS rs ON rs.plan_id = p.plan_id
WHERE p.last_execution_time > DATEADD(HOUR, -2, SYSDATETIME())
ORDER BY rs.count_executions DESC;
```

**Expected:** รายการคิวรีที่รันใน 2 ชั่วโมงล่าสุด เรียงตามจำนวน execution — คอลัมน์ `plan_type_desc` ปกติเป็น `Compiled Plan` (ถ้าเห็น `Dispatcher Plan` / `Query Variant Plan` = คิวรีนั้นถูก IQP แบบ multiplan จัดการ — ดูลึกใน Section 7.4)

---

## 2. รูปแบบการแสดงผล — กราฟิก / XML / .sqlplan / JSON

### 2.1 กราฟิก (Graphic Plan) — ผิวที่อ่านง่าย

SSMS วาด plan เป็นต้นไม้ที่ **อ่านจากขวาไปซ้าย บนลงล่าง** — ตัวดำเนินการซ้ายสุด (root) คือผลลัพธ์สุดท้าย; ลูกศรมี "ความหนา" ตามจำนวนแถวที่ไหลผ่าน ให้ลำดับการอ่านมืออาชีพคือ:

1. หา operator ที่ **ลูกศรเข้าหนาสุด** (ข้อมูลเข้าเยอะ)
2. เทียบ **Estimated vs Actual** ตรงนั้น
3. ไล่ subtree cost จาก root ลงมาหา "ตัวจ่ายแพงสุด"

ข้อจำกัดของกราฟิก: ไม่แสดงทุก property (เช่น `MemoryGrantInfo`, `OptimizerHardwareDependentProperties`, `ParameterRuntimeValue`) — สิ่งเหล่านี้อยู่ใน XML ทั้งหมด (คลิกขวา plan → Properties ก็เห็นบางส่วนในหน้าต่าง Properties)

### 2.2 XML — ฉบับสมบูรณ์ที่สุด (และเป็นตัวจริงของกราฟิก)

ไฟล์ `.sqlplan` ที่คุณ save จาก SSMS ก็คือ XML text — schema อยู่ที่ namespace `http://schemas.microsoft.com/sqlserver/2004/07/showplan` โครง 3 ชั้นที่ต้องรู้จำ:

```xml
<ShowPlanXML xmlns="...showplan" Version="..." Build="17.0.1135.8">
  <BatchSequence>
    <Batch>
      <Statements>
        <StmtSimple StatementText="..." StatementOptmLevel="FULL"
                    StatementOptmEarlyAbortReason="GoodEnoughPlanFound"
                    StatementEstRows="..." StatementSubTreeCost="...">
          <QueryPlan DegreeOfParallelism="1" MemoryGrant="1024"
                     CachedPlanSize="32" CompileTime="3" CompileCPU="3">
            <MemoryGrantInfo SerialRequiredMemory="..." SerialDesiredMemory="..." />
            <RelOp NodeId="0" PhysicalOp="Clustered Index Scan" LogicalOp="Scan" ...>
              <RunTimeInformation>...</RunTimeInformation>   <!-- เฉพาะ actual plan -->
```

แผนที่ attribute ที่ใช้บ่อยในงานวินิจฉัย:

| Attribute | อยู่ที่ | บอกอะไร |
|:----------|:--------|:--------|
| `StatementOptmLevel` | StmtSimple | TRIVIAL / FULL (Section 7.1) |
| `StatementOptmEarlyAbortReason` | StmtSimple | GoodEnoughPlanFound / TimeOut |
| `StatementEstRows` | StmtSimple | CE รวมของ statement |
| `DegreeOfParallelism` | QueryPlan | DOP ที่ใช้จริง (absent = serial บางกรณี) |
| `MemoryGrant` | QueryPlan | memory grant (KB) ที่จัดให้ |
| `CachedPlanSize` / `CompileTime` / `CompileCPU` | QueryPlan | ขนาด plan / ต้นทุน compile |
| `ActualRows` | RunTimeInformation | แถวจริงที่ไหลผ่าน (actual plan เท่านั้น) |

### 2.3 "Plan แบบ JSON" — ความจริงที่ต้องเข้าใจตรงกัน

SQL Server **ไม่มี execution plan รูปแบบ JSON มาตรฐาน** (ต่างจาก PostgreSQL ที่มี `EXPLAIN (FORMAT JSON)`) — plan ทางการของ SQL Server คือ **XML เท่านั้น** (กราฟิกใน SSMS ก็วาดจาก XML นี้) สิ่งที่คนพูดถึง "JSON" มักหมายถึงงาน integration: ดึงคุณสมบัติจาก plan XML แล้วส่งออกเป็น JSON ให้ monitoring/telemetry อ่านต่อ ซึ่งทำได้ด้วย `FOR JSON` ใน 3 บรรทัด:

```sql
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'),
Props AS (
    SELECT q.query_id,
           CAST(p.query_plan AS XML).value(
               '(/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/@StatementOptmLevel)[1]', 'NVARCHAR(40)') AS opt_level,
           CAST(p.query_plan AS XML).value(
               '(/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/@CachedPlanSize)[1]', 'INT') AS cached_plan_size_kb
    FROM sys.query_store_query AS q
    JOIN sys.query_store_plan AS p ON p.query_id = q.query_id
)
SELECT TOP (5) query_id, opt_level, cached_plan_size_kb
FROM Props
WHERE opt_level IS NOT NULL
FOR JSON PATH;
```

**Expected (รันจริง, 2026-10-02):** ผลลัพธ์เป็นข้อความ JSON หนึ่งเซลล์ เช่น

```json
[{"query_id":323,"opt_level":"FULL","cached_plan_size_kb":192},
 {"query_id":366,"opt_level":"FULL","cached_plan_size_kb":16},
 {"query_id":367,"opt_level":"FULL","cached_plan_size_kb":24}]
```

ใช้เป็นรูปแบบส่งต่อให้ pipeline ภายนอกได้ — แต่เมื่อ "วิเคราะห์ plan" ให้กลับมาที่ XML เสมอ เพราะเป็นแหล่งความจริงที่ครบที่สุด

### 2.4 ไฟล์ .sqlplan และการเทียบ plan สองฉบับ — วินัยที่กัน "แก้แล้วดีขึ้นจริงไหม"

เพราะ plan เปลี่ยนได้ (สถิติใหม่, schema, IQP feedback, restart) — วินัยที่แยกมืออาชีพออกจากการเดาคือ **เก็บ plan ก่อนแก้และหลังแก้ เทียบเป็นคู่**:

| ขั้น | ทำอะไร | ที่ไหน |
|:-----|:-------|:-------|
| 1. จับก่อนแก้ | เปิด plan ของคิวรีที่ป่วย → คลิกขวา → **Save Execution Plan As...** เป็น `query_before.sqlplan` | SSMS |
| 2. แก้ตามสมมติฐาน | สร้าง index / แก้ statistics / rewrite / hint | (Module 6-8) |
| 3. จับหลังแก้ | รันคิวรีเดิมด้วย Ctrl+M → save เป็น `query_after.sqlplan` | SSMS |
| 4. เทียบ | เปิดไฟล์หนึ่งแล้วคลิกขวาบนพื้น plan → **Compare Showplan** → เลือกอีกไฟล์ | SSMS |

สิ่งที่ Compare บอกได้ทันที: operator ที่หายไป/เกิดใหม่ (เช่น Key Lookup หายเพราะ covering index), ตัวเลข cost ที่เปลี่ยน และจุดที่ estimate ยังเบี้ยวอยู่ — ถ้าแก้แล้ว cost ลดแต่ runtime ไม่ดีขึ้น ให้กลับไปหา CE ตาม Section 7.3 ระบบที่ทำขั้น 1-4 ให้อัตโนมัติและเก็บย้อนหลังได้คือ Query Store (Module 8)

---

## 3. Operators สำคัญ — คลังที่จะเจอบ่อยสุด

**นิยามก่อนใช้:** **Operator** คือขั้นย่อยหนึ่งของ plan ที่รับแถวเข้า/ส่งแถวออก — แต่ละ operator มีทั้งชื่อ **logical** (อธิบายความหมาย เช่น Join, Scan) และ **physical** (วิธีทำจริง เช่น Hash Match, Index Scan) ที่สอดคล้องกันหลายต่อหลาย

| กลุ่ม | Operator (Physical) | ทำอะไร | สัญญาณเตือน |
|:------|:--------------------|:-------|:-------------|
| อ่านข้อมูล | Clustered Index Seek | เจาะ B-tree ของ clustered index ตาม predicate | — (ดี) |
| | Index Seek | เจาะ B-tree ของ nonclustered index | — (ดี) |
| | Clustered Index Scan / Index Scan / Table Scan | อ่าน leaf ทั้งหมด | แพงเมื่อตารางใหญ่ + predicate มี selectivity สูง |
| | Key Lookup | โดดกลับ clustered index เพื่อเอาคอลัมน์ที่ index ไม่มี | ซ้ำหลายพันครั้ง = รายจ่าย I/O โชคชะตา (แก้ใน 7.3) |
| รวมข้อมูล | Stream Aggregate | รวมข้อมูลที่ **เรียงแล้ว** ทีละกลุ่ม ไม่ใช้ memory เพิ่ม | ต้องมี input เรียง (มักมาคู่ Sort) |
| | Hash Match (Aggregate) | รวมด้วย hash table ใช้ memory grant | memory grant ไม่พอ → spill |
| เรียง | Sort | เรียงตาม ORDER BY/การซ้อนกัน | spill warning เมื่อ grant ไม่พอ |
| Join | Nested Loops / Hash Match / Merge Join | 3 อัลกอริทึม join (ลึกใน 7.3) | Loop กับ outer ใหญ่ = ภาระซ้ำ |
| ขนาน | Distribute/Repartition/Gather Streams (Parallelism) | กระจาย/รวมข้อมูลระหว่าง thread | ค่า exchange พุ่ง + CXPACKET (Module 1) |
| อื่น ๆ | Filter, Top, Compute Scalar, Spool | คัด/ตัด/คำนวณ/แคชชั่วคราว | Table Spool ซ้ำ ๆ อาจชี้ design |

> [!NOTE]
> ระวังการตัดสินจาก "ชื่อ operator เดียว" — Scan บนตาราง 10 แถวนั้นถูกกว่า Seek 10,000 ครั้งเสมอ เกณฑ์ตัดสินจริงคือ cost และจำนวนแถว ไม่ใช่ชื่อ (หัวใจของ Section 7.3)

---

## 4. Plan Properties — อ่าน "เหตุผลของ optimizer" จาก XML

กราฟิกบอก "อะไร" — property บอก "ทำไม" บล็อกนี้ดึงคุณสมบัติสำคัญของ plan ล่าสุดใน Query Store (ใช้ path เต็มจากราก `/ShowPlanXML/...` ป้องกันความคลาดเคลื่อน child-vs-descendant ตามบทเรียนจาก Labs):

```sql
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'),
Props AS (
    SELECT q.query_id,
           CAST(p.query_plan AS XML).value(
               '(/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/@StatementParameterizationType)[1]', 'NVARCHAR(40)') AS param_type,
           CAST(p.query_plan AS XML).value(
               '(/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/@StatementOptmLevel)[1]', 'NVARCHAR(40)') AS opt_level,
           CAST(p.query_plan AS XML).value(
               '(/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/@DegreeOfParallelism)[1]', 'INT') AS dop,
           CAST(p.query_plan AS XML).value(
               '(/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/@CachedPlanSize)[1]', 'INT') AS cached_plan_size_kb,
           CAST(p.query_plan AS XML).value(
               '(/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/@CompileTime)[1]', 'INT') AS compile_cpu_ms
    FROM sys.query_store_query AS q
    JOIN sys.query_store_plan AS p ON p.query_id = q.query_id
)
SELECT TOP (8) query_id, param_type, opt_level, dop, cached_plan_size_kb, compile_cpu_ms
FROM Props
WHERE opt_level IS NOT NULL
ORDER BY query_id DESC;
```

**Expected (รันจริง, 2026-10-02):**

| query_id | param_type | opt_level | dop | cached_plan_size_kb | compile_cpu_ms |
|---------:|:-----------|:----------|----:|--------------------:|---------------:|
| 2032 | 0 | FULL | NULL | 200 | 38 |
| 2031 | 0 | FULL | NULL | 80 | 40 |
| 2030 | 0 | FULL | NULL | 32 | 3 |
| ... | 0 | FULL | NULL | ... | ... |

อ่านผลแบบมืออาชีพ:

1. `param_type` (`StatementParameterizationType`): 0 = none, 1 = simple, 2 = forced — ตรวจว่าคิวรีถูก parameterize หรือเปล่า (แหล่งเดียวที่เชื่อได้ — อย่าใช้ attribute ชื่อ `Parameterization` ซึ่งไม่มีใน schema นี้)
2. `dop = NULL` บน plan ทั้งชุด = ทุก plan ที่จับได้เป็น serial — server นี้มีจำกัด CPU/ค่า threshold ทำให้คิวรีส่วนใหญ่ไม่ขนาน
3. `compile_cpu_ms` สูง ๆ คู่กับ query ที่รันถี่ = เสีย CPU ไปกับ compile มากเกิน — เข้าทาง plan reuse / Optimized sp_executesql (7.4)

> [!TIP]
> บันทึก plan ไว้เทียบ: ใน SSMS คลิกขวาที่ plan → Save Execution Plan As... ได้ `.sqlplan` ซึ่งเปิดกลับมาเทียบข้างคู่กันได้ (Compare Showplan) — เป็นวิธีมาตรฐานที่จับ "plan เปลี่ยน" ก่อนเริ่มแก้อะไร (ทำเป็นระบบด้วย Query Store ใน Module 8)

สรุป "คุณสมบัติ → ตัดสินใจอะไร" เป็นแผนที่ประจำใจ:

| เห็นค่านี้ใน XML | ตีความ | การตัดสินใจต่อ |
|:------------------|:-------|:----------------|
| `StatementOptmEarlyAbortReason="TimeOut"` | optimize ไม่จบ | ดู runtime คู่กันก่อนว่าแย่จริงไหม (7.1 §4) |
| `StatementParameterizationType=0` + รันถี่ | ไม่ถูก parameterize → compile ซ้ำ | ส่ง parameter ด้วย proc/sp_executesql |
| `DegreeOfParallelism > 1` + ช้า | ขนานแล้วยังช้า | ดู wait CXPACKET/CXCONSUMER (M1), DOP Feedback (7.4) |
| `MemoryGrant` มากแต่ `UsedGrant` น้อย | จองเกิน | CE เดามากไป — ทาง MGF (7.4) |
| `CompileTime/CPU` สูงต่อ 1 execution | compile แพง | ลดความซับซ้อน / แก้ plan reuse |
| `ActualRows` >> `EstimateRows` | CE ผิด | กลับสู่กรอบ 4 คำถามของ Section 7.3 |

---

## 5. Live Query Statistics — มอง plan ตอนกำลังรัน

**นิยามก่อนใช้:** **Live Query Statistics** คือการดู plan ขณะ query กำลังทำงาน พร้อมตัวเลขแถวที่ไหลผ่านจริงราย operator (และ animation ใน SSMS) พื้นฐานของมันคือ **Lightweight Query Profiling** ซึ่งเปิด default ตั้งแต่ SQL Server 2019 จึงมี overhead ต่ำมากและเปิดตลอดได้

| วิธี | ขั้นตอน |
|:-----|:--------|
| SSMS (ก่อนรัน) | คลิกปุ่ม "Include Live Query Statistics" ข้าง ๆ Ctrl+M แล้วรัน |
| SSMS (รันค้างอยู่) | Activity Monitor → คลิกขวา session → Show Live Execution Plan |
| T-SQL | `sys.dm_exec_query_profiles` (DMV ที่อยู่เบื้องหลังทั้งสองวิธี) |

ทดลองจริง — คิวรีที่ query DMV ของ **session ตัวเอง** (ใช้ `@@SPID`) จะเห็น operator ของตัวเองกำลังถูกโปรไฟล์:

```sql
SELECT node_id, physical_operator_name, row_count, estimate_row_count
FROM sys.dm_exec_query_profiles
WHERE session_id = @@SPID
ORDER BY node_id;
```

**Expected (รันจริง, 2026-10-02):** คิวรีนี้เห็นตัวเอง — ได้ 2 แถว:

| node_id | physical_operator_name | row_count | estimate_row_count |
|--------:|:-----------------------|----------:|-------------------:|
| 0 | Sort | 0 | 0 |
| 1 | Table-valued function | 0 | 0 |

เพราะ `sys.dm_exec_query_profiles` ทำงานเป็น Table-valued function ภายในและจัดเรียงผลด้วย Sort — บนคิวรีจริงที่รันนาน (เช่น sort ข้อมูลเป็นแสนแถว) คุณจะเห็น `row_count` ไล่ขึ้นแบบ real time และรู้ทันทีว่า "คิวรีค้างที่ operator ไหน" ระวังตีความ: คิวรีที่จบเร็วกว่าการ poll มือคุณจะไม่มีแถวให้เห็นเลย (จบไปแล้ว) งานจริงใช้ query นี้ร่วมกับ `sys.dm_exec_requests` เพื่อกรองเฉพาะ session ที่กำลัง RUNNING

กรณีใช้จริงที่คุ้มที่สุด 3 แบบ:

1. **คิวรีรันค้าง > 30 วินาที** — เปิด Live plan แล้วดูว่า operator ไหนยังไม่ส่งแถว (มักคือ Sort/Hash กำลัง spill หรือ scan ใหญ่) ต่างจาก `sys.dm_exec_requests` ที่บอกแค่ wait type รวม
2. **แปลง estimated → actual แบบไม่ต้องรอจบ** — คิวรีที่ใช้ชั่วโมง: ตัวเลข `row_count` ณ วินาทีที่ 30 บอกทันทีว่า estimate ของ optimizer ต่างจากจริงแค่ไหน โดยไม่ต้องรอรันจบถึงจะได้ actual plan
3. **ตรวจ "คิวรีใครกินทรัพยากร" ใน Activity Monitor** — คลิกขวา session ที่รันอยู่ → Show Live Execution Plan ได้ทันทีโดยไม่แตะ query ของ session นั้น (อ่านอย่างเดียว)

---

## สรุป Section 7.2

1. Estimated กับ Actual คือ **plan ใบเดียวกัน** — ต่างกันที่ตัวเลข runtime ที่ติดกลับมา ช่องว่าง Estimated/Actual Rows คือ CE error ไม่ใช่ "plan เปลี่ยน"
2. เลือกฉบับให้ถูกคำถาม: ก่อนรัน = Ctrl+L/SHOWPLAN_XML, หลังรัน = Ctrl+M/STATISTICS_XML, รันซ้ำเป็นระบบ = Query Store (`plan_type_desc`, `query_plan`), ตอนนี้ = Live Query Stats ผ่าน `sys.dm_exec_query_profiles`
3. XML คือตัวจริงของกราฟิก และมี property ที่กราฟิกซ่อน (`StatementParameterizationType`, `MemoryGrant`, `CompileTime`) — อ่านผ่าน XQuery ด้วย path เต็มจากรากพร้อม `WITH XMLNAMESPACES`
4. SQL Server ไม่มี plan แบบ JSON — JSON ใช้เป็นรูปแบบส่งออกเท่านั้น (`FOR JSON` จาก property ที่ถอดออกมา)
5. `LAST_QUERY_PLAN_STATS` ยัง OFF บน VM ใช้ร่วม — ทางที่ไม่ต้องตั้งค่าคือ Query Store

### ตรวจความเข้าใจ

1. คิวรี A มี `StatementEstRows = 500` แต่ Actual Rows = 120,000 — นี่ "plan เปลี่ยนไป" หรือไม่? อาการนี้เรียกว่าอะไร และบอกใบ้ปัญหาชั้นไหน?
2. ต้องการรู้ว่าคิวรีที่แพงมาก "จะ scan ทั้งตารางไหม" โดยไม่อยากรันจริง — ใช้วิธีใดและ SET option ใด?
3. ทำไมจึงบอกว่า "กราฟิกและ XML คือ plan เดียวกัน" — แล้วข้อมูลอะไรบ้างที่ได้เฉพาะใน XML?
4. `sys.dm_exec_query_plan_stats` ใช้ไม่ได้บน VM นี้ — เพราะอะไร และทางเลือกที่ให้ข้อมูลใกล้เคียงกันโดยไม่ต้องแก้ config คืออะไร?
5. คิวรี diagnostic ที่ดึง plan จาก `sys.query_store_plan` ด้วย XQuery ควรใช้ path แบบใด `/ShowPlanXML/.../StmtSimple/@X` หรือพึ่ง `//` สั้น ๆ — เพราะอะไร (ย้อนบทเรียน Labs Exercise 1)?

**➡ ถัดไป:** [Section 7.3 — Analyzing Query Plans](../03_Analyzing_Query_Plans/README.md)

---

[⬅ Module 07](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [03 Analyzing Query Plans](../03_Analyzing_Query_Plans/README.md)
