การแก้ไขปัญหาประสิทธิภาพ (Performance Troubleshooting) จำเป็นต้องมีกระบวนการที่เป็นระบบ (Systematic Approach) เพื่อระบุสาเหตุที่แท้จริง (Root Cause) ได้อย่างแม่นยำและรวดเร็ว การ "คาดเดา" โดยปราศจากหลักฐานข้อมูล (Data-driven evidence) อาจนำไปสู่การแก้ไขปัญหาที่ผิดจุด

บทเรียนนี้จะสรุปขั้นตอนการวิเคราะห์ปัญหามาตรฐาน (Standard Troubleshooting Workflow)

### 1.1 Skill Progression (ทักษะที่ควรได้จาก Module นี้)
- **ระดับ 1 – คิดแบบ Systematic Troubleshooting**
  - ตั้งคำถาม/นิยามปัญหา, แยก Scope/Timeline/Impact ได้ก่อนลงมือแก้ (ไม่เดาสุ่ม)
- **ระดับ 2 – ใช้ข้อมูลจาก Monitoring/DMVs/Waits มาประกอบการตัดสินใจ**
  - อ่านผลจาก Module 1–10 (CPU/Memory/I/O/Waits/Query/Index/Plan Cache/Monitoring) แล้วผูกเป็นภาพเดียวกันได้
- **ระดับ 3 – เดินตาม Workflow แก้ปัญหาจริง**
  - ใช้ Flow/Script ใน Module นี้เพื่อหาคอขวด (Resource vs Concurrency vs Query Design) อย่างเป็นขั้นตอน และเสนอแนวทางแก้ได้มากกว่าหนึ่งวิธี
- **ระดับ 4 – วางกระบวนการ Troubleshooting สำหรับทีม**
  - นำแนวคิดจาก Performance Center ของ Microsoft และบทเรียนทั้งคอร์ส มาจัดทำ Runbook/Checklist สำหรับทีม DBA/DevOps ขององค์กร เพื่อให้ทุกคนแก้ปัญหาได้เป็นระบบและสอดคล้องกัน

---

## 📚 Sections (สารบัญบทเรียน)

| # | Section |
|---|---------|
| 1 | [Troubleshooting Workflow](Sections/01_Troubleshooting_Workflow/README.md) |
| 2 | [Scenarios and Resolution](Sections/02_Scenarios_and_Resolution/README.md) |

**ทบทวนรวม:** [Quiz Bank บทที่ 11](Quiz_Bank.md) — 15 คำถามพร้อมเฉลยครอบ Learning Objectives ของบท

---

## 🧪 Labs

คู่มือปฏิบัติแบบ Instruction + Code block: [Labs/README.md](Labs/README.md) — สคริปต์ประกอบอยู่ใน `Sections/*/Scripts/` ตามหัวข้อ

---

## <details>
<summary><b>1. ขั้นตอนแรกของการ Troubleshooting คืออะไร?</b></summary>
Define the Problem: ต้องรู้ขอบเขตก่อนว่าช้าที่ใคร ใครเป็นคนบ่น และช้าช่วงเวลาไหน (ไม่ใช่เดาสุ่ม)
</details>

<details>
<summary><b>2. ถ้า Server Resources (CPU/RAM) ปกติ แต่ User ยังบ่นว่าช้า เราควรดูอะไรต่อ?</b></summary>
Wait Statistics: เพื่อดูว่า SQL Server กำลังรออะไรอยู่ (เช่นรอ Lock หรือรอ Network)
</details>

<details>
<summary><b>3. ประโยค "Performance Tuning is a journey" หมายความว่าอย่างไร?</b></summary>
การ Tuning ไม่ใช่งานที่ทำครั้งเดียวจบ เพราะข้อมูลเปลี่ยนตลอดเวลา Plan ที่เคยดีอาจจะแย่ลงได้ ต้องคอย Monitor เสมอ
</details>

---

## > **"Performance Tuning is a journey, not a destination."**

ระบบมีการเปลี่ยนแปลงข้อมูลตลอดเวลา Plan ที่เคยดีวันนี้ พรุ่งนี้อาจจะแย่
สิ่งสำคัญคือการ **Monitor (เฝ้าระวัง)** และ **Adapt (ปรับตัว)** ให้ทันกับการเปลี่ยนแปลงนั้น

ขอให้สนุกกับการ Tuning ครับ! :)

---
