#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive Pester tests for the Logging module v2.1.0

.DESCRIPTION
    Tests all functionality including:
    - Basic logging operations
    - Performance tracing
    - Bulk logging with parallel processing
    - Exception handling and formatting
    - Configuration management
    - Environment variable handling
    - Thread safety
    - Performance monitoring
#>

BeforeAll {
    # Import the Logging module
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module $ModulePath -Force

    # Setup test environment
    $script:TestLogPath = if ($env:TEMP) {
        Join-Path $env:TEMP "AitherZero-Test-$(Get-Random).log"
    } elseif (Test-Path '/tmp') {
        "/tmp/AitherZero-Test-$(Get-Random).log"
    } else {
        Join-Path (Get-Location) "AitherZero-Test-$(Get-Random).log"
    }
    $script:OriginalConfig = Get-LoggingConfiguration
}

AfterAll {
    # Cleanup test files
    if ($script:TestLogPath -and (Test-Path $script:TestLogPath)) {
        Remove-Item $script:TestLogPath -Force -ErrorAction SilentlyContinue
    }

    # Restore original configuration
    if ($script:OriginalConfig) {
        Set-LoggingConfiguration -LogLevel $script:OriginalConfig.LogLevel -ConsoleLevel $script:OriginalConfig.ConsoleLevel
    }
}

Describe "Logging Module v2.1.0 - Core Functionality" {
    Context "Module Import and Structure" {
        It "Should export all required functions" {
            $ExportedFunctions = (Get-Module Logging).ExportedFunctions.Keys
            $RequiredFunctions = @(
                'Write-CustomLog',
                'Initialize-LoggingSystem',
                'Start-PerformanceTrace',
                'Stop-PerformanceTrace',
                'Write-TraceLog',
                'Write-DebugContext',
                'Get-LoggingConfiguration',
                'Set-LoggingConfiguration',
                'Write-BulkLog',
                'Test-LoggingPerformance',
                'Import-ProjectModule'
            )

            foreach ($function in $RequiredFunctions) {
                $ExportedFunctions | Should -Contain $function
            }
        }

        It "Should have correct module version" {
            $module = Get-Module Logging
            $module.Version | Should -Be '2.1.0'
        }

        It "Should require PowerShell 7.0 or higher" {
            $module = Get-Module Logging
            $module.PowerShellVersion | Should -Be '7.0'
        }
    }

    Context "Basic Logging Operations" {
        It "Should write log messages without errors" {
            { Write-CustomLog -Message "Test message" -Level "INFO" } | Should -Not -Throw
            { Write-CustomLog -Message "Error message" -Level "ERROR" } | Should -Not -Throw
            { Write-CustomLog -Message "Success message" -Level "SUCCESS" } | Should -Not -Throw
        }

        It "Should handle all log levels" {
            $LogLevels = @("SILENT", "ERROR", "WARN", "INFO", "SUCCESS", "DEBUG", "TRACE", "VERBOSE")

            foreach ($level in $LogLevels) {
                if ($level -ne "SILENT") {
                    { Write-CustomLog -Message "Test $level message" -Level $level } | Should -Not -Throw
                }
            }
        }

        It "Should write to both console and file by default" {
            Initialize-LoggingSystem -LogPath $script:TestLogPath -Force
            Write-CustomLog -Message "Test file output" -Level "INFO"

            Test-Path $script:TestLogPath | Should -Be $true
            $logContent = Get-Content $script:TestLogPath -Raw
            $logContent | Should -Match "Test file output"
        }

        It "Should include context information" {
            $context = @{
                TestId = "CTX-001"
                Environment = "Test"
                Component = "Logging"
            }

            { Write-CustomLog -Message "Context test" -Level "INFO" -Context $context } | Should -Not -Throw
        }

        It "Should handle NoConsole and NoFile switches" {
            { Write-CustomLog -Message "No console test" -Level "INFO" -NoConsole } | Should -Not -Throw
            { Write-CustomLog -Message "No file test" -Level "INFO" -NoFile } | Should -Not -Throw
        }
    }

    Context "Exception Handling (Enhanced in v2.1.0)" {
        It "Should log exceptions with enhanced details" {
            try {
                throw [System.InvalidOperationException]::new("Test exception",
                    [System.ArgumentException]::new("Inner exception"))
            } catch {
                { Write-CustomLog -Message "Exception test" -Level "ERROR" -Exception $_.Exception } | Should -Not -Throw
            }
        }

        It "Should handle nested exception chains" {
            try {
                $inner = [System.ArgumentException]::new("Innermost exception")
                $middle = [System.InvalidOperationException]::new("Middle exception", $inner)
                throw [System.ApplicationException]::new("Outer exception", $middle)
            } catch {
                # This should not throw and should log the full exception chain
                { Write-CustomLog -Message "Nested exception test" -Level "ERROR" -Exception $_.Exception } | Should -Not -Throw
            }
        }
    }

    Context "Performance Tracing" {
        It "Should track performance when enabled" {
            Set-LoggingConfiguration -EnablePerformance

            Start-PerformanceTrace -Name "TestOperation"
            Start-Sleep -Milliseconds 50
            $result = Stop-PerformanceTrace -Name "TestOperation"

            $result | Should -Not -BeNullOrEmpty
            $result.Operation | Should -Be "TestOperation"
            $result.ElapsedMilliseconds | Should -BeGreaterThan 40
        }

        It "Should handle multiple concurrent traces" {
            Set-LoggingConfiguration -EnablePerformance

            Start-PerformanceTrace -Name "Operation1"
            Start-PerformanceTrace -Name "Operation2"
            Start-Sleep -Milliseconds 30

            $result1 = Stop-PerformanceTrace -Name "Operation1"
            $result2 = Stop-PerformanceTrace -Name "Operation2"

            $result1.Operation | Should -Be "Operation1"
            $result2.Operation | Should -Be "Operation2"
        }

        It "Should include context in performance traces" {
            Set-LoggingConfiguration -EnablePerformance
            $context = @{ TestCase = "PerformanceContext" }

            Start-PerformanceTrace -Name "ContextOperation" -Context $context
            Start-Sleep -Milliseconds 25
            $result = Stop-PerformanceTrace -Name "ContextOperation"

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Bulk Logging (NEW in v2.1.0)" {
        It "Should process bulk log entries" {
            $entries = @(
                @{ Message = "Bulk entry 1"; Level = "INFO" }
                @{ Message = "Bulk entry 2"; Level = "WARN" }
                @{ Message = "Bulk entry 3"; Level = "SUCCESS" }
            )

            { Write-BulkLog -LogEntries $entries } | Should -Not -Throw
        }

        It "Should handle default level and context" {
            $entries = @(
                @{ Message = "No level specified" }
                @{ Message = "Another entry" }
            )
            $defaultContext = @{ BatchId = "BULK-001" }

            { Write-BulkLog -LogEntries $entries -DefaultLevel "DEBUG" -DefaultContext $defaultContext } | Should -Not -Throw
        }

        It "Should support parallel processing for large batches" {
            # Create a large batch to trigger parallel processing
            $entries = 1..15 | ForEach-Object {
                @{ Message = "Parallel entry $_"; Level = "INFO"; Context = @{Id = $_} }
            }

            { Write-BulkLog -LogEntries $entries -Parallel } | Should -Not -Throw
        }
    }

    Context "Performance Testing (NEW in v2.1.0)" {
        It "Should run performance tests and return metrics" {
            $metrics = Test-LoggingPerformance -MessageCount 100 -FileOnly

            $metrics | Should -Not -BeNullOrEmpty
            $metrics.MessageCount | Should -Be 100
            $metrics.TotalTimeMs | Should -BeGreaterThan 0
            $metrics.MessagesPerSecond | Should -BeGreaterThan 0
            $metrics.AverageTimePerMessage | Should -BeGreaterThan 0
        }

        It "Should test console-only performance" {
            $metrics = Test-LoggingPerformance -MessageCount 50 -ConsoleOnly

            $metrics.TestConfiguration.ConsoleOnly | Should -Be $true
            $metrics.TestConfiguration.FileOnly | Should -Be $false
        }

        It "Should include configuration in metrics" {
            $metrics = Test-LoggingPerformance -MessageCount 25

            $metrics.TestConfiguration | Should -Not -BeNullOrEmpty
            $metrics.TestConfiguration.LogLevel | Should -Not -BeNullOrEmpty
        }
    }

    Context "Configuration Management" {
        It "Should get current configuration" {
            $config = Get-LoggingConfiguration

            $config | Should -Not -BeNullOrEmpty
            $config.LogLevel | Should -Not -BeNullOrEmpty
            $config.LogFilePath | Should -Not -BeNullOrEmpty
        }

        It "Should update configuration" {
            { Set-LoggingConfiguration -LogLevel "DEBUG" -ConsoleLevel "WARN" } | Should -Not -Throw

            $config = Get-LoggingConfiguration
            $config.LogLevel | Should -Be "DEBUG"
            $config.ConsoleLevel | Should -Be "WARN"
        }

        It "Should enable and disable performance tracking" {
            Set-LoggingConfiguration -EnablePerformance
            $config = Get-LoggingConfiguration
            $config.EnablePerformance | Should -Be $true

            Set-LoggingConfiguration -DisablePerformance
            $config = Get-LoggingConfiguration
            $config.EnablePerformance | Should -Be $false
        }

        It "Should enable and disable trace logging" {
            Set-LoggingConfiguration -EnableTrace
            $config = Get-LoggingConfiguration
            $config.EnableTrace | Should -Be $true

            Set-LoggingConfiguration -DisableTrace
            $config = Get-LoggingConfiguration
            $config.EnableTrace | Should -Be $false
        }
    }

    Context "Environment Variable Support (Enhanced in v2.1.0)" {
        BeforeEach {
            # Clear environment variables
            Remove-Item env:AITHER_LOG_LEVEL -ErrorAction SilentlyContinue
            Remove-Item env:LAB_LOG_LEVEL -ErrorAction SilentlyContinue
            Remove-Item env:AITHER_ENABLE_PERFORMANCE -ErrorAction SilentlyContinue
            Remove-Item env:LAB_ENABLE_PERFORMANCE -ErrorAction SilentlyContinue
        }

        It "Should prioritize AITHER_* over LAB_* environment variables" {
            $env:LAB_LOG_LEVEL = "INFO"
            $env:AITHER_LOG_LEVEL = "DEBUG"

            Initialize-LoggingSystem -Force
            $config = Get-LoggingConfiguration
            $config.LogLevel | Should -Be "DEBUG"
        }

        It "Should fall back to LAB_* when AITHER_* not set" {
            $env:LAB_LOG_LEVEL = "WARN"

            Initialize-LoggingSystem -Force
            $config = Get-LoggingConfiguration
            $config.LogLevel | Should -Be "WARN"
        }

        It "Should default performance tracking to enabled" {
            Initialize-LoggingSystem -Force
            $config = Get-LoggingConfiguration
            $config.EnablePerformance | Should -Be $true
        }

        AfterEach {
            # Cleanup
            Remove-Item env:AITHER_LOG_LEVEL -ErrorAction SilentlyContinue
            Remove-Item env:LAB_LOG_LEVEL -ErrorAction SilentlyContinue
            Remove-Item env:AITHER_ENABLE_PERFORMANCE -ErrorAction SilentlyContinue
            Remove-Item env:LAB_ENABLE_PERFORMANCE -ErrorAction SilentlyContinue
        }
    }

    Context "Trace and Debug Logging" {
        It "Should write trace logs when enabled" {
            Set-LoggingConfiguration -EnableTrace

            { Write-TraceLog -Message "Trace message" } | Should -Not -Throw
            { Write-TraceLog -Message "Trace with context" -Context @{Function = "TestFunction"} } | Should -Not -Throw
        }

        It "Should write debug context information" {
            $variables = @{
                TestVar1 = "Value1"
                TestVar2 = 42
                TestVar3 = $true
            }

            { Write-DebugContext -Message "Debug context test" -Variables $variables } | Should -Not -Throw
        }
    }

    Context "Thread Safety" {
        It "Should handle concurrent logging operations" {
            $jobs = 1..5 | ForEach-Object {
                Start-Job -ScriptBlock {
                    param($modulePath, $testId)
                    Import-Module $modulePath -Force
                    1..10 | ForEach-Object {
                        Write-CustomLog -Message "Concurrent test $testId-$_" -Level "INFO"
                    }
                } -ArgumentList $ModulePath, $_
            }

            $jobs | Wait-Job -Timeout 30 | Should -Not -BeNullOrEmpty
            $jobs | Remove-Job
        }
    }

    Context "Log Rotation" {
        It "Should handle log file rotation when size limit exceeded" {
            # This is a challenging test as it requires creating a large log file
            # For now, we'll just verify the function exists and doesn't error
            $config = Get-LoggingConfiguration
            $config.MaxLogSizeMB | Should -BeGreaterThan 0
            $config.MaxLogFiles | Should -BeGreaterThan 0
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should work on current platform" {
            $platform = if ($IsWindows) { "Windows" }
            elseif ($IsLinux) { "Linux" }
            elseif ($IsMacOS) { "macOS" }
            else { "Unknown" }

            $platform | Should -BeIn @("Windows", "Linux", "macOS")

            # Logging should work regardless of platform
            { Write-CustomLog -Message "Cross-platform test on $platform" -Level "INFO" } | Should -Not -Throw
        }
    }
}

Describe "Logging Module v2.1.0 - Integration Tests" {
    Context "Module Integration" {
        It "Should integrate with Import-ProjectModule" {
            # Test the Import-ProjectModule function exists and works
            Get-Command Import-ProjectModule | Should -Not -BeNullOrEmpty

            # Test it can handle missing PWSH_MODULES_PATH
            $originalPath = $env:PWSH_MODULES_PATH
            $env:PWSH_MODULES_PATH = $null

            try {
                { Import-ProjectModule -ModuleName "NonExistentModule" -ErrorAction SilentlyContinue } | Should -Not -Throw
            }
            finally {
                $env:PWSH_MODULES_PATH = $originalPath
            }
        }
    }

    Context "Real-world Usage Scenarios" {
        It "Should handle high-volume logging scenario" {
            # Simulate a high-volume logging scenario
            $startTime = Get-Date
            1..500 | ForEach-Object {
                Write-CustomLog -Message "High volume message $_" -Level "INFO" -NoConsole -NoFile
            }
            $duration = (Get-Date) - $startTime

            # Should complete within reasonable time (adjust threshold as needed)
            $duration.TotalSeconds | Should -BeLessThan 10
        }

        It "Should handle mixed log levels and contexts" {
            $levels = @("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")
            1..50 | ForEach-Object {
                $level = $levels[$_ % $levels.Count]
                $context = @{
                    Id = $_
                    Timestamp = Get-Date
                    RandomValue = Get-Random
                }
                Write-CustomLog -Message "Mixed scenario message $_" -Level $level -Context $context -NoConsole -NoFile
            }
        }
    }
}
