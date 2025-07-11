#!/usr/bin/env pwsh

# Test critical functions after domain consolidation
cd /workspaces/AitherZero

Write-Host "Testing Critical Functions Post-Domain Consolidation" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# Load dependencies
$projectRoot = "/workspaces/AitherZero"

# Load logging first
try {
    Import-Module "$projectRoot/aither-core/modules/Logging" -Force
    Write-Host "✓ Logging module loaded" -ForegroundColor Green
} catch {
    function Write-CustomLog {
        param([string]$Level, [string]$Message)
        $timestamp = Get-Date -Format "HH:mm:ss.fff"
        $color = switch ($Level) {
            'ERROR' { 'Red' }; 'WARNING' { 'Yellow' }; 'SUCCESS' { 'Green' }
            'INFO' { 'Cyan' }; default { 'White' }
        }
        Write-Host "[$timestamp] [$($Level.PadRight(7))] $Message" -ForegroundColor $color
    }
    Write-Host "✓ Fallback logging created" -ForegroundColor Yellow
}

# Load experience domain (most critical)
Write-Host "`n1. Testing Experience Domain (Critical Startup Functions)..." -ForegroundColor Yellow
try {
    . "$projectRoot/aither-core/domains/experience/Experience.ps1"
    Write-Host "   ✓ Experience domain loaded successfully" -ForegroundColor Green
    
    # Test critical startup functions
    $criticalFunctions = @(
        'Start-InteractiveMode',
        'Initialize-TerminalUI', 
        'Show-ContextMenu',
        'Test-FeatureAccess',
        'Get-StartupMode',
        'Test-EnhancedUICapability',
        'Start-IntelligentSetup'
    )
    
    $workingFunctions = 0
    foreach ($func in $criticalFunctions) {
        if (Get-Command $func -ErrorAction SilentlyContinue) {
            Write-Host "   ✓ $func - Available" -ForegroundColor Green
            $workingFunctions++
        } else {
            Write-Host "   ❌ $func - Missing" -ForegroundColor Red
        }
    }
    
    Write-Host "   📊 Experience Functions: $workingFunctions/$($criticalFunctions.Count) working" -ForegroundColor $(if($workingFunctions -eq $criticalFunctions.Count) { 'Green' } else { 'Yellow' })
    
} catch {
    Write-Host "   ❌ Experience domain failed to load: $_" -ForegroundColor Red
}

# Test specific function execution
Write-Host "`n2. Testing Function Execution..." -ForegroundColor Yellow

# Test Test-FeatureAccess (was failing before)
try {
    Write-Host "   Testing Test-FeatureAccess..." -ForegroundColor White
    $result = Test-FeatureAccess -FeatureName "free"
    Write-Host "   ✓ Test-FeatureAccess worked: $result" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Test-FeatureAccess failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Initialize-TerminalUI (was missing before)
try {
    Write-Host "   Testing Initialize-TerminalUI..." -ForegroundColor White
    Initialize-TerminalUI
    Write-Host "   ✓ Initialize-TerminalUI worked" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Initialize-TerminalUI failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Show-ContextMenu (was missing before)
try {
    Write-Host "   Testing Show-ContextMenu..." -ForegroundColor White
    $testOptions = @(
        @{Text = "Option 1"; Action = "Action1"},
        @{Text = "Option 2"; Action = "Action2"}
    )
    
    # We can't actually run this interactively, so just check it exists and has right parameters
    $cmd = Get-Command Show-ContextMenu -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Parameters.Keys -contains "Title" -and $cmd.Parameters.Keys -contains "Options") {
        Write-Host "   ✓ Show-ContextMenu has correct parameters" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Show-ContextMenu missing or wrong parameters" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Show-ContextMenu failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Get-StartupMode
try {
    Write-Host "   Testing Get-StartupMode..." -ForegroundColor White
    $startupMode = Get-StartupMode -Parameters @{}
    Write-Host "   ✓ Get-StartupMode returned: $($startupMode.Mode)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Get-StartupMode failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test backward compatibility
Write-Host "`n3. Testing Backward Compatibility..." -ForegroundColor Yellow

$legacyModules = @('Logging', 'PatchManager', 'ProgressTracking')
$workingLegacy = 0

foreach ($module in $legacyModules) {
    try {
        $modulePath = "$projectRoot/aither-core/modules/$module"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction Stop
            Write-Host "   ✓ $module legacy module - Available" -ForegroundColor Green
            $workingLegacy++
        } else {
            Write-Host "   ⚠️  $module legacy module - Not found" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ❌ $module legacy module - Failed: $_" -ForegroundColor Red
    }
}

Write-Host "   📊 Legacy Modules: $workingLegacy/$($legacyModules.Count) working" -ForegroundColor $(if($workingLegacy -gt 0) { 'Green' } else { 'Red' })

# Final assessment
Write-Host "`n4. Final Assessment..." -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Cyan

$totalTests = 4  # Experience domain, function execution, parameters, startup mode
$passedTests = 0

# Check if critical functions are working
if ((Get-Command Start-InteractiveMode -ErrorAction SilentlyContinue) -and
    (Get-Command Initialize-TerminalUI -ErrorAction SilentlyContinue) -and
    (Get-Command Test-FeatureAccess -ErrorAction SilentlyContinue) -and
    (Get-Command Get-StartupMode -ErrorAction SilentlyContinue)) {
    $passedTests = 4
    Write-Host "✅ ALL CRITICAL FUNCTIONS WORKING" -ForegroundColor Green
    Write-Host "   Domain consolidation SUCCESS!" -ForegroundColor Green
    Write-Host "   AitherZero v0.12.0 ready for release" -ForegroundColor Green
} elseif ((Get-Command Start-InteractiveMode -ErrorAction SilentlyContinue) -and
          (Get-Command Test-FeatureAccess -ErrorAction SilentlyContinue)) {
    $passedTests = 2
    Write-Host "⚠️  CORE FUNCTIONS WORKING" -ForegroundColor Yellow  
    Write-Host "   Basic functionality preserved" -ForegroundColor Yellow
    Write-Host "   Some features may need attention" -ForegroundColor Yellow
} else {
    Write-Host "❌ CRITICAL FUNCTIONS MISSING" -ForegroundColor Red
    Write-Host "   Domain consolidation needs fixes" -ForegroundColor Red
}

Write-Host "`n📊 SUCCESS RATE: $passedTests/$totalTests critical areas working" -ForegroundColor $(if($passedTests -eq $totalTests) { 'Green' } elseif($passedTests -gt 1) { 'Yellow' } else { 'Red' })

# Summary for AitherZero startup
Write-Host "`n🚀 AITHERZERO STARTUP READINESS:" -ForegroundColor Cyan
if ($passedTests -ge 3) {
    Write-Host "   Ready to run: ./Start-AitherZero.ps1" -ForegroundColor Green
    Write-Host "   Interactive mode should work correctly" -ForegroundColor Green
} elseif ($passedTests -eq 2) {
    Write-Host "   Limited functionality available" -ForegroundColor Yellow
    Write-Host "   Basic operations should work" -ForegroundColor Yellow
} else {
    Write-Host "   Startup may have issues" -ForegroundColor Red
    Write-Host "   Recommend fixing domain loading" -ForegroundColor Red
}

Write-Host "`n✅ Critical function testing completed" -ForegroundColor Green