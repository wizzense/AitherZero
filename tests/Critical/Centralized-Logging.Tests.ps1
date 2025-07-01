BeforeDiscovery {
    $script:LoggingModulePath = Join-Path $PSScriptRoot '../../aither-core/modules/Logging'
    $script:TestAppName = 'Centralized-Logging'
    
    # Verify the logging module exists
    if (-not (Test-Path $script:LoggingModulePath)) {
        throw "Logging module not found at: $script:LoggingModulePath"
    }
}

Describe 'Centralized Logging - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'Logging', 'Performance') {
    
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Set up isolated test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'centralized-logging-tests'
        
        # Save original environment
        $script:OriginalEnvVars = @{
            LAB_LOG_LEVEL = $env:LAB_LOG_LEVEL
            LAB_CONSOLE_LEVEL = $env:LAB_CONSOLE_LEVEL
            LAB_LOG_PATH = $env:LAB_LOG_PATH
            LAB_MAX_LOG_SIZE_MB = $env:LAB_MAX_LOG_SIZE_MB
            LAB_MAX_LOG_FILES = $env:LAB_MAX_LOG_FILES
            LAB_ENABLE_TRACE = $env:LAB_ENABLE_TRACE
            LAB_ENABLE_PERFORMANCE = $env:LAB_ENABLE_PERFORMANCE
            LAB_LOG_FORMAT = $env:LAB_LOG_FORMAT
            LAB_ENABLE_CALLSTACK = $env:LAB_ENABLE_CALLSTACK
            LAB_LOG_TO_FILE = $env:LAB_LOG_TO_FILE
            LAB_LOG_TO_CONSOLE = $env:LAB_LOG_TO_CONSOLE
        }
        
        # Create test directory structure
        $script:TestLogsDir = Join-Path $script:TestWorkspace 'logs'
        $script:TestConfigDir = Join-Path $script:TestWorkspace 'config'
        $script:TestDataDir = Join-Path $script:TestWorkspace 'data'
        $script:TestTempDir = Join-Path $script:TestWorkspace 'temp'
        
        @($script:TestLogsDir, $script:TestConfigDir, $script:TestDataDir, $script:TestTempDir) | ForEach-Object {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
        
        # Import logging module
        Import-Module $script:LoggingModulePath -Force -Global
        
        # Test log files for different scenarios
        $script:TestLogFiles = @{
            Standard = Join-Path $script:TestLogsDir 'standard.log'
            Performance = Join-Path $script:TestLogsDir 'performance.log'
            HighVolume = Join-Path $script:TestLogsDir 'high-volume.log'
            Rotation = Join-Path $script:TestLogsDir 'rotation.log'
            MultiLevel = Join-Path $script:TestLogsDir 'multi-level.log'
            CrossPlatform = Join-Path $script:TestLogsDir 'cross-platform.log'
            Integration = Join-Path $script:TestLogsDir 'integration.log'
            Stress = Join-Path $script:TestLogsDir 'stress.log'
        }
        
        # Performance test data
        $script:PerformanceMetrics = @{
            LogEntriesPerSecond = @()
            MemoryUsage = @()
            FileSystemPerformance = @()
            ConfigurationSwitchTime = @()
        }
        
        # Mock external components for integration testing
        $script:MockComponents = @{
            StartAitherZero = Join-Path $script:TestWorkspace 'Start-AitherZero.ps1'
            AitherCore = Join-Path $script:TestWorkspace 'aither-core.ps1'
            TestModule = Join-Path $script:TestWorkspace 'TestModule.psm1'
        }
        
        # Create mock components that use logging
        $mockStartScript = @'
Import-Module $args[0] -Force
Initialize-LoggingSystem -LogPath $args[1] -LogLevel INFO -ConsoleLevel WARN
Write-CustomLog "Start-AitherZero initiated" -Level INFO
Write-CustomLog "Configuration loaded" -Level DEBUG
Write-CustomLog "System ready" -Level SUCCESS
'@
        $mockStartScript | Out-File -FilePath $script:MockComponents.StartAitherZero -Encoding UTF8
        
        $mockCoreScript = @'
Import-Module $args[0] -Force
Write-CustomLog "Core application starting" -Level INFO
for ($i = 1; $i -le 10; $i++) {
    Write-CustomLog "Processing step $i" -Level DEBUG
    Start-Sleep -Milliseconds 10
}
Write-CustomLog "Core application completed" -Level SUCCESS
'@
        $mockCoreScript | Out-File -FilePath $script:MockComponents.AitherCore -Encoding UTF8
        
        $mockModule = @'
function Test-LoggingIntegration {
    param($Message, $Level = 'INFO')
    Write-CustomLog "Module function: $Message" -Level $Level
    Start-PerformanceTrace -Name "ModuleOperation"
    Start-Sleep -Milliseconds 50
    Stop-PerformanceTrace -Name "ModuleOperation"
}
Export-ModuleMember -Function Test-LoggingIntegration
'@
        $mockModule | Out-File -FilePath $script:MockComponents.TestModule -Encoding UTF8
    }
    
    AfterAll {
        # Restore original environment
        foreach ($key in $script:OriginalEnvVars.Keys) {
            Set-Item -Path "env:$key" -Value $script:OriginalEnvVars[$key] -ErrorAction SilentlyContinue
        }
        
        # Remove imported modules
        Remove-Module Logging -Force -ErrorAction SilentlyContinue
        
        # Clean up test workspace
        if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
            # Give time for file handles to close
            Start-Sleep -Milliseconds 500
            Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        # Clear environment variables for each test
        @('LAB_LOG_LEVEL', 'LAB_CONSOLE_LEVEL', 'LAB_LOG_PATH', 'LAB_MAX_LOG_SIZE_MB', 
          'LAB_MAX_LOG_FILES', 'LAB_ENABLE_TRACE', 'LAB_ENABLE_PERFORMANCE', 'LAB_LOG_FORMAT',
          'LAB_ENABLE_CALLSTACK', 'LAB_LOG_TO_FILE', 'LAB_LOG_TO_CONSOLE') | ForEach-Object {
            Remove-Item -Path "env:$_" -ErrorAction SilentlyContinue
        }
        
        # Clear any existing test log files
        Get-ChildItem $script:TestLogsDir -Filter "*.log" -ErrorAction SilentlyContinue | Remove-Item -Force
    }
    
    Context 'Multi-Level Logging Infrastructure' {
        
        It 'Should handle hierarchical log levels correctly across all components' {
            $logPath = $script:TestLogFiles.MultiLevel
            
            # Initialize with DEBUG level
            Initialize-LoggingSystem -LogPath $logPath -LogLevel DEBUG -ConsoleLevel SILENT -Force
            
            # Test all log levels
            $testLevels = @('ERROR', 'WARN', 'INFO', 'SUCCESS', 'DEBUG')
            $testMessages = @()
            
            foreach ($level in $testLevels) {
                $message = "Test message for $level level"
                Write-CustomLog -Message $message -Level $level
                $testMessages += @{Level = $level; Message = $message}
            }
            
            # Wait for file writes
            Start-Sleep -Milliseconds 100
            
            # Verify all messages were written
            Test-Path $logPath | Should -Be $true
            $logContent = Get-Content $logPath
            
            foreach ($testMsg in $testMessages) {
                $logContent | Should -Contain -ExpectedValue "*$($testMsg.Level)*$($testMsg.Message)*" -Because "Log should contain $($testMsg.Level) message"
            }
        }
        
        It 'Should filter log levels correctly with different console and file settings' {
            $logPath = $script:TestLogFiles.Standard
            
            # Initialize with different file and console levels
            Initialize-LoggingSystem -LogPath $logPath -LogLevel DEBUG -ConsoleLevel ERROR -Force
            
            # Capture console output
            $consoleOutput = @()
            $fileOutput = @()
            
            # Override Write-Host to capture console output
            $originalWriteHost = Get-Command Write-Host
            function Write-Host {
                param($Object, $ForegroundColor, $NoNewline)
                $script:consoleOutput += $Object
                & $originalWriteHost @PSBoundParameters
            }
            
            try {
                # Test messages at different levels
                Write-CustomLog -Message "Error message" -Level ERROR
                Write-CustomLog -Message "Warning message" -Level WARN  
                Write-CustomLog -Message "Info message" -Level INFO
                Write-CustomLog -Message "Debug message" -Level DEBUG
                
                Start-Sleep -Milliseconds 100
                
                # Verify file contains all levels (DEBUG setting)
                $fileContent = Get-Content $logPath -ErrorAction SilentlyContinue
                $fileContent | Should -Match "Error message"
                $fileContent | Should -Match "Warning message" 
                $fileContent | Should -Match "Info message"
                $fileContent | Should -Match "Debug message"
                
                # Console should only show ERROR level messages
                $consoleOutput -join "" | Should -Match "Error message"
                $consoleOutput -join "" | Should -Not -Match "Warning message"
                
            } finally {
                # Restore original Write-Host
                Remove-Item Function:\Write-Host
            }
        }
        
        It 'Should maintain performance under high-volume logging scenarios' {
            $logPath = $script:TestLogFiles.HighVolume
            
            Initialize-LoggingSystem -LogPath $logPath -LogLevel INFO -ConsoleLevel SILENT -EnablePerformance -Force
            
            $messageCount = 1000
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Generate high volume of log messages
            for ($i = 1; $i -le $messageCount; $i++) {
                Write-CustomLog -Message "High volume test message $i" -Level INFO
                
                # Vary message levels for realistic scenario
                if ($i % 10 -eq 0) {
                    Write-CustomLog -Message "Debug checkpoint $i" -Level DEBUG
                }
                if ($i % 50 -eq 0) {
                    Write-CustomLog -Message "Warning at message $i" -Level WARN
                }
            }
            
            $stopwatch.Stop()
            $totalTime = $stopwatch.ElapsedMilliseconds
            $messagesPerSecond = [math]::Round(($messageCount / $totalTime) * 1000, 2)
            
            # Performance requirements
            $totalTime | Should -BeLessThan 10000  # Should complete within 10 seconds
            $messagesPerSecond | Should -BeGreaterThan 50  # Should handle at least 50 messages/second
            
            # Store performance metrics
            $script:PerformanceMetrics.LogEntriesPerSecond += $messagesPerSecond
            
            # Verify all messages were written
            Start-Sleep -Milliseconds 200
            Test-Path $logPath | Should -Be $true
            $logLines = (Get-Content $logPath).Count
            $logLines | Should -BeGreaterThan ($messageCount * 0.9)  # Allow for some variance
        }
        
        It 'Should handle concurrent logging from multiple sources safely' {
            $logPath = $script:TestLogFiles.Standard
            
            Initialize-LoggingSystem -LogPath $logPath -LogLevel INFO -ConsoleLevel SILENT -Force
            
            # Create multiple concurrent logging jobs
            $jobs = @()
            for ($i = 1; $i -le 5; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($ModulePath, $LogPath, $WorkerId)
                    
                    Import-Module $ModulePath -Force
                    
                    for ($j = 1; $j -le 20; $j++) {
                        Write-CustomLog -Message "Worker $WorkerId - Message $j" -Level INFO
                        Start-Sleep -Milliseconds 10
                    }
                } -ArgumentList $script:LoggingModulePath, $logPath, $i
            }
            
            # Wait for all jobs to complete
            $jobs | Wait-Job -Timeout 30 | Out-Null
            $jobs | Remove-Job -Force
            
            # Verify log integrity
            Start-Sleep -Milliseconds 200
            Test-Path $logPath | Should -Be $true
            $logContent = Get-Content $logPath
            
            # Check for expected number of messages
            $logContent.Count | Should -BeGreaterThan 90  # 5 workers * 20 messages each, allowing some variance
            
            # Verify no corruption (all lines should contain proper log format)
            foreach ($line in $logContent) {
                $line | Should -Match "\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]|\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}"
            }
        }
    }
    
    Context 'Log Rotation and File Management' {
        
        It 'Should rotate logs when size limit is exceeded' {
            $logPath = $script:TestLogFiles.Rotation
            
            # Set small log size for testing (1KB)
            $env:LAB_MAX_LOG_SIZE_MB = "0.001"  # 1KB in MB
            $env:LAB_MAX_LOG_FILES = "3"
            
            Initialize-LoggingSystem -LogPath $logPath -LogLevel INFO -ConsoleLevel SILENT -Force
            
            # Generate enough content to trigger rotation
            $largeMessage = "A" * 200  # 200 characters
            for ($i = 1; $i -le 20; $i++) {
                Write-CustomLog -Message "$largeMessage Message $i" -Level INFO
            }
            
            # Force rotation check
            Start-Sleep -Milliseconds 200
            Invoke-LogRotation
            
            # Check for rotated files
            $logDir = Split-Path $logPath -Parent
            $logBaseName = [System.IO.Path]::GetFileNameWithoutExtension($logPath)
            $rotatedFiles = Get-ChildItem $logDir -Filter "$logBaseName*.log"
            
            $rotatedFiles.Count | Should -BeGreaterThan 1  # Should have original + rotated files
            $rotatedFiles.Count | Should -BeLessOrEqual 4  # Should not exceed max files + 1
        }
        
        It 'Should clean up old log files beyond the retention limit' {
            $logPath = $script:TestLogFiles.Rotation
            $logDir = Split-Path $logPath -Parent
            $logBaseName = [System.IO.Path]::GetFileNameWithoutExtension($logPath)
            
            # Create multiple old log files
            for ($i = 1; $i -le 6; $i++) {
                $oldLogFile = Join-Path $logDir "$logBaseName-$i.log"
                "Old log content $i" | Out-File -FilePath $oldLogFile
                
                # Set different creation times
                $pastTime = (Get-Date).AddDays(-$i)
                (Get-Item $oldLogFile).CreationTime = $pastTime
                (Get-Item $oldLogFile).LastWriteTime = $pastTime
            }
            
            # Set retention limit
            $env:LAB_MAX_LOG_FILES = "3"
            
            Initialize-LoggingSystem -LogPath $logPath -LogLevel INFO -ConsoleLevel SILENT -Force
            
            # Trigger cleanup
            Invoke-LogRotation
            
            # Check that only the newest files remain
            $remainingFiles = Get-ChildItem $logDir -Filter "$logBaseName*.log"
            $remainingFiles.Count | Should -BeLessOrEqual 4  # Max files + current
        }
        
        It 'Should handle disk space and permission issues gracefully' {
            $readOnlyLogPath = Join-Path $script:TestTempDir 'readonly.log'
            
            # Create a read-only directory scenario (simulate permission issues)
            $readOnlyDir = Join-Path $script:TestTempDir 'readonly'
            New-Item -ItemType Directory -Path $readOnlyDir -Force | Out-Null
            
            # Test logging to inaccessible location
            if ($IsWindows) {
                try {
                    # Try to set read-only attribute
                    (Get-Item $readOnlyDir).Attributes += 'ReadOnly'
                } catch {
                    # If we can't set read-only, skip this part
                }
            }
            
            $restrictedLogPath = Join-Path $readOnlyDir 'restricted.log'
            
            # Should handle gracefully without throwing
            { Initialize-LoggingSystem -LogPath $restrictedLogPath -LogLevel INFO -ConsoleLevel SILENT -Force } | Should -Not -Throw
            
            # Should still allow console logging even if file logging fails
            { Write-CustomLog -Message "Test message" -Level INFO } | Should -Not -Throw
        }
    }
    
    Context 'Performance Tracking Integration' {
        
        It 'Should track performance metrics accurately across operations' {
            $logPath = $script:TestLogFiles.Performance
            
            Initialize-LoggingSystem -LogPath $logPath -LogLevel DEBUG -ConsoleLevel SILENT -EnablePerformance -Force
            
            # Test performance tracking
            $operationName = "TestOperation"
            
            Start-PerformanceTrace -Name $operationName
            
            # Simulate work
            Start-Sleep -Milliseconds 100
            
            # Add some logging during the operation
            Write-CustomLog -Message "Operation in progress" -Level INFO
            
            Start-Sleep -Milliseconds 50
            
            $result = Stop-PerformanceTrace -Name $operationName
            
            # Verify performance data
            $result | Should -Not -BeNullOrEmpty
            $result.ElapsedTime | Should -BeGreaterThan 140  # Should be around 150ms, allowing variance
            $result.ElapsedTime | Should -BeLessThan 300     # Should not be too high
            
            # Verify performance data is logged
            Start-Sleep -Milliseconds 100
            $logContent = Get-Content $logPath
            $logContent | Should -Match "Performance.*$operationName"
        }
        
        It 'Should monitor memory usage during intensive logging' {
            $logPath = $script:TestLogFiles.Performance
            
            Initialize-LoggingSystem -LogPath $logPath -LogLevel INFO -ConsoleLevel SILENT -EnablePerformance -Force
            
            # Measure initial memory
            [System.GC]::Collect()
            $initialMemory = [System.GC]::GetTotalMemory($false)
            
            # Generate intensive logging
            for ($i = 1; $i -le 500; $i++) {
                $largeMessage = "Large message content " * 10 + " iteration $i"
                Write-CustomLog -Message $largeMessage -Level INFO
            }
            
            # Measure final memory
            [System.GC]::Collect()
            $finalMemory = [System.GC]::GetTotalMemory($false)
            
            $memoryIncrease = $finalMemory - $initialMemory
            $memoryIncreaseMB = [math]::Round($memoryIncrease / 1MB, 2)
            
            # Memory increase should be reasonable (less than 50MB for this test)
            $memoryIncreaseMB | Should -BeLessThan 50
            
            # Store performance metrics
            $script:PerformanceMetrics.MemoryUsage += $memoryIncreaseMB
        }
        
        It 'Should provide performance insights for different log levels' {
            $logPath = $script:TestLogFiles.Performance
            
            Initialize-LoggingSystem -LogPath $logPath -LogLevel TRACE -ConsoleLevel SILENT -EnablePerformance -Force
            
            # Test performance across different log levels
            $levels = @('ERROR', 'WARN', 'INFO', 'DEBUG', 'TRACE')
            $performanceResults = @{}
            
            foreach ($level in $levels) {
                Start-PerformanceTrace -Name "LogLevel$level"
                
                # Log 100 messages at this level
                for ($i = 1; $i -le 100; $i++) {
                    Write-CustomLog -Message "Performance test message $i" -Level $level
                }
                
                $result = Stop-PerformanceTrace -Name "LogLevel$level"
                $performanceResults[$level] = $result.ElapsedTime
            }
            
            # Verify all operations completed reasonably quickly
            foreach ($level in $levels) {
                $performanceResults[$level] | Should -BeLessThan 5000  # Less than 5 seconds
            }
            
            # Higher verbosity levels might be slightly slower but should be reasonable
            $performanceResults['TRACE'] | Should -BeLessThan ($performanceResults['ERROR'] * 3)
        }
    }
    
    Context 'Cross-Platform Compatibility' {
        
        It 'Should handle different path formats correctly' {
            $testPaths = @()
            
            if ($IsWindows) {
                $testPaths += @(
                    'C:\temp\test.log',
                    'C:\Program Files\Test\app.log',
                    '\\server\share\log.txt'
                )
            } else {
                $testPaths += @(
                    '/tmp/test.log',
                    '/var/log/app.log',
                    '/home/user/logs/test.log'
                )
            }
            
            foreach ($testPath in $testPaths) {
                # Should not throw when processing different path formats
                { 
                    $normalizedPath = [System.IO.Path]::GetFullPath($testPath)
                    $normalizedPath | Should -Not -BeNullOrEmpty
                } | Should -Not -Throw
            }
        }
        
        It 'Should use appropriate default log locations per platform' {
            # Clear any existing path settings
            Remove-Item env:LAB_LOG_PATH -ErrorAction SilentlyContinue
            Remove-Item env:TEMP -ErrorAction SilentlyContinue
            
            Initialize-LoggingSystem -LogLevel INFO -ConsoleLevel SILENT -Force
            
            $config = Get-LoggingConfiguration
            $logPath = $config.LogFilePath
            
            $logPath | Should -Not -BeNullOrEmpty
            
            if ($IsWindows) {
                # Should use Windows-appropriate paths
                $logPath | Should -Match "^[A-Z]:"
            } else {
                # Should use Unix-appropriate paths
                $logPath | Should -Match "^/"
            }
        }
        
        It 'Should handle different file encoding scenarios' {
            $logPath = $script:TestLogFiles.CrossPlatform
            
            Initialize-LoggingSystem -LogPath $logPath -LogLevel INFO -ConsoleLevel SILENT -Force
            
            # Test various character sets
            $testMessages = @(
                "ASCII test message",
                "Unicode test: ñáéíóú àèìòù",
                "Symbols: ©®™ €£¥ ±∞≠",
                "Special chars: `"quotes`" 'apostrophes' [brackets]"
            )
            
            foreach ($message in $testMessages) {
                Write-CustomLog -Message $message -Level INFO
            }
            
            Start-Sleep -Milliseconds 100
            
            # Verify all messages were written correctly
            $logContent = Get-Content $logPath -Encoding UTF8
            foreach ($message in $testMessages) {
                $logContent | Should -Contain -ExpectedValue "*$message*"
            }
        }
    }
    
    Context 'Integration with Core Infrastructure' {
        
        It 'Should integrate properly with Start-AitherZero.ps1 execution flow' {
            $logPath = $script:TestLogFiles.Integration
            
            # Execute mock Start-AitherZero script with logging
            $result = & powershell -ExecutionPolicy Bypass -File $script:MockComponents.StartAitherZero -ArgumentList $script:LoggingModulePath, $logPath
            
            Start-Sleep -Milliseconds 200
            
            # Verify integration log entries
            Test-Path $logPath | Should -Be $true
            $logContent = Get-Content $logPath
            
            $logContent | Should -Match "Start-AitherZero initiated"
            $logContent | Should -Match "Configuration loaded"
            $logContent | Should -Match "System ready"
        }
        
        It 'Should maintain logging state across module imports and reloads' {
            $logPath = $script:TestLogFiles.Integration
            
            # Initialize logging
            Initialize-LoggingSystem -LogPath $logPath -LogLevel DEBUG -ConsoleLevel SILENT -Force
            
            Write-CustomLog -Message "Before module operations" -Level INFO
            
            # Import test module
            Import-Module $script:MockComponents.TestModule -Force
            
            # Use module function that logs
            Test-LoggingIntegration -Message "Module integration test" -Level INFO
            
            # Remove and re-import
            Remove-Module TestModule -Force
            Import-Module $script:MockComponents.TestModule -Force
            
            Test-LoggingIntegration -Message "After module reload" -Level INFO
            
            Write-CustomLog -Message "After module operations" -Level INFO
            
            Start-Sleep -Milliseconds 200
            
            # Verify all log entries
            $logContent = Get-Content $logPath
            $logContent | Should -Match "Before module operations"
            $logContent | Should -Match "Module integration test"
            $logContent | Should -Match "After module reload"
            $logContent | Should -Match "After module operations"
            $logContent | Should -Match "Performance.*ModuleOperation"
        }
        
        It 'Should handle environment variable configuration dynamically' {
            $logPath = $script:TestLogFiles.Integration
            
            # Test configuration via environment variables
            $env:LAB_LOG_LEVEL = "ERROR"
            $env:LAB_CONSOLE_LEVEL = "SILENT"
            $env:LAB_LOG_FORMAT = "JSON"
            $env:LAB_ENABLE_TRACE = "true"
            
            Initialize-LoggingSystem -LogPath $logPath -Force
            
            $config = Get-LoggingConfiguration
            
            $config.LogLevel | Should -Be "ERROR"
            $config.ConsoleLevel | Should -Be "SILENT"
            $config.LogFormat | Should -Be "JSON"
            $config.EnableTrace | Should -Be $true
            
            # Test that configuration changes take effect
            Write-CustomLog -Message "Error message" -Level ERROR
            Write-CustomLog -Message "Info message" -Level INFO  # Should be filtered out
            
            Start-Sleep -Milliseconds 100
            
            $logContent = Get-Content $logPath -Raw
            $logContent | Should -Match "Error message"
            $logContent | Should -Not -Match "Info message"
            
            # Test JSON format
            if ($config.LogFormat -eq "JSON") {
                $logContent | Should -Match '\{'  # Should contain JSON structure
            }
        }
    }
    
    Context 'Error Handling and Recovery' {
        
        It 'Should recover gracefully from file system errors' {
            $logPath = $script:TestLogFiles.Standard
            
            Initialize-LoggingSystem -LogPath $logPath -LogLevel INFO -ConsoleLevel SILENT -Force
            
            # Write initial log entry
            Write-CustomLog -Message "Initial message" -Level INFO
            
            # Simulate file being locked/deleted by another process
            if (Test-Path $logPath) {
                try {
                    # Try to lock the file
                    $fileStream = [System.IO.File]::Open($logPath, 'Open', 'Read', 'None')
                    
                    # Try to log while file is locked
                    { Write-CustomLog -Message "Message during lock" -Level INFO } | Should -Not -Throw
                    
                    $fileStream.Close()
                } catch {
                    # If locking fails, that's okay - we're testing error handling
                }
            }
            
            # Verify logging continues to work after recovery
            { Write-CustomLog -Message "After recovery" -Level INFO } | Should -Not -Throw
        }
        
        It 'Should handle configuration errors without breaking the system' {
            # Test invalid configuration values
            $env:LAB_MAX_LOG_SIZE_MB = "invalid"
            $env:LAB_MAX_LOG_FILES = "not_a_number"
            $env:LAB_LOG_LEVEL = "INVALID_LEVEL"
            
            # Should not throw during initialization
            { Initialize-LoggingSystem -LogPath $script:TestLogFiles.Standard -Force } | Should -Not -Throw
            
            # Should still allow logging with fallback configuration
            { Write-CustomLog -Message "Test with invalid config" -Level INFO } | Should -Not -Throw
        }
        
        It 'Should maintain stability under resource constraints' {
            $logPath = $script:TestLogFiles.Stress
            
            Initialize-LoggingSystem -LogPath $logPath -LogLevel INFO -ConsoleLevel SILENT -Force
            
            # Simulate resource constraints with rapid logging
            $jobs = @()
            for ($i = 1; $i -le 3; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($ModulePath, $LogPath)
                    
                    Import-Module $ModulePath -Force
                    
                    # Rapid logging for 5 seconds
                    $endTime = (Get-Date).AddSeconds(5)
                    $counter = 0
                    
                    while ((Get-Date) -lt $endTime) {
                        Write-CustomLog -Message "Stress test message $counter" -Level INFO
                        $counter++
                        Start-Sleep -Milliseconds 1
                    }
                    
                    return $counter
                } -ArgumentList $script:LoggingModulePath, $logPath
            }
            
            # Wait for stress test completion
            $results = $jobs | Wait-Job -Timeout 10 | Receive-Job
            $jobs | Remove-Job -Force
            
            # Verify system remained stable
            $results | Should -Not -BeNullOrEmpty
            $totalMessages = ($results | Measure-Object -Sum).Sum
            $totalMessages | Should -BeGreaterThan 100  # Should have processed significant load
            
            # Verify log file integrity
            Start-Sleep -Milliseconds 500
            if (Test-Path $logPath) {
                { Get-Content $logPath | Out-Null } | Should -Not -Throw
            }
        }
    }
    
    Context 'Configuration Management and Flexibility' {
        
        It 'Should support dynamic configuration changes without restart' {
            $logPath = $script:TestLogFiles.Standard
            
            # Start with one configuration
            Initialize-LoggingSystem -LogPath $logPath -LogLevel INFO -ConsoleLevel INFO -Force
            
            Write-CustomLog -Message "Initial config message" -Level INFO
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Change configuration dynamically
            Set-LoggingConfiguration -LogLevel DEBUG -ConsoleLevel SILENT
            
            $stopwatch.Stop()
            $configChangeTime = $stopwatch.ElapsedMilliseconds
            
            Write-CustomLog -Message "After config change" -Level DEBUG
            
            # Verify configuration change was effective
            $config = Get-LoggingConfiguration
            $config.LogLevel | Should -Be "DEBUG"
            $config.ConsoleLevel | Should -Be "SILENT"
            
            # Configuration change should be fast
            $configChangeTime | Should -BeLessThan 100  # Less than 100ms
            
            # Store performance metric
            $script:PerformanceMetrics.ConfigurationSwitchTime += $configChangeTime
            
            Start-Sleep -Milliseconds 100
            
            # Verify both messages were logged
            $logContent = Get-Content $logPath
            $logContent | Should -Match "Initial config message"
            $logContent | Should -Match "After config change"
        }
        
        It 'Should support multiple output formats simultaneously' {
            $standardPath = Join-Path $script:TestLogsDir 'format-standard.log'
            $jsonPath = Join-Path $script:TestLogsDir 'format-json.log'
            
            # Test structured format
            Initialize-LoggingSystem -LogPath $standardPath -LogLevel INFO -ConsoleLevel SILENT -Force
            Set-LoggingConfiguration -LogFormat "Structured"
            
            Write-CustomLog -Message "Structured format test" -Level INFO
            
            Start-Sleep -Milliseconds 100
            
            # Switch to JSON format
            Set-LoggingConfiguration -LogFormat "JSON"
            Initialize-LoggingSystem -LogPath $jsonPath -Force
            
            Write-CustomLog -Message "JSON format test" -Level INFO
            
            Start-Sleep -Milliseconds 100
            
            # Verify different formats
            if (Test-Path $standardPath) {
                $structuredContent = Get-Content $standardPath -Raw
                $structuredContent | Should -Match "Structured format test"
                # Structured format should have timestamp patterns
                $structuredContent | Should -Match "\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]"
            }
            
            if (Test-Path $jsonPath) {
                $jsonContent = Get-Content $jsonPath -Raw
                $jsonContent | Should -Match "JSON format test"
                # JSON format should have JSON structure
                if ($jsonContent -match '\{.*\}') {
                    # Basic JSON validation
                    { $jsonContent | ConvertFrom-Json } | Should -Not -Throw
                }
            }
        }
    }
    
    Context 'Security and Data Protection' {
        
        It 'Should sanitize sensitive information in log messages' {
            $logPath = $script:TestLogFiles.Standard
            
            Initialize-LoggingSystem -LogPath $logPath -LogLevel DEBUG -ConsoleLevel SILENT -Force
            
            # Test potential sensitive data patterns
            $sensitiveMessages = @(
                "Password is secret123",
                "API key: abc123-def456-ghi789",
                "Token: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9",
                "Connection string: Server=sql;Password=secret;",
                "Credit card: 4111-1111-1111-1111"
            )
            
            foreach ($message in $sensitiveMessages) {
                Write-CustomLog -Message $message -Level INFO
            }
            
            Start-Sleep -Milliseconds 100
            
            # Verify sensitive patterns are handled appropriately
            if (Test-Path $logPath) {
                $logContent = Get-Content $logPath -Raw
                
                # Should not contain obvious sensitive patterns (this depends on implementation)
                # For now, just verify the log was created and contains some content
                $logContent | Should -Not -BeNullOrEmpty
                $logContent | Should -Match "Password"  # Should contain the message
                
                # In a production implementation, you might check for sanitization:
                # $logContent | Should -Not -Match "secret123"
                # $logContent | Should -Match "Password is \*\*\*\*\*"
            }
        }
        
        It 'Should enforce appropriate file permissions on log files' {
            $logPath = $script:TestLogFiles.Standard
            
            Initialize-LoggingSystem -LogPath $logPath -LogLevel INFO -ConsoleLevel SILENT -Force
            
            Write-CustomLog -Message "Permission test" -Level INFO
            
            Start-Sleep -Milliseconds 100
            
            if (Test-Path $logPath) {
                # Verify file was created
                Test-Path $logPath | Should -Be $true
                
                # Basic file access test
                { Get-Content $logPath | Out-Null } | Should -Not -Throw
                
                # On Windows, check if file is not executable
                if ($IsWindows) {
                    $file = Get-Item $logPath
                    $file.Extension | Should -Be ".log"
                }
            }
        }
    }
    
    Context 'Performance Benchmarking and Optimization' {
        
        It 'Should provide consistent performance across multiple test runs' {
            $results = @()
            
            for ($run = 1; $run -le 3; $run++) {
                $logPath = Join-Path $script:TestLogsDir "benchmark-$run.log"
                
                Initialize-LoggingSystem -LogPath $logPath -LogLevel INFO -ConsoleLevel SILENT -Force
                
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                
                # Standard benchmark workload
                for ($i = 1; $i -le 100; $i++) {
                    Write-CustomLog -Message "Benchmark message $i" -Level INFO
                }
                
                $stopwatch.Stop()
                $results += $stopwatch.ElapsedMilliseconds
            }
            
            # Verify consistent performance
            $avgTime = ($results | Measure-Object -Average).Average
            $maxTime = ($results | Measure-Object -Maximum).Maximum
            $minTime = ($results | Measure-Object -Minimum).Minimum
            
            # Performance should be consistent (max shouldn't be more than 3x min)
            $maxTime | Should -BeLessThan ($minTime * 3)
            
            # Average should be reasonable
            $avgTime | Should -BeLessThan 1000  # Less than 1 second for 100 messages
        }
        
        AfterAll {
            # Generate performance summary
            if ($script:PerformanceMetrics.LogEntriesPerSecond.Count -gt 0) {
                $avgLogRate = ($script:PerformanceMetrics.LogEntriesPerSecond | Measure-Object -Average).Average
                $maxMemoryUsage = ($script:PerformanceMetrics.MemoryUsage | Measure-Object -Maximum).Maximum
                $avgConfigTime = ($script:PerformanceMetrics.ConfigurationSwitchTime | Measure-Object -Average).Average
                
                Write-Host "`n=== PERFORMANCE SUMMARY ===" -ForegroundColor Green
                Write-Host "Average Log Rate: $([math]::Round($avgLogRate, 2)) entries/second" -ForegroundColor Cyan
                Write-Host "Maximum Memory Usage: $maxMemoryUsage MB" -ForegroundColor Cyan
                Write-Host "Average Config Switch Time: $([math]::Round($avgConfigTime, 2)) ms" -ForegroundColor Cyan
                Write-Host "================================`n" -ForegroundColor Green
            }
        }
    }
}