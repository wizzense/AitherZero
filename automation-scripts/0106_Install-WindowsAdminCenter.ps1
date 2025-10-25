#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: None
# Description: Install Windows Admin Center for server management
# Tags: management, infrastructure, windows, wac
# Condition: IsWindows -eq $true

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

Write-ScriptLog "Starting Windows Admin Center installation check"

try {
    # Skip on non-Windows platforms
    if (-not $IsWindows) {
        Write-ScriptLog "Windows Admin Center is Windows-specific. Skipping on this platform."
        exit 0
    }

    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if WAC installation is enabled
    $shouldInstall = $false
    $wacConfig = @{
        Install = $false
        InstallPort = 443
        GenerateSslCertificate = $true
        UseCredSSP = $false
    }

    if ($config.InstallationOptions -and $config.InstallationOptions.WAC) {
        $wacConfig = $config.InstallationOptions.WAC
        $shouldInstall = $wacConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Windows Admin Center installation is not enabled in configuration"
        exit 0
    }

    # Check Windows version - WAC requires Windows 10/Server 2016 or later
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber

    if ($build -lt 14393) {
        Write-ScriptLog "Windows Admin Center requires Windows 10/Server 2016 or later. Current build: $build" -Level 'Error'
        exit 1
    }

    # Check if running as administrator
    $currentPrincipal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-ScriptLog "Administrator privileges required to install Windows Admin Center" -Level 'Error'
        exit 1
    }

    # Check if WAC is already installed
    $wacInstalled = $false

    # Check registry
    $wacRegistry = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ServerManagementGateway" -ErrorAction SilentlyContinue
    if ($wacRegistry) {
        $wacInstalled = $true
        Write-ScriptLog "Windows Admin Center found in registry"
    }

    # Check service
    $wacService = Get-Service -Name ServerManagementGateway -ErrorAction SilentlyContinue
    if ($wacService) {
        $wacInstalled = $true
        Write-ScriptLog "Windows Admin Center service found: $($wacService.Status)"

        if ($wacService.Status -eq 'Running') {
            Write-ScriptLog "Windows Admin Center is already installed and running"

            # Get current port
            try {
                $currentPort = netsh http show sslcert | Select-String -Pattern "0.0.0.0:(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value } | Select-Object -First 1
                if ($currentPort) {
                    Write-ScriptLog "Windows Admin Center is running on port: $currentPort"
                }
            } catch {
                Write-Warning "Failed to get WAC service status: $($_.Exception.Message)"
            }

            exit 0
        }
    }

    # Download Windows Admin Center
    Write-ScriptLog "Downloading Windows Admin Center..."

    $downloadUrl = "https://aka.ms/WACDownload"
    $tempDir = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
        [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
    } else {
        $env:TEMP
    }

    $installerPath = Join-Path $tempDir "WindowsAdminCenter.msi"

    try {
        $ProgressPreference = 'SilentlyContinue'

        # Get the actual download URL (aka.ms redirects)
        $response = Invoke-WebRequest -Uri $downloadUrl -MaximumRedirection 0 -ErrorAction SilentlyContinue
        $actualUrl = $response.Headers.Location
        if (-not $actualUrl) {
            $actualUrl = $downloadUrl
        }

        Write-ScriptLog "Downloading from: $actualUrl" -Level 'Debug'
        Invoke-WebRequest -Uri $actualUrl -OutFile $installerPath -UseBasicParsing
        $ProgressPreference = 'Continue'

        if (-not (Test-Path $installerPath)) {
            throw "Download failed - installer not found"
        }

        $fileSize = (Get-Item $installerPath).Length / 1MB
        Write-ScriptLog "Downloaded Windows Admin Center installer ($([Math]::Round($fileSize, 2)) MB)"

    } catch {
        Write-ScriptLog "Failed to download Windows Admin Center: $_" -Level 'Error'
        throw
    }

    # Install Windows Admin Center
    if ($PSCmdlet.ShouldProcess("Windows Admin Center", "Install")) {
        Write-ScriptLog "Installing Windows Admin Center..."

        # Build MSI arguments
        $msiArgs = @(
            '/i', "`"$installerPath`"",
            '/quiet',
            '/norestart',
            '/L*v', "`"$tempDir\WAC_Install.log`"",
            "SME_PORT=$($wacConfig.InstallPort)",
            "SSL_CERTIFICATE_OPTION=$(if ($wacConfig.GenerateSslCertificate) { 'generate' } else { 'installed' })"
        )

        # Add product key if provided
        if ($wacConfig.ProductKey) {
            $msiArgs += "PRODUCTKEY=$($wacConfig.ProductKey)"
        }

        # Add CredSSP option
        if ($wacConfig.UseCredSSP) {
            $msiArgs += "USE_CREDSSP=1"
        }

        # Add trusted hosts if specified
        if ($wacConfig.TrustedHosts) {
            $msiArgs += "TRUSTED_HOSTS=$($wacConfig.TrustedHosts)"
        }

        Write-ScriptLog "Running installer with arguments: msiexec.exe $($msiArgs -join ' ')" -Level 'Debug'

        $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-ScriptLog "Windows Admin Center installed successfully"
        } elseif ($process.ExitCode -eq 3010) {
            Write-ScriptLog "Windows Admin Center installed successfully - Restart required" -Level 'Warning'
            $restartRequired = $true
        } else {
            # Check log file for details
            $logPath = Join-Path $tempDir "WAC_Install.log"
            if (Test-Path $logPath) {
                $logTail = Get-Content $logPath -Tail 50
                Write-ScriptLog "Installation log tail:" -Level 'Debug'
                $logTail | ForEach-Object { Write-ScriptLog $_ -Level 'Debug' }
            }

            Write-ScriptLog "Windows Admin Center installation failed with exit code: $($process.ExitCode)" -Level 'Error'
            throw "Installation failed"
        }
    }

    # Clean up installer
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    }

    # Configure firewall if needed
    if ($wacConfig.ConfigureFirewall -ne $false) {
        Write-ScriptLog "Configuring firewall for Windows Admin Center..."

        try {
            New-NetFirewallRule -DisplayName "Windows Admin Center" `
                -Direction Inbound `
                -LocalPort $wacConfig.InstallPort `
                -Protocol TCP `
                -Action Allow `
                -ErrorAction Stop

            Write-ScriptLog "Firewall rule created for port $($wacConfig.InstallPort)"
        } catch {
            if ($_.Exception.Message -notlike '*already exists*') {
                Write-ScriptLog "Failed to create firewall rule: $_" -Level 'Warning'
            }
        }
    }

    # Start the service
    try {
        $wacService = Get-Service -Name ServerManagementGateway -ErrorAction Stop
        if ($wacService.Status -ne 'Running') {
            Start-Service -Name ServerManagementGateway
            Write-ScriptLog "Windows Admin Center service started"
        }

        # Wait for service to be ready
        Start-Sleep -Seconds 5

        # Get access URL
        $hostname = $env:COMPUTERNAME
        $url = "https://${hostname}:$($wacConfig.InstallPort)"

        Write-ScriptLog "Windows Admin Center is available at: $url"

        # Add desktop shortcut if requested
        if ($wacConfig.CreateDesktopShortcut) {
            $desktopPath = [Environment]::GetFolderPath('Desktop')
            $shortcutPath = Join-Path $desktopPath "Windows Admin Center.url"

            @"
[InternetShortcut]
URL=$url
IconIndex=0
IconFile=%ProgramFiles%\Windows Admin Center\PowerShell\Modules\Microsoft.SME.PowerShell\Microsoft.SME.PowerShell.dll
"@ | Set-Content -Path $shortcutPath

            Write-ScriptLog "Created desktop shortcut"
        }

    } catch {
        Write-ScriptLog "Failed to start Windows Admin Center service: $_" -Level 'Warning'
    }

    if ($restartRequired) {
        Write-ScriptLog "System restart required to complete installation" -Level 'Warning'
        exit 3010
    }

    Write-ScriptLog "Windows Admin Center installation completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Windows Admin Center installation failed: $_" -Level 'Error'
    exit 1
}