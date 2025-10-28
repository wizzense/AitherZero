#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    Pester tests for 0852_Validate-PRDockerDeployment.ps1
.DESCRIPTION
    Tests the PR Docker deployment validation script to ensure correct module paths
#>

BeforeAll {
    # Get the script path - navigate from tests/unit/automation-scripts/0800-0899 to root
    $script:scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0852_Validate-PRDockerDeployment.ps1"
    $script:scriptContent = Get-Content $script:scriptPath -Raw

    # Mock dependencies
    Mock Write-Host {}
    Mock Write-Warning {}
    Mock Write-Error {}
    Mock docker {}
    Mock Test-Path { $true }
}

Describe "0852_Validate-PRDockerDeployment - Module Path Validation" {
    Context "Module Import Paths" {
        It "Should use /opt/aitherzero path for module import tests" {
            $script:scriptContent | Should -Match "Import-Module /opt/aitherzero/AitherZero\.psd1"
        }

        It "Should not use old /app path for module import" {
            # Verify old path is not used for module import
            $script:scriptContent | Should -Not -Match "Import-Module /app/AitherZero\.psd1"
        }
    }

    Context "File System Validation Paths" {
        It "Should validate /opt/aitherzero paths in container" {
            # Check for expected paths in filesystem validation
            $script:scriptContent | Should -Match "/opt/aitherzero/AitherZero\.psd1"
            $script:scriptContent | Should -Match "/opt/aitherzero/domains"
            $script:scriptContent | Should -Match "/opt/aitherzero/automation-scripts"
        }

        It "Should validate /opt/aitherzero logs and reports directories" {
            $script:scriptContent | Should -Match "/opt/aitherzero/logs"
            $script:scriptContent | Should -Match "/opt/aitherzero/reports"
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
