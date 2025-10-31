#Requires -Version 7.0
# Stage: Development
# Dependencies: PackageManager
# Description: Install Docker Desktop or Docker Engine using package managers (winget priority)
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

Write-ScriptLog "Starting Docker installation using package managers"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Docker installation is enabled
    $shouldInstall = $false
    $dockerConfig = @{
        PreferredPackageManager = $null
        AcceptLicense = $false
        EnableWSL2 = $false
        EnableHyperV = $false
        AddUserToGroup = $false
    }

    if ($config.DevelopmentTools -and $config.DevelopmentTools.Docker) {
        $dockerConfig = $config.DevelopmentTools.Docker + $dockerConfig  # Merge with defaults
        $shouldInstall = $dockerConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Docker installation is not enabled in configuration"
        exit 0
    }

    # Use PackageManager if available for Windows (Docker Desktop)
    if ($script:PackageManagerAvailable -and $IsWindows) {
        Write-ScriptLog "Using PackageManager module for Docker Desktop installation"

        # Try package manager installation
        try {
            $preferredPackageManager = $dockerConfig.PreferredPackageManager
            $installResult = Install-SoftwarePackage -SoftwareName 'docker' -PreferredPackageManager $preferredPackageManager

            if ($installResult.Success) {
                Write-ScriptLog "Docker Desktop installed successfully via $($installResult.PackageManager)"

                # Note: Docker Desktop requires manual startup and configuration
                Write-ScriptLog "Docker Desktop has been installed. You may need to:"
                Write-ScriptLog "1. Start Docker Desktop from the Start Menu"
                Write-ScriptLog "2. Accept the license agreement"
                Write-ScriptLog "3. Complete the initial setup wizard"
                Write-ScriptLog "4. Restart your computer if prompted"

                Write-ScriptLog "Docker installation completed successfully"
                exit 0
            }
        } catch {
            Write-ScriptLog "Package manager installation failed: $_" -Level 'Warning'
            Write-ScriptLog "Falling back to manual installation" -Level 'Information'
        }
    }

    # Fallback to original installation logic
    Write-ScriptLog "Using legacy installation method"

    # Check if Docker is already installed and running
    $dockerInstalled = $false
    try {
        $dockerVersion = & docker --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Docker is already installed: $dockerVersion"

            # Try to get more detailed info
            try {
                $dockerInfo = & docker info 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-ScriptLog "Docker daemon is running"
                } else {
                    Write-ScriptLog "Docker is installed but daemon may not be running" -Level 'Warning'
                }
            } catch {
                Write-ScriptLog "Could not get Docker daemon status" -Level 'Debug'
            }

            $dockerInstalled = $true
        }
    } catch {
        Write-ScriptLog "Docker not found, proceeding with installation"
    }

    if ($dockerInstalled) {
        exit 0
    }

    # Platform-specific installation
    if ($IsWindows) {
        Write-ScriptLog "Installing Docker Desktop for Windows..."

        # Check system requirements
        if (-not [Environment]::Is64BitOperatingSystem) {
            Write-ScriptLog "Docker Desktop requires 64-bit Windows" -Level 'Error'
            throw "System requirements not met"
        }

        # Download Docker Desktop installer
        $downloadUrl = 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'
        $tempDir = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
            [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
        } else {
            $env:TEMP
        }

        $installerPath = Join-Path $tempDir 'DockerDesktopInstaller.exe'

        # Download installer
        Write-ScriptLog "Downloading Docker Desktop installer..."
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            $ProgressPreference = 'Continue'
        } catch {
            Write-ScriptLog "Failed to download Docker Desktop installer: $_" -Level 'Error'
            throw
        }

        # Install Docker Desktop
        if ($PSCmdlet.ShouldProcess($installerPath, 'Install Docker Desktop')) {
            Write-ScriptLog "Running Docker Desktop installer..."

            # Docker Desktop installer arguments
            $installArgs = @('install', '--quiet')

            # Add configuration options
            if ($dockerConfig.AcceptLicense -eq $true) {
                $installArgs += '--accept-license'
            }

            if ($dockerConfig.EnableWSL2 -eq $true) {
                $installArgs += '--backend=wsl-2'
            } elseif ($dockerConfig.EnableHyperV -eq $true) {
                $installArgs += '--backend=hyper-v'
            }

            $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
                Write-ScriptLog "Docker Desktop installation failed with exit code: $($process.ExitCode)" -Level 'Error'
                throw "Docker Desktop installation failed"
            }

            if ($process.ExitCode -eq 3010) {
                Write-ScriptLog "Docker Desktop installed successfully - restart required" -Level 'Warning'
            } else {
                Write-ScriptLog "Docker Desktop installed successfully"
            }
        }

        # Clean up installer
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }

    } elseif ($IsLinux) {
        Write-ScriptLog "Installing Docker Engine for Linux..."

        # Check if already installed
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            Write-ScriptLog "Docker is already installed"
            exit 0
        }

        # Install using distribution-specific method
        if (Get-Command apt-get -ErrorAction SilentlyContinue) {
            # Debian/Ubuntu
            if ($PSCmdlet.ShouldProcess('Docker Engine', 'Install via apt-get')) {
                Write-ScriptLog "Installing Docker Engine via apt-get..."

                # Update package index
                & sudo apt-get update

                # Install prerequisites
                & sudo apt-get install -y ca-certificates curl gnupg lsb-release

                # Add Docker GPG key
                & sudo mkdir -p /etc/apt/keyrings
                & curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

                # Add Docker repository
                $distrib = & lsb_release -cs
                & bash -c "echo 'deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $distrib stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"

                # Install Docker Engine
                & sudo apt-get update
                & sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

                # Start Docker service
                & sudo systemctl start docker
                & sudo systemctl enable docker

                # Add current user to docker group (optional)
                if ($dockerConfig.AddUserToGroup -eq $true) {
                    $currentUser = $env:USER
                    & sudo usermod -aG docker $currentUser
                    Write-ScriptLog "Added $currentUser to docker group. Please log out and back in for changes to take effect."
                }
            }
        } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
            # RHEL/CentOS
            if ($PSCmdlet.ShouldProcess('Docker Engine', 'Install via yum')) {
                Write-ScriptLog "Installing Docker Engine via yum..."

                # Add Docker repository
                & sudo yum install -y yum-utils
                & sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

                # Install Docker Engine
                & sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

                # Start Docker service
                & sudo systemctl start docker
                & sudo systemctl enable docker

                # Add current user to docker group (optional)
                if ($dockerConfig.AddUserToGroup -eq $true) {
                    $currentUser = $env:USER
                    & sudo usermod -aG docker $currentUser
                    Write-ScriptLog "Added $currentUser to docker group. Please log out and back in for changes to take effect."
                }
            }
        } else {
            Write-ScriptLog "Unsupported Linux distribution for automatic Docker installation" -Level 'Error'
            throw "Cannot install Docker on this Linux distribution"
        }

    } elseif ($IsMacOS) {
        Write-ScriptLog "Installing Docker Desktop for macOS..."

        # Check if already installed
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            Write-ScriptLog "Docker is already installed"
            exit 0
        }

        # Install using Homebrew
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess('docker', 'Install via Homebrew')) {
                # Install Docker Desktop via Homebrew Cask
                & brew install --cask docker

                Write-ScriptLog "Docker Desktop installed. Please start Docker from Applications folder."
            }
        } else {
            # Download Docker Desktop for Mac manually
            $arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } else { 'amd64' }
            $downloadUrl = "https://desktop.docker.com/mac/main/$arch/Docker.dmg"
            $dmgPath = "/tmp/Docker.dmg"

            Write-ScriptLog "Downloading Docker Desktop for Mac..."
            & curl -L -o $dmgPath $downloadUrl

            # Mount DMG and copy to Applications
            & hdiutil attach $dmgPath
            & sudo cp -R "/Volumes/Docker/Docker.app" /Applications/
            & hdiutil detach "/Volumes/Docker"
            & rm $dmgPath

            Write-ScriptLog "Docker Desktop installed. Please start Docker from Applications folder."
        }
    } else {
        Write-ScriptLog "Unsupported operating system" -Level 'Error'
        throw "Cannot install Docker on this platform"
    }

    # Verify installation (may not work immediately on Windows/macOS as Docker Desktop needs to be started)
    Write-ScriptLog "Verifying Docker installation..."
    try {
        $dockerVersion = & docker --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Docker installation verified: $dockerVersion"
        } else {
            Write-ScriptLog "Docker installed but not yet available. May need to start Docker Desktop manually." -Level 'Warning'
        }
    } catch {
        Write-ScriptLog "Docker installation verification skipped - this is normal for fresh Docker Desktop installations" -Level 'Information'
    }

    Write-ScriptLog "Docker installation completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Docker installation failed: $_" -Level 'Error'
    exit 1
}