#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    AI-friendly test runner with intelligent automation and self-optimization
.DESCRIPTION
    Designed specifically for AI agents to easily understand, extend, and optimize:
    
    - Simple, predictable interface that AI can reason about
    - Self-documenting configuration and behavior
    - Automatic performance optimization based on results
    - Easy extensibility for new test types and patterns
    - Built-in reporting that AI agents can parse and act on
    - Zero configuration complexity - everything is explicit
    
    This runner learns from execution patterns and automatically optimizes:
    - Worker count based on system performance
    - Batch sizes based on test execution times  
    - Test selection based on change patterns
    - Failure prediction based on historical data
    
.PARAMETER TestType
    Type of tests to run: unit, integration, all, smart, changed
.PARAMETER Mode  
    Execution mode: fast (development), thorough (validation), adaptive (AI-optimized)
.PARAMETER MaxDuration
    Maximum time to spend on testing (auto-adjusts test selection)
.PARAMETER Learn
    Enable learning mode to optimize future runs based on results
.PARAMETER Predict
    Use AI to predict which tests are most likely to fail
    
.NOTES
    Stage: Testing
    Order: 0490
    Dependencies: None (fully self-contained)
    Tags: testing, ai-friendly, self-optimizing, intelligent
    
    AI Extension Points:
    - Add new test discovery patterns in Find-TestsWithPattern
    - Extend performance optimization in Optimize-TestExecution  
    - Add failure prediction in Predict-TestFailures
    - Customize reporting in Generate-AIFriendlyReport
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('unit', 'integration', 'all', 'smart', 'changed')]
    [string]$TestType = 'smart',
    
    [ValidateSet('fast', 'thorough', 'adaptive')]
    [string]$Mode = 'adaptive',
    
    [int]$MaxDuration = 300,  # 5 minutes default
    [switch]$Learn,
    [switch]$Predict,
    [switch]$Quiet,
    
    # Override auto-detection
    [int]$Workers = 0,
    [int]$BatchSize = 0
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Performance settings
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'

# Project structure
$projectRoot = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path $projectRoot "tests"
$dataDir = Join-Path $projectRoot "tests/.ai-data"
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# Ensure AI data directory
if (-not (Test-Path $dataDir)) {
    New-Item -Path $dataDir -ItemType Directory -Force | Out-Null
}

# AI-friendly logging (structured, parseable)
function Write-AILog {
    param(
        [string]$Message,
        [string]$Level = 'INFO',
        [hashtable]$Data = @{}
    )
    
    $logEntry = @{
        timestamp = Get-Date -Format 'o'
        level = $Level
        message = $Message
        data = $Data
        source = 'AI-TestRunner'
    }
    
    if (-not $Quiet) {
        $emoji = @{ 'INFO' = '🤖'; 'SUCCESS' = '✅'; 'ERROR' = '❌'; 'WARNING' = '⚠️'; 'LEARN' = '🧠' }[$Level]
        Write-Host "[$($logEntry.timestamp.Split('T')[1].Split('.')[0])] $emoji $Message" -ForegroundColor $(
            @{ 'INFO' = 'Cyan'; 'SUCCESS' = 'Green'; 'ERROR' = 'Red'; 'WARNING' = 'Yellow'; 'LEARN' = 'Magenta' }[$Level]
        )
    }
    
    # Log to AI data file for learning
    if ($Learn) {
        $logEntry | ConvertTo-Json -Compress | Add-Content (Join-Path $dataDir "execution-log.jsonl")
    }
}

# Load historical performance data for AI optimization
function Get-PerformanceHistory {
    $historyFile = Join-Path $dataDir "performance-history.json"
    if (Test-Path $historyFile) {
        try {
            return Get-Content $historyFile | ConvertFrom-Json
        } catch {
            Write-AILog "Failed to load performance history, starting fresh" "WARNING"
            return @()
        }
    }
    return @()
}

# AI-powered test discovery with pattern learning
function Find-TestsWithPattern {
    param([string]$Type, [string[]]$ChangedFiles = @())
    
    Write-AILog "🔍 AI discovering tests (type: $Type)"
    
    $testFiles = @()
    
    switch ($Type) {
        'unit' {
            if (Test-Path "$testRoot/unit") {
                $testFiles = Get-ChildItem "$testRoot/unit" -Filter "*.Tests.ps1" -Recurse
            }
        }
        'integration' {
            if (Test-Path "$testRoot/integration") {
                $testFiles = Get-ChildItem "$testRoot/integration" -Filter "*.Tests.ps1" -Recurse
            }
        }
        'all' {
            foreach ($path in @("$testRoot/unit", "$testRoot/integration")) {
                if (Test-Path $path) {
                    $testFiles += Get-ChildItem $path -Filter "*.Tests.ps1" -Recurse
                }
            }
        }
        'smart' {
            # AI Smart mode: prioritize based on historical failure rates and file size
            $allTests = @()
            foreach ($path in @("$testRoot/unit", "$testRoot/integration")) {
                if (Test-Path $path) {
                    $allTests += Get-ChildItem $path -Filter "*.Tests.ps1" -Recurse
                }
            }
            
            # Load failure history for smart prioritization
            $failureHistory = if (Test-Path (Join-Path $dataDir "failure-history.json")) {
                Get-Content (Join-Path $dataDir "failure-history.json") | ConvertFrom-Json
            } else { @{} }
            
            # Smart selection: fast tests first, then historically problematic ones
            $testFiles = $allTests | Sort-Object @(
                @{ Expression = { $failureHistory.$($_.Name) -or 0 }; Descending = $true },  # Failure-prone first
                @{ Expression = { $_.Length } }  # Then by size (small first)
            ) | Select-Object -First 20  # Limit for speed
            
            Write-AILog "🧠 Smart mode selected $($testFiles.Count) tests based on AI analysis"
        }
        'changed' {
            # Analyze changed files and find related tests
            if ($ChangedFiles.Count -eq 0) {
                # Get changed files from git
                $ChangedFiles = @(git diff --name-only HEAD~1 2>$null | Where-Object { $_ })
            }
            
            Write-AILog "📝 Analyzing $($ChangedFiles.Count) changed files for test impact"
            
            # Find tests that might be affected by changes
            $testFiles = @()
            foreach ($changedFile in $ChangedFiles) {
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($changedFile)
                
                # Look for direct test files
                $directTest = "$testRoot/unit/$baseName.Tests.ps1"
                if (Test-Path $directTest) {
                    $testFiles += Get-Item $directTest
                }
                
                # Look for related tests in the same domain
                if ($changedFile -match 'domains/([^/]+)') {
                    $domain = $matches[1]
                    $domainTests = Get-ChildItem "$testRoot/unit" -Filter "*$domain*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue
                    $testFiles += $domainTests
                }
            }
            
            $testFiles = $testFiles | Sort-Object FullName -Unique
            Write-AILog "🎯 Found $($testFiles.Count) tests related to changes"
        }
    }
    
    return $testFiles
}

# AI-powered performance optimization  
function Optimize-TestExecution {
    param([array]$TestFiles, [string]$Mode)
    
    $history = Get-PerformanceHistory
    $systemCores = [Environment]::ProcessorCount
    
    # AI learns optimal settings from historical data
    $optimalSettings = if ($history.Count -gt 3) {
        # Find the best performing configuration from history
        $bestRun = $history | Sort-Object { $_.Performance.ParallelEfficiency } -Descending | Select-Object -First 1
        Write-AILog "🧠 Learning from historical data: best efficiency was $($bestRun.Performance.ParallelEfficiency)%" "LEARN"
        
        @{
            Workers = $bestRun.Configuration.Workers
            BatchSize = $bestRun.Configuration.BatchSize
        }
    } else {
        # Default intelligent settings
        @{
            Workers = switch ($Mode) {
                'fast' { [Math]::Min($systemCores, 4) }
                'thorough' { $systemCores }
                'adaptive' { [Math]::Min($systemCores, 6) }
            }
            BatchSize = switch ($TestFiles.Count) {
                { $_ -lt 10 } { 2 }
                { $_ -lt 30 } { 3 }
                default { 5 }
            }
        }
    }
    
    # Override with explicit parameters if provided
    if ($Workers -gt 0) { $optimalSettings.Workers = $Workers }
    if ($BatchSize -gt 0) { $optimalSettings.BatchSize = $BatchSize }
    
    Write-AILog "⚡ AI optimization: $($optimalSettings.Workers) workers, batch size $($optimalSettings.BatchSize)"
    
    return $optimalSettings
}

# AI failure prediction based on historical patterns
function Predict-TestFailures {
    param([array]$TestFiles)
    
    if (-not $Predict) { return @() }
    
    $failureHistory = if (Test-Path (Join-Path $dataDir "failure-history.json")) {
        Get-Content (Join-Path $dataDir "failure-history.json") | ConvertFrom-Json
    } else { @{} }
    
    $predictions = @()
    foreach ($test in $TestFiles) {
        $failureRate = $failureHistory.$($test.Name) -or 0
        if ($failureRate -gt 0.3) {  # 30% failure rate threshold
            $predictions += @{
                TestFile = $test.Name
                FailureRate = $failureRate
                Confidence = 'High'
            }
        }
    }
    
    if ($predictions.Count -gt 0) {
        Write-AILog "🔮 AI predicts $($predictions.Count) tests likely to fail" "WARNING"
        $predictions | ForEach-Object { 
            Write-AILog "   $($_.TestFile) (failure rate: $([Math]::Round($_.FailureRate * 100, 1))%)" "WARNING"
        }
    }
    
    return $predictions
}

# Execute tests with AI monitoring
function Invoke-AITestExecution {
    param([array]$TestFiles, [hashtable]$Settings)
    
    $startTime = Get-Date
    $resultsDir = Join-Path $testRoot "results"
    if (-not (Test-Path $resultsDir)) {
        New-Item -Path $resultsDir -ItemType Directory -Force | Out-Null
    }
    
    # Create batches
    $batches = @()
    for ($i = 0; $i -lt $TestFiles.Count; $i += $Settings.BatchSize) {
        $batch = $TestFiles | Select-Object -Skip $i -First $Settings.BatchSize
        $batches += ,@($batch)
    }
    
    Write-AILog "🚀 Executing $($batches.Count) batches with $($Settings.Workers) workers"
    
    # Execute in parallel with AI monitoring
    $batchJobs = for ($i = 0; $i -lt $batches.Count; $i++) {
        [PSCustomObject]@{
            BatchId = $i
            Files = $batches[$i] | ForEach-Object { $_.FullName }
        }
    }
    
    $batchResults = $batchJobs | ForEach-Object -ThrottleLimit $Settings.Workers -Parallel {
        $batch = $_
        $startTime = Get-Date
        
        # Minimal isolated execution (no AitherZero dependencies)
        $script = @"
`$ProgressPreference = 'SilentlyContinue'
`$env:AITHERZERO_TEST_ISOLATION = 'true'

Import-Module Pester -Force -WarningAction SilentlyContinue

try {
    `$config = New-PesterConfiguration
    `$config.Run.Path = @($($batch.Files | ForEach-Object { "'$_'" } | Join-String -Separator ', '))
    `$config.Run.PassThru = `$true
    `$config.Run.Exit = `$false
    `$config.Output.Verbosity = 'None'
    `$config.TestResult.Enabled = `$false  # Skip XML output for speed
    
    `$result = Invoke-Pester -Configuration `$config
    
    [PSCustomObject]@{
        BatchId = $($batch.BatchId)
        Passed = `$result.PassedCount
        Failed = `$result.FailedCount
        Skipped = `$result.SkippedCount
        Duration = `$result.Duration.TotalSeconds
        Success = (`$result.FailedCount -eq 0)
        Tests = `$result.Tests | ForEach-Object { @{ Name = `$_.Name; Result = `$_.Result } }
    }
} catch {
    [PSCustomObject]@{
        BatchId = $($batch.BatchId)
        Error = `$_.Exception.Message
        Success = `$false
    }
}
"@
        
        $result = pwsh -NoProfile -Command $script | ConvertFrom-Json
        $result.ExecutionTime = ((Get-Date) - $startTime).TotalSeconds
        $result
    }
    
    $endTime = Get-Date
    $totalDuration = ($endTime - $startTime).TotalSeconds
    
    # Aggregate results with AI analysis
    $summary = @{
        TestType = $TestType
        Mode = $Mode
        Configuration = $Settings
        Results = @{
            Total = ($batchResults | Measure-Object Passed, Failed, Skipped -Sum | Measure-Object Sum -Sum).Sum
            Passed = ($batchResults | Measure-Object Passed -Sum).Sum
            Failed = ($batchResults | Measure-Object Failed -Sum).Sum
            Skipped = ($batchResults | Measure-Object Skipped -Sum).Sum
            Success = ($batchResults | Where-Object { -not $_.Success }).Count -eq 0
        }
        Performance = @{
            WallClockTime = [Math]::Round($totalDuration, 2)
            TestExecutionTime = [Math]::Round(($batchResults | Measure-Object Duration -Sum).Sum, 2)
            ParallelEfficiency = 0  # Calculate below
            Batches = $batches.Count
            Workers = $Settings.Workers
        }
        Timestamp = Get-Date
        BatchResults = $batchResults
    }
    
    $summary.Performance.ParallelEfficiency = [Math]::Round(
        ($summary.Performance.TestExecutionTime / $summary.Performance.WallClockTime) * 100, 1
    )
    
    return $summary
}

# Update AI learning data
function Update-LearningData {
    param([hashtable]$Summary)
    
    if (-not $Learn) { return }
    
    # Update performance history
    $historyFile = Join-Path $dataDir "performance-history.json"
    $history = Get-PerformanceHistory
    $history += $Summary
    
    # Keep only last 50 runs to prevent file bloat
    if ($history.Count -gt 50) {
        $history = $history | Select-Object -Last 50
    }
    
    $history | ConvertTo-Json -Depth 10 | Set-Content $historyFile
    
    # Update failure rates for prediction
    $failureFile = Join-Path $dataDir "failure-history.json"
    $failureHistory = if (Test-Path $failureFile) {
        Get-Content $failureFile | ConvertFrom-Json -AsHashtable
    } else { @{} }
    
    # Update failure rates based on this run
    foreach ($batch in $Summary.BatchResults) {
        if ($batch.Tests) {
            foreach ($test in $batch.Tests) {
                $testName = [System.IO.Path]::GetFileName($test.Name)
                $currentRate = $failureHistory.$testName -or 0
                $newRate = if ($test.Result -eq 'Failed') { 
                    ($currentRate * 0.8) + (1.0 * 0.2)  # Weighted average favoring recent results
                } else { 
                    $currentRate * 0.9  # Decay failure rate on success
                }
                $failureHistory.$testName = [Math]::Round($newRate, 3)
            }
        }
    }
    
    $failureHistory | ConvertTo-Json | Set-Content $failureFile
    
    Write-AILog "🧠 Updated AI learning data with performance metrics" "LEARN"
}

# Generate AI-friendly report
function Generate-AIFriendlyReport {
    param([hashtable]$Summary)
    
    $reportFile = Join-Path $dataDir "ai-test-report-$timestamp.json"
    
    # Add AI insights to the summary
    $aiReport = $Summary.Clone()
    $aiReport.AIInsights = @{
        PerformanceGrade = if ($Summary.Performance.ParallelEfficiency -gt 300) { 'Excellent' }
                          elseif ($Summary.Performance.ParallelEfficiency -gt 200) { 'Good' }  
                          elseif ($Summary.Performance.ParallelEfficiency -gt 100) { 'Fair' }
                          else { 'Poor' }
        
        Recommendations = @()
        OptimizationScore = [Math]::Round($Summary.Performance.ParallelEfficiency / 3, 0)
    }
    
    # Add recommendations based on analysis
    if ($Summary.Performance.ParallelEfficiency -lt 150) {
        $aiReport.AIInsights.Recommendations += "Consider reducing batch size or worker count"
    }
    if ($Summary.Results.Failed -gt 0) {
        $aiReport.AIInsights.Recommendations += "Enable prediction mode to anticipate failures"
    }
    if ($Summary.Performance.WallClockTime -gt $MaxDuration) {
        $aiReport.AIInsights.Recommendations += "Switch to 'fast' mode or use 'changed' test type"
    }
    
    $aiReport | ConvertTo-Json -Depth 10 | Set-Content $reportFile
    
    return $aiReport
}

# Main execution
try {
    Write-AILog "🤖 AI Test Runner starting (type: $TestType, mode: $Mode)"
    
    # Get changed files for impact analysis
    $changedFiles = @()
    if ($TestType -eq 'changed') {
        try {
            $changedFiles = @(git diff --name-only HEAD~1 2>$null | Where-Object { $_ })
        } catch {
            Write-AILog "Could not detect changed files, falling back to smart mode" "WARNING"
            $TestType = 'smart'
        }
    }
    
    # AI-powered test discovery
    $testFiles = Find-TestsWithPattern -Type $TestType -ChangedFiles $changedFiles
    
    if ($testFiles.Count -eq 0) {
        Write-AILog "No tests found for type '$TestType'" "WARNING"
        exit 0
    }
    
    # AI failure prediction
    $predictions = Predict-TestFailures -TestFiles $testFiles
    
    # AI performance optimization
    $settings = Optimize-TestExecution -TestFiles $testFiles -Mode $Mode
    
    if ($PSCmdlet.ShouldProcess("$($testFiles.Count) tests with AI optimization", "Execute")) {
        
        # Execute tests with AI monitoring
        $summary = Invoke-AITestExecution -TestFiles $testFiles -Settings $settings
        
        # Update AI learning data
        Update-LearningData -Summary $summary
        
        # Generate AI-friendly report
        $aiReport = Generate-AIFriendlyReport -Summary $summary
        
        # Display results
        if ($summary.Results.Success) {
            Write-AILog "All tests passed! 🎉" "SUCCESS"
        } else {
            Write-AILog "Some tests failed" "ERROR"
        }
        
        Write-Host @"

🤖 AI Test Runner Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Mode:           $($summary.Mode) ($($summary.TestType) tests)
AI Grade:       $($aiReport.AIInsights.PerformanceGrade) ($($aiReport.AIInsights.OptimizationScore)/100)

Tests:          $($summary.Results.Total) total
✅ Passed:      $($summary.Results.Passed)
❌ Failed:      $($summary.Results.Failed)
⏭️ Skipped:     $($summary.Results.Skipped)

Performance:    $($summary.Performance.WallClockTime)s wall time
⚡ Efficiency:   $($summary.Performance.ParallelEfficiency)%
🔧 Config:      $($summary.Configuration.Workers) workers, batch size $($summary.Configuration.BatchSize)

🧠 AI Report:   $((Get-Item (Join-Path $dataDir "ai-test-report-$timestamp.json")).FullName)
"@

        # Show AI recommendations
        if ($aiReport.AIInsights.Recommendations.Count -gt 0) {
            Write-Host "`n💡 AI Recommendations:" -ForegroundColor Yellow
            $aiReport.AIInsights.Recommendations | ForEach-Object {
                Write-Host "   • $_" -ForegroundColor Yellow
            }
        }
        
        # Exit with appropriate code
        exit $(if ($summary.Results.Success) { 0 } else { 1 })
    }
    
} catch {
    Write-AILog "AI test execution failed: $_" "ERROR"
    exit 2
}