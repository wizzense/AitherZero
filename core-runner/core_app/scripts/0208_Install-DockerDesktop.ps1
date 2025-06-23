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
    
    if ($Config.InstallDockerDesktop -eq $true) {
        if (-not (Get-Command docker.exe -ErrorAction SilentlyContinue)) {
            Write-CustomLog "Installing Docker Desktop..."
            $url = 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'
            
            Invoke-LabDownload -Uri $url -Prefix 'docker-desktop-installer' -Extension '.exe' -Action {
                param($installer)
                if ($PSCmdlet.ShouldProcess($installer, 'Install Docker Desktop')) {
                    Start-Process -FilePath $installer -ArgumentList 'install --quiet' -Wait
                }
            }
            Write-CustomLog "Docker Desktop installation completed."
        } else {
            Write-CustomLog "Docker Desktop is already installed."
        }
    } else {
        Write-CustomLog "InstallDockerDesktop flag is disabled. Skipping installation."
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"