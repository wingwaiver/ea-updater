param(
    [Parameter(Mandatory = $false)]
    [string]$Mt5Dir = "C:\MT5",

    [Parameter(Mandatory = $false)]
    [switch]$ForceInstall,

    [Parameter(Mandatory = $false)]
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

function Resolve-SingleFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $files = Get-ChildItem -Path $PSScriptRoot -Filter $Pattern -File
    if ($files.Count -eq 0) {
        throw "No $Description file found in $PSScriptRoot (pattern: $Pattern)"
    }
    if ($files.Count -gt 1) {
        $list = ($files | ForEach-Object { $_.Name }) -join ", "
        throw "Multiple $Description files found: $list. Keep only one."
    }
    return $files[0].FullName
}

$installScript = Join-Path $PSScriptRoot "install.ps1"
if (-not (Test-Path -LiteralPath $installScript)) {
    throw "install.ps1 not found at $installScript"
}

$ex5Path = Resolve-SingleFile -Pattern "*.ex5" -Description "EX5"
$configPath = Resolve-SingleFile -Pattern "*.ini" -Description "INI"
$setPath = Resolve-SingleFile -Pattern "*.set" -Description "SET"

Write-Host "Using EX5: $ex5Path"
Write-Host "Using INI: $configPath"
Write-Host "Using SET: $setPath"

$params = @{
    Mt5Dir = $Mt5Dir
    Ex5Source = $ex5Path
    ConfigSource = $configPath
    SetSource = $setPath
}

if ($ForceInstall) {
    $params["ForceInstall"] = $true
}
if ($NoLaunch) {
    $params["NoLaunch"] = $true
}

& $installScript @params
