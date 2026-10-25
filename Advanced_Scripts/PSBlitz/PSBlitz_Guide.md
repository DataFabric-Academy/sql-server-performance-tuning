# PSBlitz (VladDBA) - ฉบับภาษาไทย

โฟลเดอร์นี้แนะนำ **PSBlitz** — เครื่องมือ PowerShell สำหรับตรวจสุขภาพและวินิจฉัยประสิทธิภาพ SQL Server แบบ **รันแล้วได้รายงานทันที** พัฒนาโดย **Vlad Drumea (VladDBA)**

**Crucial Credit & Sources**:
- Source code: [GitHub: VladDBA/PSBlitz](https://github.com/VladDBA/PSBlitz)
- เอกสาร permissions: [PERMISSIONS.md](https://github.com/VladDBA/PSBlitz/blob/main/PERMISSIONS.md) (ใน repository ต้นทาง)

---

## PSBlitz ต่างจาก First Responder Kit อย่างไร?

PSBlitz **ฝัง** (embed) เวอร์ชันดัดแปลงของสคริปต์ชั้นนำไว้ในโฟลเดอร์ `Resources` ของตัวเอง:

- สคริปต์จาก **Brent Ozar's First Responder Kit**: sp_Blitz, sp_BlitzCache, sp_BlitzFirst, sp_BlitzIndex, sp_BlitzLock, sp_BlitzWho
- **sp_QuickieStore** ของ Erik Darling (วิเคราะห์ Query Store)

จุดต่างสำคัญ: **ไม่ต้องติดตั้ง stored procedure ใด ๆ บนเซิร์ฟเวอร์เป้าหมาย** — ต่างจากการติดตั้ง FRK ตรง ๆ ที่ต้องสร้าง procs ลง database จึงเหมาะกับ:

- เครื่องลูกค้า/Production ที่ไม่ต้องการให้ติดตั้ง object เพิ่ม
- VM ของหลักสูตรนี้ — รันจากเครื่องผู้เรียนแล้วชี้มาที่ instance เป้าหมายได้ทันที

---

## สิ่งที่ตรวจให้ (รายงานเดียวจบ)

| กลุ่ม | สิ่งที่ได้ |
|:------|:-----------|
| สุขภาพ Instance | ผล sp_Blitz (config เสี่ยง, best practice) + ข้อค้นพบด้าน security |
| **Wait stats** | สรุป wait หลักของ instance (ต่อยอด Module 1) |
| Running queries | สิ่งที่กำลังรันตอนตรวจ (sp_BlitzWho) + tempdb usage |
| **Top queries** | Top 10 query ที่กินทรัพยากรสูงสุดจาก plan cache พร้อม export ไฟล์ `.sqlplan` |
| **Index** | missing/unused index และปัญหา index เด่น ๆ (ต่อยอด Module 6) |
| **Deadlock** | ข้อมูล deadlock ย้อนหลัง 15 วัน พร้อมไฟล์ `.xdl` เปิดใน SSMS ได้ (ต่อยอด Module 5) |
| ผลลัพธ์ | รายงาน **HTML** (เปิดในเบราว์เซอร์) หรือ **Excel** — เก็บเป็นหลักฐาน/เทียบย้อนหลังได้ |

โหมดเพิ่มเติม:
- **`-InDepth`**: เจาะลึก — wait/storage/perfmon stats ตั้งแต่ restart, cache หลาย sort order, index details
- **`-CheckDB <ชื่อDB>`**: เจาะ database เดียว — เพิ่ม **Query Store, statistics, fragmentation** (ต่อยอด Module 6, 8)

---

## ความต้องการของระบบ (Requirements)

| รายการ | รายละเอียด |
|:--------|:-----------|
| PowerShell | Windows PowerShell 5.1 หรือ PowerShell 7.x (รวมบน Linux — ผลลัพธ์ HTML เท่านั้น) |
| สิทธิ์บน SQL Server | สิทธิ์อ่าน DMV/server state (**ไม่ต้องเป็น sysadmin** — ดู PERMISSIONS.md) สอดคล้องหลัก least privilege ใน Module 10 |
| Excel output (ถ้าใช้) | Microsoft Office หรือโมดูล ImportExcel — ถ้าไม่มีให้ใช้ `-ToHTML` |
| Authentication | SQL Login หรือ Windows Integrated หรือ Entra ID/MFA (ต้องมีโมดูล Az) |
| ไม่รองรับ | Amazon RDS |
| รองรับ Cloud | Azure SQL Database / Managed Instance |

---

## การใช้งานเร็ว (Quick Start)

ดาวน์โหลด release จาก [GitHub Releases](https://github.com/VladDBA/PSBlitz/releases) แล้วแตกไฟล์ (ต้องมีโฟลเดอร์ `Resources` คู่กับ `.ps1` เสมอ):

```powershell
# ตรวจพื้นฐาน (default check) ด้วย Windows Integrated Security
.\PSBlitz.ps1 Server01\SQL01

# Instance ที่รันผ่าน port เฉพาะ
.\PSBlitz.ps1 Server01,1433

# เจาะลึกเต็มรูปแบบ + ผลลัพธ์ HTML + บีบเป็น zip
.\PSBlitz.ps1 Server01\SQL01 -ToHTML -ZipOutput -InDepth

# เจาะ database เดียว (เพิ่ม Query Store / statistics / fragmentation)
.\PSBlitz.ps1 Server01\SQL01 -InDepth -CheckDB AdventureWorks2025

# ใช้ SQL Login
.\PSBlitz.ps1 Server01\SQL01 -SQLLogin DBA1 -SQLPass <รหัสผ่าน>

# Azure SQL Database ด้วย Entra ID (MFA)
.\PSBlitz.ps1 yourserver.database.windows.net,1433:YourDatabase -AADAuth

# โหมด GUI เลือกตัวเลือกผ่านเมนู
.\PSBlitz.ps1 Server01\SQL01 -GUI

# ความช่วยเหลือ
.\PSBlitz.ps1 ?
```

พารามิเตอร์ที่ใช้บ่อยอื่น ๆ: `-CacheTop` (จำนวน top queries), `-CacheMinutesBack` (ย้อนหลังกี่นาทีจาก plan cache), `-BlitzWhoDelay` (รอบ sampling), `-OutputDir`, `-SkipChecks`

---

## ใช้ในหลักสูตรนี้ตรงไหน

| โมดูล | ใช้ PSBlitz ทำอะไร |
|:------|:---------------------|
| Module 1 | เทียบ "มุมมองเครื่องมือพร้อมรายงาน" กับ wait stats ที่เรา query เอง — เห็นว่าเครื่องมือสำเร็จรูปก็อ่าน DMV เดียวกัน |
| Module 5 | ดึง deadlock ย้อนหลัง 15 วัน เป็นไฟล์ `.xdl` เปิดใน SSMS — ต่อจากแล็บ deadlock |
| Module 6 | missing index / unused index จากรายงานเดียว เทียบกับ `sys.dm_db_missing_index_details` |
| Module 8 | Top 10 queries จาก plan cache เทียบกับ `sp_BlitzCache`/`sp_QuickieStore` ที่เรียนด้วยมือ |
| Module 10–11 | เป็น "triage รอบแรก" เมื่อได้รับเซิร์ฟเวอร์ใหม่ ก่อนเข้า workflow วินิจฉัยด้วยมือ |

> **ข้อควรรู้**: PSBlitz ทำงานแบบ read-only (สอบถาม DMV) แต่เช่นเคย ให้ทดสอบบน Non-Production ก่อนรันบน Production เสมอ — และอ่าน release notes ก่อนอัปเดตเวอร์ชัน

---

## การอ้างอิงและเครดิต (Credits)

PSBlitz เป็นผลงาน open source ของ **Vlad Drumea (VladDBA)** — license และข้อกำหนดการใช้งานดูไฟล์ LICENSE ใน repository ต้นทาง สคริปต์ที่ฝังมาใน `Resources` ยังคงเครดิตของทีม First Responder Kit (Brent Ozar Unlimited) และ Erik Darling (sp_QuickieStore) ตามที่ปรากฏในตัวสคริปต์แต่ละไฟล์

> **Note**: ผู้เรียนควรให้เครดิตผู้พัฒนาเมื่อนำไปใช้งานต่อ และแนะนำให้อ่านคู่มือ `README.md` ของโปรเจกต์ต้นทางเพื่อดูพารามิเตอร์ที่ครบถ้วนและเวอร์ชันล่าสุด
