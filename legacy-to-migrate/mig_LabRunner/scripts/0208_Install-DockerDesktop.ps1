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

