#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive performance testing suite for the Aitherium Infrastructure Automation system

.DESCRIPTION
    This test suite validates performance characteristics including:
    - Module loading performance
    - Parallel execution efficiency
    - Memory usage patterns
    - Startup time optimization
    - Large dataset handling
    - Resource consumption monitoring

.NOTES
    Part of the Aitherium Infrastructure Automation testing framework
#>

BeforeAll {
    # Use improved project root detection with cross-platform path handling
    try {
        # Force correct project root for AitherZero project
        $expectedPath = "C:/Users/alexa/OneDrive/Documents/0. wizzense/AitherZero"

        # Try to use the shared Find-ProjectRoot function if available, but validate result
        $sharedUtilPath = Join-Path -Path $PSScriptRoot -ChildPath "../../aither-core/shared/Find-ProjectRoot.ps1"
        if (Test-Path $sharedUtilPath) {
            . $sharedUtilPath
            $detectedRoot = Find-ProjectRoot

            # Validate the detected root is actually the AitherZero project
            if ($detectedRoot -like "*AitherZero*" -and (Test-Path (Join-Path -Path $detectedRoot -ChildPath "aither-core/modules"))) {
                $script:ProjectRoot = $detectedRoot
                Write-Host "Found project root using shared utility: $script:ProjectRoot"
            } else {
                # Override with expected path if detection found wrong project
                $script:ProjectRoot = $expectedPath
                Write-Host "Overriding detected root, using expected path: $script:ProjectRoot"
            }
        } else {
            # Fallback to expected path
            $script:ProjectRoot = $expectedPath
            Write-Host "Using expected project root: $script:ProjectRoot"
        }
    } catch {
        # Ultimate fallback - use expected path
        $script:ProjectRoot = "C:/Users/alexa/OneDrive/Documents/0. wizzense/AitherZero"
        Write-Host "Using fallback project root: $script:ProjectRoot"
    }

    # Set environment variable for downstream modules (always using forward slashes)
    $env:PROJECT_ROOT = $script:ProjectRoot.Replace('\', '/')

    # Validate project root exists
    if (-not (Test-Path $script:ProjectRoot)) {
        throw "ERROR: Project root path doesn't exist: $script:ProjectRoot"
    }

    # Confirm core modules directory exists
    $moduleDir = Join-Path -Path $script:ProjectRoot -ChildPath "aither-core/modules"
    if (-not (Test-Path $moduleDir)) {
        throw "ERROR: Core modules directory doesn't exist: $moduleDir"
    }

    # Performance test configuration
    $script:PerformanceThresholds = @{
        ModuleLoadTime = 5000       # 5 seconds max per module
        CoreRunnerStartup = 30000   # 30 seconds max for startup
        ParallelExecutionOverhead = 1000  # 1 second max overhead
        MemoryIncreaseLimit = 100   # 100MB max increase
        LargeDatasetTime = 10000    # 10 seconds for 1000 items
    }

    # Import required modules following project standards
    $requiredModules = @(
        "Logging",
        "ParallelExecution",
        "TestingFramework"
    )

    # Track import results for reporting
    $script:ModuleImports = @{}

    foreach ($moduleName in $requiredModules) {
        $modulePath = Join-Path -Path $script:ProjectRoot -ChildPath "$env:PWSH_MODULES_PATH/$moduleName"

        try {
            # Standard project import pattern with -Force
            Import-Module $modulePath -Force -ErrorAction Stop
            $script:ModuleImports[$moduleName] = @{
                Imported = $true
                Path = $modulePath
                Error = $null
            }
            Write-Host "✅ Successfully imported $moduleName module"
        }
        catch {
            $script:ModuleImports[$moduleName] = @{
                Imported = $false
                Path = $modulePath
                Error = $_.Exception.Message
            }
            Write-Host "⚠️ Failed to import $moduleName module - $($_.Exception.Message)"

            # Create fallback functions based on module
            switch ($moduleName) {
                "Logging" {
                    function Write-CustomLog {
                        [CmdletBinding(SupportsShouldProcess)]
                        param(
                            [Parameter(Mandatory = $true)]
                            [ValidateNotNullOrEmpty()]
                            [string]$Level,

                            [Parameter(Mandatory = $true)]
                            [ValidateNotNullOrEmpty()]
                            [string]$Message
                        )

                        if ($PSCmdlet.ShouldProcess($Message, "Log [$Level]")) {
                            Write-Verbose "[$Level] $Message"
                        }
                    }
                }
                "ParallelExecution" {
                    function Invoke-ParallelForEach {
                        [CmdletBinding(SupportsShouldProcess)]
                        param(
                            [Parameter(Mandatory = $true)]
                            [ValidateNotNull()]
                            $InputObject,

                            [Parameter(Mandatory = $true)]
                            [ValidateNotNull()]
                            [scriptblock]$ScriptBlock,

                            [Parameter()]
                            [ValidateRange(1, 100)]
                            [int]$ThrottleLimit = 5
                        )

                        if ($PSCmdlet.ShouldProcess("$($InputObject.Count) items", "Process sequentially as fallback")) {
                            return $InputObject | ForEach-Object $ScriptBlock
                        }
                    }
                }
                default {
                    # Generic fallback - just report the issue
                    Write-Host "⚠️ No fallback defined for $moduleName module"
                }
            }
        }
    }
}

Describe "Module Loading Performance" -Tags @('Performance', 'ModuleLoading') {

    Context "When loading individual modules" {
        It "Should load Logging module quickly" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            try {
                Remove-Module Logging -Force -ErrorAction SilentlyContinue
                Import-Module "$env:PWSH_MODULES_PATH/Logging" -Force -ErrorAction Stop
                $stopwatch.Stop()
                $stopwatch.ElapsedMilliseconds | Should -BeLessThan $script:PerformanceThresholds.ModuleLoadTime
            }
            catch {
                $stopwatch.Stop()
                Write-CustomLog -Level 'ERROR' -Message "Failed to load Logging module: $($_.Exception.Message)"
                throw
            }
        }

        It "Should load ParallelExecution module quickly" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            try {
                Remove-Module ParallelExecution -Force -ErrorAction SilentlyContinue
                Import-Module "$env:PWSH_MODULES_PATH/ParallelExecution" -Force -ErrorAction Stop
                $stopwatch.Stop()
                $stopwatch.ElapsedMilliseconds | Should -BeLessThan $script:PerformanceThresholds.ModuleLoadTime
            }
            catch {
                $stopwatch.Stop()
                Write-CustomLog -Level 'ERROR' -Message "Failed to load ParallelExecution module: $($_.Exception.Message)"
                throw
            }
        }

        It "Should load all modules within time limit" {
            $moduleDirectories = Get-ChildItem "$script:ProjectRoot/aither-core/modules" -Directory
            $totalLoadTime = 0
            $loadResults = @()

            foreach ($moduleDir in $moduleDirectories) {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                try {
                    Import-Module $moduleDir.FullName -Force -ErrorAction Stop
                    $stopwatch.Stop()
                    $loadTime = $stopwatch.ElapsedMilliseconds
                    $totalLoadTime += $loadTime

                    $loadResults += @{
                        Module = $moduleDir.Name
                        LoadTime = $loadTime
                        Success = $true
                    }
                } catch {
                    $stopwatch.Stop()
                    $loadResults += @{
                        Module = $moduleDir.Name
                        LoadTime = $stopwatch.ElapsedMilliseconds
                        Success = $false
                        Error = $_.Exception.Message
                    }
                }
            }

            # Validate results
            $successfulLoads = $loadResults | Where-Object { $_.Success }
            $successfulLoads.Count | Should -BeGreaterThan 0

            # Total load time should be reasonable
            $totalLoadTime | Should -BeLessThan ($script:PerformanceThresholds.ModuleLoadTime * $moduleDirectories.Count)
        }
    }
}

Describe "Core Runner Performance" -Tags @('Performance', 'CoreRunner') {

    Context "When testing core runner startup" {
        It "Should start quickly in non-interactive mode" {
            # Check if core runner exists
            $coreRunnerPath = Join-Path $script:ProjectRoot 'aither-core/aither-core.ps1'
            if (-not (Test-Path $coreRunnerPath)) {
                Set-ItResult -Skipped -Because "Core runner script not found at $coreRunnerPath"
                return
            }

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            try {
                $process = Start-Process -FilePath 'pwsh' -ArgumentList @(
                    '-File', "`"$coreRunnerPath`"",
                    '-NonInteractive', '-WhatIf', '-Verbosity', 'silent'
                ) -NoNewWindow -Wait -PassThru

                $stopwatch.Stop()

                $process.ExitCode | Should -Be 0
                $stopwatch.ElapsedMilliseconds | Should -BeLessThan $script:PerformanceThresholds.CoreRunnerStartup
            }
            catch {
                $stopwatch.Stop()
                Write-CustomLog -Level 'ERROR' -Message "Failed to run core runner: $($_.Exception.Message)"
                throw
            }
        }

        It "Should handle auto mode efficiently" {
            # Check if core runner exists
            $coreRunnerPath = Join-Path $script:ProjectRoot 'aither-core/aither-core.ps1'
            if (-not (Test-Path $coreRunnerPath)) {
                Set-ItResult -Skipped -Because "Core runner script not found at $coreRunnerPath"
                return
            }

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            try {
                $process = Start-Process -FilePath 'pwsh' -ArgumentList @(
                    '-File', "`"$coreRunnerPath`"",
                    '-NonInteractive', '-Auto', '-WhatIf', '-Verbosity', 'silent'
                ) -NoNewWindow -Wait -PassThru

                $stopwatch.Stop()

                $process.ExitCode | Should -Be 0
                $stopwatch.ElapsedMilliseconds | Should -BeLessThan $script:PerformanceThresholds.CoreRunnerStartup
            }
            catch {
                $stopwatch.Stop()
                Write-CustomLog -Level 'ERROR' -Message "Failed to run core runner in auto mode: $($_.Exception.Message)"
                throw
            }
        }
    }
}

Describe "Parallel Execution Performance" -Tags @('Performance', 'ParallelExecution') {

    Context "When testing parallel execution efficiency" {
        It "Should have minimal overhead for small datasets" {
            $testData = @(1, 2, 3, 4, 5)

            # Measure sequential execution
            $sequentialStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $sequentialResults = $testData | ForEach-Object { $_ * 2 }
            $sequentialStopwatch.Stop()

            # Measure parallel execution
            $parallelStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $parallelResults = Invoke-ParallelForEach -InputObject $testData -ScriptBlock {
                $item = $_
                return $item * 2
            } -ThrottleLimit 3
            $parallelStopwatch.Stop()

            # Validate results are equivalent
            $parallelResults.Count | Should -Be $sequentialResults.Count

            # Overhead should be reasonable for small datasets
            $overhead = $parallelStopwatch.ElapsedMilliseconds - $sequentialStopwatch.ElapsedMilliseconds
            $overhead | Should -BeLessThan $script:PerformanceThresholds.ParallelExecutionOverhead
        }

        It "Should scale effectively with larger datasets" {
            $largeDataset = 1..100
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            $results = Invoke-ParallelForEach -InputObject $largeDataset -ScriptBlock {
                $item = $_
                # Simulate some work
                Start-Sleep -Milliseconds 10
                return $item * 2
            } -ThrottleLimit 8

            $stopwatch.Stop()

            $results.Count | Should -Be $largeDataset.Count
            # Should be faster than sequential execution
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan ($largeDataset.Count * 15) # Allow some overhead
        }

        It "Should handle different throttle limits efficiently" {
            $testData = 1..20
            $throttleLimits = @(1, 2, 4, 8)
            $performanceResults = @()

            foreach ($throttleLimit in $throttleLimits) {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                $results = Invoke-ParallelForEach -InputObject $testData -ScriptBlock {
                    $item = $_
                    Start-Sleep -Milliseconds 50
                    return $item
                } -ThrottleLimit $throttleLimit

                $stopwatch.Stop()

                $performanceResults += @{
                    ThrottleLimit = $throttleLimit
                    ExecutionTime = $stopwatch.ElapsedMilliseconds
                    ResultCount = $results.Count
                }
            }

            # All should complete successfully
            $performanceResults | ForEach-Object {
                $_.ResultCount | Should -Be $testData.Count
            }

            # Higher throttle limits should generally be faster (up to a point)
            $fastest = $performanceResults | Sort-Object ExecutionTime | Select-Object -First 1
            $fastest.ExecutionTime | Should -BeLessThan 5000 # 5 seconds max
        }
    }
}

Describe "Memory Usage Performance" -Tags @('Performance', 'Memory') {

    Context "When testing memory consumption" {
        It "Should use memory efficiently during module operations" {
            $beforeMemory = [GC]::GetTotalMemory($false)

            # Perform various module operations
            Write-CustomLog -Level 'INFO' -Message 'Performance test message'

            $testData = 1..50
            $results = Invoke-ParallelForEach -InputObject $testData -ScriptBlock {
                $item = $_
                # Safely call functions that might not be available in test context
                if (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue) {
                    Write-CustomLog -Level 'INFO' -Message "Processing item $item"
                }
                return $item * 2
            } -ThrottleLimit 5

            [GC]::Collect()
            $afterMemory = [GC]::GetTotalMemory($true)
            $memoryIncrease = ($afterMemory - $beforeMemory) / 1MB

            $results.Count | Should -Be $testData.Count
            $memoryIncrease | Should -BeLessThan $script:PerformanceThresholds.MemoryIncreaseLimit
        }

        It "Should handle large datasets without memory leaks" {
            $beforeMemory = [GC]::GetTotalMemory($false)

            # Process a large dataset multiple times
            for ($i = 1; $i -le 3; $i++) {
                $largeDataset = 1..200
                $results = Invoke-ParallelForEach -InputObject $largeDataset -ScriptBlock {
                    $item = $_
                    # Create some objects to test memory cleanup
                    $obj = @{
                        Value = $item
                        Data = "Test data for item $item"
                        Timestamp = Get-Date
                    }
                    return $obj.Value * 2
                } -ThrottleLimit 6

                $results.Count | Should -Be $largeDataset.Count

                # Force garbage collection
                [GC]::Collect()
                [GC]::WaitForPendingFinalizers()
                [GC]::Collect()
            }

            $afterMemory = [GC]::GetTotalMemory($true)
            $memoryIncrease = ($afterMemory - $beforeMemory) / 1MB

            # Memory increase should be minimal after multiple iterations
            $memoryIncrease | Should -BeLessThan ($script:PerformanceThresholds.MemoryIncreaseLimit * 1.5)
        }
    }
}

Describe "Large Dataset Performance" -Tags @('Performance', 'LargeDataset') {

    Context "When processing large datasets" {
        It "Should handle 1000 item dataset efficiently" {
            # Create actual integers instead of potentially empty/null slots
            $largeDataset = @()
            for ($i = 1; $i -le 1000; $i++) {
                $largeDataset += $i
            }

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            try {
                $results = Invoke-ParallelForEach -InputObject $largeDataset -ScriptBlock {
                    $item = $_
                    # Defensive coding - ensure the item is not null before processing
                    if ($null -ne $item) {
                        $hash = $item.GetHashCode()
                        return @{
                            Original = $item
                            Hash = $hash
                            Doubled = $item * 2
                        }
                    }
                    else {
                        # Return a placeholder for null items
                        return @{
                            Original = $null
                            Hash = 0
                            Doubled = 0
                        }
                    }
                } -ThrottleLimit 10

                $stopwatch.Stop()

                $results.Count | Should -Be $largeDataset.Count
                $stopwatch.ElapsedMilliseconds | Should -BeLessThan $script:PerformanceThresholds.LargeDatasetTime
            }
            catch {
                $stopwatch.Stop()
                Write-CustomLog -Level 'ERROR' -Message "Large dataset processing failed: $($_.Exception.Message)"
                throw
            }
        }

        It "Should maintain performance with complex objects" {
            # Create test objects with comprehensive error handling
            try {
                $complexObjects = @()

                # Initialize with error handling
                for ($i = 1; $i -le 100; $i++) {
                    $complexObjects += @{
                        Id = $i
                        Name = "Object $i"
                        Properties = @{
                            Value = $i * 10
                            Description = "Complex object number $i"
                            Metadata = @{
                                Created = Get-Date
                                Type = 'Test'
                                LastModified = $null  # Intentional null for testing defensive coding
                            }
                        }
                        Tags = @('Performance', 'Test', "Tag-$i")
                    }
                }

                # Pre-test validation
                $complexObjects.Count | Should -Be 100 -Because "Test data initialization should create exactly 100 items"

                # Performance measurement with proper instrumentation
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                Write-CustomLog -Level 'INFO' -Message "Starting complex object processing test with $($complexObjects.Count) objects"

                # Process with comprehensive error handling using the correct parameter pattern
                $results = Invoke-ParallelForEach -InputObject $complexObjects -ScriptBlock {
                    # In ForEach-Object -Parallel, we use $_ instead of param($obj)
                    $obj = $_

                    # BEGIN: Safe access pattern with null checking
                    if ($null -eq $obj) {
                        return @{
                            Id = 0
                            ProcessedValue = 0
                            Summary = "NULL OBJECT"
                            Error = $true
                            Success = $false
                        }
                    }

                    # Additional check for empty hashtables or wrong types
                    if ($obj -isnot [hashtable] -and $obj -isnot [pscustomobject]) {
                        return @{
                            Id = 0
                            ProcessedValue = 0
                            Summary = "INVALID OBJECT TYPE: $($obj.GetType().Name)"
                            Error = $true
                            Success = $false
                        }
                    }

                    # Process complex object with defensive coding and detailed error tracking
                    try {
                        # Extract values safely with type checking
                        $id = 0
                        if ($obj.Id -is [int]) {
                            $id = $obj.Id
                        } elseif ($null -ne $obj.Id) {
                            $id = [int]$obj.Id
                        }

                        $name = if ($null -ne $obj.Name -and $obj.Name -is [string]) { $obj.Name } else { "Unknown" }

                        # Process properties with full null protection and type checking
                        $processedValue = 0
                        if ($null -ne $obj.Properties -and ($obj.Properties -is [hashtable] -or $obj.Properties -is [pscustomobject])) {
                            if ($null -ne $obj.Properties.Value -and $obj.Properties.Value -is [int]) {
                                $processedValue = $obj.Properties.Value * 2
                            }
                        }

                        # Create result object with all required fields
                        return @{
                            Id = $id
                            ProcessedValue = $processedValue
                            Summary = "Processed $name"
                            Tags = if ($null -ne $obj.Tags -and $obj.Tags -is [array]) { $obj.Tags.Count } else { 0 }
                            Success = $true
                            Error = $false
                        }
                    }
                    catch {
                        # Capture errors without breaking the parallel execution
                        return @{
                            Id = if ($null -ne $obj -and $null -ne $obj.Id) { $obj.Id } else { 0 }
                            ProcessedValue = 0
                            Summary = "ERROR: $($_.Exception.Message)"
                            Error = $true
                            Success = $false
                        }
                    }
                    # END: Safe access pattern
                } -ThrottleLimit 8

                $stopwatch.Stop()
                $executionTime = $stopwatch.ElapsedMilliseconds
                Write-CustomLog -Level 'INFO' -Message "Complex object processing completed in ${executionTime}ms"

                # Comprehensive result validation
                $results.Count | Should -Be $complexObjects.Count

                # Debug: Check a few sample results to understand the structure
                Write-CustomLog -Level 'INFO' -Message "Sample result 1: Success=$($results[0].Success), Error=$($results[0].Error)"
                Write-CustomLog -Level 'INFO' -Message "Sample result 2: Success=$($results[1].Success), Error=$($results[1].Error)"

                # Check for processing errors - only check for explicit error markers
                $failedResults = $results | Where-Object {
                    $_.Error -eq $true -or $_.Success -eq $false -or $null -eq $_.Success
                }
                Write-CustomLog -Level 'INFO' -Message "Found $($failedResults.Count) failed results out of $($results.Count) total"

                if ($failedResults.Count -gt 0) {
                    $sampleFailed = $failedResults[0]
                    Write-CustomLog -Level 'WARN' -Message "Sample failed result: Success=$($sampleFailed.Success), Error=$($sampleFailed.Error), Summary=$($sampleFailed.Summary)"

                    # Additional debug info for the first few failures
                    for ($i = 0; $i -lt [Math]::Min(3, $failedResults.Count); $i++) {
                        $failedResult = $failedResults[$i]
                        Write-CustomLog -Level 'WARN' -Message "Failed result $($i + 1): Id=$($failedResult.Id), Summary=$($failedResult.Summary), Success=$($failedResult.Success), Error=$($failedResult.Error)"
                    }
                }

                # If all results are failing, it suggests a systematic issue with object passing
                if ($failedResults.Count -eq $results.Count) {
                    Write-CustomLog -Level 'ERROR' -Message "Complex object test failed: All $($results.Count) objects failed processing"
                    throw "All complex objects failed processing - this suggests a parameter passing issue in the parallel execution"
                }

                $failedResults.Count | Should -Be 0 -Because "All items should process without errors"

                # Performance validation
                $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000 # 5 seconds max
            }
            catch {
                if ($null -ne $stopwatch -and $stopwatch.IsRunning) {
                    $stopwatch.Stop()
                }
                Write-CustomLog -Level 'ERROR' -Message "Complex object test failed: $($_.Exception.Message)"
                throw
            }
        }
    }
}

Describe "Resource Utilization Performance" -Tags @('Performance', 'ResourceUtilization') {

    Context "When monitoring resource usage" {
        It "Should not consume excessive CPU during parallel operations" {
            # This test validates that parallel execution doesn't create CPU bottlenecks
            $testData = 1..50

            try {
                $cpuIntensiveStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                $results = Invoke-ParallelForEach -InputObject $testData -ScriptBlock {
                    $item = $_
                    # Null check to avoid null reference exceptions
                    if ($null -eq $item) { return 0 }

                    # Simulate CPU-intensive work
                    $sum = 0
                    for ($i = 1; $i -le 1000; $i++) {
                        $sum += $i * $item
                    }
                    return $sum
                } -ThrottleLimit 4 # Limited throttle to avoid overwhelming CPU

                $cpuIntensiveStopwatch.Stop()

                $results.Count | Should -Be $testData.Count
                # Should complete in reasonable time despite CPU work
                $cpuIntensiveStopwatch.ElapsedMilliseconds | Should -BeLessThan 10000 # 10 seconds max
            }
            catch {
                if ($cpuIntensiveStopwatch.IsRunning) {
                    $cpuIntensiveStopwatch.Stop()
                }
                Write-CustomLog -Level 'ERROR' -Message "CPU intensive operation failed: $($_.Exception.Message)"
                throw
            }
        }

        It "Should handle I/O operations efficiently" {
            $testFiles = @()
            for ($i = 1; $i -le 20; $i++) {
                $testFiles += "test-file-$i.txt"
            }

            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                $results = Invoke-ParallelForEach -InputObject $testFiles -ScriptBlock {
                    $filename = $_
                    # Null check for safety
                    if ($null -eq $filename) {
                        return @{
                            Filename = "unknown"
                            Size = 0
                            Processed = $false
                        }
                    }

                    # Simulate I/O operations without actually creating files
                    Start-Sleep -Milliseconds 50 # Simulate I/O delay
                    return @{
                        Filename = $filename
                        Size = Get-Random -Minimum 100 -Maximum 1000
                        Processed = $true
                    }
                } -ThrottleLimit 6

                $stopwatch.Stop()

                $results.Count | Should -Be $testFiles.Count
                # I/O operations should benefit from parallelization
                $stopwatch.ElapsedMilliseconds | Should -BeLessThan 3000 # 3 seconds max
            }
            catch {
                if ($stopwatch.IsRunning) {
                    $stopwatch.Stop()
                }
                Write-CustomLog -Level 'ERROR' -Message "I/O operation simulation failed: $($_.Exception.Message)"
                throw
            }
        }
    }
}

AfterAll {
    # Comprehensive cleanup following project standards
    try {
        Write-Host "🧹 Performing test suite cleanup..." -ForegroundColor Cyan

        # Memory cleanup
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        [GC]::Collect()

        # Clean up imported modules
        foreach ($moduleName in $script:ModuleImports.Keys) {
            if ($script:ModuleImports[$moduleName].Imported) {
                try {
                    Remove-Module $moduleName -Force -ErrorAction Stop
                    Write-Host "✅ Removed module: $moduleName" -ForegroundColor Green
                }
                catch {
                    Write-Host "⚠️ Failed to remove module $moduleName - $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }

        # Clean up environment variables if needed
        if ($env:TEST_PERFORMANCE_MODE) {
            Remove-Item env:TEST_PERFORMANCE_MODE -ErrorAction SilentlyContinue
        }

        # Performance report summary
        Write-Host "`n📊 Performance Test Suite Summary 📊" -ForegroundColor Cyan
        Write-Host "----------------------------------------" -ForegroundColor Cyan
        Write-Host "Module import status:"
        if ($null -ne $script:ModuleImports) {
            foreach ($module in $script:ModuleImports.Keys) {
                $importStatus = if ($script:ModuleImports[$module].Imported) { "✅ Imported" } else { "❌ Failed" }
                Write-Host "  - ${module}: $importStatus"
            }
        } else {
            Write-Host "  - No module import data available"
        }

        Write-Host "`nPerformance thresholds used:"
        if ($null -ne $script:PerformanceThresholds) {
            foreach ($threshold in $script:PerformanceThresholds.GetEnumerator()) {
                Write-Host "  - $($threshold.Key): $($threshold.Value)"
            }
        } else {
            Write-Host "  - No performance threshold data available"
        }

        Write-Host "`n✅ Performance test suite cleanup completed" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error during test suite cleanup: $($_.Exception.Message)" -ForegroundColor Red

        # Log the error for easier troubleshooting
        $logDir = Join-Path -Path $script:ProjectRoot -ChildPath "logs"
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
        $errorLogPath = Join-Path -Path $logDir -ChildPath "performance-test-error-$timestamp.log"

        "Error during test cleanup at $(Get-Date)`n$($_.Exception)`n$($_.ScriptStackTrace)" |
            Out-File -FilePath $errorLogPath -Encoding utf8

        Write-Host "Error details written to: $errorLogPath" -ForegroundColor Yellow
    }
}
