#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0403_Run-IntegrationTests
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-11-04 20:39:42
#>

Describe '0403_Run-IntegrationTests Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0403_Run-IntegrationTests.ps1'
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }
}
