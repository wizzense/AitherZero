#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: None
# Description: Configure firewall rules for PXE boot support

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

Write-ScriptLog "Starting PXE boot configuration"

try {
    # Skip on non-Windows platforms
    if (-not $IsWindows) {
        Write-ScriptLog "PXE configuration is Windows-specific. Skipping on this platform."
        exit 0
    }

    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if PXE configuration is enabled
    $shouldConfigure = $false
    if ($config.NetworkServices -and $config.NetworkServices.PXE) {
        $pxeConfig = $config.NetworkServices.PXE
        $shouldConfigure = $pxeConfig.Enable -eq $true
    }

    if (-not $shouldConfigure) {
        Write-ScriptLog "PXE configuration is not enabled in configuration"
        exit 0
    }

    # Check if running as administrator
    $currentPrincipal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-ScriptLog "Administrator privileges required to configure firewall rules" -Level 'Error'
        exit 1
    }
    
    Write-ScriptLog "Configuring PXE boot firewall rules..."

    # Define PXE-related firewall rules
    $firewallRules = @(
        @{
            DisplayName = 'AitherZero-PXE-DHCP'
            Direction = 'Inbound'
            Protocol = 'UDP'
            LocalPort = 67
            Description = 'DHCP server for PXE boot'
        },
        @{
            DisplayName = 'AitherZero-PXE-TFTP'
            Direction = 'Inbound'
            Protocol = 'UDP'
            LocalPort = 69
            Description = 'TFTP server for PXE boot'
        },
        @{
            DisplayName = 'AitherZero-PXE-WDS-1'
            Direction = 'Inbound'
            Protocol = 'TCP'
            LocalPort = 17519
            Description = 'Windows Deployment Services'
        },
        @{
            DisplayName = 'AitherZero-PXE-WDS-2'
            Direction = 'Inbound'
            Protocol = 'TCP'
            LocalPort = 17530
            Description = 'Windows Deployment Services'
        }
    )

    # Add custom ports from configuration if specified
    if ($pxeConfig.AdditionalPorts) {
        foreach ($port in $pxeConfig.AdditionalPorts) {
            $firewallRules += @{
                DisplayName = "AitherZero-PXE-Custom-$($port.Port)"
                Direction = 'Inbound'
                Protocol = $port.Protocol
                LocalPort = $port.Port
                Description = $port.Description
            }
        }
    }
    
    $failedRules = @()
    
    foreach ($rule in $firewallRules) {
        try {
            # Check if rule already exists
            $existingRule = Get-NetFirewallRule -DisplayName $rule.DisplayName -ErrorAction SilentlyContinue

            if ($existingRule) {
                Write-ScriptLog "Firewall rule '$($rule.DisplayName)' already exists" -Level 'Debug'
                
                # Update rule if configuration specifies it
                if ($pxeConfig.UpdateExistingRules -eq $true) {
                    if ($PSCmdlet.ShouldProcess($rule.DisplayName, 'Update firewall rule')) {
                        Set-NetFirewallRule -DisplayName $rule.DisplayName -Enabled True
                        Write-ScriptLog "Updated existing rule: $($rule.DisplayName)"
                    }
                }
            } else {
                # Create new rule
                if ($PSCmdlet.ShouldProcess($rule.DisplayName, 'Create firewall rule')) {
                    $ruleParams = @{
                        DisplayName = $rule.DisplayName
                        Enabled = $true
                        Direction = $rule.Direction
                        Protocol = $rule.Protocol
                        LocalPort = $rule.LocalPort
                        Action = 'Allow'
                        Description = $rule.Description
                    }
                    
                    # Add remote address restrictions if configured
                    if ($pxeConfig.AllowedRemoteAddresses) {
                        $ruleParams['RemoteAddress'] = $pxeConfig.AllowedRemoteAddresses
                    } else {
                        $ruleParams['RemoteAddress'] = 'Any'
                    }
                    
                    New-NetFirewallRule @ruleParams
                    Write-ScriptLog "Created firewall rule: $($rule.DisplayName) (Port: $($rule.LocalPort), Protocol: $($rule.Protocol))"
                }
            }
        } catch {
            Write-ScriptLog "Failed to configure rule '$($rule.DisplayName)': $_" -Level 'Error'
            $failedRules += $rule.DisplayName
        }
    }

    # Configure additional PXE settings if specified
    if ($pxeConfig.ConfigureWDS -eq $true) {
        Write-ScriptLog "Additional WDS configuration would be performed here" -Level 'Debug'
        # This would integrate with Windows Deployment Services if needed
    }

    # Summary
    Write-ScriptLog "PXE configuration summary:"
    Write-ScriptLog "  - Total rules configured: $($firewallRules.Count)"
    Write-ScriptLog "  - Failed rules: $($failedRules.Count)"

    if ($failedRules.Count -gt 0) {
        Write-ScriptLog "Failed to configure the following rules: $($failedRules -join ', ')" -Level 'Error'
        exit 1
    }
    
    Write-ScriptLog "PXE boot configuration completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Critical error during PXE configuration: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}
