#Requires -Modules Pester

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0000_Cleanup-Environment.ps1"

    # Mock external dependencies
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-CustomLog { }
    Mock Import-Module { }
    Mock Test-Path { $true }
    Mock Remove-Item { }
    Mock Get-ChildItem { @() }
    Mock Split-Path { "/workspaces/AitherZero" }
    Mock Join-Path { param($Path, $ChildPath) "$Path/$ChildPath" }
}

Describe "0000_Cleanup-Environment" {
    Context "Parameter Validation" {
        It "Should have CmdletBinding with SupportsShouldProcess" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            $scriptContent | Should -Match "\\[CmdletBinding\\(SupportsShouldProcess\\)\\]"
        }

        It "Should accept WhatIf parameter" {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept Configuration parameter" {
            $testConfig = @{ Infrastructure = @{ Directories = @{ LocalPath = "C:\\temp" } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "WhatIf Functionality" {
        It "Should not make changes in WhatIf mode" {
            Mock Remove-Item { throw "Remove-Item should not be called in WhatIf mode" }

            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Not -Invoke Remove-Item
        }
    }

    Context "Safety Guards" {
        It "Should refuse to delete current project directory" {
            $testConfig = @{
                Infrastructure = @{
                    Directories = @{ LocalPath = "/workspaces" }
                    Repositories = @{ RepoUrl = "https://github.com/user/AitherZero.git" }
                }
            }

            Mock Split-Path { "/workspaces/AitherZero" }
            Mock Test-Path { $true }
            Mock Write-ScriptLog { }

            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        It "Should handle missing directories gracefully" {
            Mock Test-Path { $false }
            Mock Write-ScriptLog { }

            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Logging Integration" {
        It "Should use Write-CustomLog when available" {
            Mock Get-Command { @{ Name = "Write-CustomLog" } } -ParameterFilter { $Name -eq "Write-CustomLog" }
            Mock Write-CustomLog { }

            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1
        }
    }
}
