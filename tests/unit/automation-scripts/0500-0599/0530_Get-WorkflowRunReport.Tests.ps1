#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0530_Get-WorkflowRunReport
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0530_Get-WorkflowRunReport
    Stage: Reporting & Analysis
    Description: Fetches and displays detailed GitHub workflow run information including
    Generated: 2025-11-03 15:15:17
#>

Describe '0530_Get-WorkflowRunReport' -Tag 'Unit', 'AutomationScript', 'Reporting & Analysis' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0530_Get-WorkflowRunReport.ps1'
        $script:ScriptName = '0530_Get-WorkflowRunReport'
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
        It 'Should have parameter: RunId' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunId') | Should -Be $true
        }

        It 'Should have parameter: WorkflowName' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('WorkflowName') | Should -Be $true
        }

        It 'Should have parameter: Status' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Status') | Should -Be $true
        }

        It 'Should have parameter: Branch' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Branch') | Should -Be $true
        }

        It 'Should have parameter: List' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('List') | Should -Be $true
        }

        It 'Should have parameter: MaxRuns' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MaxRuns') | Should -Be $true
        }

        It 'Should have parameter: OutputFormat' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputFormat') | Should -Be $true
        }

        It 'Should have parameter: ExportPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ExportPath') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Reporting & Analysis' {
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
