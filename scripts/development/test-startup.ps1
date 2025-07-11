#!/usr/bin/env pwsh

# Test script to check if experience domain loads properly
cd /workspaces/AitherZero

try {
    Write-Host "Testing experience domain..." -ForegroundColor Cyan

    # Load the experience domain
    $experiencePath = "./aither-core/domains/experience/Experience.ps1"
    if (Test-Path $experiencePath) {
        . $experiencePath
        Write-Host "✓ Experience domain loaded successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Experience domain not found at: $experiencePath" -ForegroundColor Red
        exit 1
    }

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
        # Test UI capability detection
        $uiCapable = Test-EnhancedUICapability
        Write-Host "✓ Enhanced UI capability: $uiCapable" -ForegroundColor Green
        
        # Test startup mode detection
        $startupMode = Get-StartupMode -Parameters @{} -IncludeAnalytics
        Write-Host "✓ Startup mode detected: $($startupMode.Mode)" -ForegroundColor Green
        Write-Host "  Reason: $($startupMode.Reason)" -ForegroundColor White
        Write-Host "  UI Capability: $($startupMode.UICapability)" -ForegroundColor White
    } catch {
        Write-Host "❌ ERROR: Could not test terminal capabilities: $_" -ForegroundColor Red
    }

} catch {
    Write-Host "❌ ERROR: Failed to load experience domain:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
}

