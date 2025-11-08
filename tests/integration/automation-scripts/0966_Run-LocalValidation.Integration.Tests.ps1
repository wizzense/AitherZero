#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0966_Run-LocalValidation
.DESCRIPTION
    Auto-generated integration tests
    Supports WhatIf: False
    Generated: 2025-11-06 03:17:57
#>

Describe '0966_Run-LocalValidation Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'library/automation-scripts/0966_Run-LocalValidation.ps1'
    }

    Context 'Integration' {
        It 'Should have required structure (has mandatory parameters)' {
            # Script has mandatory parameters - cannot execute without them
            # Verify script structure instead
            Test-Path $script:ScriptPath | Should -Be $true
            
            # Verify Get-Command can read parameters
            {
                $cmd = Get-Command $script:ScriptPath -ErrorAction Stop
                $cmd.Parameters.Count | Should -BeGreaterThan 0
            } | Should -Not -Throw
        }
    }
}
