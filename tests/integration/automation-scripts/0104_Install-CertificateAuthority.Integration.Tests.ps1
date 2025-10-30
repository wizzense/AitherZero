#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0104_Install-CertificateAuthority
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-10-30 02:11:49
#>

Describe '0104_Install-CertificateAuthority Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0104_Install-CertificateAuthority.ps1'
        $script:TestConfig = @{ Automation = @{ DryRun = $true } }
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -Configuration $script:TestConfig -WhatIf } | Should -Not -Throw
        }
    }
}
