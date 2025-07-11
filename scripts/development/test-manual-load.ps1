#!/usr/bin/env pwsh

# Test manual loading of domain functions
cd /workspaces/AitherZero

$domainRoot = "./aither-core/domains/experience"

Write-Host "Testing manual domain function loading..." -ForegroundColor Cyan

# Test if we can load the experience domain directly
$experiencePath = Join-Path $domainRoot "Experience.ps1"
Write-Host "Experience domain path: $experiencePath" -ForegroundColor White
Write-Host "File exists: $(Test-Path $experiencePath)" -ForegroundColor White

try {
    Write-Host "Loading experience domain..." -ForegroundColor Cyan
    . $experiencePath

    if (Get-Command Initialize-TerminalUI -ErrorAction SilentlyContinue) {
        Write-Host "✓ Initialize-TerminalUI is now available" -ForegroundColor Green
    } else {
        Write-Host "❌ Initialize-TerminalUI still not available" -ForegroundColor Red
    }

} catch {
    Write-Host "❌ Error loading domain: $_" -ForegroundColor Red
}

# Test other key functions
Write-Host "`nTesting other key functions..." -ForegroundColor Cyan

# Test Show-ContextMenu
try {
    if (Get-Command Show-ContextMenu -ErrorAction SilentlyContinue) {
        Write-Host "✓ Show-ContextMenu is available" -ForegroundColor Green
        
        # Test function parameters
        $cmd = Get-Command Show-ContextMenu
        Write-Host "  Parameters: $($cmd.Parameters.Keys -join ', ')" -ForegroundColor White
    } else {
        Write-Host "❌ Show-ContextMenu not available" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error testing Show-ContextMenu: $_" -ForegroundColor Red
}

# Test Test-EnhancedUICapability
try {
    if (Get-Command Test-EnhancedUICapability -ErrorAction SilentlyContinue) {
        Write-Host "✓ Test-EnhancedUICapability is available" -ForegroundColor Green
        
        # Test function execution
        $result = Test-EnhancedUICapability
        Write-Host "  Result: $result" -ForegroundColor White
    } else {
        Write-Host "❌ Test-EnhancedUICapability not available" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error testing Test-EnhancedUICapability: $_" -ForegroundColor Red
}

# Test Test-FeatureAccess
try {
    if (Get-Command Test-FeatureAccess -ErrorAction SilentlyContinue) {
        Write-Host "✓ Test-FeatureAccess is available" -ForegroundColor Green
        
        # Test the problematic call
        $result = Test-FeatureAccess -FeatureName "free"
        Write-Host "  Result: $result" -ForegroundColor White
    } else {
        Write-Host "❌ Test-FeatureAccess not available" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error testing Test-FeatureAccess: $_" -ForegroundColor Red
}

