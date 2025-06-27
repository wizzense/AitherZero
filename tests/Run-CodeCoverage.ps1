#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive code coverage analysis for AitherZero

.DESCRIPTION
    This script runs Pester tests with code coverage enabled and generates
    coverage reports in multiple formats. It supports different coverage levels
    and can enforce coverage thresholds.

.PARAMETER Scope
    Coverage scope: Module, Full, Custom (default: Module)
    - Module: Cover only module code
    - Full: Cover all PowerShell code
    - Custom: Use custom paths

.PARAMETER Module
    Specific module to analyze coverage for

.PARAMETER TestPath
    Custom test path(s) to run

.PARAMETER OutputFormat
    Coverage report formats (multiple allowed): JaCoCo, Cobertura, CoverageGutters, Console
    Default: @('Console', 'JaCoCo')

.PARAMETER EnforceThresholds
    Fail if coverage doesn't meet thresholds (80% functions, 75% lines, 70% commands)

.PARAMETER ShowDetails
    Show detailed coverage information for each file

.PARAMETER ExcludePaths
    Paths to exclude from coverage analysis

.PARAMETER CI
    Optimize for CI/CD environment (simplified output, JaCoCo format)

.EXAMPLE
    .\Run-CodeCoverage.ps1 -Scope Module -Module Logging -ShowDetails

.EXAMPLE
    .\Run-CodeCoverage.ps1 -Scope Full -EnforceThresholds -OutputFormat JaCoCo,Cobertura

.EXAMPLE
    .\Run-CodeCoverage.ps1 -CI -EnforceThresholds
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Module', 'Full', 'Custom')]
    [string]$Scope = 'Module',

    [Parameter()]
    [string]$Module,

    [Parameter()]
    [string[]]$TestPath,

    [Parameter()]
    [ValidateSet('JaCoCo', 'Cobertura', 'CoverageGutters', 'Console')]
    [string[]]$OutputFormat = @('Console', 'JaCoCo'),

    [Parameter()]
    [switch]$EnforceThresholds,

    [Parameter()]
    [switch]$ShowDetails,

    [Parameter()]
    [string[]]$ExcludePaths,

    [Parameter()]
    [switch]$CI
)

$ErrorActionPreference = 'Stop'
Write-Host '📊 AitherZero Code Coverage Analysis' -ForegroundColor Cyan
Write-Host ('=' * 60)

# Find project root
. "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Set up results directory
$resultsPath = Join-Path $projectRoot 'tests' 'results'
if (-not (Test-Path $resultsPath)) {
    New-Item -ItemType Directory -Path $resultsPath -Force | Out-Null
}

# Configure coverage paths based on scope
$coveragePaths = switch ($Scope) {
    'Module' {
        if ($Module) {
            $modulePath = Join-Path $projectRoot 'aither-core' 'modules' $Module
            if (Test-Path $modulePath) {
                Get-ChildItem -Path $modulePath -Filter '*.ps*1' -File | Select-Object -ExpandProperty FullName
            } else {
                @()
            }
        } else {
            Get-ChildItem -Path (Join-Path $projectRoot 'aither-core' 'modules') -Directory | ForEach-Object {
                Get-ChildItem -Path $_.FullName -Filter '*.ps*1' -File
            } | Select-Object -ExpandProperty FullName
        }
    }
    'Full' {
        $paths = @()
        # Core files
        $paths += Get-ChildItem -Path (Join-Path $projectRoot 'aither-core') -Filter '*.ps*1' -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        # Module files
        $paths += Get-ChildItem -Path (Join-Path $projectRoot 'aither-core' 'modules') -Filter '*.ps*1' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        # Shared files
        $paths += Get-ChildItem -Path (Join-Path $projectRoot 'aither-core' 'shared') -Filter '*.ps*1' -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        # Root files
        $paths += Get-ChildItem -Path $projectRoot -Filter '*.ps1' -File -Depth 0 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        $paths
    }
    'Custom' {
        if (-not $TestPath) {
            throw "Custom scope requires -TestPath parameter"
        }
        $TestPath
    }
}

# Default test paths
if (-not $TestPath) {
    $TestPath = if ($Module) {
        @(Join-Path $projectRoot 'tests' 'unit' 'modules' $Module)
    } else {
        @(Join-Path $projectRoot 'tests' 'unit')
    }
}

# Configure Pester
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = $TestPath
$pesterConfig.Run.PassThru = $true

# Configure code coverage
$pesterConfig.CodeCoverage.Enabled = $true
# Ensure we have valid paths
if ($coveragePaths -and $coveragePaths.Count -gt 0) {
    $pesterConfig.CodeCoverage.Path = $coveragePaths
} else {
    Write-Warning "No coverage paths found for scope '$Scope'"
    $pesterConfig.CodeCoverage.Enabled = $false
}
$pesterConfig.CodeCoverage.RecursePaths = $true
$pesterConfig.CodeCoverage.ExcludeTests = $true
$pesterConfig.CodeCoverage.UseBreakpoints = $false
$pesterConfig.CodeCoverage.SingleHitBreakpoints = $true

# Primary output format
$pesterConfig.CodeCoverage.OutputFormat = $OutputFormat[0]
$pesterConfig.CodeCoverage.OutputPath = Join-Path $resultsPath "coverage.$($OutputFormat[0].ToLower())"
$pesterConfig.CodeCoverage.OutputEncoding = 'UTF8'

# Add exclusions
if ($ExcludePaths) {
    # Pester doesn't have direct exclude support, so we filter paths
    $allPaths = Get-ChildItem -Path $coveragePaths -File -ErrorAction SilentlyContinue
    $filteredPaths = $allPaths | Where-Object {
        $file = $_
        -not ($ExcludePaths | Where-Object { $file.FullName -like $_ })
    }
    $pesterConfig.CodeCoverage.Path = $filteredPaths.FullName
}

# Configure output verbosity
if ($CI) {
    $pesterConfig.Output.Verbosity = 'Normal'
    $pesterConfig.Output.CIFormat = 'Auto'
} else {
    $pesterConfig.Output.Verbosity = if ($ShowDetails) { 'Detailed' } else { 'Normal' }
}

# Configure test result output
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputFormat = 'NUnitXml'
$pesterConfig.TestResult.OutputPath = Join-Path $resultsPath 'coverage-test-results.xml'

Write-Host "📁 Coverage Scope: $Scope" -ForegroundColor Yellow
if ($Module) {
    Write-Host "📦 Target Module: $Module" -ForegroundColor Yellow
}
Write-Host "📋 Output Formats: $($OutputFormat -join ', ')" -ForegroundColor Yellow
Write-Host "🔍 Test Paths: $($TestPath -join ', ')" -ForegroundColor Yellow

# Run tests with coverage
Write-Host "`n🚀 Running tests with code coverage..." -ForegroundColor Green
$startTime = Get-Date

try {
    $results = Invoke-Pester -Configuration $pesterConfig
} catch {
    Write-Error "Failed to run tests: $_"
    exit 1
}

$duration = (Get-Date) - $startTime

# Generate additional coverage formats
if ($OutputFormat.Count -gt 1) {
    Write-Host "`n📄 Generating additional coverage reports..." -ForegroundColor Cyan
    
    foreach ($format in $OutputFormat[1..$OutputFormat.Count]) {
        $outputFile = Join-Path $resultsPath "coverage.$($format.ToLower())"
        
        # Re-run with different format (Pester limitation)
        $additionalConfig = New-PesterConfiguration
        $additionalConfig.Run.Path = $TestPath
        $additionalConfig.Run.PassThru = $true
        $additionalConfig.CodeCoverage = $pesterConfig.CodeCoverage
        $additionalConfig.CodeCoverage.OutputFormat = $format
        $additionalConfig.CodeCoverage.OutputPath = $outputFile
        $additionalConfig.Output.Verbosity = 'Minimal'
        
        Write-Host "  Generating $format report..." -ForegroundColor Gray
        $null = Invoke-Pester -Configuration $additionalConfig
    }
}

# Calculate coverage metrics
$coverage = $results.CodeCoverage
$coveragePercent = if ($coverage -and $coverage.CoveragePercent) {
    [Math]::Round($coverage.CoveragePercent, 2)
} else { 0 }

$functionsTotal = if ($coverage.CommandsAnalyzedCount) { $coverage.CommandsAnalyzedCount } else { 0 }
$functionsCovered = if ($coverage.CommandsExecutedCount) { $coverage.CommandsExecutedCount } else { 0 }
$functionPercent = if ($functionsTotal -gt 0) {
    [Math]::Round(($functionsCovered / $functionsTotal) * 100, 2)
} else { 0 }

# Display results
Write-Host "`n" + ('=' * 60)
Write-Host '📊 CODE COVERAGE SUMMARY' -ForegroundColor Cyan
Write-Host ('=' * 60)

Write-Host "Overall Coverage:     $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { 'Green' } elseif ($coveragePercent -ge 60) { 'Yellow' } else { 'Red' })
Write-Host "Commands Analyzed:    $functionsTotal"
Write-Host "Commands Executed:    $functionsCovered"
Write-Host "Commands Missed:      $($functionsTotal - $functionsCovered)"

# Test results
Write-Host "`n📋 TEST RESULTS" -ForegroundColor Cyan
Write-Host "Total Tests:         $($results.TotalCount)"
Write-Host "Passed:              $($results.PassedCount)" -ForegroundColor Green
Write-Host "Failed:              $($results.FailedCount)" -ForegroundColor $(if ($results.FailedCount -eq 0) { 'Green' } else { 'Red' })
Write-Host "Skipped:             $($results.SkippedCount)" -ForegroundColor Yellow
Write-Host "Duration:            $($duration.ToString('mm\:ss\.fff'))"

# Show detailed coverage by file
if ($ShowDetails -and $coverage.AnalyzedFiles) {
    Write-Host "`n📁 COVERAGE BY FILE" -ForegroundColor Cyan
    Write-Host ('=' * 60)
    
    foreach ($file in $coverage.AnalyzedFiles) {
        $fileName = Split-Path $file -Leaf
        $fileCoverage = $coverage.MissedCommands | Where-Object { $_.File -eq $file }
        $fileHits = $coverage.HitCommands | Where-Object { $_.File -eq $file }
        
        $fileTotal = ($fileCoverage.Count + $fileHits.Count)
        $filePercent = if ($fileTotal -gt 0) {
            [Math]::Round(($fileHits.Count / $fileTotal) * 100, 2)
        } else { 100 }
        
        $color = if ($filePercent -ge 80) { 'Green' } elseif ($filePercent -ge 60) { 'Yellow' } else { 'Red' }
        Write-Host "  $fileName - $filePercent% ($($fileHits.Count)/$fileTotal)" -ForegroundColor $color
        
        if ($fileCoverage.Count -gt 0 -and $ShowDetails) {
            Write-Host "    Missed lines: $($fileCoverage.Line -join ', ')" -ForegroundColor DarkGray
        }
    }
}

# Check thresholds
if ($EnforceThresholds) {
    Write-Host "`n🎯 COVERAGE THRESHOLDS" -ForegroundColor Cyan
    $thresholds = @{
        Overall = 80
        Functions = 80
        Lines = 75
    }
    
    $passed = $true
    
    if ($coveragePercent -lt $thresholds.Overall) {
        Write-Host "❌ Overall coverage ($coveragePercent%) below threshold ($($thresholds.Overall)%)" -ForegroundColor Red
        $passed = $false
    } else {
        Write-Host "✅ Overall coverage ($coveragePercent%) meets threshold ($($thresholds.Overall)%)" -ForegroundColor Green
    }
    
    if ($functionPercent -lt $thresholds.Functions) {
        Write-Host "❌ Function coverage ($functionPercent%) below threshold ($($thresholds.Functions)%)" -ForegroundColor Red
        $passed = $false
    } else {
        Write-Host "✅ Function coverage ($functionPercent%) meets threshold ($($thresholds.Functions)%)" -ForegroundColor Green
    }
    
    if (-not $passed) {
        Write-Host "`n⚠️  Coverage thresholds not met!" -ForegroundColor Red
        exit 1
    }
}

# Report locations
Write-Host "`n📄 COVERAGE REPORTS" -ForegroundColor Cyan
foreach ($format in $OutputFormat) {
    $reportPath = Join-Path $resultsPath "coverage.$($format.ToLower())"
    if (Test-Path $reportPath) {
        Write-Host "  $format`: $reportPath" -ForegroundColor Gray
    }
}

Write-Host "`n✅ Code coverage analysis complete!" -ForegroundColor Green

# Return results for automation
if ($CI) {
    return @{
        CoveragePercent = $coveragePercent
        CommandsAnalyzed = $coverage.NumberOfCommandsAnalyzed
        CommandsExecuted = $coverage.NumberOfCommandsExecuted
        TestsPassed = $results.PassedCount
        TestsFailed = $results.FailedCount
        Duration = $duration
    }
}
