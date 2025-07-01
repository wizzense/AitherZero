#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/Logging'
    $script:ModuleName = 'Logging'
    $script:FunctionName = 'Stop-PerformanceTrace'
}

Describe 'Logging.Stop-PerformanceTrace' -Tag 'Unit' {
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
            { Stop-PerformanceTrace } | Should -Throw -ErrorId 'ParameterArgumentValidationErrorEmptyStringNotAllowed'
        }
        
        It 'Should accept Name parameter' {
            # Start trace first
            Start-PerformanceTrace -Name "TestOp"
            
            { Stop-PerformanceTrace -Name "TestOp" } | Should -Not -Throw
        }
        
        It 'Should accept OperationName parameter as alias' {
            Start-PerformanceTrace -Name "TestOp"
            
            { Stop-PerformanceTrace -OperationName "TestOp" } | Should -Not -Throw
        }
        
        It 'Should prefer OperationName over Name when both provided' {
            Start-PerformanceTrace -Name "OpName"
            
            Stop-PerformanceTrace -Name "Wrong" -OperationName "OpName"
            
            # Should have stopped OpName, not Wrong
            InModuleScope $script:ModuleName {
                $script:PerformanceCounters.ContainsKey("OpName") | Should -Be $false
            }
        }
        
        It 'Should accept AdditionalContext hashtable' {
            Start-PerformanceTrace -Name "TestOp"
            
            $context = @{ Result = 'Success'; Records = 100 }
            { Stop-PerformanceTrace -Name "TestOp" -AdditionalContext $context } | Should -Not -Throw
        }
    }
    
    Context 'Normal Operation' {
        It 'Should calculate elapsed time correctly' {
            Start-PerformanceTrace -Name "TimedOp"
            Start-Sleep -Milliseconds 100
            
            $result = Stop-PerformanceTrace -Name "TimedOp"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Operation | Should -Be "TimedOp"
            $result.ElapsedMilliseconds | Should -BeGreaterThan 90
            $result.ElapsedMilliseconds | Should -BeLessThan 500
        }
        
        It 'Should remove counter after stopping' {
            Start-PerformanceTrace -Name "RemoveOp"
            Stop-PerformanceTrace -Name "RemoveOp"
            
            InModuleScope $script:ModuleName {
                $script:PerformanceCounters.ContainsKey("RemoveOp") | Should -Be $false
            }
        }
        
        It 'Should return detailed timing information' {
            $startTime = Get-Date
            Start-PerformanceTrace -Name "DetailedOp"
            Start-Sleep -Milliseconds 50
            $result = Stop-PerformanceTrace -Name "DetailedOp"
            
            $result.Operation | Should -Be "DetailedOp"
            $result.StartTime | Should -BeOfType [DateTime]
            $result.EndTime | Should -BeOfType [DateTime]
            $result.ElapsedMilliseconds | Should -BeOfType [Double]
            $result.ElapsedTicks | Should -BeOfType [Int64]
            $result.EndTime | Should -BeGreaterThan $result.StartTime
        }
        
        It 'Should log trace message with duration' {
            Start-PerformanceTrace -Name "LoggedOp"
            Stop-PerformanceTrace -Name "LoggedOp"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -eq "Performance trace completed: LoggedOp" -and
                $Level -eq "TRACE" -and
                $Context.Duration -match '\d+ms'
            }
        }
        
        It 'Should merge original and additional context' {
            $originalContext = @{ User = 'TestUser'; Action = 'Query' }
            $additionalContext = @{ Result = 'Success'; Count = 42 }
            
            Start-PerformanceTrace -Name "ContextOp" -Context $originalContext
            Stop-PerformanceTrace -Name "ContextOp" -AdditionalContext $additionalContext
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.User -eq 'TestUser' -and
                $Context.Action -eq 'Query' -and
                $Context.Result -eq 'Success' -and
                $Context.Count -eq 42
            }
        }
    }
    
    Context 'Performance Tracking Disabled' {
        It 'Should return immediately when performance tracking is disabled' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnablePerformance = $false
            }
            
            $result = Stop-PerformanceTrace -Name "DisabledOp"
            
            $result | Should -BeNullOrEmpty
        }
        
        It 'Should not log when performance tracking is disabled' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnablePerformance = $false
            }
            
            Mock Write-CustomLog { } -ModuleName $script:ModuleName
            
            Stop-PerformanceTrace -Name "NoLogOp"
            
            Should -Not -Invoke Write-CustomLog -ModuleName $script:ModuleName
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle stopping non-existent operation gracefully' {
            { Stop-PerformanceTrace -Name "NonExistentOp" } | Should -Not -Throw
            
            $result = Stop-PerformanceTrace -Name "NonExistentOp"
            $result | Should -BeNullOrEmpty
        }
        
        It 'Should not log for non-existent operation' {
            Mock Write-CustomLog { } -ModuleName $script:ModuleName
            
            Stop-PerformanceTrace -Name "NoSuchOp"
            
            Should -Not -Invoke Write-CustomLog -ModuleName $script:ModuleName
        }
        
        It 'Should handle stopping already stopped operation' {
            Start-PerformanceTrace -Name "DoubleStop"
            Stop-PerformanceTrace -Name "DoubleStop"
            
            # Second stop should not throw
            { Stop-PerformanceTrace -Name "DoubleStop" } | Should -Not -Throw
        }
    }
    
    Context 'Multiple Operations' {
        It 'Should track multiple operations independently' {
            Start-PerformanceTrace -Name "Op1"
            Start-Sleep -Milliseconds 50
            Start-PerformanceTrace -Name "Op2"
            Start-Sleep -Milliseconds 50
            Start-PerformanceTrace -Name "Op3"
            
            $result2 = Stop-PerformanceTrace -Name "Op2"
            
            # Op1 and Op3 should still be running
            InModuleScope $script:ModuleName {
                $script:PerformanceCounters.ContainsKey("Op1") | Should -Be $true
                $script:PerformanceCounters.ContainsKey("Op2") | Should -Be $false
                $script:PerformanceCounters.ContainsKey("Op3") | Should -Be $true
            }
            
            # Op2 should have valid results
            $result2.Operation | Should -Be "Op2"
            $result2.ElapsedMilliseconds | Should -BeGreaterThan 0
        }
        
        It 'Should handle interleaved start/stop operations' {
            Start-PerformanceTrace -Name "A"
            Start-PerformanceTrace -Name "B"
            $resultA = Stop-PerformanceTrace -Name "A"
            Start-PerformanceTrace -Name "C"
            $resultB = Stop-PerformanceTrace -Name "B"
            $resultC = Stop-PerformanceTrace -Name "C"
            
            $resultA.Operation | Should -Be "A"
            $resultB.Operation | Should -Be "B"
            $resultC.Operation | Should -Be "C"
            
            InModuleScope $script:ModuleName {
                $script:PerformanceCounters.Count | Should -Be 0
            }
        }
    }
    
    Context 'Edge Cases' {
        It 'Should handle very short operations' {
            Start-PerformanceTrace -Name "QuickOp"
            $result = Stop-PerformanceTrace -Name "QuickOp"
            
            $result.ElapsedMilliseconds | Should -BeGreaterOrEqual 0
            $result.ElapsedTicks | Should -BeGreaterThan 0
        }
        
        It 'Should handle operations with special characters in names' {
            $specialNames = @(
                "Operation-With-Dashes",
                "Operation.With.Dots",
                "Operation_With_Underscores",
                "Operation With Spaces"
            )
            
            foreach ($name in $specialNames) {
                Start-PerformanceTrace -Name $name
                $result = Stop-PerformanceTrace -Name $name
                
                $result | Should -Not -BeNullOrEmpty
                $result.Operation | Should -Be $name
            }
        }
        
        It 'Should handle null or empty additional context' {
            Start-PerformanceTrace -Name "NullContextOp"
            
            { Stop-PerformanceTrace -Name "NullContextOp" -AdditionalContext $null } | Should -Not -Throw
            
            Start-PerformanceTrace -Name "EmptyContextOp"
            { Stop-PerformanceTrace -Name "EmptyContextOp" -AdditionalContext @{} } | Should -Not -Throw
        }
    }
}