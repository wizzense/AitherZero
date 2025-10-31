#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0511_Show-ProjectDashboard
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0511_Show-ProjectDashboard
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0511_Show-ProjectDashboard' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0511_Show-ProjectDashboard.ps1'
        $script:ScriptName = '0511_Show-ProjectDashboard'
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
        It 'Should have parameter: ProjectPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ProjectPath') | Should -Be $true
        }

        It 'Should have parameter: ShowLogs' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ShowLogs') | Should -Be $true
        }

        It 'Should have parameter: ShowTests' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ShowTests') | Should -Be $true
        }

        It 'Should have parameter: ShowMetrics' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ShowMetrics') | Should -Be $true
        }

        It 'Should have parameter: ShowAll' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ShowAll') | Should -Be $true
        }

        It 'Should have parameter: LogTailLines' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('LogTailLines') | Should -Be $true
        }

        It 'Should have parameter: Follow' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Follow') | Should -Be $true
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
