param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Process", "CurrentUser")]
    [string]$Scope = "CurrentUser",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Assert-Windows {
    if (-not $IsWindows) {
        throw "accept-security.ps1 must be run on Windows PowerShell/PowerShell."
    }
}

function Set-ExecutionPolicySafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyScope,
        [Parameter(Mandatory = $false)]
        [switch]$ApplyForce
    )

    $current = Get-ExecutionPolicy -Scope $PolicyScope
    if ($current -eq "RemoteSigned" -or $current -eq "Bypass") {
        Write-Host "ExecutionPolicy already acceptable at scope '$PolicyScope': $current"
        return
    }

    $params = @{
        Scope = $PolicyScope
        ExecutionPolicy = "RemoteSigned"
    }
    if ($ApplyForce) {
        $params["Force"] = $true
    }

    Set-ExecutionPolicy @params
    $updated = Get-ExecutionPolicy -Scope $PolicyScope
    Write-Host "ExecutionPolicy updated at scope '$PolicyScope' -> $updated"
}

function Unblock-ProjectScripts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $targets = Get-ChildItem -Path $RootPath -File -Include "*.ps1","*.psm1","*.psd1" -Recurse
    foreach ($file in $targets) {
        try {
            Unblock-File -LiteralPath $file.FullName
        } catch {
            Write-Host "WARN: Could not unblock '$($file.FullName)': $($_.Exception.Message)"
        }
    }

    Write-Host "Unblock attempt completed for $($targets.Count) script file(s)."
}

Assert-Windows

Write-Host "Applying PowerShell security acceptance for project: $PSScriptRoot"
Set-ExecutionPolicySafe -PolicyScope $Scope -ApplyForce:$Force
Unblock-ProjectScripts -RootPath $PSScriptRoot

Write-Host ""
Write-Host "Done. Try running:"
Write-Host "  .\deploy-local.ps1 -PlanPath .\deployment.plan.json -DryRun"
