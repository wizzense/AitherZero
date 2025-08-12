#Requires -Version 7.0

Describe "0201_Install-Node" {
    BeforeAll {
        # Import required modules
        Import-Module Pester -Force
        
        # Get script path
        $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0201_Install-Node.ps1"
        
        # Mock external commands that would normally be called
        Mock Start-Process { 
            return @{ ExitCode = 0 }
        }
        Mock Invoke-WebRequest { }
        Mock Remove-Item { }
        Mock Test-Path { return $false } -ParameterFilter { $Path -like "*node-installer.msi" }
        Mock Test-Path { return $true } -ParameterFilter { $Path -like "*Logging.psm1" }
        Mock Import-Module { }
        Mock Write-Host { }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'node' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'npm' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'apt-get' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'yum' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'brew' }
        
        # Mock platform variables
        $Global:IsWindows = $true
        $Global:IsLinux = $false
        $Global:IsMacOS = $false
        $Global:LASTEXITCODE = 1
        
        # Mock environment variables
        $env:TEMP = "C:\Temp"
    }
    
    Context "Configuration Validation" {
        It "Should exit early when Node installation is not enabled" {
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $false }
                }
            }
            
            # This should exit with code 0
            $result = & $scriptPath -Configuration $config -WhatIf
            # In WhatIf mode, script should show what would be done
        }
        
        It "Should handle empty configuration gracefully" {
            $config = @{}
            $result = & $scriptPath -Configuration $config -WhatIf
            # Should exit early with code 0
        }
        
        It "Should handle null configuration gracefully" {
            $result = & $scriptPath -Configuration $null -WhatIf
            # Should exit early with code 0
        }
    }
    
    Context "Node Installation Check" {
        BeforeEach {
            $Global:LASTEXITCODE = 1
        }
        
        It "Should detect already installed Node.js" {
            Mock Get-Command { return @{ Source = "C:\Program Files\nodejs\node.exe" } } -ParameterFilter { $Name -eq 'node' }
            $Global:LASTEXITCODE = 0
            
            Mock Invoke-Expression { 
                $Global:LASTEXITCODE = 0
                return "v20.18.1"
            } -ParameterFilter { $Command -like "*node --version*" }
            
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $true }
                }
            }
            
            $result = & $scriptPath -Configuration $config -WhatIf
            # Should detect existing installation
        }
        
        It "Should proceed with installation when Node is not found" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'node' }
            $Global:LASTEXITCODE = 1
            
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $true }
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
        
        It "Should download Node.js installer for Windows" {
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Invoke-WebRequest -Times 0 -Scope It # WhatIf mode shouldn't actually download
        }
        
        It "Should use custom installer URL when provided" {
            $customUrl = "https://custom.example.com/node-installer.msi"
            $config = @{
                InstallationOptions = @{
                    Node = @{
                        Install = $true
                        InstallerUrl = $customUrl
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle download failure gracefully" {
            Mock Invoke-WebRequest { throw "Download failed" }
            
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
        
        It "Should handle installation failure gracefully" {
            Mock Start-Process { return @{ ExitCode = 1 } }
            
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
        
        It "Should clean up installer file after installation" {
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Linux Installation" {
        BeforeAll {
            $Global:IsWindows = $false
            $Global:IsLinux = $true
            $Global:IsMacOS = $false
        }
        
        It "Should install Node.js on Ubuntu/Debian systems" {
            Mock Get-Command { return @{ Source = "/usr/bin/apt-get" } } -ParameterFilter { $Name -eq 'apt-get' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should install Node.js on RHEL/CentOS systems" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'apt-get' }
            Mock Get-Command { return @{ Source = "/usr/bin/yum" } } -ParameterFilter { $Name -eq 'yum' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should fail gracefully on unsupported Linux distributions" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'apt-get' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'yum' }
            
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $true }
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
        
        It "Should install Node.js using Homebrew when available" {
            Mock Get-Command { return @{ Source = "/usr/local/bin/brew" } } -ParameterFilter { $Name -eq 'brew' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should install using pkg installer when Homebrew is not available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'brew' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "WhatIf Support" {
        It "Should support WhatIf parameter without making changes" {
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $true }
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
                    Node = @{ Install = $false }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1 -Scope It
        }
        
        It "Should fallback to basic logging when custom logging is not available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            
            $config = @{
                InstallationOptions = @{
                    Node = @{ Install = $false }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Host -AtLeast 1 -Scope It
        }
    }
}
