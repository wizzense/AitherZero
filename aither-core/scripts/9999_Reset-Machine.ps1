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
    $platform = Get-Platform
    Write-CustomLog "Detected platform: $platform"
    
    if ($platform -eq 'Windows') {
        $Config.AllowRemoteDesktop = $true
        if (-not $Config.FirewallPorts) { $Config.FirewallPorts = @() }
        if ($Config.FirewallPorts -notcontains 3389) { $Config.FirewallPorts += 3389 }

        & "$PSScriptRoot/0101_Enable-RemoteDesktop.ps1" -Config $Config
        & "$PSScriptRoot/0102_Configure-Firewall.ps1" -Config $Config

        $sysprep = 'C:/Windows/System32/Sysprep/Sysprep.exe'
        if (Test-Path $sysprep) {
            Write-CustomLog "Invoking sysprep at $sysprep"
            if ($PSCmdlet.ShouldProcess($sysprep, 'Run sysprep')) {
                Start-Process $sysprep -ArgumentList '/generalize /oobe /shutdown /quiet' -Wait
            }
        } else {
            Write-CustomLog 'Sysprep not found; unable to reset.' -Level 'ERROR'
            throw 'Sysprep not found'
        }
    } elseif ($platform -in @('Linux', 'MacOS')) {
        Write-CustomLog 'Initiating system reboot...'
        if ($PSCmdlet.ShouldProcess('localhost', 'Restart computer')) {
            Restart-Computer
        }
    } else {
        Write-CustomLog 'Unknown platform; cannot reset.' -Level 'ERROR'
        throw "Unsupported platform: $platform"
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
