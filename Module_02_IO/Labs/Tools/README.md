# Tools — DiskSpd Bundle (Lab 2)

เครื่องมือและเอกสารประกอบ [Lab 2: DiskSpd Benchmark](../README.md) — bundled ไว้ใน repo เพื่อให้ผู้เรียนใช้ได้ทันทีแบบ offline

## ไฟล์ในโฟลเดอร์

| ไฟล์ | คืออะไร | ใช้เมื่อไร |
|---|---|---|
| `diskspd.exe` | DiskSpd **v2.3** build amd64 | เครื่อง/VM สถาปัตยกรรม x64 (เคสทั่วไปของ VM ในแล็บ) |
| `diskspd-arm64.exe` | DiskSpd **v2.3** build ARM64 | เครื่อง Windows on ARM (รัน native ไม่ต้องใช้ emulator) |
| `UsingDiskspdforSQLServer.md` | **ฉบับ Reference ภาษาไทย** ของ whitepaper (แปล/ปรับ + ภาคผนวกความต่างยุค 2.0 → v2.3) | อ่านบน GitHub สะดวกกว่า — เริ่มจากไฟล์นี้ |
| `UsingDiskspdforSQLServer.docx` | Whitepaper ต้นฉบับของ Microsoft — *Using DiskSpd in SQL Server environments* (Writer: Robert Beene; Contributors: Jose Barreto, Ramu Konidena) | อ่านพื้นฐานการเลือก pattern/ตีความผลสำหรับ SQL Server |
| `EULA-DiskSpd.txt` | ข้อตกลงสิทธิ์การใช้งาน DiskSpd จาก Microsoft | แนบมากับ release — ก่อนแจกจ่าย/ใช้งานโปรดอ่าน |

รัน DiskSpd ได้เฉพาะบนเครื่อง (VM) โดยตรง ใน Command Prompt/PowerShell — ไม่ใช่ T-SQL ใน SSMS

## ที่มาและเวอร์ชัน

- **DiskSpd v2.3** — [microsoft/diskspd release v2.3](https://github.com/microsoft/diskspd/releases/tag/v2.3) (2026-09-04) จาก `DiskSpd.ZIP`
  - ระบบปฏิบัติการขั้นต่ำ: Windows 10 1803 (RS4)
  - หมายเหตุ: v2.3 เปลี่ยน default บางจุดจากรุ่นก่อน (ลำดับ affinity P-core ก่อน E-core; buffer แยกตาม PDE cache line) — ค่าที่วัดจึงอาจต่างเล็กน้อยจากที่ทำด้วย DiskSpd รุ่น 2.0.x
- **UsingDiskspdforSQLServer.docx** — ต้นฉบับแนบมากับ 10987C Lab02 (whitepaper เขียนไว้ยุค DiskSpd 2.0 เนื้อหาแนวคิด/ไวยากรณ์พื้นฐานใช้ได้กับ v2.3)

### SHA256 (ตรวจความถูกต้องของไฟล์)

```
dd4e57e1e8ccaf5d6437938f8aab7f17e9a1e6d8fba8a093006b7cadf16faea2  diskspd.exe
1c94ccfd964f2e547ca3d8e1649129a0ce3f146e71dbb297e52c96ba2e873bc9  diskspd-arm64.exe
43c9c4560ed2491d88e15b55b2a79b38f324a8cfdb9b16df4a796fa46cc115d4  UsingDiskspdforSQLServer.docx
```

ตรวจ: `certutil -hashfile diskspd.exe SHA256` (Command Prompt) หรือ `Get-FileHash` (PowerShell)

## ประวัติการอัปเดต

- 2026-10-07: bundled ครั้งแรก — DiskSpd v2.3 (แทนที่ตัวที่แนบมากับ 10987C Lab02 ซึ่งเป็น v2.0.15 ปี 2017 และไม่ได้อยู่ใน git)
