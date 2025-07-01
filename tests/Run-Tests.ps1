#!/usr/bin/env pwsh
#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Simplified test runner for AitherZero test suite
.DESCRIPTION
    Runs tests with automatic discovery, parallel execution, and coverage reporting
.PARAMETER Module
    Run tests for a specific module
.PARAMETER Type
    Type of tests to run: Unit, Integration, E2E, Performance, or All
.PARAMETER Coverage
    Enable code coverage reporting
.PARAMETER FailFast
    Stop on first test failure
.PARAMETER Parallel
    Run tests in parallel (default: true)
.EXAMPLE
    ./Run-Tests.ps1
.EXAMPLE
    ./Run-Tests.ps1 -Module Logging -Coverage
.EXAMPLE
    ./Run-Tests.ps1 -Type Integration -FailFast
#>

[CmdletBinding()]
param(
    [string]$Module,
    [ValidateSet('Unit', 'Integration', 'E2E', 'Performance', 'All')]
    [string]$Type = 'All',
    [switch]$Coverage,
    [switch]$FailFast,
    [switch]$Parallel = $true,
    [int]$MaxJobs = 4
)

# Initialize
$startTime = Get-Date
$exitCode = 0

Write-Host "`n🧪 AitherZero Test Runner" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Find project root
$projectRoot = $PSScriptRoot | Split-Path -Parent
$env:PROJECT_ROOT = $projectRoot
$env:PWSH_MODULES_PATH = Join-Path $projectRoot 'aither-core/modules'

# Ensure Pester is available
if (-not (Get-Module -Name Pester -ListAvailable | Where-Object Version -ge 5.0)) {
    Write-Host "❌ Pester 5.0+ is required. Installing..." -ForegroundColor Red
    Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser
}

Import-Module Pester -MinimumVersion 5.0

# Build test paths based on parameters
$testPaths = @()

if ($Type -eq 'All') {
    $testPaths += @('Unit', 'Integration', 'E2E', 'Performance') | ForEach-Object {
        Join-Path $PSScriptRoot $_
    }
} else {
    $testPaths += Join-Path $PSScriptRoot $Type
}

# Filter by module if specified
if ($Module) {
    $testPaths = $testPaths | ForEach-Object {
        $modulePath = Join-Path $_ $Module
        if (Test-Path $modulePath) { $modulePath }
        else { 
            Get-ChildItem $_ -Filter "*$Module*.Tests.ps1" -Recurse -File | 
                Select-Object -ExpandProperty DirectoryName -Unique
        }
    } | Where-Object { $_ }
    
    if (-not $testPaths) {
        Write-Host "❌ No tests found for module: $Module" -ForegroundColor Red
        exit 1
    }
}

# Configure Pester
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = $testPaths
$pesterConfig.Run.Exit = $false
$pesterConfig.Run.PassThru = $true
$pesterConfig.Output.Verbosity = 'Normal'
$pesterConfig.Should.ErrorAction = if ($FailFast) { 'Stop' } else { 'Continue' }

# Configure parallel execution
if ($Parallel -and $testPaths.Count -gt 1) {
    # Run tests in parallel using jobs
    Write-Host "🚀 Running tests in parallel (Max Jobs: $MaxJobs)" -ForegroundColor Yellow
    $pesterConfig.Run.Container = $testPaths | ForEach-Object {
        New-PesterContainer -Path $_
    }
} else {
    Write-Host "📝 Running tests sequentially" -ForegroundColor Yellow
}

# Configure code coverage
if ($Coverage) {
    Write-Host "📊 Code coverage enabled" -ForegroundColor Yellow
    $pesterConfig.CodeCoverage.Enabled = $true
    $pesterConfig.CodeCoverage.Path = @(
        Join-Path $projectRoot 'aither-core/modules/*/*.psm1'
        Join-Path $projectRoot 'aither-core/modules/*/*.ps1'
        Join-Path $projectRoot 'aither-core/*.ps1'
    )
    $pesterConfig.CodeCoverage.ExcludeTests = $true
    $pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
    $pesterConfig.CodeCoverage.OutputPath = Join-Path $PSScriptRoot 'Coverage/coverage.xml'
    $pesterConfig.CodeCoverage.UseBreakpoints = $false
}

# Display configuration
Write-Host "`n📋 Configuration:" -ForegroundColor Cyan
Write-Host "  Module Filter: $(if ($Module) { $Module } else { 'All' })"
Write-Host "  Test Type: $Type"
Write-Host "  Coverage: $($Coverage.IsPresent)"
Write-Host "  Fail Fast: $($FailFast.IsPresent)"
Write-Host "  Parallel: $Parallel"
Write-Host "`n"

# Run tests
try {
    $results = Invoke-Pester -Configuration $pesterConfig
    
    # Display results summary
    Write-Host "`n📊 Test Results Summary" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Total Tests: $($results.TotalCount)" -ForegroundColor White
    Write-Host "Passed: $($results.PassedCount)" -ForegroundColor Green
    Write-Host "Failed: $($results.FailedCount)" -ForegroundColor $(if ($results.FailedCount -eq 0) { 'Green' } else { 'Red' })
    Write-Host "Skipped: $($results.SkippedCount)" -ForegroundColor Yellow
    Write-Host "NotRun: $($results.NotRunCount)" -ForegroundColor Gray
    
    # Display coverage if enabled
    if ($Coverage -and $results.CodeCoverage) {
        Write-Host "`n📊 Code Coverage" -ForegroundColor Cyan
        Write-Host "================================" -ForegroundColor Cyan
        $coverage = $results.CodeCoverage.CoveragePercent
        $coverageColor = if ($coverage -ge 80) { 'Green' } elseif ($coverage -ge 60) { 'Yellow' } else { 'Red' }
        Write-Host "Overall Coverage: $([math]::Round($coverage, 2))%" -ForegroundColor $coverageColor
        
        # Save coverage summary
        $coverageSummary = @{
            Date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            Coverage = $coverage
            Passed = $results.PassedCount
            Failed = $results.FailedCount
            Total = $results.TotalCount
        }
        $coverageSummary | ConvertTo-Json | Set-Content (Join-Path $PSScriptRoot 'Coverage/summary.json')
    }
    
    # Display failed tests
    if ($results.FailedCount -gt 0) {
        Write-Host "`n❌ Failed Tests:" -ForegroundColor Red
        $results.Failed | ForEach-Object {
            Write-Host "  - $($_.ExpandedPath)" -ForegroundColor Red
            Write-Host "    $($_.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed
        }
        $exitCode = 1
    }
    
} catch {
    Write-Host "`n❌ Test execution failed: $_" -ForegroundColor Red
    $exitCode = 1
}

# Display execution time
$duration = (Get-Date) - $startTime
Write-Host "`n⏱️  Total Duration: $([math]::Round($duration.TotalSeconds, 2))s" -ForegroundColor Cyan

# Exit with appropriate code
exit $exitCode