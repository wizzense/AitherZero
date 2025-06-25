#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [object]$Config
)

Import-Module "$env:PROJECT_ROOT/aither-core/modules/LabRunner" -Force
Import-Module "$env:PROJECT_ROOT/aither-core/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    if (-not $IsWindows) {
        Write-CustomLog "Hyper-V is Windows-specific. Skipping on this platform."
        return
    }

    try {
        # Check if Hyper-V is already enabled
        $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
        
        if ($hyperv.State -eq "Enabled") {
            Write-CustomLog "Hyper-V is already enabled"
        } else {
            Write-CustomLog "Enabling Hyper-V..."
            
            # Enable Hyper-V feature
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart
            
            Write-CustomLog "Hyper-V enabled successfully. Restart required."
        }
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to enable Hyper-V: $($_.Exception.Message)"
        throw
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"