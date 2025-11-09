#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0531_Get-WorkflowRunReport
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0531_Get-WorkflowRunReport
    Stage: Reporting & Analysis
    Description: Fetches and displays detailed GitHub workflow run information including
    Supports WhatIf: True
    Generated: 2025-11-04 20:50:01
#>

Describe '0531_Get-WorkflowRunReport' -Tag 'Unit', 'AutomationScript', 'Reporting & Analysis' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0531_Get-WorkflowRunReport.ps1'
        $script:ScriptName = '0531_Get-WorkflowRunReport'

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
        It 'Should have parameter: RunId' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunId') | Should -Be $true
        }

        It 'Should have parameter: WorkflowName' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('WorkflowName') | Should -Be $true
        }

        It 'Should have parameter: Status' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Status') | Should -Be $true
        }

        It 'Should have parameter: Branch' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Branch') | Should -Be $true
        }

        It 'Should have parameter: List' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('List') | Should -Be $true
        }

        It 'Should have parameter: Detailed' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Detailed') | Should -Be $true
        }

        It 'Should have parameter: MaxRuns' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MaxRuns') | Should -Be $true
        }

        It 'Should have Limit alias for MaxRuns parameter' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters['MaxRuns'].Aliases | Should -Contain 'Limit'
        }

        It 'Should have parameter: OutputFormat' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputFormat') | Should -Be $true
        }

        It 'Should accept both as OutputFormat value' {
            $cmd = Get-Command $script:ScriptPath
            $validateSet = $cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'both'
        }

        It 'Should have parameter: ExportPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ExportPath') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Reporting & Analysis' {
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
