#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates the optimized workflow architecture to ensure no duplication

.DESCRIPTION
    This script validates that the workflow optimization successfully eliminated duplication:
    - CI workflow: Fast validation, no comprehensive report triggering
    - Comprehensive report: Consumes CI results, no duplicate test execution
    - GitHub Pages: Single deployment point
    - Data sharing: Proper artifact consumption

.EXAMPLE
    ./validate-workflow-optimization.ps1
#>

param(
    [switch]$Verbose
)

Write-Host "🔍 Validating Workflow Optimization Architecture" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

$validationResults = @{
    CIDuplicationRemoved = $false
    ComprehensiveReportOptimized = $false
    DataSharingImplemented = $false
    GitHubPagesOptimized = $false
    JobReferencesUpdated = $false
    OverallSuccess = $false
}

# 1. Validate CI workflow no longer triggers comprehensive report
Write-Host "`n1. Validating CI workflow duplication removal..." -ForegroundColor Yellow

$ciWorkflowPath = ".github/workflows/ci.yml"
$ciContent = Get-Content $ciWorkflowPath -Raw

if ($ciContent -notmatch "trigger-comprehensive-report") {
    Write-Host "✅ CI workflow no longer triggers comprehensive report" -ForegroundColor Green
    $validationResults.CIDuplicationRemoved = $true
} else {
    Write-Host "❌ CI workflow still contains comprehensive report trigger" -ForegroundColor Red
}

if ($ciContent -match "export-test-results") {
    Write-Host "✅ CI workflow exports test results for consumption" -ForegroundColor Green
} else {
    Write-Host "❌ CI workflow missing test results export" -ForegroundColor Red
}

if ($ciContent -match "ci-results-summary") {
    Write-Host "✅ CI workflow creates results summary artifact" -ForegroundColor Green
} else {
    Write-Host "❌ CI workflow missing results summary creation" -ForegroundColor Red
}

# 2. Validate comprehensive report workflow optimization
Write-Host "`n2. Validating comprehensive report workflow optimization..." -ForegroundColor Yellow

$comprehensiveWorkflowPath = ".github/workflows/comprehensive-report.yml"
$comprehensiveContent = Get-Content $comprehensiveWorkflowPath -Raw

if ($comprehensiveContent -match "consume-ci-results") {
    Write-Host "✅ Comprehensive report consumes CI results" -ForegroundColor Green
    $validationResults.ComprehensiveReportOptimized = $true
} else {
    Write-Host "❌ Comprehensive report missing CI results consumption" -ForegroundColor Red
}

if ($comprehensiveContent -match "Run-Tests\.ps1.*-CI" -and $comprehensiveContent -match "Quick.*-CI") {
    Write-Host "✅ Comprehensive report runs minimal tests when CI unavailable" -ForegroundColor Green
} else {
    Write-Host "⚠️ Comprehensive report may still run full test suite" -ForegroundColor Yellow
}

# 3. Validate data sharing implementation
Write-Host "`n3. Validating data sharing between workflows..." -ForegroundColor Yellow

if ($ciContent -match "ci-results-summary\.json" -and $comprehensiveContent -match "ci-results-summary\.json") {
    Write-Host "✅ Data sharing implemented via ci-results-summary.json" -ForegroundColor Green
    $validationResults.DataSharingImplemented = $true
} else {
    Write-Host "❌ Data sharing mechanism not properly implemented" -ForegroundColor Red
}

if ($comprehensiveContent -match "listWorkflowRuns" -and $comprehensiveContent -match "listWorkflowRunArtifacts") {
    Write-Host "✅ Comprehensive report can discover and download CI artifacts" -ForegroundColor Green
} else {
    Write-Host "❌ Comprehensive report missing artifact discovery" -ForegroundColor Red
}

# 4. Validate GitHub Pages optimization
Write-Host "`n4. Validating GitHub Pages deployment optimization..." -ForegroundColor Yellow

$ciPagesCount = ($ciContent | Select-String -Pattern "actions-gh-pages|peaceiris/actions-gh-pages" -AllMatches).Matches.Count
$comprehensivePagesCount = ($comprehensiveContent | Select-String -Pattern "actions-gh-pages|peaceiris/actions-gh-pages" -AllMatches).Matches.Count

if ($ciPagesCount -eq 0 -and $comprehensivePagesCount -eq 1) {
    Write-Host "✅ GitHub Pages deployment optimized (only in comprehensive report)" -ForegroundColor Green
    $validationResults.GitHubPagesOptimized = $true
} else {
    Write-Host "❌ GitHub Pages deployment not optimized (CI: $ciPagesCount, Comprehensive: $comprehensivePagesCount)" -ForegroundColor Red
}

# 5. Validate job references are updated
Write-Host "`n5. Validating job references are updated..." -ForegroundColor Yellow

if ($comprehensiveContent -match "consume-ci-results-and-audit" -and $comprehensiveContent -notmatch "run-audits") {
    Write-Host "✅ Job references updated in comprehensive report" -ForegroundColor Green
    $validationResults.JobReferencesUpdated = $true
} else {
    Write-Host "❌ Job references not properly updated" -ForegroundColor Red
}

# 6. Validate workflow architecture principles
Write-Host "`n6. Validating workflow architecture principles..." -ForegroundColor Yellow

$principleChecks = @{
    "Complementary Architecture" = $validationResults.CIDuplicationRemoved -and $validationResults.ComprehensiveReportOptimized
    "No Test Duplication" = $validationResults.DataSharingImplemented -and $validationResults.ComprehensiveReportOptimized
    "Single Pages Deployment" = $validationResults.GitHubPagesOptimized
    "Proper Data Flow" = $validationResults.DataSharingImplemented -and $validationResults.JobReferencesUpdated
}

foreach ($principle in $principleChecks.GetEnumerator()) {
    if ($principle.Value) {
        Write-Host "✅ $($principle.Key)" -ForegroundColor Green
    } else {
        Write-Host "❌ $($principle.Key)" -ForegroundColor Red
    }
}

# Overall validation
Write-Host "`n📊 Validation Summary:" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan

$totalChecks = $validationResults.Count - 1  # Exclude OverallSuccess
$passedChecks = ($validationResults.GetEnumerator() | Where-Object { $_.Key -ne "OverallSuccess" -and $_.Value -eq $true }).Count

Write-Host "Passed: $passedChecks / $totalChecks" -ForegroundColor White

if ($passedChecks -eq $totalChecks) {
    Write-Host "✅ WORKFLOW OPTIMIZATION VALIDATION PASSED" -ForegroundColor Green
    $validationResults.OverallSuccess = $true
} else {
    Write-Host "❌ WORKFLOW OPTIMIZATION VALIDATION FAILED" -ForegroundColor Red
}

# Detailed results if verbose
if ($Verbose) {
    Write-Host "`n📋 Detailed Results:" -ForegroundColor Cyan
    $validationResults.GetEnumerator() | ForEach-Object {
        $status = if ($_.Value) { "✅ PASS" } else { "❌ FAIL" }
        Write-Host "  $($_.Key): $status"
    }
}

# Expected improvements
Write-Host "`n🚀 Expected Improvements:" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host "• 🏃 Faster CI execution (no comprehensive report generation)" -ForegroundColor Green
Write-Host "• 📉 Reduced resource usage (no duplicate test execution)" -ForegroundColor Green
Write-Host "• 🔄 Better separation of concerns (fast validation vs deep analysis)" -ForegroundColor Green
Write-Host "• 📊 Improved data flow (structured CI results consumption)" -ForegroundColor Green
Write-Host "• 🚀 Optimized GitHub Pages deployment (single deployment point)" -ForegroundColor Green
Write-Host "• ⚡ Complementary architecture (workflows work together, not in parallel)" -ForegroundColor Green

if ($validationResults.OverallSuccess) {
    Write-Host "`n🎉 Smart workflow optimization successfully implemented!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠️ Smart workflow optimization needs attention" -ForegroundColor Yellow
    exit 1
}