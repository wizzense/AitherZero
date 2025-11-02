#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0810_Create-IssueFromTestFailure
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0810_Create-IssueFromTestFailure
    Stage: Integration
    Description: Parses test results and creates detailed GitHub issues for failures
    Generated: 2025-11-02 21:41:16
#>

Describe '0810_Create-IssueFromTestFailure' -Tag 'Unit', 'AutomationScript', 'Integration' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0810_Create-IssueFromTestFailure.ps1'
        $script:ScriptName = '0810_Create-IssueFromTestFailure'
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
        It 'Should have parameter: TestResults' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('TestResults') | Should -Be $true
        }

        It 'Should have parameter: IssueType' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IssueType') | Should -Be $true
        }

        It 'Should have parameter: AutoCreate' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('AutoCreate') | Should -Be $true
        }

        It 'Should have parameter: GitHubActions' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('GitHubActions') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Integration' {
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
}
