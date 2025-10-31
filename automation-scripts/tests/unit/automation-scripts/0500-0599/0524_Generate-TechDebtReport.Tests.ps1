#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0524_Generate-TechDebtReport
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0524_Generate-TechDebtReport
    Stage: Reporting
    Description: Tech debt report generation from modular analysis results
    Generated: 2025-10-30 02:11:49
#>

Describe '0524_Generate-TechDebtReport' -Tag 'Unit', 'AutomationScript', 'Reporting' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0524_Generate-TechDebtReport.ps1'
        $script:ScriptName = '0524_Generate-TechDebtReport'
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
        It 'Should have parameter: AnalysisPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('AnalysisPath') | Should -Be $true
        }

        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: Format' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Format') | Should -Be $true
        }

        It 'Should have parameter: RunAnalysis' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunAnalysis') | Should -Be $true
        }

        It 'Should have parameter: UseLatest' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('UseLatest') | Should -Be $true
        }

        It 'Should have parameter: OpenReport' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OpenReport') | Should -Be $true
        }

        It 'Should have parameter: AnalysisTypes' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('AnalysisTypes') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Reporting' {
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
