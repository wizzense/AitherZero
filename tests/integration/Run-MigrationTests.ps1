#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Run CI/CD migration validation tests
.DESCRIPTION
    Helper script to run all workflow migration validation tests with proper configuration.
.PARAMETER TestType
    Type of tests to run: All, PR, Deploy, Release, E2E
.PARAMETER Verbosity
    Pester output verbosity: None, Normal, Detailed, Diagnostic
.PARAMETER ShowHelp
    Display usage information
.EXAMPLE
    ./Run-MigrationTests.ps1
    Run all migration tests with normal output
.EXAMPLE
    ./Run-MigrationTests.ps1 -TestType PR -Verbosity Detailed
    Run only PR check tests with detailed output
.EXAMPLE
    ./Run-MigrationTests.ps1 -TestType E2E
    Run only end-to-end validation tests
#>

param(
    [Parameter()]
    [ValidateSet('All', 'PR', 'Deploy', 'Release', 'E2E')]
    [string]$TestType = 'All',
    
    [Parameter()]
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Verbosity = 'Normal',
    
    [Parameter()]
    [switch]$ShowHelp
)

if ($ShowHelp) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

# Ensure we're in the repository root
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CI/CD Migration Validation Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Import Pester
Write-Host "Loading Pester..." -ForegroundColor Yellow
Import-Module Pester -Force -ErrorAction Stop

# Define test files
$testFiles = @{
    'PR'      = './tests/integration/workflow-pr-check-migration.Tests.ps1'
    'Deploy'  = './tests/integration/workflow-deploy-migration.Tests.ps1'
    'Release' = './tests/integration/workflow-release-migration.Tests.ps1'
    'E2E'     = './tests/integration/workflow-migration-e2e.Tests.ps1'
}

# Select tests to run
$testsToRun = if ($TestType -eq 'All') {
    $testFiles.Values
} else {
    @($testFiles[$TestType])
}

Write-Host "Test Type: $TestType" -ForegroundColor Cyan
Write-Host "Verbosity: $Verbosity" -ForegroundColor Cyan
Write-Host "Tests to run: $($testsToRun.Count)" -ForegroundColor Cyan
Write-Host ""

# Verify all test files exist
$missingTests = @()
foreach ($testFile in $testsToRun) {
    if (-not (Test-Path $testFile)) {
        $missingTests += $testFile
    }
}

if ($missingTests.Count -gt 0) {
    Write-Host "ERROR: Missing test files:" -ForegroundColor Red
    $missingTests | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

# Configure Pester
$config = New-PesterConfiguration

$config.Run.Path = $testsToRun
$config.Run.Exit = $false
$config.Run.PassThru = $true
$config.Output.Verbosity = $Verbosity
$config.Filter.Tag = 'Migration'

# Output configuration
Write-Host "Running tests..." -ForegroundColor Yellow
Write-Host ""

# Run tests
$result = Invoke-Pester -Configuration $config

# Display summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Results Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$passRate = if ($result.TotalCount -gt 0) {
    [math]::Round(($result.PassedCount / $result.TotalCount) * 100, 2)
} else {
    0
}

Write-Host "Total Tests:   $($result.TotalCount)" -ForegroundColor White
Write-Host "Passed:        $($result.PassedCount)" -ForegroundColor Green
Write-Host "Failed:        $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "Skipped:       $($result.SkippedCount)" -ForegroundColor Gray
Write-Host "Pass Rate:     $passRate%" -ForegroundColor Cyan
Write-Host "Duration:      $([math]::Round($result.Duration.TotalSeconds, 2)) seconds" -ForegroundColor Gray
Write-Host ""

# Check for failures
if ($result.FailedCount -gt 0) {
    Write-Host "❌ Some tests failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Failed Tests:" -ForegroundColor Yellow
    
    # Extract failed test names if available
    $result.Failed | ForEach-Object {
        Write-Host "  - $($_.ExpandedName)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Re-run with -Verbosity Detailed for more information" -ForegroundColor Yellow
    Write-Host ""
    exit 1
} else {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
    Write-Host ""
    exit 0
}
