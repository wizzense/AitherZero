#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/Logging'
    $script:ModuleName = 'Logging'
    $script:FunctionName = 'Write-CustomLog'
}

Describe 'Logging.Write-CustomLog' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Store original configuration
        $script:OriginalConfig = InModuleScope $script:ModuleName {
            $script:LoggingConfig.Clone()
        }
        
        # Initialize logging for tests
        Initialize-LoggingSystem -LogPath (Join-Path $TestDrive 'test.log') -Force
    }
    
    AfterAll {
        # Restore original configuration
        InModuleScope $script:ModuleName {
            $script:LoggingConfig = $using:OriginalConfig
        }
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    BeforeEach {
        # Mock Write-Host to capture console output
        Mock Write-Host { } -ModuleName $script:ModuleName
        
        # Mock Add-Content to capture file output
        Mock Add-Content { } -ModuleName $script:ModuleName
    }
    
    Context 'Parameter Validation' {
        It 'Should accept all valid log levels' {
            $levels = @('ERROR', 'WARN', 'INFO', 'SUCCESS', 'DEBUG', 'TRACE', 'VERBOSE')
            
            foreach ($level in $levels) {
                { Write-CustomLog -Message "Test" -Level $level } | Should -Not -Throw
            }
        }
        
        It 'Should accept empty message string' {
            { Write-CustomLog -Message "" } | Should -Not -Throw
        }
        
        It 'Should accept additional parameters' {
            { Write-CustomLog -Message "Test" -Source "TestSource" -Category "TestCategory" -EventId 100 } | Should -Not -Throw
        }
        
        It 'Should accept Context and AdditionalData hashtables' {
            $context = @{ Key1 = 'Value1' }
            $additional = @{ Key2 = 'Value2' }
            
            { Write-CustomLog -Message "Test" -Context $context -AdditionalData $additional } | Should -Not -Throw
        }
        
        It 'Should accept Exception parameter' {
            $exception = [System.Exception]::new("Test exception")
            
            { Write-CustomLog -Message "Error occurred" -Exception $exception } | Should -Not -Throw
        }
    }
    
    Context 'Log Level Filtering' {
        It 'Should log messages at or below configured log level' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogLevel = 'INFO'
                $script:LoggingConfig.ConsoleLevel = 'ERROR'
            }
            
            Write-CustomLog -Message "Error message" -Level 'ERROR'
            Write-CustomLog -Message "Info message" -Level 'INFO'
            
            # ERROR should be logged to both console and file
            Should -Invoke Write-Host -ModuleName $script:ModuleName -Times 1
            Should -Invoke Add-Content -ModuleName $script:ModuleName -Times 2
        }
        
        It 'Should not log messages above configured log level' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogLevel = 'WARN'
                $script:LoggingConfig.ConsoleLevel = 'WARN'
            }
            
            Write-CustomLog -Message "Debug message" -Level 'DEBUG'
            
            Should -Not -Invoke Write-Host -ModuleName $script:ModuleName
            Should -Not -Invoke Add-Content -ModuleName $script:ModuleName
        }
        
        It 'Should respect different console and file log levels' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogLevel = 'DEBUG'
                $script:LoggingConfig.ConsoleLevel = 'ERROR'
            }
            
            Write-CustomLog -Message "Info message" -Level 'INFO'
            
            # Should log to file but not console
            Should -Not -Invoke Write-Host -ModuleName $script:ModuleName
            Should -Invoke Add-Content -ModuleName $script:ModuleName -Times 1
        }
    }
    
    Context 'Output Control' {
        It 'Should respect NoConsole switch' {
            Write-CustomLog -Message "Test" -NoConsole
            
            Should -Not -Invoke Write-Host -ModuleName $script:ModuleName
            Should -Invoke Add-Content -ModuleName $script:ModuleName
        }
        
        It 'Should respect NoFile switch' {
            Write-CustomLog -Message "Test" -NoFile
            
            Should -Invoke Write-Host -ModuleName $script:ModuleName
            Should -Not -Invoke Add-Content -ModuleName $script:ModuleName
        }
        
        It 'Should respect LogToConsole configuration' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogToConsole = $false
            }
            
            Write-CustomLog -Message "Test"
            
            Should -Not -Invoke Write-Host -ModuleName $script:ModuleName
        }
        
        It 'Should respect LogToFile configuration' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogToFile = $false
            }
            
            Write-CustomLog -Message "Test"
            
            Should -Not -Invoke Add-Content -ModuleName $script:ModuleName
        }
    }
    
    Context 'Message Formatting' {
        It 'Should use correct color for each log level' {
            $colorMap = @{
                'ERROR' = 'Red'
                'WARN' = 'Yellow'
                'SUCCESS' = 'Green'
                'INFO' = 'Cyan'
                'DEBUG' = 'DarkGray'
                'TRACE' = 'Magenta'
                'VERBOSE' = 'DarkCyan'
            }
            
            foreach ($level in $colorMap.Keys) {
                Mock Write-Host { } -ModuleName $script:ModuleName
                
                Write-CustomLog -Message "Test" -Level $level
                
                Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                    $ForegroundColor -eq $colorMap[$level]
                }
            }
        }
        
        It 'Should include timestamp in log message' {
            Write-CustomLog -Message "Test message"
            
            Should -Invoke Add-Content -ModuleName $script:ModuleName -ParameterFilter {
                $Value -match '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\]'
            }
        }
        
        It 'Should include source information when not provided' {
            Write-CustomLog -Message "Test"
            
            Should -Invoke Add-Content -ModuleName $script:ModuleName -ParameterFilter {
                $Value -match '\[Write-CustomLog\]' -or $Value -match '\[PowerShell\]'
            }
        }
        
        It 'Should use provided source information' {
            Write-CustomLog -Message "Test" -Source "CustomSource"
            
            Should -Invoke Add-Content -ModuleName $script:ModuleName -ParameterFilter {
                $Value -match '\[CustomSource\]'
            }
        }
    }
    
    Context 'Context and Additional Data' {
        It 'Should merge Context and AdditionalData' {
            $context = @{ Key1 = 'Value1'; Shared = 'Context' }
            $additional = @{ Key2 = 'Value2'; Shared = 'Additional' }
            
            Write-CustomLog -Message "Test" -Context $context -AdditionalData $additional
            
            Should -Invoke Add-Content -ModuleName $script:ModuleName -ParameterFilter {
                $Value -match 'Key1=Value1' -and
                $Value -match 'Key2=Value2' -and
                $Value -match 'Shared=Additional'  # AdditionalData takes precedence
            }
        }
        
        It 'Should include context in console output' {
            $context = @{ Operation = 'Test'; Status = 'Running' }
            
            Write-CustomLog -Message "Test" -Context $context
            
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $Object -match '{Operation=Test, Status=Running}' -or
                $Object -match '{Status=Running, Operation=Test}'
            }
        }
    }
    
    Context 'Call Stack and Exception Handling' {
        It 'Should include call stack for ERROR level when enabled' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.EnableCallStack = $true
            }
            
            Write-CustomLog -Message "Error" -Level 'ERROR'
            
            Should -Invoke Add-Content -ModuleName $script:ModuleName -ParameterFilter {
                $Value -match 'CallStack:'
            }
        }
        
        It 'Should include exception details when provided' {
            $exception = [System.Exception]::new("Test exception")
            
            Write-CustomLog -Message "Error" -Exception $exception
            
            Should -Invoke Add-Content -ModuleName $script:ModuleName -ParameterFilter {
                $Value -match 'Exception: System.Exception - Test exception'
            }
        }
        
        It 'Should handle inner exceptions' {
            $inner = [System.Exception]::new("Inner exception")
            $outer = [System.Exception]::new("Outer exception", $inner)
            
            Write-CustomLog -Message "Error" -Exception $outer
            
            Should -Invoke Add-Content -ModuleName $script:ModuleName -ParameterFilter {
                $Value -match 'Inner exception'
            }
        }
    }
    
    Context 'Log Rotation' {
        It 'Should check for log rotation when file size exceeds limit' {
            Mock Test-Path { $true } -ModuleName $script:ModuleName
            Mock Get-Item { 
                [PSCustomObject]@{ Length = 100MB }
            } -ModuleName $script:ModuleName -ParameterFilter {
                $Path -eq $script:LoggingConfig.LogFilePath
            }
            Mock Invoke-LogRotation { } -ModuleName $script:ModuleName
            
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.MaxLogSizeMB = 50
            }
            
            Write-CustomLog -Message "Test"
            
            Should -Invoke Invoke-LogRotation -ModuleName $script:ModuleName
        }
        
        It 'Should handle log rotation failures gracefully' {
            Mock Test-Path { $true } -ModuleName $script:ModuleName
            Mock Get-Item { 
                [PSCustomObject]@{ Length = 100MB }
            } -ModuleName $script:ModuleName
            Mock Invoke-LogRotation { throw "Rotation failed" } -ModuleName $script:ModuleName
            
            { Write-CustomLog -Message "Test" } | Should -Not -Throw
        }
    }
    
    Context 'Error Handling' {
        It 'Should fall back to console when file logging fails' {
            Mock Add-Content { throw "File locked" } -ModuleName $script:ModuleName
            Mock Write-Host { } -ModuleName $script:ModuleName
            
            Write-CustomLog -Message "Test"
            
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $Object -match '\[LOG ERROR\] Failed to write to log file'
            }
        }
        
        It 'Should handle null or missing values gracefully' {
            { Write-CustomLog -Message "Test" -Context $null -AdditionalData $null } | Should -Not -Throw
        }
    }
    
    Context 'Format Options' {
        It 'Should support JSON format' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogFormat = 'JSON'
            }
            
            Write-CustomLog -Message "Test message" -Level 'INFO'
            
            Should -Invoke Add-Content -ModuleName $script:ModuleName -ParameterFilter {
                try {
                    $json = $Value | ConvertFrom-Json
                    $json.Message -eq "Test message" -and $json.Level -eq "INFO"
                } catch {
                    $false
                }
            }
        }
        
        It 'Should support Simple format' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogFormat = 'Simple'
            }
            
            Write-CustomLog -Message "Test message" -Level 'INFO'
            
            Should -Invoke Add-Content -ModuleName $script:ModuleName -ParameterFilter {
                $Value -match '^\[[\d-\s:.]+\] \[INFO\] Test message$'
            }
        }
        
        It 'Should support Structured format (default)' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogFormat = 'Structured'
            }
            
            Write-CustomLog -Message "Test message" -Level 'INFO'
            
            Should -Invoke Add-Content -ModuleName $script:ModuleName -ParameterFilter {
                $Value -match '\[PID:\d+\]' -and
                $Value -match '\[TID:\d+\]' -and
                $Value -match 'Test message'
            }
        }
    }
}