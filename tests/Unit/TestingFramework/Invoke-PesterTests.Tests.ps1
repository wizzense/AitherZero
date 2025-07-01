#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Invoke-PesterTests'
}

Describe 'TestingFramework.Invoke-PesterTests' -Tag 'Unit' {
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
                    Phase = 'Unit'
                    TestsRun = 10
                    TestsPassed = 9
                    TestsFailed = 1
                }
            )
        } -ModuleName $script:ModuleName
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Legacy Compatibility' {
        It 'Should log deprecation warning' {
            Invoke-PesterTests
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Legacy Pester test execution' -and
                $Message -match 'redirecting to unified framework' -and
                $Level -eq 'WARN'
            }
        }
        
        It 'Should redirect to Invoke-UnifiedTestExecution' {
            Invoke-PesterTests
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName
        }
        
        It 'Should use Unit test suite' {
            Invoke-PesterTests
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $TestSuite -eq 'Unit'
            }
        }
        
        It 'Should pass OutputPath parameter' {
            Invoke-PesterTests -OutputPath 'C:\custom\output'
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $OutputPath -eq 'C:\custom\output'
            }
        }
        
        It 'Should use default OutputPath when not specified' {
            Invoke-PesterTests
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $OutputPath -eq './tests/results'
            }
        }
        
        It 'Should pass VSCodeIntegration switch' {
            Invoke-PesterTests -VSCodeIntegration
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $VSCodeIntegration -eq $true
            }
        }
        
        It 'Should not pass VSCodeIntegration when not specified' {
            Invoke-PesterTests
            
            Should -Invoke Invoke-UnifiedTestExecution -ModuleName $script:ModuleName -ParameterFilter {
                $VSCodeIntegration -eq $false
            }
        }
        
        It 'Should return results from unified execution' {
            Mock Invoke-UnifiedTestExecution {
                @{ TestsRun = 5; TestsPassed = 5; TestsFailed = 0 }
            } -ModuleName $script:ModuleName
            
            $result = Invoke-PesterTests
            
            $result.TestsRun | Should -Be 5
            $result.TestsPassed | Should -Be 5
            $result.TestsFailed | Should -Be 0
        }
    }
}