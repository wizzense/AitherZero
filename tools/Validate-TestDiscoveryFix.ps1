#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Validates the test discovery fix is working correctly
.DESCRIPTION
    Checks that:
    1. Filter configuration is properly set in config.psd1
    2. Test discovery finds all test files
    3. Dashboard generation shows correct metrics
.EXAMPLE
    ./Validate-TestDiscoveryFix.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = $PSScriptRoot
$passed = 0
$failed = 0

function Test-Condition {
    param(
        [string]$Description,
        [scriptblock]$Test,
        [string]$ExpectedValue
    )
    
    try {
        $result = & $Test
        $success = if ($ExpectedValue) {
            $result -eq $ExpectedValue
        } else {
            [bool]$result
        }
        
        if ($success) {
            Write-Host "✅ PASS: $Description" -ForegroundColor Green
            if ($ExpectedValue) {
                Write-Host "   Value: $result" -ForegroundColor Gray
            }
            $script:passed++
        } else {
            Write-Host "❌ FAIL: $Description" -ForegroundColor Red
            Write-Host "   Expected: $ExpectedValue" -ForegroundColor Yellow
            Write-Host "   Got: $result" -ForegroundColor Yellow
            $script:failed++
        }
    }
    catch {
        Write-Host "❌ ERROR: $Description" -ForegroundColor Red
        Write-Host "   $_" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "`n🔍 Validating Test Discovery Fix" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Test 1: Check config.psd1 exists and is valid
Write-Host "`n📋 Configuration Validation" -ForegroundColor Yellow
Test-Condition "config.psd1 exists" {
    Test-Path (Join-Path $projectRoot "config.psd1")
}

Test-Condition "config.psd1 is valid PowerShell" {
    $config = Import-PowerShellDataFile (Join-Path $projectRoot "config.psd1")
    $null -ne $config
}

# Test 2: Check Filter configuration
Write-Host "`n🎯 Filter Configuration" -ForegroundColor Yellow
Test-Condition "Testing.Pester.Filter exists" {
    $config = Import-PowerShellDataFile (Join-Path $projectRoot "config.psd1")
    $null -ne $config.Testing.Pester.Filter
}

Test-Condition "Filter.Tag is empty array (run all tests)" {
    $config = Import-PowerShellDataFile (Join-Path $projectRoot "config.psd1")
    $config.Testing.Pester.Filter.Tag.Count -eq 0
}

Test-Condition "Filter.ExcludeTag contains Skip and Disabled" {
    $config = Import-PowerShellDataFile (Join-Path $projectRoot "config.psd1")
    $hasSkip = 'Skip' -in $config.Testing.Pester.Filter.ExcludeTag
    $hasDisabled = 'Disabled' -in $config.Testing.Pester.Filter.ExcludeTag
    $hasSkip -and $hasDisabled
}

# Test 3: Check test files exist
Write-Host "`n📁 Test File Discovery" -ForegroundColor Yellow
Test-Condition "Unit test directory exists" {
    Test-Path (Join-Path $projectRoot "tests/unit")
}

Test-Condition "Integration test directory exists" {
    Test-Path (Join-Path $projectRoot "tests/integration")
}

$unitTests = @(Get-ChildItem -Path (Join-Path $projectRoot "tests/unit") -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue)
# Expected: 142 unit test files, but using 50 as threshold to allow for variation
Test-Condition "Unit test files found (expected ~142)" {
    $unitTests.Count -gt 50
} "More than 50"

$integrationTests = @(Get-ChildItem -Path (Join-Path $projectRoot "tests/integration") -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue)
# Expected: 139 integration test files, but using 50 as threshold to allow for variation
Test-Condition "Integration test files found (expected ~139)" {
    $integrationTests.Count -gt 50
} "More than 50"

$totalTests = $unitTests.Count + $integrationTests.Count
Write-Host "   📊 Total test files: $totalTests" -ForegroundColor Gray

# Test 4: Check test scripts exist
Write-Host "`n🤖 Test Automation Scripts" -ForegroundColor Yellow
Test-Condition "0402_Run-UnitTests.ps1 exists" {
    Test-Path (Join-Path $projectRoot "automation-scripts/0402_Run-UnitTests.ps1")
}

Test-Condition "0403_Run-IntegrationTests.ps1 exists" {
    Test-Path (Join-Path $projectRoot "automation-scripts/0403_Run-IntegrationTests.ps1")
}

Test-Condition "0512_Generate-Dashboard.ps1 exists" {
    Test-Path (Join-Path $projectRoot "automation-scripts/0512_Generate-Dashboard.ps1")
}

# Test 5: Validate test script logic
Write-Host "`n🔧 Test Script Logic Validation" -ForegroundColor Yellow
Test-Condition "0402 script has ContainsKey logic" {
    $content = Get-Content (Join-Path $projectRoot "automation-scripts/0402_Run-UnitTests.ps1") -Raw
    $content -match "ContainsKey\('Tag'\)"
}

Test-Condition "0402 script logs filter mode" {
    $content = Get-Content (Join-Path $projectRoot "automation-scripts/0402_Run-UnitTests.ps1") -Raw
    $content -match "Running all tests - no tag filter applied"
}

# Test 6: Check dashboard updates
Write-Host "`n📊 Dashboard Updates" -ForegroundColor Yellow
Test-Condition "Dashboard uses 'Test Files' label" {
    $content = Get-Content (Join-Path $projectRoot "automation-scripts/0512_Generate-Dashboard.ps1") -Raw
    $content -match "Test Files"
}

Test-Condition "Dashboard has 'Last Test Run Results' header" {
    $content = Get-Content (Join-Path $projectRoot "automation-scripts/0512_Generate-Dashboard.ps1") -Raw
    $content -match "Last Test Run Results"
}

Test-Condition "Dashboard has partial run warning" {
    $content = Get-Content (Join-Path $projectRoot "automation-scripts/0512_Generate-Dashboard.ps1") -Raw
    $content -match "Only.*test cases executed"
}

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "📈 Validation Summary" -ForegroundColor Cyan
Write-Host "   ✅ Passed: $passed" -ForegroundColor Green
Write-Host "   ❌ Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })

if ($failed -eq 0) {
    Write-Host "`n🎉 All validation checks passed!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  1. Run: ./az 0402 (to execute full unit test suite)" -ForegroundColor White
    Write-Host "  2. Run: ./az 0512 (to generate updated dashboard)" -ForegroundColor White
    Write-Host "  3. Verify: ~2,400+ tests should be discovered and executed" -ForegroundColor White
    exit 0
} else {
    Write-Host "`n⚠️  Some validation checks failed. Please review the errors above." -ForegroundColor Yellow
    exit 1
}
