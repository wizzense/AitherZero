#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0722_Install-RunnerServices
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0722_Install-RunnerServices
    Stage: Infrastructure
    Description: Configures GitHub Actions runners to run as system services with proper monitoring and management
    Supports WhatIf: True
    Generated: 2025-11-04 20:50:01
#>

Describe '0722_Install-RunnerServices' -Tag 'Unit', 'AutomationScript', 'Infrastructure' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0722_Install-RunnerServices.ps1'
        $script:ScriptName = '0722_Install-RunnerServices'

        # Import test helpers for environment detection
        $testHelpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "../../TestHelpers.psm1"
        if (Test-Path $testHelpersPath) {
            Import-Module $testHelpersPath -Force -ErrorAction SilentlyContinue
        }

        # Detect test environment
        $script:TestEnv = if (Get-Command Get-TestEnvironment -ErrorAction SilentlyContinue) {
            Get-TestEnvironment
        } else {
            @{ IsCI = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true'); IsLocal = $true }
        }
    }

    Context 'Script Validation' {
        It 'Script file should exist' {
            Test-Path $script:ScriptPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:ScriptPath, [ref]$null, [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It 'Should support WhatIf' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'SupportsShouldProcess'
        }
    }

    Context 'Parameters' {
        It 'Should have parameter: RunnerName' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunnerName') | Should -Be $true
        }

        It 'Should have parameter: ServiceType' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ServiceType') | Should -Be $true
        }

        It 'Should have parameter: StartupType' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('StartupType') | Should -Be $true
        }

        It 'Should have parameter: RunAsUser' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunAsUser') | Should -Be $true
        }

        It 'Should have parameter: EnableMonitoring' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('EnableMonitoring') | Should -Be $true
        }

        It 'Should have parameter: LogLevel' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('LogLevel') | Should -Be $true
        }

        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }

        It 'Should have parameter: CI' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CI') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Infrastructure' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }
    }

    Context 'Execution' {
        It 'Should execute with WhatIf without throwing' {
            {
                $params = @{ WhatIf = $true }
                & $script:ScriptPath @params
            } | Should -Not -Throw
        }
    }

    Context 'Environment Awareness' {
        It 'Test environment should be detected' {
            $script:TestEnv | Should -Not -BeNullOrEmpty
            $script:TestEnv.Keys | Should -Contain 'IsCI'
        }

        It 'Should adapt to CI environment' {
            if (-not $script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "CI-only validation"
                return
            }
            $script:TestEnv.IsCI | Should -Be $true
            $env:CI | Should -Not -BeNullOrEmpty
        }

        It 'Should adapt to local environment' {
            if ($script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "Local-only validation"
                return
            }
            $script:TestEnv.IsCI | Should -Be $false
        }
    }
}
