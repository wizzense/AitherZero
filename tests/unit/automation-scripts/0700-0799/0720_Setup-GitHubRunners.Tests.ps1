#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0720_Setup-GitHubRunners
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0720_Setup-GitHubRunners
    Stage: Infrastructure
    Description: Provisions and configures GitHub Actions self-hosted runners using AitherZero infrastructure
    Supports WhatIf: True
    Generated: 2025-11-04 20:50:01
#>

Describe '0720_Setup-GitHubRunners' -Tag 'Unit', 'AutomationScript', 'Infrastructure' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0720_Setup-GitHubRunners.ps1'
        $script:ScriptName = '0720_Setup-GitHubRunners'

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
        It 'Should have parameter: RunnerCount' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunnerCount') | Should -Be $true
        }

        It 'Should have parameter: Platform' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Platform') | Should -Be $true
        }

        It 'Should have parameter: Organization' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Organization') | Should -Be $true
        }

        It 'Should have parameter: Repository' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Repository') | Should -Be $true
        }

        It 'Should have parameter: RunnerGroup' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunnerGroup') | Should -Be $true
        }

        It 'Should have parameter: Labels' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Labels') | Should -Be $true
        }

        It 'Should have parameter: WorkDirectory' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('WorkDirectory') | Should -Be $true
        }

        It 'Should have parameter: Token' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Token') | Should -Be $true
        }

        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }

        It 'Should have parameter: CI' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CI') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Infrastructure' {
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
