#Requires -Version 7.0
# Stage: Development
# Dependencies: PackageManager
# Description: Install Azure CLI for cloud management using package managers (winget priority)

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

Write-ScriptLog "Starting Azure CLI installation using package managers"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Azure CLI installation is enabled
    $shouldInstall = $false
    $azureCliConfig = @{}

    if ($config.CloudTools -and $config.CloudTools.AzureCLI) {
        $azureCliConfig = $config.CloudTools.AzureCLI
        $shouldInstall = $azureCliConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Azure CLI installation is not enabled in configuration"
        exit 0
    }

    # Use PackageManager if available
    if ($script:PackageManagerAvailable) {
        Write-ScriptLog "Using PackageManager module for Azure CLI installation"

        # Try package manager installation
        try {
            $preferredPackageManager = $azureCliConfig.PreferredPackageManager
            $installResult = Install-SoftwarePackage -SoftwareName 'azure-cli' -PreferredPackageManager $preferredPackageManager

            if ($installResult.Success) {
                Write-ScriptLog "Azure CLI installed successfully via $($installResult.PackageManager)"

                # Verify installation
                $version = Get-SoftwareVersion -SoftwareName 'azure-cli'
                Write-ScriptLog "Azure CLI version: $version"

                # Configure if settings provided
                if ($azureCliConfig.DefaultSettings) {
                    Write-ScriptLog "Configuring Azure CLI defaults..."

                    foreach ($setting in $azureCliConfig.DefaultSettings.GetEnumerator()) {
                        if ($PSCmdlet.ShouldProcess("az config $($setting.Key)", 'Configure')) {
                            & az config set $setting.Key=$setting.Value 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
                        }
                    }
                }

                # Install extensions if specified
                if ($azureCliConfig.Extensions) {
                    Write-ScriptLog "Installing Azure CLI extensions..."

                    foreach ($extension in $azureCliConfig.Extensions) {
                        if ($PSCmdlet.ShouldProcess($extension, 'Install extension')) {
                            Write-ScriptLog "Installing extension: $extension"
                            & az extension add --name $extension 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
                        }
                    }
                }

                Write-ScriptLog "Azure CLI installation completed successfully"
                exit 0
            }
        } catch {
            Write-ScriptLog "Package manager installation failed: $_" -Level 'Warning'
            Write-ScriptLog "Falling back to manual installation" -Level 'Information'
        }
    }

    # Fallback to original installation logic
    Write-ScriptLog "Using legacy installation method"

    # Platform-specific installation
    if ($IsWindows) {
        # Check if Azure CLI is already installed
        $azCmd = Get-Command az -ErrorAction SilentlyContinue
        if (-not $azCmd) {
            $azCmd = Get-Command az.cmd -ErrorAction SilentlyContinue
        }

        if ($azCmd) {
            Write-ScriptLog "Azure CLI is already installed at: $($azCmd.Source)"

            # Get version
            try {
                $version = & az version --output json | ConvertFrom-Json
                Write-ScriptLog "Current version: $($version.'azure-cli')"

                # Check for updates if configured
                if ($azureCliConfig.CheckForUpdates -eq $true) {
                    Write-ScriptLog "Checking for updates..."
                    if ($PSCmdlet.ShouldProcess('Azure CLI', 'Check for updates')) {
                        & az upgrade --yes 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
                    }
                }
            } catch {
                Write-ScriptLog "Could not determine version" -Level 'Debug'
            }

            exit 0
        }

        Write-ScriptLog "Installing Azure CLI for Windows..."

        # Download URL
        $downloadUrl = 'https://aka.ms/installazurecliwindows'
        $tempInstaller = Join-Path $env:TEMP "AzureCLI_$(Get-Date -Format 'yyyyMMddHHmmss').msi"

        try {
            if ($PSCmdlet.ShouldProcess($downloadUrl, 'Download Azure CLI installer')) {
                Write-ScriptLog "Downloading from: $downloadUrl"

                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $downloadUrl -OutFile $tempInstaller -UseBasicParsing
                $ProgressPreference = 'Continue'

                Write-ScriptLog "Downloaded to: $tempInstaller"
            }

            # Run MSI installer
            if ($PSCmdlet.ShouldProcess('Azure CLI', 'Install')) {
                Write-ScriptLog "Running installer..."

                $msiArgs = @(
                    '/i', "`"$tempInstaller`"",
                    '/quiet',
                    '/norestart'
                )

                # Add logging if debug mode
                if ($azureCliConfig.EnableInstallerLogging -eq $true) {
                    $logFile = Join-Path $env:TEMP "AzureCLI_Install_$(Get-Date -Format 'yyyyMMddHHmmss').log"
                    $msiArgs += '/l*v', "`"$logFile`""
                    Write-ScriptLog "Installer log will be written to: $logFile" -Level 'Debug'
                }

                $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru

                if ($process.ExitCode -ne 0) {
                    throw "MSI installer exited with code: $($process.ExitCode)"
                }

                Write-ScriptLog "Installation completed"
            }

            # Clean up
            Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue

        } catch {
            # Clean up on failure
            if (Test-Path $tempInstaller) {
                Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
            }
            throw
        }

    } elseif ($IsLinux) {
        # Linux installation
        Write-ScriptLog "Installing Azure CLI for Linux..."

        # Check if already installed
        if (Get-Command az -ErrorAction SilentlyContinue) {
            Write-ScriptLog "Azure CLI is already installed"

            try {
                $version = & az version --output json | ConvertFrom-Json
                Write-ScriptLog "Current version: $($version.'azure-cli')"
            } catch {
                Write-ScriptLog "Could not determine version" -Level 'Debug'
            }

            exit 0
        }

        # Install using distribution-specific method
        if (Get-Command apt-get -ErrorAction SilentlyContinue) {
            # Debian/Ubuntu
            if ($PSCmdlet.ShouldProcess('Azure CLI', 'Install via apt-get')) {
                Write-ScriptLog "Installing via apt-get..."

                # Install prerequisites
                & sudo apt-get update
                & sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg

                # Add Microsoft GPG key
                & curl -sL https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

                # Add Azure CLI repository
                $AZ_REPO = & lsb_release -cs
                & bash -c "echo 'deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main' | sudo tee /etc/apt/sources.list.d/azure-cli.list"

                # Install Azure CLI
                & sudo apt-get update
                & sudo apt-get install -y azure-cli
            }
        } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
            # RHEL/CentOS
            if ($PSCmdlet.ShouldProcess('Azure CLI', 'Install via yum')) {
                Write-ScriptLog "Installing via yum..."

                # Import Microsoft repository key
                & sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

                # Add repository
                & bash -c 'echo -e "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo'

                # Install
                & sudo yum install -y azure-cli
            }
        } else {
            Write-ScriptLog "Unsupported Linux distribution for automatic installation" -Level 'Error'
            exit 1
        }

    } elseif ($IsMacOS) {
        # macOS installation
        Write-ScriptLog "Installing Azure CLI for macOS..."

        # Check if already installed
        if (Get-Command az -ErrorAction SilentlyContinue) {
            Write-ScriptLog "Azure CLI is already installed"
            exit 0
        }

        # Install using Homebrew
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess('azure-cli', 'Install via Homebrew')) {
                & brew update
                & brew install azure-cli
            }
        } else {
            Write-ScriptLog "Homebrew not found. Please install Homebrew first" -Level 'Error'
            exit 1
        }
    }

    # Verify installation
    $azCmd = Get-Command az -ErrorAction SilentlyContinue
    if (-not $azCmd) {
        Write-ScriptLog "Azure CLI command not found after installation" -Level 'Error'
        exit 1
    }

    Write-ScriptLog "Azure CLI installed successfully"

    # Test Azure CLI
    try {
        $version = & az version --output json | ConvertFrom-Json
        Write-ScriptLog "Installed version: $($version.'azure-cli')"
    } catch {
        Write-ScriptLog "Azure CLI installed but may not be functioning correctly" -Level 'Warning'
    }

    # Configure if settings provided
    if ($azureCliConfig.DefaultSettings) {
        Write-ScriptLog "Configuring Azure CLI defaults..."

        foreach ($setting in $azureCliConfig.DefaultSettings.GetEnumerator()) {
            if ($PSCmdlet.ShouldProcess("az config $($setting.Key)", 'Configure')) {
                & az config set $setting.Key=$setting.Value 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
            }
        }
    }

    # Install extensions if specified
    if ($azureCliConfig.Extensions) {
        Write-ScriptLog "Installing Azure CLI extensions..."

        foreach ($extension in $azureCliConfig.Extensions) {
            if ($PSCmdlet.ShouldProcess($extension, 'Install extension')) {
                Write-ScriptLog "Installing extension: $extension"
                & az extension add --name $extension 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
            }
        }
    }

    Write-ScriptLog "Azure CLI installation completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Critical error during Azure CLI installation: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}