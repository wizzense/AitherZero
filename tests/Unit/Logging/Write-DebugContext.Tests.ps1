#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/Logging'
    $script:ModuleName = 'Logging'
    $script:FunctionName = 'Write-DebugContext'
}

Describe 'Logging.Write-DebugContext' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Store original configuration
        $script:OriginalConfig = InModuleScope $script:ModuleName {
            $script:LoggingConfig.Clone()
        }
        
        # Initialize logging
        Initialize-LoggingSystem -LogLevel DEBUG -Force
        
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
        It 'Should accept all parameters as optional' {
            { Write-DebugContext } | Should -Not -Throw
        }
        
        It 'Should accept custom Message' {
            { Write-DebugContext -Message "Custom debug message" } | Should -Not -Throw
        }
        
        It 'Should accept Variables hashtable' {
            $vars = @{ Var1 = 'Value1'; Var2 = 42 }
            { Write-DebugContext -Variables $vars } | Should -Not -Throw
        }
        
        It 'Should accept Context parameter' {
            { Write-DebugContext -Context "TestContext" } | Should -Not -Throw
        }
        
        It 'Should accept Scope parameter' {
            { Write-DebugContext -Scope "Global" } | Should -Not -Throw
        }
        
        It 'Should prefer Context over Scope when both provided' {
            Write-DebugContext -Context "PreferredContext" -Scope "IgnoredScope"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Scope -eq "PreferredContext"
            }
        }
    }
    
    Context 'Normal Operation' {
        It 'Should use default message when not provided' {
            Write-DebugContext
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -eq "Debug Context Information"
            }
        }
        
        It 'Should use custom message when provided' {
            Write-DebugContext -Message "Custom debug info"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -eq "Custom debug info"
            }
        }
        
        It 'Should always use DEBUG level' {
            Write-DebugContext
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Level -eq "DEBUG"
            }
        }
        
        It 'Should include variables in context' {
            $vars = @{
                Username = 'testuser'
                ProcessId = 1234
                IsEnabled = $true
            }
            
            Write-DebugContext -Variables $vars
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Username -eq 'testuser' -and
                $Context.ProcessId -eq 1234 -and
                $Context.IsEnabled -eq $true
            }
        }
        
        It 'Should use default scope when not provided' {
            Write-DebugContext
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Scope -eq "Local"
            }
        }
        
        It 'Should use provided scope' {
            Write-DebugContext -Scope "Module"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Scope -eq "Module"
            }
        }
    }
    
    Context 'Debug Level Check' {
        It 'Should add scope information when log level is DEBUG or higher' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogLevel = "DEBUG"
            }
            
            Write-DebugContext
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.ContainsKey('Scope') -and
                $Context.ContainsKey('Function') -and
                $Context.ContainsKey('Script')
            }
        }
        
        It 'Should include function name in context' {
            Write-DebugContext
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Function -ne $null
            }
        }
        
        It 'Should include script name in context' {
            Write-DebugContext
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Script -ne $null
            }
        }
        
        It 'Should still work when log level is below DEBUG' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogLevel = "INFO"
            }
            
            { Write-DebugContext } | Should -Not -Throw
            
            # Should still call Write-CustomLog (filtering happens there)
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName
        }
    }
    
    Context 'Variable Handling' {
        It 'Should handle empty variables hashtable' {
            { Write-DebugContext -Variables @{} } | Should -Not -Throw
        }
        
        It 'Should handle null variables' {
            { Write-DebugContext -Variables $null } | Should -Not -Throw
        }
        
        It 'Should preserve variable types' {
            $vars = @{
                String = "text"
                Number = 42
                Float = 3.14
                Boolean = $true
                Array = @(1, 2, 3)
                Nested = @{ Inner = "value" }
            }
            
            Write-DebugContext -Variables $vars
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.String -eq "text" -and
                $Context.Number -eq 42 -and
                $Context.Float -eq 3.14 -and
                $Context.Boolean -eq $true -and
                $Context.Array.Count -eq 3 -and
                $Context.Nested.Inner -eq "value"
            }
        }
        
        It 'Should handle variables with special characters in names' {
            $vars = @{
                'Variable-With-Dashes' = 'value1'
                'Variable.With.Dots' = 'value2'
                'Variable With Spaces' = 'value3'
            }
            
            { Write-DebugContext -Variables $vars } | Should -Not -Throw
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context['Variable-With-Dashes'] -eq 'value1' -and
                $Context['Variable.With.Dots'] -eq 'value2' -and
                $Context['Variable With Spaces'] -eq 'value3'
            }
        }
    }
    
    Context 'Edge Cases' {
        It 'Should handle very long message' {
            $longMessage = "Debug: " + ("A" * 5000)
            
            { Write-DebugContext -Message $longMessage } | Should -Not -Throw
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message.Length -gt 5000
            }
        }
        
        It 'Should handle many variables' {
            $manyVars = @{}
            1..100 | ForEach-Object { $manyVars["Var$_"] = "Value$_" }
            
            { Write-DebugContext -Variables $manyVars } | Should -Not -Throw
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Count -ge 100
            }
        }
        
        It 'Should handle circular references in variables' {
            $circular = @{ Name = "Test" }
            $circular.Self = $circular
            
            # Should not throw, but exact behavior depends on serialization
            { Write-DebugContext -Variables @{ Circular = $circular } } | Should -Not -Throw
        }
        
        It 'Should handle null values in variables' {
            $vars = @{
                NullValue = $null
                EmptyString = ""
                Zero = 0
                False = $false
            }
            
            { Write-DebugContext -Variables $vars } | Should -Not -Throw
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.ContainsKey('NullValue') -and
                $Context.EmptyString -eq "" -and
                $Context.Zero -eq 0 -and
                $Context.False -eq $false
            }
        }
    }
    
    Context 'Scope Values' {
        It 'Should accept standard scope values' {
            $scopes = @('Local', 'Script', 'Global', 'Private', 'Module')
            
            foreach ($scope in $scopes) {
                Mock Write-CustomLog { } -ModuleName $script:ModuleName
                
                Write-DebugContext -Scope $scope
                
                Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                    $Context.Scope -eq $scope
                }
            }
        }
        
        It 'Should accept custom scope values' {
            Write-DebugContext -Scope "CustomScope"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.Scope -eq "CustomScope"
            }
        }
    }
}