#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Invoke-UnifiedTestExecution'
}

Describe 'TestingFramework.Invoke-UnifiedTestExecution' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
        Mock Initialize-TestEnvironment { } -ModuleName $script:ModuleName
        Mock Get-DiscoveredModules { 
            @(
                @{
                    Name = 'TestModule1'
                    Path = 'C:\modules\TestModule1'
                    ScriptPath = 'C:\modules\TestModule1\TestModule1.psm1'
                    TestPath = 'C:\tests\TestModule1'
                },
                @{
                    Name = 'TestModule2'
                    Path = 'C:\modules\TestModule2'
                    ScriptPath = 'C:\modules\TestModule2\TestModule2.psm1'
                    TestPath = 'C:\tests\TestModule2'
                }
            )
        } -ModuleName $script:ModuleName
        Mock New-TestExecutionPlan {
            @{
                TestSuite = $TestSuite
                TestProfile = $TestProfile
                StartTime = Get-Date
                Modules = $Modules
                TestPhases = @('Unit')
                Configuration = @{ Verbosity = 'Normal' }
            }
        } -ModuleName $script:ModuleName
        Mock Invoke-SequentialTestExecution {
            @(
                @{
                    Success = $true
                    Module = 'TestModule1'
                    Phase = 'Unit'
                    Result = @{ TestsPassed = 10; TestsFailed = 0 }
                    Duration = 5
                }
            )
        } -ModuleName $script:ModuleName
        Mock Invoke-ParallelTestExecution {
            @(
                @{
                    Success = $true
                    Module = 'TestModule1'
                    Phase = 'Unit'
                    Result = @{ TestsPassed = 10; TestsFailed = 0 }
                    Duration = 3
                }
            )
        } -ModuleName $script:ModuleName
        Mock New-TestReport { 'C:\reports\test-report.html' } -ModuleName $script:ModuleName
        Mock Export-VSCodeTestResults { } -ModuleName $script:ModuleName
        Mock Publish-TestEvent { } -ModuleName $script:ModuleName
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should accept valid TestSuite values' {
            $validSuites = @('All', 'Unit', 'Integration', 'Performance', 'Modules', 'Quick', 'NonInteractive')
            
            foreach ($suite in $validSuites) {
                { Invoke-UnifiedTestExecution -TestSuite $suite } | Should -Not -Throw
            }
        }
        
        It 'Should accept valid TestProfile values' {
            $validProfiles = @('Development', 'CI', 'Production', 'Debug')
            
            foreach ($profile in $validProfiles) {
                { Invoke-UnifiedTestExecution -TestProfile $profile } | Should -Not -Throw
            }
        }
        
        It 'Should accept empty Modules array' {
            { Invoke-UnifiedTestExecution -Modules @() } | Should -Not -Throw
        }
        
        It 'Should accept specific module names' {
            { Invoke-UnifiedTestExecution -Modules @('Module1', 'Module2') } | Should -Not -Throw
        }
        
        It 'Should accept all optional switches' {
            { Invoke-UnifiedTestExecution -Parallel -VSCodeIntegration -GenerateReport } | Should -Not -Throw
        }
    }
    
    Context 'Normal Operation' {
        It 'Should initialize test environment' {
            Invoke-UnifiedTestExecution
            
            Should -Invoke Initialize-TestEnvironment -ModuleName $script:ModuleName -ParameterFilter {
                $OutputPath -eq './tests/results/unified' -and
                $TestProfile -eq 'Development'
            }
        }
        
        It 'Should discover modules when none specified' {
            Invoke-UnifiedTestExecution
            
            Should -Invoke Get-DiscoveredModules -ModuleName $script:ModuleName -ParameterFilter {
                $SpecificModules.Count -eq 0
            }
        }
        
        It 'Should pass specific modules to discovery' {
            Invoke-UnifiedTestExecution -Modules @('TestModule')
            
            Should -Invoke Get-DiscoveredModules -ModuleName $script:ModuleName -ParameterFilter {
                $SpecificModules -contains 'TestModule'
            }
        }
        
        It 'Should create test execution plan' {
            Mock Get-DiscoveredModules { @(@{ Name = 'Test' }) } -ModuleName $script:ModuleName
            
            Invoke-UnifiedTestExecution -TestSuite 'Unit' -TestProfile 'CI'
            
            Should -Invoke New-TestExecutionPlan -ModuleName $script:ModuleName -ParameterFilter {
                $TestSuite -eq 'Unit' -and
                $TestProfile -eq 'CI' -and
                $Modules.Count -eq 1
            }
        }
        
        It 'Should execute tests sequentially by default' {
            Invoke-UnifiedTestExecution
            
            Should -Invoke Invoke-SequentialTestExecution -ModuleName $script:ModuleName
            Should -Not -Invoke Invoke-ParallelTestExecution -ModuleName $script:ModuleName
        }
        
        It 'Should execute tests in parallel when specified' {
            Invoke-UnifiedTestExecution -Parallel
            
            Should -Invoke Invoke-ParallelTestExecution -ModuleName $script:ModuleName
            Should -Not -Invoke Invoke-SequentialTestExecution -ModuleName $script:ModuleName
        }
        
        It 'Should return test results' {
            $results = Invoke-UnifiedTestExecution
            
            $results | Should -Not -BeNullOrEmpty
            $results | Should -BeOfType [array]
            $results[0].Success | Should -Be $true
        }
    }
    
    Context 'Report Generation' {
        It 'Should generate report when requested' {
            Invoke-UnifiedTestExecution -GenerateReport
            
            Should -Invoke New-TestReport -ModuleName $script:ModuleName -ParameterFilter {
                $Results -ne $null -and
                $OutputPath -eq './tests/results/unified' -and
                $TestSuite -eq 'All'
            }
        }
        
        It 'Should not generate report by default' {
            Mock New-TestReport { } -ModuleName $script:ModuleName
            
            Invoke-UnifiedTestExecution
            
            Should -Not -Invoke New-TestReport -ModuleName $script:ModuleName
        }
        
        It 'Should log report path when generated' {
            Invoke-UnifiedTestExecution -GenerateReport
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Test report generated' -and
                $Level -eq 'SUCCESS'
            }
        }
    }
    
    Context 'VS Code Integration' {
        It 'Should export VS Code results when enabled' {
            Invoke-UnifiedTestExecution -VSCodeIntegration
            
            Should -Invoke Export-VSCodeTestResults -ModuleName $script:ModuleName -ParameterFilter {
                $Results -ne $null -and
                $OutputPath -eq './tests/results/unified'
            }
        }
        
        It 'Should not export VS Code results by default' {
            Mock Export-VSCodeTestResults { } -ModuleName $script:ModuleName
            
            Invoke-UnifiedTestExecution
            
            Should -Not -Invoke Export-VSCodeTestResults -ModuleName $script:ModuleName
        }
    }
    
    Context 'Event Publishing' {
        It 'Should publish completion event' {
            $startTime = Get-Date
            Mock New-TestExecutionPlan {
                @{
                    TestSuite = 'All'
                    StartTime = $startTime
                    TestPhases = @('Unit')
                    Configuration = @{}
                    Modules = @()
                }
            } -ModuleName $script:ModuleName
            
            Invoke-UnifiedTestExecution
            
            Should -Invoke Publish-TestEvent -ModuleName $script:ModuleName -ParameterFilter {
                $EventType -eq 'TestExecutionCompleted' -and
                $Data.TestSuite -eq 'All' -and
                $Data.Results -ne $null
            }
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle test execution failures' {
            Mock Invoke-SequentialTestExecution { throw "Test execution failed" } -ModuleName $script:ModuleName
            
            { Invoke-UnifiedTestExecution } | Should -Throw "Test execution failed"
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Test execution failed' -and
                $Level -eq 'ERROR'
            }
        }
        
        It 'Should handle empty module discovery' {
            Mock Get-DiscoveredModules { @() } -ModuleName $script:ModuleName
            
            { Invoke-UnifiedTestExecution } | Should -Not -Throw
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Discovered modules: 0'
            }
        }
    }
    
    Context 'Logging' {
        It 'Should log start of execution' {
            Invoke-UnifiedTestExecution -TestSuite 'Unit' -TestProfile 'CI' -Parallel
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Starting Unified Test Execution'
            }
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Test Suite: Unit' -and
                $Message -match 'Profile: CI' -and
                $Message -match 'Parallel: True'
            }
        }
        
        It 'Should log completion' {
            Invoke-UnifiedTestExecution
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Unified Test Execution completed' -and
                $Level -eq 'SUCCESS'
            }
        }
    }
    
    Context 'Output Path Handling' {
        It 'Should use default output path' {
            Invoke-UnifiedTestExecution
            
            Should -Invoke Initialize-TestEnvironment -ModuleName $script:ModuleName -ParameterFilter {
                $OutputPath -eq './tests/results/unified'
            }
        }
        
        It 'Should use custom output path' {
            Invoke-UnifiedTestExecution -OutputPath 'C:\custom\output'
            
            Should -Invoke Initialize-TestEnvironment -ModuleName $script:ModuleName -ParameterFilter {
                $OutputPath -eq 'C:\custom\output'
            }
        }
    }
}