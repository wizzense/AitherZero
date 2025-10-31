#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0599_CI-ProgressReporter
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0599_CI-ProgressReporter
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0599_CI-ProgressReporter' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0599_CI-ProgressReporter.ps1'
        $script:ScriptName = '0599_CI-ProgressReporter'
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
        It 'Should have parameter: Operation' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Operation') | Should -Be $true
        }

        It 'Should have parameter: Stage' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Stage') | Should -Be $true
        }

        It 'Should have parameter: TotalSteps' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('TotalSteps') | Should -Be $true
        }

        It 'Should have parameter: CurrentStep' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CurrentStep') | Should -Be $true
        }

        It 'Should have parameter: Message' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Message') | Should -Be $true
        }

        It 'Should have parameter: Complete' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Complete') | Should -Be $true
        }

        It 'Should have parameter: Failed' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Failed') | Should -Be $true
        }

        It 'Should have parameter: LogPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('LogPath') | Should -Be $true
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
