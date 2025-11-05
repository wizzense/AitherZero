#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0003_Sync-ConfigManifest
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0003_Sync-ConfigManifest
    Stage: Environment Setup
    Description: Automatically discovers automation scripts in the automation-scripts directory
    Supports WhatIf: False
    Generated: 2025-11-04 20:50:00
#>

Describe '0003_Sync-ConfigManifest' -Tag 'Unit', 'AutomationScript', 'Environment Setup' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0003_Sync-ConfigManifest.ps1'
        $script:ScriptName = '0003_Sync-ConfigManifest'

        # Import test helpers for environment detection
        $testHelpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "../../TestHelpers.psm1"
        if (Test-Path $testHelpersPath) {
            Import-Module $testHelpersPath -Force -ErrorAction SilentlyContinue
        }

        # Detect test environment
        $script:TestEnv = if (Get-Command Get-TestEnvironment -ErrorAction SilentlyContinue) {
            Get-TestEnvironment
        } else {
            @{ IsCI = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true'); IsLocal = $true }
        }
    }

    Context 'Script Validation' {
        It 'Script file should exist' {
            Test-Path $script:ScriptPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:ScriptPath, [ref]$null, [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It 'Should not require WhatIf support' {
            # Script does not implement SupportsShouldProcess
            # This is acceptable for read-only or simple scripts
            $content = Get-Content $script:ScriptPath -Raw
            $content -notmatch 'SupportsShouldProcess' | Should -Be $true
        }
    }

    Context 'Parameters' {
        It 'Should have parameter: Fix' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Fix') | Should -Be $true
        }

        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Environment Setup' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }

        It 'Should declare dependencies' {
            $content = Get-Content $script:ScriptPath -First 50
            ($content -join ' ') | Should -Match 'Dependencies:'
        }
    }

    Context 'Execution' {
        It 'Should be executable (no WhatIf support)' {
            # Script does not support -WhatIf parameter
            # Verify script can be dot-sourced without errors
            {
                $cmd = Get-Command $script:ScriptPath -ErrorAction Stop
                $cmd | Should -Not -BeNullOrEmpty
            } | Should -Not -Throw
        }
    }

    Context 'Environment Awareness' {
        It 'Test environment should be detected' {
            $script:TestEnv | Should -Not -BeNullOrEmpty
            $script:TestEnv.Keys | Should -Contain 'IsCI'
        }

        It 'Should adapt to CI environment' {
            if (-not $script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "CI-only validation"
                return
            }
            $script:TestEnv.IsCI | Should -Be $true
            $env:CI | Should -Not -BeNullOrEmpty
        }

        It 'Should adapt to local environment' {
            if ($script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "Local-only validation"
                return
            }
            $script:TestEnv.IsCI | Should -Be $false
        }
    }
}
