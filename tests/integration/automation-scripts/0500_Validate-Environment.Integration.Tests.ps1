#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0500_Validate-Environment
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-10-30 02:11:49
#>

Describe '0500_Validate-Environment Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0500_Validate-Environment.ps1'
        $script:TestConfig = @{ Automation = @{ DryRun = $true } }
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -Configuration $script:TestConfig -WhatIf } | Should -Not -Throw
        }
    }
    
    Context 'Cross-Platform Directory Validation' {
        It 'Should skip Windows paths on non-Windows platforms' {
            if (-not $IsWindows) {
                $testConfig = @{
                    Infrastructure = @{
                        Directories = @{
                            WindowsPath = 'C:/temp'
                            LocalPath = '/tmp/test'
                        }
                    }
                }
                
                # The script should not throw when encountering Windows paths on Linux
                { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
            }
        }
        
        It 'Should handle Windows paths on Windows platforms' {
            if ($IsWindows) {
                $testConfig = @{
                    Infrastructure = @{
                        Directories = @{
                            TempPath = 'C:/temp'
                        }
                    }
                }
                
                # The script should process Windows paths normally on Windows
                { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
            }
        }
    }
}
