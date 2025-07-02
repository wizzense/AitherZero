#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Get-RegisteredTestProviders'
}

Describe 'TestingFramework.Get-RegisteredTestProviders' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    BeforeEach {
        # Set up test providers
        InModuleScope $script:ModuleName {
            $script:TestProviders = @{
                'UnitProvider' = @{
                    TestTypes = @('Unit')
                    Handler = { "Unit tests" }
                    RegisteredAt = Get-Date
                }
                'IntegrationProvider' = @{
                    TestTypes = @('Integration')
                    Handler = { "Integration tests" }
                    RegisteredAt = Get-Date
                }
                'MultiProvider' = @{
                    TestTypes = @('Unit', 'Integration', 'E2E')
                    Handler = { "Multiple test types" }
                    RegisteredAt = Get-Date
                }
                'PerformanceProvider' = @{
                    TestTypes = @('Performance')
                    Handler = { "Performance tests" }
                    RegisteredAt = Get-Date
                }
            }
        }
    }
    
    Context 'Getting All Providers' {
        It 'Should return all providers when TestType not specified' {
            $providers = Get-RegisteredTestProviders
            
            $providers | Should -BeOfType [hashtable]
            $providers.Keys.Count | Should -Be 4
            $providers.ContainsKey('UnitProvider') | Should -Be $true
            $providers.ContainsKey('IntegrationProvider') | Should -Be $true
            $providers.ContainsKey('MultiProvider') | Should -Be $true
            $providers.ContainsKey('PerformanceProvider') | Should -Be $true
        }
        
        It 'Should preserve provider structure when returning all' {
            $providers = Get-RegisteredTestProviders
            
            $unitProvider = $providers['UnitProvider']
            $unitProvider.TestTypes | Should -HaveCount 1
            $unitProvider.TestTypes[0] | Should -Be 'Unit'
            $unitProvider.Handler | Should -BeOfType [scriptblock]
            $unitProvider.RegisteredAt | Should -BeOfType [DateTime]
        }
    }
    
    Context 'Filtering by TestType' {
        It 'Should return only providers supporting specified TestType' {
            $unitProviders = Get-RegisteredTestProviders -TestType 'Unit'
            
            $unitProviders | Should -BeOfType [System.Collections.DictionaryEntry[]]
            $unitProviders | Should -HaveCount 2 # UnitProvider and MultiProvider
            
            $providerNames = $unitProviders | ForEach-Object { $_.Key }
            $providerNames | Should -Contain 'UnitProvider'
            $providerNames | Should -Contain 'MultiProvider'
            $providerNames | Should -Not -Contain 'IntegrationProvider'
            $providerNames | Should -Not -Contain 'PerformanceProvider'
        }
        
        It 'Should return providers for Integration TestType' {
            $integrationProviders = Get-RegisteredTestProviders -TestType 'Integration'
            
            $integrationProviders | Should -HaveCount 2 # IntegrationProvider and MultiProvider
            
            $providerNames = $integrationProviders | ForEach-Object { $_.Key }
            $providerNames | Should -Contain 'IntegrationProvider'
            $providerNames | Should -Contain 'MultiProvider'
        }
        
        It 'Should return single provider for unique TestType' {
            $performanceProviders = Get-RegisteredTestProviders -TestType 'Performance'
            
            $performanceProviders | Should -HaveCount 1
            $performanceProviders[0].Key | Should -Be 'PerformanceProvider'
        }
        
        It 'Should return empty array for non-existent TestType' {
            $noProviders = Get-RegisteredTestProviders -TestType 'NonExistent'
            
            $noProviders | Should -BeNullOrEmpty
        }
    }
    
    Context 'Empty Provider Store' {
        It 'Should handle empty provider store gracefully' {
            InModuleScope $script:ModuleName {
                $script:TestProviders = @{}
            }
            
            $allProviders = Get-RegisteredTestProviders
            
            $allProviders | Should -BeOfType [hashtable]
            $allProviders.Keys.Count | Should -Be 0
        }
        
        It 'Should return empty array for TestType filter on empty store' {
            InModuleScope $script:ModuleName {
                $script:TestProviders = @{}
            }
            
            $providers = Get-RegisteredTestProviders -TestType 'Unit'
            
            $providers | Should -BeNullOrEmpty
        }
    }
    
    Context 'Case Sensitivity' {
        It 'Should be case-sensitive for TestType filtering' {
            InModuleScope $script:ModuleName {
                $script:TestProviders = @{
                    'CaseProvider' = @{
                        TestTypes = @('Unit', 'unit', 'UNIT')
                        Handler = { }
                        RegisteredAt = Get-Date
                    }
                }
            }
            
            $unitProviders = Get-RegisteredTestProviders -TestType 'Unit'
            $lowerProviders = Get-RegisteredTestProviders -TestType 'unit'
            $upperProviders = Get-RegisteredTestProviders -TestType 'UNIT'
            
            $unitProviders | Should -HaveCount 1
            $lowerProviders | Should -HaveCount 1
            $upperProviders | Should -HaveCount 1
        }
    }
    
    Context 'Return Value Structure' {
        It 'Should preserve provider data structure when filtering' {
            $e2eProviders = Get-RegisteredTestProviders -TestType 'E2E'
            
            $e2eProviders | Should -HaveCount 1
            $provider = $e2eProviders[0]
            
            $provider.Key | Should -Be 'MultiProvider'
            $provider.Value.TestTypes | Should -HaveCount 3
            $provider.Value.Handler | Should -BeOfType [scriptblock]
            $provider.Value.RegisteredAt | Should -BeOfType [DateTime]
        }
        
        It 'Should allow enumeration of filtered results' {
            $providers = Get-RegisteredTestProviders -TestType 'Unit'
            
            $count = 0
            foreach ($provider in $providers) {
                $count++
                $provider | Should -HaveProperty 'Key'
                $provider | Should -HaveProperty 'Value'
                $provider.Value | Should -HaveProperty 'TestTypes'
                $provider.Value | Should -HaveProperty 'Handler'
                $provider.Value | Should -HaveProperty 'RegisteredAt'
            }
            
            $count | Should -Be 2
        }
    }
    
    Context 'Complex Filtering Scenarios' {
        It 'Should handle providers with many TestTypes correctly' {
            InModuleScope $script:ModuleName {
                $script:TestProviders = @{
                    'MegaProvider' = @{
                        TestTypes = @('Unit', 'Integration', 'E2E', 'Performance', 'Security', 'Smoke', 'Regression')
                        Handler = { }
                        RegisteredAt = Get-Date
                    }
                }
            }
            
            $testTypes = @('Unit', 'Integration', 'E2E', 'Performance', 'Security', 'Smoke', 'Regression')
            
            foreach ($testType in $testTypes) {
                $providers = Get-RegisteredTestProviders -TestType $testType
                $providers | Should -HaveCount 1
                $providers[0].Key | Should -Be 'MegaProvider'
            }
        }
    }
}