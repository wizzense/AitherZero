#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0706_Update-PRTitle
.DESCRIPTION
    Comprehensive tests for PR title update automation
    Script: 0706_Update-PRTitle
    Stage: Development
    Description: Update pull request title with branch information
    Supports WhatIf: True
#>

Describe '0706_Update-PRTitle' -Tag 'Unit', 'AutomationScript', 'Development', 'GitHub' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0706_Update-PRTitle.ps1'
        $script:ScriptName = '0706_Update-PRTitle'

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

        It 'Should have proper header comment' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '.SYNOPSIS'
            $content | Should -Match '.DESCRIPTION'
            $content | Should -Match '.EXAMPLE'
            $content | Should -Match '.NOTES'
        }
    }

    Context 'Parameters' {
        It 'Should have parameter: PRNumber' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('PRNumber') | Should -Be $true
        }

        It 'Should have parameter: Format' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Format') | Should -Be $true
        }

        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }

        It 'Format parameter should validate set values' {
            $cmd = Get-Command $script:ScriptPath
            $formatParam = $cmd.Parameters['Format']
            $formatParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Metadata' {
        It 'Should be in stage: Development' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }

        It 'Should have GitHub category' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match 'Category:.*GitHub'
        }

        It 'Should have proper tags' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match 'Tags:.*pr'
        }
    }

    Context 'Helper Functions' {
        It 'Should contain Test-GitHubCLI function' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'function Test-GitHubCLI'
        }

        It 'Should contain Get-PRInfo function' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'function Get-PRInfo'
        }

        It 'Should contain Format-BranchInfo function' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'function Format-BranchInfo'
        }

        It 'Should contain Update-PRTitle function' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'function Update-PRTitle'
        }

        It 'Should contain Test-HasBranchInfo function' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'function Test-HasBranchInfo'
        }

        It 'Should contain Remove-BranchInfo function' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'function Remove-BranchInfo'
        }
    }

    Context 'Error Handling' {
        It 'Should check for gh CLI availability' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Test-GitHubCLI'
        }

        It 'Should check for GitHub authentication' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'gh auth status'
        }

        It 'Should have try-catch blocks' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'try\s*\{'
            $content | Should -Match 'catch\s*\{'
        }

        It 'Should set ErrorActionPreference to Stop' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\$ErrorActionPreference\s*=\s*[''"]Stop[''"]'
        }
    }

    Context 'Functionality' {
        It 'Should support Arrow format' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Arrow'
        }

        It 'Should support Brackets format' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Brackets'
        }

        It 'Should handle existing branch info' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Test-HasBranchInfo'
            $content | Should -Match 'Remove-BranchInfo'
        }

        It 'Should support dry run mode' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\$DryRun'
            $content | Should -Match 'DRY RUN'
        }

        It 'Should auto-detect current PR when no number provided' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'if \(-not \$PRNumber\)'
            $content | Should -Match 'gh pr list'
        }
    }

    Context 'Output and Logging' {
        It 'Should produce user-friendly output' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Write-Host'
        }

        It 'Should use colored output' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'ForegroundColor'
        }

        It 'Should show old and new titles on update' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Old:'
            $content | Should -Match 'New:'
        }
    }

    Context 'Integration with GitHub CLI' {
        It 'Should use gh pr view' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'gh pr view'
        }

        It 'Should use gh pr edit' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'gh pr edit'
        }

        It 'Should use gh pr list for auto-detection' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'gh pr list'
        }

        It 'Should parse JSON output' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'ConvertFrom-Json'
        }
    }

    Context 'Exit Codes' {
        It 'Should exit with 0 on success' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'exit 0'
        }

        It 'Should exit with 1 on error' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'exit 1'
        }
    }
}
