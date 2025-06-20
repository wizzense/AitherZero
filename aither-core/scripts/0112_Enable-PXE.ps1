#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    if ($Config.ConfigPXE -eq $true) {
        if (Get-Platform -eq 'Windows') {
            Write-CustomLog "Adding inbound firewall rule 'prov-pxe-67' (UDP 67)"
            if ($PSCmdlet.ShouldProcess('prov-pxe-67', 'Create firewall rule')) {
                New-NetFirewallRule -DisplayName prov-pxe-67 -Enabled True -Direction inbound -Protocol udp -LocalPort 67 -Action Allow -RemoteAddress any
            }
            
            Write-CustomLog "Adding inbound firewall rule 'prov-pxe-69' (UDP 69)"
            if ($PSCmdlet.ShouldProcess('prov-pxe-69', 'Create firewall rule')) {
                New-NetFirewallRule -DisplayName prov-pxe-69 -Enabled True -Direction inbound -Protocol udp -LocalPort 69 -Action Allow -RemoteAddress any
            }
            
            Write-CustomLog "Adding inbound firewall rule 'prov-pxe-17519' (TCP 17519)"
            if ($PSCmdlet.ShouldProcess('prov-pxe-17519', 'Create firewall rule')) {
                New-NetFirewallRule -DisplayName prov-pxe-17519 -Enabled True -Direction inbound -Protocol tcp -LocalPort 17519 -Action Allow -RemoteAddress any
            }
            
            Write-CustomLog "Adding inbound firewall rule 'prov-pxe-17530' (TCP 17530)"
            if ($PSCmdlet.ShouldProcess('prov-pxe-17530', 'Create firewall rule')) {
                New-NetFirewallRule -DisplayName prov-pxe-17530 -Enabled True -Direction inbound -Protocol tcp -LocalPort 17530 -Action Allow -RemoteAddress any
            }
            
            Write-CustomLog 'PXE firewall rules configured'
        } else {
            Write-CustomLog 'PXE configuration is only supported on Windows platform' -Level 'WARN'
        }
    } else {
        Write-CustomLog 'ConfigPXE flag is disabled. Skipping configuration.'
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"

