#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    REAL Bulletproof Validation - Actually runs Pester tests instead of fake basic checks
.DESCRIPTION
    This is the corrected bulletproof validation that runs the actual Pester test suite
    instead of fake "tests" that ignore 923 failures.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Quick', 'Standard', 'Complete')]
    [string]$ValidationLevel = 'Standard',

    [Parameter()]
    [switch]$FailFast,

    [Parameter()]
    [switch]$CI
)

Write-Host "🔧 REAL Bulletproof Validation (Fixed)" -ForegroundColor Cyan
Write-Host "Previous validation was FAKE - only tested 14 basic functions while ignoring real failures" -ForegroundColor Yellow

$testPaths = switch ($ValidationLevel) {
    'Quick' { 
        @(
            "tests/unit/modules/Logging",
            "tests/unit/modules/LabRunner",
            "tests/unit/modules/BackupManager"
        )
    }
    'Standard' { 
        @(
            "tests/unit/modules",
            "tests/unit/scripts"
        )
    }
    'Complete' { 
        @(
            "tests/unit",
            "tests/integration"
        )
    }
}

$config = @{
    Run = @{
        Path = $testPaths
        PassThru = $true
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    Should = @{
        ErrorAction = if ($FailFast) { 'Stop' } else { 'Continue' }
    }
}

try {
    $result = Invoke-Pester -Configuration $config
    
    Write-Host ""
    Write-Host "📊 REAL Test Results:" -ForegroundColor White
    Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor Red
    Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host "  Total: $($result.TotalCount)" -ForegroundColor White
    
    if ($result.FailedCount -gt 0) {
        Write-Host ""
        Write-Host "❌ VALIDATION FAILED - $($result.FailedCount) test failures found" -ForegroundColor Red
        Write-Host "This is the REAL state of the project, not the fake 100% success from before." -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host ""
        Write-Host "✅ All tests passed! System is actually healthy." -ForegroundColor Green
        exit 0
    }
} catch {
    Write-Host "💥 Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
