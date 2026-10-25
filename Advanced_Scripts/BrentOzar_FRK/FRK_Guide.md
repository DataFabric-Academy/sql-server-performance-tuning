# First Responder Kit (Brent Ozar) - ฉบับภาษาไทย

โฟลเดอร์นี้แนะนำชุดเครื่องมือตรวจวินิจฉัยประสิทธิภาพที่ถูกดาวน์โหลดและใช้งานมากที่สุดในวงการ SQL Server ทั่วโลก — **First Responder Kit (FRK)** พัฒนาและดูแลโดยทีม **Brent Ozar Unlimited** (Brent Ozar, Erik Darling และชุมชนผู้มีส่วนร่วม)

**Crucial Credit & Sources**:
- เว็บไซต์หลัก: [FirstResponderKit.org](https://www.firstresponderkit.org/)
- Source code: [GitHub: BrentOzarULTD/SQL-Server-First-Responder-Kit](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)
- หน้ารวมวิธีคิด: [Brent Ozar — SQL Server Performance Tuning](https://www.brentozar.com/sql/sql-server-performance-tuning/)

---

## แนวคิดการจูน 4 ขั้นของ Brent Ozar (Methodology)

FRK ถูกออกแบบให้เดินตามกระบวนการ **Measure → Optimize → Tune → Configure** — ซึ่งสอดคล้องตรงกับโครงของคอร์สนี้:

| ขั้น | แนวคิด | เครื่องมือในชุด | โมดูลที่เกี่ยวข้อง |
|:-----|:--------|:----------------|:-------------------|
| 1. **Measure** | วัดก่อนแก้เสมอ — อย่าเชื่อแค่คำบ่นของผู้ใช้ ให้ดู wait stats และ baseline | `sp_BlitzFirst`, `sp_BlitzWho` | Module 1, 10 |
| 2. **Optimize Queries** | หา query ที่กินทรัพยากรจาก **plan cache** (ไม่ใช่ SQL Profiler ซึ่งช้าและเปลือง) | `sp_BlitzCache`, `sp_QuickieStore` | Module 7, 8 |
| 3. **Tune Indexes** | แก้ด้วย nonclustered/covering index เมื่อไม่สามารถแก้ตัว query ได้ | `sp_BlitzIndex` | Module 6 |
| 4. **Tune Server Settings** | แก้ค่า default configuration (MAXDOP, Cost Threshold, MAX Server Memory) — บางกรณีได้ผล 20–30% โดยไม่ซื้อฮาร์ดแวร์ | `sp_Blitz` | Module 4, 11 |

---

## เครื่องมือในชุด (Core Scripts)

| Script | หน้าที่ | ใช้เมื่อไหร่ |
|:-------|:--------|:-------------|
| **sp_Blitz®** | ตรวจสุขภาพ Instance ทั้งหมด (Best Practice, Config ผิด, ความเสี่ยง) | ครั้งแรกที่เจอเซิร์ฟเวอร์ / ตรวจประจำ |
| **sp_BlitzFirst®** | "มาตรวัดความเร็ว" แบบ real-time — ตอนนี้เซิร์ฟเวอร์รออะไร กี่ % | มีคนแจ้ง "ระบบช้าตอนนี้" |
| **sp_BlitzCache®** | จัดอันดับ query ที่กินทรัพยากรสูงสุดจาก plan cache พร้อมธงเตือน (parameter sniffing, implicit conversion ฯลฯ) | จูนเชิงลึก / หา query ตัวร้าย |
| **sp_BlitzIndex®** | วิเคราะห์ index ทั้งหมด — missing, unused, duplicate, heap, over-indexing | วางแผน index / ลดภาระ write |
| **sp_BlitzWho** | ดู query ที่กำลังรันอยู่ ณ ขณะนี้ (ทางเลือก open source ของ sp_WhoIsActive) | ตาม session ที่กำลังทำปัญหา |
| **sp_BlitzLock** | ดึงและอธิบาย deadlock graph ย้อนหลังจาก system_health | หลังเกิด deadlock |

> หมายเหตุ: **sp_WhoIsActive** (ของ Adam Machanic) มักถูกใช้คู่กับชุดนี้ ดาวน์โหลดแยกที่ [whoisactive.com](http://whoisactive.com/) — คอร์สนี้สร้าง *Mini-WhoIsActive* ด้วย DMV ตรง ๆ อยู่แล้วใน Module 10

---

## ตัวอย่างการใช้งาน

```sql
-- ตรวจสุขภาพครั้งแรกที่เจอเซิร์ฟเวอร์
EXEC sp_Blitz;

-- "ตอนนี้ช้าเพราะอะไร" — สุ่มวัด 5 วินาที ทุก 1 วินาที
EXEC sp_BlitzFirst @Seconds = 5;

-- Top 10 query กิน CPU สูงสุดจาก plan cache
EXEC sp_BlitzCache @SortOrder = 'cpu';

-- วิเคราะห์ index ของ database เดียว
EXEC sp_BlitzIndex @DatabaseName = 'AdventureWorks2025';

-- ตามว่าใครกำลังรันอะไรอยู่
EXEC sp_BlitzWho;
```

---

## การติดตั้ง (Installation)

1. ดาวน์โหลด release ล่าสุดจาก [GitHub Releases](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/releases) (ไฟล์ .zip รวมสคริปต์ทั้งหมด)
2. รัน `Install-All-Scripts.sql` บน database ที่จัดไว้สำหรับ DBA (แนะนำสร้าง database แยก เช่น `DBA_Tools` — **อย่า**ติดตั้งลง `master`)
3. สิทธิ์ที่ต้องมี: `VIEW SERVER STATE`, `VIEW DATABASE STATE` และสิทธิ์ `EXECUTE` บน stored procedures ที่ติดตั้ง — เช่นเดียวกับหลัก least privilege ใน Module 10

---

## ข้อควรรู้ก่อนใช้ในหลักสูตร

- FRK คือ **stored procedures** ที่ต้องติดตั้งลงเซิร์ฟเวอร์เป้าหมาย — เหมาะกับเซิร์ฟเวอร์ที่ดูแลระยะยาว
- ถ้าต้องการตรวจวินิจฉัยแบบ **ไม่ติดตั้งอะไรเลย** บนเซิร์ฟเวอร์เป้าหมาย (เช่น เครื่องลูกค้าหรือ VM สอบ) ให้ใช้ **PSBlitz** ซึ่งฝังเวอร์ชันดัดแปลงของสคริปต์ชุดนี้ไว้ใน PowerShell แล้วรันออกรายงาน HTML/Excel ทันที — ดูคู่มือที่ [PSBlitz_Guide](../PSBlitz/PSBlitz_Guide.md)
- สคริปต์ออกแบบให้ปลอดภัยต่อระบบ (read-only diagnostics) แต่เช่นเคย ควรทดสอบบน Non-Production ก่อนใช้บน Production เสมอ

---

## การอ่านต่อ (Recommended Reading จาก Brent Ozar)

- [How to Measure SQL Server Workloads: Wait Time per Core per Second](https://www.brentozar.com/archive/2015/03/how-to-measure-sql-server-workloads-wait-time-core-second) — พื้นฐานการอ่าน wait stats เปรียบเป็น "มาตรวัดรอบเครื่องยนต์" (Module 1, 10)
- [How to Think Like the SQL Server Engine](https://www.brentozar.com/architecture/how-to-think-like-the-sql-server-engine/) — เข้าใจมุมมองของ Engine ตอนรัน query (Module 1, 7)
- [Brent Ozar First Aid](https://www.brentozar.com/first-aid/) — หน้ารวมดาวน์โหลดฟรี รวม **SQL Server Setup Checklist** ตอนติดตั้งใหม่ (Module 11)
- [A Sysadmin's Guide to Microsoft SQL Server Memory](https://www.brentozar.com/archive/2011/09/sysadmins-guide-microsoft-sql-server-memory) — ทำไม `sqlservr.exe` กิน RAM ทั้งเครื่อง + หลัก max server memory (Module 4)

---

## การอ้างอิงและเครดิต (Credits)

First Responder Kit เป็น open source ภายใต้ license ของโปรเจกต์ (ดู LICENSE ใน repository ต้นทาง) — ทางผู้จัดทำคอร์สแนะนำให้ตรวจสอบ release ล่าสุดจาก [FirstResponderKit.org](https://www.firstresponderkit.org/) เสมอ เพราะสคริปต์ถูกปรับปรุงต่อเนื่องทุกเดือน

> **Note**: ผู้เรียนควรให้เครดิตผู้พัฒนาเมื่อนำไปใช้งานต่อ และอ่าน [คู่มือการใช้งานอย่างเป็นทางการ](https://www.firstresponderkit.org/) ประกอบพารามิเตอร์ของแต่ละ script
