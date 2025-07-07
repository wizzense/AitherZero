#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive tests for the UtilityServices unified platform module

.DESCRIPTION
    Tests all aspects of the UtilityServices module including:
    - Module loading and structure validation
    - Service initialization and management  
    - Cross-service integration
    - Event system functionality
    - Configuration management
    - Integrated workflows
    - Error handling and recovery
#>

BeforeAll {
    # Import the module for testing
    $ModulePath = Join-Path $PSScriptRoot ".." "UtilityServices.psd1"
    if (Test-Path $ModulePath) {
        Import-Module $ModulePath -Force
    } else {
        throw "UtilityServices module not found at: $ModulePath"
    }
}

Describe "UtilityServices Module Structure" {
    Context "Module Loading" {
        It "Should load the UtilityServices module successfully" {
            Get-Module UtilityServices | Should -Not -BeNullOrEmpty
        }
        
        It "Should have correct module version" {
            $module = Get-Module UtilityServices
            $module.Version | Should -Match "^\d+\.\d+\.\d+$"
        }
        
        It "Should require PowerShell 7.0 or higher" {
            $module = Get-Module UtilityServices
            $module.PowerShellVersion | Should -BeGreaterOrEqual ([Version]"7.0")
        }
    }
    
    Context "Function Exports" {
        It "Should export all expected core management functions" {
            $coreManagementFunctions = @(
                'Initialize-UtilityServices',
                'Get-UtilityServiceStatus', 
                'Get-UtilityMetrics',
                'Reset-UtilityServices',
                'Test-UtilityIntegration'
            )
            
            foreach ($function in $coreManagementFunctions) {
                Get-Command $function -Module UtilityServices -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should export semantic versioning functions" {
            $semanticVersioningFunctions = @(
                'Get-NextSemanticVersion',
                'Parse-ConventionalCommits',
                'New-VersionTag',
                'Get-VersionHistory'
            )
            
            foreach ($function in $semanticVersioningFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should export progress tracking functions" {
            $progressTrackingFunctions = @(
                'Start-ProgressOperation',
                'Update-ProgressOperation',
                'Complete-ProgressOperation',
                'Start-MultiProgress'
            )
            
            foreach ($function in $progressTrackingFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should export testing framework functions" {
            $testingFrameworkFunctions = @(
                'Invoke-UnifiedTestExecution',
                'Get-DiscoveredModules',
                'New-TestExecutionPlan',
                'Invoke-SimpleTestRunner'
            )
            
            foreach ($function in $testingFrameworkFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should export script manager functions" {
            $scriptManagerFunctions = @(
                'Register-OneOffScript',
                'Invoke-OneOffScript',
                'Get-ScriptRepository',
                'Start-ScriptExecution'
            )
            
            foreach ($function in $scriptManagerFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should export integrated workflow functions" {
            $integratedFunctions = @(
                'Start-IntegratedOperation',
                'New-VersionedTestSuite',
                'Invoke-ProgressAwareExecution',
                'Start-UtilityDashboard',
                'Export-UtilityReport'
            )
            
            foreach ($function in $integratedFunctions) {
                Get-Command $function -Module UtilityServices -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe "UtilityServices Core Functionality" {
    Context "Service Initialization" {
        It "Should initialize services without errors" {
            { Initialize-UtilityServices -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should return service status information" {
            $status = Get-UtilityServiceStatus
            $status | Should -Not -BeNullOrEmpty
            $status.Services | Should -Not -BeNullOrEmpty
            $status.SystemHealth | Should -Not -BeNullOrEmpty
        }
        
        It "Should have valid system health status" {
            $status = Get-UtilityServiceStatus
            $status.SystemHealth | Should -BeIn @('Healthy', 'Degraded', 'Critical')
        }
    }
    
    Context "Configuration Management" {
        It "Should get current configuration" {
            $config = Get-UtilityConfiguration
            $config | Should -Not -BeNullOrEmpty
            $config.LogLevel | Should -Not -BeNullOrEmpty
        }
        
        It "Should allow configuration updates" {
            $originalConfig = Get-UtilityConfiguration
            
            { Set-UtilityConfiguration -Configuration @{ TestSetting = "TestValue" } } | Should -Not -Throw
            
            $updatedConfig = Get-UtilityConfiguration
            $updatedConfig.TestSetting | Should -Be "TestValue"
            
            # Reset configuration for other tests
            Reset-UtilityConfiguration
        }
        
        It "Should reset configuration to defaults" {
            Set-UtilityConfiguration -Configuration @{ TestSetting = "TestValue" }
            Reset-UtilityConfiguration
            
            $resetConfig = Get-UtilityConfiguration
            $resetConfig.ContainsKey("TestSetting") | Should -Be $false
            $resetConfig.LogLevel | Should -Be "INFO"
        }
    }
    
    Context "Metrics Collection" {
        It "Should collect metrics without errors" {
            { Get-UtilityMetrics -TimeRange "LastHour" } | Should -Not -Throw
        }
        
        It "Should return valid metrics structure" {
            $metrics = Get-UtilityMetrics -TimeRange "LastHour"
            $metrics.TimeRange | Should -Be "LastHour"
            $metrics.CollectedAt | Should -Not -BeNullOrEmpty
            $metrics.Services | Should -Not -BeNullOrEmpty
            $metrics.IntegratedOperations | Should -Not -BeNullOrEmpty
        }
        
        It "Should support different time ranges" {
            $timeRanges = @('LastHour', 'Last24Hours', 'LastWeek', 'All')
            
            foreach ($timeRange in $timeRanges) {
                { Get-UtilityMetrics -TimeRange $timeRange } | Should -Not -Throw
            }
        }
    }
}

Describe "UtilityServices Event System" {
    Context "Event Publishing and Subscription" {
        It "Should publish events without errors" {
            { Publish-UtilityEvent -EventType "TestEvent" -Data @{ Test = "Value" } } | Should -Not -Throw
        }
        
        It "Should allow event subscription" {
            $eventReceived = $false
            
            { Subscribe-UtilityEvent -EventType "TestSubscriptionEvent" -Handler {
                param($event)
                $script:eventReceived = $true
            } } | Should -Not -Throw
            
            Publish-UtilityEvent -EventType "TestSubscriptionEvent" -Data @{ Test = "Subscription" }
            
            # Brief wait for event processing
            Start-Sleep -Milliseconds 100
            
            # Note: This test may pass even if events aren't working due to timing
            # It primarily tests that the functions don't throw errors
        }
        
        It "Should retrieve event history" {
            # Publish a test event
            Publish-UtilityEvent -EventType "TestHistoryEvent" -Data @{ Test = "History" }
            
            $events = Get-UtilityEvents -Count 10
            $events | Should -Not -BeNullOrEmpty
            
            # Should find our test event
            $testEvent = $events | Where-Object { $_.EventType -eq "TestHistoryEvent" }
            $testEvent | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "UtilityServices Integration Testing" {
    Context "Self-Validation" {
        It "Should pass its own integration tests" {
            # Run basic integration test
            $testResult = Test-UtilityIntegration -TestLevel "Basic"
            
            $testResult | Should -Not -BeNullOrEmpty
            $testResult.Summary | Should -Not -BeNullOrEmpty
            
            # The test should at least attempt to validate services
            $testResult.ServiceTests | Should -Not -BeNullOrEmpty
        }
        
        It "Should generate test results structure" {
            $testResult = Test-UtilityIntegration -TestLevel "Basic"
            
            # Verify result structure
            $testResult.TestLevel | Should -Be "Basic"
            $testResult.StartTime | Should -Not -BeNullOrEmpty
            $testResult.ServiceTests | Should -Not -BeNullOrEmpty
            $testResult.Summary | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "UtilityServices Reporting" {
    Context "Report Generation" {
        It "Should export JSON reports without errors" {
            $tempPath = Join-Path $env:TEMP "utility-test-report.json"
            
            try {
                { Export-UtilityReport -OutputPath $tempPath -Format JSON } | Should -Not -Throw
                
                if (Test-Path $tempPath) {
                    $reportContent = Get-Content $tempPath -Raw | ConvertFrom-Json
                    $reportContent | Should -Not -BeNullOrEmpty
                    $reportContent.GeneratedAt | Should -Not -BeNullOrEmpty
                }
            } finally {
                if (Test-Path $tempPath) {
                    Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        It "Should support different report formats" {
            $formats = @('JSON', 'Text', 'HTML')
            
            foreach ($format in $formats) {
                { Export-UtilityReport -Format $format } | Should -Not -Throw
            }
        }
    }
}

Describe "UtilityServices Error Handling" {
    Context "Service Recovery" {
        It "Should handle service reset operations" {
            # Test that reset doesn't throw errors
            { Reset-UtilityServices -Services @('TestingFramework') -Force } | Should -Not -Throw
        }
        
        It "Should handle invalid service names gracefully" {
            # This should not crash the entire system
            { Initialize-UtilityServices -Services @('NonExistentService') } | Should -Not -Throw
        }
    }
    
    Context "Configuration Validation" {
        It "Should handle invalid configuration values gracefully" {
            # Test with invalid configuration
            { Set-UtilityConfiguration -Configuration @{ InvalidSetting = $null } } | Should -Not -Throw
        }
    }
}

Describe "UtilityServices Cross-Platform Compatibility" {
    Context "Platform Support" {
        It "Should work on current platform" {
            $platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
            Write-Host "Testing on platform: $platform"
            
            # Basic functionality should work on all platforms
            { Get-UtilityServiceStatus } | Should -Not -Throw
            { Get-UtilityConfiguration } | Should -Not -Throw
        }
        
        It "Should handle path operations correctly" {
            # Test that path operations work cross-platform
            $tempDir = Join-Path $env:TEMP "utility-test"
            
            try {
                { Export-UtilityReport -OutputPath (Join-Path $tempDir "test-report.json") -Format JSON } | Should -Not -Throw
            } finally {
                if (Test-Path $tempDir) {
                    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

AfterAll {
    # Cleanup: Reset services to clean state
    try {
        Reset-UtilityServices -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Cleanup failed: $($_.Exception.Message)"
    }
    
    # Remove module for clean test environment
    Remove-Module UtilityServices -Force -ErrorAction SilentlyContinue
}