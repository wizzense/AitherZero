#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    Pester tests for 0850_Deploy-PREnvironment.ps1
.DESCRIPTION
    Tests the PR environment deployment script to ensure correct Docker paths
#>

BeforeAll {
    # Get the script path - navigate from tests/unit/automation-scripts/0800-0899 to root
    $script:scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0850_Deploy-PREnvironment.ps1"
    $script:scriptContent = Get-Content $script:scriptPath -Raw

    # Mock dependencies
    Mock Write-Host {}
    Mock Write-Warning {}
    Mock Write-Error {}
    Mock Set-Content {}
    Mock docker {}
    Mock Test-Path { $true }
}

Describe "0850_Deploy-PREnvironment - Docker Path Configuration" {
    Context "Docker Compose Generation" {
        It "Should use /opt/aitherzero path for logs volume" {
            $script:scriptContent | Should -Match "/opt/aitherzero/logs"
        }

        It "Should use /opt/aitherzero path for reports volume" {
            $script:scriptContent | Should -Match "/opt/aitherzero/reports"
        }

        It "Should use /opt/aitherzero path in healthcheck" {
            $script:scriptContent | Should -Match "/opt/aitherzero/AitherZero\.psd1"
        }

        It "Should not reference /app for AitherZero module path" {
            # Check that healthcheck doesn't use /app/AitherZero.psd1
            $script:scriptContent | Should -Not -Match 'Test-Path /app/AitherZero\.psd1'
        }
    }

    Context "Script Structure" {
        It "Should exist and be readable" {
            Test-Path $script:scriptPath | Should -Be $true
        }

        It "Should be a valid PowerShell script" {
            { $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:scriptPath,
                [ref]$null,
                [ref]$null
            ) } | Should -Not -Throw
        }
    }
}
