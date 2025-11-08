#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0799_cleanup-old-tags
.DESCRIPTION
    Auto-generated integration tests
    Supports WhatIf: False
    Interactive Script: Yes
    Generated: 2025-11-04 20:50:01
#>

Describe '0799_cleanup-old-tags Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'library/automation-scripts/0799_cleanup-old-tags.ps1'
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
                )
                if ($errors.Count -gt 0) { throw "Parse errors: $errors" }
            } | Should -Not -Throw
        }
    }
}
