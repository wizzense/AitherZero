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

    # Check if OpenTofu is already installed
    try {
        $tofuVersion = & tofu version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-CustomLog "OpenTofu is already installed: $tofuVersion"
            return
        }
    } catch {
        # OpenTofu not found, proceed with installation
    }

    # Install OpenTofu
    if ($IsWindows) {
        Write-CustomLog "Installing OpenTofu on Windows..."
        try {
            # Download and install OpenTofu for Windows
            $downloadUrl = "https://github.com/opentofu/opentofu/releases/latest/download/tofu_1.6.0_windows_amd64.zip"
            $tempFile = Join-Path $env:TEMP "tofu.zip"
            $installPath = Join-Path $env:ProgramFiles "OpenTofu"
            
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile
            Expand-Archive -Path $tempFile -DestinationPath $installPath -Force

            # Add to PATH if not already there
            $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
            if ($currentPath -notlike "*$installPath*") {
                [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$installPath", "Machine")
            }
            
            Remove-Item $tempFile -ErrorAction SilentlyContinue
            Write-CustomLog "OpenTofu installed successfully"
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to install OpenTofu: $($_.Exception.Message)"
        }
    } else {
        Write-CustomLog "Please install OpenTofu manually from https://opentofu.org/docs/intro/install/"
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"

