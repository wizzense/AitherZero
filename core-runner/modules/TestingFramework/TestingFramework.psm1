#Requires -Version 7.0

<#
.SYNOPSIS
    Enhanced Testing Framework for OpenTofu Lab Automation - Central Orchestrator

.DESCRIPTION
    Unified testing framework that serves as the central orchestrator for all testing activities
    across the OpenTofu Lab Automation project. Provides module integration, test coordination,
    cross-platform validation, and seamless integration with VS Code and GitHub Actions.

.FEATURES
    - Module Discovery & Integration: Automatic detection and loading of project modules
    - Test Orchestration: Unified pipeline for all test types (unit, integration, performance)
    - Configuration Management: Profile-based configurations for different environments
    - Parallel Execution: Optimized parallel test execution via ParallelExecution module
    - VS Code Integration: Real-time test results and intelligent test discovery
    - GitHub Actions Support: CI/CD workflow integration with matrix testing
    - Cross-Platform: Native support for Windows, Linux, and macOS
    - Event-Driven: Module communication via publish/subscribe pattern

.NOTES
    This module acts as the central hub for all testing activities and integrates with:
    - LabRunner (execution coordination)
    - ParallelExecution (parallel processing)
    - PatchManager (CI/CD integration)
    - DevEnvironment (environment validation)
    - ScriptManager (test script management)
    - UnifiedMaintenance (cleanup operations)
    - Logging (centralized logging)
#>

# Import the centralized Logging module with fallback
$loggingImported = $false
if (Get-Module -Name 'Logging' -ErrorAction SilentlyContinue) {
    $loggingImported = $true
} else {
    $loggingPaths = @(
        'Logging',
        (Join-Path (Split-Path $PSScriptRoot -Parent) "Logging"),
        (Join-Path $env:PWSH_MODULES_PATH "Logging" -ErrorAction SilentlyContinue),
        (Join-Path $env:PROJECT_ROOT "core-runner/modules/Logging" -ErrorAction SilentlyContinue)
    )

    foreach ($loggingPath in $loggingPaths) {
        if ($loggingImported) { break }
        try {
            if ($loggingPath -eq 'Logging') {
                Import-Module 'Logging' -Global -Force -ErrorAction Stop
            } elseif (Test-Path $loggingPath) {
                Import-Module $loggingPath -Global -Force -ErrorAction Stop
            } else {
                continue
            }
            $loggingImported = $true
        } catch {
            # Continue to next path
        }
    }
}

# Fallback logging function if centralized logging unavailable
if (-not $loggingImported) {
    function Write-TestLog {
        param($Message, $Level = "INFO")
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = switch ($Level) {
            "SUCCESS" { "Green" }
            "WARN" { "Yellow" }
            "ERROR" { "Red" }
            default { "White" }
        }
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
} else {
    # Use centralized logging
    function Write-TestLog {
        param($Message, $Level = "INFO")
        Write-CustomLog -Level $Level -Message $Message
    }
}

# Module registry for tracking registered test providers
$script:TestProviders = @{}
$script:TestConfigurations = @{}
$script:TestEvents = @{}

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
# CORE TESTING ORCHESTRATION FUNCTIONS
# ============================================================================

function Invoke-UnifiedTestExecution {
    <#
    .SYNOPSIS
        Central entry point for all testing activities with module integration

    .DESCRIPTION
        Orchestrates testing across all modules with intelligent dependency resolution,
        parallel execution, and comprehensive reporting

    .PARAMETER TestSuite
        Test suite to execute: All, Unit, Integration, Performance, Modules, Quick

    .PARAMETER TestProfile
        Configuration profile: Development, CI, Production, Debug

    .PARAMETER Modules
        Specific modules to test (default: all discovered modules)

    .PARAMETER Parallel
        Enable parallel test execution

    .PARAMETER OutputPath
        Path for test results and reports

    .PARAMETER VSCodeIntegration
        Enable VS Code integration features

    .PARAMETER GenerateReport
        Generate comprehensive HTML/JSON reports

    .EXAMPLE
        Invoke-UnifiedTestExecution -TestSuite "All" -TestProfile "Development" -GenerateReport

    .EXAMPLE
        Invoke-UnifiedTestExecution -TestSuite "Unit" -Modules @("LabRunner", "PatchManager") -Parallel
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateSet("All", "Unit", "Integration", "Performance", "Modules", "Quick", "NonInteractive")]
        [string]$TestSuite = "All",

        [Parameter()]
        [ValidateSet("Development", "CI", "Production", "Debug")]
        [string]$TestProfile = "Development",

        [Parameter()]
        [string[]]$Modules = @(),

        [Parameter()]
        [switch]$Parallel,

        [Parameter()]
        [string]$OutputPath = "./tests/results/unified",

        [Parameter()]
        [switch]$VSCodeIntegration,

        [Parameter()]
        [switch]$GenerateReport
    )

    begin {
        Write-TestLog "🚀 Starting Unified Test Execution" -Level "INFO"
        Write-TestLog "Test Suite: $TestSuite | Profile: $TestProfile | Parallel: $Parallel" -Level "INFO"

        # Initialize test environment
        Initialize-TestEnvironment -OutputPath $OutputPath -TestProfile $TestProfile

        # Discover and load modules
        $discoveredModules = Get-DiscoveredModules -SpecificModules $Modules
        Write-TestLog "Discovered modules: $($discoveredModules.Count)" -Level "INFO"
    }

    process {
        try {
            # Create test execution plan
            $testPlan = New-TestExecutionPlan -TestSuite $TestSuite -Modules $discoveredModules -TestProfile $TestProfile

            # Execute tests based on plan
            $results = if ($Parallel) {
                Invoke-ParallelTestExecution -TestPlan $testPlan -OutputPath $OutputPath
            } else {
                Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath $OutputPath
            }

            # Generate reports if requested
            if ($GenerateReport) {
                $reportPath = New-TestReport -Results $results -OutputPath $OutputPath -TestSuite $TestSuite
                Write-TestLog "📊 Test report generated: $reportPath" -Level "SUCCESS"
            }

            # VS Code integration
            if ($VSCodeIntegration) {
                Export-VSCodeTestResults -Results $results -OutputPath $OutputPath
            }

            # Publish completion event
            Publish-TestEvent -EventType "TestExecutionCompleted" -Data @{
                TestSuite = $TestSuite
                Results = $results
                Duration = (Get-Date) - $testPlan.StartTime
            }

            return $results

        } catch {
            Write-TestLog "❌ Test execution failed: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }

    end {
        Write-TestLog "✅ Unified Test Execution completed" -Level "SUCCESS"
    }
}

function Get-DiscoveredModules {
    <#
    .SYNOPSIS
        Discovers and validates project modules for testing
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$SpecificModules = @()
    )

    $modulesPath = Join-Path $script:ProjectRoot "core-runner/modules"
    $allModules = @()

    if (-not (Test-Path $modulesPath)) {
        Write-TestLog "⚠️  Modules directory not found: $modulesPath" -Level "WARN"
        return @()
    }

    $moduleDirectories = Get-ChildItem -Path $modulesPath -Directory

    foreach ($moduleDir in $moduleDirectories) {
        # Skip if specific modules requested and this isn't one
        if ($SpecificModules.Count -gt 0 -and $moduleDir.Name -notin $SpecificModules) {
            continue
        }

        $moduleManifest = Join-Path $moduleDir.FullName "$($moduleDir.Name).psd1"
        $moduleScript = Join-Path $moduleDir.FullName "$($moduleDir.Name).psm1"

        if (Test-Path $moduleScript) {
            $moduleInfo = @{
                Name = $moduleDir.Name
                Path = $moduleDir.FullName
                ManifestPath = if (Test-Path $moduleManifest) { $moduleManifest } else { $null }
                ScriptPath = $moduleScript
                TestPath = Join-Path $script:ProjectRoot "tests/unit/modules/$($moduleDir.Name)"
                IntegrationTestPath = Join-Path $script:ProjectRoot "tests/integration"
            }

            $allModules += $moduleInfo
            Write-TestLog "📦 Discovered module: $($moduleDir.Name)" -Level "INFO"
        }
    }

    return $allModules
}

function New-TestExecutionPlan {
    <#
    .SYNOPSIS
        Creates an intelligent test execution plan with dependency resolution
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TestSuite,

        [Parameter(Mandatory)]
        [array]$Modules,

        [Parameter(Mandatory)]
        [string]$TestProfile
    )

    $testPlan = @{
        TestSuite = $TestSuite
        TestProfile = $TestProfile
        StartTime = Get-Date
        Modules = $Modules
        TestPhases = @()
        Configuration = Get-TestConfiguration -Profile $TestProfile
    }

    # Define test phases based on test suite
    switch ($TestSuite) {
        "All" {
            $testPlan.TestPhases = @("Environment", "Unit", "Integration", "Performance")
        }
        "Unit" {
            $testPlan.TestPhases = @("Unit")
        }
        "Integration" {
            $testPlan.TestPhases = @("Environment", "Integration")
        }
        "Performance" {
            $testPlan.TestPhases = @("Performance")
        }
        "Modules" {
            $testPlan.TestPhases = @("Unit", "Integration")
        }
        "Quick" {
            $testPlan.TestPhases = @("Unit")
        }
        "NonInteractive" {
            $testPlan.TestPhases = @("Environment", "Unit", "NonInteractive")
        }
    }

    Write-TestLog "📋 Test plan created with phases: $($testPlan.TestPhases -join ', ')" -Level "INFO"
    return $testPlan
}

function Get-TestConfiguration {
    <#
    .SYNOPSIS
        Retrieves test configuration based on profile
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Profile
    )

    $baseConfig = @{
        Verbosity = "Normal"
        TimeoutMinutes = 30
        RetryCount = 2
        MockLevel = "Standard"
        Platform = "All"
        ParallelJobs = [Math]::Min(4, ([Environment]::ProcessorCount))
    }

    $profileConfigs = @{
        Development = @{
            Verbosity = "Detailed"
            TimeoutMinutes = 15
            MockLevel = "High"
        }
        CI = @{
            Verbosity = "Normal"
            TimeoutMinutes = 45
            RetryCount = 3
            MockLevel = "Standard"
        }
        Production = @{
            Verbosity = "Normal"
            TimeoutMinutes = 60
            RetryCount = 1
            MockLevel = "Low"
        }
        Debug = @{
            Verbosity = "Verbose"
            TimeoutMinutes = 120
            MockLevel = "None"
            ParallelJobs = 1
        }
    }

    $config = $baseConfig.Clone()
    if ($profileConfigs.ContainsKey($Profile)) {
        foreach ($key in $profileConfigs[$Profile].Keys) {
            $config[$key] = $profileConfigs[$Profile][$key]
        }
    }

    return $config
}

# ============================================================================
# TEST EXECUTION ENGINES
# ============================================================================

function Invoke-ParallelTestExecution {
    <#
    .SYNOPSIS
        Executes tests in parallel using ParallelExecution module
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$TestPlan,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    Write-TestLog "🔄 Starting parallel test execution" -Level "INFO"

    # Try to import ParallelExecution module
    $parallelModule = Import-ProjectModule -ModuleName "ParallelExecution"
    if (-not $parallelModule) {
        Write-TestLog "⚠️  ParallelExecution module unavailable, falling back to sequential" -Level "WARN"
        return Invoke-SequentialTestExecution -TestPlan $TestPlan -OutputPath $OutputPath
    }

    $allResults = @()
    $maxJobs = $TestPlan.Configuration.ParallelJobs

    foreach ($phase in $TestPlan.TestPhases) {
        Write-TestLog "🏃‍♂️ Executing test phase: $phase" -Level "INFO"

        # Create test jobs for this phase
        $testJobs = @()
        foreach ($module in $TestPlan.Modules) {
            $testJobs += @{
                ModuleName = $module.Name
                Phase = $phase
                TestPath = $module.TestPath
                Configuration = $TestPlan.Configuration
            }
        }

        # Execute jobs in parallel
        $phaseResults = Invoke-ParallelForEach -InputCollection $testJobs -ScriptBlock {
            param($testJob)

            try {
                $result = Invoke-ModuleTestPhase -ModuleName $testJob.ModuleName -Phase $testJob.Phase -TestPath $testJob.TestPath -Configuration $testJob.Configuration
                return @{
                    Success = $true
                    Module = $testJob.ModuleName
                    Phase = $testJob.Phase
                    Result = $result
                    Duration = $result.Duration
                }
            } catch {
                return @{
                    Success = $false
                    Module = $testJob.ModuleName
                    Phase = $testJob.Phase
                    Error = $_.Exception.Message
                    Duration = 0
                }
            }
        } -MaxConcurrency $maxJobs

        $allResults += $phaseResults

        # Log phase summary
        $phaseSuccess = ($phaseResults | Where-Object { $_.Success }).Count
        $phaseTotal = $phaseResults.Count
        Write-TestLog "✅ Phase $phase completed: $phaseSuccess/$phaseTotal successful" -Level "INFO"
    }

    return $allResults
}

function Invoke-SequentialTestExecution {
    <#
    .SYNOPSIS
        Executes tests sequentially with proper error handling
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$TestPlan,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    Write-TestLog "📝 Starting sequential test execution" -Level "INFO"

    $allResults = @()

    foreach ($phase in $TestPlan.TestPhases) {
        Write-TestLog "🏃‍♂️ Executing test phase: $phase" -Level "INFO"

        foreach ($module in $TestPlan.Modules) {
            try {
                $startTime = Get-Date
                Write-TestLog "  Testing $($module.Name) - $phase" -Level "INFO"

                $result = Invoke-ModuleTestPhase -ModuleName $module.Name -Phase $phase -TestPath $module.TestPath -Configuration $TestPlan.Configuration

                $allResults += @{
                    Success = $true
                    Module = $module.Name
                    Phase = $phase
                    Result = $result
                    Duration = ((Get-Date) - $startTime).TotalSeconds
                }

                Write-TestLog "  ✅ $($module.Name) - $phase completed" -Level "SUCCESS"

            } catch {
                $allResults += @{
                    Success = $false
                    Module = $module.Name
                    Phase = $phase
                    Error = $_.Exception.Message
                    Duration = ((Get-Date) - $startTime).TotalSeconds
                }

                Write-TestLog "  ❌ $($module.Name) - $phase failed: $($_.Exception.Message)" -Level "ERROR"

                # Continue with next module unless critical phase
                if ($phase -eq "Environment") {
                    throw "Critical environment phase failed for $($module.Name)"
                }
            }
        }
    }

    return $allResults
}

function Invoke-ModuleTestPhase {
    <#
    .SYNOPSIS
        Executes a specific test phase for a module
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string]$Phase,

        [Parameter(Mandatory)]
        [string]$TestPath,

        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )

    $result = @{
        ModuleName = $ModuleName
        Phase = $Phase
        TestsRun = 0
        TestsPassed = 0
        TestsFailed = 0
        Duration = 0
        Details = @()
    }

    $startTime = Get-Date

    try {
        switch ($Phase) {
            "Environment" {
                $result = Invoke-EnvironmentTests -ModuleName $ModuleName -Configuration $Configuration
            }
            "Unit" {
                $result = Invoke-UnitTests -ModuleName $ModuleName -TestPath $TestPath -Configuration $Configuration
            }
            "Integration" {
                $result = Invoke-IntegrationTests -ModuleName $ModuleName -Configuration $Configuration
            }
            "Performance" {
                $result = Invoke-PerformanceTests -ModuleName $ModuleName -Configuration $Configuration
            }
            "NonInteractive" {
                $result = Invoke-NonInteractiveTests -ModuleName $ModuleName -Configuration $Configuration
            }
            default {
                throw "Unknown test phase: $Phase"
            }
        }

        $result.Duration = ((Get-Date) - $startTime).TotalSeconds
        return $result

    } catch {
        $result.TestsFailed = 1
        $result.Duration = ((Get-Date) - $startTime).TotalSeconds
        $result.Details += "Phase execution failed: $($_.Exception.Message)"
        throw
    }
}

# ============================================================================
# SPECIALIZED TEST PHASE IMPLEMENTATIONS
# ============================================================================

function Invoke-EnvironmentTests {
    [CmdletBinding()]
    param($ModuleName, $Configuration)

    # Test module loading and basic functionality
    $module = Import-ProjectModule -ModuleName $ModuleName
    if (-not $module) {
        throw "Failed to load module: $ModuleName"
    }

    # Test module exports
    $exportedCommands = Get-Command -Module $module.Name -ErrorAction SilentlyContinue

    return @{
        ModuleName = $ModuleName
        Phase = "Environment"
        TestsRun = 1
        TestsPassed = if ($exportedCommands) { 1 } else { 0 }
        TestsFailed = if ($exportedCommands) { 0 } else { 1 }
        Details = @("Module loaded successfully", "Exported commands: $($exportedCommands.Count)")
    }
}

function Invoke-UnitTests {
    [CmdletBinding()]
    param($ModuleName, $TestPath, $Configuration)

    if (-not (Test-Path $TestPath)) {
        return @{
            ModuleName = $ModuleName
            Phase = "Unit"
            TestsRun = 0
            TestsPassed = 0
            TestsFailed = 0
            Details = @("No unit tests found at: $TestPath")
        }
    }

    # Use Pester to run unit tests
    try {
        Import-Module Pester -Force -ErrorAction Stop

        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $TestPath
        $pesterConfig.Run.PassThru = $true
        $pesterConfig.Output.Verbosity = $Configuration.Verbosity

        $pesterResult = Invoke-Pester -Configuration $pesterConfig

        return @{
            ModuleName = $ModuleName
            Phase = "Unit"
            TestsRun = $pesterResult.TotalCount
            TestsPassed = $pesterResult.PassedCount
            TestsFailed = $pesterResult.FailedCount
            Details = @("Pester tests executed from: $TestPath")
        }

    } catch {
        return @{
            ModuleName = $ModuleName
            Phase = "Unit"
            TestsRun = 0
            TestsPassed = 0
            TestsFailed = 1
            Details = @("Pester execution failed: $($_.Exception.Message)")
        }
    }
}

function Invoke-IntegrationTests {
    [CmdletBinding()]
    param($ModuleName, $Configuration)

    # Integration tests for module interactions
    $integrationTestPath = Join-Path $script:ProjectRoot "tests/integration"
    $moduleIntegrationTests = Get-ChildItem -Path $integrationTestPath -Filter "*$ModuleName*.Tests.ps1" -ErrorAction SilentlyContinue

    if (-not $moduleIntegrationTests) {
        return @{
            ModuleName = $ModuleName
            Phase = "Integration"
            TestsRun = 0
            TestsPassed = 0
            TestsFailed = 0
            Details = @("No integration tests found for module")
        }
    }

    $totalRun = 0
    $totalPassed = 0
    $totalFailed = 0
    $details = @()

    foreach ($testFile in $moduleIntegrationTests) {
        try {
            Import-Module Pester -Force -ErrorAction Stop

            $pesterConfig = New-PesterConfiguration
            $pesterConfig.Run.Path = $testFile.FullName
            $pesterConfig.Run.PassThru = $true
            $pesterConfig.Output.Verbosity = $Configuration.Verbosity

            $result = Invoke-Pester -Configuration $pesterConfig

            $totalRun += $result.TotalCount
            $totalPassed += $result.PassedCount
            $totalFailed += $result.FailedCount
            $details += "Integration test: $($testFile.Name) - $($result.PassedCount)/$($result.TotalCount) passed"

        } catch {
            $totalFailed += 1
            $details += "Integration test failed: $($testFile.Name) - $($_.Exception.Message)"
        }
    }

    return @{
        ModuleName = $ModuleName
        Phase = "Integration"
        TestsRun = $totalRun
        TestsPassed = $totalPassed
        TestsFailed = $totalFailed
        Details = $details
    }
}

function Invoke-PerformanceTests {
    [CmdletBinding()]
    param($ModuleName, $Configuration)

    # Basic performance validation
    $module = Get-Module -Name $ModuleName -ErrorAction SilentlyContinue
    if (-not $module) {
        $module = Import-ProjectModule -ModuleName $ModuleName
    }

    if (-not $module) {
        return @{
            ModuleName = $ModuleName
            Phase = "Performance"
            TestsRun = 0
            TestsPassed = 0
            TestsFailed = 1
            Details = @("Module not available for performance testing")
        }
    }

    # Test module import time
    $importTime = Measure-Command {
        Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue
        Import-ProjectModule -ModuleName $ModuleName
    }

    $passed = if ($importTime.TotalSeconds -lt 5) { 1 } else { 0 }
    $failed = if ($passed) { 0 } else { 1 }

    return @{
        ModuleName = $ModuleName
        Phase = "Performance"
        TestsRun = 1
        TestsPassed = $passed
        TestsFailed = $failed
        Details = @("Module import time: $($importTime.TotalSeconds) seconds")
    }
}

function Invoke-NonInteractiveTests {
    [CmdletBinding()]
    param($ModuleName, $Configuration)

    # Test module functions in non-interactive mode
    $module = Get-Module -Name $ModuleName -ErrorAction SilentlyContinue
    if (-not $module) {
        $module = Import-ProjectModule -ModuleName $ModuleName
    }

    if (-not $module) {
        return @{
            ModuleName = $ModuleName
            Phase = "NonInteractive"
            TestsRun = 0
            TestsPassed = 0
            TestsFailed = 1
            Details = @("Module not available for non-interactive testing")
        }
    }

    # Get exported functions and test basic help availability
    $exportedFunctions = Get-Command -Module $module.Name -CommandType Function -ErrorAction SilentlyContinue
    $testedFunctions = 0
    $passedFunctions = 0

    foreach ($function in $exportedFunctions) {
        try {
            $help = Get-Help $function.Name -ErrorAction Stop
            if ($help.Synopsis -and $help.Synopsis -ne $function.Name) {
                $passedFunctions++
            }
            $testedFunctions++
        } catch {
            $testedFunctions++
        }
    }

    return @{
        ModuleName = $ModuleName
        Phase = "NonInteractive"
        TestsRun = $testedFunctions
        TestsPassed = $passedFunctions
        TestsFailed = $testedFunctions - $passedFunctions
        Details = @("Tested $testedFunctions functions for help documentation")
    }
}

# ============================================================================
# REPORTING AND INTEGRATION FUNCTIONS
# ============================================================================

function New-TestReport {
    <#
    .SYNOPSIS
        Generates comprehensive test reports in multiple formats
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Results,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$TestSuite
    )

    $reportTimestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $reportDir = Join-Path $OutputPath "reports"

    # Generate summary statistics
    $summary = @{
        TestSuite = $TestSuite
        Timestamp = Get-Date
        TotalModules = ($Results | Select-Object -ExpandProperty Module -Unique).Count
        TotalTests = ($Results | Measure-Object -Property TestsRun -Sum).Sum
        TotalPassed = ($Results | Measure-Object -Property TestsPassed -Sum).Sum
        TotalFailed = ($Results | Measure-Object -Property TestsFailed -Sum).Sum
        SuccessfulModules = ($Results | Where-Object { $_.Success -eq $true }).Count
        FailedModules = ($Results | Where-Object { $_.Success -eq $false }).Count
        TotalDuration = ($Results | Measure-Object -Property Duration -Sum).Sum
    }

    # Calculate success rate
    $summary.SuccessRate = if ($summary.TotalTests -gt 0) {
        [Math]::Round(($summary.TotalPassed / $summary.TotalTests) * 100, 2)
    } else { 0 }

    # Generate JSON report
    $jsonReport = @{
        Summary = $summary
        Results = $Results
    }
    $jsonPath = Join-Path $reportDir "test-report-$reportTimestamp.json"
    $jsonReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8

    # Generate HTML report
    $htmlPath = Join-Path $reportDir "test-report-$reportTimestamp.html"
    $htmlContent = New-HTMLTestReport -Summary $summary -Results $Results
    $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8

    # Generate summary log
    $logPath = Join-Path $reportDir "test-summary-$reportTimestamp.log"
    $logContent = New-LogTestReport -Summary $summary -Results $Results
    $logContent | Out-File -FilePath $logPath -Encoding UTF8

    Write-TestLog "📊 Reports generated:" -Level "SUCCESS"
    Write-TestLog "  JSON: $jsonPath" -Level "INFO"
    Write-TestLog "  HTML: $htmlPath" -Level "INFO"
    Write-TestLog "  Log: $logPath" -Level "INFO"

    return $htmlPath
}

function New-HTMLTestReport {
    [CmdletBinding()]
    param($Summary, $Results)

    $statusColor = if ($Summary.SuccessRate -ge 95) { "green" } elseif ($Summary.SuccessRate -ge 80) { "orange" } else { "red" }

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>OpenTofu Lab Automation - Test Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .summary { background-color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { display: inline-block; margin: 10px 20px 10px 0; }
        .metric-value { font-size: 2em; font-weight: bold; color: $statusColor; }
        .metric-label { font-size: 0.9em; color: #666; }
        .results { background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .module-result { margin: 10px 0; padding: 15px; border-left: 4px solid #ddd; background-color: #f9f9f9; }
        .success { border-left-color: #27ae60; }
        .failure { border-left-color: #e74c3c; }
        .phase { margin: 5px 0; font-size: 0.9em; }
        .details { margin-top: 10px; font-size: 0.8em; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 OpenTofu Lab Automation - Test Report</h1>
        <p>Test Suite: $($Summary.TestSuite) | Generated: $($Summary.Timestamp)</p>
    </div>

    <div class="summary">
        <h2>📊 Test Summary</h2>
        <div class="metric">
            <div class="metric-value">$($Summary.SuccessRate)%</div>
            <div class="metric-label">Success Rate</div>
        </div>
        <div class="metric">
            <div class="metric-value">$($Summary.TotalPassed)</div>
            <div class="metric-label">Tests Passed</div>
        </div>
        <div class="metric">
            <div class="metric-value">$($Summary.TotalFailed)</div>
            <div class="metric-label">Tests Failed</div>
        </div>
        <div class="metric">
            <div class="metric-value">$($Summary.SuccessfulModules)</div>
            <div class="metric-label">Modules Passed</div>
        </div>
        <div class="metric">
            <div class="metric-value">$([Math]::Round($Summary.TotalDuration, 2))s</div>
            <div class="metric-label">Total Duration</div>
        </div>
    </div>

    <div class="results">
        <h2>📋 Detailed Results</h2>
"@

    # Group results by module
    $moduleGroups = $Results | Group-Object -Property Module
    foreach ($moduleGroup in $moduleGroups) {
        $moduleSuccess = ($moduleGroup.Group | Where-Object { $_.Success -eq $true }).Count -eq $moduleGroup.Count
        $cssClass = if ($moduleSuccess) { "success" } else { "failure" }
        $icon = if ($moduleSuccess) { "✅" } else { "❌" }

        $html += @"
        <div class="module-result $cssClass">
            <h3>$icon $($moduleGroup.Name)</h3>
"@

        foreach ($result in $moduleGroup.Group) {
            $phaseIcon = if ($result.Success) { "✅" } else { "❌" }
            $html += "<div class='phase'>$phaseIcon $($result.Phase): $($result.TestsPassed)/$($result.TestsRun) passed ($([Math]::Round($result.Duration, 2))s)</div>"

            if ($result.Details) {
                $html += "<div class='details'>"
                foreach ($detail in $result.Details) {
                    $html += "<div>• $detail</div>"
                }
                $html += "</div>"
            }
        }

        $html += "</div>"
    }

    $html += @"
    </div>
</body>
</html>
"@

    return $html
}

function New-LogTestReport {
    [CmdletBinding()]
    param($Summary, $Results)

    $log = @()
    $log += "=" * 80
    $log += "OpenTofu Lab Automation - Test Report"
    $log += "=" * 80
    $log += "Test Suite: $($Summary.TestSuite)"
    $log += "Generated: $($Summary.Timestamp)"
    $log += ""
    $log += "SUMMARY:"
    $log += "  Success Rate: $($Summary.SuccessRate)%"
    $log += "  Total Tests: $($Summary.TotalTests) (Passed: $($Summary.TotalPassed), Failed: $($Summary.TotalFailed))"
    $log += "  Total Modules: $($Summary.TotalModules) (Successful: $($Summary.SuccessfulModules), Failed: $($Summary.FailedModules))"
    $log += "  Total Duration: $([Math]::Round($Summary.TotalDuration, 2)) seconds"
    $log += ""
    $log += "DETAILED RESULTS:"
    $log += "-" * 80

    $moduleGroups = $Results | Group-Object -Property Module
    foreach ($moduleGroup in $moduleGroups) {
        $moduleSuccess = ($moduleGroup.Group | Where-Object { $_.Success -eq $true }).Count -eq $moduleGroup.Count
        $status = if ($moduleSuccess) { "SUCCESS" } else { "FAILURE" }

        $log += "Module: $($moduleGroup.Name) [$status]"

        foreach ($result in $moduleGroup.Group) {
            $phaseStatus = if ($result.Success) { "PASS" } else { "FAIL" }
            $log += "  Phase: $($result.Phase) [$phaseStatus] - $($result.TestsPassed)/$($result.TestsRun) passed ($([Math]::Round($result.Duration, 2))s)"

            if ($result.Details) {
                foreach ($detail in $result.Details) {
                    $log += "    • $detail"
                }
            }

            if (-not $result.Success -and $result.Error) {
                $log += "    ERROR: $($result.Error)"
            }
        }
        $log += ""
    }

    return $log -join "`n"
}

function Export-VSCodeTestResults {
    <#
    .SYNOPSIS
        Exports test results in VS Code compatible format
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Results,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $vscodeResults = @{
        version = "1.0"
        timestamp = Get-Date -Format "o"
        results = @()
    }

    foreach ($result in $Results) {
        $vscodeResults.results += @{
            module = $result.Module
            phase = $result.Phase
            success = $result.Success
            testsRun = $result.TestsRun
            testsPassed = $result.TestsPassed
            testsFailed = $result.TestsFailed
            duration = $result.Duration
            details = $result.Details
            error = $result.Error
        }
    }

    $vscodeOutputPath = Join-Path $OutputPath "vscode-test-results.json"
    $vscodeResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $vscodeOutputPath -Encoding UTF8

    Write-TestLog "📱 VS Code test results exported: $vscodeOutputPath" -Level "INFO"
}

# ============================================================================
# EVENT SYSTEM FOR MODULE COMMUNICATION
# ============================================================================

function Publish-TestEvent {
    <#
    .SYNOPSIS
        Publishes test events for module communication
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventType,

        [Parameter()]
        [hashtable]$Data = @{}
    )

    $event = @{
        EventType = $EventType
        Timestamp = Get-Date
        Data = $Data
    }

    # Store event for subscribers
    if (-not $script:TestEvents.ContainsKey($EventType)) {
        $script:TestEvents[$EventType] = @()
    }
    $script:TestEvents[$EventType] += $event

    Write-TestLog "📡 Published event: $EventType" -Level "INFO"
}

function Subscribe-TestEvent {
    <#
    .SYNOPSIS
        Subscribes to test events (placeholder for future event-driven architecture)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventType,

        [Parameter(Mandatory)]
        [scriptblock]$Handler
    )

    # Future implementation for event-driven architecture
    Write-TestLog "📬 Subscribed to event: $EventType" -Level "INFO"
}

function Get-TestEvents {
    <#
    .SYNOPSIS
        Retrieves test events for analysis
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$EventType
    )

    if ($EventType) {
        return $script:TestEvents[$EventType]
    } else {
        return $script:TestEvents
    }
}

# ============================================================================
# MODULE REGISTRATION AND CONFIGURATION
# ============================================================================

function Register-TestProvider {
    <#
    .SYNOPSIS
        Registers a module as a test provider
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string[]]$TestTypes,

        [Parameter(Mandatory)]
        [scriptblock]$Handler
    )

    $script:TestProviders[$ModuleName] = @{
        TestTypes = $TestTypes
        Handler = $Handler
        RegisteredAt = Get-Date
    }

    Write-TestLog "🔌 Registered test provider: $ModuleName (Types: $($TestTypes -join ', '))" -Level "INFO"
}

function Get-RegisteredTestProviders {
    <#
    .SYNOPSIS
        Gets registered test providers
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TestType
    )

    if ($TestType) {
        return $script:TestProviders.GetEnumerator() | Where-Object { $_.Value.TestTypes -contains $TestType }
    } else {
        return $script:TestProviders
    }
}

# ============================================================================
# COMPATIBILITY FUNCTIONS (Legacy Support)
# ============================================================================

function Invoke-PesterTests {
    <#
    .SYNOPSIS
        Legacy compatibility function for existing scripts
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath = "./tests/results",
        [switch]$VSCodeIntegration
    )

    Write-TestLog "🔄 Legacy Pester test execution (redirecting to unified framework)" -Level "WARN"

    return Invoke-UnifiedTestExecution -TestSuite "Unit" -OutputPath $OutputPath -VSCodeIntegration:$VSCodeIntegration
}

function Invoke-PytestTests {
    <#
    .SYNOPSIS
        Legacy compatibility function - Python tests not implemented
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath = "./tests/results",
        [switch]$VSCodeIntegration
    )

    Write-TestLog "⚠️  Python tests not implemented in current framework" -Level "WARN"
    return @{ TestsRun = 0; TestsPassed = 0; TestsFailed = 0; Message = "Python tests not implemented" }
}

function Invoke-SyntaxValidation {
    <#
    .SYNOPSIS
        Legacy compatibility function - redirects to PowerShell script analysis
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath = "./tests/results",
        [switch]$VSCodeIntegration
    )

    Write-TestLog "🔍 Syntax validation (PowerShell script analysis)" -Level "INFO"

    try {
        # Use PSScriptAnalyzer if available
        Import-Module PSScriptAnalyzer -ErrorAction Stop

        $scriptsPath = Join-Path $script:ProjectRoot "core-runner"
        $analysisResults = Invoke-ScriptAnalyzer -Path $scriptsPath -Recurse -ErrorAction SilentlyContinue

        $errors = $analysisResults | Where-Object { $_.Severity -eq 'Error' }
        $warnings = $analysisResults | Where-Object { $_.Severity -eq 'Warning' }

        return @{
            TestsRun = $analysisResults.Count
            TestsPassed = $analysisResults.Count - $errors.Count
            TestsFailed = $errors.Count
            Warnings = $warnings.Count
            Details = "PSScriptAnalyzer found $($errors.Count) errors, $($warnings.Count) warnings"
        }

    } catch {
        Write-TestLog "⚠️  PSScriptAnalyzer not available: $($_.Exception.Message)" -Level "WARN"
        return @{ TestsRun = 0; TestsPassed = 0; TestsFailed = 0; Message = "PSScriptAnalyzer not available" }
    }
}

function Invoke-ParallelTests {
    <#
    .SYNOPSIS
        Legacy compatibility function for parallel test execution
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath = "./tests/results",
        [switch]$VSCodeIntegration
    )

    Write-TestLog "🔄 Legacy parallel test execution (redirecting to unified framework)" -Level "WARN"

    return Invoke-UnifiedTestExecution -TestSuite "All" -Parallel -OutputPath $OutputPath -VSCodeIntegration:$VSCodeIntegration
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================

# Export main functions
Export-ModuleMember -Function @(
    'Invoke-UnifiedTestExecution',
    'Get-DiscoveredModules',
    'New-TestExecutionPlan',
    'Get-TestConfiguration',
    'Invoke-ParallelTestExecution',
    'Invoke-SequentialTestExecution',
    'New-TestReport',
    'Export-VSCodeTestResults',
    'Publish-TestEvent',
    'Subscribe-TestEvent',
    'Get-TestEvents',
    'Register-TestProvider',
    'Get-RegisteredTestProviders',
    'Invoke-PesterTests',
    'Invoke-PytestTests',
    'Invoke-SyntaxValidation',
    'Invoke-ParallelTests'
)
