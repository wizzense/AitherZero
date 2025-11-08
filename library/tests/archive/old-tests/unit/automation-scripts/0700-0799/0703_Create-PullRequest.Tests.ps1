#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0703_Create-PullRequest
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0703_Create-PullRequest
    Stage: Development
    Description: Creates a GitHub pull request with automatic template selection,
    Supports WhatIf: True
    Generated: 2025-11-04 20:50:01
#>

Describe '0703_Create-PullRequest' -Tag 'Unit', 'AutomationScript', 'Development' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0703_Create-PullRequest.ps1'
        $script:ScriptName = '0703_Create-PullRequest'

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
        It 'Should have parameter: Title' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Title') | Should -Be $true
        }

        It 'Should have parameter: Body' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Body') | Should -Be $true
        }

        It 'Should have parameter: Base' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Base') | Should -Be $true
        }

        It 'Should have parameter: Template' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Template') | Should -Be $true
        }

        It 'Should have parameter: Reviewers' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Reviewers') | Should -Be $true
        }

        It 'Should have parameter: Assignees' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Assignees') | Should -Be $true
        }

        It 'Should have parameter: Labels' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Labels') | Should -Be $true
        }

        It 'Should have parameter: Draft' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Draft') | Should -Be $true
        }

        It 'Should have parameter: AutoMerge' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('AutoMerge') | Should -Be $true
        }

        It 'Should have parameter: MergeMethod' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MergeMethod') | Should -Be $true
        }

        It 'Should have parameter: LinkIssue' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('LinkIssue') | Should -Be $true
        }

        It 'Should have parameter: Closes' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Closes') | Should -Be $true
        }

        It 'Should have parameter: RunChecks' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunChecks') | Should -Be $true
        }

        It 'Should have parameter: OpenInBrowser' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OpenInBrowser') | Should -Be $true
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
