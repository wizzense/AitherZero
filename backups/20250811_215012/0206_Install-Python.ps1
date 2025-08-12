#Requires -Version 7.0
# Stage: Development
# Dependencies: None
# Description: Install Python programming language
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

Write-ScriptLog "Starting Python installation check"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Python installation is enabled
    $shouldInstall = $false
    if ($config.InstallationOptions -and $config.InstallationOptions.Python) {
        $pythonConfig = $config.InstallationOptions.Python
        $shouldInstall = $pythonConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Python installation is not enabled in configuration"
        exit 0
    }

    # Check if Python is already installed
    $pythonCmd = if ($IsWindows) { 'python.exe' } else { 'python3' }
    
    try {
        $pythonVersion = & $pythonCmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Python is already installed: $pythonVersion"

            # Check pip
            $pipVersion = & $pythonCmd -m pip --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ScriptLog "pip is available: $($pipVersion -split "`n" | Select-Object -First 1)"
            }
            
            exit 0
        }
    } catch {
        Write-ScriptLog "Python not found, proceeding with installation"
    }

    # Install Python based on platform
    if ($IsWindows) {
        Write-ScriptLog "Installing Python for Windows..."
        
        # Determine version
        $version = if ($pythonConfig.Version -and $pythonConfig.Version -ne 'latest') {
            $pythonConfig.Version
        } else {
            '3.12.3'  # Current stable version
        }
        
        $downloadUrl = "https://www.python.org/ftp/python/$version/python-$version-amd64.exe"
        
        $tempDir = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
            [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
        } else {
            $env:TEMP
        }
        
        $installerPath = Join-Path $tempDir "python-installer.exe"
        
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

            # Install arguments for silent installation
            $installArgs = @(
                '/quiet',
                'InstallAllUsers=1',
                'PrependPath=1',
                'Include_test=0',
                'Include_pip=1',
                'Include_launcher=1',
                'InstallLauncherAllUsers=1'
            )
        
            $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -ne 0) {
                Write-ScriptLog "Python installation failed with exit code: $($process.ExitCode)" -Level 'Error'
                throw "Python installation failed"
            }

            # Refresh PATH
            $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
            $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
            $env:PATH = "$machinePath;$userPath"
            
            Write-ScriptLog "PATH refreshed with Python location"
        }
        
        # Clean up installer
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
        
    } elseif ($IsLinux) {
        Write-ScriptLog "Installing Python for Linux..."
        
        # Most Linux distributions come with Python pre-installed
        # Install python3 and pip if not present
        if (Get-Command apt-get -ErrorAction SilentlyContinue) {
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip python3-venv
        } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
            sudo yum install -y python3 python3-pip
        } elseif (Get-Command dnf -ErrorAction SilentlyContinue) {
            sudo dnf install -y python3 python3-pip
        } else {
            Write-ScriptLog "Unsupported Linux distribution" -Level 'Error'
            throw "Cannot install Python on this Linux distribution"
        }
        
    } elseif ($IsMacOS) {
        Write-ScriptLog "Installing Python for macOS..."
        
        # Check for Homebrew
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            brew install python3
        } else {
            # Download and install from python.org
            $version = '3.12.3'
            $downloadUrl = "https://www.python.org/ftp/python/$version/python-$version-macos11.pkg"
            $installerPath = "/tmp/python-installer.pkg"
            
            curl -o $installerPath $downloadUrl
            sudo installer -pkg $installerPath -target /
            rm $installerPath
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

            # Upgrade pip
            Write-ScriptLog "Upgrading pip..."
            & $pythonCmd -m pip install --upgrade pip

            # Install common packages if specified
            if ($pythonConfig.Packages -and $pythonConfig.Packages.Count -gt 0) {
                Write-ScriptLog "Installing Python packages..."
                
                foreach ($package in $pythonConfig.Packages) {
                    try {
                        Write-ScriptLog "Installing package: $package"
                        & $pythonCmd -m pip install $package
                        
                        if ($LASTEXITCODE -ne 0) {
                            Write-ScriptLog "Failed to install $package" -Level 'Warning'
                        }
                    } catch {
                        Write-ScriptLog "Error installing $package : $_" -Level 'Warning'
                    }
                }
            }
        } else {
            throw "Python command failed after installation"
        }
    } catch {
        Write-ScriptLog "Python installation verification failed: $_" -Level 'Error'
        throw
    }
    
    Write-ScriptLog "Python installation completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Python installation failed: $_" -Level 'Error'
    exit 1
}