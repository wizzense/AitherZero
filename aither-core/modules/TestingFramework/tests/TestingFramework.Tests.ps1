#Requires -Version 7.0

BeforeAll {
    # Import the TestingFramework module
    $modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "TestingFramework.psm1"
    Import-Module $modulePath -Force
}

Describe "TestingFramework Module Tests" {
    Context "Basic Functionality" {
        It "Should load the module successfully" {
            Get-Module TestingFramework | Should -Not -BeNullOrEmpty
        }
        
        It "Should export expected functions" {
            $expectedFunctions = @(
                'Invoke-UnifiedTestExecution',
                'Get-DiscoveredModules',
                'New-TestExecutionPlan',
                'Get-TestConfiguration',
                'Initialize-TestEnvironment',
                'Import-ProjectModule',
                'Test-ModuleStructure'
            )
            
            foreach ($function in $expectedFunctions) {
                Get-Command $function -Module TestingFramework -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Configuration Management" {
        It "Should return valid configuration for Development profile" {
            $config = Get-TestConfiguration -Profile "Development"
            $config | Should -Not -BeNullOrEmpty
            $config.Verbosity | Should -Be "Detailed"
            $config.EnableCoverage | Should -Be $true
        }
        
        It "Should return valid configuration for CI profile" {
            $config = Get-TestConfiguration -Profile "CI"
            $config | Should -Not -BeNullOrEmpty
            $config.TimeoutMinutes | Should -Be 45
            $config.RetryCount | Should -Be 3
        }
        
        It "Should return valid configuration for Production profile" {
            $config = Get-TestConfiguration -Profile "Production"
            $config | Should -Not -BeNullOrEmpty
            $config.CoverageThreshold | Should -Be 90
            $config.MaxMemoryUsageMB | Should -Be 512
        }
    }
    
    Context "Module Discovery" {
        It "Should discover project modules" {
            $modules = Get-DiscoveredModules
            $modules | Should -Not -BeNullOrEmpty
            $modules.Count | Should -BeGreaterThan 0
        }
        
        It "Should include TestingFramework in discovered modules" {
            $modules = Get-DiscoveredModules
            $testingFrameworkModule = $modules | Where-Object { $_.Name -eq "TestingFramework" }
            $testingFrameworkModule | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Test Execution Planning" {
        It "Should create test execution plan for Quick suite" {
            $modules = Get-DiscoveredModules | Select-Object -First 3
            $plan = New-TestExecutionPlan -TestSuite "Quick" -Modules $modules -TestProfile "Development"
            
            $plan | Should -Not -BeNullOrEmpty
            $plan.TestSuite | Should -Be "Quick"
            $plan.TestPhases | Should -Contain "Unit"
        }
        
        It "Should create test execution plan for All suite" {
            $modules = Get-DiscoveredModules | Select-Object -First 3
            $plan = New-TestExecutionPlan -TestSuite "All" -Modules $modules -TestProfile "CI"
            
            $plan | Should -Not -BeNullOrEmpty
            $plan.TestSuite | Should -Be "All"
            $plan.TestPhases | Should -Contain "Environment"
            $plan.TestPhases | Should -Contain "Unit"
            $plan.TestPhases | Should -Contain "Integration"
        }
    }
    
    Context "Test Environment" {
        It "Should initialize test environment" {
            $tempPath = Join-Path $env:TEMP "test-framework-env"
            { Initialize-TestEnvironment -OutputPath $tempPath -TestProfile "Development" } | Should -Not -Throw
            
            Test-Path $tempPath | Should -Be $true
            Test-Path (Join-Path $tempPath "reports") | Should -Be $true
            Test-Path (Join-Path $tempPath "logs") | Should -Be $true
            Test-Path (Join-Path $tempPath "coverage") | Should -Be $true
            
            # Cleanup
            if (Test-Path $tempPath) {
                Remove-Item $tempPath -Recurse -Force
            }
        }
    }
    
    Context "Integration Functions" {
        It "Should provide module structure testing" {
            $results = Test-ModuleStructure
            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -BeGreaterThan 0
            
            # Should have both structure and module loading tests
            $structureTests = $results | Where-Object { $_.Test -like "Project Structure:*" }
            $moduleTests = $results | Where-Object { $_.Test -like "Module Loading:*" }
            
            $structureTests.Count | Should -BeGreaterThan 0
            $moduleTests.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Event System" {
        It "Should publish test events" {
            { Publish-TestEvent -EventType "TestEvent" -Data @{ Message = "Test" } } | Should -Not -Throw
        }
        
        It "Should retrieve published events" {
            Publish-TestEvent -EventType "TestRetrieve" -Data @{ Message = "Retrieve Test" }
            $events = Get-TestEvents -EventType "TestRetrieve"
            $events | Should -Not -BeNullOrEmpty
        }
    }
}