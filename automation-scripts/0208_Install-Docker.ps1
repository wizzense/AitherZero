#Requires -Version 7.0
# Stage: Development
# Dependencies: None
# Description: Install Docker Desktop or Docker Engine
# Tags: development, docker, containers, virtualization

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

Write-ScriptLog "Starting Docker installation check"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Docker installation is enabled
    $shouldInstall = $false
    if ($config.InstallationOptions -and $config.InstallationOptions.DockerDesktop) {
        $dockerConfig = $config.InstallationOptions.DockerDesktop
        $shouldInstall = $dockerConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Docker installation is not enabled in configuration"
        exit 0
    }

    # Check if Docker is already installed
    $dockerCmd = if ($IsWindows) { 'docker.exe' } else { 'docker' }
    
    try {
        $dockerVersion = & $dockerCmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Docker is already installed: $dockerVersion"

            # Check if Docker daemon is running
            $dockerInfo = & $dockerCmd info 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ScriptLog "Docker daemon is running"
            } else {
                Write-ScriptLog "Docker is installed but daemon is not running" -Level 'Warning'
            }
            
            exit 0
        }
    } catch {
        Write-ScriptLog "Docker not found, proceeding with installation"
    }

    # Install Docker based on platform
    if ($IsWindows) {
        Write-ScriptLog "Installing Docker Desktop for Windows..."
        
        # Check Windows version and features
        $os = Get-CimInstance Win32_OperatingSystem
        $build = [int]$os.BuildNumber
        
        if ($build -lt 17763) {
            Write-ScriptLog "Docker Desktop requires Windows 10 version 1809 or higher" -Level 'Error'
            exit 1
        }
        
        # Check if running Windows Home (which requires WSL 2 backend)
        $edition = $os.Caption
        $useWSL2 = $edition -match 'Home' -or $build -ge 19041
        
        if ($useWSL2) {
            Write-ScriptLog "Docker Desktop will use WSL 2 backend" -Level 'Debug'

            # Check if WSL 2 is installed
            try {
                $wslVersion = & wsl --version 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-ScriptLog "WSL 2 is required but not installed. Please run 'wsl --install' first." -Level 'Warning'
                }
            } catch {
                Write-ScriptLog "WSL not found. Docker Desktop may require manual configuration." -Level 'Warning'
            }
        }
        
        # Download Docker Desktop
        $downloadUrl = 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'
        
        $tempDir = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
            [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
        } else {
            $env:TEMP
        }
        
        $installerPath = Join-Path $tempDir 'docker-desktop-installer.exe'
        
        Write-ScriptLog "Downloading Docker Desktop installer..."
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            $ProgressPreference = 'Continue'
        } catch {
            Write-ScriptLog "Failed to download Docker Desktop: $_" -Level 'Error'
            throw
        }
        
        # Install Docker Desktop
        if ($PSCmdlet.ShouldProcess($installerPath, 'Install Docker Desktop')) {
            Write-ScriptLog "Running Docker Desktop installer..."
            
            $installArgs = @('install', '--quiet', '--accept-license')
            if ($useWSL2) {
                $installArgs += '--backend=wsl-2'
            }
            
            $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -eq 0) {
                Write-ScriptLog "Docker Desktop installed successfully"
                Write-ScriptLog "NOTE: You may need to log out and back in for Docker to work properly" -Level 'Warning'
            } elseif ($process.ExitCode -eq 3010) {
                Write-ScriptLog "Docker Desktop installed successfully - Restart required" -Level 'Warning'
                exit 3010
            } else {
                Write-ScriptLog "Docker Desktop installation failed with exit code: $($process.ExitCode)" -Level 'Error'
                throw "Docker Desktop installation failed"
            }
        }
        
        # Clean up installer
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
        
    } elseif ($IsLinux) {
        Write-ScriptLog "Installing Docker Engine for Linux..."
        
        # Detect Linux distribution
        if (Test-Path /etc/os-release) {
            $osInfo = Get-Content /etc/os-release | ConvertFrom-StringData
            $distro = $osInfo.ID
            $version = $osInfo.VERSION_ID
        } else {
            Write-ScriptLog "Cannot determine Linux distribution" -Level 'Error'
            exit 1
        }
        
        # Install based on distribution
        switch ($distro) {
            'ubuntu' {
                # Remove old versions
                sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null
                
                # Install prerequisites
                sudo apt-get update
                sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
                
                # Add Docker's official GPG key
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                
                # Set up repository
                & bash -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'
                
                # Install Docker Engine
                sudo apt-get update
                sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            }
            
            'debian' {
                # Similar to Ubuntu
                sudo apt-get update
                sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
                curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                & bash -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'
                sudo apt-get update
                sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            }
            
            {'centos', 'rhel', 'fedora'} {
                # Remove old versions
                sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
                
                # Install prerequisites
                sudo yum install -y yum-utils
                
                # Set up repository
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                
                # Install Docker Engine
                sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            }
            
            default {
                Write-ScriptLog "Unsupported Linux distribution: $distro" -Level 'Error'
                exit 1
            }
        }
        
        # Start and enable Docker
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # Add current user to docker group
        sudo usermod -aG docker $env:USER
        Write-ScriptLog "Added $env:USER to docker group. Log out and back in for this to take effect." -Level 'Warning'
        
    } elseif ($IsMacOS) {
        Write-ScriptLog "Installing Docker Desktop for macOS..."
        
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            # Install using Homebrew
            brew install --cask docker
        } else {
            # Download DMG
            $arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } else { 'amd64' }
            $downloadUrl = "https://desktop.docker.com/mac/main/$arch/Docker.dmg"
            $dmgPath = "/tmp/Docker.dmg"
            
            Write-ScriptLog "Downloading Docker Desktop..."
            curl -o $dmgPath $downloadUrl

            # Mount and install
            hdiutil attach $dmgPath
            sudo cp -R "/Volumes/Docker/Docker.app" /Applications/
            hdiutil detach "/Volumes/Docker"
            rm $dmgPath
            
            Write-ScriptLog "Docker Desktop installed. Please launch it from Applications." -Level 'Warning'
        }
    } else {
        Write-ScriptLog "Unsupported operating system" -Level 'Error'
        throw "Cannot install Docker on this platform"
    }

    # Post-installation verification (may fail if daemon not started)
    Start-Sleep -Seconds 5
    try {
        $dockerVersion = & $dockerCmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Docker installation verified: $dockerVersion"
        }
    } catch {
        Write-ScriptLog "Docker installed but not yet available. You may need to start Docker Desktop or reboot." -Level 'Warning'
    }
    
    Write-ScriptLog "Docker installation completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Docker installation failed: $_" -Level 'Error'
    exit 1
}