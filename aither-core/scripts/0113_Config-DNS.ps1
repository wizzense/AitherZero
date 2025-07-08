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

    if ($Config.SetDNSServers -eq $true) {
        if (Get-Platform -eq 'Windows') {
            try {
                $interface = Get-NetIPAddress -AddressFamily IPv4 | Select-Object -First 1
                $interfaceIndex = $interface.InterfaceIndex

                Write-CustomLog "Setting DNS servers to $($Config.DNSServers -join ', ') on interface $interfaceIndex"

                if ($PSCmdlet.ShouldProcess($interfaceIndex, 'Configure DNS servers')) {
                    Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ServerAddresses $Config.DNSServers
                }
                Write-CustomLog 'DNS servers configured'
            } catch {
                Write-CustomLog "Failed to configure DNS servers: $_" -Level 'ERROR'
            }
        } else {
            Write-CustomLog 'DNS configuration is only supported on Windows platform' -Level 'WARN'
        }
    } else {
        Write-CustomLog 'SetDNSServers flag is disabled. Skipping configuration.'
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
