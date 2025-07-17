#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Real-time CI status monitoring hook for AitherZero
    
.DESCRIPTION
    Provides detailed CI/CD status information including:
    - Workflow run status and progress
    - Job-level details with timings
    - Live log streaming for failures
    - Error analysis and categorization
    - Performance metrics
    - Historical comparison
    
.PARAMETER RunId
    Specific workflow run ID to monitor. If not specified, shows latest runs.
    
.PARAMETER Workflow
    Workflow name to monitor (default: "ci.yml")
    
.PARAMETER Branch
    Branch to monitor. If not specified, uses current branch.
    
.PARAMETER Watch
    Enable live monitoring mode with auto-refresh
    
.PARAMETER ShowLogs
    Show detailed logs for failed jobs
    
.PARAMETER OutputFormat
    Output format: Console (default), JSON, Dashboard
    
.EXAMPLE
    ./hooks/Get-CIStatus.ps1
    
.EXAMPLE
    ./hooks/Get-CIStatus.ps1 -Watch -ShowLogs
    
.EXAMPLE
    ./hooks/Get-CIStatus.ps1 -RunId 16229723979 -ShowLogs
#>

[CmdletBinding()]
param(
    [int]$RunId,
    [string]$Workflow = "ci.yml",
    [string]$Branch,
    [switch]$Watch,
    [switch]$ShowLogs,
    [ValidateSet('Console', 'JSON', 'Dashboard')]
    [string]$OutputFormat = 'Console'
)

# Import required modules
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Find project root
$scriptPath = $PSScriptRoot
$projectRoot = Split-Path $scriptPath -Parent
. "$projectRoot/aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Import modules
Import-Module "$projectRoot/aither-core/modules/Logging" -Force -ErrorAction SilentlyContinue
Import-Module "$projectRoot/aither-core/modules/ProgressTracking" -Force -ErrorAction SilentlyContinue

function Get-CurrentBranch {
    <#
    .SYNOPSIS
        Gets the current Git branch
    #>
    try {
        $branch = git branch --show-current
        return $branch
    }
    catch {
        Write-Warning "Could not detect current branch"
        return $null
    }
}

function Get-WorkflowRuns {
    <#
    .SYNOPSIS
        Gets workflow runs with detailed information
    #>
    param(
        [string]$WorkflowName,
        [string]$BranchName,
        [int]$Limit = 5
    )
    
    $args = @(
        "run", "list",
        "--workflow=$WorkflowName"
    )
    
    if ($BranchName) {
        $args += "--branch=$BranchName"
    }
    
    $args += @(
        "--limit=$Limit",
        "--json=databaseId,status,conclusion,name,displayTitle,event,headBranch,headSha,createdAt,updatedAt,runNumber,runAttempt"
    )
    
    $runs = gh @args | ConvertFrom-Json
    return $runs
}

function Get-RunDetails {
    <#
    .SYNOPSIS
        Gets detailed information about a specific run
    #>
    param([int]$Id)
    
    Write-Information "Fetching run details for #$Id..." -InformationAction Continue
    
    $run = gh run view $Id --json status,conclusion,jobs,createdAt,updatedAt,headBranch,headSha,displayTitle,event,name,runNumber,runAttempt
    return $run | ConvertFrom-Json
}

function Get-JobLogs {
    <#
    .SYNOPSIS
        Gets logs for a specific job
    #>
    param(
        [int]$RunId,
        [int]$JobId,
        [int]$LineCount = 50
    )
    
    try {
        $logs = gh run view $RunId --job $JobId --log 2>$null
        if ($logs) {
            # Extract relevant error lines
            $errorLines = $logs | Select-String -Pattern "(ERROR|FAILED|Failed|error:|::error)" -Context 5,5
            return $errorLines
        }
    }
    catch {
        return "Logs not available yet"
    }
}

function Analyze-JobFailures {
    <#
    .SYNOPSIS
        Analyzes job failures and categorizes them
    #>
    param($Jobs)
    
    $analysis = @{
        Total = $Jobs.Count
        Completed = 0
        InProgress = 0
        Queued = 0
        Failed = 0
        Passed = 0
        Skipped = 0
        FailureCategories = @{
            TestFailure = @()
            QualityCheck = @()
            BuildError = @()
            SecurityScan = @()
            Timeout = @()
            Other = @()
        }
        Performance = @{
            FastestJob = $null
            SlowestJob = $null
            AverageDuration = 0
        }
    }
    
    $durations = @()
    
    foreach ($job in $Jobs) {
        # Status counting
        switch ($job.status) {
            'completed' {
                $analysis.Completed++
                switch ($job.conclusion) {
                    'success' { $analysis.Passed++ }
                    'failure' { 
                        $analysis.Failed++
                        
                        # Categorize failure
                        $failureInfo = @{
                            Name = $job.name
                            Duration = $job.duration
                            StartedAt = $job.startedAt
                            CompletedAt = $job.completedAt
                        }
                        
                        switch -Regex ($job.name) {
                            'Test' { $analysis.FailureCategories.TestFailure += $failureInfo }
                            'Quality|Analyze' { $analysis.FailureCategories.QualityCheck += $failureInfo }
                            'Build' { $analysis.FailureCategories.BuildError += $failureInfo }
                            'Security|Scan' { $analysis.FailureCategories.SecurityScan += $failureInfo }
                            'timeout' { $analysis.FailureCategories.Timeout += $failureInfo }
                            default { $analysis.FailureCategories.Other += $failureInfo }
                        }
                    }
                    'skipped' { $analysis.Skipped++ }
                    'cancelled' { $analysis.Skipped++ }
                }
            }
            'in_progress' { $analysis.InProgress++ }
            'queued' { $analysis.Queued++ }
        }
        
        # Performance metrics
        if ($job.startedAt -and $job.completedAt) {
            $start = [DateTime]::Parse($job.startedAt)
            $end = [DateTime]::Parse($job.completedAt)
            $duration = ($end - $start).TotalSeconds
            $durations += $duration
            
            if (-not $analysis.Performance.FastestJob -or $duration -lt $analysis.Performance.FastestJob.Duration) {
                $analysis.Performance.FastestJob = @{
                    Name = $job.name
                    Duration = $duration
                }
            }
            
            if (-not $analysis.Performance.SlowestJob -or $duration -gt $analysis.Performance.SlowestJob.Duration) {
                $analysis.Performance.SlowestJob = @{
                    Name = $job.name
                    Duration = $duration
                }
            }
        }
    }
    
    if ($durations.Count -gt 0) {
        $analysis.Performance.AverageDuration = ($durations | Measure-Object -Average).Average
    }
    
    return $analysis
}

function Get-TestResults {
    <#
    .SYNOPSIS
        Extracts test results from job logs
    #>
    param(
        [int]$RunId,
        $FailedTestJobs
    )
    
    $testResults = @{
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        SkippedTests = 0
        Platforms = @{}
    }
    
    foreach ($job in $FailedTestJobs) {
        $platform = if ($job.Name -match '\((.*?)\)') { $Matches[1] } else { 'unknown' }
        
        # Try to extract test results from logs
        $logs = gh run view $RunId --job $job.databaseId --log 2>$null
        if ($logs) {
            # Look for Pester test results pattern
            $resultsLine = $logs | Select-String -Pattern "Tests Passed: (\d+).*Failed: (\d+).*Skipped: (\d+)" | Select-Object -Last 1
            if ($resultsLine) {
                if ($resultsLine -match "Tests Passed: (\d+).*Failed: (\d+).*Skipped: (\d+)") {
                    $testResults.Platforms[$platform] = @{
                        Passed = [int]$Matches[1]
                        Failed = [int]$Matches[2]
                        Skipped = [int]$Matches[3]
                    }
                    $testResults.TotalTests += [int]$Matches[1] + [int]$Matches[2] + [int]$Matches[3]
                    $testResults.PassedTests += [int]$Matches[1]
                    $testResults.FailedTests += [int]$Matches[2]
                    $testResults.SkippedTests += [int]$Matches[3]
                }
            }
        }
    }
    
    return $testResults
}

function Format-Duration {
    <#
    .SYNOPSIS
        Formats duration in seconds to human-readable format
    #>
    param([double]$Seconds)
    
    if ($Seconds -lt 60) {
        return "{0:N0}s" -f $Seconds
    }
    elseif ($Seconds -lt 3600) {
        $minutes = [Math]::Floor($Seconds / 60)
        $seconds = $Seconds % 60
        return "{0}m {1:N0}s" -f $minutes, $seconds
    }
    else {
        $hours = [Math]::Floor($Seconds / 3600)
        $minutes = [Math]::Floor(($Seconds % 3600) / 60)
        return "{0}h {1}m" -f $hours, $minutes
    }
}

function Show-ConsoleOutput {
    <#
    .SYNOPSIS
        Displays formatted console output
    #>
    param($Runs, $CurrentRun, $Analysis, $TestResults)
    
    Clear-Host
    
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                       CI/CD Status Monitor                         " -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    # Current/Selected Run
    if ($CurrentRun) {
        Write-Host "`n🎯 CURRENT RUN" -ForegroundColor Yellow
        Write-Host "   Run #$($CurrentRun.runNumber).$($CurrentRun.runAttempt): $($CurrentRun.displayTitle)"
        Write-Host "   Workflow: $($CurrentRun.name)"
        Write-Host "   Branch: $($CurrentRun.headBranch)"
        Write-Host "   Trigger: $($CurrentRun.event)"
        Write-Host "   Status: " -NoNewline
        
        $statusColor = switch ($CurrentRun.status) {
            'completed' {
                switch ($CurrentRun.conclusion) {
                    'success' { 'Green' }
                    'failure' { 'Red' }
                    'cancelled' { 'DarkGray' }
                    default { 'Yellow' }
                }
            }
            'in_progress' { 'Yellow' }
            'queued' { 'DarkYellow' }
            default { 'Gray' }
        }
        
        $statusText = if ($CurrentRun.status -eq 'completed') { 
            "$($CurrentRun.status) ($($CurrentRun.conclusion))" 
        } else { 
            $CurrentRun.status 
        }
        
        Write-Host $statusText -ForegroundColor $statusColor
        
        # Timing
        $startTime = [DateTime]::Parse($CurrentRun.createdAt)
        if ($CurrentRun.updatedAt) {
            $endTime = [DateTime]::Parse($CurrentRun.updatedAt)
            $duration = $endTime - $startTime
            Write-Host "   Duration: $(Format-Duration $duration.TotalSeconds)"
        } else {
            $elapsed = [DateTime]::UtcNow - $startTime
            Write-Host "   Elapsed: $(Format-Duration $elapsed.TotalSeconds) (running)"
        }
    }
    
    # Job Analysis
    if ($Analysis) {
        Write-Host "`n📊 JOB SUMMARY" -ForegroundColor Yellow
        Write-Host "   Total Jobs: $($Analysis.Total)"
        
        $progressBar = ""
        $barWidth = 40
        
        if ($Analysis.Total -gt 0) {
            $passedWidth = [Math]::Floor($barWidth * $Analysis.Passed / $Analysis.Total)
            $failedWidth = [Math]::Floor($barWidth * $Analysis.Failed / $Analysis.Total)
            $runningWidth = [Math]::Floor($barWidth * $Analysis.InProgress / $Analysis.Total)
            $queuedWidth = [Math]::Floor($barWidth * $Analysis.Queued / $Analysis.Total)
            $skippedWidth = $barWidth - $passedWidth - $failedWidth - $runningWidth - $queuedWidth
            
            Write-Host "   Progress: [" -NoNewline
            if ($passedWidth -gt 0) { Write-Host ("█" * $passedWidth) -ForegroundColor Green -NoNewline }
            if ($failedWidth -gt 0) { Write-Host ("█" * $failedWidth) -ForegroundColor Red -NoNewline }
            if ($runningWidth -gt 0) { Write-Host ("█" * $runningWidth) -ForegroundColor Yellow -NoNewline }
            if ($queuedWidth -gt 0) { Write-Host ("█" * $queuedWidth) -ForegroundColor DarkYellow -NoNewline }
            if ($skippedWidth -gt 0) { Write-Host ("█" * $skippedWidth) -ForegroundColor DarkGray -NoNewline }
            Write-Host "]"
        }
        
        Write-Host "   ✅ Passed: $($Analysis.Passed)" -ForegroundColor Green
        Write-Host "   ❌ Failed: $($Analysis.Failed)" -ForegroundColor Red
        Write-Host "   ⏳ Running: $($Analysis.InProgress)" -ForegroundColor Yellow
        Write-Host "   🔄 Queued: $($Analysis.Queued)" -ForegroundColor DarkYellow
        Write-Host "   ⏭️  Skipped: $($Analysis.Skipped)" -ForegroundColor DarkGray
        
        # Failure Categories
        if ($Analysis.Failed -gt 0) {
            Write-Host "`n🔍 FAILURE ANALYSIS" -ForegroundColor Yellow
            foreach ($category in $Analysis.FailureCategories.GetEnumerator()) {
                if ($category.Value.Count -gt 0) {
                    Write-Host "   $($category.Key): $($category.Value.Count)" -ForegroundColor Red
                    foreach ($failure in $category.Value) {
                        Write-Host "     - $($failure.Name)" -ForegroundColor DarkRed
                    }
                }
            }
        }
        
        # Performance Metrics
        if ($Analysis.Performance.AverageDuration -gt 0) {
            Write-Host "`n⚡ PERFORMANCE" -ForegroundColor Yellow
            Write-Host "   Average Duration: $(Format-Duration $Analysis.Performance.AverageDuration)"
            if ($Analysis.Performance.FastestJob) {
                Write-Host "   Fastest: $($Analysis.Performance.FastestJob.Name) ($(Format-Duration $Analysis.Performance.FastestJob.Duration))" -ForegroundColor Green
            }
            if ($Analysis.Performance.SlowestJob) {
                Write-Host "   Slowest: $($Analysis.Performance.SlowestJob.Name) ($(Format-Duration $Analysis.Performance.SlowestJob.Duration))" -ForegroundColor Yellow
            }
        }
    }
    
    # Test Results
    if ($TestResults -and $TestResults.TotalTests -gt 0) {
        Write-Host "`n🧪 TEST RESULTS" -ForegroundColor Yellow
        Write-Host "   Total Tests: $($TestResults.TotalTests)"
        Write-Host "   ✅ Passed: $($TestResults.PassedTests)" -ForegroundColor Green
        Write-Host "   ❌ Failed: $($TestResults.FailedTests)" -ForegroundColor Red
        Write-Host "   ⏭️  Skipped: $($TestResults.SkippedTests)" -ForegroundColor DarkGray
        
        if ($TestResults.Platforms.Count -gt 0) {
            Write-Host "   Platform Breakdown:"
            foreach ($platform in $TestResults.Platforms.GetEnumerator()) {
                Write-Host "     $($platform.Key): " -NoNewline
                Write-Host "P:$($platform.Value.Passed)" -ForegroundColor Green -NoNewline
                Write-Host "/" -NoNewline
                Write-Host "F:$($platform.Value.Failed)" -ForegroundColor Red -NoNewline
                Write-Host "/" -NoNewline
                Write-Host "S:$($platform.Value.Skipped)" -ForegroundColor DarkGray
            }
        }
    }
    
    # Recent Runs Summary
    if ($Runs -and $Runs.Count -gt 1) {
        Write-Host "`n📈 RECENT RUNS" -ForegroundColor Yellow
        $recentRuns = $Runs | Select-Object -First 5
        foreach ($run in $recentRuns) {
            $icon = switch ($run.conclusion) {
                'success' { '✅' }
                'failure' { '❌' }
                'cancelled' { '🚫' }
                default { '⏳' }
            }
            $runTime = [DateTime]::Parse($run.createdAt)
            Write-Host "   $icon Run #$($run.runNumber): $($run.conclusion ?? 'running') - $($runTime.ToString('MM/dd HH:mm'))"
        }
    }
    
    Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    if ($Watch) {
        Write-Host "`nRefreshing every 10 seconds... Press Ctrl+C to exit" -ForegroundColor DarkGray
    }
}

function Show-FailureLogs {
    <#
    .SYNOPSIS
        Shows detailed logs for failed jobs
    #>
    param($RunId, $FailedJobs)
    
    Write-Host "`n📋 FAILURE LOGS" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Red
    
    foreach ($job in $FailedJobs) {
        Write-Host "`n❌ $($job.name)" -ForegroundColor Red
        Write-Host "───────────────────────────────────────────────────────────────────" -ForegroundColor DarkRed
        
        $logs = Get-JobLogs -RunId $RunId -JobId $job.databaseId
        if ($logs -and $logs -ne "Logs not available yet") {
            foreach ($logEntry in $logs) {
                Write-Host $logEntry
            }
        } else {
            Write-Host "   No error logs available" -ForegroundColor DarkGray
        }
    }
}

function Export-JSON {
    <#
    .SYNOPSIS
        Exports CI status as JSON
    #>
    param($Runs, $CurrentRun, $Analysis, $TestResults)
    
    @{
        timestamp = Get-Date -Format 'o'
        currentRun = $CurrentRun
        analysis = $Analysis
        testResults = $TestResults
        recentRuns = $Runs
    } | ConvertTo-Json -Depth 10
}

function Show-Dashboard {
    <#
    .SYNOPSIS
        Shows an enhanced dashboard view
    #>
    param($Runs, $CurrentRun, $Analysis, $TestResults)
    
    # This could be expanded to create an HTML dashboard
    # For now, using enhanced console output
    Show-ConsoleOutput @PSBoundParameters
}

# Main execution
try {
    # Get branch
    if (-not $Branch) {
        $Branch = Get-CurrentBranch
    }
    
    do {
        # Get workflow runs
        $runs = Get-WorkflowRuns -WorkflowName $Workflow -BranchName $Branch
        
        if ($runs.Count -eq 0) {
            Write-Warning "No workflow runs found for $Workflow on branch $Branch"
            exit 0
        }
        
        # Get specific run or latest
        $currentRun = $null
        $runDetails = $null
        
        if ($RunId) {
            $runDetails = Get-RunDetails -Id $RunId
            $currentRun = $runs | Where-Object { $_.databaseId -eq $RunId } | Select-Object -First 1
        } else {
            $currentRun = $runs[0]
            $runDetails = Get-RunDetails -Id $currentRun.databaseId
        }
        
        # Analyze jobs
        $analysis = $null
        $testResults = $null
        
        if ($runDetails -and $runDetails.jobs) {
            $analysis = Analyze-JobFailures -Jobs $runDetails.jobs
            
            # Get test results if there are test failures
            if ($analysis.FailureCategories.TestFailure.Count -gt 0) {
                $failedTestJobs = $runDetails.jobs | Where-Object { 
                    $_.conclusion -eq 'failure' -and $_.name -match 'Test'
                }
                $testResults = Get-TestResults -RunId $currentRun.databaseId -FailedTestJobs $failedTestJobs
            }
        }
        
        # Format output
        switch ($OutputFormat) {
            'Console' {
                Show-ConsoleOutput -Runs $runs -CurrentRun $currentRun -Analysis $analysis -TestResults $testResults
                
                # Show failure logs if requested
                if ($ShowLogs -and $runDetails -and $analysis.Failed -gt 0) {
                    $failedJobs = $runDetails.jobs | Where-Object { $_.conclusion -eq 'failure' }
                    Show-FailureLogs -RunId $currentRun.databaseId -FailedJobs $failedJobs
                }
            }
            'JSON' {
                Export-JSON -Runs $runs -CurrentRun $currentRun -Analysis $analysis -TestResults $testResults
            }
            'Dashboard' {
                Show-Dashboard -Runs $runs -CurrentRun $currentRun -Analysis $analysis -TestResults $testResults
            }
        }
        
        if ($Watch) {
            Start-Sleep -Seconds 10
        }
        
    } while ($Watch)
}
catch {
    Write-Error "Failed to get CI status: $_"
    exit 1
}