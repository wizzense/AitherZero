#Requires -Version 7.0

<#
.SYNOPSIS
    Generate actionable recommendations from analysis results
.DESCRIPTION
    Analyzes all metrics and generates prioritized, actionable recommendations
    for PR authors
.PARAMETER AnalysisPath
    Path to analysis-summary.json
.PARAMETER QualityPath
    Path to quality metrics JSON
.PARAMETER TestResultsPath
    Path to test results directory
.PARAMETER OutputPath
    Path for recommendations.json output
.PARAMETER PrioritizeByImpact
    Sort recommendations by impact level
.EXAMPLE
    ./0518_Generate-Recommendations.ps1 -PrioritizeByImpact
.NOTES
    Stage: Reporting
    Category: Analysis
    Order: 0518
    Tags: recommendations, analysis, actionable
#>

[CmdletBinding()]
param(
    [string]$AnalysisPath = "library/reports/analysis-summary.json",
    [string]$QualityPath = "library/reports/quality-analysis.json",
    [string]$TestResultsPath = "library/tests/results",
    [string]$OutputPath = "library/reports/recommendations.json",
    [switch]$PrioritizeByImpact
)

$ErrorActionPreference = 'Stop'

Write-Host "💡 Generating actionable recommendations" -ForegroundColor Cyan

$recommendations = @{
    generated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    items = @()
}

# Load analysis if available
if (Test-Path $AnalysisPath) {
    $analysis = Get-Content $AnalysisPath -Raw | ConvertFrom-Json
    
    # Test recommendations
    if ($analysis.tests -and $analysis.tests.failed -gt 0) {
        $recommendations.items += @{
            priority = "high"
            category = "testing"
            title = "Fix Failing Tests"
            description = "$($analysis.tests.failed) test(s) are failing"
            actions = @(
                "Run tests locally: Invoke-Pester ./tests",
                "Review test output in reports/",
                "Fix issues before requesting review"
            )
            impact = "high"
        }
    }
    
    # Quality recommendations
    if ($analysis.quality -and $analysis.quality.issues.error -gt 0) {
        $recommendations.items += @{
            priority = "critical"
            category = "quality"
            title = "Address Code Quality Errors"
            description = "$($analysis.quality.issues.error) error-level PSScriptAnalyzer issue(s)"
            actions = @(
                "Run: ./library/automation-scripts/0404_Run-PSScriptAnalyzer.ps1",
                "Fix all ERROR severity issues",
                "Consider fixing WARNING issues"
            )
            impact = "critical"
        }
    }
    
    # PR size recommendations
    if ($analysis.diff -and $analysis.diff.summary.files_changed -gt 50) {
        $recommendations.items += @{
            priority = "medium"
            category = "scope"
            title = "Large PR - Consider Breaking Down"
            description = "$($analysis.diff.summary.files_changed) files changed (+$($analysis.diff.summary.additions) -$($analysis.diff.summary.deletions))"
            actions = @(
                "Review if PR can be split into smaller changes",
                "Ensure all changes are related to the same feature/fix",
                "Consider separate PRs for refactoring vs new features"
            )
            impact = "medium"
        }
    }
}

# Priority sorting
if ($PrioritizeByImpact) {
    $recommendations.items = $recommendations.items | Sort-Object {
        switch ($_.priority) {
            'critical' { 0 }
            'high' { 1 }
            'medium' { 2 }
            'low' { 3 }
            default { 4 }
        }
    }
}

# Summary
$recommendations.summary = @{
    total = $recommendations.items.Count
    critical = ($recommendations.items | Where-Object { $_.priority -eq 'critical' }).Count
    high = ($recommendations.items | Where-Object { $_.priority -eq 'high' }).Count
    medium = ($recommendations.items | Where-Object { $_.priority -eq 'medium' }).Count
    low = ($recommendations.items | Where-Object { $_.priority -eq 'low' }).Count
}

# Write output
$outputDir = Split-Path $OutputPath -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$recommendations | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

Write-Host "✅ Recommendations generated: $OutputPath" -ForegroundColor Green
Write-Host "   Total: $($recommendations.summary.total)" -ForegroundColor Cyan
Write-Host "   Critical: $($recommendations.summary.critical)" -ForegroundColor Red
Write-Host "   High: $($recommendations.summary.high)" -ForegroundColor Yellow
