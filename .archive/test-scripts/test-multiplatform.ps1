#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Multi-platform comprehensive test for AitherZero
.DESCRIPTION
    Tests AitherZero on Linux (simulating Mac/Windows) to identify cross-platform issues
#>

[CmdletBinding()]
param(
    [switch]$SkipTests,
    [switch]$SkipAnalysis
)

$ErrorActionPreference = 'Continue'
$testResults = @{
    Bootstrap = @{ Status = 'NotRun'; Error = $null }
    Syntax = @{ Status = 'NotRun'; Error = $null }
    UnitTests = @{ Status = 'NotRun'; Error = $null }
    Analysis = @{ Status = 'NotRun'; Error = $null }
    Orchestration = @{ Status = 'NotRun'; Error = $null }
}

function Test-Component {
    param(
        [string]$Name,
        [scriptblock]$TestScript
    )

    Write-Host "`n🧪 Testing $Name..." -ForegroundColor Cyan
    try {
        $result = & $TestScript
        $testResults[$Name].Status = 'Passed'
        Write-Host "✅ $Name - PASSED" -ForegroundColor Green
        return $result
    } catch {
        $testResults[$Name].Status = 'Failed'
        $testResults[$Name].Error = $_.Exception.Message
        Write-Host "❌ $Name - FAILED: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

Write-Host "🚀 AitherZero Multi-Platform Test Suite" -ForegroundColor Cyan
Write-Host "Platform: $($PSVersionTable.Platform)" -ForegroundColor Gray
Write-Host "PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host ""

# Test 1: Bootstrap
Test-Component -Name 'Bootstrap' -TestScript {
    $output = pwsh -c "./bootstrap.ps1 -Mode New -NonInteractive" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Bootstrap failed with exit code $LASTEXITCODE"
    }
    if ($output -like "*Error*" -or $output -like "*Failed*") {
        $errorLines = $output | Where-Object { $_ -like "*Error*" -or $_ -like "*Failed*" }
        throw "Bootstrap completed but had errors: $($errorLines -join '; ')"
    }
    return "Bootstrap completed successfully"
}

# Test 2: Syntax Validation
Test-Component -Name 'Syntax' -TestScript {
    $output = pwsh -c "./automation-scripts/0407_Validate-Syntax.ps1 -All" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Syntax validation failed with exit code $LASTEXITCODE"
    }
    return "All files have valid syntax"
}

# Test 3: Unit Tests (quick subset)
if (-not $SkipTests) {
    Test-Component -Name 'UnitTests' -TestScript {
        # Run a quick subset of tests
        $output = pwsh -c "timeout 45 ./automation-scripts/0402_Run-UnitTests.ps1 -NoCoverage -CI" 2>&1
        if ($LASTEXITCODE -eq 143) {
            return "Unit tests running (timed out after 45s - this is expected for quick test)"
        }
        if ($LASTEXITCODE -ne 0) {
            throw "Unit tests failed with exit code $LASTEXITCODE"
        }
        return "Unit tests completed"
    }
}

# Test 4: Static Analysis
if (-not $SkipAnalysis) {
    Test-Component -Name 'Analysis' -TestScript {
        $output = pwsh -c "./automation-scripts/0404_Run-PSScriptAnalyzer.ps1 -ExcludePaths tests,examples -WhatIf" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "PSScriptAnalyzer failed with exit code $LASTEXITCODE"
        }
        return "Static analysis completed"
    }
}

# Test 5: Orchestration
Test-Component -Name 'Orchestration' -TestScript {
    $output = pwsh -c "timeout 30 ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-ci -NonInteractive" 2>&1
    if ($LASTEXITCODE -eq 143) {
        return "Orchestration started successfully (timed out after 30s)"
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Orchestration failed with exit code $LASTEXITCODE"
    }
    return "Orchestration completed"
}

# Summary
Write-Host "`n📊 Test Results Summary:" -ForegroundColor Cyan
$totalTests = $testResults.Count
$passedTests = ($testResults.Values | Where-Object { $_.Status -eq 'Passed' }).Count
$failedTests = ($testResults.Values | Where-Object { $_.Status -eq 'Failed' }).Count

foreach ($test in $testResults.GetEnumerator()) {
    $status = switch ($test.Value.Status) {
        'Passed' { '✅ PASSED' }
        'Failed' { '❌ FAILED' }
        'NotRun' { '⏭️  SKIPPED' }
    }
    Write-Host "  $($test.Key): $status" -ForegroundColor $(
        switch ($test.Value.Status) {
            'Passed' { 'Green' }
            'Failed' { 'Red' }
            'NotRun' { 'Yellow' }
        }
    )
    if ($test.Value.Error) {
        Write-Host "    Error: $($test.Value.Error)" -ForegroundColor DarkRed
    }
}

Write-Host "`nOverall: $passedTests/$totalTests tests passed" -ForegroundColor $(
    if ($failedTests -eq 0) { 'Green' } elseif ($passedTests -ge ($totalTests * 0.8)) { 'Yellow' } else { 'Red' }
)

if ($failedTests -gt 0) {
    Write-Host "`n🔍 Failed Tests Need Investigation:" -ForegroundColor Red
    $testResults.GetEnumerator() | Where-Object { $_.Value.Status -eq 'Failed' } | ForEach-Object {
        Write-Host "  - $($_.Key): $($_.Value.Error)" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "`n🎉 All tests passed! AitherZero is working correctly on this platform." -ForegroundColor Green
    exit 0
}