#!/usr/bin/env pwsh
#Requires -Version 7.0

# Test PatchManager module loading and functionality
try {
    Write-Host "Testing PatchManager module loading..." -ForegroundColor Cyan
    
    # Import the module
    Import-Module ./aither-core/modules/PatchManager -Force -ErrorAction Stop
    Write-Host "✅ Module imported successfully" -ForegroundColor Green
    
    # List available commands
    Write-Host "`nAvailable commands:" -ForegroundColor Yellow
    $commands = Get-Command -Module PatchManager | Sort-Object Name
    $commands | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor White }
    
    # Test smart mode detection
    Write-Host "`nTesting smart mode detection..." -ForegroundColor Cyan
    if (Get-Command Get-SmartOperationMode -ErrorAction SilentlyContinue) {
        $analysis = Get-SmartOperationMode -PatchDescription "Fix typo in documentation" -HasPatchOperation $false
        Write-Host "✅ Smart mode analysis completed" -ForegroundColor Green
        Write-Host "  Recommended mode: $($analysis.RecommendedMode)" -ForegroundColor White
        Write-Host "  Risk level: $($analysis.RiskLevel)" -ForegroundColor White
        Write-Host "  Should create PR: $($analysis.ShouldCreatePR)" -ForegroundColor White
    } else {
        Write-Host "❌ Get-SmartOperationMode not found" -ForegroundColor Red
    }
    
    # Test dry-run patch creation
    Write-Host "`nTesting dry-run patch creation..." -ForegroundColor Cyan
    if (Get-Command New-Patch -ErrorAction SilentlyContinue) {
        $result = New-Patch -Description "Test patch for analysis" -DryRun
        Write-Host "✅ Dry-run patch test completed" -ForegroundColor Green
        Write-Host "  Success: $($result.Success)" -ForegroundColor White
        Write-Host "  Mode: $($result.Mode)" -ForegroundColor White
    } else {
        Write-Host "❌ New-Patch not found" -ForegroundColor Red
    }
    
    Write-Host "`n🚀 PatchManager module test completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error testing PatchManager: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    exit 1
}