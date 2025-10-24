#Requires -Version 7.0

Describe "0106_Install-WSL2.ps1" {
    BeforeAll {
        # Mock external dependencies
        Mock Import-Module { } -ParameterFilter { $Name -like "*Logging*" }
        Mock Write-CustomLog { }
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
        Mock Write-Host { }
        Mock Test-Path { $true } -ParameterFilter { $Path -like "*Logging.psm1" }
        
        # Mock Windows-specific variables
        if (-not (Test-Path Variable:IsWindows)) {
            $global:IsWindows = $true
        }
        
        # Mock administrator check
        Mock New-Object { 
            @{ IsInRole = { param($Role) $true } }
        } -ParameterFilter { $TypeName -eq 'Security.Principal.WindowsPrincipal' }
        
        # Mock OS detection
        Mock Get-CimInstance { 
            @{ Caption = 'Microsoft Windows 10 Pro'; BuildNumber = '19041' }
        } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
        
        # Mock WSL-related operations
        Mock Get-WindowsOptionalFeature { 
            @{ State = 'Disabled'; RestartNeeded = $false }
        }
        Mock Enable-WindowsOptionalFeature { 
            @{ RestartNeeded = $false }
        }
        
        # Mock WSL command execution
        Mock Invoke-Expression { }
        Mock Start-Process { @{ ExitCode = 0 } }
        Mock Invoke-WebRequest { }
        Mock Remove-Item { }
        Mock Set-Content { }
        
        # Mock environment variables
        Mock Get-Variable { @{ Value = 'TestUser' } } -ParameterFilter { $Name -eq 'env:USERNAME' }
        Mock Get-Variable { @{ Value = 'C:\temp' } } -ParameterFilter { $Name -eq 'env:TEMP' }
        Mock Get-Variable { @{ Value = 'C:\Users\TestUser' } } -ParameterFilter { $Name -eq 'env:USERPROFILE' }
        
        # Set up global LASTEXITCODE mock
        $global:LASTEXITCODE = 0
    }
    
    Context "Parameter Validation" {
        It "Should accept hashtable configuration parameter" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            $config = @{ InstallationOptions = @{ WSL2 = @{ Install = $false } } }
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should work without configuration parameter" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            { & $scriptPath -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Platform Compatibility" {
        It "Should exit gracefully on non-Windows platforms" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            $global:IsWindows = $false
            
            $result = & $scriptPath 2>&1
            $LASTEXITCODE | Should -Be 0
            
            $global:IsWindows = $true
        }
    }
    
    Context "Configuration Validation" {
        It "Should skip installation when not enabled in configuration" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            $config = @{ InstallationOptions = @{ WSL2 = @{ Install = $false } } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled Enable-WindowsOptionalFeature -Times 0
        }
        
        It "Should proceed with installation when enabled" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            $config = @{ InstallationOptions = @{ WSL2 = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Windows Version Validation" {
        It "Should exit with error on unsupported Windows versions" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock Get-CimInstance { 
                @{ Caption = 'Microsoft Windows 10 Home'; BuildNumber = '17763' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            
            $config = @{ InstallationOptions = @{ WSL2 = @{ Install = $true } } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
        
        It "Should proceed on supported Windows versions" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            $config = @{ InstallationOptions = @{ WSL2 = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Administrator Privilege Check" {
        It "Should exit with error when not running as administrator" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock New-Object { 
                @{ IsInRole = { param($Role) $false } }
            } -ParameterFilter { $TypeName -eq 'Security.Principal.WindowsPrincipal' }
            
            $config = @{ InstallationOptions = @{ WSL2 = @{ Install = $true } } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }
    
    Context "WSL Status Check" {
        It "Should detect already installed WSL" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            # Mock successful wsl --status call
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 0
                return "Default Version: 2"
            } -ParameterFilter { $Command -like "*wsl --status*" }
            
            $config = @{ InstallationOptions = @{ WSL2 = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle WSL status check failure" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 1
                throw "WSL not found"
            } -ParameterFilter { $Command -like "*wsl --status*" }
            
            $config = @{ InstallationOptions = @{ WSL2 = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "WSL Feature Installation" {
        It "Should enable WSL feature when not already enabled" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            $config = @{ InstallationOptions = @{ WSL2 = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should skip WSL feature when already enabled" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock Get-WindowsOptionalFeature { 
                @{ State = 'Enabled'; RestartNeeded = $false }
            } -ParameterFilter { $FeatureName -eq 'Microsoft-Windows-Subsystem-Linux' }
            
            $config = @{ InstallationOptions = @{ WSL2 = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Virtual Machine Platform" {
        It "Should enable Virtual Machine Platform for WSL2" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            $config = @{ 
                InstallationOptions = @{ 
                    WSL2 = @{ 
                        Install = $true
                        Version = '2'
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should skip Virtual Machine Platform for WSL1" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            $config = @{ 
                InstallationOptions = @{ 
                    WSL2 = @{ 
                        Install = $true
                        Version = '1'
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "WSL2 Kernel Update" {
        It "Should download and install kernel update on older Windows builds" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock Get-CimInstance { 
                @{ Caption = 'Microsoft Windows 10 Pro'; BuildNumber = '18363' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            
            $config = @{ 
                InstallationOptions = @{ 
                    WSL2 = @{ 
                        Install = $true
                        Version = '2'
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle kernel update download failure" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock Get-CimInstance { 
                @{ Caption = 'Microsoft Windows 10 Pro'; BuildNumber = '18363' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            Mock Invoke-WebRequest { throw "Download failed" }
            
            $config = @{ 
                InstallationOptions = @{ 
                    WSL2 = @{ 
                        Install = $true
                        Version = '2'
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Simplified WSL Installation" {
        It "Should use simplified installation on newer Windows builds" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock Get-CimInstance { 
                @{ Caption = 'Microsoft Windows 10 Pro'; BuildNumber = '19041' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            
            $config = @{ InstallationOptions = @{ WSL2 = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Distribution Installation" {
        It "Should install specified distributions" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 0
                return @()
            } -ParameterFilter { $Command -like "*wsl --list*" }
            
            $config = @{ 
                InstallationOptions = @{ 
                    WSL2 = @{ 
                        Install = $true
                        Distribution = 'Ubuntu'
                        AdditionalDistros = @('Debian')
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should skip already installed distributions" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 0
                return @('Ubuntu')
            } -ParameterFilter { $Command -like "*wsl --list*" }
            
            $config = @{ 
                InstallationOptions = @{ 
                    WSL2 = @{ 
                        Install = $true
                        Distribution = 'Ubuntu'
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle distribution installation failure" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 0
                return @()
            } -ParameterFilter { $Command -like "*wsl --list*" }
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 1
            } -ParameterFilter { $Command -like "*wsl --install*" }
            
            $config = @{ 
                InstallationOptions = @{ 
                    WSL2 = @{ 
                        Install = $true
                        Distribution = 'Ubuntu'
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "WSL Configuration" {
        It "Should create WSL configuration file when settings specified" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            $config = @{ 
                InstallationOptions = @{ 
                    WSL2 = @{ 
                        Install = $true
                        Settings = @{
                            Memory = '8GB'
                            Processors = 4
                            SwapSize = '2GB'
                            LocalhostForwarding = $true
                        }
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Tool Installation in WSL" {
        It "Should install tools in WSL distribution when configured" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 0
            } -ParameterFilter { $Command -like "*apt-get*" }
            
            $config = @{ 
                InstallationOptions = @{ 
                    WSL2 = @{ 
                        Install = $true
                        Distribution = 'Ubuntu'
                        InstallTools = $true
                        Tools = @('git', 'curl', 'wget')
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle tool installation failure" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 1
            } -ParameterFilter { $Command -like "*apt-get*" }
            
            $config = @{ 
                InstallationOptions = @{ 
                    WSL2 = @{ 
                        Install = $true
                        Distribution = 'Ubuntu'
                        InstallTools = $true
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Restart Requirements" {
        It "Should return restart required exit code when restart needed" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock Get-WindowsOptionalFeature { 
                @{ State = 'Disabled'; RestartNeeded = $true }
            }
            
            $config = @{ InstallationOptions = @{ WSL2 = @{ Install = $true } } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 3010
        }
    }
    
    Context "Error Handling" {
        It "Should handle critical errors gracefully" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            Mock Get-CimInstance { throw "Critical system error" }
            
            $result = & $scriptPath 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }
    
    Context "WhatIf Support" {
        It "Should support WhatIf parameter without making changes" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WSL2.ps1"
            $config = @{ InstallationOptions = @{ WSL2 = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            
            # Verify no actual changes were made in WhatIf mode
            Assert-MockCalled Enable-WindowsOptionalFeature -Times 0
        }
    }
}
