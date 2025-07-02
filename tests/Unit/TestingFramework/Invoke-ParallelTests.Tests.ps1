#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Invoke-ParallelTests'
}

Describe 'TestingFramework.Invoke-ParallelTests' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
        Mock Invoke-UnifiedTestExecution {
            @(
                @{
                    Success = $true
                    Module = 'TestModule'
                    Phase = 'All'
                    TestsRun = 20
                    TestsPassed = 18
                    TestsFailed = 2
                }
            )
        } -ModuleName $script:ModuleName
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Legacy Compatibility' {
        It 'Should log deprecation warning' {
            Invoke-ParallelTests
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Legacy parallel test execution' -and
                $Message -match 'redirecting to unified framework' -and
                $Level -eq 'WARN'
            }
        }
        
        It 'Should redirect to Invoke-UnifiedTestExecution' {
            Invoke-ParallelTests
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName
        }
        
        It 'Should use All test suite' {
            Invoke-ParallelTests
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $TestSuite -eq 'All'
            }
        }
        
        It 'Should enable Parallel flag' {
            Invoke-ParallelTests
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $Parallel -eq $true
            }
        }
        
        It 'Should pass OutputPath parameter' {
            Invoke-ParallelTests -OutputPath 'C:\custom\output'
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $OutputPath -eq 'C:\custom\output'
            }
        }
        
        It 'Should use default OutputPath when not specified' {
            Invoke-ParallelTests
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $OutputPath -eq './tests/results'
            }
        }
        
        It 'Should pass VSCodeIntegration switch' {
            Invoke-ParallelTests -VSCodeIntegration
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $VSCodeIntegration -eq $true
            }
        }
        
        It 'Should not pass VSCodeIntegration when not specified' {
            Invoke-ParallelTests
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $VSCodeIntegration -eq $false
            }
        }
    }
    
    Context 'Return Values' {
        It 'Should return results from unified execution' {
            Mock Invoke-UnifiedTestExecution {
                @{ TestsRun = 10; TestsPassed = 9; TestsFailed = 1 }
            } -ModuleName $script:ModuleName
            
            $result = Invoke-ParallelTests
            
            $result.TestsRun | Should -Be 10
            $result.TestsPassed | Should -Be 9
            $result.TestsFailed | Should -Be 1
        }
        
        It 'Should pass through array results' {
            Mock Invoke-UnifiedTestExecution {
                @(
                    @{ Module = 'Module1'; TestsRun = 5 },
                    @{ Module = 'Module2'; TestsRun = 3 }
                )
            } -ModuleName $script:ModuleName
            
            $result = Invoke-ParallelTests
            
            $result | Should -HaveCount 2
            $result[0].Module | Should -Be 'Module1'
            $result[1].Module | Should -Be 'Module2'
        }
    }
    
    Context 'Parameter Combinations' {
        It 'Should handle both parameters together' {
            Invoke-ParallelTests -OutputPath 'C:\test\output' -VSCodeIntegration
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $TestSuite -eq 'All' -and
                $Parallel -eq $true -and
                $OutputPath -eq 'C:\test\output' -and
                $VSCodeIntegration -eq $true
            }
        }
        
        It 'Should handle explicit false VSCodeIntegration' {
            Invoke-ParallelTests -VSCodeIntegration:$false
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $VSCodeIntegration -eq $false
            }
        }
    }
}