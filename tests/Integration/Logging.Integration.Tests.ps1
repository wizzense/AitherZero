#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../aither-core/modules/Logging'
    $script:ModuleName = 'Logging'
}

Describe 'Logging Module Integration Tests' -Tag 'Integration' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Set up test log file
        $script:TestLogPath = Join-Path $TestDrive 'integration-test.log'
        
        # Initialize logging system
        Initialize-LoggingSystem -LogPath $script:TestLogPath -LogLevel DEBUG -EnablePerformance -EnableTrace -Force
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'End-to-End Logging Workflow' {
        It 'Should log messages to file and console' {
            # Write various log levels
            Write-CustomLog -Message "Integration test info" -Level INFO
            Write-CustomLog -Message "Integration test warning" -Level WARN
            Write-CustomLog -Message "Integration test error" -Level ERROR -Exception ([System.Exception]::new("Test exception"))
            
            # Check log file exists and contains messages
            Test-Path $script:TestLogPath | Should -Be $true
            $logContent = Get-Content $script:TestLogPath -Raw
            
            $logContent | Should -Match "Integration test info"
            $logContent | Should -Match "Integration test warning"
            $logContent | Should -Match "Integration test error"
            $logContent | Should -Match "Test exception"
        }
        
        It 'Should track performance of operations' {
            # Start performance tracking
            Start-PerformanceTrace -Name "IntegrationOp" -Context @{ TestType = "Integration" }
            
            # Simulate some work
            Start-Sleep -Milliseconds 100
            
            # Stop and get results
            $result = Stop-PerformanceTrace -Name "IntegrationOp" -AdditionalContext @{ Result = "Success" }
            
            # Verify results
            $result | Should -Not -BeNullOrEmpty
            $result.Operation | Should -Be "IntegrationOp"
            $result.ElapsedMilliseconds | Should -BeGreaterThan 90
            
            # Check log contains performance info
            $logContent = Get-Content $script:TestLogPath -Raw
            $logContent | Should -Match "Performance trace started: IntegrationOp"
            $logContent | Should -Match "Performance trace completed: IntegrationOp"
            $logContent | Should -Match "TestType=Integration"
            $logContent | Should -Match "Result=Success"
        }
        
        It 'Should write trace logs when enabled' {
            Write-TraceLog -Message "Detailed trace information" -Context @{ Component = "TestComponent" }
            
            $logContent = Get-Content $script:TestLogPath -Raw
            $logContent | Should -Match "Detailed trace information"
            $logContent | Should -Match "Component=TestComponent"
            $logContent | Should -Match "\[TRACE\]"
        }
        
        It 'Should write debug context with variables' {
            $testVars = @{
                UserId = 12345
                SessionId = "ABC123"
                IsActive = $true
            }
            
            Write-DebugContext -Message "Debug state" -Variables $testVars -Context "IntegrationTest"
            
            $logContent = Get-Content $script:TestLogPath -Raw
            $logContent | Should -Match "Debug state"
            $logContent | Should -Match "UserId=12345"
            $logContent | Should -Match "SessionId=ABC123"
            $logContent | Should -Match "IsActive=True"
            $logContent | Should -Match "Scope=IntegrationTest"
        }
    }
    
    Context 'Configuration Management' {
        It 'Should update and retrieve configuration' {
            # Get initial configuration
            $initialConfig = Get-LoggingConfiguration
            
            # Update configuration
            Set-LoggingConfiguration -LogLevel TRACE -ConsoleLevel ERROR -EnableTrace
            
            # Get updated configuration
            $updatedConfig = Get-LoggingConfiguration
            
            # Verify changes
            $updatedConfig.LogLevel | Should -Be "TRACE"
            $updatedConfig.ConsoleLevel | Should -Be "ERROR"
            $updatedConfig.EnableTrace | Should -Be $true
            
            # Verify initial values preserved
            $updatedConfig.LogFilePath | Should -Be $initialConfig.LogFilePath
        }
        
        It 'Should respect log level filtering' {
            # Set restrictive log levels
            Set-LoggingConfiguration -LogLevel WARN -ConsoleLevel ERROR
            
            # Clear log file
            Clear-Content $script:TestLogPath
            
            # Write messages at different levels
            Write-CustomLog -Message "Debug message" -Level DEBUG
            Write-CustomLog -Message "Info message" -Level INFO
            Write-CustomLog -Message "Warn message" -Level WARN
            Write-CustomLog -Message "Error message" -Level ERROR
            
            # Check what got logged
            $logContent = Get-Content $script:TestLogPath -Raw
            
            $logContent | Should -Not -Match "Debug message"
            $logContent | Should -Not -Match "Info message"
            $logContent | Should -Match "Warn message"
            $logContent | Should -Match "Error message"
        }
    }
    
    Context 'Log Rotation' {
        It 'Should rotate logs when size limit is exceeded' {
            # Set small size limit
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.MaxLogSizeMB = 0.001  # 1KB
                $script:LoggingConfig.MaxLogFiles = 3
            }
            
            # Write enough data to trigger rotation
            1..100 | ForEach-Object {
                Write-CustomLog -Message ("Large message " + ("X" * 100)) -Level INFO
            }
            
            # Check for rotated files
            $logDir = Split-Path $script:TestLogPath -Parent
            $logName = [System.IO.Path]::GetFileNameWithoutExtension($script:TestLogPath)
            
            Test-Path "$logDir\$logName.log.1" | Should -Be $true
        }
    }
    
    Context 'Error Handling and Recovery' {
        It 'Should handle concurrent access gracefully' {
            $jobs = 1..5 | ForEach-Object {
                Start-Job -ScriptBlock {
                    Import-Module $using:ModulePath -Force
                    1..10 | ForEach-Object {
                        Write-CustomLog -Message "Concurrent message $_" -Level INFO
                    }
                }
            }
            
            $jobs | Wait-Job | Remove-Job
            
            # Should have logged without errors
            Test-Path $script:TestLogPath | Should -Be $true
        }
        
        It 'Should continue logging after errors' {
            # Cause an error by setting invalid path
            Set-LoggingConfiguration -LogFilePath "Z:\Invalid\Path\That\Does\Not\Exist\log.txt"
            
            # Should still be able to log (falls back to console)
            { Write-CustomLog -Message "After error" -Level ERROR } | Should -Not -Throw
            
            # Restore valid path
            Set-LoggingConfiguration -LogFilePath $script:TestLogPath
            
            # Should resume file logging
            Write-CustomLog -Message "Recovered" -Level INFO
            Get-Content $script:TestLogPath -Raw | Should -Match "Recovered"
        }
    }
    
    Context 'Module Import Function' {
        It 'Should successfully import other modules' {
            # Create a mock module
            $mockModulePath = Join-Path $TestDrive 'modules\MockModule'
            New-Item -Path $mockModulePath -ItemType Directory -Force | Out-Null
            
            $mockModuleContent = @'
function Get-MockData {
    return "Mock module loaded"
}
Export-ModuleMember -Function Get-MockData
'@
            Set-Content -Path "$mockModulePath\MockModule.psm1" -Value $mockModuleContent
            
            # Set modules path
            $env:PWSH_MODULES_PATH = Join-Path $TestDrive 'modules'
            
            # Import using the function
            $result = Import-ProjectModule -ModuleName "MockModule" -Force
            
            $result | Should -Be $true
            Get-Command Get-MockData -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            
            # Clean up
            Remove-Module MockModule -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context 'Complex Scenarios' {
        It 'Should handle nested performance traces' {
            Start-PerformanceTrace -Name "OuterOperation"
            Start-Sleep -Milliseconds 50
            
            Start-PerformanceTrace -Name "InnerOperation"
            Start-Sleep -Milliseconds 30
            $innerResult = Stop-PerformanceTrace -Name "InnerOperation"
            
            Start-Sleep -Milliseconds 20
            $outerResult = Stop-PerformanceTrace -Name "OuterOperation"
            
            # Inner should be ~30ms
            $innerResult.ElapsedMilliseconds | Should -BeGreaterThan 25
            $innerResult.ElapsedMilliseconds | Should -BeLessThan 50
            
            # Outer should be ~100ms total
            $outerResult.ElapsedMilliseconds | Should -BeGreaterThan 90
            $outerResult.ElapsedMilliseconds | Should -BeLessThan 150
        }
        
        It 'Should maintain context across log entries' {
            # Clear log
            Clear-Content $script:TestLogPath
            
            # Write related log entries
            $sessionId = [Guid]::NewGuid().ToString()
            $context = @{ SessionId = $sessionId; Component = "Integration" }
            
            Write-CustomLog -Message "Session started" -Level INFO -Context $context
            Write-TraceLog -Message "Processing step 1" -Context $context
            Write-DebugContext -Message "Current state" -Variables @{ Step = 1 }
            Write-CustomLog -Message "Session completed" -Level SUCCESS -Context $context
            
            # All entries should contain session ID
            $logContent = Get-Content $script:TestLogPath
            $sessionEntries = $logContent | Where-Object { $_ -match $sessionId }
            $sessionEntries.Count | Should -BeGreaterOrEqual 3
        }
    }
}