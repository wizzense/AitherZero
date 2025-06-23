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

