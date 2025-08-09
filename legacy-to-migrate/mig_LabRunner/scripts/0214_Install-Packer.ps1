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

    if ($Config.InstallPacker -eq $true) {
        if (-not (Get-Command packer.exe -ErrorAction SilentlyContinue)) {
            Write-CustomLog "Installing Packer..."
            $url = 'https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_windows_amd64.zip'
            $dest = Join-Path $env:ProgramFiles 'Packer'
            Invoke-LabDownload -Uri $url -Prefix 'packer' -Extension '.zip' -Action {
                param($zip)

                if (-not (Test-Path $dest)) {
                    New-Item -ItemType Directory -Path $dest -Force | Out-Null
                }
                Expand-Archive -Path $zip -DestinationPath $dest -Force

                # Add to PATH
                $env:PATH = "$env:PATH;$dest"
            }
            Write-CustomLog "Packer installation completed."
        } else {
            Write-CustomLog "Packer is already installed."
        }
    } else {
        Write-CustomLog "InstallPacker flag is disabled. Skipping installation."
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"

