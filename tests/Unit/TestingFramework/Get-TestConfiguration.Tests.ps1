#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Get-TestConfiguration'
}

Describe 'TestingFramework.Get-TestConfiguration' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require Profile parameter' {
            { Get-TestConfiguration } | Should -Throw
        }
        
        It 'Should accept valid profile names' {
            $profiles = @('Development', 'CI', 'Production', 'Debug')
            
            foreach ($profile in $profiles) {
                { Get-TestConfiguration -Profile $profile } | Should -Not -Throw
            }
        }
    }
    
    Context 'Base Configuration' {
        It 'Should return base configuration properties' {
            $result = Get-TestConfiguration -Profile 'Development'
            
            $result | Should -BeOfType [hashtable]
            $result.ContainsKey('Verbosity') | Should -Be $true
            $result.ContainsKey('TimeoutMinutes') | Should -Be $true
            $result.ContainsKey('RetryCount') | Should -Be $true
            $result.ContainsKey('MockLevel') | Should -Be $true
            $result.ContainsKey('Platform') | Should -Be $true
            $result.ContainsKey('ParallelJobs') | Should -Be $true
        }
        
        It 'Should set default base values' {
            $result = Get-TestConfiguration -Profile 'Development'
            
            $result.Verbosity | Should -Not -BeNullOrEmpty
            $result.TimeoutMinutes | Should -Be 30
            $result.RetryCount | Should -Be 2
            $result.MockLevel | Should -Be 'Standard'
            $result.Platform | Should -Be 'All'
            $result.ParallelJobs | Should -BeGreaterThan 0
            $result.ParallelJobs | Should -BeLessOrEqual 4
        }
        
        It 'Should calculate ParallelJobs based on processor count' {
            $result = Get-TestConfiguration -Profile 'Development'
            
            $expectedJobs = [Math]::Min(4, [Environment]::ProcessorCount)
            $result.ParallelJobs | Should -Be $expectedJobs
        }
    }
    
    Context 'Development Profile' {
        It 'Should override base values for Development' {
            $result = Get-TestConfiguration -Profile 'Development'
            
            $result.Verbosity | Should -Be 'Detailed'
            $result.TimeoutMinutes | Should -Be 15
            $result.MockLevel | Should -Be 'High'
            # Base values should remain
            $result.RetryCount | Should -Be 2
            $result.Platform | Should -Be 'All'
        }
    }
    
    Context 'CI Profile' {
        It 'Should override base values for CI' {
            $result = Get-TestConfiguration -Profile 'CI'
            
            $result.Verbosity | Should -Be 'Normal'
            $result.TimeoutMinutes | Should -Be 45
            $result.RetryCount | Should -Be 3
            $result.MockLevel | Should -Be 'Standard'
            $result.Platform | Should -Be 'All'
        }
    }
    
    Context 'Production Profile' {
        It 'Should override base values for Production' {
            $result = Get-TestConfiguration -Profile 'Production'
            
            $result.Verbosity | Should -Be 'Normal'
            $result.TimeoutMinutes | Should -Be 60
            $result.RetryCount | Should -Be 1
            $result.MockLevel | Should -Be 'Low'
            $result.Platform | Should -Be 'All'
        }
    }
    
    Context 'Debug Profile' {
        It 'Should override base values for Debug' {
            $result = Get-TestConfiguration -Profile 'Debug'
            
            $result.Verbosity | Should -Be 'Verbose'
            $result.TimeoutMinutes | Should -Be 120
            $result.MockLevel | Should -Be 'None'
            $result.ParallelJobs | Should -Be 1
            # Base values
            $result.RetryCount | Should -Be 2
            $result.Platform | Should -Be 'All'
        }
    }
    
    Context 'Unknown Profile' {
        It 'Should return base configuration for unknown profile' {
            # The function doesn't validate profile names, just uses base if not found
            $result = Get-TestConfiguration -Profile 'UnknownProfile'
            
            # Should get base configuration
            $result.Verbosity | Should -Be 'Normal'
            $result.TimeoutMinutes | Should -Be 30
            $result.RetryCount | Should -Be 2
            $result.MockLevel | Should -Be 'Standard'
        }
    }
    
    Context 'Configuration Independence' {
        It 'Should return independent configuration objects' {
            $config1 = Get-TestConfiguration -Profile 'Development'
            $config2 = Get-TestConfiguration -Profile 'Development'
            
            # Modify first config
            $config1.Verbosity = 'Modified'
            
            # Second config should not be affected
            $config2.Verbosity | Should -Be 'Detailed'
        }
        
        It 'Should not modify base configuration' {
            $config = Get-TestConfiguration -Profile 'Development'
            $config.NewProperty = 'Added'
            
            # Get another config
            $newConfig = Get-TestConfiguration -Profile 'Development'
            
            $newConfig.ContainsKey('NewProperty') | Should -Be $false
        }
    }
}