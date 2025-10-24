#Requires -Version 7.0
# Stage: Development
# Dependencies: PackageManager
# Description: Install Go programming language using package managers (winget priority)
# Tags: development, go, golang, programming

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
    # Fallback to basic output if logging module fails to load
    Write-Warning "Could not load logging module: $($_.Exception.Message)"
    $script:LoggingAvailable = $false
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

Write-ScriptLog "Starting Go installation using package managers"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Go installation is enabled
    $shouldInstall = $false
    $goConfig = @{
        PreferredPackageManager = $null
        Version = $null
        GoPath = $null
    }

    if ($config.DevelopmentTools -and $config.DevelopmentTools.Go) {
        $goConfig = $config.DevelopmentTools.Go + $goConfig  # Merge with defaults
        $shouldInstall = $goConfig.Install -eq $true
    } elseif ($config.DevelopmentTools -and $config.DevelopmentTools.Golang) {
        # Alternative configuration key for backward compatibility
        $goConfig = $config.DevelopmentTools.Golang + $goConfig  # Merge with defaults
        $shouldInstall = $goConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Go installation is not enabled in configuration"
        exit 0
    }

    # Use PackageManager if available
    if ($script:PackageManagerAvailable) {
        Write-ScriptLog "Using PackageManager module for Go installation"
        
        # Try package manager installation
        try {
            $preferredPackageManager = $goConfig.PreferredPackageManager
            $installResult = Install-SoftwarePackage -SoftwareName 'golang' -PreferredPackageManager $preferredPackageManager
            
            if ($installResult.Success) {
                Write-ScriptLog "Go installed successfully via $($installResult.PackageManager)"
                
                # Verify installation
                $version = Get-SoftwareVersion -SoftwareName 'golang'
                Write-ScriptLog "Go version: $version"
                
                # Set up GOPATH if configured
                if ($goConfig.GoPath) {
                    $goPath = [System.Environment]::ExpandEnvironmentVariables($goConfig.GoPath)
                    Write-ScriptLog "Setting GOPATH to: $goPath"
                    
                    if ($IsWindows) {
                        [Environment]::SetEnvironmentVariable('GOPATH', $goPath, 'User')
                    } else {
                        # For Unix-like systems, we'll note it but can't set permanently from here
                        Write-ScriptLog "Please add 'export GOPATH=$goPath' to your shell profile"
                    }
                }
                
                Write-ScriptLog "Go installation completed successfully"
                exit 0
            }
        } catch {
            Write-ScriptLog "Package manager installation failed: $_" -Level 'Warning'
            Write-ScriptLog "Falling back to manual installation" -Level 'Information'
        }
    }

    # Fallback to original installation logic
    Write-ScriptLog "Using legacy installation method"

    # Check if Go is already installed
    try {
        $goVersion = & go version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Go is already installed: $goVersion"
            
            # Display GOPATH and GOROOT if set
            try {
                $goRoot = & go env GOROOT 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-ScriptLog "GOROOT: $goRoot"
                }
                
                $goPath = & go env GOPATH 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-ScriptLog "GOPATH: $goPath"
                }
            } catch {
                Write-ScriptLog "Could not get Go environment variables" -Level 'Debug'
            }
            
            exit 0
        }
    } catch {
        Write-ScriptLog "Go not found, proceeding with installation"
    }

    # Determine Go version to install
    $goVersion = if ($goConfig.Version) {
        $goConfig.Version
    } else {
        '1.21.5'  # Default to a stable version
    }

    # Install Go based on platform
    if ($IsWindows) {
        Write-ScriptLog "Installing Go for Windows..."
        
        # Construct download URL
        $downloadUrl = "https://golang.org/dl/go$goVersion.windows-amd64.msi"
        
        $tempDir = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
            [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
        } else {
            $env:TEMP
        }
        
        $installerPath = Join-Path $tempDir 'go-installer.msi'
        
        # Download installer
        Write-ScriptLog "Downloading Go installer from $downloadUrl"
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            $ProgressPreference = 'Continue'
        } catch {
            Write-ScriptLog "Failed to download Go installer: $_" -Level 'Error'
            throw
        }
        
        # Install Go
        if ($PSCmdlet.ShouldProcess($installerPath, 'Install Go')) {
            Write-ScriptLog "Running Go installer..."
            $installArgs = @('/i', $installerPath, '/quiet', '/norestart')
            
            $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -ne 0) {
                Write-ScriptLog "Go installation failed with exit code: $($process.ExitCode)" -Level 'Error'
                throw "Go installation failed"
            }

            # Refresh PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH', 'User')
        }
        
        # Clean up installer
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
        
        # Set GOPATH if configured
        if ($goConfig.GoPath) {
            $goPath = [System.Environment]::ExpandEnvironmentVariables($goConfig.GoPath)
            Write-ScriptLog "Setting GOPATH to: $goPath"
            [Environment]::SetEnvironmentVariable('GOPATH', $goPath, 'User')
        }
        
    } elseif ($IsLinux) {
        Write-ScriptLog "Installing Go for Linux..."
        
        # Determine architecture
        $arch = & uname -m 2>&1
        $goArch = switch ($arch) {
            'x86_64' { 'amd64' }
            'aarch64' { 'arm64' }
            'armv6l' { 'armv6l' }
            default { 'amd64' }
        }
        
        # Download URL
        $downloadUrl = "https://golang.org/dl/go$goVersion.linux-$goArch.tar.gz"
        $tarPath = "/tmp/go$goVersion.linux-$goArch.tar.gz"
        
        # Download Go
        Write-ScriptLog "Downloading Go from $downloadUrl"
        & curl -L -o $tarPath $downloadUrl
        
        if ($LASTEXITCODE -ne 0) {
            Write-ScriptLog "Failed to download Go" -Level 'Error'
            throw "Go download failed"
        }
        
        # Install Go
        if ($PSCmdlet.ShouldProcess('/usr/local', 'Install Go')) {
            Write-ScriptLog "Installing Go to /usr/local..."
            
            # Remove existing Go installation
            & sudo rm -rf /usr/local/go
            
            # Extract new Go
            & sudo tar -C /usr/local -xzf $tarPath
            
            # Clean up
            & rm $tarPath
            
            # Add to PATH in current session
            if ($env:PATH -notlike "*:/usr/local/go/bin*") {
                $env:PATH = "$env:PATH:/usr/local/go/bin"
            }
            
            # Create or update shell profile
            $shellProfile = if ($env:SHELL -like "*zsh*") {
                "$HOME/.zshrc"
            } else {
                "$HOME/.bashrc"
            }
            
            $pathExport = 'export PATH=$PATH:/usr/local/go/bin'
            
            if (Test-Path $shellProfile) {
                $profileContent = Get-Content $shellProfile -Raw
                if ($profileContent -notlike "*$pathExport*") {
                    Add-Content -Path $shellProfile -Value "`n# Go"
                    Add-Content -Path $shellProfile -Value $pathExport
                    Write-ScriptLog "Added Go to PATH in $shellProfile"
                }
            }
            
            # Set GOPATH if configured
            if ($goConfig.GoPath) {
                $goPath = [System.Environment]::ExpandEnvironmentVariables($goConfig.GoPath)
                $goPathExport = "export GOPATH=$goPath"
                
                if (Test-Path $shellProfile) {
                    $profileContent = Get-Content $shellProfile -Raw
                    if ($profileContent -notlike "*$goPathExport*") {
                        Add-Content -Path $shellProfile -Value $goPathExport
                        Write-ScriptLog "Added GOPATH to $shellProfile"
                    }
                }
                
                # Create GOPATH directory if it doesn't exist
                if (-not (Test-Path $goPath)) {
                    New-Item -ItemType Directory -Path $goPath -Force | Out-Null
                    Write-ScriptLog "Created GOPATH directory: $goPath"
                }
            }
        }
        
    } elseif ($IsMacOS) {
        Write-ScriptLog "Installing Go for macOS..."
        
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess('go', 'Install via Homebrew')) {
                & brew install go
            }
        } else {
            # Determine architecture
            $arch = & uname -m 2>&1
            $goArch = if ($arch -eq 'arm64') { 'arm64' } else { 'amd64' }
            
            # Download Go
            $downloadUrl = "https://golang.org/dl/go$goVersion.darwin-$goArch.pkg"
            $pkgPath = "/tmp/go$goVersion.darwin-$goArch.pkg"
            
            Write-ScriptLog "Downloading Go from $downloadUrl"
            & curl -L -o $pkgPath $downloadUrl
            
            # Install Go
            & sudo installer -pkg $pkgPath -target /
            & rm $pkgPath
        }
        
        # Set GOPATH if configured
        if ($goConfig.GoPath) {
            $goPath = [System.Environment]::ExpandEnvironmentVariables($goConfig.GoPath)
            
            # Add to shell profile
            $shellProfile = if ($env:SHELL -like "*zsh*") {
                "$HOME/.zshrc"
            } else {
                "$HOME/.bash_profile"
            }
            
            $goPathExport = "export GOPATH=$goPath"
            
            if (Test-Path $shellProfile) {
                $profileContent = Get-Content $shellProfile -Raw
                if ($profileContent -notlike "*$goPathExport*") {
                    Add-Content -Path $shellProfile -Value "`n# Go"
                    Add-Content -Path $shellProfile -Value $goPathExport
                    Write-ScriptLog "Added GOPATH to $shellProfile"
                }
            }
            
            # Create GOPATH directory if it doesn't exist
            if (-not (Test-Path $goPath)) {
                New-Item -ItemType Directory -Path $goPath -Force | Out-Null
                Write-ScriptLog "Created GOPATH directory: $goPath"
            }
        }
    } else {
        Write-ScriptLog "Unsupported operating system" -Level 'Error'
        throw "Cannot install Go on this platform"
    }

    # Verify installation
    try {
        $goVersion = & go version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Go installed successfully: $goVersion"
            
            # Display Go environment
            try {
                $goRoot = & go env GOROOT 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-ScriptLog "GOROOT: $goRoot"
                }
                
                $goPath = & go env GOPATH 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-ScriptLog "GOPATH: $goPath"
                }
            } catch {
                Write-ScriptLog "Could not get Go environment variables" -Level 'Debug'
            }
        } else {
            throw "Go command failed after installation"
        }
    } catch {
        Write-ScriptLog "Go installation verification failed: $_" -Level 'Error'
        throw
    }
    
    Write-ScriptLog "Go installation completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Go installation failed: $_" -Level 'Error'
    exit 1
}