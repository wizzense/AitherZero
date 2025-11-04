#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0831_Prompt-Templates
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0831_Prompt-Templates
    Stage: Integration
    Description: Provides reusable prompt templates for different types of AI interactions
    Generated: 2025-11-02 21:41:16
#>

Describe '0831_Prompt-Templates' -Tag 'Unit', 'AutomationScript', 'Integration' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0831_Prompt-Templates.ps1'
        $script:ScriptName = '0831_Prompt-Templates'
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
        It 'Should have parameter: TemplateName' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('TemplateName') | Should -Be $true
        }

        It 'Should have parameter: Variables' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Variables') | Should -Be $true
        }

        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: ShowTemplate' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ShowTemplate') | Should -Be $true
        }

        It 'Should have parameter: CopyToClipboard' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CopyToClipboard') | Should -Be $true
        }

        It 'Should have parameter: ReturnObject' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ReturnObject') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Integration' {
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
