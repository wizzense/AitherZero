#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: None
# Description: Enable Hyper-V virtualization feature on Windows

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

Write-ScriptLog "Starting Hyper-V installation check"

try {
    # Skip on non-Windows platforms
    if (-not $IsWindows) {
        Write-ScriptLog "Hyper-V is Windows-specific. Skipping on this platform."
        exit 0
    }

    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Hyper-V installation is enabled
    $shouldInstall = $false
    if ($config.InstallationOptions -and $config.InstallationOptions.HyperV) {
        $hyperVConfig = $config.InstallationOptions.HyperV
        $shouldInstall = $hyperVConfig.Install -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Hyper-V installation is not enabled in configuration"
        exit 0
    }

    # Check Windows edition and version
    $os = Get-CimInstance Win32_OperatingSystem
    $edition = $os.Caption

    # Check if running Windows Pro, Enterprise, or Server
    if ($edition -notmatch 'Pro|Enterprise|Server|Education') {
        Write-ScriptLog "Hyper-V requires Windows Pro, Enterprise, Education, or Server edition. Current: $edition" -Level 'Warning'
        exit 0
    }

    # Check if running as administrator
    $currentPrincipal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-ScriptLog "Administrator privileges required to install Hyper-V" -Level 'Error'
        exit 1
    }

    # Check if Hyper-V is already enabled
    Write-ScriptLog "Checking Hyper-V status..."
    
    try {
        $hyperVFeatures = @(
            'Microsoft-Hyper-V',
            'Microsoft-Hyper-V-Tools-All',
            'Microsoft-Hyper-V-Management-PowerShell',
            'Microsoft-Hyper-V-Hypervisor',
            'Microsoft-Hyper-V-Services'
        )
    
        $allEnabled = $true
        foreach ($feature in $hyperVFeatures) {
            $state = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
            if ($state.State -ne 'Enabled') {
                $allEnabled = $false
                Write-ScriptLog "Feature $feature is not enabled" -Level 'Debug'
            }
        }
        
        if ($allEnabled) {
            Write-ScriptLog "Hyper-V is already fully enabled"

            # Check if Hyper-V service is running
            $vmms = Get-Service -Name vmms -ErrorAction SilentlyContinue
            if ($vmms -and $vmms.Status -eq 'Running') {
                Write-ScriptLog "Hyper-V Virtual Machine Management service is running"
            } else {
                Write-ScriptLog "Hyper-V is enabled but the management service is not running" -Level 'Warning'
            }
            
            exit 0
        }
    } catch {
        Write-ScriptLog "Could not check Hyper-V status: $_" -Level 'Debug'
    }

    # Enable Hyper-V
    Write-ScriptLog "Enabling Hyper-V features..."
    
    try {
        # Enable all Hyper-V features
        $result = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart
        
        if ($result.RestartNeeded) {
            Write-ScriptLog "Hyper-V has been enabled successfully" 
            Write-ScriptLog "IMPORTANT: A system restart is required to complete the installation" -Level 'Warning'

            # Set a flag or exit code to indicate restart is needed
            exit 3010  # Standard Windows exit code for "restart required"
        } else {
            Write-ScriptLog "Hyper-V has been enabled successfully"
        }
        
        # Enable Hyper-V PowerShell module if needed
        if (-not (Get-Module -ListAvailable -Name Hyper-V)) {
            Write-ScriptLog "Installing Hyper-V PowerShell module..."
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell -All -NoRestart
        }
        
    } catch {
        Write-ScriptLog "Failed to enable Hyper-V: $_" -Level 'Error'
        throw
    }

    # Prepare Hyper-V host if configured
    if ($config.InstallationOptions.HyperV.PrepareHost -eq $true) {
        Write-ScriptLog "Preparing Hyper-V host settings..."
        
        try {
            # Import and verify Hyper-V module availability
            Import-Module Hyper-V -ErrorAction SilentlyContinue

            # Verify module loaded successfully
            if (Get-Module -Name Hyper-V) {
                Write-ScriptLog "Hyper-V PowerShell module is loaded and available"
                
                # Test basic Hyper-V cmdlet functionality
                try {
                    $null = Get-VMHost -ErrorAction Stop
                    Write-ScriptLog "Hyper-V provider is functional and ready for OpenTofu"
                } catch {
                    Write-ScriptLog "Hyper-V module loaded but provider may not be fully functional: $_" -Level 'Warning'
                }
            } else {
                Write-ScriptLog "Hyper-V PowerShell module could not be loaded. Provider preparation incomplete." -Level 'Warning'
            }

            # Create default virtual switch if it doesn't exist
            $defaultSwitch = Get-VMSwitch -Name 'Default Switch' -ErrorAction SilentlyContinue
            if (-not $defaultSwitch) {
                Write-ScriptLog "Creating default virtual switch..." -Level 'Debug'
                # This will be handled by infrastructure scripts after restart
            }

            # Set default paths if configured
            if ($config.Infrastructure -and $config.Infrastructure.DefaultVMPath) {
                $vmPath = [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.DefaultVMPath)
                if (-not (Test-Path $vmPath)) {
                    New-Item -ItemType Directory -Path $vmPath -Force | Out-Null
                }
                Write-ScriptLog "Default VM path set to: $vmPath"
            }

            # Set default VHD path if configured
            if ($config.Infrastructure -and $config.Infrastructure.DefaultVHDPath) {
                $vhdPath = [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.DefaultVHDPath)
                if (-not (Test-Path $vhdPath)) {
                    New-Item -ItemType Directory -Path $vhdPath -Force | Out-Null
                }
                Write-ScriptLog "Default VHD path set to: $vhdPath"
            }
            
        } catch {
            Write-ScriptLog "Could not prepare Hyper-V host settings: $_" -Level 'Warning'
        }
    }
    
    Write-ScriptLog "Hyper-V installation completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Hyper-V installation failed: $_" -Level 'Error'
    exit 1
}
