#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0744_Generate-AutoDocumentation
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0744_Generate-AutoDocumentation
    Stage: AI & Documentation
    Description: Automated reactive documentation generation with quality validation
    Generated: 2025-10-30 02:11:49
#>

Describe '0744_Generate-AutoDocumentation' -Tag 'Unit', 'AutomationScript', 'AI & Documentation' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0744_Generate-AutoDocumentation.ps1'
        $script:ScriptName = '0744_Generate-AutoDocumentation'
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
        It 'Should have parameter: Mode' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Mode') | Should -Be $true
        }

        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: Format' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Format') | Should -Be $true
        }

        It 'Should have parameter: Watch' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Watch') | Should -Be $true
        }

        It 'Should have parameter: Quality' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Quality') | Should -Be $true
        }

        It 'Should have parameter: WatchTimeout' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('WatchTimeout') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: AI & Documentation' {
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
