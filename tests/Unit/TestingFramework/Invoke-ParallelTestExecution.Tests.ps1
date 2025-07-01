#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Invoke-ParallelTestExecution'
}

Describe 'TestingFramework.Invoke-ParallelTestExecution' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
        Mock Import-ProjectModule { $true } -ModuleName $script:ModuleName
        Mock Invoke-ParallelForEach {
            # Return mock results based on input
            $InputCollection | ForEach-Object {
                @{
                    Success = $true
                    Module = $_.ModuleName
                    Phase = $_.Phase
                    Result = @{ TestsPassed = 10; TestsFailed = 0 }
                    Duration = 3
                }
            }
        } -ModuleName $script:ModuleName
        Mock Invoke-SequentialTestExecution {
            @(
                @{
                    Success = $true
                    Module = 'Module1'
                    Phase = 'Unit'
                    Result = @{ TestsPassed = 10; TestsFailed = 0 }
                    Duration = 5
                }
            )
        } -ModuleName $script:ModuleName
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require TestPlan parameter' {
            { Invoke-ParallelTestExecution -OutputPath './output' } | Should -Throw
        }
        
        It 'Should require OutputPath parameter' {
            $testPlan = @{ TestPhases = @('Unit'); Modules = @(); Configuration = @{} }
            { Invoke-ParallelTestExecution -TestPlan $testPlan } | Should -Throw
        }
    }
    
    Context 'Parallel Module Loading' {
        It 'Should attempt to import ParallelExecution module' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @()
                Configuration = @{ ParallelJobs = 4 }
            }
            
            Invoke-ParallelTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Import-ProjectModule -ModuleName $script:ModuleName -ParameterFilter {
                $ModuleName -eq 'ParallelExecution'
            }
        }
        
        It 'Should fall back to sequential when ParallelExecution unavailable' {
            Mock Import-ProjectModule { $false } -ModuleName $script:ModuleName
            
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(@{ Name = 'Module1'; TestPath = 'C:\Tests' })
                Configuration = @{ ParallelJobs = 4 }
            }
            
            Invoke-ParallelTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'ParallelExecution module unavailable' -and
                $Level -eq 'WARN'
            }
            
            Should -Invoke Invoke-SequentialTestExecution -ModuleName $script:ModuleName
        }
    }
    
    Context 'Parallel Job Creation' {
        It 'Should create job for each module-phase combination' {
            $testPlan = @{
                TestPhases = @('Unit', 'Integration')
                Modules = @(
                    @{ Name = 'Module1'; TestPath = 'C:\Tests\Module1' },
                    @{ Name = 'Module2'; TestPath = 'C:\Tests\Module2' }
                )
                Configuration = @{ ParallelJobs = 4 }
            }
            
            Invoke-ParallelTestExecution -TestPlan $testPlan -OutputPath './output'
            
            # Should create 4 jobs (2 modules × 2 phases)
            Should -Invoke Invoke-ParallelForEach -ModuleName $script:ModuleName -ParameterFilter {
                $InputCollection.Count -eq 2  # Per phase
            }
        }
        
        It 'Should pass correct job parameters' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(
                    @{ Name = 'TestModule'; TestPath = 'C:\Tests\TestModule' }
                )
                Configuration = @{ ParallelJobs = 4; Verbosity = 'Detailed' }
            }
            
            $capturedJobs = $null
            Mock Invoke-ParallelForEach {
                $capturedJobs = $InputCollection
                @(@{ Success = $true; Module = 'TestModule'; Phase = 'Unit' })
            } -ModuleName $script:ModuleName
            
            Invoke-ParallelTestExecution -TestPlan $testPlan -OutputPath './output'
            
            $capturedJobs | Should -HaveCount 1
            $capturedJobs[0].ModuleName | Should -Be 'TestModule'
            $capturedJobs[0].Phase | Should -Be 'Unit'
            $capturedJobs[0].TestPath | Should -Be 'C:\Tests\TestModule'
            $capturedJobs[0].Configuration.Verbosity | Should -Be 'Detailed'
        }
    }
    
    Context 'Max Concurrency' {
        It 'Should use ParallelJobs from configuration' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(
                    @{ Name = 'Module1' },
                    @{ Name = 'Module2' },
                    @{ Name = 'Module3' }
                )
                Configuration = @{ ParallelJobs = 2 }
            }
            
            Invoke-ParallelTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Invoke-ParallelForEach -ModuleName $script:ModuleName -ParameterFilter {
                $MaxConcurrency -eq 2
            }
        }
    }
    
    Context 'Result Collection' {
        It 'Should collect results from all parallel executions' {
            $testPlan = @{
                TestPhases = @('Unit', 'Integration')
                Modules = @(
                    @{ Name = 'Module1'; TestPath = 'C:\Tests\Module1' },
                    @{ Name = 'Module2'; TestPath = 'C:\Tests\Module2' }
                )
                Configuration = @{ ParallelJobs = 4 }
            }
            
            Mock Invoke-ParallelForEach {
                $InputCollection | ForEach-Object {
                    @{
                        Success = $true
                        Module = $_.ModuleName
                        Phase = $_.Phase
                        Result = @{ TestsPassed = 5; TestsFailed = 0 }
                        Duration = 2
                    }
                }
            } -ModuleName $script:ModuleName
            
            $results = Invoke-ParallelTestExecution -TestPlan $testPlan -OutputPath './output'
            
            $results | Should -HaveCount 4  # 2 modules × 2 phases
        }
        
        It 'Should preserve result structure from parallel execution' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(@{ Name = 'Module1'; TestPath = 'C:\Tests' })
                Configuration = @{ ParallelJobs = 1 }
            }
            
            Mock Invoke-ParallelForEach {
                @(
                    @{
                        Success = $true
                        Module = 'Module1'
                        Phase = 'Unit'
                        Result = @{ TestsPassed = 10; TestsFailed = 2 }
                        Duration = 3.5
                    }
                )
            } -ModuleName $script:ModuleName
            
            $results = Invoke-ParallelTestExecution -TestPlan $testPlan -OutputPath './output'
            
            $results[0].Success | Should -Be $true
            $results[0].Module | Should -Be 'Module1'
            $results[0].Phase | Should -Be 'Unit'
            $results[0].Result.TestsPassed | Should -Be 10
            $results[0].Result.TestsFailed | Should -Be 2
            $results[0].Duration | Should -Be 3.5
        }
    }
    
    Context 'Phase Summary Logging' {
        It 'Should log phase completion summary' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(
                    @{ Name = 'Module1'; TestPath = 'C:\Tests' },
                    @{ Name = 'Module2'; TestPath = 'C:\Tests' },
                    @{ Name = 'Module3'; TestPath = 'C:\Tests' }
                )
                Configuration = @{ ParallelJobs = 4 }
            }
            
            Mock Invoke-ParallelForEach {
                @(
                    @{ Success = $true; Module = 'Module1'; Phase = 'Unit' },
                    @{ Success = $true; Module = 'Module2'; Phase = 'Unit' },
                    @{ Success = $false; Module = 'Module3'; Phase = 'Unit' }
                )
            } -ModuleName $script:ModuleName
            
            Invoke-ParallelTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Phase Unit completed: 2/3 successful'
            }
        }
    }
    
    Context 'Error Handling in Parallel' {
        It 'Should handle exceptions in parallel execution' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(@{ Name = 'FailModule'; TestPath = 'C:\Tests' })
                Configuration = @{ ParallelJobs = 1 }
            }
            
            Mock Invoke-ParallelForEach {
                @(
                    @{
                        Success = $false
                        Module = 'FailModule'
                        Phase = 'Unit'
                        Error = 'Test execution failed'
                        Duration = 0
                    }
                )
            } -ModuleName $script:ModuleName
            
            $results = Invoke-ParallelTestExecution -TestPlan $testPlan -OutputPath './output'
            
            $results[0].Success | Should -Be $false
            $results[0].Error | Should -Be 'Test execution failed'
        }
    }
    
    Context 'Logging' {
        It 'Should log start of parallel execution' {
            $testPlan = @{
                TestPhases = @()
                Modules = @()
                Configuration = @{ ParallelJobs = 4 }
            }
            
            Invoke-ParallelTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Starting parallel test execution' -and
                $Level -eq 'INFO'
            }
        }
        
        It 'Should log each phase execution' {
            $testPlan = @{
                TestPhases = @('Unit', 'Integration')
                Modules = @(@{ Name = 'Module1'; TestPath = 'C:\Tests' })
                Configuration = @{ ParallelJobs = 2 }
            }
            
            Invoke-ParallelTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Executing test phase: Unit'
            }
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Executing test phase: Integration'
            }
        }
    }
}