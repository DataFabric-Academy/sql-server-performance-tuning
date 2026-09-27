[⬅ Module 4_](../../README.md) | Section 2/4 | ➡ ถัดไป: [Memory Pressure Diagnostics](../03_Memory_Pressure_Diagnostics/README.md)

## SQL Server Memory (Lesson 2)

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
        > `../03_Memory_Pressure_Diagnostics/Scripts/04_Resource_Monitor_Ring_Buffer.sql`

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

---

[⬅ ก่อนหน้า](../../README.md) | [Module 4_ README](../../README.md) | ➡ ถัดไป: [Memory Pressure Diagnostics](../03_Memory_Pressure_Diagnostics/README.md) | [🧪 Labs](../../Labs/README.md)
