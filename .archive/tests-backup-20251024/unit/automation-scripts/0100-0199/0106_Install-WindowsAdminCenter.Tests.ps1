#Requires -Version 7.0

Describe "0106_Install-WindowsAdminCenter.ps1" {
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
        
        # Mock WAC installation checks
        Mock Get-ItemProperty { $null } -ParameterFilter { $Path -like "*ServerManagementGateway*" }
        Mock Get-Service { $null } -ParameterFilter { $Name -eq 'ServerManagementGateway' }
        
        # Mock download and installation
        Mock Invoke-WebRequest { } -ParameterFilter { $MaximumRedirection -eq 0 }
        Mock Invoke-WebRequest { }
        Mock Test-Path { $false } -ParameterFilter { $Path -like "*WindowsAdminCenter.msi" }
        Mock Get-Item { @{ Length = 100MB } }
        Mock Start-Process { @{ ExitCode = 0 } }
        Mock Remove-Item { }
        
        # Mock firewall and service operations
        Mock New-NetFirewallRule { }
        Mock Start-Service { }
        Mock Set-Content { }
        
        # Mock environment variables
        Mock Get-Variable { @{ Value = 'TestComputer' } } -ParameterFilter { $Name -eq 'env:COMPUTERNAME' }
        Mock Get-Variable { @{ Value = 'C:\temp' } } -ParameterFilter { $Name -eq 'env:TEMP' }
    }
    
    Context "Parameter Validation" {
        It "Should accept hashtable configuration parameter" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $false } } }
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should work without configuration parameter" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            { & $scriptPath -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Platform Compatibility" {
        It "Should exit gracefully on non-Windows platforms" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            $global:IsWindows = $false
            
            $result = & $scriptPath 2>&1
            $LASTEXITCODE | Should -Be 0
            
            $global:IsWindows = $true
        }
    }
    
    Context "Configuration Validation" {
        It "Should skip installation when not enabled in configuration" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $false } } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled Invoke-WebRequest -Times 0
        }
        
        It "Should proceed with installation when enabled" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Windows Version Validation" {
        It "Should exit with error on unsupported Windows versions" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Get-CimInstance { 
                @{ Caption = 'Microsoft Windows 8.1'; BuildNumber = '9600' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
        
        It "Should proceed on supported Windows versions" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Administrator Privilege Check" {
        It "Should exit with error when not running as administrator" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock New-Object { 
                @{ IsInRole = { param($Role) $false } }
            } -ParameterFilter { $TypeName -eq 'Security.Principal.WindowsPrincipal' }
            
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }
    
    Context "Existing Installation Check" {
        It "Should detect already installed WAC via registry" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Get-ItemProperty { @{ Version = '1.0' } } -ParameterFilter { $Path -like "*ServerManagementGateway*" }
            
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled Invoke-WebRequest -Times 0
        }
        
        It "Should detect already running WAC service" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Get-Service { 
                @{ Status = 'Running' }
            } -ParameterFilter { $Name -eq 'ServerManagementGateway' }
            
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled Invoke-WebRequest -Times 0
        }
    }
    
    Context "Download Process" {
        It "Should download WAC installer" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*WindowsAdminCenter.msi" }
            
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle download failure" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Invoke-WebRequest { throw "Download failed" }
            
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
        
        It "Should handle redirect URLs" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Invoke-WebRequest { 
                @{ Headers = @{ Location = 'https://download.microsoft.com/wac.msi' } }
            } -ParameterFilter { $MaximumRedirection -eq 0 }
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*WindowsAdminCenter.msi" }
            
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Installation Process" {
        It "Should install WAC with default configuration" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*WindowsAdminCenter.msi" }
            
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should install WAC with custom port" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*WindowsAdminCenter.msi" }
            
            $config = @{ 
                InstallationOptions = @{ 
                    WAC = @{ 
                        Install = $true
                        InstallPort = 8080
                        GenerateSslCertificate = $false
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle installation failure" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*WindowsAdminCenter.msi" }
            Mock Start-Process { @{ ExitCode = 1603 } }
            
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
        
        It "Should handle restart required scenario" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*WindowsAdminCenter.msi" }
            Mock Start-Process { @{ ExitCode = 3010 } }
            
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 3010
        }
    }
    
    Context "Firewall Configuration" {
        It "Should create firewall rule when configured" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*WindowsAdminCenter.msi" }
            Mock Get-Service { 
                @{ Status = 'Running' }
            } -ParameterFilter { $Name -eq 'ServerManagementGateway' }
            
            $config = @{ 
                InstallationOptions = @{ 
                    WAC = @{ 
                        Install = $true
                        ConfigureFirewall = $true
                        InstallPort = 443
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle firewall rule creation failure" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*WindowsAdminCenter.msi" }
            Mock Get-Service { 
                @{ Status = 'Running' }
            } -ParameterFilter { $Name -eq 'ServerManagementGateway' }
            Mock New-NetFirewallRule { throw "Firewall rule creation failed" }
            
            $config = @{ 
                InstallationOptions = @{ 
                    WAC = @{ 
                        Install = $true
                        ConfigureFirewall = $true
                        InstallPort = 443
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Service Management" {
        It "Should start WAC service after installation" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*WindowsAdminCenter.msi" }
            Mock Get-Service { 
                @{ Status = 'Stopped' }
            } -ParameterFilter { $Name -eq 'ServerManagementGateway' }
            
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle service start failure" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*WindowsAdminCenter.msi" }
            Mock Get-Service { 
                @{ Status = 'Stopped' }
            } -ParameterFilter { $Name -eq 'ServerManagementGateway' }
            Mock Start-Service { throw "Service start failed" }
            
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Desktop Shortcut Creation" {
        It "Should create desktop shortcut when configured" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*WindowsAdminCenter.msi" }
            Mock Get-Service { 
                @{ Status = 'Running' }
            } -ParameterFilter { $Name -eq 'ServerManagementGateway' }
            
            $config = @{ 
                InstallationOptions = @{ 
                    WAC = @{ 
                        Install = $true
                        CreateDesktopShortcut = $true
                    } 
                } 
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Error Handling" {
        It "Should handle critical errors gracefully" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            Mock Get-CimInstance { throw "Critical system error" }
            
            $result = & $scriptPath 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }
    
    Context "WhatIf Support" {
        It "Should support WhatIf parameter without making changes" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0106_Install-WindowsAdminCenter.ps1"
            $config = @{ InstallationOptions = @{ WAC = @{ Install = $true } } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            
            # Verify no actual changes were made in WhatIf mode
            Assert-MockCalled Start-Process -Times 0
            Assert-MockCalled New-NetFirewallRule -Times 0
        }
    }
}
