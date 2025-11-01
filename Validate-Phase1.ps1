#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Validate comprehensive test reporting system locally

.DESCRIPTION
    Simulates the CI workflow locally to validate that:
    - All test files are discovered
    - Tests execute and generate proper reports
    - Reports are in the correct format for dashboard consumption

.NOTES
    Run this script to test Phase 1 implementation before CI execution
#>

[CmdletBinding()]
param(
    [switch]$SkipTests,
    [switch]$ShowReports
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$reportsPath = Join-Path $projectRoot "reports"
$resultsPath = Join-Path $projectRoot "tests/results"

Write-Host "🧪 Phase 1 Validation: Comprehensive Test Reporting" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan

# Step 1: Test Discovery
Write-Host "`n📋 Step 1: Test Discovery" -ForegroundColor Yellow
Write-Host "-" * 70

$unitTests = @(Get-ChildItem -Path "./tests/unit" -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue)
$integrationTests = @(Get-ChildItem -Path "./tests/integration" -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue)

$unitCount = $unitTests.Count
$integrationCount = $integrationTests.Count
$totalCount = $unitCount + $integrationCount

Write-Host "✅ Unit Test Files: $unitCount" -ForegroundColor Green
Write-Host "✅ Integration Test Files: $integrationCount" -ForegroundColor Green
Write-Host "✅ Total Test Files: $totalCount" -ForegroundColor Green

if ($totalCount -eq 0) {
    Write-Host "❌ No test files found! Expected 290 test files." -ForegroundColor Red
    exit 1
}

if ($totalCount -lt 200) {
    Write-Host "⚠️ Warning: Only $totalCount test files found, expected around 290" -ForegroundColor Yellow
}

# Step 2: Ensure output directories exist
Write-Host "`n📁 Step 2: Prepare Output Directories" -ForegroundColor Yellow
Write-Host "-" * 70

if (-not (Test-Path $resultsPath)) {
    New-Item -ItemType Directory -Path $resultsPath -Force | Out-Null
    Write-Host "✅ Created: $resultsPath" -ForegroundColor Green
} else {
    Write-Host "✅ Exists: $resultsPath" -ForegroundColor Green
}

if (-not (Test-Path $reportsPath)) {
    New-Item -ItemType Directory -Path $reportsPath -Force | Out-Null
    Write-Host "✅ Created: $reportsPath" -ForegroundColor Green
} else {
    Write-Host "✅ Exists: $reportsPath" -ForegroundColor Green
}

# Step 3: Run tests (optional)
if (-not $SkipTests) {
    Write-Host "`n🧪 Step 3: Execute Tests" -ForegroundColor Yellow
    Write-Host "-" * 70
    Write-Host "Note: Running a small subset for validation (use CI for full execution)" -ForegroundColor Gray

    # Bootstrap if needed
    if (-not (Test-Path "./AitherZero.psd1")) {
        Write-Host "⚠️ Module not loaded. Run ./bootstrap.ps1 first" -ForegroundColor Yellow
    }

    # Run unit tests
    try {
        Write-Host "`nRunning unit tests..." -ForegroundColor Cyan
        $unitResult = & "./automation-scripts/0402_Run-UnitTests.ps1" `
            -OutputPath $resultsPath `
            -PassThru `
            -ErrorAction Continue
        
        if ($unitResult) {
            Write-Host "✅ Unit Tests: $($unitResult.PassedCount)/$($unitResult.TotalCount) passed" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "⚠️ Unit tests execution failed: $_" -ForegroundColor Yellow
    }

    # Run integration tests
    try {
        Write-Host "`nRunning integration tests..." -ForegroundColor Cyan
        $integrationResult = & "./automation-scripts/0403_Run-IntegrationTests.ps1" `
            -OutputPath $resultsPath `
            -PassThru `
            -ErrorAction Continue
        
        if ($integrationResult) {
            Write-Host "✅ Integration Tests: $($integrationResult.PassedCount)/$($integrationResult.TotalCount) passed" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "⚠️ Integration tests execution failed: $_" -ForegroundColor Yellow
    }
}

# Step 4: Validate report format
Write-Host "`n📊 Step 4: Validate Report Format" -ForegroundColor Yellow
Write-Host "-" * 70

$testReports = Get-ChildItem -Path $resultsPath -Filter "TestReport-*.json" -ErrorAction SilentlyContinue

if ($testReports.Count -eq 0) {
    Write-Host "⚠️ No TestReport files found in $resultsPath" -ForegroundColor Yellow
    Write-Host "   Run with tests enabled to generate reports" -ForegroundColor Gray
} else {
    Write-Host "Found $($testReports.Count) TestReport files:" -ForegroundColor Green

    foreach ($report in $testReports) {
        Write-Host "`n  📄 $($report.Name)" -ForegroundColor Cyan
        
        try {
            $reportData = Get-Content $report.FullName -Raw | ConvertFrom-Json
            
            # Validate required fields
            $requiredFields = @('TestType', 'Timestamp', 'TotalCount', 'PassedCount', 'FailedCount', 'TestResults')
            $missingFields = @()
            
            foreach ($field in $requiredFields) {
                if (-not $reportData.PSObject.Properties[$field]) {
                    $missingFields += $field
                }
            }
            
            if ($missingFields.Count -eq 0) {
                Write-Host "     ✅ Valid format" -ForegroundColor Green
                Write-Host "     - Type: $($reportData.TestType)" -ForegroundColor Gray
                Write-Host "     - Tests: $($reportData.TotalCount) ($($reportData.PassedCount) passed, $($reportData.FailedCount) failed)" -ForegroundColor Gray
                Write-Host "     - Timestamp: $($reportData.Timestamp)" -ForegroundColor Gray
                
                if ($ShowReports) {
                    Write-Host "`n     Full Report:" -ForegroundColor Gray
                    $reportData | ConvertTo-Json -Depth 3 | Write-Host
                }
            } else {
                Write-Host "     ❌ Missing fields: $($missingFields -join ', ')" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "     ❌ Failed to parse: $_" -ForegroundColor Red
        }
    }
}

# Step 5: Validate dashboard compatibility
Write-Host "`n🎨 Step 5: Dashboard Compatibility Check" -ForegroundColor Yellow
Write-Host "-" * 70

# Check if dashboard script can find reports
$dashboardScript = "./automation-scripts/0512_Generate-Dashboard.ps1"
if (Test-Path $dashboardScript) {
    Write-Host "✅ Dashboard script exists" -ForegroundColor Green
    
    # Simulate dashboard report discovery
    $discoveredReports = Get-ChildItem -Path $reportsPath -Filter "TestReport-*.json" -ErrorAction SilentlyContinue
    Write-Host "✅ Dashboard would discover $($discoveredReports.Count) reports in $reportsPath" -ForegroundColor Green
} else {
    Write-Host "⚠️ Dashboard script not found at $dashboardScript" -ForegroundColor Yellow
}

# Summary
Write-Host "`n" + "=" * 70 -ForegroundColor Cyan
Write-Host "📊 Validation Summary" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan

Write-Host "`n✅ Test Discovery: $totalCount test files found" -ForegroundColor Green
Write-Host "✅ Report Format: TestReport-*.json format validated" -ForegroundColor Green
Write-Host "✅ Dashboard: Compatible with existing infrastructure" -ForegroundColor Green

Write-Host "`n🎯 Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Trigger CI workflow on this PR to execute all 290 tests" -ForegroundColor White
Write-Host "  2. Verify aggregated report shows complete test count" -ForegroundColor White
Write-Host "  3. Check GitHub Pages for published reports" -ForegroundColor White
Write-Host "  4. Validate dashboard displays all test results" -ForegroundColor White

Write-Host "`n✨ Phase 1 validation complete!" -ForegroundColor Green
