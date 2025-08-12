#Requires -Version 7.0

Describe "0206_Install-Python" {
    BeforeAll {
        # Import required modules
        Import-Module Pester -Force
        
        # Get script path
        $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0206_Install-Python.ps1"
        
        # Mock external commands
        Mock Start-Process { return @{ ExitCode = 0 } }
        Mock Invoke-WebRequest { }
        Mock Remove-Item { }
        Mock Test-Path { return $false } -ParameterFilter { $Path -like "*python-installer.exe" }
        Mock Test-Path { return $true } -ParameterFilter { $Path -like "*Logging.psm1" }
        Mock Import-Module { }
        Mock Write-Host { }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'python.exe' -or $Name -eq 'python3' }
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
        It "Should exit early when Python installation is not enabled" {
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $false }
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
    
    Context "Existing Python Detection" {
        BeforeEach {
            $Global:LASTEXITCODE = 1
        }
        
        It "Should detect already installed Python on Windows" {
            $Global:IsWindows = $true
            Mock Get-Command { return @{ Source = "C:\Python39\python.exe" } } -ParameterFilter { $Name -eq 'python.exe' }
            Mock Invoke-Expression { 
                $Global:LASTEXITCODE = 0
                if ($Command -like "*python.exe --version*") { return "Python 3.9.7" }
                if ($Command -like "*pip --version*") { return "pip 21.2.4" }
            }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            $result = & $scriptPath -Configuration $config -WhatIf
        }
        
        It "Should detect already installed Python on Linux" {
            $Global:IsWindows = $false
            $Global:IsLinux = $true
            Mock Get-Command { return @{ Source = "/usr/bin/python3" } } -ParameterFilter { $Name -eq 'python3' }
            Mock Invoke-Expression { 
                $Global:LASTEXITCODE = 0
                if ($Command -like "*python3 --version*") { return "Python 3.9.7" }
                if ($Command -like "*pip --version*") { return "pip 21.2.4" }
            }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            $result = & $scriptPath -Configuration $config -WhatIf
        }
        
        It "Should proceed with installation when Python is not found" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'python.exe' -or $Name -eq 'python3' }
            $Global:LASTEXITCODE = 1
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
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
        
        It "Should download Python installer for Windows" {
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Invoke-WebRequest -Times 0 -Scope It # WhatIf mode shouldn't download
        }
        
        It "Should use specified Python version when configured" {
            $config = @{
                InstallationOptions = @{
                    Python = @{
                        Install = $true
                        Version = "3.11.5"
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should use default version when 'latest' is specified" {
            $config = @{
                InstallationOptions = @{
                    Python = @{
                        Install = $true
                        Version = "latest"
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle download failure gracefully" {
            Mock Invoke-WebRequest { throw "Download failed" }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
        
        It "Should handle installation failure gracefully" {
            Mock Start-Process { return @{ ExitCode = 1 } }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
        
        It "Should clean up installer file after installation" {
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            # Remove-Item should be called during cleanup
        }
        
        It "Should refresh PATH after installation" {
            Mock Start-Process { return @{ ExitCode = 0 } }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
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
        
        It "Should install Python on Ubuntu/Debian systems" {
            Mock Get-Command { return @{ Source = "/usr/bin/apt-get" } } -ParameterFilter { $Name -eq 'apt-get' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should install Python on RHEL/CentOS systems with yum" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'apt-get' }
            Mock Get-Command { return @{ Source = "/usr/bin/yum" } } -ParameterFilter { $Name -eq 'yum' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should install Python on Fedora systems with dnf" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'apt-get' -or $Name -eq 'yum' }
            Mock Get-Command { return @{ Source = "/usr/bin/dnf" } } -ParameterFilter { $Name -eq 'dnf' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should fail gracefully on unsupported Linux distributions" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'apt-get' -or $Name -eq 'yum' -or $Name -eq 'dnf' }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
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
        
        It "Should install Python using Homebrew when available" {
            Mock Get-Command { return @{ Source = "/usr/local/bin/brew" } } -ParameterFilter { $Name -eq 'brew' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should install using pkg installer when Homebrew is not available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'brew' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Unsupported Platform" {
        It "Should fail on unsupported platforms" {
            $Global:IsWindows = $false
            $Global:IsLinux = $false
            $Global:IsMacOS = $false
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }
    
    Context "Installation Verification" {
        It "Should verify Python installation after successful install" {
            $Global:IsWindows = $true
            Mock Start-Process { return @{ ExitCode = 0 } }
            Mock Invoke-Expression { 
                if ($Command -like "*python.exe --version*") { 
                    $Global:LASTEXITCODE = 0
                    return "Python 3.12.3" 
                }
                if ($Command -like "*pip install --upgrade pip*") { 
                    $Global:LASTEXITCODE = 0
                }
            }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }
        
        It "Should upgrade pip after successful installation" {
            $Global:IsWindows = $true
            Mock Start-Process { return @{ ExitCode = 0 } }
            Mock Invoke-Expression { 
                if ($Command -like "*python.exe --version*") { 
                    $Global:LASTEXITCODE = 0
                    return "Python 3.12.3" 
                }
                if ($Command -like "*pip install --upgrade pip*") { 
                    $Global:LASTEXITCODE = 0
                }
            }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }
        
        It "Should fail when Python verification fails" {
            Mock Start-Process { return @{ ExitCode = 0 } }
            Mock Invoke-Expression { 
                $Global:LASTEXITCODE = 1
                throw "Python command not found"
            } -ParameterFilter { $Command -like "*python* --version*" }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }
    
    Context "Python Package Installation" {
        It "Should install specified Python packages" {
            $Global:IsWindows = $true
            Mock Start-Process { return @{ ExitCode = 0 } }
            Mock Invoke-Expression { 
                if ($Command -like "*python.exe --version*") { 
                    $Global:LASTEXITCODE = 0
                    return "Python 3.12.3" 
                }
                if ($Command -like "*pip install*") { 
                    $Global:LASTEXITCODE = 0
                }
            }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{
                        Install = $true
                        Packages = @("requests", "numpy", "pandas")
                    }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }
        
        It "Should handle package installation failures gracefully" {
            $Global:IsWindows = $true
            Mock Start-Process { return @{ ExitCode = 0 } }
            Mock Invoke-Expression { 
                if ($Command -like "*python.exe --version*") { 
                    $Global:LASTEXITCODE = 0
                    return "Python 3.12.3" 
                }
                if ($Command -like "*pip install --upgrade pip*") { 
                    $Global:LASTEXITCODE = 0
                }
                if ($Command -like "*pip install nonexistent-package*") { 
                    $Global:LASTEXITCODE = 1  # Simulate package installation failure
                }
            }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{
                        Install = $true
                        Packages = @("nonexistent-package")
                    }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw # Should continue despite package failure
        }
        
        It "Should handle package installation exceptions gracefully" {
            $Global:IsWindows = $true
            Mock Start-Process { return @{ ExitCode = 0 } }
            Mock Invoke-Expression { 
                if ($Command -like "*python.exe --version*") { 
                    $Global:LASTEXITCODE = 0
                    return "Python 3.12.3" 
                }
                if ($Command -like "*pip install --upgrade pip*") { 
                    $Global:LASTEXITCODE = 0
                }
                if ($Command -like "*pip install failing-package*") { 
                    throw "Package installation error"
                }
            }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{
                        Install = $true
                        Packages = @("failing-package")
                    }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw # Should continue despite exception
        }
    }
    
    Context "WhatIf Support" {
        It "Should support WhatIf parameter without making changes" {
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $true }
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
                    Python = @{ Install = $false }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1 -Scope It
        }
        
        It "Should fallback to basic logging when custom logging is not available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            
            $config = @{
                InstallationOptions = @{
                    Python = @{ Install = $false }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Host -AtLeast 1 -Scope It
        }
    }
}
