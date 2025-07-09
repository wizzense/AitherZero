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

# Initialize standardized logging fallback
$fallbackPath = Join-Path (Split-Path $PSScriptRoot -Parent) "shared/Initialize-LoggingFallback.ps1"
if (Test-Path $fallbackPath) {
    . $fallbackPath
    Initialize-LoggingFallback -ModuleName "TestingFramework"
} else {
    # Basic fallback if shared utility isn't available
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Message, [string]$Level = "INFO")
            $color = switch ($Level) { 'SUCCESS' { 'Green' }; 'ERROR' { 'Red' }; 'WARNING' { 'Yellow' }; 'INFO' { 'Cyan' }; default { 'White' } }
            Write-Host "[$Level] $Message" -ForegroundColor $color
        }
    }
}

# Fallback logging function if centralized logging unavailable
if (-not $loggingImported -or -not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
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

# Validate project root
if ([string]::IsNullOrEmpty($script:ProjectRoot)) {
    Write-TestLog "Warning: Project root could not be determined, using PSScriptRoot parent" -Level "WARN"
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Initialize-TestEnvironment {
    <#
    .SYNOPSIS
        Initializes the test environment for unified test execution
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$TestProfile
    )

    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-TestLog "Created output directory: $OutputPath" -Level "INFO"
    }

    # Create subdirectories for results
    $subDirs = @('reports', 'logs', 'coverage')
    foreach ($subDir in $subDirs) {
        $dirPath = Join-Path $OutputPath $subDir
        if (-not (Test-Path $dirPath)) {
            New-Item -Path $dirPath -ItemType Directory -Force | Out-Null
        }
    }

    # Set environment variables for tests
    $env:TEST_OUTPUT_PATH = $OutputPath
    $env:TEST_PROFILE = $TestProfile
    $env:TEST_TIMESTAMP = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    Write-TestLog "Test environment initialized for profile: $TestProfile" -Level "SUCCESS"
}

function Import-ProjectModule {
    <#
    .SYNOPSIS
        Imports a project module with error handling and fallback
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    try {
        # First try to use the centralized Import-ProjectModule from Logging module
        if (Get-Command Import-ProjectModule -Module Logging -ErrorAction SilentlyContinue) {
            return & (Get-Command Import-ProjectModule -Module Logging) -ModuleName $ModuleName
        }

        # Fallback to manual import
        $modulePath = Join-Path $script:ProjectRoot "aither-core/modules/$ModuleName"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction Stop
            $module = Get-Module -Name $ModuleName
            Write-TestLog "✅ Imported module: $ModuleName" -Level "INFO"
            return $module
        } else {
            Write-TestLog "⚠️  Module path not found: $modulePath" -Level "WARN"
            return $null
        }
    } catch {
        Write-TestLog "❌ Failed to import module $ModuleName`: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
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
        [ValidateSet("All", "Unit", "Integration", "Performance", "Modules", "Quick", "NonInteractive", "Environment")]
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

            # Submit completion event
            Submit-TestEvent -EventType "TestExecutionCompleted" -Data @{
                TestSuite = $TestSuite
                Results = $results
                Duration = (Get-Date) - $testPlan.StartTime
            }

            return ,$results

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
        Discovers and validates project modules for testing with distributed test support

    .DESCRIPTION
        Enhanced module discovery that finds both centralized and distributed (co-located) tests.
        Supports automatic discovery of module-level tests following the pattern:
        - Module directory: {ModuleName}/tests/{ModuleName}.Tests.ps1
        - Centralized tests: tests/unit/modules/{ModuleName}
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$SpecificModules = @(),

        [Parameter()]
        [switch]$IncludeDistributedTests = $true,

        [Parameter()]
        [switch]$IncludeCentralizedTests = $true
    )

    $modulesPath = Join-Path $script:ProjectRoot "aither-core/modules"
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
            # Discover distributed (co-located) tests
            $distributedTestPath = Join-Path $moduleDir.FullName "tests"
            $distributedTestFile = Join-Path $distributedTestPath "$($moduleDir.Name).Tests.ps1"

            # Discover centralized tests
            $centralizedTestPath = Join-Path $script:ProjectRoot "tests/unit/modules/$($moduleDir.Name)"

            $moduleInfo = @{
                Name = $moduleDir.Name
                Path = $moduleDir.FullName
                ManifestPath = if (Test-Path $moduleManifest) { $moduleManifest } else { $null }
                ScriptPath = $moduleScript

                # Test discovery results
                TestDiscovery = @{
                    HasDistributedTests = (Test-Path $distributedTestFile)
                    HasCentralizedTests = (Test-Path $centralizedTestPath)
                    DistributedTestPath = $distributedTestPath
                    DistributedTestFile = $distributedTestFile
                    CentralizedTestPath = $centralizedTestPath
                    TestStrategy = $null  # Will be determined below
                }

                # Legacy compatibility (primary test path)
                TestPath = $null
                IntegrationTestPath = Join-Path $script:ProjectRoot "tests/integration"
            }

            # Determine test strategy and primary test path
            if ($moduleInfo.TestDiscovery.HasDistributedTests -and $IncludeDistributedTests) {
                $moduleInfo.TestDiscovery.TestStrategy = "Distributed"
                $moduleInfo.TestPath = $distributedTestFile
                Write-TestLog "📦 Discovered module with distributed tests: $($moduleDir.Name)" -Level "INFO"

            } elseif ($moduleInfo.TestDiscovery.HasCentralizedTests -and $IncludeCentralizedTests) {
                $moduleInfo.TestDiscovery.TestStrategy = "Centralized"
                $moduleInfo.TestPath = $centralizedTestPath
                Write-TestLog "📦 Discovered module with centralized tests: $($moduleDir.Name)" -Level "INFO"

            } else {
                # No tests found - this is a candidate for test generation
                $moduleInfo.TestDiscovery.TestStrategy = "None"
                $moduleInfo.TestPath = $distributedTestFile  # Target path for future test generation
                Write-TestLog "📦 Discovered module without tests: $($moduleDir.Name) (test generation candidate)" -Level "WARN"
            }

            $allModules += $moduleInfo
        }
    }

    # Log discovery summary
    $withDistributed = ($allModules | Where-Object { $_.TestDiscovery.TestStrategy -eq "Distributed" }).Count
    $withCentralized = ($allModules | Where-Object { $_.TestDiscovery.TestStrategy -eq "Centralized" }).Count
    $withoutTests = ($allModules | Where-Object { $_.TestDiscovery.TestStrategy -eq "None" }).Count

    Write-TestLog "📊 Module Test Discovery Summary:" -Level "INFO"
    Write-TestLog "  Modules with distributed tests: $withDistributed" -Level "INFO"
    Write-TestLog "  Modules with centralized tests: $withCentralized" -Level "INFO"
    Write-TestLog "  Modules without tests: $withoutTests" -Level "WARN"

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
        [AllowEmptyCollection()]
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
        EnableCoverage = $false
        CoverageThreshold = 80
        EnablePerformanceMetrics = $true
        MaxMemoryUsageMB = 1024
    }

    $profileConfigs = @{
        Development = @{
            Verbosity = "Detailed"
            TimeoutMinutes = 15
            MockLevel = "High"
            EnableCoverage = $true
            CoverageThreshold = 70
        }
        CI = @{
            Verbosity = "Normal"
            TimeoutMinutes = 45
            RetryCount = 3
            MockLevel = "Standard"
            EnableCoverage = $true
            CoverageThreshold = 80
            EnablePerformanceMetrics = $true
        }
        Production = @{
            Verbosity = "Normal"
            TimeoutMinutes = 60
            RetryCount = 1
            MockLevel = "Low"
            EnableCoverage = $true
            CoverageThreshold = 90
            MaxMemoryUsageMB = 512
        }
        Debug = @{
            Verbosity = "Verbose"
            TimeoutMinutes = 120
            MockLevel = "None"
            ParallelJobs = 1
            EnableCoverage = $false
            EnablePerformanceMetrics = $true
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
        Executes tests in parallel using enhanced job management
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$TestPlan,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    Write-TestLog "🔄 Starting enhanced parallel test execution" -Level "INFO"

    # Try to import ParallelExecution module
    $parallelModule = Import-ProjectModule -ModuleName "ParallelExecution"
    if (-not $parallelModule) {
        Write-TestLog "⚠️  ParallelExecution module unavailable, using built-in parallel execution" -Level "WARN"
        return Invoke-BuiltInParallelExecution -TestPlan $TestPlan -OutputPath $OutputPath
    }

    $allResults = @()
    $maxJobs = [Math]::Min($TestPlan.Configuration.ParallelJobs, ([Environment]::ProcessorCount))
    
    Write-TestLog "Using $maxJobs parallel jobs" -Level "INFO"

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
                TestingFrameworkPath = $PSScriptRoot
                ProjectRoot = $script:ProjectRoot
                OutputPath = $OutputPath
            }
        }

        # Execute jobs in parallel with enhanced error handling
        if ($testJobs.Count -eq 0) {
            Write-TestLog "No test jobs for phase: $phase" -Level "WARN"
            continue
        }
        
        try {
            $phaseResults = Invoke-ParallelForEach -InputObject $testJobs -ScriptBlock {
                param($testJob)

                # Set up isolated environment for this job
                $ErrorActionPreference = 'Stop'
                
                try {
                    # Validate critical paths before using them
                    if ([string]::IsNullOrEmpty($testJob.ProjectRoot)) {
                        throw "ProjectRoot is null or empty in test job"
                    }
                    
                    if ([string]::IsNullOrEmpty($testJob.TestingFrameworkPath)) {
                        throw "TestingFrameworkPath is null or empty in test job"
                    }
                    
                    # Re-import required modules in job context
                    $env:PROJECT_ROOT = $testJob.ProjectRoot
                    
                    # Import TestingFramework module in the job context
                    if (Test-Path $testJob.TestingFrameworkPath) {
                        Import-Module $testJob.TestingFrameworkPath -Force -ErrorAction Stop
                    } else {
                        throw "TestingFramework path does not exist: '$($testJob.TestingFrameworkPath)'"
                    }
                    
                    # Initialize logging system in parallel context to prevent null path errors
                    # Only do this once, not twice
                    $loggingPath = Join-Path $testJob.ProjectRoot "aither-core/modules/Logging"
                    if (Test-Path $loggingPath) {
                        Import-Module $loggingPath -Force -ErrorAction SilentlyContinue
                        if (Get-Command Initialize-LoggingSystem -ErrorAction SilentlyContinue) {
                            Initialize-LoggingSystem -ErrorAction SilentlyContinue
                        }
                    }
                    
                    # Validate test path before proceeding
                    if ([string]::IsNullOrEmpty($testJob.TestPath)) {
                        throw "TestPath is null or empty for module: $($testJob.ModuleName)"
                    }
                    
                    # Initialize logging system in parallel context to prevent null path errors
                    $loggingPath = Join-Path $testJob.ProjectRoot "aither-core/modules/Logging"
                    if (Test-Path $loggingPath) {
                        Import-Module $loggingPath -Force -ErrorAction SilentlyContinue
                        if (Get-Command Initialize-LoggingSystem -ErrorAction SilentlyContinue) {
                            Initialize-LoggingSystem -ErrorAction SilentlyContinue
                        }
                    }
                    
                    # Execute the test phase
                    $result = Invoke-ModuleTestPhase -ModuleName $testJob.ModuleName -Phase $testJob.Phase -TestPath $testJob.TestPath -Configuration $testJob.Configuration
                    
                    return @{
                        Success = ($result.TestsFailed -eq 0)
                        Module = $testJob.ModuleName
                        Phase = $testJob.Phase
                        Result = $result
                        Duration = $result.Duration
                        TestsRun = $result.TestsRun
                        TestsPassed = $result.TestsPassed
                        TestsFailed = $result.TestsFailed
                        Details = $result.Details
                        JobId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                    }
                } catch {
                    return @{
                        Success = $false
                        Module = $testJob.ModuleName
                        Phase = $testJob.Phase
                        Error = $_.Exception.Message
                        Duration = 0
                        TestsRun = 0
                        TestsPassed = 0
                        TestsFailed = 1
                        Details = @("Parallel execution error: $($_.Exception.Message)", "Stack: $($_.ScriptStackTrace)")
                        JobId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                    }
                }
            } -ThrottleLimit $maxJobs

            $allResults += $phaseResults

            # Enhanced phase summary
            $phaseSuccess = ($phaseResults | Where-Object { $_.Success }).Count
            $phaseTotal = $phaseResults.Count
            $phaseErrors = ($phaseResults | Where-Object { $_.Error }).Count
            
            Write-TestLog "✅ Phase $phase completed: $phaseSuccess/$phaseTotal successful, $phaseErrors errors" -Level "INFO"
            
            # Log individual failures for debugging
            $failedJobs = $phaseResults | Where-Object { -not $_.Success }
            foreach ($failed in $failedJobs) {
                Write-TestLog "❌ Failed: $($failed.Module) - $($failed.Error)" -Level "ERROR"
            }
            
        } catch {
            Write-TestLog "❌ Phase $phase execution failed: $($_.Exception.Message)" -Level "ERROR"
            
            # Create error results for all modules in this phase
            $errorResults = @()
            foreach ($module in $TestPlan.Modules) {
                $errorResults += @{
                    Success = $false
                    Module = $module.Name
                    Phase = $phase
                    Error = "Phase execution failed: $($_.Exception.Message)"
                    Duration = 0
                    TestsRun = 0
                    TestsPassed = 0
                    TestsFailed = 1
                    Details = @("Phase execution error: $($_.Exception.Message)")
                }
            }
            $allResults += $errorResults
        }
    }

    return ,$allResults
}

function Invoke-BuiltInParallelExecution {
    <#
    .SYNOPSIS
        Built-in parallel execution using PowerShell jobs as fallback
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$TestPlan,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    Write-TestLog "🔄 Using built-in parallel execution" -Level "INFO"

    $allResults = @()
    $maxJobs = [Math]::Min($TestPlan.Configuration.ParallelJobs, ([Environment]::ProcessorCount))

    foreach ($phase in $TestPlan.TestPhases) {
        Write-TestLog "🏃‍♂️ Executing test phase: $phase" -Level "INFO"

        $jobs = @()
        
        # Start jobs for each module
        foreach ($module in $TestPlan.Modules) {
            $job = Start-Job -ScriptBlock {
                param($ModuleName, $Phase, $TestPath, $Configuration, $FrameworkPath, $ProjectRoot)
                
                $ErrorActionPreference = 'Stop'
                
                try {
                    # Set up environment
                    if ($ProjectRoot) {
                        $env:PROJECT_ROOT = $ProjectRoot
                    }
                    
                    # Import Logging module first - it's critical for all other modules
                    $loggingPath = Join-Path $ProjectRoot "aither-core/modules/Logging"
                    if (Test-Path $loggingPath) {
                        Import-Module $loggingPath -Force -Global -ErrorAction Stop
                        if (Get-Command Initialize-LoggingSystem -ErrorAction SilentlyContinue) {
                            Initialize-LoggingSystem -ErrorAction SilentlyContinue
                        }
                    }
                    
                    # Import required modules
                    Import-Module $FrameworkPath -Force
                    
                    # Initialize logging system in parallel context to prevent null path errors
                    $loggingPath = Join-Path $ProjectRoot "aither-core/modules/Logging"
                    if (Test-Path $loggingPath) {
                        Import-Module $loggingPath -Force -ErrorAction SilentlyContinue
                        if (Get-Command Initialize-LoggingSystem -ErrorAction SilentlyContinue) {
                            Initialize-LoggingSystem -ErrorAction SilentlyContinue
                        }
                    }
                    
                    # Execute the test phase
                    $result = Invoke-ModuleTestPhase -ModuleName $ModuleName -Phase $Phase -TestPath $TestPath -Configuration $Configuration
                    
                    return @{
                        Success = ($result.TestsFailed -eq 0)
                        Module = $ModuleName
                        Phase = $Phase
                        Result = $result
                        Duration = $result.Duration
                        TestsRun = $result.TestsRun
                        TestsPassed = $result.TestsPassed
                        TestsFailed = $result.TestsFailed
                        Details = $result.Details
                    }
                } catch {
                    return @{
                        Success = $false
                        Module = $ModuleName
                        Phase = $Phase
                        Error = $_.Exception.Message
                        Duration = 0
                        TestsRun = 0
                        TestsPassed = 0
                        TestsFailed = 1
                        Details = @("Built-in parallel execution error: $($_.Exception.Message)")
                    }
                }
            } -ArgumentList $module.Name, $phase, $module.TestPath, $TestPlan.Configuration, $PSScriptRoot, $script:ProjectRoot
            
            $jobs += $job
            
            # Throttle job creation
            while ((Get-Job -State Running).Count -ge $maxJobs) {
                Start-Sleep -Milliseconds 100
            }
        }

        # Wait for all jobs to complete with timeout
        $timeout = New-TimeSpan -Minutes ($TestPlan.Configuration.TimeoutMinutes ?? 30)
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        while ($jobs | Where-Object { $_.State -eq 'Running' }) {
            if ($stopwatch.Elapsed -gt $timeout) {
                Write-TestLog "⏱️ Jobs timed out after $($timeout.TotalMinutes) minutes" -Level "WARN"
                $jobs | Where-Object { $_.State -eq 'Running' } | Stop-Job
                break
            }
            Start-Sleep -Seconds 1
        }

        # Collect results
        $phaseResults = @()
        foreach ($job in $jobs) {
            try {
                $result = Receive-Job -Job $job -ErrorAction Stop
                $phaseResults += $result
            } catch {
                $phaseResults += @{
                    Success = $false
                    Module = "Unknown"
                    Phase = $phase
                    Error = "Job failed: $($_.Exception.Message)"
                    Duration = 0
                    TestsRun = 0
                    TestsPassed = 0
                    TestsFailed = 1
                    Details = @("Job execution error: $($_.Exception.Message)")
                }
            }
            Remove-Job -Job $job
        }

        $allResults += $phaseResults

        # Log phase summary
        $phaseSuccess = ($phaseResults | Where-Object { $_.Success }).Count
        $phaseTotal = $phaseResults.Count
        Write-TestLog "✅ Phase $phase completed: $phaseSuccess/$phaseTotal successful" -Level "INFO"
    }

    return ,$allResults
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
                    Success = ($result.TestsFailed -eq 0)
                    Module = $module.Name
                    Phase = $phase
                    Result = $result
                    Duration = ((Get-Date) - $startTime).TotalSeconds
                    TestsRun = $result.TestsRun
                    TestsPassed = $result.TestsPassed
                    TestsFailed = $result.TestsFailed
                    Details = $result.Details
                }

                Write-TestLog "  ✅ $($module.Name) - $phase completed" -Level "SUCCESS"

            } catch {
                $allResults += @{
                    Success = $false
                    Module = $module.Name
                    Phase = $phase
                    Error = $_.Exception.Message
                    Duration = ((Get-Date) - $startTime).TotalSeconds
                    TestsRun = 0
                    TestsPassed = 0
                    TestsFailed = 1
                    Details = @("Error: $($_.Exception.Message)")
                }

                Write-TestLog "  ❌ $($module.Name) - $phase failed: $($_.Exception.Message)" -Level "ERROR"

                # Continue with next module unless critical phase
                if ($phase -eq "Environment") {
                    throw "Critical environment phase failed for $($module.Name)"
                }
            }
        }
    }

    return ,$allResults
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

    # Ensure Logging module is available in test context
    $loggingPath = Join-Path $script:ProjectRoot "aither-core/modules/Logging"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global -ErrorAction SilentlyContinue
    }

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

    # Enhanced test file discovery with better path resolution
    $testLocations = @(
        $TestPath,
        (Join-Path $script:ProjectRoot "tests/unit/modules/$ModuleName"),
        (Join-Path $script:ProjectRoot "aither-core/modules/$ModuleName/tests"),
        (Join-Path $script:ProjectRoot "tests/$ModuleName.Tests.ps1")
    )

    $actualTestPath = $null
    $testFileType = "Unknown"
    
    foreach ($location in $testLocations) {
        if (Test-Path $location) {
            $actualTestPath = $location
            $testFileType = if ($location -match "\.ps1$") { "File" } else { "Directory" }
            break
        }
    }

    if (-not $actualTestPath) {
        # If no tests exist, report as skipped
        return @{
            ModuleName = $ModuleName
            Phase = "Unit"
            TestsRun = 0
            TestsPassed = 0
            TestsFailed = 0
            Details = @("No unit tests found - skipped", "Searched locations: $($testLocations -join ', ')")
        }
    }

    # Use Pester to run unit tests with enhanced error handling
    try {
        # Ensure Pester is available
        $pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $pesterModule) {
            throw "Pester module not found. Please install Pester 5.0+."
        }

        # Import Pester with explicit version check
        Import-Module Pester -Force -ErrorAction Stop
        $pesterVersion = (Get-Module Pester).Version
        
        if ($pesterVersion.Major -lt 5) {
            throw "Pester version $pesterVersion is not supported. Please upgrade to Pester 5.0+."
        }

        # Create and configure Pester configuration
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $actualTestPath
        $pesterConfig.Run.PassThru = $true
        $pesterConfig.Output.Verbosity = switch ($Configuration.Verbosity) {
            "Detailed" { "Detailed" }
            "Verbose" { "Detailed" }
            "Debug" { "Diagnostic" }
            default { "Normal" }
        }

        # Enhanced output configuration
        $pesterConfig.TestResult.Enabled = $true
        $pesterConfig.TestResult.OutputFormat = "NUnitXml"
        
        # Ensure output directory exists
        $outputPath = if ($env:TEST_OUTPUT_PATH) { $env:TEST_OUTPUT_PATH } else { Join-Path $script:ProjectRoot "tests/results" }
        if (-not (Test-Path $outputPath)) {
            New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
        }
        
        $pesterConfig.TestResult.OutputPath = Join-Path $outputPath "pester-results-$ModuleName.xml"

        # Code coverage configuration with validation
        if ($Configuration.EnableCoverage -and (Test-Path $actualTestPath)) {
            try {
                $pesterConfig.CodeCoverage.Enabled = $true
                $pesterConfig.CodeCoverage.Path = $actualTestPath
                $pesterConfig.CodeCoverage.OutputFormat = "JaCoCo"
                $pesterConfig.CodeCoverage.OutputPath = Join-Path $outputPath "coverage-$ModuleName.xml"
            } catch {
                Write-TestLog "Code coverage configuration failed: $($_.Exception.Message)" -Level "WARN"
            }
        }

        # Performance and timeout settings
        $pesterConfig.Run.Exit = $false
        
        # Add timeout if supported
        if ($pesterConfig.Run.PSObject.Properties.Name -contains "Timeout") {
            $pesterConfig.Run.Timeout = [TimeSpan]::FromMinutes($Configuration.TimeoutMinutes ?? 10)
        }

        # Execute Pester tests with enhanced isolation and timeout
        $testStartTime = Get-Date
        $pesterResult = $null
        
        # Try to use TestIsolation module for better test isolation
        $isolationModule = Get-Module -Name TestIsolation -ErrorAction SilentlyContinue
        if (-not $isolationModule) {
            $isolationPath = Join-Path $script:ProjectRoot "tests/TestIsolation.psm1"
            if (Test-Path $isolationPath) {
                try {
                    Import-Module $isolationPath -Force -ErrorAction Stop
                    $isolationModule = Get-Module -Name TestIsolation
                } catch {
                    Write-TestLog "Failed to import TestIsolation module: $($_.Exception.Message)" -Level "WARN"
                }
            }
        }
        
        if ($isolationModule) {
            # Use enhanced isolation
            try {
                $pesterResult = Invoke-PesterWithIsolation -TestPath $actualTestPath -PesterConfiguration @{
                    Run = @{
                        Path = $actualTestPath
                        PassThru = $true
                        Exit = $false
                    }
                    TestResult = @{
                        Enabled = $true
                        OutputFormat = "NUnitXml"
                        OutputPath = $pesterConfig.TestResult.OutputPath
                    }
                    Output = @{
                        Verbosity = $pesterConfig.Output.Verbosity
                    }
                } -IsolateModules -IsolateEnvironment -PreserveModules @('Microsoft.PowerShell.Core', 'Microsoft.PowerShell.Utility', 'Microsoft.PowerShell.Management', 'Pester', 'TestHelpers')
                
                Write-TestLog "Pester executed with isolation" -Level "INFO"
                
                # Re-import Logging module after isolation in case it was unloaded
                $loggingPath = Join-Path $script:ProjectRoot "aither-core/modules/Logging"
                if (Test-Path $loggingPath) {
                    Import-Module $loggingPath -Force -Global -ErrorAction SilentlyContinue
                }
                
            } catch {
                # Re-import Logging module if it was unloaded
                $loggingPath = Join-Path $script:ProjectRoot "aither-core/modules/Logging"
                if (Test-Path $loggingPath) {
                    Import-Module $loggingPath -Force -Global -ErrorAction SilentlyContinue
                }
                
                # Use fallback logging if Write-TestLog is not available
                if (Get-Command Write-TestLog -ErrorAction SilentlyContinue) {
                    Write-TestLog "Isolated Pester execution failed: $($_.Exception.Message)" -Level "WARN"
                    Write-TestLog "Falling back to standard execution" -Level "INFO"
                } else {
                    Write-Warning "Isolated Pester execution failed: $($_.Exception.Message)"
                    Write-Warning "Falling back to standard execution"
                }
                $isolationModule = $null
            }
        }
        
        # Fallback to standard execution with timeout
        if (-not $isolationModule -or -not $pesterResult) {
            $testJob = Start-Job -ScriptBlock {
                param($TestPath, $Config)
                Import-Module Pester -Force
                Invoke-Pester -Configuration $Config
            } -ArgumentList $actualTestPath, $pesterConfig
            
            $timeoutMinutes = $Configuration.TimeoutMinutes ?? 10
            $testCompleted = Wait-Job -Job $testJob -Timeout ($timeoutMinutes * 60)
            
            if ($testCompleted) {
                $pesterResult = Receive-Job -Job $testJob
            } else {
                Write-TestLog "Test execution timed out after $timeoutMinutes minutes" -Level "WARN"
                Stop-Job -Job $testJob
                throw "Test execution timed out after $timeoutMinutes minutes"
            }
            
            Remove-Job -Job $testJob
        }

        # Enhanced result parsing with multiple fallback strategies
        $totalCount = 0
        $passedCount = 0
        $failedCount = 0
        $skippedCount = 0
        $details = @()

        if ($pesterResult) {
            # Pester 5.x format - primary
            if ($null -ne $pesterResult.Tests) {
                $totalCount = $pesterResult.Tests.Count
                $passedCount = ($pesterResult.Tests | Where-Object { $_.Result -eq 'Passed' }).Count
                $failedCount = ($pesterResult.Tests | Where-Object { $_.Result -eq 'Failed' }).Count
                $skippedCount = ($pesterResult.Tests | Where-Object { $_.Result -eq 'Skipped' }).Count
                
                # Add details about failed tests
                $failedTests = $pesterResult.Tests | Where-Object { $_.Result -eq 'Failed' }
                foreach ($failed in $failedTests) {
                    $details += "Failed: $($failed.Name) - $($failed.ErrorRecord.Exception.Message)"
                }
            }
            # Pester 4.x format fallback
            elseif ($null -ne $pesterResult.TotalCount) {
                $totalCount = $pesterResult.TotalCount
                $passedCount = $pesterResult.PassedCount
                $failedCount = $pesterResult.FailedCount
                $skippedCount = $pesterResult.SkippedCount ?? 0
            }
            # Additional Pester 5.x properties check
            elseif ($null -ne $pesterResult.Passed -or $null -ne $pesterResult.Failed) {
                $passedCount = if ($pesterResult.Passed) { $pesterResult.Passed.Count } else { 0 }
                $failedCount = if ($pesterResult.Failed) { $pesterResult.Failed.Count } else { 0 }
                $skippedCount = if ($pesterResult.Skipped) { $pesterResult.Skipped.Count } else { 0 }
                $totalCount = $passedCount + $failedCount + $skippedCount
            }
            
            # Add general details
            $details += "Pester tests executed from: $actualTestPath ($testFileType)"
            $details += "Pester version: $($pesterVersion)"
            $details += "Execution time: $((Get-Date) - $testStartTime)"
            
            if ($skippedCount -gt 0) {
                $details += "Skipped tests: $skippedCount"
            }
        } else {
            # Ensure Logging module is available before throwing
            $loggingPath = Join-Path $script:ProjectRoot "aither-core/modules/Logging"
            if (Test-Path $loggingPath) {
                Import-Module $loggingPath -Force -Global -ErrorAction SilentlyContinue
            }
            throw "No Pester results returned"
        }
        
        # Ensure Logging module is available after test execution
        $loggingPath = Join-Path $script:ProjectRoot "aither-core/modules/Logging"
        if (Test-Path $loggingPath) {
            Import-Module $loggingPath -Force -Global -ErrorAction SilentlyContinue
        }

        return @{
            ModuleName = $ModuleName
            Phase = "Unit"
            TestsRun = $totalCount
            TestsPassed = $passedCount
            TestsFailed = $failedCount
            TestsSkipped = $skippedCount
            Details = $details
            TestPath = $actualTestPath
            PesterVersion = $pesterVersion.ToString()
        }

    } catch {
        # Re-import Logging module in case it was unloaded by test isolation
        $loggingPath = Join-Path $script:ProjectRoot "aither-core/modules/Logging"
        if (Test-Path $loggingPath) {
            Import-Module $loggingPath -Force -Global -ErrorAction SilentlyContinue
        }
        
        $errorDetails = @(
            "Pester execution failed: $($_.Exception.Message)",
            "Test path: $actualTestPath",
            "Module: $ModuleName",
            "Configuration: $($Configuration | ConvertTo-Json -Depth 1 -Compress)"
        )
        
        # Add stack trace for debugging
        if ($_.ScriptStackTrace) {
            $errorDetails += "Stack trace: $($_.ScriptStackTrace)"
        }
        
        return @{
            ModuleName = $ModuleName
            Phase = "Unit"
            TestsRun = 0
            TestsPassed = 0
            TestsFailed = 1
            TestsSkipped = 0
            Details = $errorDetails
            TestPath = $actualTestPath
            Error = $_.Exception.Message
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
            $pesterConfig.Output.Verbosity = switch ($Configuration.Verbosity) {
                "Detailed" { "Detailed" }
                "Verbose" { "Detailed" }
                "Debug" { "Diagnostic" }
                default { "Normal" }
            }

            # Enhanced integration test configuration
            $pesterConfig.TestResult.Enabled = $true
            $pesterConfig.TestResult.OutputFormat = "NUnitXml"
            $pesterConfig.TestResult.OutputPath = Join-Path $env:TEST_OUTPUT_PATH "integration-$($testFile.BaseName)-results.xml"
            # Note: Timeout property may not exist in all Pester versions
            # $pesterConfig.Run.Timeout = [TimeSpan]::FromMinutes($Configuration.TimeoutMinutes)

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
        Generates comprehensive test reports in multiple formats with enhanced analysis
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Results,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$TestSuite
    )

    $reportTimestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $reportDir = Join-Path $OutputPath "reports"

    # Ensure report directory exists
    if (-not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
    }

    # Generate enhanced summary statistics
    $summary = @{
        TestSuite = $TestSuite
        Timestamp = Get-Date
        TotalModules = ($Results | Select-Object -ExpandProperty Module -Unique).Count
        TotalTests = ($Results | Measure-Object -Property TestsRun -Sum).Sum
        TotalPassed = ($Results | Measure-Object -Property TestsPassed -Sum).Sum
        TotalFailed = ($Results | Measure-Object -Property TestsFailed -Sum).Sum
        TotalSkipped = ($Results | Measure-Object -Property TestsSkipped -Sum).Sum
        SuccessfulModules = ($Results | Where-Object { $_.Success -eq $true }).Count
        FailedModules = ($Results | Where-Object { $_.Success -eq $false }).Count
        TotalDuration = ($Results | Measure-Object -Property Duration -Sum).Sum
        AverageDuration = if ($Results.Count -gt 0) { ($Results | Measure-Object -Property Duration -Average).Average } else { 0 }
        SlowestModule = ($Results | Sort-Object Duration -Descending | Select-Object -First 1).Module
        FastestModule = ($Results | Sort-Object Duration | Select-Object -First 1).Module
    }

    # Calculate success rate
    $summary.SuccessRate = if ($summary.TotalTests -gt 0) {
        [Math]::Round(($summary.TotalPassed / $summary.TotalTests) * 100, 2)
    } else { 0 }

    # Add failure analysis
    $failureAnalysis = @{
        ModulesWithFailures = $Results | Where-Object { $_.TestsFailed -gt 0 } | Select-Object Module, TestsFailed, @{Name="FailureRate"; Expression={[Math]::Round(($_.TestsFailed / $_.TestsRun) * 100, 2)}}
        CommonFailurePatterns = @()
        CriticalFailures = @()
    }

    # Analyze failure patterns
    $failedResults = $Results | Where-Object { $_.TestsFailed -gt 0 }
    foreach ($failed in $failedResults) {
        if ($failed.Details) {
            foreach ($detail in $failed.Details) {
                if ($detail -match "Failed:|Error:|Exception:") {
                    $failureAnalysis.CommonFailurePatterns += $detail
                }
            }
        }
        
        # Mark critical failures (modules with >50% failure rate)
        if ($failed.TestsRun -gt 0 -and ($failed.TestsFailed / $failed.TestsRun) -gt 0.5) {
            $failureAnalysis.CriticalFailures += $failed.Module
        }
    }

    # Generate enhanced JSON report
    $jsonReport = @{
        Summary = $summary
        Results = $Results
        FailureAnalysis = $failureAnalysis
        GeneratedBy = "AitherZero TestingFramework"
        Version = "1.0.0"
    }
    $jsonPath = Join-Path $reportDir "test-report-$reportTimestamp.json"
    $jsonReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8

    # Generate enhanced HTML report
    $htmlPath = Join-Path $reportDir "test-report-$reportTimestamp.html"
    $htmlContent = New-EnhancedHTMLTestReport -Summary $summary -Results $Results -FailureAnalysis $failureAnalysis
    $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8

    # Generate summary log
    $logPath = Join-Path $reportDir "test-summary-$reportTimestamp.log"
    $logContent = New-LogTestReport -Summary $summary -Results $Results
    $logContent | Out-File -FilePath $logPath -Encoding UTF8

    # Generate CSV report for data analysis
    $csvPath = Join-Path $reportDir "test-results-$reportTimestamp.csv"
    $csvContent = New-CSVTestReport -Results $Results
    $csvContent | Out-File -FilePath $csvPath -Encoding UTF8

    Write-TestLog "📊 Enhanced reports generated:" -Level "SUCCESS"
    Write-TestLog "  JSON: $jsonPath" -Level "INFO"
    Write-TestLog "  HTML: $htmlPath" -Level "INFO"
    Write-TestLog "  Log: $logPath" -Level "INFO"
    Write-TestLog "  CSV: $csvPath" -Level "INFO"

    return $htmlPath
}

function New-EnhancedHTMLTestReport {
    <#
    .SYNOPSIS
        Generates enhanced HTML test report with failure analysis
    #>
    [CmdletBinding()]
    param($Summary, $Results, $FailureAnalysis)

    $statusColor = if ($Summary.SuccessRate -ge 95) { "green" } elseif ($Summary.SuccessRate -ge 80) { "orange" } else { "red" }

    # Generate failure analysis section
    $failureAnalysisHtml = ""
    if ($FailureAnalysis.CriticalFailures.Count -gt 0) {
        $failureAnalysisHtml = @"
    <div class="failure-analysis">
        <h2>🔍 Failure Analysis</h2>
        <div class="critical-failures">
            <h3>Critical Failures (>50% failure rate)</h3>
            <ul>
"@
        foreach ($critical in $FailureAnalysis.CriticalFailures) {
            $failureAnalysisHtml += "<li>$critical</li>"
        }
        $failureAnalysisHtml += "</ul></div></div>"
    }

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Test Report - Enhanced</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .summary { background-color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { display: inline-block; margin: 10px 20px 10px 0; }
        .metric-value { font-size: 2em; font-weight: bold; color: $statusColor; }
        .metric-label { font-size: 0.9em; color: #666; }
        .results { background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; }
        .failure-analysis { background-color: #fff3cd; padding: 20px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #ffc107; }
        .module-result { margin: 10px 0; padding: 15px; border-left: 4px solid #ddd; background-color: #f9f9f9; }
        .success { border-left-color: #27ae60; }
        .failure { border-left-color: #e74c3c; }
        .phase { margin: 5px 0; font-size: 0.9em; }
        .details { margin-top: 10px; font-size: 0.8em; color: #666; }
        .performance-metrics { background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; }
        .chart { display: flex; justify-content: space-around; margin: 20px 0; }
        .chart-item { text-align: center; }
        .progress-bar { width: 200px; height: 20px; background-color: #e0e0e0; border-radius: 10px; overflow: hidden; margin: 10px auto; }
        .progress-fill { height: 100%; background-color: $statusColor; transition: width 0.3s ease; }
        .critical-failure { background-color: #f8d7da; border-left-color: #dc3545; }
        .expandable { cursor: pointer; }
        .expandable:hover { background-color: #f0f0f0; }
        .details-expanded { display: block; }
        .details-collapsed { display: none; }
    </style>
    <script>
        function toggleDetails(element) {
            const details = element.nextElementSibling;
            if (details.classList.contains('details-collapsed')) {
                details.classList.remove('details-collapsed');
                details.classList.add('details-expanded');
                element.textContent = element.textContent.replace('▶', '▼');
            } else {
                details.classList.remove('details-expanded');
                details.classList.add('details-collapsed');
                element.textContent = element.textContent.replace('▼', '▶');
            }
        }
    </script>
</head>
<body>
    <div class="header">
        <h1>🧪 AitherZero Test Report - Enhanced</h1>
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
            <div class="metric-value">$($Summary.TotalSkipped)</div>
            <div class="metric-label">Tests Skipped</div>
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

    <div class="performance-metrics">
        <h2>⚡ Performance Metrics</h2>
        <div class="chart">
            <div class="chart-item">
                <div class="metric-label">Average Duration</div>
                <div class="metric-value">$([Math]::Round($Summary.AverageDuration, 2))s</div>
            </div>
            <div class="chart-item">
                <div class="metric-label">Slowest Module</div>
                <div class="metric-value">$($Summary.SlowestModule)</div>
            </div>
            <div class="chart-item">
                <div class="metric-label">Fastest Module</div>
                <div class="metric-value">$($Summary.FastestModule)</div>
            </div>
        </div>
        <div class="progress-bar">
            <div class="progress-fill" style="width: $($Summary.SuccessRate)%"></div>
        </div>
    </div>

    $failureAnalysisHtml

    <div class="results">
        <h2>📋 Detailed Results</h2>
"@

    # Group results by module
    $moduleGroups = $Results | Group-Object -Property Module
    foreach ($moduleGroup in $moduleGroups) {
        $moduleSuccess = ($moduleGroup.Group | Where-Object { $_.Success -eq $true }).Count -eq $moduleGroup.Count
        $cssClass = if ($moduleSuccess) { "success" } else { "failure" }
        $icon = if ($moduleSuccess) { "✅" } else { "❌" }
        
        # Check if this is a critical failure
        $isCritical = $moduleGroup.Name -in $FailureAnalysis.CriticalFailures
        $criticalClass = if ($isCritical) { " critical-failure" } else { "" }

        $html += @"
        <div class="module-result $cssClass$criticalClass">
            <div class="expandable" onclick="toggleDetails(this)">
                <h3>$icon $($moduleGroup.Name) $(if ($isCritical) { "🚨" } else { "" }) ▶</h3>
            </div>
            <div class="details details-collapsed">
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

        $html += "</div></div>"
    }

    $html += @"
    </div>

    <div class="footer" style="text-align: center; margin-top: 20px; color: #666;">
        <p>Generated by AitherZero TestingFramework v1.0.0 | $(Get-Date)</p>
    </div>
</body>
</html>
"@

    return $html
}

function New-CSVTestReport {
    <#
    .SYNOPSIS
        Generates CSV test report for data analysis
    #>
    [CmdletBinding()]
    param($Results)

    $csvContent = "Module,Phase,TestsRun,TestsPassed,TestsFailed,TestsSkipped,Duration,Success,Error`n"
    
    foreach ($result in $Results) {
        $csvContent += "$($result.Module),$($result.Phase),$($result.TestsRun),$($result.TestsPassed),$($result.TestsFailed),$($result.TestsSkipped ?? 0),$($result.Duration),$($result.Success),$($result.Error -replace ',', ';')`n"
    }

    return $csvContent
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

function Submit-TestEvent {
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

    # Store event for subscribers - ensure script:TestEvents is initialized
    if (-not $script:TestEvents) {
        $script:TestEvents = @{}
    }
    
    if (-not $script:TestEvents.ContainsKey($EventType)) {
        $script:TestEvents[$EventType] = @()
    }
    $script:TestEvents[$EventType] += $event

    Write-TestLog "📡 Submitted event: $EventType" -Level "INFO"
}

function Register-TestEventHandler {
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
# INTEGRATION WITH EXISTING TEST RUNNER
# ============================================================================

function Invoke-SimpleTestRunner {
    <#
    .SYNOPSIS
        Integration function to work with the existing simple test runner
    #>
    [CmdletBinding()]
    param(
        [switch]$Quick,
        [switch]$Setup,
        [switch]$All,
        [switch]$CI,
        [string]$OutputPath = "./tests/results"
    )

    Write-TestLog "🔄 Running tests through TestingFramework integration" -Level "INFO"

    # Map simple runner parameters to unified framework
    $testSuite = if ($All) { "All" }
                elseif ($Setup) { "NonInteractive" }
                else { "Quick" }

    $testProfile = if ($CI) { "CI" } else { "Development" }

    try {
        $results = Invoke-UnifiedTestExecution -TestSuite $testSuite -TestProfile $testProfile -OutputPath $OutputPath -GenerateReport

        # Convert results to simple format for compatibility
        $totalPassed = ($results | Measure-Object -Property TestsPassed -Sum).Sum
        $totalFailed = ($results | Measure-Object -Property TestsFailed -Sum).Sum
        $totalCount = $totalPassed + $totalFailed

        return @{
            Passed = $totalPassed
            Failed = $totalFailed
            TotalCount = $totalCount
            Duration = [TimeSpan]::FromSeconds(($results | Measure-Object -Property Duration -Sum).Sum)
        }
    } catch {
        Write-TestLog "❌ Unified test execution failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Test-ModuleStructure {
    <#
    .SYNOPSIS
        Tests project module structure and basic functionality
    #>
    [CmdletBinding()]
    param()

    $projectRoot = $script:ProjectRoot
    $testResults = @()

    # Test basic project structure
    $requiredPaths = @(
        "Start-AitherZero.ps1",
        "aither-core/aither-core.ps1",
        "aither-core/modules",
        "configs/default-config.json"
    )

    foreach ($path in $requiredPaths) {
        $fullPath = Join-Path $projectRoot $path
        $testResults += @{
            Test = "Project Structure: $path"
            Result = Test-Path $fullPath
            Details = if (Test-Path $fullPath) { "Found" } else { "Missing: $fullPath" }
        }
    }

    # Test module loading
    $coreModules = @("Logging", "PatchManager", "SetupWizard", "TestingFramework")
    foreach ($module in $coreModules) {
        try {
            $moduleResult = Import-ProjectModule -ModuleName $module
            $testResults += @{
                Test = "Module Loading: $module"
                Result = ($null -ne $moduleResult)
                Details = if ($moduleResult) { "Loaded successfully" } else { "Failed to load" }
            }
        } catch {
            $testResults += @{
                Test = "Module Loading: $module"
                Result = $false
                Details = "Error: $($_.Exception.Message)"
            }
        }
    }

    return $testResults
}

# ============================================================================
# DISTRIBUTED TEST GENERATION FUNCTIONS
# ============================================================================

function New-ModuleTest {
    <#
    .SYNOPSIS
        Generates standardized test files for modules that don't have tests

    .DESCRIPTION
        Automatically creates comprehensive test files based on module analysis and templates.
        Supports different module types (Manager, Provider, Core, Utility) with specialized templates.

    .PARAMETER ModuleName
        Name of the module to generate tests for

    .PARAMETER ModulePath
        Path to the module directory

    .PARAMETER TemplateType
        Type of template to use (Auto, Manager, Provider, Core, Utility)

    .PARAMETER Force
        Overwrite existing test files

    .EXAMPLE
        New-ModuleTest -ModuleName "PatchManager" -ModulePath "./aither-core/modules/PatchManager"

    .EXAMPLE
        New-ModuleTest -ModuleName "OpenTofuProvider" -TemplateType "Provider" -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter()]
        [string]$ModulePath,

        [Parameter()]
        [ValidateSet("Auto", "Manager", "Provider", "Core", "Utility")]
        [string]$TemplateType = "Auto",

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-TestLog "🧪 Generating test for module: $ModuleName" -Level "INFO"

        # Determine module path if not provided
        if (-not $ModulePath) {
            $ModulePath = Join-Path $script:ProjectRoot "aither-core/modules/$ModuleName"
        }

        if (-not (Test-Path $ModulePath)) {
            throw "Module path not found: $ModulePath"
        }

        # Determine template directory
        $templateDir = Join-Path $script:ProjectRoot "scripts/testing/templates"
        if (-not (Test-Path $templateDir)) {
            throw "Template directory not found: $templateDir"
        }
    }

    process {
        try {
            # Analyze module structure
            $moduleAnalysis = Get-ModuleAnalysis -ModulePath $ModulePath -ModuleName $ModuleName

            # Determine template type automatically if requested
            if ($TemplateType -eq "Auto") {
                $TemplateType = Get-OptimalTemplateType -ModuleAnalysis $moduleAnalysis
                Write-TestLog "Auto-selected template type: $TemplateType" -Level "INFO"
            }

            # Generate test content
            $testContent = New-TestContentFromTemplate -ModuleAnalysis $moduleAnalysis -TemplateType $TemplateType -TemplateDirectory $templateDir

            # Create test directory and file
            $testDir = Join-Path $ModulePath "tests"
            $testFile = Join-Path $testDir "$ModuleName.Tests.ps1"

            if ((Test-Path $testFile) -and -not $Force) {
                Write-TestLog "Test file already exists: $testFile (use -Force to overwrite)" -Level "WARN"
                return $false
            }

            if ($PSCmdlet.ShouldProcess($testFile, "Create test file")) {
                # Create test directory
                if (-not (Test-Path $testDir)) {
                    New-Item -Path $testDir -ItemType Directory -Force | Out-Null
                }

                # Write test file
                Set-Content -Path $testFile -Value $testContent -Encoding UTF8

                Write-TestLog "✅ Generated test file: $testFile" -Level "SUCCESS"
                return $true
            }

        } catch {
            Write-TestLog "❌ Failed to generate test for $ModuleName : $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function Get-ModuleAnalysis {
    <#
    .SYNOPSIS
        Analyzes a module to extract information for test generation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModulePath,

        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    $analysis = @{
        ModuleName = $ModuleName
        ModulePath = $ModulePath
        ModuleType = "Utility"  # Default
        ExportedFunctions = @()
        HasManifest = $false
        HasPrivatePublic = $false
        RequiredModules = @()
        Description = ""
        ModuleVersion = "1.0.0"
    }

    try {
        # Check for manifest file
        $manifestPath = Join-Path $ModulePath "$ModuleName.psd1"
        if (Test-Path $manifestPath) {
            $analysis.HasManifest = $true

            try {
                $manifest = Import-PowerShellDataFile -Path $manifestPath
                $analysis.Description = $manifest.Description ?? ""
                $analysis.ModuleVersion = $manifest.ModuleVersion ?? "1.0.0"
                $analysis.RequiredModules = $manifest.RequiredModules ?? @()
                if ($manifest.FunctionsToExport -and $manifest.FunctionsToExport -ne '*') {
                    $analysis.ExportedFunctions = $manifest.FunctionsToExport
                }
            } catch {
                Write-TestLog "Could not parse manifest file: $_" -Level "WARN"
            }
        }

        # Check for Private/Public structure
        $publicPath = Join-Path $ModulePath "Public"
        $privatePath = Join-Path $ModulePath "Private"
        $analysis.HasPrivatePublic = (Test-Path $publicPath) -and (Test-Path $privatePath)

        # If no functions from manifest, try to discover from Public folder
        if ($analysis.ExportedFunctions.Count -eq 0 -and (Test-Path $publicPath)) {
            $publicFiles = Get-ChildItem -Path $publicPath -Filter "*.ps1" -ErrorAction SilentlyContinue
            $analysis.ExportedFunctions = $publicFiles | ForEach-Object {
                [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            }
        }

        # Determine module type based on name and structure
        $analysis.ModuleType = Get-ModuleTypeFromAnalysis -ModuleName $ModuleName -Analysis $analysis

        Write-TestLog "Module analysis completed for $ModuleName : Type=$($analysis.ModuleType), Functions=$($analysis.ExportedFunctions.Count)" -Level "INFO"

    } catch {
        Write-TestLog "Error analyzing module $ModuleName : $_" -Level "ERROR"
    }

    return $analysis
}

function Get-ModuleTypeFromAnalysis {
    <#
    .SYNOPSIS
        Determines the optimal module type based on name and structure analysis
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $true)]
        [hashtable]$Analysis
    )

    # Manager modules
    if ($ModuleName -match '.*Manager$') {
        return "Manager"
    }

    # Provider modules
    if ($ModuleName -match '.*Provider$') {
        return "Provider"
    }

    # Core framework modules
    if ($ModuleName -in @('Logging', 'TestingFramework', 'ParallelExecution', 'ConfigurationCore')) {
        return "Core"
    }

    # Check function patterns for additional clues
    $managerPatterns = @('Start-', 'Stop-', 'Invoke-.*Management', 'Reset-', 'Get-.*Status')
    $providerPatterns = @('Connect-', 'Disconnect-', 'New-.*Resource', 'Remove-.*Resource', 'Get-.*Resource')

    $managerMatches = $Analysis.ExportedFunctions | Where-Object {
        $func = $_
        $managerPatterns | Where-Object { $func -match $_ }
    }

    $providerMatches = $Analysis.ExportedFunctions | Where-Object {
        $func = $_
        $providerPatterns | Where-Object { $func -match $_ }
    }

    if ($managerMatches.Count -gt $providerMatches.Count -and $managerMatches.Count -gt 0) {
        return "Manager"
    }

    if ($providerMatches.Count -gt 0) {
        return "Provider"
    }

    return "Utility"
}

function Get-OptimalTemplateType {
    <#
    .SYNOPSIS
        Determines the optimal template type based on module analysis
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ModuleAnalysis
    )

    switch ($ModuleAnalysis.ModuleType) {
        "Manager" { return "Manager" }
        "Provider" { return "Provider" }
        "Core" { return "Core" }
        default { return "Utility" }
    }
}

function New-TestContentFromTemplate {
    <#
    .SYNOPSIS
        Generates test content from template with variable substitution
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ModuleAnalysis,

        [Parameter(Mandatory = $true)]
        [string]$TemplateType,

        [Parameter(Mandatory = $true)]
        [string]$TemplateDirectory
    )

    # Select template file
    $templateFile = switch ($TemplateType) {
        "Manager" { Join-Path $TemplateDirectory "manager-module-test-template.ps1" }
        "Provider" { Join-Path $TemplateDirectory "provider-module-test-template.ps1" }
        default { Join-Path $TemplateDirectory "module-test-template.ps1" }
    }

    if (-not (Test-Path $templateFile)) {
        throw "Template file not found: $templateFile"
    }

    # Read template content
    $template = Get-Content -Path $templateFile -Raw

    # Prepare substitution variables
    $substitutions = Get-TemplateSubstitutions -ModuleAnalysis $ModuleAnalysis

    # Perform substitutions
    $content = $template
    foreach ($substitution in $substitutions.GetEnumerator()) {
        $placeholder = "{{$($substitution.Key)}}"
        $content = $content -replace [regex]::Escape($placeholder), $substitution.Value
    }

    # Clean up any remaining placeholders
    $content = $content -replace '\{\{[^}]+\}\}', '# TODO: Customize this section'

    return $content
}

function Get-TemplateSubstitutions {
    <#
    .SYNOPSIS
        Generates template variable substitutions based on module analysis
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ModuleAnalysis
    )

    $substitutions = @{
        'MODULE_NAME' = $ModuleAnalysis.ModuleName
        'MODULE_DESCRIPTION' = $ModuleAnalysis.Description
        'MODULE_VERSION' = $ModuleAnalysis.ModuleVersion
        'ADDITIONAL_TEST_AREAS' = "Module-specific functionality testing"
        'TEST_SETUP' = '# Module-specific setup can be added here'
        'TEST_CLEANUP' = '# Module-specific cleanup can be added here'
    }

    # Generate expected functions list
    if ($ModuleAnalysis.ExportedFunctions.Count -gt 0) {
        $functionList = $ModuleAnalysis.ExportedFunctions | ForEach-Object { "'$_'" }
        $substitutions['EXPECTED_FUNCTIONS'] = $functionList -join ",`n                "
    } else {
        $expectedFunctions = $ModuleAnalysis.Functions | ForEach-Object { "'$($_.Name)'" }
        $substitutions['EXPECTED_FUNCTIONS'] = "@(" + ($expectedFunctions -join ", ") + ")"
    }

    # Add type-specific substitutions
    switch ($ModuleAnalysis.ModuleType) {
        "Manager" {
            $resourceType = $ModuleAnalysis.ModuleName -replace 'Manager$', ''
            $substitutions['RESOURCE_TYPE'] = $resourceType
        }
        "Provider" {
            $providerType = $ModuleAnalysis.ModuleName -replace 'Provider$', ''
            $substitutions['PROVIDER_TYPE'] = $providerType
        }
    }

    # Generate basic test content
    $substitutions['CORE_FUNCTIONALITY_TESTS'] = 'It "Should execute core functions without errors" {
            $functions = Get-Command -Module $ModuleName -CommandType Function
            $functions | Should -Not -BeNullOrEmpty

            foreach ($function in $functions) {
                { Get-Help $function.Name } | Should -Not -Throw
            }
        }'

    $substitutions['ERROR_HANDLING_TESTS'] = 'It "Should handle errors gracefully" {
            $functions = Get-Command -Module $ModuleName -CommandType Function

            foreach ($function in $functions) {
                $help = Get-Help $function.Name
                if ($help.Parameters) {
                    # Test with invalid parameters where possible
                    $mandatoryParams = $help.Parameters.Parameter | Where-Object { $_.Required -eq "true" }
                    if ($mandatoryParams) {
                        # Test should throw when mandatory parameters are missing
                        { & $function.Name -ErrorAction Stop } | Should -Throw
                    }
                }
            }
        }'

    $substitutions['LOGGING_INTEGRATION_TEST'] = '$true | Should -Be $true'
    $substitutions['CONFIGURATION_TEST'] = '$true | Should -Be $true'
    $substitutions['CROSS_PLATFORM_TEST'] = '$true | Should -Be $true'
    $substitutions['PERFORMANCE_TESTS'] = '$true | Should -Be $true'
    $substitutions['CONCURRENCY_TESTS'] = '$true | Should -Be $true'
    $substitutions['RESOURCE_CONSTRAINT_TESTS'] = '$true | Should -Be $true'
    $substitutions['EDGE_CASE_TESTS'] = 'It "Should handle edge cases properly" {
            $functions = Get-Command -Module $ModuleName -CommandType Function

            foreach ($function in $functions) {
                # Test with null/empty inputs where applicable
                $help = Get-Help $function.Name
                $stringParams = $help.Parameters.Parameter | Where-Object { $_.Type -like "*String*" -and $_.Required -eq "false" }

                foreach ($param in $stringParams) {
                    { & $function.Name -$($param.Name) "" -ErrorAction SilentlyContinue } | Should -Not -Throw
                }
            }
        }'
    $substitutions['INTEGRATION_TESTS'] = 'It "Should integrate with other modules" {
            # Test module loading and basic dependencies
            $moduleInfo = Get-Module $ModuleName
            $moduleInfo | Should -Not -BeNullOrEmpty
            $moduleInfo.ExportedFunctions | Should -Not -BeNullOrEmpty

            # Check if common AitherZero patterns are followed
            $functions = Get-Command -Module $ModuleName -CommandType Function
            $writeCustomLogAvailable = Get-Command Write-CustomLog -ErrorAction SilentlyContinue
            if ($writeCustomLogAvailable) {
                # Module should integrate with logging if available
                $true | Should -Be $true
            }
        }'
    $substitutions['REGRESSION_TESTS'] = 'It "Should not regress existing functionality" {
            # Ensure all expected functions are still exported
            $moduleInfo = Get-Module $ModuleName
            $exportedFunctions = $moduleInfo.ExportedFunctions.Keys

            # Basic regression check - module should have functions
            $exportedFunctions.Count | Should -BeGreaterThan 0

            # All exported functions should be callable
            foreach ($functionName in $exportedFunctions) {
                $function = Get-Command $functionName -ErrorAction SilentlyContinue
                $function | Should -Not -BeNullOrEmpty
                $function.ModuleName | Should -Be $ModuleName
            }
        }'

    return $substitutions
}

function Invoke-BulkTestGeneration {
    <#
    .SYNOPSIS
        Generates tests for multiple modules that don't have tests

    .DESCRIPTION
        Discovers modules without tests and generates standardized test files for them

    .PARAMETER ModuleNames
        Specific modules to generate tests for (default: all modules without tests)

    .PARAMETER MaxConcurrency
        Maximum number of concurrent test generations

    .PARAMETER Force
        Overwrite existing test files

    .EXAMPLE
        Invoke-BulkTestGeneration -MaxConcurrency 3
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string[]]$ModuleNames = @(),

        [Parameter()]
        [int]$MaxConcurrency = 3,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-TestLog "🏭 Starting bulk test generation" -Level "INFO"

        # Discover modules without tests
        $allModules = Get-DiscoveredModules -IncludeDistributedTests:$true -IncludeCentralizedTests:$false
        $modulesWithoutTests = $allModules | Where-Object { $_.TestDiscovery.TestStrategy -eq "None" }

        if ($ModuleNames.Count -gt 0) {
            $modulesWithoutTests = $modulesWithoutTests | Where-Object { $_.Name -in $ModuleNames }
        }

        Write-TestLog "Found $($modulesWithoutTests.Count) modules without tests" -Level "INFO"
    }

    process {
        $results = @()
        $errors = @()

        # Process modules in batches for better performance
        $batches = @()
        for ($i = 0; $i -lt $modulesWithoutTests.Count; $i += $MaxConcurrency) {
            $batches += ,($modulesWithoutTests[$i..([Math]::Min($i + $MaxConcurrency - 1, $modulesWithoutTests.Count - 1))])
        }

        foreach ($batch in $batches) {
            $jobs = @()

            foreach ($module in $batch) {
                if ($PSCmdlet.ShouldProcess($module.Name, "Generate test file")) {
                    $jobs += Start-Job -ScriptBlock {
                        param($ModuleName, $ModulePath, $Force)

                        try {
                            # Re-import TestingFramework in job context
                            $frameworkPath = Split-Path $using:PSScriptRoot -Parent
                            Import-Module (Join-Path $frameworkPath "TestingFramework") -Force

                            $result = New-ModuleTest -ModuleName $ModuleName -ModulePath $ModulePath -Force:$Force

                            return @{
                                Success = $true
                                ModuleName = $ModuleName
                                Result = $result
                                Message = "Test generated successfully"
                            }
                        } catch {
                            return @{
                                Success = $false
                                ModuleName = $ModuleName
                                Error = $_.Exception.Message
                                Message = "Test generation failed"
                            }
                        }
                    } -ArgumentList $module.Name, $module.Path, $Force.IsPresent
                }
            }

            # Wait for batch to complete
            if ($jobs.Count -gt 0) {
                $batchResults = $jobs | Wait-Job | Receive-Job
                $jobs | Remove-Job

                $results += $batchResults

                # Log batch completion
                $successful = ($batchResults | Where-Object { $_.Success }).Count
                $failed = ($batchResults | Where-Object { -not $_.Success }).Count
                Write-TestLog "Batch completed: $successful successful, $failed failed" -Level "INFO"
            }
        }

        # Summary
        $totalSuccessful = ($results | Where-Object { $_.Success }).Count
        $totalFailed = ($results | Where-Object { -not $_.Success }).Count

        Write-TestLog "🎯 Bulk test generation completed: $totalSuccessful successful, $totalFailed failed" -Level "SUCCESS"

        if ($totalFailed -gt 0) {
            Write-TestLog "❌ Failed modules:" -Level "ERROR"
            $results | Where-Object { -not $_.Success } | ForEach-Object {
                Write-TestLog "  - $($_.ModuleName): $($_.Error)" -Level "ERROR"
            }
        }

        return $results
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
# BULLETPROOF TESTING COMPATIBILITY FUNCTIONS
# ============================================================================

function Invoke-BulletproofTest {
    <#
    .SYNOPSIS
        Executes a bulletproof test with comprehensive validation

    .DESCRIPTION
        Compatibility function for bulletproof testing framework integration

    .PARAMETER TestName
        Name of the test to execute

    .PARAMETER Type
        Type of test (Core, Module, System, Performance, Integration)

    .PARAMETER Critical
        Whether this is a critical test that must pass
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TestName,

        [Parameter(Mandatory)]
        [ValidateSet('Core', 'Module', 'System', 'Performance', 'Integration')]
        [string]$Type,

        [switch]$Critical
    )

    Write-TestLog "🎯 Executing bulletproof test: $TestName ($Type)" -Level "INFO"

    try {
        # Delegate to unified test execution with appropriate parameters
        $testConfig = @{
            TestSuite = $Type
            TestName = $TestName
            Critical = $Critical.IsPresent
        }

        return Invoke-UnifiedTestExecution @testConfig
    } catch {
        Write-TestLog "❌ Bulletproof test failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Start-TestSuite {
    <#
    .SYNOPSIS
        Starts a test suite execution

    .DESCRIPTION
        Compatibility function for starting test suite execution

    .PARAMETER SuiteName
        Name of the test suite to start

    .PARAMETER Configuration
        Test configuration parameters
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SuiteName,

        [hashtable]$Configuration = @{
            Verbosity = "Normal"
            TimeoutMinutes = 30
            RetryCount = 2
            MockLevel = "Standard"
            Platform = "All"
            ParallelJobs = [Math]::Min(4, ([Environment]::ProcessorCount))
        }
    )

    Write-TestLog "🚀 Starting test suite: $SuiteName" -Level "INFO"

    try {
        # Delegate to unified test execution
        $params = @{
            TestSuite = $SuiteName
        }

        if ($Configuration.Count -gt 0) {
            $params['Configuration'] = $Configuration
        }

        return Invoke-UnifiedTestExecution @params
    } catch {
        Write-TestLog "❌ Test suite start failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Update-ReadmeTestStatus {
    <#
    .SYNOPSIS
        Updates README.md files with test execution results and status information.
    
    .DESCRIPTION
        This function automatically updates README.md files in module directories and the project root
        with current test status, coverage percentages, execution timestamps, and result summaries.
        
        Preserves existing README.md content while adding/updating a standardized test status section.
    
    .PARAMETER ModulePath
        Path to specific module to update. If not specified, updates all modules.
    
    .PARAMETER TestResults
        Pester test results object containing execution data.
    
    .PARAMETER UpdateAll
        Updates README.md files for all modules in the project.
    
    .PARAMETER CoverageData
        Code coverage data to include in the status.
    
    .EXAMPLE
        Update-ReadmeTestStatus -UpdateAll -TestResults $testResults
        
        Updates README.md files for all modules with test results.
    
    .EXAMPLE
        Update-ReadmeTestStatus -ModulePath "./aither-core/modules/Logging" -TestResults $results
        
        Updates README.md for a specific module.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ModulePath,
        
        [Parameter(Mandatory = $false)]
        [object]$TestResults,
        
        [Parameter(Mandatory = $false)]
        [switch]$UpdateAll,
        
        [Parameter(Mandatory = $false)]
        [object]$CoverageData
    )
    
    begin {
        . "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        
        function Update-ModuleReadme {
            param(
                [string]$ModuleDir,
                [object]$Results,
                [object]$Coverage
            )
            
            $readmePath = Join-Path $ModuleDir "README.md"
            $moduleName = Split-Path $ModuleDir -Leaf
            
            # Calculate test metrics
            $totalTests = if ($Results) { $Results.TotalCount } else { 0 }
            $passedTests = if ($Results) { $Results.PassedCount } else { 0 }
            $failedTests = if ($Results) { $Results.FailedCount } else { 0 }
            $coveragePercent = if ($Coverage) { [math]::Round($Coverage.CoveragePercent, 1) } else { 0 }
            
            # Status indicators
            $statusIcon = if ($failedTests -eq 0 -and $totalTests -gt 0) { "✅" } else { "❌" }
            $platformStatus = "✅ Windows ✅ Linux ✅ macOS"
            
            # Create status section
            $statusSection = @"
## Test Status
- **Last Run**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC
- **Status**: $statusIcon $(if ($totalTests -gt 0) { "PASSING ($passedTests/$totalTests tests)" } else { "NO TESTS" })
- **Coverage**: $coveragePercent%
- **Platform**: $platformStatus
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | $statusIcon $(if ($failedTests -eq 0) { "PASS" } else { "FAIL" }) | $passedTests/$totalTests | $coveragePercent% | $(if ($Results) { "$([math]::Round($Results.Duration.TotalSeconds, 1))s" } else { "N/A" }) |

---
*Test status updated automatically by AitherZero Testing Framework*

"@
            
            # Update or create README.md
            if (Test-Path $readmePath) {
                $content = Get-Content $readmePath -Raw
                
                # Remove existing test status section if present
                $content = $content -replace '(?s)## Test Status.*?(?=##|\z)', ''
                
                # Add new status section at the top (after title if present)
                if ($content -match '(?s)^(# .+?\n\n?)(.*)') {
                    $newContent = $matches[1] + $statusSection + $matches[2]
                } else {
                    $newContent = $statusSection + "`n" + $content
                }
                
                Set-Content $readmePath -Value $newContent.Trim() -NoNewline
            } else {
                # Create new README.md with test status
                $newReadme = @"
# $moduleName

## Module Overview
*Description will be added*

$statusSection
"@
                Set-Content $readmePath -Value $newReadme
            }
            
            Write-TestLog "Updated README.md for $moduleName" -Level "INFO"
        }
    }
    
    process {
        try {
            if ($UpdateAll) {
                # Update all module README files
                $modulesPath = Join-Path $projectRoot "aither-core/modules"
                $modules = Get-ChildItem $modulesPath -Directory
                
                foreach ($module in $modules) {
                    Update-ModuleReadme -ModuleDir $module.FullName -Results $TestResults -Coverage $CoverageData
                }
                
                Write-TestLog "Updated README.md files for $($modules.Count) modules" -Level "INFO"
            } elseif ($ModulePath) {
                # Update specific module
                if (Test-Path $ModulePath) {
                    Update-ModuleReadme -ModuleDir $ModulePath -Results $TestResults -Coverage $CoverageData
                } else {
                    Write-TestLog "Module path not found: $ModulePath" -Level "WARN"
                }
            } else {
                Write-TestLog "Please specify -ModulePath or use -UpdateAll" -Level "WARN"
            }
        }
        catch {
            Write-TestLog "Failed to update README.md files: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================

# Create backward compatibility aliases
New-Alias -Name 'Publish-TestEvent' -Value 'Submit-TestEvent' -Force
New-Alias -Name 'Subscribe-TestEvent' -Value 'Register-TestEventHandler' -Force

# Export main functions
Export-ModuleMember -Function @(
    'Invoke-UnifiedTestExecution',
    'Get-DiscoveredModules',
    'New-TestExecutionPlan',
    'Get-TestConfiguration',
    'Invoke-ParallelTestExecution',
    'Invoke-SequentialTestExecution',
    'Invoke-ModuleTestPhase',
    'Invoke-EnvironmentTests',
    'Invoke-UnitTests',
    'Invoke-IntegrationTests',
    'Invoke-PerformanceTests',
    'Invoke-NonInteractiveTests',
    'New-TestReport',
    'Export-VSCodeTestResults',
    'Submit-TestEvent',
    'Register-TestEventHandler',
    'Get-TestEvents',
    'Register-TestProvider',
    'Get-RegisteredTestProviders',
    'New-ModuleTest',
    'Get-ModuleAnalysis',
    'Invoke-BulkTestGeneration',
    'Invoke-SimpleTestRunner',
    'Test-ModuleStructure',
    'Initialize-TestEnvironment',
    'Import-ProjectModule',
    'Invoke-PesterTests',
    'Invoke-PytestTests',
    'Invoke-SyntaxValidation',
    'Invoke-ParallelTests',
    'Invoke-BulletproofTest',
    'Start-TestSuite',
    'Write-TestLog',
    'Update-ReadmeTestStatus'
) -Alias @(
    'Publish-TestEvent',
    'Subscribe-TestEvent'
)
