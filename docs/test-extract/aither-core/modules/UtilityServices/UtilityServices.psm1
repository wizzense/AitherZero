#Requires -Version 7.0

<#
.SYNOPSIS
    Unified Utility Services Platform for AitherZero

.DESCRIPTION
    This module consolidates and unifies four critical utility modules:
    - SemanticVersioning: Intelligent version management with conventional commits
    - ProgressTracking: Visual progress indicators and operation monitoring  
    - TestingFramework: Comprehensive testing orchestration with module integration
    - ScriptManager: Script management, execution, and repository functions

    The UtilityServices module provides:
    - Unified APIs that integrate versioning, progress tracking, testing, and script management
    - Shared utility patterns for consistent behavior across all operations
    - Integrated progress tracking for testing and script execution
    - Version-aware script management and testing capabilities
    - Combined reporting across all utility services
    - Cross-cutting concerns like logging, error handling, and event management

.NOTES
    This module serves as the central hub for all utility operations in AitherZero,
    providing both individual service access and integrated workflows that leverage
    multiple utility services together for enhanced functionality.
#>

# Module-level variables for service management
$script:UtilityServices = @{
    SemanticVersioning = @{ Loaded = $false; Functions = @() }
    ProgressTracking = @{ Loaded = $false; Functions = @() }
    TestingFramework = @{ Loaded = $false; Functions = @() }
    ScriptManager = @{ Loaded = $false; Functions = @() }
    IntegratedServices = @{ Active = @(); History = @() }
}

$script:ServiceEventSystem = @{
    Subscribers = @{}
    EventHistory = @()
    Enabled = $true
}

$script:SharedConfiguration = @{
    LogLevel = 'INFO'
    EnableProgressTracking = $true
    EnableVersioning = $true
    EnableMetrics = $true
    DefaultTimeout = 300
    MaxConcurrency = 4
}

# Project root detection
$script:ProjectRoot = if ($env:PROJECT_ROOT) {
    $env:PROJECT_ROOT
} else {
    $currentPath = $PSScriptRoot
    while ($currentPath -and -not (Test-Path (Join-Path $currentPath ".git"))) {
        $currentPath = Split-Path $currentPath -Parent
    }
    $currentPath
}

# ============================================================================
# CORE INFRASTRUCTURE AND SHARED UTILITIES
# ============================================================================

# Load shared infrastructure functions first
$sharedPath = Join-Path $PSScriptRoot "Private/Shared"
if (Test-Path $sharedPath) {
    Get-ChildItem -Path $sharedPath -Filter "*.ps1" | ForEach-Object {
        try {
            . $_.FullName
        } catch {
            Write-Error "Failed to load shared function $($_.Name): $($_.Exception.Message)"
        }
    }
}

# Load core infrastructure functions
$corePath = Join-Path $PSScriptRoot "Private/Core"
if (Test-Path $corePath) {
    Get-ChildItem -Path $corePath -Filter "*.ps1" | ForEach-Object {
        try {
            . $_.FullName
        } catch {
            Write-Error "Failed to load core function $($_.Name): $($_.Name): $($_.Exception.Message)"
        }
    }
}

# Load all public functions organized by category
$publicPath = Join-Path $PSScriptRoot "Public"
if (Test-Path $publicPath) {
    # Load functions from all categories
    $categories = @('Versioning', 'Progress', 'Testing', 'Scripts')
    foreach ($category in $categories) {
        $categoryPath = Join-Path $publicPath $category
        if (Test-Path $categoryPath) {
            Get-ChildItem -Path $categoryPath -Filter "*.ps1" | ForEach-Object {
                try {
                    . $_.FullName
                } catch {
                    Write-Error "Failed to load $category function $($_.Name): $($_.Exception.Message)"
                }
            }
        }
    }
    
    # Load any functions directly in Public root
    Get-ChildItem -Path $publicPath -Filter "*.ps1" | ForEach-Object {
        try {
            . $_.FullName
        } catch {
            Write-Error "Failed to load public function $($_.Name): $($_.Exception.Message)"
        }
    }
}

# ============================================================================
# UNIFIED LOGGING INFRASTRUCTURE
# ============================================================================

function Write-UtilityLog {
    <#
    .SYNOPSIS
        Centralized logging function for all utility services
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('DEBUG', 'INFO', 'SUCCESS', 'WARN', 'ERROR')]
        [string]$Level = 'INFO',
        
        [string]$Service = 'UtilityServices',
        
        [switch]$NoTimestamp
    )
    
    # Check if centralized logging is available
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message "[$Service] $Message"
        return
    }
    
    # Fallback to local logging
    $timestamp = if (-not $NoTimestamp) { "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] " } else { "" }
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        'DEBUG' { 'Gray' }
        default { 'White' }
    }
    
    Write-Host "$timestamp[$Level] [$Service] $Message" -ForegroundColor $color
}

# ============================================================================
# SERVICE INITIALIZATION AND MANAGEMENT
# ============================================================================

function Initialize-UtilityServices {
    <#
    .SYNOPSIS
        Initializes the unified utility services platform
    
    .DESCRIPTION
        Sets up the integrated environment for all utility services,
        configures shared resources, and validates service availability
    
    .PARAMETER Services
        Specific services to initialize (default: all)
    
    .PARAMETER Configuration
        Custom configuration overrides
    
    .EXAMPLE
        Initialize-UtilityServices
        
        Initialize all utility services with default configuration
    
    .EXAMPLE
        Initialize-UtilityServices -Services @('SemanticVersioning', 'ProgressTracking')
        
        Initialize only specific services
    #>
    [CmdletBinding()]
    param(
        [string[]]$Services = @('SemanticVersioning', 'ProgressTracking', 'TestingFramework', 'ScriptManager'),
        
        [hashtable]$Configuration = @{}
    )
    
    begin {
        Write-UtilityLog "🚀 Initializing UtilityServices platform" -Level "INFO"
        
        # Merge configuration
        foreach ($key in $Configuration.Keys) {
            $script:SharedConfiguration[$key] = $Configuration[$key]
        }
    }
    
    process {
        try {
            $initResults = @()
            
            foreach ($service in $Services) {
                Write-UtilityLog "Initializing service: $service" -Level "INFO" -Service $service
                
                $serviceResult = @{
                    Service = $service
                    Success = $false
                    Functions = @()
                    Error = $null
                }
                
                try {
                    switch ($service) {
                        'SemanticVersioning' {
                            $serviceResult = Initialize-SemanticVersioningService
                        }
                        'ProgressTracking' {
                            $serviceResult = Initialize-ProgressTrackingService  
                        }
                        'TestingFramework' {
                            $serviceResult = Initialize-TestingFrameworkService
                        }
                        'ScriptManager' {
                            $serviceResult = Initialize-ScriptManagerService
                        }
                        default {
                            throw "Unknown service: $service"
                        }
                    }
                    
                    $script:UtilityServices[$service] = $serviceResult
                    Write-UtilityLog "✅ Service initialized: $service ($($serviceResult.Functions.Count) functions)" -Level "SUCCESS" -Service $service
                    
                } catch {
                    $serviceResult.Error = $_.Exception.Message
                    Write-UtilityLog "❌ Failed to initialize service $service`: $($_.Exception.Message)" -Level "ERROR" -Service $service
                }
                
                $initResults += $serviceResult
            }
            
            # Initialize integrated services
            Initialize-IntegratedServices
            
            # Publish initialization event
            Publish-UtilityEvent -EventType "ServicesInitialized" -Data @{
                Services = $Services
                Results = $initResults
                Configuration = $script:SharedConfiguration
            }
            
            $successCount = ($initResults | Where-Object Success).Count
            Write-UtilityLog "🎯 UtilityServices initialization completed: $successCount/$($Services.Count) services loaded" -Level "SUCCESS"
            
            return $initResults
            
        } catch {
            Write-UtilityLog "❌ UtilityServices initialization failed: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function Get-UtilityServiceStatus {
    <#
    .SYNOPSIS
        Gets the current status of all utility services
    
    .DESCRIPTION
        Provides comprehensive status information about loaded services,
        active operations, and system health
    
    .EXAMPLE
        Get-UtilityServiceStatus
        
        Get status of all utility services
    #>
    [CmdletBinding()]
    param()
    
    $status = @{
        Services = @{}
        IntegratedOperations = $script:UtilityServices.IntegratedServices.Active.Count
        Configuration = $script:SharedConfiguration
        EventSystem = @{
            Enabled = $script:ServiceEventSystem.Enabled
            Subscribers = $script:ServiceEventSystem.Subscribers.Count
            EventHistory = $script:ServiceEventSystem.EventHistory.Count
        }
        SystemHealth = 'Healthy'
        LastUpdated = Get-Date
    }
    
    # Check each service
    foreach ($serviceName in $script:UtilityServices.Keys) {
        if ($serviceName -ne 'IntegratedServices') {
            $service = $script:UtilityServices[$serviceName]
            $status.Services[$serviceName] = @{
                Loaded = $service.Loaded
                FunctionCount = $service.Functions.Count
                Status = if ($service.Loaded) { 'Active' } else { 'Inactive' }
            }
        }
    }
    
    # Determine overall health
    $loadedServices = ($status.Services.Values | Where-Object { $_.Loaded }).Count
    $totalServices = $status.Services.Count
    
    if ($loadedServices -eq 0) {
        $status.SystemHealth = 'Critical'
    } elseif ($loadedServices -lt $totalServices) {
        $status.SystemHealth = 'Degraded'
    }
    
    Write-UtilityLog "📊 UtilityServices status: $($status.SystemHealth) ($loadedServices/$totalServices services active)" -Level "INFO"
    return $status
}

# ============================================================================
# INTEGRATED UTILITY OPERATIONS
# ============================================================================

function Start-IntegratedOperation {
    <#
    .SYNOPSIS
        Starts an integrated operation leveraging multiple utility services
    
    .DESCRIPTION
        Combines multiple utility services to perform complex operations with
        integrated progress tracking, version awareness, and comprehensive logging
    
    .PARAMETER OperationType
        Type of integrated operation to perform
    
    .PARAMETER Parameters
        Parameters specific to the operation
    
    .PARAMETER EnableProgressTracking
        Whether to enable visual progress tracking
    
    .PARAMETER EnableVersioning
        Whether to include versioning operations
    
    .EXAMPLE
        Start-IntegratedOperation -OperationType "VersionedTestSuite" -Parameters @{TestSuite = "All"}
        
        Run a complete test suite with automatic version detection and progress tracking
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('VersionedTestSuite', 'ProgressAwareScriptExecution', 'TestAwareVersioning', 'FullUtilityWorkflow')]
        [string]$OperationType,
        
        [hashtable]$Parameters = @{},
        
        [switch]$EnableProgressTracking = $script:SharedConfiguration.EnableProgressTracking,
        
        [switch]$EnableVersioning = $script:SharedConfiguration.EnableVersioning
    )
    
    begin {
        $operationId = [Guid]::NewGuid().ToString()
        Write-UtilityLog "🔄 Starting integrated operation: $OperationType" -Level "INFO"
        
        # Initialize progress tracking if enabled
        $progressId = $null
        if ($EnableProgressTracking) {
            $progressId = Start-ProgressOperation -OperationName "Integrated: $OperationType" -TotalSteps 5 -ShowTime -ShowETA
        }
    }
    
    process {
        try {
            $result = @{
                OperationId = $operationId
                OperationType = $OperationType
                StartTime = Get-Date
                Parameters = $Parameters
                Results = @{}
                Success = $false
                Error = $null
            }
            
            # Track as active operation
            $script:UtilityServices.IntegratedServices.Active += $result
            
            switch ($OperationType) {
                'VersionedTestSuite' {
                    $result.Results = Invoke-VersionedTestSuite -Parameters $Parameters -ProgressId $progressId
                }
                'ProgressAwareScriptExecution' {
                    $result.Results = Invoke-ProgressAwareScriptExecution -Parameters $Parameters -ProgressId $progressId
                }
                'TestAwareVersioning' {
                    $result.Results = Invoke-TestAwareVersioning -Parameters $Parameters -ProgressId $progressId
                }
                'FullUtilityWorkflow' {
                    $result.Results = Invoke-FullUtilityWorkflow -Parameters $Parameters -ProgressId $progressId
                }
                default {
                    throw "Unknown operation type: $OperationType"
                }
            }
            
            $result.Success = $true
            $result.EndTime = Get-Date
            $result.Duration = ($result.EndTime - $result.StartTime).TotalSeconds
            
            # Complete progress tracking
            if ($progressId) {
                Complete-ProgressOperation -OperationId $progressId -ShowSummary
            }
            
            # Move to history
            $script:UtilityServices.IntegratedServices.History += $result
            $script:UtilityServices.IntegratedServices.Active = $script:UtilityServices.IntegratedServices.Active | Where-Object { $_.OperationId -ne $operationId }
            
            # Publish completion event
            Publish-UtilityEvent -EventType "IntegratedOperationCompleted" -Data $result
            
            Write-UtilityLog "✅ Integrated operation completed: $OperationType ($($result.Duration)s)" -Level "SUCCESS"
            return $result
            
        } catch {
            $result.Success = $false
            $result.Error = $_.Exception.Message
            $result.EndTime = Get-Date
            
            if ($progressId) {
                Add-ProgressError -OperationId $progressId -Error $_.Exception.Message
                Complete-ProgressOperation -OperationId $progressId
            }
            
            Write-UtilityLog "❌ Integrated operation failed: $OperationType - $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function Get-UtilityMetrics {
    <#
    .SYNOPSIS
        Gets comprehensive metrics for all utility services
    
    .DESCRIPTION
        Provides detailed metrics and performance data across all utility services,
        including operation counts, execution times, and resource usage
    
    .PARAMETER TimeRange
        Time range for metrics collection
    
    .EXAMPLE
        Get-UtilityMetrics -TimeRange "Last24Hours"
        
        Get metrics for the last 24 hours
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('LastHour', 'Last24Hours', 'LastWeek', 'All')]
        [string]$TimeRange = 'Last24Hours'
    )
    
    $cutoffTime = switch ($TimeRange) {
        'LastHour' { (Get-Date).AddHours(-1) }
        'Last24Hours' { (Get-Date).AddDays(-1) }
        'LastWeek' { (Get-Date).AddDays(-7) }
        'All' { [DateTime]::MinValue }
    }
    
    $metrics = @{
        TimeRange = $TimeRange
        CollectedAt = Get-Date
        Services = @{}
        IntegratedOperations = @{
            Total = 0
            Successful = 0
            Failed = 0
            AverageExecutionTime = 0
        }
        EventSystem = @{
            EventsPublished = 0
            ActiveSubscribers = $script:ServiceEventSystem.Subscribers.Count
        }
        SystemHealth = @{
            OverallStatus = 'Healthy'
            LoadedServices = 0
            TotalServices = 0
        }
    }
    
    # Collect service-specific metrics
    foreach ($serviceName in @('SemanticVersioning', 'ProgressTracking', 'TestingFramework', 'ScriptManager')) {
        $service = $script:UtilityServices[$serviceName]
        $metrics.Services[$serviceName] = @{
            Loaded = $service.Loaded
            FunctionCount = $service.Functions.Count
            Status = if ($service.Loaded) { 'Active' } else { 'Inactive' }
        }
        
        if ($service.Loaded) {
            $metrics.SystemHealth.LoadedServices++
        }
        $metrics.SystemHealth.TotalServices++
    }
    
    # Collect integrated operation metrics
    $recentOperations = $script:UtilityServices.IntegratedServices.History | Where-Object { 
        $_.StartTime -gt $cutoffTime 
    }
    
    if ($recentOperations) {
        $metrics.IntegratedOperations.Total = $recentOperations.Count
        $metrics.IntegratedOperations.Successful = ($recentOperations | Where-Object Success).Count
        $metrics.IntegratedOperations.Failed = $metrics.IntegratedOperations.Total - $metrics.IntegratedOperations.Successful
        $metrics.IntegratedOperations.AverageExecutionTime = ($recentOperations | Where-Object Duration | Measure-Object -Property Duration -Average).Average
    }
    
    # Collect event system metrics
    $recentEvents = $script:ServiceEventSystem.EventHistory | Where-Object { 
        $_.Timestamp -gt $cutoffTime 
    }
    $metrics.EventSystem.EventsPublished = $recentEvents.Count
    
    # Determine overall health
    if ($metrics.SystemHealth.LoadedServices -eq 0) {
        $metrics.SystemHealth.OverallStatus = 'Critical'
    } elseif ($metrics.SystemHealth.LoadedServices -lt $metrics.SystemHealth.TotalServices) {
        $metrics.SystemHealth.OverallStatus = 'Degraded'
    }
    
    Write-UtilityLog "📈 Utility metrics collected for $TimeRange" -Level "INFO"
    return $metrics
}

# ============================================================================
# EVENT SYSTEM FOR CROSS-SERVICE COMMUNICATION
# ============================================================================

function Publish-UtilityEvent {
    <#
    .SYNOPSIS
        Publishes events for cross-service communication
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventType,
        
        [hashtable]$Data = @{},
        
        [string]$Source = 'UtilityServices'
    )
    
    if (-not $script:ServiceEventSystem.Enabled) { return }
    
    $event = @{
        EventType = $EventType
        Source = $Source
        Timestamp = Get-Date
        Data = $Data
        Id = [Guid]::NewGuid().ToString()
    }
    
    # Store in history
    $script:ServiceEventSystem.EventHistory += $event
    
    # Notify subscribers
    if ($script:ServiceEventSystem.Subscribers.ContainsKey($EventType)) {
        foreach ($subscriber in $script:ServiceEventSystem.Subscribers[$EventType]) {
            try {
                & $subscriber $event
            } catch {
                Write-UtilityLog "Event subscriber error for $EventType`: $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
    
    Write-UtilityLog "📡 Published event: $EventType from $Source" -Level "DEBUG"
}

function Subscribe-UtilityEvent {
    <#
    .SYNOPSIS
        Subscribes to utility service events
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventType,
        
        [Parameter(Mandatory)]
        [scriptblock]$Handler
    )
    
    if (-not $script:ServiceEventSystem.Subscribers.ContainsKey($EventType)) {
        $script:ServiceEventSystem.Subscribers[$EventType] = @()
    }
    
    $script:ServiceEventSystem.Subscribers[$EventType] += $Handler
    Write-UtilityLog "📬 Subscribed to event: $EventType" -Level "INFO"
}

# ============================================================================
# UTILITY INTEGRATION WORKFLOWS
# ============================================================================

function New-VersionedTestSuite {
    <#
    .SYNOPSIS
        Creates a test suite with integrated version awareness and progress tracking
    
    .DESCRIPTION
        Combines testing capabilities with semantic versioning to create
        version-aware test execution with progress visualization
    
    .PARAMETER TestSuite
        Type of test suite to execute
    
    .PARAMETER VersioningConfig
        Version-specific configuration
    
    .EXAMPLE
        New-VersionedTestSuite -TestSuite "All" -VersioningConfig @{PreRelease = "alpha"}
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("All", "Unit", "Integration", "Performance", "Quick")]
        [string]$TestSuite = "All",
        
        [hashtable]$VersioningConfig = @{}
    )
    
    return Start-IntegratedOperation -OperationType "VersionedTestSuite" -Parameters @{
        TestSuite = $TestSuite
        VersioningConfig = $VersioningConfig
    }
}

function Invoke-ProgressAwareExecution {
    <#
    .SYNOPSIS
        Executes scripts with integrated progress tracking and monitoring
    
    .DESCRIPTION
        Combines script execution with real-time progress tracking,
        providing visual feedback and performance metrics
    
    .PARAMETER ScriptPath
        Path to script to execute
    
    .PARAMETER Parameters
        Parameters to pass to the script
    
    .EXAMPLE
        Invoke-ProgressAwareExecution -ScriptPath "./scripts/deploy.ps1" -Parameters @{Environment = "dev"}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        
        [hashtable]$Parameters = @{}
    )
    
    return Start-IntegratedOperation -OperationType "ProgressAwareScriptExecution" -Parameters @{
        ScriptPath = $ScriptPath
        ScriptParameters = $Parameters
    }
}

# ============================================================================
# MODULE EXPORTS AND INITIALIZATION
# ============================================================================

# Initialize utility services on module import
try {
    # Auto-initialize core services if not explicitly disabled
    if ($env:DISABLE_UTILITY_AUTO_INIT -ne 'true') {
        $null = Initialize-UtilityServices -ErrorAction SilentlyContinue
    }
} catch {
    Write-UtilityLog "Auto-initialization failed: $($_.Exception.Message)" -Level "WARN"
}

# Set up module cleanup
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    try {
        # Clean up active operations
        $script:UtilityServices.IntegratedServices.Active | ForEach-Object {
            Write-UtilityLog "Cleaning up active operation: $($_.OperationId)" -Level "INFO"
        }
        
        # Disable event system
        $script:ServiceEventSystem.Enabled = $false
        
        Write-UtilityLog "UtilityServices module cleanup completed" -Level "INFO"
    } catch {
        Write-Warning "Error during UtilityServices cleanup: $($_.Exception.Message)"
    }
}

# Export all functions as defined in the manifest
Export-ModuleMember -Function @(
    # === SEMANTIC VERSIONING SERVICES ===
    'Get-NextSemanticVersion', 'Parse-ConventionalCommits', 'Get-CommitTypeImpact',
    'New-VersionTag', 'Get-VersionHistory', 'Update-ProjectVersion', 'Get-ReleaseNotes',
    'Test-SemanticVersion', 'Compare-SemanticVersions', 'Get-VersionBump',
    
    # === PROGRESS TRACKING SERVICES ===
    'Start-ProgressOperation', 'Update-ProgressOperation', 'Complete-ProgressOperation',
    'Get-ProgressStatus', 'Stop-ProgressOperation', 'Add-ProgressWarning', 'Add-ProgressError',
    'Start-MultiProgress', 'Update-MultiProgress', 'Complete-MultiProgress',
    'Show-ProgressSummary', 'Get-ProgressHistory', 'Clear-ProgressHistory',
    'Export-ProgressReport', 'Test-ProgressOperationActive',
    
    # === TESTING FRAMEWORK SERVICES ===
    'Invoke-UnifiedTestExecution', 'Get-DiscoveredModules', 'New-TestExecutionPlan',
    'Get-TestConfiguration', 'Invoke-ParallelTestExecution', 'Invoke-SequentialTestExecution',
    'New-TestReport', 'Export-VSCodeTestResults', 'Publish-TestEvent', 'Subscribe-TestEvent',
    'Get-TestEvents', 'Register-TestProvider', 'Get-RegisteredTestProviders',
    'Invoke-SimpleTestRunner', 'Test-ModuleStructure', 'Initialize-TestEnvironment',
    'Import-ProjectModule', 'Invoke-PesterTests', 'Invoke-PytestTests', 'Invoke-SyntaxValidation',
    'Invoke-ParallelTests', 'Invoke-BulletproofTest', 'Start-TestSuite', 'Write-TestLog',
    'New-ModuleTest', 'Invoke-BulkTestGeneration', 'Get-ModuleAnalysis',
    
    # === SCRIPT MANAGEMENT SERVICES ===
    'Register-OneOffScript', 'Invoke-OneOffScript', 'Get-ScriptRepository',
    'Start-ScriptExecution', 'Get-ScriptTemplate', 'Test-OneOffScript',
    
    # === INTEGRATED UTILITY SERVICES ===
    'Start-IntegratedOperation', 'New-VersionedTestSuite', 'Invoke-ProgressAwareExecution',
    'Get-UtilityServiceStatus', 'Start-UtilityDashboard', 'Export-UtilityReport',
    'Initialize-UtilityServices', 'Test-UtilityIntegration', 'Get-UtilityMetrics',
    'Reset-UtilityServices',
    
    # === CONFIGURATION AND EVENT MANAGEMENT ===
    'Get-UtilityConfiguration', 'Set-UtilityConfiguration', 'Reset-UtilityConfiguration',
    'Get-UtilityEvents', 'Clear-UtilityEvents', 'Publish-UtilityEvent', 'Subscribe-UtilityEvent'
)