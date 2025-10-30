#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0404_Run-PSScriptAnalyzer
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0404_Run-PSScriptAnalyzer
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0404_Run-PSScriptAnalyzer' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0404_Run-PSScriptAnalyzer.ps1'
        $script:ScriptName = '0404_Run-PSScriptAnalyzer'
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
        It 'Should have parameter: Path' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Path') | Should -Be $true
        }

        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }

        It 'Should have parameter: Fix' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Fix') | Should -Be $true
        }

        It 'Should have parameter: IncludeSuppressed' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IncludeSuppressed') | Should -Be $true
        }

        It 'Should have parameter: ExcludePaths' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ExcludePaths') | Should -Be $true
        }

        It 'Should have parameter: Severity' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Severity') | Should -Be $true
        }

        It 'Should have parameter: ExcludeRules' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ExcludeRules') | Should -Be $true
        }

        It 'Should have parameter: IncludeRules' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IncludeRules') | Should -Be $true
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
