<#
.SYNOPSIS
    Sets performance baselines for AitherZero operations and modules.

.DESCRIPTION
    Set-PerformanceBaseline establishes performance baselines by collecting metrics over
    a specified period and calculating statistical thresholds. These baselines are used
    for performance regression detection and SLA monitoring.

.PARAMETER BaselineType
    The type of baseline to establish. Valid values: 'System', 'Module', 'Operation', 'All'

.PARAMETER Duration
    Duration in seconds to collect baseline data. Default is 60 seconds.

.PARAMETER SampleInterval
    Interval in seconds between samples. Default is 5 seconds.

.PARAMETER SaveToFile
    Save the baseline to a file for persistence across sessions.

.PARAMETER Force
    Overwrite existing baseline without confirmation.

.EXAMPLE
    Set-PerformanceBaseline -BaselineType All -Duration 300
    Establishes comprehensive baselines over 5 minutes.

.EXAMPLE
    Set-PerformanceBaseline -BaselineType Module -SaveToFile
    Creates module performance baselines and saves them to disk.
#>
function Set-PerformanceBaseline {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('System', 'Module', 'Operation', 'All')]
        [string]$BaselineType,

        [Parameter()]
        [ValidateRange(30, 3600)]
        [int]$Duration = 60,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$SampleInterval = 5,

        [Parameter()]
        [switch]$SaveToFile,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Message "Starting baseline collection for: $BaselineType" -Level "INFO"

        # Check for existing baseline
        if ($script:PerformanceBaselines -and $script:PerformanceBaselines[$BaselineType] -and -not $Force) {
            if (-not $PSCmdlet.ShouldProcess("Existing baseline for $BaselineType", "Overwrite")) {
                Write-CustomLog -Message "Baseline collection cancelled" -Level "WARNING"
                return
            }
        }

        # Initialize baseline storage
        if (-not $script:PerformanceBaselines) {
            $script:PerformanceBaselines = @{}
        }

        $baseline = @{
            Type = $BaselineType
            StartTime = Get-Date
            EndTime = $null
            Duration = $Duration
            SampleCount = [Math]::Floor($Duration / $SampleInterval)
            Samples = @()
            Statistics = $null
            Thresholds = $null
        }
    }

    process {
        try {
            Write-CustomLog -Message "Collecting $($baseline.SampleCount) samples over $Duration seconds" -Level "INFO"

            # Progress tracking
            $progress = @{
                Activity = "Collecting Performance Baseline"
                Status = "Sampling $BaselineType metrics"
                PercentComplete = 0
            }

            # Collect samples
            for ($i = 0; $i -lt $baseline.SampleCount; $i++) {
                $progress.PercentComplete = [Math]::Round(($i / $baseline.SampleCount) * 100)
                $progress.CurrentOperation = "Sample $($i + 1) of $($baseline.SampleCount)"
                Write-Progress @progress

                # Collect metrics based on type
                $sample = switch ($BaselineType) {
                    'System' { Get-SystemPerformance -MetricType System -Duration 1 }
                    'Module' { Get-SystemPerformance -MetricType Module -Duration 1 }
                    'Operation' { Get-SystemPerformance -MetricType Operation -Duration 1 }
                    'All' { Get-SystemPerformance -MetricType All -Duration 1 }
                }

                $baseline.Samples += $sample

                # Wait for next sample (unless last)
                if ($i -lt $baseline.SampleCount - 1) {
                    Start-Sleep -Seconds $SampleInterval
                }
            }

            Write-Progress -Activity "Collecting Performance Baseline" -Completed

            # Calculate statistics
            $baseline.EndTime = Get-Date
            $baseline.Statistics = Calculate-BaselineStatistics -Samples $baseline.Samples -Type $BaselineType
            $baseline.Thresholds = Calculate-PerformanceThresholds -Statistics $baseline.Statistics

            # Store baseline
            $script:PerformanceBaselines[$BaselineType] = $baseline

            # Save to file if requested
            if ($SaveToFile) {
                Save-PerformanceBaseline -Baseline $baseline
            }

            # Create summary report
            $summary = @{
                BaselineType = $BaselineType
                Duration = "$Duration seconds"
                SampleCount = $baseline.SampleCount
                CreatedAt = $baseline.StartTime
                Key_Metrics = $baseline.Statistics.Summary
                Thresholds = $baseline.Thresholds
            }

            Write-CustomLog -Message "Performance baseline established successfully" -Level "SUCCESS"
            return $summary

        } catch {
            Write-CustomLog -Message "Error setting performance baseline: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

# Helper function to calculate baseline statistics
function Calculate-BaselineStatistics {
    param($Samples, $Type)

    Write-CustomLog -Message "Calculating statistics for $($Samples.Count) samples" -Level "DEBUG"

    $stats = @{
        Summary = @{}
        Details = @{}
    }

    switch ($Type) {
        'System' {
            # CPU statistics
            $cpuValues = $Samples | ForEach-Object { $_.System.CPU.Average } | Where-Object { $_ }
            if ($cpuValues) {
                $stats.Summary.CPU = @{
                    Mean = [Math]::Round(($cpuValues | Measure-Object -Average).Average, 2)
                    StdDev = Calculate-StandardDeviation -Values $cpuValues
                    P95 = Calculate-Percentile -Values $cpuValues -Percentile 95
                    P99 = Calculate-Percentile -Values $cpuValues -Percentile 99
                }
            }

            # Memory statistics
            $memValues = $Samples | ForEach-Object { $_.System.Memory.Average } | Where-Object { $_ }
            if ($memValues) {
                $stats.Summary.Memory = @{
                    Mean = [Math]::Round(($memValues | Measure-Object -Average).Average, 2)
                    StdDev = Calculate-StandardDeviation -Values $memValues
                    P95 = Calculate-Percentile -Values $memValues -Percentile 95
                    P99 = Calculate-Percentile -Values $memValues -Percentile 99
                }
            }

            # Network statistics
            $netValues = $Samples | ForEach-Object { $_.System.Network.ThroughputMbps } | Where-Object { $_ }
            if ($netValues) {
                $stats.Summary.Network = @{
                    Mean = [Math]::Round(($netValues | Measure-Object -Average).Average, 2)
                    StdDev = Calculate-StandardDeviation -Values $netValues
                    Min = ($netValues | Measure-Object -Minimum).Minimum
                    Max = ($netValues | Measure-Object -Maximum).Maximum
                }
            }
        }

        'Module' {
            # Module load time statistics
            $moduleData = @{}
            foreach ($sample in $Samples) {
                if ($sample.Modules) {
                    foreach ($moduleName in $sample.Modules.Keys) {
                        if (-not $moduleData[$moduleName]) {
                            $moduleData[$moduleName] = @()
                        }
                        if ($sample.Modules[$moduleName].LoadTime) {
                            $moduleData[$moduleName] += $sample.Modules[$moduleName].LoadTime
                        }
                    }
                }
            }

            foreach ($moduleName in $moduleData.Keys) {
                if ($moduleData[$moduleName].Count -gt 0) {
                    $stats.Details[$moduleName] = @{
                        Mean = [Math]::Round(($moduleData[$moduleName] | Measure-Object -Average).Average, 3)
                        Max = ($moduleData[$moduleName] | Measure-Object -Maximum).Maximum
                        SampleCount = $moduleData[$moduleName].Count
                    }
                }
            }

            # Overall module statistics
            $allLoadTimes = $moduleData.Values | ForEach-Object { $_ } | Where-Object { $_ }
            if ($allLoadTimes) {
                $stats.Summary.ModuleLoading = @{
                    MeanTime = [Math]::Round(($allLoadTimes | Measure-Object -Average).Average, 3)
                    MaxTime = ($allLoadTimes | Measure-Object -Maximum).Maximum
                    TotalModules = $moduleData.Keys.Count
                }
            }
        }

        'Operation' {
            # Operation performance statistics
            $operationTypes = @('PatchWorkflows', 'InfrastructureDeployments', 'TestExecutions')

            foreach ($opType in $operationTypes) {
                $opTimes = @()
                foreach ($sample in $Samples) {
                    if ($sample.Operations -and $sample.Operations[$opType] -and $sample.Operations[$opType].AverageTime) {
                        $opTimes += $sample.Operations[$opType].AverageTime
                    }
                }

                if ($opTimes.Count -gt 0) {
                    $stats.Summary[$opType] = @{
                        Mean = [Math]::Round(($opTimes | Measure-Object -Average).Average, 2)
                        Max = ($opTimes | Measure-Object -Maximum).Maximum
                        SampleCount = $opTimes.Count
                    }
                }
            }
        }

        'All' {
            # Recursive call for each type
            foreach ($subType in @('System', 'Module', 'Operation')) {
                $subStats = Calculate-BaselineStatistics -Samples $Samples -Type $subType
                $stats.Details[$subType] = $subStats
            }

            # Overall application statistics
            if ($Samples[0].Application) {
                $appMemory = $Samples | ForEach-Object { $_.Application.ProcessInfo.WorkingSetMB } | Where-Object { $_ }
                if ($appMemory) {
                    $stats.Summary.ApplicationMemory = @{
                        Mean = [Math]::Round(($appMemory | Measure-Object -Average).Average, 2)
                        Max = ($appMemory | Measure-Object -Maximum).Maximum
                        Growth = [Math]::Round($appMemory[-1] - $appMemory[0], 2)
                    }
                }
            }
        }
    }

    return $stats
}

# Helper function to calculate standard deviation
function Calculate-StandardDeviation {
    param([array]$Values)

    if ($Values.Count -lt 2) { return 0 }

    $mean = ($Values | Measure-Object -Average).Average
    $squaredDiffs = $Values | ForEach-Object { [Math]::Pow($_ - $mean, 2) }
    $variance = ($squaredDiffs | Measure-Object -Sum).Sum / ($Values.Count - 1)

    return [Math]::Round([Math]::Sqrt($variance), 2)
}

# Helper function to calculate percentile
function Calculate-Percentile {
    param(
        [array]$Values,
        [int]$Percentile
    )

    $sorted = $Values | Sort-Object
    $index = [Math]::Ceiling($Percentile / 100 * $sorted.Count) - 1
    $index = [Math]::Max(0, [Math]::Min($index, $sorted.Count - 1))

    return $sorted[$index]
}

# Helper function to calculate performance thresholds
function Calculate-PerformanceThresholds {
    param($Statistics)

    Write-CustomLog -Message "Calculating performance thresholds from statistics" -Level "DEBUG"

    $thresholds = @{}

    # CPU thresholds (based on mean + standard deviations)
    if ($Statistics.Summary.CPU) {
        $cpuMean = $Statistics.Summary.CPU.Mean
        $cpuStdDev = $Statistics.Summary.CPU.StdDev

        $thresholds.CPU = @{
            Normal = [Math]::Round($cpuMean + $cpuStdDev, 2)
            Warning = [Math]::Round($cpuMean + (2 * $cpuStdDev), 2)
            Critical = [Math]::Min(95, [Math]::Round($cpuMean + (3 * $cpuStdDev), 2))
        }
    }

    # Memory thresholds
    if ($Statistics.Summary.Memory) {
        $memMean = $Statistics.Summary.Memory.Mean
        $memStdDev = $Statistics.Summary.Memory.StdDev

        $thresholds.Memory = @{
            Normal = [Math]::Round($memMean + $memStdDev, 2)
            Warning = [Math]::Round($memMean + (2 * $memStdDev), 2)
            Critical = [Math]::Min(95, [Math]::Round($memMean + (3 * $memStdDev), 2))
        }
    }

    # Module loading thresholds (SLA: < 2 seconds)
    if ($Statistics.Summary.ModuleLoading) {
        $moduleMax = $Statistics.Summary.ModuleLoading.MaxTime

        $thresholds.ModuleLoading = @{
            Normal = [Math]::Min(1.5, $moduleMax * 1.1)
            Warning = [Math]::Min(1.8, $moduleMax * 1.25)
            Critical = 2.0  # SLA limit
        }
    }

    # Operation thresholds
    foreach ($opType in @('PatchWorkflows', 'InfrastructureDeployments', 'TestExecutions')) {
        if ($Statistics.Summary[$opType]) {
            $opMean = $Statistics.Summary[$opType].Mean
            $opMax = $Statistics.Summary[$opType].Max

            # Define SLA-based thresholds
            $slaLimits = @{
                PatchWorkflows = 10  # 10 seconds
                InfrastructureDeployments = 120  # 2 minutes
                TestExecutions = 300  # 5 minutes
            }

            $thresholds[$opType] = @{
                Normal = [Math]::Min($opMean * 1.2, $slaLimits[$opType] * 0.7)
                Warning = [Math]::Min($opMax * 1.1, $slaLimits[$opType] * 0.9)
                Critical = $slaLimits[$opType]
            }
        }
    }

    return $thresholds
}

# Helper function to save baseline to file
function Save-PerformanceBaseline {
    param($Baseline)

    try {
        $baselinePath = Join-Path $script:ProjectRoot "configs/performance"
        if (-not (Test-Path $baselinePath)) {
            New-Item -Path $baselinePath -ItemType Directory -Force | Out-Null
        }

        $filename = "baseline-$($Baseline.Type.ToLower())-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $filepath = Join-Path $baselinePath $filename

        # Create exportable baseline object
        $export = @{
            Type = $Baseline.Type
            Created = $Baseline.StartTime
            Duration = $Baseline.Duration
            SampleCount = $Baseline.SampleCount
            Statistics = $Baseline.Statistics
            Thresholds = $Baseline.Thresholds
            SystemInfo = @{
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                Platform = $PSVersionTable.Platform
                OS = $PSVersionTable.OS
            }
        }

        $export | ConvertTo-Json -Depth 10 | Out-File -FilePath $filepath -Encoding UTF8

        Write-CustomLog -Message "Performance baseline saved to: $filepath" -Level "SUCCESS"

        # Also update the current baseline file
        $currentFile = Join-Path $baselinePath "current-baseline-$($Baseline.Type.ToLower()).json"
        Copy-Item -Path $filepath -Destination $currentFile -Force

    } catch {
        Write-CustomLog -Message "Error saving baseline: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# Export public function
Export-ModuleMember -Function Set-PerformanceBaseline
