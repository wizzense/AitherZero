#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [object]$Config
)

# Source Find-ProjectRoot from relative path
. (Join-Path $PSScriptRoot (Join-Path ".." (Join-Path "shared" "Find-ProjectRoot.ps1")))
$projectRoot = Find-ProjectRoot -StartPath $PSScriptRoot
Import-Module (Join-Path $env:PWSH_MODULES_PATH "LabRunner") -Force
Import-Module (Join-Path $env:PWSH_MODULES_PATH "Logging") -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    if (-not $IsWindows) {
        Write-CustomLog "WinRM is Windows-specific. Skipping on this platform."
        return
    }

    try {
        # Enable WinRM
        Write-CustomLog "Enabling WinRM..."
        Enable-PSRemoting -Force -SkipNetworkProfileCheck
        
        # Configure WinRM settings
        Set-WSManInstance -ResourceURI winrm/config/service -ValueSet @{AllowUnencrypted="true"}
        Set-WSManInstance -ResourceURI winrm/config/service/auth -ValueSet @{Basic="true"}
        Set-WSManInstance -ResourceURI winrm/config/client -ValueSet @{AllowUnencrypted="true"}
        Set-WSManInstance -ResourceURI winrm/config/client/auth -ValueSet @{Basic="true"}
        
        Write-CustomLog "WinRM enabled successfully"
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to enable WinRM: $($_.Exception.Message)"
        throw
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"

