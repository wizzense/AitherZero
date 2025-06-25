#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
Tests for the ParallelExecution module

.DESCRIPTION
Validates parallel processing functionality including job management, 
test execution, and result aggregation.
#>

BeforeAll {
    # Import the ParallelExecution module directly
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $modulePath = Join-Path $moduleRoot "pwsh\modules\ParallelExecution\ParallelExecution.psm1"
    
    if (-not (Test-Path $modulePath)) {
        throw "ParallelExecution module not found at: $modulePath"
    }
    
    # Source the module file directly
    . $modulePath
    
    # Mock Write-CustomLog if not available
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function global:Write-CustomLog {
            param([string]$Message, [string]$Level = "INFO")
            Write-Host "[$Level] $Message"
        }
    }
}

Describe "ParallelExecution Module" {
      Context "Module Loading" {
        It "Should load the functions successfully" {
            Get-Command Invoke-ParallelForEach -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export expected functions" {
            $expectedFunctions = @(
                'Invoke-ParallelForEach',
                'Start-ParallelJob',
                'Wait-ParallelJobs', 
                'Invoke-ParallelPesterTests',
                'Merge-ParallelTestResults'
            )
            
            foreach ($function in $expectedFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "Function $function should be available"
            }
        }
    }
    
    Context "Invoke-ParallelForEach" {
        It "Should process items in parallel" {
            $items = 1..5
            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                param($item)
                Start-Sleep -Milliseconds 100
                return $item * 2
            } -ThrottleLimit 3
            
            $results | Should -HaveCount 5
            $results | Should -Contain 2
            $results | Should -Contain 4
            $results | Should -Contain 6
            $results | Should -Contain 8
            $results | Should -Contain 10
        }
        
        It "Should handle empty input gracefully" {
            $results = Invoke-ParallelForEach -InputObject @() -ScriptBlock {
                param($item)
                return $item
            }
            
            $results | Should -BeNullOrEmpty
        }
        
        It "Should respect throttle limit" {
            # This test verifies the function accepts the parameter
            # Actual throttling verification would require more complex timing tests
            { 
                Invoke-ParallelForEach -InputObject (1..3) -ScriptBlock { 
                    param($item) 
                    return $item 
                } -ThrottleLimit 2 
            } | Should -Not -Throw
        }
    }
    
    Context "Start-ParallelJob" {
        It "Should start a background job successfully" {
            $job = Start-ParallelJob -Name "TestJob" -ScriptBlock {
                return "Test completed"
            }
            
            $job | Should -Not -BeNullOrEmpty
            $job.Name | Should -Be "TestJob"
            $job.State | Should -BeIn @('Running', 'Completed')
            
            # Clean up
            $job | Remove-Job -Force -ErrorAction SilentlyContinue
        }
        
        It "Should start job with arguments" {
            $job = Start-ParallelJob -Name "TestJobWithArgs" -ScriptBlock {
                param($value)
                return "Processed: $value"
            } -ArgumentList @("TestValue")
            
            $job | Should -Not -BeNullOrEmpty
            
            # Wait briefly and check result
            Wait-Job $job -Timeout 5 | Out-Null
            $result = Receive-Job $job
            $result | Should -Be "Processed: TestValue"
            
            # Clean up
            $job | Remove-Job -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Wait-ParallelJobs" {
        It "Should wait for multiple jobs to complete" {
            $jobs = @()
            
            # Create multiple test jobs
            for ($i = 1; $i -le 3; $i++) {
                $job = Start-ParallelJob -Name "TestJob$i" -ScriptBlock {
                    param($number)
                    Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 300)
                    return "Job $number completed"
                } -ArgumentList @($i)
                
                $jobs += $job
            }
            
            # Wait for all jobs
            $results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 10
            
            $results | Should -HaveCount 3
            $results | ForEach-Object {
                $_.State | Should -BeIn @('Completed', 'Failed')
                $_.Name | Should -Match 'TestJob\d+'
            }
        }
        
        It "Should handle job timeout appropriately" {
            $job = Start-ParallelJob -Name "SlowJob" -ScriptBlock {
                Start-Sleep -Seconds 10  # This will timeout
                return "Should not complete"
            }
            
            $results = Wait-ParallelJobs -Jobs @($job) -TimeoutSeconds 2
            
            $results | Should -HaveCount 1
            # Job should either be running or stopped due to timeout
            
            # Clean up
            $job | Remove-Job -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Merge-ParallelTestResults" {
        It "Should merge test results correctly" {
            # Create mock test results
            $testResults = @(
                @{
                    Name = "Test1"
                    State = "Completed"
                    Result = [PSCustomObject]@{
                        Passed = @(1, 2, 3)  # 3 passed tests
                        Failed = @()         # 0 failed tests
                        Skipped = @(1)       # 1 skipped test
                        TotalTime = [timespan]::FromSeconds(5)
                    }
                    HasErrors = $false
                    Errors = @()
                },
                @{
                    Name = "Test2" 
                    State = "Completed"
                    Result = [PSCustomObject]@{
                        Passed = @(1, 2)     # 2 passed tests
                        Failed = @(1)        # 1 failed test
                        Skipped = @()        # 0 skipped tests
                        TotalTime = [timespan]::FromSeconds(3)
                    }
                    HasErrors = $false
                    Errors = @()
                }
            )
            
            $summary = Merge-ParallelTestResults -TestResults $testResults
            
            $summary.TotalTests | Should -Be 7
            $summary.Passed | Should -Be 5
            $summary.Failed | Should -Be 1
            $summary.Skipped | Should -Be 1
            $summary.TotalTime.TotalSeconds | Should -Be 8
            $summary.Success | Should -Be $false  # Because there's 1 failure
        }
        
        It "Should handle empty results gracefully" {
            $summary = Merge-ParallelTestResults -TestResults @()
            
            $summary.TotalTests | Should -Be 0
            $summary.Passed | Should -Be 0
            $summary.Failed | Should -Be 0
            $summary.Skipped | Should -Be 0
            $summary.Success | Should -Be $true  # No failures means success
        }
    }
    
    Context "Error Handling" {
        It "Should handle script block errors in parallel execution" {
            $results = Invoke-ParallelForEach -InputObject @(1, 2, 3) -ScriptBlock {
                param($item)
                if ($item -eq 2) {
                    throw "Test error for item 2"
                }
                return $item
            }
            
            # Even with errors, should return results for successful items
            $results | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle invalid job parameters" {
            {
                Start-ParallelJob -Name "" -ScriptBlock { return "test" }
            } | Should -Throw
        }
    }
}

Describe "Parallel Processing Integration" {
    
    Context "Real-world Scenarios" {
        It "Should process files in parallel" {
            # Create temporary test files
            $tempDir = Join-Path $TestDrive "ParallelTest"
            if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
            
            $testFiles = @()
            for ($i = 1; $i -le 5; $i++) {
                $filePath = Join-Path $tempDir "test$i.txt"
                "Test content $i" | Out-File -FilePath $filePath
                $testFiles += Get-Item $filePath
            }
            
            # Process files in parallel
            $results = Invoke-ParallelForEach -InputObject $testFiles -ScriptBlock {
                param($file)
                $content = Get-Content $file.FullName
                return @{
                    FileName = $file.Name
                    Content = $content
                    Length = $content.Length
                }
            }
            
            $results | Should -HaveCount 5
            $results | ForEach-Object {
                $_.FileName | Should -Match 'test\d+\.txt'
                $_.Content | Should -Match 'Test content \d+'
            }
        }
        
        It "Should handle mixed success and failure scenarios" {
            $items = @(
                @{ Value = 1; ShouldFail = $false },
                @{ Value = 2; ShouldFail = $true },
                @{ Value = 3; ShouldFail = $false }
            )
            
            $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
                param($item)
                if ($item.ShouldFail) {
                    throw "Intentional failure for value $($item.Value)"
                }
                return "Success: $($item.Value)"
            }
            
            # Should get results for successful items
            $successfulResults = $results | Where-Object { $_ -like "Success:*" }
            $successfulResults | Should -HaveCount 2
        }
    }
}

AfterAll {
    # Clean up any remaining jobs
    Get-Job | Where-Object { $_.Name -like "TestJob*" -or $_.Name -like "*Parallel*" } | Remove-Job -Force -ErrorAction SilentlyContinue
}