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

    if ($Config.InstallVSBuildTools -eq $true) {
        if (-not (Test-Path 'C:/BuildTools')) {
            Write-CustomLog "Installing Visual Studio Build Tools..."
            $url = 'https://aka.ms/vs/17/release/vs_BuildTools.exe'

            Invoke-LabDownload -Uri $url -Prefix 'vs_buildtools' -Extension '.exe' -Action {
                param($installer)
                if ($PSCmdlet.ShouldProcess($installer, 'Install VS Build Tools')) {
                    Start-Process -FilePath $installer -ArgumentList '--quiet --wait --norestart --nocache --installPath C:/BuildTools' -Wait
                }
            }
            Write-CustomLog "Visual Studio Build Tools installation completed."
        } else {
            Write-CustomLog "Visual Studio Build Tools are already installed."
        }
    } else {
        Write-CustomLog "InstallVSBuildTools flag is disabled. Skipping installation."
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
