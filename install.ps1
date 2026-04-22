param(
    [Parameter(Mandatory = $false)]
    [string]$Mt5Dir = "C:\MT5",

    [Parameter(Mandatory = $false)]
    [string]$ConfigSource = "$PSScriptRoot\config.ini",

    [Parameter(Mandatory = $false)]
    [string]$Login = $env:MT5_LOGIN,

    [Parameter(Mandatory = $false)]
    [string]$Password = $env:MT5_PASSWORD,

    [Parameter(Mandatory = $false)]
    [string]$Server = $env:MT5_SERVER,

    [Parameter(Mandatory = $false)]
    [switch]$NoLaunch,

    [Parameter(Mandatory = $false)]
    [switch]$ForceInstall,

    [Parameter(Mandatory = $false)]
    [string]$SetSource,

    [Parameter(Mandatory = $false)]
    [string]$StartupSymbol = "XAUUSD",

    [Parameter(Mandatory = $false)]
    [string]$StartupPeriod = "M5",

    [Parameter(Mandatory = $true)]
    [string]$Ex5Source
)

$ErrorActionPreference = "Stop"

function Assert-Path {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathToCheck,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $PathToCheck)) {
        throw "$Description not found: $PathToCheck"
    }
}

function New-ConfigContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccountLogin,
        [Parameter(Mandatory = $true)]
        [string]$AccountPassword,
        [Parameter(Mandatory = $true)]
        [string]$AccountServer,
        [Parameter(Mandatory = $true)]
        [string]$ExpertName,
        [Parameter(Mandatory = $false)]
        [string]$PresetFileName,
        [Parameter(Mandatory = $true)]
        [string]$ChartSymbol,
        [Parameter(Mandatory = $true)]
        [string]$ChartPeriod
    )

    $lines = @(
        "[Common]"
        "Login=$AccountLogin"
        "Password=$AccountPassword"
        "Server=$AccountServer"
        "Portable=1"
        ""
        "[Experts]"
        "AllowLiveTrading=1"
        "AllowDllImport=1"
        "Enabled=1"
        ""
        "[StartUp]"
        "Expert=$ExpertName"
    )

    if (-not [string]::IsNullOrWhiteSpace($PresetFileName)) {
        $lines += "ExpertParameters=$PresetFileName"
    }

    $lines += @(
        "Symbol=$ChartSymbol"
        "Period=$ChartPeriod"
    )

    return $lines -join [Environment]::NewLine
}

function Get-NormalizedExitCode {
    param(
        [Parameter(Mandatory = $true)]
        $RawExitCode
    )

    if ($RawExitCode -is [int]) {
        return $RawExitCode
    }

    $rawText = [string]$RawExitCode
    if ($rawText -match '^-?\d+') {
        return [int]$Matches[0]
    }

    return -1
}

function Assert-ConfigReady {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    Assert-Path -PathToCheck $ConfigPath -Description "Config INI"
    $configText = Get-Content -LiteralPath $ConfigPath -Raw

    if ([string]::IsNullOrWhiteSpace($configText)) {
        throw "Config INI is empty: $ConfigPath"
    }

    $missing = @()
    foreach ($key in @("Login=", "Password=", "Server=")) {
        if ($configText -notmatch [Regex]::Escape($key)) {
            $missing += $key.TrimEnd("=")
        }
    }
    if ($missing.Count -gt 0) {
        throw "Config INI is missing required keys: $($missing -join ', ')"
    }

    if ($configText -match "YOUR_ACCOUNT_NUMBER|YOUR_PASSWORD|YOUR_BROKER_SERVER") {
        throw "Config INI still contains placeholder values. Update Login/Password/Server before running."
    }
}

function Set-StartupConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        [Parameter(Mandatory = $true)]
        [string]$ExpertName,
        [Parameter(Mandatory = $false)]
        [string]$PresetFileName,
        [Parameter(Mandatory = $true)]
        [string]$ChartSymbol,
        [Parameter(Mandatory = $true)]
        [string]$ChartPeriod
    )

    Assert-Path -PathToCheck $ConfigPath -Description "Config INI"
    $content = Get-Content -LiteralPath $ConfigPath -Raw

    $startupLines = @(
        "[StartUp]"
        "Expert=$ExpertName"
    )
    if (-not [string]::IsNullOrWhiteSpace($PresetFileName)) {
        $startupLines += "ExpertParameters=$PresetFileName"
    }
    $startupLines += @(
        "Symbol=$ChartSymbol"
        "Period=$ChartPeriod"
    )
    $startupBlock = ($startupLines -join [Environment]::NewLine) + [Environment]::NewLine

    $pattern = '(?ms)^\[StartUp\]\r?\n.*?(?=^\[|\z)'
    if ($content -match $pattern) {
        $updated = [regex]::Replace($content, $pattern, $startupBlock)
    } else {
        $separator = ""
        if (-not $content.EndsWith([Environment]::NewLine)) {
            $separator = [Environment]::NewLine
        }
        $updated = $content + $separator + [Environment]::NewLine + $startupBlock
    }

    Set-Content -LiteralPath $ConfigPath -Value $updated -Encoding ascii
}

$installerUrl = "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
$installerPath = Join-Path $env:TEMP "mt5setup.exe"
$terminalPath = Join-Path $Mt5Dir "terminal64.exe"
$configTarget = Join-Path $Mt5Dir "config.ini"
$expertsDir = Join-Path $Mt5Dir "MQL5\Experts"
$presetsDir = Join-Path $Mt5Dir "MQL5\Presets"
$expertFileName = Split-Path -Path $Ex5Source -Leaf
$expertName = [System.IO.Path]::GetFileNameWithoutExtension($expertFileName)
$expertTarget = Join-Path $expertsDir $expertFileName
$setTarget = $null
$setFileName = $null
$hasEnvConfig = -not [string]::IsNullOrWhiteSpace($Login) -and -not [string]::IsNullOrWhiteSpace($Password) -and -not [string]::IsNullOrWhiteSpace($Server)

Write-Host "Validating source files..."
Assert-Path -PathToCheck $Ex5Source -Description "Expert EX5"
if ([string]::IsNullOrWhiteSpace($SetSource)) {
    $defaultSetSource = Join-Path $PSScriptRoot "ea-inputs.set"
    if (Test-Path -LiteralPath $defaultSetSource) {
        $SetSource = $defaultSetSource
        Write-Host "Auto-detected SET preset: $SetSource"
    }
}
if (-not [string]::IsNullOrWhiteSpace($SetSource)) {
    Assert-Path -PathToCheck $SetSource -Description "EA preset SET"
    $setFileName = Split-Path -Path $SetSource -Leaf
    $setTarget = Join-Path $presetsDir $setFileName
}
if (-not $hasEnvConfig) {
    Assert-Path -PathToCheck $ConfigSource -Description "Config INI"
}

if ((Test-Path -LiteralPath $terminalPath) -and (-not $ForceInstall)) {
    Write-Host "MT5 already installed at $Mt5Dir, skipping install step."
} else {
    if ($ForceInstall) {
        Write-Host "ForceInstall enabled, reinstalling MT5..."
    }
    Write-Host "Downloading MT5 installer..."
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
    Assert-Path -PathToCheck $installerPath -Description "Downloaded installer"

    Write-Host "Installing MT5 to $Mt5Dir ..."
    New-Item -ItemType Directory -Path $Mt5Dir -Force | Out-Null
    $installArgs = "/auto /path:`"$Mt5Dir`""
    $installProc = Start-Process -FilePath $installerPath -ArgumentList $installArgs -PassThru -Wait -WindowStyle Hidden
    $normalizedExitCode = Get-NormalizedExitCode -RawExitCode $installProc.ExitCode
    if ($normalizedExitCode -ne 0) {
        if (Test-Path -LiteralPath $terminalPath) {
            Write-Warning "MT5 installer returned exit code $normalizedExitCode (raw: $($installProc.ExitCode)), but terminal64.exe exists. Continuing."
        } else {
            throw "MT5 installation failed. Exit code: $normalizedExitCode (raw: $($installProc.ExitCode))"
        }
    }
}

Assert-Path -PathToCheck $terminalPath -Description "terminal64.exe"

Write-Host "Copying automation files..."
New-Item -ItemType Directory -Path $expertsDir -Force | Out-Null
if ($setTarget -ne $null) {
    New-Item -ItemType Directory -Path $presetsDir -Force | Out-Null
}
if ($hasEnvConfig) {
    Write-Host "Generating config.ini from MT5_LOGIN/MT5_PASSWORD/MT5_SERVER..."
    New-ConfigContent -AccountLogin $Login -AccountPassword $Password -AccountServer $Server -ExpertName $expertName -PresetFileName $setFileName -ChartSymbol $StartupSymbol -ChartPeriod $StartupPeriod | Set-Content -LiteralPath $configTarget -Encoding ascii
} else {
    Write-Host "Using config file from $ConfigSource ..."
    Copy-Item -LiteralPath $ConfigSource -Destination $configTarget -Force
}

Copy-Item -LiteralPath $Ex5Source -Destination $expertTarget -Force
if ($setTarget -ne $null) {
    Copy-Item -LiteralPath $SetSource -Destination $setTarget -Force
}

Assert-Path -PathToCheck $configTarget -Description "Target config.ini"
Assert-ConfigReady -ConfigPath $configTarget
Assert-Path -PathToCheck $expertTarget -Description "Target EX5"
if ($setTarget -ne $null) {
    Assert-Path -PathToCheck $setTarget -Description "Target SET"
}
Set-StartupConfig -ConfigPath $configTarget -ExpertName $expertName -PresetFileName $setFileName -ChartSymbol $StartupSymbol -ChartPeriod $StartupPeriod

if (-not $NoLaunch) {
    Write-Host "Starting MT5 in portable mode with config..."
    $launchArgs = "/portable /config:`"$configTarget`""
    Start-Process -FilePath $terminalPath -ArgumentList $launchArgs
}

if ($setTarget -ne $null) {
    Write-Host "SET deployed to $setTarget"
}
Write-Host "Done. EX5 deployed to $expertTarget"