#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Invoke-PytestTests'
}

Describe 'TestingFramework.Invoke-PytestTests' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Legacy Compatibility' {
        It 'Should log Python tests not implemented message' {
            Invoke-PytestTests
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -eq 'Python tests not implemented' -and
                $Level -eq 'INFO'
            }
        }
        
        It 'Should return proper not-implemented structure' {
            $result = Invoke-PytestTests
            
            $result | Should -BeOfType [hashtable]
            $result.TestsRun | Should -Be 0
            $result.TestsPassed | Should -Be 0
            $result.TestsFailed | Should -Be 0
            $result.Message | Should -Be 'Python tests not implemented'
        }
        
        It 'Should accept OutputPath parameter (ignored)' {
            $result = Invoke-PytestTests -OutputPath 'C:\custom\output'
            
            $result.Message | Should -Be 'Python tests not implemented'
        }
        
        It 'Should use default OutputPath when not specified' {
            $result = Invoke-PytestTests
            
            # Even though the parameter has a default, it's not used
            $result.TestsRun | Should -Be 0
        }
        
        It 'Should accept VSCodeIntegration switch (ignored)' {
            $result = Invoke-PytestTests -VSCodeIntegration
            
            $result.Message | Should -Be 'Python tests not implemented'
        }
    }
    
    Context 'Return Value Structure' {
        It 'Should return consistent structure regardless of parameters' {
            $result1 = Invoke-PytestTests
            $result2 = Invoke-PytestTests -OutputPath 'C:\test' -VSCodeIntegration
            
            $result1.Keys | Should -Be $result2.Keys
            $result1.TestsRun | Should -Be $result2.TestsRun
            $result1.TestsPassed | Should -Be $result2.TestsPassed
            $result1.TestsFailed | Should -Be $result2.TestsFailed
            $result1.Message | Should -Be $result2.Message
        }
        
        It 'Should return all expected properties' {
            $result = Invoke-PytestTests
            
            $result | Should -HaveProperty 'TestsRun'
            $result | Should -HaveProperty 'TestsPassed'
            $result | Should -HaveProperty 'TestsFailed'
            $result | Should -HaveProperty 'Message'
        }
        
        It 'Should return zero values for all test counts' {
            $result = Invoke-PytestTests
            
            $result.TestsRun | Should -BeExactly 0
            $result.TestsPassed | Should -BeExactly 0
            $result.TestsFailed | Should -BeExactly 0
        }
    }
    
    Context 'Parameter Handling' {
        It 'Should handle various OutputPath formats' {
            $paths = @(
                'C:\output',
                './tests/results',
                'relative/path',
                'C:\path with spaces\output',
                '\\network\share\output'
            )
            
            foreach ($path in $paths) {
                { Invoke-PytestTests -OutputPath $path } | Should -Not -Throw
            }
        }
        
        It 'Should handle both switch states for VSCodeIntegration' {
            { Invoke-PytestTests -VSCodeIntegration:$true } | Should -Not -Throw
            { Invoke-PytestTests -VSCodeIntegration:$false } | Should -Not -Throw
        }
    }
    
    Context 'Logging Behavior' {
        It 'Should log exactly once per invocation' {
            Invoke-PytestTests
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -Times 1
        }
        
        It 'Should always use INFO level' {
            Invoke-PytestTests -OutputPath 'test' -VSCodeIntegration
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Level -eq 'INFO'
            }
        }
    }
}