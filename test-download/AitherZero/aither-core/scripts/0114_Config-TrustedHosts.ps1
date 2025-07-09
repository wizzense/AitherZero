#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

# Use shared utilities for project root detection
. "$PSScriptRoot/../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

Import-Module (Join-Path $env:PWSH_MODULES_PATH "LabRunner") -Force
Import-Module (Join-Path $env:PWSH_MODULES_PATH "Logging") -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    if ($Config.SetTrustedHosts -eq $true) {
        $trustedHosts = if ($Config.TrustedHosts) { $Config.TrustedHosts } else { '*' }
        $args = "/d /c winrm set winrm/config/client @{TrustedHosts=`"$trustedHosts`"}"
        Write-CustomLog "Configuring TrustedHosts with: $args"

        if ($PSCmdlet.ShouldProcess($trustedHosts, 'Configure WinRM TrustedHosts')) {
            Start-Process -FilePath cmd.exe -ArgumentList $args -Wait
        }
        Write-CustomLog 'TrustedHosts configured'
    } else {
        Write-CustomLog 'SetTrustedHosts flag is disabled. Skipping configuration.'
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
