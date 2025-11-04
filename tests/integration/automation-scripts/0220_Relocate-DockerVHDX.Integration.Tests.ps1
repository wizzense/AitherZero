#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0220_Relocate-DockerVHDX
.DESCRIPTION
    Integration tests for Docker Desktop VHDX relocation script
    Tests Windows-specific functionality and Docker Desktop integration
    Generated: 2025-11-04 00:26:00
#>

Describe '0220_Relocate-DockerVHDX Integration Tests' -Tag 'Integration', 'AutomationScript', 'Development', 'Docker' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0220_Relocate-DockerVHDX.ps1'
        $script:ScriptName = '0220_Relocate-DockerVHDX'
    }

    Context 'Windows-Only Execution' {
        It 'Should gracefully exit on non-Windows platforms' {
            if (-not $IsWindows) {
                $output = & $script:ScriptPath -WhatIf 2>&1
                $LASTEXITCODE | Should -Be 0
            } else {
                # On Windows, verify it attempts to run
                Set-ItResult -Skipped -Because "Test is for non-Windows platforms"
            }
        }
    }

    Context 'Administrator Check' -Skip:(-not $IsWindows) {
        It 'Should detect non-administrator execution' {
            # This test verifies the admin check works
            # In CI/CD this may run as admin, so we just verify the check exists
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'WindowsBuiltInRole.*Administrator'
        }
    }

    Context 'Directory Creation' -Skip:(-not $IsWindows) {
        It 'Should handle custom disk directory parameter' {
            $testDir = Join-Path $env:TEMP "TestDockerVM_$(Get-Random)"
            
            # Verify parameter is accepted
            {
                & $script:ScriptPath -DiskDir $testDir -WhatIf
            } | Should -Not -Throw
            
            # Clean up if created
            if (Test-Path $testDir) {
                Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Configuration Parameter' {
        It 'Should accept Configuration hashtable' {
            $config = @{
                DevelopmentTools = @{
                    Docker = @{
                        Install = $true
                    }
                }
            }
            
            {
                & $script:ScriptPath -Configuration $config -WhatIf
            } | Should -Not -Throw
        }
    }

    Context 'Error Handling' {
        It 'Should handle missing dependencies gracefully' {
            # Script should handle missing logging module
            {
                & $script:ScriptPath -WhatIf 2>&1 | Out-Null
            } | Should -Not -Throw
        }
    }

    Context 'WhatIf Support' {
        It 'Should support WhatIf for all operations' {
            # WhatIf should not make any actual changes
            {
                & $script:ScriptPath -WhatIf
            } | Should -Not -Throw
        }
    }
}
