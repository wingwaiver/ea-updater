# Component: install.ps1

## หน้าที่

`install.ps1` คือสคริปต์หลักสำหรับ deploy MT5 instance เดียวในเครื่อง Windows/VPS

งานหลักที่สคริปต์ทำ:

1. เลือก installer URL ตามลำดับความสำคัญ (CLI > config > broker catalog > default)
2. ติดตั้ง MT5 แบบ unattended (`/auto /path`)
3. คัดลอกไฟล์ EA (`.ex5`) และ preset (`.set`)
4. สร้าง/คัดลอก `config.ini`
5. ตั้ง startup chart + EA + preset
6. เปิด terminal ด้วย `/portable /config:...`

## Inputs สำคัญ

- `-Mt5Dir` ตำแหน่ง instance ปลายทาง
- `-Ex5Source` ไฟล์ EA ที่ต้อง deploy
- `-SetSource` ไฟล์ `.set` (optional, auto-detect `ea-inputs.set` ได้)
- `-BrokerName` ชื่อ broker ใน `brokers.json`
- `-InstallerUrl` override URL installer โดยตรง
- `-Login`, `-Password`, `-Server` ค่า account (แนะนำให้ส่งแบบ env)
- `-StartupSymbol`, `-StartupPeriod` ตั้งกราฟเริ่มต้น
- `-ForceInstall` บังคับติดตั้งใหม่
- `-NoLaunch` ติดตั้ง/คัดลอกอย่างเดียว

## Outputs สำคัญ

- `terminal64.exe` ใน `Mt5Dir`
- `config.ini` ใน `Mt5Dir`
- EA ใน `Mt5Dir\MQL5\Experts`
- Preset ใน `Mt5Dir\MQL5\Presets`

## ข้อควรรู้สำหรับทีม

- หาก MT5 ติดตั้งแล้วและไม่ใส่ `-ForceInstall` จะข้าม step install
- สคริปต์ตรวจ placeholder ใน `config.ini` (`YOUR_...`) เพื่อกันรันผิด
- มีการ normalize installer exit code ก่อนตัดสินว่า fail/pass
