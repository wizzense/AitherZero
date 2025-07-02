#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Register-TestProvider'
}

Describe 'TestingFramework.Register-TestProvider' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
        Mock Get-Date { [DateTime]::new(2025, 1, 15, 10, 30, 45) } -ModuleName $script:ModuleName
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    BeforeEach {
        # Clear TestProviders before each test
        InModuleScope $script:ModuleName {
            $script:TestProviders = @{}
        }
    }
    
    Context 'Parameter Validation' {
        It 'Should require ModuleName parameter' {
            { Register-TestProvider -TestTypes @('Unit') -Handler { } } | Should -Throw
        }
        
        It 'Should require TestTypes parameter' {
            { Register-TestProvider -ModuleName 'TestModule' -Handler { } } | Should -Throw
        }
        
        It 'Should require Handler parameter' {
            { Register-TestProvider -ModuleName 'TestModule' -TestTypes @('Unit') } | Should -Throw
        }
        
        It 'Should accept all required parameters' {
            { Register-TestProvider -ModuleName 'TestModule' -TestTypes @('Unit') -Handler { } } | Should -Not -Throw
        }
    }
    
    Context 'Provider Registration' {
        It 'Should register provider with correct structure' {
            $handler = { param($TestData) return "Handled" }
            
            Register-TestProvider -ModuleName 'MyProvider' -TestTypes @('Unit', 'Integration') -Handler $handler
            
            $providers = InModuleScope $script:ModuleName {
                $script:TestProviders
            }
            
            $providers.ContainsKey('MyProvider') | Should -Be $true
            $provider = $providers['MyProvider']
            $provider.TestTypes | Should -HaveCount 2
            $provider.TestTypes | Should -Contain 'Unit'
            $provider.TestTypes | Should -Contain 'Integration'
            $provider.Handler | Should -BeOfType [scriptblock]
            $provider.RegisteredAt | Should -Be ([DateTime]::new(2025, 1, 15, 10, 30, 45))
        }
        
        It 'Should overwrite existing provider with same name' {
            Register-TestProvider -ModuleName 'DuplicateProvider' -TestTypes @('Unit') -Handler { "First" }
            Register-TestProvider -ModuleName 'DuplicateProvider' -TestTypes @('Integration') -Handler { "Second" }
            
            $providers = InModuleScope $script:ModuleName {
                $script:TestProviders
            }
            
            $providers.Keys.Count | Should -Be 1
            $provider = $providers['DuplicateProvider']
            $provider.TestTypes | Should -HaveCount 1
            $provider.TestTypes | Should -Contain 'Integration'
            $provider.TestTypes | Should -Not -Contain 'Unit'
        }
    }
    
    Context 'Test Types Handling' {
        It 'Should accept single test type' {
            Register-TestProvider -ModuleName 'SingleType' -TestTypes @('Unit') -Handler { }
            
            $provider = InModuleScope $script:ModuleName {
                $script:TestProviders['SingleType']
            }
            
            $provider.TestTypes | Should -HaveCount 1
            $provider.TestTypes[0] | Should -Be 'Unit'
        }
        
        It 'Should accept multiple test types' {
            $types = @('Unit', 'Integration', 'E2E', 'Performance', 'Custom')
            
            Register-TestProvider -ModuleName 'MultiType' -TestTypes $types -Handler { }
            
            $provider = InModuleScope $script:ModuleName {
                $script:TestProviders['MultiType']
            }
            
            $provider.TestTypes | Should -HaveCount 5
            $provider.TestTypes | Should -Be $types
        }
        
        It 'Should preserve test type order' {
            $orderedTypes = @('First', 'Second', 'Third')
            
            Register-TestProvider -ModuleName 'OrderedTypes' -TestTypes $orderedTypes -Handler { }
            
            $provider = InModuleScope $script:ModuleName {
                $script:TestProviders['OrderedTypes']
            }
            
            $provider.TestTypes[0] | Should -Be 'First'
            $provider.TestTypes[1] | Should -Be 'Second'
            $provider.TestTypes[2] | Should -Be 'Third'
        }
    }
    
    Context 'Handler Storage' {
        It 'Should store handler scriptblock correctly' {
            $testHandler = {
                param($TestData)
                Write-Host "Processing: $($TestData.Name)"
                return $TestData.Name.ToUpper()
            }
            
            Register-TestProvider -ModuleName 'HandlerTest' -TestTypes @('Unit') -Handler $testHandler
            
            $provider = InModuleScope $script:ModuleName {
                $script:TestProviders['HandlerTest']
            }
            
            $provider.Handler | Should -BeOfType [scriptblock]
            # Test handler execution
            $result = & $provider.Handler @{ Name = 'test' }
            $result | Should -Be 'TEST'
        }
        
        It 'Should handle empty handler scriptblock' {
            Register-TestProvider -ModuleName 'EmptyHandler' -TestTypes @('Unit') -Handler { }
            
            $provider = InModuleScope $script:ModuleName {
                $script:TestProviders['EmptyHandler']
            }
            
            $provider.Handler | Should -BeOfType [scriptblock]
            { & $provider.Handler } | Should -Not -Throw
        }
    }
    
    Context 'Logging' {
        It 'Should log provider registration' {
            Register-TestProvider -ModuleName 'LogTest' -TestTypes @('Unit', 'Integration') -Handler { }
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Registered test provider: LogTest' -and
                $Message -match 'Types: Unit, Integration' -and
                $Level -eq 'INFO'
            }
        }
        
        It 'Should include emoji in log message' {
            Register-TestProvider -ModuleName 'EmojiTest' -TestTypes @('Unit') -Handler { }
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match '🔌'
            }
        }
    }
    
    Context 'Multiple Providers' {
        It 'Should register multiple providers independently' {
            Register-TestProvider -ModuleName 'Provider1' -TestTypes @('Unit') -Handler { "P1" }
            Register-TestProvider -ModuleName 'Provider2' -TestTypes @('Integration') -Handler { "P2" }
            Register-TestProvider -ModuleName 'Provider3' -TestTypes @('E2E') -Handler { "P3" }
            
            $providers = InModuleScope $script:ModuleName {
                $script:TestProviders
            }
            
            $providers.Keys.Count | Should -Be 3
            $providers.ContainsKey('Provider1') | Should -Be $true
            $providers.ContainsKey('Provider2') | Should -Be $true
            $providers.ContainsKey('Provider3') | Should -Be $true
        }
    }
    
    Context 'Edge Cases' {
        It 'Should handle module names with special characters' {
            $specialNames = @(
                'Module-Name',
                'Module.Name',
                'Module_Name',
                'Module@Name',
                'Module:Name'
            )
            
            foreach ($name in $specialNames) {
                { Register-TestProvider -ModuleName $name -TestTypes @('Unit') -Handler { } } | Should -Not -Throw
            }
            
            $providers = InModuleScope $script:ModuleName {
                $script:TestProviders
            }
            
            $providers.Keys.Count | Should -Be $specialNames.Count
        }
        
        It 'Should handle very long module names' {
            $longName = 'A' * 200
            
            { Register-TestProvider -ModuleName $longName -TestTypes @('Unit') -Handler { } } | Should -Not -Throw
        }
    }
}