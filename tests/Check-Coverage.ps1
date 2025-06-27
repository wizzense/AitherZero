#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Quick code coverage check for AitherZero modules

.DESCRIPTION
    This script provides a quick way to check code coverage for specific modules
    or the entire codebase. It's designed for rapid feedback during development.

.PARAMETER Module
    Specific module to check coverage for. If not specified, checks all modules.

.PARAMETER Quick
    Run only essential tests for faster results

.PARAMETER ShowUncovered
    Display list of uncovered commands/lines

.EXAMPLE
    .\Check-Coverage.ps1 -Module Logging

.EXAMPLE
    .\Check-Coverage.ps1 -Quick -ShowUncovered
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Module,

    [Parameter()]
    [switch]$Quick,

    [Parameter()]
    [switch]$ShowUncovered
)

Write-Host '📊 Quick Coverage Check' -ForegroundColor Cyan
Write-Host ('=' * 40)

# Find project root
. "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Determine what to test
if ($Module) {
    Write-Host "Module: $Module" -ForegroundColor Yellow
    $testPath = Join-Path $projectRoot 'tests' 'unit' 'modules' $Module
    $coveragePath = Join-Path $projectRoot 'aither-core' 'modules' $Module '*.ps1'
} else {
    Write-Host "Scope: All Modules" -ForegroundColor Yellow
    $testPath = Join-Path $projectRoot 'tests' 'unit' 'modules'
    $coveragePath = Join-Path $projectRoot 'aither-core' 'modules' '*' '*.ps1'
}

# Configure Pester
$config = New-PesterConfiguration
$config.Run.Path = $testPath
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Minimal'

# Configure code coverage
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = $coveragePath
$config.CodeCoverage.ExcludeTests = $true
$config.CodeCoverage.UseBreakpoints = $false
$config.CodeCoverage.SingleHitBreakpoints = $true

# Add test filter for quick mode
if ($Quick) {
    $config.Filter.ExcludeTag = @('Slow', 'Integration')
}

Write-Host "Running tests..." -ForegroundColor Gray
$result = Invoke-Pester -Configuration $config

# Display results
$coverage = $result.CodeCoverage
$coveragePercent = if ($coverage.NumberOfCommandsAnalyzed -gt 0) {
    [Math]::Round(($coverage.NumberOfCommandsExecuted / $coverage.NumberOfCommandsAnalyzed) * 100, 2)
} else { 0 }

Write-Host "`n📈 COVERAGE SUMMARY" -ForegroundColor Cyan
Write-Host ('=' * 40)

$color = if ($coveragePercent -ge 80) { 'Green' } elseif ($coveragePercent -ge 60) { 'Yellow' } else { 'Red' }
Write-Host "Overall Coverage: $coveragePercent%" -ForegroundColor $color
Write-Host "Commands: $($coverage.NumberOfCommandsExecuted)/$($coverage.NumberOfCommandsAnalyzed)"

# Show uncovered items if requested
if ($ShowUncovered -and $coverage.MissedCommands.Count -gt 0) {
    Write-Host "`n❌ UNCOVERED ITEMS" -ForegroundColor Red
    $groupedMissed = $coverage.MissedCommands | Group-Object File
    foreach ($group in $groupedMissed) {
        $fileName = Split-Path $group.Name -Leaf
        Write-Host "`n  $fileName" -ForegroundColor Yellow
        $group.Group | Select-Object -First 5 | ForEach-Object {
            Write-Host "    Line $($_.Line): $($_.Command)" -ForegroundColor Gray
        }
        if ($group.Count -gt 5) {
            Write-Host "    ... and $($group.Count - 5) more" -ForegroundColor DarkGray
        }
    }
}

# Quick recommendation
Write-Host "`n💡 RECOMMENDATION" -ForegroundColor Cyan
if ($coveragePercent -ge 80) {
    Write-Host "✅ Excellent coverage! Keep it up." -ForegroundColor Green
} elseif ($coveragePercent -ge 60) {
    Write-Host "⚠️  Good coverage, but room for improvement." -ForegroundColor Yellow
    Write-Host "   Consider adding tests for critical paths." -ForegroundColor Gray
} else {
    Write-Host "❌ Low coverage detected." -ForegroundColor Red
    Write-Host "   Add more tests to improve reliability." -ForegroundColor Gray
}

# Return coverage percentage for automation
return $coveragePercent
