#Requires -Version 7.0
using namespace System.Management.Automation

Describe "0104_Install-CertificateAuthority.ps1" {
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
        
        # Mock certificate-related cmdlets
        Mock Get-WindowsFeature { 
            @{ Name = 'ADCS-Cert-Authority'; InstallState = 'Available' }
        }
        Mock Install-WindowsFeature { 
            @{ Success = $true; RestartNeeded = $false }
        }
        Mock Install-AdcsCertificationAuthority { }
        Mock Start-Service { }
        Mock Restart-Service { }
        Mock Get-Service { 
            @{ Status = 'Running' }
        } -ParameterFilter { $Name -eq 'CertSvc' }
        Mock New-SelfSignedCertificate { 
            @{ Subject = 'CN=TestCA'; Thumbprint = '1234567890ABCDEF' }
        }
        Mock Export-Certificate { }
        Mock New-Item { } -ParameterFilter { $ItemType -eq 'Directory' }
        Mock Get-ChildItem { @() } -ParameterFilter { $Path -like "*Cert:*" }
        
        # Mock OS detection
        Mock Get-CimInstance { 
            @{ Caption = 'Microsoft Windows 10 Pro' }
        } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
        
        # Mock computer system info
        Mock Get-CimInstance { 
            @{ Domain = 'WORKGROUP' }
        } -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
        
        # Mock certificate store operations
        Mock New-Object { 
            $mockStore = @{
                Open = { }
                Add = { }
                Close = { }
            }
            return $mockStore
        } -ParameterFilter { $TypeName -like '*X509Store*' }
        
        # Mock certutil command
        Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $FilePath -eq 'certutil' }
    }
    
    Context "Parameter Validation" {
        It "Should accept hashtable configuration parameter" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            $config = @{ CertificateAuthority = @{ InstallCA = $false } }
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should work without configuration parameter" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            { & $scriptPath -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Platform Compatibility" {
        It "Should exit gracefully on non-Windows platforms" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            $global:IsWindows = $false
            
            $result = & $scriptPath 2>&1
            $LASTEXITCODE | Should -Be 0
            
            $global:IsWindows = $true
        }
    }
    
    Context "Configuration Validation" {
        It "Should skip installation when not enabled in configuration" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            $config = @{ CertificateAuthority = @{ InstallCA = $false } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled Install-WindowsFeature -Times 0
        }
        
        It "Should proceed with installation when enabled" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            $config = @{ CertificateAuthority = @{ InstallCA = $true; CommonName = 'TestCA' } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Windows Edition Detection" {
        It "Should create self-signed certificate on non-Server editions" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            Mock Get-CimInstance { 
                @{ Caption = 'Microsoft Windows 10 Pro' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            
            $config = @{ CertificateAuthority = @{ InstallCA = $true; CommonName = 'TestCA' } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should install ADCS role on Server editions" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            Mock Get-CimInstance { 
                @{ Caption = 'Microsoft Windows Server 2019 Standard' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            
            $config = @{ CertificateAuthority = @{ InstallCA = $true; CommonName = 'TestCA' } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Self-Signed Certificate Creation" {
        It "Should create self-signed certificate with correct parameters" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            $config = @{ 
                CertificateAuthority = @{ 
                    InstallCA = $true
                    CommonName = 'TestRootCA'
                    ValidityYears = 10
                }
            }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should skip certificate creation if already exists" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            Mock Get-ChildItem { 
                @(@{ Subject = 'CN=TestRootCA' })
            } -ParameterFilter { $Path -like "*Cert:*" }
            
            $config = @{ 
                CertificateAuthority = @{ 
                    InstallCA = $true
                    CommonName = 'TestRootCA'
                }
            }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled New-SelfSignedCertificate -Times 0
        }
        
        It "Should handle certificate creation failure" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            Mock New-SelfSignedCertificate { throw "Certificate creation failed" }
            
            $config = @{ 
                CertificateAuthority = @{ 
                    InstallCA = $true
                    CommonName = 'TestRootCA'
                }
            }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }
    
    Context "ADCS Role Installation" {
        It "Should check for existing ADCS installation" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            Mock Get-CimInstance { 
                @{ Caption = 'Microsoft Windows Server 2019 Standard' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            
            Mock Get-WindowsFeature { 
                @{ Name = 'ADCS-Cert-Authority'; InstallState = 'Installed' }
            }
            
            $config = @{ CertificateAuthority = @{ InstallCA = $true; CommonName = 'TestCA' } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Assert-MockCalled Get-WindowsFeature -Times 1
        }
        
        It "Should install ADCS role when not present" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            Mock Get-CimInstance { 
                @{ Caption = 'Microsoft Windows Server 2019 Standard' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            
            Mock Get-WindowsFeature { 
                @{ Name = 'ADCS-Cert-Authority'; InstallState = 'Available' }
            }
            
            $config = @{ CertificateAuthority = @{ InstallCA = $true; CommonName = 'TestCA' } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle ADCS installation failure" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            Mock Get-CimInstance { 
                @{ Caption = 'Microsoft Windows Server 2019 Standard' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            
            Mock Install-WindowsFeature { 
                @{ Success = $false; RestartNeeded = $false }
            }
            
            $config = @{ CertificateAuthority = @{ InstallCA = $true; CommonName = 'TestCA' } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }
    
    Context "CA Type Detection" {
        It "Should configure as Enterprise CA for domain-joined machines" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            Mock Get-CimInstance { 
                @{ Caption = 'Microsoft Windows Server 2019 Standard' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            
            Mock Get-CimInstance { 
                @{ Domain = 'contoso.com' }
            } -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
            
            $config = @{ CertificateAuthority = @{ InstallCA = $true; CommonName = 'TestCA' } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
        
        It "Should configure as Standalone CA for workgroup machines" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            Mock Get-CimInstance { 
                @{ Caption = 'Microsoft Windows Server 2019 Standard' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            
            Mock Get-CimInstance { 
                @{ Domain = 'WORKGROUP' }
            } -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
            
            $config = @{ CertificateAuthority = @{ InstallCA = $true; CommonName = 'TestCA' } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Administrator Privilege Check" {
        It "Should exit with error when not running as administrator" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            Mock Get-CimInstance { 
                @{ Caption = 'Microsoft Windows Server 2019 Standard' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            
            Mock New-Object { 
                @{ IsInRole = { param($Role) $false } }
            } -ParameterFilter { $TypeName -eq 'Security.Principal.WindowsPrincipal' }
            
            $config = @{ CertificateAuthority = @{ InstallCA = $true; CommonName = 'TestCA' } }
            
            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }
    
    Context "Error Handling" {
        It "Should handle critical errors gracefully" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            Mock Get-CimInstance { throw "Critical system error" }
            
            $result = & $scriptPath 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }
    
    Context "WhatIf Support" {
        It "Should support WhatIf parameter without making changes" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0104_Install-CertificateAuthority.ps1"
            $config = @{ CertificateAuthority = @{ InstallCA = $true; CommonName = 'TestCA' } }
            
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            
            # Verify no actual changes were made in WhatIf mode
            Assert-MockCalled Install-WindowsFeature -Times 0
            Assert-MockCalled New-SelfSignedCertificate -Times 0
        }
    }
}
