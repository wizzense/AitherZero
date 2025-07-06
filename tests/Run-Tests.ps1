#Requires -Version 7.0

param(
    [switch]$Quick,
    [switch]$Setup,
    [switch]$All,
    [switch]$CI
)

# Simple test runner - no complexity, just run tests

$ErrorActionPreference = 'Stop'
$testPath = $PSScriptRoot

# Install Pester if needed (CI environments)
if ($CI -and -not (Get-Module -ListAvailable -Name Pester | Where-Object Version -ge '5.0.0')) {
    Write-Host "Installing Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
}

# Import Pester
Import-Module Pester -MinimumVersion 5.0.0

# Determine which tests to run
$testsToRun = @()

if ($All) {
    Write-Host "Running ALL tests..." -ForegroundColor Cyan
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

# Run tests
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
Write-Host "`nTest Results:" -ForegroundColor White
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