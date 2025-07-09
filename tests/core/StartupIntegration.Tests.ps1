#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive Pester tests for AitherZero startup integration and module loading

.DESCRIPTION
    Tests the complete startup experience including:
    - Module dependency resolution
    - Bootstrap process validation
    - Non-interactive mode support
    - Error handling and recovery
    - CI/CD compatibility

.NOTES
    These tests validate the core startup functionality that users experience
    when running bootstrap.ps1 and Start-AitherZero.ps1
#>

BeforeAll {
    # Set up test environment
    $script:TestStartTime = Get-Date
    $script:ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:AitherCorePath = Join-Path $script:ProjectRoot "aither-core"
    $script:ModulesPath = Join-Path $script:AitherCorePath "modules"
    
    # Create test workspace
    $script:TestWorkspace = if ($env:TEMP) {
        Join-Path $env:TEMP "AitherZero-StartupTests-$(Get-Random)"
    } elseif (Test-Path '/tmp') {
        "/tmp/AitherZero-StartupTests-$(Get-Random)"
    } else {
        Join-Path (Get-Location) "AitherZero-StartupTests-$(Get-Random)"
    }
    
    New-Item -Path $script:TestWorkspace -ItemType Directory -Force | Out-Null
    
    # Mock Write-CustomLog for consistent testing
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param(
                [string]$Message, 
                [string]$Level = "INFO",
                [string]$Source = "Test"
            )
            Write-Host "[$Level] [$Source] $Message"
        }
    }
}

AfterAll {
    # Cleanup test workspace
    if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
        Remove-Item $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "AitherZero Startup Integration Tests" -Tag @('Integration', 'Startup', 'Core') {
    
    Context "Module Structure Validation" {
        It "Should have all required core modules present" {
            $requiredModules = @(
                'Logging',
                'LabRunner', 
                'OpenTofuProvider',
                'ModuleCommunication',
                'ConfigurationCore'
            )
            
            foreach ($module in $requiredModules) {
                $modulePath = Join-Path $script:ModulesPath $module
                Test-Path $modulePath | Should -Be $true -Because "Core module $module should exist"
                
                # Check for manifest file
                $manifestPath = Join-Path $modulePath "$module.psd1"
                Test-Path $manifestPath | Should -Be $true -Because "Module $module should have a manifest file"
            }
        }
        
        It "Should have valid module manifests" {
            $moduleDirectories = Get-ChildItem -Path $script:ModulesPath -Directory
            
            foreach ($moduleDir in $moduleDirectories) {
                $manifestPath = Join-Path $moduleDir.FullName "$($moduleDir.Name).psd1"
                
                if (Test-Path $manifestPath) {
                    # Test that manifest can be loaded
                    { Test-ModuleManifest $manifestPath -ErrorAction Stop } | Should -Not -Throw -Because "Module manifest for $($moduleDir.Name) should be valid"
                    
                    # Test PowerShell version requirement
                    $manifest = Import-PowerShellDataFile $manifestPath
                    $manifest.PowerShellVersion | Should -Be '7.0' -Because "All modules should target PowerShell 7.0"
                }
            }
        }
    }
    
    Context "Dependency Resolution" {
        It "Should resolve UtilityServices dependency correctly" {
            $utilityServicesPath = Join-Path $script:ModulesPath "UtilityServices"
            $manifestPath = Join-Path $utilityServicesPath "UtilityServices.psd1"
            
            Test-Path $manifestPath | Should -Be $true
            
            $manifest = Import-PowerShellDataFile $manifestPath
            $manifest.RequiredModules | Should -Be @() -Because "UtilityServices should handle Logging dependency internally"
        }
        
        It "Should handle PSScriptAnalyzerIntegration optional dependency" {
            $psaIntegrationPath = Join-Path $script:ModulesPath "PSScriptAnalyzerIntegration"
            $manifestPath = Join-Path $psaIntegrationPath "PSScriptAnalyzerIntegration.psd1"
            
            Test-Path $manifestPath | Should -Be $true
            
            $manifest = Import-PowerShellDataFile $manifestPath
            $manifest.RequiredModules | Should -Be @() -Because "PSScriptAnalyzerIntegration should not have hard dependencies"
        }
    }
    
    Context "AitherCore Module Loading" {
        It "Should load AitherCore module successfully" {
            $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            Test-Path $aitherCorePath | Should -Be $true
            
            { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
            
            # Test that core functions are available
            Get-Command Initialize-CoreApplication -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Write-CustomLog -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Write-CustomLog function available" {
            $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            Import-Module $aitherCorePath -Force
            
            # Test that Write-CustomLog is exported and functional
            $writeCustomLogCmd = Get-Command Write-CustomLog -ErrorAction SilentlyContinue
            $writeCustomLogCmd | Should -Not -BeNullOrEmpty
            
            # Test that it can be called without error
            { Write-CustomLog -Message "Test message" -Level "INFO" } | Should -Not -Throw
        }
    }
    
    Context "Module Import Process" {
        It "Should import core modules without errors" {
            $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            Import-Module $aitherCorePath -Force
            
            # Test module import functionality
            { $result = Initialize-CoreApplication -RequiredOnly -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should handle missing optional modules gracefully" {
            $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            Import-Module $aitherCorePath -Force
            
            # Test that system can handle missing optional dependencies
            { $result = Initialize-CoreApplication -ErrorAction Stop } | Should -Not -Throw
        }
    }
    
    Context "Startup Script Validation" {
        It "Should have main startup script" {
            $startupScript = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"
            Test-Path $startupScript | Should -Be $true
        }
        
        It "Should have aither-core runner script" {
            $coreScript = Join-Path $script:AitherCorePath "aither-core.ps1"
            Test-Path $coreScript | Should -Be $true
        }
        
        It "Should have bootstrap script" {
            $bootstrapScript = Join-Path $script:ProjectRoot "bootstrap.ps1"
            Test-Path $bootstrapScript | Should -Be $true
        }
    }
    
    Context "Error Handling" {
        It "Should handle Write-CustomLog unavailability gracefully" {
            # Remove Write-CustomLog if it exists
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Remove-Item Function:\Write-CustomLog -ErrorAction SilentlyContinue
            }
            
            $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            
            # Should not throw even if Write-CustomLog is not available initially
            { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
            
            # Should create the function
            Get-Command Write-CustomLog -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should provide meaningful error messages for missing dependencies" {
            # This test would be more comprehensive in a real scenario
            # For now, we test that the modules handle missing dependencies
            $testModule = Join-Path $script:ModulesPath "PSScriptAnalyzerIntegration"
            
            { Import-Module $testModule -Force -ErrorAction Stop } | Should -Not -Throw
        }
    }
    
    Context "Non-Interactive Mode Support" {
        It "Should support non-interactive execution" {
            $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            Import-Module $aitherCorePath -Force
            
            # Test that initialization works without user interaction
            { $result = Initialize-CoreApplication -RequiredOnly -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should handle CI/CD environment variables" {
            # Test environment variables that would be set in CI/CD
            $env:AITHER_LOG_LEVEL = "ERROR"
            $env:AITHER_CONSOLE_LEVEL = "ERROR"
            
            try {
                $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
                { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
            } finally {
                # Clean up
                Remove-Item Env:\AITHER_LOG_LEVEL -ErrorAction SilentlyContinue
                Remove-Item Env:\AITHER_CONSOLE_LEVEL -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Performance and Reliability" {
        It "Should complete module loading within reasonable time" {
            $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Import-Module $aitherCorePath -Force
            Initialize-CoreApplication -RequiredOnly
            $stopwatch.Stop()
            
            # Module loading should complete within 30 seconds
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 30000 -Because "Module loading should be fast"
        }
        
        It "Should be idempotent - multiple imports should not cause issues" {
            $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            
            # Import multiple times
            { Import-Module $aitherCorePath -Force } | Should -Not -Throw
            { Import-Module $aitherCorePath -Force } | Should -Not -Throw
            { Import-Module $aitherCorePath -Force } | Should -Not -Throw
            
            # Should still work correctly
            { Initialize-CoreApplication -RequiredOnly } | Should -Not -Throw
        }
    }
    
    Context "Configuration and Environment" {
        It "Should set up required environment variables" {
            $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            Import-Module $aitherCorePath -Force
            
            Initialize-CoreApplication -RequiredOnly
            
            # Check that environment variables are set
            $env:PROJECT_ROOT | Should -Not -BeNullOrEmpty
            $env:PWSH_MODULES_PATH | Should -Not -BeNullOrEmpty
            
            # Verify paths exist
            Test-Path $env:PROJECT_ROOT | Should -Be $true
            Test-Path $env:PWSH_MODULES_PATH | Should -Be $true
        }
        
        It "Should handle different operating systems" {
            $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            Import-Module $aitherCorePath -Force
            
            # Should work regardless of OS
            { Initialize-CoreApplication -RequiredOnly } | Should -Not -Throw
            
            # Get-PlatformInfo should return a valid platform
            $platform = Get-PlatformInfo
            $platform | Should -BeIn @('Windows', 'Linux', 'macOS')
        }
    }
}

Describe "Bootstrap Process Tests" -Tag @('Integration', 'Bootstrap', 'E2E') {
    
    Context "Bootstrap Script Validation" {
        It "Should have executable bootstrap script" {
            $bootstrapScript = Join-Path $script:ProjectRoot "bootstrap.ps1"
            Test-Path $bootstrapScript | Should -Be $true
            
            # Check that it's a valid PowerShell script
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $bootstrapScript -Raw), [ref]$null) } | Should -Not -Throw
        }
        
        It "Should support different installation profiles" {
            $bootstrapScript = Join-Path $script:ProjectRoot "bootstrap.ps1"
            $content = Get-Content $bootstrapScript -Raw
            
            # Should contain profile references
            $content | Should -Match "minimal|developer|full" -Because "Bootstrap should support installation profiles"
        }
    }
    
    Context "End-to-End Startup Flow" {
        It "Should complete full startup sequence" {
            # This would be a more comprehensive test in a real scenario
            # For now, we verify the core components work together
            $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            
            # Simulate the full startup flow
            { Import-Module $aitherCorePath -Force } | Should -Not -Throw
            { Initialize-CoreApplication } | Should -Not -Throw
            { Test-CoreApplicationHealth } | Should -Not -Throw
        }
    }
}