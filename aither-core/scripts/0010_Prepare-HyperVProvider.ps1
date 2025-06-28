#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [object]$Config
)

# Source Find-ProjectRoot from relative path
. (Join-Path $PSScriptRoot (Join-Path ".." (Join-Path "shared" "Find-ProjectRoot.ps1")))
$projectRoot = Find-ProjectRoot -StartPath $PSScriptRoot
Import-Module (Join-Path $projectRoot (Join-Path "aither-core" (Join-Path "modules" "LabRunner"))) -Force
Import-Module (Join-Path $projectRoot (Join-Path "aither-core" (Join-Path "modules" "Logging"))) -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    # Prepare Hyper-V provider for OpenTofu
    if (-not $IsWindows) {
        Write-CustomLog "Hyper-V is only available on Windows. Skipping..."
        return
    }

    # Check if Hyper-V is enabled
    try {
        $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
        if ($hyperv.State -ne "Enabled") {
            Write-CustomLog "Hyper-V is not enabled. This provider will not function correctly."
        } else {
            Write-CustomLog "Hyper-V is enabled and ready"
        }
    } catch {
        Write-CustomLog -Level 'WARN' -Message "Could not check Hyper-V status: $($_.Exception.Message)"
    }

    # Ensure required PowerShell modules are available
    $requiredModules = @('Hyper-V')
    foreach ($module in $requiredModules) {
        try {
            Import-Module $module -ErrorAction Stop
            Write-CustomLog "Module $module is available"
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Required module $module is not available: $($_.Exception.Message)"
        }
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
