# Note: Tests work best with PowerShell 7.0+ but will attempt to run on older versions

<#
.SYNOPSIS
    Optimized test runner for CI/CD environments
.DESCRIPTION
    Runs focused, fast tests suitable for CI/CD pipelines with minimal dependencies
.PARAMETER TestSuite
    Which test suite to run: Core, Entry, PowerShell, All
.PARAMETER OutputFormat
    Output format: Console, JUnit, Both
.PARAMETER Timeout
    Test execution timeout in seconds (default: 300)
.EXAMPLE
    ./Run-CI-Tests.ps1 -TestSuite All -OutputFormat Both
#>

param(
    [ValidateSet('Core', 'Entry', 'PowerShell', 'All')]
    [string]$TestSuite = 'All',

    [ValidateSet('Console', 'JUnit', 'Both')]
    [string]$OutputFormat = 'Both',

    [int]$Timeout = 300
)

# Set error handling
$ErrorActionPreference = 'Stop'

Write-Host "`n🚀 AitherZero CI Test Runner" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor $(if($PSVersionTable.PSVersion.Major -ge 7){"Green"}else{"Yellow"})
Write-Host "Test Suite: $TestSuite" -ForegroundColor Yellow
Write-Host "Output Format: $OutputFormat" -ForegroundColor Yellow
Write-Host "Timeout: ${Timeout}s" -ForegroundColor Yellow
Write-Host ""

# Warn if not on PS7+
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "Some tests require PowerShell 7.0+. They will be skipped on version $($PSVersionTable.PSVersion)"
}

# Set platform-specific environment variables
if ($env:CI_PLATFORM) {
    Write-Host "Running on CI platform: $env:CI_PLATFORM" -ForegroundColor Cyan
    $env:AITHER_PLATFORM = $env:CI_PLATFORM
}

# Performance optimization settings
$performanceMode = $env:PERFORMANCE_MODE -eq "optimized"
$enableParallelTests = $env:ENABLE_PARALLEL_TESTS -eq "true"
if ($performanceMode) {
    Write-Host "Performance mode: ENABLED" -ForegroundColor Green
    $Timeout = [Math]::Min($Timeout, 300)  # Reduce timeout for performance
}
if ($enableParallelTests) {
    Write-Host "Parallel tests: ENABLED" -ForegroundColor Green
}

# Ensure Pester is available with caching optimization
if (-not (Get-Module -ListAvailable Pester)) {
    Write-Host "Installing Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -AllowClobber -Scope CurrentUser -MinimumVersion 5.0.0 -SkipPublisherCheck
} else {
    Write-Host "Pester already available (cached)" -ForegroundColor Green
}

# Import ParallelExecution module if available for performance optimization
$parallelExecutionPath = "./aither-core/modules/ParallelExecution"
if ($enableParallelTests -and (Test-Path $parallelExecutionPath)) {
    try {
        Import-Module $parallelExecutionPath -Force
        Write-Host "ParallelExecution module loaded for optimization" -ForegroundColor Green
        $useParallel = $true
    } catch {
        Write-Host "ParallelExecution import failed: $($_.Exception.Message)" -ForegroundColor Yellow
        $useParallel = $false
    }
} else {
    $useParallel = $false
}

Import-Module Pester -Force

# Test definitions
$tests = @{
    'Core' = @{
        Path = './tests/Core.Tests.ps1'
        Description = 'Core functionality and module loading'
        OutputFile = 'core-test-results.xml'
    }
    'Entry' = @{
        Path = './tests/EntryPoint-Validation.Tests.ps1'
        Description = 'Entry point validation and launcher scripts'
        OutputFile = 'entry-test-results.xml'
    }
    'PowerShell' = @{
        Path = './tests/PowerShell-Version.Tests.ps1'
        Description = 'PowerShell version compatibility'
        OutputFile = 'ps-version-test-results.xml'
    }
}

# Determine which tests to run
$testsToRun = if ($TestSuite -eq 'All') {
    $tests.Keys
} else {
    @($TestSuite)
}

$allResults = @()
$totalTests = 0
$totalPassed = 0
$totalFailed = 0
$startTime = Get-Date

try {
    if ($useParallel -and $testsToRun.Count -gt 1) {
        # Parallel test execution for performance
        Write-Host "🚀 Running tests in parallel for performance optimization..." -ForegroundColor Green
        
        $parallelResults = Invoke-ParallelForEach -InputObject $testsToRun -ThrottleLimit 3 -ScriptBlock {
            param($testName)
            
            # Get test configuration from the global tests hashtable
            $allTests = $using:tests
            $test = $allTests[$testName]
            
            # Check if test file exists
            if (-not (Test-Path $test.Path)) {
                return [PSCustomObject]@{
                    TestSuite = $testName
                    TotalCount = 0
                    PassedCount = 0
                    FailedCount = 0
                    SkippedCount = 0
                    Duration = 0
                    Result = 'Skipped'
                    Error = "Test file not found: $($test.Path)"
                }
            }
            
            # Configure Pester
            $config = New-PesterConfiguration
            $config.Run.Path = $test.Path
            $config.Run.PassThru = $true
            $config.Output.Verbosity = 'Minimal'  # Reduce output for parallel execution
            
            # Set timeout if supported
            try {
                $config.Run.Timeout = $using:Timeout
            } catch {
                # Timeout not supported in this version
            }
            
            # Configure output formats
            if ($using:OutputFormat -in @('JUnit', 'Both')) {
                $config.TestResult.Enabled = $true
                $config.TestResult.OutputFormat = 'JUnitXml'
                $config.TestResult.OutputPath = $test.OutputFile
            }
            
            # Set environment variables for platform-specific testing
            $env:PESTER_PLATFORM = if ($using:env:CI_PLATFORM) { $using:env:CI_PLATFORM } else { "Unknown" }
            
            $testStartTime = Get-Date
            
            try {
                $results = Invoke-Pester -Configuration $config
                $testDuration = (Get-Date) - $testStartTime
                
                return [PSCustomObject]@{
                    TestSuite = $testName
                    TotalCount = $results.TotalCount
                    PassedCount = $results.PassedCount
                    FailedCount = $results.FailedCount
                    SkippedCount = $results.SkippedCount
                    Duration = $testDuration.TotalSeconds
                    Result = if ($results.FailedCount -eq 0) { 'Passed' } else { 'Failed' }
                    FailedTests = if ($results.FailedCount -gt 0) { $results.Failed | ForEach-Object { $_.ExpandedName } } else { @() }
                }
            } catch {
                $testDuration = (Get-Date) - $testStartTime
                return [PSCustomObject]@{
                    TestSuite = $testName
                    TotalCount = 0
                    PassedCount = 0
                    FailedCount = 1
                    SkippedCount = 0
                    Duration = $testDuration.TotalSeconds
                    Result = 'Failed'
                    Error = $_.Exception.Message
                }
            }
        }
        
        # Process parallel results
        foreach ($result in $parallelResults) {
            $allResults += $result
            $totalTests += $result.TotalCount
            $totalPassed += $result.PassedCount
            $totalFailed += $result.FailedCount
            
            # Report results
            $status = if ($result.FailedCount -eq 0) { "✅ PASSED" } else { "❌ FAILED" }
            Write-Host "📋 $($result.TestSuite): $status - $($result.PassedCount)/$($result.TotalCount) tests in $([math]::Round($result.Duration, 2))s" -ForegroundColor $(if ($result.FailedCount -eq 0) { 'Green' } else { 'Red' })
            
            if ($result.FailedCount -gt 0) {
                if ($result.Error) {
                    Write-Host "  Error: $($result.Error)" -ForegroundColor Red
                }
                if ($result.FailedTests) {
                    Write-Host "  Failed tests:" -ForegroundColor Red
                    foreach ($failure in $result.FailedTests) {
                        Write-Host "    - $failure" -ForegroundColor Red
                    }
                }
            }
        }
        
        Write-Host "🎯 Parallel test execution completed" -ForegroundColor Green
        
    } else {
        # Sequential test execution (fallback)
        Write-Host "⚡ Running tests sequentially..." -ForegroundColor Yellow
        
        foreach ($testName in $testsToRun) {
            $test = $tests[$testName]

            # Check if test file exists
            if (-not (Test-Path $test.Path)) {
                Write-Warning "Test file not found: $($test.Path)"
                continue
            }

            Write-Host "📋 Running $testName Tests: $($test.Description)" -ForegroundColor Yellow

            # Configure Pester
            $config = New-PesterConfiguration
            $config.Run.Path = $test.Path
            $config.Run.PassThru = $true
            $config.Output.Verbosity = if ($performanceMode) { 'Minimal' } else { 'Normal' }

            # Set timeout if supported (Pester 5.4+)
            try {
                $config.Run.Timeout = $Timeout
            } catch {
                Write-Verbose "Timeout property not supported in this Pester version"
            }

            # Configure output formats
            if ($OutputFormat -in @('JUnit', 'Both')) {
                $config.TestResult.Enabled = $true
                $config.TestResult.OutputFormat = 'JUnitXml'
                $config.TestResult.OutputPath = $test.OutputFile
            }

            # Run tests with timeout and platform awareness
            $testStartTime = Get-Date
            
            # Set environment variables for platform-specific testing
            $env:PESTER_PLATFORM = if ($env:CI_PLATFORM) { $env:CI_PLATFORM } else { "Unknown" }
            
            $results = Invoke-Pester -Configuration $config
            $testDuration = (Get-Date) - $testStartTime

            # Store results
            $allResults += [PSCustomObject]@{
                TestSuite = $testName
                TotalCount = $results.TotalCount
                PassedCount = $results.PassedCount
                FailedCount = $results.FailedCount
                SkippedCount = $results.SkippedCount
                Duration = $testDuration.TotalSeconds
                Result = if ($results.FailedCount -eq 0) { 'Passed' } else { 'Failed' }
            }

            $totalTests += $results.TotalCount
            $totalPassed += $results.PassedCount
            $totalFailed += $results.FailedCount

            # Report individual test suite results
            $status = if ($results.FailedCount -eq 0) { "✅ PASSED" } else { "❌ FAILED" }
            Write-Host "  $status - $($results.PassedCount)/$($results.TotalCount) tests in $([math]::Round($testDuration.TotalSeconds, 2))s" -ForegroundColor $(if ($results.FailedCount -eq 0) { 'Green' } else { 'Red' })

            if ($results.FailedCount -gt 0) {
                Write-Host "  Failed tests:" -ForegroundColor Red
                foreach ($failure in $results.Failed) {
                    Write-Host "    - $($failure.ExpandedName)" -ForegroundColor Red
                }
            }

            Write-Host ""
        }
    }

    # Final summary
    $totalDuration = (Get-Date) - $startTime
    Write-Host "📊 CI Test Summary" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    Write-Host "Total Tests: $totalTests" -ForegroundColor White
    Write-Host "Passed: $totalPassed" -ForegroundColor Green
    Write-Host "Failed: $totalFailed" -ForegroundColor $(if ($totalFailed -eq 0) { 'Green' } else { 'Red' })
    Write-Host "Duration: $([math]::Round($totalDuration.TotalSeconds, 2))s" -ForegroundColor Cyan
    Write-Host ""

    # Detailed results table
    if ($allResults.Count -gt 1) {
        Write-Host "📋 Test Suite Details:" -ForegroundColor Cyan
        $allResults | Format-Table -Property TestSuite, TotalCount, PassedCount, FailedCount, @{Name='Duration(s)'; Expression={[math]::Round($_.Duration, 2)}}, Result -AutoSize
    }

    # Generate summary file for CI with performance metrics
    $summary = @{
        TotalTests = $totalTests
        TotalPassed = $totalPassed
        TotalFailed = $totalFailed
        TotalDuration = $totalDuration.TotalSeconds
        TestSuites = $allResults
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Success = ($totalFailed -eq 0)
        Performance = @{
            Mode = if ($performanceMode) { 'Optimized' } else { 'Standard' }
            ParallelExecution = $useParallel
            TestsPerSecond = if ($totalDuration.TotalSeconds -gt 0) { [Math]::Round($totalTests / $totalDuration.TotalSeconds, 2) } else { 0 }
            AverageTestDuration = if ($totalTests -gt 0) { [Math]::Round($totalDuration.TotalSeconds / $totalTests, 3) } else { 0 }
        }
    }

    $summaryPath = 'ci-test-summary.json'
    $summary | ConvertTo-Json -Depth 10 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-Host "📄 Test summary exported to: $summaryPath" -ForegroundColor Blue
    
    # Update README.md files with test results
    try {
        Write-Host "📝 Updating README.md files with test results..." -ForegroundColor Cyan
        
        # Load TestingFramework module for README updates
        $testingFrameworkPath = Join-Path $PSScriptRoot "../aither-core/modules/TestingFramework"
        if (Test-Path $testingFrameworkPath) {
            Import-Module $testingFrameworkPath -Force -ErrorAction SilentlyContinue
            
            # Create test results object for README update
            $readmeResults = [PSCustomObject]@{
                TotalCount = $totalTests
                PassedCount = $totalPassed
                FailedCount = $totalFailed
                Duration = $totalDuration
                Timestamp = Get-Date
            }
            
            # Update all module README.md files
            if (Get-Command Update-ReadmeTestStatus -ErrorAction SilentlyContinue) {
                Update-ReadmeTestStatus -UpdateAll -TestResults $readmeResults
                Write-Host "✅ README.md files updated successfully" -ForegroundColor Green
            } else {
                Write-Host "⚠️  Update-ReadmeTestStatus function not available" -ForegroundColor Yellow
            }
        } else {
            Write-Host "⚠️  TestingFramework module not found for README updates" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "⚠️  Failed to update README.md files: $($_.Exception.Message)" -ForegroundColor Yellow
        # Don't fail the entire CI run because of README update issues
    }
    
    # Performance reporting
    if ($performanceMode) {
        Write-Host "🎯 Performance Summary:" -ForegroundColor Cyan
        Write-Host "  Mode: $($summary.Performance.Mode)" -ForegroundColor White
        Write-Host "  Parallel Execution: $($summary.Performance.ParallelExecution)" -ForegroundColor White
        Write-Host "  Tests/Second: $($summary.Performance.TestsPerSecond)" -ForegroundColor White
        Write-Host "  Avg Test Duration: $($summary.Performance.AverageTestDuration)s" -ForegroundColor White
        
        if ($summary.Performance.ParallelExecution) {
            Write-Host "  🚀 Parallel optimization: ENABLED" -ForegroundColor Green
        }
    }

    # Exit with appropriate code
    if ($totalFailed -gt 0) {
        Write-Host "❌ CI Tests Failed: $totalFailed tests failed" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✅ All CI Tests Passed!" -ForegroundColor Green
        exit 0
    }

} catch {
    Write-Host "💥 CI Test Execution Failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
