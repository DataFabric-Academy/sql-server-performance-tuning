[⬅ Module 2_](../../README.md) | Section 4/4

## Monitoring & Troubleshooting

### 5.1 Measuring Performance (Latency is King)
ดัชนีชี้วัดที่สำคัญที่สุดคือ **Avg. Disk sec/Transfer** (PerfMon) หรือ `io_stall` (DMVs)

**Log File (.ldf) Latency:**
*   **1-5 ms**: ประสิทธิภาพสูงสุด (Optimal) - Log File ต้องการ Latency ต่ำที่สุดเพราะเป็น Sequential Write ที่สำคัญต่อ Transaction Performance
*   **5-10 ms**: ยอมรับได้ (Acceptable) แต่ควรพิจารณา Optimize
*   **> 10 ms**: เริ่มพบปัญหาประสิทธิภาพ (Degraded) - Transaction Commit อาจช้าลง
*   **> 50 ms**: วิกฤต (Critical) - ผู้ใช้งานจะพบปัญหา Timeout หรือ Transaction Blocking

**Data File (.mdf) Latency:**
*   **< 5 ms**: ประสิทธิภาพสูง (SSD/NVMe level)
*   **10-20 ms**: ยอมรับได้ (Acceptable) สำหรับ Data File
*   **> 20 ms**: เริ่มพบปัญหาประสิทธิภาพ (Degraded)
*   **> 100 ms**: วิกฤต (Critical) ผู้ใช้งานจะพบปัญหา Timeout หรือ System Freeze

### 5.2 DMVs: `sys.dm_io_virtual_file_stats`
DMV นี้ให้ข้อมูลประสิทธิภาพระดับไฟล์ (Granular level) ช่วยระบุได้ว่าไฟล์ใดมี response time สูงสุด

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 2_ README](../../README.md) | [🧪 Labs](../../Labs/README.md)
