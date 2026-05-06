# Deployment Plans

ไฟล์ในโฟลเดอร์นี้แยกเป็น 2 โหมด:

- `deployment.smoke.json`  
  ใช้ทดสอบ installer ทุก broker (`forceInstall=true`, `noLaunch=true`)
- `deployment.live.json`  
  ใช้งานจริง/รันซ้ำประจำ (`forceInstall=false`, `noLaunch=false`)
- `deployment.test.json`  
  แผนทดสอบรวมทุก broker (ค่าปัจจุบันเปิด MT5 หลัง deploy และไม่ force reinstall)

## ก่อนใช้งาน

1. แก้ `login`, `password`, `server` ของทุก instance จาก `REPLACE_*` เป็นค่าจริง
2. ตรวจว่าไฟล์ `EX5` และ `.set` อยู่ตำแหน่งตาม `defaults` (`../...`)
3. รันบนเครื่อง Windows ที่มีสิทธิ์พอสำหรับติดตั้ง MT5

## คำสั่งรัน

```powershell
# ตรวจแผนก่อน (ไม่ deploy จริง)
.\deploy-local.ps1 -PlanPath ".\plans\deployment.smoke.json" -DryRun

# ทดสอบ installer ทุก broker
.\deploy-local.ps1 -PlanPath ".\plans\deployment.smoke.json"

# รันใช้งานจริง (เปิด MT5 หลัง deploy)
.\deploy-local.ps1 -PlanPath ".\plans\deployment.live.json"
```

## หมายเหตุ

- ถ้ารันจากโฟลเดอร์ `ea-updater` ให้ใช้ path ตามตัวอย่างด้านบน
- ถ้ามีปัญหา policy/security ให้รัน `.\accept-security.ps1` ก่อน
