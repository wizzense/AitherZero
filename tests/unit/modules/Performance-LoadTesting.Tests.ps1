Describe 'Performance Load Testing Tests' {

BeforeAll {
    # Find project root using shared utilities
    . "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot

    # Import core modules for performance testing
    $script:PerformanceModules = @{}
    $moduleNames = @('Logging', 'ParallelExecution', 'BackupManager', 'PatchManager')

    foreach ($moduleName in $moduleNames) {
        $modulePath = Join-Path $projectRoot "aither-core/modules/$moduleName"
        try {
            Import-Module $modulePath -Force -ErrorAction Stop
            $script:PerformanceModules[$moduleName] = $true
            Write-Verbose "Imported $moduleName for performance testing"
        }
        catch {
            Write-Warning "Could not import $moduleName for performance testing: $_"
            $script:PerformanceModules[$moduleName] = $false
        }
    }

    # Performance measurement helpers
    function Measure-OperationPerformance {
        param(
            [scriptblock]$Operation,
            [string]$OperationName,
            [int]$Iterations = 1,
            [int]$MaxExpectedMs = 5000
        )

        $measurements = @()

        for ($i = 1; $i -le $Iterations; $i++) {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            try {
                & $Operation
                $stopwatch.Stop()
                $measurements += $stopwatch.ElapsedMilliseconds
            }
            catch {
                $stopwatch.Stop()
                Write-Warning "$OperationName iteration $i failed: $($_.Exception.Message)"
                $measurements += $stopwatch.ElapsedMilliseconds
            }
        }

        $avgTime = ($measurements | Measure-Object -Average).Average
        $maxTime = ($measurements | Measure-Object -Maximum).Maximum
        $minTime = ($measurements | Measure-Object -Minimum).Minimum

        return @{
            OperationName = $OperationName
            Iterations = $Iterations
            AverageMs = $avgTime
            MaximumMs = $maxTime
            MinimumMs = $minTime
            AllMeasurements = $measurements
            WithinExpectedTime = $maxTime -le $MaxExpectedMs
        }
    }

    # Test data generation
    function New-TestDataSet {
        param(
            [int]$Size = 1000,
            [string]$Type = "String"
        )

        switch ($Type) {
            "String" {
                return 1..$Size | ForEach-Object { "TestString$_$(Get-Random)" }
            }
            "Hashtable" {
                return 1..$Size | ForEach-Object {
                    @{
                        Id = $_
                        Name = "Item$_"
                        Timestamp = Get-Date
                        Data = "Data$(Get-Random)"
                    }
                }
            }
            "Object" {
                return 1..$Size | ForEach-Object {
                    [PSCustomObject]@{
                        Id = $_
                        Name = "Object$_"
                        Timestamp = Get-Date
                        Value = Get-Random
                    }
                }
            }
        }
    }

    $script:testDir = Join-Path $TestDrive "PerformanceTests"
    New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
}

Describe "Performance and Load Testing" {

    Context "Module Import Performance" {

        It "Should import modules within reasonable time" {
            $moduleNames = @('Logging', 'BackupManager', 'ScriptManager', 'DevEnvironment')

            foreach ($moduleName in $moduleNames) {
                $modulePath = Join-Path $projectRoot "aither-core/modules/$moduleName"

                if (Test-Path $modulePath) {
                    $result = Measure-OperationPerformance -Operation {
                        Import-Module $modulePath -Force
                    } -OperationName "Import-$moduleName" -MaxExpectedMs 3000

                    Write-Host "$($result.OperationName): $($result.AverageMs)ms average" -ForegroundColor Cyan
                    $result.WithinExpectedTime | Should -Be $true
                }
            }
        }

        It "Should handle repeated module imports efficiently" {
            $loggingPath = Join-Path $projectRoot "aither-core/modules/Logging"

            if (Test-Path $loggingPath) {
                $result = Measure-OperationPerformance -Operation {
                    Import-Module $loggingPath -Force
                } -OperationName "RepeatedImport-Logging" -Iterations 10 -MaxExpectedMs 1000

                Write-Host "Repeated imports average: $($result.AverageMs)ms" -ForegroundColor Cyan
                $result.AverageMs | Should -BeLessThan 500
            }
        }
    }

    Context "Logging Performance" -Skip:(-not ($script:PerformanceModules.ContainsKey('Logging') -and $script:PerformanceModules['Logging'])) {

        BeforeEach {
            if ($script:PerformanceModules['Logging']) {
                $logFile = Join-Path $script:testDir "performance-test.log"
                Initialize-LoggingSystem -LogPath $logFile -LogLevel "INFO"
            }
        }

        It "Should handle high-volume logging efficiently" {
            if ($script:PerformanceModules['Logging']) {
                $result = Measure-OperationPerformance -Operation {
                    for ($i = 1; $i -le 100; $i++) {
                        Write-CustomLog -Message "Performance test message $i" -Level "INFO"
                    }
                } -OperationName "HighVolumeLogging" -MaxExpectedMs 3000

                Write-Host "High-volume logging: $($result.AverageMs)ms for 100 messages" -ForegroundColor Cyan
                $result.WithinExpectedTime | Should -Be $true
            }
        }

        It "Should handle concurrent logging without significant performance degradation" {
            if ($script:PerformanceModules['Logging']) {
                $jobs = @()
                $startTime = Get-Date

                # Start concurrent logging jobs
                for ($i = 1; $i -le 5; $i++) {
                    $jobs += Start-Job -ScriptBlock {
                        param($projectRoot, $jobId)

                        $loggingPath = Join-Path $projectRoot "aither-core/modules/Logging"
                        Import-Module $loggingPath -Force

                        $logFile = Join-Path ([System.IO.Path]::GetTempPath()) "concurrent-test-$jobId.log"
                        Initialize-LoggingSystem -LogPath $logFile

                        for ($j = 1; $j -le 50; $j++) {
                            Write-CustomLog -Message "Concurrent job $jobId message $j" -Level "INFO"
                        }

                        return "Job $jobId completed"
                    } -ArgumentList $projectRoot, $i
                }

                $results = $jobs | Wait-Job | Receive-Job
                $jobs | Remove-Job -Force

                $endTime = Get-Date
                $totalTime = ($endTime - $startTime).TotalMilliseconds

                Write-Host "Concurrent logging (5 jobs, 50 messages each): $totalTime ms" -ForegroundColor Cyan

                $results.Count | Should -Be 5
                $totalTime | Should -BeLessThan 10000  # 10 seconds max
            }
        }

        It "Should handle large log messages efficiently" {
            if ($script:PerformanceModules['Logging']) {
                # Create a large message (1MB)
                $largeMessage = "A" * 1024 * 1024

                $result = Measure-OperationPerformance -Operation {
                    Write-CustomLog -Message $largeMessage -Level "INFO"
                } -OperationName "LargeMessageLogging" -MaxExpectedMs 2000

                Write-Host "Large message logging: $($result.AverageMs)ms" -ForegroundColor Cyan
                $result.WithinExpectedTime | Should -Be $true
            }
        }
    }

    Context "File Operations Performance" -Skip:(-not ($script:PerformanceModules.ContainsKey('BackupManager') -and $script:PerformanceModules['BackupManager'])) {

        It "Should handle large file operations efficiently" {
            if ($script:PerformanceModules['BackupManager']) {
                # Create test files
                $sourceDir = Join-Path $script:testDir "LargeFileSource"
                New-Item -Path $sourceDir -ItemType Directory -Force | Out-Null

                # Create multiple medium-sized files
                for ($i = 1; $i -le 10; $i++) {
                    $testFile = Join-Path $sourceDir "TestFile$i.txt"
                    $content = "Test data " * 10000  # ~100KB per file
                    Set-Content -Path $testFile -Value $content
                }

                $backupDir = Join-Path $script:testDir "LargeFileBackup"

                $result = Measure-OperationPerformance -Operation {
                    Invoke-BackupConsolidation -SourcePath $sourceDir -BackupPath $backupDir
                } -OperationName "LargeFileBackup" -MaxExpectedMs 10000

                Write-Host "Large file backup: $($result.AverageMs)ms" -ForegroundColor Cyan
                $result.WithinExpectedTime | Should -Be $true
            }
        }

        It "Should handle deep directory structures efficiently" {
            if ($script:PerformanceModules['BackupManager']) {
                # Create a deep directory structure
                $deepDir = Join-Path $script:testDir "DeepStructure"
                $currentPath = $deepDir

                # Create 20 levels deep
                for ($i = 1; $i -le 20; $i++) {
                    $currentPath = Join-Path $currentPath "Level$i"
                    New-Item -Path $currentPath -ItemType Directory -Force | Out-Null

                    # Add a file at each level
                    $testFile = Join-Path $currentPath "file$i.txt"
                    "Content at level $i" | Set-Content $testFile
                }

                $backupDir = Join-Path $script:testDir "DeepBackup"

                $result = Measure-OperationPerformance -Operation {
                    Invoke-BackupConsolidation -SourcePath $deepDir -BackupPath $backupDir
                } -OperationName "DeepDirectoryBackup" -MaxExpectedMs 5000

                Write-Host "Deep directory backup: $($result.AverageMs)ms" -ForegroundColor Cyan
                $result.WithinExpectedTime | Should -Be $true
            }
        }
    }

    Context "Parallel Execution Performance" -Skip:(-not ($script:PerformanceModules.ContainsKey('ParallelExecution') -and $script:PerformanceModules['ParallelExecution'])) {

        It "Should demonstrate performance improvement with parallel execution" {
            if ($script:PerformanceModules['ParallelExecution']) {
                $testData = 1..100

                # Measure serial execution
                $serialResult = Measure-OperationPerformance -Operation {
                    $results = $testData | ForEach-Object {
                        Start-Sleep -Milliseconds 10
                        $_ * 2
                    }
                } -OperationName "SerialExecution"

                # Measure parallel execution
                $parallelResult = Measure-OperationPerformance -Operation {
                    $results = Invoke-ParallelForEach -InputObject $testData -ScriptBlock {
                        param($item)
                        Start-Sleep -Milliseconds 10
                        return $item * 2
                    } -ThrottleLimit 10
                } -OperationName "ParallelExecution"

                Write-Host "Serial execution: $($serialResult.AverageMs)ms" -ForegroundColor Yellow
                Write-Host "Parallel execution: $($parallelResult.AverageMs)ms" -ForegroundColor Green

                # Parallel should be significantly faster
                $parallelResult.AverageMs | Should -BeLessThan ($serialResult.AverageMs * 0.5)
            }
        }

        It "Should handle different throttle limits efficiently" {
            if ($script:PerformanceModules['ParallelExecution']) {
                $testData = 1..50
                $throttleLimits = @(2, 5, 10, 20)
                $results = @{}

                foreach ($throttle in $throttleLimits) {
                    $result = Measure-OperationPerformance -Operation {
                        Invoke-ParallelForEach -InputObject $testData -ScriptBlock {
                            param($item)
                            Start-Sleep -Milliseconds 20
                            return $item
                        } -ThrottleLimit $throttle
                    } -OperationName "Throttle$throttle"

                    $results[$throttle] = $result.AverageMs
                    Write-Host "Throttle $throttle`: $($result.AverageMs)ms" -ForegroundColor Cyan
                }

                # Higher throttle limits should generally be faster (up to a point)
                $results[2] | Should -BeGreaterThan $results[10]
            }
        }

        It "Should handle large datasets efficiently" {
            if ($script:PerformanceModules['ParallelExecution']) {
                $largeDataset = New-TestDataSet -Size 1000 -Type "Object"

                $result = Measure-OperationPerformance -Operation {
                    $processed = Invoke-ParallelForEach -InputObject $largeDataset -ScriptBlock {
                        param($obj)
                        return @{
                            Id = $obj.Id
                            ProcessedName = $obj.Name.ToUpper()
                            Square = $obj.Value * $obj.Value
                        }
                    } -ThrottleLimit 10
                } -OperationName "LargeDatasetProcessing" -MaxExpectedMs 15000

                Write-Host "Large dataset processing: $($result.AverageMs)ms for 1000 items" -ForegroundColor Cyan
                $result.WithinExpectedTime | Should -Be $true
            }
        }
    }

    Context "Memory Usage Patterns" {

        It "Should maintain reasonable memory usage during operations" {
            $initialMemory = [System.GC]::GetTotalMemory($true)

            # Perform memory-intensive operations
            $largeArray = 1..10000 | ForEach-Object {
                [PSCustomObject]@{
                    Id = $_
                    Data = "Large data string that takes up memory $_" * 10
                    Timestamp = Get-Date
                }
            }

            $peakMemory = [System.GC]::GetTotalMemory($false)

            # Process the array
            $processed = $largeArray | Where-Object { $_.Id -le 5000 } | ForEach-Object { $_.Id }

            # Force garbage collection
            $largeArray = $null
            $processed = $null
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()

            $finalMemory = [System.GC]::GetTotalMemory($true)

            $memoryGrowth = $peakMemory - $initialMemory
            $memoryRetained = $finalMemory - $initialMemory

            Write-Host "Memory growth: $([math]::Round($memoryGrowth / 1MB, 2))MB" -ForegroundColor Yellow
            Write-Host "Memory retained: $([math]::Round($memoryRetained / 1MB, 2))MB" -ForegroundColor Cyan

            # Should not retain excessive memory after cleanup
            $memoryRetained | Should -BeLessThan (50 * 1MB)
        }

        It "Should handle memory pressure gracefully" {
            $arrays = @()
            $maxArrays = 10

            try {
                # Create multiple large arrays to simulate memory pressure
                for ($i = 1; $i -le $maxArrays; $i++) {
                    $currentMemory = [System.GC]::GetTotalMemory($false)

                    # Stop if we're using too much memory (>500MB)
                    if ($currentMemory -gt 500MB) {
                        Write-Host "Stopping at array $i due to memory limit" -ForegroundColor Yellow
                        break
                    }

                    $arrays += New-TestDataSet -Size 5000 -Type "String"
                }

                # Should be able to handle at least a few arrays
                $arrays.Count | Should -BeGreaterThan 2
            }
            finally {
                # Cleanup
                $arrays = $null
                [System.GC]::Collect()
            }
        }
    }

    Context "Stress Testing" {

        It "Should handle rapid function calls" {
            if ($script:PerformanceModules['Logging']) {
                $callCount = 0
                $errors = 0

                $result = Measure-OperationPerformance -Operation {
                    for ($i = 1; $i -le 500; $i++) {
                        try {
                            Write-CustomLog -Message "Rapid call $i" -Level "INFO"
                            $script:callCount++
                        }
                        catch {
                            $script:errors++
                        }
                    }
                } -OperationName "RapidFunctionCalls" -MaxExpectedMs 5000

                Write-Host "Rapid function calls: $($result.AverageMs)ms for 500 calls" -ForegroundColor Cyan
                Write-Host "Successful calls: $callCount, Errors: $errors" -ForegroundColor Yellow

                $result.WithinExpectedTime | Should -Be $true
                $errors | Should -BeLessThan 10  # Allow for some errors under stress
            }
        }

        It "Should handle concurrent module usage" {
            $jobs = @()
            $jobCount = 5

            for ($i = 1; $i -le $jobCount; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($projectRoot, $jobId)

                    $results = @()

                    try {
                        # Import modules concurrently
                        $loggingPath = Join-Path $projectRoot "aither-core/modules/Logging"
                        Import-Module $loggingPath -Force -ErrorAction SilentlyContinue

                        # Use the module
                        for ($j = 1; $j -le 50; $j++) {
                            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                                Write-CustomLog -Message "Stress test job $jobId iteration $j" -Level "INFO"
                                $results += "Success-$j"
                            }
                            else {
                                $results += "Failed-$j"
                            }
                        }
                    }
                    catch {
                        $results += "Error: $($_.Exception.Message)"
                    }

                    return @{
                        JobId = $jobId
                        Results = $results
                        Success = ($results | Where-Object { $_ -like "Success-*" }).Count
                    }
                } -ArgumentList $projectRoot, $i
            }

            $startTime = Get-Date
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job -Force
            $endTime = Get-Date

            $totalTime = ($endTime - $startTime).TotalMilliseconds
            $totalSuccess = ($results | ForEach-Object { $_.Success } | Measure-Object -Sum).Sum

            Write-Host "Concurrent stress test: $totalTime ms" -ForegroundColor Cyan
            Write-Host "Total successful operations: $totalSuccess" -ForegroundColor Green

            Write-Host "Concurrent stress test: $totalTime ms" -ForegroundColor Cyan
            Write-Host "Total successful operations: $totalSuccess" -ForegroundColor Green

            $results.Count | Should -Be $jobCount
            $totalSuccess | Should -BeGreaterThan 100  # At least some operations should succeed
        }
    }
}  # End of Describe 'Performance Load Testing Tests'

}
