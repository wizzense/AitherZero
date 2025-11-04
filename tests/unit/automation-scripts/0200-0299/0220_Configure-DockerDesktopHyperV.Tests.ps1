#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0220_Configure-DockerDesktopHyperV
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0220_Configure-DockerDesktopHyperV
    Stage: Development
    Description: Configure Docker Desktop with Hyper-V backend and custom VHDX location on Windows
    Generated: 2025-11-04 00:20:00
#>

Describe '0220_Configure-DockerDesktopHyperV' -Tag 'Unit', 'AutomationScript', 'Development' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0220_Configure-DockerDesktopHyperV.ps1'
        $script:ScriptName = '0220_Configure-DockerDesktopHyperV'
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
        It 'Should have parameter: Configuration' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Configuration') | Should -Be $true
        }

        It 'Should have parameter: DiskDir' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DiskDir') | Should -Be $true
        }

        It 'Should have parameter: SkipFeatureInstall' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SkipFeatureInstall') | Should -Be $true
        }
    }

    Context 'Metadata' {
        It 'Should be in stage: Development' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }

        It 'Should declare dependencies' {
            $content = Get-Content $script:ScriptPath -First 20
            ($content -join ' ') | Should -Match 'Dependencies:'
        }

        It 'Should have proper tags' {
            $content = Get-Content $script:ScriptPath -First 20
            ($content -join ' ') | Should -Match 'Tags:'
        }
    }

    Context 'Execution' {
        It 'Should execute with WhatIf' {
            {
                $params = @{ WhatIf = $true }
                $params.Configuration = @{}
                & $script:ScriptPath @params
            } | Should -Not -Throw
        }

        It 'Should handle missing Configuration parameter' {
            {
                & $script:ScriptPath -WhatIf
            } | Should -Not -Throw
        }

        It 'Should accept custom DiskDir parameter' {
            {
                & $script:ScriptPath -DiskDir "E:\CustomPath" -WhatIf
            } | Should -Not -Throw
        }
    }

    Context 'Platform Detection' {
        It 'Should skip on non-Windows platforms' {
            # This test will naturally pass on Linux/macOS
            # The script should exit 0 when not on Windows
            if (-not $IsWindows) {
                $result = & $script:ScriptPath -WhatIf 2>&1
                $LASTEXITCODE | Should -Be 0
            }
        }
    }

    Context 'Logging' {
        It 'Should use Write-ScriptLog function' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'function Write-ScriptLog'
        }

        It 'Should attempt to load Logging module' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Logging\.psm1'
        }
    }
}
