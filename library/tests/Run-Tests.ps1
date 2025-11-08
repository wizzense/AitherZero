#Requires -Version 7.0

<#
.SYNOPSIS
    Master test orchestration script for AitherZero

.DESCRIPTION
    Orchestrates the execution of all test types based on profiles
    and generates comprehensive reports

.EXAMPLE
    ./Run-Tests.ps1 -Profile Quick
    
.EXAMPLE
    ./Run-Tests.ps1 -Profile Standard -GenerateReport
    
.EXAMPLE
    ./Run-Tests.ps1 -Profile Full -Parallel -MaxParallel 16
#>

[CmdletBinding()]
param(
    [ValidateSet('Quick', 'Standard', 'Full', 'CI', 'Developer', 'Release')]
    [string]$Profile = 'Standard',
    
    [switch]$Parallel,
    [int]$MaxParallel = 8,
    [switch]$GenerateReport,
    [switch]$GenerateCoverage,
    [switch]$StopOnFirstFailure,
    [string]$OutputPath = (Join-Path $PSScriptRoot 'results')
)

$ErrorActionPreference = 'Stop'

# Import test helpers
$testHelpersPath = Join-Path $PSScriptRoot 'helpers/TestHelpers.psm1'
if (Test-Path $testHelpersPath) {
    Import-Module $testHelpersPath -Force
}

Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         AitherZero Test Suite - Profile: $Profile         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Load test profile
$profilePath = Join-Path $PSScriptRoot "config/test-profiles.psd1"
if (-not (Test-Path $profilePath)) {
    throw "Test profile configuration not found: $profilePath"
}

$profiles = Import-PowerShellDataFile -Path $profilePath
$config = $profiles[$Profile]

if (-not $config) {
    throw "Profile not found: $Profile"
}

Write-Host "Profile: $($config.Name)" -ForegroundColor Yellow
Write-Host "Description: $($config.Description)" -ForegroundColor Gray
Write-Host "Expected Duration: $($config.Duration)" -ForegroundColor Gray
Write-Host ""

# Initialize test environment
Initialize-TestEnvironment

# Results tracking
$results = @{
    Profile = $Profile
    StartTime = Get-Date
    Tests = @()
    Summary = @{
        Total = 0
        Passed = 0
        Failed = 0
        Skipped = 0
    }
}

# Helper function to run tests
function Invoke-TestSuite {
    param(
        [string]$Name,
        [string]$Path,
        [hashtable]$Config
    )
    
    Write-Host "┌─────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ $Name" -ForegroundColor Cyan
    Write-Host "└─────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
    
    if (-not (Test-Path $Path)) {
        Write-Host "  ⚠ Path not found: $Path" -ForegroundColor Yellow
        return
    }
    
    $pesterConfig = New-PesterConfiguration
    $pesterConfig.Run.Path = $Path
    $pesterConfig.Output.Verbosity = 'Detailed'
    $pesterConfig.Run.Exit = $false
    
    if ($GenerateCoverage -and $Config.GenerateCoverage) {
        $coveragePath = Join-Path (Get-TestFilePath '') 'aithercore/**/*.psm1'
        $pesterConfig.CodeCoverage.Enabled = $true
        $pesterConfig.CodeCoverage.Path = $coveragePath
    }
    
    try {
        $testResult = Invoke-Pester -Configuration $pesterConfig
        
        $results.Tests += @{
            Name = $Name
            Path = $Path
            Passed = $testResult.PassedCount
            Failed = $testResult.FailedCount
            Skipped = $testResult.SkippedCount
            Total = $testResult.TotalCount
            Duration = $testResult.Duration
        }
        
        $results.Summary.Total += $testResult.TotalCount
        $results.Summary.Passed += $testResult.PassedCount
        $results.Summary.Failed += $testResult.FailedCount
        $results.Summary.Skipped += $testResult.SkippedCount
        
        if ($testResult.FailedCount -gt 0) {
            Write-Host "  ❌ Failed: $($testResult.FailedCount)" -ForegroundColor Red
            if ($StopOnFirstFailure) {
                throw "Tests failed, stopping execution"
            }
        }
        else {
            Write-Host "  ✅ All tests passed!" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ❌ Error running tests: $_" -ForegroundColor Red
        throw
    }
    
    Write-Host ""
}

# Execute test suites based on profile
$basePath = $PSScriptRoot

# Unit Tests
if ($config.Include.Unit) {
    if ($config.Include.Unit.Modules) {
        $modulesPath = Join-Path $basePath 'unit/modules'
        Invoke-TestSuite -Name "Unit Tests: Modules" -Path $modulesPath -Config $config.Options
    }
    
    if ($config.Include.Unit.Scripts) {
        $scriptsPath = Join-Path $basePath 'unit/scripts'
        Invoke-TestSuite -Name "Unit Tests: Scripts" -Path $scriptsPath -Config $config.Options
    }
    
    if ($config.Include.Unit.Workflows) {
        $workflowsPath = Join-Path $basePath 'unit/workflows'
        Invoke-TestSuite -Name "Unit Tests: Workflows" -Path $workflowsPath -Config $config.Options
    }
}

# Integration Tests
if ($config.Include.Integration) {
    if ($config.Include.Integration.Modules) {
        $integrationPath = Join-Path $basePath 'integration/modules'
        Invoke-TestSuite -Name "Integration Tests: Modules" -Path $integrationPath -Config $config.Options
    }
    
    if ($config.Include.Integration.Playbooks) {
        $playbooksPath = Join-Path $basePath 'integration/playbooks'
        Invoke-TestSuite -Name "Integration Tests: Playbooks" -Path $playbooksPath -Config $config.Options
    }
}

# E2E Tests
if ($config.Include.E2E) {
    $e2ePath = Join-Path $basePath 'e2e'
    Invoke-TestSuite -Name "End-to-End Tests" -Path $e2ePath -Config $config.Options
}

# Quality Tests
if ($config.Include.Quality) {
    $qualityPath = Join-Path $basePath 'quality'
    Invoke-TestSuite -Name "Quality Validation" -Path $qualityPath -Config $config.Options
}

# Performance Tests
if ($config.Include.Performance) {
    $performancePath = Join-Path $basePath 'performance'
    Invoke-TestSuite -Name "Performance Tests" -Path $performancePath -Config $config.Options
}

# Calculate results
$results.EndTime = Get-Date
$results.Duration = $results.EndTime - $results.StartTime

# Display summary
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    Test Summary                          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Profile: $Profile" -ForegroundColor Yellow
Write-Host "Duration: $($results.Duration.ToString('mm\:ss'))" -ForegroundColor Gray
Write-Host ""
Write-Host "Total Tests: $($results.Summary.Total)" -ForegroundColor White
Write-Host "✅ Passed: $($results.Summary.Passed)" -ForegroundColor Green
Write-Host "❌ Failed: $($results.Summary.Failed)" -ForegroundColor Red
Write-Host "⚠ Skipped: $($results.Summary.Skipped)" -ForegroundColor Yellow
Write-Host ""

$passRate = if ($results.Summary.Total -gt 0) {
    [math]::Round(($results.Summary.Passed / $results.Summary.Total) * 100, 2)
} else { 0 }

Write-Host "Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 95) { 'Green' } elseif ($passRate -ge 80) { 'Yellow' } else { 'Red' })

# Generate report if requested
if ($GenerateReport -or $config.Options.GenerateReport) {
    Write-Host ""
    Write-Host "Generating test report..." -ForegroundColor Cyan
    
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    $reportPath = Join-Path $OutputPath "test-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $results | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath
    
    Write-Host "Report saved: $reportPath" -ForegroundColor Green
}

# Clean up
Clear-TestEnvironment

# Exit with appropriate code
if ($results.Summary.Failed -gt 0) {
    exit 1
}

exit 0
