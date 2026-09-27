[⬅ Module 4_](../../README.md) | Section 3/4 | ➡ ถัดไป: [In Memory OLTP](../04_In_Memory_OLTP/README.md)

## Investigating Memory Pressure

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

---

[⬅ ก่อนหน้า](../../README.md) | [Module 4_ README](../../README.md) | ➡ ถัดไป: [In Memory OLTP](../04_In_Memory_OLTP/README.md) | [🧪 Labs](../../Labs/README.md)
