#!/usr/bin/env pwsh
# Compatible with PowerShell 5.1+

<#
.SYNOPSIS
    Enable the new dynamic menu system for AitherZero
.DESCRIPTION
    Applies patches to enable dynamic module discovery and configuration editing
#>

Write-Host "`n🚀 Enabling AitherZero Dynamic Menu System" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Cyan

try {
    # Find project root
    . "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    Write-Host "`n✨ New Features:" -ForegroundColor Yellow
    Write-Host "  • Dynamic module discovery and menu system" -ForegroundColor White
    Write-Host "  • Configuration editor integrated into main menu" -ForegroundColor White
    Write-Host "  • Enhanced setup wizard with config review" -ForegroundColor White
    Write-Host "  • Module-based execution with -Scripts parameter" -ForegroundColor White
    Write-Host "  • First-run detection and guidance" -ForegroundColor White
    Write-Host ""
    
    # Check if patch script exists
    $patchScript = Join-Path $projectRoot "scripts/Apply-DynamicMenuPatch.ps1"
    if (Test-Path $patchScript) {
        Write-Host "🔧 Applying dynamic menu patch..." -ForegroundColor Cyan
        & $patchScript
    } else {
        Write-Host "⚠️  Patch script not found, checking if already applied..." -ForegroundColor Yellow
        
        # Check if already patched
        $coreScript = Join-Path $projectRoot "aither-core/aither-core.ps1"
        if (-not (Test-Path $coreScript)) {
            $coreScript = Join-Path $projectRoot "aither-core.ps1"
        }
        
        if (Test-Path $coreScript) {
            $content = Get-Content $coreScript -Raw
            if ($content -match "Show-DynamicMenu") {
                Write-Host "✅ Dynamic menu system is already enabled!" -ForegroundColor Green
            } else {
                Write-Host "❌ Could not apply patch automatically" -ForegroundColor Red
                Write-Host "Please check the Apply-DynamicMenuPatch.ps1 script" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host "`n📚 Usage Examples:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  # Interactive mode with dynamic menu:" -ForegroundColor Gray
    Write-Host "  ./Start-AitherZero.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Run specific modules directly:" -ForegroundColor Gray
    Write-Host "  ./Start-AitherZero.ps1 -Scripts 'LabRunner,BackupManager'" -ForegroundColor White
    Write-Host ""
    Write-Host "  # First-time setup with configuration:" -ForegroundColor Gray
    Write-Host "  ./Start-AitherZero.ps1 -Setup" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Edit configuration anytime:" -ForegroundColor Gray
    Write-Host "  Import-Module ./aither-core/modules/SetupWizard" -ForegroundColor White
    Write-Host "  Edit-Configuration" -ForegroundColor White
    Write-Host ""
    
    Write-Host "✅ Dynamic menu system ready to use!" -ForegroundColor Green
    Write-Host ""
    
    # Offer to run now
    $response = Read-Host "Would you like to start AitherZero with the new menu now? (Y/n)"
    if ($response -ne 'n' -and $response -ne 'N') {
        Write-Host "`nStarting AitherZero..." -ForegroundColor Green
        & (Join-Path $projectRoot "Start-AitherZero.ps1")
    }
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}