#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
}

Describe 'TestingFramework Module Integration Tests' -Tag 'Integration' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Create test module structure
        $script:TestRoot = Join-Path $TestDrive 'TestProject'
        $script:ModulesPath = Join-Path $script:TestRoot 'aither-core/modules'
        $script:TestsPath = Join-Path $script:TestRoot 'tests'
        
        # Create directories
        New-Item -Path $script:ModulesPath -ItemType Directory -Force | Out-Null
        New-Item -Path "$script:TestsPath/unit/modules" -ItemType Directory -Force | Out-Null
        New-Item -Path "$script:TestsPath/integration" -ItemType Directory -Force | Out-Null
        New-Item -Path "$script:TestsPath/results/unified/reports" -ItemType Directory -Force | Out-Null
        
        # Set project root
        InModuleScope $script:ModuleName -ArgumentList $script:TestRoot {
            param($root)
            $script:ProjectRoot = $root
        }
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Module Discovery and Test Execution' {
        BeforeAll {
            # Create a test module
            $testModulePath = Join-Path $script:ModulesPath 'IntegrationTestModule'
            New-Item -Path $testModulePath -ItemType Directory -Force | Out-Null
            
            # Create module script
            $moduleContent = @'
function Get-TestData {
    return "Integration Test Data"
}

Export-ModuleMember -Function Get-TestData
'@
            Set-Content -Path "$testModulePath\IntegrationTestModule.psm1" -Value $moduleContent
            
            # Create unit test for the module
            $testPath = Join-Path $script:TestsPath 'unit/modules/IntegrationTestModule'
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null
            
            $testContent = @'
Describe 'IntegrationTestModule' {
    It 'Should return test data' {
        $true | Should -Be $true
    }
}
'@
            Set-Content -Path "$testPath\IntegrationTestModule.Tests.ps1" -Value $testContent
        }
        
        It 'Should discover and execute tests for real modules' {
            $results = Invoke-UnifiedTestExecution -TestSuite 'Unit' -OutputPath "$script:TestsPath/results/unified"
            
            $results | Should -Not -BeNullOrEmpty
            $moduleResult = $results | Where-Object { $_.Module -eq 'IntegrationTestModule' }
            $moduleResult | Should -Not -BeNullOrEmpty
        }
        
        It 'Should generate reports for executed tests' {
            $results = Invoke-UnifiedTestExecution -TestSuite 'Unit' -OutputPath "$script:TestsPath/results/unified" -GenerateReport
            
            # Check that report files were created
            $reportFiles = Get-ChildItem -Path "$script:TestsPath/results/unified/reports" -Filter "*.json"
            $reportFiles | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Event System Integration' {
        It 'Should publish and retrieve test events' {
            # Clear any existing events
            InModuleScope $script:ModuleName {
                $script:TestEvents = @{}
            }
            
            # Publish test event
            Publish-TestEvent -EventType 'TestStarted' -Data @{ Module = 'TestModule'; Time = Get-Date }
            
            # Retrieve events
            $events = Get-TestEvents -EventType 'TestStarted'
            
            $events | Should -Not -BeNullOrEmpty
            $events[0].EventType | Should -Be 'TestStarted'
            $events[0].Data.Module | Should -Be 'TestModule'
        }
        
        It 'Should handle multiple event types' {
            Publish-TestEvent -EventType 'TestCompleted' -Data @{ Success = $true }
            Publish-TestEvent -EventType 'TestFailed' -Data @{ Error = 'Test error' }
            
            $allEvents = Get-TestEvents
            
            $allEvents.ContainsKey('TestCompleted') | Should -Be $true
            $allEvents.ContainsKey('TestFailed') | Should -Be $true
        }
    }
    
    Context 'Test Provider Registration' {
        It 'Should register and retrieve test providers' {
            # Register a test provider
            Register-TestProvider -ModuleName 'CustomProvider' -TestTypes @('Custom', 'Special') -Handler {
                param($TestData)
                return "Handled by CustomProvider"
            }
            
            # Retrieve registered providers
            $providers = Get-RegisteredTestProviders
            
            $providers.ContainsKey('CustomProvider') | Should -Be $true
            $providers['CustomProvider'].TestTypes | Should -Contain 'Custom'
            $providers['CustomProvider'].TestTypes | Should -Contain 'Special'
        }
        
        It 'Should filter providers by test type' {
            Register-TestProvider -ModuleName 'UnitProvider' -TestTypes @('Unit') -Handler { }
            Register-TestProvider -ModuleName 'IntegrationProvider' -TestTypes @('Integration') -Handler { }
            
            $unitProviders = Get-RegisteredTestProviders -TestType 'Unit'
            
            $unitProviders.Count | Should -BeGreaterOrEqual 1
            $unitProviders.Keys | Should -Contain 'UnitProvider'
            $unitProviders.Keys | Should -Not -Contain 'IntegrationProvider'
        }
    }
    
    Context 'Configuration Profiles' {
        It 'Should apply different configuration profiles correctly' {
            $devConfig = Get-TestConfiguration -Profile 'Development'
            $ciConfig = Get-TestConfiguration -Profile 'CI'
            $prodConfig = Get-TestConfiguration -Profile 'Production'
            
            # Development should be more verbose
            $devConfig.Verbosity | Should -Be 'Detailed'
            $devConfig.TimeoutMinutes | Should -BeLessThan $prodConfig.TimeoutMinutes
            
            # CI should have more retries
            $ciConfig.RetryCount | Should -BeGreaterThan $prodConfig.RetryCount
            
            # Production should have longer timeout
            $prodConfig.TimeoutMinutes | Should -BeGreaterThan $devConfig.TimeoutMinutes
        }
    }
    
    Context 'Parallel vs Sequential Execution' {
        BeforeAll {
            # Create multiple test modules
            @('Module1', 'Module2', 'Module3') | ForEach-Object {
                $modPath = Join-Path $script:ModulesPath $_
                New-Item -Path $modPath -ItemType Directory -Force | Out-Null
                "function Test-$_ { return '$_' }" | Set-Content "$modPath\$_.psm1"
            }
        }
        
        It 'Should execute tests sequentially when parallel is disabled' {
            $startTime = Get-Date
            $results = Invoke-UnifiedTestExecution -TestSuite 'Quick' -Parallel:$false -OutputPath "$script:TestsPath/results"
            $duration = (Get-Date) - $startTime
            
            $results | Should -Not -BeNullOrEmpty
            # Sequential execution exists
        }
        
        It 'Should handle parallel execution when enabled' {
            # Note: Actual parallel execution requires ParallelExecution module
            # This test verifies the framework handles the parallel flag
            $results = Invoke-UnifiedTestExecution -TestSuite 'Quick' -Parallel -OutputPath "$script:TestsPath/results"
            
            $results | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Legacy Function Compatibility' {
        It 'Should maintain compatibility with legacy Invoke-PesterTests' {
            $result = Invoke-PesterTests -OutputPath "$script:TestsPath/results"
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should maintain compatibility with legacy Invoke-SyntaxValidation' {
            $result = Invoke-SyntaxValidation -OutputPath "$script:TestsPath/results"
            
            $result | Should -Not -BeNullOrEmpty
            $result.ContainsKey('TestsRun') | Should -Be $true
        }
        
        It 'Should provide meaningful results from Invoke-PytestTests' {
            $result = Invoke-PytestTests
            
            $result.Message | Should -Be 'Python tests not implemented'
            $result.TestsRun | Should -Be 0
        }
    }
    
    Context 'Error Recovery and Logging' {
        It 'Should continue execution after module failures' {
            # Create a module that will fail to load
            $failModulePath = Join-Path $script:ModulesPath 'FailModule'
            New-Item -Path $failModulePath -ItemType Directory -Force | Out-Null
            'throw "Module load error"' | Set-Content "$failModulePath\FailModule.psm1"
            
            # Should not throw and should continue with other modules
            { Invoke-UnifiedTestExecution -TestSuite 'Quick' -OutputPath "$script:TestsPath/results" } | Should -Not -Throw
        }
        
        It 'Should handle missing test directories gracefully' {
            # Remove test directories
            Remove-Item -Path "$script:TestsPath/unit" -Recurse -Force -ErrorAction SilentlyContinue
            
            { Invoke-UnifiedTestExecution -TestSuite 'Unit' -OutputPath "$script:TestsPath/results" } | Should -Not -Throw
        }
    }
}