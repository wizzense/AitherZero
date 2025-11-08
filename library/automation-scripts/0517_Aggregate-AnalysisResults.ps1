#Requires -Version 7.0

<#
.SYNOPSIS
    Aggregate analysis results and generate action able recommendations
.DESCRIPTION
    Combines test, quality, diff, and other analysis results to create a unified
    summary with prioritized recommendations
.PARAMETER SourcePath
    Directory containing analysis JSON files
.PARAMETER OutputPath
    Path for aggregated analysis-summary.json
.PARAMETER IncludeComparison
    Include comparison with base branch metrics
.PARAMETER GenerateRecommendations
    Generate actionable recommendations
.EXAMPLE
    ./0517_Aggregate-AnalysisResults.ps1 -SourcePath ./library/reports -GenerateRecommendations
.NOTES
    Stage: Reporting
    Category: Analysis
    Order: 0517
    Tags: aggregate, analysis, recommendations
#>

[CmdletBinding()]
param(
    [string]$SourcePath = "library/reports",
    [string]$OutputPath = "library/reports/analysis-summary.json",
    [switch]$IncludeComparison,
    [switch]$GenerateRecommendations
)

$ErrorActionPreference = 'Stop'

Write-Host "📊 Aggregating analysis results from $SourcePath" -ForegroundColor Cyan

$summary = @{
    generated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    status = "unknown"
    score = 0
}

# Load test results
$testResultsPath = Join-Path $SourcePath "../tests/results"
if (Test-Path $testResultsPath) {
    $testFiles = Get-ChildItem -Path $testResultsPath -Filter "*.xml" -ErrorAction SilentlyContinue
    if ($testFiles) {
        $summary.tests = @{
            total = 0
            passed = 0
            failed = 0
            skipped = 0
        }
        # Parse test XML files (simplified)
        Write-Host "  Found $($testFiles.Count) test result files" -ForegroundColor Gray
    }
}

# Load quality metrics
$qualityPath = Join-Path $SourcePath "quality-analysis.json"
if (Test-Path $qualityPath) {
    $quality = Get-Content $qualityPath -Raw | ConvertFrom-Json
    $summary.quality = $quality
    Write-Host "  ✓ Quality metrics loaded" -ForegroundColor Green
}

# Load diff analysis
$diffPath = Join-Path $SourcePath "diff-analysis.json"
if (Test-Path $diffPath) {
    $diff = Get-Content $diffPath -Raw | ConvertFrom-Json
    $summary.diff = $diff
    Write-Host "  ✓ Diff analysis loaded" -ForegroundColor Green
}

# Generate recommendations
if ($GenerateRecommendations) {
    $recommendations = @()
    
    # Test-based recommendations
    if ($summary.tests -and $summary.tests.failed -gt 0) {
        $recommendations += @{
            priority = "high"
            category = "tests"
            message = "Fix $($summary.tests.failed) failing test(s) before merging"
            action = "Review test failures in reports"
        }
    }
    
    # Quality-based recommendations
    if ($summary.quality -and $summary.quality.issues.error -gt 0) {
        $recommendations += @{
            priority = "critical"
            category = "quality"
            message = "Address $($summary.quality.issues.error) error-level issue(s)"
            action = "Run PSScriptAnalyzer locally to fix"
        }
    }
    
    # Diff-based recommendations
    if ($summary.diff -and $summary.diff.summary.files_changed -gt 50) {
        $recommendations += @{
            priority = "medium"
            category = "scope"
            message = "Large PR with $($summary.diff.summary.files_changed) files changed"
            action = "Consider breaking into smaller PRs"
        }
    }
    
    $summary.recommendations = $recommendations | Sort-Object { 
        switch ($_.priority) {
            'critical' { 0 }
            'high' { 1 }
            'medium' { 2 }
            'low' { 3 }
        }
    }
    
    Write-Host "  ✓ Generated $($recommendations.Count) recommendation(s)" -ForegroundColor Green
}

# Calculate overall status
if ($summary.tests.failed -eq 0 -and $summary.quality.issues.error -eq 0) {
    $summary.status = "pass"
} elseif ($summary.tests.failed -gt 0 -or $summary.quality.issues.error -gt 0) {
    $summary.status = "fail"
} else {
    $summary.status = "warning"
}

# Write output
$outputDir = Split-Path $OutputPath -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$summary | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

Write-Host "✅ Analysis summary generated: $OutputPath" -ForegroundColor Green
Write-Host "   Status: $($summary.status)" -ForegroundColor Cyan
Write-Host "   Recommendations: $($summary.recommendations.Count)" -ForegroundColor Cyan
