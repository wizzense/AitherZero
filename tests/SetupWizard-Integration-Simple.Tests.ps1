# Simple SetupWizard Integration Tests
# Tests core functionality without complex test structure

BeforeAll {
    $script:ProjectRoot = Split-Path $PSScriptRoot -Parent
    $script:ModulePath = Join-Path $script:ProjectRoot "aither-core/modules/SetupWizard/SetupWizard.psd1"
}

Describe "SetupWizard Module Tests" {
    Context "Module Loading" {
        It "Should have SetupWizard module available" {
            Test-Path $script:ModulePath | Should -Be $true
        }

        It "Should import SetupWizard module successfully" {
            { Import-Module $script:ModulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should have valid module manifest" {
            { Test-ModuleManifest $script:ModulePath -ErrorAction Stop } | Should -Not -Throw
            
            $manifest = Test-ModuleManifest $script:ModulePath
            $manifest.Version | Should -Not -BeNullOrEmpty
            $manifest.PowerShellVersion | Should -BeLessOrEqual $PSVersionTable.PSVersion
        }
    }

    Context "Core Functions" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }

        It "Should export Start-IntelligentSetup function" {
            Get-Command Start-IntelligentSetup -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should export Get-PlatformInfo function" {
            Get-Command Get-PlatformInfo -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should export Get-SetupSteps function" {
            Get-Command Get-SetupSteps -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should get platform information" {
            $platform = Get-PlatformInfo
            $platform | Should -Not -BeNullOrEmpty
            if ($platform.Platform) {
                $platform.Platform | Should -BeIn @('Windows', 'Linux', 'macOS')
            }
            # Architecture may be part of platform object
        }
    }
}