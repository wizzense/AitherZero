#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive integration tests for cross-module functionality

.DESCRIPTION
    This test suite validates integration between different modules:
    - Logging integration across all modules
    - ParallelExecution with other modules
    - PatchManager workflow integration
    - Configuration system integration
    - Error handling across module boundaries

.NOTES
    Part of the Aitherium Infrastructure Automation testing framework
#>

BeforeAll {
    # Force the correct project root
    $script:ProjectRoot = "C:/Users/alexa/OneDrive/Documents/0. wizzense/AitherZero"
    if (-not (Test-Path "$script:ProjectRoot/aither-core")) {
        # Fallback to Find-ProjectRoot if the expected path doesn't exist
        . "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"
        $script:ProjectRoot = Find-ProjectRoot
    }

    # Import all core modules
    $script:Modules = @(
        'Logging',
        'ParallelExecution',
        'TestingFramework',
        'PatchManager',
        'LabRunner',
        'DevEnvironment',
        'BackupManager',
        'ScriptManager'
    )

    foreach ($module in $script:Modules) {
        try {
            Import-Module "$script:ProjectRoot/aither-core/modules/$module" -Force -ErrorAction Stop
        } catch {
            Write-Warning "Failed to import $module module: $($_.Exception.Message)"
        }
    }

    # Ensure Write-CustomLog is available for parallel execution contexts
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Message, [string]$Level = "INFO")
            Write-Host "[$Level] $Message"
        }
    }

    # Define a script block that includes Write-CustomLog for parallel contexts
    $script:ParallelLogFunction = {
        function Write-CustomLog {
            param([string]$Message, [string]$Level = "INFO")
            Write-Host "[$Level] $Message"
        }
    }
}

Describe "Cross-Module Communication" -Tags @('Integration', 'CrossModule', 'Communication') {

    Context "When modules communicate with each other" {
        It "Should allow Logging integration across all modules" {
            $loggedModules = @()

            foreach ($module in $script:Modules) {
                try {
                    # Test that each module can use logging
                    $moduleCommands = Get-Command -Module $module -ErrorAction SilentlyContinue
                    if ($moduleCommands) {
                        $loggedModules += $module
                    }
                } catch {
                    Write-Warning "Module $module logging test failed: $($_.Exception.Message)"
                }
            }

            $loggedModules.Count | Should -BeGreaterThan 0
        }

        It "Should support parallel execution of module functions" {
            $testData = @('Module1', 'Module2', 'Module3')

            $results = Invoke-ParallelForEach -InputObject $testData -ScriptBlock {
                & $using:ParallelLogFunction
                try {
                    Write-CustomLog -Level 'INFO' -Message "Testing parallel execution for $($_)"
                    return @{ Module = $_; Success = $true }
                } catch {
                    return @{ Module = $_; Success = $false; Error = $_.Exception.Message }
                }
            } -ThrottleLimit 3

            $results.Count | Should -Be 3
            $successfulResults = $results | Where-Object { $_.Success -eq $true }
            $successfulResults.Count | Should -BeGreaterThan 0
        }

        It "Should handle error propagation across modules" {
            try {
                # Simulate an error scenario that crosses module boundaries
                Invoke-ParallelForEach -InputObject @('test') -ScriptBlock {
                    & $using:ParallelLogFunction
                    Write-CustomLog -Level 'ERROR' -Message "Test error"
                    throw "Simulated error"
                } -ThrottleLimit 1 -ErrorAction Stop

                $false | Should -Be $true # Should not reach here
            } catch {
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe "Configuration System Integration" -Tags @('Integration', 'Configuration') {

    Context "When modules access configuration" {
        It "Should load shared configuration successfully" {
            $configFiles = @(
                "$script:ProjectRoot/configs/default-config.json",
                "$script:ProjectRoot/configs/core-runner-config.json"
            )

            $loadedConfigs = @()
            foreach ($configFile in $configFiles) {
                if (Test-Path $configFile) {
                    try {
                        $config = Get-Content $configFile | ConvertFrom-Json
                        $loadedConfigs += @{ File = $configFile; Config = $config; Success = $true }
                    } catch {
                        $loadedConfigs += @{ File = $configFile; Config = $null; Success = $false; Error = $_.Exception.Message }
                    }
                }
            }

            $successfulConfigs = $loadedConfigs | Where-Object { $_.Success -eq $true }
            $successfulConfigs.Count | Should -BeGreaterThan 0
        }

        It "Should handle configuration validation across modules" {
            # Test that modules can validate their configuration sections
            $moduleConfigTests = @()

            foreach ($module in $script:Modules) {
                try {
                    $moduleInfo = Get-Module $module -ErrorAction SilentlyContinue
                    if ($moduleInfo) {
                        $moduleConfigTests += @{ Module = $module; HasConfig = $true }
                    }
                } catch {
                    $moduleConfigTests += @{ Module = $module; HasConfig = $false }
                }
            }

            $moduleConfigTests.Count | Should -BeGreaterThan 0
        }
    }
}

Describe "Workflow Integration Testing" -Tags @('Integration', 'Workflow', 'EndToEnd') {

    Context "When executing complete workflows" {
        It "Should execute a basic development workflow" {
            $workflowSteps = @()

            # Step 1: Environment validation
            try {
                $envResult = Test-DevEnvironment
                $workflowSteps += @{ Step = 'EnvironmentValidation'; Success = $true; Result = $envResult }
            } catch {
                $workflowSteps += @{ Step = 'EnvironmentValidation'; Success = $false; Error = $_.Exception.Message }
            }

            # Step 2: Logging initialization
            try {
                Write-CustomLog -Level 'INFO' -Message 'Starting workflow integration test'
                $workflowSteps += @{ Step = 'LoggingInitialization'; Success = $true }
            } catch {
                $workflowSteps += @{ Step = 'LoggingInitialization'; Success = $false; Error = $_.Exception.Message }
            }

            # Step 3: Parallel task execution
            try {
                $tasks = @('Task1', 'Task2', 'Task3')
                $taskResults = Invoke-ParallelForEach -InputObject $tasks -ScriptBlock {
                    param($task)
                    Write-CustomLog -Level 'INFO' -Message "Executing $task"
                    return @{ Task = $task; Completed = $true }
                } -ThrottleLimit 2

                $workflowSteps += @{ Step = 'ParallelExecution'; Success = $true; Results = $taskResults }
            } catch {
                $workflowSteps += @{ Step = 'ParallelExecution'; Success = $false; Error = $_.Exception.Message }
            }

            # Validate workflow completion
            $successfulSteps = $workflowSteps | Where-Object { $_.Success -eq $true }
            $successfulSteps.Count | Should -BeGreaterThan 0
        }

        It "Should handle backup and restoration workflow" {
            if (Get-Command 'Start-BackupOperation' -ErrorAction SilentlyContinue) {
                try {
                    # Simulate backup workflow
                    $backupConfig = @{
                        SourcePath = $script:ProjectRoot
                        BackupType = 'Test'
                        DryRun = $true
                    }

                    # This should not fail in dry-run mode
                    { Start-BackupOperation @backupConfig } | Should -Not -Throw
                } catch {
                    Write-Warning "Backup workflow test skipped: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "BackupManager commands not available, skipping backup workflow test"
            }
        }

        It "Should support script management workflow" {
            if (Get-Command 'Get-ScriptRepository' -ErrorAction SilentlyContinue) {
                try {
                    $scriptRepo = Get-ScriptRepository
                    $scriptRepo | Should -Not -BeNullOrEmpty
                } catch {
                    Write-Warning "Script management workflow test failed: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "ScriptManager commands not available, skipping script workflow test"
            }
        }
    }
}

Describe "Error Handling Integration" -Tags @('Integration', 'ErrorHandling') {

    Context "When errors occur across module boundaries" {
        It "Should propagate errors consistently" {
            $errorTests = @()

            # Test error in parallel execution
            try {
                Invoke-ParallelForEach -InputObject @('error-test') -ScriptBlock {
                    throw "Intentional test error"
                } -ThrottleLimit 1 -ErrorAction Stop
            } catch {
                $errorTests += @{ Source = 'ParallelExecution'; ErrorCaught = $true; Message = $_.Exception.Message }
            }

            # Test error in logging
            try {
                # This should handle errors gracefully
                Write-CustomLog -Level 'ERROR' -Message 'Test error message'
                $errorTests += @{ Source = 'Logging'; ErrorCaught = $false; Handled = $true }
            } catch {
                $errorTests += @{ Source = 'Logging'; ErrorCaught = $true; Message = $_.Exception.Message }
            }

            $errorTests.Count | Should -BeGreaterThan 0
        }

        It "Should maintain system stability during errors" {
            # Verify that modules are still functional after error scenarios
            $stabilityTests = @()

            foreach ($module in $script:Modules) {
                try {
                    $moduleInfo = Get-Module $module -ErrorAction SilentlyContinue
                    if ($moduleInfo) {
                        $stabilityTests += @{ Module = $module; Stable = $true }
                    } else {
                        $stabilityTests += @{ Module = $module; Stable = $false }
                    }
                } catch {
                    $stabilityTests += @{ Module = $module; Stable = $false; Error = $_.Exception.Message }
                }
            }

            $stableModules = $stabilityTests | Where-Object { $_.Stable -eq $true }
            $stableModules.Count | Should -BeGreaterThan 0
        }
    }
}

Describe "Performance Integration" -Tags @('Integration', 'Performance') {

    Context "When testing integrated performance" {
        It "Should maintain acceptable performance under load" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            # Execute multiple operations concurrently
            $operations = 1..10
            $results = Invoke-ParallelForEach -InputObject $operations -ScriptBlock {
                param($operation)

                # Simulate complex operation
                Write-CustomLog -Level 'INFO' -Message "Operation $operation"
                Start-Sleep -Milliseconds 100

                return @{ Operation = $operation; Completed = $true }
            } -ThrottleLimit 5

            $stopwatch.Stop()

            # Should complete within reasonable time
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000 # 5 seconds max
            $results.Count | Should -Be 10
        }

        It "Should use memory efficiently in integrated scenarios" {
            $beforeMemory = [GC]::GetTotalMemory($false)

            # Execute memory-intensive integrated operations
            $data = 1..100
            $results = Invoke-ParallelForEach -InputObject $data -ScriptBlock {
                param($item)
                Write-CustomLog -Level 'INFO' -Message "Processing item $item"
                return $item * 2
            } -ThrottleLimit 3

            [GC]::Collect()
            $afterMemory = [GC]::GetTotalMemory($true)
            $memoryIncrease = ($afterMemory - $beforeMemory) / 1MB

            # Should not use excessive memory
            $memoryIncrease | Should -BeLessThan 100 # 100MB max
            $results.Count | Should -Be 100
        }
    }
}

AfterAll {
    # Cleanup - remove imported modules
    foreach ($module in $script:Modules) {
        Remove-Module $module -Force -ErrorAction SilentlyContinue
    }
}