#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0405_Validate-ModuleManifests
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-10-30 03:41:21
#>

Describe '0405_Validate-ModuleManifests Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        $script:ScriptPath = './automation-scripts/0405_Validate-ModuleManifests.ps1'
        $script:TestConfig = @{ Automation = @{ DryRun = $true } }
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -Configuration $script:TestConfig -WhatIf } | Should -Not -Throw
        }
    }
}
