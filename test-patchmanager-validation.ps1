#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Validate PatchManager v3.0 atomic operations functionality
    
.DESCRIPTION
    Tests the core functionality of PatchManager v3.0 including:
    - Module loading and function availability
    - Smart mode detection
    - Atomic operations capabilities
    - DryRun functionality
#>

Write-Host '🚀 Testing PatchManager v3.0 Atomic Operations' -ForegroundColor Cyan
Write-Host '=================================================' -ForegroundColor Cyan

# Test 1: Module Import
Write-Host '[1/5] Importing PatchManager module...' -ForegroundColor Yellow
try {
    Import-Module './aither-core/modules/PatchManager' -Force
    Write-Host '  ✅ PatchManager module imported successfully' -ForegroundColor Green
} catch {
    Write-Host "  ❌ Failed to import PatchManager: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Check atomic operations availability
Write-Host '[2/5] Checking atomic operations availability...' -ForegroundColor Yellow
$functions = @('New-Patch', 'New-QuickFix', 'New-Feature', 'New-Hotfix')
$availableFunctions = 0
foreach ($func in $functions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "  ✅ $func - Available" -ForegroundColor Green
        $availableFunctions++
    } else {
        Write-Host "  ❌ $func - Missing" -ForegroundColor Red
    }
}

if ($availableFunctions -eq $functions.Count) {
    Write-Host "  ✅ All atomic operations available ($availableFunctions/$($functions.Count))" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Some atomic operations missing ($availableFunctions/$($functions.Count))" -ForegroundColor Yellow
}

# Test 3: Check supporting functions
Write-Host '[3/5] Checking supporting functions...' -ForegroundColor Yellow
$supportFunctions = @('Get-SmartOperationMode', 'Invoke-MultiModeOperation', 'Invoke-AtomicOperation')
$availableSupport = 0
foreach ($func in $supportFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "  ✅ $func - Available" -ForegroundColor Green
        $availableSupport++
    } else {
        Write-Host "  ❌ $func - Missing" -ForegroundColor Red
    }
}

# Test 4: Test dry-run functionality
Write-Host '[4/5] Testing New-Patch dry-run functionality...' -ForegroundColor Yellow
try {
    $dryRunResult = New-Patch -Description "Test patch for validation" -DryRun -Mode "Simple"
    if ($dryRunResult.Success -and $dryRunResult.DryRun) {
        Write-Host '  ✅ Dry-run functionality working' -ForegroundColor Green
        Write-Host "    Mode detected: $($dryRunResult.Mode)" -ForegroundColor Gray
    } else {
        Write-Host '  ⚠️ Dry-run completed but with unexpected results' -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ❌ Dry-run failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Check legacy compatibility
Write-Host '[5/5] Checking legacy compatibility...' -ForegroundColor Yellow
$legacyFunctions = @('Invoke-PatchWorkflow', 'New-PatchIssue', 'New-PatchPR')
$availableLegacy = 0
foreach ($func in $legacyFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "  ✅ $func - Available" -ForegroundColor Green
        $availableLegacy++
    } else {
        Write-Host "  ❌ $func - Missing" -ForegroundColor Red
    }
}

# Summary
Write-Host ''
Write-Host '📊 PatchManager v3.0 Validation Summary:' -ForegroundColor Cyan
Write-Host "  Atomic Operations: $availableFunctions/$($functions.Count)" -ForegroundColor White
Write-Host "  Support Functions: $availableSupport/$($supportFunctions.Count)" -ForegroundColor White
Write-Host "  Legacy Functions: $availableLegacy/$($legacyFunctions.Count)" -ForegroundColor White

$totalExpected = $functions.Count + $supportFunctions.Count + $legacyFunctions.Count
$totalAvailable = $availableFunctions + $availableSupport + $availableLegacy
$successRate = [math]::Round(($totalAvailable / $totalExpected) * 100, 1)

Write-Host "  Overall Success Rate: $successRate% ($totalAvailable/$totalExpected)" -ForegroundColor $(if ($successRate -ge 90) { 'Green' } elseif ($successRate -ge 70) { 'Yellow' } else { 'Red' })

if ($successRate -ge 90) {
    Write-Host '✅ PatchManager v3.0 validation PASSED' -ForegroundColor Green
    exit 0
} elseif ($successRate -ge 70) {
    Write-Host '⚠️ PatchManager v3.0 validation PASSED with warnings' -ForegroundColor Yellow
    exit 0
} else {
    Write-Host '❌ PatchManager v3.0 validation FAILED' -ForegroundColor Red
    exit 1
}