#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/Logging'
    $script:ModuleName = 'Logging'
    $script:FunctionName = 'Write-TraceLog'
}

Describe 'Logging.Write-TraceLog' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Store original configuration
        $script:OriginalConfig = InModuleScope $script:ModuleName {
            $script:LoggingConfig.Clone()
        }
        
        # Initialize logging with trace enabled
        Initialize-LoggingSystem -EnableTrace -Force
        
        # Mock Write-CustomLog to capture calls
        Mock Write-CustomLog { } -ModuleName $script:ModuleName
    }
    
    AfterAll {
        # Restore original configuration
        InModuleScope $script:ModuleName {
            $script:LoggingConfig = $using:OriginalConfig
        }
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require Message parameter' {
            { Write-TraceLog } | Should -Throw -ErrorId 'ParameterArgumentValidationErrorEmptyStringNotAllowed'
        }
        
        It 'Should accept Message parameter' {
            { Write-TraceLog -Message "Test trace" } | Should -Not -Throw
        }
        
        It 'Should accept Context hashtable' {
            $context = @{ Component = 'Test'; State = 'Running' }
            { Write-TraceLog -Message "Trace" -Context $context } | Should -Not -Throw
        }
        
        It 'Should accept Category parameter' {
            { Write-TraceLog -Message "Trace" -Category "Database" } | Should -Not -Throw
        }
    }
    
    Context 'Normal Operation' {
        It 'Should call Write-CustomLog with TRACE level' {
            Write-TraceLog -Message "Test trace message"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -eq "Test trace message" -and
                $Level -eq "TRACE"
            }
        }
        
        It 'Should include enhanced context with caller information' {
            Write-TraceLog -Message "Trace with context"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.ContainsKey('Function') -and
                $Context.ContainsKey('Line') -and
                $Context.ContainsKey('Command')
            }
        }
        
        It 'Should preserve user-provided context' {
            $userContext = @{ Database = 'TestDB'; Query = 'SELECT *' }
            Write-TraceLog -Message "DB trace" -Context $userContext
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Database -eq 'TestDB' -and
                $Context.Query -eq 'SELECT *'
            }
        }
        
        It 'Should not override existing Function key in context' {
            $context = @{ Function = 'CustomFunction' }
            Write-TraceLog -Message "Custom function trace" -Context $context
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Function -eq 'CustomFunction'
            }
        }
        
        It 'Should pass through Category parameter' {
            Write-TraceLog -Message "Categorized trace" -Category "Security"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Category -eq "Security"
            }
        }
    }
    
    Context 'Trace Disabled' {
        It 'Should not log when trace is disabled' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnableTrace = $false
            }
            
            Mock Write-CustomLog { } -ModuleName $script:ModuleName
            
            Write-TraceLog -Message "Should not log"
            
            Should -Not -Invoke Write-CustomLog -ModuleName $script:ModuleName
        }
        
        It 'Should return immediately when trace is disabled' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnableTrace = $false
            }
            
            # Should complete quickly without processing
            $duration = Measure-Command {
                Write-TraceLog -Message "Quick return"
            }
            
            $duration.TotalMilliseconds | Should -BeLessThan 10
        }
    }
    
    Context 'Context Enhancement' {
        It 'Should add line number to context' {
            Write-TraceLog -Message "Line number test"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Line -is [int] -and $Context.Line -gt 0
            }
        }
        
        It 'Should add command to context when available' {
            Write-TraceLog -Message "Command test"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.ContainsKey('Command')
            }
        }
        
        It 'Should handle empty command gracefully' {
            # Mock Get-PSCallStack to return empty command
            Mock Get-PSCallStack {
                [PSCustomObject]@{
                    FunctionName = "TestFunction"
                    ScriptLineNumber = 42
                    InvocationInfo = @{
                        Line = $null
                    }
                }
            } -ModuleName $script:ModuleName
            
            { Write-TraceLog -Message "Empty command test" } | Should -Not -Throw
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Command -eq ""
            }
        }
    }
    
    Context 'Edge Cases' {
        It 'Should handle empty message' {
            { Write-TraceLog -Message "" } | Should -Not -Throw
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -eq ""
            }
        }
        
        It 'Should handle null context' {
            { Write-TraceLog -Message "Null context" -Context $null } | Should -Not -Throw
        }
        
        It 'Should handle empty context' {
            { Write-TraceLog -Message "Empty context" -Context @{} } | Should -Not -Throw
        }
        
        It 'Should handle very long messages' {
            $longMessage = "A" * 10000
            { Write-TraceLog -Message $longMessage } | Should -Not -Throw
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message.Length -eq 10000
            }
        }
        
        It 'Should handle context with many keys' {
            $bigContext = @{}
            1..100 | ForEach-Object { $bigContext["Key$_"] = "Value$_" }
            
            { Write-TraceLog -Message "Big context" -Context $bigContext } | Should -Not -Throw
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Count -gt 100  # Enhanced context adds more keys
            }
        }
    }
    
    Context 'Integration with Write-CustomLog' {
        It 'Should pass all parameters correctly to Write-CustomLog' {
            $context = @{ TestKey = 'TestValue' }
            Write-TraceLog -Message "Integration test" -Context $context -Category "TestCategory"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -Times 1 -Exactly -ParameterFilter {
                $Message -eq "Integration test" -and
                $Level -eq "TRACE" -and
                $Context.TestKey -eq "TestValue" -and
                $Category -eq "TestCategory"
            }
        }
    }
}