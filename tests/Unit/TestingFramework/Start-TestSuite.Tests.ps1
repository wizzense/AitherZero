#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Start-TestSuite'
}

Describe 'TestingFramework.Start-TestSuite' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
        Mock Invoke-UnifiedTestExecution {
            @{
                Success = $true
                TestsRun = 10
                TestsPassed = 10
                TestsFailed = 0
            }
        } -ModuleName $script:ModuleName
        
        # Mock processor count for consistent testing
        Mock Get-Variable { 
            [PSCustomObject]@{ Value = 8 } 
        } -ModuleName $script:ModuleName -ParameterFilter { $Name -eq 'env:ProcessorCount' }
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require SuiteName parameter' {
            { Start-TestSuite } | Should -Throw
        }
        
        It 'Should accept SuiteName without Configuration' {
            { Start-TestSuite -SuiteName 'TestSuite' } | Should -Not -Throw
        }
        
        It 'Should accept SuiteName with Configuration' {
            $config = @{ Verbosity = 'Detailed' }
            { Start-TestSuite -SuiteName 'TestSuite' -Configuration $config } | Should -Not -Throw
        }
    }
    
    Context 'Default Configuration' {
        It 'Should use default configuration when not specified' {
            # We can't directly inspect the default values used internally,
            # but we can verify the function executes successfully
            { Start-TestSuite -SuiteName 'DefaultConfig' } | Should -Not -Throw
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $TestSuite -eq 'DefaultConfig'
            }
        }
        
        It 'Should log test suite start' {
            Start-TestSuite -SuiteName 'LogTest'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Starting test suite: LogTest' -and
                $Level -eq 'INFO'
            }
        }
        
        It 'Should include emoji in log message' {
            Start-TestSuite -SuiteName 'EmojiTest'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match '🚀'
            }
        }
    }
    
    Context 'Custom Configuration' {
        It 'Should pass custom configuration to unified execution' {
            $customConfig = @{
                Verbosity = 'Detailed'
                TimeoutMinutes = 60
                RetryCount = 3
                MockLevel = 'Full'
                Platform = 'Windows'
                ParallelJobs = 2
            }
            
            Start-TestSuite -SuiteName 'CustomConfig' -Configuration $customConfig
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $TestSuite -eq 'CustomConfig' -and
                $Configuration -ne $null -and
                $Configuration.Verbosity -eq 'Detailed' -and
                $Configuration.TimeoutMinutes -eq 60
            }
        }
        
        It 'Should handle empty configuration hashtable' {
            Start-TestSuite -SuiteName 'EmptyConfig' -Configuration @{}
            
            # With empty config, it should not pass Configuration parameter
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $TestSuite -eq 'EmptyConfig' -and
                $Configuration -eq $null
            }
        }
        
        It 'Should handle partial configuration' {
            $partialConfig = @{
                Verbosity = 'Quiet'
                RetryCount = 5
            }
            
            Start-TestSuite -SuiteName 'PartialConfig' -Configuration $partialConfig
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $TestSuite -eq 'PartialConfig' -and
                $Configuration.Verbosity -eq 'Quiet' -and
                $Configuration.RetryCount -eq 5
            }
        }
    }
    
    Context 'Return Values' {
        It 'Should return results from unified execution' {
            Mock Invoke-UnifiedTestExecution {
                @{
                    Success = $true
                    SuiteName = 'ReturnTest'
                    TestsRun = 15
                    TestsPassed = 14
                    TestsFailed = 1
                    Duration = 30.5
                }
            } -ModuleName $script:ModuleName
            
            $result = Start-TestSuite -SuiteName 'ReturnTest'
            
            $result.Success | Should -Be $true
            $result.SuiteName | Should -Be 'ReturnTest'
            $result.TestsRun | Should -Be 15
            $result.TestsPassed | Should -Be 14
            $result.TestsFailed | Should -Be 1
            $result.Duration | Should -Be 30.5
        }
        
        It 'Should pass through array results' {
            Mock Invoke-UnifiedTestExecution {
                @(
                    @{ Module = 'Module1'; Success = $true },
                    @{ Module = 'Module2'; Success = $false }
                )
            } -ModuleName $script:ModuleName
            
            $result = Start-TestSuite -SuiteName 'ArrayTest'
            
            $result | Should -HaveCount 2
            $result[0].Module | Should -Be 'Module1'
            $result[0].Success | Should -Be $true
            $result[1].Module | Should -Be 'Module2'
            $result[1].Success | Should -Be $false
        }
    }
    
    Context 'Error Handling' {
        It 'Should log error when unified execution fails' {
            Mock Invoke-UnifiedTestExecution { throw 'Suite execution failed' } -ModuleName $script:ModuleName
            
            { Start-TestSuite -SuiteName 'FailTest' } | Should -Throw
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Test suite start failed:' -and
                $Message -match 'Suite execution failed' -and
                $Level -eq 'ERROR'
            }
        }
        
        It 'Should rethrow exceptions from unified execution' {
            $testError = 'Specific suite error'
            Mock Invoke-UnifiedTestExecution { throw $testError } -ModuleName $script:ModuleName
            
            { Start-TestSuite -SuiteName 'ErrorTest' } | Should -Throw $testError
        }
        
        It 'Should include error emoji in failure log' {
            Mock Invoke-UnifiedTestExecution { throw 'Error' } -ModuleName $script:ModuleName
            
            try {
                Start-TestSuite -SuiteName 'EmojiErrorTest'
            } catch {
                # Expected to throw
            }
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match '❌' -and
                $Level -eq 'ERROR'
            }
        }
    }
    
    Context 'Suite Name Variations' {
        It 'Should handle various suite name formats' {
            $suiteNames = @(
                'SimpleTest',
                'Test-Suite',
                'Test.Suite',
                'Test_Suite',
                'Test Suite With Spaces',
                'Test123',
                '123Test'
            )
            
            foreach ($suiteName in $suiteNames) {
                { Start-TestSuite -SuiteName $suiteName } | Should -Not -Throw
                
                Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                    $TestSuite -eq $suiteName
                }
            }
        }
    }
    
    Context 'Configuration Edge Cases' {
        It 'Should handle configuration with invalid keys' {
            $invalidConfig = @{
                Verbosity = 'Normal'
                InvalidKey = 'InvalidValue'
                AnotherInvalidKey = 123
            }
            
            { Start-TestSuite -SuiteName 'InvalidKeys' -Configuration $invalidConfig } | Should -Not -Throw
        }
        
        It 'Should handle configuration with null values' {
            $nullConfig = @{
                Verbosity = $null
                TimeoutMinutes = $null
                RetryCount = 2
            }
            
            { Start-TestSuite -SuiteName 'NullValues' -Configuration $nullConfig } | Should -Not -Throw
        }
    }
}