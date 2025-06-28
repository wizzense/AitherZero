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

    if (-not $IsWindows) {
        Write-CustomLog "Remote Desktop is Windows-specific. Skipping on this platform."
        return
    }

    try {
        # Enable Remote Desktop
        Write-CustomLog "Enabling Remote Desktop..."
        
        # Enable RDP through registry
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
        
        # Enable RDP through WMI
        $rdp = Get-WmiObject -Class Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices
        $rdp.SetAllowTSConnections(1, 1)
        
        Write-CustomLog "Remote Desktop enabled successfully"
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to enable Remote Desktop: $($_.Exception.Message)"
        throw
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
