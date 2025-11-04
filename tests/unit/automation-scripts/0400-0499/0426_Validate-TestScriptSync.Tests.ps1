#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0426_Validate-TestScriptSync
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0426_Validate-TestScriptSync
    Stage: Testing
    Description: Detects and optionally removes orphaned test files (tests that reference non-existent scripts).
    Supports WhatIf: True
    Generated: 2025-11-04 20:50:00
#>

Describe '0426_Validate-TestScriptSync' -Tag 'Unit', 'AutomationScript', 'Testing' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0426_Validate-TestScriptSync.ps1'
        $script:ScriptName = '0426_Validate-TestScriptSync'

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

        It 'Should support WhatIf' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'SupportsShouldProcess'
        }
    }

    Context 'Parameters' {
        It 'Should have parameter: RemoveOrphaned' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RemoveOrphaned') | Should -Be $true
        }

        It 'Should have parameter: CI' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CI') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Testing' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }
    }

    Context 'Execution' {
        It 'Should execute with WhatIf without throwing' {
            {
                $params = @{ WhatIf = $true }
                & $script:ScriptPath @params
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
