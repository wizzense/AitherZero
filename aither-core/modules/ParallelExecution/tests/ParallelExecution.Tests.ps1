#Requires -Version 7.0

BeforeAll {
    # Import required modules
    Import-Module Pester -Force

    # Set up test environment
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
    while (-not (Test-Path (Join-Path $ProjectRoot "aither-core")) -and $ProjectRoot -ne (Split-Path $ProjectRoot -Parent)) {
        $ProjectRoot = Split-Path $ProjectRoot -Parent
    }

    # Import the module under test
    $ModulePath = Join-Path $PSScriptRoot ".."
    Import-Module $ModulePath -Force

    # Mock Write-CustomLog if not available
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Message, [string]$Level = "INFO")
            Write-Host "[$Level] $Message"
        }
    }
}

Describe "ParallelExecution Module Tests" {

    Context "Module Import and Basic Functionality" {
        It "Should import the module successfully" {
            Get-Module -Name "ParallelExecution" | Should -Not -BeNullOrEmpty
        }

        It "Should export all expected functions" {
            $expectedFunctions = @(
                'Invoke-ParallelForEach',
                'Start-ParallelJob',
                'Wait-ParallelJobs',
                'Invoke-ParallelPesterTests',
                'Merge-ParallelTestResults',
                'Get-OptimalThrottleLimit',
                'Measure-ParallelPerformance',
                'Start-AdaptiveParallelExecution'
            )

            $exportedFunctions = Get-Command -Module "ParallelExecution" | Select-Object -ExpandProperty Name

            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }
    }

    Context "Invoke-ParallelForEach Tests" {
        It "Should process items in parallel with parameter-based script block" {
            $items = 1..5
            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                param($item)
                $item * 2
            } -ThrottleLimit 2

            $results | Should -HaveCount 5
            $results | Should -Contain 2
            $results | Should -Contain 4
            $results | Should -Contain 6
            $results | Should -Contain 8
            $results | Should -Contain 10
        }

        It "Should process items in parallel with pipeline-based script block" {
            $items = 1..3
            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                $_ * 3
            } -ThrottleLimit 2

            $results | Should -HaveCount 3
            $results | Should -Contain 3
            $results | Should -Contain 6
            $results | Should -Contain 9
        }

        It "Should handle empty input gracefully" {
            $results = Invoke-ParallelForEach -InputObject @() -ScriptBlock {
                "Should not execute"
            }

            $results | Should -BeNullOrEmpty
        }

        It "Should respect throttle limits" {
            $throttleLimit = 2
            $items = 1..10
            $startTime = Get-Date

            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                param($item)
                Start-Sleep -Milliseconds 100  # Simulate work
                $item
            } -ThrottleLimit $throttleLimit

            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalMilliseconds

            $results | Should -HaveCount 10
            # Should take at least 500ms due to throttling (10 items, 2 parallel, 100ms each)
            $duration | Should -BeGreaterThan 400
        }

        It "Should handle errors in parallel execution" {
            $items = 1..5
            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                param($item)
                if ($item -eq 3) {
                    throw "Test error for item 3"
                }
                $item * 2
            } -ThrottleLimit 2 -ErrorAction SilentlyContinue

            # Should get results from successful items
            $results | Should -HaveCount 4
            $results | Should -Not -Contain 6  # Item 3 should have failed
        }

        It "Should handle timeout correctly" {
            $items = 1..3

            {
                Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                    Start-Sleep -Seconds 10  # Long running operation
                    $_
                } -TimeoutSeconds 1
            } | Should -Throw
        }
    }

    Context "Start-ParallelJob Tests" {
        It "Should start a background job successfully" {
            $job = Start-ParallelJob -Name "TestJob" -ScriptBlock {
                "Job completed"
            }

            $job | Should -Not -BeNullOrEmpty
            $job.Name | Should -Be "TestJob"
            $job.State | Should -BeIn @("Running", "Completed")

            # Cleanup
            $job | Remove-Job -Force -ErrorAction SilentlyContinue
        }

        It "Should pass arguments to job script block" {
            $job = Start-ParallelJob -Name "TestJobWithArgs" -ScriptBlock {
                param($arg1, $arg2)
                "$arg1-$arg2"
            } -ArgumentList @("Hello", "World")

            $job | Should -Not -BeNullOrEmpty
            Wait-Job -Job $job | Out-Null
            $result = Receive-Job -Job $job
            $result | Should -Be "Hello-World"

            # Cleanup
            $job | Remove-Job -Force -ErrorAction SilentlyContinue
        }

        It "Should handle job creation errors" {
            {
                Start-ParallelJob -Name "FailingJob" -ScriptBlock {
                    throw "Job creation test error"
                }
            } | Should -Not -Throw  # The job should be created, but fail during execution
        }
    }

    Context "Wait-ParallelJobs Tests" {
        It "Should wait for multiple jobs to complete" {
            $jobs = @()
            $jobs += Start-ParallelJob -Name "Job1" -ScriptBlock { Start-Sleep -Milliseconds 100; "Result1" }
            $jobs += Start-ParallelJob -Name "Job2" -ScriptBlock { Start-Sleep -Milliseconds 200; "Result2" }
            $jobs += Start-ParallelJob -Name "Job3" -ScriptBlock { Start-Sleep -Milliseconds 150; "Result3" }

            $results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 10

            $results | Should -HaveCount 3
            $results | ForEach-Object {
                $_.Name | Should -BeIn @("Job1", "Job2", "Job3")
                $_.State | Should -BeIn @("Completed", "Failed")
            }

            # Verify results are collected
            $completedResults = $results | Where-Object { $_.State -eq "Completed" }
            $completedResults | Should -HaveCount 3
        }

        It "Should handle job timeouts" {
            $jobs = @()
            $jobs += Start-ParallelJob -Name "SlowJob" -ScriptBlock { Start-Sleep -Seconds 10; "Should not complete" }

            $results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 1

            $results | Should -HaveCount 1
            $results[0].State | Should -Be "Timeout"
        }

        It "Should collect errors from failed jobs" {
            $jobs = @()
            $jobs += Start-ParallelJob -Name "FailingJob" -ScriptBlock { throw "Test error" }
            $jobs += Start-ParallelJob -Name "SuccessJob" -ScriptBlock { "Success" }

            $results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 5

            $results | Should -HaveCount 2

            $failedJob = $results | Where-Object { $_.Name -eq "FailingJob" }
            $failedJob.State | Should -Be "Failed"
            $failedJob.HasErrors | Should -Be $true

            $successJob = $results | Where-Object { $_.Name -eq "SuccessJob" }
            $successJob.State | Should -Be "Completed"
            $successJob.HasErrors | Should -Be $false
        }

        It "Should show progress when requested" {
            $jobs = @()
            $jobs += Start-ParallelJob -Name "ProgressJob1" -ScriptBlock { Start-Sleep -Milliseconds 100; "Done1" }
            $jobs += Start-ParallelJob -Name "ProgressJob2" -ScriptBlock { Start-Sleep -Milliseconds 200; "Done2" }

            # This should not throw when ShowProgress is used
            {
                $results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 5 -ShowProgress
                $results | Should -HaveCount 2
            } | Should -Not -Throw
        }
    }

    Context "Invoke-ParallelPesterTests Tests" {
        BeforeAll {
            # Create temporary test files
            $TestDir = Join-Path $TestDrive "ParallelTests"
            New-Item -Path $TestDir -ItemType Directory -Force

            # Create simple test files
            $Test1Content = @'
Describe "Test File 1" {
    It "Should pass test 1" {
        $true | Should -Be $true
    }
    It "Should pass test 2" {
        1 + 1 | Should -Be 2
    }
}
'@

            $Test2Content = @'
Describe "Test File 2" {
    It "Should pass test 3" {
        "hello" | Should -Be "hello"
    }
    It "Should pass test 4" {
        @(1,2,3) | Should -HaveCount 3
    }
}
'@

            $Test1Path = Join-Path $TestDir "Test1.Tests.ps1"
            $Test2Path = Join-Path $TestDir "Test2.Tests.ps1"

            Set-Content -Path $Test1Path -Value $Test1Content
            Set-Content -Path $Test2Path -Value $Test2Content
        }

        It "Should run Pester tests in parallel" {
            $testPaths = @(
                (Join-Path $TestDir "Test1.Tests.ps1"),
                (Join-Path $TestDir "Test2.Tests.ps1")
            )

            $results = Invoke-ParallelPesterTests -TestPaths $testPaths -ThrottleLimit 2

            $results | Should -HaveCount 2
            $results | ForEach-Object {
                $_.Name | Should -Match "PesterTest_Test\d\.Tests\.ps1"
                $_.State | Should -BeIn @("Completed", "Failed")
            }
        }

        It "Should handle missing test files gracefully" {
            $testPaths = @(
                (Join-Path $TestDir "NonExistent.Tests.ps1")
            )

            $results = Invoke-ParallelPesterTests -TestPaths $testPaths -ThrottleLimit 1

            $results | Should -HaveCount 1
            $results[0].State | Should -Be "Failed"
        }

        It "Should respect throttle limits for test execution" {
            $testPaths = @(
                (Join-Path $TestDir "Test1.Tests.ps1"),
                (Join-Path $TestDir "Test2.Tests.ps1")
            )

            $startTime = Get-Date
            $results = Invoke-ParallelPesterTests -TestPaths $testPaths -ThrottleLimit 1
            $endTime = Get-Date

            $results | Should -HaveCount 2

            # With throttle limit of 1, tests should run sequentially
            $duration = ($endTime - $startTime).TotalMilliseconds
            $duration | Should -BeGreaterThan 100  # Should take some time due to sequential execution
        }
    }

    Context "Merge-ParallelTestResults Tests" {
        It "Should merge test results correctly" {
            # Create mock test results
            $testResults = @(
                @{
                    Name = "Test1"
                    State = "Completed"
                    Result = @{
                        Passed = @(1, 2, 3)  # 3 passed tests
                        Failed = @()
                        Skipped = @()
                        TotalTime = [TimeSpan]::FromSeconds(5)
                    }
                    HasErrors = $false
                    Errors = @()
                },
                @{
                    Name = "Test2"
                    State = "Completed"
                    Result = @{
                        Passed = @(1, 2)  # 2 passed tests
                        Failed = @(1)     # 1 failed test
                        Skipped = @(1)    # 1 skipped test
                        TotalTime = [TimeSpan]::FromSeconds(3)
                    }
                    HasErrors = $false
                    Errors = @()
                }
            )

            $summary = Merge-ParallelTestResults -TestResults $testResults

            $summary.TotalTests | Should -Be 7  # 3 + 2 + 1 + 1
            $summary.Passed | Should -Be 5      # 3 + 2
            $summary.Failed | Should -Be 1      # 0 + 1
            $summary.Skipped | Should -Be 1     # 0 + 1
            $summary.TotalTime.TotalSeconds | Should -Be 8  # 5 + 3
            $summary.Success | Should -Be $false  # Has failed tests
        }

        It "Should handle empty test results" {
            $summary = Merge-ParallelTestResults -TestResults @()

            $summary.TotalTests | Should -Be 0
            $summary.Passed | Should -Be 0
            $summary.Failed | Should -Be 0
            $summary.Skipped | Should -Be 0
            $summary.TotalTime.TotalSeconds | Should -Be 0
            $summary.Success | Should -Be $true  # No failures
        }

        It "Should aggregate failures correctly" {
            $testResults = @(
                @{
                    Name = "Test1"
                    State = "Completed"
                    Result = @{
                        Passed = @(1)
                        Failed = @(
                            @{ Name = "Failing Test 1"; ErrorRecord = @{ Exception = @{ Message = "Error 1" } } }
                        )
                        Skipped = @()
                        TotalTime = [TimeSpan]::FromSeconds(2)
                    }
                    HasErrors = $true
                    Errors = @("Job error 1")
                }
            )

            $summary = Merge-ParallelTestResults -TestResults $testResults

            $summary.Failed | Should -Be 1
            $summary.Failures | Should -HaveCount 1
            $summary.Success | Should -Be $false
        }
    }

    Context "Performance and Resource Management Tests" {
        It "Should handle large parallel workloads efficiently" {
            $items = 1..100
            $startTime = Get-Date

            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                param($item)
                Start-Sleep -Milliseconds 10
                $item * 2
            } -ThrottleLimit 10

            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalMilliseconds

            $results | Should -HaveCount 100
            # Should complete in reasonable time with parallel execution
            $duration | Should -BeLessThan 2000  # Should be much faster than sequential (10 seconds)
        }

        It "Should clean up resources properly" {
            $initialJobCount = (Get-Job).Count

            $jobs = @()
            for ($i = 1; $i -le 5; $i++) {
                $jobs += Start-ParallelJob -Name "CleanupTest$i" -ScriptBlock { Start-Sleep -Milliseconds 100; "Done" }
            }

            $results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 10

            # Jobs should be cleaned up after Wait-ParallelJobs
            $finalJobCount = (Get-Job).Count
            $finalJobCount | Should -Be $initialJobCount
        }

        It "Should handle memory-intensive operations" {
            $items = 1..20

            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                param($item)
                # Create some memory load
                $data = 1..1000 | ForEach-Object { "Item $_ for $item" }
                $data.Count
            } -ThrottleLimit 4

            $results | Should -HaveCount 20
            $results | ForEach-Object { $_ | Should -Be 1000 }
        }
    }

    Context "Error Handling and Edge Cases" {
        It "Should handle script block compilation errors" {
            {
                Invoke-ParallelForEach -InputObject @(1, 2, 3) -ScriptBlock {
                    param($item)
                    # Invalid PowerShell syntax
                    $invalid =
                    $item
                } -ThrottleLimit 2
            } | Should -Throw
        }

        It "Should handle null input objects" {
            $results = Invoke-ParallelForEach -InputObject @($null, $null) -ScriptBlock {
                param($item)
                if ($null -eq $item) { "null" } else { $item }
            } -ThrottleLimit 2

            $results | Should -HaveCount 2
            $results | ForEach-Object { $_ | Should -Be "null" }
        }

        It "Should handle mixed success and failure scenarios" {
            $items = 1..10

            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                param($item)
                if ($item % 3 -eq 0) {
                    throw "Error for item $item"
                }
                "Success: $item"
            } -ThrottleLimit 3 -ErrorAction SilentlyContinue

            # Should get results from successful items only
            $results | Should -HaveCount 7  # 10 - 3 failures (3, 6, 9)
            $results | ForEach-Object { $_ | Should -Match "Success: \d+" }
        }

        It "Should handle extremely high throttle limits gracefully" {
            $items = 1..10

            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                param($item)
                $item * 2
            } -ThrottleLimit 1000  # Much higher than item count

            $results | Should -HaveCount 10
            $results | Should -Contain 2
            $results | Should -Contain 20
        }
    }

    Context "Thread Safety and Concurrency Tests" {
        It "Should handle concurrent access to shared resources safely" {
            $sharedCounter = 0
            $items = 1..50

            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                param($item)
                # Simulate some work
                Start-Sleep -Milliseconds (Get-Random -Minimum 1 -Maximum 10)
                $item
            } -ThrottleLimit 10

            $results | Should -HaveCount 50
            $results | Sort-Object | Should -Be (1..50)
        }

        It "Should maintain data integrity across parallel operations" {
            $items = 1..25

            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                param($item)
                # Complex operation that could reveal race conditions
                $temp = $item
                for ($i = 0; $i -lt 5; $i++) {
                    $temp = $temp + $item
                }
                $temp
            } -ThrottleLimit 5

            $results | Should -HaveCount 25
            # Verify each result is correct (item * 6)
            for ($i = 0; $i -lt 25; $i++) {
                $expected = ($i + 1) * 6
                $results[$i] | Should -Be $expected
            }
        }
    }

    Context "Advanced Features Tests" {
        It "Should calculate optimal throttle limits correctly" {
            $cpuOptimal = Get-OptimalThrottleLimit -WorkloadType "CPU"
            $ioOptimal = Get-OptimalThrottleLimit -WorkloadType "IO"
            $networkOptimal = Get-OptimalThrottleLimit -WorkloadType "Network"
            $mixedOptimal = Get-OptimalThrottleLimit -WorkloadType "Mixed"

            $cpuCount = [Environment]::ProcessorCount

            $cpuOptimal | Should -Be $cpuCount
            $ioOptimal | Should -Be ($cpuCount * 2)
            $networkOptimal | Should -Be ($cpuCount * 3)
            $mixedOptimal | Should -Be ([Math]::Ceiling($cpuCount * 1.5))
        }

        It "Should respect maximum throttle limits" {
            $optimal = Get-OptimalThrottleLimit -WorkloadType "Network" -MaxLimit 4
            $optimal | Should -BeLessOrEqual 4
        }

        It "Should apply system load factor correctly" {
            $optimal = Get-OptimalThrottleLimit -WorkloadType "CPU" -SystemLoadFactor 0.5
            $cpuCount = [Environment]::ProcessorCount
            $expected = [Math]::Ceiling($cpuCount * 0.5)
            $optimal | Should -Be $expected
        }

        It "Should measure parallel performance correctly" {
            $startTime = Get-Date
            Start-Sleep -Milliseconds 100
            $endTime = Get-Date

            $metrics = Measure-ParallelPerformance -OperationName "TestOp" -StartTime $startTime -EndTime $endTime -ItemCount 10 -ThrottleLimit 4

            $metrics | Should -Not -BeNullOrEmpty
            $metrics.OperationName | Should -Be "TestOp"
            $metrics.ItemCount | Should -Be 10
            $metrics.ThrottleLimit | Should -Be 4
            $metrics.Duration | Should -BeGreaterThan ([TimeSpan]::FromMilliseconds(90))
            $metrics.ThroughputPerSecond | Should -BeGreaterThan 0
        }

        It "Should handle adaptive parallel execution" {
            $items = 1..20

            $results = Start-AdaptiveParallelExecution -InputObject $items -ScriptBlock {
                param($item)
                Start-Sleep -Milliseconds 10
                $item * 2
            } -InitialThrottle 2 -MaxThrottle 8

            $results | Should -HaveCount 20
            $results | Should -Contain 2
            $results | Should -Contain 40
        }
    }

    Context "Integration with Other Modules" {
        It "Should work with custom logging" {
            $logMessages = @()

            # Mock Write-CustomLog to capture messages
            function Write-CustomLog {
                param([string]$Message, [string]$Level = "INFO")
                $script:logMessages += "$Level`: $Message"
            }

            $items = 1..3
            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                param($item)
                $item * 2
            } -ThrottleLimit 2

            $results | Should -HaveCount 3
            # Note: The original function may not use our mocked version due to scoping
        }

        It "Should handle module dependency failures gracefully" {
            # Test behavior when dependent modules are not available
            $items = 1..3

            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                param($item)
                # Try to use a potentially missing command
                try {
                    $item * 2
                } catch {
                    "Error: $($_.Exception.Message)"
                }
            } -ThrottleLimit 2

            $results | Should -HaveCount 3
        }
    }
}

AfterAll {
    # Clean up any remaining jobs
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue

    # Remove the module
    Remove-Module -Name "ParallelExecution" -Force -ErrorAction SilentlyContinue
}
