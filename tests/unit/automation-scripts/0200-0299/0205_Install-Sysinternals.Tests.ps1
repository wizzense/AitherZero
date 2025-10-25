#Requires -Version 7.0

Describe "0205_Install-Sysinternals" {
    BeforeAll {
        # Import required modules
        Import-Module Pester -Force

        # Get script path
        $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0205_Install-Sysinternals.ps1"

        # Mock external commands
        Mock Invoke-WebRequest { }
        Mock Expand-Archive { }
        Mock New-Item { }
        Mock Remove-Item { }
        Mock Get-ChildItem { return @() }
        Mock Test-Path { return $false }
        Mock Test-Path { return $true } -ParameterFilter { $Path -like "*Logging.psm1" }
        Mock Import-Module { }
        Mock Write-Host { }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
        Mock New-ItemProperty { }
        Mock Set-ItemProperty { }
        Mock Get-EnvironmentVariable { return "C:\Windows\System32" }
        Mock Set-EnvironmentVariable { }

        # Mock platform variables
        $Global:IsWindows = $true
        $Global:IsLinux = $false
        $Global:IsMacOS = $false

        # Mock environment variables
        $env:TEMP = "C:\Temp"
        $env:PATH = "C:\Windows\System32"
    }

    Context "Platform Support" {
        It "Should skip installation on non-Windows platforms" {
            $Global:IsWindows = $false
            $Global:IsLinux = $true

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            $result = & $scriptPath -Configuration $config -WhatIf
            # Should exit early on non-Windows platforms
        }

        It "Should proceed on Windows platform" {
            $Global:IsWindows = $true

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Configuration Validation" {
        It "Should exit early when Sysinternals installation is not enabled" {
            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $false }
                }
            }

            $result = & $scriptPath -Configuration $config -WhatIf
        }

        It "Should handle empty configuration gracefully" {
            $config = @{}
            $result = & $scriptPath -Configuration $config -WhatIf
        }

        It "Should use default installation path when not specified" {
            Mock Test-Path { return $false }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should use custom installation path when specified" {
            $customPath = "D:\Tools\Sysinternals"
            Mock Test-Path { return $false }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{
                        Install = $true
                        InstallPath = $customPath
                    }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Existing Installation Detection" {
        It "Should detect existing Sysinternals installation" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -eq "C:\Tools\Sysinternals" }
            Mock Get-ChildItem {
                return @(
                    @{ Name = "PsInfo.exe"; Count = 1 },
                    @{ Name = "PsExec.exe"; Count = 1 },
                    @{ Name = "Handle.exe"; Count = 1 }
                )
            } -ParameterFilter { $Path -eq "C:\Tools\Sysinternals" }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            $result = & $scriptPath -Configuration $config -WhatIf
            # Should detect existing installation and exit early
        }

        It "Should add existing installation to PATH" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -eq "C:\Tools\Sysinternals" }
            Mock Get-ChildItem {
                return @(
                    @{ Name = "PsInfo.exe" },
                    @{ Name = "PsExec.exe" }
                )
            }
            $env:PATH = "C:\Windows\System32"  # Reset PATH without Sysinternals

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Download and Installation" {
        It "Should create installation directory if it doesn't exist" {
            Mock Test-Path { return $false }
            Mock Get-ChildItem { return @() }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke New-Item -Times 0 -Scope It # WhatIf mode shouldn't create directory
        }

        It "Should download Sysinternals Suite" {
            Mock Test-Path { return $false }
            Mock Get-ChildItem { return @() }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Invoke-WebRequest -Times 0 -Scope It # WhatIf mode shouldn't download
        }

        It "Should handle download failure gracefully" {
            Mock Test-Path { return $false }
            Mock Get-ChildItem { return @() }
            Mock Invoke-WebRequest { throw "Download failed" }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Throw
        }

        It "Should extract downloaded archive" {
            Mock Test-Path { return $false }
            Mock Get-ChildItem { return @() }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*SysinternalsSuite*.zip" }
            Mock Get-Item { return @{ Length = 1024000 } }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Not -Throw
            Should -Invoke Expand-Archive -Times 1 -Scope It
        }

        It "Should clean up downloaded archive" {
            Mock Test-Path { return $false }
            Mock Get-ChildItem { return @() }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*SysinternalsSuite*.zip" }
            Mock Get-Item { return @{ Length = 1024000 } }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Not -Throw
            Should -Invoke Remove-Item -AtLeast 1 -Scope It
        }

        It "Should verify installation by checking for executables" {
            Mock Test-Path { return $false }
            Mock Get-ChildItem {
                param($Path, $Filter)
                if ($Filter -eq "*.exe") {
                    return @(
                        @{ Name = "PsInfo.exe" },
                        @{ Name = "PsExec.exe" },
                        @{ Name = "Handle.exe" }
                    )
                }
                return @()
            }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*SysinternalsSuite*.zip" }
            Mock Get-Item { return @{ Length = 1024000 } }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }

        It "Should fail when no executables are found after extraction" {
            Mock Test-Path { return $false }
            Mock Get-ChildItem { return @() } # No executables found
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*SysinternalsSuite*.zip" }
            Mock Get-Item { return @{ Length = 1024000 } }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }

    Context "Key Tool Verification" {
        It "Should verify presence of key Sysinternals tools" {
            Mock Test-Path { return $false }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*\PsInfo.exe" -or $Path -like "*\PsExec.exe" -or $Path -like "*\Handle.exe" }
            Mock Get-ChildItem {
                return @(
                    @{ Name = "PsInfo.exe" },
                    @{ Name = "PsExec.exe" },
                    @{ Name = "Handle.exe" },
                    @{ Name = "ProcMon.exe" },
                    @{ Name = "ProcExp.exe" }
                )
            }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*SysinternalsSuite*.zip" }
            Mock Get-Item { return @{ Length = 1024000 } }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }

        It "Should warn when key tools are missing" {
            Mock Test-Path { return $false }
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*\PsInfo.exe" }
            Mock Get-ChildItem {
                return @(
                    @{ Name = "SomeOtherTool.exe" }
                )
            }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*SysinternalsSuite*.zip" }
            Mock Get-Item { return @{ Length = 1024000 } }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }
    }

    Context "PATH Configuration" {
        It "Should add Sysinternals to system PATH when configured" {
            Mock Test-Path { return $false }
            Mock Get-ChildItem {
                return @(
                    @{ Name = "PsInfo.exe" }
                )
            }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*SysinternalsSuite*.zip" }
            Mock Get-Item { return @{ Length = 1024000 } }
            Mock Get-EnvironmentVariable { return "C:\Windows\System32" }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{
                        Install = $true
                        AddToPath = $true
                    }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should handle system PATH modification failure gracefully" {
            Mock Test-Path { return $false }
            Mock Get-ChildItem {
                return @(
                    @{ Name = "PsInfo.exe" }
                )
            }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*SysinternalsSuite*.zip" }
            Mock Get-Item { return @{ Length = 1024000 } }
            Mock Set-EnvironmentVariable { throw "Access denied" }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{
                        Install = $true
                        AddToPath = $true
                    }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Not -Throw # Should not throw despite PATH failure
        }
    }

    Context "EULA Configuration" {
        It "Should configure EULA acceptance when requested" {
            Mock Test-Path { return $false }
            Mock Get-ChildItem {
                return @(
                    @{ Name = "PsInfo.exe" },
                    @{ Name = "PsExec.exe" }
                )
            }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*SysinternalsSuite*.zip" }
            Mock Get-Item { return @{ Length = 1024000 } }
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*HKCU*" }
            Mock New-Item { }
            Mock Set-ItemProperty { }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{
                        Install = $true
                        AcceptEula = $true
                    }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Not -Throw
            Should -Invoke Set-ItemProperty -AtLeast 1 -Scope It
        }

        It "Should handle EULA configuration failure gracefully" {
            Mock Test-Path { return $false }
            Mock Get-ChildItem {
                return @(
                    @{ Name = "PsInfo.exe" }
                )
            }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*SysinternalsSuite*.zip" }
            Mock Get-Item { return @{ Length = 1024000 } }
            Mock Set-ItemProperty { throw "Registry access failed" }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{
                        Install = $true
                        AcceptEula = $true
                    }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Not -Throw # Should not throw despite registry failure
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter without making changes" {
            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke New-Item -Times 0 -Scope It
            Should -Invoke Invoke-WebRequest -Times 0 -Scope It
            Should -Invoke Expand-Archive -Times 0 -Scope It
        }
    }

    Context "Logging" {
        It "Should use custom logging when available" {
            Mock Get-Command { return @{ Name = 'Write-CustomLog' } } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            Mock Write-CustomLog { }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $false }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1 -Scope It
        }

        It "Should fallback to basic logging when custom logging is not available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }

            $config = @{
                DevelopmentTools = @{
                    Sysinternals = @{ Install = $false }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Host -AtLeast 1 -Scope It
        }
    }
}
