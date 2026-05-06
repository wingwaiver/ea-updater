# EA Updater (Windows VPS, no manual remote)

This project deploys MT5 + your EA (`.ex5`) with one PowerShell command.

MT5 installation uses unattended mode (`/auto /path`) so no installer "Next" clicks are required.

Team docs for handover and maintenance are in `docs/README.md`.

## 1) Prepare files

- Put your EA file somewhere accessible on VPS, for example `C:\deploy\MyEA.ex5`.
- Keep `config.ini` in this project **or** provide credentials via environment variables.
- If you use `config.ini`, set real values for `Login`, `Password`, and `Server` (not `YOUR_...` placeholders).
- Select broker in `config.ini` under `[Deployment]` or pass `-BrokerName`.

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
- `-BrokerName "Vantage"`: select installer from `brokers.json`.
- `-BrokerCatalogPath ".\brokers.json"`: use custom broker catalog template.
- `-InstallerUrl "https://.../setup.exe"`: force installer URL override.

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

# Install by broker catalog entry
.\install.ps1 -Ex5Source "C:\deploy\MyEA.ex5" -BrokerName "PU Prime"

# Full override (custom installer URL)
.\install.ps1 -Ex5Source "C:\deploy\MyEA.ex5" -InstallerUrl "https://download.mql5.com/cdn/web/dupoin.markets.ltd/mt5/dupoinmarkets5setup.exe"
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

## 5.1) Multi-account layout on one VPS

Use one terminal folder per account/broker. Example:

```powershell
.\install.ps1 -Mt5Dir "C:\MT5\Vantage-1001" -Ex5Source ".\MyEA.ex5" -BrokerName "Vantage"
.\install.ps1 -Mt5Dir "C:\MT5\PUPrime-2001" -Ex5Source ".\MyEA.ex5" -BrokerName "PU Prime"
```

This keeps terminals isolated and avoids account/profile conflicts.

## 5.2) Deploy many local instances (one machine, many brokers)

Use `deploy-local.ps1` to run many instances on the same machine from a single JSON plan (same schema as `remote-deploy.ps1`).

```powershell
# Validate plan and print resolved actions
.\deploy-local.ps1 -PlanPath ".\deployment.plan.json" -DryRun

# Deploy all vps[] groups in the plan on this machine
.\deploy-local.ps1 -PlanPath ".\deployment.plan.json"

# Deploy only one group (match vps[].name)
.\deploy-local.ps1 -PlanPath ".\deployment.plan.json" -VpsName "vps-main"

# Continue processing other instances when one fails
.\deploy-local.ps1 -PlanPath ".\deployment.plan.json" -ContinueOnError
```

## 6) EA custom inputs (.set)

- A preset example is included at `ea-inputs.set`.
- Replace keys to match your EA `input` names exactly (case-sensitive).
- Keep only parameters that exist in your EA.
- When `-SetSource` is provided, the preset is copied to `C:\MT5\MQL5\Presets\`.

## 7) Remote deployment to VPS (no manual RDP)

Use `remote-deploy.ps1` with a plan file to deploy many brokers/accounts automatically.

### 7.1 Prepare plan

1. Copy `deployment.plan.template.json` to `deployment.plan.json`.
2. Fill VPS connection values: `host`, `username`, `port`, `useSsl`, and either `password` or `passwordEnv`.
3. Add each MT5 instance under `instances` with:
   - `brokerName` (must exist in `brokers.json`)
   - `mt5Dir` (separate folder per account)
   - `login`, `password`, `server`

### 7.2 Run

```powershell
.\remote-deploy.ps1 -PlanPath ".\deployment.plan.json"

# Validate plan and print resolved actions without connecting
.\remote-deploy.ps1 -PlanPath ".\deployment.plan.json" -DryRun

# Continue processing other instances when one fails
.\remote-deploy.ps1 -PlanPath ".\deployment.plan.json" -ContinueOnError
```

### 7.3 Notes

- This script uses PowerShell remoting (`New-PSSession`), so WinRM must be enabled on the VPS.
- Prefer `passwordEnv` to keep VPS passwords out of plan files.
- One MT5 folder per account is strongly recommended to avoid profile conflicts.
