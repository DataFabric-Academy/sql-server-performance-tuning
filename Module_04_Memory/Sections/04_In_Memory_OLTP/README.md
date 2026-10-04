[⬅ Module 04](../../README.md) | Section 4/4 | ➡ กลับ: [Module 04 README](../../README.md)

# 4.4 In-Memory OLTP (Hekaton) — เมื่อข้อมูลอาศัยอยู่ใน RAM ทั้งก้อน

> *"Buffer pool พยายามพาข้อมูลไปใกล้ CPU ให้มากที่สุด — Hekaton ตัดเงื่อนไขนั้นทิ้ง: ข้อมูลต้องอยู่ใน memory ตลอดเวลา แลกกับกฎเหล็กหลายข้อ"*

> **ต้องรู้มาก่อน**: [Section 4.2 — SQL Server Memory](../02_SQL_Server_Memory/README.md) (clerks, buffer pool) และ [Section 4.3](../03_Memory_Pressure_Diagnostics/README.md) (การอ่าน memory ต่อ clerk) — พอเข้าใจ `MEMORYCLERK_*` แล้วจะต่อเรื่องนี้ได้ทันที
> ศัพท์ใหม่ดู [Glossary](../../../Glossary.md) — Buffer Pool, Memory Clerk

## ทำไม Section นี้จึงอยู่ในหลักสูตร Memory

สี่ section ก่อนหน้าพูดถึง memory ในบทบาท **cache** — เก็บของที่อยู่บนดิสก์ให้เร็วขึ้น In-Memory OLTP (ชื่อเล่น **Hekaton** — ภาษากรีกแปลว่า "ร้อย" ตามเป้าหมายเร่งเร็วร้อยเท่า) เปลี่ยนสมมติฐาน: **ตารางทั้งตารางถูกกำหนดให้อาศัยอยู่ใน memory ตลอดเวลา** — memory ไม่ใช่ cache อีกต่อไป แต่คือที่เก็บหลัก ดังนั้นการจัดการ memory ที่เรียนมาทั้งหมด (clerks, pressure, grants) ยังใช้อ่านระบบเหล่านี้ได้โดยตรง

Section นี้ตอบ 4 คำถาม: สถาปัตยกรรมข้างในเร็วเพราะอะไร · เริ่มใช้ต้องมีอะไรก่อน (และ error ที่เจอแน่) · จัดการ memory ของมันอย่างไร · และในปี 2025 ยังควรใช้หรือไม่

**เกี่ยวกับเดโมใน section นี้:** การสร้างตาราง memory-optimized ต้องมี **MEMORY_OPTIMIZED_DATA filegroup** ในฐานข้อมูลก่อนเสมอ และการเพิ่ม filegroup คือการแก้โครงสร้างฐานข้อมูล (`ALTER DATABASE`) — เซิร์ฟเวอร์หลักสูตรที่ใช้ร่วมกันจึง **ไม่รันบล็อก DDL เหล่านี้ให้ดูสด** แต่ทุกบล็อกทำเป็นแบบมี guard พร้อมบอก **Expected ที่คุณจะเห็นเมื่อรันบนเครื่อง/DB ของตัวเอง** (รวมถึง error 41337 ที่จะเจอถ้าข้ามขั้นตอน) — ส่วนบล็อก DMV อ่านอย่างเดียวทั้งหมด รันได้จริงบนเซิร์ฟเวอร์หลักสูตร

---

## 1. สถาปัตยกรรมข้างใน — เร็วเพราะตัดของสามอย่าง

ศัพท์ก่อนใช้:

| ศัพท์ | นิยาม |
|:------|:------|
| **Memory-Optimized Table** | ตารางที่ข้อมูลอยู่ใน memory เป็นหลัก (และถูก persist ลงดิสก์ตามโหมด durability) |
| **MVCC (Multi-Version Concurrency Control) แบบ Optimistic** | ผู้อ่านไม่ล็อกผู้เขียน — ทุก transaction อ่าน "เวอร์ชัน" ของแถวตอนต้นทาง ถ้าขัดแย้งจริง engine ตัดสินตอน commit |
| **Lock-free / Latch-free** | ไม่ใช้ lock/latch เหมือนตารางปกติ — ใช้โครงสร้างแบบ lock-free แทน |
| **Native Compilation** | คอมไพล์ T-SQL (proc/table access) เป็น **machine code (DLL)** ตั้งแต่ตอนสร้าง — ตัด overhead ของ interpreter |
| **Checkpoint File Pairs (CFP)** | คู่ไฟล์ DATA/DELTA ใน filegroup ที่ใช้ persist ข้อมูล — เขียนแบบ append-only |

อะไรถูกตัดไป:

1. **ตัด latch** — ตารางปกติต้อง latch กันทุกครั้งที่แตะ page Hekaton ไม่มี page 8 KB บน buffer pool ของตารางนี้ (ข้อมูลเป็นแถวใน memory) — จึงไม่มี latch contention
2. **ตัด lock** (ในบรรทัดเดียวกับ MVCC) — อ่านไม่บล็อกเขียน เขียนไม่บล็อกอ่าน ขัดแย้งเกิดนาน ๆ ครั้งจึงถูกตัดสินด้วย optimistic logic
3. **ตัด interpretation** — natively compiled proc รันด้วย machine code ที่ไม่ต้องผ่าน query processor แบบ interpreted

**ราคาที่ต้องจ่ายของ "optimistic"** — ไม่มี lock ไม่ได้แปลว่าไม่มีความขัดแย้ง แค่ย้ายจุดตัดสินไปตอน commit: ถ้า transaction สองตัวแก้ **แถวเดียวกัน** พร้อมกัน ตัวที่ commit ทีหลังจะได้ error **write conflict (41302)** ทันที — application ต้องมี retry logic ดังนั้น pattern ที่เหมาะคือขัดแย้งน้อย (แย่งกันเขียนคนละแถว) ถ้า workload ของคุณแย่งแถวเดียวกันหนัก ๆ การย้ายมา Hekaton อาจทำให้ "ช้ากว่าเดิม" ในเชิง throughput จริง

ลำดับชีวิตหนึ่ง transaction แบบ optimistic:

```
BEGIN ──► อ่านเวอร์ชันของแถว ณ จุดเริ่ม (snapshot ของตัวเอง)
      ──► แก้แถว: สร้าง "เวอร์ชันใหม่" ชี้ต่อจากเวอร์ชันเก่า (แถวเก่ายังอยู่ให้คนอื่นอ่าน)
      ──► COMMIT: ตรวจว่าแถวที่แตะถูกใครแก้ไปหรือไม่
              ├── ไม่มีใครแตะ → commit สำเร็จ
              └── ถูกแก้แล้ว  → write conflict (41302) — rollback ตัวเอง + app retry
```

สังเกตว่า "แถวเก่า" ไม่ได้ถูกลบทันที — มันเป็น **garbage รอกวาด** โดย background thread ของ Hekaton ที่รอจนไม่มี transaction ไหนอ้างถึง (เช่นเดียวกับแนวคิด version store ใน Section 4.3 หัวข้อ PVS) — transaction ยาวจึงทำให้ memory ของ Hekaton โตตาม garbage ที่กวาดไม่ออกเหมือนกัน

```
             ตาราง disk-based (ปกติ)                 ตาราง memory-optimized
        ┌───────────────────────────┐          ┌───────────────────────────────┐
        │  Query  ──► Query Processor│          │  Native proc (machine code)   │
        │  ──► Buffer Pool (latch)   │          │  ──► แถวใน memory (lock-free) │
        │  ──► Data file             │          │  ──► CFP บนดิสก์ (append-only) │
        └───────────────────────────┘          └───────────────────────────────┘
           เขียน: log + dirty page                 เขียน: log + append CFP
           อ่าน: latch ทุกครั้ง                     อ่าน: ไม่มี latch/lock
```

> [!NOTE]
> "เร็วขึ้น 10–100 เท่า" ที่โฆษณากันเป็นค่าของ **pattern ที่เหมาะสม** (insert หนาแน่น/lookup แบบ point) ไม่ใช่กับทุก query — เดโมใน Lab 4 Exercise 4 วัด insert 10,000 แถวได้ระดับหลักร้อย ms บนเครื่องทดสอบ

---

## 2. เริ่มใช้อย่างถูกลำดับ — Filegroup มาก่อนเสมอ

**MEMORY_OPTIMIZED_DATA filegroup** (มีผู้ตรวจเรียกว่า "Hk filegroup") คือที่เก็บ checkpoint files ของตาราง memory-optimized — เป็น **เงื่อนไขบังคับ** ก่อนสร้างตารางแรก:

1. เพิ่ม filegroup ชนิด `CONTAINS MEMORY_OPTIMIZED_DATA`
2. เพิ่ม **container** (ไฟล์) ใน filegroup นั้น
3. จึงสร้างตาราง `MEMORY_OPTIMIZED = ON` ได้

ข้ามขั้นที่ 1 = เจอ **Msg 41337** ทันที (เดโมใน [Lab 4 Exercise 4](../../Labs/README.md) จงใจพิสูจน์ข้อความนี้): *"Cannot create memory optimized tables. To create memory optimized tables, the database must have a MEMORY_OPTIMIZED_FILEGROUP that is online and has at least one container."*

> ⚠️ **บล็อกเดโม — รันบนเครื่อง/DB ของคุณเองเท่านั้น (ไม่รันบนเซิร์ฟเวอร์ห้องเรียนร่วม)**
> บล็อกนี้มี `ALTER DATABASE` — ห้ามรันบนฐานข้อมูลที่ใช้ร่วมกัน

```sql
-- [DEMO-ONLY] Step 1-2: filegroup + container (บน DB ของคุณเอง)
USE AdventureWorks;
GO
IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE type = 'FX')   -- FX = memory-optimized filegroup
BEGIN
    ALTER DATABASE CURRENT ADD FILEGROUP [AdventureWorks_mod]
        CONTAINS MEMORY_OPTIMIZED_DATA;
    ALTER DATABASE CURRENT ADD FILE (NAME = 'AdventureWorks_mod_dir',
        FILENAME = N'D:\SQLData\AdventureWorks_mod_dir')   -- แก้ path ตามเครื่องคุณ
        TO FILEGROUP [AdventureWorks_mod];
END
GO
```

**Expected (เมื่อรันบนเครื่องตัวเอง):** `SELECT * FROM sys.filegroups WHERE type = 'FX'` ที่ก่อนหน้าว่างเปล่า จะมีแถว `AdventureWorks_mod / MEMORY_OPTIMIZED_DATA` เพิ่มขึ้น — ถ้า path ผิด/สิทธิ์ไม่พอ จะได้ error ที่ขั้น ADD FILE (Msg 5120 ฯลฯ) ให้แก้ path แล้วรันซ้ำ (ส่วน ADD FILEGROUP จะถูกข้ามเพราะ guard) — หลังสำเร็จ **ไม่ต้อง restart ใด ๆ** ตารางแรกสร้างได้ทันที

เรื่องการวางที่ในหัวข้อนี้ที่มักถูกถาม: container ของ Hk filegroup ควรอยู่บน **storage เร็วและแยกจาก transaction log** — เพราะมันถูกเขียนแบบ append หนัก ๆ ตลอดเวลาที่ workload วิ่ง (แม้แต่ตาราง SCHEMA_ONLY ยังต้องเขียน CFP เพื่อ persist "schema" และรองรับ recovery) และอย่าวางบน drive ที่เผื่อที่ไว้น้อย ๆ — การ merge CFP จะพองพื้นที่ใช้งานชั่วคราวก่อนหดกลับ

ตรวจสถานะ filegroup ได้ด้วย query อ่านอย่างเดียวนี้ (รันได้จริงทุก DB):

```sql
SELECT fg.name AS filegroup_name, fg.type_desc,
       COUNT(df.name) AS containers
FROM sys.filegroups AS fg
LEFT JOIN sys.database_files AS df
    ON fg.data_space_id = df.data_space_id
WHERE fg.type = 'FX'
GROUP BY fg.name, fg.type_desc;
```

**Expected (รันจริงบนเซิร์ฟเวอร์หลักสูตร):** ผลลัพธ์ **ว่างเปล่า** — AdventureWorks ของหลักสูตรยังไม่มี Hk filegroup ซึ่งเป็นเหตุผลที่ Lab 4 Exercise 4 ใช้เครื่องนี้พิสูจน์ Msg 41337 ได้พอดี

---

## 3. Memory-Optimized Tables — Durability, Indexes และกฎเหล็ก

### 3.1 สองโหมด durability

| โหมด | ข้อมูลหลัง restart | เขียน log ทุก commit? | เหมาะกับ |
|:------|:-------------------|:-----------------------|:----------|
| `DURABILITY = SCHEMA_AND_DATA` (durable) | อยู่ครบ (restore จาก CFP + log) | เขียน | ข้อมูลจริงที่ห้ามหาย |
| `DURABILITY = SCHEMA_ONLY` (non-durable) | เหลือแต่โครงตาราง — ข้อมูลหาย | **ไม่เขียนเลย** | staging, session store, ตัวนับ — ของที่สร้างใหม่ได้ |

จุดนี้คือคำตอบของ "ทำไม SCHEMA_ONLY ถึงเร็วมากกับ insert ทีละแถว": ตาราง disk-based แบบ autocommit ต้อง **flush log ก่อนรายงานสำเร็จทุกครั้ง** (WAL — Module 1.1) ส่วน SCHEMA_ONLY ไม่มี log ให้ flush — Lab 4 วัดคู่เทียบไว้แล้ว (~503 ms สำหรับ 10,000 insert บนตาราง disk-based ชั่วคราว)

### 3.2 ทำไมจึงมีข้อจำกัดมากมาย — และข้อจำกัดที่เจอบ่อย

ทุกข้อจำกัดของ Hekaton มาจากการออกแบบเดียวกัน: "โครงสร้างที่คอมไพล์ล่วงหน้า + ไม่มี latch + อยู่ใน memory" — อะไรที่ต้อง "เปลี่ยนใจกลางทาง" เช่น schema แก้บ่อย, โครงข้อมูลไม่คงที่ จึงเข้ากันยาก ข้อที่เจอบ่อยในหน้างาน:

| ความสามารถ | สถานะ | หมายเหตุ |
|:------------|:-------|:----------|
| PRIMARY KEY / UNIQUE | ใช้ได้ (ต้องเป็น index ของตาราง MO) | ทุกตาราง MO ต้องมี PK (หรือ index) อย่างน้อยหนึ่งตัว |
| FOREIGN KEY ระหว่างตาราง MO | ใช้ได้ | อ้างไปตาราง disk-based **ไม่ได้** |
| TRUNCATE TABLE | **ห้าม** | ใช้ DELETE แทน (หรือออกแบบด้วยตารางชุดใหม่/swap) |
| คอลัมน์ LOB ในแถวเดียวกับตาราง | ใช้ได้ตั้งแต่ 2016+ (off-row data) | เวอร์ชันเก่าจำกัดขนาดแถว 8,060 bytes |
| ALTER แก้ BUCKET_COUNT / ชนิด index | ไม่ได้ตรง ๆ | ต้องสร้าง index ใหม่ที่ถูกแล้ว drop เก่า (นับโควตา 8 indexes) |
| แก้ schema ของตาราง | ได้แบบจำกัด | ALTER TABLE แบบ metadata-only ส่วนใหญ่; ต้องระวัง proc ที่ SCHEMABINDING |
| เข้าถึงจาก interpreted T-SQL ทั่วไป | ใช้ได้ | SELECT/JOIN ปกติเห็นตาราง MO เหมือนตารางธรรมดา |

### 3.3 Index สองตระกูล (ไม่มี clustered index!)

| Index | เหมาะกับ | ข้อควรรู้ |
|:--------|:----------|:-----------|
| **HASH** | equality lookup (`WHERE key = @p`) เท่านั้น | ต้องตั้ง **`BUCKET_COUNT`** — แนะนำ ~1–2 เท่าของจำนวนแถวเอกลักษณ์ที่คาด; ตั้งต่ำเกิน → chain ยาว ค้นช้า |
| **NONCLUSTERED (Bw-tree)** | range scan (`>`, `<`, `BETWEEN`, `ORDER BY`) | index แบบ lock-free เชื่อมหน้าแบบ pointer |

> [!IMPORTANT]
> กฎเหล็กที่เจอบ่อย: ห้าม `TRUNCATE TABLE`, FK อ้างไปตาราง disk-based ไม่ได้ (อ้างระหว่างตาราง MO กันเองได้), สูงสุด 8 indexes ต่อตาราง, `BUCKET_COUNT` แก้ไม่ได้ต้อง drop สร้างใหม่ และ **ตาราง memory-optimized ไม่ใช้ buffer pool** — memory ของมันถูกจองผ่าน `MEMORYCLERK_XTP` (หัวข้อ 5) ต้องวางแผน memory ทั้งตารางไว้ใน `max server memory` เดียวกัน

### 3.4 ข้างหลัง `SCHEMA_AND_DATA`: Checkpoint File Pairs (CFP)

ที่ที่ข้อมูล durable ไปอยู่คือ **คู่ไฟล์ใน Hk filegroup** — จับคู่กันเสมอ:

| ไฟล์ | เก็บอะไร | ลักษณะการเขียน |
|:------|:----------|:-----------------|
| **DATA file** | แถวที่ insert/update (เวอร์ชันที่ถูกต้อง) | append-only — ไม่มีการแก้ไฟล์เดิม |
| **DELTA file** | รายการแถวที่ถูก delete (หรือเวอร์ชันเก่าที่ update ทิ้ง) | append-only เช่นกัน |

```
   INSERT แถว A,B,C ──► DATA file: [A B C]
   DELETE แถว B    ──► DELTA file: [B]
   การอ่าน = DATA − DELTA (engine กรองเอง)
   ทั้งหมดถูกยึดด้วย log เหมือนตารางปกติ → crash recovery จาก log + CFP
```

เมื่อไฟล์ชุดเก่าเต็มและไม่มี transaction ไหนอ้างถึงแล้ว engine จะ **merge** คู่ไฟล์เก่าให้เป็นชุดใหม่แล้วยกเลิกชุดเก่า (garbage collection ระดับ storage) — นี่คือเหตุผลที่ Hk filegroup "ดูเปลืองพื้นที่" ระหว่างใช้งานหนัก และเป็นสัญญาณที่ต้องเฝ้าดูถ้าดิสก์จำกัด

### 3.5 ตัวอย่างการออกแบบสั้น ๆ: "Session Store"

โจทย์: เก็บ session ของ application สูงสุด ~50,000 sessions พร้อมกัน, เขียนถี่มาก, ตายแล้วตั้งใหม่ได้, ค้นด้วย `SessionId` เสมอ — ตัดสินใจ:

1. **Durability**: ข้อมูลหายได้เมื่อ restart (app ยอมให้ user login ใหม่) → `SCHEMA_ONLY` — ประหยัด log ทุก commit
2. **Index หลัก**: ค้นเฉพาะ `WHERE SessionId = @id` (equality เท่านั้น) → **HASH index** พร้อม `BUCKET_COUNT = 100000` (~2 เท่าของ 50,000 — ทศนิยมปลอดภัย)
3. **ขนาด memory**: payload ~300 bytes × 50,000 = ~15 MB + overhead → ถูกเมื่อเทียบกับประโยชน์; ถ้าเกมนี้โตไม่มีเพดาน ต้องออกแบบ TTL/ล้างของ (ลบเป็นชุด)
4. **Proc**: insert/lookup รันถี่หลักพัน ๆ ครั้ง/วินาที → natively compiled คุ้ม

จะเห็นว่าการตัดสินใจทุกข้อมาจากกฎใน section นี้ทั้งหมด — ไม่มีข้อไหนต้องเดา

> ⚠️ **บล็อกเดโม — รันบนเครื่อง/DB ของคุณเองเท่านั้น**

```sql
-- [DEMO-ONLY] ตาราง memory-optimized สองโหมด durability
USE AdventureWorks;
GO
CREATE TABLE dbo.MO_Sessions
(
    SessionId  UNIQUEIDENTIFIER NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 100000),
    CreatedAt  DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    Payload    NVARCHAR(256) NOT NULL
) WITH ( MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_ONLY );
GO
```

**Expected (เมื่อรันบนเครื่องตัวเองหลังทำหัวข้อ 2 ครบ):** สร้างสำเร็จ — ถ้ายังไม่มี filegroup จะได้ **Msg 41337** (ตามที่ Lab พิสูจน์ไว้); ถ้าตั้ง `BUCKET_COUNT = 10` กับคาย 100,000 key จะเตือน Msg 41316 เรื่อง bucket count ต่ำเกิน; ทดสอบความเร็วด้วยลูป insert 10,000 แถวใน Lab 4 Exercise 4 แล้วเทียบกับตาราง disk-based (~503 ms บนเครื่องทดสอบ)

---

## 4. Natively Compiled Stored Procedures — Machine Code แต่ต้องแลกกับกฎ

**Natively compiled stored procedure** คือ proc ที่ถูกคอมไพล์เป็น DLL ตั้งแต่ `CREATE` (แตกต่างจาก proc ปกติที่ compile ตอนรันครั้งแรก) — เหมาะกับ logic แบบ point operation ที่วิ่งถี่มาก

ข้อกำหนดบังคับ (ที่ทำให้หลายทีมล้มเลิกกลางทาง — อ่านให้ครบก่อนใช้):

1. **`SCHEMABINDING`** — ผูกติด schema ของตารางที่อ้าง → ห้ามแก้ตารางถ้าไม่ drop/alter proc ก่อน
2. **`BEGIN ATOMIC`** — บล็อกทั้งหมดเป็น transaction เดียว พร้อมระบุ `TRANSACTION ISOLATION LEVEL` และ `LANGUAGE` ชัดเจน
3. รองรับเฉพาะชุด T-SQL ย่อย (ไม่มี CTE แบบ recursive, ห้าม query ตาราง disk-based ในรุ่นเก่า ฯลฯ)

> ⚠️ **บล็อกเดโม — รันบนเครื่อง/DB ของคุณเองเท่านั้น**

```sql
-- [DEMO-ONLY] natively compiled proc สำหรับ insert ความเร็วสูง
USE AdventureWorks;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MO_AddSession
    @SessionId UNIQUEIDENTIFIER,
    @Payload   NVARCHAR(256)
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH
(
    TRANSACTION ISOLATION LEVEL = SNAPSHOT,
    LANGUAGE = N'us_english'
)
    INSERT INTO dbo.MO_Sessions (SessionId, Payload)
    VALUES (@SessionId, @Payload);
END;
GO
```

**Expected (เมื่อรันบนเครื่องตัวเอง):** proc ถูกคอมไพล์เป็น DLL ทันทีที่ `CREATE` (สังเกตเวลา `CREATE` นานกว่า proc ปกติเล็กน้อยคือตอน compile) — ถ้าตาราง `dbo.MO_Sessions` ยังไม่มี จะได้ error binding; ลองแก้ schema ของ `MO_Sessions` โดยไม่ drop proc จะโดนข้อห้ามของ SCHEMABINDING

---

## 5. บัญชี Memory ของ Hekaton — อ่านด้วยเครื่องมือเดียวกับที่เรียนมา

ความสวยของสถาปัตยกรรมนี้จากมุมผู้ดูแลระบบคือ **ทุกไบต์ของ Hekaton ถูกจดใน clerk ที่เรารู้จักแล้ว** — สาม DMV หลัก (รันได้จริงแม้ DB ยังไม่มีตาราง MO):

```sql
-- 1) Clerk ของ Hekaton (MEMORYCLERK_XTP — XTP = eXtreme Transaction Processing)
SELECT type, pages_kb / 1024.0 AS pages_mb,
       virtual_memory_committed_kb / 1024.0 AS vm_committed_mb
FROM sys.dm_os_memory_clerks
WHERE type LIKE '%XTP%';

-- 2) ผู้บริโภคระบบของ Hekaton (มีอยู่เสมอ แม้ยังไม่มีตาราง)
SELECT TOP (5) memory_consumer_id, memory_consumer_type_desc,
       allocated_bytes / 1024 AS allocated_kb,
       used_bytes / 1024 AS used_kb
FROM sys.dm_xtp_system_memory_consumers
ORDER BY allocated_bytes DESC;

-- 3) Memory ต่อตาราง MO (ว่างถ้ายังไม่มีตาราง)
SELECT object_id,
       memory_allocated_for_table_kb,
       memory_used_by_table_kb
FROM sys.dm_db_xtp_table_memory_stats;
```

**Expected (รันจริงบนเซิร์ฟเวอร์หลักสูตร):** (1) เห็น `MEMORYCLERK_XTP` ~11 MB — Hekaton จองโครงสร้างระบบเอาไว้แล้วแม้คุณยังไม่ได้ใช้; (2) ผู้บริโภคระบบมีแถว `VARHEAP` ~448 KB ให้เห็น; (3) **ผลลัพธ์ว่างเปล่า** เพราะ DB ไม่มีตาราง memory-optimized — สามข้อนี้คือ baseline "ก่อนเปิดใช้ Hekaton" ให้จดไว้เทียบตอนที่เปิดใช้จริง ค่าที่เปลี่ยนแรกคือ `MEMORYCLERK_XTP` ที่จะโตตามขนาดข้อมูลทั้งหมดในตาราง MO

> [!IMPORTANT]
> เมื่อมีตาราง MO จริง ให้เพิ่ม `MEMORYCLERK_XTP` เข้าในเช็คลิสต์ clerks ของ Section 4.3 — ถ้ามันบวมจนกด buffer pool นั่นคือ moment ที่ต้องทบทวนขนาดข้อมูลใน Hekaton (และถ้าเกิน `max server memory` จะเจอ error "There is insufficient system memory" ตระกูล 41839 ฯลฯ)

---

## 6. ปี 2025: Hekaton ยังเกี่ยวหรือไม่?

ข่าวดีที่ปิดจุดอ่อนที่สุดของการนำไปใช้จริง:

- **SQL Server 2025 ลบ memory-optimized filegroup ที่ว่างออกได้แล้ว** — ยุคก่อน "เคยลอง Hekaton แล้วเลิกใช้ แต่ถอดไม่ได้ ต้องย้าย DB ทั้งก้อน" เป็นข้อโต้แย้งอันดับหนึ่งของทีมที่ไม่กล้าแตะ วันนี้ข้อนั้นหมดไป
- การย้ายออกจาก Hekaton ก็ง่ายขึ้นเรื่อย ๆ จากฟีเจอร์ยุค 2022/2025 (tempdb metadata ใน memory, Optimized Locking ที่ลด lock memory ด้วย TID Lock — Module 5)

pattern ที่ยังเหมาะ (insert หนาแน่น + lookup เร็ว ของที่สร้างใหม่ได้หรือขนาดคุมได้):

- **ETL staging** — โหลดชั่วคราวแบบ SCHEMA_ONLY แล้ว merge ทิ้ง
- **Session store / rate limiter / counter** — เขียนถี่ อายุสั้น
- **IoT ingestion / queue ใน DB** — insert throughput สูงก่อนส่งต่อ

และ pattern ที่ **ไม่ควร** ใช้: reporting scan/aggregation ใหญ่หลากหลาย operator (natively compiled proc ทำงาน single-threaded — จุดแข็งอยู่ที่ point operation), ตารางที่โตไม่จำกัด (memory ต้องรองรับทั้งก้อน), workload ที่พึ่ง T-SQL surface เต็มรูป

> [!TIP]
> กฎการตัดสินใจแบบสั้น ๆ: **"เริ่มจาก index + statistics + query ให้ดีก่อนเสมอ"** — Hekaton คือทางเลือกสุดท้ายเมื่อ pattern เฉพาะจุดยังติดคอขวด memory/latch/log จริง ๆ ไม่ใช่ตัวเลือกแรกของ "อยากเร็วขึ้น"

### เทียบเคียงทางเลือกในยุคเดียวกัน

ปัญหาบางอย่างที่เคยใช้ Hekaton แก้ ตอนนี้มีทางเลือกที่ "แพงน้อยกว่า" — ใช้ตารางนี้ช่วงชิงก่อนตัดสินใจ:

| ปัญหา | Hekaton แก้ได้ | ทางเลือกใหม่ที่ควรลองก่อน |
|:------|:----------------|:---------------------------|
| Insert หนาแน่นต้อง flush log ต่อแถว | SCHEMA_ONLY | — (ยังคงเป็นจุดแข็งของ Hekaton) |
| TempDB อืดจาก metadata contention | — | TempDB metadata memory-optimized (2019+) |
| Lock memory บวมจาก transaction ใหญ่ | — | Optimized Locking / TID Lock (2025 — Module 5) |
| Read โดน block จาก writer | MVCC ของ Hekaton | RCSI (เปิดง่ายกว่ามาก — ฐานข้อมูลหลักสูตรเปิดแล้ว) |
| Blocking ยาวจน redo/recovery ยาว | — | ADR — Accelerated Database Recovery (2019+) |

### คำถามที่เจอบ่อย (FAQ)

**"Hekaton แทน temp table ได้ไหม?"** — ได้เฉพาะจุด: ตาราง MO แชร์ข้าม session และตัด log ได้ (SCHEMA_ONLY) แต่ temp table ไม่ต้องจอง memory ถาวรและมี tempdb metadata ใหม่ช่วยแล้ว — ย้ายเมื่อ "แชร์ข้าม session + เขียนถี่" เท่านั้น

**"ใช้กับ Always On ได้ไหม?"** — ได้ (รองรับตั้งแต่ 2016) แต่กระแส redo ของตาราง MO มีลักษณะต่างจาก disk-based ให้วัด latency ของ redo จริงก่อน production

**"ลืมตั้ง BUCKET_COUNT แล้วแก้ทีหลังได้ไหม?"** — ไม่ได้ตรง ๆ — ต้องเพิ่ม hash index ใหม่ที่ตั้งถูก แล้ว drop ตัวเก่า (และจำว่าสูงสุด 8 indexes ต่อตาราง — ทางลัดนี้กินโควตา)

**"ตาราง MO หายได้ไหมถ้า SQL Server crash?"** — แยกตาม durability: `SCHEMA_AND_DATA` จะ recover จาก log + CFP ครบทุกแถวที่ commit แล้ว, `SCHEMA_ONLY` จะเหลือ "โครงตารางเปล่า" โดยดีไซน์ — ทั้งสองแบบตารางและข้อมูล **ไม่เคยอยู่ครึ่ง ๆ กลาง ๆ** เพราะทุก commit ผูกกับ log ตามหลัก WAL เสมอ

### Pre-flight checklist ก่อนกด `CREATE TABLE ... MEMORY_OPTIMIZED = ON`

1. **Filegroup + container พร้อมแล้ว?** — query ในหัวข้อ 2 ต้องคืนแถวก่อน ไม่งั้น Msg 41337
2. **ขนาดข้อมูลรวม (ตอนนี้ + อนาคต) พอดี memory ไหม?** — ทั้งตารางต้องอยู่ใน RAM; ให้เผื่อ overhead row version ต่อ transaction ที่เปิดค้าง
3. **`BUCKET_COUNT` คิดจากแถวเอกลักษณ์ที่คาด?** — ประมาณ 1–2 เท่า; ต่ำเกิน = chain ยาว, สูงเกิน = เปลือง memory เปล่า
4. **เลือก durability ตาม "หายได้ไหม"** ไม่ใช่ตาม "อยากเร็ว" — SCHEMA_ONLY คือข้อตกลงเรื่องข้อมูลหาย ไม่ใช่แค่ speed hack
5. **T-SQL ที่ใช้รองรับไหม?** — เช่น proc ต้อง native compilation + ATOMIC; ตรวจ surface ที่รองรับก่อนพอร์ตโค้ด
6. **ทางถอยหลังวางไว้แล้ว?** — บน 2025: ลบ filegroup ที่ว่างได้; บนรุ่นเก่า: การถอดต้องย้ายข้อมูลออกทั้งหมดก่อน — รู้ตอน "เข้า" ดีกว่าตอน "อยากออก"
7. **เฝ้าดู `MEMORYCLERK_XTP`** ในบัญชี clerks ประจำวัน (เช็คลิสต์ Section 4.3)

---

## สรุป Section 4

1. **In-Memory OLTP เปลี่ยน memory จาก cache เป็นที่เก็บหลัก** — เร็วจากการตัด latch, lock (MVCC optimistic) และ interpretation (native compilation)
2. **ลำดับบังคับ: Hk filegroup + container มาก่อนตารางเสมอ** — ข้ามขั้นเจอ Msg 41337 ทันที; บน SQL Server 2025 filegroup ที่ว่างลบออกได้แล้ว
3. เลือกให้ถูก: **`SCHEMA_AND_DATA`** สำหรับของจริง, **`SCHEMA_ONLY`** สำหรับของชั่วคราว (ประหยัด log flush ต่อ commit); **HASH index** สำหรับ equality (BUCKET_COUNT ตั้งพอดี), **NONCLUSTERED** สำหรับ range
4. **Natively compiled proc** ต้องแลกด้วย SCHEMABINDING + ATOMIC + T-SQL ย่อย — เหมาะกับ point operation ถี่ ๆ
5. **อ่านสุขภาพ Hekaton ด้วยเครื่องมือเดิม**: `MEMORYCLERK_XTP`, `sys.dm_xtp_system_memory_consumers`, `sys.dm_db_xtp_table_memory_stats` — และใส่ clerk นี้ลงเช็คลิสต์ pressure ของ Section 4.3
6. ปี 2025: ใช้แบบมีเป้าหมาย — pattern insert/lookup ความเร็วสูงเฉพาะจุด ไม่ใช่ยาแครามทุกปัญหา

### ตรวจความเข้าใจ

1. เหตุใดตาราง `DURABILITY = SCHEMA_ONLY` จึงเร็วมากกับ insert ทีละแถวแบบ autocommit — ขั้นตอนใดของ WAL ที่ถูกข้ามไป?
2. ตาราง memory-optimized ที่ออกแบบ HASH index ไว้ `BUCKET_COUNT = 1,000` แต่โตเป็น 500,000 แถวเอกลักษณ์ — เกิดอะไรขึ้น และทำไมจึงแก้ด้วย `ALTER INDEX` ไม่ได้?
3. Msg 41337 เกิดจากขาดอะไร ลำดับขั้นที่ถูกคืออย่างไร และข่าวดีใน SQL Server 2025 เกี่ยวกับ filegroup นี้คืออะไร?
4. ข้อกำหนด `SCHEMABINDING` + `BEGIN ATOMIC` ของ natively compiled proc สร้างค่าใช้จ่ายด้านการดูแลอะไรบ้าง — กรณีไหนจึง "คุ้ม" ที่จะจ่าย?
5. หลังเปิดใช้ตาราง MO จริง ใครควรเป็น clerk ที่คุณเฝ้าดูในเช็คลิสต์ pressure และอาการอะไรที่บอกว่า Hekaton กินเกินส่วน?
6. ทีมเสนอย้าย "ตาราง report ขนาด 200 GB" ไปเป็น memory-optimized เพื่อให้ "อยู่ใน RAM" — ขัดข้องเชิงหลักการข้อใด (คิดจากเนื้อหาหัวข้อ 6)?

**➡ จบ Module 04:** กลับไปทบทวน [Module 04 README](../../README.md) และทดสอบความเข้าใจด้วย [Quiz Bank](../../Quiz_Bank.md)

---

[⬅ Module 04](../../README.md) | [🧪 Labs](../../Labs/README.md) | [Quiz Bank](../../Quiz_Bank.md)
