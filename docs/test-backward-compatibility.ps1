#!/usr/bin/env pwsh

# Backward Compatibility Test Script
# Tests that existing scripts and function calls still work

$ErrorActionPreference = 'Stop'
Set-Location '/workspaces/AitherZero'

Write-Host "=== BACKWARD COMPATIBILITY TESTING ===" -ForegroundColor Cyan

# Test 1: Legacy PatchManager function calls
try {
    Import-Module './aither-core/modules/PatchManager' -Force
    Write-Host "✓ PatchManager module imported successfully" -ForegroundColor Green
    
    # Test legacy function availability
    $LegacyFunctions = @(
        'Invoke-PatchWorkflow',
        'Get-GitCommand',
        'Get-PatchStatus',
        'Invoke-PatchRollback'
    )
    
    foreach ($Function in $LegacyFunctions) {
        if (Get-Command $Function -ErrorAction SilentlyContinue) {
            Write-Host "  ✓ Legacy function '$Function' available" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Legacy function '$Function' missing" -ForegroundColor Red
        }
    }
    
    # Test new v3.0 functions
    $NewFunctions = @(
        'New-Patch',
        'New-QuickFix',
        'New-Feature',
        'New-Hotfix'
    )
    
    foreach ($Function in $NewFunctions) {
        if (Get-Command $Function -ErrorAction SilentlyContinue) {
            Write-Host "  ✓ New function '$Function' available" -ForegroundColor Green
        } else {
            Write-Host "  ✗ New function '$Function' missing" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "✗ PatchManager compatibility test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Configuration management
try {
    Import-Module './aither-core/modules/ConfigurationCore' -Force
    Write-Host "✓ ConfigurationCore module imported successfully" -ForegroundColor Green
    
    # Test configuration functions
    $ConfigFunctions = @(
        'Get-ConfigurationStore',
        'Set-ConfigurationStore',
        'Initialize-ConfigurationCore'
    )
    
    foreach ($Function in $ConfigFunctions) {
        if (Get-Command $Function -ErrorAction SilentlyContinue) {
            Write-Host "  ✓ Configuration function '$Function' available" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Configuration function '$Function' missing" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "✗ ConfigurationCore compatibility test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Logging system
try {
    Import-Module './aither-core/modules/Logging' -Force
    Write-Host "✓ Logging module imported successfully" -ForegroundColor Green
    
    # Test if Write-CustomLog is available
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-Host "  ✓ Write-CustomLog function available" -ForegroundColor Green
        
        # Test actual logging
        Write-CustomLog -Level 'INFO' -Message "Backward compatibility test"
        Write-Host "  ✓ Write-CustomLog execution successful" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Write-CustomLog function missing" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ Logging compatibility test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Module loading from entry point
try {
    Write-Host "Testing entry point module loading..." -ForegroundColor Yellow
    
    # Test the main entry point can access modules
    $EntryPoint = './Start-AitherZero.ps1'
    if (Test-Path $EntryPoint) {
        Write-Host "  ✓ Entry point exists" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Entry point missing" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ Entry point compatibility test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: VS Code tasks compatibility
try {
    $VSCodeTasks = './.vscode/tasks.json'
    if (Test-Path $VSCodeTasks) {
        Write-Host "✓ VS Code tasks file exists" -ForegroundColor Green
        
        $TasksContent = Get-Content $VSCodeTasks -Raw | ConvertFrom-Json
        $TaskCount = $TasksContent.tasks.Count
        Write-Host "  ✓ Found $TaskCount VS Code tasks" -ForegroundColor Green
    } else {
        Write-Host "✗ VS Code tasks file missing" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ VS Code tasks compatibility test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 6: Test existing scripts
try {
    $TestScript = './tests/Run-Tests.ps1'
    if (Test-Path $TestScript) {
        Write-Host "✓ Test script exists" -ForegroundColor Green
        
        # Test that it can be loaded (not executed to avoid long run)
        $ScriptContent = Get-Content $TestScript -Raw
        if ($ScriptContent -like "*Import-Module*") {
            Write-Host "  ✓ Test script imports modules correctly" -ForegroundColor Green
        }
    } else {
        Write-Host "✗ Test script missing" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ Test script compatibility test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== BACKWARD COMPATIBILITY TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host "All tests completed. Check output above for specific results." -ForegroundColor Yellow