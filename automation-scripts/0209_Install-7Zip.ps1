#Requires -Version 7.0
# Stage: Development
# Dependencies: PackageManager
# Description: Install 7-Zip file archiver using package managers (winget priority)

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Initialize logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/utilities/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global
        $script:LoggingAvailable = $true
    }
} catch {
    # Fallback to basic output
}

# Import PackageManager module
try {
    $packageManagerPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/utilities/PackageManager.psm1"
    if (Test-Path $packageManagerPath) {
        Import-Module $packageManagerPath -Force -Global
        $script:PackageManagerAvailable = $true
    } else {
        throw "PackageManager module not found at: $packageManagerPath"
    }
} catch {
    Write-Warning "Could not load PackageManager module: $_"
    $script:PackageManagerAvailable = $false
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

Write-ScriptLog "Starting 7-Zip installation using package managers"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if 7-Zip installation is enabled
    $shouldInstall = $false
    $sevenZipConfig = @{}

    if ($config.DevelopmentTools -and $config.DevelopmentTools.'7Zip') {
        $sevenZipConfig = $config.DevelopmentTools.'7Zip'
        $shouldInstall = $sevenZipConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "7-Zip installation is not enabled in configuration"
        exit 0
    }

    # Use PackageManager if available
    if ($script:PackageManagerAvailable) {
        Write-ScriptLog "Using PackageManager module for 7-Zip installation"

        # Try package manager installation
        try {
            $preferredPackageManager = $sevenZipConfig.PreferredPackageManager
            $installResult = Install-SoftwarePackage -SoftwareName '7zip' -PreferredPackageManager $preferredPackageManager

            if ($installResult.Success) {
                Write-ScriptLog "7-Zip installed successfully via $($installResult.PackageManager)"

                # Verify installation
                $sevenZipCmd = if ($IsWindows) { '7z.exe' } else { '7z' }
                if (Get-Command $sevenZipCmd -ErrorAction SilentlyContinue) {
                    Write-ScriptLog "7-Zip is working correctly"

                    # Test 7-Zip
                    try {
                        $testOutput = & $sevenZipCmd 2>&1
                        if ($testOutput -match '7-Zip') {
                            Write-ScriptLog "7-Zip functionality verified"
                        }
                    } catch {
                        Write-ScriptLog "7-Zip installed but may not be functioning correctly" -Level 'Warning'
                    }
                }

                Write-ScriptLog "7-Zip installation completed successfully"
                exit 0
            }
        } catch {
            Write-ScriptLog "Package manager installation failed: $_" -Level 'Warning'
            Write-ScriptLog "Falling back to manual installation" -Level 'Information'
        }
    }

    # Fallback to original installation logic
    Write-ScriptLog "Using legacy installation method"

    # Platform-specific installation
    if ($IsWindows) {
        # Check if 7-Zip is already installed
        $sevenZipPaths = @(
            "${env:ProgramFiles}\7-Zip\7z.exe",
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
        )

        $existingPath = $sevenZipPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($existingPath) {
            Write-ScriptLog "7-Zip is already installed at: $(Split-Path $existingPath -Parent)"

            # Get version
            try {
                $versionInfo = (Get-Item $existingPath).VersionInfo
                Write-ScriptLog "Current version: $($versionInfo.ProductVersion)"
            } catch {
                Write-ScriptLog "Could not determine version" -Level 'Debug'
            }

            # Ensure in PATH
            $sevenZipDir = Split-Path $existingPath -Parent
            if ($env:PATH -notlike "*$sevenZipDir*") {
                $env:PATH = "$env:PATH;$sevenZipDir"
                Write-ScriptLog "Added 7-Zip to current session PATH"
            }

            exit 0
        }

        Write-ScriptLog "Installing 7-Zip for Windows..."

        # Determine download URL
        $downloadUrl = if ($sevenZipConfig.Version) {
            # Construct URL for specific version
            $version = $sevenZipConfig.Version -replace '\.', ''
            "https://www.7-zip.org/a/7z$version-x64.exe"
        } else {
            # Use latest stable version
            'https://www.7-zip.org/a/7z2408-x64.exe'
        }

        $tempInstaller = Join-Path $env:TEMP "7z_$(Get-Date -Format 'yyyyMMddHHmmss').exe"

        try {
            if ($PSCmdlet.ShouldProcess($downloadUrl, 'Download 7-Zip installer')) {
                Write-ScriptLog "Downloading from: $downloadUrl"

                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $downloadUrl -OutFile $tempInstaller -UseBasicParsing
                $ProgressPreference = 'Continue'

                Write-ScriptLog "Downloaded to: $tempInstaller"
            }

            # Run installer
            if ($PSCmdlet.ShouldProcess('7-Zip', 'Install')) {
                Write-ScriptLog "Running installer..."

                $installArgs = '/S'  # Silent install

                # Add install directory if specified
                if ($sevenZipConfig.InstallPath) {
                    $installPath = [System.Environment]::ExpandEnvironmentVariables($sevenZipConfig.InstallPath)
                    $installArgs = "/S /D=$installPath"
                }

                $process = Start-Process -FilePath $tempInstaller -ArgumentList $installArgs -Wait -PassThru

                if ($process.ExitCode -ne 0) {
                    throw "Installer exited with code: $($process.ExitCode)"
                }

                Write-ScriptLog "Installation completed"
            }

            # Clean up
            Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue

        } catch {
            # Clean up on failure
            if (Test-Path $tempInstaller) {
                Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
            }
            throw
        }

        # Verify installation
        $installedPath = $sevenZipPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

        if (-not $installedPath) {
            Write-ScriptLog "7-Zip executable not found after installation" -Level 'Error'
            exit 1
        }

        Write-ScriptLog "7-Zip installed successfully at: $(Split-Path $installedPath -Parent)"

        # Add to PATH
        $sevenZipDir = Split-Path $installedPath -Parent

        # Add to system PATH if configured
        if ($sevenZipConfig.AddToPath -eq $true) {
            try {
                $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
                if ($currentPath -notlike "*$sevenZipDir*") {
                    if ($PSCmdlet.ShouldProcess('System PATH', "Add $sevenZipDir")) {
                        [Environment]::SetEnvironmentVariable('PATH', "$currentPath;$sevenZipDir", 'Machine')
                        Write-ScriptLog "Added 7-Zip to system PATH"
                    }
                }
            } catch {
                Write-ScriptLog "Could not modify system PATH: $_" -Level 'Warning'
            }
        }

        # Add to current session
        if ($env:PATH -notlike "*$sevenZipDir*") {
            $env:PATH = "$env:PATH;$sevenZipDir"
            Write-ScriptLog "Added 7-Zip to current session PATH"
        }

    } elseif ($IsLinux) {
        # Linux installation
        Write-ScriptLog "Installing 7-Zip for Linux..."

        # Check if already installed
        if (Get-Command 7z -ErrorAction SilentlyContinue) {
            Write-ScriptLog "7-Zip is already installed"
            exit 0
        }

        # Install using package manager
        if (Get-Command apt-get -ErrorAction SilentlyContinue) {
            # Debian/Ubuntu
            if ($PSCmdlet.ShouldProcess('p7zip-full', 'Install via apt-get')) {
                & sudo apt-get update
                & sudo apt-get install -y p7zip-full
            }
        } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
            # RHEL/CentOS
            if ($PSCmdlet.ShouldProcess('p7zip p7zip-plugins', 'Install via yum')) {
                & sudo yum install -y p7zip p7zip-plugins
            }
        } else {
            Write-ScriptLog "Unsupported Linux distribution for automatic installation" -Level 'Error'
            exit 1
        }

    } elseif ($IsMacOS) {
        # macOS installation
        Write-ScriptLog "Installing 7-Zip for macOS..."

        # Check if already installed
        if (Get-Command 7z -ErrorAction SilentlyContinue) {
            Write-ScriptLog "7-Zip is already installed"
            exit 0
        }

        # Install using Homebrew
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess('p7zip', 'Install via Homebrew')) {
                & brew install p7zip
            }
        } else {
            Write-ScriptLog "Homebrew not found. Please install Homebrew first or install 7-Zip manually" -Level 'Error'
            exit 1
        }
    }

    # Final verification
    $sevenZipCmd = if ($IsWindows) { '7z.exe' } else { '7z' }
    if (-not (Get-Command $sevenZipCmd -ErrorAction SilentlyContinue)) {
        Write-ScriptLog "7-Zip command not found after installation" -Level 'Error'
        exit 1
    }

    # Test 7-Zip
    try {
        $testOutput = & $sevenZipCmd 2>&1
        if ($testOutput -match '7-Zip') {
            Write-ScriptLog "7-Zip is working correctly"
        }
    } catch {
        Write-ScriptLog "7-Zip installed but may not be functioning correctly" -Level 'Warning'
    }

    Write-ScriptLog "7-Zip installation completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Critical error during 7-Zip installation: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}