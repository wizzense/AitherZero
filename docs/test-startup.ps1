#!/usr/bin/env pwsh

# Test script to check if StartupExperience module loads properly
cd /workspaces/AitherZero

try {
    Write-Host "Testing StartupExperience module..." -ForegroundColor Cyan
    
    Import-Module ./aither-core/modules/StartupExperience -Force -ErrorAction Stop
    Write-Host "✓ StartupExperience module loaded successfully" -ForegroundColor Green
    
    if (Get-Command Start-InteractiveMode -ErrorAction SilentlyContinue) {
        Write-Host "✓ Start-InteractiveMode function is available" -ForegroundColor Green
    } else {
        Write-Host "❌ ERROR: Start-InteractiveMode function not found" -ForegroundColor Red
    }
    
    # Test if any required functions are missing
    $missing = @()
    $requiredFunctions = @('Initialize-TerminalUI', 'Show-ContextMenu', 'Test-FeatureAccess')
    foreach ($func in $requiredFunctions) {
        if (-not (Get-Command $func -ErrorAction SilentlyContinue)) {
            $missing += $func
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-Host "❌ Missing required functions:" -ForegroundColor Red
        $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    } else {
        Write-Host "✓ All required functions are available" -ForegroundColor Green
    }
    
    # Test terminal capabilities
    Write-Host "`nTesting terminal capabilities..." -ForegroundColor Cyan
    try {
        $capabilities = Get-TerminalCapabilities
        Write-Host "✓ Terminal capabilities detected:" -ForegroundColor Green
        $capabilities.GetEnumerator() | Sort-Object Key | ForEach-Object {
            Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor White
        }
    } catch {
        Write-Host "❌ ERROR: Could not get terminal capabilities: $_" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ ERROR: Failed to import StartupExperience module:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
}