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
    
    if ($Config.Install7Zip -eq $true) {
        if (-not (Get-Command 7z.exe -ErrorAction SilentlyContinue)) {
            Write-CustomLog "Installing 7-Zip..."
            $url = 'https://www.7-zip.org/a/7z2301-x64.exe'
            
            Invoke-LabDownload -Uri $url -Prefix '7zip' -Extension '.exe' -Action {
                param($installer)
                if ($PSCmdlet.ShouldProcess($installer, 'Install 7-Zip')) {
                    Start-Process -FilePath $installer -ArgumentList '/S' -Wait
                }
            }
            Write-CustomLog "7-Zip installation completed."
        } else {
            Write-CustomLog "7-Zip is already installed."
        }
    } else {
        Write-CustomLog "Install7Zip flag is disabled. Skipping installation."
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"