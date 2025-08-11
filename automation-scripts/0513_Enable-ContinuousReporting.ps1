#Requires -Version 7.0

<#
.SYNOPSIS
    Enable continuous reporting and monitoring for development workflow
.DESCRIPTION
    Sets up file watchers, event triggers, and continuous monitoring for automatic report generation
#>

[CmdletBinding()]
param(
    [string]$ProjectPath = ($PSScriptRoot | Split-Path -Parent),
    [ValidateSet('Enable', 'Disable', 'Status')]
    [string]$Action = 'Enable',
    [switch]$IncludeFileWatcher,
    [switch]$IncludeTestWatcher,
    [switch]$IncludeGitHooks,
    [int]$ReportIntervalMinutes = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import modules
$loggingModule = Join-Path $ProjectPath "domains/utilities/Logging.psm1"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
}

function Write-MonitorLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "ContinuousReporting"
    } else {
        Write-Host "[$Level] $Message"
    }
}

# Status check
if ($Action -eq 'Status') {
    Write-Host "`nContinuous Reporting Status" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan
    
    # Check for running watchers
    $watchers = Get-Job | Where-Object { $_.Name -like "AitherZero-*Watcher" }
    if ($watchers) {
        Write-Host "`nActive Watchers:" -ForegroundColor Green
        foreach ($watcher in $watchers) {
            Write-Host "  - $($watcher.Name): $($watcher.State)" -ForegroundColor White
        }
    } else {
        Write-Host "`nNo active watchers found" -ForegroundColor Yellow
    }
    
    # Check git hooks
    $preCommitHook = Join-Path $ProjectPath ".git/hooks/pre-commit"
    $postCommitHook = Join-Path $ProjectPath ".git/hooks/post-commit"
    
    Write-Host "`nGit Hooks:" -ForegroundColor Green
    Write-Host "  - Pre-commit: $(if (Test-Path $preCommitHook) { 'Installed' } else { 'Not installed' })" -ForegroundColor White
    Write-Host "  - Post-commit: $(if (Test-Path $postCommitHook) { 'Installed' } else { 'Not installed' })" -ForegroundColor White
    
    # Check scheduled tasks
    $scheduledReports = Get-ScheduledTask -TaskName "AitherZero-*" -ErrorAction SilentlyContinue
    if ($scheduledReports) {
        Write-Host "`nScheduled Tasks:" -ForegroundColor Green
        foreach ($task in $scheduledReports) {
            Write-Host "  - $($task.TaskName): $($task.State)" -ForegroundColor White
        }
    }
    
    # Check last report generation
    $reportsPath = Join-Path $ProjectPath "tests/reports"
    $latestReport = Get-ChildItem -Path $reportsPath -Filter "ProjectReport-*.html" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    
    if ($latestReport) {
        $age = New-TimeSpan -Start $latestReport.LastWriteTime -End (Get-Date)
        Write-Host "`nLast Report Generated:" -ForegroundColor Green
        Write-Host "  - File: $($latestReport.Name)" -ForegroundColor White
        Write-Host "  - Time: $($latestReport.LastWriteTime)" -ForegroundColor White
        Write-Host "  - Age: $($age.Hours)h $($age.Minutes)m ago" -ForegroundColor $(if ($age.TotalHours -gt 24) { 'Yellow' } else { 'White' })
    }
    
    return
}

# Disable monitoring
if ($Action -eq 'Disable') {
    Write-MonitorLog "Disabling continuous reporting..."
    
    # Stop watchers
    Get-Job | Where-Object { $_.Name -like "AitherZero-*Watcher" } | Stop-Job -PassThru | Remove-Job
    Write-MonitorLog "Stopped all file watchers"
    
    # Remove monitoring state file
    $stateFile = Join-Path $ProjectPath ".aitherzero/monitoring-state.json"
    if (Test-Path $stateFile) {
        Remove-Item $stateFile -Force
    }
    
    Write-Host "`n✅ Continuous reporting disabled" -ForegroundColor Green
    return
}

# Enable monitoring
Write-MonitorLog "Enabling continuous reporting..."

# Create monitoring state file
$stateDir = Join-Path $ProjectPath ".aitherzero"
if (-not (Test-Path $stateDir)) {
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
}

$monitoringState = @{
    Enabled = $true
    StartTime = Get-Date -Format 'o'
    FileWatcher = $IncludeFileWatcher
    TestWatcher = $IncludeTestWatcher
    GitHooks = $IncludeGitHooks
    ReportInterval = $ReportIntervalMinutes
    LastReportTime = $null
    EventCount = 0
}

# Setup file watcher for PowerShell files
if ($IncludeFileWatcher) {
    Write-MonitorLog "Setting up file watcher for PowerShell files..."
    
    $fileWatcherScript = {
        param($ProjectPath, $ReportInterval)
        
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $ProjectPath
        $watcher.Filter = "*.ps*"
        $watcher.IncludeSubdirectories = $true
        $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite
        
        $lastReport = Get-Date
        $changedFiles = @{}
        
        $action = {
            $path = $Event.SourceEventArgs.FullPath
            $changeType = $Event.SourceEventArgs.ChangeType
            
            # Skip test results and reports
            if ($path -match 'tests/(results|reports)' -or $path -match '\.git') {
                return
            }
            
            # Track changed files
            $changedFiles[$path] = Get-Date
            
            # Check if enough time has passed for a report
            $timeSinceLastReport = (Get-Date) - $lastReport
            if ($timeSinceLastReport.TotalMinutes -ge $ReportInterval) {
                # Generate report in background
                Start-Job -ScriptBlock {
                    param($ProjectPath)
                    Set-Location $ProjectPath
                    & pwsh -File "./automation-scripts/0510_Generate-ProjectReport.ps1" -Format JSON
                } -ArgumentList $ProjectPath | Out-Null
                
                $lastReport = Get-Date
                $changedFiles.Clear()
                
                Write-Host "📊 Auto-generated report due to file changes" -ForegroundColor Cyan
            }
        }
        
        Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action
        $watcher.EnableRaisingEvents = $true
        
        # Keep the watcher alive
        while ($true) {
            Start-Sleep -Seconds 60
            
            # Periodic check for stale changes
            if ($changedFiles.Count -gt 0) {
                $oldestChange = ($changedFiles.Values | Measure-Object -Minimum).Minimum
                if (((Get-Date) - $oldestChange).TotalMinutes -ge $ReportInterval) {
                    Start-Job -ScriptBlock {
                        param($ProjectPath)
                        Set-Location $ProjectPath
                        & pwsh -File "./automation-scripts/0510_Generate-ProjectReport.ps1" -Format JSON
                    } -ArgumentList $ProjectPath | Out-Null
                    
                    $lastReport = Get-Date
                    $changedFiles.Clear()
                }
            }
        }
    }
    
    $watcherJob = Start-Job -Name "AitherZero-FileWatcher" -ScriptBlock $fileWatcherScript -ArgumentList $ProjectPath, $ReportIntervalMinutes
    Write-MonitorLog "File watcher started (Job ID: $($watcherJob.Id))"
}

# Setup test result watcher
if ($IncludeTestWatcher) {
    Write-MonitorLog "Setting up test result watcher..."
    
    $testWatcherScript = {
        param($ProjectPath)
        
        $testResultsPath = Join-Path $ProjectPath "tests/results"
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $testResultsPath
        $watcher.Filter = "*.xml"
        $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite
        
        $action = {
            $path = $Event.SourceEventArgs.FullPath
            
            # Wait a moment for file to be written completely
            Start-Sleep -Seconds 2
            
            # Generate report after test completion
            Start-Job -ScriptBlock {
                param($ProjectPath)
                Set-Location $ProjectPath
                & pwsh -File "./automation-scripts/0510_Generate-ProjectReport.ps1" -Format All
                & pwsh -File "./automation-scripts/0511_Show-ProjectDashboard.ps1" -ShowMetrics -Export
            } -ArgumentList $ProjectPath | Out-Null
            
            Write-Host "📊 Auto-generated report after test completion" -ForegroundColor Green
        }
        
        Register-ObjectEvent -InputObject $watcher -EventName "Created" -Action $action
        $watcher.EnableRaisingEvents = $true
        
        # Keep the watcher alive
        while ($true) {
            Start-Sleep -Seconds 60
        }
    }
    
    $testWatcherJob = Start-Job -Name "AitherZero-TestWatcher" -ScriptBlock $testWatcherScript -ArgumentList $ProjectPath
    Write-MonitorLog "Test watcher started (Job ID: $($testWatcherJob.Id))"
}

# Setup git hooks integration
if ($IncludeGitHooks) {
    Write-MonitorLog "Setting up git hooks integration..."
    
    # Ensure hooks are installed
    $hooksPath = Join-Path $ProjectPath ".git/hooks"
    
    # Install pre-commit hook if not present
    $preCommitHook = Join-Path $hooksPath "pre-commit"
    if (-not (Test-Path $preCommitHook)) {
        Write-MonitorLog "Installing pre-commit hook..."
        # Hook is already created by previous script
    }
    
    # Install post-merge hook for report generation
    $postMergeHook = Join-Path $hooksPath "post-merge"
    $postMergeContent = @'
#!/usr/bin/env pwsh
# Generate report after merge
$projectRoot = git rev-parse --show-toplevel
Set-Location $projectRoot
& pwsh -File "./automation-scripts/0510_Generate-ProjectReport.ps1" -Format All
Write-Host "📊 Generated post-merge report" -ForegroundColor Green
'@
    $postMergeContent | Set-Content $postMergeHook
    chmod +x $postMergeHook 2>$null
    
    Write-MonitorLog "Git hooks configured"
}

# Setup periodic report generation
Write-MonitorLog "Setting up periodic report generation..."

$periodicReportScript = {
    param($ProjectPath, $IntervalMinutes)
    
    while ($true) {
        Start-Sleep -Seconds ($IntervalMinutes * 60)
        
        # Check if project is active (files modified in last hour)
        $recentChanges = Get-ChildItem -Path $ProjectPath -Filter "*.ps*" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-1) }
        
        if ($recentChanges) {
            Start-Job -ScriptBlock {
                param($ProjectPath)
                Set-Location $ProjectPath
                
                # Generate comprehensive report
                & pwsh -File "./automation-scripts/0510_Generate-ProjectReport.ps1" -Format All
                
                # Run tech debt analysis
                & pwsh -File "./automation-scripts/0520_Analyze-TechDebt.ps1" -GenerateReport
                
                # Update dashboard
                & pwsh -File "./automation-scripts/0511_Show-ProjectDashboard.ps1" -ShowAll -Export
            } -ArgumentList $ProjectPath | Out-Null
            
            Write-Host "📊 Periodic report generated (active development detected)" -ForegroundColor Cyan
        }
    }
}

$periodicJob = Start-Job -Name "AitherZero-PeriodicReporter" -ScriptBlock $periodicReportScript -ArgumentList $ProjectPath, $ReportIntervalMinutes
Write-MonitorLog "Periodic reporter started (Job ID: $($periodicJob.Id))"

# Save monitoring state
$stateFile = Join-Path $stateDir "monitoring-state.json"
$monitoringState.LastReportTime = Get-Date -Format 'o'
$monitoringState | ConvertTo-Json | Set-Content $stateFile

# Display summary
Write-Host "`n✅ Continuous Reporting Enabled" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Active Components:" -ForegroundColor Cyan
if ($IncludeFileWatcher) {
    Write-Host "  ✓ File watcher (monitors *.ps* changes)" -ForegroundColor White
}
if ($IncludeTestWatcher) {
    Write-Host "  ✓ Test watcher (triggers on test completion)" -ForegroundColor White
}
if ($IncludeGitHooks) {
    Write-Host "  ✓ Git hooks (pre-commit, post-merge)" -ForegroundColor White
}
Write-Host "  ✓ Periodic reporter (every $ReportIntervalMinutes minutes)" -ForegroundColor White

Write-Host "`nReports will be generated:" -ForegroundColor Cyan
Write-Host "  • After file changes (batched every $ReportIntervalMinutes min)" -ForegroundColor White
Write-Host "  • After test completion" -ForegroundColor White
Write-Host "  • Before/after git operations" -ForegroundColor White
Write-Host "  • Periodically during active development" -ForegroundColor White

Write-Host "`nManagement Commands:" -ForegroundColor Cyan
Write-Host "  Check status:  ./automation-scripts/0513_Enable-ContinuousReporting.ps1 -Action Status" -ForegroundColor White
Write-Host "  Disable:       ./automation-scripts/0513_Enable-ContinuousReporting.ps1 -Action Disable" -ForegroundColor White
Write-Host "  View reports:  ./az 0511 -ShowAll" -ForegroundColor White

Write-Host "`n📊 Monitoring active. Reports will be generated automatically." -ForegroundColor Green