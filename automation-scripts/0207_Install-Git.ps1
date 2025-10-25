#Requires -Version 7.0
# Stage: Development
# Dependencies: PackageManager
# Description: Install Git version control system using package managers (winget priority)

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
    # Fallback to basic output
}

# Import PackageManager module
try {
    $packageManagerPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/development/DevTools.psm1"
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

Write-ScriptLog "Starting Git installation using package managers"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Git installation is enabled
    $shouldInstall = $false
    if ($config.InstallationOptions -and $config.InstallationOptions.Git) {
        $gitConfig = $config.InstallationOptions.Git
        $shouldInstall = $gitConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Git installation is not enabled in configuration"
        exit 0
    }

    # Use PackageManager if available
    if ($script:PackageManagerAvailable) {
        Write-ScriptLog "Using PackageManager module for Git installation"
        
        # Try package manager installation
        try {
            $preferredPackageManager = $gitConfig.PreferredPackageManager
            $installResult = Install-SoftwarePackage -SoftwareName 'git' -PreferredPackageManager $preferredPackageManager
            
            if ($installResult.Success) {
                Write-ScriptLog "Git installed successfully via $($installResult.PackageManager)"
                
                # Verify installation
                $version = Get-SoftwareVersion -SoftwareName 'git'
                Write-ScriptLog "Git version: $version"
                
                Write-ScriptLog "Git installation completed successfully"
                exit 0
            }
        } catch {
            Write-ScriptLog "Package manager installation failed: $_" -Level 'Warning'
            Write-ScriptLog "Falling back to manual installation" -Level 'Information'
        }
    }

    # Fallback to original installation logic
    Write-ScriptLog "Using legacy installation method"

    # Check if Git is already installed
    $gitCommand = if ($IsWindows) { 'git.exe' } else { 'git' }
    
    try {
        $gitVersion = & $gitCommand --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Git is already installed: $gitVersion"

            # Check version requirement if specified
            if ($config.InstallationOptions.Git.Version) {
                $requiredVersion = $config.InstallationOptions.Git.Version
                Write-ScriptLog "Required version: $requiredVersion" -Level 'Debug'
            }
            
            exit 0
        }
    } catch {
        Write-ScriptLog "Git not found, proceeding with installation"
    }

    # Install Git based on platform
    if ($IsWindows) {
        Write-ScriptLog "Installing Git for Windows..."
        
        # Download URL - could be updated to use configuration
        $downloadUrl = 'https://github.com/git-for-windows/git/releases/download/v2.48.1.windows.1/Git-2.48.1-64-bit.exe'
        
        $tempDir = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
            [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
        } else {
            $env:TEMP
        }
        
        $installerPath = Join-Path $tempDir 'git-installer.exe'
        
        # Download installer
        Write-ScriptLog "Downloading Git installer from $downloadUrl"
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            $ProgressPreference = 'Continue'
        } catch {
            Write-ScriptLog "Failed to download Git installer: $_" -Level 'Error'
            throw
        }
        
        # Install Git
        if ($PSCmdlet.ShouldProcess($installerPath, 'Install Git')) {
            Write-ScriptLog "Running Git installer..."
            $installArgs = @('/VERYSILENT', '/NORESTART', '/NOCANCEL', '/SP-', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS')
            
            $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -ne 0) {
                Write-ScriptLog "Git installation failed with exit code: $($process.ExitCode)" -Level 'Error'
                throw "Git installation failed"
            }

            # Refresh PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH', 'User')
        }
        
        # Clean up installer
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
        
    } elseif ($IsLinux) {
        Write-ScriptLog "Installing Git for Linux..."
        
        # Detect package manager and install
        if (Get-Command apt-get -ErrorAction SilentlyContinue) {
            sudo apt-get update
            sudo apt-get install -y git
        } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
            sudo yum install -y git
        } elseif (Get-Command dnf -ErrorAction SilentlyContinue) {
            sudo dnf install -y git
        } else {
            Write-ScriptLog "Unsupported Linux distribution - no known package manager found" -Level 'Error'
            throw "Cannot install Git on this Linux distribution"
        }
        
    } elseif ($IsMacOS) {
        Write-ScriptLog "Installing Git for macOS..."
        
        # Check for Homebrew
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            brew install git
        } else {
            Write-ScriptLog "Homebrew not found. Please install Xcode Command Line Tools: xcode-select --install" -Level 'Error'
            throw "Cannot install Git without Homebrew or Xcode Command Line Tools"
        }
    } else {
        Write-ScriptLog "Unsupported operating system" -Level 'Error'
        throw "Cannot install Git on this platform"
    }

    # Verify installation
    try {
        $gitVersion = & $gitCommand --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Git installed successfully: $gitVersion"
        } else {
            throw "Git command failed after installation"
        }
    } catch {
        Write-ScriptLog "Git installation verification failed: $_" -Level 'Error'
        throw
    }
    
    Write-ScriptLog "Git installation completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Git installation failed: $_" -Level 'Error'
    exit 1
}
