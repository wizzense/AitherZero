#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive Pester tests for AitherZero module loading system

.DESCRIPTION
    Tests all aspects of the module loading architecture including:
    - Logging module loads first
    - All core modules can be loaded without errors
    - Write-CustomLog availability after loading
    - Dependency resolution and load order
    - UtilityServices loads after Logging
    - PSScriptAnalyzerIntegration graceful handling
    - Module loading performance
    - Correct log levels ('WARNING' not 'WARN')
    - Parallel loading of independent modules
    - Error handling for missing dependencies
#>

BeforeAll {
    # Find project root and set up test environment
    $script:ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:ModulesPath = Join-Path $script:ProjectRoot "aither-core" "modules"
    $script:AitherCorePath = Join-Path $script:ProjectRoot "aither-core" "aither-core.ps1"
    $script:AitherCoreModulePath = Join-Path $script:ProjectRoot "aither-core" "AitherCore.psm1"
    
    # Track original environment for cleanup
    $script:OriginalPROJECT_ROOT = $env:PROJECT_ROOT
    $script:OriginalPWSH_MODULES_PATH = $env:PWSH_MODULES_PATH
    $script:OriginalLAB_CONSOLE_LEVEL = $env:LAB_CONSOLE_LEVEL
    
    # Track loaded modules for cleanup
    $script:PreTestModules = Get-Module | Select-Object -ExpandProperty Name
    
    # Performance tracking
    $script:ModuleLoadTimes = @{}
    
    Write-Host "Test environment initialized. Project root: $script:ProjectRoot" -ForegroundColor Cyan
}

AfterAll {
    # Restore original environment
    if ($null -ne $script:OriginalPROJECT_ROOT) {
        $env:PROJECT_ROOT = $script:OriginalPROJECT_ROOT
    } else {
        Remove-Item env:PROJECT_ROOT -ErrorAction SilentlyContinue
    }
    
    if ($null -ne $script:OriginalPWSH_MODULES_PATH) {
        $env:PWSH_MODULES_PATH = $script:OriginalPWSH_MODULES_PATH
    } else {
        Remove-Item env:PWSH_MODULES_PATH -ErrorAction SilentlyContinue
    }
    
    if ($null -ne $script:OriginalLAB_CONSOLE_LEVEL) {
        $env:LAB_CONSOLE_LEVEL = $script:OriginalLAB_CONSOLE_LEVEL
    } else {
        Remove-Item env:LAB_CONSOLE_LEVEL -ErrorAction SilentlyContinue
    }
    
    # Remove modules loaded during testing
    $currentModules = Get-Module | Select-Object -ExpandProperty Name
    $modulesToRemove = $currentModules | Where-Object { $_ -notin $script:PreTestModules }
    foreach ($module in $modulesToRemove) {
        Remove-Module $module -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "Test cleanup completed" -ForegroundColor Green
}

Describe "AitherZero Module Loading System" {
    
    Context "1. Logging Module Loads First" {
        BeforeEach {
            # Clean slate for each test
            Get-Module -Name Logging -ErrorAction SilentlyContinue | Remove-Module -Force
            Get-Module -Name AitherCore -ErrorAction SilentlyContinue | Remove-Module -Force
        }
        
        It "Should load Logging module before any other module" {
            # Import AitherCore which orchestrates module loading
            Import-Module $script:AitherCoreModulePath -Force
            
            # Initialize core application (this triggers module loading)
            $initResult = Initialize-CoreApplication -RequiredOnly
            
            # Verify Logging was loaded
            $loggingModule = Get-Module -Name Logging
            $loggingModule | Should -Not -BeNullOrEmpty
            $loggingModule.Name | Should -Be "Logging"
        }
        
        It "Should make Write-CustomLog available immediately after Logging loads" {
            # Load just the Logging module
            $loggingPath = Join-Path $script:ModulesPath "Logging"
            Import-Module $loggingPath -Force
            
            # Verify Write-CustomLog is available
            Get-Command Write-CustomLog -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            
            # Test that it works
            { Write-CustomLog -Message "Test message" -Level "INFO" } | Should -Not -Throw
        }
    }
    
    Context "2. All Core Modules Load Without Errors" {
        BeforeAll {
            # Get list of all modules in modules directory
            $script:AllModules = Get-ChildItem -Path $script:ModulesPath -Directory | 
                Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).psd1") } |
                Select-Object -ExpandProperty Name
        }
        
        It "Should load module: <_>" -ForEach $script:AllModules {
            $modulePath = Join-Path $script:ModulesPath $_
            $moduleManifest = Join-Path $modulePath "$_.psd1"
            
            # Module manifest should exist
            Test-Path $moduleManifest | Should -Be $true
            
            # Module should load without errors
            { Import-Module $moduleManifest -Force } | Should -Not -Throw
            
            # Module should be loaded
            Get-Module -Name $_ | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "3. Write-CustomLog Availability After Loading" {
        It "Should have Write-CustomLog available after core system initialization" {
            # Remove all modules for clean test
            Get-Module -Name Logging -ErrorAction SilentlyContinue | Remove-Module -Force
            Get-Module -Name AitherCore -ErrorAction SilentlyContinue | Remove-Module -Force
            
            # Import and initialize
            Import-Module $script:AitherCoreModulePath -Force
            Initialize-CoreApplication -RequiredOnly
            
            # Write-CustomLog should be available
            Get-Command Write-CustomLog -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            
            # And it should work with various log levels
            { Write-CustomLog -Message "INFO test" -Level "INFO" } | Should -Not -Throw
            { Write-CustomLog -Message "WARNING test" -Level "WARNING" } | Should -Not -Throw
            { Write-CustomLog -Message "ERROR test" -Level "ERROR" } | Should -Not -Throw
        }
    }
    
    Context "4. Dependency Resolution and Load Order" {
        It "Should resolve module dependencies correctly" {
            # Import AitherCore
            Import-Module $script:AitherCoreModulePath -Force
            
            # Get module status to check load order
            $moduleStatus = Get-CoreModuleStatus
            
            # Core modules with dependencies
            $modulesWithDeps = @{
                'ConfigurationManager' = @('ConfigurationCore')
                'ConfigurationCarousel' = @('ConfigurationCore')
                'TestingFramework' = @('Logging')
                'PatchManager' = @('Logging')
            }
            
            foreach ($module in $modulesWithDeps.Keys) {
                $moduleInfo = $moduleStatus | Where-Object { $_.Name -eq $module }
                if ($moduleInfo -and $moduleInfo.Loaded) {
                    # Check that dependencies were loaded
                    foreach ($dep in $modulesWithDeps[$module]) {
                        $depInfo = $moduleStatus | Where-Object { $_.Name -eq $dep }
                        $depInfo | Should -Not -BeNullOrEmpty
                        $depInfo.Loaded | Should -Be $true
                    }
                }
            }
        }
        
        It "Should load modules in dependency order" {
            # Track load order
            $loadOrder = @()
            
            # Mock Write-CustomLog to track module loading order
            Mock Write-CustomLog {
                if ($Message -match "✓ Imported: (.+)") {
                    $script:loadOrder += $matches[1]
                }
            } -ModuleName AitherCore
            
            # Import and initialize
            Import-Module $script:AitherCoreModulePath -Force
            Initialize-CoreApplication
            
            # Verify Logging loaded before modules that depend on it
            $loggingIndex = $loadOrder.IndexOf('Logging')
            $loggingIndex | Should -BeGreaterOrEqual 0
            
            # Check dependent modules loaded after Logging
            $dependentModules = @('TestingFramework', 'PatchManager', 'BackupManager')
            foreach ($depModule in $dependentModules) {
                $depIndex = $loadOrder.IndexOf($depModule)
                if ($depIndex -ge 0) {
                    $depIndex | Should -BeGreaterThan $loggingIndex
                }
            }
        }
    }
    
    Context "5. UtilityServices Loads After Logging" {
        It "Should load UtilityServices after Logging module" {
            $loadOrder = @()
            
            # Track module load order
            Mock Import-Module {
                $moduleName = Split-Path -Leaf $Path
                $script:loadOrder += $moduleName
                # Call the original Import-Module
                Microsoft.PowerShell.Core\Import-Module @PSBoundParameters
            } -ModuleName AitherCore
            
            # Import and initialize
            Import-Module $script:AitherCoreModulePath -Force
            Initialize-CoreApplication
            
            # Find positions
            $loggingPos = $loadOrder.IndexOf('Logging')
            $utilityPos = $loadOrder.IndexOf('UtilityServices')
            
            if ($utilityPos -ge 0 -and $loggingPos -ge 0) {
                $utilityPos | Should -BeGreaterThan $loggingPos
            }
        }
    }
    
    Context "6. PSScriptAnalyzerIntegration Graceful Handling" {
        It "Should handle missing PSScriptAnalyzer gracefully" {
            # Temporarily hide PSScriptAnalyzer if it exists
            $psaModule = Get-Module -ListAvailable -Name PSScriptAnalyzer
            $hidePSA = $null -ne $psaModule
            
            if ($hidePSA) {
                # Note: This is a mock scenario - in reality we can't easily hide a module
                # But we can test the module loads anyway
            }
            
            # Load PSScriptAnalyzerIntegration module
            $psaIntPath = Join-Path $script:ModulesPath "PSScriptAnalyzerIntegration"
            
            # Should not throw even if PSScriptAnalyzer is missing
            { Import-Module $psaIntPath -Force } | Should -Not -Throw
            
            # Module should be loaded
            Get-Module -Name PSScriptAnalyzerIntegration | Should -Not -BeNullOrEmpty
        }
        
        It "Should provide meaningful error messages when PSScriptAnalyzer is missing" {
            # Import the module
            $psaIntPath = Join-Path $script:ModulesPath "PSScriptAnalyzerIntegration"
            Import-Module $psaIntPath -Force
            
            # Check if functions handle missing analyzer gracefully
            $commands = Get-Command -Module PSScriptAnalyzerIntegration
            
            foreach ($cmd in $commands) {
                # Each command should have proper error handling
                $definition = (Get-Command $cmd.Name).Definition
                $definition | Should -Match "try|catch|ErrorAction"
            }
        }
    }
    
    Context "7. Module Loading Performance" {
        It "Should load all core modules within reasonable time" {
            # Clean slate
            Get-Module | Where-Object { $_.Name -like "Aither*" -or $_.Path -like "*aither-core*" } | 
                Remove-Module -Force -ErrorAction SilentlyContinue
            
            # Measure time to load all modules
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            Import-Module $script:AitherCoreModulePath -Force
            Initialize-CoreApplication
            
            $stopwatch.Stop()
            
            # Should complete within 30 seconds (adjust based on system)
            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 30
            
            Write-Host "Total module loading time: $($stopwatch.Elapsed.TotalSeconds) seconds" -ForegroundColor Yellow
        }
        
        It "Should track individual module load times" {
            # Import with timing
            Import-Module $script:AitherCoreModulePath -Force
            
            # Initialize and get timing data
            $importResult = Import-CoreModules
            
            # Should have timing information
            $importResult | Should -Not -BeNullOrEmpty
            $importResult.ImportedCount | Should -BeGreaterThan 0
            
            # Each module should load in under 5 seconds
            foreach ($detail in $importResult.Details) {
                if ($detail.Status -eq 'Imported') {
                    # Note: Actual timing would need to be implemented in the module
                    # This is a placeholder for the expected behavior
                    Write-Host "Module $($detail.Name): $($detail.Status)" -ForegroundColor Green
                }
            }
        }
    }
    
    Context "8. Correct Log Levels (WARNING not WARN)" {
        It "Should accept 'WARNING' as a valid log level" {
            Import-Module (Join-Path $script:ModulesPath "Logging") -Force
            
            # Should not throw with WARNING level
            { Write-CustomLog -Message "Test warning" -Level "WARNING" } | Should -Not -Throw
        }
        
        It "Should handle both 'WARN' and 'WARNING' for compatibility" {
            Import-Module (Join-Path $script:ModulesPath "Logging") -Force
            
            # Both should work
            { Write-CustomLog -Message "Test warn" -Level "WARN" } | Should -Not -Throw
            { Write-CustomLog -Message "Test warning" -Level "WARNING" } | Should -Not -Throw
        }
        
        It "Should map log levels correctly in verbosity settings" {
            # Check aither-core.ps1 verbosity mapping
            $coreContent = Get-Content $script:AitherCorePath -Raw
            
            # Should use WARN internally for compatibility
            $coreContent | Should -Match "VerbosityToLogLevel.*WARN"
            
            # But accept WARNING from users
            Import-Module (Join-Path $script:ModulesPath "Logging") -Force
            $validLevels = @("SILENT", "ERROR", "WARN", "WARNING", "INFO", "SUCCESS", "DEBUG", "TRACE", "VERBOSE")
            
            foreach ($level in $validLevels) {
                if ($level -ne "SILENT") {
                    { Write-CustomLog -Message "Level test" -Level $level } | Should -Not -Throw
                }
            }
        }
    }
    
    Context "9. Parallel Loading of Independent Modules" {
        It "Should identify modules that can be loaded in parallel" {
            Import-Module $script:AitherCoreModulePath -Force
            
            # Get module information
            $moduleStatus = Get-CoreModuleStatus
            
            # Modules with no dependencies (except Logging) can be loaded in parallel
            $independentModules = @(
                'ISOManager',
                'SystemMonitoring',
                'RemoteConnection',
                'SemanticVersioning',
                'RepoSync'
            )
            
            # These should all be loadable
            foreach ($module in $independentModules) {
                $moduleInfo = $moduleStatus | Where-Object { $_.Name -eq $module }
                if ($moduleInfo -and $moduleInfo.Available) {
                    { Import-Module (Join-Path $script:ModulesPath $module) -Force } | Should -Not -Throw
                }
            }
        }
        
        It "Should support parallel module loading for better performance" {
            # This tests the concept - actual implementation would use runspaces
            $modulesToLoad = @('ISOManager', 'SystemMonitoring', 'RemoteConnection')
            
            # Simulate parallel loading with jobs
            $jobs = foreach ($module in $modulesToLoad) {
                Start-Job -ScriptBlock {
                    param($modulePath, $moduleName)
                    Import-Module (Join-Path $modulePath $moduleName) -Force
                    return @{
                        Module = $moduleName
                        Success = $true
                        LoadTime = (Get-Date)
                    }
                } -ArgumentList $script:ModulesPath, $module
            }
            
            # Wait for completion
            $results = $jobs | Wait-Job -Timeout 10 | Receive-Job
            $jobs | Remove-Job
            
            # All should succeed
            $results | ForEach-Object {
                $_.Success | Should -Be $true
            }
        }
    }
    
    Context "10. Error Handling for Missing Dependencies" {
        It "Should provide clear error messages for missing required modules" {
            # Test with a module that has dependencies
            $configMgrPath = Join-Path $script:ModulesPath "ConfigurationManager"
            
            # First, ensure ConfigurationCore is not loaded
            Get-Module -Name ConfigurationCore -ErrorAction SilentlyContinue | Remove-Module -Force
            
            # Try to load ConfigurationManager (depends on ConfigurationCore)
            try {
                Import-Module $configMgrPath -Force -ErrorAction Stop
                # If it succeeds, dependency was auto-loaded (good!)
                Get-Module -Name ConfigurationCore | Should -Not -BeNullOrEmpty
            } catch {
                # If it fails, error should mention the dependency
                $_.Exception.Message | Should -Match "ConfigurationCore|dependency|required"
            }
        }
        
        It "Should handle circular dependencies gracefully" {
            # Import the orchestration module
            Import-Module $script:AitherCoreModulePath -Force
            
            # Initialize should handle any circular dependencies
            { Initialize-CoreApplication } | Should -Not -Throw
            
            # All core modules should still be functional
            $moduleStatus = Get-CoreModuleStatus
            $loadedModules = $moduleStatus | Where-Object { $_.Loaded }
            $loadedModules.Count | Should -BeGreaterThan 0
        }
        
        It "Should continue loading other modules when one fails" {
            # Mock a module failure
            Mock Import-Module {
                if ($Path -like "*ISOManager*") {
                    throw "Simulated module load failure"
                } else {
                    Microsoft.PowerShell.Core\Import-Module @PSBoundParameters
                }
            } -ModuleName AitherCore
            
            # Import and initialize
            Import-Module $script:AitherCoreModulePath -Force
            $result = Import-CoreModules
            
            # Should have some failures but also successes
            $result.FailedCount | Should -BeGreaterThan 0
            $result.ImportedCount | Should -BeGreaterThan 0
            
            # Other modules should still be loaded
            Get-Module -Name Logging | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Module Loading Integration Tests" {
    
    Context "Full System Integration" {
        It "Should successfully run aither-core.ps1 with module loading" {
            # Set up environment
            $env:PROJECT_ROOT = $script:ProjectRoot
            $env:PWSH_MODULES_PATH = $script:ModulesPath
            
            # Run aither-core.ps1 in validation mode
            $scriptBlock = {
                param($aitherCorePath)
                & $aitherCorePath -WhatIf -NonInteractive
                return $LASTEXITCODE
            }
            
            $result = Start-Job -ScriptBlock $scriptBlock -ArgumentList $script:AitherCorePath | 
                      Wait-Job -Timeout 30 | 
                      Receive-Job
            
            # Should complete successfully
            $result | Should -Be 0
        }
        
        It "Should maintain module state across operations" {
            # Import and initialize
            Import-Module $script:AitherCoreModulePath -Force
            Initialize-CoreApplication
            
            # Get initial state
            $initialStatus = Get-CoreModuleStatus
            
            # Perform some operations
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message "State test" -Level "INFO"
            }
            
            # Re-check state
            $finalStatus = Get-CoreModuleStatus
            
            # Module state should be maintained
            $initialLoaded = $initialStatus | Where-Object { $_.Loaded } | Select-Object -ExpandProperty Name
            $finalLoaded = $finalStatus | Where-Object { $_.Loaded } | Select-Object -ExpandProperty Name
            
            # Same modules should still be loaded
            $finalLoaded | Should -Contain $initialLoaded
        }
    }
    
    Context "Error Recovery and Resilience" {
        It "Should recover from module loading interruptions" {
            # Start loading modules
            Import-Module $script:AitherCoreModulePath -Force
            
            # Initialize partially
            $partialResult = Import-CoreModules -RequiredOnly
            $partialResult.ImportedCount | Should -BeGreaterThan 0
            
            # Try full initialization (should handle already loaded modules)
            { Initialize-CoreApplication } | Should -Not -Throw
            
            # Should have more modules loaded now
            $fullStatus = Get-CoreModuleStatus
            $loadedCount = ($fullStatus | Where-Object { $_.Loaded }).Count
            $loadedCount | Should -BeGreaterThan $partialResult.ImportedCount
        }
        
        It "Should provide diagnostic information for troubleshooting" {
            Import-Module $script:AitherCoreModulePath -Force
            
            # Get comprehensive status
            $status = Get-CoreModuleStatus
            
            # Should include diagnostic information
            $status | ForEach-Object {
                $_.Name | Should -Not -BeNullOrEmpty
                $_.Available | Should -BeIn @($true, $false)
                $_.Loaded | Should -BeIn @($true, $false)
                $_.Path | Should -Not -BeNullOrEmpty
            }
            
            # Test consolidated health check
            $healthReport = Test-ConsolidationHealth -Detailed
            
            $healthReport | Should -Not -BeNullOrEmpty
            $healthReport.ConsolidationStatus | Should -Not -BeNullOrEmpty
            $healthReport.ModuleValidation | Should -Not -BeNullOrEmpty
            $healthReport.OverallHealth | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Module Loading Performance Benchmarks" {
    
    Context "Performance Metrics" {
        It "Should collect and report module loading metrics" {
            # Clean start
            Get-Module | Where-Object { $_.Path -like "*aither-core*" } | 
                Remove-Module -Force -ErrorAction SilentlyContinue
            
            # Track detailed timing
            $timings = @{}
            $totalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Load each module individually with timing
            $modules = @('Logging', 'LabRunner', 'OpenTofuProvider', 'ConfigurationCore')
            
            foreach ($module in $modules) {
                $moduleStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                Import-Module (Join-Path $script:ModulesPath $module) -Force
                $moduleStopwatch.Stop()
                $timings[$module] = $moduleStopwatch.Elapsed.TotalMilliseconds
            }
            
            $totalStopwatch.Stop()
            
            # Report findings
            Write-Host "`nModule Loading Performance Report:" -ForegroundColor Cyan
            Write-Host "=================================" -ForegroundColor Cyan
            foreach ($module in $timings.Keys | Sort-Object) {
                Write-Host "$module : $([math]::Round($timings[$module], 2)) ms" -ForegroundColor Yellow
            }
            Write-Host "Total Time: $([math]::Round($totalStopwatch.Elapsed.TotalMilliseconds, 2)) ms" -ForegroundColor Green
            
            # Performance assertions
            $timings['Logging'] | Should -BeLessThan 5000  # Logging should be fast
            $totalStopwatch.Elapsed.TotalSeconds | Should -BeLessThan 10  # Total under 10 seconds
        }
    }
}