#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0443_Install-PowerShellYaml
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0443_Install-PowerShellYaml
    Stage: Testing
    Description: Installs the powershell-yaml module which provides:
    Generated: 2025-11-02 21:41:15
#>

Describe '0443_Install-PowerShellYaml' -Tag 'Unit', 'AutomationScript', 'Testing' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0443_Install-PowerShellYaml.ps1'
        $script:ScriptName = '0443_Install-PowerShellYaml'
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
        It 'Should have parameter: Force' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Force') | Should -Be $true
        }

        It 'Should have parameter: Scope' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Scope') | Should -Be $true
        }

        It 'Should have parameter: CI' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CI') | Should -Be $true
        }

        It 'Should have parameter: MinimumVersion' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MinimumVersion') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Testing' {
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
