#!/usr/bin/env pwsh

# Test manual loading of private functions
cd /workspaces/AitherZero

$moduleRoot = "./aither-core/modules/StartupExperience"

Write-Host "Testing manual function loading..." -ForegroundColor Cyan

# Test if we can manually dot-source the Initialize-TerminalUI function
$initTerminalPath = Join-Path $moduleRoot "Private/Initialize-TerminalUI.ps1"
Write-Host "Initialize-TerminalUI path: $initTerminalPath" -ForegroundColor White
Write-Host "File exists: $(Test-Path $initTerminalPath)" -ForegroundColor White

try {
    Write-Host "Manually dot-sourcing Initialize-TerminalUI..." -ForegroundColor Cyan
    . $initTerminalPath

    if (Get-Command Initialize-TerminalUI -ErrorAction SilentlyContinue) {
        Write-Host "✓ Initialize-TerminalUI is now available" -ForegroundColor Green
    } else {
        Write-Host "❌ Initialize-TerminalUI still not available" -ForegroundColor Red
    }

} catch {
    Write-Host "❌ Error dot-sourcing: $_" -ForegroundColor Red
}

# Now test the other missing function
$showContextPath = Join-Path $moduleRoot "Private/Show-ContextMenu.ps1"
Write-Host "`nShow-ContextMenu path: $showContextPath" -ForegroundColor White
Write-Host "File exists: $(Test-Path $showContextPath)" -ForegroundColor White

try {
    Write-Host "Manually dot-sourcing Show-ContextMenu..." -ForegroundColor Cyan
    . $showContextPath

    if (Get-Command Show-ContextMenu -ErrorAction SilentlyContinue) {
        Write-Host "✓ Show-ContextMenu is now available" -ForegroundColor Green
    } else {
        Write-Host "❌ Show-ContextMenu still not available" -ForegroundColor Red
    }

    # Test if the function has dependencies
    if (Get-Command Test-EnhancedUICapability -ErrorAction SilentlyContinue) {
        Write-Host "✓ Test-EnhancedUICapability is available" -ForegroundColor Green
    } else {
        Write-Host "❌ Test-EnhancedUICapability not available (Show-ContextMenu dependency)" -ForegroundColor Red
    }

} catch {
    Write-Host "❌ Error dot-sourcing Show-ContextMenu: $_" -ForegroundColor Red
}
