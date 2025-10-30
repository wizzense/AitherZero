#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0735_Analyze-AISecurity
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0735_Analyze-AISecurity
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0735_Analyze-AISecurity' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0735_Analyze-AISecurity.ps1'
        $script:ScriptName = '0735_Analyze-AISecurity'
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

        It 'Should have parameter: ComplianceFramework' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ComplianceFramework') | Should -Be $true
        }

        It 'Should have parameter: GenerateRemediation' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('GenerateRemediation') | Should -Be $true
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
