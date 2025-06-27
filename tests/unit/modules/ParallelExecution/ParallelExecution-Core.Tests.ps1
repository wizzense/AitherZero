BeforeAll {
    # Mock Write-CustomLog function
    function global:Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }

    # Find project root using robust detection
    $projectRoot = if ($env:PROJECT_ROOT) {
        $env:PROJECT_ROOT
    } elseif (Test-Path '/workspaces/AitherLabs') {
        '/workspaces/AitherLabs'
    } else {
        Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
    }

    # Import the ParallelExecution module
    $parallelExecutionPath = Join-Path $projectRoot "aither-core/modules/ParallelExecution"

    try {
        Import-Module $parallelExecutionPath -Force -ErrorAction Stop
        Write-Host "ParallelExecution module imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import ParallelExecution module: $_"
        throw
    }

    # Helper function to create test script blocks
    function New-TestScriptBlock {
        param([int]$DelayMs = 100, [string]$ReturnValue = "Success")
        return [scriptblock]::Create(@"
            param(`$InputObject)
            Start-Sleep -Milliseconds $DelayMs
            return "$ReturnValue - `$InputObject"
"@)
    }
}

Describe "ParallelExecution Module - Core Functions" {

    Context "Invoke-ParallelForEach" {

        It "Should execute script block in parallel for multiple inputs" {
            $inputs = @(1, 2, 3, 4, 5)
            $scriptBlock = { param($num) return $num * 2 }

            $results = Invoke-ParallelForEach -InputObject $inputs -ScriptBlock $scriptBlock -ThrottleLimit 3

            $results | Should -HaveCount 5
            $results | Should -Contain 2
            $results | Should -Contain 4
            $results | Should -Contain 6
            $results | Should -Contain 8
            $results | Should -Contain 10
        }

        It "Should respect throttle limit" {
            $inputs = @(1, 2, 3, 4, 5, 6, 7, 8)
            $scriptBlock = New-TestScriptBlock -DelayMs 200

            $startTime = Get-Date
            $results = Invoke-ParallelForEach -InputObject $inputs -ScriptBlock $scriptBlock -ThrottleLimit 2
            $endTime = Get-Date

            $results | Should -HaveCount 8
            # With throttle limit of 2, it should take approximately 4 cycles of 200ms each
            ($endTime - $startTime).TotalMilliseconds | Should -BeGreaterThan 600
        }

        It "Should handle empty input collection" {
            $inputs = @()
            $scriptBlock = { param($num) return $num * 2 }

            $results = Invoke-ParallelForEach -InputObject $inputs -ScriptBlock $scriptBlock

            $results | Should -BeNullOrEmpty
        }

        It "Should handle single input item" {
            $inputs = @("test")
            $scriptBlock = { param($item) return "Processed: $item" }

            $results = Invoke-ParallelForEach -InputObject $inputs -ScriptBlock $scriptBlock

            $results | Should -HaveCount 1
            $results[0] | Should -Be "Processed: test"
        }

        It "Should pass parameters to script block correctly" {
            $inputs = @("A", "B", "C")
            $scriptBlock = {
                param($item)
                return "TEST-$item"
            }

            $results = Invoke-ParallelForEach -InputObject $inputs -ScriptBlock $scriptBlock

            $results | Should -Contain "TEST-A"
            $results | Should -Contain "TEST-B"
            $results | Should -Contain "TEST-C"
        }
    }

    Context "Start-ParallelJob and Wait-ParallelJobs" {

        It "Should start parallel jobs successfully" {
            $job1 = Start-ParallelJob -Name "Job1" -ScriptBlock { Start-Sleep -Milliseconds 100; return "Job1 Result" }
            $job2 = Start-ParallelJob -Name "Job2" -ScriptBlock { Start-Sleep -Milliseconds 100; return "Job2 Result" }

            $job1 | Should -Not -BeNullOrEmpty
            $job2 | Should -Not -BeNullOrEmpty
            $job1.Name | Should -Be "Job1"
            $job2.Name | Should -Be "Job2"

            # Clean up
            $job1, $job2 | Remove-Job -Force -ErrorAction SilentlyContinue
        }

        It "Should wait for parallel jobs to complete" {
            $jobs = @()
            $jobs += Start-ParallelJob -Name "Job1" -ScriptBlock { Start-Sleep -Milliseconds 200; return "Result1" }
            $jobs += Start-ParallelJob -Name "Job2" -ScriptBlock { Start-Sleep -Milliseconds 100; return "Result2" }

            $results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 5

            $results | Should -HaveCount 2
            $results.Values | Should -Contain "Result1"
            $results.Values | Should -Contain "Result2"

            # Clean up
            $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
        }

        It "Should handle job timeout gracefully" {
            $job = Start-ParallelJob -Name "SlowJob" -ScriptBlock { Start-Sleep -Seconds 10; return "Should not complete" }

            $results = Wait-ParallelJobs -Jobs @($job) -TimeoutSeconds 1

            # Should return empty or partial results due to timeout
            $results | Should -Not -BeNullOrEmpty

            # Clean up
            $job | Remove-Job -Force -ErrorAction SilentlyContinue
        }

        It "Should pass arguments to parallel jobs" {
            $job = Start-ParallelJob -Name "JobWithArgs" -ScriptBlock {
                param($value, $multiplier)
                return $value * $multiplier
            } -ArgumentList @(5, 3)

            $results = Wait-ParallelJobs -Jobs @($job) -TimeoutSeconds 5

            $results["JobWithArgs"] | Should -Be 15

            # Clean up
            $job | Remove-Job -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Invoke-ParallelPesterTests" {

        BeforeEach {
            # Create temporary test files
            $script:testDir = Join-Path $TestDrive "TestFiles"
            New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null

            # Create sample test files
            $testFile1 = Join-Path $script:testDir "Test1.Tests.ps1"
            $testFile2 = Join-Path $script:testDir "Test2.Tests.ps1"

            @"
Describe "Sample Test 1" {
    It "Should pass" {
        `$true | Should -Be `$true
    }
}
"@ | Out-File -FilePath $testFile1 -Encoding UTF8

            @"
Describe "Sample Test 2" {
    It "Should also pass" {
        1 + 1 | Should -Be 2
    }
}
"@ | Out-File -FilePath $testFile2 -Encoding UTF8
        }

        It "Should execute Pester tests in parallel" {
            $testFiles = Get-ChildItem -Path $script:testDir -Filter "*.Tests.ps1"

            $results = Invoke-ParallelPesterTests -TestFiles $testFiles.FullName -ThrottleLimit 2

            $results | Should -Not -BeNullOrEmpty
            $results | Should -HaveCount 2
        }

        It "Should handle single test file" {
            $testFile = Get-ChildItem -Path $script:testDir -Filter "Test1.Tests.ps1"

            $results = Invoke-ParallelPesterTests -TestFiles $testFile.FullName

            $results | Should -Not -BeNullOrEmpty
            $results | Should -HaveCount 1
        }

        It "Should pass through Pester configuration" {
            $testFiles = Get-ChildItem -Path $script:testDir -Filter "*.Tests.ps1"
            $pesterConfig = @{
                Output = @{
                    Verbosity = 'Minimal'
                }
            }

            { Invoke-ParallelPesterTests -TestFiles $testFiles.FullName -PesterConfiguration $pesterConfig } | Should -Not -Throw
        }
    }

    Context "Merge-ParallelTestResults" {

        It "Should merge multiple test result objects" {
            # Create mock test results
            $result1 = [PSCustomObject]@{
                TotalCount = 5
                PassedCount = 4
                FailedCount = 1
                SkippedCount = 0
                Duration = [TimeSpan]::FromSeconds(10)
            }

            $result2 = [PSCustomObject]@{
                TotalCount = 3
                PassedCount = 3
                FailedCount = 0
                SkippedCount = 0
                Duration = [TimeSpan]::FromSeconds(5)
            }

            $merged = Merge-ParallelTestResults -TestResults @($result1, $result2)

            $merged.TotalCount | Should -Be 8
            $merged.PassedCount | Should -Be 7
            $merged.FailedCount | Should -Be 1
            $merged.SkippedCount | Should -Be 0
            $merged.Duration.TotalSeconds | Should -Be 15
        }

        It "Should handle empty test results array" {
            $merged = Merge-ParallelTestResults -TestResults @()

            $merged.TotalCount | Should -Be 0
            $merged.PassedCount | Should -Be 0
            $merged.FailedCount | Should -Be 0
            $merged.SkippedCount | Should -Be 0
        }

        It "Should handle single test result" {
            $result = [PSCustomObject]@{
                TotalCount = 2
                PassedCount = 2
                FailedCount = 0
                SkippedCount = 0
                Duration = [TimeSpan]::FromSeconds(3)
            }

            $merged = Merge-ParallelTestResults -TestResults @($result)

            $merged.TotalCount | Should -Be 2
            $merged.PassedCount | Should -Be 2
            $merged.FailedCount | Should -Be 0
            $merged.Duration.TotalSeconds | Should -Be 3
        }
    }
}

Describe "ParallelExecution Module - Error Handling" {

    Context "Error Scenarios" {

        It "Should handle script block errors gracefully in parallel execution" {
            $inputs = @(1, 2, 3)
            $scriptBlock = {
                param($num)
                if ($num -eq 2) { throw "Error for number 2" }
                return $num * 2
            }
              # Should not throw, but may return partial results
            { Invoke-ParallelForEach -InputObject $inputs -ScriptBlock $scriptBlock } | Should -Not -Throw
        }

        It "Should handle invalid throttle limits" {
            $inputs = @(1, 2, 3)
            $scriptBlock = { param($num) return $num * 2 }

            # Should throw for invalid ThrottleLimit values (must be >= 1)
            { Invoke-ParallelForEach -InputObject $inputs -ScriptBlock $scriptBlock -ThrottleLimit -1 } | Should -Throw
            { Invoke-ParallelForEach -InputObject $inputs -ScriptBlock $scriptBlock -ThrottleLimit 0 } | Should -Throw
        }

        It "Should handle null script block" {
            $inputs = @(1, 2, 3)

            { Invoke-ParallelForEach -InputObject $inputs -ScriptBlock $null } | Should -Throw
        }
    }

    Context "Resource Management" {

        It "Should clean up jobs properly after completion" {
            $initialJobCount = (Get-Job).Count
              $jobs = @()
            $jobs += Start-ParallelJob -Name "CleanupTest1" -ScriptBlock { return "Test" }
            $jobs += Start-ParallelJob -Name "CleanupTest2" -ScriptBlock { return "Test" }

            Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 5 | Out-Null

            # Jobs should be cleaned up automatically or we should clean them
            $jobs | Remove-Job -Force -ErrorAction SilentlyContinue

            $finalJobCount = (Get-Job).Count
            $finalJobCount | Should -BeLessOrEqual $initialJobCount
        }
    }
}
