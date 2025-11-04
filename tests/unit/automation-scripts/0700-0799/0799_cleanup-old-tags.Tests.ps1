#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0799_cleanup-old-tags
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0799_cleanup-old-tags
    Stage: Git Automation & Maintenance
    Description: This script removes old version tags and development tags to maintain a clean tag history.
    Generated: 2025-11-02 21:41:15
#>

Describe '0799_cleanup-old-tags' -Tag 'Unit', 'AutomationScript', 'Git Automation & Maintenance' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0799_cleanup-old-tags.ps1'
        $script:ScriptName = '0799_cleanup-old-tags'
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
        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }

        It 'Should have parameter: KeepMajorVersions' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('KeepMajorVersions') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Git Automation & Maintenance' {
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
