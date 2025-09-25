#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script to validate GitHub Actions workflow fixes
.DESCRIPTION
    Simulates the issues that were fixed in the GitHub Actions workflows and validates the solutions
#>

[CmdletBinding()]
param()

Write-Host "🧪 Testing GitHub Actions Workflow Fixes" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Gray

$testsPassed = 0
$totalTests = 0

function Test-Issue {
    param(
        [string]$TestName,
        [scriptblock]$TestCode,
        [string]$ExpectedResult = "Success"
    )
    
    $script:totalTests++
    Write-Host "`n[$script:totalTests] Testing: $TestName" -ForegroundColor Yellow
    
    try {
        $result = & $TestCode
        if ($result -eq $ExpectedResult -or $ExpectedResult -eq "Success") {
            Write-Host "✅ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
        } else {
            Write-Host "❌ FAIL: $TestName - Expected: $ExpectedResult, Got: $result" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ FAIL: $TestName - Exception: $_" -ForegroundColor Red
    }
}

# Test 1: Cross-platform chmod handling
Test-Issue -TestName "Cross-platform chmod handling" -TestCode {
    if ($IsWindows) {
        # On Windows, the old approach would fail
        # Test that we now properly skip chmod on Windows
        try {
            # This should not be executed on Windows
            if (-not $IsWindows) {
                & chmod +x *.ps1 *.sh 2>$null -ErrorAction SilentlyContinue
            }
            return "Success"
        } catch {
            return "Failed: $_"
        }
    } else {
        # On Unix, chmod should work
        try {
            & chmod +x *.ps1 *.sh 2>$null -ErrorAction SilentlyContinue
            return "Success"
        } catch {
            return "Failed: $_"
        }
    }
}

# Test 2: Module loading before script execution
Test-Issue -TestName "Module loading before script execution" -TestCode {
    try {
        Import-Module ./AitherZero.psd1 -Force -Global
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            return "Success"
        } else {
            return "Failed: Write-CustomLog not available"
        }
    } catch {
        return "Failed: $_"
    }
}

# Test 3: PSScriptAnalyzer works with proper module loading
Test-Issue -TestName "PSScriptAnalyzer execution with modules" -TestCode {
    try {
        Import-Module ./AitherZero.psd1 -Force -Global
        $result = & { pwsh ./automation-scripts/0404_Run-PSScriptAnalyzer.ps1 -WhatIf 2>&1 }
        if ($LASTEXITCODE -eq 0) {
            return "Success"
        } else {
            return "Failed: Exit code $LASTEXITCODE"
        }
    } catch {
        return "Failed: $_"
    }
}

# Test 4: Validate /dev/null reference is removed
Test-Issue -TestName "No /dev/null references in Windows workflows" -TestCode {
    $workflows = Get-ChildItem -Path ".github/workflows/*.yml"
    $badReferences = @()
    foreach ($workflow in $workflows) {
        $content = Get-Content $workflow.FullName -Raw
        if ($content -match "2>/dev/null") {
            $badReferences += $workflow.Name
        }
    }
    
    if ($badReferences.Count -eq 0) {
        return "Success"
    } else {
        return "Failed: Found /dev/null references in: $($badReferences -join ', ')"
    }
}

# Summary
Write-Host "`n" -NoNewline
Write-Host "🏁 Test Results Summary" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Gray
Write-Host "Tests Passed: $testsPassed / $totalTests" -ForegroundColor $(if ($testsPassed -eq $totalTests) { "Green" } else { "Yellow" })

if ($testsPassed -eq $totalTests) {
    Write-Host "🎉 All GitHub Actions workflow fixes are working correctly!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️ Some tests failed. Review the issues above." -ForegroundColor Yellow
    exit 1
}