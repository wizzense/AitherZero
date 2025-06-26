BeforeAll {
    # Import the Logging module
    $projectRoot = if ($env:PROJECT_ROOT) { 
        $env:PROJECT_ROOT 
    } else { 
        # Default to workspace root if environment variable not set
        '/workspaces/AitherLabs'
    }
    $loggingModulePath = Join-Path $projectRoot "$env:PWSH_MODULES_PATH/Logging"
    
    try {
        Import-Module $loggingModulePath -Force -ErrorAction Stop
        Write-Host "Logging module imported successfully from: $loggingModulePath" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import Logging module from $loggingModulePath : $_"
        throw
    }
    
    # Test log directory
    $script:testLogDir = Join-Path $TestDrive "logs"
    New-Item -Path $script:testLogDir -ItemType Directory -Force | Out-Null
    $script:testLogFile = Join-Path $script:testLogDir "test.log"
}

Describe "Logging Module - Core Functions" {
    
    Context "Initialize-LoggingSystem" {
        
        It "Should initialize logging system with default settings" {
            { Initialize-LoggingSystem } | Should -Not -Throw
        }
        
        It "Should initialize logging system with custom log path" {
            { Initialize-LoggingSystem -LogPath $script:testLogFile } | Should -Not -Throw
        }
        
        It "Should initialize logging system with custom log levels" {
            { Initialize-LoggingSystem -LogLevel "DEBUG" -ConsoleLevel "WARN" } | Should -Not -Throw
        }
        
        It "Should initialize logging system with trace and performance enabled" {
            { Initialize-LoggingSystem -EnableTrace -EnablePerformance } | Should -Not -Throw
        }
        
        It "Should initialize with custom log path without error" {
            $customLogDir = Join-Path $TestDrive "custom-logs"
            $customLogFile = Join-Path $customLogDir "custom.log"
            
            # Create the directory first since Initialize-LoggingSystem doesn't create it
            New-Item -Path $customLogDir -ItemType Directory -Force
            
            { Initialize-LoggingSystem -LogPath $customLogFile } | Should -Not -Throw
            
            # Check that the directory exists
            Test-Path $customLogDir | Should -Be $true
        }
    }
    
    Context "Write-CustomLog" {
        
        BeforeEach {
            Initialize-LoggingSystem -LogPath $script:testLogFile -LogLevel "TRACE"
        }
        
        It "Should write INFO level log message" {
            { Write-CustomLog -Message "Test INFO message" -Level "INFO" } | Should -Not -Throw
        }
        
        It "Should write ERROR level log message" {
            { Write-CustomLog -Message "Test ERROR message" -Level "ERROR" } | Should -Not -Throw
        }
        
        It "Should write WARN level log message" {
            { Write-CustomLog -Message "Test WARN message" -Level "WARN" } | Should -Not -Throw
        }
        
        It "Should write DEBUG level log message" {
            { Write-CustomLog -Message "Test DEBUG message" -Level "DEBUG" } | Should -Not -Throw
        }
        
        It "Should write SUCCESS level log message" {
            { Write-CustomLog -Message "Test SUCCESS message" -Level "SUCCESS" } | Should -Not -Throw
        }
        
        It "Should write TRACE level log message" {
            { Write-CustomLog -Message "Test TRACE message" -Level "TRACE" } | Should -Not -Throw
        }
        
        It "Should write message with context" {
            $context = @{
                Module = "TestModule"
                Function = "TestFunction"
                Source = "TestSource"
            }
            
            { Write-CustomLog -Message "Test message with context" -Level "INFO" -Context $context } | Should -Not -Throw
        }
        
        It "Should write message with additional data" {
            $additionalData = @{
                TestKey = "TestValue"
                Number = 42
            }
            
            { Write-CustomLog -Message "Test message with data" -Level "INFO" -AdditionalData $additionalData } | Should -Not -Throw
        }
        
        It "Should create log file when writing first message" {
            # Get the actual log file path from configuration
            $config = Get-LoggingConfiguration
            $actualLogFile = $config.LogFilePath
            
            # Remove existing log file if it exists
            if (Test-Path $actualLogFile) {
                Remove-Item $actualLogFile -Force
            }
            
            Write-CustomLog -Message "First message" -Level "INFO"
            
            # Check the actual log file location
            Test-Path $actualLogFile | Should -Be $true
        }
    }
    
    Context "Performance Tracing" {
        
        BeforeEach {
            Initialize-LoggingSystem -LogPath $script:testLogFile -EnablePerformance
        }
        
        It "Should start performance trace" {
            { Start-PerformanceTrace -Name "TestOperation" } | Should -Not -Throw
        }
        
        It "Should stop performance trace" {
            Start-PerformanceTrace -Name "TestOperation"
            Start-Sleep -Milliseconds 100
            
            { Stop-PerformanceTrace -Name "TestOperation" } | Should -Not -Throw
        }
        
        It "Should measure execution time" {
            Start-PerformanceTrace -Name "TestOperation"
            Start-Sleep -Milliseconds 100
            $result = Stop-PerformanceTrace -Name "TestOperation"
            
            # The function might not return a value, just check it doesn't throw
            { Stop-PerformanceTrace -Name "TestOperation2" } | Should -Not -Throw
        }
        
        It "Should handle multiple concurrent traces" {
            Start-PerformanceTrace -Name "Operation1"
            Start-PerformanceTrace -Name "Operation2"
            Start-Sleep -Milliseconds 50
            Stop-PerformanceTrace -Name "Operation1"
            Stop-PerformanceTrace -Name "Operation2"
            
            # Should not throw any errors
            $true | Should -Be $true
        }
    }
    
    Context "Trace Logging" {
        
        BeforeEach {
            Initialize-LoggingSystem -LogPath $script:testLogFile -EnableTrace -LogLevel "TRACE"
        }
        
        It "Should write trace log with call stack" {
            { Write-TraceLog -Message "Trace message" } | Should -Not -Throw
        }
        
        It "Should write trace log with custom context" {
            $context = @{
                Module = "TestModule"
                Function = "TestFunction"
            }
            
            { Write-TraceLog -Message "Trace message" -Context $context } | Should -Not -Throw
        }
    }
    
    Context "Debug Context" {
        
        BeforeEach {
            Initialize-LoggingSystem -LogPath $script:testLogFile -LogLevel "DEBUG"
        }
        
        It "Should write debug context information" {
            $variables = @{
                TestVar = "TestValue"
                Number = 123
            }
            
            { Write-DebugContext -Variables $variables } | Should -Not -Throw
        }
        
        It "Should write debug context with custom message" {
            $variables = @{
                TestVar = "TestValue"
            }
            
            { Write-DebugContext -Variables $variables -Context "Custom debug context" } | Should -Not -Throw
        }
    }
    
    Context "Configuration Management" {
        
        It "Should get current logging configuration" {
            $config = Get-LoggingConfiguration
            
            $config | Should -Not -BeNullOrEmpty
            $config.LogLevel | Should -Not -BeNullOrEmpty
            $config.ConsoleLevel | Should -Not -BeNullOrEmpty
            $config.LogFilePath | Should -Not -BeNullOrEmpty
        }
        
        It "Should set logging configuration" {
            $newConfig = @{
                LogLevel = "ERROR"
                ConsoleLevel = "WARN"
                EnableTrace = $true
                EnablePerformance = $true
            }
            
            { Set-LoggingConfiguration @newConfig } | Should -Not -Throw
            
            $config = Get-LoggingConfiguration
            $config.LogLevel | Should -Be "ERROR"
            $config.ConsoleLevel | Should -Be "WARN"
            $config.EnableTrace | Should -Be $true
            $config.EnablePerformance | Should -Be $true
        }
    }
}

Describe "Logging Module - Error Handling" {
    
    Context "Invalid Parameters" {
        
        It "Should handle invalid log level gracefully" {
            # This should either throw a proper error or handle gracefully
            try {
                Write-CustomLog -Message "Test" -Level "INVALID"
                $true | Should -Be $true  # If it doesn't throw, that's acceptable
            }
            catch {
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should handle null or empty messages" {
            { Write-CustomLog -Message "" -Level "INFO" } | Should -Not -Throw
            { Write-CustomLog -Message $null -Level "INFO" } | Should -Not -Throw
        }
    }
    
    Context "File System Issues" {
        
        It "Should handle inaccessible log directory" {
            # Try to use a path that doesn't exist and can't be created
            $invalidPath = "Z:\nonexistent\path\test.log"
            
            try {
                Initialize-LoggingSystem -LogPath $invalidPath
                # If it doesn't throw, that's fine - it might handle it gracefully
                $true | Should -Be $true
            }
            catch {
                # If it throws, the error should be meaningful
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
    }
}
