#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0405_Validate-ModuleManifests
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0405_Validate-ModuleManifests
    Stage: Testing
    Description: This script validates all .psd1 module manifest files in the AitherZero project to ensure:
    Generated: 2025-10-30 03:41:21
#>

Describe '0405_Validate-ModuleManifests' -Tag 'Unit', 'AutomationScript', 'Testing' {

    BeforeAll {
        $script:ScriptPath = './automation-scripts/0405_Validate-ModuleManifests.ps1'
        $script:ScriptName = '0405_Validate-ModuleManifests'
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
        It 'Should have parameter: Fix' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Fix') | Should -Be $true
        }

        It 'Should have parameter: Path' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Path') | Should -Be $true
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
