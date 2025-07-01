#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/Logging'
    $script:ModuleName = 'Logging'
    $script:FunctionName = 'Initialize-LoggingSystem'
}

Describe 'Logging.Initialize-LoggingSystem' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Store original configuration
        $script:OriginalConfig = InModuleScope $script:ModuleName {
            $script:LoggingConfig.Clone()
        }
    }
    
    AfterAll {
        # Restore original configuration
        InModuleScope $script:ModuleName {
            $script:LoggingConfig = $using:OriginalConfig
        }
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    BeforeEach {
        # Reset configuration before each test
        InModuleScope $script:ModuleName {
            $script:LoggingConfig.Initialized = $false
        }
        
        # Create test directory
        $script:TestLogPath = Join-Path $TestDrive 'logs/test.log'
    }
    
    Context 'Parameter Validation' {
        It 'Should accept valid LogLevel values' {
            $validLevels = @('SILENT', 'ERROR', 'WARN', 'INFO', 'DEBUG', 'TRACE', 'VERBOSE')
            foreach ($level in $validLevels) {
                { Initialize-LoggingSystem -LogLevel $level -Force } | Should -Not -Throw
            }
        }
        
        It 'Should accept custom log path' {
            Initialize-LoggingSystem -LogPath $script:TestLogPath -Force
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogFilePath | Should -Be $using:TestLogPath
            }
        }
        
        It 'Should accept EnableTrace switch' {
            Initialize-LoggingSystem -EnableTrace -Force
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnableTrace | Should -Be $true
            }
        }
        
        It 'Should accept EnablePerformance switch' {
            Initialize-LoggingSystem -EnablePerformance -Force
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnablePerformance | Should -Be $true
            }
        }
    }
    
    Context 'Normal Operation' {
        It 'Should initialize with default values when no parameters provided' {
            Initialize-LoggingSystem -Force
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.Initialized | Should -Be $true
                $script:LoggingConfig.LogLevel | Should -Be 'INFO'
                $script:LoggingConfig.ConsoleLevel | Should -Be 'INFO'
                $script:LoggingConfig.EnableTrace | Should -Be $false
                $script:LoggingConfig.EnablePerformance | Should -Be $false
            }
        }
        
        It 'Should create log directory if it does not exist' {
            $testPath = Join-Path $TestDrive 'newlogs/app.log'
            Initialize-LoggingSystem -LogPath $testPath -Force
            
            $logDir = Split-Path $testPath -Parent
            Test-Path $logDir | Should -Be $true
        }
        
        It 'Should write session header to log file' {
            Mock Add-Content { } -ModuleName $script:ModuleName
            
            Initialize-LoggingSystem -LogPath $script:TestLogPath -Force
            
            Should -Invoke Add-Content -ModuleName $script:ModuleName -ParameterFilter {
                $Value -like "*OpenTofu Lab Automation - New Session Started*" -and
                $Value -like "*PowerShell Version:*" -and
                $Value -like "*Log Level:*"
            }
        }
        
        It 'Should not reinitialize if already initialized without Force' {
            # First initialization
            Initialize-LoggingSystem -LogPath $script:TestLogPath
            
            # Try to reinitialize with different path
            $newPath = Join-Path $TestDrive 'other.log'
            Initialize-LoggingSystem -LogPath $newPath
            
            # Should keep original path
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogFilePath | Should -Be $using:TestLogPath
            }
        }
        
        It 'Should reinitialize when Force switch is used' {
            # First initialization
            Initialize-LoggingSystem -LogPath $script:TestLogPath
            
            # Reinitialize with Force
            $newPath = Join-Path $TestDrive 'forced.log'
            Initialize-LoggingSystem -LogPath $newPath -Force
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogFilePath | Should -Be $using:newPath
            }
        }
    }
    
    Context 'Configuration Updates' {
        It 'Should update LogLevel when specified' {
            Initialize-LoggingSystem -LogLevel 'DEBUG' -Force
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogLevel | Should -Be 'DEBUG'
            }
        }
        
        It 'Should update ConsoleLevel when specified' {
            Initialize-LoggingSystem -ConsoleLevel 'WARN' -Force
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.ConsoleLevel | Should -Be 'WARN'
            }
        }
        
        It 'Should enable trace when switch is provided' {
            Initialize-LoggingSystem -EnableTrace -Force
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnableTrace | Should -Be $true
            }
        }
        
        It 'Should enable performance tracking when switch is provided' {
            Initialize-LoggingSystem -EnablePerformance -Force
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnablePerformance | Should -Be $true
            }
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle missing parent directory gracefully' {
            Mock New-Item { throw "Access denied" } -ModuleName $script:ModuleName
            Mock Add-Content { } -ModuleName $script:ModuleName
            
            $invalidPath = Join-Path 'C:\InvalidPath\SubDir' 'test.log'
            { Initialize-LoggingSystem -LogPath $invalidPath -Force } | Should -Not -Throw
        }
        
        It 'Should continue if Add-Content fails' {
            Mock Add-Content { throw "File locked" } -ModuleName $script:ModuleName
            
            { Initialize-LoggingSystem -Force } | Should -Not -Throw
        }
    }
    
    Context 'Message Output' {
        It 'Should show initialization message on first initialization' {
            Mock Write-CustomLog { } -ModuleName $script:ModuleName
            
            Initialize-LoggingSystem -Force
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -eq "Logging system initialized" -and
                $Level -eq "SUCCESS"
            }
        }
        
        It 'Should not show initialization message when already initialized' {
            # Initialize first
            Initialize-LoggingSystem -Force
            
            # Reset mock
            Mock Write-CustomLog { } -ModuleName $script:ModuleName
            
            # Try to initialize again without Force
            Initialize-LoggingSystem
            
            Should -Not -Invoke Write-CustomLog -ModuleName $script:ModuleName
        }
        
        It 'Should show initialization message when Force is used' {
            # Initialize first
            Initialize-LoggingSystem
            
            Mock Write-CustomLog { } -ModuleName $script:ModuleName
            
            # Initialize again with Force
            Initialize-LoggingSystem -Force
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -eq "Logging system initialized"
            }
        }
    }
}