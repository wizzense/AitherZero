#Requires -Version 7.0
# Stage: Development
# Dependencies: None
# Description: Install Chocolatey package manager for Windows

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

Write-ScriptLog "Starting Chocolatey installation"

try {
    # Skip on non-Windows platforms
    if (-not $IsWindows) {
        Write-ScriptLog "Chocolatey is Windows-specific. Skipping on this platform."
        exit 0
    }

    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Chocolatey installation is enabled
    $shouldInstall = $false
    $chocoConfig = @{}

    if ($config.PackageManagers -and $config.PackageManagers.Chocolatey) {
        $chocoConfig = $config.PackageManagers.Chocolatey
        $shouldInstall = $chocoConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Chocolatey installation is not enabled in configuration"
        exit 0
    }

    # Check if running as administrator
    $currentPrincipal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-ScriptLog "Administrator privileges required to install Chocolatey" -Level 'Error'
        exit 1
    }

    # Check if Chocolatey is already installed
    $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoCmd) {
        $chocoCmd = Get-Command choco.exe -ErrorAction SilentlyContinue
    }

    if ($chocoCmd) {
        Write-ScriptLog "Chocolatey is already installed at: $($chocoCmd.Source)"

        # Get version
        try {
            $version = & choco --version 2>&1
            Write-ScriptLog "Current version: $version"

            # Check for updates if configured
            if ($chocoConfig.CheckForUpdates -eq $true) {
                Write-ScriptLog "Checking for Chocolatey updates..."
                if ($PSCmdlet.ShouldProcess('Chocolatey', 'Check for updates')) {
                    & choco upgrade chocolatey -y 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
                }
            }
        } catch {
            Write-ScriptLog "Could not determine version" -Level 'Debug'
        }

        exit 0
    }

    Write-ScriptLog "Installing Chocolatey..."

    # Set installation options
    $installUrl = 'https://community.chocolatey.org/install.ps1'

    # Configure installation directory if specified
    if ($chocoConfig.InstallPath) {
        $env:ChocolateyInstall = [System.Environment]::ExpandEnvironmentVariables($chocoConfig.InstallPath)
        Write-ScriptLog "Custom installation path: $env:ChocolateyInstall"
    }

    # Set proxy if configured
    if ($chocoConfig.Proxy) {
        $env:chocolateyProxyLocation = $chocoConfig.Proxy.Url
        if ($chocoConfig.Proxy.Username) {
            $env:chocolateyProxyUser = $chocoConfig.Proxy.Username
        }
        if ($chocoConfig.Proxy.Password) {
            $env:chocolateyProxyPassword = $chocoConfig.Proxy.Password
        }
        Write-ScriptLog "Proxy configured: $($chocoConfig.Proxy.Url)"
    }

    # Download and run installer
    if ($PSCmdlet.ShouldProcess('Chocolatey', 'Download and install')) {
        try {
            Write-ScriptLog "Downloading Chocolatey installer..."

            # Set TLS version for download
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

            # Download installer script
            $installScript = (New-Object System.Net.WebClient).DownloadString($installUrl)

            # Run installer
            Write-ScriptLog "Running Chocolatey installer..."
            Invoke-Expression $installScript

        } catch {
            Write-ScriptLog "Failed to download or run installer: $_" -Level 'Error'
            throw
        }
    }

    # Refresh environment variables
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH', 'User')

    # Verify installation
    $chocoExe = Join-Path $env:ChocolateyInstall 'bin\choco.exe'
    if (-not (Test-Path $chocoExe)) {
        # Try default location
        $chocoExe = 'C:\ProgramData\chocolatey\bin\choco.exe'
    }

    if (-not (Test-Path $chocoExe)) {
        Write-ScriptLog "Chocolatey executable not found after installation" -Level 'Error'
        exit 1
    }

    Write-ScriptLog "Chocolatey installed successfully"

    # Test Chocolatey
    try {
        $version = & $chocoExe --version 2>&1
        Write-ScriptLog "Installed version: $version"
    } catch {
        Write-ScriptLog "Chocolatey installed but may not be functioning correctly" -Level 'Warning'
    }

    # Configure Chocolatey settings
    if ($chocoConfig.Settings) {
        Write-ScriptLog "Configuring Chocolatey settings..."

        foreach ($setting in $chocoConfig.Settings.GetEnumerator()) {
            if ($PSCmdlet.ShouldProcess("Chocolatey feature $($setting.Key)", "Set to $($setting.Value)")) {
                $cmd = if ($setting.Value -eq $true) { 'enable' } else { 'disable' }
                & $chocoExe feature $cmd -n=$($setting.Key) -y 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
            }
        }
    }

    # Configure sources if specified
    if ($chocoConfig.Sources) {
        Write-ScriptLog "Configuring Chocolatey sources..."

        foreach ($source in $chocoConfig.Sources) {
            if ($PSCmdlet.ShouldProcess($source.Name, 'Add Chocolatey source')) {
                $sourceArgs = @('source', 'add', '-n', $source.Name, '-s', $source.Url)

                if ($source.Priority) {
                    $sourceArgs += '--priority', $source.Priority
                }

                if ($source.Username) {
                    $sourceArgs += '-u', $source.Username
                }

                if ($source.Password) {
                    $sourceArgs += '-p', $source.Password
                }

                & $chocoExe $sourceArgs -y 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
            }
        }
    }

    # Install initial packages if specified
    if ($chocoConfig.InitialPackages) {
        Write-ScriptLog "Installing initial packages..."

        foreach ($package in $chocoConfig.InitialPackages) {
            if ($PSCmdlet.ShouldProcess($package, 'Install package')) {
                Write-ScriptLog "Installing package: $package"
                & $chocoExe install $package -y 2>&1 | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
            }
        }
    }

    Write-ScriptLog "Chocolatey installation completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Critical error during Chocolatey installation: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}