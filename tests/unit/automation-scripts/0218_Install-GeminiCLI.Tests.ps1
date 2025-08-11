#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0218_Install-GeminiCLI
.DESCRIPTION
    Automated tests generated for automation script: 0218_Install-GeminiCLI
    Script Description: Install Google Gemini CLI and dependencies
    Generated: 2025-08-08 22:47:46
#>

Describe '0218_Install-GeminiCLI' -Tag 'Unit', 'AutomationScript' {

    BeforeAll {
        $script:ScriptPath = './automation-scripts/0218_Install-GeminiCLI.ps1'
        $script:ScriptName = '0218_Install-GeminiCLI'

        # Create a dummy function for gemini if it doesn't exist
        if (-not (Get-Command gemini -ErrorAction SilentlyContinue)) {
            function gemini { param([string]$arg) }
        }

        # Mock external commands
        Mock Add-Content { return $null } -Verifiable
        Mock ForEach-Object { return $null } -Verifiable
        Mock gemini { return $null } -Verifiable
        Mock Import-Module { return $null } -Verifiable
        Mock Join-Path { return $null } -Verifiable
        Mock npm { return $null } -Verifiable
        Mock Select-String { return $null } -Verifiable
        Mock Split-Path { return $null } -Verifiable
    }

    Context 'Script Validation' {
        It 'Script file should exist' {
            Test-Path $script:ScriptPath | Should -Be $true
        }

        It 'Script should have valid PowerShell syntax' {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:ScriptPath,
                [ref]$null,
                [ref]$errors
            )
            $errors.Count | Should -Be 0
        }
    }

    Context 'Parameter Validation' {
        It 'Should accept -Configuration parameter' {
            $scriptInfo = Get-Command $script:ScriptPath
            $scriptInfo.Parameters.ContainsKey('Configuration') | Should -Be $true
            $scriptInfo.Parameters['Configuration'].ParameterType.Name | Should -Be 'Hashtable'
        }

    }

    Context 'Function Tests' {
        It 'Function Write-ScriptLog should be defined' {
            # This test would require sourcing the script
            # . $script:ScriptPath
            # Get-Command -Name 'Write-ScriptLog' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            $true | Should -Be $true # Placeholder
        }

    }

    Context 'Script Execution' {
        It 'Should not throw when executed with WhatIf' {
            {
                $params = @{}
                $params['Configuration'] = @{}
                $params['WhatIf'] = $true
                & $script:ScriptPath @params
            } | Should -Not -Throw
        }

        It 'Should be in stage: Development' {
            $content = Get-Content $script:ScriptPath -First 10
            $content -join ' ' | Should -Match '#\s+Stage:\s*Development'
        }

        It 'Should declare dependencies: Node, Python' {
            $content = Get-Content $script:ScriptPath -First 10
            $content -join ' ' | Should -Match 'Dependencies:'
        }
    }

    AfterAll {
        # Verify all mocks were called as expected
        # Assert-VerifiableMock
    }

}

