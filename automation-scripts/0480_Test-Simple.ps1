#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Ultra-simple, high-performance test runner for AitherZero
.DESCRIPTION
    Completely redesigned testing infrastructure that:
    - Eliminates configuration reloading completely
    - Uses static configuration to prevent module loading cascades
    - Runs in true isolation with minimal dependencies
    - Designed for AI agents - simple, predictable, extensible
    - Uses AitherZero orchestration for intelligent parallel execution
    
    Performance Features:
    - No configuration module imports during test execution
    - Static configuration files instead of dynamic loading
    - Process isolation with minimal PowerShell startup
    - Intelligent test batching by file size and complexity
    - Zero-overhead logging during test runs
    
    Exit Codes:
    0   - All tests passed
    1   - One or more tests failed
    2   - Test execution error
    
.NOTES
    Stage: Testing
    Order: 0480
    Dependencies: None (self-contained)
    Tags: testing, simple, fast, ai-friendly, isolated
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TestPath = "./tests",
    [ValidateSet('unit', 'integration', 'all', 'fast')]
    [string]$Mode = 'fast',
    
    [int]$Workers = [Math]::Min([Environment]::ProcessorCount, 4),
    [int]$BatchSize = 3,
    
    [switch]$FailFast,
    [switch]$CI,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Performance: Disable all progress and verbose output
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'

# Get absolute paths
$projectRoot = Split-Path $PSScriptRoot -Parent
$testRoot = if ([System.IO.Path]::IsPathRooted($TestPath)) { $TestPath } else { Join-Path $projectRoot $TestPath }
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$startTime = Get-Date

# Simple logging (no external dependencies)
function Write-TestLog {
    param([string]$Message, [string]$Level = 'INFO')
    if ($Quiet) { return }
    
    $time = (Get-Date).ToString("HH:mm:ss")
    $emoji = @{
        'INFO' = '🔍'; 'SUCCESS' = '✅'; 'ERROR' = '❌'; 'WARNING' = '⚠️'
    }[$Level]
    
    Write-Host "[$time] $emoji $Message" -ForegroundColor $(
        @{ 'INFO' = 'Cyan'; 'SUCCESS' = 'Green'; 'ERROR' = 'Red'; 'WARNING' = 'Yellow' }[$Level]
    )
}

Write-TestLog "Starting simple test runner (Mode: $Mode, Workers: $Workers)"

# Ultra-fast test discovery
function Find-TestFiles {
    param([string]$Path, [string]$Mode)
    
    $searchPaths = switch ($Mode) {
        'unit' { @("$Path/unit") }
        'integration' { @("$Path/integration") }
        'all' { @("$Path/unit", "$Path/integration") }
        'fast' {
            # Fast mode: unit tests + small integration tests only
            $unitTests = if (Test-Path "$Path/unit") {
                Get-ChildItem "$Path/unit" -Filter "*.Tests.ps1" -Recurse
            } else { @() }
            
            $fastIntegration = if (Test-Path "$Path/integration") {
                Get-ChildItem "$Path/integration" -Filter "*.Tests.ps1" -Recurse | 
                Where-Object { $_.Length -lt 20KB }  # Only small files
            } else { @() }
            
            return ($unitTests + $fastIntegration) | Sort-Object Length
        }
    }
    
    $testFiles = @()
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $testFiles += Get-ChildItem $path -Filter "*.Tests.ps1" -Recurse
        }
    }
    
    # Sort by size (small files first for faster feedback)
    return $testFiles | Sort-Object Length
}

# Create static test configuration (no dynamic loading)
function New-StaticTestConfig {
    return @{
        # Static Pester configuration - no external dependencies
        Run = @{
            PassThru = $true
            Exit = $false
        }
        Output = @{
            Verbosity = if ($CI) { 'Normal' } else { 'Minimal' }
        }
        Should = @{
            ErrorAction = 'Continue'
        }
        TestResult = @{
            Enabled = $true
            OutputFormat = 'NUnitXml'
        }
        # No code coverage to avoid complexity and performance issues
        CodeCoverage = @{
            Enabled = $false
        }
    }
}



# Main execution
try {
    # Ensure results directory
    $resultsDir = Join-Path $testRoot "results"
    if (-not (Test-Path $resultsDir)) {
        New-Item -Path $resultsDir -ItemType Directory -Force | Out-Null
    }

    # Discover tests
    Write-TestLog "Discovering test files..."
    $testFiles = Find-TestFiles -Path $testRoot -Mode $Mode
    
    if ($testFiles.Count -eq 0) {
        Write-TestLog "No test files found in mode '$Mode'" "WARNING"
        exit 0
    }
    
    Write-TestLog "Found $($testFiles.Count) test files"
    
    # Create test batches
    $batches = @()
    for ($i = 0; $i -lt $testFiles.Count; $i += $BatchSize) {
        $batchFiles = $testFiles | Select-Object -Skip $i -First $BatchSize
        $batches += ,@($batchFiles)
    }
    
    Write-TestLog "Created $($batches.Count) batches (size: $BatchSize)"
    
    # Static configuration (no dynamic loading)
    $testConfig = New-StaticTestConfig
    
    if ($PSCmdlet.ShouldProcess("$($testFiles.Count) test files in $($batches.Count) batches", "Execute tests")) {
        
        Write-TestLog "Executing $($batches.Count) batches with $Workers workers"
        
        # Execute batches in parallel
        $batchJobs = for ($i = 0; $i -lt $batches.Count; $i++) {
            [PSCustomObject]@{
                BatchId = $i
                Files = $batches[$i] | ForEach-Object { $_.FullName }
            }
        }
        
        $batchResults = $batchJobs | ForEach-Object -ThrottleLimit $Workers -Parallel {
            $batch = $_
            $testConfig = $using:testConfig
            
            # Execute batch directly in parallel runspace
            $outputFile = Join-Path ($using:testRoot) "results/batch-$($batch.BatchId)-$($using:timestamp).xml"
            
            # Create minimal test execution script (zero dependencies)
            $isolatedScript = @"
# Minimal test script - no AitherZero dependencies to prevent config loading
`$ErrorActionPreference = 'Stop'
`$ProgressPreference = 'SilentlyContinue'
`$VerbosePreference = 'SilentlyContinue'
`$WarningPreference = 'SilentlyContinue'

# Prevent any AitherZero module loading
`$env:AITHERZERO_NO_MODULES = 'true'
`$env:AITHERZERO_TEST_ISOLATION = 'true'

try {
    # Only import Pester - nothing else
    Import-Module Pester -Force -WarningAction SilentlyContinue -ErrorAction Stop
    
    # Static configuration
    `$config = New-PesterConfiguration
    `$config.Run.Path = @($($batch.Files | ForEach-Object { "'$_'" } | Join-String -Separator ', '))
    `$config.Run.PassThru = `$true  
    `$config.Run.Exit = `$false
    `$config.Output.Verbosity = '$($testConfig.Output.Verbosity)'
    `$config.Should.ErrorAction = '$($testConfig.Should.ErrorAction)'
    `$config.TestResult.Enabled = `$true
    `$config.TestResult.OutputPath = '$outputFile'
    `$config.TestResult.OutputFormat = 'NUnitXml'
    
    # Execute tests
    `$result = Invoke-Pester -Configuration `$config
    
    # Return minimal result (avoid complex object serialization)
    [PSCustomObject]@{
        BatchId = $($batch.BatchId)
        Total = `$result.TotalCount
        Passed = `$result.PassedCount
        Failed = `$result.FailedCount
        Skipped = `$result.SkippedCount
        Duration = `$result.Duration.TotalSeconds
        Success = (`$result.FailedCount -eq 0)
        OutputFile = '$outputFile'
    }
} catch {
    [PSCustomObject]@{
        BatchId = $($batch.BatchId)
        Total = 0
        Passed = 0
        Failed = 0
        Skipped = 0
        Duration = 0
        Success = `$false
        Error = `$_.Exception.Message
        OutputFile = '$outputFile'
    }
}
"@

            # Execute in completely isolated PowerShell process
            $jsonOutput = pwsh -NoProfile -Command $isolatedScript
            if ([string]::IsNullOrWhiteSpace($jsonOutput)) {
                Write-Host "❌ Empty output from batch $($batch.BatchId)" -ForegroundColor Red
                return [PSCustomObject]@{
                    BatchId = $batch.BatchId; Total = 0; Passed = 0; Failed = 0; Skipped = 0
                    Duration = 0; Success = $false; Error = "Empty output"; OutputFile = ''
                }
            }
            try {
                # Extract JSON from the output (it's at the end after Pester output)
                $lines = $jsonOutput -split "`n"
                $jsonStart = -1
                for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                    if ($lines[$i].Trim() -match '^\s*\{') {
                        $jsonStart = $i
                        break
                    }
                }
                
                if ($jsonStart -ge 0) {
                    $jsonPart = ($lines[$jsonStart..($lines.Count-1)] | Where-Object { $_.Trim() }) -join "`n"
                    $result = $jsonPart | ConvertFrom-Json
                    return $result
                } else {
                    # No JSON found, create result from Pester output
                    $passedMatch = if ($jsonOutput -match "Tests Passed: (\d+)") { [int]$matches[1] } else { 0 }
                    $failedMatch = if ($jsonOutput -match "Failed: (\d+)") { [int]$matches[1] } else { 0 }
                    $skippedMatch = if ($jsonOutput -match "Skipped: (\d+)") { [int]$matches[1] } else { 0 }
                    
                    return [PSCustomObject]@{
                        BatchId = $batch.BatchId
                        Total = $passedMatch + $failedMatch + $skippedMatch  
                        Passed = $passedMatch
                        Failed = $failedMatch
                        Skipped = $skippedMatch
                        Duration = 1.0
                        Success = ($failedMatch -eq 0)
                        OutputFile = ''
                    }
                }
            } catch {
                Write-Host "❌ JSON parse error for batch $($batch.BatchId): $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "Raw output length: $($jsonOutput.Length)" -ForegroundColor Yellow
                return [PSCustomObject]@{
                    BatchId = $batch.BatchId; Total = 0; Passed = 0; Failed = 0; Skipped = 0
                    Duration = 0; Success = $false; Error = "JSON parse error: $($_.Exception.Message)"; OutputFile = ''
                }
            }
        }
        
        # Aggregate results
        $totalTests = ($batchResults | Measure-Object Total -Sum).Sum
        $totalPassed = ($batchResults | Measure-Object Passed -Sum).Sum
        $totalFailed = ($batchResults | Measure-Object Failed -Sum).Sum
        $totalSkipped = ($batchResults | Measure-Object Skipped -Sum).Sum
        $totalDuration = ($batchResults | Measure-Object Duration -Sum).Sum
        $allSuccess = ($batchResults | Where-Object { -not $_.Success }).Count -eq 0
        
        $endTime = Get-Date
        $wallClockTime = ($endTime - $startTime).TotalSeconds
        
        # Create comprehensive summary
        $summary = @{
            Mode = $Mode
            Success = $allSuccess
            Tests = @{
                Total = $totalTests
                Passed = $totalPassed
                Failed = $totalFailed
                Skipped = $totalSkipped
            }
            Performance = @{
                WallClockTime = [Math]::Round($wallClockTime, 2)
                TestExecutionTime = [Math]::Round($totalDuration, 2)
                ParallelEfficiency = [Math]::Round(($totalDuration / $wallClockTime) * 100, 1)
                Batches = $batches.Count
                Workers = $Workers
            }
            Files = $testFiles.Count
            Timestamp = Get-Date
            Results = $batchResults
        }
        
        # Save comprehensive results
        $summaryFile = Join-Path $resultsDir "simple-test-summary-$timestamp.json"
        $summary | ConvertTo-Json -Depth 10 | Set-Content $summaryFile
        
        # Display results
        Write-Host "`n" -NoNewline
        if ($allSuccess) {
            Write-TestLog "All tests passed! 🎉" "SUCCESS"
        } else {
            Write-TestLog "Some tests failed" "ERROR"
        }
        
        $efficiencyColor = if ($summary.Performance.ParallelEfficiency -gt 200) { 'Green' } 
                          elseif ($summary.Performance.ParallelEfficiency -gt 100) { 'Yellow' } 
                          else { 'Red' }
        
        Write-Host @"

📊 Test Execution Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Mode:           $Mode
Total Tests:    $totalTests
✅ Passed:      $totalPassed
❌ Failed:      $totalFailed
⏭️ Skipped:     $totalSkipped

⏱️ Wall Time:    $($summary.Performance.WallClockTime)s
⚡ Test Time:    $($summary.Performance.TestExecutionTime)s
🚀 Efficiency:   $($summary.Performance.ParallelEfficiency)% (higher is better)
🔧 Workers:      $Workers workers, $($batches.Count) batches

📁 Results:      $summaryFile
"@ -ForegroundColor White

        # Show failed batches if any
        $failedBatches = $batchResults | Where-Object { -not $_.Success }
        if ($failedBatches.Count -gt 0) {
            Write-Host "`n❌ Failed Batches:" -ForegroundColor Red
            $failedBatches | ForEach-Object {
                $errorMsg = if ($_.Error) { $_.Error } else { "Test failures" }
                Write-Host "  Batch $($_.BatchId): $errorMsg" -ForegroundColor Red
            }
        }
        
        # Performance feedback
        if ($summary.Performance.ParallelEfficiency -lt 100 -and -not $Quiet) {
            Write-Host "`n💡 Performance Tip: Low parallel efficiency detected." -ForegroundColor Yellow
            Write-Host "   Consider reducing batch size or worker count for better performance." -ForegroundColor Yellow
        }
        
        Write-TestLog "Summary saved to: $summaryFile"
        
        # Exit with appropriate code
        exit $(if ($allSuccess) { 0 } else { 1 })
    }
    
} catch {
    Write-TestLog "Test execution failed: $_" "ERROR"
    exit 2
}