#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0821_Generate-ContinuationPrompt
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0821_Generate-ContinuationPrompt
    Stage: Integration
    Description: Creates comprehensive prompts for AI assistants to continue work seamlessly
    Generated: 2025-11-02 21:41:16
#>

Describe '0821_Generate-ContinuationPrompt' -Tag 'Unit', 'AutomationScript', 'Integration' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0821_Generate-ContinuationPrompt.ps1'
        $script:ScriptName = '0821_Generate-ContinuationPrompt'
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
        It 'Should have parameter: ContextPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ContextPath') | Should -Be $true
        }

        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: MaxTokens' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MaxTokens') | Should -Be $true
        }

        It 'Should have parameter: CopyToClipboard' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CopyToClipboard') | Should -Be $true
        }

        It 'Should have parameter: ShowPrompt' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ShowPrompt') | Should -Be $true
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
