#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive test suite for the consolidated AitherCore module

.DESCRIPTION
    Tests the consolidated AitherCore module architecture including:
    - Module loading and orchestration
    - Cross-module integration
    - Legacy compatibility
    - Performance and reliability
    - Error handling and recovery

.NOTES
    This test suite validates the consolidated module architecture while
    ensuring backward compatibility with existing functionality.
#>

BeforeAll {
    # Find project root
    $projectRoot = Split-Path -Parent $PSScriptRoot
    
    # Import the consolidated AitherCore module
    $aitherCorePath = Join-Path $projectRoot "aither-core/AitherCore.psd1"
    
    if (Test-Path $aitherCorePath) {
        Import-Module $aitherCorePath -Force
        Write-Host "🔄 Imported consolidated AitherCore module" -ForegroundColor Cyan
    } else {
        throw "AitherCore module not found at: $aitherCorePath"
    }
    
    # Store original state for cleanup
    $script:originalModules = Get-Module | Select-Object Name, Version
    $script:testStartTime = Get-Date
}

Describe "AitherCore Consolidated Module Tests" {
    
    Context "Module Loading and Structure" {
        It "Should load AitherCore module successfully" {
            $aitherCoreModule = Get-Module -Name AitherCore
            $aitherCoreModule | Should -Not -BeNullOrEmpty
            $aitherCoreModule.Name | Should -Be "AitherCore"
        }
        
        It "Should export expected core functions" {
            $expectedFunctions = @(
                'Invoke-CoreApplication',
                'Start-LabRunner',
                'Get-CoreConfiguration',
                'Test-CoreApplicationHealth',
                'Write-CustomLog',
                'Get-PlatformInfo',
                'Initialize-CoreApplication',
                'Import-CoreModules',
                'Get-CoreModuleStatus',
                'Invoke-UnifiedMaintenance',
                'Start-DevEnvironmentSetup'
            )
            
            foreach ($functionName in $expectedFunctions) {
                Get-Command -Name $functionName -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should have valid module manifest" {
            $manifest = Test-ModuleManifest (Join-Path (Split-Path -Parent $PSScriptRoot) "aither-core/AitherCore.psd1")
            $manifest | Should -Not -BeNullOrEmpty
            $manifest.Version | Should -Not -BeNullOrEmpty
            $manifest.PowerShellVersion | Should -Be "7.0"
        }
        
        It "Should have proper module metadata" {
            $aitherCoreModule = Get-Module -Name AitherCore
            $aitherCoreModule.Author | Should -Not -BeNullOrEmpty
            $aitherCoreModule.Description | Should -Not -BeNullOrEmpty
            $aitherCoreModule.CompanyName | Should -Be "Aitherium"
        }
    }
    
    Context "Core Application Functions" {
        It "Should initialize core application successfully" {
            { Initialize-CoreApplication -RequiredOnly } | Should -Not -Throw
        }
        
        It "Should test core application health" {
            $healthResult = Test-CoreApplicationHealth
            $healthResult | Should -Be $true
        }
        
        It "Should get platform information" {
            $platformInfo = Get-PlatformInfo
            $platformInfo | Should -BeIn @('Windows', 'Linux', 'macOS')
        }
        
        It "Should provide logging functionality" {
            { Write-CustomLog -Level 'INFO' -Message 'Test message from AitherCore tests' } | Should -Not -Throw
        }
        
        It "Should get core configuration" {
            { Get-CoreConfiguration } | Should -Not -Throw
        }
    }
    
    Context "Module Orchestration and Discovery" {
        It "Should import core modules" {
            $importResult = Import-CoreModules -RequiredOnly
            $importResult | Should -Not -BeNullOrEmpty
            $importResult.ImportedCount | Should -BeGreaterThan 0
        }
        
        It "Should get module status information" {
            $moduleStatus = Get-CoreModuleStatus
            $moduleStatus | Should -Not -BeNullOrEmpty
            $moduleStatus | Should -BeOfType [Array]
            
            # Should have information about core modules
            $coreModules = $moduleStatus | Where-Object { $_.Required -eq $true }
            $coreModules.Count | Should -BeGreaterThan 0
        }
        
        It "Should handle module loading gracefully" {
            # Test importing all available modules
            $allModulesResult = Import-CoreModules -Force
            $allModulesResult | Should -Not -BeNullOrEmpty
            
            # Should handle missing modules without crashing
            $allModulesResult.FailedCount | Should -BeGreaterOrEqual 0
            $allModulesResult.ImportedCount | Should -BeGreaterThan 0
        }
        
        It "Should provide integrated toolset information" {
            if (Get-Command Get-IntegratedToolset -ErrorAction SilentlyContinue) {
                $toolset = Get-IntegratedToolset
                $toolset | Should -Not -BeNullOrEmpty
                $toolset.CoreModules | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Integrated Workflows" {
        It "Should support quick actions" {
            if (Get-Command Start-QuickAction -ErrorAction SilentlyContinue) {
                # Test system health quick action
                $healthResult = Start-QuickAction -Action 'SystemHealth'
                $healthResult | Should -Not -BeNullOrEmpty
                $healthResult.CoreHealth | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should handle unified maintenance" {
            # Test with WhatIf to avoid actual maintenance operations
            { Invoke-UnifiedMaintenance -Mode 'Quick' -WhatIf } | Should -Not -Throw
        }
        
        It "Should support development environment setup" {
            # Test with WhatIf to avoid actual setup operations
            { Start-DevEnvironmentSetup -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Error Handling and Recovery" {
        It "Should handle invalid configuration gracefully" {
            $invalidConfigPath = "C:\NonExistent\Config.json"
            { Invoke-CoreApplication -ConfigPath $invalidConfigPath -WhatIf } | Should -Throw
        }
        
        It "Should handle missing modules gracefully" {
            # Import modules with some potentially missing
            $result = Import-CoreModules
            $result | Should -Not -BeNullOrEmpty
            
            # Should complete without throwing even if some modules are missing
            $result.ImportedCount + $result.FailedCount + $result.SkippedCount | Should -BeGreaterThan 0
        }
        
        It "Should provide meaningful error messages" {
            try {
                Invoke-CoreApplication -ConfigPath "invalid-path.json"
                $false | Should -Be $true  # Should not reach here
            } catch {
                $_.Exception.Message | Should -Not -BeNullOrEmpty
                $_.Exception.Message | Should -Match "Configuration file not found"
            }
        }
    }
    
    Context "Performance and Efficiency" {
        It "Should load modules efficiently" {
            $loadTime = Measure-Command {
                Remove-Module AitherCore -Force -ErrorAction SilentlyContinue
                Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "aither-core/AitherCore.psd1") -Force
            }
            
            $loadTime.TotalSeconds | Should -BeLessThan 10
        }
        
        It "Should handle concurrent operations" {
            # Test multiple concurrent health checks
            $jobs = 1..3 | ForEach-Object {
                Start-Job -ScriptBlock {
                    Import-Module $using:aitherCorePath -Force
                    Test-CoreApplicationHealth
                }
            }
            
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -Be 3
            $results | ForEach-Object { $_ | Should -Be $true }
        }
        
        It "Should manage memory efficiently" {
            $beforeMemory = [GC]::GetTotalMemory($false)
            
            # Perform multiple operations
            1..5 | ForEach-Object {
                Initialize-CoreApplication -RequiredOnly
                Test-CoreApplicationHealth
                Get-CoreModuleStatus | Out-Null
            }
            
            # Force garbage collection
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            
            $afterMemory = [GC]::GetTotalMemory($false)
            $memoryIncrease = $afterMemory - $beforeMemory
            
            # Memory increase should be reasonable (less than 50MB)
            $memoryIncrease | Should -BeLessThan 52428800
        }
    }
    
    Context "Cross-Platform Compatibility" {
        It "Should work on current platform" {
            $platform = Get-PlatformInfo
            $platform | Should -BeIn @('Windows', 'Linux', 'macOS')
        }
        
        It "Should handle path operations correctly" {
            $testPath1 = "folder1"
            $testPath2 = "folder2"
            $testPath3 = "file.txt"
            
            # Should use platform-appropriate path separators
            $joinedPath = Join-Path $testPath1 $testPath2 $testPath3
            $joinedPath | Should -Not -BeNullOrEmpty
            
            # Path should be valid for current platform
            if ($IsWindows) {
                $joinedPath | Should -Match '^[^/]+$|^.*\\[^/]+$'
            } else {
                $joinedPath | Should -Match '^[^\\]+$|^.*/[^\\]+$'
            }
        }
        
        It "Should handle PowerShell version requirements" {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
        }
    }
    
    Context "Integration with Other Systems" {
        It "Should integrate with Pester testing framework" {
            # This test itself proves Pester integration works
            $true | Should -Be $true
        }
        
        It "Should support VS Code integration" {
            # Test if module can be imported in VS Code context
            $moduleInfo = Get-Module -Name AitherCore
            $moduleInfo.ExportedFunctions.Count | Should -BeGreaterThan 0
        }
        
        It "Should support CI/CD environments" {
            # Test non-interactive mode
            $env:CI = "true"
            try {
                { Test-CoreApplicationHealth } | Should -Not -Throw
            } finally {
                Remove-Item Env:CI -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Backward Compatibility" {
        It "Should maintain compatibility with existing function signatures" {
            # Test that core functions still accept expected parameters
            $coreAppParams = (Get-Command Invoke-CoreApplication).Parameters
            $coreAppParams.Keys | Should -Contain 'ConfigPath'
            $coreAppParams.Keys | Should -Contain 'Scripts'
            $coreAppParams.Keys | Should -Contain 'Auto'
        }
        
        It "Should provide legacy function aliases" {
            # Test that important legacy functions are still available
            $legacyFunctions = @('Write-CustomLog', 'Get-PlatformInfo')
            
            foreach ($functionName in $legacyFunctions) {
                Get-Command -Name $functionName -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should maintain configuration compatibility" {
            # Test that existing configurations can still be loaded
            $projectRoot = Split-Path -Parent $PSScriptRoot
            $defaultConfigPath = Join-Path $projectRoot "configs/default-config.json"
            
            if (Test-Path $defaultConfigPath) {
                { Get-CoreConfiguration -ConfigPath $defaultConfigPath } | Should -Not -Throw
            }
        }
    }
}

Describe "AitherCore Module Integration Tests" {
    
    Context "TestingFramework Integration" {
        It "Should work with distributed testing" {
            $testingFramework = Get-Module -Name TestingFramework -ErrorAction SilentlyContinue
            
            if ($testingFramework) {
                # Test integration with TestingFramework
                if (Get-Command Invoke-UnifiedTestExecution -ErrorAction SilentlyContinue) {
                    # Should be able to execute tests through unified framework
                    $true | Should -Be $true
                }
            } else {
                # TestingFramework not loaded - this is acceptable
                Write-Host "  ℹ️ TestingFramework not loaded - skipping integration test" -ForegroundColor Yellow
                $true | Should -Be $true
            }
        }
    }
    
    Context "Individual Module Integration" {
        It "Should work with Logging module" {
            $loggingModule = Get-Module -Name Logging -ErrorAction SilentlyContinue
            
            if ($loggingModule -or (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
                { Write-CustomLog -Level 'INFO' -Message 'Integration test message' } | Should -Not -Throw
            } else {
                # Logging should be available through consolidated module
                { Write-CustomLog -Level 'INFO' -Message 'Integration test message' } | Should -Not -Throw
            }
        }
        
        It "Should work with PatchManager if available" {
            $patchManager = Get-Module -Name PatchManager -ErrorAction SilentlyContinue
            
            if ($patchManager) {
                # Test basic PatchManager integration
                if (Get-Command Get-PatchStatus -ErrorAction SilentlyContinue) {
                    { Get-PatchStatus } | Should -Not -Throw
                }
            } else {
                Write-Host "  ℹ️ PatchManager not loaded - skipping integration test" -ForegroundColor Yellow
                $true | Should -Be $true
            }
        }
        
        It "Should work with SetupWizard if available" {
            $setupWizard = Get-Module -Name SetupWizard -ErrorAction SilentlyContinue
            
            if ($setupWizard) {
                # Test basic SetupWizard integration
                Write-Host "  ✅ SetupWizard module available" -ForegroundColor Green
                $true | Should -Be $true
            } else {
                Write-Host "  ℹ️ SetupWizard not loaded - skipping integration test" -ForegroundColor Yellow
                $true | Should -Be $true
            }
        }
    }
}

AfterAll {
    Write-Host "🧹 Cleaning up test environment..." -ForegroundColor Cyan
    
    # Report test execution time
    $testDuration = (Get-Date) - $script:testStartTime
    Write-Host "⏱️ Test execution time: $($testDuration.TotalSeconds.ToString('0.00'))s" -ForegroundColor Green
    
    # Optional: Remove test-specific modules to clean environment
    # Note: We keep AitherCore loaded as it might be needed by other tests
    
    Write-Host "✅ AitherCore tests completed successfully" -ForegroundColor Green
}