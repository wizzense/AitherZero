#Requires -Version 7.0
# Stage: Development
# Dependencies: Python
# Description: Install Poetry package manager for Python

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

Write-ScriptLog "Starting Poetry installation"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Poetry installation is enabled
    $shouldInstall = $false
    if ($config.DevelopmentTools -and $config.DevelopmentTools.Poetry) {
        $poetryConfig = $config.DevelopmentTools.Poetry
        $shouldInstall = $poetryConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Poetry installation is not enabled in configuration"
        exit 0
    }

    # Check for Python prerequisite
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        $python = Get-Command python3 -ErrorAction SilentlyContinue
    }

    if (-not $python) {
        Write-ScriptLog "Python is required for Poetry installation but was not found" -Level 'Error'
        exit 1
    }
    
    Write-ScriptLog "Found Python at: $($python.Source)"

    # Check if Poetry is already installed
    $existingPoetry = Get-Command poetry -ErrorAction SilentlyContinue

    if ($existingPoetry) {
        Write-ScriptLog "Poetry is already installed at: $($existingPoetry.Source)"
        
        # Check version
        try {
            $currentVersion = & poetry --version 2>&1
            Write-ScriptLog "Current Poetry version: $currentVersion"

            # Check for updates if configured
            if ($poetryConfig.CheckForUpdates -eq $true) {
                Write-ScriptLog "Checking for Poetry updates..."
                if ($PSCmdlet.ShouldProcess('Poetry', 'Check for updates')) {
                    & poetry self update 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
                }
            }
        } catch {
            Write-ScriptLog "Could not determine Poetry version: $_" -Level 'Warning'
        }
        
        exit 0
    }
    
    Write-ScriptLog "Installing Poetry..."

    # Install using pipx if available (recommended method)
    $pipx = Get-Command pipx -ErrorAction SilentlyContinue

    if ($pipx) {
        Write-ScriptLog "Installing Poetry using pipx (recommended method)"
        
        if ($PSCmdlet.ShouldProcess('Poetry', 'Install using pipx')) {
            try {
                $installCmd = "pipx install poetry"
                if ($poetryConfig.Version) {
                    $installCmd += "==$($poetryConfig.Version)"
                    Write-ScriptLog "Installing specific version: $($poetryConfig.Version)"
                }
                
                & pipx install poetry 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
                
                # Ensure pipx bin directory is in PATH
                if ($IsWindows) {
                    $pipxBinDir = Join-Path $env:USERPROFILE '.local\bin'
                } else {
                    $pipxBinDir = Join-Path $env:HOME '.local/bin'
                }
                
                if (Test-Path $pipxBinDir) {
                    $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
                    if ($currentPath -notlike "*$pipxBinDir*") {
                        [Environment]::SetEnvironmentVariable('PATH', "$currentPath;$pipxBinDir", 'User')
                        $env:PATH = "$env:PATH;$pipxBinDir"
                        Write-ScriptLog "Added pipx bin directory to PATH: $pipxBinDir"
                    }
                }
            } catch {
                Write-ScriptLog "Failed to install Poetry using pipx: $_" -Level 'Error'
                throw
            }
        }
    } else {
        # Fallback to official installer
        Write-ScriptLog "pipx not found, using official installer"
        
        if ($PSCmdlet.ShouldProcess('Poetry', 'Install using official installer')) {
            try {
                # Download installer script
                $installerUrl = 'https://install.python-poetry.org'
                $tempScript = Join-Path $env:TEMP 'install-poetry.py'
                
                Write-ScriptLog "Downloading Poetry installer..."
                Invoke-WebRequest -Uri $installerUrl -OutFile $tempScript -UseBasicParsing
                
                # Set version if specified
                $env:POETRY_VERSION = if ($poetryConfig.Version) { $poetryConfig.Version } else { $null }
                
                # Run installer
                Write-ScriptLog "Running Poetry installer..."
                & $python.Source $tempScript 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
                
                # Clean up
                Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
                
                # Add Poetry to PATH
                if ($IsWindows) {
                    $poetryBinDir = Join-Path $env:APPDATA 'Python\Scripts'
                } else {
                    $poetryBinDir = Join-Path $env:HOME '.local/bin'
                }
                
                if (Test-Path $poetryBinDir) {
                    $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
                    if ($currentPath -notlike "*$poetryBinDir*") {
                        [Environment]::SetEnvironmentVariable('PATH', "$currentPath;$poetryBinDir", 'User')
                        $env:PATH = "$env:PATH;$poetryBinDir"
                        Write-ScriptLog "Added Poetry to PATH: $poetryBinDir"
                    }
                }
            } catch {
                Write-ScriptLog "Failed to install Poetry using official installer: $_" -Level 'Error'
                throw
            }
        }
    }

    # Verify installation
    $poetry = Get-Command poetry -ErrorAction SilentlyContinue
    if ($poetry) {
        $version = & poetry --version 2>&1
        Write-ScriptLog "Poetry installed successfully: $version"
        
        # Configure Poetry if settings are provided
        if ($poetryConfig.Settings) {
            Write-ScriptLog "Configuring Poetry settings..."
            
            foreach ($setting in $poetryConfig.Settings.GetEnumerator()) {
                if ($PSCmdlet.ShouldProcess("Poetry config $($setting.Key)", 'Configure')) {
                    & poetry config $setting.Key $setting.Value 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
                }
            }
        }
    } else {
        Write-ScriptLog "Poetry installation verification failed" -Level 'Error'
        exit 1
    }
    
    Write-ScriptLog "Poetry installation completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Critical error during Poetry installation: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}
