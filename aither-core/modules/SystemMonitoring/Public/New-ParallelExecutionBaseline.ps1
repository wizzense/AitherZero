<#
.SYNOPSIS
    Create and manage performance baselines for parallel execution optimization

.DESCRIPTION
    Establishes performance baselines for parallel vs sequential execution across different
    workload types, system configurations, and environmental conditions. Enables intelligent
    decision-making for when to use parallel execution and optimal thread counts.

.PARAMETER WorkloadType
    Type of workload to baseline: Test, Build, Deploy, Analysis

.PARAMETER BaselineIterations
    Number of iterations to run for baseline establishment (default: 5)

.PARAMETER IncludeSequential
    Include sequential execution baseline for comparison

.PARAMETER MaxParallelThreads
    Maximum parallel threads to test (default: CPU count * 2)

.PARAMETER OutputPath
    Path to save baseline data (default: ./baselines)

.PARAMETER ExportFormat
    Export format: JSON, CSV, XML

.EXAMPLE
    New-ParallelExecutionBaseline -WorkloadType Test -IncludeSequential

.EXAMPLE
    New-ParallelExecutionBaseline -WorkloadType Build -BaselineIterations 10 -MaxParallelThreads 8

.NOTES
    Creates comprehensive performance baselines for intelligent parallel execution decisions
#>
function New-ParallelExecutionBaseline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Test', 'Build', 'Deploy', 'Analysis', 'General')]
        [string]$WorkloadType,
        
        [Parameter()]
        [ValidateRange(3, 20)]
        [int]$BaselineIterations = 5,
        
        [Parameter()]
        [switch]$IncludeSequential,
        
        [Parameter()]
        [ValidateRange(1, 32)]
        [int]$MaxParallelThreads = ([Environment]::ProcessorCount * 2),
        
        [Parameter()]
        [string]$OutputPath = './baselines',
        
        [Parameter()]
        [ValidateSet('JSON', 'CSV', 'XML')]
        [string]$ExportFormat = 'JSON',
        
        [Parameter()]
        [switch]$SkipBaseline
    )
    
    Write-CustomLog -Message "Creating parallel execution baseline for workload type: $WorkloadType" -Level "INFO"
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # Get system configuration for baseline context
    $systemConfig = Get-IntelligentResourceMetrics -DetailedAnalysis
    
    $baseline = [PSCustomObject]@{
        WorkloadType = $WorkloadType
        CreationTime = Get-Date
        SystemConfiguration = $systemConfig
        BaselineIterations = $BaselineIterations
        ExecutionResults = @{
            Sequential = $null
            Parallel = @()
        }
        OptimalConfiguration = $null
        PerformanceAnalysis = $null
        Recommendations = $null
        BaselineVersion = "1.0"
    }
    
    Write-CustomLog -Message "System configuration: $($systemConfig.Platform.ProcessorCount) cores, $($systemConfig.Hardware.Memory.TotalPhysicalGB)GB RAM" -Level "INFO"
    
    if (-not $SkipBaseline) {
        # Run sequential baseline if requested
        if ($IncludeSequential) {
            Write-CustomLog -Message "Running sequential execution baseline..." -Level "INFO"
            $baseline.ExecutionResults.Sequential = Test-SequentialExecution -WorkloadType $WorkloadType -Iterations $BaselineIterations
        }
        
        # Run parallel execution tests for different thread counts
        Write-CustomLog -Message "Running parallel execution baselines (1 to $MaxParallelThreads threads)..." -Level "INFO"
        
        $threadCounts = @(1, 2)
        if ($MaxParallelThreads -ge 4) { $threadCounts += @(4) }
        if ($MaxParallelThreads -ge 6) { $threadCounts += @(6) }
        if ($MaxParallelThreads -ge 8) { $threadCounts += @(8) }
        if ($MaxParallelThreads -gt 8) { $threadCounts += @($MaxParallelThreads) }
        
        foreach ($threadCount in $threadCounts) {
            Write-CustomLog -Message "Testing with $threadCount parallel threads..." -Level "INFO"
            
            $parallelResult = Test-ParallelExecution -WorkloadType $WorkloadType -ThreadCount $threadCount -Iterations $BaselineIterations
            $baseline.ExecutionResults.Parallel += $parallelResult
            
            # Show progress
            $progress = [math]::Round(($threadCounts.IndexOf($threadCount) + 1) / $threadCounts.Count * 100, 1)
            Write-Host "  Progress: $progress% - $threadCount threads completed" -ForegroundColor Cyan
        }
        
        # Analyze results and determine optimal configuration
        $baseline.PerformanceAnalysis = Get-BaselinePerformanceAnalysis -ExecutionResults $baseline.ExecutionResults
        $baseline.OptimalConfiguration = Get-OptimalParallelConfiguration -PerformanceAnalysis $baseline.PerformanceAnalysis -SystemConfig $systemConfig
        $baseline.Recommendations = Get-BaselineRecommendations -Baseline $baseline
    }
    
    # Export baseline data
    $baselineFileName = "baseline-$WorkloadType-$(Get-Date -Format 'yyyyMMdd-HHmmss').$($ExportFormat.ToLower())"
    $baselineFilePath = Join-Path $OutputPath $baselineFileName
    
    switch ($ExportFormat) {
        'JSON' {
            $baseline | ConvertTo-Json -Depth 10 | Out-File $baselineFilePath -Encoding UTF8
        }
        'CSV' {
            # Flatten data for CSV export
            $csvData = Export-BaselineToCSV -Baseline $baseline
            $csvData | Export-Csv $baselineFilePath -NoTypeInformation
        }
        'XML' {
            $baseline | Export-Clixml -Path $baselineFilePath
        }
    }
    
    Write-CustomLog -Message "Baseline saved to: $baselineFilePath" -Level "SUCCESS"
    
    # Display summary
    if ($baseline.OptimalConfiguration) {
        Write-Host ""
        Write-Host "📊 Baseline Summary for $WorkloadType workload:" -ForegroundColor Green
        Write-Host "  Optimal Threads: $($baseline.OptimalConfiguration.OptimalThreads)" -ForegroundColor Cyan
        Write-Host "  Performance Improvement: $($baseline.OptimalConfiguration.PerformanceImprovement)%" -ForegroundColor Cyan
        Write-Host "  Efficiency Rating: $($baseline.OptimalConfiguration.EfficiencyRating)/100" -ForegroundColor Cyan
        Write-Host "  Recommendation: $($baseline.OptimalConfiguration.Recommendation)" -ForegroundColor Yellow
        Write-Host ""
    }
    
    return $baseline
}

function Test-SequentialExecution {
    <#
    .SYNOPSIS
    Run sequential execution baseline test
    #>
    param(
        [string]$WorkloadType,
        [int]$Iterations
    )
    
    $results = @()
    
    for ($i = 1; $i -le $Iterations; $i++) {
        Write-Host "  Sequential run $i/$Iterations..." -ForegroundColor Gray
        
        $metrics = Measure-Command {
            switch ($WorkloadType) {
                'Test' { 
                    # Simulate test workload
                    Invoke-TestWorkloadSimulation -Sequential
                }
                'Build' { 
                    # Simulate build workload
                    Invoke-BuildWorkloadSimulation -Sequential
                }
                'Deploy' { 
                    # Simulate deployment workload
                    Invoke-DeployWorkloadSimulation -Sequential
                }
                'Analysis' { 
                    # Simulate analysis workload
                    Invoke-AnalysisWorkloadSimulation -Sequential
                }
                'General' {
                    # General workload simulation
                    Invoke-GeneralWorkloadSimulation -Sequential
                }
            }
        }
        
        $results += @{
            Iteration = $i
            Duration = $metrics
            DurationSeconds = $metrics.TotalSeconds
            SystemLoad = Get-SystemLoadDuringExecution
            MemoryUsage = Get-MemoryUsageDuringExecution
        }
    }
    
    return @{
        ThreadCount = 1
        Iterations = $results
        AverageDuration = ($results | Measure-Object -Property DurationSeconds -Average).Average
        MinDuration = ($results | Measure-Object -Property DurationSeconds -Minimum).Minimum
        MaxDuration = ($results | Measure-Object -Property DurationSeconds -Maximum).Maximum
        StandardDeviation = Get-StandardDeviation -Values ($results | ForEach-Object { $_.DurationSeconds })
        ConsistencyRating = Get-ConsistencyRating -Values ($results | ForEach-Object { $_.DurationSeconds })
    }
}

function Test-ParallelExecution {
    <#
    .SYNOPSIS
    Run parallel execution baseline test
    #>
    param(
        [string]$WorkloadType,
        [int]$ThreadCount,
        [int]$Iterations
    )
    
    $results = @()
    
    for ($i = 1; $i -le $Iterations; $i++) {
        Write-Host "  Parallel run $i/$Iterations ($ThreadCount threads)..." -ForegroundColor Gray
        
        $metrics = Measure-Command {
            switch ($WorkloadType) {
                'Test' { 
                    Invoke-TestWorkloadSimulation -Parallel -ThreadCount $ThreadCount
                }
                'Build' { 
                    Invoke-BuildWorkloadSimulation -Parallel -ThreadCount $ThreadCount
                }
                'Deploy' { 
                    Invoke-DeployWorkloadSimulation -Parallel -ThreadCount $ThreadCount
                }
                'Analysis' { 
                    Invoke-AnalysisWorkloadSimulation -Parallel -ThreadCount $ThreadCount
                }
                'General' {
                    Invoke-GeneralWorkloadSimulation -Parallel -ThreadCount $ThreadCount
                }
            }
        }
        
        $results += @{
            Iteration = $i
            Duration = $metrics
            DurationSeconds = $metrics.TotalSeconds
            SystemLoad = Get-SystemLoadDuringExecution
            MemoryUsage = Get-MemoryUsageDuringExecution
            OverheadDetected = Test-ParallelOverhead -ThreadCount $ThreadCount
        }
    }
    
    return @{
        ThreadCount = $ThreadCount
        Iterations = $results
        AverageDuration = ($results | Measure-Object -Property DurationSeconds -Average).Average
        MinDuration = ($results | Measure-Object -Property DurationSeconds -Minimum).Minimum
        MaxDuration = ($results | Measure-Object -Property DurationSeconds -Maximum).Maximum
        StandardDeviation = Get-StandardDeviation -Values ($results | ForEach-Object { $_.DurationSeconds })
        ConsistencyRating = Get-ConsistencyRating -Values ($results | ForEach-Object { $_.DurationSeconds })
        ParallelEfficiency = Get-ParallelEfficiency -ThreadCount $ThreadCount -Results $results
    }
}

function Get-BaselinePerformanceAnalysis {
    <#
    .SYNOPSIS
    Analyze baseline performance results
    #>
    param($ExecutionResults)
    
    $analysis = @{
        SequentialBaseline = $null
        ParallelPerformance = @()
        OptimalThreadCount = 1
        MaxPerformanceImprovement = 0
        DiminishingReturnsThreshold = 2
        ParallelOverheadDetected = $false
    }
    
    if ($ExecutionResults.Sequential) {
        $analysis.SequentialBaseline = $ExecutionResults.Sequential.AverageDuration
    }
    
    # Analyze each parallel configuration
    foreach ($parallelResult in $ExecutionResults.Parallel) {
        $improvement = 0
        $efficiency = 0
        
        if ($analysis.SequentialBaseline -and $analysis.SequentialBaseline -gt 0) {
            $improvement = [math]::Round((($analysis.SequentialBaseline - $parallelResult.AverageDuration) / $analysis.SequentialBaseline) * 100, 2)
            $efficiency = [math]::Round($improvement / $parallelResult.ThreadCount, 2)
        }
        
        $performanceData = @{
            ThreadCount = $parallelResult.ThreadCount
            AverageDuration = $parallelResult.AverageDuration
            PerformanceImprovement = $improvement
            EfficiencyPerThread = $efficiency
            ConsistencyRating = $parallelResult.ConsistencyRating
            ParallelEfficiency = $parallelResult.ParallelEfficiency
        }
        
        $analysis.ParallelPerformance += $performanceData
        
        # Track best performance
        if ($improvement -gt $analysis.MaxPerformanceImprovement) {
            $analysis.MaxPerformanceImprovement = $improvement
            $analysis.OptimalThreadCount = $parallelResult.ThreadCount
        }
    }
    
    # Detect diminishing returns
    if ($analysis.ParallelPerformance.Count -gt 1) {
        $analysis.DiminishingReturnsThreshold = Get-DiminishingReturnsThreshold -PerformanceData $analysis.ParallelPerformance
    }
    
    # Detect parallel overhead
    $singleThreadParallel = $analysis.ParallelPerformance | Where-Object { $_.ThreadCount -eq 1 }
    if ($singleThreadParallel -and $analysis.SequentialBaseline) {
        $overheadPercentage = (($singleThreadParallel.AverageDuration - $analysis.SequentialBaseline) / $analysis.SequentialBaseline) * 100
        if ($overheadPercentage -gt 5) {
            $analysis.ParallelOverheadDetected = $true
        }
    }
    
    return $analysis
}

function Get-OptimalParallelConfiguration {
    <#
    .SYNOPSIS
    Determine optimal parallel configuration based on analysis
    #>
    param($PerformanceAnalysis, $SystemConfig)
    
    $optimal = @{
        OptimalThreads = $PerformanceAnalysis.OptimalThreadCount
        PerformanceImprovement = $PerformanceAnalysis.MaxPerformanceImprovement
        EfficiencyRating = 0
        Recommendation = ""
        ReasoningFactors = @()
        ConfigurationData = @{}
    }
    
    # Calculate efficiency rating
    $optimalPerformance = $PerformanceAnalysis.ParallelPerformance | Where-Object { $_.ThreadCount -eq $optimal.OptimalThreads }
    if ($optimalPerformance) {
        $optimal.EfficiencyRating = [math]::Round($optimalPerformance.EfficiencyPerThread * 10, 0)
        $optimal.ConfigurationData = $optimalPerformance
    }
    
    # Generate recommendation
    if ($optimal.PerformanceImprovement -gt 30) {
        $optimal.Recommendation = "Highly recommend parallel execution"
        $optimal.ReasoningFactors += "Significant performance improvement ($($optimal.PerformanceImprovement)%)"
    }
    elseif ($optimal.PerformanceImprovement -gt 15) {
        $optimal.Recommendation = "Recommend parallel execution"
        $optimal.ReasoningFactors += "Moderate performance improvement ($($optimal.PerformanceImprovement)%)"
    }
    elseif ($optimal.PerformanceImprovement -gt 5) {
        $optimal.Recommendation = "Consider parallel execution for larger workloads"
        $optimal.ReasoningFactors += "Small performance improvement ($($optimal.PerformanceImprovement)%)"
    }
    else {
        $optimal.Recommendation = "Parallel execution not recommended"
        $optimal.ReasoningFactors += "Minimal or no performance improvement"
    }
    
    # Add reasoning factors
    if ($PerformanceAnalysis.ParallelOverheadDetected) {
        $optimal.ReasoningFactors += "Parallel overhead detected"
    }
    
    if ($optimal.OptimalThreads -le $PerformanceAnalysis.DiminishingReturnsThreshold) {
        $optimal.ReasoningFactors += "Optimal thread count below diminishing returns threshold"
    }
    
    # System-specific factors
    if ($SystemConfig.Platform.ProcessorCount -lt 4) {
        $optimal.ReasoningFactors += "Limited CPU cores may reduce parallel benefits"
    }
    
    if ($SystemConfig.Hardware.Memory.TotalPhysicalGB -lt 8) {
        $optimal.ReasoningFactors += "Limited memory may constrain parallel execution"
    }
    
    return $optimal
}

function Get-BaselineRecommendations {
    <#
    .SYNOPSIS
    Generate recommendations based on baseline results
    #>
    param($Baseline)
    
    $recommendations = @()
    
    $optimal = $Baseline.OptimalConfiguration
    $analysis = $Baseline.PerformanceAnalysis
    
    # Performance recommendations
    if ($optimal.PerformanceImprovement -gt 20) {
        $recommendations += "Enable parallel execution by default for $($Baseline.WorkloadType) workloads"
        $recommendations += "Set default thread count to $($optimal.OptimalThreads) for optimal performance"
    }
    
    # Efficiency recommendations
    if ($optimal.EfficiencyRating -lt 50) {
        $recommendations += "Monitor system resources during parallel execution - efficiency may be constrained"
    }
    
    # Consistency recommendations
    $parallelConsistency = $analysis.ParallelPerformance | Where-Object { $_.ThreadCount -eq $optimal.OptimalThreads }
    if ($parallelConsistency -and $parallelConsistency.ConsistencyRating -lt 70) {
        $recommendations += "Parallel execution shows inconsistent performance - consider workload-specific optimization"
    }
    
    # System-specific recommendations
    if ($analysis.ParallelOverheadDetected) {
        $recommendations += "Parallel overhead detected - consider increasing minimum workload size before enabling parallel execution"
    }
    
    if ($optimal.OptimalThreads -eq 1) {
        $recommendations += "Single-threaded execution performs best - avoid parallel overhead for this workload type"
    }
    
    # Resource recommendations
    $systemConfig = $Baseline.SystemConfiguration
    if ($systemConfig.Hardware.Memory.AvailableGB -lt 4) {
        $recommendations += "Consider memory optimization before enabling parallel execution"
    }
    
    if ($systemConfig.Performance.CPULoad -gt 70) {
        $recommendations += "High baseline CPU load detected - monitor for resource contention during parallel execution"
    }
    
    return $recommendations
}

# Workload simulation functions
function Invoke-TestWorkloadSimulation {
    param([switch]$Sequential, [switch]$Parallel, [int]$ThreadCount = 1)
    
    if ($Sequential) {
        # Simulate sequential test execution
        for ($i = 1; $i -le 20; $i++) {
            Start-Sleep -Milliseconds (Get-Random -Minimum 50 -Maximum 150)
        }
    } else {
        # Simulate parallel test execution
        1..$ThreadCount | ForEach-Object -Parallel {
            for ($i = 1; $i -le (20 / $using:ThreadCount); $i++) {
                Start-Sleep -Milliseconds (Get-Random -Minimum 50 -Maximum 150)
            }
        } -ThrottleLimit $ThreadCount
    }
}

function Invoke-BuildWorkloadSimulation {
    param([switch]$Sequential, [switch]$Parallel, [int]$ThreadCount = 1)
    
    if ($Sequential) {
        # Simulate sequential build steps
        for ($i = 1; $i -le 15; $i++) {
            Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 300)
        }
    } else {
        # Simulate parallel build steps
        1..$ThreadCount | ForEach-Object -Parallel {
            for ($i = 1; $i -le (15 / $using:ThreadCount); $i++) {
                Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 300)
            }
        } -ThrottleLimit $ThreadCount
    }
}

function Invoke-DeployWorkloadSimulation {
    param([switch]$Sequential, [switch]$Parallel, [int]$ThreadCount = 1)
    
    if ($Sequential) {
        # Simulate sequential deployment tasks
        for ($i = 1; $i -le 10; $i++) {
            Start-Sleep -Milliseconds (Get-Random -Minimum 200 -Maximum 500)
        }
    } else {
        # Simulate parallel deployment tasks
        1..$ThreadCount | ForEach-Object -Parallel {
            for ($i = 1; $i -le (10 / $using:ThreadCount); $i++) {
                Start-Sleep -Milliseconds (Get-Random -Minimum 200 -Maximum 500)
            }
        } -ThrottleLimit $ThreadCount
    }
}

function Invoke-AnalysisWorkloadSimulation {
    param([switch]$Sequential, [switch]$Parallel, [int]$ThreadCount = 1)
    
    if ($Sequential) {
        # Simulate sequential analysis tasks
        for ($i = 1; $i -le 25; $i++) {
            Start-Sleep -Milliseconds (Get-Random -Minimum 30 -Maximum 100)
        }
    } else {
        # Simulate parallel analysis tasks
        1..$ThreadCount | ForEach-Object -Parallel {
            for ($i = 1; $i -le (25 / $using:ThreadCount); $i++) {
                Start-Sleep -Milliseconds (Get-Random -Minimum 30 -Maximum 100)
            }
        } -ThrottleLimit $ThreadCount
    }
}

function Invoke-GeneralWorkloadSimulation {
    param([switch]$Sequential, [switch]$Parallel, [int]$ThreadCount = 1)
    
    # Simulate general computational workload
    if ($Sequential) {
        for ($i = 1; $i -le 30; $i++) {
            # Simulate CPU work
            $result = 1..1000 | ForEach-Object { [math]::Sqrt($_) }
            Start-Sleep -Milliseconds (Get-Random -Minimum 10 -Maximum 50)
        }
    } else {
        1..$ThreadCount | ForEach-Object -Parallel {
            for ($i = 1; $i -le (30 / $using:ThreadCount); $i++) {
                # Simulate CPU work
                $result = 1..1000 | ForEach-Object { [math]::Sqrt($_) }
                Start-Sleep -Milliseconds (Get-Random -Minimum 10 -Maximum 50)
            }
        } -ThrottleLimit $ThreadCount
    }
}

# Helper functions
function Get-SystemLoadDuringExecution { return Get-Random -Minimum 20 -Maximum 60 }
function Get-MemoryUsageDuringExecution { return Get-Random -Minimum 30 -Maximum 70 }
function Test-ParallelOverhead { param($ThreadCount); return $ThreadCount -gt 4 }
function Get-ParallelEfficiency { param($ThreadCount, $Results); return [math]::Round(100 / $ThreadCount, 2) }

function Get-StandardDeviation {
    param([double[]]$Values)
    if ($Values.Count -le 1) { return 0 }
    $mean = ($Values | Measure-Object -Average).Average
    $sumSquaredDiffs = ($Values | ForEach-Object { [math]::Pow($_ - $mean, 2) } | Measure-Object -Sum).Sum
    return [math]::Sqrt($sumSquaredDiffs / ($Values.Count - 1))
}

function Get-ConsistencyRating {
    param([double[]]$Values)
    if ($Values.Count -le 1) { return 100 }
    $mean = ($Values | Measure-Object -Average).Average
    $stdDev = Get-StandardDeviation -Values $Values
    $coefficientOfVariation = if ($mean -gt 0) { ($stdDev / $mean) * 100 } else { 0 }
    return [math]::Max(0, [math]::Round(100 - $coefficientOfVariation, 2))
}

function Get-DiminishingReturnsThreshold {
    param($PerformanceData)
    # Simple heuristic: find where efficiency per thread drops below 80% of peak
    $maxEfficiency = ($PerformanceData | Measure-Object -Property EfficiencyPerThread -Maximum).Maximum
    $threshold = $maxEfficiency * 0.8
    
    $thresholdPoint = $PerformanceData | Where-Object { $_.EfficiencyPerThread -ge $threshold } | 
                     Measure-Object -Property ThreadCount -Maximum
    
    return if ($thresholdPoint) { $thresholdPoint.Maximum } else { 2 }
}

function Export-BaselineToCSV {
    param($Baseline)
    
    $csvData = @()
    
    # Add sequential data if available
    if ($Baseline.ExecutionResults.Sequential) {
        $csvData += [PSCustomObject]@{
            WorkloadType = $Baseline.WorkloadType
            ExecutionType = "Sequential"
            ThreadCount = 1
            AverageDuration = $Baseline.ExecutionResults.Sequential.AverageDuration
            MinDuration = $Baseline.ExecutionResults.Sequential.MinDuration
            MaxDuration = $Baseline.ExecutionResults.Sequential.MaxDuration
            ConsistencyRating = $Baseline.ExecutionResults.Sequential.ConsistencyRating
            PerformanceImprovement = 0
            EfficiencyPerThread = 0
        }
    }
    
    # Add parallel data
    foreach ($parallel in $Baseline.ExecutionResults.Parallel) {
        $performanceData = $Baseline.PerformanceAnalysis.ParallelPerformance | Where-Object { $_.ThreadCount -eq $parallel.ThreadCount }
        
        $csvData += [PSCustomObject]@{
            WorkloadType = $Baseline.WorkloadType
            ExecutionType = "Parallel"
            ThreadCount = $parallel.ThreadCount
            AverageDuration = $parallel.AverageDuration
            MinDuration = $parallel.MinDuration
            MaxDuration = $parallel.MaxDuration
            ConsistencyRating = $parallel.ConsistencyRating
            PerformanceImprovement = if ($performanceData) { $performanceData.PerformanceImprovement } else { 0 }
            EfficiencyPerThread = if ($performanceData) { $performanceData.EfficiencyPerThread } else { 0 }
        }
    }
    
    return $csvData
}

Export-ModuleMember -Function New-ParallelExecutionBaseline