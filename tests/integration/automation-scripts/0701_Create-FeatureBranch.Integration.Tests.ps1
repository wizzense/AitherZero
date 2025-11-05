#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0701_Create-FeatureBranch
.DESCRIPTION
    Auto-generated integration tests
    Supports WhatIf: True
    Interactive Script: Yes
    Generated: 2025-11-04 20:50:01
#>

Describe '0701_Create-FeatureBranch Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0701_Create-FeatureBranch.ps1'
    }

    Context 'Integration' {
        It 'Should execute in test mode with WhatIf' {
            {
                $params = @{ WhatIf = $true; ErrorAction = 'Stop' }
                & $script:ScriptPath @params
            } | Should -Not -Throw
        }
    }
}
