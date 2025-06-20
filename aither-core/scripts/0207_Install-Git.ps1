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
    
    if ($Config.InstallGit -eq $true) {
        if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
            Write-CustomLog "Installing Git..."
            $url = 'https://github.com/git-for-windows/git/releases/download/v2.48.1.windows.1/Git-2.48.1-64-bit.exe'
            
            Invoke-LabDownload -Uri $url -Prefix 'git-installer' -Extension '.exe' -Action {
                param($installer)
                if ($PSCmdlet.ShouldProcess($installer, 'Install Git')) {
                    Start-Process -FilePath $installer -ArgumentList '/SILENT' -Wait
                }
            }
            Write-CustomLog "Git installation completed."
        } else {
            Write-CustomLog "Git is already installed."
        }
    } else {
        Write-CustomLog "InstallGit flag is disabled. Skipping installation."
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"