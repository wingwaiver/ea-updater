param(
    [Parameter(Mandatory = $false)]
    [string]$PlanPath = "$PSScriptRoot\deployment.plan.json",

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

function Add-FileIfExists {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[string]]$Bucket,
        [Parameter(Mandatory = $false)]
        [string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return
    }

    if (-not (Test-Path -LiteralPath $PathValue)) {
        throw "Referenced file not found: $PathValue"
    }

    $resolved = (Resolve-Path -LiteralPath $PathValue).Path
    if (-not $Bucket.Contains($resolved)) {
        $Bucket.Add($resolved)
    }
}

function Resolve-VpsPassword {
    param(
        [Parameter(Mandatory = $true)]
        $Vps
    )

    if (-not [string]::IsNullOrWhiteSpace([string]$Vps.password)) {
        return [string]$Vps.password
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Vps.passwordEnv)) {
        $envName = [string]$Vps.passwordEnv
        $envValue = [Environment]::GetEnvironmentVariable($envName)
        if ([string]::IsNullOrWhiteSpace($envValue)) {
            throw "Environment variable '$envName' is empty or not set for VPS '$([string]$Vps.host)'."
        }
        return $envValue
    }

    throw "Missing VPS password. Provide 'password' or 'passwordEnv'."
}

Assert-PlanField -Value $PlanPath -FieldName "PlanPath"
if (-not (Test-Path -LiteralPath $PlanPath)) {
    throw "Deployment plan not found: $PlanPath"
}

$plan = Get-Content -LiteralPath $PlanPath -Raw | ConvertFrom-Json
if (-not $plan.vps -or $plan.vps.Count -eq 0) {
    throw "Deployment plan must contain at least one entry in 'vps'."
}

$defaults = $plan.defaults

$filesToCopy = [System.Collections.Generic.List[string]]::new()
Add-FileIfExists -Bucket $filesToCopy -PathValue (Join-Path $PSScriptRoot "install.ps1")
Add-FileIfExists -Bucket $filesToCopy -PathValue (Resolve-LocalPath (Get-ValueOrDefault -PrimaryValue $defaults.brokerCatalogPath -FallbackValue "brokers.json"))

foreach ($vps in $plan.vps) {
    Assert-PlanField -Value $vps.host -FieldName "vps.host"
    Assert-PlanField -Value $vps.username -FieldName "vps.username"
    Resolve-VpsPassword -Vps $vps | Out-Null

    if (-not $vps.instances -or $vps.instances.Count -eq 0) {
        throw "Each VPS must contain at least one instance."
    }

    foreach ($instance in $vps.instances) {
        $localEx5 = Resolve-LocalPath (Get-ValueOrDefault -PrimaryValue $instance.ex5Source -FallbackValue $defaults.ex5Source)
        Add-FileIfExists -Bucket $filesToCopy -PathValue $localEx5

        $setValue = Get-ValueOrDefault -PrimaryValue $instance.setSource -FallbackValue $defaults.setSource
        if (-not [string]::IsNullOrWhiteSpace($setValue)) {
            Add-FileIfExists -Bucket $filesToCopy -PathValue (Resolve-LocalPath $setValue)
        }
    }
}

$results = [System.Collections.Generic.List[object]]::new()

if ($DryRun) {
    Write-Host "DRY RUN: No connection or deployment will be performed."
    foreach ($vps in $plan.vps) {
        $vpsName = Get-ValueOrDefault -PrimaryValue $vps.name -FallbackValue $vps.host
        $remoteWorkspace = Get-ValueOrDefault -PrimaryValue $vps.remoteWorkspace -FallbackValue (Get-ValueOrDefault -PrimaryValue $defaults.remoteWorkspace -FallbackValue "C:\ea-updater")
        Write-Host "---- $vpsName ($($vps.host)) ----"
        Write-Host "Remote workspace: $remoteWorkspace"
        foreach ($instance in $vps.instances) {
            $instanceName = Get-ValueOrDefault -PrimaryValue $instance.name -FallbackValue "instance"
            $resolvedEx5 = Resolve-LocalPath (Get-ValueOrDefault -PrimaryValue $instance.ex5Source -FallbackValue $defaults.ex5Source)
            $resolvedSet = Get-ValueOrDefault -PrimaryValue $instance.setSource -FallbackValue $defaults.setSource
            $resolvedSetDisplay = ""
            if (-not [string]::IsNullOrWhiteSpace($resolvedSet)) {
                $resolvedSetDisplay = Resolve-LocalPath $resolvedSet
            } else {
                $resolvedSetDisplay = "<none>"
            }
            $resolvedBroker = [string](Get-ValueOrDefault -PrimaryValue $instance.brokerName -FallbackValue $defaults.brokerName)
            $resolvedDir = [string](Get-ValueOrDefault -PrimaryValue $instance.mt5Dir -FallbackValue $defaults.mt5Dir)
            Write-Host "Instance: $instanceName | Broker: $resolvedBroker | Mt5Dir: $resolvedDir"
            Write-Host "  EX5: $resolvedEx5"
            Write-Host "  SET: $resolvedSetDisplay"
        }
    }
    return
}

foreach ($vps in $plan.vps) {
    $vpsName = Get-ValueOrDefault -PrimaryValue $vps.name -FallbackValue $vps.host
    $remoteWorkspace = Get-ValueOrDefault -PrimaryValue $vps.remoteWorkspace -FallbackValue (Get-ValueOrDefault -PrimaryValue $defaults.remoteWorkspace -FallbackValue "C:\ea-updater")
    $port = [int](Get-ValueOrDefault -PrimaryValue $vps.port -FallbackValue 5985)
    $useSsl = [bool](Get-ValueOrDefault -PrimaryValue $vps.useSsl -FallbackValue $false)

    Write-Host "==== Connecting to $vpsName ($($vps.host)) ===="
    $resolvedVpsPassword = Resolve-VpsPassword -Vps $vps
    $securePassword = ConvertTo-SecureString -String $resolvedVpsPassword -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ([string]$vps.username, $securePassword)

    $sessionParams = @{
        ComputerName = [string]$vps.host
        Port = $port
        Credential = $credential
    }
    if ($useSsl) {
        $sessionParams["UseSSL"] = $true
    }

    $session = New-PSSession @sessionParams
    try {
        Invoke-Command -Session $session -ScriptBlock {
            param($workspace)
            New-Item -ItemType Directory -Path $workspace -Force | Out-Null
        } -ArgumentList $remoteWorkspace

        foreach ($file in $filesToCopy) {
            Copy-Item -LiteralPath $file -Destination $remoteWorkspace -ToSession $session -Force
        }

        $remoteInstallScript = Join-Path $remoteWorkspace "install.ps1"
        $remoteBrokerCatalogPath = Join-Path $remoteWorkspace (Split-Path -Path (Resolve-LocalPath (Get-ValueOrDefault -PrimaryValue $defaults.brokerCatalogPath -FallbackValue "brokers.json")) -Leaf)

        foreach ($instance in $vps.instances) {
            $instanceName = Get-ValueOrDefault -PrimaryValue $instance.name -FallbackValue "instance"
            Write-Host "Running deployment for '$instanceName' on $vpsName ..."

            $localEx5 = Resolve-LocalPath (Get-ValueOrDefault -PrimaryValue $instance.ex5Source -FallbackValue $defaults.ex5Source)
            $remoteEx5 = Join-Path $remoteWorkspace (Split-Path -Path $localEx5 -Leaf)

            $setValue = Get-ValueOrDefault -PrimaryValue $instance.setSource -FallbackValue $defaults.setSource
            $remoteSet = $null
            if (-not [string]::IsNullOrWhiteSpace($setValue)) {
                $localSet = Resolve-LocalPath $setValue
                $remoteSet = Join-Path $remoteWorkspace (Split-Path -Path $localSet -Leaf)
            }

            $installParams = @{
                Mt5Dir = [string](Get-ValueOrDefault -PrimaryValue $instance.mt5Dir -FallbackValue $defaults.mt5Dir)
                Ex5Source = $remoteEx5
                BrokerCatalogPath = $remoteBrokerCatalogPath
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
            Assert-PlanField -Value $installParams.Ex5Source -FieldName "instances.ex5Source"
            Assert-PlanField -Value $installParams.BrokerName -FieldName "instances.brokerName"
            Assert-PlanField -Value $installParams.Login -FieldName "instances.login"
            Assert-PlanField -Value $installParams.Password -FieldName "instances.password"
            Assert-PlanField -Value $installParams.Server -FieldName "instances.server"

            if ($remoteSet) {
                $installParams["SetSource"] = $remoteSet
            }

            $instanceInstallerUrl = Get-ValueOrDefault -PrimaryValue $instance.installerUrl -FallbackValue $defaults.installerUrl
            if (-not [string]::IsNullOrWhiteSpace($instanceInstallerUrl)) {
                $installParams["InstallerUrl"] = [string]$instanceInstallerUrl
            }

            if ([bool](Get-ValueOrDefault -PrimaryValue $instance.forceInstall -FallbackValue $false)) {
                $installParams["ForceInstall"] = $true
            }
            if ([bool](Get-ValueOrDefault -PrimaryValue $instance.noLaunch -FallbackValue $false)) {
                $installParams["NoLaunch"] = $true
            }

            try {
                Invoke-Command -Session $session -ScriptBlock {
                    param($scriptPath, $params)
                    & $scriptPath @params
                } -ArgumentList $remoteInstallScript, $installParams

                $results.Add([pscustomobject]@{
                    VPS = $vpsName
                    Instance = $instanceName
                    Broker = $installParams.BrokerName
                    Mt5Dir = $installParams.Mt5Dir
                    Status = "Success"
                    Error = ""
                })
            } catch {
                $results.Add([pscustomobject]@{
                    VPS = $vpsName
                    Instance = $instanceName
                    Broker = $installParams.BrokerName
                    Mt5Dir = $installParams.Mt5Dir
                    Status = "Failed"
                    Error = $_.Exception.Message
                })

                if (-not $ContinueOnError) {
                    throw
                }
            }
        }
    } finally {
        Remove-PSSession -Session $session
    }
}

Write-Host "Remote deployment completed."
if ($results.Count -gt 0) {
    $results | Format-Table -AutoSize
}

$failedCount = ($results | Where-Object { $_.Status -eq "Failed" }).Count
if ($failedCount -gt 0) {
    throw "$failedCount instance(s) failed. Check summary output for details."
}
