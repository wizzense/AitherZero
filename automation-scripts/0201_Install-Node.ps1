#Requires -Version 7.0
# Stage: Development  
# Dependencies: PackageManager
# Description: Install Node.js runtime using package managers (winget priority)

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

Write-ScriptLog "Starting Node.js installation using package managers"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Node installation is enabled
    $shouldInstall = $false
    $nodeConfig = $null

    if ($config.InstallationOptions -and $config.InstallationOptions.Node) {
        $nodeConfig = $config.InstallationOptions.Node
        $shouldInstall = $nodeConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Node.js installation is not enabled in configuration"
        exit 0
    }

    # Use PackageManager if available
    if ($script:PackageManagerAvailable) {
        Write-ScriptLog "Using PackageManager module for Node.js installation"
        
        # Try package manager installation
        try {
            $preferredPackageManager = $nodeConfig.PreferredPackageManager
            $installResult = Install-SoftwarePackage -SoftwareName 'nodejs' -PreferredPackageManager $preferredPackageManager
            
            if ($installResult.Success) {
                Write-ScriptLog "Node.js installed successfully via $($installResult.PackageManager)"
                
                # Verify installation
                $version = Get-SoftwareVersion -SoftwareName 'nodejs'
                Write-ScriptLog "Node.js version: $version"
                
                # Also check npm
                try {
                    $npmVersion = Get-SoftwareVersion -SoftwareName 'nodejs' -Command 'npm --version'
                    Write-ScriptLog "npm version: $npmVersion"
                } catch {
                    Write-ScriptLog "Could not verify npm version" -Level 'Warning'
                }
                
                # Install global packages if configured
                if ($nodeConfig.GlobalPackages -and $nodeConfig.GlobalPackages.Count -gt 0) {
                    Write-ScriptLog "Installing global npm packages..."
                    
                    foreach ($package in $nodeConfig.GlobalPackages) {
                        try {
                            Write-ScriptLog "Installing global package: $package"
                            & npm install -g $package
                            
                            if ($LASTEXITCODE -ne 0) {
                                Write-ScriptLog "Failed to install $package" -Level 'Warning'
                            }
                        } catch {
                            Write-ScriptLog "Error installing $package : $_" -Level 'Warning'
                        }
                    }
                }
                
                Write-ScriptLog "Node.js installation completed successfully"
                exit 0
            }
        } catch {
            Write-ScriptLog "Package manager installation failed: $_" -Level 'Warning'
            Write-ScriptLog "Falling back to manual installation" -Level 'Information'
        }
    }

    # Fallback to original installation logic
    Write-ScriptLog "Using legacy installation method"
    
    # Check if Node is already installed
    try {
        $nodeVersion = & node --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Node.js is already installed: $nodeVersion"

            # Also check npm
            $npmVersion = & npm --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ScriptLog "npm is already installed: v$npmVersion"
            }
            
            exit 0
        }
    } catch {
        Write-ScriptLog "Node.js not found, proceeding with installation"
    }

    # Install Node.js based on platform
    if ($IsWindows) {
        Write-ScriptLog "Installing Node.js for Windows..."
        
        # Use configured URL or default
        $downloadUrl = if ($nodeConfig.InstallerUrl) {
            $nodeConfig.InstallerUrl
        } else {
            # Get latest v20 LTS version
            'https://nodejs.org/dist/v20.18.1/node-v20.18.1-x64.msi'
        }
        
        $tempDir = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
            [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
        } else {
            $env:TEMP
        }
        
        $installerPath = Join-Path $tempDir 'node-installer.msi'
        
        # Download installer
        Write-ScriptLog "Downloading Node.js installer from $downloadUrl"
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            $ProgressPreference = 'Continue'
        } catch {
            Write-ScriptLog "Failed to download Node.js installer: $_" -Level 'Error'
            throw
        }
        
        # Install Node.js
        if ($PSCmdlet.ShouldProcess($installerPath, 'Install Node.js')) {
            Write-ScriptLog "Running Node.js installer..."
            $installArgs = @('/i', $installerPath, '/quiet', '/norestart', 'ADDLOCAL=ALL')
            
            $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -ne 0) {
                Write-ScriptLog "Node.js installation failed with exit code: $($process.ExitCode)" -Level 'Error'
                throw "Node.js installation failed"
            }

            # Refresh PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH', 'User')
        }
        
        # Clean up installer
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
        
    } elseif ($IsLinux) {
        Write-ScriptLog "Installing Node.js for Linux..."
        
        # Use NodeSource repository for consistent versions
        if (Get-Command apt-get -ErrorAction SilentlyContinue) {
            # Debian/Ubuntu
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
        } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
            # RHEL/CentOS
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo yum install -y nodejs
        } else {
            Write-ScriptLog "Unsupported Linux distribution" -Level 'Error'
            throw "Cannot install Node.js on this Linux distribution"
        }
        
    } elseif ($IsMacOS) {
        Write-ScriptLog "Installing Node.js for macOS..."
        
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            brew install node
        } else {
            # Download and install pkg
            $downloadUrl = 'https://nodejs.org/dist/v20.18.1/node-v20.18.1.pkg'
            $installerPath = '/tmp/node-installer.pkg'
            
            curl -o $installerPath $downloadUrl
            sudo installer -pkg $installerPath -target /
            rm $installerPath
        }
    } else {
        Write-ScriptLog "Unsupported operating system" -Level 'Error'
        throw "Cannot install Node.js on this platform"
    }

    # Verify installation
    try {
        $nodeVersion = & node --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Node.js installed successfully: $nodeVersion"
        } else {
            throw "Node command failed after installation"
        }
        
        $npmVersion = & npm --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "npm installed successfully: v$npmVersion"
        }
    } catch {
        Write-ScriptLog "Node.js installation verification failed: $_" -Level 'Error'
        throw
    }

    # Install global packages if configured
    if ($nodeConfig.GlobalPackages -and $nodeConfig.GlobalPackages.Count -gt 0) {
        Write-ScriptLog "Installing global npm packages..."
        
        foreach ($package in $nodeConfig.GlobalPackages) {
            try {
                Write-ScriptLog "Installing global package: $package"
                & npm install -g $package
                
                if ($LASTEXITCODE -ne 0) {
                    Write-ScriptLog "Failed to install $package" -Level 'Warning'
                }
            } catch {
                Write-ScriptLog "Error installing $package : $_" -Level 'Warning'
            }
        }
    }
    
    Write-ScriptLog "Node.js installation completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Node.js installation failed: $_" -Level 'Error'
    exit 1
}