#Requires -Version 7.0

<#
.SYNOPSIS
    Intelligent test runner with caching and incremental testing
.DESCRIPTION
    Smart test execution that:
    - Checks cache for recent results
    - Runs only necessary tests based on changes
    - Provides AI-friendly concise output
    - Minimizes redundant test executions

    Exit Codes:
    0   - Tests passed (from cache or execution)
    1   - One or more tests failed
    2   - Test execution error
    3   - Skipped (recent cache hit)

.NOTES
    Stage: Testing
    Order: 0411
    Dependencies: 0400
    Tags: testing, smart, cache, incremental, ai-optimized
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path,
    [string]$TestType = 'Unit',
    [switch]$ForceRun,
    [switch]$UseCache = $true,
    [switch]$Incremental = $true,
    [int]$CacheMinutes = 5,
    [switch]$Verbose,
    [switch]$AIOutput = $true,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0411
    Dependencies = @('0400')
    Tags = @('testing', 'smart', 'cache', 'incremental', 'ai-optimized')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

# Import modules
$projectRoot = Split-Path $PSScriptRoot -Parent
$testCacheModule = Join-Path $projectRoot "domains/testing/TestCacheManager.psm1"
$loggingModule = Join-Path $projectRoot "domains/utilities/Logging.psm1"

if (Test-Path $testCacheModule) {
    Import-Module $testCacheModule -Force
}

if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
}

function Write-SmartTestLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if ($AIOutput) {
        # Concise output for AI agents
        switch ($Level) {
            'Error' { Write-Host "❌ $Message" -ForegroundColor Red }
            'Warning' { Write-Host "⚠️ $Message" -ForegroundColor Yellow }
            'Success' { Write-Host "✅ $Message" -ForegroundColor Green }
            'Cache' { Write-Host "💾 $Message" -ForegroundColor Cyan }
            'Skip' { Write-Host "⏭️ $Message" -ForegroundColor Gray }
            default { Write-Host "ℹ️ $Message" }
        }
    } else {
        # Standard logging
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message $Message -Level $Level -Source "0411_Test-Smart"
        } else {
            Write-Host "[$Level] $Message"
        }
    }
}

function Get-TestContext {
    # Analyze current context to determine test needs
    $context = @{
        ProjectRoot = $projectRoot
        TestPath = if ($Path) { $Path } else { Join-Path $projectRoot "tests/$($TestType.ToLower())" }
        SourcePath = Join-Path $projectRoot "domains"
        RecentChanges = @()
        LastTestRun = $null
    }

    # Find recent changes
    $context.RecentChanges = Get-ChildItem -Path $context.SourcePath -Recurse -File -Include "*.ps1", "*.psm1" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-$CacheMinutes) }

    # Check for recent test runs in results directory
    $resultsPath = Join-Path $projectRoot "tests/results"
    if (Test-Path $resultsPath) {
        $recentResults = Get-ChildItem -Path $resultsPath -Filter "*Tests-Summary-*.json" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($recentResults -and $recentResults.LastWriteTime -gt (Get-Date).AddMinutes(-$CacheMinutes)) {
            $context.LastTestRun = Get-Content $recentResults.FullName -Raw | ConvertFrom-Json
            $context.LastTestRunTime = $recentResults.LastWriteTime
        }
    }

    return $context
}

try {
    Write-SmartTestLog "Smart Test Runner initiated"

    if ($DryRun) {
        Write-SmartTestLog "DRY RUN MODE - No tests will be executed" -Level Warning
    }

    # Get test context
    $context = Get-TestContext

    # Generate cache key
    $cacheKey = if (Get-Command Get-TestCacheKey -ErrorAction SilentlyContinue) {
        Get-TestCacheKey -TestPath $context.TestPath -TestType $TestType
    } else {
        $null
    }

    # Check if we should run tests
    if (-not $ForceRun -and $UseCache) {
        if (Get-Command Test-ShouldRunTests -ErrorAction SilentlyContinue) {
            $testDecision = Test-ShouldRunTests -TestPath $context.TestPath -SourcePath $context.SourcePath -MinutesSinceLastRun $CacheMinutes

            if (-not $testDecision.ShouldRun) {
                Write-SmartTestLog "Tests skipped: $($testDecision.Reason)" -Level Skip

                # Return cached results if available
                if ($testDecision.LastRun) {
                    Write-SmartTestLog "Using cached results:" -Level Cache
                    Write-Host ""
                    Write-Host "📊 Cached Test Results ($(([DateTime]::Now - [DateTime]::Parse($testDecision.LastRun.Timestamp)).TotalMinutes) min ago):"
                    Write-Host "  Total: $($testDecision.LastRun.Summary.TotalTests)"
                    Write-Host "  ✅ Passed: $($testDecision.LastRun.Summary.Passed)"
                    Write-Host "  ❌ Failed: $($testDecision.LastRun.Summary.Failed)"
                    Write-Host "  ⏱️ Duration: $($testDecision.LastRun.Summary.Duration)s"

                    if ($testDecision.LastRun.Summary.Failed -eq 0) {
                        exit 3  # Special code for successful cache hit
                    } else {
                        exit 1  # Previous failures still relevant
                    }
                }

                # Or use context last run
                if ($context.LastTestRun -and $context.LastTestRunTime) {
                    $minutesAgo = [Math]::Round(([DateTime]::Now - $context.LastTestRunTime).TotalMinutes, 1)
                    Write-SmartTestLog "Using recent test results from $minutesAgo minutes ago:" -Level Cache
                    Write-Host ""
                    Write-Host "📊 Recent Test Results:"
                    Write-Host "  Total: $($context.LastTestRun.TotalTests)"
                    Write-Host "  ✅ Passed: $($context.LastTestRun.Passed)"
                    Write-Host "  ❌ Failed: $($context.LastTestRun.Failed)"
                    Write-Host "  ⏱️ Duration: $([Math]::Round($context.LastTestRun.Duration, 1))s"

                    if ($context.LastTestRun.Failed -eq 0) {
                        exit 3
                    } else {
                        exit 1
                    }
                }
            }
        }
    }

    # Check for cached results
    if ($UseCache -and $cacheKey) {
        if (Get-Command Get-CachedTestResult -ErrorAction SilentlyContinue) {
            $cachedResult = Get-CachedTestResult -CacheKey $cacheKey -SourcePath $context.SourcePath

            if ($cachedResult) {
                Write-SmartTestLog "Valid cache hit! Returning cached results" -Level Cache
                Write-Host ""
                Write-Host "📊 Cached Test Results:"
                Write-Host "  Total: $($cachedResult.TotalTests)"
                Write-Host "  ✅ Passed: $($cachedResult.Passed)"
                Write-Host "  ❌ Failed: $($cachedResult.Failed)"
                Write-Host "  ⏱️ Duration: $($cachedResult.Duration)s"

                if ($cachedResult.Failed -eq 0) {
                    Write-SmartTestLog "All tests passed (cached)" -Level Success
                    exit 0
                } else {
                    Write-SmartTestLog "$($cachedResult.Failed) tests failed (cached)" -Level Error
                    exit 1
                }
            }
        }
    }

    # Determine test scope for incremental testing
    $testScope = $null
    if ($Incremental -and $context.RecentChanges.Count -gt 0) {
        if (Get-Command Get-IncrementalTestScope -ErrorAction SilentlyContinue) {
            $testScope = Get-IncrementalTestScope -BasePath $projectRoot -ChangedFiles $context.RecentChanges.FullName

            if ($testScope.All) {
                Write-SmartTestLog "Core files changed - running all tests" -Level Warning
            } elseif ($testScope.Modules.Count -gt 0) {
                Write-SmartTestLog "Running tests for changed modules: $($testScope.Modules -join ', ')"
            }
        }
    }

    if ($DryRun) {
        Write-SmartTestLog "Would execute tests:" -Level Information
        Write-Host "  Path: $($context.TestPath)"
        Write-Host "  Type: $TestType"
        Write-Host "  Incremental: $Incremental"
        if ($testScope) {
            Write-Host "  Scope: $(if ($testScope.All) { 'All' } else { $testScope.Modules -join ', ' })"
        }
        exit 0
    }

    # Execute tests (delegate to standard test runner with optimizations)
    Write-SmartTestLog "Executing $TestType tests..."

    $testScript = Join-Path $PSScriptRoot "0402_Run-UnitTests.ps1"
    $testParams = @{
        Path = $context.TestPath
        NoCoverage = $true  # Skip coverage for speed in smart mode
        CI = $true
        PassThru = $true
    }

    # Add scope restrictions if incremental
    if ($testScope -and -not $testScope.All -and $testScope.Modules.Count -gt 0) {
        # Modify path to only test specific modules
        $testPaths = $testScope.Modules | ForEach-Object {
            $modulePath = Join-Path $context.TestPath "$_.Tests.ps1"
            if (Test-Path $modulePath) { $modulePath }
        }
        if ($testPaths) {
            $testParams.Path = $testPaths
        }
    }

    # Run tests
    if ($PSCmdlet.ShouldProcess("$TestType tests", "Execute test suite")) {
        $result = & $testScript @testParams
    } else {
        Write-SmartTestLog "WhatIf: Would execute $TestType tests" -Level Information
        return @{
            TotalCount = 0
            PassedCount = 0
            FailedCount = 0
            SkippedCount = 0
            Duration = [TimeSpan]::Zero
        }
    }

    # Cache successful results
    if ($result -and $UseCache -and $cacheKey) {
        if (Get-Command Set-CachedTestResult -ErrorAction SilentlyContinue) {
            $cacheData = @{
                TotalTests = $result.TotalCount
                Passed = $result.PassedCount
                Failed = $result.FailedCount
                Skipped = $result.SkippedCount
                Duration = $result.Duration.TotalSeconds
                Timestamp = (Get-Date).ToString('o')
            }
            if ($PSCmdlet.ShouldProcess("Test results", "Cache test results")) {
                Set-CachedTestResult -CacheKey $cacheKey -Result ([PSCustomObject]$cacheData) -SourcePath $context.SourcePath
                Write-SmartTestLog "Results cached for future use" -Level Cache
            }
        }
    }

    # AI-friendly output
    if ($AIOutput) {
        Write-Host ""
        Write-Host "📊 Test Execution Summary:"
        Write-Host "  Total: $($result.TotalCount)"
        Write-Host "  ✅ Passed: $($result.PassedCount)"
        Write-Host "  ❌ Failed: $($result.FailedCount)"
        Write-Host "  ⏱️ Duration: $([Math]::Round($result.Duration.TotalSeconds, 1))s"

        if ($result.FailedCount -gt 0) {
            Write-Host ""
            Write-Host "Failed tests require attention:"
            $result.Failed | Select-Object -First 3 | ForEach-Object {
                Write-Host "  - $($_.Name)"
            }
            if ($result.FailedCount -gt 3) {
                Write-Host "  ... and $($result.FailedCount - 3) more"
            }
        }
    }

    # Exit based on results
    if ($result.FailedCount -eq 0) {
        Write-SmartTestLog "All tests passed!" -Level Success
        exit 0
    } else {
        Write-SmartTestLog "$($result.FailedCount) tests failed" -Level Error
        exit 1
    }

} catch {
    Write-SmartTestLog "Test execution error: $_" -Level Error
    if ($Verbose) {
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
    exit 2
}