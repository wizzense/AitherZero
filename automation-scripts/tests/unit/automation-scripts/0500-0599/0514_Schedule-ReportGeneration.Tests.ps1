#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0514_Schedule-ReportGeneration
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0514_Schedule-ReportGeneration
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0514_Schedule-ReportGeneration' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0514_Schedule-ReportGeneration.ps1'
        $script:ScriptName = '0514_Schedule-ReportGeneration'
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

        It 'Should have parameter: Schedule' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Schedule') | Should -Be $true
        }

        It 'Should have parameter: Time' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Time') | Should -Be $true
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
