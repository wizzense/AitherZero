#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0805_Analyze-OpenIssues
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0805_Analyze-OpenIssues
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0805_Analyze-OpenIssues' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0805_Analyze-OpenIssues.ps1'
        $script:ScriptName = '0805_Analyze-OpenIssues'
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
        It 'Should have parameter: Branch' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Branch') | Should -Be $true
        }

        It 'Should have parameter: BaseBranch' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('BaseBranch') | Should -Be $true
        }

        It 'Should have parameter: IncludeClosed' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IncludeClosed') | Should -Be $true
        }

        It 'Should have parameter: IssueType' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IssueType') | Should -Be $true
        }

        It 'Should have parameter: MaxIssues' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MaxIssues') | Should -Be $true
        }

        It 'Should have parameter: UseAI' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('UseAI') | Should -Be $true
        }

        It 'Should have parameter: MatchThreshold' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MatchThreshold') | Should -Be $true
        }

        It 'Should have parameter: Verbose' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Verbose') | Should -Be $true
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
