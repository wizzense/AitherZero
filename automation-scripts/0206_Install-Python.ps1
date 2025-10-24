#Requires -Version 7.0
# Stage: Development
# Dependencies: PackageManager
# Description: Install Python programming language using package managers (winget priority)
# Tags: development, python, programming

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

Write-ScriptLog "Starting Python installation using package managers"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Python installation is enabled
    $shouldInstall = $false
    $pythonConfig = @{}

    if ($config.DevelopmentTools -and $config.DevelopmentTools.Python) {
        $pythonConfig = $config.DevelopmentTools.Python
        $shouldInstall = $pythonConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Python installation is not enabled in configuration"
        exit 0
    }

    # Use PackageManager if available
    if ($script:PackageManagerAvailable) {
        Write-ScriptLog "Using PackageManager module for Python installation"
        
        # Try package manager installation
        try {
            $preferredPackageManager = $pythonConfig.PreferredPackageManager
            $installResult = Install-SoftwarePackage -SoftwareName 'python' -PreferredPackageManager $preferredPackageManager
            
            if ($installResult.Success) {
                Write-ScriptLog "Python installed successfully via $($installResult.PackageManager)"
                
                # Verify installation
                $version = Get-SoftwareVersion -SoftwareName 'python'
                Write-ScriptLog "Python version: $version"
                
                # Also check pip
                try {
                    $pipVersion = & pip --version 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-ScriptLog "pip version: $pipVersion"
                    }
                } catch {
                    Write-ScriptLog "Could not verify pip version" -Level 'Warning'
                }
                
                # Install packages if configured
                if ($pythonConfig.Packages -and $pythonConfig.Packages.Count -gt 0) {
                    Write-ScriptLog "Installing Python packages..."
                    
                    foreach ($package in $pythonConfig.Packages) {
                        try {
                            Write-ScriptLog "Installing package: $package"
                            & pip install $package
                            
                            if ($LASTEXITCODE -ne 0) {
                                Write-ScriptLog "Failed to install $package" -Level 'Warning'
                            }
                        } catch {
                            Write-ScriptLog "Error installing $package : $_" -Level 'Warning'
                        }
                    }
                }
                
                Write-ScriptLog "Python installation completed successfully"
                exit 0
            }
        } catch {
            Write-ScriptLog "Package manager installation failed: $_" -Level 'Warning'
            Write-ScriptLog "Falling back to manual installation" -Level 'Information'
        }
    }

    # Fallback to original installation logic
    Write-ScriptLog "Using legacy installation method"

    # Check if Python is already installed
    $pythonCmd = if ($IsWindows) { 'python.exe' } else { 'python3' }
    
    try {
        $pythonVersion = & $pythonCmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Python is already installed: $pythonVersion"

            # Also check pip
            try {
                $pipVersion = & pip --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-ScriptLog "pip is available: $pipVersion"
                }
            } catch {
                Write-ScriptLog "pip not found" -Level 'Debug'
            }
            
            exit 0
        }
    } catch {
        Write-ScriptLog "Python not found, proceeding with installation"
    }

    # Install Python based on platform
    if ($IsWindows) {
        Write-ScriptLog "Installing Python for Windows..."
        
        # Determine version to install
        $pythonVersion = if ($pythonConfig.Version) {
            $pythonConfig.Version
        } else {
            '3.12.0'  # Default to Python 3.12
        }
        
        # Construct download URL
        $downloadUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-amd64.exe"
        
        $tempDir = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
            [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
        } else {
            $env:TEMP
        }
        
        $installerPath = Join-Path $tempDir 'python-installer.exe'
        
        # Download installer
        Write-ScriptLog "Downloading Python installer from $downloadUrl"
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            $ProgressPreference = 'Continue'
        } catch {
            Write-ScriptLog "Failed to download Python installer: $_" -Level 'Error'
            throw
        }
        
        # Install Python
        if ($PSCmdlet.ShouldProcess($installerPath, 'Install Python')) {
            Write-ScriptLog "Running Python installer..."
            
            # Build install arguments
            $installArgs = @(
                '/quiet',
                'InstallAllUsers=1',
                'PrependPath=1',
                'Include_test=0'
            )
            
            # Add optional features
            if ($pythonConfig.InstallLauncher -ne $false) {
                $installArgs += 'InstallLauncherAllUsers=1'
            }
            
            if ($pythonConfig.AssociateFiles -ne $false) {
                $installArgs += 'AssociateFiles=1'
            }
            
            if ($pythonConfig.Shortcuts -ne $false) {
                $installArgs += 'Shortcuts=1'
            }
            
            $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -ne 0) {
                Write-ScriptLog "Python installation failed with exit code: $($process.ExitCode)" -Level 'Error'
                throw "Python installation failed"
            }

            # Refresh PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH', 'User')
        }
        
        # Clean up installer
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
        
    } elseif ($IsLinux) {
        Write-ScriptLog "Installing Python for Linux..."
        
        # Most modern Linux distributions come with Python 3 pre-installed
        # Install python3-pip and development tools
        if (Get-Command apt-get -ErrorAction SilentlyContinue) {
            # Debian/Ubuntu
            if ($PSCmdlet.ShouldProcess('python3-pip python3-dev', 'Install via apt-get')) {
                & sudo apt-get update
                & sudo apt-get install -y python3 python3-pip python3-dev python3-venv
            }
        } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
            # RHEL/CentOS
            if ($PSCmdlet.ShouldProcess('python3-pip python3-devel', 'Install via yum')) {
                & sudo yum install -y python3 python3-pip python3-devel
            }
        } elseif (Get-Command dnf -ErrorAction SilentlyContinue) {
            # Fedora
            if ($PSCmdlet.ShouldProcess('python3-pip python3-devel', 'Install via dnf')) {
                & sudo dnf install -y python3 python3-pip python3-devel
            }
        } else {
            Write-ScriptLog "Unsupported Linux distribution" -Level 'Error'
            throw "Cannot install Python on this Linux distribution"
        }
        
        # Create python -> python3 symlink if it doesn't exist
        if (-not (Get-Command python -ErrorAction SilentlyContinue) -and (Get-Command python3 -ErrorAction SilentlyContinue)) {
            try {
                & sudo ln -sf /usr/bin/python3 /usr/bin/python
                Write-ScriptLog "Created python -> python3 symlink"
            } catch {
                Write-ScriptLog "Could not create python symlink" -Level 'Debug'
            }
        }
        
    } elseif ($IsMacOS) {
        Write-ScriptLog "Installing Python for macOS..."
        
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess('python@3.12', 'Install via Homebrew')) {
                # Install Python via Homebrew
                & brew install python@3.12
                
                # Create symlinks
                & brew link --force python@3.12
            }
        } else {
            # Download Python for macOS
            $pythonVersion = if ($pythonConfig.Version) {
                $pythonConfig.Version
            } else {
                '3.12.0'
            }
            
            $downloadUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-macos11.pkg"
            $pkgPath = "/tmp/python-installer.pkg"
            
            Write-ScriptLog "Downloading Python installer..."
            & curl -L -o $pkgPath $downloadUrl
            
            # Install Python
            & sudo installer -pkg $pkgPath -target /
            & rm $pkgPath
        }
    } else {
        Write-ScriptLog "Unsupported operating system" -Level 'Error'
        throw "Cannot install Python on this platform"
    }

    # Verify installation
    try {
        $pythonVersion = & $pythonCmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Python installed successfully: $pythonVersion"
        } else {
            throw "Python command failed after installation"
        }
        
        # Verify pip
        try {
            $pipVersion = & pip --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ScriptLog "pip is available: $pipVersion"
            }
        } catch {
            Write-ScriptLog "pip not available after Python installation" -Level 'Warning'
        }
    } catch {
        Write-ScriptLog "Python installation verification failed: $_" -Level 'Error'
        throw
    }

    # Install packages if configured
    if ($pythonConfig.Packages -and $pythonConfig.Packages.Count -gt 0) {
        Write-ScriptLog "Installing Python packages..."
        
        foreach ($package in $pythonConfig.Packages) {
            try {
                Write-ScriptLog "Installing package: $package"
                & pip install $package
                
                if ($LASTEXITCODE -ne 0) {
                    Write-ScriptLog "Failed to install $package" -Level 'Warning'
                }
            } catch {
                Write-ScriptLog "Error installing $package : $_" -Level 'Warning'
            }
        }
    }

    # Upgrade pip if configured
    if ($pythonConfig.UpgradePip -eq $true) {
        Write-ScriptLog "Upgrading pip to latest version..."
        try {
            & pip install --upgrade pip
        } catch {
            Write-ScriptLog "Could not upgrade pip" -Level 'Warning'
        }
    }
    
    Write-ScriptLog "Python installation completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Python installation failed: $_" -Level 'Error'
    exit 1
}