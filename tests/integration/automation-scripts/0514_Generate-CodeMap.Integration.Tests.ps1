#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0514_Generate-CodeMap
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-11-04 20:18:33
#>

Describe '0514_Generate-CodeMap Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0514_Generate-CodeMap.ps1'
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }
}
