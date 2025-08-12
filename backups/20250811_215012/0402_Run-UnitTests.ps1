#Requires -Version 7.0

<#
.SYNOPSIS
    Execute unit tests for AitherZero
.DESCRIPTION
    Runs all unit tests using Pester framework with code coverage
    
    Exit Codes:
    0   - All tests passed
    1   - One or more tests failed
    2   - Test execution error
    
.NOTES
    Stage: Testing
    Order: 0402
    Dependencies: 0400
    Tags: testing, unit-tests, pester, coverage
#>

param(
    [string]$Path = (Join-Path (Split-Path $PSScriptRoot -Parent) "tests/unit"),
    [string]$OutputPath,
    [switch]$DryRun,
    [switch]$PassThru,
    [switch]$NoCoverage,
    [switch]$CI,
    [switch]$UseCache = $false,
    [switch]$ForceRun = $false,
    [int]$CacheMinutes = 5
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0402
    Dependencies = @('0400')
    Tags = @('testing', 'unit-tests', 'pester', 'coverage')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

# Import modules
$projectRoot = Split-Path $PSScriptRoot -Parent
$testingModule = Join-Path $projectRoot "domains/testing/TestingFramework.psm1"
$loggingModule = Join-Path $projectRoot "domains/utilities/Logging.psm1"
$testCacheModule = Join-Path $projectRoot "domains/testing/TestCacheManager.psm1"

if (Test-Path $testingModule) {
    Import-Module $testingModule -Force
}

if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
    $script:LoggingAvailable = $true
} else {
    $script:LoggingAvailable = $false
}

if (Test-Path $testCacheModule) {
    Import-Module $testCacheModule -Force
    $script:CacheAvailable = $true
} else {
    $script:CacheAvailable = $false
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0402_Run-UnitTests" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

try {
    Write-ScriptLog -Message "Starting unit test execution"

    # Check cache if enabled and not forced
    if ($UseCache -and -not $ForceRun -and $script:CacheAvailable) {
        Write-ScriptLog -Message "Checking test cache..."
        
        # Generate cache key
        $cacheKey = Get-TestCacheKey -TestPath $Path -TestType 'Unit'
        $sourcePath = Join-Path $projectRoot "domains"
        
        # Check if tests should run
        $testDecision = Test-ShouldRunTests -TestPath $Path -SourcePath $sourcePath -MinutesSinceLastRun $CacheMinutes
        
        if (-not $testDecision.ShouldRun) {
            Write-ScriptLog -Message "Tests skipped: $($testDecision.Reason)"
            
            if ($testDecision.LastRun) {
                Write-Host "`n📊 Cached Test Results:" -ForegroundColor Cyan
                Write-Host "  Total: $($testDecision.LastRun.Summary.TotalTests)"
                Write-Host "  ✅ Passed: $($testDecision.LastRun.Summary.Passed)" -ForegroundColor Green
                Write-Host "  ❌ Failed: $($testDecision.LastRun.Summary.Failed)" -ForegroundColor $(if ($testDecision.LastRun.Summary.Failed -gt 0) { 'Red' } else { 'Green' })
                Write-Host "  ⏱️ Duration: $($testDecision.LastRun.Summary.Duration)s"
                Write-Host "  💾 From cache ($(([DateTime]::Now - [DateTime]::Parse($testDecision.LastRun.Timestamp)).TotalMinutes) min ago)" -ForegroundColor Cyan
                
                if ($PassThru) {
                    return [PSCustomObject]@{
                        TotalCount = $testDecision.LastRun.Summary.TotalTests
                        PassedCount = $testDecision.LastRun.Summary.Passed
                        FailedCount = $testDecision.LastRun.Summary.Failed
                        Duration = [TimeSpan]::FromSeconds($testDecision.LastRun.Summary.Duration)
                        FromCache = $true
                    }
                }
                
                exit $(if ($testDecision.LastRun.Summary.Failed -eq 0) { 0 } else { 1 })
            }
        }
        
        # Try to get cached result
        $cachedResult = Get-CachedTestResult -CacheKey $cacheKey -SourcePath $sourcePath
        
        if ($cachedResult) {
            Write-ScriptLog -Message "Using cached test results"
            Write-Host "`n📊 Cached Test Results:" -ForegroundColor Cyan
            Write-Host "  Total: $($cachedResult.TotalTests)"
            Write-Host "  ✅ Passed: $($cachedResult.Passed)" -ForegroundColor Green
            Write-Host "  ❌ Failed: $($cachedResult.Failed)" -ForegroundColor $(if ($cachedResult.Failed -gt 0) { 'Red' } else { 'Green' })
            Write-Host "  ⏱️ Duration: $($cachedResult.Duration)s"
            Write-Host "  💾 From cache" -ForegroundColor Cyan
            
            if ($PassThru) {
                return [PSCustomObject]@{
                    TotalCount = $cachedResult.TotalTests
                    PassedCount = $cachedResult.Passed
                    FailedCount = $cachedResult.Failed
                    Duration = [TimeSpan]::FromSeconds($cachedResult.Duration)
                    FromCache = $true
                }
            }
            
            exit $(if ($cachedResult.Failed -eq 0) { 0 } else { 1 })
        }
    }

    # Check if running in DryRun mode
    if ($DryRun) {
        Write-ScriptLog -Message "DRY RUN: Would execute unit tests"
        Write-ScriptLog -Message "Test path: $Path"
        Write-ScriptLog -Message "Coverage enabled: $(-not $NoCoverage)"
        Write-ScriptLog -Message "Cache enabled: $UseCache"
        
        # List test files that would be run
        if (Test-Path $Path) {
            $testFiles = @(Get-ChildItem -Path $Path -Filter "*.Tests.ps1" -Recurse)
            Write-ScriptLog -Message "Found $($testFiles.Count) test files:"
            foreach ($file in $testFiles) {
                Write-ScriptLog -Message "  - $($file.Name)"
            }
        }
        exit 0
    }

    # Verify test path exists
    if (-not (Test-Path $Path)) {
        Write-ScriptLog -Level Warning -Message "Test path not found: $Path"
        Write-ScriptLog -Message "Creating test directory structure"
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

    # Get test files
    $testFiles = @(Get-ChildItem -Path $Path -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue)

    if ($testFiles.Count -eq 0) {
        Write-ScriptLog -Level Warning -Message "No test files found in: $Path"
        exit 0
    }
    
    Write-ScriptLog -Message "Found $($testFiles.Count) test files"

    # Load configuration
    $configPath = Join-Path $projectRoot "config.json"
    $testingConfig = if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $config.Testing
    } else {
        @{
            Framework = 'Pester'
            MinVersion = '5.0.0'
            CodeCoverage = @{
                Enabled = $true
                MinimumPercent = 80
            }
        }
    }

    # Ensure Pester is available
    $pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [Version]$testingConfig.MinVersion } | Sort-Object Version -Descending | Select-Object -First 1
    
    if (-not $pesterModule) {
        Write-ScriptLog -Level Error -Message "Pester $($testingConfig.MinVersion) or higher is required. Run 0400_Install-TestingTools.ps1 first."
        exit 2
    }
    
    Write-ScriptLog -Message "Loading Pester version $($pesterModule.Version)"
    Import-Module Pester -MinimumVersion $testingConfig.MinVersion -Force

    # Build Pester configuration
    $pesterConfig = New-PesterConfiguration
    $pesterConfig.Run.Path = $Path
    $pesterConfig.Run.PassThru = $true
    $pesterConfig.Run.Exit = $false

    # CI mode adjustments
    if ($CI) {
        Write-ScriptLog -Message "Running in CI mode"
        $pesterConfig.Output.Verbosity = 'Normal'
        $pesterConfig.Should.ErrorAction = 'Continue'
    }

    # Filter for unit tests only
    $pesterConfig.Filter.Tag = @('Unit')
    $pesterConfig.Filter.ExcludeTag = @('Integration', 'E2E', 'Performance')

    # Output configuration
    if (-not $OutputPath) {
        $OutputPath = Join-Path $projectRoot "tests/results"
    }

    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $pesterConfig.TestResult.Enabled = $true
    $pesterConfig.TestResult.OutputPath = Join-Path $OutputPath "UnitTests-$timestamp.xml"
    $pesterConfig.TestResult.OutputFormat = 'NUnitXml'

    # Code coverage configuration
    if (-not $NoCoverage -and $testingConfig.CodeCoverage.Enabled) {
        Write-ScriptLog -Message "Configuring code coverage"
        $pesterConfig.CodeCoverage.Enabled = $true
        $pesterConfig.CodeCoverage.Path = @(
            Join-Path $projectRoot 'domains'
            Join-Path $projectRoot 'AitherZero.psm1'
        )
    $pesterConfig.CodeCoverage.OutputPath = Join-Path $OutputPath "Coverage-Unit-$timestamp.xml"
        $pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
    }

    # Performance tracking
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Start-PerformanceTrace -Name "UnitTests" -Description "Unit test execution"
    }
    
    Write-ScriptLog -Message "Executing unit tests..."
    $result = Invoke-Pester -Configuration $pesterConfig

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        $duration = Stop-PerformanceTrace -Name "UnitTests"
    }

    # Log results
    $testSummary = @{
        TotalTests = $result.TotalCount
        Passed = $result.PassedCount
        Failed = $result.FailedCount
        Skipped = $result.SkippedCount
        Duration = if ($duration) { $duration.TotalSeconds } else { $result.Duration.TotalSeconds }
    }
    
    Write-ScriptLog -Message "Unit test execution completed" -Data $testSummary

    # Display summary
    Write-Host "`nUnit Test Summary:" -ForegroundColor Cyan
    Write-Host "  Total Tests: $($result.TotalCount)"
    Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host "  Duration: $($result.Duration.TotalSeconds.ToString('F2'))s"

    if ($pesterConfig.CodeCoverage.Enabled -and $result.CodeCoverage) {
        Write-Host "`nCode Coverage:" -ForegroundColor Cyan
        $coveragePercent = $result.CodeCoverage.CoveragePercent
        Write-Host "  Coverage: $($coveragePercent)%" -ForegroundColor $(
            if ($coveragePercent -ge $testingConfig.CodeCoverage.MinimumPercent) { 'Green' } else { 'Yellow' }
        )
    
        # Handle different Pester versions
        if ($result.CodeCoverage.PSObject.Properties['CommandsAnalyzedCount']) {
            # Pester 5.5+
            Write-Host "  Analyzed Commands: $($result.CodeCoverage.CommandsAnalyzedCount)"
            Write-Host "  Covered Commands: $($result.CodeCoverage.CommandsExecutedCount)"
            Write-Host "  Missed Commands: $($result.CodeCoverage.CommandsMissedCount)"
        } elseif ($result.CodeCoverage.PSObject.Properties['NumberOfCommandsAnalyzed']) {
            # Older Pester 5.x
            Write-Host "  Covered Commands: $($result.CodeCoverage.NumberOfCommandsAnalyzed - $result.CodeCoverage.NumberOfCommandsMissed)"
            Write-Host "  Missed Commands: $($result.CodeCoverage.NumberOfCommandsMissed)"
        } else {
            # Fallback for other versions
            Write-Host "  Files Covered: $($result.CodeCoverage.FilesAnalyzedCount ?? 'N/A')"
        }
        
        if ($coveragePercent -lt $testingConfig.CodeCoverage.MinimumPercent) {
            Write-ScriptLog -Level Warning -Message "Code coverage below minimum threshold ($($testingConfig.CodeCoverage.MinimumPercent)%)"
        }
    }

    # Display failed tests
    if ($result.FailedCount -gt 0) {
        Write-Host "`nFailed Tests:" -ForegroundColor Red
        $result.Failed | ForEach-Object {
            Write-Host "  - $($_.ExpandedPath)" -ForegroundColor Red
            if ($_.ErrorRecord -and $_.ErrorRecord.Exception) {
                Write-Host "    $($_.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed
            } elseif ($_.ErrorRecord) {
                Write-Host "    $($_.ErrorRecord)" -ForegroundColor DarkRed
            }
        }
    }

    # Save result summary
    $summaryPath = Join-Path $OutputPath "UnitTests-Summary-$timestamp.json"
    $testSummary | ConvertTo-Json | Set-Content -Path $summaryPath
    Write-ScriptLog -Message "Test summary saved to: $summaryPath"

    # Return result if PassThru
    if ($PassThru) {
        return $result
    }

    # Exit based on test results
    if ($result.FailedCount -eq 0) {
        Write-ScriptLog -Message "All unit tests passed!"
        exit 0
    } else {
        Write-ScriptLog -Level Error -Message "$($result.FailedCount) unit tests failed"
        exit 1
    }
}
catch {
    $errorMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    Write-ScriptLog -Level Error -Message "Unit test execution failed: $_" -Data @{ Exception = $errorMsg }
    exit 2
}