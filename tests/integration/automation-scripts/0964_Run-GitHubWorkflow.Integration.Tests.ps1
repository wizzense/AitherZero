#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0964_Run-GitHubWorkflow
.DESCRIPTION
    Auto-generated integration tests
    Supports WhatIf: False
    Interactive Script: Yes
    Generated: 2025-11-05 18:57:10
#>

Describe '0964_Run-GitHubWorkflow Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0964_Run-GitHubWorkflow.ps1'
    }

    Context 'Integration' {
        It 'Should be loadable (interactive script)' {
            # Script is interactive - cannot execute in non-interactive test
            # Verify script structure instead
            Test-Path $script:ScriptPath | Should -Be $true
            
            # Verify script can be parsed
            {
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile(
                    $script:ScriptPath, [ref]$null, [ref]$errors
                if ($errors.Count -gt 0) { throw "Parse errors: $errors" }
            } | Should -Not -Throw
        }
    }
}
