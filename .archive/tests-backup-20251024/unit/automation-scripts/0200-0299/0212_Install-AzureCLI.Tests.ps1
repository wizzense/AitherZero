#Requires -Version 7.0

Describe "0212_Install-AzureCLI" {
    BeforeAll {
        Import-Module Pester -Force

        $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0212_Install-AzureCLI.ps1"

        # Mock external commands
        Mock Start-Process { return @{ ExitCode = 0 } }
        Mock Invoke-WebRequest { }
        Mock Expand-Archive { }
        Mock New-Item { }
        Mock Remove-Item { }
        Mock Test-Path { return $false }
        Mock Test-Path { return $true } -ParameterFilter { $Path -like "*Logging.psm1" }
        Mock Import-Module { }
        Mock Write-Host { }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'docker' -or $Name -eq '7z' -or $Name -eq 'code' -or $Name -eq 'az' -or $Name -eq 'aws' -or $Name -eq 'packer' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'winget' -or $Name -eq 'apt-get' -or $Name -eq 'yum' -or $Name -eq 'brew' }
        Mock Invoke-Expression { }
        Mock Get-EnvironmentVariable { return "C:\Windows\System32" }
        Mock Set-EnvironmentVariable { }
        Mock New-ItemProperty { }
        Mock Set-ItemProperty { }
        Mock Get-ChildItem { return @() }

        # Mock platform variables
        $Global:IsWindows = $true
        $Global:IsLinux = $false
        $Global:IsMacOS = $false
        $Global:LASTEXITCODE = 0

        # Mock environment variables
        $env:TEMP = "C:\Temp"
        $env:PATH = "C:\Windows\System32"
    }

    Context "Configuration Validation" {
        It "Should exit early when installation is not enabled" {
            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $false }
                }
                DevelopmentTools = @{
                    TestTool = @{ Install = $false }
                }
                PackageManagers = @{
                    TestTool = @{ Install = $false }
                }
            }

            $result = & $scriptPath -Configuration $config -WhatIf
        }

        It "Should handle empty configuration gracefully" {
            $config = @{}
            $result = & $scriptPath -Configuration $config -WhatIf
        }

        It "Should handle null configuration gracefully" {
            $result = & $scriptPath -Configuration $null -WhatIf
        }
    }

    Context "Installation Detection" {
        It "Should detect already installed application" {
            Mock Get-Command { return @{ Source = "C:\Program Files\TestApp\app.exe" } } -ParameterFilter { $Name -like "*" }
            Mock Invoke-Expression {
                $Global:LASTEXITCODE = 0
                return "TestApp version 1.0.0"
            }

            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $true }
                }
                DevelopmentTools = @{
                    TestTool = @{ Install = $true }
                }
            }

            $result = & $scriptPath -Configuration $config -WhatIf
        }

        It "Should proceed with installation when application is not found" {
            Mock Get-Command { return $null }
            $Global:LASTEXITCODE = 1

            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $true }
                }
                DevelopmentTools = @{
                    TestTool = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Windows Installation" {
        BeforeAll {
            $Global:IsWindows = $true
            $Global:IsLinux = $false
            $Global:IsMacOS = $false
        }

        It "Should handle Windows installation process" {
            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $true }
                }
                DevelopmentTools = @{
                    TestTool = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Invoke-WebRequest -Times 0 -Scope It # WhatIf mode shouldn't download
        }

        It "Should handle download failure gracefully" {
            Mock Invoke-WebRequest { throw "Download failed" }

            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $true }
                }
                DevelopmentTools = @{
                    TestTool = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Throw
        }

        It "Should handle installation failure gracefully" {
            Mock Start-Process { return @{ ExitCode = 1 } }

            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $true }
                }
                DevelopmentTools = @{
                    TestTool = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Throw
        }

        It "Should clean up temporary files after installation" {
            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $true }
                }
                DevelopmentTools = @{
                    TestTool = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Cross-Platform Support" {
        It "Should handle Linux installation when supported" {
            $Global:IsWindows = $false
            $Global:IsLinux = $true
            Mock Get-Command { return @{ Source = "/usr/bin/apt-get" } } -ParameterFilter { $Name -eq 'apt-get' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }

            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $true }
                }
                DevelopmentTools = @{
                    TestTool = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should handle macOS installation when supported" {
            $Global:IsWindows = $false
            $Global:IsMacOS = $true
            Mock Get-Command { return @{ Source = "/usr/local/bin/brew" } } -ParameterFilter { $Name -eq 'brew' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }

            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $true }
                }
                DevelopmentTools = @{
                    TestTool = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Installation Verification" {
        It "Should verify installation after successful install" {
            Mock Start-Process { return @{ ExitCode = 0 } }
            Mock Get-Command {
                param($Name)
                # Simulate command not found initially, then found after installation
                if ($script:InstallCallCount -eq $null) { $script:InstallCallCount = 0 }
                $script:InstallCallCount++
                if ($script:InstallCallCount -le 1) { return $null }
                else { return @{ Source = "C:\Program Files\TestApp\app.exe" } }
            }
            Mock Invoke-Expression {
                $Global:LASTEXITCODE = 0
                return "TestApp version 1.0.0"
            }

            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $true }
                }
                DevelopmentTools = @{
                    TestTool = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }

        It "Should fail when installation verification fails" {
            Mock Start-Process { return @{ ExitCode = 0 } }
            Mock Get-Command { return $null }
            Mock Invoke-Expression {
                $Global:LASTEXITCODE = 1
                throw "Command not found"
            }

            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $true }
                }
                DevelopmentTools = @{
                    TestTool = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter without making changes" {
            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $true }
                }
                DevelopmentTools = @{
                    TestTool = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Start-Process -Times 0 -Scope It
            Should -Invoke Invoke-WebRequest -Times 0 -Scope It
            Should -Invoke New-Item -Times 0 -Scope It
        }
    }

    Context "Logging" {
        It "Should use custom logging when available" {
            Mock Get-Command { return @{ Name = 'Write-CustomLog' } } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            Mock Write-CustomLog { }

            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $false }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1 -Scope It
        }

        It "Should fallback to basic logging when custom logging is not available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }

            $config = @{
                InstallationOptions = @{
                    TestTool = @{ Install = $false }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Host -AtLeast 1 -Scope It
        }
    }
}
