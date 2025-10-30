#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0405_Validate-ModuleManifests
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0405_Validate-ModuleManifests
    Stage: Testing
    Description: This script validates all .psd1 module manifest files in the AitherZero project to ensure:
    Generated: 2025-10-30 03:41:21
#>

Describe "0405_Validate-ModuleManifests" {
    BeforeAll {
        $script:ScriptPath = './automation-scripts/0405_Validate-ModuleManifests.ps1'
        $script:ScriptName = '0405_Validate-ModuleManifests'
        $script:ToolPath = './tools/Validate-ModuleManifest.ps1'
        $script:TestTempDir = Join-Path $TestDrive "manifest-tests"
        New-Item -Path $script:TestTempDir -ItemType Directory -Force | Out-Null
    }

    Context "Script Validation" {
        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$errors)
            $errors | Should -BeNullOrEmpty
        }

        It "Should support WhatIf" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'SupportsShouldProcess'
        }
    }

    Context "Metadata" {
        It "Should be in stage: Testing" {
            $content = Get-Content $scriptPath
            ($content -join ' ') | Should -Match 'Stage:'
            ($content -join ' ') | Should -Match 'Testing'
        }

        It "Should have order: 0405" {
            $content = Get-Content $scriptPath
            ($content -join ' ') | Should -Match 'Order.*0405'
        }
    }

    Context "Execution" {
        It "Should execute with WhatIf" {
            { & $scriptPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Valid Manifest Validation" {
        It "Should pass validation for a clean manifest" {
            $validManifest = @"
@{
    ModuleVersion = '1.0.0'
    GUID = 'a7d4e8f1-2b3c-4d5e-6f7a-8b9c0d1e2f3a'
    Author = 'Test Author'
    Description = 'Test module without Unicode issues'
    PowerShellVersion = '7.0'
    RootModule = 'TestModule.psm1'
    FunctionsToExport = @('*')
}
"@
            $manifestPath = Join-Path $script:TestTempDir "valid-manifest.psd1"
            Set-Content -Path $manifestPath -Value $validManifest -Encoding UTF8
            
            # Create a dummy module file to satisfy Test-ModuleManifest
            $modulePath = Join-Path $script:TestTempDir "TestModule.psm1"
            Set-Content -Path $modulePath -Value "# Test module" -Encoding UTF8
            
            $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:ToolPath -Path $manifestPath 2>&1
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'Parameters' {
        It 'Should have parameter: Fix' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Fix') | Should -Be $true
        }

        It 'Should have parameter: Path' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Path') | Should -Be $true
        }
    }
}
