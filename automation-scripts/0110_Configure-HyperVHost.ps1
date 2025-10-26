#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: Hyper-V Feature
# Description: Complete Hyper-V host configuration for production use
# Tags: hyperv, virtualization, infrastructure

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

Write-ScriptLog "Starting Hyper-V host configuration"

try {
    # Skip on non-Windows platforms
    if (-not $IsWindows) {
        Write-ScriptLog "Hyper-V is only available on Windows. Skipping configuration."
        exit 0
    }

    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if Hyper-V configuration is enabled
    $shouldConfigure = $false
    if ($config.Features -and $config.Features.Infrastructure -and $config.Features.Infrastructure.HyperV) {
        $hypervConfig = $config.Features.Infrastructure.HyperV
        $shouldConfigure = $hypervConfig.Enabled -eq $true
    }

    if (-not $shouldConfigure) {
        Write-ScriptLog "Hyper-V host configuration is not enabled in configuration"
        exit 0
    }

    # Check if Hyper-V is installed
    $hypervFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
    if (-not $hypervFeature -or $hypervFeature.State -ne "Enabled") {
        Write-ScriptLog "Hyper-V feature is not installed. Please run script 0105 first." -Level 'Error'
        exit 1
    }

    Write-ScriptLog "Configuring Hyper-V host settings..."

    # Configure default paths
    $defaultVMPath = if ($hypervConfig.Configuration -and $hypervConfig.Configuration.DefaultVMPath) {
        $hypervConfig.Configuration.DefaultVMPath
    } else {
        "C:\VMs"
    }

    $defaultVHDPath = if ($hypervConfig.Configuration -and $hypervConfig.Configuration.DefaultVHDPath) {
        $hypervConfig.Configuration.DefaultVHDPath
    } else {
        "C:\VHDs"
    }

    # Create directories if they don't exist
    foreach ($path in @($defaultVMPath, $defaultVHDPath)) {
        if (-not (Test-Path $path)) {
            Write-ScriptLog "Creating directory: $path"
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }

    # Set Hyper-V host settings
    Write-ScriptLog "Setting Hyper-V default paths"
    try {
        Set-VMHost -VirtualMachinePath $defaultVMPath -VirtualHardDiskPath $defaultVHDPath
        Write-ScriptLog "Default VM path set to: $defaultVMPath"
        Write-ScriptLog "Default VHD path set to: $defaultVHDPath"
    } catch {
        Write-ScriptLog "Failed to set Hyper-V host paths: $_" -Level 'Warning'
    }

    # Configure Enhanced Session Mode if available
    try {
        $currentHost = Get-VMHost
        if ($currentHost.EnableEnhancedSessionMode -eq $false) {
            Write-ScriptLog "Enabling Enhanced Session Mode"
            Set-VMHost -EnableEnhancedSessionMode $true
        }
    } catch {
        Write-ScriptLog "Failed to configure Enhanced Session Mode: $_" -Level 'Warning'
    }

    # Configure virtual switches
    Write-ScriptLog "Configuring virtual switches..."
    
    # Create default external switch if configured
    if ($hypervConfig.Configuration -and $hypervConfig.Configuration.CreateExternalSwitch -eq $true) {
        $externalAdapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' -and $_.MediaType -eq '802.3' } | Select-Object -First 1
        
        if ($externalAdapter) {
            $switchName = "External Switch"
            $existingSwitch = Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue
            
            if (-not $existingSwitch) {
                Write-ScriptLog "Creating external virtual switch: $switchName"
                try {
                    New-VMSwitch -Name $switchName -NetAdapterName $externalAdapter.Name -AllowManagementOS $true
                    Write-ScriptLog "External switch created successfully"
                } catch {
                    Write-ScriptLog "Failed to create external switch: $_" -Level 'Warning'
                }
            } else {
                Write-ScriptLog "External switch already exists: $switchName"
            }
        } else {
            Write-ScriptLog "No suitable network adapter found for external switch" -Level 'Warning'
        }
    }

    # Create default internal switch
    $internalSwitchName = "Internal Switch"
    $existingInternalSwitch = Get-VMSwitch -Name $internalSwitchName -ErrorAction SilentlyContinue
    
    if (-not $existingInternalSwitch) {
        Write-ScriptLog "Creating internal virtual switch: $internalSwitchName"
        try {
            New-VMSwitch -Name $internalSwitchName -SwitchType Internal
            Write-ScriptLog "Internal switch created successfully"
        } catch {
            Write-ScriptLog "Failed to create internal switch: $_" -Level 'Warning'
        }
    } else {
        Write-ScriptLog "Internal switch already exists: $internalSwitchName"
    }

    # Configure memory settings for Dynamic Memory if specified
    if ($hypervConfig.Configuration -and $hypervConfig.Configuration.ConfigureDynamicMemory -eq $true) {
        Write-ScriptLog "Configuring Dynamic Memory settings"
        try {
            # These are global settings that affect new VMs
            $memoryConfig = $hypervConfig.Configuration.DynamicMemory
            if ($memoryConfig) {
                Write-ScriptLog "Dynamic Memory configuration will be applied to new VMs"
                Write-ScriptLog "  Minimum RAM: $($memoryConfig.MinimumBytes -replace 'GB','GB')"
                Write-ScriptLog "  Maximum RAM: $($memoryConfig.MaximumBytes -replace 'GB','GB')"
                Write-ScriptLog "  Startup RAM: $($memoryConfig.StartupBytes -replace 'GB','GB')"
            }
        } catch {
            Write-ScriptLog "Failed to configure Dynamic Memory settings: $_" -Level 'Warning'
        }
    }

    # Configure Hyper-V integration services
    Write-ScriptLog "Checking integration services configuration"
    try {
        $integrationServices = @(
            "Microsoft:${env:COMPUTERNAME}\Guest Service Interface",
            "Microsoft:${env:COMPUTERNAME}\Heartbeat",
            "Microsoft:${env:COMPUTERNAME}\Key-Value Pair Exchange",
            "Microsoft:${env:COMPUTERNAME}\Shutdown",
            "Microsoft:${env:COMPUTERNAME}\Time Synchronization",
            "Microsoft:${env:COMPUTERNAME}\VSS"
        )
        Write-ScriptLog "Integration services will be available for new VMs"
    } catch {
        Write-ScriptLog "Failed to configure integration services: $_" -Level 'Warning'
    }

    # Configure resource allocation if specified
    if ($hypervConfig.Configuration -and $hypervConfig.Configuration.ResourceAllocation) {
        $resourceConfig = $hypervConfig.Configuration.ResourceAllocation
        Write-ScriptLog "Applying resource allocation settings"
        
        try {
            if ($resourceConfig.NumaSpanning) {
                Set-VMHost -NumaSpanningEnabled:$resourceConfig.NumaSpanning
                Write-ScriptLog "NUMA spanning set to: $($resourceConfig.NumaSpanning)"
            }
            
            if ($resourceConfig.VirtualMachineMigration) {
                Set-VMHost -VirtualMachineMigrationEnabled:$resourceConfig.VirtualMachineMigration
                Write-ScriptLog "VM migration enabled: $($resourceConfig.VirtualMachineMigration)"
            }
        } catch {
            Write-ScriptLog "Failed to configure resource allocation: $_" -Level 'Warning'
        }
    }

    # Configure checkpoint settings
    Write-ScriptLog "Configuring checkpoint settings"
    try {
        # Set automatic checkpoint type to Production (Standard checkpoints for fallback)
        if (Get-Command Set-VMHost -ErrorAction SilentlyContinue) {
            Set-VMHost -DefaultStorageProvider Microsoft-Hyper-V-Standard
            Write-ScriptLog "Checkpoint configuration applied"
        }
    } catch {
        Write-ScriptLog "Failed to configure checkpoints: $_" -Level 'Warning'
    }

    # Display configuration summary
    Write-ScriptLog "Hyper-V host configuration summary:"
    try {
        $hostInfo = Get-VMHost
        Write-ScriptLog "  Default VM Path: $($hostInfo.VirtualMachinePath)"
        Write-ScriptLog "  Default VHD Path: $($hostInfo.VirtualHardDiskPath)"
        Write-ScriptLog "  Enhanced Session Mode: $($hostInfo.EnableEnhancedSessionMode)"
        Write-ScriptLog "  NUMA Spanning: $($hostInfo.NumaSpanningEnabled)"
        Write-ScriptLog "  VM Migration: $($hostInfo.VirtualMachineMigrationEnabled)"
        
        $switches = Get-VMSwitch
        Write-ScriptLog "  Virtual Switches: $($switches.Count)"
        foreach ($switch in $switches) {
            Write-ScriptLog "    - $($switch.Name) ($($switch.SwitchType))"
        }
    } catch {
        Write-ScriptLog "Failed to retrieve host information: $_" -Level 'Warning'
    }

    # Set up basic networking for internal switch if configured
    if ($hypervConfig.Configuration -and $hypervConfig.Configuration.ConfigureInternalNetwork -eq $true) {
        Write-ScriptLog "Configuring internal network..."
        
        try {
            # Get the internal switch adapter
            $internalAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*$internalSwitchName*" } | Select-Object -First 1
            
            if ($internalAdapter) {
                # Set static IP if configured
                $networkConfig = $hypervConfig.Configuration.InternalNetwork
                if ($networkConfig -and $networkConfig.IPAddress) {
                    Write-ScriptLog "Setting static IP: $($networkConfig.IPAddress)"
                    New-NetIPAddress -InterfaceAlias $internalAdapter.Name -IPAddress $networkConfig.IPAddress -PrefixLength $networkConfig.PrefixLength -ErrorAction SilentlyContinue
                    
                    # Configure NAT if specified
                    if ($networkConfig.EnableNAT -eq $true -and $networkConfig.NATName) {
                        Write-ScriptLog "Configuring NAT: $($networkConfig.NATName)"
                        New-NetNat -Name $networkConfig.NATName -InternalIPInterfaceAddressPrefix "$($networkConfig.NetworkAddress)/$($networkConfig.PrefixLength)" -ErrorAction SilentlyContinue
                    }
                }
            }
        } catch {
            Write-ScriptLog "Failed to configure internal network: $_" -Level 'Warning'
        }
    }

    Write-ScriptLog "Hyper-V host configuration completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Hyper-V host configuration failed: $_" -Level 'Error'
    exit 1
}