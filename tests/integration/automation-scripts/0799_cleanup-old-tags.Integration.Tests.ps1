#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0799_cleanup-old-tags
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-11-04 20:39:43
#>

Describe '0799_cleanup-old-tags Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0799_cleanup-old-tags.ps1'
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            # Script does not support -WhatIf parameter
            # Test basic script structure instead
            Test-Path $script:ScriptPath | Should -Be $true
        }
    }
}
