#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'New-TestExecutionPlan'
}

Describe 'TestingFramework.New-TestExecutionPlan' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
        Mock Get-TestConfiguration {
            @{
                Verbosity = 'Normal'
                TimeoutMinutes = 30
                RetryCount = 2
                MockLevel = 'Standard'
                Platform = 'All'
                ParallelJobs = 4
            }
        } -ModuleName $script:ModuleName
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require TestSuite parameter' {
            { New-TestExecutionPlan -TestProfile 'Development' -Modules @() } | Should -Throw
        }
        
        It 'Should require TestProfile parameter' {
            { New-TestExecutionPlan -TestSuite 'All' -Modules @() } | Should -Throw
        }
        
        It 'Should require Modules parameter' {
            { New-TestExecutionPlan -TestSuite 'All' -TestProfile 'Development' } | Should -Throw
        }
        
        It 'Should accept empty Modules array' {
            { New-TestExecutionPlan -TestSuite 'All' -TestProfile 'Development' -Modules @() } | Should -Not -Throw
        }
    }
    
    Context 'Test Plan Creation' {
        It 'Should create plan with basic properties' {
            $modules = @(
                @{ Name = 'Module1'; Path = 'C:\Module1' },
                @{ Name = 'Module2'; Path = 'C:\Module2' }
            )
            
            $result = New-TestExecutionPlan -TestSuite 'Unit' -TestProfile 'CI' -Modules $modules
            
            $result | Should -BeOfType [hashtable]
            $result.TestSuite | Should -Be 'Unit'
            $result.TestProfile | Should -Be 'CI'
            $result.Modules | Should -Be $modules
            $result.StartTime | Should -BeOfType [DateTime]
            $result.Configuration | Should -Not -BeNullOrEmpty
        }
        
        It 'Should set correct test phases for All suite' {
            $result = New-TestExecutionPlan -TestSuite 'All' -TestProfile 'Development' -Modules @()
            
            $result.TestPhases | Should -Be @('Environment', 'Unit', 'Integration', 'Performance')
        }
        
        It 'Should set correct test phases for Unit suite' {
            $result = New-TestExecutionPlan -TestSuite 'Unit' -TestProfile 'Development' -Modules @()
            
            $result.TestPhases | Should -Be @('Unit')
        }
        
        It 'Should set correct test phases for Integration suite' {
            $result = New-TestExecutionPlan -TestSuite 'Integration' -TestProfile 'Development' -Modules @()
            
            $result.TestPhases | Should -Be @('Environment', 'Integration')
        }
        
        It 'Should set correct test phases for Performance suite' {
            $result = New-TestExecutionPlan -TestSuite 'Performance' -TestProfile 'Development' -Modules @()
            
            $result.TestPhases | Should -Be @('Performance')
        }
        
        It 'Should set correct test phases for Modules suite' {
            $result = New-TestExecutionPlan -TestSuite 'Modules' -TestProfile 'Development' -Modules @()
            
            $result.TestPhases | Should -Be @('Unit', 'Integration')
        }
        
        It 'Should set correct test phases for Quick suite' {
            $result = New-TestExecutionPlan -TestSuite 'Quick' -TestProfile 'Development' -Modules @()
            
            $result.TestPhases | Should -Be @('Unit')
        }
        
        It 'Should set correct test phases for NonInteractive suite' {
            $result = New-TestExecutionPlan -TestSuite 'NonInteractive' -TestProfile 'Development' -Modules @()
            
            $result.TestPhases | Should -Be @('Environment', 'Unit', 'NonInteractive')
        }
    }
    
    Context 'Configuration Integration' {
        It 'Should get configuration based on profile' {
            New-TestExecutionPlan -TestSuite 'All' -TestProfile 'Production' -Modules @()
            
            Should -Invoke Get-TestConfiguration -ModuleName $script:ModuleName -ParameterFilter {
                $Profile -eq 'Production'
            }
        }
        
        It 'Should include configuration in plan' {
            $mockConfig = @{ Verbosity = 'Detailed'; TimeoutMinutes = 60 }
            Mock Get-TestConfiguration { $mockConfig } -ModuleName $script:ModuleName
            
            $result = New-TestExecutionPlan -TestSuite 'All' -TestProfile 'Debug' -Modules @()
            
            $result.Configuration | Should -Be $mockConfig
        }
    }
    
    Context 'Logging' {
        It 'Should log test plan creation' {
            New-TestExecutionPlan -TestSuite 'Integration' -TestProfile 'CI' -Modules @()
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Test plan created with phases:' -and
                $Message -match 'Environment, Integration' -and
                $Level -eq 'INFO'
            }
        }
    }
    
    Context 'Start Time' {
        It 'Should set start time to current time' {
            $before = Get-Date
            $result = New-TestExecutionPlan -TestSuite 'All' -TestProfile 'Development' -Modules @()
            $after = Get-Date
            
            $result.StartTime | Should -BeGreaterOrEqual $before
            $result.StartTime | Should -BeLessOrEqual $after
        }
    }
}