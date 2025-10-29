# AitherZero Performance Monitoring Module
# Provides comprehensive performance measurement and monitoring capabilities

# Global performance tracking
$script:PerformanceData = @{}
$script:ActiveTimers = @{}
$script:MetricsHistory = @()

#region Core Performance Functions

function Start-PerformanceTimer {
    <#
    .SYNOPSIS
    Starts a performance timer for measuring operation duration.

    .PARAMETER Name
    Unique name for the timer

    .PARAMETER Category
    Category for grouping related metrics (e.g., 'ModuleLoading', 'FileProcessing')

    .PARAMETER Tags
    Optional tags for additional context
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$Category = 'General',

        [Parameter()]
        [string[]]$Tags = @()
    )

    $timer = @{
        Name = $Name
        Category = $Category
        Tags = $Tags
        StartTime = Get-Date
        StartTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()
        ProcessId = $PID
        ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        MemoryStart = [System.GC]::GetTotalMemory($false)
    }

    $script:ActiveTimers[$Name] = $timer

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog "Started performance timer: $Name [$Category]" -Level Debug
    }

    return $timer
}

function Stop-PerformanceTimer {
    <#
    .SYNOPSIS
    Stops a performance timer and records the metrics.

    .PARAMETER Name
    Name of the timer to stop

    .PARAMETER ReturnMetrics
    Whether to return the collected metrics
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [switch]$ReturnMetrics
    )

    if (-not $script:ActiveTimers.ContainsKey($Name)) {
        Write-Warning "Performance timer '$Name' not found or already stopped"
        return $null
    }

    $timer = $script:ActiveTimers[$Name]
    $endTime = Get-Date
    $endTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()
    $memoryEnd = [System.GC]::GetTotalMemory($false)

    $metrics = @{
        Name = $timer.Name
        Category = $timer.Category
        Tags = $timer.Tags
        StartTime = $timer.StartTime
        EndTime = $endTime
        Duration = $endTime - $timer.StartTime
        DurationMs = ($endTicks - $timer.StartTicks) / [System.Diagnostics.Stopwatch]::Frequency * 1000
        MemoryStart = $timer.MemoryStart
        MemoryEnd = $memoryEnd
        MemoryDelta = $memoryEnd - $timer.MemoryStart
        ProcessId = $timer.ProcessId
        ThreadId = $timer.ThreadId
    }

    # Store metrics
    $script:MetricsHistory += $metrics
    $script:ActiveTimers.Remove($Name)

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog "Stopped performance timer: $Name - Duration: $($metrics.DurationMs.ToString('F2'))ms" -Level Debug
    }

    if ($ReturnMetrics) {
        return $metrics
    }
}

function Measure-Performance {
    <#
    .SYNOPSIS
    Measures the performance of a script block.

    .PARAMETER ScriptBlock
    The code to measure

    .PARAMETER Name
    Name for the measurement

    .PARAMETER Category
    Category for grouping

    .PARAMETER Tags
    Optional tags
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$Category = 'General',

        [Parameter()]
        [string[]]$Tags = @()
    )

    Start-PerformanceTimer -Name $Name -Category $Category -Tags $Tags

    try {
        $result = & $ScriptBlock
        $metrics = Stop-PerformanceTimer -Name $Name -ReturnMetrics

        return @{
            Result = $result
            Metrics = $metrics
        }
    }
    catch {
        Stop-PerformanceTimer -Name $Name | Out-Null
        throw
    }
}

#endregion

#region Metrics Collection and Analysis

function Get-PerformanceMetrics {
    <#
    .SYNOPSIS
    Retrieves performance metrics with optional filtering.

    .PARAMETER Category
    Filter by category

    .PARAMETER Name
    Filter by name pattern

    .PARAMETER Since
    Only return metrics since this time

    .PARAMETER Last
    Return only the last N metrics
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Category,

        [Parameter()]
        [string]$Name,

        [Parameter()]
        [datetime]$Since,

        [Parameter()]
        [int]$Last
    )

    $metrics = $script:MetricsHistory

    if ($Category) {
        $metrics = $metrics | Where-Object { $_.Category -eq $Category }
    }

    if ($Name) {
        $metrics = $metrics | Where-Object { $_.Name -like $Name }
    }

    if ($Since) {
        $metrics = $metrics | Where-Object { $_.StartTime -gt $Since }
    }

    if ($Last -gt 0) {
        $metrics = $metrics | Select-Object -Last $Last
    }

    return $metrics
}

function Get-PerformanceSummary {
    <#
    .SYNOPSIS
    Generates a summary of performance metrics.

    .PARAMETER Category
    Category to summarize

    .PARAMETER GroupBy
    Group results by this property
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Category,

        [Parameter()]
        [ValidateSet('Category', 'Name', 'Hour', 'Day')]
        [string]$GroupBy = 'Category'
    )

    $metrics = Get-PerformanceMetrics -Category $Category

    if ($GroupBy -eq 'Hour') {
        $grouped = $metrics | Group-Object { $_.StartTime.ToString('yyyy-MM-dd HH') }
    }
    elseif ($GroupBy -eq 'Day') {
        $grouped = $metrics | Group-Object { $_.StartTime.ToString('yyyy-MM-dd') }
    }
    else {
        $grouped = $metrics | Group-Object $GroupBy
    }

    $summary = $grouped | ForEach-Object {
        $durations = $_.Group | Select-Object -ExpandProperty DurationMs
        $memoryDeltas = $_.Group | Select-Object -ExpandProperty MemoryDelta

        [PSCustomObject]@{
            Group = $_.Name
            Count = $_.Count
            TotalDurationMs = ($durations | Measure-Object -Sum).Sum
            AvgDurationMs = ($durations | Measure-Object -Average).Average
            MinDurationMs = ($durations | Measure-Object -Minimum).Minimum
            MaxDurationMs = ($durations | Measure-Object -Maximum).Maximum
            TotalMemoryDelta = ($memoryDeltas | Measure-Object -Sum).Sum
            AvgMemoryDelta = ($memoryDeltas | Measure-Object -Average).Average
            FirstSeen = ($_.Group | Sort-Object StartTime | Select-Object -First 1).StartTime
            LastSeen = ($_.Group | Sort-Object StartTime | Select-Object -Last 1).StartTime
        }
    }

    return $summary | Sort-Object AvgDurationMs -Descending
}

function Show-PerformanceDashboard {
    <#
    .SYNOPSIS
    Displays a real-time performance dashboard.

    .PARAMETER RefreshSeconds
    How often to refresh the display

    .PARAMETER Top
    Show top N slow operations
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$RefreshSeconds = 5,

        [Parameter()]
        [int]$Top = 10
    )

    if (Get-Command Show-UIProgress -ErrorAction SilentlyContinue) {
        Show-UIProgress -Activity "Performance Dashboard" -Status "Loading..." -PercentComplete 0
    }

    while ($true) {
        Clear-Host

        Write-Host "=" * 80 -ForegroundColor Cyan
        Write-Host " AitherZero Performance Dashboard" -ForegroundColor Yellow
        Write-Host " Last Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
        Write-Host "=" * 80 -ForegroundColor Cyan
        Write-Host

        # Active Timers
        Write-Host "Active Timers:" -ForegroundColor Yellow
        if ($script:ActiveTimers.Count -gt 0) {
            $script:ActiveTimers.Values | ForEach-Object {
                $elapsed = ((Get-Date) - $_.StartTime).TotalSeconds
                Write-Host "  $($_.Name) [$($_.Category)] - Running for $($elapsed.ToString('F1'))s" -ForegroundColor White
            }
        } else {
            Write-Host "  No active timers" -ForegroundColor Gray
        }
        Write-Host

        # Recent Metrics Summary
        Write-Host "Recent Performance (Last Hour):" -ForegroundColor Yellow
        $recent = Get-PerformanceMetrics -Since (Get-Date).AddHours(-1)
        if ($recent.Count -gt 0) {
            $summary = Get-PerformanceSummary -GroupBy Category
            $summary | Select-Object -First $Top | ForEach-Object {
                Write-Host "  $($_.Group): Avg $($_.AvgDurationMs.ToString('F1'))ms ($($_.Count) runs)" -ForegroundColor White
            }
        } else {
            Write-Host "  No recent metrics" -ForegroundColor Gray
        }
        Write-Host

        # Slowest Operations
        Write-Host "Slowest Operations:" -ForegroundColor Yellow
        $slow = $recent | Sort-Object DurationMs -Descending | Select-Object -First $Top
        $slow | ForEach-Object {
            Write-Host "  $($_.Name): $($_.DurationMs.ToString('F1'))ms" -ForegroundColor White
        }

        Write-Host
        Write-Host "Press Ctrl+C to exit, refreshing in $RefreshSeconds seconds..." -ForegroundColor Gray

        Start-Sleep -Seconds $RefreshSeconds
    }
}

#endregion

#region File Processing Metrics

function Measure-FileProcessing {
    <#
    .SYNOPSIS
    Measures file processing performance with detailed metrics.

    .PARAMETER Files
    Array of files to process

    .PARAMETER ProcessingFunction
    Function to apply to each file

    .PARAMETER BatchSize
    Number of files to process in parallel

    .PARAMETER Name
    Name for the measurement
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$Files,

        [Parameter(Mandatory)]
        [scriptblock]$ProcessingFunction,

        [Parameter()]
        [int]$BatchSize = 8,

        [Parameter()]
        [string]$Name = 'FileProcessing'
    )

    Start-PerformanceTimer -Name $Name -Category 'FileProcessing' -Tags @($Files.Count, $BatchSize)

    $results = @()
    $processed = 0

    try {
        for ($i = 0; $i -lt $Files.Count; $i += $BatchSize) {
            $batch = $Files[$i..([Math]::Min($i + $BatchSize - 1, $Files.Count - 1))]

            $batchName = "$Name-Batch$($i/$BatchSize + 1)"
            Start-PerformanceTimer -Name $batchName -Category 'FileProcessing'

            $batchResults = $batch | ForEach-Object {
                & $ProcessingFunction $_
            }

            Stop-PerformanceTimer -Name $batchName

            $results += $batchResults
            $processed += $batch.Count

            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog "Processed $processed/$($Files.Count) files" -Level Information
            }
        }

        $metrics = Stop-PerformanceTimer -Name $Name -ReturnMetrics

        # Add file processing specific metrics
        $metrics.FilesProcessed = $Files.Count
        $metrics.FilesPerSecond = $Files.Count / ($metrics.DurationMs / 1000)
        $metrics.AvgTimePerFile = $metrics.DurationMs / $Files.Count

        return @{
            Results = $results
            Metrics = $metrics
        }
    }
    catch {
        Stop-PerformanceTimer -Name $Name | Out-Null
        throw
    }
}

#endregion

#region Module Integration

function Initialize-PerformanceMonitoring {
    <#
    .SYNOPSIS
    Initializes the performance monitoring system.
    #>
    [CmdletBinding()]
    param()

    # Clear any existing data
    $script:PerformanceData = @{}
    $script:ActiveTimers = @{}
    $script:MetricsHistory = @()

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog "Performance monitoring initialized" -Level Information
    }
}

function Export-PerformanceReport {
    <#
    .SYNOPSIS
    Exports performance metrics to various formats.

    .PARAMETER Path
    Path to save the report

    .PARAMETER Format
    Report format
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Path = "./reports/performance-$(Get-Date -Format 'yyyyMMdd-HHmmss')",

        [Parameter()]
        [ValidateSet('JSON', 'CSV', 'HTML')]
        [string]$Format = 'JSON'
    )

    $metrics = $script:MetricsHistory
    $summary = Get-PerformanceSummary

    $report = @{
        Generated = Get-Date
        TotalMetrics = $metrics.Count
        ActiveTimers = $script:ActiveTimers.Count
        Summary = $summary
        Metrics = $metrics
    }

    switch ($Format) {
        'JSON' {
            $report | ConvertTo-Json -Depth 10 | Out-File "$Path.json"
        }
        'CSV' {
            $metrics | Export-Csv "$Path.csv" -NoTypeInformation
        }
        'HTML' {
            # Basic HTML report
            $html = @"
<!DOCTYPE html>
<html>
<head><title>AitherZero Performance Report</title></head>
<body>
<h1>Performance Report</h1>
<p>Generated: $((Get-Date).ToString())</p>
<h2>Summary</h2>
<table border="1">
<tr><th>Category</th><th>Count</th><th>Avg Duration (ms)</th><th>Total Duration (ms)</th></tr>
"@
            $summary | ForEach-Object {
                $html += "<tr><td>$($_.Group)</td><td>$($_.Count)</td><td>$($_.AvgDurationMs.ToString('F2'))</td><td>$($_.TotalDurationMs.ToString('F2'))</td></tr>"
            }
            $html += "</table></body></html>"

            $html | Out-File "$Path.html"
        }
    }

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog "Performance report exported to $Path.$($Format.ToLower())" -Level Information
    }
}

#endregion

#region Performance Budgets

# Performance budgets (in milliseconds)
$script:PerformanceBudgets = @{
    'TotalInitialization' = 150    # Total initialization should be < 150ms
    'ModuleLoad_Average' = 15      # Average module load time should be < 15ms
    'ModuleLoad_UserInterface' = 25 # UserInterface module should be < 25ms (was 40ms)
    'ModuleLoad_Individual' = 30   # No individual module should take > 30ms
}

function Test-PerformanceBudget {
    <#
    .SYNOPSIS
        Test performance metrics against defined budgets
    .PARAMETER Metrics
        Performance metrics to test
    .PARAMETER Throw
        Throw exception if budget is exceeded
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Metrics,
        [switch]$Throw
    )

    $results = @{
        Passed = @()
        Failed = @()
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
    }

    # Test total initialization time
    if ($Metrics.ContainsKey('TotalInitTimeMs')) {
        $actual = $Metrics.TotalInitTimeMs
        $budget = $script:PerformanceBudgets.TotalInitialization
        $results.TotalTests++

        if ($actual -le $budget) {
            $results.Passed += @{
                Test = 'TotalInitialization'
                Actual = $actual
                Budget = $budget
                Status = 'PASS'
            }
            $results.PassedTests++
        } else {
            $results.Failed += @{
                Test = 'TotalInitialization'
                Actual = $actual
                Budget = $budget
                Status = 'FAIL'
                Difference = $actual - $budget
            }
            $results.FailedTests++
        }
    }

    # Test individual module loading times
    if ($Metrics.ContainsKey('ModuleTimings')) {
        foreach ($module in $Metrics.ModuleTimings.GetEnumerator()) {
            $moduleName = $module.Key
            $timing = $module.Value
            $results.TotalTests++

            # Check specific budget for UserInterface module
            $budget = if ($moduleName -eq 'UserInterface') {
                $script:PerformanceBudgets.ModuleLoad_UserInterface
            } else {
                $script:PerformanceBudgets.ModuleLoad_Individual
            }

            if ($timing -le $budget) {
                $results.Passed += @{
                    Test = "ModuleLoad_$moduleName"
                    Actual = $timing
                    Budget = $budget
                    Status = 'PASS'
                }
                $results.PassedTests++
            } else {
                $results.Failed += @{
                    Test = "ModuleLoad_$moduleName"
                    Actual = $timing
                    Budget = $budget
                    Status = 'FAIL'
                    Difference = $timing - $budget
                }
                $results.FailedTests++
            }
        }
    }

    # Test average module load time
    if ($Metrics.ContainsKey('ModuleTimings') -and $Metrics.ModuleTimings.Count -gt 0) {
        $average = ($Metrics.ModuleTimings.Values | Measure-Object -Average).Average
        $budget = $script:PerformanceBudgets.ModuleLoad_Average
        $results.TotalTests++

        if ($average -le $budget) {
            $results.Passed += @{
                Test = 'ModuleLoad_Average'
                Actual = $average
                Budget = $budget
                Status = 'PASS'
            }
            $results.PassedTests++
        } else {
            $results.Failed += @{
                Test = 'ModuleLoad_Average'
                Actual = $average
                Budget = $budget
                Status = 'FAIL'
                Difference = $average - $budget
            }
            $results.FailedTests++
        }
    }

    # Report results
    Write-Host "`nPerformance Budget Test Results:" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Total Tests: $($results.TotalTests)" -ForegroundColor White
    Write-Host "Passed: $($results.PassedTests)" -ForegroundColor Green
    Write-Host "Failed: $($results.FailedTests)" -ForegroundColor Red

    if ($results.Failed.Count -gt 0) {
        Write-Host "`nFailed Tests:" -ForegroundColor Red
        foreach ($failure in $results.Failed) {
            Write-Host "  ❌ $($failure.Test): $($failure.Actual)ms > $($failure.Budget)ms (+$([math]::Round($failure.Difference, 2))ms)" -ForegroundColor Red
        }
    }

    if ($results.Passed.Count -gt 0) {
        Write-Host "`nPassed Tests:" -ForegroundColor Green
        foreach ($pass in $results.Passed) {
            Write-Host "  ✅ $($pass.Test): $($pass.Actual)ms <= $($pass.Budget)ms" -ForegroundColor Green
        }
    }

    if ($Throw -and $results.FailedTests -gt 0) {
        throw "Performance budget exceeded: $($results.FailedTests) of $($results.TotalTests) tests failed"
    }

    return $results
}

function Set-PerformanceBudget {
    <#
    .SYNOPSIS
        Set or update performance budgets
    .PARAMETER BudgetName
        Name of the budget to set
    .PARAMETER Value
        Budget value in milliseconds
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BudgetName,

        [Parameter(Mandatory)]
        [double]$Value
    )

    $script:PerformanceBudgets[$BudgetName] = $Value
    Write-Host "Performance budget updated: $BudgetName = $Value ms" -ForegroundColor Green
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    'Start-PerformanceTimer',
    'Stop-PerformanceTimer',
    'Measure-Performance',
    'Get-PerformanceMetrics',
    'Get-PerformanceSummary',
    'Show-PerformanceDashboard',
    'Measure-FileProcessing',
    'Initialize-PerformanceMonitoring',
    'Export-PerformanceReport',
    'Test-PerformanceBudget',
    'Set-PerformanceBudget'
)