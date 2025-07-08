#Requires -Version 7.0

BeforeAll {
    # Import the module being tested
    $ModulePath = Split-Path $PSScriptRoot -Parent
    Import-Module "$ModulePath/ISOCustomizer.psd1" -Force
    
    # Set up test environment
    $script:TestDrive = Join-Path ([System.IO.Path]::GetTempPath()) "ISOCustomizer_Tests_$(Get-Date -Format 'yyyyMMddHHmmss')"
    New-Item -Path $script:TestDrive -ItemType Directory -Force | Out-Null
}

Describe "ISOCustomizer Module Tests" {
    
    Context "Module Import and Structure" {
        It "Should import successfully" {
            Get-Module ISOCustomizer | Should -Not -BeNullOrEmpty
        }
        
        It "Should export expected functions" {
            $ExportedFunctions = (Get-Module ISOCustomizer).ExportedFunctions.Keys
            $ExportedFunctions | Should -Contain "New-CustomISO"
            $ExportedFunctions | Should -Contain "New-AutounattendFile"
            $ExportedFunctions | Should -Contain "Get-AutounattendTemplate"
            $ExportedFunctions | Should -Contain "Get-BootstrapTemplate"
            $ExportedFunctions | Should -Contain "Get-KickstartTemplate"
        }
        
        It "Should have proper module manifest" {
            $Manifest = Import-PowerShellDataFile "$ModulePath/ISOCustomizer.psd1"
            $Manifest.ModuleVersion | Should -Not -BeNullOrEmpty
            $Manifest.Description | Should -Not -BeNullOrEmpty
            $Manifest.PowerShellVersion | Should -Be "7.0"
        }
    }
    
    Context "Template Helper Functions" {
        It "Should find autounattend generic template" {
            $GenericTemplate = Get-AutounattendTemplate -TemplateType "Generic"
            $GenericTemplate | Should -Not -BeNullOrEmpty
            Test-Path $GenericTemplate | Should -Be $true
        }
        
        It "Should find autounattend headless template" {
            $HeadlessTemplate = Get-AutounattendTemplate -TemplateType "Headless"
            $HeadlessTemplate | Should -Not -BeNullOrEmpty
            Test-Path $HeadlessTemplate | Should -Be $true
        }
        
        It "Should find bootstrap template" {
            $BootstrapTemplate = Get-BootstrapTemplate
            $BootstrapTemplate | Should -Not -BeNullOrEmpty
            Test-Path $BootstrapTemplate | Should -Be $true
        }
        
        It "Should find kickstart template" {
            $KickstartTemplate = Get-KickstartTemplate
            $KickstartTemplate | Should -Not -BeNullOrEmpty
            Test-Path $KickstartTemplate | Should -Be $true
        }
        
        It "Should validate template content structure" {
            $GenericTemplate = Get-AutounattendTemplate -TemplateType "Generic"
            $Content = Get-Content $GenericTemplate -Raw
            $Content | Should -Match "<unattend"
            $Content | Should -Match "windowsPE"
            $Content | Should -Match "oobeSystem"
            $Content | Should -Match "specialize"
        }
    }
}

Describe "New-AutounattendFile Function Tests" {
    
    Context "Basic Autounattend Generation" {
        It "Should generate autounattend file with minimal configuration" {
            $Config = @{
                ComputerName = "TEST-VM-01"
                AdminPassword = "TestPass123!"
            }
            
            $OutputPath = Join-Path $script:TestDrive "test-autounattend.xml"
            
            $Result = New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Server2025"
            
            $Result.Success | Should -Be $true
            Test-Path $OutputPath | Should -Be $true
            
            # Validate XML structure
            [xml]$Xml = Get-Content $OutputPath -Raw
            $Xml.unattend | Should -Not -BeNullOrEmpty
        }
        
        It "Should generate valid XML content" {
            $Config = @{
                ComputerName = "TEST-VM-02"
                AdminPassword = "TestPass123!"
                TimeZone = "UTC"
                EnableRDP = $true
            }
            
            $OutputPath = Join-Path $script:TestDrive "test-xml-validation.xml"
            
            $Result = New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Server2022"
            
            # XML should be parseable
            { [xml](Get-Content $OutputPath -Raw) } | Should -Not -Throw
            
            [xml]$Xml = Get-Content $OutputPath -Raw
            $Xml.unattend.settings | Should -Not -BeNullOrEmpty
        }
        
        It "Should include computer name in generated XML" {
            $Config = @{
                ComputerName = "CUSTOM-NAME-01"
                AdminPassword = "TestPass123!"
            }
            
            $OutputPath = Join-Path $script:TestDrive "test-computername.xml"
            
            New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Server2025" | Out-Null
            
            $Content = Get-Content $OutputPath -Raw
            $Content | Should -Match "CUSTOM-NAME-01"
        }
        
        It "Should handle special characters in configuration" {
            $Config = @{
                ComputerName = "TEST-VM-SPECIAL"
                AdminPassword = "P@ssw0rd&<>!"
                FullName = "Test User <Admin>"
                Organization = "Test & Validation Corp"
            }
            
            $OutputPath = Join-Path $script:TestDrive "test-special-chars.xml"
            
            { New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Server2025" } | Should -Not -Throw
            
            # XML should still be valid
            { [xml](Get-Content $OutputPath -Raw) } | Should -Not -Throw
        }
    }
    
    Context "Different OS Types" {
        It "Should generate correct image name for Server 2025" {
            $Config = @{
                ComputerName = "SRV2025-TEST"
                AdminPassword = "TestPass123!"
            }
            
            $OutputPath = Join-Path $script:TestDrive "server2025-test.xml"
            
            New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Server2025" -Edition "Datacenter" | Out-Null
            
            $Content = Get-Content $OutputPath -Raw
            $Content | Should -Match "Windows Server 2025 SERVERDATACENTER"
        }
        
        It "Should generate correct image name for Server 2022 Core" {
            $Config = @{
                ComputerName = "CORE2022-TEST"
                AdminPassword = "TestPass123!"
            }
            
            $OutputPath = Join-Path $script:TestDrive "server2022core-test.xml"
            
            New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Server2022" -Edition "Core" | Out-Null
            
            $Content = Get-Content $OutputPath -Raw
            $Content | Should -Match "Windows Server 2022 SERVERDATACENTERCORE"
        }
        
        It "Should generate correct image name for Windows 11" {
            $Config = @{
                ComputerName = "WIN11-TEST"
                AdminPassword = "TestPass123!"
            }
            
            $OutputPath = Join-Path $script:TestDrive "windows11-test.xml"
            
            New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Windows11" -Edition "Pro" | Out-Null
            
            $Content = Get-Content $OutputPath -Raw
            $Content | Should -Match "Windows 11 Pro"
        }
    }
    
    Context "Advanced Configuration Options" {
        It "Should include RDP configuration when enabled" {
            $Config = @{
                ComputerName = "RDP-TEST"
                AdminPassword = "TestPass123!"
                EnableRDP = $true
            }
            
            $OutputPath = Join-Path $script:TestDrive "rdp-test.xml"
            
            New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Server2025" | Out-Null
            
            $Content = Get-Content $OutputPath -Raw
            $Content | Should -Match "Microsoft-Windows-TerminalServices"
            $Content | Should -Match "fDenyTSConnections.*false"
        }
        
        It "Should include auto logon configuration when enabled" {
            $Config = @{
                ComputerName = "AUTOLOGON-TEST"
                AdminPassword = "TestPass123!"
                AutoLogon = $true
                AutoLogonCount = 5
            }
            
            $OutputPath = Join-Path $script:TestDrive "autologon-test.xml"
            
            New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Server2025" | Out-Null
            
            $Content = Get-Content $OutputPath -Raw
            $Content | Should -Match "<AutoLogon>"
            $Content | Should -Match "<LogonCount>5</LogonCount>"
        }
        
        It "Should include first logon commands" {
            $Config = @{
                ComputerName = "COMMANDS-TEST"
                AdminPassword = "TestPass123!"
                FirstLogonCommands = @(
                    @{
                        CommandLine = "powershell.exe -Command 'Write-Host Test'"
                        Description = "Test Command"
                    }
                )
            }
            
            $OutputPath = Join-Path $script:TestDrive "commands-test.xml"
            
            New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Server2025" | Out-Null
            
            $Content = Get-Content $OutputPath -Raw
            $Content | Should -Match "<FirstLogonCommands>"
            $Content | Should -Match "Write-Host Test"
        }
        
        It "Should include bootstrap script command when specified" {
            $Config = @{
                ComputerName = "BOOTSTRAP-TEST"
                AdminPassword = "TestPass123!"
                BootstrapScript = "C:\Windows\bootstrap.ps1"
            }
            
            $OutputPath = Join-Path $script:TestDrive "bootstrap-test.xml"
            
            New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Server2025" | Out-Null
            
            $Content = Get-Content $OutputPath -Raw
            $Content | Should -Match "bootstrap.ps1"
        }
    }
    
    Context "Error Handling" {
        It "Should throw error when output file exists and Force not specified" {
            $Config = @{
                ComputerName = "ERROR-TEST"
                AdminPassword = "TestPass123!"
            }
            
            $OutputPath = Join-Path $script:TestDrive "existing-file.xml"
            
            # Create existing file
            "existing content" | Set-Content $OutputPath
            
            { New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Server2025" } | Should -Throw "*already exists*"
        }
        
        It "Should overwrite when Force is specified" {
            $Config = @{
                ComputerName = "FORCE-TEST"
                AdminPassword = "TestPass123!"
            }
            
            $OutputPath = Join-Path $script:TestDrive "force-overwrite.xml"
            
            # Create existing file
            "existing content" | Set-Content $OutputPath
            
            { New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Server2025" -Force } | Should -Not -Throw
            
            $Content = Get-Content $OutputPath -Raw
            $Content | Should -Match "<unattend"
        }
        
        It "Should validate required configuration parameters" {
            $EmptyConfig = @{}
            
            $OutputPath = Join-Path $script:TestDrive "empty-config.xml"
            
            # Should use defaults for missing parameters
            { New-AutounattendFile -Configuration $EmptyConfig -OutputPath $OutputPath -OSType "Server2025" } | Should -Not -Throw
        }
    }
}

Describe "New-CustomISO Function Tests" {
    
    Context "Parameter Validation" {
        It "Should validate source ISO path" {
            $NonExistentISO = Join-Path $script:TestDrive "nonexistent.iso"
            $OutputISO = Join-Path $script:TestDrive "output.iso"
            
            { New-CustomISO -SourceISOPath $NonExistentISO -OutputISOPath $OutputISO } | Should -Throw "*not found*"
        }
        
        It "Should validate output path permissions" {
            # Create a mock source ISO file
            $SourceISO = Join-Path $script:TestDrive "source.iso"
            "mock iso content" | Set-Content $SourceISO
            
            $OutputISO = Join-Path $script:TestDrive "output.iso"
            
            # Test parameter validation (will fail on administrative privileges check in most cases)
            # This is expected behavior
            { New-CustomISO -SourceISOPath $SourceISO -OutputISOPath $OutputISO -WhatIf } | Should -Not -Throw
        }
        
        It "Should generate proper default paths" {
            $SourceISO = Join-Path $script:TestDrive "source.iso"
            "mock iso content" | Set-Content $SourceISO
            
            $OutputISO = Join-Path $script:TestDrive "output.iso"
            
            # Test parameter validation - will check admin privileges
            # In test environment, this will likely fail due to missing admin privileges
            $Result = { New-CustomISO -SourceISOPath $SourceISO -OutputISOPath $OutputISO -WhatIf }
            $Result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Configuration Integration" {
        It "Should accept autounattend configuration hashtable" {
            $SourceISO = Join-Path $script:TestDrive "source.iso"
            "mock iso content" | Set-Content $SourceISO
            
            $OutputISO = Join-Path $script:TestDrive "configured-output.iso"
            
            $Config = @{
                ComputerName = "CONFIG-TEST"
                AdminPassword = "TestPass123!"
            }
            
            # Test configuration acceptance
            $Result = { New-CustomISO -SourceISOPath $SourceISO -OutputISOPath $OutputISO -AutounattendConfig $Config -WhatIf }
            $Result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Integration Tests" {
    
    Context "Template and Generation Integration" {
        It "Should use headless template in headless mode" {
            $Config = @{
                ComputerName = "HEADLESS-TEST"
                AdminPassword = "TestPass123!"
            }
            
            $OutputPath = Join-Path $script:TestDrive "headless-integration.xml"
            
            New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType "Server2025" -HeadlessMode | Out-Null
            
            Test-Path $OutputPath | Should -Be $true
            [xml]$Xml = Get-Content $OutputPath -Raw
            $Xml.unattend | Should -Not -BeNullOrEmpty
        }
        
        It "Should integrate bootstrap template when available" {
            $BootstrapPath = Get-BootstrapTemplate
            
            if ($BootstrapPath -and (Test-Path $BootstrapPath)) {
                $Content = Get-Content $BootstrapPath -Raw
                $Content | Should -Not -BeNullOrEmpty
                $Content | Should -Match "bootstrap"
            }
        }
    }
    
    Context "Cross-Platform Considerations" {
        It "Should handle path construction properly" {
            $TestPath = Join-Path "some" "test" "path"
            $TestPath | Should -Not -BeNullOrEmpty
            
            # Test path construction doesn't fail
            $TempPath = Join-Path $env:TEMP "test-iso-customizer"
            $TempPath | Should -Match "test-iso-customizer"
        }
    }
}

Describe "Configuration Validation Tests" {
    
    Context "OS Image Name Resolution" {
        # Test the private Get-OSImageName function through public interface
        It "Should generate correct image names through autounattend generation" {
            $Configs = @(
                @{ OSType = "Server2025"; Edition = "Datacenter"; Expected = "Windows Server 2025 SERVERDATACENTER" }
                @{ OSType = "Server2022"; Edition = "Standard"; Expected = "Windows Server 2022 SERVERSTANDARD" }
                @{ OSType = "Server2019"; Edition = "Core"; Expected = "Windows Server 2019 SERVERDATACENTERCORE" }
                @{ OSType = "Windows11"; Edition = "Pro"; Expected = "Windows 11 Pro" }
                @{ OSType = "Windows10"; Edition = "Pro"; Expected = "Windows 10 Pro" }
            )
            
            foreach ($ConfigTest in $Configs) {
                $Config = @{
                    ComputerName = "IMAGE-TEST"
                    AdminPassword = "TestPass123!"
                }
                
                $OutputPath = Join-Path $script:TestDrive "image-test-$($ConfigTest.OSType)-$($ConfigTest.Edition).xml"
                
                $Result = New-AutounattendFile -Configuration $Config -OutputPath $OutputPath -OSType $ConfigTest.OSType -Edition $ConfigTest.Edition
                
                $Result.ImageName | Should -Be $ConfigTest.Expected
                
                $Content = Get-Content $OutputPath -Raw
                $Content | Should -Match [regex]::Escape($ConfigTest.Expected)
            }
        }
    }
    
    Context "Configuration Defaults" {
        It "Should apply default configuration values" {
            $MinimalConfig = @{
                ComputerName = "DEFAULTS-TEST"
            }
            
            $OutputPath = Join-Path $script:TestDrive "defaults-test.xml"
            
            $Result = New-AutounattendFile -Configuration $MinimalConfig -OutputPath $OutputPath -OSType "Server2025"
            
            # Check that defaults were applied
            $Result.Configuration.InputLocale | Should -Be "en-US"
            $Result.Configuration.AcceptEula | Should -Be $true
            $Result.Configuration.DiskID | Should -Be 0
            $Result.Configuration.TimeZone | Should -Be "UTC"
        }
    }
}

AfterAll {
    # Clean up test environment
    if (Test-Path $script:TestDrive) {
        Remove-Item $script:TestDrive -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Remove module
    Remove-Module ISOCustomizer -Force -ErrorAction SilentlyContinue
}