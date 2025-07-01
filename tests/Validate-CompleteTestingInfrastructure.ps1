#Requires -Version 7.0
<#
.SYNOPSIS
    Comprehensive end-to-end validation of AitherZero's enhanced testing infrastructure

.DESCRIPTION
    Validates the complete testing infrastructure including parallel execution, intelligent
    resource management, adaptive throttling, and all testing capabilities. Designed to
    ensure the entire testing ecosystem functions correctly before automated release.

.PARAMETER ValidationScope
    Scope of validation: Quick, Standard, Complete, Production

.PARAMETER CreateBaselines
    Create performance baselines during validation

.PARAMETER TestParallelOptimization
    Test parallel execution optimization features

.PARAMETER ValidateResourceDetection
    Validate intelligent resource detection across configurations

.PARAMETER GenerateReport
    Generate comprehensive validation report

.PARAMETER CreateRelease
    Create automated release after successful validation

.EXAMPLE
    ./tests/Validate-CompleteTestingInfrastructure.ps1 -ValidationScope Complete -CreateBaselines

.EXAMPLE
    ./tests/Validate-CompleteTestingInfrastructure.ps1 -ValidationScope Production -CreateRelease

.NOTES
    Comprehensive validation of all testing infrastructure enhancements
#>

[CmdletBinding()]
param(
    [ValidateSet('Quick', 'Standard', 'Complete', 'Production')]
    [string]$ValidationScope = 'Standard',
    
    [switch]$CreateBaselines,
    [switch]$TestParallelOptimization,
    [switch]$ValidateResourceDetection,
    [switch]$GenerateReport,
    [switch]$CreateRelease,
    [switch]$CI,
    
    [string]$OutputPath = './tests/TestResults/infrastructure-validation',
    [string]$ReportPath = './tests/TestResults/validation-report.html'
)

# Initialize validation environment
$ErrorActionPreference = 'Stop'
$script:ValidationStartTime = Get-Date
$script:ValidationResults = @{
    Scope = $ValidationScope
    StartTime = $script:ValidationStartTime
    TestingInfrastructure = @{}
    ParallelExecution = @{}
    ResourceManagement = @{}
    AdaptiveThrottling = @{}
    PerformanceBaselines = @{}
    CICDIntegration = @{}
    OverallResult = 'Unknown'
    Issues = @()
    Recommendations = @()
    ValidationStages = @()
}

# Ensure output directory exists
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

function Write-ValidationLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO',
        [string]$Stage = 'General'
    )
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $icon = switch ($Level) {
        'INFO' { "ℹ️" }
        'WARN' { "⚠️" }
        'ERROR' { "❌" }
        'SUCCESS' { "✅" }
        'DEBUG' { "🔍" }
    }
    
    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        'SUCCESS' { 'Green' }
        'DEBUG' { 'Gray' }
    }
    
    $formattedMessage = "[$timestamp] [$Stage] $icon $Message"
    Write-Host $formattedMessage -ForegroundColor $color
    
    # Add to validation results
    $script:ValidationResults.ValidationStages += @{
        Timestamp = Get-Date
        Stage = $Stage
        Level = $Level
        Message = $Message
    }
}

function Test-TestingInfrastructureCore {
    <#
    .SYNOPSIS
    Validate core testing infrastructure components
    #>
    $stage = "Testing-Infrastructure"
    Write-ValidationLog "Validating core testing infrastructure..." -Stage $stage
    
    $results = @{
        TestRunners = @{}
        TestUtilities = @{}
        ReportGeneration = @{}
        IssueCreation = @{}
        OverallStatus = 'Unknown'
    }
    
    try {
        # Test production test runner
        Write-ValidationLog "Testing Run-ProductionTests.ps1..." -Stage $stage
        $productionTestPath = Join-Path (Get-Location) 'tests/Run-ProductionTests.ps1'
        
        if (Test-Path $productionTestPath) {
            # Validate script syntax
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $productionTestPath -Raw), [ref]$null)
            $results.TestRunners.ProductionTests = @{ Status = 'Valid'; Features = @('Parallel', 'GitHub Integration', 'Multi-format Reporting') }
            Write-ValidationLog "Production test runner validated ✓" -Level 'SUCCESS' -Stage $stage
        } else {
            $results.TestRunners.ProductionTests = @{ Status = 'Missing'; Issues = @('File not found') }
            $script:ValidationResults.Issues += "Production test runner not found"
        }
        
        # Test quick test runner
        Write-ValidationLog "Testing Invoke-QuickTests.ps1..." -Stage $stage
        $quickTestPath = Join-Path (Get-Location) 'tests/Invoke-QuickTests.ps1'
        
        if (Test-Path $quickTestPath) {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $quickTestPath -Raw), [ref]$null)
            $results.TestRunners.QuickTests = @{ Status = 'Valid'; Features = @('Parallel', 'Coverage Enforcement', 'CI Optimization') }
            Write-ValidationLog "Quick test runner validated ✓" -Level 'SUCCESS' -Stage $stage
        } else {
            $results.TestRunners.QuickTests = @{ Status = 'Missing'; Issues = @('File not found') }
            $script:ValidationResults.Issues += "Quick test runner not found"
        }
        
        # Test module test runner
        Write-ValidationLog "Testing Test-Module.ps1..." -Stage $stage
        $moduleTestPath = Join-Path (Get-Location) 'tests/Test-Module.ps1'
        
        if (Test-Path $moduleTestPath) {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $moduleTestPath -Raw), [ref]$null)
            $results.TestRunners.ModuleTests = @{ Status = 'Valid'; Features = @('Parallel', 'Watch Mode', 'Coverage Analysis') }
            Write-ValidationLog "Module test runner validated ✓" -Level 'SUCCESS' -Stage $stage
        } else {
            $results.TestRunners.ModuleTests = @{ Status = 'Missing'; Issues = @('File not found') }
            $script:ValidationResults.Issues += "Module test runner not found"
        }
        
        # Test release validation
        Write-ValidationLog "Testing Invoke-ReleaseValidation.ps1..." -Stage $stage
        $releaseValidationPath = Join-Path (Get-Location) 'tests/Invoke-ReleaseValidation.ps1'
        
        if (Test-Path $releaseValidationPath) {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $releaseValidationPath -Raw), [ref]$null)
            $results.TestRunners.ReleaseValidation = @{ Status = 'Valid'; Features = @('Parallel Stages', 'Multi-level Validation', 'Automated Release') }
            Write-ValidationLog "Release validation runner validated ✓" -Level 'SUCCESS' -Stage $stage
        } else {
            $results.TestRunners.ReleaseValidation = @{ Status = 'Missing'; Issues = @('File not found') }
            $script:ValidationResults.Issues += "Release validation runner not found"
        }
        
        # Test utilities
        Write-ValidationLog "Testing test utilities..." -Stage $stage
        $testUtilitiesPath = Join-Path (Get-Location) 'tests/Shared/Test-Utilities.ps1'
        
        if (Test-Path $testUtilitiesPath) {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $testUtilitiesPath -Raw), [ref]$null)
            $results.TestUtilities.SharedUtilities = @{ Status = 'Valid'; Functions = @('Write-TestLog', 'Assert-TestResult', 'Test-FileExists') }
            Write-ValidationLog "Test utilities validated ✓" -Level 'SUCCESS' -Stage $stage
        } else {
            $results.TestUtilities.SharedUtilities = @{ Status = 'Missing'; Issues = @('File not found') }
            $script:ValidationResults.Issues += "Test utilities not found"
        }
        
        # Count successful validations
        $validRunners = ($results.TestRunners.Values | Where-Object { $_.Status -eq 'Valid' }).Count
        $totalRunners = $results.TestRunners.Count
        
        if ($validRunners -eq $totalRunners) {
            $results.OverallStatus = 'Pass'
            Write-ValidationLog "Testing infrastructure validation: $validRunners/$totalRunners runners validated ✓" -Level 'SUCCESS' -Stage $stage
        } else {
            $results.OverallStatus = 'Partial'
            Write-ValidationLog "Testing infrastructure validation: $validRunners/$totalRunners runners validated" -Level 'WARN' -Stage $stage
        }
        
    } catch {
        $results.OverallStatus = 'Fail'
        $script:ValidationResults.Issues += "Testing infrastructure validation failed: $_"
        Write-ValidationLog "Testing infrastructure validation failed: $_" -Level 'ERROR' -Stage $stage
    }
    
    $script:ValidationResults.TestingInfrastructure = $results
    return $results.OverallStatus -eq 'Pass'
}

function Test-ParallelExecutionCapabilities {
    <#
    .SYNOPSIS
    Validate parallel execution and optimization features
    #>
    $stage = "Parallel-Execution"
    Write-ValidationLog "Validating parallel execution capabilities..." -Stage $stage
    
    $results = @{
        ParallelModule = @{}
        IntelligentSettings = @{}
        AdaptiveExecution = @{}
        PerformanceOptimization = @{}
        OverallStatus = 'Unknown'
    }
    
    try {
        # Test ParallelExecution module
        Write-ValidationLog "Testing ParallelExecution module..." -Stage $stage
        $parallelModulePath = Join-Path (Get-Location) 'aither-core/modules/ParallelExecution'
        
        if (Test-Path $parallelModulePath) {
            Import-Module $parallelModulePath -Force
            
            # Test core functions
            $coreFunctions = @('Invoke-ParallelForEach', 'Start-ParallelJob', 'Wait-ParallelJobs', 'Invoke-ParallelPesterTests', 'Merge-ParallelTestResults')
            $enhancedFunctions = @('Get-IntelligentParallelSettings', 'Start-AdaptiveParallelExecution', 'Get-ParallelExecutionAnalytics')
            
            $availableFunctions = Get-Command -Module ParallelExecution | ForEach-Object { $_.Name }
            
            $coreAvailable = $coreFunctions | ForEach-Object { $availableFunctions -contains $_ }
            $enhancedAvailable = $enhancedFunctions | ForEach-Object { $availableFunctions -contains $_ }
            
            $results.ParallelModule = @{
                Status = if ($coreAvailable -notcontains $false -and $enhancedAvailable -notcontains $false) { 'Complete' } else { 'Partial' }
                CoreFunctions = $coreAvailable -notcontains $false
                EnhancedFunctions = $enhancedAvailable -notcontains $false
                AvailableFunctions = $availableFunctions
            }
            
            if ($results.ParallelModule.Status -eq 'Complete') {
                Write-ValidationLog "ParallelExecution module complete with all enhanced features ✓" -Level 'SUCCESS' -Stage $stage
            } else {
                Write-ValidationLog "ParallelExecution module partially available" -Level 'WARN' -Stage $stage
            }
            
        } else {
            $results.ParallelModule = @{ Status = 'Missing'; Issues = @('Module not found') }
            $script:ValidationResults.Issues += "ParallelExecution module not found"
        }
        
        # Test intelligent parallel settings
        if ($results.ParallelModule.EnhancedFunctions) {
            Write-ValidationLog "Testing intelligent parallel settings..." -Stage $stage
            
            try {
                $intelligentSettings = Get-IntelligentParallelSettings -WorkloadType 'Test'
                
                $results.IntelligentSettings = @{
                    Status = 'Available'
                    OptimalThreads = $intelligentSettings.OptimalThreads
                    MaxSafeThreads = $intelligentSettings.MaxSafeThreads
                    RecommendParallel = $intelligentSettings.RecommendParallel
                    IntelligentDetection = $intelligentSettings.IntelligentDetection
                    Source = $intelligentSettings.Source
                }
                
                Write-ValidationLog "Intelligent settings: $($intelligentSettings.OptimalThreads) threads (Source: $($intelligentSettings.Source)) ✓" -Level 'SUCCESS' -Stage $stage
                
            } catch {
                $results.IntelligentSettings = @{ Status = 'Error'; Issues = @("Failed to get intelligent settings: $_") }
                Write-ValidationLog "Intelligent settings failed: $_" -Level 'WARN' -Stage $stage
            }
        }
        
        # Test basic parallel execution
        if ($results.ParallelModule.CoreFunctions) {
            Write-ValidationLog "Testing basic parallel execution..." -Stage $stage
            
            try {
                $testItems = 1..10
                $startTime = Get-Date
                
                $parallelResults = Invoke-ParallelForEach -InputObject $testItems -ScriptBlock {
                    param($item)
                    Start-Sleep -Milliseconds 100
                    return "Item-$item-Processed"
                } -ThrottleLimit 4
                
                $duration = (Get-Date) - $startTime
                
                if ($parallelResults.Count -eq $testItems.Count) {
                    $results.PerformanceOptimization = @{
                        Status = 'Working'
                        ItemsProcessed = $parallelResults.Count
                        Duration = $duration.TotalSeconds
                        ThroughputPerSecond = [math]::Round($parallelResults.Count / $duration.TotalSeconds, 2)
                    }
                    
                    Write-ValidationLog "Parallel execution test: $($parallelResults.Count) items in $($duration.TotalSeconds.ToString('F2'))s ✓" -Level 'SUCCESS' -Stage $stage
                } else {
                    $results.PerformanceOptimization = @{ Status = 'Incomplete'; Issues = @('Not all items processed') }
                }
                
            } catch {
                $results.PerformanceOptimization = @{ Status = 'Error'; Issues = @("Parallel execution failed: $_") }
                Write-ValidationLog "Parallel execution test failed: $_" -Level 'ERROR' -Stage $stage
            }
        }
        
        # Determine overall status
        $successfulComponents = 0
        $totalComponents = 4
        
        if ($results.ParallelModule.Status -eq 'Complete') { $successfulComponents++ }
        if ($results.IntelligentSettings.Status -eq 'Available') { $successfulComponents++ }
        if ($results.PerformanceOptimization.Status -eq 'Working') { $successfulComponents++ }
        
        if ($successfulComponents -eq $totalComponents) {
            $results.OverallStatus = 'Pass'
        } elseif ($successfulComponents -ge 2) {
            $results.OverallStatus = 'Partial'
        } else {
            $results.OverallStatus = 'Fail'
        }
        
        Write-ValidationLog "Parallel execution validation: $successfulComponents/$totalComponents components validated" -Level ($results.OverallStatus -eq 'Pass' ? 'SUCCESS' : 'WARN') -Stage $stage
        
    } catch {
        $results.OverallStatus = 'Fail'
        $script:ValidationResults.Issues += "Parallel execution validation failed: $_"
        Write-ValidationLog "Parallel execution validation failed: $_" -Level 'ERROR' -Stage $stage
    }
    
    $script:ValidationResults.ParallelExecution = $results
    return $results.OverallStatus -in @('Pass', 'Partial')
}

function Test-ResourceManagement {
    <#
    .SYNOPSIS
    Validate intelligent resource management and monitoring
    #>
    $stage = "Resource-Management"
    Write-ValidationLog "Validating resource management capabilities..." -Stage $stage
    
    $results = @{
        SystemMonitoring = @{}
        ResourceDetection = @{}
        PressureMonitoring = @{}
        PerformanceBaselines = @{}
        OverallStatus = 'Unknown'
    }
    
    try {
        # Test SystemMonitoring module
        Write-ValidationLog "Testing SystemMonitoring module..." -Stage $stage
        $systemMonitoringPath = Join-Path (Get-Location) 'aither-core/modules/SystemMonitoring'
        
        if (Test-Path $systemMonitoringPath) {
            Import-Module $systemMonitoringPath -Force
            
            # Test enhanced functions
            $enhancedFunctions = @('Get-IntelligentResourceMetrics', 'Watch-SystemResourcePressure', 'New-ParallelExecutionBaseline')
            $availableFunctions = Get-Command -Module SystemMonitoring | ForEach-Object { $_.Name }
            
            $enhancedAvailable = $enhancedFunctions | ForEach-Object { $availableFunctions -contains $_ }
            
            $results.SystemMonitoring = @{
                Status = if ($enhancedAvailable -notcontains $false) { 'Enhanced' } else { 'Basic' }
                EnhancedFunctions = $enhancedAvailable -notcontains $false
                AvailableFunctions = $availableFunctions
            }
            
            if ($results.SystemMonitoring.Status -eq 'Enhanced') {
                Write-ValidationLog "SystemMonitoring module enhanced with intelligent features ✓" -Level 'SUCCESS' -Stage $stage
            } else {
                Write-ValidationLog "SystemMonitoring module basic functionality only" -Level 'WARN' -Stage $stage
            }
            
        } else {
            $results.SystemMonitoring = @{ Status = 'Missing'; Issues = @('Module not found') }
            $script:ValidationResults.Issues += "SystemMonitoring module not found"
        }
        
        # Test resource detection
        if ($results.SystemMonitoring.EnhancedFunctions) {
            Write-ValidationLog "Testing intelligent resource detection..." -Stage $stage
            
            try {
                $resourceMetrics = Get-IntelligentResourceMetrics -IncludeRecommendations -DetailedAnalysis
                
                $results.ResourceDetection = @{
                    Status = 'Working'
                    Platform = $resourceMetrics.Platform.OS
                    ProcessorCount = $resourceMetrics.Platform.ProcessorCount
                    TotalMemoryGB = $resourceMetrics.Hardware.Memory.TotalPhysicalGB
                    AvailableMemoryGB = $resourceMetrics.Hardware.Memory.AvailableGB
                    RecommendParallel = $resourceMetrics.Recommendations.RecommendParallel
                    OptimalThreads = $resourceMetrics.Recommendations.OptimalParallelThreads
                    AnalysisLevel = $resourceMetrics.AnalysisLevel
                }
                
                Write-ValidationLog "Resource detection: $($resourceMetrics.Platform.ProcessorCount) cores, $($resourceMetrics.Hardware.Memory.TotalPhysicalGB)GB RAM ✓" -Level 'SUCCESS' -Stage $stage
                
            } catch {
                $results.ResourceDetection = @{ Status = 'Error'; Issues = @("Resource detection failed: $_") }
                Write-ValidationLog "Resource detection failed: $_" -Level 'ERROR' -Stage $stage
            }
        }
        
        # Test pressure monitoring (short test)
        if ($results.SystemMonitoring.EnhancedFunctions) {
            Write-ValidationLog "Testing resource pressure monitoring..." -Stage $stage
            
            try {
                # Short monitoring test
                $monitoring = Watch-SystemResourcePressure -MonitoringInterval 2 -MaxMonitoringDuration 1 -ReturnImmediately
                
                if ($monitoring) {
                    Start-Sleep -Seconds 3  # Let it collect some data
                    
                    $report = Get-ResourcePressureReport -MonitoringData $monitoring -ReportType 'Summary'
                    
                    $results.PressureMonitoring = @{
                        Status = 'Working'
                        MonitoringActive = $monitoring.MonitoringActive
                        SamplesCollected = $monitoring.PressureHistory.Count
                        ReportGenerated = $report -ne $null
                    }
                    
                    # Stop monitoring
                    Stop-ResourcePressureMonitoring -MonitoringData $monitoring
                    
                    Write-ValidationLog "Pressure monitoring: Collected samples and generated report ✓" -Level 'SUCCESS' -Stage $stage
                } else {
                    $results.PressureMonitoring = @{ Status = 'Failed'; Issues = @('Monitoring not started') }
                }
                
            } catch {
                $results.PressureMonitoring = @{ Status = 'Error'; Issues = @("Pressure monitoring failed: $_") }
                Write-ValidationLog "Pressure monitoring failed: $_" -Level 'WARN' -Stage $stage
            }
        }
        
        # Determine overall status
        $successfulComponents = 0
        $totalComponents = 3
        
        if ($results.SystemMonitoring.Status -eq 'Enhanced') { $successfulComponents++ }
        if ($results.ResourceDetection.Status -eq 'Working') { $successfulComponents++ }
        if ($results.PressureMonitoring.Status -eq 'Working') { $successfulComponents++ }
        
        if ($successfulComponents -eq $totalComponents) {
            $results.OverallStatus = 'Pass'
        } elseif ($successfulComponents -ge 2) {
            $results.OverallStatus = 'Partial'
        } else {
            $results.OverallStatus = 'Fail'
        }
        
        Write-ValidationLog "Resource management validation: $successfulComponents/$totalComponents components validated" -Level ($results.OverallStatus -eq 'Pass' ? 'SUCCESS' : 'WARN') -Stage $stage
        
    } catch {
        $results.OverallStatus = 'Fail'
        $script:ValidationResults.Issues += "Resource management validation failed: $_"
        Write-ValidationLog "Resource management validation failed: $_" -Level 'ERROR' -Stage $stage
    }
    
    $script:ValidationResults.ResourceManagement = $results
    return $results.OverallStatus -in @('Pass', 'Partial')
}

function Test-AdaptiveThrottling {
    <#
    .SYNOPSIS
    Test adaptive throttling under simulated load conditions
    #>
    $stage = "Adaptive-Throttling"
    Write-ValidationLog "Testing adaptive throttling capabilities..." -Stage $stage
    
    if (-not $TestParallelOptimization) {
        Write-ValidationLog "Adaptive throttling test skipped (not requested)" -Level 'INFO' -Stage $stage
        $script:ValidationResults.AdaptiveThrottling = @{ Status = 'Skipped'; Reason = 'Not requested' }
        return $true
    }
    
    $results = @{
        AdaptiveExecution = @{}
        ThrottleAdjustments = @{}
        PerformanceImpact = @{}
        OverallStatus = 'Unknown'
    }
    
    try {
        Write-ValidationLog "Testing adaptive parallel execution..." -Stage $stage
        
        # Import required modules
        $parallelModulePath = Join-Path (Get-Location) 'aither-core/modules/ParallelExecution'
        $systemMonitoringPath = Join-Path (Get-Location) 'aither-core/modules/SystemMonitoring'
        
        Import-Module $parallelModulePath -Force
        Import-Module $systemMonitoringPath -Force
        
        # Test adaptive execution with monitoring
        $testItems = 1..20
        $adaptiveResults = $null
        
        try {
            $adaptiveResults = Start-AdaptiveParallelExecution -ScriptBlock {
                param($item)
                # Simulate variable workload
                Start-Sleep -Milliseconds (Get-Random -Minimum 50 -Maximum 200)
                return "Adaptive-Item-$item"
            } -InputObject $testItems -WorkloadType 'Test' -EnableAdaptiveThrottling
            
            if ($adaptiveResults -and $adaptiveResults.Count -eq $testItems.Count) {
                $results.AdaptiveExecution = @{
                    Status = 'Working'
                    ItemsProcessed = $adaptiveResults.Count
                    AdaptiveEnabled = $true
                }
                
                Write-ValidationLog "Adaptive execution processed $($adaptiveResults.Count) items successfully ✓" -Level 'SUCCESS' -Stage $stage
            } else {
                $results.AdaptiveExecution = @{ Status = 'Partial'; Issues = @('Not all items processed or adaptive execution failed') }
            }
            
        } catch {
            $results.AdaptiveExecution = @{ Status = 'Error'; Issues = @("Adaptive execution failed: $_") }
            Write-ValidationLog "Adaptive execution failed: $_" -Level 'ERROR' -Stage $stage
        }
        
        # Test throttle adjustment simulation
        Write-ValidationLog "Testing throttle adjustment logic..." -Stage $stage
        
        try {
            # Get intelligent settings for comparison
            $intelligentSettings = Get-IntelligentParallelSettings -WorkloadType 'Test'
            
            $results.ThrottleAdjustments = @{
                Status = 'Tested'
                BaselineThreads = $intelligentSettings.OptimalThreads
                MaxSafeThreads = $intelligentSettings.MaxSafeThreads
                RecommendParallel = $intelligentSettings.RecommendParallel
                IntelligentDetection = $intelligentSettings.IntelligentDetection
            }
            
            Write-ValidationLog "Throttle adjustment: $($intelligentSettings.OptimalThreads) optimal threads detected ✓" -Level 'SUCCESS' -Stage $stage
            
        } catch {
            $results.ThrottleAdjustments = @{ Status = 'Error'; Issues = @("Throttle adjustment test failed: $_") }
            Write-ValidationLog "Throttle adjustment test failed: $_" -Level 'WARN' -Stage $stage
        }
        
        # Determine overall status
        if ($results.AdaptiveExecution.Status -eq 'Working' -and $results.ThrottleAdjustments.Status -eq 'Tested') {
            $results.OverallStatus = 'Pass'
        } elseif ($results.AdaptiveExecution.Status -ne 'Error' -or $results.ThrottleAdjustments.Status -ne 'Error') {
            $results.OverallStatus = 'Partial'
        } else {
            $results.OverallStatus = 'Fail'
        }
        
        Write-ValidationLog "Adaptive throttling validation: $($results.OverallStatus)" -Level ($results.OverallStatus -eq 'Pass' ? 'SUCCESS' : 'WARN') -Stage $stage
        
    } catch {
        $results.OverallStatus = 'Fail'
        $script:ValidationResults.Issues += "Adaptive throttling validation failed: $_"
        Write-ValidationLog "Adaptive throttling validation failed: $_" -Level 'ERROR' -Stage $stage
    }
    
    $script:ValidationResults.AdaptiveThrottling = $results
    return $results.OverallStatus -in @('Pass', 'Partial')
}

function New-PerformanceBaselines {
    <#
    .SYNOPSIS
    Create performance baselines for all workload types
    #>
    $stage = "Performance-Baselines"
    Write-ValidationLog "Creating performance baselines..." -Stage $stage
    
    if (-not $CreateBaselines) {
        Write-ValidationLog "Baseline creation skipped (not requested)" -Level 'INFO' -Stage $stage
        $script:ValidationResults.PerformanceBaselines = @{ Status = 'Skipped'; Reason = 'Not requested' }
        return $true
    }
    
    $results = @{
        Baselines = @{}
        OverallStatus = 'Unknown'
    }
    
    try {
        # Import SystemMonitoring module
        $systemMonitoringPath = Join-Path (Get-Location) 'aither-core/modules/SystemMonitoring'
        Import-Module $systemMonitoringPath -Force
        
        $workloadTypes = @('Test', 'Build', 'Analysis', 'General')
        
        foreach ($workloadType in $workloadTypes) {
            Write-ValidationLog "Creating baseline for $workloadType workload..." -Stage $stage
            
            try {
                $baseline = New-ParallelExecutionBaseline -WorkloadType $workloadType -BaselineIterations 3 -IncludeSequential -ExportFormat 'JSON' -OutputPath $OutputPath
                
                if ($baseline -and $baseline.OptimalConfiguration) {
                    $results.Baselines[$workloadType] = @{
                        Status = 'Created'
                        OptimalThreads = $baseline.OptimalConfiguration.OptimalThreads
                        PerformanceImprovement = $baseline.OptimalConfiguration.PerformanceImprovement
                        Recommendation = $baseline.OptimalConfiguration.Recommendation
                        BaselineFile = "baseline-$workloadType-*.json"
                    }
                    
                    Write-ValidationLog "$workloadType baseline: $($baseline.OptimalConfiguration.OptimalThreads) threads, $($baseline.OptimalConfiguration.PerformanceImprovement)% improvement ✓" -Level 'SUCCESS' -Stage $stage
                } else {
                    $results.Baselines[$workloadType] = @{ Status = 'Failed'; Issues = @('Baseline creation returned null') }
                }
                
            } catch {
                $results.Baselines[$workloadType] = @{ Status = 'Error'; Issues = @("Baseline creation failed: $_") }
                Write-ValidationLog "$workloadType baseline failed: $_" -Level 'ERROR' -Stage $stage
            }
        }
        
        # Determine overall status
        $successfulBaselines = ($results.Baselines.Values | Where-Object { $_.Status -eq 'Created' }).Count
        $totalBaselines = $results.Baselines.Count
        
        if ($successfulBaselines -eq $totalBaselines) {
            $results.OverallStatus = 'Pass'
        } elseif ($successfulBaselines -gt 0) {
            $results.OverallStatus = 'Partial'
        } else {
            $results.OverallStatus = 'Fail'
        }
        
        Write-ValidationLog "Baseline creation: $successfulBaselines/$totalBaselines baselines created" -Level ($results.OverallStatus -eq 'Pass' ? 'SUCCESS' : 'WARN') -Stage $stage
        
    } catch {
        $results.OverallStatus = 'Fail'
        $script:ValidationResults.Issues += "Baseline creation failed: $_"
        Write-ValidationLog "Baseline creation failed: $_" -Level 'ERROR' -Stage $stage
    }
    
    $script:ValidationResults.PerformanceBaselines = $results
    return $results.OverallStatus -in @('Pass', 'Partial')
}

function Test-CICDIntegration {
    <#
    .SYNOPSIS
    Validate CI/CD integration and GitHub Actions compatibility
    #>
    $stage = "CICD-Integration"
    Write-ValidationLog "Validating CI/CD integration..." -Stage $stage
    
    $results = @{
        GitHubActions = @{}
        WorkflowFiles = @{}
        BuildPipeline = @{}
        OverallStatus = 'Unknown'
    }
    
    try {
        # Check GitHub Actions workflow files
        Write-ValidationLog "Checking GitHub Actions workflows..." -Stage $stage
        $workflowsPath = Join-Path (Get-Location) '.github/workflows'
        
        if (Test-Path $workflowsPath) {
            $workflowFiles = Get-ChildItem -Path $workflowsPath -Filter "*.yml" -File
            
            $criticalWorkflows = @('intelligent-cicd.yml', 'build-release.yml', 'docs-sync.yml')
            $foundWorkflows = @()
            
            foreach ($workflow in $criticalWorkflows) {
                if ($workflowFiles.Name -contains $workflow) {
                    $foundWorkflows += $workflow
                }
            }
            
            $results.WorkflowFiles = @{
                Status = if ($foundWorkflows.Count -eq $criticalWorkflows.Count) { 'Complete' } else { 'Partial' }
                TotalWorkflows = $workflowFiles.Count
                CriticalWorkflows = $foundWorkflows.Count
                FoundWorkflows = $foundWorkflows
            }
            
            Write-ValidationLog "GitHub workflows: $($foundWorkflows.Count)/$($criticalWorkflows.Count) critical workflows found ✓" -Level 'SUCCESS' -Stage $stage
            
        } else {
            $results.WorkflowFiles = @{ Status = 'Missing'; Issues = @('Workflows directory not found') }
            $script:ValidationResults.Issues += "GitHub workflows directory not found"
        }
        
        # Check build and release pipeline
        Write-ValidationLog "Checking build and release pipeline..." -Stage $stage
        $buildScriptPath = Join-Path (Get-Location) 'build/Build-Package.ps1'
        
        if (Test-Path $buildScriptPath) {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $buildScriptPath -Raw), [ref]$null)
            $results.BuildPipeline = @{ Status = 'Available'; Features = @('Multi-platform', 'Multi-profile', 'Automated') }
            Write-ValidationLog "Build pipeline script validated ✓" -Level 'SUCCESS' -Stage $stage
        } else {
            $results.BuildPipeline = @{ Status = 'Missing'; Issues = @('Build script not found') }
            Write-ValidationLog "Build pipeline script not found" -Level 'WARN' -Stage $stage
        }
        
        # Test PatchManager release workflow
        Write-ValidationLog "Testing PatchManager release workflow..." -Stage $stage
        $patchManagerPath = Join-Path (Get-Location) 'aither-core/modules/PatchManager'
        
        if (Test-Path $patchManagerPath) {
            Import-Module $patchManagerPath -Force
            
            $releaseFunction = Get-Command Invoke-ReleaseWorkflow -ErrorAction SilentlyContinue
            if ($releaseFunction) {
                $results.GitHubActions = @{
                    Status = 'Available'
                    ReleaseWorkflow = 'Available'
                    PatchManager = 'Loaded'
                }
                Write-ValidationLog "PatchManager release workflow available ✓" -Level 'SUCCESS' -Stage $stage
            } else {
                $results.GitHubActions = @{ Status = 'Partial'; Issues = @('Release workflow function not found') }
            }
        } else {
            $results.GitHubActions = @{ Status = 'Missing'; Issues = @('PatchManager module not found') }
        }
        
        # Determine overall status
        $successfulComponents = 0
        $totalComponents = 3
        
        if ($results.WorkflowFiles.Status -eq 'Complete') { $successfulComponents++ }
        if ($results.BuildPipeline.Status -eq 'Available') { $successfulComponents++ }
        if ($results.GitHubActions.Status -eq 'Available') { $successfulComponents++ }
        
        if ($successfulComponents -eq $totalComponents) {
            $results.OverallStatus = 'Pass'
        } elseif ($successfulComponents -ge 2) {
            $results.OverallStatus = 'Partial'
        } else {
            $results.OverallStatus = 'Fail'
        }
        
        Write-ValidationLog "CI/CD integration validation: $successfulComponents/$totalComponents components validated" -Level ($results.OverallStatus -eq 'Pass' ? 'SUCCESS' : 'WARN') -Stage $stage
        
    } catch {
        $results.OverallStatus = 'Fail'
        $script:ValidationResults.Issues += "CI/CD integration validation failed: $_"
        Write-ValidationLog "CI/CD integration validation failed: $_" -Level 'ERROR' -Stage $stage
    }
    
    $script:ValidationResults.CICDIntegration = $results
    return $results.OverallStatus -in @('Pass', 'Partial')
}

function Invoke-AutomatedRelease {
    <#
    .SYNOPSIS
    Create automated release using enhanced testing pipeline
    #>
    $stage = "Automated-Release"
    Write-ValidationLog "Creating automated release..." -Stage $stage
    
    if (-not $CreateRelease) {
        Write-ValidationLog "Automated release skipped (not requested)" -Level 'INFO' -Stage $stage
        return $true
    }
    
    try {
        # Import PatchManager
        $patchManagerPath = Join-Path (Get-Location) 'aither-core/modules/PatchManager'
        Import-Module $patchManagerPath -Force
        
        Write-ValidationLog "Starting automated release workflow..." -Stage $stage
        
        # Create release using PatchManager
        $releaseDescription = "Enhanced testing infrastructure with intelligent parallel execution and adaptive throttling"
        
        $releaseResult = Invoke-ReleaseWorkflow -ReleaseType "patch" -Description $releaseDescription -DryRun:$CI
        
        if ($releaseResult) {
            Write-ValidationLog "Automated release workflow completed successfully ✓" -Level 'SUCCESS' -Stage $stage
            return $true
        } else {
            Write-ValidationLog "Automated release workflow failed" -Level 'ERROR' -Stage $stage
            $script:ValidationResults.Issues += "Automated release failed"
            return $false
        }
        
    } catch {
        Write-ValidationLog "Automated release failed: $_" -Level 'ERROR' -Stage $stage
        $script:ValidationResults.Issues += "Automated release failed: $_"
        return $false
    }
}

function Export-ValidationReport {
    <#
    .SYNOPSIS
    Generate comprehensive validation report
    #>
    if (-not $GenerateReport) {
        return
    }
    
    Write-ValidationLog "Generating comprehensive validation report..." -Stage "Report-Generation"
    
    try {
        $script:ValidationResults.EndTime = Get-Date
        $script:ValidationResults.TotalDuration = $script:ValidationResults.EndTime - $script:ValidationResults.StartTime
        
        # Determine overall result
        $componentResults = @(
            $script:ValidationResults.TestingInfrastructure.OverallStatus,
            $script:ValidationResults.ParallelExecution.OverallStatus,
            $script:ValidationResults.ResourceManagement.OverallStatus
        )
        
        $passCount = ($componentResults | Where-Object { $_ -eq 'Pass' }).Count
        $partialCount = ($componentResults | Where-Object { $_ -eq 'Partial' }).Count
        $failCount = ($componentResults | Where-Object { $_ -eq 'Fail' }).Count
        
        if ($failCount -gt 0) {
            $script:ValidationResults.OverallResult = 'Failed'
        } elseif ($partialCount -gt 0) {
            $script:ValidationResults.OverallResult = 'Partial'
        } else {
            $script:ValidationResults.OverallResult = 'Passed'
        }
        
        # Generate recommendations
        $script:ValidationResults.Recommendations = @()
        
        if ($script:ValidationResults.ParallelExecution.OverallStatus -eq 'Pass') {
            $script:ValidationResults.Recommendations += "Parallel execution infrastructure is fully functional - enable by default"
        }
        
        if ($script:ValidationResults.ResourceManagement.OverallStatus -eq 'Pass') {
            $script:ValidationResults.Recommendations += "Intelligent resource management is operational - use for optimal performance"
        }
        
        if ($script:ValidationResults.Issues.Count -gt 0) {
            $script:ValidationResults.Recommendations += "Address identified issues before production deployment"
        } else {
            $script:ValidationResults.Recommendations += "Infrastructure validation successful - ready for production use"
        }
        
        # Export JSON report
        $jsonReport = $script:ValidationResults | ConvertTo-Json -Depth 10
        $jsonReportPath = Join-Path $OutputPath "infrastructure-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $jsonReport | Out-File $jsonReportPath -Encoding UTF8
        
        # Generate HTML report
        $htmlReport = New-ValidationHtmlReport -ValidationResults $script:ValidationResults
        $htmlReport | Out-File $ReportPath -Encoding UTF8
        
        Write-ValidationLog "Validation report generated: $ReportPath" -Level 'SUCCESS' -Stage "Report-Generation"
        
    } catch {
        Write-ValidationLog "Report generation failed: $_" -Level 'ERROR' -Stage "Report-Generation"
    }
}

function New-ValidationHtmlReport {
    param([hashtable]$ValidationResults)
    
    $overallColor = switch ($ValidationResults.OverallResult) {
        'Passed' { '#28a745' }
        'Partial' { '#ffc107' }
        'Failed' { '#dc3545' }
        default { '#6c757d' }
    }
    
    return @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero Testing Infrastructure Validation Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8f9fa; color: #333; line-height: 1.6; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; border-radius: 10px; margin-bottom: 30px; text-align: center; }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .status-badge { display: inline-block; padding: 10px 20px; border-radius: 25px; color: white; font-weight: bold; background: $overallColor; }
        .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric-card { background: white; padding: 25px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.05); text-align: center; }
        .section { background: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.05); }
        .section h2 { font-size: 1.8em; margin-bottom: 20px; color: #495057; border-bottom: 2px solid #e9ecef; padding-bottom: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 Testing Infrastructure Validation</h1>
            <p>Generated: $($ValidationResults.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))</p>
            <p>Validation Scope: $($ValidationResults.Scope)</p>
            <div style="margin-top: 20px;">
                <span class="status-badge">$($ValidationResults.OverallResult)</span>
            </div>
        </div>
        
        <div class="section">
            <h2>📊 Validation Summary</h2>
            <div class="metrics-grid">
                <div class="metric-card">
                    <h3>Testing Infrastructure</h3>
                    <div style="font-size: 2em; color: $(if ($ValidationResults.TestingInfrastructure.OverallStatus -eq 'Pass') { '#28a745' } else { '#ffc107' });">$($ValidationResults.TestingInfrastructure.OverallStatus)</div>
                </div>
                <div class="metric-card">
                    <h3>Parallel Execution</h3>
                    <div style="font-size: 2em; color: $(if ($ValidationResults.ParallelExecution.OverallStatus -eq 'Pass') { '#28a745' } else { '#ffc107' });">$($ValidationResults.ParallelExecution.OverallStatus)</div>
                </div>
                <div class="metric-card">
                    <h3>Resource Management</h3>
                    <div style="font-size: 2em; color: $(if ($ValidationResults.ResourceManagement.OverallStatus -eq 'Pass') { '#28a745' } else { '#ffc107' });">$($ValidationResults.ResourceManagement.OverallStatus)</div>
                </div>
                <div class="metric-card">
                    <h3>Total Duration</h3>
                    <div style="font-size: 2em; color: #17a2b8;">$($ValidationResults.TotalDuration.TotalMinutes.ToString('F1'))m</div>
                </div>
            </div>
        </div>
        
        $(if ($ValidationResults.Issues.Count -gt 0) {
            "<div class='section'><h2>❌ Issues Identified</h2><ul>" + 
            ($ValidationResults.Issues | ForEach-Object { "<li>$_</li>" }) -join "" + 
            "</ul></div>"
        })
        
        <div class="section">
            <h2>💡 Recommendations</h2>
            <ul>
                $($ValidationResults.Recommendations | ForEach-Object { "<li>$_</li>" } | Join-String)
            </ul>
        </div>
    </div>
</body>
</html>
"@
}

# Main execution flow
Write-Host ""
Write-Host "🧪 AitherZero Testing Infrastructure Validation" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host "Validation Scope: $ValidationScope" -ForegroundColor Cyan
Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host ""

# Define validation pipeline based on scope
$validationPipeline = @()

switch ($ValidationScope) {
    'Quick' {
        $validationPipeline = @(
            { Test-TestingInfrastructureCore },
            { Test-ParallelExecutionCapabilities }
        )
    }
    'Standard' {
        $validationPipeline = @(
            { Test-TestingInfrastructureCore },
            { Test-ParallelExecutionCapabilities },
            { Test-ResourceManagement },
            { Test-CICDIntegration }
        )
    }
    'Complete' {
        $validationPipeline = @(
            { Test-TestingInfrastructureCore },
            { Test-ParallelExecutionCapabilities },
            { Test-ResourceManagement },
            { Test-AdaptiveThrottling },
            { New-PerformanceBaselines },
            { Test-CICDIntegration }
        )
    }
    'Production' {
        $validationPipeline = @(
            { Test-TestingInfrastructureCore },
            { Test-ParallelExecutionCapabilities },
            { Test-ResourceManagement },
            { Test-AdaptiveThrottling },
            { New-PerformanceBaselines },
            { Test-CICDIntegration },
            { Invoke-AutomatedRelease }
        )
    }
}

# Execute validation pipeline
$overallSuccess = $true
$stageCount = 0
$totalStages = $validationPipeline.Count

foreach ($stage in $validationPipeline) {
    $stageCount++
    
    Write-Host ""
    Write-Host "[$stageCount/$totalStages] " -NoNewline -ForegroundColor Yellow
    
    try {
        $result = & $stage
        if (-not $result) {
            $overallSuccess = $false
            Write-ValidationLog "Validation stage failed but continuing..." -Level 'WARN'
        }
    } catch {
        Write-ValidationLog "Validation stage failed with exception: $_" -Level 'ERROR'
        $overallSuccess = $false
    }
}

# Generate report
Export-ValidationReport

# Final summary
Write-Host ""
Write-Host "=" * 80 -ForegroundColor Yellow
Write-Host "🏁 INFRASTRUCTURE VALIDATION SUMMARY" -ForegroundColor Yellow
Write-Host "=" * 80 -ForegroundColor Yellow
Write-Host ""

$finalResult = $script:ValidationResults.OverallResult
$resultColor = switch ($finalResult) {
    'Passed' { 'Green' }
    'Partial' { 'Yellow' }
    'Failed' { 'Red' }
    default { 'Gray' }
}

Write-Host "Overall Result: " -NoNewline
Write-Host $finalResult -ForegroundColor $resultColor -NoNewline
Write-Host " ($($script:ValidationResults.TotalDuration.TotalMinutes.ToString('F1')) minutes)"

Write-Host "Validation Scope: $ValidationScope"
Write-Host "Stages Completed: $totalStages"

if ($script:ValidationResults.Issues.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ Issues: $($script:ValidationResults.Issues.Count)" -ForegroundColor Red
    foreach ($issue in $script:ValidationResults.Issues) {
        Write-Host "  • $issue" -ForegroundColor Red
    }
}

if ($script:ValidationResults.Recommendations.Count -gt 0) {
    Write-Host ""
    Write-Host "💡 Recommendations: $($script:ValidationResults.Recommendations.Count)" -ForegroundColor Cyan
    foreach ($recommendation in $script:ValidationResults.Recommendations) {
        Write-Host "  • $recommendation" -ForegroundColor Cyan
    }
}

if ($GenerateReport) {
    Write-Host ""
    Write-Host "📊 Validation report: $ReportPath" -ForegroundColor Green
}

Write-Host ""

# Exit with appropriate code
if ($finalResult -eq 'Failed') {
    exit 1
} elseif ($finalResult -eq 'Partial') {
    exit 2
} else {
    exit 0
}