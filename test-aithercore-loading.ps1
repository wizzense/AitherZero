#!/usr/bin/env pwsh
#Requires -Version 7.0

# Test script for AitherCore module loading and initialization

param(
    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "=== Testing AitherCore Module Loading ===" -ForegroundColor Cyan
    
    # Test 1: Basic Import
    Write-Host "`n1. Testing basic AitherCore import..." -ForegroundColor Yellow
    Import-Module ./aither-core/AitherCore.psd1 -Force -Verbose
    Write-Host "✓ AitherCore module imported successfully" -ForegroundColor Green
    
    # Test 2: Check exported functions
    Write-Host "`n2. Checking exported functions..." -ForegroundColor Yellow
    $commands = Get-Command -Module AitherCore
    Write-Host "✓ Found $($commands.Count) exported functions" -ForegroundColor Green
    
    if ($Detailed) {
        $commands | Select-Object Name, ModuleName | Format-Table
    }
    
    # Test 3: Test core functions availability
    Write-Host "`n3. Testing core function availability..." -ForegroundColor Yellow
    $coreFunctions = @(
        'Initialize-CoreApplication',
        'Import-CoreModules',
        'Get-CoreModuleStatus',
        'Test-CoreApplicationHealth',
        'Write-CustomLog'
    )
    
    foreach ($func in $coreFunctions) {
        if (Get-Command $func -ErrorAction SilentlyContinue) {
            Write-Host "✓ $func available" -ForegroundColor Green
        } else {
            Write-Host "✗ $func NOT available" -ForegroundColor Red
        }
    }
    
    # Test 4: Initialize Core Application (Required Only)
    Write-Host "`n4. Testing Initialize-CoreApplication (Required modules only)..." -ForegroundColor Yellow
    $initResult = Initialize-CoreApplication -RequiredOnly -Verbose
    if ($initResult) {
        Write-Host "✓ Core application initialized successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠ Core application initialization completed with warnings" -ForegroundColor Yellow
    }
    
    # Test 5: Get Module Status
    Write-Host "`n5. Getting module status..." -ForegroundColor Yellow
    $moduleStatus = Get-CoreModuleStatus
    $totalModules = $moduleStatus.Count
    $loadedModules = ($moduleStatus | Where-Object { $_.Loaded }).Count
    $availableModules = ($moduleStatus | Where-Object { $_.Available }).Count
    $requiredModules = ($moduleStatus | Where-Object { $_.Required }).Count
    
    Write-Host "✓ Module Status Summary:" -ForegroundColor Green
    Write-Host "  - Total registered modules: $totalModules" -ForegroundColor White
    Write-Host "  - Available modules: $availableModules" -ForegroundColor White
    Write-Host "  - Loaded modules: $loadedModules" -ForegroundColor White
    Write-Host "  - Required modules: $requiredModules" -ForegroundColor White
    
    if ($Detailed) {
        Write-Host "`nDetailed Module Status:" -ForegroundColor Cyan
        $moduleStatus | Format-Table Name, Required, Available, Loaded -AutoSize
    }
    
    # Test 6: Test Consolidation Health
    Write-Host "`n6. Testing consolidation health..." -ForegroundColor Yellow
    $healthReport = Test-ConsolidationHealth
    Write-Host "✓ Consolidation health score: $($healthReport.OverallHealth.Score)% ($($healthReport.OverallHealth.Status))" -ForegroundColor Green
    
    if ($healthReport.DuplicateCheck.Issues.Count -gt 0) {
        Write-Host "⚠ Found $($healthReport.DuplicateCheck.Issues.Count) duplicate/unknown module issues:" -ForegroundColor Yellow
        foreach ($issue in $healthReport.DuplicateCheck.Issues) {
            Write-Host "  - $issue" -ForegroundColor Yellow
        }
    }
    
    # Test 7: Test Error Handling
    Write-Host "`n7. Testing error handling for missing dependencies..." -ForegroundColor Yellow
    try {
        # Try to import a non-existent module path
        Import-Module "./non-existent-module" -ErrorAction Stop
        Write-Host "✗ Error handling test failed - should have thrown error" -ForegroundColor Red
    } catch {
        Write-Host "✓ Error handling working correctly for missing modules" -ForegroundColor Green
    }
    
    Write-Host "`n=== AitherCore Module Loading Test Complete ===" -ForegroundColor Cyan
    Write-Host "Status: SUCCESS" -ForegroundColor Green
    
    return @{
        Success = $true
        ModuleStatus = $moduleStatus
        HealthReport = $healthReport
        LoadedCount = $loadedModules
        AvailableCount = $availableModules
    }
    
} catch {
    Write-Host "`n=== AitherCore Module Loading Test FAILED ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host "Stack Trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
    
    return @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }
}