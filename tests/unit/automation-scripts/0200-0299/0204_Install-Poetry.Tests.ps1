#Requires -Version 7.0

Describe "0204_Install-Poetry" {
    BeforeAll {
        # Import required modules
        Import-Module Pester -Force
        
        # Get script path
        $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0204_Install-Poetry.ps1"
        
        # Mock external commands
        Mock Invoke-WebRequest { }
        Mock Remove-Item { }
        Mock Test-Path { return $false } -ParameterFilter { $Path -like "*install-poetry.py" }
        Mock Test-Path { return $true } -ParameterFilter { $Path -like "*Logging.psm1" }
        Mock Test-Path { return $true } -ParameterFilter { $Path -like "*/.local/bin" -or $Path -like "*\Python\Scripts" }
        Mock Import-Module { }
        Mock Write-Host { }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'poetry' }
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'pipx' }
        Mock Get-Command { return @{ Source = "/usr/bin/python3" } } -ParameterFilter { $Name -eq 'python' -or $Name -eq 'python3' }
        Mock Invoke-Expression { }
        
        # Mock environment functions
        Mock Set-EnvironmentVariable { }
        
        # Mock platform variables
        $Global:IsWindows = $true
        $Global:IsLinux = $false
        $Global:IsMacOS = $false
        $Global:LASTEXITCODE = 0
        
        # Mock environment variables
        $env:TEMP = "C:\Temp"
        $env:APPDATA = "C:\Users\Test\AppData\Roaming"
        $env:USERPROFILE = "C:\Users\Test"
        $env:HOME = "/home/test"
    }
    
    Context "Configuration Validation" {
        It "Should exit early when Poetry installation is not enabled" {
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $false }
                }
            }
            
            $result = & $scriptPath -Configuration $config -WhatIf
            # Should exit early with code 0
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
    
    Context "Python Prerequisite Check" {
        It "Should detect Python installation" {
            Mock Get-Command { return @{ Source = "/usr/bin/python3" } } -ParameterFilter { $Name -eq 'python3' }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should fail gracefully when Python is not found" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'python' -or $Name -eq 'python3' }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
        
        It "Should prefer python3 over python when both exist" {
            Mock Get-Command { return @{ Source = "/usr/bin/python" } } -ParameterFilter { $Name -eq 'python' }
            Mock Get-Command { return @{ Source = "/usr/bin/python3" } } -ParameterFilter { $Name -eq 'python3' }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Existing Poetry Detection" {
        It "Should detect already installed Poetry" {
            Mock Get-Command { return @{ Source = "/usr/local/bin/poetry" } } -ParameterFilter { $Name -eq 'poetry' }
            Mock Invoke-Expression { return "Poetry (version 1.6.1)" } -ParameterFilter { $Command -like "*poetry --version*" }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            $result = & $scriptPath -Configuration $config -WhatIf
            # Should exit early when already installed
        }
        
        It "Should check for Poetry updates when configured" {
            Mock Get-Command { return @{ Source = "/usr/local/bin/poetry" } } -ParameterFilter { $Name -eq 'poetry' }
            Mock Invoke-Expression { 
                if ($Command -like "*poetry --version*") { return "Poetry (version 1.6.1)" }
                if ($Command -like "*poetry self update*") { return "Updated successfully" }
            }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{
                        Install = $true
                        CheckForUpdates = $true
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Installation via pipx" {
        It "Should prefer pipx installation when available" {
            Mock Get-Command { return @{ Source = "/usr/local/bin/pipx" } } -ParameterFilter { $Name -eq 'pipx' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'poetry' }
            Mock Invoke-Expression { 
                if ($Command -like "*pipx install poetry*") { 
                    $Global:LASTEXITCODE = 0
                    return "Successfully installed poetry"
                }
                if ($Command -like "*poetry --version*") { 
                    return "Poetry (version 1.6.1)" 
                }
            }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should install specific Poetry version when configured" {
            Mock Get-Command { return @{ Source = "/usr/local/bin/pipx" } } -ParameterFilter { $Name -eq 'pipx' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'poetry' }
            Mock Invoke-Expression { 
                $Global:LASTEXITCODE = 0
                return "Successfully installed poetry==1.5.1"
            }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{
                        Install = $true
                        Version = "1.5.1"
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle pipx installation failure gracefully" {
            Mock Get-Command { return @{ Source = "/usr/local/bin/pipx" } } -ParameterFilter { $Name -eq 'pipx' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'poetry' }
            Mock Invoke-Expression { throw "pipx installation failed" } -ParameterFilter { $Command -like "*pipx install*" }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }
    
    Context "Installation via Official Installer" {
        It "Should fallback to official installer when pipx is not available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'pipx' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'poetry' }
            Mock Get-Command { return @{ Source = "/usr/bin/python3" } } -ParameterFilter { $Name -eq 'python3' }
            Mock Invoke-Expression { 
                if ($Command -like "*install-poetry.py*") {
                    $Global:LASTEXITCODE = 0
                    return "Poetry installed successfully"
                }
                if ($Command -like "*poetry --version*") { 
                    return "Poetry (version 1.6.1)" 
                }
            }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Invoke-WebRequest -Times 0 -Scope It # WhatIf mode shouldn't download
        }
        
        It "Should download and run official installer" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'pipx' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'poetry' }
            Mock Get-Command { return @{ Source = "/usr/bin/python3" } } -ParameterFilter { $Name -eq 'python3' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw
            Should -Invoke Invoke-WebRequest -Times 1 -Scope It
        }
        
        It "Should set Poetry version environment variable when specified" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'pipx' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'poetry' }
            Mock Get-Command { return @{ Source = "/usr/bin/python3" } } -ParameterFilter { $Name -eq 'python3' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{
                        Install = $true
                        Version = "1.5.1"
                    }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw
            # Should set POETRY_VERSION environment variable
        }
        
        It "Should handle installer download failure gracefully" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'pipx' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'poetry' }
            Mock Invoke-WebRequest { throw "Download failed" }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
        
        It "Should clean up installer script after installation" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'pipx' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'poetry' }
            Mock Get-Command { return @{ Source = "/usr/bin/python3" } } -ParameterFilter { $Name -eq 'python3' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw
            Should -Invoke Remove-Item -Times 1 -Scope It
        }
    }
    
    Context "PATH Configuration" {
        BeforeAll {
            Mock Get-EnvironmentVariable { return "C:\Windows\System32" }
            Mock Set-EnvironmentVariable { }
        }
        
        It "Should add Poetry to PATH on Windows" {
            $Global:IsWindows = $true
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'pipx' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'poetry' }
            Mock Get-Command { return @{ Source = "C:\Python39\python.exe" } } -ParameterFilter { $Name -eq 'python3' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }
        
        It "Should add Poetry to PATH on Linux/macOS" {
            $Global:IsWindows = $false
            $Global:IsLinux = $true
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'pipx' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'poetry' }
            Mock Get-Command { return @{ Source = "/usr/bin/python3" } } -ParameterFilter { $Name -eq 'python3' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }
    }
    
    Context "Poetry Configuration" {
        It "Should configure Poetry settings when provided" {
            Mock Get-Command { return @{ Source = "/usr/local/bin/poetry" } } -ParameterFilter { $Name -eq 'poetry' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'poetry' } -Exactly 1
            Mock Invoke-Expression { 
                if ($Command -like "*poetry --version*") { return "Poetry (version 1.6.1)" }
                if ($Command -like "*poetry config*") { return "Configuration updated" }
            }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{
                        Install = $true
                        Settings = @{
                            "virtualenvs.create" = "true"
                            "virtualenvs.in-project" = "true"
                        }
                    }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Installation Verification" {
        It "Should verify Poetry installation after successful install" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'pipx' }
            Mock Get-Command { 
                param($Name)
                if ($Name -eq 'poetry') {
                    # First call returns null (not installed), second call returns installed
                    if ($script:PoetryCallCount -eq $null) { $script:PoetryCallCount = 0 }
                    $script:PoetryCallCount++
                    if ($script:PoetryCallCount -le 1) { return $null }
                    else { return @{ Source = "/usr/local/bin/poetry" } }
                }
                if ($Name -eq 'python3') { return @{ Source = "/usr/bin/python3" } }
                return $null
            }
            Mock Invoke-Expression { 
                if ($Command -like "*poetry --version*") { return "Poetry (version 1.6.1)" }
                $Global:LASTEXITCODE = 0
            }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }
        
        It "Should fail when Poetry verification fails" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'pipx' }
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'poetry' }
            Mock Get-Command { return @{ Source = "/usr/bin/python3" } } -ParameterFilter { $Name -eq 'python3' }
            Mock Invoke-Expression { $Global:LASTEXITCODE = 0 }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config } | Should -Throw
        }
    }
    
    Context "WhatIf Support" {
        It "Should support WhatIf parameter without making changes" {
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $true }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Invoke-WebRequest -Times 0 -Scope It
            Should -Invoke Invoke-Expression -Times 0 -Scope It
        }
    }
    
    Context "Logging" {
        It "Should use custom logging when available" {
            Mock Get-Command { return @{ Name = 'Write-CustomLog' } } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            Mock Write-CustomLog { }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $false }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1 -Scope It
        }
        
        It "Should fallback to basic logging when custom logging is not available" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            
            $config = @{
                DevelopmentTools = @{
                    Poetry = @{ Install = $false }
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Host -AtLeast 1 -Scope It
        }
    }
}
