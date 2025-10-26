#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: None
# Description: Install Tailscale VPN for secure networking
# Tags: networking, vpn, security, tailscale

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

Write-ScriptLog "Starting Tailscale installation check"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Tailscale installation is enabled
    $shouldInstall = $false
    if ($config.Features -and $config.Features.Infrastructure -and $config.Features.Infrastructure.Tailscale) {
        $tailscaleConfig = $config.Features.Infrastructure.Tailscale
        $shouldInstall = $tailscaleConfig.Enabled -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Tailscale installation is not enabled in configuration"
        exit 0
    }

    # Check if Tailscale is already installed
    try {
        $tailscaleVersion = & tailscale version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Tailscale is already installed: $($tailscaleVersion -split "`n" | Select-Object -First 1)"
            exit 0
        }
    } catch {
        Write-ScriptLog "Tailscale not found, proceeding with installation"
    }

    Write-ScriptLog "Installing Tailscale..."

    # Install based on platform
    if ($IsWindows) {
        # Windows installation via MSI
        Write-ScriptLog "Installing Tailscale on Windows"
        
        $downloadUrl = "https://pkgs.tailscale.com/stable/tailscale-setup-latest.msi"
        $tempDir = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
            [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
        } else {
            $env:TEMP
        }
        
        $tempFile = Join-Path $tempDir "tailscale-setup.msi"

        # Download
        Write-ScriptLog "Downloading Tailscale from: $downloadUrl"
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
            $ProgressPreference = 'Continue'
        } catch {
            Write-ScriptLog "Failed to download Tailscale: $_" -Level 'Error'
            throw
        }

        # Install
        Write-ScriptLog "Installing Tailscale MSI package"
        try {
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$tempFile`"", "/quiet", "/norestart" -Wait -Verb RunAs
        } catch {
            Write-ScriptLog "Failed to install Tailscale: $_" -Level 'Error'
            throw
        }

        # Clean up
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

    } elseif ($IsLinux) {
        # Linux installation via package manager
        Write-ScriptLog "Installing Tailscale on Linux"
        
        # Detect Linux distribution
        if (Test-Path '/etc/os-release') {
            $osInfo = Get-Content '/etc/os-release' | ConvertFrom-StringData
            $distro = $osInfo.ID
        } else {
            $distro = "unknown"
        }

        switch -Regex ($distro) {
            'ubuntu|debian' {
                Write-ScriptLog "Installing on Debian/Ubuntu using apt"
                # Add Tailscale signing key and repository
                curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
                curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
                
                # Update package list and install
                sudo apt update
                sudo apt install -y tailscale
            }
            'centos|rhel|fedora' {
                Write-ScriptLog "Installing on RHEL/CentOS/Fedora using yum/dnf"
                # Add Tailscale repository
                sudo yum-config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/tailscale.repo
                # Install
                if (Get-Command dnf -ErrorAction SilentlyContinue) {
                    sudo dnf install -y tailscale
                } else {
                    sudo yum install -y tailscale
                }
            }
            default {
                Write-ScriptLog "Installing using universal script for $distro"
                # Use Tailscale's universal installer script
                curl -fsSL https://tailscale.com/install.sh | sh
            }
        }

    } elseif ($IsMacOS) {
        # macOS installation
        Write-ScriptLog "Installing Tailscale on macOS"
        
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            Write-ScriptLog "Installing Tailscale via Homebrew"
            brew install --cask tailscale
        } else {
            Write-ScriptLog "Installing Tailscale via direct download"
            # Download and install .pkg
            $downloadUrl = "https://pkgs.tailscale.com/stable/tailscale-latest.pkg"
            $tempFile = "/tmp/tailscale-latest.pkg"
            
            # Download
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
            
            # Install
            sudo installer -pkg $tempFile -target /
            
            # Clean up
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-ScriptLog "Unsupported operating system" -Level 'Error'
        throw "Cannot install Tailscale on this platform"
    }

    # Verify installation
    Start-Sleep -Seconds 5  # Give installation time to complete
    try {
        $tailscaleVersion = & tailscale version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Tailscale installed successfully: $($tailscaleVersion -split "`n" | Select-Object -First 1)"
        } else {
            throw "Tailscale command failed after installation"
        }
    } catch {
        Write-ScriptLog "Tailscale installation verification failed: $_" -Level 'Error'
        throw
    }

    # Start Tailscale service if configured
    if ($tailscaleConfig.AutoStart -eq $true) {
        Write-ScriptLog "Starting Tailscale service..."
        
        try {
            if ($IsWindows) {
                Start-Service -Name "Tailscale" -ErrorAction SilentlyContinue
            } elseif ($IsLinux) {
                sudo systemctl enable --now tailscaled
            } elseif ($IsMacOS) {
                # On macOS, Tailscale typically starts automatically after installation
                Write-ScriptLog "Tailscale should start automatically on macOS"
            }
            
            Write-ScriptLog "Tailscale service started"
        } catch {
            Write-ScriptLog "Failed to start Tailscale service: $_" -Level 'Warning'
        }
    }

    # Display connection instructions
    Write-ScriptLog "Tailscale installation completed successfully"
    Write-ScriptLog "To connect to your Tailscale network, run: tailscale up"
    Write-ScriptLog "To authenticate, visit the URL provided by the 'tailscale up' command"

    exit 0

} catch {
    Write-ScriptLog "Tailscale installation failed: $_" -Level 'Error'
    exit 1
}