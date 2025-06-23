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
    
    if ($Config.InstallVSCode -eq $true) {
        if (-not (Get-Command code.exe -ErrorAction SilentlyContinue)) {
            Write-CustomLog "Installing Visual Studio Code..."
            $url = 'https://update.code.visualstudio.com/latest/win32-x64-user/stable'
            
            Invoke-LabDownload -Uri $url -Prefix 'vscode' -Extension '.exe' -Action {
                param($installer)
                if ($PSCmdlet.ShouldProcess($installer, 'Install VS Code')) {
                    Start-Process -FilePath $installer -ArgumentList '/verysilent /suppressmsgboxes /mergetasks=!runcode' -Wait
                }
            }
            Write-CustomLog "Visual Studio Code installation completed."
        } else {
            Write-CustomLog "Visual Studio Code is already installed."
        }
    } else {
        Write-CustomLog "InstallVSCode flag is disabled. Skipping installation."
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
