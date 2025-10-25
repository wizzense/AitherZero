#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: None
# Description: Install OpenTofu infrastructure as code tool

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Initialize logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/core/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global
        $script:LoggingAvailable = $true
    }
} catch {
    # Fallback to basic output if logging module fails to load
    Write-Warning "Could not load logging module: $($_.Exception.Message)"
    $script:LoggingAvailable = $false
}

function Write-ScriptLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $prefix = switch ($Level) {
            'Error' { 'ERROR' }
            'Warning' { 'WARN' }
            'Debug' { 'DEBUG' }
            default { 'INFO' }
        }
        Write-Host "[$timestamp] [$prefix] $Message"
    }
}

Write-ScriptLog "Starting OpenTofu installation check"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if OpenTofu installation is enabled
    $shouldInstall = $false
    if ($config.InstallationOptions -and $config.InstallationOptions.OpenTofu) {
        $tofuConfig = $config.InstallationOptions.OpenTofu
        $shouldInstall = $tofuConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "OpenTofu installation is not enabled in configuration"
        exit 0
    }

    # Check if OpenTofu is already installed
    try {
        $tofuVersion = & tofu version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "OpenTofu is already installed: $($tofuVersion -split "`n" | Select-Object -First 1)"
            exit 0
        }
    } catch {
        Write-ScriptLog "OpenTofu not found, proceeding with installation"
    }

    # Get latest version or use configured version
    $version = if ($config.InstallationOptions.OpenTofu.Version -and $config.InstallationOptions.OpenTofu.Version -ne 'latest') {
        $config.InstallationOptions.OpenTofu.Version
    } else {
        # Get latest version from GitHub API
        try {
            $latestRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/opentofu/opentofu/releases/latest' -UseBasicParsing
            $latestRelease.tag_name -replace '^v', ''
        } catch {
            Write-ScriptLog "Could not fetch latest version, using default" -Level 'Warning'
            '1.8.0'  # Fallback version
        }
    }

    Write-ScriptLog "Installing OpenTofu version: $version"

    # Install based on platform
    if ($IsWindows) {
        # Windows installation
        $arch = if ([System.Environment]::Is64BitOperatingSystem) { 'amd64' } else { '386' }
        $downloadUrl = "https://github.com/opentofu/opentofu/releases/download/v$version/tofu_${version}_windows_${arch}.zip"

        $tempDir = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
            [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
        } else {
            $env:TEMP
        }

        $tempFile = Join-Path $tempDir "opentofu_${version}.zip"
        $installPath = Join-Path $env:ProgramFiles 'OpenTofu'

        # Download
        Write-ScriptLog "Downloading OpenTofu from: $downloadUrl"
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
            $ProgressPreference = 'Continue'
        } catch {
            Write-ScriptLog "Failed to download OpenTofu: $_" -Level 'Error'
            throw
        }

        # Extract
        Write-ScriptLog "Extracting OpenTofu to: $installPath"
        if (Test-Path $installPath) {
            Remove-Item -Path $installPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null

        try {
            Expand-Archive -Path $tempFile -DestinationPath $installPath -Force
        } catch {
            Write-ScriptLog "Failed to extract OpenTofu: $_" -Level 'Error'
            throw
        }

        # Add to PATH
        $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
        if ($currentPath -notlike "*$installPath*") {
            Write-ScriptLog "Adding OpenTofu to system PATH"
            [Environment]::SetEnvironmentVariable('PATH', "$currentPath;$installPath", 'Machine')
            $env:PATH = "$env:PATH;$installPath"
        }

        # Clean up
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

    } elseif ($IsLinux) {
        # Linux installation
        $arch = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
            'X64' { 'amd64' }
            'Arm64' { 'arm64' }
            'Arm' { 'arm' }
            default { 'amd64' }
        }

        $downloadUrl = "https://github.com/opentofu/opentofu/releases/download/v$version/tofu_${version}_linux_${arch}.zip"
        $tempFile = "/tmp/opentofu_${version}.zip"

        # Download
        Write-ScriptLog "Downloading OpenTofu from: $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing

        # Extract and install
        sudo unzip -o $tempFile -d /usr/local/bin/
        sudo chmod +x /usr/local/bin/tofu

        # Clean up
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

    } elseif ($IsMacOS) {
        # macOS installation
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            Write-ScriptLog "Installing OpenTofu via Homebrew"
            brew tap opentofu/tap
            brew install opentofu
        } else {
            # Manual installation
            $arch = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
                'X64' { 'amd64' }
                'Arm64' { 'arm64' }
                default { 'amd64' }
            }

            $downloadUrl = "https://github.com/opentofu/opentofu/releases/download/v$version/tofu_${version}_darwin_${arch}.zip"
            $tempFile = "/tmp/opentofu_${version}.zip"

            # Download
            Write-ScriptLog "Downloading OpenTofu from: $downloadUrl"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing

            # Extract and install
            sudo unzip -o $tempFile -d /usr/local/bin/
            sudo chmod +x /usr/local/bin/tofu

            # Clean up
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-ScriptLog "Unsupported operating system" -Level 'Error'
        throw "Cannot install OpenTofu on this platform"
    }

    # Verify installation
    try {
        $tofuVersion = & tofu version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "OpenTofu installed successfully: $($tofuVersion -split "`n" | Select-Object -First 1)"
        } else {
            throw "OpenTofu command failed after installation"
        }
    } catch {
        Write-ScriptLog "OpenTofu installation verification failed: $_" -Level 'Error'
        throw
    }

    # Initialize OpenTofu if configured
    if ($config.InstallationOptions.OpenTofu.Initialize -eq $true) {
        Write-ScriptLog "Initializing OpenTofu working directory..."

        $workingDir = if ($config.Infrastructure -and $config.Infrastructure.WorkingDirectory) {
            $config.Infrastructure.WorkingDirectory
        } else {
            './infrastructure'
        }

        if (Test-Path $workingDir) {
            Push-Location $workingDir
            try {
                & tofu init
                Write-ScriptLog "OpenTofu initialization completed"
            } catch {
                Write-ScriptLog "OpenTofu initialization failed: $_" -Level 'Warning'
            } finally {
                Pop-Location
            }
        } else {
            Write-ScriptLog "Working directory not found: $workingDir" -Level 'Warning'
        }
    }

    Write-ScriptLog "OpenTofu installation completed successfully"
    exit 0

} catch {
    Write-ScriptLog "OpenTofu installation failed: $_" -Level 'Error'
    exit 1
}
