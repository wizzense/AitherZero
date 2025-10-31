#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0742_Create-AIPoweredPR
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0742_Create-AIPoweredPR
    Stage: Development
    Description: Create AI-enhanced pull request with automatic description generation
    Generated: 2025-10-30 02:11:49
#>

Describe '0742_Create-AIPoweredPR' -Tag 'Unit', 'AutomationScript', 'Development' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0742_Create-AIPoweredPR.ps1'
        $script:ScriptName = '0742_Create-AIPoweredPR'
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
        It 'Should have parameter: Title' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Title') | Should -Be $true
        }

        It 'Should have parameter: Body' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Body') | Should -Be $true
        }

        It 'Should have parameter: Base' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Base') | Should -Be $true
        }

        It 'Should have parameter: Labels' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Labels') | Should -Be $true
        }

        It 'Should have parameter: UseAI' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('UseAI') | Should -Be $true
        }

        It 'Should have parameter: EnhanceWithCopilot' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('EnhanceWithCopilot') | Should -Be $true
        }

        It 'Should have parameter: EnhanceWithClaude' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('EnhanceWithClaude') | Should -Be $true
        }

        It 'Should have parameter: AutoMerge' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('AutoMerge') | Should -Be $true
        }

        It 'Should have parameter: Draft' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Draft') | Should -Be $true
        }

        It 'Should have parameter: NonInteractive' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('NonInteractive') | Should -Be $true
        }

        It 'Should have parameter: Force' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Force') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Development' {
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
