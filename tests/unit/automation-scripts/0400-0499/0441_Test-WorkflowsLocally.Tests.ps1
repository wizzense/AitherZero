#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0441_Test-WorkflowsLocally
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0441_Test-WorkflowsLocally
    Stage: Testing
    Description: Enables local testing of GitHub Actions workflows without pushing to GitHub:
    Supports WhatIf: True
    Generated: 2025-11-04 20:50:00
#>

Describe '0441_Test-WorkflowsLocally' -Tag 'Unit', 'AutomationScript', 'Testing' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0441_Test-WorkflowsLocally.ps1'
        $script:ScriptName = '0441_Test-WorkflowsLocally'

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
        It 'Should have parameter: WorkflowFile' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('WorkflowFile') | Should -Be $true
        }

        It 'Should have parameter: EventName' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('EventName') | Should -Be $true
        }

        It 'Should have parameter: Job' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Job') | Should -Be $true
        }

        It 'Should have parameter: Secrets' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Secrets') | Should -Be $true
        }

        It 'Should have parameter: EnvVars' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('EnvVars') | Should -Be $true
        }

        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }

        It 'Should have parameter: InstallDependencies' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('InstallDependencies') | Should -Be $true
        }

        It 'Should have parameter: Platform' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Platform') | Should -Be $true
        }

        It 'Should have parameter: VerboseOutput' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('VerboseOutput') | Should -Be $true
        }

        It 'Should have parameter: NoCache' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('NoCache') | Should -Be $true
        }

        It 'Should have parameter: CI' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CI') | Should -Be $true
        }

        It 'Should have parameter: EventNamePayload' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('EventNamePayload') | Should -Be $true
        }

        It 'Should have parameter: ActVersion' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ActVersion') | Should -Be $true
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
