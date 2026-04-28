# EA Updater Docs

เอกสารชุดนี้ใช้สำหรับสื่อสารในทีม, onboarding สมาชิกใหม่, และส่งต่อการ maintain ระบบ deploy EA/MT5 บน VPS

## เอกสารหลัก

- `components/install-script.md` — รายละเอียด `install.ps1`
- `components/remote-orchestrator.md` — รายละเอียด `remote-deploy.ps1`
- `configuration-files.md` — อธิบายโครงสร้างไฟล์ config ทุกชนิด
- `runbooks.md` — ขั้นตอนปฏิบัติจริงและ troubleshooting

## เป้าหมายของระบบ

- ติดตั้ง MT5 แบบ unattended
- deploy `.ex5` และ `.set` อัตโนมัติ
- ตั้งค่า account/startup/algo trading ผ่าน config
- รองรับหลาย broker และหลาย account ต่อ VPS
- รองรับ remote orchestration โดยไม่ต้อง RDP มือ
