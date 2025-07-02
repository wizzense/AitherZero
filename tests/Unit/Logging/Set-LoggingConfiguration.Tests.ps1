#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/Logging'
    $script:ModuleName = 'Logging'
    $script:FunctionName = 'Set-LoggingConfiguration'
}

Describe 'Logging.Set-LoggingConfiguration' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Store original configuration
        $script:OriginalConfig = InModuleScope $script:ModuleName {
            $script:LoggingConfig.Clone()
        }
        
        # Initialize logging
        Initialize-LoggingSystem -Force
        
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
    
    BeforeEach {
        # Reset to known state
        InModuleScope $script:ModuleName {
            $script:LoggingConfig.LogLevel = "INFO"
            $script:LoggingConfig.ConsoleLevel = "INFO"
            $script:LoggingConfig.EnableTrace = $false
            $script:LoggingConfig.EnablePerformance = $false
        }
    }
    
    Context 'Parameter Validation' {
        It 'Should accept valid LogLevel values' {
            $validLevels = @("SILENT", "ERROR", "WARN", "INFO", "DEBUG", "TRACE", "VERBOSE")
            
            foreach ($level in $validLevels) {
                { Set-LoggingConfiguration -LogLevel $level } | Should -Not -Throw
            }
        }
        
        It 'Should accept valid ConsoleLevel values' {
            $validLevels = @("SILENT", "ERROR", "WARN", "INFO", "DEBUG", "TRACE", "VERBOSE")
            
            foreach ($level in $validLevels) {
                { Set-LoggingConfiguration -ConsoleLevel $level } | Should -Not -Throw
            }
        }
        
        It 'Should accept LogFilePath parameter' {
            $testPath = Join-Path $TestDrive 'newlog.log'
            { Set-LoggingConfiguration -LogFilePath $testPath } | Should -Not -Throw
        }
        
        It 'Should accept switch parameters' {
            { Set-LoggingConfiguration -EnableTrace } | Should -Not -Throw
            { Set-LoggingConfiguration -DisableTrace } | Should -Not -Throw
            { Set-LoggingConfiguration -EnablePerformance } | Should -Not -Throw
            { Set-LoggingConfiguration -DisablePerformance } | Should -Not -Throw
        }
        
        It 'Should accept all parameters simultaneously' {
            { Set-LoggingConfiguration -LogLevel "DEBUG" -ConsoleLevel "WARN" -EnableTrace -EnablePerformance } | Should -Not -Throw
        }
    }
    
    Context 'Configuration Updates' {
        It 'Should update LogLevel when specified' {
            Set-LoggingConfiguration -LogLevel "DEBUG"
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogLevel | Should -Be "DEBUG"
            }
        }
        
        It 'Should update ConsoleLevel when specified' {
            Set-LoggingConfiguration -ConsoleLevel "ERROR"
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.ConsoleLevel | Should -Be "ERROR"
            }
        }
        
        It 'Should update LogFilePath when specified' {
            $newPath = Join-Path $TestDrive 'updated.log'
            Set-LoggingConfiguration -LogFilePath $newPath
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogFilePath | Should -Be $using:newPath
            }
        }
        
        It 'Should enable trace when EnableTrace is specified' {
            Set-LoggingConfiguration -EnableTrace
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnableTrace | Should -Be $true
            }
        }
        
        It 'Should disable trace when DisableTrace is specified' {
            # First enable it
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnableTrace = $true
            }
            
            Set-LoggingConfiguration -DisableTrace
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnableTrace | Should -Be $false
            }
        }
        
        It 'Should enable performance when EnablePerformance is specified' {
            Set-LoggingConfiguration -EnablePerformance
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnablePerformance | Should -Be $true
            }
        }
        
        It 'Should disable performance when DisablePerformance is specified' {
            # First enable it
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnablePerformance = $true
            }
            
            Set-LoggingConfiguration -DisablePerformance
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnablePerformance | Should -Be $false
            }
        }
    }
    
    Context 'Partial Updates' {
        It 'Should only update specified parameters' {
            # Set initial state
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogLevel = "INFO"
                $script:LoggingConfig.ConsoleLevel = "WARN"
                $script:LoggingConfig.EnableTrace = $true
            }
            
            # Update only LogLevel
            Set-LoggingConfiguration -LogLevel "DEBUG"
            
            # Check that only LogLevel changed
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogLevel | Should -Be "DEBUG"
                $script:LoggingConfig.ConsoleLevel | Should -Be "WARN"
                $script:LoggingConfig.EnableTrace | Should -Be $true
            }
        }
        
        It 'Should handle no parameters gracefully' {
            $configBefore = Get-LoggingConfiguration
            
            { Set-LoggingConfiguration } | Should -Not -Throw
            
            $configAfter = Get-LoggingConfiguration
            
            # Nothing should have changed
            $configAfter.LogLevel | Should -Be $configBefore.LogLevel
            $configAfter.ConsoleLevel | Should -Be $configBefore.ConsoleLevel
        }
    }
    
    Context 'Conflicting Parameters' {
        It 'Should handle EnableTrace and DisableTrace conflict' {
            # Last one wins
            Set-LoggingConfiguration -EnableTrace -DisableTrace
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnableTrace | Should -Be $false
            }
            
            Set-LoggingConfiguration -DisableTrace -EnableTrace
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnableTrace | Should -Be $true
            }
        }
        
        It 'Should handle EnablePerformance and DisablePerformance conflict' {
            # Last one wins
            Set-LoggingConfiguration -EnablePerformance -DisablePerformance
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnablePerformance | Should -Be $false
            }
            
            Set-LoggingConfiguration -DisablePerformance -EnablePerformance
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnablePerformance | Should -Be $true
            }
        }
    }
    
    Context 'Logging Output' {
        It 'Should log configuration update' {
            Set-LoggingConfiguration -LogLevel "DEBUG"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -eq "Logging configuration updated" -and
                $Level -eq "INFO"
            }
        }
        
        It 'Should include updated configuration in log context' {
            Set-LoggingConfiguration -LogLevel "TRACE" -EnableTrace
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Context.LogLevel -eq "TRACE" -and
                $Context.EnableTrace -eq $true
            }
        }
    }
    
    Context 'Edge Cases' {
        It 'Should handle empty string LogFilePath' {
            { Set-LoggingConfiguration -LogFilePath "" } | Should -Not -Throw
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogFilePath | Should -Be ""
            }
        }
        
        It 'Should handle very long file paths' {
            $longPath = "C:\" + ("A" * 200) + "\log.txt"
            { Set-LoggingConfiguration -LogFilePath $longPath } | Should -Not -Throw
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogFilePath | Should -Be $using:longPath
            }
        }
        
        It 'Should handle special characters in file path' {
            $specialPath = Join-Path $TestDrive "log with spaces & special!@#$%^&()_+.log"
            { Set-LoggingConfiguration -LogFilePath $specialPath } | Should -Not -Throw
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogFilePath | Should -Be $using:specialPath
            }
        }
    }
    
    Context 'Multiple Calls' {
        It 'Should handle rapid successive calls' {
            1..10 | ForEach-Object {
                Set-LoggingConfiguration -LogLevel "DEBUG"
                Set-LoggingConfiguration -LogLevel "INFO"
                Set-LoggingConfiguration -EnableTrace
                Set-LoggingConfiguration -DisableTrace
            }
            
            # Final state should be predictable
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogLevel | Should -Be "INFO"
                $script:LoggingConfig.EnableTrace | Should -Be $false
            }
        }
        
        It 'Should accumulate changes across multiple calls' {
            Set-LoggingConfiguration -LogLevel "DEBUG"
            Set-LoggingConfiguration -ConsoleLevel "ERROR"
            Set-LoggingConfiguration -EnableTrace
            Set-LoggingConfiguration -EnablePerformance
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogLevel | Should -Be "DEBUG"
                $script:LoggingConfig.ConsoleLevel | Should -Be "ERROR"
                $script:LoggingConfig.EnableTrace | Should -Be $true
                $script:LoggingConfig.EnablePerformance | Should -Be $true
            }
        }
    }
}