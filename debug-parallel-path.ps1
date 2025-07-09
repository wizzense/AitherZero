#!/usr/bin/env pwsh
# Debug the parallel path error

$env:PROJECT_ROOT = "/workspaces/AitherZero"

# Import required modules
Import-Module ./aither-core/modules/Logging -Force -Global
Import-Module ./aither-core/modules/TestingFramework -Force
Import-Module ./aither-core/modules/ParallelExecution -Force

Write-Host "Debugging Parallel Path Error:" -ForegroundColor Cyan

# Create a test job that should trigger the error
$testJob = @{
    ModuleName = "AIToolsIntegration"
    Phase = "Unit"
    TestPath = "/workspaces/AitherZero/aither-core/modules/AIToolsIntegration/tests/AIToolsIntegration.Tests.ps1"
    Configuration = @{
        Verbosity = "Normal"
        TimeoutMinutes = 30
    }
    TestingFrameworkPath = "/workspaces/AitherZero/aither-core/modules/TestingFramework"
    ProjectRoot = "/workspaces/AitherZero"
    OutputPath = "./tests/results/unified"
}

# Create the exact scriptblock used in TestingFramework
$debugScriptBlock = {
    param($testJob)
    
    $ErrorActionPreference = 'Stop'
    
    try {
        Write-Host "[DEBUG] Inside parallel scriptblock" -ForegroundColor Yellow
        Write-Host "[DEBUG] TestJob properties:" -ForegroundColor Yellow
        $testJob.GetEnumerator() | ForEach-Object {
            Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor White
        }
        
        # Check environment
        Write-Host "[DEBUG] Environment check:" -ForegroundColor Yellow
        Write-Host "  PSScriptRoot: $PSScriptRoot" -ForegroundColor White
        Write-Host "  Current Location: $(Get-Location)" -ForegroundColor White
        Write-Host "  PROJECT_ROOT env: $env:PROJECT_ROOT" -ForegroundColor White
        
        # Re-import required modules in job context
        if ($testJob.ProjectRoot) {
            $env:PROJECT_ROOT = $testJob.ProjectRoot
            Write-Host "[DEBUG] Set PROJECT_ROOT to: $env:PROJECT_ROOT" -ForegroundColor Green
        }
        
        # Import TestingFramework module in the job context
        Write-Host "[DEBUG] Checking TestingFramework path: $($testJob.TestingFrameworkPath)" -ForegroundColor Yellow
        if ($testJob.TestingFrameworkPath -and (Test-Path $testJob.TestingFrameworkPath)) {
            Write-Host "[DEBUG] TestingFramework path exists, importing..." -ForegroundColor Green
            Import-Module $testJob.TestingFrameworkPath -Force -ErrorAction Stop
            Write-Host "[DEBUG] TestingFramework imported successfully" -ForegroundColor Green
        } else {
            throw "TestingFramework path is invalid or null: '$($testJob.TestingFrameworkPath)'"
        }
        
        # Initialize logging system
        if ($testJob.ProjectRoot) {
            Write-Host "[DEBUG] Initializing logging..." -ForegroundColor Yellow
            
            # This is likely where the error occurs - Join-Path with null
            try {
                $loggingPath = Join-Path $testJob.ProjectRoot "aither-core/modules/Logging"
                Write-Host "[DEBUG] Logging path: $loggingPath" -ForegroundColor Green
            } catch {
                Write-Host "[DEBUG] ERROR in Join-Path: $_" -ForegroundColor Red
                Write-Host "[DEBUG] ProjectRoot value: '$($testJob.ProjectRoot)'" -ForegroundColor Red
                throw
            }
            
            if (Test-Path $loggingPath) {
                Import-Module $loggingPath -Force -ErrorAction SilentlyContinue
                Write-Host "[DEBUG] Logging module imported" -ForegroundColor Green
            }
        }
        
        # Now try to invoke the actual test phase
        Write-Host "[DEBUG] About to invoke test phase..." -ForegroundColor Yellow
        Write-Host "[DEBUG] Available commands:" -ForegroundColor Yellow
        Get-Command -Module TestingFramework | Select-Object -First 5 | ForEach-Object {
            Write-Host "  $_" -ForegroundColor White
        }
        
        return @{
            Success = $true
            Module = $testJob.ModuleName
            Message = "Debug completed"
        }
        
    } catch {
        Write-Host "[DEBUG] CAUGHT ERROR: $_" -ForegroundColor Red
        Write-Host "[DEBUG] Error Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        Write-Host "[DEBUG] Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
        
        return @{
            Success = $false
            Module = $testJob.ModuleName
            Error = $_.Exception.Message
            ErrorType = $_.Exception.GetType().FullName
            StackTrace = $_.ScriptStackTrace
        }
    }
}

# Test with single job
Write-Host "`nTesting with debug scriptblock:" -ForegroundColor Cyan
try {
    $result = Invoke-ParallelForEach -InputObject @($testJob) -ScriptBlock $debugScriptBlock
    $result | Format-List
} catch {
    Write-Host "Outer Error: $_" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}