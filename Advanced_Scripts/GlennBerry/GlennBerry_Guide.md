# SQL Server Diagnostic Information Scripts (Glenn Berry) - ฉบับภาษาไทย

โฟลเดอร์นี้แนะนำชุดสคริปต์ตรวจสุขภาพและวิเคราะห์ประสิทธิภาพ SQL Server ที่ได้รับการยอมรับอย่างกว้างขวางในวงการ DBA ทั่วโลก พัฒนาโดย **Glenn Berry** (Dr. DMV)

**Crucial Credit & Source**: [GlennSQLPerformance.com/resources](https://glennsqlperformance.com/resources/)

---

## ทำไมต้องใช้ Script ของ Glenn Berry?
สคริปต์ชุดนี้ (Diagnostic Information Queries) ถูกออกแบบมาให้:
1.  **Lightweight**: ไม่สร้างภาระให้ระบบ (Non-intrusive)
2.  **Comprehensive**: ครอบคลุมทุกด้านตั้งแต่ CPU, Memory, I/O, Index, จนถึง Configuration
3.  **Version Specific**: มีสคริปต์แยกตามเวอร์ชันของ SQL Server เพื่อความถูกต้องสูงสุดของ DMV

---

## วิธีการเลือกใช้งาน (Version Compatibility)

คุณต้องเลือกดาวน์โหลดไฟล์ **.sql** ให้ตรงกับเวอร์ชันของ SQL Server ที่คุณใช้งานอยู่ (ทุกรุ่นแนบ **spreadsheet ผลรัน .xlsx** ไว้ให้เทียบค่า baseline ได้ทันที):

### 1. SQL Server 2025 ⭐ (ใช้ในคอร์สนี้)
*   **เหมาะสำหรับ**: SQL Server 2025 (GA พฤศจิกายน 2025) — มีสคริปต์เฉพาะรุ่นแล้ว
*   **Link**: [SQL Server 2025 Diagnostic Scripts](https://glennsqlperformance.com/resources/) (มองหาหัวข้อ SQL Server 2025)

### 2. SQL Server 2022
*   **เหมาะสำหรับ**: SQL Server 2022 (RTM หรือ Cumulative Update ล่าสุด — เช่น CU23 จากมกราคม 2026 ตามที่ Glenn ติดตามในบล็อก)
*   **Link**: [SQL Server 2022 Diagnostic Scripts](https://glennsqlperformance.com/resources/)

### 3. SQL Server 2019
*   **เหมาะสำหรับ**: SQL Server 2019
*   **Link**: [SQL Server 2019 Diagnostic Scripts](https://glennsqlperformance.com/resources/)

### 4. SQL Server 2016 / 2017 (Legacy)
*   มีแยกไฟล์เฉพาะสำหรับแต่ละเวอร์ชัน (2017, 2016 SP2, 2016 SP1) — กรณีดูแลระบบเก่าที่ยังไม่ย้ายขึ้น

### 5. Azure SQL Database / Managed Instance
*   มีสคริปต์แยกต่างหากทั้งสองแบบ เนื่องจากบาง DMV ไม่สามารถเข้าถึงได้เหมือน On-Premise

> **Note**: นอกจากไฟล์ .sql แล้ว ยังมี **Jupyter Notebooks (.ipynb)** สำหรับบางรุ่นที่จัดรูปแบบผลลัพธ์และเพิ่มคำอธิบายเพิ่มจากเวอร์ชันปกติ

---

## อัปเดตล่าสุด (Stay Current)

- **อัปเดตรายเดือน**: Glenn เผยแพร่เวอร์ชันปรับปรุงทุกเดือนในบล็อก ภายใต้ชื่อ *SQL Server Diagnostic Information Queries for <เดือน/ปี>* (เช่น [ฉบับมกราคม 2026](https://glennsqlperformance.com/2026/01/02/sql-server-diagnostic-information-queries-for-january-2026)) — สคริปต์ของ SQL Server 2025 ได้รับการเพิ่มเติม/แก้ไขต่อเนื่องตั้งแต่เปิดตัว
- **ควรดาวน์โหลดใหม่ทุก 3–6 เดือน** เพราะสคริปต์ถูกแก้ให้ตรงกับ DMV ที่เปลี่ยนตาม Cumulative Update ใหม่
- **วิดีโอสอนอ่านผล**: มีชุดวิดีโอ YouTube บนช่องของ Glenn อธิบายวิธีตีความผลลัพธ์ทีละ query (ค้นว่า "Glenn Berry Diagnostic Queries" บน YouTube)

---

## วิธีการรัน (How to Execute)

1.  เปิดไฟล์ Script ใน **SQL Server Management Studio (SSMS)**
2.  กด `Ctrl + T` เพื่อแสดงผลลัพธ์เป็น Text (Optional: หรือ Grid `Ctrl + D` ตามถนัด แต่มักแนะนำ Grid สำหรับอ่านง่าย)
3.  **สำคัญ**: สคริปต์ของ Glenn มักจะมีหลาย Query ในไฟล์เดียว
    *   **วิธีที่ 1**: รันทั้งหมด (Execute) แล้วดูผลลัพธ์ทีละตาราง
    *   **วิธีที่ 2 (แนะนำ)**: Highlight รันทีละ Query ที่สนใจ อ่านคำอธิบาย (Comment) ด้านบนของแต่ละ Query เพื่อเข้าใจความหมาย

## ตัวอย่าง Query ที่สำคัญในชุดนี้
*   **Wait Statistics**: บอกว่า Server รออะไรอยู่ (Network, Disk, CPU?)
*   **CPU Utilization History**: กราฟการใช้ CPU ย้อนหลัง 256 นาที
*   **Top Worker Time Queries**: หา Query ที่กิน CPU สูงสุด
*   **Missing Indexes**: แนะนำ Index ที่ควรสร้าง
*   **Database File Latency**: ตรวจสอบความช้าของ Disk แยกตามไฟล์

---

## การอ้างอิงและเครดิต (Credits)
สคริปต์ทั้งหมดเป็นลิขสิทธิ์และผลงานของ **Glenn Berry**
ทางผู้จัดทำคอร์สแนะนำให้ตรวจสอบการอัปเดตล่าสุดจากเว็บไซต์ต้นทางเสมอ เพื่อให้ได้สคริปต์ที่ Updated ตาม Patch ล่าสุดของ Microsoft

> **Note**: ผู้เรียนควรเคารพ License และให้เครดิตผู้พัฒนาเมื่อนำไปใช้งานต่อ
