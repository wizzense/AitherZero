#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    High-performance parallel test execution optimized for AitherZero
.DESCRIPTION
    Optimized test runner that:
    - Uses AitherZero orchestration for parallel execution 
    - Minimizes configuration reloading bottlenecks
    - Runs tests in isolated processes to prevent interference
    - Leverages intelligent test batching and caching
    - Provides fast feedback for development workflows
    
    Exit Codes:
    0   - All tests passed
    1   - One or more tests failed
    2   - Test execution error
    
.NOTES
    Stage: Testing
    Order: 0450
    Dependencies: 0400
    Tags: testing, optimized, parallel, fast, orchestration
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TestPath = "./tests",
    [ValidateSet('Unit', 'Integration', 'All', 'Smart')]
    [string]$TestType = 'Smart',
    
    [int]$MaxWorkers = [Environment]::ProcessorCount,
    [int]$BatchSize = 5,
    
    [switch]$NoCoverage,
    [switch]$FastFail,
    [switch]$UseCache,
    [int]$CacheMinutes = 10,
    
    [string]$OutputPath = "./tests/results/optimized",
    [switch]$CI,
    [switch]$Verbose,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Performance optimizations
$ProgressPreference = 'SilentlyContinue'  # Disable progress bars for speed
$VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }

# Initialize
$projectRoot = Split-Path $PSScriptRoot -Parent
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$startTime = Get-Date

# Logging helper
function Write-OptimizedLog {
    param([string]$Message, [string]$Level = 'Info')
    $time = (Get-Date).ToString("HH:mm:ss.fff")
    $prefix = switch ($Level) {
        'Error' { '❌' }
        'Warning' { '⚠️ ' }  
        'Success' { '✅' }
        'Info' { '🔍' }
        default { '  ' }
    }
    Write-Host "[$time] $prefix $Message" -ForegroundColor $(
        switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Success' { 'Green' }
            'Info' { 'Cyan' }
            default { 'White' }
        }
    )
}

Write-OptimizedLog "🚀 Starting optimized test execution"
Write-OptimizedLog "Test Type: $TestType | Workers: $MaxWorkers | Batch Size: $BatchSize"

# Ensure output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

# Smart test discovery with caching
function Get-TestFilesOptimized {
    param([string]$Path, [string]$Type)
    
    $cacheFile = Join-Path $OutputPath "test-discovery-cache.json"
    $useCache = $UseCache -and (Test-Path $cacheFile) -and 
                ((Get-Date) - (Get-Item $cacheFile).LastWriteTime).TotalMinutes -lt $CacheMinutes
    
    if ($useCache) {
        Write-OptimizedLog "📦 Using cached test discovery"
        $cached = Get-Content $cacheFile | ConvertFrom-Json
        return $cached.TestFiles
    }
    
    Write-OptimizedLog "🔍 Discovering test files..."
    
    $searchPaths = switch ($Type) {
        'Unit' { @("$Path/unit") }
        'Integration' { @("$Path/integration") }  
        'All' { @("$Path/unit", "$Path/integration") }
        'Smart' {
            # Smart: prioritize unit tests, add integration if time allows
            $unitPath = "$Path/unit"
            $integrationPath = "$Path/integration"
            
            $unitTests = if (Test-Path $unitPath) {
                Get-ChildItem -Path $unitPath -Filter "*.Tests.ps1" -Recurse
            } else { @() }
            
            # For smart mode, only include fast integration tests
            $fastIntegrationTests = if (Test-Path $integrationPath) {
                Get-ChildItem -Path $integrationPath -Filter "*.Tests.ps1" -Recurse | 
                Where-Object { $_.Length -lt 50KB }  # Small files are usually faster
            } else { @() }
            
            Write-OptimizedLog "Smart mode: $($unitTests.Count) unit tests + $($fastIntegrationTests.Count) fast integration tests"
            return ($unitTests + $fastIntegrationTests)
        }
    }
    
    $testFiles = @()
    foreach ($searchPath in $searchPaths) {
        if (Test-Path $searchPath) {
            $testFiles += Get-ChildItem -Path $searchPath -Filter "*.Tests.ps1" -Recurse
        }
    }
    
    # Cache the discovery
    @{
        Timestamp = Get-Date
        TestFiles = $testFiles | ForEach-Object { $_.FullName }
    } | ConvertTo-Json | Set-Content $cacheFile
    
    Write-OptimizedLog "📁 Found $($testFiles.Count) test files"
    return $testFiles
}

# Optimized test batch creation
function New-TestBatches {
    param([array]$TestFiles, [int]$BatchSize)
    
    # Sort by file size (smaller files first for faster feedback)
    $sortedFiles = $TestFiles | Sort-Object Length
    
    $batches = @()
    for ($i = 0; $i -lt $sortedFiles.Count; $i += $BatchSize) {
        $batch = $sortedFiles | Select-Object -Skip $i -First $BatchSize
        $batches += ,@($batch)
    }
    
    Write-OptimizedLog "📦 Created $($batches.Count) test batches (size: $BatchSize)"
    return $batches
}



# Main execution
if ($PSCmdlet.ShouldProcess("Test execution", "Run optimized tests")) {
    
    # Discover tests
    $testFiles = Get-TestFilesOptimized -Path $TestPath -Type $TestType
    
    if ($testFiles.Count -eq 0) {
        Write-OptimizedLog "⚠️  No test files found" "Warning"
        exit 0
    }
    
    # Create batches
    $batches = New-TestBatches -TestFiles $testFiles -BatchSize $BatchSize
    
    Write-OptimizedLog "🚀 Executing $($batches.Count) batches with $MaxWorkers workers"
    
    # Execute batches in parallel using PowerShell 7's ForEach-Object -Parallel
    # Create indexed batches for parallel processing
    $indexedBatches = for ($i = 0; $i -lt $batches.Count; $i++) {
        @{ Index = $i; Batch = $batches[$i] }
    }
    
    $batchResults = $indexedBatches | ForEach-Object -ThrottleLimit $MaxWorkers -Parallel {
        $batchInfo = $_
        $batch = $batchInfo.Batch
        $batchIndex = $batchInfo.Index
        $OutputPath = $using:OutputPath
        $timestamp = $using:timestamp
        
        # Invoke-TestBatchIsolated function logic inline
        $TestFiles = $batch | ForEach-Object { $_.FullName }
        $batchOutput = Join-Path $OutputPath "batch-$BatchIndex-$timestamp.xml"
        $batchLog = Join-Path $OutputPath "batch-$BatchIndex-$timestamp.log"
        
        # Create minimal PowerShell script for isolated execution
        $testScript = @"
# Optimized test execution script - minimal imports to reduce startup time
`$ProgressPreference = 'SilentlyContinue'
`$VerbosePreference = 'SilentlyContinue'  
`$WarningPreference = 'SilentlyContinue'
`$InformationPreference = 'SilentlyContinue'

# Disable configuration file watching to prevent reloads
`$env:AITHERZERO_NO_CONFIG_WATCH = 'true'
`$env:AITHERZERO_MINIMAL_LOGGING = 'true'
`$env:AITHERZERO_TEST_MODE = 'true'

try {
    Import-Module Pester -Force -WarningAction SilentlyContinue
    
    `$config = New-PesterConfiguration
    `$config.Run.Path = @('$($TestFiles -join "', '")')
    `$config.Run.PassThru = `$true
    `$config.Run.Exit = `$false
    `$config.Output.Verbosity = 'None'  # Minimal output for speed
    `$config.TestResult.Enabled = `$true
    `$config.TestResult.OutputPath = '$batchOutput'
    `$config.TestResult.OutputFormat = 'NUnitXml'
    
    # Run tests
    `$result = Invoke-Pester -Configuration `$config
    
    # Return summary
    @{
        BatchIndex = $BatchIndex
        Passed = `$result.PassedCount
        Failed = `$result.FailedCount  
        Skipped = `$result.SkippedCount
        Duration = `$result.Duration.TotalSeconds
        Success = (`$result.FailedCount -eq 0)
    } | ConvertTo-Json
    
} catch {
    @{
        BatchIndex = $BatchIndex
        Error = `$_.Exception.Message
        Success = `$false
    } | ConvertTo-Json
}
"@
        
        # Execute in isolated PowerShell process
        $result = pwsh -Command $testScript 2>$batchLog
        
        try {
            $batchResult = $result | ConvertFrom-Json
            if ($batchResult) {
                Write-Host "Batch $batchIndex completed: $($batchResult.Passed) passed, $($batchResult.Failed) failed" -ForegroundColor $(if ($batchResult.Success) { 'Green' } else { 'Red' })
                return $batchResult
            } else {
                Write-Warning "Batch $batchIndex returned no result"
                return @{ BatchIndex = $batchIndex; Success = $false; Error = "No result returned" }
            }
        } catch {
            Write-Warning "Failed to parse batch $batchIndex result: $_"
            return @{ BatchIndex = $batchIndex; Success = $false; Error = $_.Exception.Message }
        }
    }
    
    # Aggregate results
    $totalPassed = ($batchResults | Measure-Object Passed -Sum).Sum
    $totalFailed = ($batchResults | Measure-Object Failed -Sum).Sum  
    $totalSkipped = ($batchResults | Measure-Object Skipped -Sum).Sum
    $totalDuration = ($batchResults | Measure-Object Duration -Sum).Sum
    $allSuccess = ($batchResults | Where-Object { -not $_.Success }).Count -eq 0
    
    $endTime = Get-Date
    $totalElapsed = ($endTime - $startTime).TotalSeconds
    
    # Results summary
    $summary = @{
        TestType = $TestType
        TotalTests = $totalPassed + $totalFailed + $totalSkipped
        Passed = $totalPassed
        Failed = $totalFailed
        Skipped = $totalSkipped  
        Success = $allSuccess
        Duration = [math]::Round($totalElapsed, 2)
        TestExecutionTime = [math]::Round($totalDuration, 2)
        Efficiency = [math]::Round(($totalDuration / $totalElapsed) * 100, 1)
        Batches = $batchResults.Count
        Workers = $MaxWorkers
        Timestamp = Get-Date
    }
    
    # Save summary
    $summaryPath = Join-Path $OutputPath "optimized-summary-$timestamp.json"
    $summary | ConvertTo-Json -Depth 10 | Set-Content $summaryPath
    
    # Display results
    Write-Host "`n" -NoNewline
    if ($allSuccess) {
        Write-OptimizedLog "🎉 All tests passed!" "Success"
    } else {
        Write-OptimizedLog "❌ Some tests failed" "Error"
    }
    
    Write-Host @"

📊 Test Results Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Passed:      $totalPassed
❌ Failed:      $totalFailed  
⏭️  Skipped:     $totalSkipped
🕒 Duration:    $($summary.Duration)s (efficiency: $($summary.Efficiency)%)
⚡ Batches:     $($summary.Batches) batches, $MaxWorkers workers
📁 Results:     $OutputPath

"@

    # Show failed batches if any
    $failedBatches = $batchResults | Where-Object { -not $_.Success }
    if ($failedBatches) {
        Write-Host "❌ Failed Batches:" -ForegroundColor Red
        $failedBatches | ForEach-Object {
            Write-Host "   Batch $($_.BatchIndex): $($_.Error -replace "`n", " ")" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    Write-OptimizedLog "📄 Summary saved to: $summaryPath"
    
    # Exit with appropriate code
    exit $(if ($allSuccess) { 0 } else { 1 })
    
} else {
    Write-OptimizedLog "👀 DryRun: Would execute $($testFiles.Count) tests in $($batches.Count) batches"
    Write-OptimizedLog "   Workers: $MaxWorkers | Batch Size: $BatchSize"
    exit 0
}