#Requires -Version 7.0

<#
.SYNOPSIS
    SystemMonitoring module for AitherZero - Comprehensive system monitoring and health management

.DESCRIPTION
    This module provides real-time system monitoring, performance tracking, alerting,
    and health management capabilities for AitherZero infrastructure.

.NOTES
    Author: AitherZero Development Team
    Version: 1.0.0
    PowerShell: 7.0+
#>

# Import shared utilities
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"

# Initialize module variables
$script:ModuleRoot = $PSScriptRoot
$script:ProjectRoot = Find-ProjectRoot
$script:MonitoringData = @{}
$script:AlertThresholds = @{
    CPU = @{ Critical = 90; High = 80; Medium = 70 }
    Memory = @{ Critical = 95; High = 85; Medium = 75 }
    Disk = @{ Critical = 98; High = 90; Medium = 80 }
    Network = @{ Critical = 95; High = 85; Medium = 75 }
}

# Write-CustomLog is guaranteed to be available from AitherCore orchestration
# No explicit Logging import needed - trust the orchestration system
}

# Import public functions
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
        Write-CustomLog -Message "Loaded function: $($function.BaseName)" -Level "DEBUG"
    } catch {
        Write-CustomLog -Message "Failed to load function $($function.BaseName): $($_.Exception.Message)" -Level "ERROR"
    }
}

# Module initialization
Write-CustomLog -Message "SystemMonitoring v2.0.0 loaded - Advanced monitoring with intelligent analytics" -Level "INFO"

# Export module members
Export-ModuleMember -Function @(
    'Get-SystemDashboard',
    'Get-SystemAlerts',
    'Get-SystemPerformance',
    'Get-ServiceStatus',
    'Search-SystemLogs',
    'Set-PerformanceBaseline',
    'Invoke-HealthCheck',
    'Start-SystemMonitoring',
    'Stop-SystemMonitoring',
    'Get-MonitoringConfiguration',
    'Set-MonitoringConfiguration',
    'Export-MonitoringData',
    'Import-MonitoringData',
    'Enable-PredictiveAlerting',
    'Get-MonitoringInsights'
)

# Initialize module-level variables for performance tracking
$script:ApplicationStartTime = Get-Date
$script:ApplicationReadyTime = $null
$script:ModulePerformanceData = @{}
$script:OperationMetrics = @{}
$script:PerformanceBaselines = @{}
$script:MonitoringJob = $null
$script:MonitoringConfig = $null
$script:MonitoringStartTime = $null

# Initialize new v2.0 variables for enhanced monitoring
$script:AlertHistory = @()
$script:MutedAlerts = @()
$script:NotificationConfig = @{}
$script:RetentionPolicy = @{}
$script:PredictiveJob = $null
$script:PredictiveConfig = @{}
$script:IntelligentThresholds = $false
$script:MonitoringInsights = @{}
