#!/usr/bin/env pwsh
# Debug the module test phase execution

$env:PROJECT_ROOT = "/workspaces/AitherZero"

# Import required modules
Import-Module ./aither-core/modules/Logging -Force -Global
Import-Module ./aither-core/modules/TestingFramework -Force

Write-Host "Debugging Module Test Phase Execution:" -ForegroundColor Cyan

# Create test configuration
$testConfiguration = @{
    Verbosity = "Normal"
    TimeoutMinutes = 30
    RetryCount = 2
    MockLevel = "Standard"
    Platform = "All"
    ParallelJobs = 4
    EnableCoverage = $false
    CoverageThreshold = 80
    EnablePerformanceMetrics = $true
    MaxMemoryUsageMB = 1024
}

# Test a single module
$moduleName = "AIToolsIntegration"
$testPath = "/workspaces/AitherZero/aither-core/modules/AIToolsIntegration/tests/AIToolsIntegration.Tests.ps1"

Write-Host "`nInvoking Invoke-ModuleTestPhase directly:" -ForegroundColor Yellow
try {
    $result = Invoke-ModuleTestPhase -ModuleName $moduleName -Phase "Unit" -TestPath $testPath -Configuration $testConfiguration
    
    Write-Host "`nTest Phase Result:" -ForegroundColor Green
    $result | Format-List
    
} catch {
    Write-Host "Error in Invoke-ModuleTestPhase: $_" -ForegroundColor Red
    Write-Host "Error Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
    
    # Check inner exception
    if ($_.Exception.InnerException) {
        Write-Host "`nInner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        Write-Host "Inner Type: $($_.Exception.InnerException.GetType().FullName)" -ForegroundColor Red
    }
}