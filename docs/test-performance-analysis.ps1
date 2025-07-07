#!/usr/bin/env pwsh

# Performance Analysis Test Script
# Tests performance and memory usage of consolidated modules

$ErrorActionPreference = 'Stop'
Set-Location '/workspaces/AitherZero'

Write-Host "=== PERFORMANCE ANALYSIS ===" -ForegroundColor Cyan

# Function to measure memory usage
function Get-MemoryUsage {
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    $Process = Get-Process -Id $PID
    return [Math]::Round($Process.WorkingSet64 / 1MB, 2)
}

# Function to measure module loading time
function Measure-ModuleLoadTime {
    param([string]$ModulePath)
    
    $StartTime = Get-Date
    $StartMemory = Get-MemoryUsage
    
    try {
        Import-Module $ModulePath -Force
        $EndTime = Get-Date
        $EndMemory = Get-MemoryUsage
        
        $LoadTime = ($EndTime - $StartTime).TotalMilliseconds
        $MemoryIncrease = $EndMemory - $StartMemory
        
        return @{
            Success = $true
            LoadTime = $LoadTime
            MemoryIncrease = $MemoryIncrease
            Error = $null
        }
    } catch {
        return @{
            Success = $false
            LoadTime = 0
            MemoryIncrease = 0
            Error = $_.Exception.Message
        }
    }
}

# Test modules
$ModulesToTest = @(
    'ConfigurationCore',
    'PatchManager',
    'BackupManager',
    'DevEnvironment',
    'LabRunner',
    'ModuleCommunication',
    'StartupExperience',
    'SystemMonitoring',
    'TestingFramework'
)

$PerformanceResults = @()

Write-Host "Starting performance analysis..." -ForegroundColor Yellow
$InitialMemory = Get-MemoryUsage
Write-Host "Initial memory usage: $InitialMemory MB" -ForegroundColor Cyan

foreach ($Module in $ModulesToTest) {
    $ModulePath = "./aither-core/modules/$Module"
    
    if (Test-Path $ModulePath) {
        Write-Host "Testing $Module..." -ForegroundColor Green
        
        $Result = Measure-ModuleLoadTime -ModulePath $ModulePath
        
        $PerformanceResults += [PSCustomObject]@{
            ModuleName = $Module
            Success = $Result.Success
            LoadTimeMs = $Result.LoadTime
            MemoryIncreaseMB = $Result.MemoryIncrease
            Error = $Result.Error
        }
        
        if ($Result.Success) {
            Write-Host "  ✓ Loaded in $($Result.LoadTime) ms, Memory: +$($Result.MemoryIncrease) MB" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to load: $($Result.Error)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ⚠ Module not found: $ModulePath" -ForegroundColor Yellow
    }
}

$FinalMemory = Get-MemoryUsage
$TotalMemoryIncrease = $FinalMemory - $InitialMemory

Write-Host "`n=== PERFORMANCE SUMMARY ===" -ForegroundColor Cyan
Write-Host "Final memory usage: $FinalMemory MB" -ForegroundColor Cyan
Write-Host "Total memory increase: $TotalMemoryIncrease MB" -ForegroundColor Cyan

# Calculate statistics
$SuccessfulResults = $PerformanceResults | Where-Object { $_.Success }
if ($SuccessfulResults.Count -gt 0) {
    $AvgLoadTime = ($SuccessfulResults | Measure-Object -Property LoadTimeMs -Average).Average
    $TotalLoadTime = ($SuccessfulResults | Measure-Object -Property LoadTimeMs -Sum).Sum
    $AvgMemoryIncrease = ($SuccessfulResults | Measure-Object -Property MemoryIncreaseMB -Average).Average
    
    Write-Host "Average load time: $([Math]::Round($AvgLoadTime, 2)) ms" -ForegroundColor Green
    Write-Host "Total load time: $([Math]::Round($TotalLoadTime, 2)) ms" -ForegroundColor Green
    Write-Host "Average memory increase per module: $([Math]::Round($AvgMemoryIncrease, 2)) MB" -ForegroundColor Green
}

# Display detailed results
Write-Host "`n=== DETAILED RESULTS ===" -ForegroundColor Cyan
$PerformanceResults | Format-Table -AutoSize

# Test dependency resolution
Write-Host "`n=== DEPENDENCY RESOLUTION TEST ===" -ForegroundColor Cyan

try {
    # Test loading modules that depend on others
    Write-Host "Testing PatchManager (depends on ProgressTracking)..." -ForegroundColor Yellow
    Import-Module './aither-core/modules/PatchManager' -Force
    Write-Host "✓ PatchManager loaded successfully with dependencies" -ForegroundColor Green
    
    Write-Host "Testing ConfigurationCore (standalone)..." -ForegroundColor Yellow
    Import-Module './aither-core/modules/ConfigurationCore' -Force
    Write-Host "✓ ConfigurationCore loaded successfully" -ForegroundColor Green
    
    Write-Host "Testing TestingFramework (depends on multiple modules)..." -ForegroundColor Yellow
    Import-Module './aither-core/modules/TestingFramework' -Force
    Write-Host "✓ TestingFramework loaded successfully with dependencies" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Dependency resolution test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Export results
$PerformanceResults | ConvertTo-Json -Depth 3 | Out-File './docs/performance-analysis-results.json'
Write-Host "`nResults exported to: ./docs/performance-analysis-results.json" -ForegroundColor Cyan

Write-Host "`n=== PERFORMANCE ANALYSIS COMPLETE ===" -ForegroundColor Cyan