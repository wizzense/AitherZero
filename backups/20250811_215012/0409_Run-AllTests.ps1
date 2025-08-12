#Requires -Version 7.0

<#
.SYNOPSIS
    Execute all tests for AitherZero (unit, integration, E2E)
.DESCRIPTION
    Runs all test suites without tag filtering
    
    Exit Codes:
    0   - All tests passed
    1   - One or more tests failed
    2   - Test execution error
    
.NOTES
    Stage: Testing
    Order: 0409
    Dependencies: 0400
    Tags: testing, all-tests, pester, coverage
#>

param(
    [string]$Path = (Join-Path (Split-Path $PSScriptRoot -Parent) "tests"),
    [string]$OutputPath,
    [switch]$DryRun,
    [switch]$PassThru,
    [switch]$NoCoverage,
    [switch]$CI
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0409
    Dependencies = @('0400')
    Tags = @('testing', 'all-tests', 'pester', 'coverage')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

# Import modules
$projectRoot = Split-Path $PSScriptRoot -Parent
$testingModule = Join-Path $projectRoot "domains/testing/TestingFramework.psm1"
$loggingModule = Join-Path $projectRoot "domains/utilities/Logging.psm1"

if (Test-Path $testingModule) {
    Import-Module $testingModule -Force
}

if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
    $script:LoggingAvailable = $true
} else {
    $script:LoggingAvailable = $false
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0409_Run-AllTests" -Data $Data
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
    Write-ScriptLog -Message "Starting all tests execution"

    # Check if running in DryRun mode
    if ($DryRun) {
        Write-ScriptLog -Message "DRY RUN: Would execute all tests"
        Write-ScriptLog -Message "Test path: $Path"
        Write-ScriptLog -Message "Coverage enabled: $(-not $NoCoverage)"
        
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
        Write-ScriptLog -Message "No tests to run"
        exit 0
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

    # NO TAG FILTERING - RUN ALL TESTS
    # This is the key difference from 0402_Run-UnitTests.ps1
    Write-ScriptLog -Message "Running ALL tests (no tag filtering)"

    # Output configuration
    if (-not $OutputPath) {
        $OutputPath = Join-Path $projectRoot "tests/results"
    }

    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $pesterConfig.TestResult.Enabled = $true
    $pesterConfig.TestResult.OutputPath = Join-Path $OutputPath "AllTests-$timestamp.xml"
    $pesterConfig.TestResult.OutputFormat = 'NUnitXml'

    # Code coverage configuration
    if (-not $NoCoverage -and $testingConfig.CodeCoverage.Enabled) {
        Write-ScriptLog -Message "Configuring code coverage"
        $pesterConfig.CodeCoverage.Enabled = $true
        $pesterConfig.CodeCoverage.Path = @(
            Join-Path $projectRoot 'domains'
            Join-Path $projectRoot 'AitherZero.psm1'
            Join-Path $projectRoot 'Start-AitherZero.ps1'
        )
        $pesterConfig.CodeCoverage.OutputPath = Join-Path $OutputPath "Coverage-All-$timestamp.xml"
        $pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
    }

    # Performance tracking
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Start-PerformanceTrace -Name "AllTests" -Description "All tests execution"
    }
    
    Write-ScriptLog -Message "Executing all tests..."
    $result = Invoke-Pester -Configuration $pesterConfig

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        $duration = Stop-PerformanceTrace -Name "AllTests"
    }

    # Log results
    $testSummary = @{
        TotalTests = $result.TotalCount
        Passed = $result.PassedCount
        Failed = $result.FailedCount
        Skipped = $result.SkippedCount
        Duration = if ($duration) { $duration.TotalSeconds } else { $result.Duration.TotalSeconds }
    }
    
    Write-ScriptLog -Message "All tests execution completed" -Data $testSummary

    # Display summary
    Write-Host "`nAll Tests Summary:" -ForegroundColor Cyan
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
    $summaryPath = Join-Path $OutputPath "AllTests-Summary-$timestamp.json"
    $testSummary | ConvertTo-Json | Set-Content -Path $summaryPath
    Write-ScriptLog -Message "Test summary saved to: $summaryPath"

    # Return result if PassThru
    if ($PassThru) {
        return $result
    }

    # Exit based on test results
    if ($result.FailedCount -eq 0) {
        Write-ScriptLog -Message "All tests passed!"
        exit 0
    } else {
        Write-ScriptLog -Level Error -Message "$($result.FailedCount) tests failed"
        exit 1
    }
}
catch {
    $errorMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    Write-ScriptLog -Level Error -Message "Test execution failed: $_" -Data @{ Exception = $errorMsg }
    exit 2
}