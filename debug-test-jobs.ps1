#!/usr/bin/env pwsh
# Debug script to investigate test jobs construction

$env:PROJECT_ROOT = "/workspaces/AitherZero"

# Import required modules
Import-Module ./aither-core/modules/Logging -Force -Global
Import-Module ./aither-core/modules/TestingFramework -Force

# Get test plan
$testPlan = Get-TestPlan -TestSuite 'Unit' -TestProfile 'Development' -Modules @() -OutputPath './tests/results/unified' -GenerateReport:$true -Parallel:$true

Write-Host "`nTest Plan Structure:" -ForegroundColor Cyan
Write-Host "TestPhases: $($testPlan.TestPhases -join ', ')" -ForegroundColor White
Write-Host "Modules Count: $($testPlan.Modules.Count)" -ForegroundColor White
Write-Host "Configuration: $($testPlan.Configuration | ConvertTo-Json -Depth 2)" -ForegroundColor White

# Check first few modules
Write-Host "`nFirst 3 Modules:" -ForegroundColor Cyan
$testPlan.Modules | Select-Object -First 3 | ForEach-Object {
    Write-Host "  Module: $($_.Name)" -ForegroundColor Yellow
    Write-Host "    TestPath: $($_.TestPath)" -ForegroundColor White
    Write-Host "    TestPath Exists: $(Test-Path $_.TestPath)" -ForegroundColor White
}

# Simulate test job creation
Write-Host "`nSimulating Test Job Creation:" -ForegroundColor Cyan
$phase = $testPlan.TestPhases[0]
$module = $testPlan.Modules[0]

$testJob = @{
    ModuleName = $module.Name
    Phase = $phase
    TestPath = $module.TestPath
    Configuration = $testPlan.Configuration
    TestingFrameworkPath = $PSScriptRoot
    ProjectRoot = $env:PROJECT_ROOT
    OutputPath = './tests/results/unified'
}

Write-Host "`nTest Job Structure:" -ForegroundColor Cyan
$testJob.GetEnumerator() | ForEach-Object {
    Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor White
}

# Check ParallelExecution module
Write-Host "`nChecking ParallelExecution module:" -ForegroundColor Cyan
try {
    Import-Module ./aither-core/modules/ParallelExecution -Force
    $parallelCommands = Get-Command -Module ParallelExecution
    Write-Host "  Module loaded successfully" -ForegroundColor Green
    Write-Host "  Available commands: $($parallelCommands.Name -join ', ')" -ForegroundColor White
    
    # Test with simple input
    Write-Host "`nTesting Invoke-ParallelForEach with simple input:" -ForegroundColor Cyan
    $simpleTest = @(1, 2, 3)
    try {
        $result = Invoke-ParallelForEach -InputObject $simpleTest -ScriptBlock { param($num) return $num * 2 }
        Write-Host "  Simple test succeeded: $($result -join ', ')" -ForegroundColor Green
    } catch {
        Write-Host "  Simple test failed: $_" -ForegroundColor Red
    }
    
} catch {
    Write-Host "  Failed to load ParallelExecution: $_" -ForegroundColor Red
}