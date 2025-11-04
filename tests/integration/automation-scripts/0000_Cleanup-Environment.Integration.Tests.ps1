#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0000_Cleanup-Environment
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-11-04 20:39:42
#>

Describe '0000_Cleanup-Environment Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0000_Cleanup-Environment.ps1'
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }
}
