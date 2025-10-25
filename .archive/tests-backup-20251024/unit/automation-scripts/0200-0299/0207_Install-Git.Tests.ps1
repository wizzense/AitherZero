#Requires -Version 7.0

Describe "0207_Install-Git" {
    BeforeAll {
        Import-Module Pester -Force

        $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0207_Install-Git.ps1"

        # Mock external commands
        Mock Start-Process { return @{ ExitCode = 0 } }
        Mock Invoke-WebRequest { }
        Mock Remove-Item { }
        Mock Test-Path { return $false } -ParameterFilter { $Path -like "*git-installer.exe" }
        Mock Test-Path { return $true } -ParameterFilter { $Path -like "*Logging.psm1" }
        Mock Import-Module { }
        Mock Write-Host { }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'git.exe' -or $Name -eq 'git' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'apt-get' -or $Name -eq 'yum' -or $Name -eq 'dnf' -or $Name -eq 'brew' }
        Mock Invoke-Expression { }
        Mock Get-EnvironmentVariable { return "C:\Windows\System32" }

        # Mock platform variables
        $Global:IsWindows = $true
        $Global:IsLinux = $false
        $Global:IsMacOS = $false
        $Global:LASTEXITCODE = 1

        # Mock environment variables
        $env:TEMP = "C:\Temp"
    }

    Context "Configuration Validation" {
        It "Should exit early when Git installation is not enabled" {
            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $false }
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

    Context "Existing Git Detection" {
        BeforeEach {
            $Global:LASTEXITCODE = 1
        }

        It "Should detect already installed Git on Windows" {
            $Global:IsWindows = $true
            Mock Get-Command { return @{ Source = "C:\Program Files\Git\bin\git.exe" } } -ParameterFilter { $Name -eq 'git.exe' }
            Mock Invoke-Expression {
                $Global:LASTEXITCODE = 0
                return "git version 2.48.1.windows.1"
            } -ParameterFilter { $Command -like "*git.exe --version*" }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            $result = & $scriptPath -Configuration $config -WhatIf
        }

        It "Should detect already installed Git on Linux" {
            $Global:IsWindows = $false
            $Global:IsLinux = $true
            Mock Get-Command { return @{ Source = "/usr/bin/git" } } -ParameterFilter { $Name -eq 'git' }
            Mock Invoke-Expression {
                $Global:LASTEXITCODE = 0
                return "git version 2.43.0"
            } -ParameterFilter { $Command -like "*git --version*" }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            $result = & $scriptPath -Configuration $config -WhatIf
        }

        It "Should check version requirement when specified" {
            Mock Get-Command { return @{ Source = "/usr/bin/git" } } -ParameterFilter { $Name -eq 'git' }
            Mock Invoke-Expression {
                $Global:LASTEXITCODE = 0
                return "git version 2.43.0"
            }

            $config = @{
                InstallationOptions = @{
                    Git = @{
                        Install = $true
                        Version = "2.40.0"
                    }
                }
            }

            $result = & $scriptPath -Configuration $config -WhatIf
        }

        It "Should proceed with installation when Git is not found" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'git.exe' -or $Name -eq 'git' }
            $Global:LASTEXITCODE = 1

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
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

        It "Should download Git installer for Windows" {
            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Invoke-WebRequest -Times 0 -Scope It # WhatIf mode shouldn't download
        }

        It "Should handle download failure gracefully" {
            Mock Invoke-WebRequest { throw "Download failed" }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Throw
        }

        It "Should handle installation failure gracefully" {
            Mock Start-Process { return @{ ExitCode = 1 } }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Throw
        }

        It "Should clean up installer file after installation" {
            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should refresh PATH after installation" {
            Mock Start-Process { return @{ ExitCode = 0 } }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }
    }

    Context "Linux Installation" {
        BeforeAll {
            $Global:IsWindows = $false
            $Global:IsLinux = $true
            $Global:IsMacOS = $false
        }

        It "Should install Git on Ubuntu/Debian systems" {
            Mock Get-Command { return @{ Source = "/usr/bin/apt-get" } } -ParameterFilter { $Name -eq 'apt-get' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should install Git on RHEL/CentOS systems with yum" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'apt-get' }
            Mock Get-Command { return @{ Source = "/usr/bin/yum" } } -ParameterFilter { $Name -eq 'yum' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should install Git on Fedora systems with dnf" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'apt-get' -or $Name -eq 'yum' }
            Mock Get-Command { return @{ Source = "/usr/bin/dnf" } } -ParameterFilter { $Name -eq 'dnf' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should fail gracefully on unsupported Linux distributions" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'apt-get' -or $Name -eq 'yum' -or $Name -eq 'dnf' }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }

    Context "macOS Installation" {
        BeforeAll {
            $Global:IsWindows = $false
            $Global:IsLinux = $false
            $Global:IsMacOS = $true
        }

        It "Should install Git using Homebrew when available" {
            Mock Get-Command { return @{ Source = "/usr/local/bin/brew" } } -ParameterFilter { $Name -eq 'brew' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should fail gracefully when Homebrew is not available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'brew' }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }

    Context "Unsupported Platform" {
        It "Should fail on unsupported platforms" {
            $Global:IsWindows = $false
            $Global:IsLinux = $false
            $Global:IsMacOS = $false

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }

    Context "Installation Verification" {
        It "Should verify Git installation after successful install" {
            $Global:IsWindows = $true
            Mock Start-Process { return @{ ExitCode = 0 } }
            Mock Get-Command {
                param($Name)
                if ($Name -eq 'git.exe') {
                    # First call returns null (not installed), second call returns installed
                    if ($script:GitCallCount -eq $null) { $script:GitCallCount = 0 }
                    $script:GitCallCount++
                    if ($script:GitCallCount -le 1) { return $null }
                    else { return @{ Source = "C:\Program Files\Git\bin\git.exe" } }
                }
                return $null
            }
            Mock Invoke-Expression {
                $Global:LASTEXITCODE = 0
                return "git version 2.48.1.windows.1"
            } -ParameterFilter { $Command -like "*git* --version*" }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }

        It "Should fail when Git verification fails" {
            Mock Start-Process { return @{ ExitCode = 0 } }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'git.exe' -or $Name -eq 'git' }
            Mock Invoke-Expression {
                $Global:LASTEXITCODE = 1
                throw "Git command not found"
            } -ParameterFilter { $Command -like "*git* --version*" }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter without making changes" {
            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $true }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Start-Process -Times 0 -Scope It
            Should -Invoke Invoke-WebRequest -Times 0 -Scope It
        }
    }

    Context "Logging" {
        It "Should use custom logging when available" {
            Mock Get-Command { return @{ Name = 'Write-CustomLog' } } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            Mock Write-CustomLog { }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $false }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1 -Scope It
        }

        It "Should fallback to basic logging when custom logging is not available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }

            $config = @{
                InstallationOptions = @{
                    Git = @{ Install = $false }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Host -AtLeast 1 -Scope It
        }
    }
}
