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
    
    if ($Config.InstallAWSCLI -eq $true) {
        if (-not (Get-Command aws.exe -ErrorAction SilentlyContinue)) {
            Write-CustomLog "Installing AWS CLI..."
            $url = 'https://awscli.amazonaws.com/AWSCLIV2.msi'
            
            Invoke-LabDownload -Uri $url -Prefix 'awscli' -Extension '.msi' -Action {
                param($msi)
                if ($PSCmdlet.ShouldProcess($msi, 'Install AWS CLI')) {
                    Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /quiet /norestart" -Wait -NoNewWindow
                }
            }
            Write-CustomLog "AWS CLI installation completed."
        } else {
            Write-CustomLog "AWS CLI is already installed."
        }
    } else {
        Write-CustomLog "InstallAWSCLI flag is disabled. Skipping installation."
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
