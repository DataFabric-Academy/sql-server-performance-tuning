# Advanced Scripts & Community Tools

โฟลเดอร์นี้รวมคู่มือ (ภาษาไทย) ของเครื่องมือวินิจฉัยและจูนประสิทธิภาพระดับมืออาชีพที่วงการ DBA ทั่วโลกใช้เป็นมาตรฐาน — เนื้อหาคอร์สสอนให้ query DMV ด้วยมือเพื่อ "เข้าใจกลไก" ส่วนเครื่องมือเหล่านี้คือ **สิ่งที่ทีมงานจริงใช้ทำงานเดียวกันให้เร็วขึ้น**

| โฟลเดอร์ | เครื่องมือ | ลักษณะ | คู่มือ |
|:----------|:-----------|:--------|:-------|
| `GlennBerry/` | **SQL Server Diagnostic Information Queries** (Glenn Berry) | สคริปต์ .sql แบบ copy-run — สแนปช็อตเชิงลึกทั้งระบบ อัปเดตรายเดือน มีรุ่น SQL Server 2025 | [GlennBerry_Guide.md](GlennBerry/GlennBerry_Guide.md) |
| `BrentOzar_FRK/` | **First Responder Kit** (Brent Ozar Unlimited) | Stored procedures open source — sp_Blitz / sp_BlitzCache / sp_BlitzIndex / sp_BlitzFirst | [FRK_Guide.md](BrentOzar_FRK/FRK_Guide.md) |
| `PSBlitz/` | **PSBlitz** (VladDBA) | PowerShell — รันครั้งเดียวได้รายงาน HTML/Excel ครบ โดย **ไม่ต้องติดตั้งอะไรบนเซิร์ฟเวอร์เป้าหมาย** (ฝัง FRK + sp_QuickieStore ไว้ข้างใน) | [PSBlitz_Guide.md](PSBlitz/PSBlitz_Guide.md) |
| `Microsoft_Tiger/` | **Tiger Toolbox** (Microsoft Tiger Team) | BPCheck, Waits and Latches, AdaptiveIndexDefrag | [Tiger_Toolbox_Guide.md](Microsoft_Tiger/Tiger_Toolbox_Guide.md) |

## เลือกใช้ยังไง? (Quick Chooser)

- **ตรวจสุขภาพรายวัน/รายสัปดาห์ แบบลึกทั้งระบบ** → Glenn Berry diagnostics (เทียบกับ spreadsheet baseline)
- **"ตอนนี้ช้าเพราะอะไร" ทันที** → `sp_BlitzFirst` (FRK) หรือ Mini-WhoIsActive ที่เรียนใน Module 10
- **ได้รายงานจบในไฟล์เดียว ไม่ติดตั้งอะไรบนเป้าหมาย** → PSBlitz
- **จูนเชิงลึกราย query / ราย index** → `sp_BlitzCache` + `sp_BlitzIndex` (FRK)
- **ตรวจ config ตาม Best Practice ของ Microsoft เอง** → BPCheck (Tiger Toolbox)

## ความเชื่อมโยงกับคอร์ส

เครื่องมือทุกตัวใช้ DMV ชุดเดียวกับที่เรียนใน Module 1–10 — จุดเชื่อมต่อแบบละเอียดอยู่ในแต่ละคู่มือ และในบทเรียน:
- [Module 10 — Baselining & Benchmarking](../Module_10_Monitoring_Tracing/Sections/02_Baselining_Benchmarking/README.md) (หัวข้อ 7: เครื่องมือมาตรฐาน)
- [Module 11 — Troubleshooting](../Module_11_Troubleshooting/README.md) (triage รอบแรกด้วยเครื่องมือพร้อมรายงาน)

> ⚠️ ทุกเครื่องมือในหน้านี้เป็นผลงานของบุคคล/ทีมที่กล่าวถึง — ให้เครดิตและตรวจ release ล่าสุดจากแหล่งต้นทางเสมอ และทดสอบบน Non-Production ก่อนใช้บน Production
