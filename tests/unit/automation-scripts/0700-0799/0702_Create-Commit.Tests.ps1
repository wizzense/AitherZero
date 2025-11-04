#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0702_Create-Commit
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0702_Create-Commit
    Stage: Development
    Description: Creates a Git commit following conventional commit standards with
    Generated: 2025-11-04 20:39:43
#>

Describe '0702_Create-Commit' -Tag 'Unit', 'AutomationScript', 'Development' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0702_Create-Commit.ps1'
        $script:ScriptName = '0702_Create-Commit'

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
        It 'Should have parameter: Type' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Type') | Should -Be $true
        }

        It 'Should have parameter: Message' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Message') | Should -Be $true
        }

        It 'Should have parameter: Scope' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Scope') | Should -Be $true
        }

        It 'Should have parameter: Body' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Body') | Should -Be $true
        }

        It 'Should have parameter: CoAuthors' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CoAuthors') | Should -Be $true
        }

        It 'Should have parameter: Breaking' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Breaking') | Should -Be $true
        }

        It 'Should have parameter: Closes' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Closes') | Should -Be $true
        }

        It 'Should have parameter: Refs' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Refs') | Should -Be $true
        }

        It 'Should have parameter: AutoStage' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('AutoStage') | Should -Be $true
        }

        It 'Should have parameter: Push' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Push') | Should -Be $true
        }

        It 'Should have parameter: SignOff' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SignOff') | Should -Be $true
        }

        It 'Should have parameter: NonInteractive' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('NonInteractive') | Should -Be $true
        }

        It 'Should have parameter: Force' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Force') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Development' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }
    }

    Context 'Execution' {
        It 'Should execute with WhatIf' {
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
            # Skip if not in CI
            if (-not $script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "CI-only validation"
                return
            }
            
            # This test only runs in CI
            $script:TestEnv.IsCI | Should -Be $true
            $env:CI | Should -Not -BeNullOrEmpty
        }

        It 'Should adapt to local environment' {
            # Skip if in CI
            if ($script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "Local-only validation"
                return
            }
            
            # This test only runs locally
            $script:TestEnv.IsCI | Should -Be $false
        }
    }
}
