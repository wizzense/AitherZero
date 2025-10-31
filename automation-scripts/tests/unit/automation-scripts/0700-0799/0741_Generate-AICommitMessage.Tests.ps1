#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0741_Generate-AICommitMessage
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0741_Generate-AICommitMessage
    Stage: Development
    Description: Generate AI-enhanced commit messages from staged changes
    Generated: 2025-10-30 02:11:49
#>

Describe '0741_Generate-AICommitMessage' -Tag 'Unit', 'AutomationScript', 'Development' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1'
        $script:ScriptName = '0741_Generate-AICommitMessage'
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

        It 'Should have parameter: Scope' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Scope') | Should -Be $true
        }

        It 'Should have parameter: IncludeBody' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IncludeBody') | Should -Be $true
        }

        It 'Should have parameter: IncludeStats' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IncludeStats') | Should -Be $true
        }

        It 'Should have parameter: BreakingChange' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('BreakingChange') | Should -Be $true
        }

        It 'Should have parameter: ShowDiff' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ShowDiff') | Should -Be $true
        }

        It 'Should have parameter: CopyToClipboard' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CopyToClipboard') | Should -Be $true
        }

        It 'Should have parameter: ApplyDirectly' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ApplyDirectly') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Development' {
            $content = Get-Content $script:ScriptPath -First 20
            ($content -join ' ') | Should -Match 'Stage:'
        }

        It 'Should declare dependencies' {
            $content = Get-Content $script:ScriptPath -First 20
            ($content -join ' ') | Should -Match 'Dependencies:'
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
