# Component: remote-deploy.ps1

## หน้าที่

`remote-deploy.ps1` ใช้ orchestrate การ deploy ไปหลาย VPS และหลาย MT5 instances จากไฟล์ plan เดียว

## Flow การทำงาน

1. อ่าน `deployment.plan.json`
2. validate โครงสร้าง plan และไฟล์ที่อ้างอิง
3. สร้าง PSSession ไปแต่ละ VPS (WinRM)
4. copy ไฟล์ที่ต้องใช้ไป `remoteWorkspace`
5. เรียก `install.ps1` ต่อ instance
6. สรุปผล success/fail ต่อ instance

## ความสามารถหลัก

- รองรับหลาย VPS ในรอบเดียว
- รองรับหลายบัญชีต่อ VPS
- รองรับ `passwordEnv` (ไม่ต้องเก็บรหัสผ่านในไฟล์)
- รองรับ `-DryRun` เพื่อตรวจแผนก่อนยิงจริง
- รองรับ `-ContinueOnError` เพื่อรันต่อแม้บาง instance fail

## สิ่งที่ต้องมีในระบบปลายทาง

- WinRM/PowerShell remoting เปิดใช้งาน
- user ที่ใช้ต้องมีสิทธิ์เพียงพอในการติดตั้งและรัน MT5

## แนวทาง maintain

- ใช้ `deployment.plan.template.json` เป็น source of truth สำหรับโครง
- แก้ broker URL ใน `brokers.json` จุดเดียว
- เพิ่ม account ใหม่ด้วยการเพิ่ม object ใน `instances[]`
