#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0876_Rotate-LicenseKeys
.DESCRIPTION
    Auto-generated integration tests
    Supports WhatIf: True
    Generated: 2025-11-07 20:42:23
#>

Describe '0876_Rotate-LicenseKeys Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0876_Rotate-LicenseKeys.ps1'
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
