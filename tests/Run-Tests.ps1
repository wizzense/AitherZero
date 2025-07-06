#Requires -Version 7.0

param(
    [switch]$Quick,
    [switch]$Setup,
    [switch]$All,
    [switch]$CI,
    [switch]$Distributed,
    [string[]]$Modules = @()
)

# Enhanced test runner - supports centralized and distributed tests

$ErrorActionPreference = 'Stop'
$testPath = $PSScriptRoot
$projectRoot = Split-Path $testPath -Parent

# Install Pester if needed (CI environments)
if ($CI -and -not (Get-Module -ListAvailable -Name Pester | Where-Object Version -ge '5.0.0')) {
    Write-Host "Installing Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
}

# Import Pester
Import-Module Pester -MinimumVersion 5.0.0

# Handle distributed testing
if ($Distributed) {
    Write-Host "Running distributed tests using TestingFramework..." -ForegroundColor Cyan
    
    # Import TestingFramework for distributed testing
    $testingFrameworkPath = Join-Path $projectRoot "aither-core/modules/TestingFramework"
    if (Test-Path $testingFrameworkPath) {
        Import-Module $testingFrameworkPath -Force
        
        # Determine test suite based on parameters
        $testSuite = if ($All) { "All" }
                    elseif ($Setup) { "Environment" } 
                    else { "Unit" }
        
        # Configure execution parameters
        $executionParams = @{
            TestSuite = $testSuite
            TestProfile = if ($CI) { "CI" } else { "Development" }
            GenerateReport = $true
            Parallel = -not $CI  # Use parallel for non-CI runs
        }
        
        # Add specific modules if specified
        if ($Modules.Count -gt 0) {
            $executionParams.Modules = $Modules
            Write-Host "Testing specific modules: $($Modules -join ', ')" -ForegroundColor Yellow
        }
        
        # Execute distributed tests
        $results = Invoke-UnifiedTestExecution @executionParams
        
        # Calculate summary from distributed results
        $totalPassed = ($results | Measure-Object -Property TestsPassed -Sum).Sum
        $totalFailed = ($results | Measure-Object -Property TestsFailed -Sum).Sum
        $totalCount = $totalPassed + $totalFailed
        $totalDuration = ($results | Measure-Object -Property Duration -Sum).Sum
        
        # Display distributed test summary
        Write-Host "`nDistributed Test Results:" -ForegroundColor White
        Write-Host "  Modules Tested: $(($results | Select-Object -ExpandProperty Module -Unique).Count)" -ForegroundColor Cyan
        Write-Host "  Passed: $totalPassed " -ForegroundColor Green
        Write-Host "  Failed: $totalFailed " -ForegroundColor $(if ($totalFailed -eq 0) { 'Green' } else { 'Red' })
        Write-Host "  Total:  $totalCount" -ForegroundColor White
        Write-Host "  Time:   $($totalDuration.ToString('0.00'))s" -ForegroundColor Cyan
        
        # Exit with proper code for CI
        if ($CI -and $totalFailed -gt 0) {
            exit 1
        }
        
        return
    } else {
        Write-Host "⚠️  TestingFramework not found, falling back to centralized tests" -ForegroundColor Yellow
    }
}

# Standard centralized testing (original behavior)
$testsToRun = @()

if ($All) {
    Write-Host "Running ALL centralized tests..." -ForegroundColor Cyan
    $testsToRun = @(
        Join-Path $testPath "Core.Tests.ps1"
        Join-Path $testPath "Setup.Tests.ps1"
    )
} elseif ($Setup) {
    Write-Host "Running Setup tests..." -ForegroundColor Cyan
    $testsToRun = @(Join-Path $testPath "Setup.Tests.ps1")
} else {
    # Default to Quick (Core tests only)
    Write-Host "Running Core tests..." -ForegroundColor Cyan
    $testsToRun = @(Join-Path $testPath "Core.Tests.ps1")
}

# Run centralized tests
$config = @{
    Path = $testsToRun
    Output = 'Detailed'
    PassThru = $true
}

if ($CI) {
    $config.Output = 'Minimal'
}

$results = Invoke-Pester @config

# Simple result summary
Write-Host "`nCentralized Test Results:" -ForegroundColor White
Write-Host "  Passed: $($results.Passed) " -ForegroundColor Green
Write-Host "  Failed: $($results.Failed) " -ForegroundColor $(if ($results.Failed -eq 0) { 'Green' } else { 'Red' })
Write-Host "  Total:  $($results.TotalCount)" -ForegroundColor White
Write-Host "  Time:   $($results.Duration.TotalSeconds.ToString('0.00'))s" -ForegroundColor Cyan

# Exit with proper code for CI
if ($CI) {
    # Ensure we have valid results object
    if ($null -eq $results) {
        Write-Error "Test execution failed - no results returned"
        exit 1
    }
    
    # Check for failures
    $failureCount = if ($null -ne $results.Failed) { $results.Failed } else { 0 }
    if ($failureCount -gt 0) {
        exit 1
    }
}