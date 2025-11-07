#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0877_Rotate-GitHubCredentials
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0877_Rotate-GitHubCredentials
    Stage: Credential Rotation
    Description: Safely rotates GitHub access tokens used for license/credential management:
    Supports WhatIf: True
    Generated: 2025-11-07 20:42:23
#>

Describe '0877_Rotate-GitHubCredentials' -Tag 'Unit', 'AutomationScript', 'Credential Rotation' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0877_Rotate-GitHubCredentials.ps1'
        $script:ScriptName = '0877_Rotate-GitHubCredentials'

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
        It 'Should have parameter: NewToken' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('NewToken') | Should -Be $true
        }

        It 'Should have parameter: TestOwner' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('TestOwner') | Should -Be $true
        }

        It 'Should have parameter: TestRepo' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('TestRepo') | Should -Be $true
        }

        It 'Should have parameter: SkipTests' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SkipTests') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Credential Rotation' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }

        It 'Should declare dependencies' {
            $content = Get-Content $script:ScriptPath -First 50
            ($content -join ' ') | Should -Match 'Dependencies:'
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
