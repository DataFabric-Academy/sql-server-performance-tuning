# สไลด์ไบล์พรินต์รายสไลด์ — Module 4: Memory Management (M04)

> **เด็ค:** 20 สไลด์ ตามสูตรตายตัวของแผนแม่บท §4.2 (โครง 4 สไลด์: Cover / Module Divider / Lab / Closing + 4 สไลด์ × 4 sections) — เพดาน Code Lab ใช้ 4/4 ใบ (สไลด์ 13, 14, 18, 19)
> **งบเวลา:** บรรยาย 90 นาที (วันที่ 2, 09:00–10:30) + LAB 4 อีก 60 นาที (10:30–11:30) — จาก `Trainer_Docs/Course_Guide_4Days.md:87-88`
> **แหล่งเนื้อหา:** `Module_04_Memory/README.md` + Sections 4 ไฟล์ (Windows Memory 61 บรรทัด / SQL Server Memory 325 / Memory Pressure Diagnostics 75 / In-Memory OLTP 49) + สคริปต์ 4 ไฟล์ใน `Sections/*/Scripts/`
> **ภาพ:** repo ยังไม่มีภาพของโมดูลนี้ (`find Module_04_Memory -type d -name images` = ไม่พบ; `git ls-files "*.png"` เจอแค่ 2 PNG ของ M1) → แผนภาพทั้ง 6 ชิ้นต้องวาดใหม่เป็น PNG กว้าง ≥2400px ตาม spec §4.4
> **สถานะเนื้อหา:** Section 1, 3, 4 ยังเป็น outline — สไลด์ออกแบบตาม "เป้าหมายของหัวข้อ" และระบุ **"ต้องเขียนเนื้อหาเพิ่ม"** ใน speaker notes ของสไลด์ที่เกี่ยว

**การตรวจที่รันจริงระหว่างเขียนไบล์พรินต์ (2026-10-01):** `grep -c "^## Exercise" Module_04_Memory/Labs/README.md` = **4** · `grep -n "^## ###" Module_04_Memory/README.md` = บรรทัด 61 (heading เสีย ตรงตามแผน §3) · `wc -l` ของ 4 section README = 61/325/75/49 · `grep -l "MinVersion" Module_04_Memory/Sections/*/Scripts/*.sql` = **ไม่พบ** (0/4 ไฟล์ — ต้องเติม header ตาม Blocking เฟส 0 ก่อนประกอบเด็ค) · `find . -name "01_Buffer_Usage_By_DB.sql" -o -name "02_Page_Life_Expectancy.sql"` = **ไม่พบ** (สคริปต์ที่ `03_Workload_Buffer_Pool.sql:3,15` อ้าง ยังไม่มีใน repo)

---

### สไลด์ 1: Cover — Module 4: Memory Management
- **Layout:** `title` → potx `01 Cover (dark)`
- **Bullets:**
  1. หลักสูตร Microsoft SQL Server Performance Tuning (4 วัน / 24 ชั่วโมง)
  2. Module 4: Memory Management — วันที่ 2 เวลา 09:00–10:30
  3. ความต่อเนื่อง: ต่อจาก Module 3 (Database Structures) → ก่อน Module 5 (Concurrency & Transactions)
- **ภาพ/แผนภาพ:** ไม่ใช้ — ใช้ background ของ layout 01 เท่านั้น
- **Speaker notes:** เปิดโมดูลด้วยประโยคว่าการเข้าถึงข้อมูลใน RAM เร็วกว่า Disk หลายพันเท่า จึงเป็นทรัพยากรสำคัญที่สุดของ SQL Server Ref: `Module_04_Memory/README.md:1-3`
- **Script:** —

### สไลด์ 2: Module Divider — ภาพรวมโมดูลและงบเวลา
- **Layout:** `section-divider` → potx `02 Module Divider (dark)`
- **Bullets:**
  1. **งบเวลาโมดูล 90 นาที** (09:00–10:30 วันที่ 2) + **LAB 4 อีก 60 นาที** (10:30–11:30)
  2. 4 sections: Windows Memory → SQL Server Memory → Memory Pressure Diagnostics → In-Memory OLTP
  3. แล็บมี **4 Exercise**: สุขภาพ memory → buffer pool ต่อ database → memory spill & Memory Grant Feedback → In-Memory OLTP
  4. เป้าหมาย: ตั้งค่า Memory ได้อย่างปลอดภัย และวินิจฉัย Memory Pressure ได้ด้วย DMVs / Wait Types
- **ภาพ/แผนภาพ:** ไม่ใช้
- **Speaker notes:** ย้ำงบเวลาและจำนวน Exercise ให้ผู้เรียนวางแผน; เวลาจริงจากการทดสอบผู้เรียน (เฟส 4 ของแผน) ต้องนำมาเทียบกับงบบนสไลด์นี้ Ref: `Trainer_Docs/Course_Guide_4Days.md:87-88` · `Module_04_Memory/Labs/README.md`
- **Script:** —

### สไลด์ 3: Section Divider — Section 1: Windows Memory
- **Layout:** `section-divider` → potx `02 Module Divider (dark)`
- **Bullets:**
  1. เป้าหมาย 1: อธิบาย Virtual Address Space (VAS) และข้อต่าง 32-bit vs 64-bit
  2. เป้าหมาย 2: แยก Physical vs Virtual Memory และอธิบายผลของ Paging ต่อ SQL Server
  3. เป้าหมาย 3: อธิบาย NUMA — Local/Remote Memory และ node awareness ของ SQL Server
- **ภาพ/แผนภาพ:** ไม่ใช้
- **Speaker notes:** ต้องรู้มาก่อน: พื้นฐาน OS (RAM / page file) และศัพท์ DMV — ชี้ลิงก์ Glossary กลาง (path รอกำหนดตาม Blocking เฟส 0 — วันนี้ repo ยังไม่มีไฟล์ glossary) · **ต้องเขียนเนื้อหาเพิ่ม**: section ปัจจุบัน 61 บรรทัด ไม่มีบล็อก ```sql และไม่มีหัวข้อ "ตรวจความเข้าใจ" Ref: `Module_04_Memory/Sections/01_Windows_Memory/README.md`
- **Script:** —

### สไลด์ 4: Virtual Address Space (VAS) — 32-bit vs 64-bit
- **Layout:** `two-column` → potx `04 Two-Column`
- **Bullets (ซ้าย 32-bit / ขวา 64-bit):**
  1. VAS = พื้นที่ address ที่ process มองเห็นและใช้งานได้ แยกอิสระจาก Physical RAM
  2. 32-bit: ข้อจำกัดสูง (max ~4 GB) — ปัจจุบันไม่แนะนำให้ใช้งาน
  3. 64-bit: รองรับ VAS ขนาดมหาศาล (8 TB–128 TB) ข้อจำกัด address space หมดไป
  4. บทสรุป tuning: บน 64-bit ให้โฟกัส Physical Memory และการจัดสรร ไม่ใช่ VAS
  5. เชื่อมโยง: อ่านค่า VAS committed จริงได้จาก `sys.dm_os_process_memory` (`virtual_address_space_committed_kb`)
- **ภาพ/แผนภาพ:** ไม่บังคับ — เทียบสองคอลัมน์ด้วย layout 04 ล้วน
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม**: เพิ่มตัวอย่างการอ่านค่า VAS จริงจาก `sys.dm_os_process_memory` ซึ่งมีอยู่แล้วในสคริปต์วิเคราะห์ของ Section 3 Ref: `Module_04_Memory/Sections/01_Windows_Memory/README.md:5-8` · `Module_04_Memory/Sections/03_Memory_Pressure_Diagnostics/Scripts/02_Memory_Analysis.sql:19-26`
- **Script:** —

### สไลด์ 5: Physical vs Virtual Memory และผลของ Paging
- **Layout:** `bullets+diagram` → potx `03 Content`
- **Bullets:**
  1. Physical Memory = หน่วยความจำหลัก (RAM) / Virtual Memory = กลไก OS ที่ใช้ Page File บน Disk ขยายพื้นที่
  2. Paging = กระบวนการย้าย Data Pages ระหว่าง RAM และ Disk
  3. ถ้า Windows ทำ Paging process ของ SQL Server → Performance Degradation อย่างรุนแรง
  4. เป้าหมายการ tuning: กันไม่ให้ SQL Server ถูก paging — ทางแก้คือ LPIM ซึ่งจะเจาะลึกใน Section 2
  5. สัญญาณที่ต้องเฝ้าดู: Available RAM และ hard faults/sec ของ process (bullet เป้าหมาย — ยังไม่มีในเนื้อหา repo)
- **ภาพ/แผนภาพ:** วาดใหม่ PNG ≥2400px → `Module_04_Memory/Sections/01_Windows_Memory/images/windows-physical-vs-virtual-paging.png` (โครง: RAM ↔ Page File ↔ SQL Server process)
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม**: เพิ่ม counters ฝั่ง Windows ที่ควรดูและเกณฑ์ตัดสิน Ref: `Module_04_Memory/Sections/01_Windows_Memory/README.md:10-14`
- **Script:** —

### สไลด์ 6: NUMA — Local vs Remote Memory
- **Layout:** `bullets+diagram` → potx `03 Content`
- **Bullets:**
  1. NUMA (Non-Uniform Memory Access) ออกแบบเพื่อลดคอขวด Memory Bus ในเครื่องที่มี CPU จำนวนมาก
  2. Local Memory เข้าถึงเร็วที่สุด (~100 ns) / Remote Memory ข้าม node ช้ากว่า (~200–300 ns)
  3. SQL Server Awareness: Engine พยายามจัดสรร Memory ใน node เดียวกับ Thread ที่ทำงานเสมอ
  4. วัดต่อ node ไม่ใช่ดูรวม: `sys.dm_os_memory_nodes` และ PLE ต่อ Buffer Node (ใช้จริงในแล็บ Exercise 2 Step 3)
- **ภาพ/แผนภาพ:** วาดใหม่ PNG ≥2400px → `Module_04_Memory/Sections/01_Windows_Memory/images/numa-local-remote.png` (redraw จาก mermaid NUMA ใน README บรรทัด 18–50)
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม**: เพิ่มเรื่อง soft-NUMA และวิธีตรวจ node จริงของ instance Ref: `Module_04_Memory/Sections/01_Windows_Memory/README.md:16-55` · `Module_04_Memory/README.md:71`
- **Script:** —

### สไลด์ 7: Section Divider — Section 2: SQL Server Memory
- **Layout:** `section-divider` → potx `02 Module Divider (dark)`
- **Bullets:**
  1. เป้าหมาย 1: เลือก Memory Model ให้ถูก — Conventional / LPIM / Large Page
  2. เป้าหมาย 2: อ่านโครงสร้างภายใน — Buffer Pool, Memory Clerks และ Page Lifecycle
  3. เป้าหมาย 3: ตั้งค่า min/max server memory อย่างปลอดภัย และใช้ Resource Governor จัดสรรงบ Memory
- **ภาพ/แผนภาพ:** ไม่ใช้
- **Speaker notes:** ต้องรู้มาก่อน: NUMA + Paging จาก Section 1 และศัพท์ Buffer Pool / DMV — ชี้ลิงก์ Glossary กลาง (ยังไม่มีไฟล์ — เฟส 0) · section นี้หนาที่สุดของโมดูล (325 บรรทัด) เนื้อหาตาม README ได้เลย Ref: `Module_04_Memory/Sections/02_SQL_Server_Memory/README.md`
- **Script:** —

### สไลด์ 8: Memory Models — Conventional / LPIM / Large Page
- **Layout:** `bullets+diagram` → potx `03 Content`
- **Bullets:**
  1. Conventional Memory Model: Dynamic Allocation — OS ทำ Paging ได้ จึงเสี่ยง Performance Degradation
  2. LPIM (Lock Pages in Memory): Windows Policy กันไม่ให้ SQL Server Memory ถูก paging ลง Disk — เสถียรภาพสูง แนะนำสำหรับ Production Server
  3. Large Page Memory Model: ใช้ 2 MB Pages แทน 4 KB ลด TLB Overhead — แลกด้วย Static Allocation ตอน Startup (เปิด service ช้า)
  4. ตรวจผลจริง: ค่า `locked_page_allocations_kb` ใน `sys.dm_os_process_memory` (แล็บ Exercise 1 Step 2)
- **ภาพ/แผนภาพ:** วาดใหม่ PNG ≥2400px → `Module_04_Memory/Sections/02_SQL_Server_Memory/images/memory-models-lpim-largepage.png` (redraw จาก mermaid 3.1 ใน README บรรทัด 7–46)
- **Speaker notes:** คำแนะนำ LPIM ให้อ้าง Memory Management Architecture Guide ของ Microsoft ตามลิงก์ใน README Ref: `Module_04_Memory/Sections/02_SQL_Server_Memory/README.md:5-55`
- **Script:** —

### สไลด์ 9: Buffer Pool และ Memory Clerks — Page Lifecycle
- **Layout:** `bullets+diagram` → potx `03 Content`
- **Bullets:**
  1. Buffer Pool = cache เก็บ Data/Index Pages ขนาด 8 KB — อ่านจาก memory (~100 ns) เร็วกว่า disk (~10 ms) ราว 100,000 เท่า
  2. Memory Clerks ตัวอื่น: `MEMORYCLERK_SQLQUERYPLAN` (Plan Cache), `MEMORYCLERK_SQLCONNECTIONPOOL`, `OBJECTSTORE_LOCK_MANAGER`, `WORKSPACE` (Sort/Hash)
  3. Page Lifecycle: cache miss → Physical Read; **Lazy Writer** evict page แบบ LRU เมื่อ memory ตึง; **Checkpoint** เขียน Dirty Pages ลง disk
  4. **Resource Monitor** (background thread) รับสัญญาณจาก Windows: `RESOURCE_MEMPHYSICAL_HIGH/LOW/STEADY` — เมื่อ LOW จะ Trim Caches คืน memory ให้ OS
  5. ตั้งแต่ SQL 2012+ ใช้ "Any Size" Page Allocator → **max server memory คุมการใช้ memory เกือบทั้งหมด** (รวม CLR / multi-page)
- **ภาพ/แผนภาพ:** วาดใหม่ PNG ≥2400px → `Module_04_Memory/Sections/02_SQL_Server_Memory/images/buffer-pool-architecture.png` (รวม mermaid 3.2 + 3.5 เป็นแผนภาพเดียว: Allocator → Buffer Pool / Clerks → Lazy Writer & Checkpoint → Data Files)
- **Speaker notes:** แผนภาพนี้คือหัวใจของโมดูล — ชี้ให้เห็น Resource Monitor ก่อนไปต่อวิธีอ่าน ring buffer ใน Section 3 Ref: `Module_04_Memory/Sections/02_SQL_Server_Memory/README.md:57-319`
- **Script:** —

### สไลด์ 10: การตั้งค่า Memory — min/max server memory & Resource Governor
- **Layout:** `two-column` → potx `04 Two-Column`
- **Bullets (ซ้าย Min/Max Server Memory / ขวา Resource Governor):**
  1. **max server memory = Critical Setting**: คำนวณ = Total RAM − (OS Reserved + Other Applications)
  2. ข้อควรรู้: ค่านี้ไม่ครอบคลุม Thread Stacks และ CLR allocations บางส่วน
  3. **min server memory**: ค่าต่ำสุดที่จะรักษาไว้ (Reserve) — จะไม่คืน memory ให้ OS ถ้าต่ำกว่า
  4. Resource Governor: Classifier Function → Workload Groups → Resource Pools (กำหนด MIN/MAX %)
  5. Use case: ป้องกัน Report ขนาดใหญ่แย่ง Memory จนกระทบ Transaction หลัก (เช่น ReportPool MAX 40%)
  6. SQL Server 2025 Standard: buffer pool สูงสุด 256 GB ต่อ instance (เพิ่มจาก 128 GB ใน 2022)
- **ภาพ/แผนภาพ:** ไม่บังคับ — ถ้าใส่ตารางเทียบ Resource Pools ให้ใช้ shape บน layout 04 (ห้ามแก้ potx)
- **Speaker notes:** ตัวเลข 256 GB (bullet 6) ยังไม่นำขึ้น layout `07 Stat Callout` จนกว่าจะมี sign-off รันจริงบน 17.x ตาม spec §4.6 Ref: `Module_04_Memory/Sections/02_SQL_Server_Memory/README.md:121-187` · `Module_04_Memory/README.md:61-63`
- **Script:** —

### สไลด์ 11: Section Divider — Section 3: Memory Pressure Diagnostics
- **Layout:** `section-divider` → potx `02 Module Divider (dark)`
- **Bullets:**
  1. เป้าหมาย 1: ใช้ Key Indicators ชี้ Memory Pressure — Buffer Cache Hit Ratio / Page Life Expectancy / Wait Types
  2. เป้าหมาย 2: วิเคราะห์ด้วย DMVs และ Ring Buffer ของ Resource Monitor
  3. เป้าหมาย 3: เข้าใจ Memory Grant Feedback และการวัดยุคใหม่ — ไม่ตัดสินจาก PLE ตัวเดียว
- **ภาพ/แผนภาพ:** ไม่ใช้
- **Speaker notes:** ต้องรู้มาก่อน: Buffer Pool / Memory Clerks จาก Section 2 และแนวคิด wait type จาก Module 1 — ชี้ลิงก์ Glossary กลาง (ยังไม่มีไฟล์) Ref: `Module_04_Memory/Sections/03_Memory_Pressure_Diagnostics/README.md`
- **Script:** —

### สไลด์ 12: Key Indicators — Buffer Cache Hit Ratio / PLE / Wait Types
- **Layout:** `bullets+diagram` → potx `03 Content`
- **Bullets:**
  1. **Buffer Cache Hit Ratio**: อัตราการอ่านเจอจาก cache — ควร > 90–95% สำหรับ OLTP
  2. **Page Life Expectancy (PLE)**: อายุเฉลี่ยของ page ใน memory (วินาที) — pattern Sawtooth / trend ตก = Memory Pressure
  3. อ่าน PLE ให้ถูกวิธี: ดูต่อ NUMA node และเทียบกับ baseline — อย่าใช้เกณฑ์ 300 วินาทีเดิมบนเครื่อง RAM หลายสิบ GB
  4. อย่าตัดสินจาก PLE ตัวเดียว: ดูคู่กับ Page Reads/Writes/sec, page faults ของ process และ waits — `RESOURCE_SEMAPHORE` (รอ Memory Grant), `CMEMTHREAD` (แย่ง memory object)
- **ภาพ/แผนภาพ:** วาดใหม่ PNG ≥2400px → `Module_04_Memory/Sections/03_Memory_Pressure_Diagnostics/images/memory-pressure-indicators.png` (redraw จาก mermaid 4.1 ใน README บรรทัด 7–57)
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม**: เกณฑ์ตัดสินต่อประเภท workload และวิธีเก็บ baseline (แล็บส่งเรื่อง baseline ต่อไปยัง Lab 10 ตาม `Labs/README.md:101`) Ref: `Module_04_Memory/Sections/03_Memory_Pressure_Diagnostics/README.md:5-65` · `Module_04_Memory/README.md:69-72`
- **Script:** —

### สไลด์ 13: Demo — วิเคราะห์ Memory ด้วย DMVs + Resource Monitor Ring Buffer
- **Layout:** `demo` → potx `06 Code Lab`
- **Bullets:**
  1. ขั้น demo: เปิดหน้าต่าง workload ก่อน (`03_Workload_Buffer_Pool.sql` รัน ~5 นาที) → รัน `02_Memory_Analysis.sql` → ปิดท้ายดู ring buffer ด้วย `04_Resource_Monitor_Ring_Buffer.sql`
  2. อ่านผล: `MEMORYCLERK_SQLBUFFERPOOL` ควรเป็นตัวใหญ่สุด — clerk อื่นบวมผิดปกติ (เช่น `OBJECTSTORE_LOCK_MANAGER`) ให้ตามต่อ
  3. ใครกิน cache: `sys.dm_os_buffer_descriptors` จัดอันดับ cached pages ต่อ database
  4. Ring Buffer: Notification = `RESOURCE_MEMPHYSICAL_HIGH / LOW / STEADY` + ค่า Target/Committed ต่อ Memory Node
  5. Error ที่พบได้: ยังไม่ได้รับ `VIEW SERVER STATE` → permission denied ตอน query DMV (Msg 300) · รุ่นขั้นต่ำ: SQL Server 2019+ (แนะนำ 17.x)
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ (live demo) — ถ้าใส่ภาพผลลัพธ์ ต้องถ่ายใหม่จากการรันจริง 17.x ห้ามดึงจากเด็คเก่า
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน: DMV (dynamic management view = system view สำรวจสถานะ runtime ของ instance) และ XQuery `.value()` ที่ใช้อ่าน XML จาก `sys.dm_os_ring_buffers` · ไฟล์ทั้งสามยังไม่มี header `MinVersion:` (0/4 ไฟล์ของโมดูล — ต้องเติมตามเฟส 0 ก่อนประกอบเด็ค) Ref: `Module_04_Memory/Labs/README.md:24-101`
- **Script:** `Module_04_Memory/Sections/03_Memory_Pressure_Diagnostics/Scripts/02_Memory_Analysis.sql` · `Module_04_Memory/Sections/03_Memory_Pressure_Diagnostics/Scripts/04_Resource_Monitor_Ring_Buffer.sql` · `Module_04_Memory/Sections/02_SQL_Server_Memory/Scripts/03_Workload_Buffer_Pool.sql`

### สไลด์ 14: Demo — Memory Spill และ Memory Grant Feedback
- **Layout:** `demo` → potx `06 Code Lab`
- **Bullets:**
  1. ขั้น demo: เปิด "Include Actual Execution Plan" (Ctrl+M) → รัน sort บังคับ spill → เห็น warning ที่ Sort operator: "Operator used tempdb to spill data during execution"
  2. รันซ้ำ 1–2 ครั้ง: **Memory Grant Feedback** เรียนรู้จาก spill รอบก่อน — เช็ค `is_memory_grant_feedback_adjusted = 1` ใน `sys.query_store_plan` (feedback ถูก persist ตั้งแต่ SQL 2022)
  3. ดูคิวรอ grant: `sys.dm_exec_query_resource_semaphores` / `sys.dm_exec_query_memory_grants` — `total_waiter_count > 0` = มี query รอ grant (`RESOURCE_SEMAPHORE`)
  4. Error ที่พบได้: ลืมเปิด Ctrl+M → ไม่เห็น warning; Query Store ปิดอยู่ → ไม่มีแถวให้ join · รุ่นขั้นต่ำ: SQL Server 2019+ (สคริปต์ set COMPATIBILITY_LEVEL = 150 เอง)
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ (live demo)
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน: Memory Grant (พื้นที่ memory ที่ engine จองล่วงหน้าสำหรับ Sort/Hash) และ window function `ROW_NUMBER() OVER (ORDER BY …)` ที่แล็บ Exercise 3 ใช้ Ref: `Module_04_Memory/Labs/README.md:105-146` · `Module_04_Memory/Sections/02_SQL_Server_Memory/Scripts/01_Memory_Spill.sql`
- **Script:** `Module_04_Memory/Sections/02_SQL_Server_Memory/Scripts/01_Memory_Spill.sql`

### สไลด์ 15: Section Divider — Section 4: In-Memory OLTP (Hekaton)
- **Layout:** `section-divider` → potx `02 Module Divider (dark)`
- **Bullets:**
  1. เป้าหมาย 1: อธิบายสถาปัตยกรรม lock-free / latch-free และ optimistic concurrency control (MVCC)
  2. เป้าหมาย 2: เขียน Natively Compiled Stored Procedure ได้ พร้อมเงื่อนไขบังคับ 3 ข้อ
  3. เป้าหมาย 3: เลือก Durability (SCHEMA_AND_DATA vs SCHEMA_ONLY) และ Index type (Hash vs Bw-Tree) ให้ตรง workload
- **ภาพ/แผนภาพ:** ไม่ใช้
- **Speaker notes:** ต้องรู้มาก่อน: ศัพท์ MVCC / optimistic concurrency — ชี้ลิงก์ Glossary กลาง (ยังไม่มีไฟล์); concurrency เชิงลึกจะสอนต่อใน Module 5 · **ต้องเขียนเนื้อหาเพิ่ม**: section นี้สั้นสุดของโมดูล (49 บรรทัด) และยังไม่มี Scripts/ Ref: `Module_04_Memory/Sections/04_In_Memory_OLTP/README.md`
- **Script:** —

### สไลด์ 16: In-Memory OLTP Architecture — Lock-free & Native Compilation
- **Layout:** `bullets` → potx `03 Content`
- **Bullets:**
  1. **Lock-free / Latch-free Data Structures**: ใช้ Optimistic Concurrency Control (MVCC) ขจัดปัญหา Blocking/Locking
  2. **Native Compilation**: แปลง Stored Procedure เป็น DLL (Machine Code) ตอน create — ลด CPU instructions ตอนรัน
  3. ประสิทธิภาพสูงกว่า T-SQL แบบ interpreted 10x–100x สำหรับ logic ที่คำนวณมาก (ตามข้อมูลใน README ของ section)
  4. Pattern ที่เหมาะ: high-throughput insert + lookup — เช่น ETL staging, session store, IoT ingestion
  5. SQL Server 2025: ลบ memory-optimized container/filegroup ที่ว่างได้แล้ว — ปิดจุดอ่อน "เคยลอง Hekaton แล้วถอดไม่ได้"
- **ภาพ/แผนภาพ:** วาดใหม่ PNG ≥2400px → `Module_04_Memory/Sections/04_In_Memory_OLTP/images/hekaton-architecture.png` (เป้าหมายหัวข้อ: memory-optimized table → hash/Bw-Tree index → checkpoint file pairs — section ยังไม่มี mermaid ให้ redraw)
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม**: เพิ่ม data flow ของ Checkpoint File Pairs และข้อจำกัดของ memory-optimized table Ref: `Module_04_Memory/Sections/04_In_Memory_OLTP/README.md:5-9` · `Module_04_Memory/README.md:65-67`
- **Script:** —

### สไลด์ 17: Natively Compiled SP & Memory-Optimized Tables / Index
- **Layout:** `two-column` → potx `04 Two-Column`
- **Bullets (ซ้าย Natively Compiled SP / ขวา Tables & Index):**
  1. เงื่อนไขบังคับ: `WITH NATIVE_COMPILATION, SCHEMABINDING` + `EXECUTE AS OWNER` + `BEGIN ATOMIC WITH` (ระบุ TRANSACTION ISOLATION LEVEL = SNAPSHOT และ LANGUAGE)
  2. ผลของ SCHEMABINDING: ห้ามแก้ Table ที่ผูกไว้ จนกว่าจะ Drop Proc
  3. Durable (`SCHEMA_AND_DATA`): ข้อมูลคงอยู่ถาวร — มี Checkpoint File Pairs บน Disk
  4. Non-Durable (`SCHEMA_ONLY`): อยู่ใน Memory เท่านั้น สูญหายเมื่อ Restart — เหมาะกับ ETL Staging / Session State
  5. Index: **Hash Index** = equality search / **Bw-Tree** (memory-optimized nonclustered) = range scan
- **ภาพ/แผนภาพ:** ไม่บังคับ — อาจแทรกโค้ดย่อ `usp_InsertData` จาก README บรรทัด 19–32 บนคอลัมน์ซ้าย
- **Speaker notes:** **ต้องเขียนเนื้อหาเพิ่ม**: ตัวอย่าง natively compiled proc ควรย้ายลง `Scripts/` ของ section นี้ด้วย Ref: `Module_04_Memory/Sections/04_In_Memory_OLTP/README.md:11-43`
- **Script:** —

### สไลด์ 18: Demo — In-Memory OLTP: วัดความเร็ว 10,000 Inserts (Lab Exercise 4)
- **Layout:** `demo` → potx `06 Code Lab`
- **Bullets:**
  1. ขั้น demo: เพิ่ม filegroup `CONTAINS MEMORY_OPTIMIZED_DATA` → สร้าง `dbo.MO_Sessions` (Hash index `BUCKET_COUNT = 100000`, `DURABILITY = SCHEMA_ONLY`)
  2. วัดผล: วน INSERT 10,000 แถว แล้วอ่านค่า `DATEDIFF(..., MILLISECOND)` เป็น insert_10k_ms
  3. สังเกต: SCHEMA_ONLY → ตารางหายเมื่อ restart (สาธิตให้เห็นจริงได้)
  4. SQL Server 2025: ลบ memory-optimized filegroup ที่ว่างทิ้งได้ — ทางออกคนที่เคยลองแล้วเลิกใช้
  5. Error ที่พบได้: ลืมสร้าง filegroup ก่อน → CREATE TABLE fail; BUCKET_COUNT ตั้งต่ำเกิน → hash collision กระทบประสิทธิภาพ · รุ่นขั้นต่ำ: SQL Server 2019+ (ฟีเจอร์ลบ filegroup เฉพาะ 17.x)
- **ภาพ/แผนภาพ:** ไม่ใช้ภาพ (live demo)
- **Speaker notes:** ศัพท์/syntax ต้องรู้ก่อน: BUCKET_COUNT (จำนวน bucket ของ hash index) และ DURABILITY = SCHEMA_ONLY (ไม่เก็บข้อมูลข้าม restart) · **ต้องเขียนเนื้อหาเพิ่ม** + **ยังไม่มีไฟล์สคริปต์**: T-SQL ทั้งหมดฝังใน Labs/README.md Exercise 4 — ต้องแยกเป็น `Sections/04_In_Memory_OLTP/Scripts/01_InMemory_OLTP_Demo.sql` ตามแผนขยาย Scripts 2/4 → 4/4 ก่อนประกอบเด็ค Ref: `Module_04_Memory/Labs/README.md:150-183`
- **Script:** (ไม่มีไฟล์จริงใน `Sections/04_In_Memory_OLTP/Scripts/` — ใช้ T-SQL จาก `Module_04_Memory/Labs/README.md:154-181` ชั่วคราว พร้อมเงื่อนไขข้างต้น)

### สไลด์ 19: Lab 4 — Memory Pressure & Buffer Pool Analysis
- **Layout:** `lab` → potx `06 Code Lab`
- **Bullets:**
  1. **4 Exercise** (Exercise 4 optional) — งบเวลา 60 นาที (10:30–11:30)
  2. Ex1 สุขภาพ Memory: `sys.dm_os_sys_memory` → `sys.dm_os_process_memory` → Top 10 Memory Clerks
  3. Ex2 Buffer Pool ต่อ database: `sys.dm_os_buffer_descriptors` + object ที่ cache หนักสุด + PLE ต่อ NUMA node
  4. Ex3 จำลอง Memory Spill + Memory Grant Feedback + ดู resource semaphore
  5. Ex4 In-Memory OLTP: สร้าง `dbo.MO_Sessions` แล้ววัด 10k inserts
  6. Prereq: AdventureWorks2025 + `VIEW SERVER STATE` + SSMS 2 หน้าต่าง query — ปิดท้ายด้วย 3 คำถาม wrap-up และ Cleanup
  7. Error ที่พบได้: ไม่ได้รับ `VIEW SERVER STATE` → permission denied ตอน query DMV (Msg 300) · ลืมเปิด Ctrl+M (Ex3) → ไม่เห็น spill warning · Query Store ปิดอยู่ (Ex3) → ไม่มีแถวให้ join · ลืมสร้าง filegroup MEMORY_OPTIMIZED_DATA (Ex4) → CREATE TABLE fail · รุ่นขั้นต่ำ: **SQL Server 2019+** (แนะนำ 2025/17.x) — Memory Grant Feedback persist เฉพาะ 2022+ และฟีเจอร์ลบ filegroup ว่างเฉพาะ 17.x
- **ภาพ/แผนภาพ:** ไม่ใช้
- **Speaker notes:** แจ้งผู้เรียนล่วงหน้าว่าต้องรัน 4 Exercise; หัวใจของแล็บคือ Ex3 ซึ่งเชื่อม Memory Grant Feedback กลับไปที่ wait `RESOURCE_SEMAPHORE` ใน Section 3 Ref: `Module_04_Memory/Labs/README.md` · สคริปต์ประกอบจัดอยู่ใน `Sections/*/Scripts/` ของโมดูล
- **Script:** `Module_04_Memory/Sections/*/Scripts/` (4 ไฟล์ — รายไฟล์อ้างในสไลด์ 13, 14, 18)

### สไลด์ 20: สรุปโมดูล + ตรวจความเข้าใจ
- **Layout:** `summary` → potx `08 Closing (dark)`
- **Bullets:**
  1. เส้นทางโมดูล: Windows Memory → SQL Server Memory Architecture → Memory Pressure Diagnostics → In-Memory OLTP
  2. ตรวจตัวเอง 3 คำถาม: PLE คืออะไรและควรอ่านอย่างไร / LPIM มีประโยชน์อย่างไร / `RESOURCE_SEMAPHORE` บอกอะไร
  3. กติกาที่ต้องจำ: max server memory = Total RAM − (OS Reserved + Other Applications) และพิจารณา LPIM บน production
  4. ต่อไป: Module 5 Concurrency & Transactions — Lock Modes, Isolation Levels, ADR / Optimized Locking
- **ภาพ/แผนภาพ:** ไม่ใช้ — ใช้ background ของ layout 08
- **Speaker notes:** ใช้ 3 คำถาม FAQ ท้ายโมดูลเป็นการตรวจความเข้าใจ; quiz bank รายโมดูลเป็นงานเฟส 3 ของแผน — ยังไม่มีไฟล์ Ref: `Module_04_Memory/README.md:41-54` · `Trainer_Docs/Course_Guide_4Days.md:87-92`
- **Script:** —

---

## เงื่อนไขที่ต้องเกิดก่อนประกอบเด็คจริง (ช่องว่างที่ตรวจพบระหว่างเขียน)

| # | ช่องว่าง | หลักฐาน (รันจริง 2026-10-01) |
|---|----------|------------------------------|
| 1 | Glossary กลางยังไม่มี — notes ของสไลด์เริ่ม section (3, 7, 11, 15) อ้างลิงก์ไว้แบบ "รอ path" | แผนแม่บท §3/ภาคผนวก A: glossary = 0 ไฟล์ |
| 2 | ไฟล์ .sql ของโมดูลทั้ง 4 ยังไม่มี header `MinVersion:` — สไลด์ Code Lab ต้อง pull T-SQL จากไฟล์ที่ผ่าน header แล้วเท่านั้น (spec §4.6) | `grep -l "MinVersion" Module_04_Memory/Sections/*/Scripts/*.sql` = ไม่พบ |
| 3 | Section 4 ไม่มี `Scripts/` — สไลด์ 18 ยังอ้าง T-SQL ที่ฝังใน Labs/README.md อยู่ | `find Module_04_Memory -name "*.sql"` = 4 ไฟล์อยู่เฉพาะ Sections 02 และ 03 |
| 4 | `03_Workload_Buffer_Pool.sql:3,15` อ้าง `01_Buffer_Usage_By_DB.sql` และ `02_Page_Life_Expectancy.sql` ซึ่งไม่มีใน repo — ต้องสร้างหรือแก้คอมเมนต์ | `find . -name "01_Buffer_Usage_By_DB.sql" -o -name "02_Page_Life_Expectancy.sql"` = ไม่พบ |
| 5 | แผนภาพ 6 ชิ้นต้องวาดใหม่เป็น PNG ≥2400px (สไลด์ 5, 6, 8, 9, 12, 16) | `git ls-files "*.png"` = มีแค่ 2 ไฟล์ของ M1; ไม่มีโฟลเดอร์ images/ ใน Module_04_Memory |
| 6 | Section 1 (61 บรรทัด), 3 (75), 4 (49) ต้องขยายเนื้อหา — สไลด์ที่เกี่ยวระบุ "ต้องเขียนเนื้อหาเพิ่ม" ไว้แล้ว | `wc -l Module_04_Memory/Sections/*/README.md` = 61/325/75/49 |
| 7 | Heading เสีย `## ###` ที่ `Module_04_Memory/README.md:61` — เป็นงาน Blocking เฟส 0 (ไม่ใช่ของเด็ค แต่กระทบการอ้างอิง) | `grep -n "^## ###" Module_04_Memory/README.md` = 61 |
