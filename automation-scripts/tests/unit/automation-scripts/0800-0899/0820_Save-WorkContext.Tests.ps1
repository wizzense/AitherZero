#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0820_Save-WorkContext
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0820_Save-WorkContext
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0820_Save-WorkContext' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0820_Save-WorkContext.ps1'
        $script:ScriptName = '0820_Save-WorkContext'
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
        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: IncludeHistory' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IncludeHistory') | Should -Be $true
        }

        It 'Should have parameter: CompressContext' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CompressContext') | Should -Be $true
        }

        It 'Should have parameter: HistoryCount' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('HistoryCount') | Should -Be $true
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
