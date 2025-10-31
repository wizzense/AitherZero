#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0832_Generate-PromptFromData
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0832_Generate-PromptFromData
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0832_Generate-PromptFromData' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0832_Generate-PromptFromData.ps1'
        $script:ScriptName = '0832_Generate-PromptFromData'
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
        It 'Should have parameter: inputValuePath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('inputValuePath') | Should -Be $true
        }

        It 'Should have parameter: DataType' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DataType') | Should -Be $true
        }

        It 'Should have parameter: PromptTemplate' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('PromptTemplate') | Should -Be $true
        }

        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: CustomTemplate' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CustomTemplate') | Should -Be $true
        }

        It 'Should have parameter: MaxTokens' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MaxTokens') | Should -Be $true
        }

        It 'Should have parameter: Context' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Context') | Should -Be $true
        }

        It 'Should have parameter: IncludeExamples' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IncludeExamples') | Should -Be $true
        }

        It 'Should have parameter: GenerateCode' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('GenerateCode') | Should -Be $true
        }

        It 'Should have parameter: Interactive' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Interactive') | Should -Be $true
        }

        It 'Should have parameter: CopyToClipboard' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CopyToClipboard') | Should -Be $true
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
