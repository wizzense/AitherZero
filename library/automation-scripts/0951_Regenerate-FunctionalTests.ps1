#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Regenerate ALL tests with enhanced functional testing
.DESCRIPTION
    Uses the new EnhancedTestGenerator to create MEANINGFUL tests that validate
    actual functionality, not just structure.
    
    This replaces the old auto-generated "file exists" tests with tests that:
    - ✅ Validate structure (file, syntax, parameters)
    - ✅ Test functionality (behavior, outputs, exit codes)
    - ✅ Test error handling (edge cases, invalid inputs)
    - ✅ Mock external dependencies (network calls, file operations)
    
.PARAMETER Mode
    Regeneration mode:
    - Sample: Regenerate 5 scripts as examples
    - Range: Regenerate specific range (e.g., 0400-0499)
    - All: Regenerate ALL 316 tests (takes time!)
    
.PARAMETER Force
    Overwrite existing tests
    
.PARAMETER TestType
    Type of tests to generate (Structural, Functional, Integration, All)
    
.EXAMPLE
    # Regenerate sample scripts to see the difference
    ./0951_Regenerate-EnhancedTests.ps1 -Mode Sample
    
.EXAMPLE
    # Regenerate all testing scripts (0400-0499)
    ./0951_Regenerate-EnhancedTests.ps1 -Mode Range -Range "0400-0499" -Force
    
.EXAMPLE
    # Regenerate everything
    ./0951_Regenerate-EnhancedTests.ps1 -Mode All -Force
    
.NOTES
    Stage: Testing
    Order: 0951
    Dependencies: EnhancedTestGenerator module
    Tags: testing, generation, overhaul, functional-tests
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Sample', 'Range', 'All')]
    [string]$Mode = 'Sample',
    
    [string]$Range,
    
    [ValidateSet('Structural', 'Functional', 'Integration', 'All')]
    [string]$TestType = 'All',
    
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path $PSScriptRoot -Parent
$testGeneratorPath = Join-Path $projectRoot "aithercore/testing/FunctionalTestGenerator.psm1"

# Banner
Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Functional Test Regeneration v2.0                      ║" -ForegroundColor Cyan
Write-Host "║     Comprehensive Behavioral & Integration Testing         ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Load generator
if (-not (Test-Path $testGeneratorPath)) {
    Write-Host "❌ Test generator not found: $testGeneratorPath" -ForegroundColor Red
    exit 1
}

try {
    Import-Module $testGeneratorPath -Force -ErrorAction Stop
    Write-Host "✅ Functional test generator loaded" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to load generator: $_" -ForegroundColor Red
    exit 1
}

# Get scripts to regenerate
$scriptsToRegenerate = switch ($Mode) {
    'Sample' {
        # Sample: 5 representative scripts
        $sampleScripts = @(
            '0402_Run-UnitTests.ps1',
            '0404_Run-PSScriptAnalyzer.ps1',
            '0407_Validate-Syntax.ps1',
            '0510_Generate-ProjectReport.ps1',
            '0512_Generate-Dashboard.ps1'
        )
        
        foreach ($scriptName in $sampleScripts) {
            $scriptPath = Join-Path $projectRoot "automation-scripts/$scriptName"
            if (Test-Path $scriptPath) {
                Get-Item $scriptPath
            }
        }
    }
    'Range' {
        if (-not $Range) {
            Write-Host "❌ -Range parameter required for Range mode" -ForegroundColor Red
            exit 1
        }
        
        $rangePattern = "$Range/*.ps1"
        Get-ChildItem -Path (Join-Path $projectRoot "automation-scripts") -Filter "*.ps1" |
            Where-Object { $_.Name -match "^$($Range.Split('-')[0])" }
    }
    'All' {
        Get-ChildItem -Path (Join-Path $projectRoot "automation-scripts") -Filter "*.ps1" -File
    }
}

if ($scriptsToRegenerate.Count -eq 0) {
    Write-Host "⚠️  No scripts found to regenerate" -ForegroundColor Yellow
    exit 0
}

Write-Host "📋 Found $($scriptsToRegenerate.Count) scripts to regenerate" -ForegroundColor Cyan
Write-Host "   Mode: $Mode"
Write-Host "   Test Type: $TestType"
Write-Host "   Force: $Force"
Write-Host ""

# Confirm if All mode
if ($Mode -eq 'All' -and -not $Force) {
    $response = Read-Host "⚠️  Regenerate ALL $($scriptsToRegenerate.Count) tests? This will take time! (y/N)"
    if ($response -ne 'y') {
        Write-Host "❌ Cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Regenerate tests
$results = @{
    Total = 0
    Generated = 0
    Skipped = 0
    Failed = 0
}

$startTime = Get-Date

foreach ($scriptFile in $scriptsToRegenerate) {
    $results.Total++
    
    try {
        $result = New-FunctionalTest -ScriptPath $scriptFile.FullName -TestType $TestType -Force:$Force
        
        if ($result.Generated) {
            $results.Generated++
            Write-Host "  ✅ $($scriptFile.Name) - $($result.TestCount) tests" -ForegroundColor Green
        } elseif ($result.Skipped) {
            $results.Skipped++
            Write-Host "  ⏭️  $($scriptFile.Name) - Skipped (exists)" -ForegroundColor Yellow
        } else {
            $results.Failed++
            Write-Host "  ❌ $($scriptFile.Name) - Failed" -ForegroundColor Red
        }
    } catch {
        $results.Failed++
        Write-Host "  ❌ $($scriptFile.Name) - Error: $_" -ForegroundColor Red
    }
    
    # Progress indicator
    if ($results.Total % 10 -eq 0) {
        $percent = [math]::Round(($results.Total / $scriptsToRegenerate.Count) * 100, 0)
        Write-Host "`n  Progress: $percent% ($($results.Total)/$($scriptsToRegenerate.Count))`n" -ForegroundColor Cyan
    }
}

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

# Summary
Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         Functional Test Regeneration Complete!             ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "📊 Summary:" -ForegroundColor Cyan
Write-Host "  Total Scripts:  $($results.Total)"
Write-Host "  Generated:      " -NoNewline
Write-Host "$($results.Generated)" -ForegroundColor Green
Write-Host "  Skipped:        " -NoNewline
Write-Host "$($results.Skipped)" -ForegroundColor Yellow
Write-Host "  Failed:         " -NoNewline
Write-Host "$($results.Failed)" -ForegroundColor $(if ($results.Failed -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Duration:       $([math]::Round($duration, 1))s"
Write-Host ""

# Show example
if ($results.Generated -gt 0) {
    Write-Host "💡 Example Test Generated:" -ForegroundColor Cyan
    Write-Host "   Location: library/tests/unit/automation-scripts/" -ForegroundColor White
    Write-Host "   Features: ✅ Structural ✅ Functional ✅ Error Handling ✅ Mocks" -ForegroundColor White
    Write-Host ""
    Write-Host "   To run: Invoke-Pester -Path library/tests/unit/automation-scripts/" -ForegroundColor Yellow
    Write-Host ""
}

# Next steps
if ($Mode -eq 'Sample') {
    Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Review generated tests in library/tests/unit/automation-scripts/"
    Write-Host "   2. Run them: Invoke-Pester -Path library/tests/unit/automation-scripts/0400-0499/"
    Write-Host "   3. If satisfied, regenerate more: -Mode Range or -Mode All"
    Write-Host ""
}

exit $(if ($results.Failed -gt 0) { 1 } else { 0 })
