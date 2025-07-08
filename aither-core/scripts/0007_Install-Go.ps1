#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
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

    # Check if Go is already installed
    try {
        $goVersion = & go version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-CustomLog "Go is already installed: $goVersion"
            return
        }
    } catch {
        # Go not found, proceed with installation
    }

    # Install Go using chocolatey if available, otherwise manual installation
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-CustomLog "Installing Go using Chocolatey..."
        try {
            & choco install golang -y
            if ($LASTEXITCODE -eq 0) {
                Write-CustomLog "Go installed successfully via Chocolatey"
            } else {
                Write-CustomLog -Level 'ERROR' -Message "Failed to install Go via Chocolatey"
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error installing Go: $($_.Exception.Message)"
        }
    } else {
        Write-CustomLog "Chocolatey not available. Please install Go manually from https://golang.org/dl/"
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
