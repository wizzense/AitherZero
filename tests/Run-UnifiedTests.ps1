#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Unified Test Runner for AitherZero - Consolidates all testing functionality
    
.DESCRIPTION
    Enterprise-grade unified test runner that combines functionality from:
    - Run-Tests.ps1 (Core/Setup/All testing with AitherCore support)
    - Run-CI-Tests.ps1 (CI/CD optimization with comprehensive reporting)
    - Run-Installation-Tests.ps1 (Installation and setup validation)
    
    Features:
    - Sub-30-second execution for core tests
    - Comprehensive dashboard reporting for CI/CD
    - Full audit trail and compliance reporting
    - Parallel execution optimization
    - Cross-platform testing support
    - Multiple output formats (Console, JUnit, JSON, HTML)
    - Real-time progress tracking
    - Fail-fast strategy for CI environments
    - Automatic test discovery (centralized and distributed)
    - Installation profile testing
    - Performance metrics and benchmarking
    
.PARAMETER TestSuite
    Test suite to run:
    - Quick: Core tests only (~30 seconds)
    - Core: Core functionality tests
    - Setup: Setup and installation tests
    - Installation: Installation profile validation
    - Platform: Cross-platform compatibility tests
    - CI: Optimized CI/CD test suite
    - All: Complete test suite
    
.PARAMETER Profile
    Installation profile to test (for Installation suite):
    - minimal: Minimal installation
    - developer: Developer setup
    - full: Full installation
    - all: All profiles
    
.PARAMETER Platform
    Platform-specific testing:
    - Windows: Windows-specific tests
    - Linux: Linux-specific tests
    - macOS: macOS-specific tests
    - Current: Current platform only
    - All: All platforms
    
.PARAMETER CI
    Run in CI/CD mode with optimizations:
    - Minimal output
    - Parallel execution
    - Fail-fast strategy
    - Comprehensive reporting
    - Dashboard generation
    
.PARAMETER Distributed
    Use distributed testing via TestingFramework module
    
.PARAMETER OutputFormat
    Output format for reports:
    - Console: Standard console output
    - JUnit: JUnit XML format
    - JSON: JSON format
    - HTML: HTML dashboard
    - All: Generate all formats
    
.PARAMETER ReportPath
    Path to save test reports (default: tests/results)
    
.PARAMETER MaxParallelJobs
    Maximum parallel test execution jobs (default: 4)
    
.PARAMETER TimeoutMinutes
    Test execution timeout in minutes (default: 30)
    
.PARAMETER FailFast
    Stop on first test failure
    
.PARAMETER ShowProgress
    Show detailed progress information
    
.PARAMETER Verbose
    Enable verbose logging
    
.PARAMETER WhatIf
    Show what tests would be run without executing
    
.PARAMETER Tags
    Include specific test tags
    
.PARAMETER ExcludeTags
    Exclude specific test tags
    
.PARAMETER Modules
    Test specific modules only
    
.PARAMETER Performance
    Enable performance mode optimizations
    
.PARAMETER GenerateDashboard
    Generate comprehensive HTML dashboard
    
.PARAMETER UpdateReadme
    Update README.md files with test results
    
.EXAMPLE
    ./tests/Run-UnifiedTests.ps1
    # Run quick tests (default, ~30 seconds)
    
.EXAMPLE
    ./tests/Run-UnifiedTests.ps1 -TestSuite All -CI
    # Run all tests in CI mode with full reporting
    
.EXAMPLE
    ./tests/Run-UnifiedTests.ps1 -TestSuite Installation -Profile developer
    # Test developer installation profile
    
.EXAMPLE
    ./tests/Run-UnifiedTests.ps1 -TestSuite CI -OutputFormat All -GenerateDashboard
    # CI mode with all output formats and dashboard
    
.EXAMPLE
    ./tests/Run-UnifiedTests.ps1 -Distributed -ShowProgress -Performance
    # Distributed testing with performance optimization
    
.NOTES
    Version: 1.0.0
    Unified test runner consolidating all AitherZero testing functionality
    Maintains full auditing/reporting and comprehensive dashboard capabilities
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Test suite to run")]
    [ValidateSet('Quick', 'Core', 'Setup', 'Installation', 'Platform', 'CI', 'All')]
    [string]$TestSuite = 'Quick',
    
    [Parameter(HelpMessage = "Installation profile to test")]
    [ValidateSet('minimal', 'developer', 'full', 'all')]
    [string]$Profile = 'all',
    
    [Parameter(HelpMessage = "Platform-specific testing")]
    [ValidateSet('Windows', 'Linux', 'macOS', 'Current', 'All')]
    [string]$Platform = 'Current',
    
    [Parameter(HelpMessage = "Run in CI/CD mode")]
    [switch]$CI,
    
    [Parameter(HelpMessage = "Use distributed testing")]
    [switch]$Distributed,
    
    [Parameter(HelpMessage = "Output format for reports")]
    [ValidateSet('Console', 'JUnit', 'JSON', 'HTML', 'All')]
    [string]$OutputFormat = 'Console',
    
    [Parameter(HelpMessage = "Path to save test reports")]
    [string]$ReportPath = 'tests/results',
    
    [Parameter(HelpMessage = "Maximum parallel jobs")]
    [int]$MaxParallelJobs = 4,
    
    [Parameter(HelpMessage = "Test execution timeout in minutes")]
    [int]$TimeoutMinutes = 30,
    
    [Parameter(HelpMessage = "Stop on first failure")]
    [switch]$FailFast,
    
    [Parameter(HelpMessage = "Show detailed progress")]
    [switch]$ShowProgress,
    
    [Parameter(HelpMessage = "Enable verbose logging")]
    [switch]$VerboseOutput,
    
    [Parameter(HelpMessage = "Show what would be run")]
    [switch]$WhatIf,
    
    [Parameter(HelpMessage = "Include specific test tags")]
    [string[]]$Tags = @(),
    
    [Parameter(HelpMessage = "Exclude specific test tags")]
    [string[]]$ExcludeTags = @(),
    
    [Parameter(HelpMessage = "Test specific modules only")]
    [string[]]$Modules = @(),
    
    [Parameter(HelpMessage = "Enable performance mode")]
    [switch]$Performance,
    
    [Parameter(HelpMessage = "Generate comprehensive HTML dashboard")]
    [switch]$GenerateDashboard,
    
    [Parameter(HelpMessage = "Update README.md files with results")]
    [switch]$UpdateReadme
)

# Script configuration
$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($VerboseOutput) { 'Continue' } else { 'SilentlyContinue' }


# Global test session tracking
$script:TestSession = @{
    StartTime = Get-Date
    TestResults = @()
    TestSuites = @()
    Errors = @()
    Warnings = @()
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    SkippedTests = 0
    Duration = [TimeSpan]::Zero
    Platform = @{
        OS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
        OSVersion = [System.Environment]::OSVersion.VersionString
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        PowerShellEdition = $PSVersionTable.PSEdition
        Architecture = [System.Environment]::Is64BitOperatingSystem ? "x64" : "x86"
        ProcessorCount = [Environment]::ProcessorCount
        MachineName = [Environment]::MachineName
        WorkingDirectory = (Get-Location).Path
        GitBranch = $null
        GitCommit = $null
    }
    Configuration = @{
        TestSuite = $TestSuite
        Profile = $Profile
        Platform = $Platform
        CI = $CI.IsPresent
        Distributed = $Distributed.IsPresent
        OutputFormat = $OutputFormat
        MaxParallelJobs = $MaxParallelJobs
        TimeoutMinutes = $TimeoutMinutes
        FailFast = $FailFast.IsPresent
        Performance = $Performance.IsPresent
    }
    Metrics = @{
        TestsPerSecond = 0
        AverageTestDuration = 0
        SetupTime = 0
        ExecutionTime = 0
        ReportingTime = 0
        ParallelEfficiency = 0
    }
}

# Initialize paths
$script:TestPath = $PSScriptRoot
$script:ProjectRoot = Split-Path $script:TestPath -Parent
$script:ReportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $script:ProjectRoot $ReportPath }

# Create report directory
if (-not (Test-Path $script:ReportPath)) {
    New-Item -Path $script:ReportPath -ItemType Directory -Force | Out-Null
}

# Enhanced logging function
function Write-TestLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug', 'Progress')]
        [string]$Level = 'Info',
        [switch]$NoNewline,
        [switch]$NoTimestamp
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $prefix = switch ($Level) {
        'Info' { "ℹ️" }
        'Success' { "✅" }
        'Warning' { "⚠️" }
        'Error' { "❌" }
        'Debug' { "🔍" }
        'Progress' { "⏳" }
    }
    
    $color = switch ($Level) {
        'Info' { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Debug' { 'Gray' }
        'Progress' { 'Blue' }
    }
    
    $logPrefix = if ($NoTimestamp) { "$prefix " } else { "[$timestamp] $prefix " }
    $formattedMessage = "$logPrefix$Message"
    
    if ($NoNewline) {
        Write-Host $formattedMessage -ForegroundColor $color -NoNewline
    } else {
        Write-Host $formattedMessage -ForegroundColor $color
    }
    
    # Track errors and warnings
    if ($Level -eq 'Error') {
        $script:TestSession.Errors += $Message
    } elseif ($Level -eq 'Warning') {
        $script:TestSession.Warnings += $Message
    }
}

# Progress tracking function
function Write-ProgressUpdate {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete = 0,
        [int]$Id = 1
    )
    
    if ($ShowProgress) {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -Id $Id
        Write-TestLog "$Activity - $Status ($PercentComplete%)" -Level 'Progress'
    }
}

# Banner function
function Show-UnifiedTestBanner {
    if (-not $CI) {
        Clear-Host
        Write-Host ""
        Write-Host "    ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "    ║              AitherZero Unified Test Runner                  ║" -ForegroundColor Cyan
        Write-Host "    ║          Enterprise-Grade Testing Framework                  ║" -ForegroundColor Cyan
        Write-Host "    ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
    }
    
    Write-TestLog "🚀 AitherZero Unified Test Runner v1.0.0" -Level 'Info'
    Write-TestLog "Project Root: $script:ProjectRoot" -Level 'Info'
    Write-TestLog "Test Suite: $TestSuite" -Level 'Info'
    Write-TestLog "Platform: $($script:TestSession.Platform.OS)" -Level 'Info'
    Write-TestLog "PowerShell: $($script:TestSession.Platform.PowerShellVersion)" -Level 'Info'
    
    if ($CI) {
        Write-TestLog "CI Mode: Enabled (optimized for speed and reporting)" -Level 'Info'
    }
    
    if ($Performance) {
        Write-TestLog "Performance Mode: Enabled" -Level 'Info'
    }
    
    if ($WhatIf) {
        Write-TestLog "WhatIf Mode: Tests will not be executed" -Level 'Warning'
    }
    
    Write-Host ""
}

# Git information gathering
function Get-GitInformation {
    try {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $script:TestSession.Platform.GitBranch = (git branch --show-current 2>$null) ?? "Unknown"
            $script:TestSession.Platform.GitCommit = (git rev-parse --short HEAD 2>$null) ?? "Unknown"
        } else {
            $script:TestSession.Platform.GitBranch = "Git Not Available"
            $script:TestSession.Platform.GitCommit = "Git Not Available"
        }
    } catch {
        $script:TestSession.Platform.GitBranch = "Error"
        $script:TestSession.Platform.GitCommit = "Error"
    }
}

# Prerequisites validation
function Test-Prerequisites {
    Write-ProgressUpdate -Activity "Initializing" -Status "Validating prerequisites" -PercentComplete 10
    
    $prerequisites = @{
        PowerShell = $PSVersionTable.PSVersion.Major -ge 7
        ProjectStructure = Test-Path (Join-Path $script:ProjectRoot "Start-AitherZero.ps1")
        TestDirectory = Test-Path $script:TestPath
        AitherCore = Test-Path (Join-Path $script:ProjectRoot "aither-core")
    }
    
    $failed = @()
    foreach ($prereq in $prerequisites.GetEnumerator()) {
        if (-not $prereq.Value) {
            $failed += $prereq.Key
            Write-TestLog "Prerequisite failed: $($prereq.Key)" -Level 'Error'
        } else {
            Write-TestLog "Prerequisite passed: $($prereq.Key)" -Level 'Debug'
        }
    }
    
    if ($failed.Count -gt 0) {
        Write-TestLog "Prerequisites validation failed: $($failed -join ', ')" -Level 'Error'
        return $false
    }
    
    # Check and install Pester
    try {
        $pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object Version -ge '5.0.0'
        if (-not $pesterModule -or $CI) {
            Write-TestLog "Installing/updating Pester module..." -Level 'Info'
            Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck -Scope CurrentUser
        }
        
        Import-Module Pester -MinimumVersion 5.0.0 -Force
        Write-TestLog "Pester module ready" -Level 'Success'
    } catch {
        Write-TestLog "Failed to setup Pester: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
    
    # Check for ParallelExecution module (skip if disabled by environment)
    if ($env:AITHERZERO_DISABLE_PARALLEL -eq "true") {
        Write-TestLog "ParallelExecution disabled by environment variable" -Level 'Info'
        $script:TestSession.Configuration.ParallelSupport = $false
    } else {
        $parallelPath = Join-Path $script:ProjectRoot "aither-core/modules/ParallelExecution"
        if (Test-Path $parallelPath) {
            try {
                Import-Module $parallelPath -Force
                Write-TestLog "ParallelExecution module loaded" -Level 'Success'
                $script:TestSession.Configuration.ParallelSupport = $true
            } catch {
                Write-TestLog "ParallelExecution module failed to load: $($_.Exception.Message)" -Level 'Warning'
                $script:TestSession.Configuration.ParallelSupport = $false
            }
        } else {
            $script:TestSession.Configuration.ParallelSupport = $false
        }
    }
    
    Write-TestLog "Prerequisites validation completed" -Level 'Success'
    return $true
}

# Test file discovery
function Get-TestFiles {
    Write-ProgressUpdate -Activity "Discovery" -Status "Discovering test files" -PercentComplete 20
    
    $testFiles = @()
    
    # Define test file mappings based on test suite
    if ($TestSuite -eq 'All' -or $TestSuite -eq 'Comprehensive') {
        # Discover ALL test files - centralized and distributed
        Write-ProgressUpdate -Activity "Discovery" -Status "Discovering all test files (centralized + distributed)" -PercentComplete 25
        
        # Get centralized tests
        $centralizedTests = Get-ChildItem -Path $script:TestPath -Filter "*.Tests.ps1" -Recurse | ForEach-Object { $_.Name }
        
        # Get distributed module tests
        $moduleTestsPath = Join-Path $script:ProjectRoot "aither-core/modules"
        $distributedTests = @()
        if (Test-Path $moduleTestsPath) {
            $distributedTests = Get-ChildItem -Path $moduleTestsPath -Filter "*.Tests.ps1" -Recurse | ForEach-Object { $_.FullName }
        }
        
        Write-Host "📊 Test Discovery Results:" -ForegroundColor Cyan
        Write-Host "  Centralized tests: $($centralizedTests.Count)" -ForegroundColor White
        Write-Host "  Distributed tests: $($distributedTests.Count)" -ForegroundColor White
        Write-Host "  Total tests: $($centralizedTests.Count + $distributedTests.Count)" -ForegroundColor White
        
        $testSuiteMapping = @{
            'All' = $centralizedTests
            'Comprehensive' = $centralizedTests
        }
    } else {
        # Legacy hardcoded mappings for specific test suites
        $testSuiteMapping = @{
            'Quick' = @('Core.Tests.ps1')
            'Core' = @('Core.Tests.ps1')
            'Setup' = @('Setup.Tests.ps1', 'Setup-Installation.Tests.ps1')
            'Installation' = @('Setup-Installation.Tests.ps1', 'PowerShell-Version.Tests.ps1', 'EntryPoint-Validation.Tests.ps1')
            'Platform' = @('PowerShell-Version.Tests.ps1', 'CrossPlatform-Bootstrap.Tests.ps1')
            'CI' = @('Core.Tests.ps1', 'EntryPoint-Validation.Tests.ps1', 'PowerShell-Version.Tests.ps1')
        }
    }
    
    $targetFiles = $testSuiteMapping[$TestSuite]
    
    foreach ($fileName in $targetFiles) {
        $fullPath = Join-Path $script:TestPath $fileName
        if (Test-Path $fullPath) {
            $testFiles += @{
                Name = $fileName
                Path = $fullPath
                Category = switch ($fileName) {
                    { $_ -like "*Core*" } { 'Core' }
                    { $_ -like "*Setup*" } { 'Setup' }
                    { $_ -like "*Installation*" } { 'Installation' }
                    { $_ -like "*Platform*" -or $_ -like "*PowerShell*" } { 'Platform' }
                    { $_ -like "*EntryPoint*" } { 'Validation' }
                    default { 'Other' }
                }
                EstimatedDuration = switch ($fileName) {
                    "Core.Tests.ps1" { 25 }
                    "Setup.Tests.ps1" { 30 }
                    "Setup-Installation.Tests.ps1" { 45 }
                    "PowerShell-Version.Tests.ps1" { 15 }
                    "EntryPoint-Validation.Tests.ps1" { 20 }
                    "CrossPlatform-Bootstrap.Tests.ps1" { 40 }
                    "SetupWizard-Integration.Tests.ps1" { 60 }
                    default { 30 }
                }
            }
        } else {
            Write-TestLog "Test file not found: $fileName" -Level 'Warning'
        }
    }
    
    # Check for AitherCore consolidated module tests
    $aitherCorePath = Join-Path $script:ProjectRoot "aither-core/AitherCore.psd1"
    if (Test-Path $aitherCorePath) {
        $script:TestSession.Configuration.ConsolidatedModule = $true
        Write-TestLog "Detected consolidated AitherCore module" -Level 'Info'
        
        # Add AitherCore-specific tests if available
        $aitherCoreTestPath = Join-Path $script:TestPath "AitherCore.Tests.ps1"
        if (Test-Path $aitherCoreTestPath) {
            $testFiles += @{
                Name = "AitherCore.Tests.ps1"
                Path = $aitherCoreTestPath
                Category = 'Core'
                EstimatedDuration = 35
            }
        }
    } else {
        $script:TestSession.Configuration.ConsolidatedModule = $false
    }
    
    Write-TestLog "Discovered $($testFiles.Count) test files" -Level 'Success'
    return $testFiles
}

# Distributed testing execution
function Invoke-DistributedTests {
    Write-ProgressUpdate -Activity "Execution" -Status "Starting distributed testing" -PercentComplete 30
    
    try {
        # Try to load TestingFramework for distributed testing
        $testingFrameworkPath = Join-Path $script:ProjectRoot "aither-core/modules/TestingFramework"
        
        if ($script:TestSession.Configuration.ConsolidatedModule) {
            try {
                $aitherCorePath = Join-Path $script:ProjectRoot "aither-core/AitherCore.psd1"
                Import-Module $aitherCorePath -Force
                Write-TestLog "Loaded consolidated AitherCore module" -Level 'Success'
                
                if (Get-Command Initialize-CoreApplication -ErrorAction SilentlyContinue) {
                    Initialize-CoreApplication -RequiredOnly:($TestSuite -eq 'Quick')
                    Write-TestLog "Initialized core application" -Level 'Success'
                }
            } catch {
                Write-TestLog "Failed to load consolidated AitherCore: $($_.Exception.Message)" -Level 'Warning'
            }
        }
        
        if (Test-Path $testingFrameworkPath) {
            Import-Module $testingFrameworkPath -Force
            Write-TestLog "Loaded TestingFramework module" -Level 'Success'
            
            # Configure distributed testing
            $testSuiteType = switch ($TestSuite) {
                'Quick' { 'Unit' }
                'Core' { 'Unit' }
                'Setup' { 'Environment' }
                'Installation' { 'Integration' }
                'Platform' { 'Integration' }
                'CI' { 'Unit' }
                'All' { 'All' }
            }
            
            $executionParams = @{
                TestSuite = $testSuiteType
                TestProfile = if ($CI) { "CI" } else { "Development" }
                GenerateReport = $true
                Parallel = ($Performance -and -not $FailFast)
                OutputPath = $script:ReportPath
                MaxParallelJobs = $MaxParallelJobs
                TimeoutMinutes = $TimeoutMinutes
            }
            
            if ($Modules.Count -gt 0) {
                $executionParams.Modules = $Modules
            }
            
            Write-TestLog "Starting distributed test execution..." -Level 'Info'
            $distributedResults = Invoke-UnifiedTestExecution @executionParams
            
            # Process distributed results
            $totalPassed = ($distributedResults | Measure-Object -Property TestsPassed -Sum).Sum
            $totalFailed = ($distributedResults | Measure-Object -Property TestsFailed -Sum).Sum
            $totalSkipped = ($distributedResults | Measure-Object -Property TestsSkipped -Sum).Sum
            $totalDuration = ($distributedResults | Measure-Object -Property Duration -Sum).Sum
            
            $script:TestSession.TotalTests = $totalPassed + $totalFailed + $totalSkipped
            $script:TestSession.PassedTests = $totalPassed
            $script:TestSession.FailedTests = $totalFailed
            $script:TestSession.SkippedTests = $totalSkipped
            $script:TestSession.Duration = [TimeSpan]::FromSeconds($totalDuration)
            $script:TestSession.TestResults = $distributedResults
            
            Write-TestLog "Distributed testing completed" -Level 'Success'
            return $true
        } else {
            Write-TestLog "TestingFramework not found, falling back to centralized tests" -Level 'Warning'
            return $false
        }
    } catch {
        Write-TestLog "Distributed testing failed: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# Centralized testing execution
function Invoke-CentralizedTests {
    param([array]$TestFiles)
    
    Write-ProgressUpdate -Activity "Execution" -Status "Starting centralized testing" -PercentComplete 40
    
    $setupStartTime = Get-Date
    
    # Set environment variables for test context
    $env:AITHERZERO_TEST_MODE = $true
    $env:AITHERZERO_TEST_SUITE = $TestSuite
    $env:AITHERZERO_TEST_PROFILE = $Profile
    $env:AITHERZERO_TEST_PLATFORM = $Platform
    $env:AITHERZERO_TEST_CI = $CI
    $env:PESTER_PLATFORM = $script:TestSession.Platform.OS
    
    try {
        $allResults = @()
        $totalTests = 0
        $totalPassed = 0
        $totalFailed = 0
        $totalSkipped = 0
        
        # Determine execution strategy
        $useParallel = ($Performance -and $script:TestSession.Configuration.ParallelSupport -and $TestFiles.Count -gt 1 -and -not $FailFast)
        
        if ($useParallel) {
            Write-TestLog "Using parallel execution for performance optimization" -Level 'Info'
            $results = Invoke-ParallelTestExecution -TestFiles $TestFiles
        } else {
            Write-TestLog "Using sequential execution" -Level 'Info'
            $results = Invoke-SequentialTestExecution -TestFiles $TestFiles
        }
        
        $setupTime = (Get-Date) - $setupStartTime
        $script:TestSession.Metrics.SetupTime = $setupTime.TotalSeconds
        
        # Process results
        foreach ($result in $results) {
            $allResults += $result
            $totalTests += $result.TotalCount
            $totalPassed += $result.PassedCount
            $totalFailed += $result.FailedCount
            $totalSkipped += $result.SkippedCount
        }
        
        # Update test session
        $script:TestSession.TotalTests = $totalTests
        $script:TestSession.PassedTests = $totalPassed
        $script:TestSession.FailedTests = $totalFailed
        $script:TestSession.SkippedTests = $totalSkipped
        $script:TestSession.TestResults = $allResults
        $script:TestSession.Duration = (Get-Date) - $setupStartTime
        
        Write-TestLog "Centralized testing completed" -Level 'Success'
        return $true
        
    } catch {
        Write-TestLog "Centralized testing failed: $($_.Exception.Message)" -Level 'Error'
        return $false
    } finally {
        # Clean up environment variables
        Remove-Item Env:AITHERZERO_TEST_MODE -ErrorAction SilentlyContinue
        Remove-Item Env:AITHERZERO_TEST_SUITE -ErrorAction SilentlyContinue
        Remove-Item Env:AITHERZERO_TEST_PROFILE -ErrorAction SilentlyContinue
        Remove-Item Env:AITHERZERO_TEST_PLATFORM -ErrorAction SilentlyContinue
        Remove-Item Env:AITHERZERO_TEST_CI -ErrorAction SilentlyContinue
        Remove-Item Env:PESTER_PLATFORM -ErrorAction SilentlyContinue
    }
}

# Parallel test execution
function Invoke-ParallelTestExecution {
    param([array]$TestFiles)
    
    Write-TestLog "Executing $($TestFiles.Count) test files in parallel..." -Level 'Info'
    
    $parallelResults = Invoke-ParallelForEach -InputObject $TestFiles -ThrottleLimit $MaxParallelJobs -ScriptBlock {
        param($testFile)
        
        # Defensive path validation
        if (-not $testFile -or -not $testFile.Path -or -not (Test-Path $testFile.Path)) {
            throw "Invalid test file path: $($testFile.Path ?? 'null')"
        }
        
        Import-Module Pester -Force
        
        $config = New-PesterConfiguration
        $config.Run.Path = $testFile.Path
        $config.Run.PassThru = $true
        $config.Output.Verbosity = 'Minimal'
        # Timeout not supported in this Pester version
        
        $testStartTime = Get-Date
        
        try {
            $results = Invoke-Pester -Configuration $config
            $testDuration = (Get-Date) - $testStartTime
            
            return [PSCustomObject]@{
                TestFile = $testFile.Name
                Category = $testFile.Category
                TotalCount = $results.TotalCount
                PassedCount = $results.PassedCount
                FailedCount = $results.FailedCount
                SkippedCount = $results.SkippedCount
                Duration = $testDuration.TotalSeconds
                Result = if ($results.FailedCount -eq 0) { 'Passed' } else { 'Failed' }
                FailedTests = if ($results.FailedCount -gt 0) { $results.Failed | ForEach-Object { $_.ExpandedName } } else { @() }
                StartTime = $testStartTime
                EndTime = Get-Date
            }
        } catch {
            $testDuration = (Get-Date) - $testStartTime
            return [PSCustomObject]@{
                TestFile = $testFile.Name
                Category = $testFile.Category
                TotalCount = 0
                PassedCount = 0
                FailedCount = 1
                SkippedCount = 0
                Duration = $testDuration.TotalSeconds
                Result = 'Failed'
                Error = $_.Exception.Message
                StartTime = $testStartTime
                EndTime = Get-Date
            }
        }
    }
    
    return $parallelResults
}

# Sequential test execution
function Invoke-SequentialTestExecution {
    param([array]$TestFiles)
    
    Write-TestLog "Executing $($TestFiles.Count) test files sequentially..." -Level 'Info'
    
    $results = @()
    $fileIndex = 0
    
    foreach ($testFile in $TestFiles) {
        $fileIndex++
        $progress = [math]::Round(($fileIndex / $TestFiles.Count) * 60 + 40)
        Write-ProgressUpdate -Activity "Execution" -Status "Running $($testFile.Name)" -PercentComplete $progress
        
        Write-TestLog "Running test: $($testFile.Name)" -Level 'Info'
        
        # Defensive path validation
        if (-not $testFile -or -not $testFile.Path -or -not (Test-Path $testFile.Path)) {
            Write-TestLog "Invalid test file path: $($testFile.Path ?? 'null')" -Level 'Error'
            continue
        }
        
        $config = New-PesterConfiguration
        $config.Run.Path = $testFile.Path
        $config.Run.PassThru = $true
        $config.Output.Verbosity = if ($CI) { 'Minimal' } else { 'Normal' }
        # Timeout not supported in this Pester version
        
        # Configure tags if specified
        if ($Tags.Count -gt 0) {
            $config.Filter.Tag = $Tags
        }
        if ($ExcludeTags.Count -gt 0) {
            $config.Filter.ExcludeTag = $ExcludeTags
        }
        
        $testStartTime = Get-Date
        
        try {
            $testResults = Invoke-Pester -Configuration $config
            $testDuration = (Get-Date) - $testStartTime
            
            $result = [PSCustomObject]@{
                TestFile = $testFile.Name
                Category = $testFile.Category
                TotalCount = $testResults.TotalCount
                PassedCount = $testResults.PassedCount
                FailedCount = $testResults.FailedCount
                SkippedCount = $testResults.SkippedCount
                Duration = $testDuration.TotalSeconds
                Result = if ($testResults.FailedCount -eq 0) { 'Passed' } else { 'Failed' }
                FailedTests = if ($testResults.FailedCount -gt 0) { $testResults.Failed | ForEach-Object { $_.ExpandedName } } else { @() }
                StartTime = $testStartTime
                EndTime = Get-Date
            }
            
            $results += $result
            
            # Report individual test results
            $status = if ($testResults.FailedCount -eq 0) { "✅ PASSED" } else { "❌ FAILED" }
            Write-TestLog "$($testFile.Name): $status - $($testResults.PassedCount)/$($testResults.TotalCount) tests in $([math]::Round($testDuration.TotalSeconds, 2))s" -Level $(if ($testResults.FailedCount -eq 0) { 'Success' } else { 'Error' })
            
            # Show failed tests
            if ($testResults.FailedCount -gt 0) {
                Write-TestLog "Failed tests in $($testFile.Name):" -Level 'Error'
                foreach ($failure in $testResults.Failed) {
                    Write-TestLog "  - $($failure.ExpandedName)" -Level 'Error'
                }
                
                # Fail fast if enabled
                if ($FailFast) {
                    Write-TestLog "FailFast enabled - stopping execution" -Level 'Error'
                    break
                }
            }
            
        } catch {
            $testDuration = (Get-Date) - $testStartTime
            Write-TestLog "Test execution failed for $($testFile.Name): $($_.Exception.Message)" -Level 'Error'
            
            $result = [PSCustomObject]@{
                TestFile = $testFile.Name
                Category = $testFile.Category
                TotalCount = 0
                PassedCount = 0
                FailedCount = 1
                SkippedCount = 0
                Duration = $testDuration.TotalSeconds
                Result = 'Failed'
                Error = $_.Exception.Message
                StartTime = $testStartTime
                EndTime = Get-Date
            }
            
            $results += $result
            
            if ($FailFast) {
                Write-TestLog "FailFast enabled - stopping execution" -Level 'Error'
                break
            }
        }
    }
    
    return $results
}

# Calculate metrics
function Update-TestMetrics {
    Write-ProgressUpdate -Activity "Analysis" -Status "Calculating metrics" -PercentComplete 80
    
    $executionTime = $script:TestSession.Duration.TotalSeconds
    $totalTests = $script:TestSession.TotalTests
    
    $script:TestSession.Metrics.ExecutionTime = $executionTime
    $script:TestSession.Metrics.TestsPerSecond = if ($executionTime -gt 0) { [math]::Round($totalTests / $executionTime, 2) } else { 0 }
    $script:TestSession.Metrics.AverageTestDuration = if ($totalTests -gt 0) { [math]::Round($executionTime / $totalTests, 3) } else { 0 }
    
    # Calculate parallel efficiency if applicable
    if ($script:TestSession.Configuration.ParallelSupport -and $script:TestSession.TestResults.Count -gt 1) {
        $sequentialTime = ($script:TestSession.TestResults | Measure-Object -Property Duration -Sum).Sum
        $parallelTime = $executionTime
        $script:TestSession.Metrics.ParallelEfficiency = if ($sequentialTime -gt 0) { [math]::Round((1 - ($parallelTime / $sequentialTime)) * 100, 1) } else { 0 }
    }
    
    Write-TestLog "Metrics calculated successfully" -Level 'Success'
}

# Generate comprehensive reports
function New-TestReports {
    Write-ProgressUpdate -Activity "Reporting" -Status "Generating reports" -PercentComplete 85
    
    $reportingStartTime = Get-Date
    
    try {
        # Create comprehensive test summary
        $testSummary = @{
            # Basic metrics
            TotalTests = $script:TestSession.TotalTests
            PassedTests = $script:TestSession.PassedTests
            FailedTests = $script:TestSession.FailedTests
            SkippedTests = $script:TestSession.SkippedTests
            Success = ($script:TestSession.FailedTests -eq 0)
            
            # Timing information
            StartTime = $script:TestSession.StartTime.ToString('yyyy-MM-dd HH:mm:ss')
            EndTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            Duration = $script:TestSession.Duration.TotalSeconds
            
            # Test results
            TestResults = $script:TestSession.TestResults
            
            # Platform information
            Platform = $script:TestSession.Platform
            
            # Configuration
            Configuration = $script:TestSession.Configuration
            
            # Metrics
            Metrics = $script:TestSession.Metrics
            
            # Error summary
            ErrorSummary = @{
                TotalErrors = $script:TestSession.Errors.Count
                TotalWarnings = $script:TestSession.Warnings.Count
                Errors = $script:TestSession.Errors
                Warnings = $script:TestSession.Warnings
                FailedTests = $script:TestSession.TestResults | Where-Object { $_.Result -eq 'Failed' }
            }
            
            # Quality metrics
            QualityMetrics = @{
                SuccessRate = if ($script:TestSession.TotalTests -gt 0) { [math]::Round(($script:TestSession.PassedTests / $script:TestSession.TotalTests) * 100, 2) } else { 0 }
                FailureRate = if ($script:TestSession.TotalTests -gt 0) { [math]::Round(($script:TestSession.FailedTests / $script:TestSession.TotalTests) * 100, 2) } else { 0 }
                TestCoverage = @{
                    CoreTests = ($script:TestSession.TestResults | Where-Object { $_.Category -eq 'Core' }).Count
                    SetupTests = ($script:TestSession.TestResults | Where-Object { $_.Category -eq 'Setup' }).Count
                    InstallationTests = ($script:TestSession.TestResults | Where-Object { $_.Category -eq 'Installation' }).Count
                    PlatformTests = ($script:TestSession.TestResults | Where-Object { $_.Category -eq 'Platform' }).Count
                    ValidationTests = ($script:TestSession.TestResults | Where-Object { $_.Category -eq 'Validation' }).Count
                }
                Performance = @{
                    TestsPerSecond = $script:TestSession.Metrics.TestsPerSecond
                    AverageTestDuration = $script:TestSession.Metrics.AverageTestDuration
                    ParallelEfficiency = $script:TestSession.Metrics.ParallelEfficiency
                    SetupTime = $script:TestSession.Metrics.SetupTime
                    ExecutionTime = $script:TestSession.Metrics.ExecutionTime
                }
            }
            
            # CI/CD information
            CIInfo = @{
                CI_PLATFORM = $env:CI_PLATFORM
                GITHUB_WORKFLOW = $env:GITHUB_WORKFLOW
                GITHUB_RUN_ID = $env:GITHUB_RUN_ID
                GITHUB_RUN_NUMBER = $env:GITHUB_RUN_NUMBER
                GITHUB_REPOSITORY = $env:GITHUB_REPOSITORY
                GITHUB_REF = $env:GITHUB_REF
                GITHUB_SHA = $env:GITHUB_SHA
                GITHUB_ACTIONS = $env:GITHUB_ACTIONS
            }
        }
        
        # Generate reports in requested formats
        $reportFormats = if ($OutputFormat -eq 'All') { @('Console', 'JSON', 'JUnit', 'HTML') } else { @($OutputFormat) }
        
        foreach ($format in $reportFormats) {
            switch ($format) {
                'JSON' {
                    $jsonPath = Join-Path $script:ReportPath "unified-test-results.json"
                    $testSummary | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
                    Write-TestLog "JSON report saved: $jsonPath" -Level 'Success'
                    
                    # Generate simplified dashboard JSON
                    $dashboardSummary = @{
                        success = $testSummary.Success
                        totalTests = $testSummary.TotalTests
                        passed = $testSummary.PassedTests
                        failed = $testSummary.FailedTests
                        skipped = $testSummary.SkippedTests
                        duration = $testSummary.Duration
                        successRate = $testSummary.QualityMetrics.SuccessRate
                        testsPerSecond = $testSummary.QualityMetrics.Performance.TestsPerSecond
                        timestamp = $testSummary.StartTime
                        platform = $testSummary.Platform.OS
                        testSuite = $testSummary.Configuration.TestSuite
                    }
                    
                    $dashboardPath = Join-Path $script:ReportPath "test-dashboard.json"
                    $dashboardSummary | ConvertTo-Json -Depth 5 | Set-Content -Path $dashboardPath -Encoding UTF8
                    Write-TestLog "Dashboard JSON saved: $dashboardPath" -Level 'Success'
                }
                
                'JUnit' {
                    $junitPath = Join-Path $script:ReportPath "unified-test-results.xml"
                    $junitXml = New-JUnitReport -TestSummary $testSummary
                    $junitXml | Set-Content -Path $junitPath -Encoding UTF8
                    Write-TestLog "JUnit XML report saved: $junitPath" -Level 'Success'
                }
                
                'HTML' {
                    if ($GenerateDashboard) {
                        $htmlPath = Join-Path $script:ReportPath "test-dashboard.html"
                        $htmlDashboard = New-HTMLDashboard -TestSummary $testSummary
                        $htmlDashboard | Set-Content -Path $htmlPath -Encoding UTF8
                        Write-TestLog "HTML dashboard saved: $htmlPath" -Level 'Success'
                    }
                }
            }
        }
        
        # Update README files if requested
        if ($UpdateReadme) {
            Update-ReadmeFiles -TestSummary $testSummary
        }
        
        $reportingTime = (Get-Date) - $reportingStartTime
        $script:TestSession.Metrics.ReportingTime = $reportingTime.TotalSeconds
        
        Write-TestLog "Reports generated successfully" -Level 'Success'
        
    } catch {
        Write-TestLog "Report generation failed: $($_.Exception.Message)" -Level 'Error'
    }
}

# Generate JUnit XML report
function New-JUnitReport {
    param([hashtable]$TestSummary)
    
    $xml = @"
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="AitherZero Unified Tests" tests="$($TestSummary.TotalTests)" failures="$($TestSummary.FailedTests)" skipped="$($TestSummary.SkippedTests)" time="$($TestSummary.Duration)">
"@
    
    foreach ($result in $TestSummary.TestResults) {
        $xml += @"
    <testsuite name="$($result.TestFile)" tests="$($result.TotalCount)" failures="$($result.FailedCount)" skipped="$($result.SkippedCount)" time="$($result.Duration)">
"@
        
        if ($result.FailedTests -and $result.FailedTests.Count -gt 0) {
            foreach ($failedTest in $result.FailedTests) {
                $xml += @"
        <testcase name="$failedTest" classname="$($result.Category)">
            <failure message="Test failed">$($result.Error)</failure>
        </testcase>
"@
            }
        }
        
        $xml += @"
    </testsuite>
"@
    }
    
    $xml += @"
</testsuites>
"@
    
    return $xml
}

# Generate HTML dashboard
function New-HTMLDashboard {
    param([hashtable]$TestSummary)
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero Test Dashboard</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { color: #2c3e50; margin: 0; }
        .header p { color: #7f8c8d; margin: 5px 0; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric { background: #ecf0f1; padding: 20px; border-radius: 8px; text-align: center; }
        .metric h3 { margin: 0 0 10px 0; color: #2c3e50; }
        .metric .value { font-size: 2em; font-weight: bold; }
        .success { color: #27ae60; }
        .failure { color: #e74c3c; }
        .warning { color: #f39c12; }
        .info { color: #3498db; }
        .results-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        .results-table th, .results-table td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        .results-table th { background-color: #34495e; color: white; }
        .status-passed { background-color: #d5edda; color: #155724; }
        .status-failed { background-color: #f8d7da; color: #721c24; }
        .footer { text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #7f8c8d; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 AitherZero Test Dashboard</h1>
            <p>Unified Test Results - $($TestSummary.Configuration.TestSuite) Suite</p>
            <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        </div>
        
        <div class="metrics">
            <div class="metric">
                <h3>Overall Status</h3>
                <div class="value $(if ($TestSummary.Success) { 'success' } else { 'failure' })">$(if ($TestSummary.Success) { '✅ PASSED' } else { '❌ FAILED' })</div>
            </div>
            <div class="metric">
                <h3>Success Rate</h3>
                <div class="value $(if ($TestSummary.QualityMetrics.SuccessRate -ge 90) { 'success' } elseif ($TestSummary.QualityMetrics.SuccessRate -ge 70) { 'warning' } else { 'failure' })">$($TestSummary.QualityMetrics.SuccessRate)%</div>
            </div>
            <div class="metric">
                <h3>Total Tests</h3>
                <div class="value info">$($TestSummary.TotalTests)</div>
            </div>
            <div class="metric">
                <h3>Duration</h3>
                <div class="value info">$([math]::Round($TestSummary.Duration, 2))s</div>
            </div>
            <div class="metric">
                <h3>Tests/Second</h3>
                <div class="value info">$($TestSummary.QualityMetrics.Performance.TestsPerSecond)</div>
            </div>
            <div class="metric">
                <h3>Platform</h3>
                <div class="value info">$($TestSummary.Platform.OS)</div>
            </div>
        </div>
        
        <h2>Test Results by File</h2>
        <table class="results-table">
            <thead>
                <tr>
                    <th>Test File</th>
                    <th>Category</th>
                    <th>Status</th>
                    <th>Passed</th>
                    <th>Failed</th>
                    <th>Skipped</th>
                    <th>Duration</th>
                </tr>
            </thead>
            <tbody>
"@
    
    foreach ($result in $TestSummary.TestResults) {
        $statusClass = if ($result.Result -eq 'Passed') { 'status-passed' } else { 'status-failed' }
        $html += @"
                <tr class="$statusClass">
                    <td>$($result.TestFile)</td>
                    <td>$($result.Category)</td>
                    <td>$($result.Result)</td>
                    <td>$($result.PassedCount)</td>
                    <td>$($result.FailedCount)</td>
                    <td>$($result.SkippedCount)</td>
                    <td>$([math]::Round($result.Duration, 2))s</td>
                </tr>
"@
    }
    
    $html += @"
            </tbody>
        </table>
        
        <div class="footer">
            <p>Generated by AitherZero Unified Test Runner v1.0.0</p>
            <p>PowerShell $($TestSummary.Platform.PowerShellVersion) on $($TestSummary.Platform.OS)</p>
        </div>
    </div>
</body>
</html>
"@
    
    return $html
}

# Update README files
function Update-ReadmeFiles {
    param([hashtable]$TestSummary)
    
    try {
        Write-TestLog "Updating README.md files with test results..." -Level 'Info'
        
        # Load TestingFramework module if available
        $testingFrameworkPath = Join-Path $script:ProjectRoot "aither-core/modules/TestingFramework"
        if (Test-Path $testingFrameworkPath) {
            Import-Module $testingFrameworkPath -Force -ErrorAction SilentlyContinue
            
            if (Get-Command Update-ReadmeTestStatus -ErrorAction SilentlyContinue) {
                $readmeResults = [PSCustomObject]@{
                    TotalCount = $TestSummary.TotalTests
                    PassedCount = $TestSummary.PassedTests
                    FailedCount = $TestSummary.FailedTests
                    Duration = [TimeSpan]::FromSeconds($TestSummary.Duration)
                    Timestamp = Get-Date
                }
                
                Update-ReadmeTestStatus -UpdateAll -TestResults $readmeResults
                Write-TestLog "README.md files updated successfully" -Level 'Success'
            }
        }
    } catch {
        Write-TestLog "Failed to update README files: $($_.Exception.Message)" -Level 'Warning'
    }
}

# Show test summary
function Show-TestSummary {
    Write-ProgressUpdate -Activity "Complete" -Status "Showing summary" -PercentComplete 100
    
    $duration = (Get-Date) - $script:TestSession.StartTime
    
    Write-Host ""
    if ($CI) {
        Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                    TEST SUMMARY                              ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    } else {
        Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║              AitherZero Unified Test Summary                 ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    }
    Write-Host ""
    
    # Overall status
    $overallStatus = if ($script:TestSession.FailedTests -eq 0) { '✅ PASSED' } else { '❌ FAILED' }
    $statusColor = if ($script:TestSession.FailedTests -eq 0) { 'Green' } else { 'Red' }
    
    Write-Host "  Overall Status: $overallStatus" -ForegroundColor $statusColor
    Write-Host "  Test Suite: $($script:TestSession.Configuration.TestSuite)" -ForegroundColor White
    Write-Host "  Platform: $($script:TestSession.Platform.OS)" -ForegroundColor White
    Write-Host "  PowerShell: $($script:TestSession.Platform.PowerShellVersion)" -ForegroundColor White
    Write-Host ""
    
    # Test statistics
    Write-Host "  Test Results:" -ForegroundColor White
    Write-Host "    Total Tests: $($script:TestSession.TotalTests)" -ForegroundColor Cyan
    Write-Host "    Passed: $($script:TestSession.PassedTests)" -ForegroundColor Green
    Write-Host "    Failed: $($script:TestSession.FailedTests)" -ForegroundColor $(if ($script:TestSession.FailedTests -eq 0) { 'Green' } else { 'Red' })
    Write-Host "    Skipped: $($script:TestSession.SkippedTests)" -ForegroundColor Yellow
    Write-Host ""
    
    # Performance metrics
    Write-Host "  Performance Metrics:" -ForegroundColor White
    Write-Host "    Duration: $([math]::Round($script:TestSession.Duration.TotalSeconds, 2))s" -ForegroundColor Cyan
    Write-Host "    Tests/Second: $($script:TestSession.Metrics.TestsPerSecond)" -ForegroundColor Cyan
    Write-Host "    Avg Test Duration: $($script:TestSession.Metrics.AverageTestDuration)s" -ForegroundColor Cyan
    
    if ($script:TestSession.Metrics.ParallelEfficiency -gt 0) {
        Write-Host "    Parallel Efficiency: $($script:TestSession.Metrics.ParallelEfficiency)%" -ForegroundColor Cyan
    }
    
    Write-Host ""
    
    # Success rate
    $successRate = if ($script:TestSession.TotalTests -gt 0) { ($script:TestSession.PassedTests / $script:TestSession.TotalTests) * 100 } else { 0 }
    $successRateColor = if ($successRate -ge 90) { 'Green' } elseif ($successRate -ge 70) { 'Yellow' } else { 'Red' }
    Write-Host "  Success Rate: $([math]::Round($successRate, 1))%" -ForegroundColor $successRateColor
    
    # Test files summary
    if ($script:TestSession.TestResults.Count -gt 0) {
        Write-Host ""
        Write-Host "  Test Files:" -ForegroundColor White
        foreach ($result in $script:TestSession.TestResults) {
            $status = if ($result.Result -eq 'Passed') { "✅" } else { "❌" }
            Write-Host "    $status $($result.TestFile) - $($result.PassedCount)/$($result.TotalCount) in $([math]::Round($result.Duration, 2))s" -ForegroundColor $(if ($result.Result -eq 'Passed') { 'Green' } else { 'Red' })
        }
    }
    
    # Show errors if any
    if ($script:TestSession.Errors.Count -gt 0) {
        Write-Host ""
        Write-Host "  Errors:" -ForegroundColor Red
        foreach ($error in $script:TestSession.Errors) {
            Write-Host "    • $error" -ForegroundColor Red
        }
    }
    
    # Show warnings if any
    if ($script:TestSession.Warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "  Warnings:" -ForegroundColor Yellow
        foreach ($warning in $script:TestSession.Warnings) {
            Write-Host "    • $warning" -ForegroundColor Yellow
        }
    }
    
    # Report locations
    Write-Host ""
    Write-Host "  Reports:" -ForegroundColor White
    Write-Host "    Report Directory: $script:ReportPath" -ForegroundColor Cyan
    
    $reportFiles = Get-ChildItem $script:ReportPath -Filter "*test*" -ErrorAction SilentlyContinue
    foreach ($reportFile in $reportFiles) {
        Write-Host "    • $($reportFile.Name)" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Next steps
    if ($script:TestSession.FailedTests -eq 0) {
        Write-Host "  🎉 All tests passed! System is ready for use." -ForegroundColor Green
    } else {
        Write-Host "  💡 Recommendations:" -ForegroundColor Yellow
        Write-Host "     • Check failed tests for specific issues" -ForegroundColor White
        Write-Host "     • Review error messages and logs" -ForegroundColor White
        Write-Host "     • Run with -WhatIf to see test details" -ForegroundColor White
    }
    
    Write-Host ""
}

# Main execution function
function Start-UnifiedTestRunner {
    try {
        # Initialize
        Show-UnifiedTestBanner
        Get-GitInformation
        
        # Validate prerequisites
        if (-not (Test-Prerequisites)) {
            Write-TestLog "Prerequisites validation failed" -Level 'Error'
            exit 1
        }
        
        # Get test files
        $testFiles = Get-TestFiles
        
        if ($testFiles.Count -eq 0) {
            Write-TestLog "No test files found for suite: $TestSuite" -Level 'Warning'
            exit 0
        }
        
        # Show what would be run in WhatIf mode
        if ($WhatIf) {
            Write-TestLog "WhatIf Mode - Tests that would be run:" -Level 'Info'
            foreach ($testFile in $testFiles) {
                Write-TestLog "  ✓ $($testFile.Name) - Category: $($testFile.Category), Duration: ~$($testFile.EstimatedDuration)s" -Level 'Info'
            }
            $totalDuration = ($testFiles | Measure-Object -Property EstimatedDuration -Sum).Sum
            Write-TestLog "Total estimated duration: $totalDuration seconds" -Level 'Info'
            return
        }
        
        Write-TestLog "Found $($testFiles.Count) test files to execute" -Level 'Success'
        
        # Execute tests
        $testSuccess = $false
        
        if ($Distributed) {
            $testSuccess = Invoke-DistributedTests
            if (-not $testSuccess) {
                Write-TestLog "Falling back to centralized testing" -Level 'Warning'
                $testSuccess = Invoke-CentralizedTests -TestFiles $testFiles
            }
        } else {
            $testSuccess = Invoke-CentralizedTests -TestFiles $testFiles
        }
        
        if (-not $testSuccess) {
            Write-TestLog "Test execution failed" -Level 'Error'
            exit 1
        }
        
        # Calculate metrics and generate reports
        Update-TestMetrics
        New-TestReports
        
        # Show summary
        Show-TestSummary
        
        # Exit with appropriate code
        if ($script:TestSession.FailedTests -gt 0) {
            Write-TestLog "Tests completed with failures" -Level 'Error'
            exit 1
        } else {
            Write-TestLog "All tests completed successfully" -Level 'Success'
            exit 0
        }
        
    } catch {
        Write-TestLog "Unified test runner failed: $($_.Exception.Message)" -Level 'Error'
        Write-TestLog "Stack trace: $($_.ScriptStackTrace)" -Level 'Debug'
        exit 1
    } finally {
        # Clean up progress indicators
        Write-Progress -Activity "Complete" -Completed
    }
}

# Script entry point
if ($MyInvocation.InvocationName -ne '.') {
    Start-UnifiedTestRunner
}