#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Test PatchManager v3.0 Integration and Functionality

.DESCRIPTION
    This script tests all PatchManager v3.0 functions to verify they work as claimed
#>

# Test module import
Write-Host "=== PatchManager v3.0 Integration Test ===" -ForegroundColor Cyan
Write-Host "1. Testing module import..." -ForegroundColor Yellow

try {
    Import-Module ./PatchManager -Force -Verbose
    Write-Host "   ✅ PatchManager module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "   ❌ PatchManager module import failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test available commands
Write-Host "2. Testing available commands..." -ForegroundColor Yellow
try {
    $commands = Get-Command -Module PatchManager
    Write-Host "   ✅ Found $($commands.Count) commands in PatchManager module" -ForegroundColor Green
    
    # List key v3.0 functions
    $keyFunctions = @('New-Patch', 'New-QuickFix', 'New-Feature', 'New-Hotfix')
    foreach ($func in $keyFunctions) {
        $command = Get-Command $func -ErrorAction SilentlyContinue
        if ($command) {
            Write-Host "   ✅ $func is available" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $func is NOT available" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   ❌ Error testing commands: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Git detection
Write-Host "3. Testing Git detection..." -ForegroundColor Yellow
try {
    $gitCmd = Get-GitCommand -TestConnection
    Write-Host "   ✅ Git detected at: $gitCmd" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Git detection failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test dry-run operations
Write-Host "4. Testing dry-run operations..." -ForegroundColor Yellow

# Test New-QuickFix dry-run
Write-Host "   4a. Testing New-QuickFix dry-run..." -ForegroundColor Cyan
try {
    $result = New-QuickFix -Description "Test typo fix" -Changes {
        Write-Host "Test change operation"
    } -DryRun
    
    if ($result.Success) {
        Write-Host "   ✅ New-QuickFix dry-run succeeded" -ForegroundColor Green
    } else {
        Write-Host "   ❌ New-QuickFix dry-run failed: $($result.Error)" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ New-QuickFix dry-run error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test New-Patch dry-run  
Write-Host "   4b. Testing New-Patch dry-run..." -ForegroundColor Cyan
try {
    $result = New-Patch -Description "Test patch operation" -Changes {
        Write-Host "Test patch change operation"
    } -DryRun
    
    if ($result.Success) {
        Write-Host "   ✅ New-Patch dry-run succeeded" -ForegroundColor Green
    } else {
        Write-Host "   ❌ New-Patch dry-run failed: $($result.Error)" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ New-Patch dry-run error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test New-Feature dry-run
Write-Host "   4c. Testing New-Feature dry-run..." -ForegroundColor Cyan
try {
    $result = New-Feature -Description "Test feature implementation" -Changes {
        Write-Host "Test feature change operation"
    } -DryRun
    
    if ($result.Success) {
        Write-Host "   ✅ New-Feature dry-run succeeded" -ForegroundColor Green
    } else {
        Write-Host "   ❌ New-Feature dry-run failed: $($result.Error)" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ New-Feature dry-run error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test New-Hotfix dry-run
Write-Host "   4d. Testing New-Hotfix dry-run..." -ForegroundColor Cyan
try {
    $result = New-Hotfix -Description "Test hotfix implementation" -Changes {
        Write-Host "Test hotfix change operation"
    } -DryRun
    
    if ($result.Success) {
        Write-Host "   ✅ New-Hotfix dry-run succeeded" -ForegroundColor Green
    } else {
        Write-Host "   ❌ New-Hotfix dry-run failed: $($result.Error)" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ New-Hotfix dry-run error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Smart Operation Mode
Write-Host "5. Testing Smart Operation Mode..." -ForegroundColor Yellow
try {
    $smartMode = Get-SmartOperationMode -PatchDescription "Fix typo in documentation" -HasPatchOperation $true
    Write-Host "   ✅ Smart mode detection returned: $($smartMode.RecommendedMode)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Smart mode detection failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test atomic operations
Write-Host "6. Testing atomic operations..." -ForegroundColor Yellow
try {
    $result = Invoke-AtomicOperation -Operation {
        Write-Host "Test atomic operation"
        return "Success"
    } -OperationName "Test Operation"
    
    if ($result.Success) {
        Write-Host "   ✅ Atomic operation test succeeded" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Atomic operation test failed: $($result.Error)" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Atomic operation test error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "=== PatchManager v3.0 Integration Test Complete ===" -ForegroundColor Cyan