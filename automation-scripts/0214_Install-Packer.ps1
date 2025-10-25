#Requires -Version 7.0
# Stage: Development
# Dependencies: None
# Description: Install HashiCorp Packer for machine image building

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

Write-ScriptLog "Starting Packer installation"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Packer installation is enabled
    $shouldInstall = $false
    $packerConfig = @{}

    if ($config.InfrastructureTools -and $config.InfrastructureTools.Packer) {
        $packerConfig = $config.InfrastructureTools.Packer
        $shouldInstall = $packerConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Packer installation is not enabled in configuration"
        exit 0
    }

    # Check if Packer is already installed
    $packerCmd = Get-Command packer -ErrorAction SilentlyContinue

    if ($packerCmd) {
        Write-ScriptLog "Packer is already installed at: $($packerCmd.Source)"
        
        # Get version
        try {
            $version = & packer version 2>&1 | Select-Object -First 1
            Write-ScriptLog "Current version: $version"

            # Check if update is needed
            if ($packerConfig.Version) {
                $currentVersion = $version -replace 'Packer v', ''
                if ($currentVersion -ne $packerConfig.Version) {
                    Write-ScriptLog "Version mismatch. Current: $currentVersion, Required: $($packerConfig.Version)"
                    $packerCmd = $null  # Force reinstall
                } else {
                    exit 0
                }
            } else {
                exit 0
            }
        } catch {
            Write-ScriptLog "Could not determine version" -Level 'Debug'
        }
    }

    # Determine installation path
    $installPath = if ($packerConfig.InstallPath) {
        [System.Environment]::ExpandEnvironmentVariables($packerConfig.InstallPath)
    } else {
        if ($IsWindows) {
            'C:\Tools\Packer'
        } else {
            '/usr/local/bin'
        }
    }
    
    Write-ScriptLog "Installing Packer to: $installPath"

    # Create installation directory
    if (-not (Test-Path $installPath)) {
        if ($PSCmdlet.ShouldProcess($installPath, 'Create directory')) {
            New-Item -ItemType Directory -Path $installPath -Force | Out-Null
        }
    }

    # Determine version to install
    $version = if ($packerConfig.Version) {
        $packerConfig.Version
    } else {
        # Get latest version from releases API
        try {
            Write-ScriptLog "Fetching latest version information..."
            $releases = Invoke-RestMethod -Uri 'https://api.github.com/repos/hashicorp/packer/releases/latest' -UseBasicParsing
            $releases.tag_name -replace 'v', ''
        } catch {
            Write-ScriptLog "Could not fetch latest version, using default" -Level 'Warning'
            '1.10.0'  # Fallback version
        }
    }
    
    Write-ScriptLog "Installing Packer version: $version"

    # Platform-specific download
    $platform = if ($IsWindows) {
        'windows'
    } elseif ($IsLinux) {
        'linux'
    } elseif ($IsMacOS) {
        'darwin'
    }
    
    $arch = if ([System.Environment]::Is64BitOperatingSystem) {
        'amd64'
    } else {
        '386'
    }

    # Special case for ARM Macs
    if ($IsMacOS -and [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq 'Arm64') {
        $arch = 'arm64'
    }
    
    $downloadUrl = "https://releases.hashicorp.com/packer/${version}/packer_${version}_${platform}_${arch}.zip"
    $tempZip = Join-Path $env:TEMP "packer_$(Get-Date -Format 'yyyyMMddHHmmss').zip"
    
    try {
        if ($PSCmdlet.ShouldProcess($downloadUrl, 'Download Packer')) {
            Write-ScriptLog "Downloading from: $downloadUrl"
            
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing
            $ProgressPreference = 'Continue'
            
            Write-ScriptLog "Downloaded to: $tempZip"
        }
        
        # Extract archive
        if ($PSCmdlet.ShouldProcess($tempZip, 'Extract archive')) {
            Write-ScriptLog "Extracting archive..."

            if ($IsWindows) {
                Expand-Archive -Path $tempZip -DestinationPath $installPath -Force
            } else {
                # Use unzip on Unix-like systems
                & unzip -o $tempZip -d $installPath
                
                # Make executable
                $packerExe = Join-Path $installPath 'packer'
                & chmod +x $packerExe
            }
            
            Write-ScriptLog "Extraction completed"
        }
        
        # Clean up
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        
    } catch {
        # Clean up on failure
        if (Test-Path $tempZip) {
            Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        }
        throw
    }

    # Add to PATH if needed
    if ($IsWindows) {
        if ($env:PATH -notlike "*$installPath*") {
            $env:PATH = "$env:PATH;$installPath"
            Write-ScriptLog "Added Packer to current session PATH"
        }
        
        # Add to system PATH if configured
        if ($packerConfig.AddToPath -eq $true) {
            try {
                $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
                if ($currentPath -notlike "*$installPath*") {
                    if ($PSCmdlet.ShouldProcess('System PATH', "Add $installPath")) {
                        [Environment]::SetEnvironmentVariable('PATH', "$currentPath;$installPath", 'Machine')
                        Write-ScriptLog "Added Packer to system PATH"
                    }
                }
            } catch {
                Write-ScriptLog "Could not modify system PATH: $_" -Level 'Warning'
            }
        }
    }

    # Verify installation
    $packerExe = if ($IsWindows) {
        Join-Path $installPath 'packer.exe'
    } else {
        Join-Path $installPath 'packer'
    }

    if (-not (Test-Path $packerExe)) {
        Write-ScriptLog "Packer executable not found after installation" -Level 'Error'
        exit 1
    }

    # Test Packer
    try {
        $testVersion = & $packerExe version 2>&1 | Select-Object -First 1
        Write-ScriptLog "Packer installed successfully: $testVersion"
    } catch {
        Write-ScriptLog "Packer installed but may not be functioning correctly" -Level 'Warning'
    }

    # Install plugins if specified
    if ($packerConfig.Plugins) {
        Write-ScriptLog "Installing Packer plugins..."
        
        foreach ($plugin in $packerConfig.Plugins) {
            if ($PSCmdlet.ShouldProcess($plugin, 'Install Packer plugin')) {
                Write-ScriptLog "Installing plugin: $plugin"
                & $packerExe plugins install $plugin 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
            }
        }
    }
    
    Write-ScriptLog "Packer installation completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Critical error during Packer installation: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}
