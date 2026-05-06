param(
    [Parameter(Mandatory = $false)]
    [string]$PlanPath = "$PSScriptRoot\deployment.plan.json",

    [Parameter(Mandatory = $false)]
    [string]$VpsName,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$ContinueOnError
)

$ErrorActionPreference = "Stop"

function Assert-PlanField {
    param(
        [Parameter(Mandatory = $true)]
        $Value,
        [Parameter(Mandatory = $true)]
        [string]$FieldName
    )

    if ($null -eq $Value -or ([string]$Value).Trim().Length -eq 0) {
        throw "Missing required field: $FieldName"
    }
}

function Resolve-LocalPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }

    return Join-Path $PSScriptRoot $PathValue
}

function Get-ValueOrDefault {
    param(
        $PrimaryValue,
        $FallbackValue
    )

    if ($null -eq $PrimaryValue) {
        return $FallbackValue
    }

    if (($PrimaryValue -is [string]) -and [string]::IsNullOrWhiteSpace($PrimaryValue)) {
        return $FallbackValue
    }

    return $PrimaryValue
}

function Assert-FileExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,
        [Parameter(Mandatory = $true)]
        [string]$FieldName
    )

    if (-not (Test-Path -LiteralPath $PathValue)) {
        throw "Referenced file not found for '$FieldName': $PathValue"
    }
}

function Select-VpsEntries {
    param(
        [Parameter(Mandatory = $true)]
        $Plan,
        [Parameter(Mandatory = $false)]
        [string]$NameFilter
    )

    $entries = @($Plan.vps)
    if ($entries.Count -eq 0) {
        throw "Deployment plan must contain at least one entry in 'vps'."
    }

    if ([string]::IsNullOrWhiteSpace($NameFilter)) {
        return $entries
    }

    $matched = @()
    foreach ($vps in $entries) {
        $vpsResolvedName = [string](Get-ValueOrDefault -PrimaryValue $vps.name -FallbackValue $vps.host)
        if ($vpsResolvedName -eq $NameFilter) {
            $matched += $vps
        }
    }

    if ($matched.Count -eq 0) {
        $names = ($entries | ForEach-Object { [string](Get-ValueOrDefault -PrimaryValue $_.name -FallbackValue $_.host) }) -join ", "
        throw "No vps entry matched -VpsName '$NameFilter'. Available: $names"
    }

    return $matched
}

Assert-PlanField -Value $PlanPath -FieldName "PlanPath"
if (-not (Test-Path -LiteralPath $PlanPath)) {
    throw "Deployment plan not found: $PlanPath"
}

$installScript = Join-Path $PSScriptRoot "install.ps1"
if (-not (Test-Path -LiteralPath $installScript)) {
    throw "install.ps1 not found at $installScript"
}

$plan = Get-Content -LiteralPath $PlanPath -Raw | ConvertFrom-Json
$defaults = $plan.defaults
$brokerCatalogPath = Resolve-LocalPath (Get-ValueOrDefault -PrimaryValue $defaults.brokerCatalogPath -FallbackValue "brokers.json")
Assert-FileExists -PathValue $brokerCatalogPath -FieldName "defaults.brokerCatalogPath"

$selectedVpsEntries = Select-VpsEntries -Plan $plan -NameFilter $VpsName

foreach ($vps in $selectedVpsEntries) {
    if (-not $vps.instances -or $vps.instances.Count -eq 0) {
        $vpsResolvedName = [string](Get-ValueOrDefault -PrimaryValue $vps.name -FallbackValue $vps.host)
        throw "VPS entry '$vpsResolvedName' must contain at least one instance."
    }
}

if ($DryRun) {
    Write-Host "DRY RUN: No deployment will be performed."
    foreach ($vps in $selectedVpsEntries) {
        $vpsResolvedName = [string](Get-ValueOrDefault -PrimaryValue $vps.name -FallbackValue $vps.host)
        Write-Host "---- $vpsResolvedName (local) ----"
        foreach ($instance in $vps.instances) {
            $instanceName = [string](Get-ValueOrDefault -PrimaryValue $instance.name -FallbackValue "instance")
            $resolvedEx5 = Resolve-LocalPath (Get-ValueOrDefault -PrimaryValue $instance.ex5Source -FallbackValue $defaults.ex5Source)
            $resolvedSet = Get-ValueOrDefault -PrimaryValue $instance.setSource -FallbackValue $defaults.setSource
            $resolvedSetDisplay = "<none>"
            if (-not [string]::IsNullOrWhiteSpace([string]$resolvedSet)) {
                $resolvedSetDisplay = Resolve-LocalPath ([string]$resolvedSet)
            }

            $resolvedBroker = [string](Get-ValueOrDefault -PrimaryValue $instance.brokerName -FallbackValue $defaults.brokerName)
            $resolvedDir = [string](Get-ValueOrDefault -PrimaryValue $instance.mt5Dir -FallbackValue $defaults.mt5Dir)

            Write-Host "Instance: $instanceName | Broker: $resolvedBroker | Mt5Dir: $resolvedDir"
            Write-Host "  EX5: $resolvedEx5"
            Write-Host "  SET: $resolvedSetDisplay"
            Write-Host "  BrokerCatalog: $brokerCatalogPath"
        }
    }
    return
}

$results = [System.Collections.Generic.List[object]]::new()
$hasFailures = $false

foreach ($vps in $selectedVpsEntries) {
    $vpsResolvedName = [string](Get-ValueOrDefault -PrimaryValue $vps.name -FallbackValue $vps.host)
    Write-Host "==== Deploying group '$vpsResolvedName' (local) ===="

    foreach ($instance in $vps.instances) {
        $instanceName = [string](Get-ValueOrDefault -PrimaryValue $instance.name -FallbackValue "instance")
        Write-Host "Running deployment for '$instanceName' ..."

        $resolvedEx5 = Resolve-LocalPath (Get-ValueOrDefault -PrimaryValue $instance.ex5Source -FallbackValue $defaults.ex5Source)
        Assert-PlanField -Value $resolvedEx5 -FieldName "instances.ex5Source"
        Assert-FileExists -PathValue $resolvedEx5 -FieldName "instances.ex5Source"

        $setValue = Get-ValueOrDefault -PrimaryValue $instance.setSource -FallbackValue $defaults.setSource
        $resolvedSet = $null
        if (-not [string]::IsNullOrWhiteSpace([string]$setValue)) {
            $resolvedSet = Resolve-LocalPath ([string]$setValue)
            Assert-FileExists -PathValue $resolvedSet -FieldName "instances.setSource"
        }

        $installParams = @{
            Mt5Dir = [string](Get-ValueOrDefault -PrimaryValue $instance.mt5Dir -FallbackValue $defaults.mt5Dir)
            Ex5Source = $resolvedEx5
            BrokerCatalogPath = $brokerCatalogPath
            BrokerName = [string](Get-ValueOrDefault -PrimaryValue $instance.brokerName -FallbackValue $defaults.brokerName)
            StartupSymbol = [string](Get-ValueOrDefault -PrimaryValue $instance.startupSymbol -FallbackValue (Get-ValueOrDefault -PrimaryValue $defaults.startupSymbol -FallbackValue "XAUUSD"))
            StartupPeriod = [string](Get-ValueOrDefault -PrimaryValue $instance.startupPeriod -FallbackValue (Get-ValueOrDefault -PrimaryValue $defaults.startupPeriod -FallbackValue "M5"))
            Login = [string]$instance.login
            Password = [string]$instance.password
            Server = [string]$instance.server
        }

        if ([string]::IsNullOrWhiteSpace($installParams.Mt5Dir)) {
            throw "Missing mt5Dir for instance '$instanceName'"
        }
        Assert-PlanField -Value $installParams.BrokerName -FieldName "instances.brokerName"
        Assert-PlanField -Value $installParams.Login -FieldName "instances.login"
        Assert-PlanField -Value $installParams.Password -FieldName "instances.password"
        Assert-PlanField -Value $installParams.Server -FieldName "instances.server"

        if ($resolvedSet) {
            $installParams["SetSource"] = $resolvedSet
        }

        $instanceInstallerUrl = Get-ValueOrDefault -PrimaryValue $instance.installerUrl -FallbackValue $defaults.installerUrl
        if (-not [string]::IsNullOrWhiteSpace([string]$instanceInstallerUrl)) {
            $installParams["InstallerUrl"] = [string]$instanceInstallerUrl
        }
        $instanceInstallerArgsTemplate = Get-ValueOrDefault -PrimaryValue $instance.installerArgsTemplate -FallbackValue $defaults.installerArgsTemplate
        if (-not [string]::IsNullOrWhiteSpace([string]$instanceInstallerArgsTemplate)) {
            $installParams["InstallerArgsTemplate"] = [string]$instanceInstallerArgsTemplate
        }

        if ([bool](Get-ValueOrDefault -PrimaryValue $instance.forceInstall -FallbackValue $false)) {
            $installParams["ForceInstall"] = $true
        }
        if ([bool](Get-ValueOrDefault -PrimaryValue $instance.noLaunch -FallbackValue $false)) {
            $installParams["NoLaunch"] = $true
        }

        try {
            & $installScript @installParams
            $results.Add([pscustomobject]@{
                Group = $vpsResolvedName
                Instance = $instanceName
                Broker = $installParams.BrokerName
                Mt5Dir = $installParams.Mt5Dir
                Status = "success"
                Error = $null
            })
        } catch {
            $hasFailures = $true
            $results.Add([pscustomobject]@{
                Group = $vpsResolvedName
                Instance = $instanceName
                Broker = $installParams.BrokerName
                Mt5Dir = $installParams.Mt5Dir
                Status = "failed"
                Error = [string]$_.Exception.Message
            })

            Write-Host "ERROR: Instance '$instanceName' failed: $($_.Exception.Message)"
            if (-not $ContinueOnError) {
                throw
            }
        }
    }
}

Write-Host ""
Write-Host "==== Summary ===="
$results | Format-Table -AutoSize

if ($hasFailures) {
    exit 1
}
