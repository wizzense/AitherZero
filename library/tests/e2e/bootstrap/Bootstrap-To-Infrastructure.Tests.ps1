#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    End-to-end test for bootstrap to infrastructure flow

.DESCRIPTION
    Validates the complete flow from bootstrap through module loading
    to infrastructure readiness
#>

Describe 'Bootstrap to Infrastructure E2E' -Tag 'E2E', 'Bootstrap', 'Infrastructure' {
    
    BeforeAll {
        # Import test helpers
        $testHelpersPath = Join-Path $PSScriptRoot '../../helpers/TestHelpers.psm1'
        if (Test-Path $testHelpersPath) {
            Import-Module $testHelpersPath -Force
        }
        
        # Get test environment
        $script:testEnv = Get-TestEnvironment
        
        # Create temporary test directory
        $script:testDir = New-TestDirectory -Prefix 'E2E-Bootstrap'
        
        # Set up test environment
        $script:originalRoot = $env:AITHERZERO_ROOT
        $env:AITHERZERO_ROOT = Get-TestFilePath ''
    }
    
    AfterAll {
        # Restore environment
        if ($script:originalRoot) {
            $env:AITHERZERO_ROOT = $script:originalRoot
        }
        
        # Clean up test directory
        if ($script:testDir -and (Test-Path $script:testDir)) {
            Remove-TestDirectory -Path $script:testDir
        }
    }
    
    Context 'Bootstrap Process' {
        It 'Should have bootstrap script' {
            $bootstrapPath = Get-TestFilePath 'bootstrap.ps1'
            Test-Path $bootstrapPath | Should -Be $true
        }
        
        It 'Should set AITHERZERO_ROOT environment variable' {
            # Simulate bootstrap
            $env:AITHERZERO_ROOT = Get-TestFilePath ''
            $env:AITHERZERO_ROOT | Should -Not -BeNullOrEmpty
            Test-Path $env:AITHERZERO_ROOT | Should -Be $true
        }
        
        It 'Should create required directories' {
            $requiredDirs = @(
                'aithercore',
                'library/automation-scripts',
                'library/tests'
            )
            
            foreach ($dir in $requiredDirs) {
                $dirPath = Get-TestFilePath $dir
                Test-Path $dirPath | Should -Be $true
            }
        }
    }
    
    Context 'Module Loading' {
        It 'Should load AitherZero module' {
            $manifestPath = Get-TestFilePath 'AitherZero.psd1'
            { Import-Module $manifestPath -Force } | Should -Not -Throw
        }
        
        It 'Should export core configuration functions' {
            Import-Module (Get-TestFilePath 'AitherZero.psd1') -Force
            
            $expectedFunctions = @(
                'Get-Configuration',
                'Set-Configuration'
            )
            
            foreach ($func in $expectedFunctions) {
                Get-Command $func -ErrorAction SilentlyContinue | Should -Not -BeNull
            }
        }
        
        It 'Should load all domain modules' {
            Import-Module (Get-TestFilePath 'AitherZero.psd1') -Force
            
            # Check for module-specific commands from different domains
            $domainCommands = @(
                'Write-CustomLog',      # Utilities
                'Get-Configuration',    # Configuration
                'Invoke-AitherScript'  # Automation
            )
            
            foreach ($cmd in $domainCommands) {
                Get-Command $cmd -ErrorAction SilentlyContinue | Should -Not -BeNull
            }
        }
    }
    
    Context 'Configuration System' {
        BeforeAll {
            Import-Module (Get-TestFilePath 'AitherZero.psd1') -Force
        }
        
        It 'Should load configuration' {
            { $config = Get-Configuration } | Should -Not -Throw
        }
        
        It 'Should have Core section' {
            $config = Get-Configuration
            $config.Core | Should -Not -BeNull
        }
        
        It 'Should have Testing section' {
            $config = Get-Configuration
            $config.Testing | Should -Not -BeNull
        }
        
        It 'Should detect environment correctly' {
            $config = Get-Configuration
            $env = $config.Core.Environment
            $env | Should -BeIn @('Development', 'CI', 'Production')
        }
    }
    
    Context 'Automation Scripts' {
        It 'Should have numbered scripts available' {
            $scriptsPath = Get-TestFilePath 'library/automation-scripts'
            $scripts = Get-ChildItem -Path $scriptsPath -Filter '*.ps1' |
                Where-Object { $_.Name -match '^\d{4}_' }
            
            $scripts.Count | Should -BeGreaterThan 0
        }
        
        It 'Should be able to list scripts' {
            Import-Module (Get-TestFilePath 'AitherZero.psd1') -Force
            
            # If list function exists
            if (Get-Command Get-AutomationScripts -ErrorAction SilentlyContinue) {
                { Get-AutomationScripts } | Should -Not -Throw
            }
        }
    }
    
    Context 'Testing Infrastructure' {
        It 'Should have test directories' {
            $testPath = Get-TestFilePath 'library/tests'
            Test-Path $testPath | Should -Be $true
        }
        
        It 'Should have test helpers' {
            $helpersPath = Get-TestFilePath 'library/tests/helpers/TestHelpers.psm1'
            Test-Path $helpersPath | Should -Be $true
        }
        
        It 'Should have test configuration' {
            $configPath = Get-TestFilePath 'library/tests/config/test-profiles.psd1'
            Test-Path $configPath | Should -Be $true
        }
    }
    
    Context 'Infrastructure Readiness' {
        It 'Should validate module manifest' {
            $manifestPath = Get-TestFilePath 'AitherZero.psd1'
            { Test-ModuleManifest -Path $manifestPath } | Should -Not -Throw
        }
        
        It 'Should have config.psd1' {
            $configPath = Get-TestFilePath 'config.psd1'
            Test-Path $configPath | Should -Be $true
        }
        
        It 'Should be able to execute WhatIf operations' {
            Import-Module (Get-TestFilePath 'AitherZero.psd1') -Force
            
            # Try a safe operation with WhatIf
            $testScript = Get-ChildItem (Get-TestFilePath 'library/automation-scripts') -Filter '0407_*.ps1' |
                Select-Object -First 1
            
            if ($testScript) {
                { & $testScript.FullName -WhatIf } | Should -Not -Throw
            }
        }
    }
    
    Context 'Cross-Platform Compatibility' {
        It 'Should detect platform correctly' {
            if ($script:testEnv.IsWindows) {
                $IsWindows | Should -Be $true
            }
            elseif ($script:testEnv.IsLinux) {
                $IsLinux | Should -Be $true
            }
            elseif ($script:testEnv.IsMacOS) {
                $IsMacOS | Should -Be $true
            }
        }
        
        It 'Should use platform-appropriate paths' {
            $scriptsPath = Get-TestFilePath 'library/automation-scripts'
            
            if ($script:testEnv.IsWindows) {
                $scriptsPath | Should -Match '[A-Z]:\\'
            }
            else {
                $scriptsPath | Should -Match '^/'
            }
        }
    }
}
