
## วัตถุประสงค์
เอกสารนี้สรุป “สิทธิ์/ข้อกำหนดด้าน security” ที่เครื่อง Windows ต้องมีเพื่อให้สคริปต์ของ `ea-updater` รันได้
โดยเฉพาะเคสที่พบ error เช่น `UnauthorizedAccess`, `InvalidOperation`, `WebException`

> หมายเหตุ: สคริปต์ในโปรเจกต์นี้เป็น PowerShell (`*.ps1`) ดังนั้นเครื่องปลายทางต้องอนุญาตการรันสคริปต์ และต้องมีสิทธิ์เขียนในโฟลเดอร์ที่ deploy ไป

---

## 1) PowerShell Execution Policy
มี 2 ทางเลือก (แนะนำข้อ 1):

1. ใช้สคริปต์เตรียมความพร้อมก่อน
   - รันบนเครื่องที่ “จะเป็นคนรัน deploy จริง” เท่านั้น

   ```powershell
   # จากโฟลเดอร์ ea-updater
   .\accept-security.ps1 -Scope CurrentUser -Force
   ```

2. ตั้ง Execution Policy เอง

   ```powershell
   # ทางเลือก: เฉพาะผู้ใช้ที่รันงาน (ไม่กระทบทั้งเครื่อง)
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

ถ้ายังติดเรื่องสิทธิ์/การบล็อคไฟล์ ให้ดูหัวข้อ 2 (MOTW/Unblock-File)

---

## 2) Unblock-File / Mark-of-the-Web (MOTW)
เมื่อไฟล์ถูกดาวน์โหลด/ก็อปจากภายนอก (เช่น zip จาก browser, artifact ที่มี MOTW)
PowerShell อาจบล็อคการรันสคริปต์ จนเกิด error แนว `UnauthorizedAccess`.

แนวทาง production ที่ใช้บ่อย:

1. รัน `accept-security.ps1` (จะลอง `Unblock-File` ให้กับไฟล์ `*.ps1, *.psm1, *.psd1` ในโปรเจกต์)
2. หรือรันด้วยมือ:

   ```powershell
   Get-ChildItem -Path "C:\ea-updater" -Recurse -File -Include *.ps1,*.psm1,*.psd1 |
     Unblock-File
   ```

> ถ้า `Unblock-File` เองขึ้น `UnauthorizedAccess` มักเป็น “สิทธิ์ในการอ่าน/เขียน/เปลี่ยน metadata” ของโฟลเดอร์นั้น หรือโดน EDR จับล็อกไฟล์
ให้ตรวจว่ามีสิทธิ์เขียนในโฟลเดอร์ `C:\ea-updater` (หรือโฟลเดอร์ที่วางสคริปต์) และไม่อยู่ใน path ที่จำเป็นต้องใช้ admin เพื่อแก้ metadata

---

## 3) สิทธิ์เขียนไฟล์/โฟลเดอร์ (File System ACL)
สคริปต์ `install.ps1` จะสร้าง/เขียนไฟล์ในหลายตำแหน่งตามพารามิเตอร์:

- โฟลเดอร์ root ของโปรเจกต์ (สำหรับคัดลอกไฟล์ `*.ex5`, `*.set`, config ฯลฯ)
- `Mt5Dir` ที่ระบุใน plan (ค่าใน `instances[].mt5Dir`)
  - สร้าง/เขียน `terminal64.exe`, `config.ini`
  - สร้าง/เขียน `MQL5\Experts\...`
  - สร้าง/เขียน `MQL5\Presets\...` (ถ้ามี `.set`)

สิทธิ์ขั้นต่ำที่จำเป็น:
- อ่านไฟล์ต้นทาง (EX5/SET/INI หรืออ่านจาก config)
- เขียน/สร้างโฟลเดอร์ปลายทางใน `Mt5Dir`
- รันโปรเซส/ไฟล์ exe ที่ดาวน์โหลดได้

คำแนะนำ:
- ให้รันด้วย “service account / user” ที่มี ownership หรือมี write permission ใน `Mt5Dir` ทุกอัน
- เลี่ยงวางโปรเจกต์หรือ `Mt5Dir` ไว้ในโฟลเดอร์ที่ต้อง admin เท่านั้น (เช่นบาง subfolder ภายใต้ `C:\Program Files`)

---

## 4) Network / Outbound HTTPS (จำเป็นสำหรับดาวน์โหลด MT5 installer)
`install.ps1` มีขั้นตอน `Invoke-WebRequest ... -OutFile $installerPath` เพื่อดาวน์โหลด MT5 installer
ดังนั้นต้องอนุญาต outbound:

- TCP `443` (HTTPS) จากเครื่องที่รันงาน ไปยัง URL ที่อยู่ใน:
  - `brokers.json` (`brokers[BrokerName].installerUrl`)
  - หรือ `deployment.plan.json` (ถ้า `instances[].installerUrl` override)
  - หรือ `config.ini` (section `[Deployment]` key `InstallerUrl` หากตั้งไว้)

กรณีองค์กรใช้ Proxy:
- ต้องตั้งค่า proxy/allowlist ให้ account ที่รันงานใช้ออกเน็ตได้

กรณีปัญหา TLS:
- สคริปต์พยายาม enforce TLS 1.2 แล้ว แต่สุดท้ายต้อง pass ผ่าน policy ด้านเครือข่าย/SSL inspection ขององค์กร

เพื่อ debug (รันบนเครื่องจริงที่เป็นตัวรัน):
```powershell
Invoke-WebRequest "https://download.mql5.com/" -Method Head
Test-NetConnection download.mql5.com -Port 443
```

---

## 5) Remote deployment (ใช้เฉพาะ `remote-deploy.ps1`)
ถ้าใช้ `remote-deploy.ps1` (deploy ไปหลาย VPS ด้วย WinRM) จะต้องมีเพิ่ม:

1. WinRM/PowerShell remoting บนเครื่องปลายทาง (VPS)
2. Firewall อนุญาตพอร์ต WinRM (ส่วนมาก TCP `5985` HTTP หรือ `5986` HTTPS ตาม plan)
3. account ที่ใช้ WinRM ต้องมีสิทธิ์:
   - สร้างโฟลเดอร์ใน `vps[].remoteWorkspace` (ค่าเริ่มต้นในสคริปต์คือ `C:\ea-updater` ถ้าไม่ได้ override)
   - รัน `install.ps1` และเขียนไฟล์ใน `instances[].mt5Dir`

> ถ้าการดาวน์โหลดไฟล์เกิดในเครื่องปลายทาง (มักเป็นเช่นนั้น) ก็ต้องมี outbound HTTPS อนุญาตบน VPS ด้วย ไม่ใช่แค่เครื่องที่เรียกสคริปต์

---

## Checklist สรุป (production)
- Execution Policy อนุญาตการรันสคริปต์ (แนะนำ `accept-security.ps1`)
- ไฟล์ไม่ถูกบล็อคด้วย MOTW / `Unblock-File` สำเร็จ
- account ที่รัน job มีสิทธิ์ write ใน `Mt5Dir` และโฟลเดอร์โปรเจกต์
- outbound HTTPS ไปยัง URL ใน `brokers.json`/`installerUrl` ผ่าน policy/proxy/TLS ได้
- ถ้า remote: WinRM เปิด + firewall + สิทธิ์บน VPS ครบ