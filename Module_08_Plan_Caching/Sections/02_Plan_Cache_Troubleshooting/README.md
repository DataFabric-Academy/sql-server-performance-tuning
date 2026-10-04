[⬅ Module 08](../../README.md) | [8.1 Plan Cache Internals](../01_Plan_Cache_Internals/README.md) | Section 2/3 | ➡ ถัดไป: [03 Query Store & Automatic Tuning](../03_Query_Store_Automatic_Tuning/README.md)

# 8.2 Plan Cache Troubleshooting — วินิจฉัยและแก้ปัญหาจาก Plan Cache

> *"Plan Cache บอกอะไรคุณทุกวัน ถ้ารู้ว่าต้องดูคอลัมน์ไหน — ปัญหา CPU สูง, memory บวม, query บางครั้งเร็วบางครั้งช้า ส่วนใหญ่อยู่ในนี้ทั้งหมด"*

> **ต้องรู้มาก่อน:** กลไก compile/reuse, cache stores, parameter sniffing เชิงกลไก ([8.1](../01_Plan_Cache_Internals/README.md)) · การอ่าน DMV และ performance counters แบบ delta (Module 1.4, 10)
> ศัพท์ที่ใช้ใน section นี้: [Glossary](../../../Glossary.md) — Plan Cache, Parameter Sniffing, DMV/DMF

---

## แผนที่การวินิจฉัยของ Section นี้

| อาการที่เห็นหน้างาน | สิ่งที่ต้องวัด | หัวข้อ |
|:---|:---|:---:|
| CPU สูงแต่ query ไหนก็ไม่ "หนัก" | `SQL Compilations/sec` + plan cache ราย objtype | 2 |
| Plan cache กิน memory มหาศาล / `CACHESTORE_SQLCP` บวม | สัดส่วน single-use plans | 3 |
| Compile ต่อเนื่อง / plan หลุดตลอด | `SQL Re-Compilations/sec` + ตาเหตุ invalidation | 5 |
| Query "บางครั้งเร็วบางครั้งช้า" โดยไม่มีใครแก้โค้ด | Parameter Sniffing + ตัวเลือกการแก้ 4 แบบ | 6 |
| ล้าง cache ต้องกล้า / กลัวกระทบคนอื่น | การล้างเฉพาะตัว (plan_handle) | 8 |

---

## 1. กติกาการวัดค่า Plan Cache ก่อนตัดสินใจ

ค่าทุกตัวใน DMV นี้เป็น "ค่าสะสมตั้งแต่ restart" — เหมือน `dm_os_wait_stats` ใน Module 1.4 วิธีอ่านให้ถูกคือ **delta ระหว่างจุดเวลา** และเทียบกับ baseline (Module 10) ค่าที่ต้องเก็บเป็นนิสัย:

| Metric | แหล่ง | แปลความเมื่อผิดปกติ |
|:---|:---|:---|
| Plan cache ราย objtype (จำนวน/ขนาด/reuse) | `sys.dm_exec_cached_plans` | `Adhoc` โตโดย avg_usecounts ~1 = pollution |
| Cache store ราย store | `sys.dm_os_memory_cache_counters` | `SQL Plans` > `Object Plans` มากผิดปกติ |
| `SQL Compilations/sec` | `sys.dm_os_performance_counters` | สูงต่อเนื่อง = ไม่มี reuse (ad-hoc/SET options กระจัด) |
| `SQL Re-Compilations/sec` | `sys.dm_os_performance_counters` | สูง = plan ถูก invalidate หรือ RECOMPILE ใช้หนัก |
| Single-use plan ratio | `sys.dm_exec_cached_plans` | > 60–70% ของ Adhoc = เข้าข่าย pollution |

---

## 2. วัดครั้งแรก: cache ทั้งหมดเป็นยังไง — และ compile กำลังร้อนอยู่ไหม

**สอง query นี้คือ "หน้าแรก" ของการวินิจฉัย** (สคริปต์เดียวกับ `Sections/01_Plan_Cache_Internals/Scripts/02_Plan_Cache_Size.sql` ในโมดูลนี้):

```sql
USE AdventureWorks;
GO
-- สรุป Plan Cache ราย objtype: จำนวน, ขนาด, และสัดส่วน single-use
SELECT objtype AS cache_type,
       COUNT_BIG(*) AS total_plans,
       SUM(CAST(size_in_bytes AS DECIMAL(18, 2))) / 1048576.0 AS total_mb,
       AVG(CAST(usecounts AS FLOAT)) AS avg_usecounts,
       SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS single_use_plans,
       CAST(SUM(CASE WHEN usecounts = 1 THEN size_in_bytes ELSE 0 END) / 1048576.0 AS DECIMAL(12, 2)) AS single_use_mb
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY total_mb DESC;
```

**Expected:** แถว `Adhoc` มักได้คะแนนแย่ที่สุด — จำนวน plan เยอะสุด, avg_usecounts ใกล้ 1, single_use_mb กินขนาดรวมเกือบหมด; แถว `Proc`/`Prepared` reuse สูงกว่าชัดเจน
> อ้างอิงรันจริง (17.0.1135.8, VM ทดสอบ): `Adhoc 431 plans / 65.4 MB / avg_usecounts 1.68 / single-use 400 plans = 62.2 MB` (95% ของ Adhoc คือขยะ) เทียบกับ `View 242 plans / avg_usecounts 8.5`, `Proc 4 plans / avg_usecounts 36`

```sql
USE AdventureWorks;
GO
-- ตัวชี้วัด compilation: อ่าน 2 จุดห่าง 5 วินาที (counter เป็นค่าสะสม ต้องหา delta)
DECLARE @snap1 TABLE (counter_name sysname, cntr_value BIGINT);
INSERT INTO @snap1
SELECT counter_name, cntr_value
FROM sys.dm_os_performance_counters
WHERE counter_name IN ('SQL Compilations/sec', 'SQL Re-Compilations/sec')
  AND instance_name = '';
WAITFOR DELAY '00:00:05';
SELECT s.counter_name,
       (c.cntr_value - s.cntr_value) / 5.0 AS per_second
FROM @snap1 AS s
JOIN sys.dm_os_performance_counters AS c
    ON c.counter_name = s.counter_name AND c.instance_name = '';
```

**Expected:** สองแถวพร้อมค่าต่อวินาที — บนระบบที่ใช้ cache ดี, `SQL Compilations/sec` จะต่ำเมื่อไม่มี deploy/กระตุ้นใหม่ (เช่น < 10–50 บนระบบ idle); ถ้าสูงต่อเนื่องร่วมกับแถว `Adhoc` ที่ avg_usecounts ~1 จาก query แรก = โจทย์ชัดคือ pollution
> อ้างอิงรันจริง (17.0.1135.8, VM ช่วง idle): Compilations 0.2/วิ, Re-Compilations 0.2/วิ — ระบบจริงที่มีปัญหาจะเห็นหลักร้อย

> [!IMPORTANT]
> **ต่างกันยังไง:** *Compilations* = สร้าง plan ใหม่ครั้งแรก (cache miss); *Re-Compilations* = สร้างใหม่ **ทั้งที่เคยมี** (plan ถูก invalidate หรือสั่ง RECOMPILE) — ตัวที่สองเป็นสัญญาณของหัวข้อ 5, ตัวแรกเป็นสัญญาณของหัวข้อ 3

---

## 3. Ad-hoc Plan Pollution — โรคที่พบบ่อยที่สุด

### 3.1 อาการ

App ส่ง SQL ด้วย literal (string concatenation) ทุกครั้ง → ทุกค่าใหม่ = batch ใหม่ = shell plan ใหม่ (usecounts=1) กองอยู่ใน `CACHESTORE_SQLCP` — อย่าลืมจาก 8.1 ว่าแม้ simple parameterization จะช่วยสร้าง Prepared plan ร่วม แต่ **shell plan ยังถูกทิ้งไว้ทุกค่า**

### 3.2 หาตัวผู้ก่อเหตุ

```sql
USE AdventureWorks;
GO
-- ตัวอย่าง single-use ad-hoc plan ที่กินพื้นที่มากสุด
SELECT TOP (10)
       LEFT(st.text, 55) AS sample_text,
       cp.objtype,
       cp.size_in_bytes / 1024 AS size_kb
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS st
WHERE cp.objtype = 'Adhoc'
  AND cp.usecounts = 1
  AND st.text NOT LIKE '%dm_exec_cached_plans%'
ORDER BY cp.size_in_bytes DESC;
```

**Expected:** รายการ text ของ plan ที่รันครั้งเดียวแล้วทิ้ง — จะรู้ทันทีว่ามาจาก app ใด/monitoring ตัวไหน บน VM ทดสอบผู้ก่อเหตุเป็น query ระบบ/เครื่องมือตรวจเอง (จะเห็น query ของเราในบรรดาผู้ต้องสงสัยด้วย — อย่างน้อยมันสอนว่า "อ่าน query ที่หา ก็ควรกรองตัวเองออก")
> อ้างอิงรันจริง (17.0.1135.8): top ตัว ~1.6 MB ต่อ plan เป็น query ตรวจระบบ (`SELECT ... FROM sys.all_columns ...`, `x.value('(@timestamp)[1]',...)`) — แสดงว่าแม้เครื่องมือวินิจฉัยเองก็มีส่วนทิ้ง single-use plan

### 3.3 ทางแก้ที่ระดับ server: Optimize for Ad-hoc Workloads

กลไก: ครั้งแรกที่ ad-hoc batch ถูก compile **เก็บเพียง "Compiled Plan Stub" (~8 KB)** แทน plan เต็ม — ถ้ามีการรันซ้ำ ครั้งที่สองจึง compile เต็มและเก็บ plan จริง — ผลคือ plan ที่ "รันครั้งเดียว" แทบไม่กิน memory

```sql
-- ดูค่าปัจจุบัน (read-only — ปลอดภัยทุก environment)
SELECT name, value, value_in_use
FROM sys.configurations
WHERE name = 'optimize for ad hoc workloads';
```

**Expected:** ค่าเริ่มต้นคือ `0` (ปิด) — บน VM ทดสอบได้ 0/0
> อ้างอิงรันจริง (17.0.1135.8): `optimize for ad hoc workloads | 0 | 0`

การเปิดใช้เป็น **server configuration ที่กระทบทั้ง instance** — บน VM ใช้ร่วมของหลักสูตรจึงเป็น **คำสั่งสาธิตเท่านั้น (ไม่รันบน server แบ่งใช้)**:

```text
-- รูปแบบคำสั่ง (อย่ารันบน server ที่ใช้ร่วม — ปรับค่าทั้ง instance):
EXEC sys.sp_configure 'show advanced options', 1;  RECONFIGURE;
EXEC sys.sp_configure 'optimize for ad hoc workloads', 1;  RECONFIGURE;
```

> [!NOTE]
> เปิดแล้วต้อง "ผ่านช่วงเวลา" ถึงจะเห็นผล: plan เก่าที่อยู่ใน cache จะถูก evict ตามธรรมชาติ ค่อย ๆ เปลี่ยนเป็น stub — ทางที่เร็วกว่าคือเคลียร์ cache (หัวข้อ 8) แต่ต้องรับ compilation storm ชั่วคราว

### 3.4 ทางแก้ที่ราก: แก้ฝั่ง app

- ส่ง `sp_executesql` / parameterized queries จาก ORM (แต่ระวัง ORM อย่าง EF ที่ฝังค่าเป็น literal โดย default — เปิด parameterization ใน config ของ ORM)
- ลดรูปแบบ query: `WHERE OrderDate IN ('2024-01-01','2024-01-02')` ที่มี literal ไม่จำกัดจำนวน = plan ไม่จำกัดจำนวนเช่นกัน

---

## 4. Forced Parameterization — เครื่องมือหนักระดับฐานข้อมูล

เมื่อแก้ app ไม่ได้ อีกทางคือบังคับให้ engine "หลุด" literal เป็นพารามิเตอร์กว้างขึ้นมาก:

```text
-- รูปแบบคำสั่ง (ระดับฐานข้อมูล — สาธิตเท่านั้น):
ALTER DATABASE [MyDB] SET PARAMETERIZATION FORCED;
-- กลับคืน:
ALTER DATABASE [MyDB] SET PARAMETERIZATION SIMPLE;
```

| | Simple (ค่าเริ่มต้น) | Forced |
|:---|:---|:---|
| สิ่งที่ parameterize | เฉพาะ "ปลอดภัย" (key lookup ฯลฯ) | กว้างมาก — แม้ literal ที่กระทบ plan |
| ข้อดี | — | ลด compile และ plan bloat จัด |
| ข้อเสีย | — | **Parameter Sniffing รุนแรงขึ้น** — ค่าที่ต่างกันอาจควรได้ plan ต่างกัน (เช่น `TOP (5)` vs `TOP (5000)`, date range สั้น/ยาว) แต่ถูกบังคับใช้ plan เดียว |
| เหมาะกับ | ส่วนใหญ่ | OLTP ที่ query จาก app ส่ง literal มากมายและรูปแบบ plan ไม่ sensitive ต่อค่า |

> [!WARNING]
> Forced Parameterization แก้ "cache บวม" แต่ส่งต่อปัญหาไปที่ "sniffing" — คู่แก้ของมันคือหัวข้อ 6 (OPTIMIZE FOR / RECOMPILE) และ Query Store (Section 3) ที่ช่วยจัดการ plan ให้ต่อค่าที่จำเป็น

---

## 5. Recompilation — เมื่อ plan "แก่" หรือ "ถูกเทียบชวนใหม่"

จาก 8.1 หัวข้อ 9: plan หลุดเมื่อ schema/stats เปลี่ยน (invalidation) — คราวนี้วัดให้เห็นจริง พร้อมข้อสังเกตที่หลายคนไม่เคยจับ:

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.PC2_T;
CREATE TABLE dbo.PC2_T (ID INT PRIMARY KEY, Val INT);
INSERT INTO dbo.PC2_T VALUES (1, 10), (2, 20);
GO
CREATE OR ALTER PROC dbo.PC2_RecompileDemo
AS
BEGIN
    SELECT COUNT_BIG(*) AS cnt FROM dbo.PC2_T;
END;
GO
EXEC dbo.PC2_RecompileDemo;
GO
-- creation_time ของ statement ใน proc (ก่อน)
SELECT qs.creation_time FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE st.objectid = OBJECT_ID('dbo.PC2_RecompileDemo');
GO
DECLARE @before BIGINT;
SELECT @before = cntr_value FROM sys.dm_os_performance_counters
WHERE counter_name = 'SQL Re-Compilations/sec' AND instance_name = '';
ALTER TABLE dbo.PC2_T ADD ColNew INT NULL;
EXEC dbo.PC2_RecompileDemo;
DECLARE @after BIGINT;
SELECT @after = cntr_value FROM sys.dm_os_performance_counters
WHERE counter_name = 'SQL Re-Compilations/sec' AND instance_name = '';
SELECT @after - @before AS recompiles_during_exec;
GO
-- creation_time ของ statement (หลัง)
SELECT qs.creation_time FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE st.objectid = OBJECT_ID('dbo.PC2_RecompileDemo');
GO
DROP PROC dbo.PC2_RecompileDemo;
DROP TABLE IF EXISTS dbo.PC2_T;
GO
```

**Expected:** `recompiles_during_exec = 1` (counter ขยับตามจริง) และ `creation_time` ของ statement เปลี่ยนเป็นเวลาหลัง ALTER — **แต่ถ้าดู `sys.dm_exec_procedure_stats.cached_time` จะยังเป็นค่าเดิม** เพราะ recompile นี้เกิด "ระดับ statement" ภายใน proc plan เดิม — สองเครื่องมือเล่าเรื่องคนละระดับ ต้องใช้คู่กัน
> อ้างอิงรันจริง (17.0.1135.8): counter +1 · creation_time 05:22:01.443 → 05:22:01.567 · cached_time คงเดิม

**สาเหตุ recompile ที่ต้องจำ (เรียงตามความพบในหน้างาน):**

| กลุ่ม | สาเหตุ | ข้อสังเกต |
|:---|:---|:---|
| Schema | `ALTER TABLE/VIEW/PROC/INDEX` ที่ plan อ้าง | ตั้งใจ/ไม่ตั้งใจ — deployment กลางวันเป็นฝูง recompile |
| Statistics | `UPDATE STATISTICS` / auto-update | ดี (ข้อมูลเปลี่ยน) — แต่ stats ที่อัปเดต "บ่อยเกินเหตุ" ก็ compile แพง |
| SET options | session ใหม่ตั้งไม่ตรง plan | สร้าง plan ใหม่ ไม่ใช่ recompile ของ plan เดิม (8.1 หัวข้อ 8) |
| Temp table | `CREATE TABLE #t` ใน proc + statement ถัด ๆ ไป | recompile เมื่อ temp table ถูกแก้/สร้างใหม่ — ยอมรับได้ถ้าข้างแลกคุ้ม |
| Hint | `OPTION (RECOMPILE)` / `WITH RECOMPILE` / `sp_recompile` | ตั้งใจ — หัวข้อ 6 |
| Threshold | `sp_recompile`, ค่า `TRIGGER_RECOMPILE` ฯลฯ ใน XE `sql_statement_recompile` | หา reason ด้วย event `sql_statement_recompile` (Module 9) |

> [!TIP]
> **เกณฑ์ตัดสิน:** Re-Compilations/sec ต่อเนื่อง > 10% ของ Batch Requests/sec บน baseline จริง = ต้องตามหาเหตุ — ใช้ XEvent `sql_statement_recompile` (reason column) เจาะทีละ statement แทนการเดา

---

## 6. Parameter Sniffing — กล่องเครื่องมือ 4 ทางเลือก

จาก 8.1 หัวข้อ 6 เรารู้กลไกแล้ว — คราวนี้เทียบ "ยา" ทั้ง 4 ตัวบนข้อมูลเบ้ชุดเดียวกัน (TH = 1 แถว, US = 10,000 แถว):

```sql
USE AdventureWorks;
GO
DROP TABLE IF EXISTS dbo.PC2_Sniff;
CREATE TABLE dbo.PC2_Sniff (
    ID INT IDENTITY PRIMARY KEY,
    CountryCode CHAR(2) NOT NULL,
    Payload CHAR(50) NOT NULL DEFAULT 'x'
);
INSERT INTO dbo.PC2_Sniff (CountryCode) VALUES ('TH');
INSERT INTO dbo.PC2_Sniff (CountryCode)
SELECT TOP (10000) 'US' FROM sys.all_objects AS a CROSS JOIN sys.all_objects AS b;
CREATE INDEX IX_PC2_Sniff_Country ON dbo.PC2_Sniff (CountryCode);
GO
CREATE OR ALTER PROC dbo.PC2_Sniff_Default @CountryCode CHAR(2)
AS SELECT * FROM dbo.PC2_Sniff WHERE CountryCode = @CountryCode;
GO
CREATE OR ALTER PROC dbo.PC2_Sniff_Unknown @CountryCode CHAR(2)
AS SELECT * FROM dbo.PC2_Sniff WHERE CountryCode = @CountryCode
   OPTION (OPTIMIZE FOR UNKNOWN);
GO
CREATE OR ALTER PROC dbo.PC2_Sniff_Value @CountryCode CHAR(2)
AS SELECT * FROM dbo.PC2_Sniff WHERE CountryCode = @CountryCode
   OPTION (OPTIMIZE FOR (@CountryCode = 'US'));
GO
CREATE OR ALTER PROC dbo.PC2_Sniff_Recomp @CountryCode CHAR(2)
AS SELECT * FROM dbo.PC2_Sniff WHERE CountryCode = @CountryCode
   OPTION (RECOMPILE);
GO
-- compile ทุก proc ด้วยค่า "เบา" ('TH') แล้วรันตามด้วยค่า "หนัก" ('US')
SET STATISTICS IO ON;
EXEC dbo.PC2_Sniff_Default 'TH';    -- compile: est 1 แถว -> Seek
EXEC dbo.PC2_Sniff_Default 'US';    -- reuse plan เดิม -> 10,001 lookups!
EXEC dbo.PC2_Sniff_Unknown 'TH';    -- compile ไม่สนค่า (density) -> Scan
EXEC dbo.PC2_Sniff_Unknown 'US';    -- reuse plan เดิม -> Scan (คงที่ทั้งคู่)
EXEC dbo.PC2_Sniff_Value 'TH';      -- compile สมมุติค่า US ที่แย่สุด -> Scan
EXEC dbo.PC2_Sniff_Value 'US';      -- reuse -> Scan
EXEC dbo.PC2_Sniff_Recomp 'TH';     -- compile สดรู้จริง -> Seek
EXEC dbo.PC2_Sniff_Recomp 'US';     -- compile สดรู้จริง -> Scan (ถูกทุกครั้ง เปลือง compile)
SET STATISTICS IO OFF;
GO
DROP PROC dbo.PC2_Sniff_Default, dbo.PC2_Sniff_Unknown, dbo.PC2_Sniff_Value, dbo.PC2_Sniff_Recomp;
DROP TABLE IF EXISTS dbo.PC2_Sniff;
GO
```

**Expected (logical reads ต่อการรัน):**

| Proc | รัน 'TH' | รัน 'US' | การตีความ |
|:---|---:|---:|:---|
| Default | 4 | **20,017** | sniffing victim — plan จากค่าแรกถูกใช้กับค่าหนัก |
| OPTIMIZE FOR UNKNOWN | 101 | 101 | สม่ำเสมอ — แลกค่าเบา (เกินจำเป็น ~25 เท่า) |
| OPTIMIZE FOR 'US' | 101 | 101 | เลือกสมมุติตามค่าที่กำหนด — ใช้เมื่อรู้ว่าค่าหนักคือ "คนส่วนใหญ่" |
| OPTION (RECOMPILE) | 4 | 101 | **ถูกต้องทั้งคู่** — แลกด้วย compile ทุกครั้ง |
> อ้างอิงรันจริง (17.0.1135.8): 4/20017 · 101/101 · 101/101 · 4/101 — ตรงตารางทุกช่อง

**เลือกใช้อย่างไร:**

| สถานการณ์ | ทางเลือกที่เหมาะ |
|:---|:---|
| ค่าที่ส่งมา "เบามาก" เป็นครั้งคราว ส่วนใหญ่ค่าหนัก | `OPTIMIZE FOR (@p = 'ค่าหนัก')` หรือ UNKNOWN |
| ค่ากระจายหลากหลายมาก ไม่มีตัวแทนที่แทนทุกคนได้ | `OPTION (RECOMPILE)` (ถ้า frequency ต่ำ) |
| Query รันถี่มาก (วินาทีละครั้ง) | **อย่า** RECOMPILE — แก้ที่ design (index ที่เหมาะทั้งคู่, แยก proc ตาม pattern) |
| แก้โค้ดไม่ได้เลย | Query Store Plan Forcing / QS Hints (Section 3) |

> **anti-pattern ที่ยังเจอในโค้ดเก่า:** ก๊อปค่าพารามิเตอร์ลง local variable ก่อนใช้ (`DECLARE @cc = @CountryCode; ... WHERE CountryCode = @cc`) — ยุคเก่าใช้กันเพราะ optimizer ประมาณด้วย density (เหมือน OPTIMIZE FOR UNKNOWN) แต่บังคับเงา ๆ ไม่ชัด ใช้ hint ที่มีชื่อเรียกชัดดีกว่า

---

## 7. Parameter Embedding — ทางออกพิเศษของ `OPTION (RECOMPILE)`

`OPTION (RECOMPILE)` มีความสามารถที่ไม่ใช่แค่ "compile ใหม่": ตอน compile มัน **ฝังค่า literal จริงลงใน plan** (parameter embedding) แล้ว optimize ต่อค่าแบบสุดความสามารถ — เช่น `WHERE DateCol >= @from AND DateCol <= @to` เมื่อรันด้วยช่วงว่าง อาจถูกตัดออกทั้ง predicate (constant folding) และข้ามการอ่านตารางได้เลย

ค่าใช้จ่าย: plan ที่ฝัง literal **ใช้ซ้ำไม่ได้** — จึงหมายเหตุไว้ใน plan ว่า `StatementNotForReuse` — เหมาะกับ query ที่ "ค่าเปลี่ยนและสำคัญ" แต่รันไม่บ่อยมาก

**ขั้วตรงข้ามที่ต้องระวัง — dynamic SQL แบบต่อ string:**

```sql
USE AdventureWorks;
GO
-- anti-pattern: ทุกค่า = batch text ใหม่ = plan ใหม่ทั้งที่ไม่จำเป็น
EXEC (N'SELECT * FROM Sales.SalesOrderHeader WHERE SalesOrderID = 43669;');

-- ที่ถูก: พารามิเตอร์แยกออกจากโครง SQL
EXEC sp_executesql
     N'SELECT * FROM Sales.SalesOrderHeader WHERE SalesOrderID = @so;',
     N'@so int', @so = 43669;
GO
```

> แบบ anti-pattern ให้ shell plan ต่อค่า (8.1 หัวข้อ 5 ได้พิสูจน์ pattern นี้แล้ว) — และยังเสี่ยง **SQL Injection** อีกชั้น

---

## 8. ล้าง Cache แบบ "ศัลยแพทย์" — ลบเฉพาะตัวที่ต้องการ

สมมุติสถานการณ์: plan ของ proc หนึ่งตัว "แปลก ๆ" (compile ด้วยค่าเบ้ ณ ตอน deploy) คุณต้องการรีเซ็ตเฉพาะมัน โดยไม่กระทบ workload ทั้ง instance:

```sql
USE AdventureWorks;
GO
CREATE OR ALTER PROC dbo.PC2_FreeTarget
AS SELECT COUNT_BIG(*) AS cnt FROM Person.Person;
GO
EXEC dbo.PC2_FreeTarget;
GO
-- เก็บ plan_handle ของ "proc นี้เท่านั้น" แล้วลบเฉพาะตัว (ไม่กระทบ workload อื่น)
DECLARE @plan_handle VARBINARY(64);
SELECT @plan_handle = cp.plan_handle
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS st
WHERE st.objectid = OBJECT_ID('dbo.PC2_FreeTarget')
  AND cp.objtype = 'Proc';
DBCC FREEPROCCACHE (@plan_handle);
GO
-- ยืนยัน: plan ของ proc นี้หายจาก cache (แถวว่าง) — ของอื่นไม่ถูกกระทบ
SELECT cp.objtype, cp.cacheobjtype
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS st
WHERE st.objectid = OBJECT_ID('dbo.PC2_FreeTarget')
  AND cp.objtype = 'Proc';
GO
DROP PROC dbo.PC2_FreeTarget;
GO
```

**Expected:** หลัง `DBCC FREEPROCCACHE(@plan_handle)` query ยืนยันได้ 0 แถว — ตัวอื่นใน cache ไม่ถูกแตะ; ครั้งถัดไปที่เรียก proc จะ compile ใหม่เฉพาะมัน
> อ้างอิงรันจริง (17.0.1135.8): DBCC ผ่าน, verify ได้ 0 แถว

```text
-- ทางเลือกอื่น ๆ (รูปแบบคำสั่ง — คิดก่อนรันเสมอ):
DBCC FREEPROCCACHE;                                    -- ล้างทั้ง instance (สุดท้ายที่ควรใช้)
DBCC FREEPROCCACHE (0x060005...);                      -- เฉพาะ plan_handle (ที่สาธิตข้างบน)
DBCC FREEPROCCACHE ('SQL Plans');                      -- เฉพาะ cache store ของ ad-hoc/prepared
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;  -- เฉพาะฐานข้อมูลนี้
```

> [!WARNING]
> การล้าง cache ชุดใหญ่ (ทั้ง instance/store/DB) ทำให้ query ทุกตัวที่โดน compile ใหม่พร้อมกัน — บนระบบ busy อาจ CPU spike จน server ชั่วคราวตอบสนองช้า — เตรียมหน้าต่างเวลาและแจ้งทีมก่อน

---

## 9. ใหม่ใน SQL Server 2025: Optimized `sp_executesql` — กัน Compilation Storm ตั้งแต่ประตู

**ปัญหาที่มันแก้:** หลัง failover / ล้าง cache / deploy ใหญ่ — workload ที่ส่ง `sp_executesql` จำนวนมากจะ compile "พร้อมกันทั้งยวง" (compilation storm) เพราะคอมไพล์ batch ที่ส่งมาแบบ `sp_executesql` ทำงานแข่งกันขนาน

**กลไก:** เปิดแล้ว compilation ของ batch จาก `sp_executesql` ถูก **serialize** เหมือน stored procedure — ลดการแย่ง CPU ตอน cache ว่างเปล่า (ต้นทุน: บางกรณี latency แรกของแต่ละ query ยาวขึ้นนิดหน่อยเพราะต้องคิว)

```sql
-- อ่านสถานะปัจจุบัน (read-only)
SELECT name, value, value_for_secondary
FROM sys.database_scoped_configurations
WHERE name = 'OPTIMIZED_SP_EXECUTESQL';
```

**Expected:** `value = 0` (ปิด — ค่าเริ่มต้น) — การเปิดทำผ่าน database scoped configuration (ไม่ต้องแตะ server config)
> อ้างอิงรันจริง (17.0.1135.8): `OPTIMIZED_SP_EXECUTESQL | 0 | NULL`

```text
-- รูปแบบคำสั่งเปิดใช้ (ระดับฐานข้อมูล — ประเมินผลกับ workload ก่อนเปิดจริง):
ALTER DATABASE SCOPED CONFIGURATION SET OPTIMIZED_SP_EXECUTESQL = ON;
```

**ความสัมพันธ์กับหัวข้ออื่น:** มันไม่ได้แก้ pollution (หัวข้อ 3) แต่แก้ "จังหวะ compile ซ้ำที่มาพร้อมกัน" — ทั้งสองเรื่องต่างกันและเปิดใช้ร่วมกันได้

---

## 10. เช็กลิสต์จบ Section นี้ (เก็บไว้ใช้หน้างาน)

1. จับ `SQL Compilations/sec` + `Re-Compilations/sec` แบบ delta — เทียบ baseline
2. สรุป cache ราย objtype — ดู `Adhoc` single-use ratio ก่อนเป็นอันดับแรก
3. เจอ pollution → แก้ app เป็นหลัก / `optimize for ad hoc workloads` เป็นรอง
4. จะใช้ Forced Parameterization → ต้องรับ sniffing แล้ววางมือแก้ (หัวข้อ 6 / Section 3)
5. Sniffing → เลือกยา 4 ตัวตามสถานการณ์ อย่าหยิบ `RECOMPILE` กับ query วิ่งถี่โดยไม่คิด
6. ต้องรีเซ็ต plan → ลบเฉพาะ `plan_handle` / เฉพาะ store / เฉพาะ DB — อย่าล้างทั้ง instance
7. 2025 → พิจารณา `OPTIMIZED_SP_EXECUTESQL` กับ workload ที่ compile พร้อมกันมาก

---

## สรุป Section 2

1. วินิจฉัย plan cache ต้องวัด 4 ชุด: objtype summary, single-use ratio, Compilations/Re-Compilations แบบ delta, และ cache store sizes
2. **Ad-hoc pollution** มาจาก app ส่ง literal — ทางแก้ที่รากคือ parameterization ฝั่ง app; `optimize for ad hoc workloads` เป็นขั้นกลางที่แปลง plan รันครั้งเดียวเป็น stub
3. **Forced Parameterization** ลด compile แต่ส่งปัญหาไปที่ sniffing — อย่าเปิดลอย ๆ โดยไม่มีแผนจัดการ plan
4. **Recompilation** วัดได้ทั้งระดับ counter (ทั้ง server) และ `creation_time` (ระดับ statement) — schema/stats/SET options/temp tables/hints คือเหตุหลัก
5. กล่องยา sniffing มี 4 ตัว — Default/UNKNOWN/VALUE/RECOMPILE — แต่ละตัวมีราคาของตัวเอง (ทดสอบแล้ว: 4→20017 / 101→101 / 101→101 / 4→101)
6. `DBCC FREEPROCCACHE` ต้องใช้แบบเฉพาะตัว; 2025 มี `OPTIMIZED_SP_EXECUTESQL` กัน compilation storm ตั้งแต่ต้นทาง

### ตรวจความเข้าใจ

1. จากผลรันจริง: `Adhoc 431 plans, single-use 400` — คำนวณ single-use ratio และบอกว่าเกณฑ์ตัดสิน "ผิดปกติ" ของคุณอยู่ตรงไหน?
2. `SQL Compilations/sec` สูงแต่ `SQL Re-Compilations/sec` ต่ำ — ปัญหาอยู่ที่ "ไม่เคย cache" หรือ "cache แล้วหาย"? และข้อไหนที่ pollution เข้าข่าย?
3. เพราะอะไร `OPTIMIZE FOR UNKNOWN` จึงให้ 101 logical reads ทั้งสองค่า — มันประมาณจากอะไร และกรณีข้อมูลไม่เบ้มาก การใช้ตัวนี้คุ้มหรือเปลือง?
4. `OPTION (RECOMPILE)` ให้ผลดีที่สุด (4/101) แต่ทำไมไม่ใช่คำตอบเริ่มต้นของทุก proc บนระบบ OLTP?
5. เจอ proc ที่ `cached_time` ไม่เปลี่ยนแต่ statement ภายในถูก compile ใหม่ — เกิดจากอะไร และควรใช้ DMV ไหนอีกตัวยืนยัน?
6. หัวหน้าสั่ง `DBCC FREEPROCCACHE` ทั้ง instance บน production ตอน 10:00 น. — จะโต้แย้งด้วยข้อไหน และเสนอทางเลือกใด?

---

[⬅ Module 08](../../README.md) | [🧪 Labs](../../Labs/README.md) | ➡ [03 Query Store & Automatic Tuning](../03_Query_Store_Automatic_Tuning/README.md)
