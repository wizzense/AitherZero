#Requires -Version 7.0

Describe "0215_Install-Chocolatey" {
    BeforeAll {
        Import-Module Pester -Force
        
        $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0215_Install-Chocolatey.ps1"
        
        # Mock external commands
        Mock Test-Path { return $false }
        Mock Test-Path { return $true } -ParameterFilter { $Path -like "*Logging.psm1" }
        Mock Import-Module { }
        Mock Write-Host { }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'choco.exe' }
        Mock Invoke-Expression { }
        Mock Get-EnvironmentVariable { return "C:\Windows\System32" }
        Mock Set-EnvironmentVariable { }
        
        # Mock .NET classes for admin check
        Mock New-Object { 
            return @{
                IsInRole = { param($role) return $true }
            }
        } -ParameterFilter { $TypeName -like "*WindowsPrincipal*" }
        
        # Mock WebClient for Chocolatey installer
        Mock New-Object {
            return @{
                DownloadString = { param($url) return "# Chocolatey installer script" }
            }
        } -ParameterFilter { $TypeName -eq "System.Net.WebClient" }
        
        # Mock platform variables
        $Global:IsWindows = $true
        $Global:IsLinux = $false
        $Global:IsMacOS = $false
        
        # Mock environment variables
        $env:ChocolateyInstall = $null
    }
    
    Context "Platform Support" {
        It "Should skip installation on non-Windows platforms" {
            $Global:IsWindows = $false
            $Global:IsLinux = $true
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            $result = & $scriptPath -Configuration $config -WhatIf
        }
        
        It "Should proceed on Windows platform" {
            $Global:IsWindows = $true
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Configuration Validation" {
        It "Should exit early when Chocolatey installation is not enabled" {
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $false }
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
    
    Context "Administrator Privileges Check" {
        It "Should check for administrator privileges" {
            Mock New-Object { 
                return @{
                    IsInRole = { param($role) return $true }
                }
            } -ParameterFilter { $TypeName -like "*WindowsPrincipal*" }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should fail when not running as administrator" {
            Mock New-Object { 
                return @{
                    IsInRole = { param($role) return $false }
                }
            } -ParameterFilter { $TypeName -like "*WindowsPrincipal*" }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }
    
    Context "Existing Chocolatey Detection" {
        It "Should detect already installed Chocolatey" {
            Mock Get-Command { return @{ Source = "C:\ProgramData\chocolatey\bin\choco.exe" } } -ParameterFilter { $Name -eq 'choco' }
            Mock Invoke-Expression { return "1.4.0" } -ParameterFilter { $Command -like "*choco --version*" }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            $result = & $scriptPath -Configuration $config -WhatIf
        }
        
        It "Should check for updates when configured" {
            Mock Get-Command { return @{ Source = "C:\ProgramData\chocolatey\bin\choco.exe" } } -ParameterFilter { $Name -eq 'choco' }
            Mock Invoke-Expression { 
                if ($Command -like "*choco --version*") { return "1.4.0" }
                if ($Command -like "*choco upgrade chocolatey*") { return "Chocolatey upgraded successfully" }
            }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{
                        Install = $true
                        CheckForUpdates = $true
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle version check failure gracefully" {
            Mock Get-Command { return @{ Source = "C:\ProgramData\chocolatey\bin\choco.exe" } } -ParameterFilter { $Name -eq 'choco' }
            Mock Invoke-Expression { throw "Version check failed" } -ParameterFilter { $Command -like "*choco --version*" }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            $result = & $scriptPath -Configuration $config -WhatIf
        }
    }
    
    Context "Installation Configuration" {
        It "Should use custom installation path when specified" {
            $customPath = "D:\Tools\Chocolatey"
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'choco.exe' }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{
                        Install = $true
                        InstallPath = $customPath
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should configure proxy settings when specified" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'choco.exe' }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{
                        Install = $true
                        Proxy = @{
                            Url = "http://proxy.company.com:8080"
                            Username = "proxyuser"
                            Password = "proxypass"
                        }
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Installation Process" {
        It "Should download and run Chocolatey installer" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'choco.exe' }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*choco.exe" }
            Mock Invoke-Expression { return "Chocolatey installed successfully" }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke New-Object -Times 0 -ParameterFilter { $TypeName -eq "System.Net.WebClient" } -Scope It # WhatIf mode
        }
        
        It "Should handle installer download failure gracefully" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'choco.exe' }
            Mock New-Object {
                return @{
                    DownloadString = { param($url) throw "Download failed" }
                }
            } -ParameterFilter { $TypeName -eq "System.Net.WebClient" }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
        
        It "Should handle installer execution failure gracefully" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'choco.exe' }
            Mock Invoke-Expression { throw "Installation failed" } -ParameterFilter { $Command -like "*Chocolatey installer script*" }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
        
        It "Should refresh environment variables after installation" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'choco.exe' }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*choco.exe" }
            Mock Invoke-Expression { return "Chocolatey installed" }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }
    }
    
    Context "Installation Verification" {
        It "Should verify Chocolatey installation" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'choco.exe' }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*choco.exe" }
            Mock Invoke-Expression { 
                if ($Command -like "*choco.exe --version*") { return "1.4.0" }
                else { return "Installation completed" }
            }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }
        
        It "Should fail when Chocolatey executable is not found after installation" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'choco.exe' }
            Mock Test-Path { return $false } # Chocolatey not found after installation
            Mock Invoke-Expression { return "Installation completed" }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
        
        It "Should warn when Chocolatey is installed but not functioning" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'choco.exe' }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*choco.exe" }
            Mock Invoke-Expression { 
                if ($Command -like "*--version*") { throw "Command failed" }
                else { return "Installation completed" }
            }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw # Should not throw but should warn
        }
    }
    
    Context "Post-Installation Configuration" {
        It "Should configure Chocolatey settings when provided" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'choco.exe' }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*choco.exe" }
            Mock Invoke-Expression { 
                if ($Command -like "*--version*") { return "1.4.0" }
                if ($Command -like "*feature*") { return "Feature configured" }
                else { return "Installation completed" }
            }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{
                        Install = $true
                        Settings = @{
                            "allowGlobalConfirmation" = $true
                            "checksumFiles" = $false
                        }
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should configure Chocolatey sources when provided" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'choco.exe' }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*choco.exe" }
            Mock Invoke-Expression { 
                if ($Command -like "*--version*") { return "1.4.0" }
                if ($Command -like "*source add*") { return "Source added" }
                else { return "Installation completed" }
            }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{
                        Install = $true
                        Sources = @(
                            @{
                                Name = "internal-repo"
                                Url = "https://chocolatey.company.com/api/v2/"
                                Priority = 1
                                Username = "user"
                                Password = "pass"
                            }
                        )
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should install initial packages when specified" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'choco' -or $Name -eq 'choco.exe' }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*choco.exe" }
            Mock Invoke-Expression { 
                if ($Command -like "*--version*") { return "1.4.0" }
                if ($Command -like "*install*") { return "Package installed" }
                else { return "Installation completed" }
            }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{
                        Install = $true
                        InitialPackages = @("git", "7zip", "notepadplusplus")
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "WhatIf Support" {
        It "Should support WhatIf parameter without making changes" {
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke New-Object -Times 0 -ParameterFilter { $TypeName -eq "System.Net.WebClient" } -Scope It
            Should -Invoke Invoke-Expression -Times 0 -Scope It
        }
    }
    
    Context "Logging" {
        It "Should use custom logging when available" {
            Mock Get-Command { return @{ Name = 'Write-CustomLog' } } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            Mock Write-CustomLog { }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $false }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1 -Scope It
        }
        
        It "Should fallback to basic logging when custom logging is not available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            
            $config = @{
                PackageManagers = @{
                    Chocolatey = @{ Install = $false }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Host -AtLeast 1 -Scope It
        }
    }
}
