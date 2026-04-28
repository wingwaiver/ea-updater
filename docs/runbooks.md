# Runbooks

## A) Deploy instance เดียวบน VPS

1. เตรียม `config.ini`, `.ex5`, `.set`
2. รัน `install.ps1`
3. ตรวจว่า MT5 เปิดขึ้นมาและ EA อยู่บนกราฟที่กำหนด

ตัวอย่าง:

```powershell
.\install.ps1 -Mt5Dir "C:\MT5\Vantage-1001" -Ex5Source ".\COV - Breakthrough (8 Apr).ex5" -SetSource ".\ea-inputs.set" -BrokerName "Vantage"
```

## B) Deploy หลาย VPS/หลาย account

1. สร้าง `deployment.plan.json` จาก template
2. ตั้ง env password ของแต่ละ VPS
3. รัน `remote-deploy.ps1 -DryRun`
4. รันจริง

ตัวอย่าง:

```powershell
$env:VPS_MAIN_PASSWORD="your_password"
.\remote-deploy.ps1 -PlanPath ".\deployment.plan.json" -DryRun
.\remote-deploy.ps1 -PlanPath ".\deployment.plan.json"
```

## C) Troubleshooting พื้นฐาน

- **ติดตั้งแล้วเด้งถาม account**
  - ตรวจ `Login/Password/Server` ใน config ว่าเป็นค่าจริง
  - ตรวจว่า launch ใช้ `/config:` ไฟล์ที่ถูกต้อง

- **ไม่โหลด `.set` อัตโนมัติ**
  - ตรวจว่าไฟล์อยู่ `MQL5\Presets`
  - ตรวจชื่อ key ใน `.set` ตรงกับ input EA

- **EA ไม่เทรด**
  - ตรวจ `[Experts]` มี `AllowLiveTrading=1`
  - ตรวจ `AllowDllImport=1` หาก EA ใช้ DLL
  - ตรวจ algo trading button ใน terminal

- **remote deploy ต่อ VPS ไม่ได้**
  - ตรวจ WinRM/Firewall/Port
  - ตรวจ `username/password` หรือ `passwordEnv`
  - ลอง `-DryRun` ก่อนเสมอ
