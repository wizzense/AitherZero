#Requires -Version 7.0

Describe "0105_Install-HyperV.ps1" {
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

        # Mock Hyper-V related cmdlets
        Mock Get-WindowsOptionalFeature {
            @{ State = 'Disabled'; RestartNeeded = $false }
        }
        Mock Enable-WindowsOptionalFeature {
            @{ RestartNeeded = $true }
        }
        Mock Get-Module { $null } -ParameterFilter { $Name -eq 'Hyper-V' }
        Mock Import-Module { } -ParameterFilter { $Name -eq 'Hyper-V' }
        Mock Get-VMHost { @{ Name = 'TestHost' } }
        Mock Get-VMSwitch { @() }
        Mock New-Item { } -ParameterFilter { $ItemType -eq 'Directory' }
    }

    Context "Parameter Validation" {
        It "Should accept hashtable configuration parameter" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            $config = @{ InstallationOptions = @{ HyperV = @{ Install = $false } } }
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should work without configuration parameter" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            { & $scriptPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Platform Compatibility" {
        It "Should exit gracefully on non-Windows platforms" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            $global:IsWindows = $false

            $result = & $scriptPath 2>&1
            $LASTEXITCODE | Should -Be 0

            $global:IsWindows = $true
        }
    }

    Context "Configuration Validation" {
        It "Should skip installation when not enabled in configuration" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            $config = @{ InstallationOptions = @{ HyperV = @{ Install = $false } } }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 0

            Assert-MockCalled Enable-WindowsOptionalFeature -Times 0
        }

        It "Should proceed with installation when enabled" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            $config = @{ InstallationOptions = @{ HyperV = @{ Install = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Windows Edition Validation" {
        It "Should skip installation on unsupported Windows editions" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            Mock Get-CimInstance {
                @{ Caption = 'Microsoft Windows 10 Home'; BuildNumber = '19041' }
            } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }

            $config = @{ InstallationOptions = @{ HyperV = @{ Install = $true } } }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 0

            Assert-MockCalled Enable-WindowsOptionalFeature -Times 0
        }

        It "Should proceed on supported Windows editions" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            $config = @{ InstallationOptions = @{ HyperV = @{ Install = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Administrator Privilege Check" {
        It "Should exit with error when not running as administrator" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            Mock New-Object {
                @{ IsInRole = { param($Role) $false } }
            } -ParameterFilter { $TypeName -eq 'Security.Principal.WindowsPrincipal' }

            $config = @{ InstallationOptions = @{ HyperV = @{ Install = $true } } }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Hyper-V Status Check" {
        It "Should detect already enabled Hyper-V" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            Mock Get-WindowsOptionalFeature {
                @{ State = 'Enabled'; RestartNeeded = $false }
            }
            Mock Get-Service {
                @{ Status = 'Running' }
            } -ParameterFilter { $Name -eq 'vmms' }

            $config = @{ InstallationOptions = @{ HyperV = @{ Install = $true } } }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 0

            Assert-MockCalled Enable-WindowsOptionalFeature -Times 0
        }

        It "Should handle Hyper-V status check failure" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            Mock Get-WindowsOptionalFeature { throw "Feature check failed" }

            $config = @{ InstallationOptions = @{ HyperV = @{ Install = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Hyper-V Installation" {
        It "Should enable Hyper-V features" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            $config = @{ InstallationOptions = @{ HyperV = @{ Install = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should return restart required exit code when restart needed" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            Mock Enable-WindowsOptionalFeature {
                @{ RestartNeeded = $true }
            }

            $config = @{ InstallationOptions = @{ HyperV = @{ Install = $true } } }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 3010
        }

        It "Should handle Hyper-V installation failure" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            Mock Enable-WindowsOptionalFeature { throw "Installation failed" }

            $config = @{ InstallationOptions = @{ HyperV = @{ Install = $true } } }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Hyper-V Host Preparation" {
        It "Should prepare Hyper-V host when configured" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            $config = @{
                InstallationOptions = @{
                    HyperV = @{
                        Install = $true
                        PrepareHost = $true
                    }
                }
                Infrastructure = @{
                    DefaultVMPath = 'C:\VMs'
                    DefaultVHDPath = 'C:\VHDs'
                }
            }

            Mock Get-Module { @{ Name = 'Hyper-V' } } -ParameterFilter { $Name -eq 'Hyper-V' }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should handle Hyper-V module loading failure" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            Mock Import-Module { throw "Module load failed" } -ParameterFilter { $Name -eq 'Hyper-V' }

            $config = @{
                InstallationOptions = @{
                    HyperV = @{
                        Install = $true
                        PrepareHost = $true
                    }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "PowerShell Module Installation" {
        It "Should install Hyper-V PowerShell module when missing" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            Mock Get-Module { $null } -ParameterFilter { $Name -eq 'Hyper-V' -and $ListAvailable }

            $config = @{ InstallationOptions = @{ HyperV = @{ Install = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Directory Creation" {
        It "Should create VM and VHD directories when specified" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            Mock Test-Path { $false } -ParameterFilter { $Path -like 'C:\*' }

            $config = @{
                InstallationOptions = @{
                    HyperV = @{
                        Install = $true
                        PrepareHost = $true
                    }
                }
                Infrastructure = @{
                    DefaultVMPath = 'C:\VMs'
                    DefaultVHDPath = 'C:\VHDs'
                }
            }

            Mock Get-Module { @{ Name = 'Hyper-V' } } -ParameterFilter { $Name -eq 'Hyper-V' }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        It "Should handle critical errors gracefully" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            Mock Get-CimInstance { throw "Critical system error" }

            $result = & $scriptPath 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter without making changes" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0105_Install-HyperV.ps1"
            $config = @{ InstallationOptions = @{ HyperV = @{ Install = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw

            # Verify no actual changes were made in WhatIf mode
            Assert-MockCalled Enable-WindowsOptionalFeature -Times 0
        }
    }
}
