#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0703_Create-PullRequest
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0703_Create-PullRequest
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0703_Create-PullRequest' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0703_Create-PullRequest.ps1'
        $script:ScriptName = '0703_Create-PullRequest'
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
        It 'Should be in stage: Unknown' {
            $content = Get-Content $script:ScriptPath -First 20
            ($content -join ' ') | Should -Match 'Stage:'
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
