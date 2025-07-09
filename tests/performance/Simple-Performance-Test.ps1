#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Simplified performance test for AitherZero domain architecture
.DESCRIPTION
    This script provides focused performance testing for the AitherZero domain architecture,
    specifically comparing domain loading vs traditional module loading performance.
.NOTES
    Performance Test Agent 7 - Focused Performance Validation
#>

param(
    [int]$Iterations = 5,
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Find project root
$ProjectRoot = $PSScriptRoot
while ($ProjectRoot -and -not (Test-Path (Join-Path $ProjectRoot ".git"))) {
    $ProjectRoot = Split-Path $ProjectRoot -Parent
}

if (-not $ProjectRoot) {
    throw "Could not find project root"
}

Write-Host "🚀 AitherZero Performance Test" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Gray
Write-Host "Iterations: $Iterations" -ForegroundColor Yellow
Write-Host "=" * 50 -ForegroundColor DarkGray

# Performance measurement function
function Measure-Operation {
    param(
        [scriptblock]$Operation,
        [string]$Name,
        [int]$Iterations = 5
    )
    
    $measurements = @()
    
    for ($i = 1; $i -le $Iterations; $i++) {
        # Force garbage collection for accurate measurement
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        
        $startTime = Get-Date
        $startMemory = [System.GC]::GetTotalMemory($false)
        
        try {
            $result = & $Operation
            $success = $true
        } catch {
            $result = $_.Exception.Message
            $success = $false
        }
        
        $endTime = Get-Date
        $endMemory = [System.GC]::GetTotalMemory($false)
        
        $measurements += @{
            Iteration = $i
            Duration = ($endTime - $startTime).TotalMilliseconds
            MemoryUsed = ($endMemory - $startMemory) / 1MB
            Success = $success
            Result = $result
        }
        
        if ($Verbose) {
            Write-Host "  Iteration $i/$Iterations - $([math]::Round(($endTime - $startTime).TotalMilliseconds, 2))ms" -ForegroundColor Gray
        }
    }
    
    # Calculate statistics
    $successfulMeasurements = $measurements | Where-Object { $_.Success }
    $durations = $successfulMeasurements | ForEach-Object { $_.Duration }
    $memoryUsages = $successfulMeasurements | ForEach-Object { $_.MemoryUsed }
    
    if ($durations.Count -eq 0) {
        Write-Host "❌ $Name - All iterations failed" -ForegroundColor Red
        return $null
    }
    
    $stats = @{
        Name = $Name
        Iterations = $Iterations
        SuccessCount = $successfulMeasurements.Count
        SuccessRate = ($successfulMeasurements.Count / $Iterations) * 100
        AverageDuration = ($durations | Measure-Object -Average).Average
        MinDuration = ($durations | Measure-Object -Minimum).Minimum
        MaxDuration = ($durations | Measure-Object -Maximum).Maximum
        AverageMemory = ($memoryUsages | Measure-Object -Average).Average
        MinMemory = ($memoryUsages | Measure-Object -Minimum).Minimum
        MaxMemory = ($memoryUsages | Measure-Object -Maximum).Maximum
        Measurements = $measurements
    }
    
    Write-Host "✅ $Name" -ForegroundColor Green
    Write-Host "  Success Rate: $([math]::Round($stats.SuccessRate, 1))%" -ForegroundColor Cyan
    Write-Host "  Average Duration: $([math]::Round($stats.AverageDuration, 2))ms" -ForegroundColor Cyan
    Write-Host "  Average Memory: $([math]::Round($stats.AverageMemory, 2))MB" -ForegroundColor Cyan
    Write-Host "  Range: $([math]::Round($stats.MinDuration, 2))ms - $([math]::Round($stats.MaxDuration, 2))ms" -ForegroundColor Gray
    
    return $stats
}

# Test 1: Domain Loading Performance
Write-Host "`n📦 Testing Domain Loading Performance..." -ForegroundColor Yellow
$domainLoadingStats = Measure-Operation -Name "Domain Loading" -Iterations $Iterations -Operation {
    # Import AitherCore with domain loading
    $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
    Import-Module $aitherCorePath -Force -Global -ErrorAction Stop
    
    # Initialize with domain loading
    $result = Initialize-CoreApplication -RequiredOnly:$false -Force:$true
    
    # Get status
    $status = Get-CoreModuleStatus
    $loadedCount = ($status | Where-Object { $_.Loaded }).Count
    
    # Clean up
    Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore', 'AIToolsIntegration', 'ConfigurationCarousel', 'DevEnvironment', 'PatchManager', 'TestingFramework', 'ParallelExecution', 'ProgressTracking', 'ModuleCommunication', 'OrchestrationEngine', 'RemoteConnection', 'RestAPIServer') } | Remove-Module -Force -ErrorAction SilentlyContinue
    
    return @{
        Success = $result
        LoadedCount = $loadedCount
    }
}

# Test 2: Traditional Module Loading Performance
Write-Host "`n🔧 Testing Traditional Module Loading Performance..." -ForegroundColor Yellow
$traditionalLoadingStats = Measure-Operation -Name "Traditional Module Loading" -Iterations $Iterations -Operation {
    # Load modules individually
    $moduleNames = @(
        "Logging",
        "BackupManager", 
        "ConfigurationCore",
        "AIToolsIntegration",
        "ConfigurationCarousel",
        "DevEnvironment",
        "PatchManager",
        "TestingFramework"
    )
    
    $loadedModules = 0
    foreach ($moduleName in $moduleNames) {
        $modulePath = Join-Path $ProjectRoot "aither-core/modules/$moduleName"
        if (Test-Path $modulePath) {
            try {
                Import-Module $modulePath -Force -Global -ErrorAction Stop
                $loadedModules++
            } catch {
                # Continue with other modules
            }
        }
    }
    
    # Clean up
    Get-Module | Where-Object { $_.Name -in $moduleNames } | Remove-Module -Force -ErrorAction SilentlyContinue
    
    return @{
        Success = $loadedModules -gt 0
        LoadedCount = $loadedModules
    }
}

# Test 3: Minimal Domain Loading (Required Only)
Write-Host "`n⚡ Testing Minimal Domain Loading Performance..." -ForegroundColor Yellow
$minimalLoadingStats = Measure-Operation -Name "Minimal Domain Loading" -Iterations $Iterations -Operation {
    # Import AitherCore with minimal loading
    $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
    Import-Module $aitherCorePath -Force -Global -ErrorAction Stop
    
    # Initialize with required only
    $result = Initialize-CoreApplication -RequiredOnly:$true -Force:$true
    
    # Get status
    $status = Get-CoreModuleStatus
    $loadedCount = ($status | Where-Object { $_.Loaded }).Count
    
    # Clean up
    Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore', 'AIToolsIntegration', 'ConfigurationCarousel', 'DevEnvironment', 'PatchManager', 'TestingFramework', 'ParallelExecution', 'ProgressTracking', 'ModuleCommunication', 'OrchestrationEngine', 'RemoteConnection', 'RestAPIServer') } | Remove-Module -Force -ErrorAction SilentlyContinue
    
    return @{
        Success = $result
        LoadedCount = $loadedCount
    }
}

# Test 4: Core Function Performance
Write-Host "`n🎯 Testing Core Function Performance..." -ForegroundColor Yellow
$corePerformanceStats = Measure-Operation -Name "Core Function Performance" -Iterations $Iterations -Operation {
    # Import AitherCore
    $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
    Import-Module $aitherCorePath -Force -Global -ErrorAction Stop
    
    # Test core functions
    $operations = @()
    
    # Initialize
    $result = Initialize-CoreApplication -RequiredOnly:$true -Force:$true
    $operations += "Initialize"
    
    # Get status
    if (Get-Command Get-CoreModuleStatus -ErrorAction SilentlyContinue) {
        $status = Get-CoreModuleStatus
        $operations += "GetStatus"
    }
    
    # Test health
    if (Get-Command Test-CoreApplicationHealth -ErrorAction SilentlyContinue) {
        $health = Test-CoreApplicationHealth
        $operations += "TestHealth"
    }
    
    # Get platform info
    if (Get-Command Get-PlatformInfo -ErrorAction SilentlyContinue) {
        $platform = Get-PlatformInfo
        $operations += "GetPlatform"
    }
    
    # Clean up
    Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore', 'AIToolsIntegration', 'ConfigurationCarousel', 'DevEnvironment', 'PatchManager', 'TestingFramework', 'ParallelExecution', 'ProgressTracking', 'ModuleCommunication', 'OrchestrationEngine', 'RemoteConnection', 'RestAPIServer') } | Remove-Module -Force -ErrorAction SilentlyContinue
    
    return @{
        Success = $result
        Operations = $operations
        OperationCount = $operations.Count
    }
}

# Performance Analysis
Write-Host "`n📊 Performance Analysis:" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor DarkGray

# Compare domain vs traditional loading
if ($domainLoadingStats -and $traditionalLoadingStats) {
    $domainFaster = $domainLoadingStats.AverageDuration -lt $traditionalLoadingStats.AverageDuration
    $speedupRatio = if ($domainLoadingStats.AverageDuration -gt 0) { $traditionalLoadingStats.AverageDuration / $domainLoadingStats.AverageDuration } else { 0 }
    $memoryEfficient = $domainLoadingStats.AverageMemory -lt $traditionalLoadingStats.AverageMemory
    $memorySavings = $traditionalLoadingStats.AverageMemory - $domainLoadingStats.AverageMemory
    
    Write-Host "🔄 Domain vs Traditional Loading:" -ForegroundColor White
    Write-Host "  Domain faster: $domainFaster" -ForegroundColor $(if ($domainFaster) { 'Green' } else { 'Red' })
    Write-Host "  Speed ratio: $([math]::Round($speedupRatio, 2))x" -ForegroundColor Cyan
    Write-Host "  Memory efficient: $memoryEfficient" -ForegroundColor $(if ($memoryEfficient) { 'Green' } else { 'Red' })
    Write-Host "  Memory difference: $([math]::Round($memorySavings, 2))MB" -ForegroundColor Cyan
}

# Compare minimal vs full domain loading
if ($minimalLoadingStats -and $domainLoadingStats) {
    $minimalFaster = $minimalLoadingStats.AverageDuration -lt $domainLoadingStats.AverageDuration
    $minimalSpeedup = if ($minimalLoadingStats.AverageDuration -gt 0) { $domainLoadingStats.AverageDuration / $minimalLoadingStats.AverageDuration } else { 0 }
    $minimalMemoryEfficient = $minimalLoadingStats.AverageMemory -lt $domainLoadingStats.AverageMemory
    $minimalMemorySavings = $domainLoadingStats.AverageMemory - $minimalLoadingStats.AverageMemory
    
    Write-Host "`n⚡ Minimal vs Full Domain Loading:" -ForegroundColor White
    Write-Host "  Minimal faster: $minimalFaster" -ForegroundColor $(if ($minimalFaster) { 'Green' } else { 'Red' })
    Write-Host "  Speed ratio: $([math]::Round($minimalSpeedup, 2))x" -ForegroundColor Cyan
    Write-Host "  Memory efficient: $minimalMemoryEfficient" -ForegroundColor $(if ($minimalMemoryEfficient) { 'Green' } else { 'Red' })
    Write-Host "  Memory savings: $([math]::Round($minimalMemorySavings, 2))MB" -ForegroundColor Cyan
}

# Performance recommendations
Write-Host "`n💡 Performance Recommendations:" -ForegroundColor Yellow
Write-Host "=" * 50 -ForegroundColor DarkGray

$recommendations = @()

# Analyze results and provide recommendations
if ($domainLoadingStats -and $domainLoadingStats.SuccessRate -lt 100) {
    $recommendations += "⚠️  Domain loading has reliability issues ($([math]::Round($domainLoadingStats.SuccessRate, 1))% success rate)"
}

if ($traditionalLoadingStats -and $domainLoadingStats -and $traditionalLoadingStats.AverageDuration -lt $domainLoadingStats.AverageDuration) {
    $recommendations += "🐌 Domain loading is slower than traditional loading - investigate domain file structure"
}

if ($minimalLoadingStats -and $domainLoadingStats -and $minimalLoadingStats.AverageDuration -lt ($domainLoadingStats.AverageDuration * 0.5)) {
    $recommendations += "⚡ Minimal loading is significantly faster - consider lazy loading for non-essential modules"
}

if ($domainLoadingStats -and $domainLoadingStats.AverageMemory -gt 50) {
    $recommendations += "🧠 Domain loading uses significant memory ($([math]::Round($domainLoadingStats.AverageMemory, 2))MB) - optimize module imports"
}

if ($corePerformanceStats -and $corePerformanceStats.AverageDuration -gt 1000) {
    $recommendations += "🎯 Core functions are slow ($([math]::Round($corePerformanceStats.AverageDuration, 2))ms) - optimize critical paths"
}

if ($recommendations.Count -eq 0) {
    Write-Host "✅ No significant performance issues detected" -ForegroundColor Green
} else {
    foreach ($recommendation in $recommendations) {
        Write-Host "  $recommendation" -ForegroundColor Yellow
    }
}

# Performance verdict
Write-Host "`n🎯 Performance Verdict:" -ForegroundColor White
Write-Host "=" * 50 -ForegroundColor DarkGray

$overallGood = $true
$issues = @()

if ($domainLoadingStats -and $domainLoadingStats.SuccessRate -lt 90) {
    $overallGood = $false
    $issues += "Low reliability"
}

if ($domainLoadingStats -and $domainLoadingStats.AverageDuration -gt 3000) {
    $overallGood = $false
    $issues += "Slow startup"
}

if ($domainLoadingStats -and $domainLoadingStats.AverageMemory -gt 100) {
    $overallGood = $false
    $issues += "High memory usage"
}

if ($overallGood) {
    Write-Host "✅ ACCEPTABLE PERFORMANCE" -ForegroundColor Green
    Write-Host "Domain architecture performance is within acceptable limits" -ForegroundColor Green
} else {
    Write-Host "❌ PERFORMANCE ISSUES DETECTED" -ForegroundColor Red
    Write-Host "Issues: $($issues -join ', ')" -ForegroundColor Red
    Write-Host "Domain architecture requires optimization" -ForegroundColor Red
}

# Summary table
Write-Host "`n📋 Performance Summary:" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor DarkGray

$results = @(
    @{Test = "Domain Loading"; Duration = $domainLoadingStats.AverageDuration; Memory = $domainLoadingStats.AverageMemory; Success = $domainLoadingStats.SuccessRate},
    @{Test = "Traditional Loading"; Duration = $traditionalLoadingStats.AverageDuration; Memory = $traditionalLoadingStats.AverageMemory; Success = $traditionalLoadingStats.SuccessRate},
    @{Test = "Minimal Loading"; Duration = $minimalLoadingStats.AverageDuration; Memory = $minimalLoadingStats.AverageMemory; Success = $minimalLoadingStats.SuccessRate},
    @{Test = "Core Functions"; Duration = $corePerformanceStats.AverageDuration; Memory = $corePerformanceStats.AverageMemory; Success = $corePerformanceStats.SuccessRate}
)

foreach ($result in $results) {
    if ($result.Duration -and $result.Memory -and $result.Success) {
        $durationStr = "$([math]::Round($result.Duration, 2))ms"
        $memoryStr = "$([math]::Round($result.Memory, 2))MB"
        $successStr = "$([math]::Round($result.Success, 1))%"
        Write-Host "  $($result.Test.PadRight(20)) | $($durationStr.PadLeft(8)) | $($memoryStr.PadLeft(8)) | $($successStr.PadLeft(6))" -ForegroundColor Gray
    }
}

Write-Host "`n🏁 Performance test completed!" -ForegroundColor Green