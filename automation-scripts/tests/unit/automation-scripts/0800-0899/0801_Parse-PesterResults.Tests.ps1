#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0801_Parse-PesterResults
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0801_Parse-PesterResults
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0801_Parse-PesterResults' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0801_Parse-PesterResults.ps1'
        $script:ScriptName = '0801_Parse-PesterResults'
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
        It 'Should have parameter: ResultsFile' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ResultsFile') | Should -Be $true
        }

        It 'Should have parameter: Format' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Format') | Should -Be $true
        }

        It 'Should have parameter: FailuresOnly' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('FailuresOnly') | Should -Be $true
        }

        It 'Should have parameter: IncludeCoverage' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IncludeCoverage') | Should -Be $true
        }

        It 'Should have parameter: IncludePerformance' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IncludePerformance') | Should -Be $true
        }

        It 'Should have parameter: GroupByDescribe' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('GroupByDescribe') | Should -Be $true
        }

        It 'Should have parameter: OutputFormat' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputFormat') | Should -Be $true
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
