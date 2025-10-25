#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: None
# Description: Install Windows Subsystem for Linux 2 with chosen distribution
# Tags: infrastructure, wsl, linux, virtualization
# Condition: IsWindows -eq $true

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

Write-ScriptLog "Starting WSL2 installation check"

try {
    # Check if running on Windows
    if (-not $IsWindows) {
        Write-ScriptLog "WSL2 is Windows-specific. Skipping on this platform."
        exit 0
    }

    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if WSL2 installation is enabled
    $shouldInstall = $false
    $wslConfig = @{
        Install = $true
        Distribution = 'Ubuntu'
        Version = '2'
        DefaultUser = $env:USERNAME
        AdditionalDistros = @()
    }

    if ($config.InstallationOptions -and $config.InstallationOptions.WSL2) {
        $wslConfig = $config.InstallationOptions.WSL2
        $shouldInstall = $wslConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "WSL2 installation is not enabled in configuration"
        exit 0
    }

    # Check Windows version
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber

    if ($build -lt 18362) {
        Write-ScriptLog "WSL2 requires Windows 10 version 1903 (build 18362) or higher. Current build: $build" -Level 'Error'
        exit 1
    }

    # Check if running as administrator
    $currentPrincipal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-ScriptLog "Administrator privileges required to install WSL2" -Level 'Error'
        exit 1
    }

    # Check current WSL status
    $wslInstalled = $false
    $wslVersion = 1
    
    try {
        $wslStatus = & wsl --status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $wslInstalled = $true

            # Check default version
            if ($wslStatus -match 'Default Version:\s*(\d+)') {
                $wslVersion = [int]$Matches[1]
            }
            
            Write-ScriptLog "WSL is already installed (default version: $wslVersion)"
        }
    } catch {
        Write-ScriptLog "WSL not found, proceeding with installation"
    }

    # Enable WSL feature if not already enabled
    if (-not $wslInstalled) {
        Write-ScriptLog "Enabling Windows Subsystem for Linux..."
        
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
        if ($wslFeature.State -ne 'Enabled') {
            if ($PSCmdlet.ShouldProcess("Windows Subsystem for Linux", "Enable Feature")) {
                Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart
                Write-ScriptLog "WSL feature enabled"
            }
        } else {
            Write-ScriptLog "WSL feature already enabled"
        }
    }

    # Enable Virtual Machine Platform for WSL2
    if ($wslConfig.Version -eq '2' -or $wslConfig.Version -eq 2) {
        Write-ScriptLog "Enabling Virtual Machine Platform for WSL2..."
        
        $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
        if ($vmFeature.State -ne 'Enabled') {
            if ($PSCmdlet.ShouldProcess("Virtual Machine Platform", "Enable Feature")) {
                Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
                Write-ScriptLog "Virtual Machine Platform enabled"
            }
        } else {
            Write-ScriptLog "Virtual Machine Platform already enabled"
        }
        
        # Download and install WSL2 kernel update if needed
        if ($build -lt 19041) {
            Write-ScriptLog "Installing WSL2 Linux kernel update..."
            
            $kernelUrl = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi'
            $tempDir = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
                [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
            } else {
                $env:TEMP
            }
            
            $kernelPath = Join-Path $tempDir 'wsl_update_x64.msi'
            
            try {
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $kernelUrl -OutFile $kernelPath -UseBasicParsing
                $ProgressPreference = 'Continue'
                
                Write-ScriptLog "Installing WSL2 kernel update..."
                $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$kernelPath`" /quiet" -Wait -PassThru
                
                if ($process.ExitCode -ne 0) {
                    Write-ScriptLog "WSL2 kernel update failed with exit code: $($process.ExitCode)" -Level 'Warning'
                }
                
                Remove-Item $kernelPath -Force -ErrorAction SilentlyContinue
            } catch {
                Write-ScriptLog "Failed to install WSL2 kernel update: $_" -Level 'Warning'
            }
        }
    }

    # Simple installation on newer Windows versions
    if ($build -ge 19041 -and -not $wslInstalled) {
        Write-ScriptLog "Using simplified WSL installation (Windows 10 version 2004+)"
        
        if ($PSCmdlet.ShouldProcess("WSL", "Install")) {
            # Install WSL with default distribution
            & wsl --install --no-distribution

            if ($LASTEXITCODE -ne 0) {
                Write-ScriptLog "WSL installation failed" -Level 'Error'
                throw "WSL installation failed"
            }
        }
    }

    # Set WSL default version
    if ($wslConfig.Version -eq '2' -or $wslConfig.Version -eq 2) {
        Write-ScriptLog "Setting WSL default version to 2..."
        & wsl --set-default-version 2
        
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "WSL default version set to 2"
        } else {
            Write-ScriptLog "Failed to set WSL default version" -Level 'Warning'
        }
    }

    # Install distributions
    $distrosToInstall = @($wslConfig.Distribution)
    if ($wslConfig.AdditionalDistros -and $wslConfig.AdditionalDistros.Count -gt 0) {
        $distrosToInstall += $wslConfig.AdditionalDistros
    }

    # Get list of installed distributions
    $installedDistros = @()
    try {
        $wslList = & wsl --list --quiet 2>&1
        if ($LASTEXITCODE -eq 0) {
            $installedDistros = $wslList | Where-Object { $_ -and $_ -notmatch '^\s*$' }
        }
    } catch {
        Write-Warning "Failed to get WSL list: $($_.Exception.Message)"
        $wslList = @()
    }
    
    foreach ($distro in $distrosToInstall) {
        if ($distro -in $installedDistros) {
            Write-ScriptLog "Distribution already installed: $distro"
            continue
        }
        
        Write-ScriptLog "Installing distribution: $distro"
        
        if ($PSCmdlet.ShouldProcess($distro, "Install WSL Distribution")) {
            # Map common distribution names to their official names
            $distroName = switch ($distro.ToLower()) {
                'ubuntu' { 'Ubuntu' }
                'ubuntu-20.04' { 'Ubuntu-20.04' }
                'ubuntu-22.04' { 'Ubuntu-22.04' }
                'debian' { 'Debian' }
                'kali' { 'kali-linux' }
                'opensuse' { 'openSUSE-Leap-15.5' }
                'sles' { 'SLES-15' }
                'oracle' { 'OracleLinux_9_3' }
                'alpine' { 'Alpine' }
                default { $distro }
            }

            # Install distribution
            & wsl --install -d $distroName

            if ($LASTEXITCODE -eq 0) {
                Write-ScriptLog "Successfully installed: $distro"
                
                # Set up default user if specified
                if ($wslConfig.DefaultUser -and $distro -eq $wslConfig.Distribution) {
                    Write-ScriptLog "Setting default user for $distro to: $($wslConfig.DefaultUser)"
                    
                    # Different distros have different config commands
                    switch ($distro.ToLower()) {
                        'ubuntu' { & ubuntu config --default-user $wslConfig.DefaultUser }
                        'debian' { & debian config --default-user $wslConfig.DefaultUser }
                        'kali' { & kali config --default-user $wslConfig.DefaultUser }
                        default {
                            Write-ScriptLog "Cannot set default user for $distro automatically" -Level 'Warning'
                        }
                    }
                }
            } else {
                Write-ScriptLog "Failed to install distribution: $distro" -Level 'Error'
            }
        }
    }

    # Configure WSL settings
    $wslConfigPath = "$env:USERPROFILE\.wslconfig"
    if ($wslConfig.Settings) {
        Write-ScriptLog "Configuring WSL2 settings..."
        
        $configContent = @"
[wsl2]
# Settings configured by AitherZero
"@
        
        if ($wslConfig.Settings.Memory) {
            $configContent += "`nmemory=$($wslConfig.Settings.Memory)"
        }
        if ($wslConfig.Settings.Processors) {
            $configContent += "`nprocessors=$($wslConfig.Settings.Processors)"
        }
        if ($wslConfig.Settings.SwapSize) {
            $configContent += "`nswap=$($wslConfig.Settings.SwapSize)"
        }
        if ($wslConfig.Settings.LocalhostForwarding -ne $null) {
            $configContent += "`nlocalhostForwarding=$($wslConfig.Settings.LocalhostForwarding.ToString().ToLower())"
        }
        
        $configContent | Set-Content -Path $wslConfigPath -Force
        Write-ScriptLog "WSL2 configuration saved to: $wslConfigPath"
    }

    # Install additional tools in WSL if specified
    if ($wslConfig.InstallTools -and $wslConfig.Distribution) {
        Write-ScriptLog "Installing tools in WSL distribution: $($wslConfig.Distribution)"
        
        $tools = @(
            'curl',
            'wget',
            'git',
            'build-essential',
            'python3',
            'python3-pip'
        )
    
        if ($wslConfig.Tools) {
            $tools = $wslConfig.Tools
        }
        
        $installCmd = "sudo apt-get update && sudo apt-get install -y $($tools -join ' ')"
        
        & wsl -d $wslConfig.Distribution -e bash -c $installCmd
        
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Tools installed successfully in WSL"
        } else {
            Write-ScriptLog "Failed to install tools in WSL" -Level 'Warning'
        }
    }

    # Check if restart is needed
    $restartNeeded = $false
    
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    if ($wslFeature.RestartNeeded) {
        $restartNeeded = $true
    }

    if ($wslConfig.Version -eq '2' -or $wslConfig.Version -eq 2) {
        $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
        if ($vmFeature.RestartNeeded) {
            $restartNeeded = $true
        }
    }

    if ($restartNeeded) {
        Write-ScriptLog "IMPORTANT: A system restart is required to complete WSL installation" -Level 'Warning'
        exit 3010
    }

    # Final verification
    try {
        $wslVersion = & wsl --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "WSL installation completed successfully"
            Write-ScriptLog $($wslVersion -join "`n") -Level 'Debug'
        }
    } catch {
        Write-ScriptLog "WSL installed but may require a restart to function properly" -Level 'Warning'
    }
    
    Write-ScriptLog "WSL2 installation completed"
    exit 0
    
} catch {
    Write-ScriptLog "WSL2 installation failed: $_" -Level 'Error'
    exit 1
}
