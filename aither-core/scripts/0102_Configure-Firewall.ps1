#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

Import-Module (Join-Path $env:PROJECT_ROOT (Join-Path "aither-core" (Join-Path "modules" "LabRunner"))) -Force
Import-Module (Join-Path $env:PROJECT_ROOT (Join-Path "aither-core" (Join-Path "modules" "Logging"))) -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    Write-CustomLog "Configuring Firewall rules..."

    if ($null -ne $Config.FirewallPorts) {
        foreach ($port in $Config.FirewallPorts) {
            Write-CustomLog " - Opening TCP port $port"
            New-NetFirewallRule -DisplayName "Open Port $port" `
                                -Direction Inbound `
                                -Protocol TCP `
                                -LocalPort $port `
                                -Action Allow | Out-Null
        }
    } else {
        Write-CustomLog 'No FirewallPorts specified. Skipping.'
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
