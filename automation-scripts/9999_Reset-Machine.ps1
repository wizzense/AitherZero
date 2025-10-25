#Requires -Version 7.0
# Stage: Maintenance
# Dependencies: None
# Description: Reset machine to clean state (sysprep on Windows, reboot on Linux/macOS)

[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
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

Write-ScriptLog "Starting machine reset process"
Write-ScriptLog "WARNING: This will reset the machine to a clean state!" -Level 'Warning'

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if reset is enabled
    $shouldReset = $false
    $resetConfig = @{
        AllowReset = $false
        PrepareForRemoteAccess = $true
        WindowsSysprepMode = 'oobe'
        CreateRestorePoint = $true
        BackupUserData = $false
    }

    if ($config.Maintenance -and $config.Maintenance.MachineReset) {
        $machineResetConfig = $config.Maintenance.MachineReset
        $shouldReset = $machineResetConfig.Enable -eq $true
        
        # Override defaults with config
        if ($null -ne $machineResetConfig.AllowReset) { $resetConfig.AllowReset = $machineResetConfig.AllowReset }
        if ($null -ne $machineResetConfig.PrepareForRemoteAccess) { $resetConfig.PrepareForRemoteAccess = $machineResetConfig.PrepareForRemoteAccess }
        if ($machineResetConfig.WindowsSysprepMode) { $resetConfig.WindowsSysprepMode = $machineResetConfig.WindowsSysprepMode }
        if ($null -ne $machineResetConfig.CreateRestorePoint) { $resetConfig.CreateRestorePoint = $machineResetConfig.CreateRestorePoint }
        if ($null -ne $machineResetConfig.BackupUserData) { $resetConfig.BackupUserData = $machineResetConfig.BackupUserData }
    }

    if (-not $shouldReset -or -not $resetConfig.AllowReset) {
        Write-ScriptLog "Machine reset is not enabled in configuration"
        Write-ScriptLog "To enable, set Maintenance.MachineReset.Enable and AllowReset to true"
        exit 0
    }

    # Confirm with user
    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Reset machine to clean state')) {
        Write-ScriptLog "Machine reset cancelled by user"
        exit 0
    }

    # Platform-specific reset
    if ($IsWindows) {
        Write-ScriptLog "Detected Windows platform"
        
        # Create restore point if configured
        if ($resetConfig.CreateRestorePoint) {
            Write-ScriptLog "Creating system restore point..."
            try {
                if ($PSCmdlet.ShouldProcess('System Protection', 'Create restore point')) {
                    Checkpoint-Computer -Description "Before AitherZero Machine Reset" -RestorePointType MODIFY_SETTINGS
                    Write-ScriptLog "Restore point created successfully"
                }
            } catch {
                Write-ScriptLog "Failed to create restore point: $_" -Level 'Warning'
            }
        }
        
        # Prepare for remote access if configured
        if ($resetConfig.PrepareForRemoteAccess) {
            Write-ScriptLog "Preparing for remote access..."

            # Enable Remote Desktop
            try {
                Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
                Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
                Write-ScriptLog "Remote Desktop enabled"
            } catch {
                Write-ScriptLog "Failed to enable Remote Desktop: $_" -Level 'Warning'
            }

            # Configure firewall for RDP
            if ($PSCmdlet.ShouldProcess('Windows Firewall', 'Allow RDP (port 3389)')) {
                New-NetFirewallRule -DisplayName "AitherZero-RDP" -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow -ErrorAction SilentlyContinue
            }
        }
        
        # Run sysprep
        $sysprepPath = Join-Path $env:SystemRoot 'System32\Sysprep\Sysprep.exe'
        
        if (Test-Path $sysprepPath) {
            Write-ScriptLog "Found sysprep at: $sysprepPath"

            # Build sysprep arguments
            $sysprepArgs = @('/generalize', '/quiet')

            # Add mode-specific arguments
            switch ($resetConfig.WindowsSysprepMode) {
                'oobe' {
                    $sysprepArgs += '/oobe'
                    $sysprepArgs += '/shutdown'
                    Write-ScriptLog "Sysprep will generalize and shutdown for OOBE"
                }
                'audit' {
                    $sysprepArgs += '/audit'
                    $sysprepArgs += '/reboot'
                    Write-ScriptLog "Sysprep will generalize and reboot to audit mode"
                }
                default {
                    $sysprepArgs += '/oobe'
                    $sysprepArgs += '/shutdown'
                }
            }
            
            Write-ScriptLog "WARNING: System will be generalized and shut down!" -Level 'Warning'
            Write-ScriptLog "Executing sysprep with arguments: $($sysprepArgs -join ' ')"

            if ($PSCmdlet.ShouldProcess($sysprepPath, "Execute sysprep $($sysprepArgs -join ' ')")) {
                Start-Process -FilePath $sysprepPath -ArgumentList $sysprepArgs -Wait -NoNewWindow
            }
        } else {
            Write-ScriptLog "Sysprep not found at expected location" -Level 'Error'
            throw "Sysprep not found"
        }
        
    } elseif ($IsLinux -or $IsMacOS) {
        $platform = if ($IsLinux) { "Linux" } else { "macOS" }
        Write-ScriptLog "Detected $platform platform"
        
        # For Unix-like systems, perform a clean reboot
        Write-ScriptLog "Preparing for system reboot..."
        
        # Clear temporary files
        if ($PSCmdlet.ShouldProcess('/tmp', 'Clear temporary files')) {
            try {
                Get-ChildItem -Path '/tmp' -File | Remove-Item -Force -ErrorAction SilentlyContinue
                Write-ScriptLog "Cleared temporary files"
            } catch {
                Write-ScriptLog "Failed to clear some temporary files: $_" -Level 'Warning'
            }
        }
        
        # Clear package manager cache
        if ($IsLinux) {
            if (Get-Command apt-get -ErrorAction SilentlyContinue) {
                if ($PSCmdlet.ShouldProcess('apt', 'Clean package cache')) {
                    & sudo apt-get clean
                    Write-ScriptLog "Cleared apt cache"
                }
            } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
                if ($PSCmdlet.ShouldProcess('yum', 'Clean package cache')) {
                    & sudo yum clean all
                    Write-ScriptLog "Cleared yum cache"
                }
            }
        } elseif ($IsMacOS) {
            if (Get-Command brew -ErrorAction SilentlyContinue) {
                if ($PSCmdlet.ShouldProcess('brew', 'Clean package cache')) {
                    & brew cleanup
                    Write-ScriptLog "Cleared Homebrew cache"
                }
            }
        }
        
        # Initiate reboot
        Write-ScriptLog "WARNING: System will reboot in 1 minute!" -Level 'Warning'
        Write-ScriptLog "Use 'shutdown -c' to cancel if needed"
        
        if ($PSCmdlet.ShouldProcess($env:HOSTNAME, 'Reboot system')) {
            if ($IsLinux) {
                & sudo shutdown -r +1 "AitherZero machine reset - system will reboot in 1 minute"
            } elseif ($IsMacOS) {
                & sudo shutdown -r +1
            }
        }
        
    } else {
        Write-ScriptLog "Unknown platform - cannot perform reset" -Level 'Error'
        throw "Unsupported platform for machine reset"
    }
    
    Write-ScriptLog "Machine reset initiated successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Critical error during machine reset: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}
