#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0822_Test-IssueCreation
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0822_Test-IssueCreation
    Stage: Integration
    Description: Validates that analysis findings are correctly converted to GitHub issues
    Generated: 2025-11-02 21:41:16
#>

Describe '0822_Test-IssueCreation' -Tag 'Unit', 'AutomationScript', 'Integration' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0822_Test-IssueCreation.ps1'
        $script:ScriptName = '0822_Test-IssueCreation'
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
        It 'Should have parameter: CreateActualIssues' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CreateActualIssues') | Should -Be $true
        }

        It 'Should have parameter: TestMode' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('TestMode') | Should -Be $true
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
