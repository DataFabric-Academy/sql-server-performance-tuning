# Module 4: SQL Server Memory

## 1. บทนำ (Introduction)
หน่วยความจำ (Memory) เป็นทรัพยากรที่สำคัญที่สุดสำหรับ SQL Server เนื่องจากการเข้าถึงข้อมูลใน RAM มีความเร็วกว่า Disk หลายพันเท่า การบริหารจัดการ Memory ที่มีประสิทธิภาพจึงเป็นหัวใจสำคัญของการปรับปรุงประสิทธิภาพระบบ (Performance Tuning)

ในบทเรียนนี้ ผู้เรียนจะศึกษาโครงสร้าง Memory Architecture ของ SQL Server, การตั้งค่าที่เหมาะสม, และการวิเคราะห์ปัญหา Memory Pressure

### 1.1 Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – เข้าใจ Virtual/Physical Memory และ NUMA**
  - อธิบาย Virtual Address Space, Paging, NUMA Node, Local/Remote Memory ได้
- **ระดับ 2 – อ่านโครงสร้าง Memory ภายใน SQL Server**
  - เข้าใจ Buffer Pool, Memory Clerks ต่างๆ, Resource Monitor และ Target/Committed Memory
- **ระดับ 3 – ตั้งค่า Memory ได้อย่างปลอดภัย**
  - คำนวณและกำหนด `max server memory`, ตัดสินใจใช้ LPIM และ Resource Governor ตามแนวทางจาก Performance Center และ Architecture Guide ได้
- **ระดับ 4 – วินิจฉัย Memory Pressure ได้จาก DMVs/Waits**
  - ใช้ `sys.dm_os_process_memory`, `sys.dm_os_memory_clerks`, PLE, และ Wait Types เช่น `RESOURCE_SEMAPHORE` เพื่อหาสาเหตุและออกแบบแนวทางแก้ไขได้อย่างเป็นขั้นตอน

---

---

## 2. Windows Memory (Lesson 1)

### 2.1 Virtual Address Space (VAS)
พื้นที่ Address ที่ Process สามารถมองเห็นและใช้งานได้ ซึ่งแยกอิสระจาก Physical RAM
*   **32-bit Systems**: มีข้อจำกัดสูง (max 4GB) ปัจจุบันไม่แนะนำให้ใช้งาน
*   **64-bit Systems**: รองรับ VAS ขนาดมหาศาล (8TB - 128TB) ทำให้ข้อจำกัดเรื่อง Address Space หมดไป

### 2.2 Physical vs Virtual Memory
*   **Physical Memory**: หน่วยความจำหลัก (RAM)
*   **Virtual Memory**: กลไกของ OS ที่ใช้ Disk (Page File) มาขยายพื้นที่หน่วยความจำ
    *   *Paging*: กระบวนการย้าย Data Pages ระหว่าง RAM และ Disk
    *   *Impact*: หาก Windows ทำการ Paging Process ของ SQL Server จะส่งผลกระทบต่อประสิทธิภาพอย่างรุนแรง (Performance Degradation)

### 2.3 NUMA (Non-Uniform Memory Access)

```mermaid
flowchart TB
    subgraph Node0["NUMA Node 0"]
        CPU0A["CPU 0"]
        CPU0B["CPU 1"]
        LocalMem0["Local Memory<br/>Fast ~100ns"]
        CPU0A <--> LocalMem0
        CPU0B <--> LocalMem0
    end
    
    subgraph Node1["NUMA Node 1"]
        CPU1A["CPU 2"]
        CPU1B["CPU 3"]
        LocalMem1["Local Memory<br/>Fast ~100ns"]
        CPU1A <--> LocalMem1
        CPU1B <--> LocalMem1
    end
    
    subgraph SQLServer2["SQL Server Schedulers"]
        Scheduler0["Scheduler 0"]
        Scheduler1["Scheduler 1"]
    end
    
    LocalMem0 <-.->|Remote<br/>200-300ns| LocalMem1
    
    Scheduler0 -->|Allocates| LocalMem0
    Scheduler1 -->|Allocates| LocalMem1
    
    style LocalMem0 fill:#3b82f6,stroke:#2563eb,stroke-width:3px,color:#fff
    style LocalMem1 fill:#3b82f6,stroke:#2563eb,stroke-width:3px,color:#fff
    style Scheduler0 fill:#10b981,stroke:#059669,stroke-width:2px,color:#fff
    style Scheduler1 fill:#10b981,stroke:#059669,stroke-width:2px,color:#fff
```

สถาปัตยกรรมที่ออกแบบมาเพื่อลดคอขวดของ Memory Bus ในระบบที่มี CPU จำนวนมาก
*   **Local Memory**: หน่วยความจำที่เชื่อมต่อกับ CPU Node นั้นๆ โดยตรง (Access เร็วที่สุด)
*   **Remote Memory**: หน่วยความจำที่อยู่ต่าง Node (Access ช้ากว่า)
*   *SQL Server Awareness*: Engine จะพยายามจัดสรร Memory ใน Node เดียวกับที่ Thread ทำงานเสมอ

---

## 3. SQL Server Memory (Lesson 2)

### 3.1 Memory Models

```mermaid
flowchart TB
    subgraph Conventional["1. Conventional"]
        direction TB
        C1["Dynamic Allocation"]
        C2["OS สามารถ Paging ได้"]
        C3["เสี่ยง Performance Degradation"]
        C1 --> C2 --> C3
    end
    
    subgraph LPIM["2. LPIM"]
        direction TB
        L1["Windows Policy: Lock Pages"]
        L2["ป้องกัน Paging ลง Disk"]
        L3["เสถียรภาพสูง"]
        L1 --> L2 --> L3
    end
    
    subgraph LargePage["3. Large Page"]
        direction TB
        LP1["ใช้ 2MB Pages แทน 4KB"]
        LP2["ลด TLB Overhead"]
        LP3["Static Allocation Startup ช้า"]
        LP1 --> LP2 --> LP3
    end
    
    OS2["Windows OS"]
    
    C3 --> OS2
    L3 -.->|Lock| OS2
    LP3 --> OS2
    
    Conventional -.->| | LPIM
    LPIM -.->| | LargePage
    
    style Conventional fill:#fbbf24,stroke:#f59e0b,stroke-width:2px
    style LPIM fill:#10b981,stroke:#059669,stroke-width:3px,color:#fff
    style LargePage fill:#8b5cf6,stroke:#7c3aed,stroke-width:2px,color:#fff
    style OS2 fill:#64748b,stroke:#475569,stroke-width:2px,color:#fff
```

**รายละเอียด:**
1.  **Conventional Memory Model**: รูปแบบมาตรฐาน (Dynamic Allocation) OS สามารถทำ Paging ได้
2.  **Locked Memory Model (LPIM)**: การกำหนดสิทธิ์ **Lock Pages in Memory**
    *   ป้องกันไม่ให้ Windows นำ SQL Server Memory ไปทำ Paging ลง Disk
    *   *Recommendation*: ควรเปิดใช้งานเสมอสำหรับ Production Server เพื่อเสถียรภาพ
3.  **Large Page Memory Model**: การใช้ Memory Page ขนาดใหญ่ (2MB) แทนขนาดปกติ (4KB)
    *   *Benefit*: ลด Overhead ของ Translation Look-aside Buffer (TLB)
    *   *Drawback*: ต้องจองพื้นที่ทั้งหมดตั้งแต่ Startup (Static Allocation) อาจทำให้เปิด Service ช้า

### 3.2 SQL Server Memory Architecture

```mermaid
flowchart TB
    subgraph OS["Windows OS"]
        PhysicalRAM["Physical RAM"]
        PageFile["Page File (virtual memory)"]
    end
    
    SpacerA[ ]
    
    MemoryAllocator["Memory Allocator<br/>Any Size Page Allocator"]
    
    SpacerB[ ]
    
    subgraph BPool["Buffer Pool"]
        DataPages["Data Pages 8KB"]
        IndexPages["Index Pages 8KB"]
    end
    
    SpacerC[ ]
    
    subgraph OtherClerks["Other Memory Clerks"]
        PlanCache["Plan Cache"]
        ConnectionPool["Connection Pool"]
        LockManager["Lock Manager"]
        WorkspaceGrant["Workspace Memory"]
    end
    
    MTL["Memory To Leave"]
    
    SpacerD[ ]
    
    ResourceMonitor["Resource Monitor<br/>Background Thread"]
    
    PhysicalRAM -->|Allocate| MemoryAllocator
    MemoryAllocator --> BPool
    MemoryAllocator --> OtherClerks
    MemoryAllocator --> MTL
    
    ResourceMonitor -->|Monitor| PhysicalRAM
    ResourceMonitor -->|Trim Caches| MemoryAllocator
    
    OS -.->|LPIM| MemoryAllocator
    
    style BPool fill:#2563eb,stroke:#1e40af,stroke-width:3px,color:#fff
    style OtherClerks fill:#059669,stroke:#047857,stroke-width:2px,color:#fff
    style MTL fill:#ea580c,stroke:#c2410c,stroke-width:2px,color:#fff
    style ResourceMonitor fill:#7c3aed,stroke:#6d28d9,stroke-width:2px,color:#fff
    style MemoryAllocator fill:#dc2626,stroke:#991b1b,stroke-width:2px,color:#fff
    style SpacerA fill:transparent,stroke:transparent,color:transparent
    style SpacerB fill:transparent,stroke:transparent,color:transparent
    style SpacerC fill:transparent,stroke:transparent,color:transparent
    style SpacerD fill:transparent,stroke:transparent,color:transparent
```

**โครงสร้างหลัก:**
*   **Memory Allocator**: ตัวจัดการการของหน่วยความจำจาก OS
*   **Memory Clerks**: ส่วนประกอบที่ทำหน้าที่ดูแลหน่วยความจำแต่ละประเภท
    *   *SQLBUFFERPOOL*: จัดการ Data Pages (Cache หลัก)
    *   *SQLQUERYPLAN*: จัดการ Plan Cache
    *   *SQLCONNECTIONPOOL*: จัดการ Connection Context
*   **Memory To Leave (MTL)**: พื้นที่หน่วยความจำที่ SQL Server เว้นไว้สำหรับ Process ภายนอก Loop (Non-BPool)

### 3.3 Configuration Best Practices
*   **Min Server Memory**: ค่าต่ำสุดที่ SQL Server จะรักษาไว้ (Reserve) -> จะไม่คืน memory ให้ OS ถ้าต่ำกว่าค่านี้
*   **Max Server Memory**: ค่าสูงสุดที่ SQL Server สามารถใช้งานได้ (Buffer Pool & Caches) -> **Critical Setting**
    *   *Calculation*: Total RAM - (OS Reserved + Other Applications)
    *   *Note*: ไม่ครอบคลุม Thread Stacks และ CLR allocations บางส่วน

---

### 3.4 Resource Governor

```mermaid
flowchart TB
    CF["Classifier Function<br/>Route Sessions"]
    
    SpacerRG1[ ]
    
    subgraph WorkloadGroups["Workload Groups"]
        WG1["internal"]
        WG2["default"]
        WG3["ReportUsers"]
        WG4["ETLUsers"]
    end
    
    SpacerRG2[ ]
    
    subgraph ResourcePools["Resource Pools"]
        RP1["internal<br/>MIN: 0% MAX: 100%"]
        RP2["default<br/>MIN: 0% MAX: 100%"]
        RP3["ReportPool<br/>MIN: 10% MAX: 40%"]
        RP4["ETLPool<br/>MIN: 20% MAX: 50%"]
    end
    
    SpacerRG3[ ]
    
    TotalMem["Total Available Memory"]
    
    CF --> WG1
    CF --> WG2
    CF --> WG3
    CF --> WG4
    
    WG1 --> RP1
    WG2 --> RP2
    WG3 --> RP3
    WG4 --> RP4
    
    TotalMem --> RP1
    TotalMem --> RP2
    TotalMem --> RP3
    TotalMem --> RP4
    
    style SpacerRG1 fill:transparent,stroke:transparent,color:transparent
    style SpacerRG2 fill:transparent,stroke:transparent,color:transparent
    style SpacerRG3 fill:transparent,stroke:transparent,color:transparent
    
    style RP3 fill:#f59e0b,stroke:#d97706,stroke-width:3px,color:#fff
    style RP4 fill:#8b5cf6,stroke:#7c3aed,stroke-width:3px,color:#fff
    style RP1 fill:#6b7280,stroke:#4b5563,stroke-width:2px,color:#fff
    style RP2 fill:#6b7280,stroke:#4b5563,stroke-width:2px,color:#fff
    style CF fill:#06b6d4,stroke:#0891b2,stroke-width:2px,color:#fff
    style TotalMem fill:#84cc16,stroke:#65a30d,stroke-width:2px,color:#000
```

เครื่องมือสำหรับจำกัดและจัดสรรทรัพยากร (CPU, Memory, I/O) ให้กับ Workload แต่ละประเภท
*   **Workload Group**: กลุ่มของผู้ใช้งาน (เช่น Report Users, Data Load Users)
*   **Resource Pool**: การกำหนดโควต้าทรัพยากร (MIN/MAX Usage)
    *   *Use Case*: ป้องกันไม่ให้ Report ขนาดใหญ่แย่ง Memory จนกระทบต่อระบบ Transaction หลัก

### 3.5 Buffer Pool (The Cache)

**Buffer Pool** คือพื้นที่ใน Memory ที่ SQL Server ใช้เก็บ **Data Pages** (หน่วยข้อมูลขนาด 8KB) ที่อ่านมาจาก Disk เพื่อลดการเข้าถึง Disk ซ้ำๆ

> **ทำไมสำคัญ?** การอ่านจาก Memory (~100 ns) เร็วกว่า Disk (~10 ms) ประมาณ **100,000 เท่า** ดังนั้น "ยิ่งข้อมูลอยู่ใน Buffer Pool มากเท่าไร ยิ่งเร็ว"

**สถาปัตยกรรม Buffer Pool:**

```mermaid
flowchart TB
    subgraph SQLServerMemory["SQL Server Memory"]
        subgraph BufferPool["Buffer Pool"]
            direction LR
            P1["Page 8KB Clean"]
            P2["Page 8KB Clean"]
            P3["Page 8KB Dirty"]
            P4["Page 8KB Dirty"]
            P5["Page 8KB Clean"]
            
            P1 -.->|Modified| P3
            P4 -.->|Checkpoint| P2
        end
        
        Spacer1[ ]
        
        subgraph MemoryClerks["Memory Clerks"]
            MC1["SQLQUERYPLAN"]
            MC2["SQLCONNECTIONPOOL"]
            MC3["OBJECTSTORE"]
            MC4["WORKSPACE"]
        end
        
        MTL["Memory To Leave"]
    end
    
    Spacer2[ ]
    
    LW["Lazy Writer<br/>Evict Unused Pages<br/>LRU Algorithm"]
    CP["Checkpoint<br/>Write Dirty Pages to Disk"]
    
    Spacer3[ ]
    
    DataFiles["Data Files<br/>Disk Storage"]
    
    BufferPool -->|Evict| LW
    BufferPool -->|Write| CP
    CP -->|Persist| DataFiles
    DataFiles -->|Physical Read| BufferPool
    
    SQLServerMemory --> MemoryClerks
    SQLServerMemory --> MTL
    
    style BufferPool fill:#4a90e2,stroke:#2c5282,stroke-width:3px,color:#fff
    style MemoryClerks fill:#38a169,stroke:#2f855a,stroke-width:2px,color:#fff
    style MTL fill:#ed8936,stroke:#c05621,stroke-width:2px,color:#fff
    style LW fill:#e53e3e,stroke:#c53030,stroke-width:2px,color:#fff
    style CP fill:#d69e2e,stroke:#b7791f,stroke-width:2px,color:#fff
    style DataFiles fill:#9333ea,stroke:#7e22ce,stroke-width:2px,color:#fff
    style Spacer1 fill:transparent,stroke:transparent,color:transparent
    style Spacer2 fill:transparent,stroke:transparent,color:transparent
    style Spacer3 fill:transparent,stroke:transparent,color:transparent
```

**กระบวนการทำงาน:**
*   **Page Request**: เมื่อ Query ต้องการข้อมูล → ตรวจสอบ Buffer Pool ก่อน → ถ้าไม่มี → อ่านจาก Disk (Physical Read)
*   **Lazy Writer**: เมื่อ Memory เริ่มเต็ม จะลบ Page ที่ไม่ได้ใช้นานออก (LRU Algorithm)
*   **Checkpoint**: บันทึก Dirty Pages (หน้าที่ถูกแก้ไขแล้ว) ลง Disk เป็นระยะ

### 3.6 Other Memory Clerks
นอกจาก Buffer Pool แล้ว ยังมีการใช้ Memory ในส่วนอื่นๆ:
*   **CACHESTORE_SQLCP**: Plan Cache (เก็บ Execution Plans)
*   **OBJECTSTORE_LOCK_MANAGER**: เก็บโครงสร้าง Lock (Lock Structures)
*   **MEMORYCLERK_SQLCONNECTIONPOOL**: เก็บ Connection objects
*   **WORKSPACE_MEMORY_GRANT**: พื้นที่สำหรับ Query Operation (Sort/Hash)

### 3.7 Deep Dive: Memory Management Internals (from Architecture Guide)
ข้อมูลเชิงลึกสำหรับการจัดการหน่วยความจำของ SQL Server ยุคใหม่ (SQL 2012+):

1.  **"Any Size" Page Allocator**:
    *   *Legacy (Pre-2012)*: แยกจัดการระหว่าง Single-Page (<=8KB) และ Multi-Page (>8KB) โดย Max Server Memory คุมแค่ Single-Page
    *   *Modern*: รวมทุก Allocator เข้าด้วยกัน ดังนั้น **Max Server Memory** จึงควบคุมการใช้ Memory เกือบทั้งหมดของ SQL Server (รวม CLR, Multi-Page)
    
2.  **Memory Pressure Detection (Resource Monitor)**:
    *   SQL Server มี Background Thread ชื่อ **Resource Monitor** คอยตรวจสอบสัญญาณหน่วยความจำจาก Windows:
        *   `RESOURCE_MEMPHYSICAL_HIGH`: สภาวะปกติ -> ขยาย Memory ได้เต็มที่
        *   `RESOURCE_MEMPHYSICAL_LOW`: ระบบขาดแคลน Memory -> SQL Server จะเริ่ม **Trim Caches** และคืน Memory ให้ OS
        *   `RESOURCE_MEMPHYSICAL_STEADY`: ทรงตัว
        
        > [!TIP]
        > ดูประวัติการทำงานของ Resource Monitor ได้ด้วย Script:
        > `Scripts\03_Resource_Monitor_Ring_Buffer.sql`

3.  **Dynamic Memory Management**:

```mermaid
sequenceDiagram
    participant Query as Query Request
    participant BP as Buffer Pool
    participant RM as Resource Monitor
    participant OS as Windows OS
    
    Note over Query,OS: Normal Operation (RESOURCE_MEMPHYSICAL_HIGH)
    Query->>BP: Check Page in Cache?
    alt Page Found (Cache Hit)
        BP-->>Query: Return Page (~100ns)
    else Page Not Found (Cache Miss)
        BP->>OS: Physical Read from Disk
        OS-->>BP: Return Page (~10ms)
        BP-->>Query: Return Page
    end
    
    Note over RM,OS: Memory Pressure Detection
    OS->>RM: Signal: RESOURCE_MEMPHYSICAL_LOW
    RM->>BP: Trim Caches (LRU)
    RM->>OS: Release Memory
    
    Note over BP,OS: Memory Management
    BP->>BP: Calculate Target Memory<br/>(Based on Available RAM)
    loop Ramp-up Phase
        BP->>OS: Request More Memory
        OS-->>BP: Grant Memory
        Note over BP: Committed < Target
    end
    
    Note over BP,OS: Steady State
    BP->>BP: Target Memory = Committed Memory
```

**หลักการทำงาน:**
    *   SQL Server ปรับขนาด Memory อัตโนมัติ โดยดูจาก **Target Memory** (เป้าหมายที่อยากได้) vs **Committed Memory** (ที่ขอ OS มาได้จริง)
    *   *Ramp-up*: ช่วงเริ่มต้น Service ที่จะทยอยขอ Memory จนถึง Target

---

## 4. Investigating Memory Pressure

### 4.1 Key Indicators

```mermaid
flowchart TB
    subgraph Row1[" "]
        direction LR
        subgraph Metric1["1. Buffer Cache Hit Ratio"]
            BCHR["Target: > 90-95%"]
            BCHRGood["✓ Cache Hit<br/>Memory"]
            BCHRBad["✗ Cache Miss<br/>Disk"]
            BCHR --> BCHRGood
            BCHR --> BCHRBad
        end
        
        subgraph Metric2["2. Page Life Expectancy"]
            PLENormal["Normal: เสถียร<br/>ค่าสูง เส้นราบ"]
            PLEPressure["Pressure: Sawtooth<br/>ค่าตก แนวโน้วลด"]
            PLENormal -.->|Memory Pressure| PLEPressure
        end
        
        subgraph WaitTypes["3. Wait Types"]
            WT1["RESOURCE_SEMAPHORE<br/>Wait Memory Grant"]
            WT2["CMEMTHREAD<br/>Thread Contention"]
        end
    end
    
    SpacerM1[ ]
    
    subgraph Monitoring["Monitoring Tools"]
        direction LR
        DMV1["dm_os_performance_counters<br/>Buffer Cache Hit Ratio"]
        DMV2["dm_os_performance_counters<br/>Page Life Expectancy"]
        DMV3["dm_os_wait_stats<br/>Wait Types"]
        DMV4["dm_os_memory_clerks<br/>Memory Usage"]
    end
    
    Metric1 --> DMV1
    Metric2 --> DMV2
    WaitTypes --> DMV3
    Metric1 --> DMV4
    Metric2 --> DMV4
    WaitTypes --> DMV4
    
    style BCHRGood fill:#10b981,stroke:#059669,stroke-width:2px,color:#fff
    style BCHRBad fill:#ef4444,stroke:#dc2626,stroke-width:2px,color:#fff
    style PLENormal fill:#10b981,stroke:#059669,stroke-width:2px,color:#fff
    style PLEPressure fill:#ef4444,stroke:#dc2626,stroke-width:2px,color:#fff
    style WT1 fill:#f59e0b,stroke:#d97706,stroke-width:2px,color:#fff
    style WT2 fill:#f59e0b,stroke:#d97706,stroke-width:2px,color:#fff
    style Row1 fill:transparent,stroke:transparent,color:transparent
    style Monitoring fill:#e0e7ff,stroke:#6366f1,stroke-width:2px
    style SpacerM1 fill:transparent,stroke:transparent,color:transparent
```

**รายละเอียด:**
1.  **Buffer Cache Hit Ratio**: อัตราการอ่านข้อมูลได้จาก Cache (ควร > 90-95% สำหรับ OLTP)
2.  **Page Life Expectancy (PLE)**: ค่าเฉลี่ยเวลาที่ Page อยู่ใน Memory (Unit: วินาที)
    *   *Trend*: หากค่าลดลงอย่างรวดเร็ว (Sawtooth pattern) บ่งชี้ถึงแรงกดดันด้าน Memory (Memory Pressure)
3.  **Wait Types**:
    *   `RESOURCE_SEMAPHORE`: Query ต้องรอ Memory Grant (Sort/Hash Workload มีมากเกินไป)
    *   `CMEMTHREAD`: การแย่งชิงเข้าถึง Memory Object (Thread Safety contention)

### 4.2 Modern Memory Feedback (SQL 2019/2022)
*   **Memory Grant Feedback**: SQL Server สามารถจดจำปริมาณ Memory ที่ Query เคยใช้จริง และปรับขนาด Grant ในครั้งถัดไปให้เหมาะสม (ลด Spill / ลด Wasted Memory)
*   **Persistence (SQL 2022)**: ข้อมูล Feedback ถูกบันทึกลง Query Store ทำให้จำค่าได้แม้ Restart Server

---

## 5. In-Memory OLTP (Hekaton) (Lesson 3)
เทคโนโลยีการจัดเก็บและประมวลผลข้อมูลในหน่วยความจำหลัก (Main Memory) เพื่อประสิทธิภาพสูงสุด

### 5.1 Architecture Highlights
*   **Lock-free / Latch-free Data Structures**: ใช้เทคโนโลยี *Optimistic Concurrency Control (MVCC)* ขจัดปัญหา Blocking/Locking
*   **Native Compilation**: แปลง Stored Procedure เป็น **DLL (Machine Code)** เพื่อลด CPU Instructions ในการประมวลผล

### 5.2 Natively Compiled Stored Procedures
คือ Stored Procedure ที่ถูก Compile เป็น Machine Code (C) ทันทีที่สร้าง (Create Time) แทนที่จะ Interpreted ตอนรัน

**ข้อกำหนด (Requirements):**
1.  **SCHEMABINDING**: ต้องผูกติดกับ Table (ห้ามแก้ Table ถ้าไม่ Drop Proc)
2.  **EXECUTE AS OWNER**: ต้องระบุ Context ผู้รัน
3.  **ATOMIC WITH**: ทั้งบล็อกถือเป็น Transaction เดียว (Atomic)

```sql
CREATE PROCEDURE dbo.usp_InsertData 
    @ID INT, 
    @Name NVARCHAR(50)
WITH NATIVE_COMPILATION, SCHEMABINDING
AS BEGIN ATOMIC WITH
(
    TRANSACTION ISOLATION LEVEL = SNAPSHOT, 
    LANGUAGE = N'us_english'
)
    INSERT INTO dbo.MyMemoryTable (ID, Name) 
    VALUES (@ID, @Name);
END;
```

> [!NOTE]
> ประสิทธิภาพสูงกว่า T-SQL ปกติ **10x - 100x** สำหรับ Logic ที่ซับซ้อนและการคำนวณ (Math/String)

### 5.3 Table Types
1.  **Durable (SCHEMA_AND_DATA)**: ข้อมูลคงอยู่ถาวร (มี Checkpoint File Pairs บน Disk)
2.  **Non-Durable (SCHEMA_ONLY)**: ข้อมูลอยู่ใน Memory เท่านั้น (สูญหายเมื่อ Restart) เหมาะสำหรับ ETL Staging หรือ Session State

### 5.4 Index Types for Memory-Optimized
*   **Hash Index**: เหมาะสำหรับการค้นหาแบบเท่ากับ (Equality Search)
*   **Memory-Optimized Non-Clustered Index (Bw-Tree)**: เหมาะสำหรับการค้นหาแบบช่วง (Range Scan)

---

## 6. Lab: Analyzing Memory Spills

**[ไปยังคำแนะนำแล็บ](Labs/README.md)**

ในแล็บนี้ คุณจะระบุ Memory Spills (Sort Warnings) ใน Execution Plans และสังเกตว่า Memory Grant Feedback ของ SQL Server แก้ไขปัญหาอัตโนมัติอย่างไร

### Exercise 1: Reconfigure SQL Server Memory
1.  **Execute Workload**: รัน Script จำลองการโหลดหนักๆ (PowerShell/SQLCMD)
2.  **Monitor Wait Stats**: สังเกต `sys.dm_os_wait_stats` ว่า `RESOURCE_SEMAPHORE` ขึ้นหรือไม่?
3.  **Fix Configuration**:
    *   ใช้ `sp_configure` ตั้งค่า `min server memory` และ `max server memory`
    *   *Example*: Set Max = 4096 MB (สำหรับเครื่อง Lab)
    *   *Command*:
        ```sql
        EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
        EXEC sp_configure 'max server memory (MB)', 4096; RECONFIGURE;
        ```
4.  **Verify**: รัน Workload เดิมอีกครั้ง แล้วดูว่า Wait หายไปหรือไม่ (ถ้า RAM พอควรจะหายไป)

### Exercise 2: Buffer Usage Analysis
*   ใช้ `01_Buffer_Usage_By_DB.sql` เพื่อดูว่าใครกินแรมไป

---

## 7. Review Quiz (Knowledge Check)

<details>
<summary><b>1. Page Life Expectancy (PLE) หมายถึงอะไร?</b></summary>
ค่าเฉลี่ยเวลาที่ Page อยู่ใน Buffer Pool (หน่วยเป็นวินาที) ถ้าค่าลดลงอย่างรวดเร็ว (รูปฟันเลื่อย) บ่งบอก Memory Pressure
</details>

<details>
<summary><b>2. Lock Pages in Memory (LPIM) มีประโยชน์อย่างไร?</b></summary>
ป้องกันไม่ให้ Windows นำ SQL Server Memory ไปทำ Paging ลง Disk ช่วยให้ระบบมีเสถียรภาพมากขึ้น
</details>

<details>
<summary><b>3. RESOURCE_SEMAPHORE wait type บอกอะไร?</b></summary>
บอกว่า Query ต้องรอ Memory Grant สำหรับ Sort/Hash Operation แสดงว่ามี Workload ที่ต้องการ Memory เยอะเกินไป
</details>

---

## 7. 🆕 Modernization Notes: SQL Server 2019 → 2025 (อัปเดตตาม Microsoft Learn)

### 7.1 ตัวเลข Memory ปัจจุบัน
- **SQL Server 2025 Standard edition: buffer pool สูงสุด 256 GB** ต่อ instance (เพิ่มจาก 128 GB ใน 2022) — วางแผน edition ตามขนาด working set ได้ง่ายขึ้น
- Standard Developer / Enterprise Developer editions (ฟรี ใช้พัฒนา) ให้ความจุเท่ารุ่นจ่ายเงิน — เหมาะกับการจำลอง Lab

### 7.2 In-Memory OLTP ปี 2025
- ตอนนี้ **ลบ memory-optimized container/filegroup ที่ว่างได้แล้ว (2025)** — แก้ปัญหา "เคยลอง Hekaton แล้วเลิกใช้ แต่ถอดไม่ได้" ปิดจุดอ่อนสุดท้ายของการนำไปใช้จริง
- ยังเหมาะกับ pattern: high-throughput insert + lookup (เช่น ETL staging, session store, IoT ingestion) — ไม่ใช่ยาแครามทุกปัญหา

### 7.3 การวัด Memory Pressure ยุคปัจจุบัน
- **อย่าตัดสินจาก PLE ตัวเดียว**: PLE เป็นค่ารวมทั้ง instance และแปรผันกับขนาด buffer pool — ต้องดูคู่กับ `Page reader/writer sec`, `MEMORYCLERK_SQLBUFFERPAGES`, page faults ของ process, และ wait `RESOURCE_SEMAPHORE` / `WRITE_PAGE` / `RESERVED_MEMORY_ALLOCATION_EXT`
- ดู memory ต่อ NUMA node (`sys.dm_os_memory_nodes`) ไม่ใช่แค่รวม
- PMEM/Hybrid Buffer Pool: เข้าถึง data page บน PMEM โดยตรง กระทบการตีความ `sys.dm_os_buffer_descriptors`

> อ้างอิง: [Memory Management Architecture Guide](https://learn.microsoft.com/sql/relational-databases/memory-management-architecture-guide), [What's new in SQL Server 2025](https://learn.microsoft.com/sql/sql-server/what-s-new-in-sql-server-2025)
