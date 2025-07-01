#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Invoke-BulletproofTest'
}

Describe 'TestingFramework.Invoke-BulletproofTest' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
        Mock Invoke-UnifiedTestExecution {
            @{
                Success = $true
                TestsRun = 1
                TestsPassed = 1
                TestsFailed = 0
            }
        } -ModuleName $script:ModuleName
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require TestName parameter' {
            { Invoke-BulletproofTest -Type 'Core' } | Should -Throw
        }
        
        It 'Should require Type parameter' {
            { Invoke-BulletproofTest -TestName 'TestName' } | Should -Throw
        }
        
        It 'Should validate Type parameter values' {
            { Invoke-BulletproofTest -TestName 'Test' -Type 'Invalid' } | Should -Throw
        }
        
        It 'Should accept valid Type values' {
            $validTypes = @('Core', 'Module', 'System', 'Performance', 'Integration')
            
            foreach ($type in $validTypes) {
                { Invoke-BulletproofTest -TestName 'Test' -Type $type } | Should -Not -Throw
            }
        }
    }
    
    Context 'Test Execution' {
        It 'Should log test execution start' {
            Invoke-BulletproofTest -TestName 'MyTest' -Type 'Core'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Executing bulletproof test: MyTest \(Core\)' -and
                $Level -eq 'INFO'
            }
        }
        
        It 'Should include emoji in log message' {
            Invoke-BulletproofTest -TestName 'MyTest' -Type 'Core'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match '🎯'
            }
        }
        
        It 'Should delegate to Invoke-UnifiedTestExecution' {
            Invoke-BulletproofTest -TestName 'DelegateTest' -Type 'Module'
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName
        }
        
        It 'Should pass correct parameters to unified execution' {
            Invoke-BulletproofTest -TestName 'ConfigTest' -Type 'System'
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $TestSuite -eq 'System' -and
                $TestName -eq 'ConfigTest' -and
                $Critical -eq $false
            }
        }
        
        It 'Should pass Critical flag when specified' {
            Invoke-BulletproofTest -TestName 'CriticalTest' -Type 'Core' -Critical
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $Critical -eq $true
            }
        }
    }
    
    Context 'Return Values' {
        It 'Should return results from unified execution' {
            Mock Invoke-UnifiedTestExecution {
                @{
                    Success = $true
                    TestsRun = 5
                    TestsPassed = 4
                    TestsFailed = 1
                    Details = 'Test completed'
                }
            } -ModuleName $script:ModuleName
            
            $result = Invoke-BulletproofTest -TestName 'ReturnTest' -Type 'Module'
            
            $result.Success | Should -Be $true
            $result.TestsRun | Should -Be 5
            $result.TestsPassed | Should -Be 4
            $result.TestsFailed | Should -Be 1
            $result.Details | Should -Be 'Test completed'
        }
    }
    
    Context 'Error Handling' {
        It 'Should log error when unified execution fails' {
            Mock Invoke-UnifiedTestExecution { throw 'Test execution failed' } -ModuleName $script:ModuleName
            
            { Invoke-BulletproofTest -TestName 'FailTest' -Type 'Core' } | Should -Throw
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Bulletproof test failed:' -and
                $Message -match 'Test execution failed' -and
                $Level -eq 'ERROR'
            }
        }
        
        It 'Should rethrow exceptions from unified execution' {
            $testError = 'Specific test error'
            Mock Invoke-UnifiedTestExecution { throw $testError } -ModuleName $script:ModuleName
            
            { Invoke-BulletproofTest -TestName 'ErrorTest' -Type 'Core' } | Should -Throw $testError
        }
        
        It 'Should include error emoji in failure log' {
            Mock Invoke-UnifiedTestExecution { throw 'Error' } -ModuleName $script:ModuleName
            
            try {
                Invoke-BulletproofTest -TestName 'EmojiTest' -Type 'Core'
            } catch {
                # Expected to throw
            }
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match '❌' -and
                $Level -eq 'ERROR'
            }
        }
    }
    
    Context 'Type-Specific Testing' {
        It 'Should handle each test type appropriately' {
            $testTypes = @{
                'Core' = 'CoreSystemTest'
                'Module' = 'ModuleValidation'
                'System' = 'SystemIntegrity'
                'Performance' = 'PerformanceBenchmark'
                'Integration' = 'IntegrationScenario'
            }
            
            foreach ($type in $testTypes.Keys) {
                Invoke-BulletproofTest -TestName $testTypes[$type] -Type $type
                
                Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                    $TestSuite -eq $type -and
                    $TestName -eq $testTypes[$type]
                }
            }
        }
    }
    
    Context 'Critical Test Handling' {
        It 'Should handle critical test success' {
            Mock Invoke-UnifiedTestExecution {
                @{ Success = $true; TestsRun = 1; TestsPassed = 1; TestsFailed = 0 }
            } -ModuleName $script:ModuleName
            
            $result = Invoke-BulletproofTest -TestName 'CriticalSuccess' -Type 'Core' -Critical
            
            $result.Success | Should -Be $true
        }
        
        It 'Should handle critical test failure' {
            Mock Invoke-UnifiedTestExecution {
                @{ Success = $false; TestsRun = 1; TestsPassed = 0; TestsFailed = 1 }
            } -ModuleName $script:ModuleName
            
            $result = Invoke-BulletproofTest -TestName 'CriticalFailure' -Type 'Core' -Critical
            
            $result.Success | Should -Be $false
        }
    }
}