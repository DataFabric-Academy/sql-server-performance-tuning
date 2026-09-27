[⬅ Module 2_](../../README.md) | Section 2/4 | ➡ ถัดไป: [IO Setup Best Practices](../03_IO_Setup_Best_Practices/README.md)

## Storage Solutions (Lesson 2)

### 3.1 Common Storage Architectures
1.  **DAS (Direct-Attached Storage)**: การเชื่อมต่อพื้นที่จัดเก็บข้อมูลโดยตรงกับ Server
    *   *Pros*: ความซับซ้อนต่ำ, ได้ Bandwidth สูงสุด (Dedicated)
    *   *Cons*: ขยายตัวยาก (Scalability), ไม่สามารถแชร์ทรัพยากรได้
2.  **SAN (Storage Area Network)**: เครือข่ายจัดเก็บข้อมูลผ่าน Fiber Channel หรือ iSCSI
    *   *Pros*: แชร์พื้นที่ได้, รองรับ Snapshot/DR ระดับ Hardware
    *   *Cons*: ต้นทุนสูง, ต้องมีการบริหารจัดการ Bandwidth (QoS) เพื่อป้องกันปัญหา Noisy Neighbor
3.  **S3-Compatible Object Storage (SQL 2022+)**:
    *   SQL Server 2022 รองรับการ Backup/Restore หรือวาง Data File ลงบน Object Storage (เช่น AWS S3, Azure Blob) ผ่าน S3 API
    *   *Use Case*: เหมาะสำหรับการเก็บข้อมูลขนาดใหญ่ (Data Lake) หรือ Backup Storage ราคาประหยัด

---

---

[⬅ ก่อนหน้า](../../README.md) | [Module 2_ README](../../README.md) | ➡ ถัดไป: [IO Setup Best Practices](../03_IO_Setup_Best_Practices/README.md) | [🧪 Labs](../../Labs/README.md)
