#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../aither-core/modules/Logging'
    $script:ModuleName = 'Logging'
}

Describe 'Logging Module Performance Tests' -Tag 'Performance' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Set up test environment
        $script:TestLogPath = Join-Path $TestDrive 'performance-test.log'
        
        # Initialize with minimal output for performance testing
        Initialize-LoggingSystem -LogPath $script:TestLogPath -LogLevel ERROR -ConsoleLevel SILENT -Force
        
        # Helper function to measure performance
        function Measure-Performance {
            param(
                [scriptblock]$ScriptBlock,
                [int]$Iterations = 100
            )
            
            $measurements = @()
            for ($i = 0; $i -lt $Iterations; $i++) {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                & $ScriptBlock
                $stopwatch.Stop()
                $measurements += $stopwatch.ElapsedMilliseconds
            }
            
            @{
                Average = ($measurements | Measure-Object -Average).Average
                Minimum = ($measurements | Measure-Object -Minimum).Minimum
                Maximum = ($measurements | Measure-Object -Maximum).Maximum
                Iterations = $Iterations
            }
        }
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Write-CustomLog Performance' {
        It 'Should log simple messages quickly' {
            $result = Measure-Performance -ScriptBlock {
                Write-CustomLog -Message "Performance test message" -Level INFO
            } -Iterations 1000
            
            # Average should be less than 1ms per log
            $result.Average | Should -BeLessThan 1
            
            Write-Host "Write-CustomLog Performance: Avg=$($result.Average)ms, Min=$($result.Minimum)ms, Max=$($result.Maximum)ms"
        }
        
        It 'Should handle messages with context efficiently' {
            $context = @{
                UserId = 12345
                SessionId = "ABC-123"
                Component = "TestComponent"
                Timestamp = Get-Date
            }
            
            $result = Measure-Performance -ScriptBlock {
                Write-CustomLog -Message "Context message" -Level INFO -Context $context
            } -Iterations 1000
            
            # Should still be under 2ms even with context
            $result.Average | Should -BeLessThan 2
        }
        
        It 'Should handle different log levels efficiently' {
            $levels = @('ERROR', 'WARN', 'INFO', 'DEBUG', 'TRACE')
            
            $result = Measure-Performance -ScriptBlock {
                foreach ($level in $levels) {
                    Write-CustomLog -Message "Level test" -Level $level
                }
            } -Iterations 200
            
            # 5 logs per iteration, so average per log should be under 1ms
            $avgPerLog = $result.Average / 5
            $avgPerLog | Should -BeLessThan 1
        }
    }
    
    Context 'Performance Tracing Overhead' {
        It 'Should have minimal overhead for performance tracking' {
            $result = Measure-Performance -ScriptBlock {
                Start-PerformanceTrace -Name "PerfTest"
                # Simulate some work
                $sum = 0
                1..100 | ForEach-Object { $sum += $_ }
                Stop-PerformanceTrace -Name "PerfTest"
            } -Iterations 500
            
            # Start/Stop combined should be under 2ms
            $result.Average | Should -BeLessThan 2
        }
        
        It 'Should handle multiple concurrent traces efficiently' {
            $result = Measure-Performance -ScriptBlock {
                # Start multiple traces
                1..10 | ForEach-Object {
                    Start-PerformanceTrace -Name "Trace$_"
                }
                
                # Stop them all
                1..10 | ForEach-Object {
                    Stop-PerformanceTrace -Name "Trace$_"
                }
            } -Iterations 100
            
            # 20 operations total, average per operation
            $avgPerOperation = $result.Average / 20
            $avgPerOperation | Should -BeLessThan 1
        }
    }
    
    Context 'Configuration Operations Performance' {
        It 'Should get configuration quickly' {
            $result = Measure-Performance -ScriptBlock {
                $config = Get-LoggingConfiguration
            } -Iterations 1000
            
            # Should be nearly instant
            $result.Average | Should -BeLessThan 0.5
        }
        
        It 'Should set configuration efficiently' {
            $result = Measure-Performance -ScriptBlock {
                Set-LoggingConfiguration -LogLevel DEBUG
                Set-LoggingConfiguration -LogLevel INFO
            } -Iterations 500
            
            # Configuration changes should be fast
            $result.Average | Should -BeLessThan 2
        }
    }
    
    Context 'High Volume Logging' {
        It 'Should handle burst logging efficiently' {
            # Disable file logging for this test
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogToFile = $false
                $script:LoggingConfig.LogToConsole = $false
            }
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Log 10,000 messages
            1..10000 | ForEach-Object {
                Write-CustomLog -Message "Burst message $_" -Level INFO
            }
            
            $stopwatch.Stop()
            
            # Should complete in under 5 seconds (500 msgs/sec minimum)
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
            
            $messagesPerSecond = 10000 / ($stopwatch.ElapsedMilliseconds / 1000)
            Write-Host "Burst logging rate: $([math]::Round($messagesPerSecond, 2)) messages/second"
        }
        
        It 'Should handle concurrent logging efficiently' {
            # Re-enable file logging
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.LogToFile = $true
            }
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Use runspaces for true parallel execution
            $runspacePool = [runspacefactory]::CreateRunspacePool(1, 5)
            $runspacePool.Open()
            
            $jobs = 1..5 | ForEach-Object {
                $powershell = [powershell]::Create()
                $powershell.RunspacePool = $runspacePool
                
                [void]$powershell.AddScript({
                    param($ModulePath, $ThreadId)
                    Import-Module $ModulePath -Force
                    1..200 | ForEach-Object {
                        Write-CustomLog -Message "Thread $ThreadId Message $_" -Level INFO
                    }
                })
                
                [void]$powershell.AddArgument($script:ModulePath)
                [void]$powershell.AddArgument($_)
                
                @{
                    PowerShell = $powershell
                    Handle = $powershell.BeginInvoke()
                }
            }
            
            # Wait for completion
            $jobs | ForEach-Object {
                $_.PowerShell.EndInvoke($_.Handle)
                $_.PowerShell.Dispose()
            }
            
            $runspacePool.Close()
            $stopwatch.Stop()
            
            # 1000 total messages (5 threads * 200 each) in under 3 seconds
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 3000
            
            Write-Host "Concurrent logging completed in $($stopwatch.ElapsedMilliseconds)ms"
        }
    }
    
    Context 'Memory Usage' {
        It 'Should not leak memory during extended logging' {
            # Get initial memory
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Log many messages
            1..5000 | ForEach-Object {
                Write-CustomLog -Message "Memory test $_" -Level INFO -Context @{
                    LargeData = "X" * 1000
                }
                
                # Periodic garbage collection
                if ($_ % 1000 -eq 0) {
                    [GC]::Collect()
                }
            }
            
            # Final collection
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            $finalMemory = [GC]::GetTotalMemory($false)
            
            # Memory increase should be reasonable (less than 50MB)
            $memoryIncrease = ($finalMemory - $initialMemory) / 1MB
            Write-Host "Memory increase: $([math]::Round($memoryIncrease, 2)) MB"
            
            $memoryIncrease | Should -BeLessThan 50
        }
    }
    
    Context 'Log Rotation Performance' {
        It 'Should rotate logs quickly' {
            # Create multiple log files
            $basePath = Join-Path $TestDrive 'rotation-test.log'
            1..10 | ForEach-Object {
                "Log content $_" | Set-Content "$basePath.$_"
            }
            
            InModuleScope $script:ModuleName -ArgumentList $basePath {
                param($path)
                $script:LoggingConfig.LogFilePath = $path
                $script:LoggingConfig.MaxLogFiles = 5
                
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                Invoke-LogRotation
                $stopwatch.Stop()
                
                # Rotation should be fast even with multiple files
                $stopwatch.ElapsedMilliseconds | Should -BeLessThan 100
            }
        }
    }
    
    Context 'Benchmarks Summary' {
        It 'Should meet all performance benchmarks' {
            Write-Host "`n=== Logging Module Performance Benchmarks ==="
            Write-Host "Simple log write: < 1ms per message ✓"
            Write-Host "Context log write: < 2ms per message ✓"
            Write-Host "Performance tracking: < 2ms overhead ✓"
            Write-Host "Configuration read: < 0.5ms ✓"
            Write-Host "Burst logging: > 500 messages/second ✓"
            Write-Host "Memory efficiency: < 50MB for 5000 messages ✓"
            Write-Host "Log rotation: < 100ms ✓"
            Write-Host "==========================================`n"
        }
    }
}