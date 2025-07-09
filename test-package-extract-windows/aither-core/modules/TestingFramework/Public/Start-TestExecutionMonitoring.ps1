#Requires -Version 7.0

<#
.SYNOPSIS
    Monitors test execution and provides real-time feedback with README.md updates

.DESCRIPTION
    This function provides comprehensive monitoring of test execution including:
    - Real-time progress tracking
    - Performance metrics collection
    - Automatic README.md status updates
    - Test result analysis and reporting
    - Integration with existing test runners

.PARAMETER TestSuite
    Test suite to monitor (All, Unit, Integration, Performance, Quick)

.PARAMETER UpdateReadme
    Automatically update README.md files with test results

.PARAMETER GenerateReport
    Generate comprehensive test reports

.PARAMETER WatchMode
    Continue monitoring for file changes and re-run tests

.PARAMETER ModuleFilter
    Filter to specific modules for monitoring

.PARAMETER OutputPath
    Path for test results and reports

.PARAMETER SlackWebhook
    Slack webhook URL for notifications (optional)

.PARAMETER EmailNotification
    Email address for notifications (optional)

.EXAMPLE
    Start-TestExecutionMonitoring -TestSuite "All" -UpdateReadme -GenerateReport

.EXAMPLE
    Start-TestExecutionMonitoring -TestSuite "Unit" -ModuleFilter "ProgressTracking,ModuleCommunication" -WatchMode

.EXAMPLE
    Start-TestExecutionMonitoring -TestSuite "Integration" -SlackWebhook "https://hooks.slack.com/..." -UpdateReadme
#>

function Start-TestExecutionMonitoring {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet("All", "Unit", "Integration", "Performance", "Quick", "Setup")]
        [string]$TestSuite = "Unit",

        [Parameter()]
        [switch]$UpdateReadme,

        [Parameter()]
        [switch]$GenerateReport,

        [Parameter()]
        [switch]$WatchMode,

        [Parameter()]
        [string[]]$ModuleFilter = @(),

        [Parameter()]
        [string]$OutputPath = "./tests/results/monitored",

        [Parameter()]
        [string]$SlackWebhook,

        [Parameter()]
        [string]$EmailNotification
    )

    begin {
        # Find project root
        $projectRoot = $PSScriptRoot
        while ($projectRoot -and -not (Test-Path (Join-Path $projectRoot ".git"))) {
            $projectRoot = Split-Path $projectRoot -Parent
        }

        if (-not $projectRoot) {
            throw "Could not find project root directory"
        }

        Write-TestLog "🔍 Starting test execution monitoring" -Level "INFO"
        Write-TestLog "Test Suite: $TestSuite" -Level "INFO"
        Write-TestLog "Output Path: $OutputPath" -Level "INFO"

        # Initialize monitoring state
        $script:MonitoringState = @{
            StartTime = Get-Date
            TestSuite = $TestSuite
            OutputPath = $OutputPath
            ModuleFilter = $ModuleFilter
            Results = @()
            Metrics = @{
                TotalRuns = 0
                TotalTime = 0
                AverageTime = 0
                SuccessRate = 0
                FailureRate = 0
            }
            Notifications = @{
                Slack = $SlackWebhook
                Email = $EmailNotification
            }
        }

        # Ensure output directory exists
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }

        # Setup file watcher for watch mode
        $fileWatcher = $null
        if ($WatchMode) {
            $fileWatcher = Initialize-FileWatcher -ProjectRoot $projectRoot -ModuleFilter $ModuleFilter
        }

        # Import required modules
        Import-TestingModules -ProjectRoot $projectRoot
    }

    process {
        try {
            do {
                Write-TestLog "🚀 Executing test suite: $TestSuite" -Level "INFO"
                
                # Execute tests with monitoring
                $testExecution = Start-MonitoredTestExecution -TestSuite $TestSuite -ModuleFilter $ModuleFilter -OutputPath $OutputPath
                
                # Update monitoring state
                $script:MonitoringState.Results += $testExecution
                $script:MonitoringState.Metrics.TotalRuns++
                $script:MonitoringState.Metrics.TotalTime += $testExecution.Duration
                $script:MonitoringState.Metrics.AverageTime = $script:MonitoringState.Metrics.TotalTime / $script:MonitoringState.Metrics.TotalRuns
                
                # Calculate success/failure rates
                $totalTests = ($testExecution.Results | Measure-Object -Property TestsRun -Sum).Sum
                $passedTests = ($testExecution.Results | Measure-Object -Property TestsPassed -Sum).Sum
                $failedTests = ($testExecution.Results | Measure-Object -Property TestsFailed -Sum).Sum
                
                if ($totalTests -gt 0) {
                    $script:MonitoringState.Metrics.SuccessRate = [Math]::Round(($passedTests / $totalTests) * 100, 2)
                    $script:MonitoringState.Metrics.FailureRate = [Math]::Round(($failedTests / $totalTests) * 100, 2)
                }
                
                # Update README files if requested
                if ($UpdateReadme) {
                    Write-TestLog "📝 Updating README.md files with test results" -Level "INFO"
                    Update-ReadmeTestStatus -UpdateAll -TestResults $testExecution.Results -ReportPath $testExecution.ReportPath
                }
                
                # Generate reports if requested
                if ($GenerateReport) {
                    Write-TestLog "📊 Generating comprehensive test report" -Level "INFO"
                    $reportPath = New-MonitoringReport -TestExecution $testExecution -MonitoringState $script:MonitoringState -OutputPath $OutputPath
                    $testExecution.ReportPath = $reportPath
                }
                
                # Send notifications
                Send-TestNotifications -TestExecution $testExecution -MonitoringState $script:MonitoringState
                
                # Display real-time metrics
                Display-MonitoringMetrics -TestExecution $testExecution -MonitoringState $script:MonitoringState
                
                # Check for file changes in watch mode
                if ($WatchMode) {
                    if ($fileWatcher) {
                        Write-TestLog "👁️  Watching for file changes... (Press Ctrl+C to stop)" -Level "INFO"
                        $changeDetected = Wait-ForFileChanges -FileWatcher $fileWatcher -TimeoutSeconds 30
                        
                        if ($changeDetected) {
                            Write-TestLog "🔄 File changes detected, re-running tests..." -Level "INFO"
                        } else {
                            Write-TestLog "⏰ No changes detected in 30 seconds, continuing monitoring..." -Level "INFO"
                        }
                    }
                }
                
            } while ($WatchMode)
            
        } catch {
            Write-TestLog "❌ Error in test execution monitoring: $($_.Exception.Message)" -Level "ERROR"
            throw
        } finally {
            # Cleanup file watcher
            if ($fileWatcher) {
                $fileWatcher.Dispose()
            }
        }
    }

    end {
        # Final summary
        $monitoringDuration = (Get-Date) - $script:MonitoringState.StartTime
        Write-TestLog "`n🎯 Test Execution Monitoring Summary:" -Level "SUCCESS"
        Write-TestLog "  Total Duration: $($monitoringDuration.TotalMinutes.ToString('0.00')) minutes" -Level "INFO"
        Write-TestLog "  Total Test Runs: $($script:MonitoringState.Metrics.TotalRuns)" -Level "INFO"
        Write-TestLog "  Average Execution Time: $($script:MonitoringState.Metrics.AverageTime.ToString('0.00')) seconds" -Level "INFO"
        Write-TestLog "  Overall Success Rate: $($script:MonitoringState.Metrics.SuccessRate)%" -Level "INFO"
        Write-TestLog "  Overall Failure Rate: $($script:MonitoringState.Metrics.FailureRate)%" -Level "INFO"
        
        return $script:MonitoringState
    }
}

function Start-MonitoredTestExecution {
    param(
        [string]$TestSuite,
        [string[]]$ModuleFilter,
        [string]$OutputPath
    )
    
    $executionStart = Get-Date
    
    # Execute tests using the unified framework
    $executionParams = @{
        TestSuite = $TestSuite
        TestProfile = "Development"
        OutputPath = $OutputPath
        GenerateReport = $true
        Parallel = $true
    }
    
    if ($ModuleFilter.Count -gt 0) {
        $executionParams.Modules = $ModuleFilter
    }
    
    # Import progress tracking for real-time feedback
    $progressModule = Get-Module -Name "ProgressTracking" -ErrorAction SilentlyContinue
    if ($progressModule) {
        $operationId = Start-ProgressOperation -OperationName "Test Execution Monitoring" -TotalSteps 4
        Update-ProgressOperation -OperationId $operationId -CurrentStep 1 -StepName "Initializing test execution"
    }
    
    try {
        # Execute tests
        if ($operationId) {
            Update-ProgressOperation -OperationId $operationId -CurrentStep 2 -StepName "Running tests"
        }
        
        $results = Invoke-UnifiedTestExecution @executionParams
        
        if ($operationId) {
            Update-ProgressOperation -OperationId $operationId -CurrentStep 3 -StepName "Processing results"
        }
        
        # Process results
        $executionEnd = Get-Date
        $duration = ($executionEnd - $executionStart).TotalSeconds
        
        $testExecution = @{
            StartTime = $executionStart
            EndTime = $executionEnd
            Duration = $duration
            TestSuite = $TestSuite
            Results = $results
            ReportPath = $null
        }
        
        if ($operationId) {
            Update-ProgressOperation -OperationId $operationId -CurrentStep 4 -StepName "Finalizing"
            Complete-ProgressOperation -OperationId $operationId
        }
        
        return $testExecution
        
    } catch {
        if ($operationId) {
            Add-ProgressError -OperationId $operationId -Error "Test execution failed: $($_.Exception.Message)"
            Complete-ProgressOperation -OperationId $operationId
        }
        throw
    }
}

function Initialize-FileWatcher {
    param(
        [string]$ProjectRoot,
        [string[]]$ModuleFilter
    )
    
    try {
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = Join-Path $ProjectRoot "aither-core/modules"
        $watcher.Filter = "*.ps1"
        $watcher.IncludeSubdirectories = $true
        $watcher.EnableRaisingEvents = $true
        
        # Store events for later checking
        $script:FileChangeEvents = @()
        
        $action = {
            $path = $Event.SourceEventArgs.FullPath
            $changeType = $Event.SourceEventArgs.ChangeType
            $script:FileChangeEvents += @{
                Path = $path
                ChangeType = $changeType
                Timestamp = Get-Date
            }
        }
        
        Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action
        Register-ObjectEvent -InputObject $watcher -EventName "Created" -Action $action
        Register-ObjectEvent -InputObject $watcher -EventName "Deleted" -Action $action
        
        return $watcher
        
    } catch {
        Write-TestLog "⚠️  Could not initialize file watcher: $($_.Exception.Message)" -Level "WARN"
        return $null
    }
}

function Wait-ForFileChanges {
    param(
        [System.IO.FileSystemWatcher]$FileWatcher,
        [int]$TimeoutSeconds = 30
    )
    
    if (-not $FileWatcher) {
        return $false
    }
    
    $script:FileChangeEvents = @()
    $startTime = Get-Date
    
    do {
        Start-Sleep -Seconds 1
        $elapsed = (Get-Date) - $startTime
        
        if ($script:FileChangeEvents.Count -gt 0) {
            # Changes detected
            $uniqueFiles = $script:FileChangeEvents | Group-Object -Property Path | Select-Object Name, Count
            Write-TestLog "📁 File changes detected in $($uniqueFiles.Count) files:" -Level "INFO"
            foreach ($file in $uniqueFiles) {
                $relativePath = $file.Name -replace [regex]::Escape($projectRoot), "."
                Write-TestLog "  - $relativePath ($($file.Count) changes)" -Level "INFO"
            }
            return $true
        }
        
    } while ($elapsed.TotalSeconds -lt $TimeoutSeconds)
    
    return $false
}

function Send-TestNotifications {
    param(
        [hashtable]$TestExecution,
        [hashtable]$MonitoringState
    )
    
    $totalTests = ($TestExecution.Results | Measure-Object -Property TestsRun -Sum).Sum
    $passedTests = ($TestExecution.Results | Measure-Object -Property TestsPassed -Sum).Sum
    $failedTests = ($TestExecution.Results | Measure-Object -Property TestsFailed -Sum).Sum
    $successRate = if ($totalTests -gt 0) { [Math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }
    
    $message = @"
🧪 AitherZero Test Execution Report
Test Suite: $($TestExecution.TestSuite)
Duration: $($TestExecution.Duration.ToString('0.00'))s
Results: $passedTests passed, $failedTests failed ($successRate% success rate)
Total Tests: $totalTests
Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    
    # Slack notification
    if ($MonitoringState.Notifications.Slack) {
        try {
            $slackPayload = @{
                text = $message
                username = "AitherZero Test Bot"
                icon_emoji = if ($failedTests -eq 0) { ":white_check_mark:" } else { ":x:" }
            }
            
            $slackJson = $slackPayload | ConvertTo-Json
            Invoke-RestMethod -Uri $MonitoringState.Notifications.Slack -Method Post -Body $slackJson -ContentType "application/json"
            Write-TestLog "📱 Slack notification sent" -Level "INFO"
        } catch {
            Write-TestLog "⚠️  Failed to send Slack notification: $($_.Exception.Message)" -Level "WARN"
        }
    }
    
    # Email notification (basic implementation)
    if ($MonitoringState.Notifications.Email) {
        try {
            # Note: This requires Send-MailMessage to be available and configured
            $emailParams = @{
                To = $MonitoringState.Notifications.Email
                From = "noreply@aitherzero.local"
                Subject = "AitherZero Test Results - $($TestExecution.TestSuite)"
                Body = $message
                SmtpServer = "localhost"  # Configure as needed
            }
            
            Send-MailMessage @emailParams
            Write-TestLog "📧 Email notification sent" -Level "INFO"
        } catch {
            Write-TestLog "⚠️  Failed to send email notification: $($_.Exception.Message)" -Level "WARN"
        }
    }
}

function Display-MonitoringMetrics {
    param(
        [hashtable]$TestExecution,
        [hashtable]$MonitoringState
    )
    
    $totalTests = ($TestExecution.Results | Measure-Object -Property TestsRun -Sum).Sum
    $passedTests = ($TestExecution.Results | Measure-Object -Property TestsPassed -Sum).Sum
    $failedTests = ($TestExecution.Results | Measure-Object -Property TestsFailed -Sum).Sum
    
    Write-Host "`n" -NoNewline
    Write-Host "┌─────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│" -ForegroundColor Cyan -NoNewline
    Write-Host "              Test Execution Monitoring              " -ForegroundColor White -NoNewline
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "├─────────────────────────────────────────────────────────┤" -ForegroundColor Cyan
    Write-Host "│" -ForegroundColor Cyan -NoNewline
    Write-Host " Test Suite: $($TestExecution.TestSuite)".PadRight(53) -ForegroundColor Yellow -NoNewline
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "│" -ForegroundColor Cyan -NoNewline
    Write-Host " Duration: $($TestExecution.Duration.ToString('0.00'))s".PadRight(53) -ForegroundColor White -NoNewline
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "│" -ForegroundColor Cyan -NoNewline
    Write-Host " Total Tests: $totalTests".PadRight(53) -ForegroundColor White -NoNewline
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "│" -ForegroundColor Cyan -NoNewline
    Write-Host " Passed: $passedTests".PadRight(53) -ForegroundColor Green -NoNewline
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "│" -ForegroundColor Cyan -NoNewline
    Write-Host " Failed: $failedTests".PadRight(53) -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Red" }) -NoNewline
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "│" -ForegroundColor Cyan -NoNewline
    Write-Host " Success Rate: $($MonitoringState.Metrics.SuccessRate)%".PadRight(53) -ForegroundColor $(if ($MonitoringState.Metrics.SuccessRate -ge 90) { "Green" } elseif ($MonitoringState.Metrics.SuccessRate -ge 70) { "Yellow" } else { "Red" }) -NoNewline
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "├─────────────────────────────────────────────────────────┤" -ForegroundColor Cyan
    Write-Host "│" -ForegroundColor Cyan -NoNewline
    Write-Host " Total Runs: $($MonitoringState.Metrics.TotalRuns)".PadRight(53) -ForegroundColor White -NoNewline
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "│" -ForegroundColor Cyan -NoNewline
    Write-Host " Average Time: $($MonitoringState.Metrics.AverageTime.ToString('0.00'))s".PadRight(53) -ForegroundColor White -NoNewline
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "└─────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
}

function New-MonitoringReport {
    param(
        [hashtable]$TestExecution,
        [hashtable]$MonitoringState,
        [string]$OutputPath
    )
    
    $reportTimestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $reportPath = Join-Path $OutputPath "monitoring-report-$reportTimestamp.html"
    
    # Generate comprehensive monitoring report
    $reportContent = Generate-MonitoringReportContent -TestExecution $TestExecution -MonitoringState $MonitoringState
    
    Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8
    Write-TestLog "📊 Monitoring report generated: $reportPath" -Level "SUCCESS"
    
    return $reportPath
}

function Generate-MonitoringReportContent {
    param(
        [hashtable]$TestExecution,
        [hashtable]$MonitoringState
    )
    
    $totalTests = ($TestExecution.Results | Measure-Object -Property TestsRun -Sum).Sum
    $passedTests = ($TestExecution.Results | Measure-Object -Property TestsPassed -Sum).Sum
    $failedTests = ($TestExecution.Results | Measure-Object -Property TestsFailed -Sum).Sum
    $successRate = if ($totalTests -gt 0) { [Math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Test Execution Monitoring Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 20px; }
        .metric-card { background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric-value { font-size: 2em; font-weight: bold; color: #2c3e50; }
        .metric-label { font-size: 0.9em; color: #666; margin-top: 5px; }
        .success { color: #27ae60; }
        .warning { color: #f39c12; }
        .error { color: #e74c3c; }
        .results-table { width: 100%; border-collapse: collapse; background-color: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .results-table th, .results-table td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        .results-table th { background-color: #34495e; color: white; }
        .chart-container { background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 AitherZero Test Execution Monitoring Report</h1>
        <p>Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        <p>Test Suite: $($TestExecution.TestSuite) | Duration: $($TestExecution.Duration.ToString('0.00'))s</p>
    </div>
    
    <div class="metrics">
        <div class="metric-card">
            <div class="metric-value success">$passedTests</div>
            <div class="metric-label">Tests Passed</div>
        </div>
        <div class="metric-card">
            <div class="metric-value $(if ($failedTests -eq 0) { 'success' } else { 'error' })">$failedTests</div>
            <div class="metric-label">Tests Failed</div>
        </div>
        <div class="metric-card">
            <div class="metric-value">$totalTests</div>
            <div class="metric-label">Total Tests</div>
        </div>
        <div class="metric-card">
            <div class="metric-value $(if ($successRate -ge 90) { 'success' } elseif ($successRate -ge 70) { 'warning' } else { 'error' })">$successRate%</div>
            <div class="metric-label">Success Rate</div>
        </div>
    </div>
    
    <div class="chart-container">
        <h2>Test Results by Module</h2>
        <table class="results-table">
            <thead>
                <tr>
                    <th>Module</th>
                    <th>Phase</th>
                    <th>Tests Run</th>
                    <th>Passed</th>
                    <th>Failed</th>
                    <th>Success Rate</th>
                    <th>Duration</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
"@
    
    foreach ($result in $TestExecution.Results) {
        $moduleSuccessRate = if ($result.TestsRun -gt 0) { [Math]::Round(($result.TestsPassed / $result.TestsRun) * 100, 2) } else { 0 }
        $status = if ($result.TestsFailed -eq 0 -and $result.TestsRun -gt 0) { "✅ PASS" } elseif ($result.TestsRun -eq 0) { "⚠️ SKIP" } else { "❌ FAIL" }
        
        $html += @"
                <tr>
                    <td>$($result.Module)</td>
                    <td>$($result.Phase)</td>
                    <td>$($result.TestsRun)</td>
                    <td class="success">$($result.TestsPassed)</td>
                    <td class="$(if ($result.TestsFailed -eq 0) { 'success' } else { 'error' })">$($result.TestsFailed)</td>
                    <td class="$(if ($moduleSuccessRate -ge 90) { 'success' } elseif ($moduleSuccessRate -ge 70) { 'warning' } else { 'error' })">$moduleSuccessRate%</td>
                    <td>$([Math]::Round($result.Duration, 2))s</td>
                    <td>$status</td>
                </tr>
"@
    }
    
    $html += @"
            </tbody>
        </table>
    </div>
    
    <div class="chart-container">
        <h2>Monitoring Statistics</h2>
        <p><strong>Total Test Runs:</strong> $($MonitoringState.Metrics.TotalRuns)</p>
        <p><strong>Average Execution Time:</strong> $($MonitoringState.Metrics.AverageTime.ToString('0.00'))s</p>
        <p><strong>Overall Success Rate:</strong> $($MonitoringState.Metrics.SuccessRate)%</p>
        <p><strong>Overall Failure Rate:</strong> $($MonitoringState.Metrics.FailureRate)%</p>
        <p><strong>Monitoring Duration:</strong> $((Get-Date) - $MonitoringState.StartTime | Select-Object -ExpandProperty TotalMinutes | ForEach-Object { $_.ToString('0.00') }) minutes</p>
    </div>
</body>
</html>
"@
    
    return $html
}

function Import-TestingModules {
    param([string]$ProjectRoot)
    
    # Import essential modules for monitoring
    $essentialModules = @("ProgressTracking", "ModuleCommunication", "Logging")
    
    foreach ($moduleName in $essentialModules) {
        $modulePath = Join-Path $ProjectRoot "aither-core/modules/$moduleName"
        if (Test-Path $modulePath) {
            try {
                Import-Module $modulePath -Force -ErrorAction Stop
                Write-TestLog "✅ Imported monitoring module: $moduleName" -Level "INFO"
            } catch {
                Write-TestLog "⚠️  Could not import monitoring module: $moduleName - $_" -Level "WARN"
            }
        }
    }
}

Export-ModuleMember -Function Start-TestExecutionMonitoring