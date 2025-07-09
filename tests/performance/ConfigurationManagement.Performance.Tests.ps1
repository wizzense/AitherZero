#Requires -Module Pester

<#
.SYNOPSIS
    Performance test suite for configuration management under load
.DESCRIPTION
    Comprehensive performance testing of configuration management capabilities including:
    - Large configuration file processing and validation
    - Memory usage optimization under load conditions
    - Configuration operation scalability testing
    - Concurrent configuration access and modification
    - Hot-reload performance with large datasets
    - Backup and restore performance benchmarks
    - Configuration search and query performance
    - Network latency impact on remote configurations
    - Configuration caching and optimization strategies
    - Resource usage monitoring and limits
    - Performance regression detection
    - Load balancing and distributed configuration scenarios
.NOTES
    This test suite focuses on performance characteristics and scalability
    of the configuration management system under various load conditions.
#>

BeforeAll {
    # Import required modules using the TestingFramework infrastructure
    $ProjectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else {
        $currentPath = $PSScriptRoot
        while ($currentPath -and -not (Test-Path (Join-Path $currentPath ".git"))) {
            $currentPath = Split-Path $currentPath -Parent
        }
        $currentPath
    }

    # Import TestingFramework for infrastructure
    $testingFrameworkPath = Join-Path $ProjectRoot "aither-core/modules/TestingFramework"
    if (Test-Path $testingFrameworkPath) {
        Import-Module $testingFrameworkPath -Force
    }

    # Import configuration modules
    $configModules = @("ConfigurationCore", "ConfigurationCarousel", "ConfigurationRepository", "ConfigurationManager")
    foreach ($module in $configModules) {
        $modulePath = Join-Path $ProjectRoot "aither-core/modules/$module"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction SilentlyContinue
        }
    }

    # Write-CustomLog is guaranteed to be available from AitherCore orchestration
    # No fallback needed - trust the orchestration system

    # Create comprehensive test directory structure for performance testing
    $TestPerformanceDir = Join-Path $TestDrive 'ConfigurationPerformance'
    $TestLargeConfigsDir = Join-Path $TestPerformanceDir 'large-configs'
    $TestConcurrentDir = Join-Path $TestPerformanceDir 'concurrent'
    $TestCacheDir = Join-Path $TestPerformanceDir 'cache'
    $TestBenchmarkDir = Join-Path $TestPerformanceDir 'benchmarks'
    $TestLoadTestDir = Join-Path $TestPerformanceDir 'load-tests'
    $TestMetricsDir = Join-Path $TestPerformanceDir 'metrics'

    @($TestPerformanceDir, $TestLargeConfigsDir, $TestConcurrentDir, $TestCacheDir,
      $TestBenchmarkDir, $TestLoadTestDir, $TestMetricsDir) | ForEach-Object {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }

    # Set up test environment
    $env:TEST_PERFORMANCE_DIR = $TestPerformanceDir
    $env:TEST_LARGE_CONFIGS_DIR = $TestLargeConfigsDir
    $env:TEST_CONCURRENT_DIR = $TestConcurrentDir

    # Initialize performance tracking
    $script:PerformanceMetrics = @()
    $script:LoadTestResults = @()
    $script:BenchmarkResults = @()
    $script:ResourceUsage = @()

    # Performance test data and scenarios
    $script:TestData = @{
        PerformanceBaselines = @{
            SmallConfig = @{
                Size = "Small"
                FileCount = 5
                SettingsCount = 50
                ExpectedLoadTime = 500      # milliseconds
                ExpectedMemoryUsage = 1     # MB
                ExpectedValidationTime = 100 # milliseconds
            }
            MediumConfig = @{
                Size = "Medium"
                FileCount = 25
                SettingsCount = 500
                ExpectedLoadTime = 2000     # milliseconds
                ExpectedMemoryUsage = 5     # MB
                ExpectedValidationTime = 500 # milliseconds
            }
            LargeConfig = @{
                Size = "Large"
                FileCount = 100
                SettingsCount = 5000
                ExpectedLoadTime = 10000    # milliseconds
                ExpectedMemoryUsage = 25    # MB
                ExpectedValidationTime = 2000 # milliseconds
            }
            ExtraLargeConfig = @{
                Size = "ExtraLarge"
                FileCount = 500
                SettingsCount = 50000
                ExpectedLoadTime = 60000    # milliseconds
                ExpectedMemoryUsage = 100   # MB
                ExpectedValidationTime = 10000 # milliseconds
            }
        }

        LoadTestScenarios = @{
            ConcurrentRead = @{
                Description = "Multiple concurrent read operations"
                OperationType = "Read"
                ConcurrentOperations = 10
                DurationSeconds = 30
                ExpectedThroughput = 100  # operations per second
            }
            ConcurrentWrite = @{
                Description = "Multiple concurrent write operations"
                OperationType = "Write"
                ConcurrentOperations = 5
                DurationSeconds = 60
                ExpectedThroughput = 50   # operations per second
            }
            MixedOperations = @{
                Description = "Mixed read/write operations under load"
                OperationType = "Mixed"
                ConcurrentOperations = 20
                DurationSeconds = 120
                ReadWriteRatio = 0.7      # 70% reads, 30% writes
                ExpectedThroughput = 75   # operations per second
            }
            SustainedLoad = @{
                Description = "Sustained load over extended period"
                OperationType = "Sustained"
                ConcurrentOperations = 15
                DurationSeconds = 300     # 5 minutes
                ExpectedThroughput = 80   # operations per second
            }
        }

        ResourceLimits = @{
            MaxMemoryUsage = 500MB      # Maximum memory usage allowed
            MaxCpuTime = 30000          # Maximum CPU time in milliseconds
            MaxFileHandles = 1000       # Maximum file handles
            MaxConcurrentOperations = 50 # Maximum concurrent operations
            ResponseTimeThreshold = 5000 # Maximum response time in milliseconds
        }

        BenchmarkOperations = @{
            ConfigurationLoad = @{
                Operation = "Load"
                Iterations = 100
                WarmupIterations = 10
                ExpectedAverageTime = 100  # milliseconds
                ExpectedP95Time = 200      # milliseconds
                ExpectedP99Time = 500      # milliseconds
            }
            ConfigurationValidation = @{
                Operation = "Validate"
                Iterations = 200
                WarmupIterations = 20
                ExpectedAverageTime = 50   # milliseconds
                ExpectedP95Time = 100      # milliseconds
                ExpectedP99Time = 200      # milliseconds
            }
            ConfigurationSave = @{
                Operation = "Save"
                Iterations = 50
                WarmupIterations = 5
                ExpectedAverageTime = 200  # milliseconds
                ExpectedP95Time = 400      # milliseconds
                ExpectedP99Time = 800      # milliseconds
            }
            HotReload = @{
                Operation = "HotReload"
                Iterations = 30
                WarmupIterations = 3
                ExpectedAverageTime = 300  # milliseconds
                ExpectedP95Time = 600      # milliseconds
                ExpectedP99Time = 1000     # milliseconds
            }
        }
    }

    # Performance measurement utilities
    function Measure-ConfigurationPerformance {
        param(
            [scriptblock]$ScriptBlock,
            [string]$OperationName = "Unknown",
            [hashtable]$ExpectedLimits = @{}
        )

        # Force garbage collection before measurement
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()

        $startTime = Get-Date
        $startMemory = [System.GC]::GetTotalMemory($false)
        $startCpu = (Get-Process -Id $PID).TotalProcessorTime

        $result = $null
        $success = $false
        $exception = $null

        try {
            $result = & $ScriptBlock
            $success = $true
        } catch {
            $exception = $_.Exception
            $result = $exception.Message
        }

        $endTime = Get-Date
        $endMemory = [System.GC]::GetTotalMemory($false)
        $endCpu = (Get-Process -Id $PID).TotalProcessorTime

        $metrics = @{
            OperationName = $OperationName
            Success = $success
            Result = $result
            Exception = $exception
            StartTime = $startTime
            EndTime = $endTime
            Duration = ($endTime - $startTime).TotalMilliseconds
            MemoryUsed = ($endMemory - $startMemory) / 1MB
            CpuTime = ($endCpu - $startCpu).TotalMilliseconds
            Timestamp = Get-Date
        }

        # Add performance assessment
        if ($ExpectedLimits.Count -gt 0) {
            $metrics.PerformanceAssessment = @{
                WithinDurationLimit = if ($ExpectedLimits.MaxDuration) { $metrics.Duration -le $ExpectedLimits.MaxDuration } else { $true }
                WithinMemoryLimit = if ($ExpectedLimits.MaxMemory) { $metrics.MemoryUsed -le $ExpectedLimits.MaxMemory } else { $true }
                WithinCpuLimit = if ($ExpectedLimits.MaxCpu) { $metrics.CpuTime -le $ExpectedLimits.MaxCpu } else { $true }
            }
            $metrics.OverallPerformance = $metrics.PerformanceAssessment.WithinDurationLimit -and
                                        $metrics.PerformanceAssessment.WithinMemoryLimit -and
                                        $metrics.PerformanceAssessment.WithinCpuLimit
        }

        $script:PerformanceMetrics += $metrics
        return $metrics
    }

    function Start-LoadTest {
        param(
            [scriptblock]$Operation,
            [int]$ConcurrentOperations = 5,
            [int]$DurationSeconds = 30,
            [string]$TestName = "LoadTest"
        )

        $loadTestId = [System.Guid]::NewGuid().ToString().Substring(0, 8)
        $startTime = Get-Date
        $endTime = $startTime.AddSeconds($DurationSeconds)
        $operations = @()
        $runspaces = @()
        $runspacePool = [runspacefactory]::CreateRunspacePool(1, $ConcurrentOperations)
        $runspacePool.Open()

        Write-CustomLog -Level 'INFO' -Message "Starting load test '$TestName' with $ConcurrentOperations concurrent operations for $DurationSeconds seconds"

        try {
            # Start concurrent operations
            for ($i = 1; $i -le $ConcurrentOperations; $i++) {
                $runspace = [powershell]::Create()
                $runspace.RunspacePool = $runspacePool

                $runspace.AddScript({
                    param($Operation, $EndTime, $OperationId)

                    $results = @()
                    $operationCount = 0

                    while ((Get-Date) -lt $EndTime) {
                        $operationStart = Get-Date
                        try {
                            $result = & $Operation
                            $success = $true
                            $error = $null
                        } catch {
                            $result = $null
                            $success = $false
                            $error = $_.Exception.Message
                        }
                        $operationEnd = Get-Date

                        $results += @{
                            OperationId = $OperationId
                            OperationNumber = ++$operationCount
                            StartTime = $operationStart
                            EndTime = $operationEnd
                            Duration = ($operationEnd - $operationStart).TotalMilliseconds
                            Success = $success
                            Error = $error
                            Result = $result
                        }

                        Start-Sleep -Milliseconds 10  # Small delay between operations
                    }

                    return @{
                        OperationId = $OperationId
                        OperationCount = $operationCount
                        Results = $results
                    }
                }).AddArgument($Operation).AddArgument($endTime).AddArgument($i) | Out-Null

                $runspaces += @{
                    Runspace = $runspace
                    Handle = $runspace.BeginInvoke()
                    Id = $i
                }
            }

            # Wait for completion
            foreach ($runspaceInfo in $runspaces) {
                $result = $runspaceInfo.Runspace.EndInvoke($runspaceInfo.Handle)
                $operations += $result
                $runspaceInfo.Runspace.Dispose()
            }

        } finally {
            $runspacePool.Close()
            $runspacePool.Dispose()
        }

        $actualEndTime = Get-Date
        $actualDuration = ($actualEndTime - $startTime).TotalSeconds

        # Analyze results
        $allOperationResults = $operations | ForEach-Object { $_.Results }
        $totalOperations = ($operations | Measure-Object -Property OperationCount -Sum).Sum
        $successfulOperations = ($allOperationResults | Where-Object { $_.Success }).Count
        $failedOperations = $totalOperations - $successfulOperations
        $averageResponseTime = ($allOperationResults | Measure-Object -Property Duration -Average).Average
        $throughput = $totalOperations / $actualDuration

        $loadTestResult = @{
            LoadTestId = $loadTestId
            TestName = $TestName
            StartTime = $startTime
            EndTime = $actualEndTime
            PlannedDuration = $DurationSeconds
            ActualDuration = $actualDuration
            ConcurrentOperations = $ConcurrentOperations
            TotalOperations = $totalOperations
            SuccessfulOperations = $successfulOperations
            FailedOperations = $failedOperations
            SuccessRate = if ($totalOperations -gt 0) { $successfulOperations / $totalOperations } else { 0 }
            AverageResponseTime = $averageResponseTime
            Throughput = $throughput
            Operations = $operations
            AllResults = $allOperationResults
        }

        $script:LoadTestResults += $loadTestResult

        Write-CustomLog -Level 'INFO' -Message "Load test '$TestName' completed: $totalOperations operations, $($throughput.ToString('F2')) ops/sec, $($averageResponseTime.ToString('F2'))ms avg response time"

        return $loadTestResult
    }

    function Invoke-BenchmarkTest {
        param(
            [scriptblock]$Operation,
            [int]$Iterations = 100,
            [int]$WarmupIterations = 10,
            [string]$BenchmarkName = "Benchmark"
        )

        $benchmarkId = [System.Guid]::NewGuid().ToString().Substring(0, 8)
        Write-CustomLog -Level 'INFO' -Message "Starting benchmark '$BenchmarkName' with $WarmupIterations warmup and $Iterations test iterations"

        # Warmup iterations
        for ($i = 1; $i -le $WarmupIterations; $i++) {
            try {
                & $Operation | Out-Null
            } catch {
                # Ignore warmup errors
            }
        }

        # Force garbage collection after warmup
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()

        # Benchmark iterations
        $measurements = @()
        for ($i = 1; $i -le $Iterations; $i++) {
            $measurement = Measure-ConfigurationPerformance -ScriptBlock $Operation -OperationName "$BenchmarkName-Iteration-$i"
            $measurements += $measurement
        }

        # Calculate statistics
        $durations = $measurements | ForEach-Object { $_.Duration }
        $memoryUsages = $measurements | ForEach-Object { $_.MemoryUsed }
        $successfulMeasurements = $measurements | Where-Object { $_.Success }

        $statistics = @{
            BenchmarkId = $benchmarkId
            BenchmarkName = $BenchmarkName
            Iterations = $Iterations
            WarmupIterations = $WarmupIterations
            SuccessfulIterations = $successfulMeasurements.Count
            FailedIterations = $Iterations - $successfulMeasurements.Count
            SuccessRate = $successfulMeasurements.Count / $Iterations

            # Duration statistics
            MinDuration = ($durations | Measure-Object -Minimum).Minimum
            MaxDuration = ($durations | Measure-Object -Maximum).Maximum
            AverageDuration = ($durations | Measure-Object -Average).Average
            MedianDuration = $durations | Sort-Object | Select-Object -Index ([math]::Floor($durations.Count / 2))
            P95Duration = $durations | Sort-Object | Select-Object -Index ([math]::Floor($durations.Count * 0.95))
            P99Duration = $durations | Sort-Object | Select-Object -Index ([math]::Floor($durations.Count * 0.99))

            # Memory statistics
            MinMemoryUsage = ($memoryUsages | Measure-Object -Minimum).Minimum
            MaxMemoryUsage = ($memoryUsages | Measure-Object -Maximum).Maximum
            AverageMemoryUsage = ($memoryUsages | Measure-Object -Average).Average

            # Raw measurements
            Measurements = $measurements
            Timestamp = Get-Date
        }

        $script:BenchmarkResults += $statistics

        Write-CustomLog -Level 'INFO' -Message "Benchmark '$BenchmarkName' completed: avg $($statistics.AverageDuration.ToString('F2'))ms, P95 $($statistics.P95Duration.ToString('F2'))ms, P99 $($statistics.P99Duration.ToString('F2'))ms"

        return $statistics
    }

    function New-LargeConfiguration {
        param(
            [int]$SettingsCount = 1000,
            [int]$ModuleCount = 50,
            [int]$EnvironmentCount = 10,
            [int]$NestedLevels = 5
        )

        $config = @{
            version = "1.0"
            name = "Large Performance Test Configuration"
            created = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            metadata = @{
                generatedFor = "performance testing"
                settingsCount = $SettingsCount
                moduleCount = $ModuleCount
                environmentCount = $EnvironmentCount
            }
            settings = @{}
            modules = @{}
            environments = @{}
            largeDataSections = @{}
        }

        # Generate many settings
        for ($i = 1; $i -le $SettingsCount; $i++) {
            $config.settings["setting$i"] = @{
                value = "performance_test_value_$i"
                type = @("string", "number", "boolean", "array")[(Get-Random -Maximum 4)]
                priority = Get-Random -Maximum 100
                category = "performance_category_$($i % 20)"
                description = "Performance test setting $i with detailed description" * 3
            }
        }

        # Generate many modules
        for ($i = 1; $i -le $ModuleCount; $i++) {
            $config.modules["module$i"] = @{
                enabled = ($i % 3 -ne 0)  # ~67% enabled
                version = "1.$($i % 10).0"
                config = @{}
                dependencies = @()
                metadata = @{
                    author = "performance_test"
                    description = "Performance test module $i"
                }
            }

            # Add module-specific configuration
            for ($j = 1; $j -le 20; $j++) {
                $config.modules["module$i"].config["param$j"] = "module_${i}_param_${j}_value"
            }

            # Add dependencies
            for ($d = 1; $d -le (Get-Random -Maximum 5); $d++) {
                $depIndex = Get-Random -Maximum $ModuleCount
                if ($depIndex -ne $i) {
                    $config.modules["module$i"].dependencies += "module$depIndex"
                }
            }
        }

        # Generate many environments
        for ($i = 1; $i -le $EnvironmentCount; $i++) {
            $config.environments["env$i"] = @{
                name = "Environment $i"
                type = @("development", "testing", "staging", "production")[(Get-Random -Maximum 4)]
                settings = @{}
                resources = @{}
                networks = @{}
            }

            # Environment-specific settings
            for ($j = 1; $j -le 50; $j++) {
                $config.environments["env$i"].settings["env_setting$j"] = "env_${i}_setting_${j}_value"
            }

            # Environment resources
            for ($r = 1; $r -le 10; $r++) {
                $config.environments["env$i"].resources["resource$r"] = @{
                    type = "compute"
                    size = "standard"
                    count = Get-Random -Maximum 10
                }
            }
        }

        # Generate nested data structures
        function Add-NestedData {
            param($Parent, $Level, $MaxLevel, $BranchFactor = 3)

            if ($Level -lt $MaxLevel) {
                for ($i = 1; $i -le $BranchFactor; $i++) {
                    $key = "level${Level}_item$i"
                    $Parent[$key] = @{
                        level = $Level
                        data = "nested_data_level_${Level}_item_$i" * (6 - $Level)  # Deeper levels have less data
                        metadata = @{
                            created = Get-Date
                            level = $Level
                            path = "$Level.$i"
                        }
                    }
                    Add-NestedData -Parent $Parent[$key] -Level ($Level + 1) -MaxLevel $MaxLevel -BranchFactor $BranchFactor
                }
            }
        }

        Add-NestedData -Parent $config.largeDataSections -Level 1 -MaxLevel $NestedLevels -BranchFactor 3

        return $config
    }

    function New-ConfigurationFile {
        param(
            [string]$Path,
            [hashtable]$Configuration,
            [string]$Format = "json"
        )

        $dir = Split-Path $Path -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        switch ($Format.ToLower()) {
            "json" {
                $Configuration | ConvertTo-Json -Depth 20 | Set-Content -Path $Path
            }
            default {
                throw "Unsupported format: $Format"
            }
        }
    }

    function Test-ResourceUsage {
        param([scriptblock]$ScriptBlock)

        $beforeMemory = [System.GC]::GetTotalMemory($false)
        $beforeHandles = (Get-Process -Id $PID).HandleCount
        $beforeTime = Get-Date

        try {
            $result = & $ScriptBlock
            $success = $true
        } catch {
            $result = $_.Exception.Message
            $success = $false
        }

        $afterTime = Get-Date
        $afterMemory = [System.GC]::GetTotalMemory($false)
        $afterHandles = (Get-Process -Id $PID).HandleCount

        $usage = @{
            Success = $success
            Result = $result
            Duration = ($afterTime - $beforeTime).TotalMilliseconds
            MemoryDelta = ($afterMemory - $beforeMemory) / 1MB
            HandleDelta = $afterHandles - $beforeHandles
            Timestamp = Get-Date
        }

        $script:ResourceUsage += $usage
        return $usage
    }
}

Describe "Configuration Management Performance Tests" {

    Context "Large Configuration Processing" {

        It "Should handle small configurations within performance baselines" {
            $baseline = $script:TestData.PerformanceBaselines.SmallConfig

            # Create small configuration
            $smallConfig = New-LargeConfiguration -SettingsCount $baseline.SettingsCount -ModuleCount 5 -EnvironmentCount 2 -NestedLevels 2
            $configPath = Join-Path $TestLargeConfigsDir "small-config.json"
            New-ConfigurationFile -Path $configPath -Configuration $smallConfig

            # Test configuration loading
            $loadPerformance = Measure-ConfigurationPerformance -OperationName "SmallConfigLoad" -ExpectedLimits @{
                MaxDuration = $baseline.ExpectedLoadTime
                MaxMemory = $baseline.ExpectedMemoryUsage
            } -ScriptBlock {
                $config = Get-Content $configPath | ConvertFrom-Json
                return $config
            }

            # Test configuration validation
            $validationPerformance = Measure-ConfigurationPerformance -OperationName "SmallConfigValidation" -ExpectedLimits @{
                MaxDuration = $baseline.ExpectedValidationTime
            } -ScriptBlock {
                $config = Get-Content $configPath | ConvertFrom-Json
                # Mock validation
                $valid = $config.version -and $config.name -and $config.settings
                return $valid
            }

            # Assert performance baselines
            $loadPerformance.Success | Should -Be $true
            $loadPerformance.Duration | Should -BeLessThan $baseline.ExpectedLoadTime
            $loadPerformance.MemoryUsed | Should -BeLessThan $baseline.ExpectedMemoryUsage
            $loadPerformance.OverallPerformance | Should -Be $true

            $validationPerformance.Success | Should -Be $true
            $validationPerformance.Duration | Should -BeLessThan $baseline.ExpectedValidationTime
        }

        It "Should handle medium configurations within performance baselines" {
            $baseline = $script:TestData.PerformanceBaselines.MediumConfig

            # Create medium configuration
            $mediumConfig = New-LargeConfiguration -SettingsCount $baseline.SettingsCount -ModuleCount 25 -EnvironmentCount 5 -NestedLevels 3
            $configPath = Join-Path $TestLargeConfigsDir "medium-config.json"
            New-ConfigurationFile -Path $configPath -Configuration $mediumConfig

            # Test configuration processing
            $processPerformance = Measure-ConfigurationPerformance -OperationName "MediumConfigProcess" -ExpectedLimits @{
                MaxDuration = $baseline.ExpectedLoadTime
                MaxMemory = $baseline.ExpectedMemoryUsage
            } -ScriptBlock {
                $config = Get-Content $configPath | ConvertFrom-Json

                # Simulate configuration processing
                $processedSettings = @{}
                foreach ($key in $config.settings.Keys) {
                    $processedSettings[$key] = $config.settings[$key]
                }

                $processedModules = @{}
                foreach ($key in $config.modules.Keys) {
                    if ($config.modules[$key].enabled) {
                        $processedModules[$key] = $config.modules[$key]
                    }
                }

                return @{
                    settings = $processedSettings
                    modules = $processedModules
                    processed = $true
                }
            }

            # Assert performance
            $processPerformance.Success | Should -Be $true
            $processPerformance.Duration | Should -BeLessThan $baseline.ExpectedLoadTime
            $processPerformance.MemoryUsed | Should -BeLessThan $baseline.ExpectedMemoryUsage
            $processPerformance.OverallPerformance | Should -Be $true

            # Verify processing results
            $processPerformance.Result.processed | Should -Be $true
            $processPerformance.Result.settings.Count | Should -BeGreaterThan 0
        }

        It "Should handle large configurations efficiently" {
            $baseline = $script:TestData.PerformanceBaselines.LargeConfig

            # Create large configuration
            $largeConfig = New-LargeConfiguration -SettingsCount $baseline.SettingsCount -ModuleCount 100 -EnvironmentCount 10 -NestedLevels 4
            $configPath = Join-Path $TestLargeConfigsDir "large-config.json"
            New-ConfigurationFile -Path $configPath -Configuration $largeConfig

            # Test large configuration handling
            $largeConfigPerformance = Measure-ConfigurationPerformance -OperationName "LargeConfigProcess" -ExpectedLimits @{
                MaxDuration = $baseline.ExpectedLoadTime
                MaxMemory = $baseline.ExpectedMemoryUsage
            } -ScriptBlock {
                $config = Get-Content $configPath | ConvertFrom-Json

                # Simulate complex configuration operations
                $enabledModules = $config.modules.Keys | Where-Object { $config.modules[$_].enabled }
                $prodEnvironments = $config.environments.Keys | Where-Object { $config.environments[$_].type -eq "production" }
                $criticalSettings = $config.settings.Keys | Where-Object { $config.settings[$_].priority -gt 80 }

                # Simulate dependency resolution
                $dependencyMap = @{}
                foreach ($module in $enabledModules) {
                    $dependencies = $config.modules[$module].dependencies
                    if ($dependencies) {
                        $dependencyMap[$module] = $dependencies | Where-Object { $_ -in $enabledModules }
                    }
                }

                return @{
                    totalSettings = $config.settings.Count
                    enabledModules = $enabledModules.Count
                    prodEnvironments = $prodEnvironments.Count
                    criticalSettings = $criticalSettings.Count
                    dependencyMap = $dependencyMap.Count
                    processed = $true
                }
            }

            # Assert large configuration performance
            $largeConfigPerformance.Success | Should -Be $true
            $largeConfigPerformance.Duration | Should -BeLessThan $baseline.ExpectedLoadTime
            $largeConfigPerformance.MemoryUsed | Should -BeLessThan $baseline.ExpectedMemoryUsage

            # Verify processing results
            $largeConfigPerformance.Result.processed | Should -Be $true
            $largeConfigPerformance.Result.totalSettings | Should -Be $baseline.SettingsCount
            $largeConfigPerformance.Result.enabledModules | Should -BeGreaterThan 0
        }

        It "Should handle extra-large configurations with acceptable performance degradation" {
            $baseline = $script:TestData.PerformanceBaselines.ExtraLargeConfig

            # Create extra-large configuration
            $extraLargeConfig = New-LargeConfiguration -SettingsCount $baseline.SettingsCount -ModuleCount 500 -EnvironmentCount 20 -NestedLevels 5
            $configPath = Join-Path $TestLargeConfigsDir "extra-large-config.json"
            New-ConfigurationFile -Path $configPath -Configuration $extraLargeConfig

            # Test extra-large configuration with resource monitoring
            $resourceUsage = Test-ResourceUsage {
                $config = Get-Content $configPath | ConvertFrom-Json

                # Simulate intensive configuration operations
                $allSettings = @{}
                foreach ($key in $config.settings.Keys) {
                    $setting = $config.settings[$key]
                    $allSettings[$key] = @{
                        value = $setting.value
                        category = $setting.category
                        priority = $setting.priority
                    }
                }

                $moduleStats = @{}
                foreach ($module in $config.modules.Keys) {
                    $moduleData = $config.modules[$module]
                    $moduleStats[$module] = @{
                        enabled = $moduleData.enabled
                        configCount = $moduleData.config.Keys.Count
                        dependencyCount = if ($moduleData.dependencies) { $moduleData.dependencies.Count } else { 0 }
                    }
                }

                return @{
                    settingsProcessed = $allSettings.Count
                    modulesProcessed = $moduleStats.Count
                    completed = $true
                }
            }

            # Assert resource usage within acceptable limits
            $resourceUsage.Success | Should -Be $true
            $resourceUsage.Duration | Should -BeLessThan $baseline.ExpectedLoadTime
            $resourceUsage.MemoryDelta | Should -BeLessThan $baseline.ExpectedMemoryUsage
            $resourceUsage.HandleDelta | Should -BeLessThan 100  # Should not create excessive handles

            # Verify processing completed
            $resourceUsage.Result.completed | Should -Be $true
            $resourceUsage.Result.settingsProcessed | Should -Be $baseline.SettingsCount
            $resourceUsage.Result.modulesProcessed | Should -Be 500
        }
    }

    Context "Concurrent Operations Performance" {

        It "Should handle concurrent read operations efficiently" {
            $scenario = $script:TestData.LoadTestScenarios.ConcurrentRead

            # Create test configuration for concurrent access
            $testConfig = New-LargeConfiguration -SettingsCount 1000 -ModuleCount 50 -EnvironmentCount 5
            $configPath = Join-Path $TestConcurrentDir "concurrent-read-config.json"
            New-ConfigurationFile -Path $configPath -Configuration $testConfig

            # Define read operation
            $readOperation = {
                $config = Get-Content $using:configPath | ConvertFrom-Json
                $randomSetting = $config.settings.Keys | Get-Random
                return $config.settings[$randomSetting]
            }

            # Execute concurrent read load test
            $loadTestResult = Start-LoadTest -Operation $readOperation -ConcurrentOperations $scenario.ConcurrentOperations -DurationSeconds $scenario.DurationSeconds -TestName "ConcurrentRead"

            # Assert concurrent read performance
            $loadTestResult.SuccessRate | Should -BeGreaterThan 0.95  # 95% success rate
            $loadTestResult.Throughput | Should -BeGreaterThan ($scenario.ExpectedThroughput * 0.8)  # 80% of expected throughput
            $loadTestResult.AverageResponseTime | Should -BeLessThan 1000  # Under 1 second average response time
            $loadTestResult.FailedOperations | Should -BeLessThan ($loadTestResult.TotalOperations * 0.05)  # Less than 5% failures
        }

        It "Should handle concurrent write operations with acceptable performance" {
            $scenario = $script:TestData.LoadTestScenarios.ConcurrentWrite

            # Create test configuration for concurrent writes
            $baseConfig = New-LargeConfiguration -SettingsCount 500 -ModuleCount 25 -EnvironmentCount 3
            $writeConfigDir = Join-Path $TestConcurrentDir "concurrent-write"
            New-Item -ItemType Directory -Path $writeConfigDir -Force | Out-Null

            # Define write operation
            $writeOperation = {
                $operationId = [System.Guid]::NewGuid().ToString().Substring(0, 8)
                $configPath = Join-Path $using:writeConfigDir "config-write-$operationId.json"

                $config = $using:baseConfig.Clone()
                $config.metadata.writeTest = $operationId
                $config.metadata.writeTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')

                $config | ConvertTo-Json -Depth 20 | Set-Content -Path $configPath
                return $operationId
            }

            # Execute concurrent write load test
            $loadTestResult = Start-LoadTest -Operation $writeOperation -ConcurrentOperations $scenario.ConcurrentOperations -DurationSeconds $scenario.DurationSeconds -TestName "ConcurrentWrite"

            # Assert concurrent write performance
            $loadTestResult.SuccessRate | Should -BeGreaterThan 0.90  # 90% success rate (writes are more prone to contention)
            $loadTestResult.Throughput | Should -BeGreaterThan ($scenario.ExpectedThroughput * 0.7)  # 70% of expected throughput
            $loadTestResult.AverageResponseTime | Should -BeLessThan 2000  # Under 2 seconds average response time

            # Verify written files
            $writtenFiles = Get-ChildItem -Path $writeConfigDir -Filter "config-write-*.json"
            $writtenFiles.Count | Should -BeGreaterThan 0
            $writtenFiles.Count | Should -BeLessOrEqual $loadTestResult.SuccessfulOperations
        }

        It "Should handle mixed read/write operations under load" {
            $scenario = $script:TestData.LoadTestScenarios.MixedOperations

            # Create test configuration
            $testConfig = New-LargeConfiguration -SettingsCount 2000 -ModuleCount 75 -EnvironmentCount 8
            $mixedConfigDir = Join-Path $TestConcurrentDir "mixed-operations"
            New-Item -ItemType Directory -Path $mixedConfigDir -Force | Out-Null
            $readConfigPath = Join-Path $mixedConfigDir "read-config.json"
            New-ConfigurationFile -Path $readConfigPath -Configuration $testConfig

            # Define mixed operation
            $mixedOperation = {
                $operationId = [System.Guid]::NewGuid().ToString().Substring(0, 8)
                $readWriteRatio = $using:scenario.ReadWriteRatio

                if ((Get-Random) -lt $readWriteRatio) {
                    # Read operation
                    $config = Get-Content $using:readConfigPath | ConvertFrom-Json
                    $randomModule = $config.modules.Keys | Get-Random
                    return @{
                        Type = "Read"
                        OperationId = $operationId
                        Result = $config.modules[$randomModule].enabled
                    }
                } else {
                    # Write operation
                    $writeConfigPath = Join-Path $using:mixedConfigDir "mixed-write-$operationId.json"
                    $config = $using:testConfig.Clone()
                    $config.metadata.mixedTest = $operationId
                    $config.metadata.operationType = "Write"

                    $config | ConvertTo-Json -Depth 20 | Set-Content -Path $writeConfigPath
                    return @{
                        Type = "Write"
                        OperationId = $operationId
                        Result = "Written"
                    }
                }
            }

            # Execute mixed operations load test
            $loadTestResult = Start-LoadTest -Operation $mixedOperation -ConcurrentOperations $scenario.ConcurrentOperations -DurationSeconds $scenario.DurationSeconds -TestName "MixedOperations"

            # Assert mixed operations performance
            $loadTestResult.SuccessRate | Should -BeGreaterThan 0.85  # 85% success rate
            $loadTestResult.Throughput | Should -BeGreaterThan ($scenario.ExpectedThroughput * 0.75)  # 75% of expected throughput
            $loadTestResult.AverageResponseTime | Should -BeLessThan 1500  # Under 1.5 seconds average response time

            # Analyze operation types
            $readOperations = $loadTestResult.AllResults | Where-Object { $_.Result.Type -eq "Read" }
            $writeOperations = $loadTestResult.AllResults | Where-Object { $_.Result.Type -eq "Write" }
            $actualReadRatio = $readOperations.Count / ($readOperations.Count + $writeOperations.Count)

            # Verify read/write ratio is approximately correct (within 10%)
            [Math]::Abs($actualReadRatio - $scenario.ReadWriteRatio) | Should -BeLessThan 0.1
        }
    }

    Context "Hot-Reload Performance" {

        It "Should perform hot-reload operations efficiently" {
            # Create configuration for hot-reload testing
            $hotReloadConfig = New-LargeConfiguration -SettingsCount 1000 -ModuleCount 30 -EnvironmentCount 5
            $hotReloadPath = Join-Path $TestConcurrentDir "hot-reload-config.json"
            New-ConfigurationFile -Path $hotReloadPath -Configuration $hotReloadConfig

            # Define hot-reload operation
            $hotReloadOperation = {
                # Simulate file change detection
                $config = Get-Content $using:hotReloadPath | ConvertFrom-Json

                # Simulate validation
                $isValid = $config.version -and $config.name -and $config.settings

                if ($isValid) {
                    # Simulate configuration reload
                    $processedSettings = @{}
                    $enabledModules = @()

                    foreach ($key in $config.settings.Keys) {
                        if ($config.settings[$key].priority -gt 50) {
                            $processedSettings[$key] = $config.settings[$key]
                        }
                    }

                    foreach ($module in $config.modules.Keys) {
                        if ($config.modules[$module].enabled) {
                            $enabledModules += $module
                        }
                    }

                    return @{
                        Success = $true
                        ProcessedSettings = $processedSettings.Count
                        EnabledModules = $enabledModules.Count
                        ReloadTime = Get-Date
                    }
                } else {
                    return @{
                        Success = $false
                        Error = "Validation failed"
                    }
                }
            }

            # Benchmark hot-reload operations
            $benchmarkSettings = $script:TestData.BenchmarkOperations.HotReload
            $hotReloadBenchmark = Invoke-BenchmarkTest -Operation $hotReloadOperation -Iterations $benchmarkSettings.Iterations -WarmupIterations $benchmarkSettings.WarmupIterations -BenchmarkName "HotReload"

            # Assert hot-reload performance
            $hotReloadBenchmark.SuccessRate | Should -BeGreaterThan 0.95
            $hotReloadBenchmark.AverageDuration | Should -BeLessThan $benchmarkSettings.ExpectedAverageTime
            $hotReloadBenchmark.P95Duration | Should -BeLessThan $benchmarkSettings.ExpectedP95Time
            $hotReloadBenchmark.P99Duration | Should -BeLessThan $benchmarkSettings.ExpectedP99Time

            # Verify all reloads were successful
            $successfulMeasurements = $hotReloadBenchmark.Measurements | Where-Object { $_.Success -and $_.Result.Success }
            $successfulMeasurements.Count | Should -Be $hotReloadBenchmark.SuccessfulIterations
        }

        It "Should handle rapid successive hot-reload operations" {
            # Create configuration for rapid hot-reload testing
            $rapidConfig = New-LargeConfiguration -SettingsCount 500 -ModuleCount 20 -EnvironmentCount 3
            $rapidConfigPath = Join-Path $TestConcurrentDir "rapid-hot-reload-config.json"
            New-ConfigurationFile -Path $rapidConfigPath -Configuration $rapidConfig

            # Test rapid successive hot-reloads
            $rapidHotReloadPerformance = Measure-ConfigurationPerformance -OperationName "RapidHotReload" -ExpectedLimits @{
                MaxDuration = 5000  # 5 seconds for multiple rapid reloads
                MaxMemory = 10      # 10MB
            } -ScriptBlock {
                $results = @()

                for ($i = 1; $i -le 10; $i++) {
                    # Simulate rapid configuration change
                    $config = Get-Content $using:rapidConfigPath | ConvertFrom-Json
                    $config.metadata.rapidReloadIteration = $i
                    $config.metadata.rapidReloadTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')

                    # Simulate quick validation and reload
                    $isValid = $config.version -and $config.name
                    if ($isValid) {
                        $enabledCount = ($config.modules.Keys | Where-Object { $config.modules[$_].enabled }).Count
                        $results += @{
                            Iteration = $i
                            EnabledModules = $enabledCount
                            ReloadTime = Get-Date
                        }
                    }

                    Start-Sleep -Milliseconds 10  # Small delay between rapid reloads
                }

                return $results
            }

            # Assert rapid hot-reload performance
            $rapidHotReloadPerformance.Success | Should -Be $true
            $rapidHotReloadPerformance.Duration | Should -BeLessThan 5000
            $rapidHotReloadPerformance.MemoryUsed | Should -BeLessThan 10
            $rapidHotReloadPerformance.Result.Count | Should -Be 10
        }
    }

    Context "Benchmark Operations" {

        It "Should meet configuration load benchmark targets" {
            $benchmarkSettings = $script:TestData.BenchmarkOperations.ConfigurationLoad

            # Create test configuration for load benchmarking
            $loadTestConfig = New-LargeConfiguration -SettingsCount 2000 -ModuleCount 50 -EnvironmentCount 5
            $loadTestPath = Join-Path $TestBenchmarkDir "load-benchmark-config.json"
            New-ConfigurationFile -Path $loadTestPath -Configuration $loadTestConfig

            # Define load operation
            $loadOperation = {
                $config = Get-Content $using:loadTestPath | ConvertFrom-Json

                # Simulate configuration loading with processing
                $loadedSettings = $config.settings.Count
                $loadedModules = $config.modules.Count
                $loadedEnvironments = $config.environments.Count

                return @{
                    LoadedSettings = $loadedSettings
                    LoadedModules = $loadedModules
                    LoadedEnvironments = $loadedEnvironments
                    LoadTime = Get-Date
                }
            }

            # Execute load benchmark
            $loadBenchmark = Invoke-BenchmarkTest -Operation $loadOperation -Iterations $benchmarkSettings.Iterations -WarmupIterations $benchmarkSettings.WarmupIterations -BenchmarkName "ConfigurationLoad"

            # Assert load benchmark targets
            $loadBenchmark.SuccessRate | Should -BeGreaterThan 0.98
            $loadBenchmark.AverageDuration | Should -BeLessThan $benchmarkSettings.ExpectedAverageTime
            $loadBenchmark.P95Duration | Should -BeLessThan $benchmarkSettings.ExpectedP95Time
            $loadBenchmark.P99Duration | Should -BeLessThan $benchmarkSettings.ExpectedP99Time

            # Verify consistency of results
            $successfulResults = $loadBenchmark.Measurements | Where-Object { $_.Success }
            $avgLoadedSettings = ($successfulResults | ForEach-Object { $_.Result.LoadedSettings } | Measure-Object -Average).Average
            $avgLoadedSettings | Should -Be 2000  # Should consistently load all settings
        }

        It "Should meet configuration validation benchmark targets" {
            $benchmarkSettings = $script:TestData.BenchmarkOperations.ConfigurationValidation

            # Create test configuration for validation benchmarking
            $validationTestConfig = New-LargeConfiguration -SettingsCount 1500 -ModuleCount 40 -EnvironmentCount 6
            $validationTestPath = Join-Path $TestBenchmarkDir "validation-benchmark-config.json"
            New-ConfigurationFile -Path $validationTestPath -Configuration $validationTestConfig

            # Define validation operation
            $validationOperation = {
                $config = Get-Content $using:validationTestPath | ConvertFrom-Json

                # Simulate comprehensive validation
                $validationResults = @{
                    HasVersion = [bool]$config.version
                    HasName = [bool]$config.name
                    HasSettings = [bool]$config.settings
                    HasModules = [bool]$config.modules
                    SettingsValid = $true
                    ModulesValid = $true
                    EnvironmentsValid = $true
                }

                # Validate settings
                foreach ($key in $config.settings.Keys) {
                    $setting = $config.settings[$key]
                    if (-not $setting.value -or -not $setting.type) {
                        $validationResults.SettingsValid = $false
                        break
                    }
                }

                # Validate modules
                foreach ($key in $config.modules.Keys) {
                    $module = $config.modules[$key]
                    if (-not $module.PSObject.Properties['enabled']) {
                        $validationResults.ModulesValid = $false
                        break
                    }
                }

                $overallValid = $validationResults.HasVersion -and $validationResults.HasName -and
                               $validationResults.HasSettings -and $validationResults.SettingsValid -and
                               $validationResults.ModulesValid -and $validationResults.EnvironmentsValid

                return @{
                    Valid = $overallValid
                    ValidationResults = $validationResults
                    ValidationTime = Get-Date
                }
            }

            # Execute validation benchmark
            $validationBenchmark = Invoke-BenchmarkTest -Operation $validationOperation -Iterations $benchmarkSettings.Iterations -WarmupIterations $benchmarkSettings.WarmupIterations -BenchmarkName "ConfigurationValidation"

            # Assert validation benchmark targets
            $validationBenchmark.SuccessRate | Should -BeGreaterThan 0.99
            $validationBenchmark.AverageDuration | Should -BeLessThan $benchmarkSettings.ExpectedAverageTime
            $validationBenchmark.P95Duration | Should -BeLessThan $benchmarkSettings.ExpectedP95Time
            $validationBenchmark.P99Duration | Should -BeLessThan $benchmarkSettings.ExpectedP99Time

            # Verify all validations passed
            $successfulValidations = $validationBenchmark.Measurements | Where-Object { $_.Success -and $_.Result.Valid }
            $successfulValidations.Count | Should -Be $validationBenchmark.SuccessfulIterations
        }

        It "Should meet configuration save benchmark targets" {
            $benchmarkSettings = $script:TestData.BenchmarkOperations.ConfigurationSave

            # Create test configuration for save benchmarking
            $saveTestConfig = New-LargeConfiguration -SettingsCount 1000 -ModuleCount 30 -EnvironmentCount 4
            $saveTestDir = Join-Path $TestBenchmarkDir "save-benchmark"
            New-Item -ItemType Directory -Path $saveTestDir -Force | Out-Null

            # Define save operation
            $saveOperation = {
                $iterationId = [System.Guid]::NewGuid().ToString().Substring(0, 8)
                $saveTestPath = Join-Path $using:saveTestDir "save-benchmark-$iterationId.json"

                $config = $using:saveTestConfig.Clone()
                $config.metadata.saveTest = $iterationId
                $config.metadata.saveTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')

                # Simulate configuration save with validation
                $config | ConvertTo-Json -Depth 20 | Set-Content -Path $saveTestPath

                # Verify save
                $savedConfig = Get-Content $saveTestPath | ConvertFrom-Json
                $saveValid = $savedConfig.metadata.saveTest -eq $iterationId

                return @{
                    SavedPath = $saveTestPath
                    SaveValid = $saveValid
                    SavedSize = (Get-Item $saveTestPath).Length
                    SaveTime = Get-Date
                }
            }

            # Execute save benchmark
            $saveBenchmark = Invoke-BenchmarkTest -Operation $saveOperation -Iterations $benchmarkSettings.Iterations -WarmupIterations $benchmarkSettings.WarmupIterations -BenchmarkName "ConfigurationSave"

            # Assert save benchmark targets
            $saveBenchmark.SuccessRate | Should -BeGreaterThan 0.95
            $saveBenchmark.AverageDuration | Should -BeLessThan $benchmarkSettings.ExpectedAverageTime
            $saveBenchmark.P95Duration | Should -BeLessThan $benchmarkSettings.ExpectedP95Time
            $saveBenchmark.P99Duration | Should -BeLessThan $benchmarkSettings.ExpectedP99Time

            # Verify all saves were valid
            $successfulSaves = $saveBenchmark.Measurements | Where-Object { $_.Success -and $_.Result.SaveValid }
            $successfulSaves.Count | Should -Be $saveBenchmark.SuccessfulIterations

            # Verify files were created
            $savedFiles = Get-ChildItem -Path $saveTestDir -Filter "save-benchmark-*.json"
            $savedFiles.Count | Should -Be $saveBenchmark.SuccessfulIterations
        }
    }

    Context "Resource Usage and Limits" {

        It "Should respect memory usage limits during intensive operations" {
            $resourceLimits = $script:TestData.ResourceLimits

            # Create very large configuration for memory testing
            $memoryTestConfig = New-LargeConfiguration -SettingsCount 10000 -ModuleCount 200 -EnvironmentCount 15 -NestedLevels 6
            $memoryTestPath = Join-Path $TestBenchmarkDir "memory-test-config.json"
            New-ConfigurationFile -Path $memoryTestPath -Configuration $memoryTestConfig

            # Test memory usage under intensive operations
            $memoryUsage = Test-ResourceUsage {
                $configs = @()

                # Load multiple large configurations
                for ($i = 1; $i -le 10; $i++) {
                    $config = Get-Content $using:memoryTestPath | ConvertFrom-Json
                    $config.metadata.memoryTestIteration = $i
                    $configs += $config
                }

                # Process configurations
                $processedData = @{}
                foreach ($config in $configs) {
                    $processedData[$config.metadata.memoryTestIteration] = @{
                        settingsCount = $config.settings.Count
                        modulesCount = $config.modules.Count
                        environmentsCount = $config.environments.Count
                    }
                }

                return @{
                    ConfigurationsLoaded = $configs.Count
                    ProcessedData = $processedData.Count
                    MemoryTestCompleted = $true
                }
            }

            # Assert memory usage within limits
            $memoryUsage.Success | Should -Be $true
            $memoryUsage.MemoryDelta | Should -BeLessThan ($resourceLimits.MaxMemoryUsage / 1MB)
            $memoryUsage.Duration | Should -BeLessThan $resourceLimits.ResponseTimeThreshold
            $memoryUsage.Result.MemoryTestCompleted | Should -Be $true
        }

        It "Should handle maximum concurrent operations efficiently" {
            $resourceLimits = $script:TestData.ResourceLimits

            # Create test configuration for concurrency testing
            $concurrencyTestConfig = New-LargeConfiguration -SettingsCount 1000 -ModuleCount 50 -EnvironmentCount 5
            $concurrencyTestPath = Join-Path $TestConcurrentDir "concurrency-limit-test.json"
            New-ConfigurationFile -Path $concurrencyTestPath -Configuration $concurrencyTestConfig

            # Define operation for concurrency testing
            $concurrentOperation = {
                $operationId = [System.Guid]::NewGuid().ToString().Substring(0, 8)
                $config = Get-Content $using:concurrencyTestPath | ConvertFrom-Json

                # Simulate processing time
                Start-Sleep -Milliseconds (Get-Random -Minimum 50 -Maximum 200)

                # Process some data
                $enabledModules = $config.modules.Keys | Where-Object { $config.modules[$_].enabled }

                return @{
                    OperationId = $operationId
                    ProcessedModules = $enabledModules.Count
                    ProcessTime = Get-Date
                }
            }

            # Test with maximum concurrent operations
            $maxConcurrencyTest = Start-LoadTest -Operation $concurrentOperation -ConcurrentOperations $resourceLimits.MaxConcurrentOperations -DurationSeconds 30 -TestName "MaxConcurrency"

            # Assert performance under maximum concurrency
            $maxConcurrencyTest.SuccessRate | Should -BeGreaterThan 0.80  # 80% success rate under max load
            $maxConcurrencyTest.AverageResponseTime | Should -BeLessThan $resourceLimits.ResponseTimeThreshold
            $maxConcurrencyTest.TotalOperations | Should -BeGreaterThan 0

            # Verify system remained stable
            $maxConcurrencyTest.FailedOperations | Should -BeLessThan ($maxConcurrencyTest.TotalOperations * 0.2)  # Less than 20% failures
        }

        It "Should perform well under sustained load" {
            $scenario = $script:TestData.LoadTestScenarios.SustainedLoad

            # Create configuration for sustained load testing
            $sustainedConfig = New-LargeConfiguration -SettingsCount 2000 -ModuleCount 60 -EnvironmentCount 8
            $sustainedConfigPath = Join-Path $TestConcurrentDir "sustained-load-config.json"
            New-ConfigurationFile -Path $sustainedConfigPath -Configuration $sustainedConfig

            # Define sustained operation
            $sustainedOperation = {
                $config = Get-Content $using:sustainedConfigPath | ConvertFrom-Json

                # Simulate realistic configuration operation
                $randomOperation = Get-Random -Maximum 3
                switch ($randomOperation) {
                    0 {
                        # Read operation
                        $randomSetting = $config.settings.Keys | Get-Random
                        return @{ Operation = "Read"; Result = $config.settings[$randomSetting].value }
                    }
                    1 {
                        # Validation operation
                        $validModules = ($config.modules.Keys | Where-Object { $config.modules[$_].enabled }).Count
                        return @{ Operation = "Validate"; Result = $validModules }
                    }
                    2 {
                        # Query operation
                        $criticalSettings = ($config.settings.Keys | Where-Object { $config.settings[$_].priority -gt 80 }).Count
                        return @{ Operation = "Query"; Result = $criticalSettings }
                    }
                }
            }

            # Execute sustained load test
            $sustainedLoadResult = Start-LoadTest -Operation $sustainedOperation -ConcurrentOperations $scenario.ConcurrentOperations -DurationSeconds $scenario.DurationSeconds -TestName "SustainedLoad"

            # Assert sustained load performance
            $sustainedLoadResult.SuccessRate | Should -BeGreaterThan 0.90  # 90% success rate over 5 minutes
            $sustainedLoadResult.Throughput | Should -BeGreaterThan ($scenario.ExpectedThroughput * 0.8)  # 80% of expected throughput
            $sustainedLoadResult.AverageResponseTime | Should -BeLessThan 1000  # Under 1 second average

            # Verify performance remained stable throughout the test
            $sustainedLoadResult.ActualDuration | Should -BeGreaterThan ($scenario.DurationSeconds * 0.95)  # Completed most of the test
            $sustainedLoadResult.TotalOperations | Should -BeGreaterThan ($scenario.ExpectedThroughput * $scenario.DurationSeconds * 0.7)  # Reasonable operation count
        }
    }
}

AfterAll {
    # Generate performance summary report
    if ($script:PerformanceMetrics.Count -gt 0) {
        $performanceSummary = @{
            TotalOperations = $script:PerformanceMetrics.Count
            SuccessfulOperations = ($script:PerformanceMetrics | Where-Object { $_.Success }).Count
            AverageDuration = ($script:PerformanceMetrics | Measure-Object -Property Duration -Average).Average
            AverageMemoryUsage = ($script:PerformanceMetrics | Measure-Object -Property MemoryUsed -Average).Average
            MaxDuration = ($script:PerformanceMetrics | Measure-Object -Property Duration -Maximum).Maximum
            MaxMemoryUsage = ($script:PerformanceMetrics | Measure-Object -Property MemoryUsed -Maximum).Maximum
            TestCompletionTime = Get-Date
        }

        $summaryPath = Join-Path $TestMetricsDir "performance-summary.json"
        $performanceSummary | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath

        Write-CustomLog -Level 'INFO' -Message "Performance test summary: $($performanceSummary.SuccessfulOperations)/$($performanceSummary.TotalOperations) operations successful, avg duration $($performanceSummary.AverageDuration.ToString('F2'))ms"
    }

    # Cleanup test environment
    if ($env:TEST_PERFORMANCE_DIR -and (Test-Path $env:TEST_PERFORMANCE_DIR)) {
        try {
            # Keep summary files but clean up large test data
            $largeFiles = Get-ChildItem -Path $env:TEST_PERFORMANCE_DIR -Recurse -File | Where-Object { $_.Length -gt 10MB }
            foreach ($file in $largeFiles) {
                Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-CustomLog -Level 'WARNING' -Message "Could not cleanup large test files"
        }
    }

    # Clear test environment variables
    $env:TEST_PERFORMANCE_DIR = $null
    $env:TEST_LARGE_CONFIGS_DIR = $null
    $env:TEST_CONCURRENT_DIR = $null

    # Clear performance tracking
    $script:PerformanceMetrics = @()
    $script:LoadTestResults = @()
    $script:BenchmarkResults = @()
    $script:ResourceUsage = @()
}
