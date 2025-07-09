#!/usr/bin/env pwsh
# Debug module discovery

$env:PROJECT_ROOT = "/workspaces/AitherZero"

# Import required modules
Import-Module ./aither-core/modules/Logging -Force -Global
Import-Module ./aither-core/modules/TestingFramework -Force

Write-Host "Testing Module Discovery:" -ForegroundColor Cyan

# Check modules directory
$modulesPath = Join-Path $env:PROJECT_ROOT "aither-core/modules"
Write-Host "`nModules Path: $modulesPath" -ForegroundColor Yellow
Write-Host "Exists: $(Test-Path $modulesPath)" -ForegroundColor White

if (Test-Path $modulesPath) {
    $moduleDirectories = Get-ChildItem -Path $modulesPath -Directory
    Write-Host "Module Directories Found: $($moduleDirectories.Count)" -ForegroundColor White
    
    # Check first few modules
    $moduleDirectories | Select-Object -First 5 | ForEach-Object {
        Write-Host "`n  Module: $($_.Name)" -ForegroundColor Green
        
        $moduleScript = Join-Path $_.FullName "$($_.Name).psm1"
        Write-Host "    Script: $(Test-Path $moduleScript)" -ForegroundColor White
        
        # Check for distributed tests
        $distributedTestFile = Join-Path $_.FullName "tests/$($_.Name).Tests.ps1"
        Write-Host "    Distributed Test: $(Test-Path $distributedTestFile) - $distributedTestFile" -ForegroundColor White
        
        # Check for centralized tests
        $centralizedTestPath = Join-Path $env:PROJECT_ROOT "tests/unit/modules/$($_.Name)"
        Write-Host "    Centralized Test: $(Test-Path $centralizedTestPath) - $centralizedTestPath" -ForegroundColor White
    }
}

# Test discovery function directly
Write-Host "`n`nTesting Get-DiscoveredModules:" -ForegroundColor Cyan
try {
    $discoveredModules = Get-DiscoveredModules
    Write-Host "Discovered Modules: $($discoveredModules.Count)" -ForegroundColor Green
    
    if ($discoveredModules.Count -gt 0) {
        Write-Host "`nFirst Module Details:" -ForegroundColor Yellow
        $firstModule = $discoveredModules[0]
        $firstModule | Format-List
    }
} catch {
    Write-Host "Error discovering modules: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
}

# Check test execution plan
Write-Host "`n`nTesting Test Execution Plan:" -ForegroundColor Cyan
try {
    $testPlan = New-TestExecutionPlan -TestSuite 'Unit' -Modules $discoveredModules -TestProfile 'Development'
    Write-Host "Test Plan Created Successfully" -ForegroundColor Green
    Write-Host "  Phases: $($testPlan.TestPhases -join ', ')" -ForegroundColor White
    Write-Host "  Module Count: $($testPlan.Modules.Count)" -ForegroundColor White
} catch {
    Write-Host "Error creating test plan: $_" -ForegroundColor Red
}