# EA Updater (Windows VPS, no manual remote)

This project deploys MT5 + your EA (`.ex5`) with one PowerShell command.

## 1) Prepare files

- Put your EA file somewhere accessible on VPS, for example `C:\deploy\MyEA.ex5`.
- Keep `config.ini` in this project **or** provide credentials via environment variables.

## 2) Run unattended with environment variables (recommended)

```powershell
$env:MT5_LOGIN="12345678"
$env:MT5_PASSWORD="your_password"
$env:MT5_SERVER="Broker-Server"

.\install.ps1 -Ex5Source "C:\deploy\MyEA.ex5"
```

This mode generates `C:\MT5\config.ini` automatically and avoids editing config on server.

## 3) Run with explicit config.ini

```powershell
.\install.ps1 -Ex5Source "C:\deploy\MyEA.ex5" -ConfigSource ".\config.ini"
```

## 4) Useful options

- `-Mt5Dir "C:\MT5"`: change MT5 install folder.
- `-NoLaunch`: install/copy only, do not start terminal.
- `-ForceInstall`: reinstall MT5 even if already installed.
- `-SetSource ".\ea-inputs.set"`: copy EA preset file to MT5 presets folder.

## 4.1) Command examples

```powershell
# Standard run (skip install if MT5 already exists)
.\install.ps1 -Ex5Source "C:\deploy\MyEA.ex5"

# Copy/update files only (do not launch terminal)
.\install.ps1 -Ex5Source "C:\deploy\MyEA.ex5" -NoLaunch

# Force reinstall MT5, then deploy and launch
.\install.ps1 -Ex5Source "C:\deploy\MyEA.ex5" -ForceInstall

# Deploy EA with .set preset file
.\install.ps1 -Ex5Source "C:\deploy\MyEA.ex5" -SetSource ".\ea-inputs.set"
```

## 4.2) One-command run for staff

Put exactly one `.ex5`, one `.ini`, and one `.set` in this folder, then run:

```powershell
.\run-deploy.ps1
```

Optional flags:

```powershell
.\run-deploy.ps1 -ForceInstall
.\run-deploy.ps1 -NoLaunch
.\run-deploy.ps1 -Mt5Dir "C:\MT5"
```

## 5) Result paths

- Terminal: `C:\MT5\terminal64.exe`
- Config: `C:\MT5\config.ini`
- EA target: `C:\MT5\MQL5\Experts\<your-file>.ex5`

## 6) EA custom inputs (.set)

- A preset example is included at `ea-inputs.set`.
- Replace keys to match your EA `input` names exactly (case-sensitive).
- Keep only parameters that exist in your EA.
- When `-SetSource` is provided, the preset is copied to `C:\MT5\MQL5\Profiles\Presets\`.
