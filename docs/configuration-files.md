# Configuration Files

## 1) `config.ini`

ใช้เป็น MT5 runtime config ของ instance

section สำคัญ:

- `[Common]` — `Login`, `Password`, `Server`, `Portable`
- `[Experts]` — `AllowLiveTrading`, `AllowDllImport`, `Enabled`
- `[StartUp]` — `Expert`, `ExpertParameters`, `Symbol`, `Period`
- `[Deployment]` — metadata สำหรับเลือก broker installer (`Broker`, optional `InstallerUrl`)

## 2) `brokers.json`

catalog installer ตาม broker เพื่อให้เลือก broker โดยใช้ชื่อ

โครงหลัก:

```json
{
  "brokers": {
    "Broker Name": {
      "installerUrl": "https://.../setup.exe"
    }
  }
}
```

## 3) `deployment.plan.json`

ไฟล์ orchestration สำหรับยิง deploy หลาย VPS/หลาย account

โครงหลัก:

- `defaults` ค่า default ที่ใช้ร่วมกัน
- `vps[]` รายการเครื่องปลายทาง
- `vps[].instances[]` รายการ account/instance ที่จะ deploy

## 4) `ea-inputs.set`

preset input ของ EA

ข้อสำคัญ:

- ชื่อ key ต้องตรงกับ `input` ของ EA แบบ exact match
- เก็บเฉพาะค่าที่ EA ใช้งานจริง
