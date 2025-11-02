#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0860_Validate-Deployments
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-11-02 08:36:29
#>

Describe '0860_Validate-Deployments Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Resolve script path relative to repository root
        $script:TestRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $script:ProjectRoot = Split-Path $script:TestRoot -Parent
        $script:ScriptPath = Join-Path $script:ProjectRoot "automation-scripts/0860_Validate-Deployments.ps1"
        $script:TestConfig = @{ Automation = @{ DryRun = $true } }
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -Configuration $script:TestConfig -WhatIf } | Should -Not -Throw
        }
    }
}
