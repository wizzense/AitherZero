#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
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

    if ($Config.DisableTCPIP6 -eq $true) {
        if (Get-Platform -eq 'Windows') {
            Write-CustomLog 'Disabling IPv6 bindings on all adapters'

            if ($PSCmdlet.ShouldProcess('IPv6 bindings', 'Disable on all adapters')) {
                Get-NetAdapterBinding -ComponentID 'ms_tcpip6' |
                    Where-Object { $_.Enabled -eq $true } |
                    Disable-NetAdapterBinding -ComponentID 'ms_tcpip6'
            }
            Write-CustomLog 'IPv6 bindings disabled'
        } else {
            Write-CustomLog 'IPv6 configuration is only supported on Windows platform' -Level 'WARN'
        }
    } else {
        Write-CustomLog 'DisableTCPIP6 flag is disabled. Skipping configuration.'
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
