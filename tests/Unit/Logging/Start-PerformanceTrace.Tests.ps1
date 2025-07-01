#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/Logging'
    $script:ModuleName = 'Logging'
    $script:FunctionName = 'Start-PerformanceTrace'
}

Describe 'Logging.Start-PerformanceTrace' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Initialize logging
        Initialize-LoggingSystem -EnablePerformance -Force
        
        # Mock Write-CustomLog to prevent actual logging
        Mock Write-CustomLog { } -ModuleName $script:ModuleName
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    BeforeEach {
        # Clear performance counters
        InModuleScope $script:ModuleName {
            $script:PerformanceCounters = @{}
        }
    }
    
    Context 'Parameter Validation' {
        It 'Should require Name parameter' {
            { Start-PerformanceTrace } | Should -Throw -ErrorId 'ParameterArgumentValidationErrorEmptyStringNotAllowed'
        }
        
        It 'Should accept Name parameter' {
            { Start-PerformanceTrace -Name "TestOperation" } | Should -Not -Throw
        }
        
        It 'Should accept OperationName parameter as alias' {
            { Start-PerformanceTrace -OperationName "TestOperation" } | Should -Not -Throw
        }
        
        It 'Should prefer OperationName over Name when both provided' {
            Start-PerformanceTrace -Name "Name" -OperationName "OpName"
            
            InModuleScope $script:ModuleName {
                $script:PerformanceCounters.ContainsKey("OpName") | Should -Be $true
                $script:PerformanceCounters.ContainsKey("Name") | Should -Be $false
            }
        }
        
        It 'Should accept Context hashtable' {
            $context = @{ User = 'TestUser'; Action = 'TestAction' }
            { Start-PerformanceTrace -Name "Test" -Context $context } | Should -Not -Throw
        }
    }
    
    Context 'Normal Operation' {
        It 'Should create performance counter entry' {
            Start-PerformanceTrace -Name "TestOperation"
            
            InModuleScope $script:ModuleName {
                $script:PerformanceCounters.ContainsKey("TestOperation") | Should -Be $true
                $script:PerformanceCounters["TestOperation"] | Should -Not -BeNullOrEmpty
            }
        }
        
        It 'Should store start time' {
            $beforeTime = Get-Date
            Start-PerformanceTrace -Name "TestOp"
            $afterTime = Get-Date
            
            InModuleScope $script:ModuleName {
                $startTime = $script:PerformanceCounters["TestOp"].StartTime
                $startTime | Should -BeGreaterOrEqual $using:beforeTime
                $startTime | Should -BeLessOrEqual $using:afterTime
            }
        }
        
        It 'Should store context information' {
            $context = @{ Database = 'TestDB'; Query = 'SELECT *' }
            Start-PerformanceTrace -Name "DbQuery" -Context $context
            
            InModuleScope $script:ModuleName {
                $storedContext = $script:PerformanceCounters["DbQuery"].Context
                $storedContext.Database | Should -Be 'TestDB'
                $storedContext.Query | Should -Be 'SELECT *'
            }
        }
        
        It 'Should log trace message when trace is enabled' {
            Start-PerformanceTrace -Name "TracedOp"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -eq "Performance trace started: TracedOp" -and
                $Level -eq "TRACE"
            }
        }
        
        It 'Should include context in trace log' {
            $context = @{ Module = 'Test'; Version = '1.0' }
            Start-PerformanceTrace -Name "ContextOp" -Context $context
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Module -eq 'Test' -and
                $Context.Version -eq '1.0'
            }
        }
    }
    
    Context 'Performance Tracking Disabled' {
        It 'Should not create counter when performance tracking is disabled' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnablePerformance = $false
            }
            
            Start-PerformanceTrace -Name "DisabledOp"
            
            InModuleScope $script:ModuleName {
                $script:PerformanceCounters.Count | Should -Be 0
            }
        }
        
        It 'Should not log when performance tracking is disabled' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnablePerformance = $false
            }
            
            Mock Write-CustomLog { } -ModuleName $script:ModuleName
            
            Start-PerformanceTrace -Name "NoLogOp"
            
            Should -Not -Invoke Write-CustomLog -ModuleName $script:ModuleName
        }
    }
    
    Context 'Multiple Operations' {
        It 'Should track multiple operations simultaneously' {
            Start-PerformanceTrace -Name "Op1"
            Start-PerformanceTrace -Name "Op2"
            Start-PerformanceTrace -Name "Op3"
            
            InModuleScope $script:ModuleName {
                $script:PerformanceCounters.Count | Should -Be 3
                $script:PerformanceCounters.ContainsKey("Op1") | Should -Be $true
                $script:PerformanceCounters.ContainsKey("Op2") | Should -Be $true
                $script:PerformanceCounters.ContainsKey("Op3") | Should -Be $true
            }
        }
        
        It 'Should overwrite existing operation with same name' {
            $context1 = @{ Run = 1 }
            $context2 = @{ Run = 2 }
            
            Start-PerformanceTrace -Name "DuplicateOp" -Context $context1
            Start-Sleep -Milliseconds 100
            Start-PerformanceTrace -Name "DuplicateOp" -Context $context2
            
            InModuleScope $script:ModuleName {
                $script:PerformanceCounters.Count | Should -Be 1
                $script:PerformanceCounters["DuplicateOp"].Context.Run | Should -Be 2
            }
        }
    }
    
    Context 'Edge Cases' {
        It 'Should handle empty context' {
            { Start-PerformanceTrace -Name "EmptyContext" -Context @{} } | Should -Not -Throw
        }
        
        It 'Should handle null context' {
            { Start-PerformanceTrace -Name "NullContext" -Context $null } | Should -Not -Throw
        }
        
        It 'Should handle operation names with special characters' {
            $specialNames = @(
                "Operation-With-Dashes",
                "Operation.With.Dots",
                "Operation_With_Underscores",
                "Operation With Spaces",
                "Operation/With/Slashes"
            )
            
            foreach ($name in $specialNames) {
                { Start-PerformanceTrace -Name $name } | Should -Not -Throw
                
                InModuleScope $script:ModuleName -ArgumentList $name {
                    param($name)
                    $script:PerformanceCounters.ContainsKey($name) | Should -Be $true
                }
            }
        }
    }
}