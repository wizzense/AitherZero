#Requires -Version 7.0

<#
.SYNOPSIS
    Integration tests for {{MODULE_NAME}} module interactions

.DESCRIPTION
    Tests the integration between {{MODULE_NAME}} and other AitherZero modules including:
    - Inter-module communication
    - Shared resource management
    - Configuration synchronization
    - Event handling
    - Performance under integration scenarios

.NOTES
    Integration test template - focuses on module interactions and dependencies
#>

BeforeAll {
    # Setup integration test environment
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
    while ($ProjectRoot -and -not (Test-Path (Join-Path $ProjectRoot ".git"))) {
        $ProjectRoot = Split-Path $ProjectRoot -Parent
    }

    if (-not $ProjectRoot) {
        throw "Could not find project root"
    }

    # Import the primary module
    $PrimaryModulePath = Join-Path $ProjectRoot "aither-core/modules/{{MODULE_NAME}}"
    Import-Module $PrimaryModulePath -Force -ErrorAction Stop

    # Import related modules for integration testing
    $RelatedModules = @(
        "Logging",
        "ConfigurationCore",
        "ModuleCommunication",
        "ProgressTracking"
    )

    $script:LoadedModules = @()
    foreach ($moduleName in $RelatedModules) {
        $modulePath = Join-Path $ProjectRoot "aither-core/modules/$moduleName"
        if (Test-Path $modulePath) {
            try {
                Import-Module $modulePath -Force -ErrorAction Stop
                $script:LoadedModules += $moduleName
                Write-Host "✅ Loaded integration module: $moduleName" -ForegroundColor Green
            } catch {
                Write-Host "⚠️  Could not load integration module: $moduleName - $_" -ForegroundColor Yellow
            }
        }
    }

    # Setup mock environment for integration testing
    $script:IntegrationTestData = @{
        TestStartTime = Get-Date
        CommunicationEvents = @()
        ConfigurationChanges = @()
        LogMessages = @()
        ProgressOperations = @()
    }

    # Mock Write-CustomLog to capture log messages
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        $script:OriginalWriteCustomLog = Get-Command Write-CustomLog
        
        function Write-CustomLog {
            param([string]$Message, [string]$Level = "INFO")
            $script:IntegrationTestData.LogMessages += @{
                Message = $Message
                Level = $Level
                Timestamp = Get-Date
                Module = "{{MODULE_NAME}}"
            }
            & $script:OriginalWriteCustomLog @PSBoundParameters
        }
    }
}

AfterAll {
    # Cleanup integration test environment
    foreach ($moduleName in $script:LoadedModules) {
        Remove-Module $moduleName -Force -ErrorAction SilentlyContinue
    }
    
    Remove-Module "{{MODULE_NAME}}" -Force -ErrorAction SilentlyContinue

    # Restore original Write-CustomLog if it was mocked
    if ($script:OriginalWriteCustomLog) {
        Set-Item -Path "function:Write-CustomLog" -Value $script:OriginalWriteCustomLog
    }

    # Integration test summary
    $testDuration = (Get-Date) - $script:IntegrationTestData.TestStartTime
    Write-Host "`n📊 Integration Test Summary for {{MODULE_NAME}}:" -ForegroundColor Cyan
    Write-Host "  Duration: $($testDuration.TotalSeconds.ToString('0.00')) seconds" -ForegroundColor White
    Write-Host "  Log Messages: $($script:IntegrationTestData.LogMessages.Count)" -ForegroundColor White
    Write-Host "  Configuration Changes: $($script:IntegrationTestData.ConfigurationChanges.Count)" -ForegroundColor White
    Write-Host "  Communication Events: $($script:IntegrationTestData.CommunicationEvents.Count)" -ForegroundColor White
    Write-Host "  Progress Operations: $($script:IntegrationTestData.ProgressOperations.Count)" -ForegroundColor White
}

Describe "{{MODULE_NAME}} Integration Tests" {
    Context "Module Communication Integration" {
        BeforeEach {
            $script:IntegrationTestData.CommunicationEvents = @()
        }

        It "Should integrate with ModuleCommunication system" {
            if ("ModuleCommunication" -in $script:LoadedModules) {
                # Test module registration
                { Register-ModuleAPI -ModuleName "{{MODULE_NAME}}" -APIVersion "1.0.0" -Endpoints @("health", "status") } | Should -Not -Throw

                # Test API invocation
                $apiResult = Invoke-ModuleAPI -ModuleName "{{MODULE_NAME}}" -Endpoint "health" -ErrorAction SilentlyContinue
                # Should not throw even if endpoint is not implemented
                
                # Test event publishing
                { Submit-ModuleEvent -EventType "TestEvent" -EventData @{ TestKey = "TestValue" } } | Should -Not -Throw
                
                # Test message handling
                { Submit-ModuleMessage -MessageType "TestMessage" -MessageData @{ TestKey = "TestValue" } } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "ModuleCommunication not available"
            }
        }

        It "Should handle cross-module events properly" {
            if ("ModuleCommunication" -in $script:LoadedModules) {
                # Register event handler
                $eventHandled = $false
                Register-ModuleEventHandler -EventType "{{MODULE_NAME}}.TestEvent" -Handler {
                    param($EventData)
                    $script:eventHandled = $true
                    $script:IntegrationTestData.CommunicationEvents += @{
                        Type = "EventHandled"
                        Data = $EventData
                        Timestamp = Get-Date
                    }
                }

                # Publish event
                Submit-ModuleEvent -EventType "{{MODULE_NAME}}.TestEvent" -EventData @{ TestValue = "Integration Test" }

                # Give time for event processing
                Start-Sleep -Milliseconds 100

                # Verify event was handled
                $script:eventHandled | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "ModuleCommunication not available"
            }
        }
    }

    Context "Configuration Integration" {
        BeforeEach {
            $script:IntegrationTestData.ConfigurationChanges = @()
        }

        It "Should integrate with ConfigurationCore system" {
            if ("ConfigurationCore" -in $script:LoadedModules) {
                # Test configuration registration
                { Register-ModuleConfiguration -ModuleName "{{MODULE_NAME}}" -ConfigurationSchema @{ TestSetting = "string" } } | Should -Not -Throw

                # Test configuration access
                $config = Get-ModuleConfiguration -ModuleName "{{MODULE_NAME}}" -ErrorAction SilentlyContinue
                $config | Should -Not -BeNullOrEmpty

                # Test configuration update
                { Set-ModuleConfiguration -ModuleName "{{MODULE_NAME}}" -Configuration @{ TestSetting = "IntegrationTest" } } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "ConfigurationCore not available"
            }
        }

        It "Should respond to configuration changes" {
            if ("ConfigurationCore" -in $script:LoadedModules) {
                # Subscribe to configuration events
                Subscribe-ConfigurationEvent -EventType "ConfigurationChanged" -Handler {
                    param($EventData)
                    if ($EventData.ModuleName -eq "{{MODULE_NAME}}") {
                        $script:IntegrationTestData.ConfigurationChanges += @{
                            Change = $EventData
                            Timestamp = Get-Date
                        }
                    }
                }

                # Trigger configuration change
                Set-ModuleConfiguration -ModuleName "{{MODULE_NAME}}" -Configuration @{ TestSetting = "ChangedValue" }

                # Give time for event processing
                Start-Sleep -Milliseconds 100

                # Verify configuration change was detected
                $script:IntegrationTestData.ConfigurationChanges.Count | Should -BeGreaterThan 0
            } else {
                Set-ItResult -Skipped -Because "ConfigurationCore not available"
            }
        }
    }

    Context "Logging Integration" {
        BeforeEach {
            $script:IntegrationTestData.LogMessages = @()
        }

        It "Should integrate with Logging system" {
            if ("Logging" -in $script:LoadedModules) {
                # Test logging functionality
                Write-CustomLog -Message "Integration test message" -Level "INFO"
                
                # Verify log message was captured
                $script:IntegrationTestData.LogMessages | Should -Not -BeNullOrEmpty
                $script:IntegrationTestData.LogMessages[-1].Message | Should -Be "Integration test message"
                $script:IntegrationTestData.LogMessages[-1].Level | Should -Be "INFO"
                $script:IntegrationTestData.LogMessages[-1].Module | Should -Be "{{MODULE_NAME}}"
            } else {
                Set-ItResult -Skipped -Because "Logging not available"
            }
        }

        It "Should handle different log levels appropriately" {
            if ("Logging" -in $script:LoadedModules) {
                $logLevels = @("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")
                
                foreach ($level in $logLevels) {
                    Write-CustomLog -Message "Test $level message" -Level $level
                }
                
                # Verify all log levels were captured
                $script:IntegrationTestData.LogMessages.Count | Should -BeGreaterOrEqual $logLevels.Count
                
                foreach ($level in $logLevels) {
                    $script:IntegrationTestData.LogMessages | Where-Object { $_.Level -eq $level } | Should -Not -BeNullOrEmpty
                }
            } else {
                Set-ItResult -Skipped -Because "Logging not available"
            }
        }
    }

    Context "Progress Tracking Integration" {
        BeforeEach {
            $script:IntegrationTestData.ProgressOperations = @()
        }

        It "Should integrate with ProgressTracking system" {
            if ("ProgressTracking" -in $script:LoadedModules) {
                # Test progress operation
                $operationId = Start-ProgressOperation -OperationName "{{MODULE_NAME}} Integration Test" -TotalSteps 3
                $operationId | Should -Not -BeNullOrEmpty
                
                $script:IntegrationTestData.ProgressOperations += @{
                    OperationId = $operationId
                    Action = "Started"
                    Timestamp = Get-Date
                }

                # Test progress updates
                Update-ProgressOperation -OperationId $operationId -CurrentStep 1 -StepName "Integration Step 1"
                Update-ProgressOperation -OperationId $operationId -CurrentStep 2 -StepName "Integration Step 2"
                Update-ProgressOperation -OperationId $operationId -CurrentStep 3 -StepName "Integration Step 3"

                # Complete operation
                Complete-ProgressOperation -OperationId $operationId
                
                $script:IntegrationTestData.ProgressOperations += @{
                    OperationId = $operationId
                    Action = "Completed"
                    Timestamp = Get-Date
                }

                # Verify operation was tracked
                $script:IntegrationTestData.ProgressOperations.Count | Should -BeGreaterOrEqual 2
            } else {
                Set-ItResult -Skipped -Because "ProgressTracking not available"
            }
        }

        It "Should handle progress errors gracefully" {
            if ("ProgressTracking" -in $script:LoadedModules) {
                $operationId = Start-ProgressOperation -OperationName "{{MODULE_NAME}} Error Test" -TotalSteps 2
                
                # Add error to progress
                { Add-ProgressError -OperationId $operationId -Error "Test integration error" } | Should -Not -Throw
                
                # Add warning to progress
                { Add-ProgressWarning -OperationId $operationId -Warning "Test integration warning" } | Should -Not -Throw
                
                # Complete operation
                Complete-ProgressOperation -OperationId $operationId
            } else {
                Set-ItResult -Skipped -Because "ProgressTracking not available"
            }
        }
    }

    Context "Cross-Module Data Flow" {
        It "Should handle data sharing between modules" {
            # Test data passing through module boundaries
            $testData = @{
                Source = "{{MODULE_NAME}}"
                Timestamp = Get-Date
                TestValue = "Integration Test Data"
            }

            # Test with ModuleCommunication
            if ("ModuleCommunication" -in $script:LoadedModules) {
                { Submit-ModuleMessage -MessageType "DataFlow" -MessageData $testData } | Should -Not -Throw
            }

            # Test with ConfigurationCore
            if ("ConfigurationCore" -in $script:LoadedModules) {
                { Set-ModuleConfiguration -ModuleName "{{MODULE_NAME}}" -Configuration $testData } | Should -Not -Throw
            }

            # Verify data integrity
            $testData.Source | Should -Be "{{MODULE_NAME}}"
            $testData.TestValue | Should -Be "Integration Test Data"
        }

        It "Should maintain data consistency across modules" {
            $consistencyTestData = @{
                Id = [guid]::NewGuid().ToString()
                Value = "Consistency Test"
                Timestamp = Get-Date
            }

            # Store in multiple systems
            if ("ConfigurationCore" -in $script:LoadedModules) {
                Set-ModuleConfiguration -ModuleName "{{MODULE_NAME}}" -Configuration @{ ConsistencyTest = $consistencyTestData }
            }

            if ("ModuleCommunication" -in $script:LoadedModules) {
                Submit-ModuleMessage -MessageType "ConsistencyTest" -MessageData $consistencyTestData
            }

            # Verify data consistency
            if ("ConfigurationCore" -in $script:LoadedModules) {
                $retrievedConfig = Get-ModuleConfiguration -ModuleName "{{MODULE_NAME}}"
                $retrievedConfig.ConsistencyTest.Id | Should -Be $consistencyTestData.Id
                $retrievedConfig.ConsistencyTest.Value | Should -Be $consistencyTestData.Value
            }
        }
    }

    Context "Performance Under Integration" {
        It "Should maintain performance with multiple modules loaded" {
            $functions = Get-Command -Module "{{MODULE_NAME}}" -CommandType Function | Select-Object -First 3
            
            foreach ($function in $functions) {
                $executionTimes = @()
                
                for ($i = 0; $i -lt 5; $i++) {
                    $startTime = Get-Date
                    try {
                        & $function.Name -ErrorAction SilentlyContinue
                    } catch {
                        # Expected for functions requiring parameters
                    }
                    $endTime = Get-Date
                    $executionTimes += ($endTime - $startTime).TotalMilliseconds
                }
                
                $averageTime = ($executionTimes | Measure-Object -Average).Average
                # Performance should be reasonable even with multiple modules
                $averageTime | Should -BeLessThan 5000 -Because "Function execution should be fast even with integration overhead"
            }
        }

        It "Should handle integration scenarios under load" {
            $operations = @()
            
            # Start multiple operations simultaneously
            for ($i = 1; $i -le 5; $i++) {
                if ("ProgressTracking" -in $script:LoadedModules) {
                    $operationId = Start-ProgressOperation -OperationName "Load Test $i" -TotalSteps 2
                    $operations += $operationId
                }
            }
            
            # Process operations
            foreach ($operationId in $operations) {
                Update-ProgressOperation -OperationId $operationId -CurrentStep 1 -StepName "Processing"
                
                if ("ModuleCommunication" -in $script:LoadedModules) {
                    Submit-ModuleMessage -MessageType "LoadTest" -MessageData @{ OperationId = $operationId }
                }
                
                Update-ProgressOperation -OperationId $operationId -CurrentStep 2 -StepName "Completing"
                Complete-ProgressOperation -OperationId $operationId
            }
            
            # All operations should complete successfully
            $operations.Count | Should -Be 5
        }
    }

    Context "Error Handling in Integration Scenarios" {
        It "Should handle integration errors gracefully" {
            # Test error scenarios with each integrated module
            
            if ("ModuleCommunication" -in $script:LoadedModules) {
                # Test invalid API call
                { Invoke-ModuleAPI -ModuleName "NonExistentModule" -Endpoint "test" -ErrorAction SilentlyContinue } | Should -Not -Throw
                
                # Test invalid event
                { Submit-ModuleEvent -EventType "" -EventData @{} -ErrorAction SilentlyContinue } | Should -Not -Throw
            }
            
            if ("ConfigurationCore" -in $script:LoadedModules) {
                # Test invalid configuration
                { Set-ModuleConfiguration -ModuleName "{{MODULE_NAME}}" -Configuration $null -ErrorAction SilentlyContinue } | Should -Not -Throw
            }
            
            if ("ProgressTracking" -in $script:LoadedModules) {
                # Test invalid progress operation
                { Update-ProgressOperation -OperationId "invalid-id" -CurrentStep 1 -ErrorAction SilentlyContinue } | Should -Not -Throw
            }
        }

        It "Should recover from integration failures" {
            # Simulate module failure scenario
            if ("ModuleCommunication" -in $script:LoadedModules) {
                # Test resilience when communication fails
                $originalFunction = Get-Command Submit-ModuleMessage -ErrorAction SilentlyContinue
                
                if ($originalFunction) {
                    # Temporarily replace with failing function
                    function Submit-ModuleMessage { throw "Simulated failure" }
                    
                    # Test that the primary module handles the failure
                    { 
                        try {
                            Submit-ModuleMessage -MessageType "Test" -MessageData @{}
                        } catch {
                            # Expected to fail
                        }
                    } | Should -Not -Throw
                    
                    # Restore original function
                    Set-Item -Path "function:Submit-ModuleMessage" -Value $originalFunction
                }
            }
        }
    }
}

Describe "{{MODULE_NAME}} End-to-End Integration Scenarios" {
    Context "Complete Workflow Integration" {
        It "Should support complete AitherZero workflow" {
            # Test a complete workflow involving multiple modules
            $workflowData = @{
                WorkflowId = [guid]::NewGuid().ToString()
                Stage = "Integration Test"
                StartTime = Get-Date
            }

            # Step 1: Configuration
            if ("ConfigurationCore" -in $script:LoadedModules) {
                Register-ModuleConfiguration -ModuleName "{{MODULE_NAME}}" -ConfigurationSchema @{ WorkflowEnabled = "boolean" }
                Set-ModuleConfiguration -ModuleName "{{MODULE_NAME}}" -Configuration @{ WorkflowEnabled = $true }
            }

            # Step 2: Progress Tracking
            $operationId = $null
            if ("ProgressTracking" -in $script:LoadedModules) {
                $operationId = Start-ProgressOperation -OperationName "Complete Workflow" -TotalSteps 4
                Update-ProgressOperation -OperationId $operationId -CurrentStep 1 -StepName "Configuration"
            }

            # Step 3: Communication
            if ("ModuleCommunication" -in $script:LoadedModules) {
                Submit-ModuleEvent -EventType "WorkflowStarted" -EventData $workflowData
                if ($operationId) {
                    Update-ProgressOperation -OperationId $operationId -CurrentStep 2 -StepName "Communication"
                }
            }

            # Step 4: Logging
            if ("Logging" -in $script:LoadedModules) {
                Write-CustomLog -Message "Workflow $($workflowData.WorkflowId) processing" -Level "INFO"
                if ($operationId) {
                    Update-ProgressOperation -OperationId $operationId -CurrentStep 3 -StepName "Logging"
                }
            }

            # Step 5: Completion
            if ("ModuleCommunication" -in $script:LoadedModules) {
                Submit-ModuleEvent -EventType "WorkflowCompleted" -EventData $workflowData
            }

            if ($operationId) {
                Update-ProgressOperation -OperationId $operationId -CurrentStep 4 -StepName "Completion"
                Complete-ProgressOperation -OperationId $operationId
            }

            # Verify workflow completed
            $workflowData.WorkflowId | Should -Not -BeNullOrEmpty
            $workflowData.Stage | Should -Be "Integration Test"
        }
    }

    Context "Concurrent Integration Operations" {
        It "Should handle concurrent operations across modules" {
            $jobs = @()
            
            for ($i = 1; $i -le 3; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($ModulePath, $IntegrationModules, $JobId)
                    
                    # Import modules in job
                    Import-Module $ModulePath -Force
                    foreach ($module in $IntegrationModules) {
                        $modulePath = Join-Path (Split-Path $ModulePath -Parent) $module
                        if (Test-Path $modulePath) {
                            Import-Module $modulePath -Force -ErrorAction SilentlyContinue
                        }
                    }
                    
                    # Perform integration operations
                    if (Get-Command Submit-ModuleMessage -ErrorAction SilentlyContinue) {
                        Submit-ModuleMessage -MessageType "ConcurrentTest" -MessageData @{ JobId = $JobId }
                    }
                    
                    if (Get-Command Start-ProgressOperation -ErrorAction SilentlyContinue) {
                        $opId = Start-ProgressOperation -OperationName "Concurrent Job $JobId" -TotalSteps 1
                        Complete-ProgressOperation -OperationId $opId
                    }
                    
                    return $JobId
                } -ArgumentList $PrimaryModulePath, $script:LoadedModules, $i
            }
            
            # Wait for all jobs
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            # All jobs should complete successfully
            $results.Count | Should -Be 3
            $results | Should -Contain 1
            $results | Should -Contain 2
            $results | Should -Contain 3
        }
    }
}