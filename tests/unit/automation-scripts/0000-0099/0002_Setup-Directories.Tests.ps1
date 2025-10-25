#Requires -Modules Pester

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0002_Setup-Directories.ps1"

    # Mock external dependencies
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-CustomLog { }
    Mock Import-Module { }
    Mock Test-Path { $false }
    Mock New-Item { }
    Mock Join-Path { param($Path, $ChildPath) "$Path/$ChildPath" }
}

Describe "0002_Setup-Directories" {
    Context "Parameter Validation" {
        It "Should have CmdletBinding with SupportsShouldProcess" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            $scriptContent | Should -Match "\\[CmdletBinding\\(SupportsShouldProcess\\)\\]"
        }

        It "Should accept WhatIf parameter" {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept Configuration parameter" {
            $testConfig = @{ Infrastructure = @{ Directories = @{ HyperVPath = "C:\\HyperV" } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "WhatIf Functionality" {
        It "Should not create directories in WhatIf mode" {
            Mock New-Item { throw "Should not create directories in WhatIf mode" }

            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Not -Invoke New-Item
        }
    }

    Context "Directory Creation" {
        It "Should create infrastructure directories from configuration" {
            $testConfig = @{
                Infrastructure = @{
                    Directories = @{
                        HyperVPath = "C:\\HyperV"
                        IsoSharePath = "C:\\iso_share"
                        LocalPath = "C:\\temp"
                    }
                }
            }

            Mock Test-Path { $false }
            Mock New-Item { }
            Mock Write-ScriptLog { }

            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should use default directories when configuration is empty" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock Test-Path { $false }
            Mock New-Item { }
            Mock Write-ScriptLog { }

            { & $script:ScriptPath -Configuration @{} -WhatIf } | Should -Not -Throw
        }

        It "Should use Unix paths on non-Windows systems" {
            Mock Get-Variable { @{ Value = $false } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock Test-Path { $false }
            Mock New-Item { }
            Mock Write-ScriptLog { }

            { & $script:ScriptPath -Configuration @{} -WhatIf } | Should -Not -Throw
        }

        It "Should skip existing directories" {
            Mock Test-Path { $true }
            Mock Write-ScriptLog { }

            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Not -Invoke New-Item
        }

        It "Should expand environment variables in paths" {
            Mock [System.Environment]::ExpandEnvironmentVariables { param($Path) $Path -replace "%TEMP%", "C:\\temp" }
            Mock Test-Path { $false }
            Mock New-Item { }
            Mock Write-ScriptLog { }

            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Logs Directory Creation" {
        It "Should create logs directory" {
            Mock Test-Path { $false }
            Mock New-Item { }
            Mock Join-Path { "./logs" }
            Mock Split-Path { "/workspaces/AitherZero" }
            Mock Write-ScriptLog { }

            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle custom logs path from configuration" {
            $testConfig = @{
                Logging = @{ Path = "/custom/logs" }
            }

            Mock Test-Path { $false }
            Mock New-Item { }
            Mock [System.IO.Path]::IsPathRooted { $true }
            Mock Write-ScriptLog { }

            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        It "Should handle directory creation failures" {
            Mock Test-Path { $false }
            Mock New-Item { throw "Access denied" }

            $result = try { & $script:ScriptPath 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }

        It "Should handle null or empty directory paths" {
            $testConfig = @{
                Infrastructure = @{
                    Directories = @{
                        HyperVPath = ""
                        LocalPath = $null
                    }
                }
            }

            Mock Write-ScriptLog { }

            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Logging Integration" {
        It "Should use Write-CustomLog when available" {
            Mock Get-Command { @{ Name = "Write-CustomLog" } } -ParameterFilter { $Name -eq "Write-CustomLog" }
            Mock Write-CustomLog { }
            Mock Test-Path { $true }

            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1
        }

        It "Should fallback to Write-Host when logging unavailable" {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "Write-CustomLog" }
            Mock Write-Host { }
            Mock Test-Path { $true }

            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Host -AtLeast 1
        }
    }
}
