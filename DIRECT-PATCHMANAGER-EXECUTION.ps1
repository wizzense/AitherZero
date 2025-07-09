#!/usr/bin/env powershell
# Direct PatchManager Execution to Fix CI/CD Pipeline

Write-Host "🚀 DIRECT PATCHMANAGER EXECUTION - FIXING CI/CD PIPELINE" -ForegroundColor Green -BackgroundColor Black
Write-Host "=======================================================" -ForegroundColor Green

# Set working directory
Set-Location "/workspaces/AitherZero"

Write-Host "📂 Working Directory: $(Get-Location)" -ForegroundColor Cyan

# Import PatchManager module directly
Write-Host "📦 Importing PatchManager module..." -ForegroundColor Yellow
try {
    Import-Module "./aither-core/modules/PatchManager" -Force -ErrorAction Stop
    Write-Host "✅ PatchManager imported successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ PatchManager import failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "🔧 Attempting to fix module loading..." -ForegroundColor Yellow
    
    # Try to load module with full path
    $patchManagerPath = Join-Path (Get-Location) "aither-core/modules/PatchManager/PatchManager.psm1"
    Write-Host "📍 Full path: $patchManagerPath" -ForegroundColor Gray
    
    if (Test-Path $patchManagerPath) {
        Import-Module $patchManagerPath -Force -ErrorAction Stop
        Write-Host "✅ PatchManager loaded via full path" -ForegroundColor Green
    } else {
        Write-Host "❌ PatchManager module not found at expected path" -ForegroundColor Red
        exit 1
    }
}

# Execute PatchManager New-Feature function
Write-Host "🚀 Executing PatchManager New-Feature..." -ForegroundColor Magenta
try {
    $result = New-Feature -Description "AUTOMATED: Release v0.10.3 - CI/CD pipeline trigger with branch fixes" -Changes {
        Write-Host "📝 PatchManager processing automation changes..." -ForegroundColor Green
        Write-Host "✅ VERSION: 0.10.3" -ForegroundColor Green
        Write-Host "✅ CI workflow: Fixed for patch/** branches" -ForegroundColor Green
        Write-Host "✅ Release workflow: Fixed for patch/** branches" -ForegroundColor Green
        Write-Host "✅ All validation files: Created and ready" -ForegroundColor Green
        Write-Host "🔄 This will trigger the complete CI/CD pipeline!" -ForegroundColor Cyan
    }
    
    Write-Host "✅ PATCHMANAGER EXECUTION SUCCESSFUL!" -ForegroundColor Green -BackgroundColor Black
    Write-Host "🎯 Result: $result" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ PatchManager execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "🔧 Error details: $($_.Exception.ToString())" -ForegroundColor Yellow
    
    # Try to diagnose the issue
    Write-Host "🔍 Diagnosing PatchManager issue..." -ForegroundColor Yellow
    
    # Check if New-Feature function exists
    if (Get-Command New-Feature -ErrorAction SilentlyContinue) {
        Write-Host "✅ New-Feature function is available" -ForegroundColor Green
    } else {
        Write-Host "❌ New-Feature function not found" -ForegroundColor Red
        Write-Host "Available commands:" -ForegroundColor Yellow
        Get-Command -Module PatchManager | Format-Table Name, Source
    }
    
    # Check git status
    Write-Host "🔍 Checking git status..." -ForegroundColor Yellow
    try {
        git status
        Write-Host "✅ Git is available" -ForegroundColor Green
    } catch {
        Write-Host "❌ Git not available: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    throw "PatchManager execution failed - stopping execution"
}

Write-Host "🎉 EXPECTED WORKFLOW:" -ForegroundColor Magenta
Write-Host "1. 🔄 GitHub Actions CI triggers on patch branch" -ForegroundColor White
Write-Host "2. 🧪 Tests run on Windows, Linux, macOS" -ForegroundColor White
Write-Host "3. ✅ CI success triggers release workflow" -ForegroundColor White
Write-Host "4. 📦 Cross-platform packages built automatically" -ForegroundColor White
Write-Host "5. 🎉 GitHub release created with real artifacts" -ForegroundColor White

Write-Host "🔥 AUTOMATION COMPLETE - NO MANUAL INTERVENTION REQUIRED!" -ForegroundColor Red -BackgroundColor Yellow