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

    if ($Config.InstallAzureCLI -eq $true) {
        if (-not (Get-Command az.exe -ErrorAction SilentlyContinue)) {
            Write-CustomLog "Installing Azure CLI..."
            $url = 'https://aka.ms/installazurecliwindows'

            Invoke-LabDownload -Uri $url -Prefix 'azure-cli' -Extension '.msi' -Action {
                param($msi)
                if ($PSCmdlet.ShouldProcess($msi, 'Install Azure CLI')) {
                    Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /quiet /norestart" -Wait -NoNewWindow
                }
            }
            Write-CustomLog "Azure CLI installation completed."
        } else {
            Write-CustomLog "Azure CLI is already installed."
        }
    } else {
        Write-CustomLog "InstallAzureCLI flag is disabled. Skipping installation."
    }
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
