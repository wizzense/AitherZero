#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/Logging'
    $script:ModuleName = 'Logging'
    $script:FunctionName = 'Get-LoggingConfiguration'
}

Describe 'Logging.Get-LoggingConfiguration' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Initialize logging with known configuration
        Initialize-LoggingSystem -Force
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Normal Operation' {
        It 'Should return a hashtable' {
            $config = Get-LoggingConfiguration
            
            $config | Should -BeOfType [hashtable]
        }
        
        It 'Should return all configuration properties' {
            $config = Get-LoggingConfiguration
            
            $expectedKeys = @(
                'LogLevel',
                'ConsoleLevel',
                'LogFilePath',
                'MaxLogSizeMB',
                'MaxLogFiles',
                'EnableTrace',
                'EnablePerformance',
                'LogFormat',
                'EnableCallStack',
                'LogToFile',
                'LogToConsole',
                'Initialized'
            )
            
            foreach ($key in $expectedKeys) {
                $config.ContainsKey($key) | Should -Be $true -Because "Configuration should contain $key"
            }
        }
        
        It 'Should return current configuration values' {
            # Set specific values
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogLevel = "DEBUG"
                $script:LoggingConfig.ConsoleLevel = "WARN"
                $script:LoggingConfig.EnableTrace = $true
                $script:LoggingConfig.MaxLogSizeMB = 100
            }
            
            $config = Get-LoggingConfiguration
            
            $config.LogLevel | Should -Be "DEBUG"
            $config.ConsoleLevel | Should -Be "WARN"
            $config.EnableTrace | Should -Be $true
            $config.MaxLogSizeMB | Should -Be 100
        }
        
        It 'Should return a cloned copy, not a reference' {
            $config1 = Get-LoggingConfiguration
            $config1.LogLevel = "TRACE"
            
            $config2 = Get-LoggingConfiguration
            
            # Original configuration should not be modified
            $config2.LogLevel | Should -Not -Be "TRACE"
        }
    }
    
    Context 'Configuration Types' {
        It 'Should return correct types for all properties' {
            $config = Get-LoggingConfiguration
            
            $config.LogLevel | Should -BeOfType [string]
            $config.ConsoleLevel | Should -BeOfType [string]
            $config.LogFilePath | Should -BeOfType [string]
            $config.MaxLogSizeMB | Should -BeOfType [int]
            $config.MaxLogFiles | Should -BeOfType [int]
            $config.EnableTrace | Should -BeOfType [bool]
            $config.EnablePerformance | Should -BeOfType [bool]
            $config.LogFormat | Should -BeOfType [string]
            $config.EnableCallStack | Should -BeOfType [bool]
            $config.LogToFile | Should -BeOfType [bool]
            $config.LogToConsole | Should -BeOfType [bool]
            $config.Initialized | Should -BeOfType [bool]
        }
        
        It 'Should have valid log level values' {
            $config = Get-LoggingConfiguration
            $validLevels = @("SILENT", "ERROR", "WARN", "INFO", "DEBUG", "TRACE", "VERBOSE")
            
            $config.LogLevel | Should -BeIn $validLevels
            $config.ConsoleLevel | Should -BeIn $validLevels
        }
        
        It 'Should have valid log format values' {
            $config = Get-LoggingConfiguration
            $validFormats = @("Structured", "Simple", "JSON")
            
            $config.LogFormat | Should -BeIn $validFormats
        }
    }
    
    Context 'Default Values' {
        It 'Should have sensible defaults after initialization' {
            # Reset and reinitialize
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.Initialized = $false
            }
            Initialize-LoggingSystem -Force
            
            $config = Get-LoggingConfiguration
            
            # Check defaults
            $config.LogLevel | Should -Be "INFO"
            $config.ConsoleLevel | Should -Be "INFO"
            $config.MaxLogSizeMB | Should -Be 50
            $config.MaxLogFiles | Should -Be 10
            $config.EnableTrace | Should -Be $false
            $config.EnablePerformance | Should -Be $false
            $config.LogFormat | Should -Be "Structured"
            $config.EnableCallStack | Should -Be $true
            $config.LogToFile | Should -Be $true
            $config.LogToConsole | Should -Be $true
            $config.Initialized | Should -Be $true
        }
    }
    
    Context 'Environment Variable Integration' {
        It 'Should reflect environment variable overrides' {
            # Set environment variables
            $env:LAB_LOG_LEVEL = "TRACE"
            $env:LAB_CONSOLE_LEVEL = "ERROR"
            $env:LAB_MAX_LOG_SIZE_MB = "200"
            
            # Force module reload to pick up env vars
            Remove-Module $script:ModuleName -Force
            Import-Module $script:ModulePath -Force
            
            $config = Get-LoggingConfiguration
            
            # These should reflect env var values
            $config.LogLevel | Should -Be "TRACE"
            $config.ConsoleLevel | Should -Be "ERROR"
            $config.MaxLogSizeMB | Should -Be 200
            
            # Clean up
            Remove-Item env:LAB_LOG_LEVEL
            Remove-Item env:LAB_CONSOLE_LEVEL
            Remove-Item env:LAB_MAX_LOG_SIZE_MB
        }
    }
    
    Context 'No Parameters' {
        It 'Should not accept any parameters' {
            { Get-LoggingConfiguration -SomeParam "value" } | Should -Throw
        }
        
        It 'Should work with explicit empty parameters' {
            { Get-LoggingConfiguration @{} } | Should -Not -Throw
        }
    }
    
    Context 'Thread Safety' {
        It 'Should handle concurrent calls' {
            $jobs = 1..10 | ForEach-Object {
                Start-Job -ScriptBlock {
                    Import-Module $using:ModulePath -Force
                    Get-LoggingConfiguration
                }
            }
            
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            # All results should be valid configurations
            $results.Count | Should -Be 10
            foreach ($result in $results) {
                $result | Should -BeOfType [hashtable]
                $result.ContainsKey('LogLevel') | Should -Be $true
            }
        }
    }
}