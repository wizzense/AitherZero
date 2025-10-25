#Requires -Version 7.0
using namespace System.Management.Automation

Describe "0100_Configure-System.ps1" {
    BeforeAll {
        # Mock external dependencies
        Mock Import-Module { } -ParameterFilter { $Name -like "*Logging*" }
        Mock Write-CustomLog { }
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
        Mock Write-Host { }

        # Mock Windows-specific variables
        if (-not (Test-Path Variable:IsWindows)) {
            $global:IsWindows = $true
        }

        Mock Get-CimInstance {
            @{ Caption = 'Microsoft Windows 10 Pro' }
        } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }

        Mock Test-Path { $true } -ParameterFilter { $Path -like "*Logging.psm1" }

        # Mock administrator check
        Mock New-Object {
            @{ IsInRole = { param($Role) $true } }
        } -ParameterFilter { $TypeName -eq 'Security.Principal.WindowsPrincipal' }

        # Mock system configuration cmdlets
        Mock Rename-Computer { }
        Mock Get-NetAdapter { @(@{ Name = 'Ethernet'; Status = 'Up'; InterfaceIndex = 1 }) }
        Mock Set-DnsClientServerAddress { }
        Mock Set-Item { } -ParameterFilter { $Path -like "WSMan:*" }
        Mock Disable-NetAdapterBinding { }
        Mock New-Item { } -ParameterFilter { $Path -like "HKLM:*" }
        Mock Set-ItemProperty { }
        Mock Enable-NetFirewallRule { }
        Mock Set-Service { }
        Mock Start-Service { }
        Mock New-NetFirewallRule { }
        Mock Enable-PSRemoting { }
        Mock Test-Path { $false } -ParameterFilter { $Path -like "HKLM:*" }
    }

    Context "Parameter Validation" {
        It "Should accept hashtable configuration parameter" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0100_Configure-System.ps1"
            $config = @{ System = @{ SetComputerName = $false } }
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Platform Compatibility" {
        It "Should exit gracefully on non-Windows platforms" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0100_Configure-System.ps1"
            $global:IsWindows = $false

            $result = & $scriptPath 2>&1
            $LASTEXITCODE | Should -Be 0

            $global:IsWindows = $true
        }
    }

    Context "Computer Name Configuration" {
        It "Should handle rename computer functionality" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0100_Configure-System.ps1"
            $config = @{
                System = @{
                    SetComputerName = $true
                    ComputerName = 'NewComputerName'
                }
            }

            Mock Get-Variable { @{ Value = 'OldComputerName' } } -ParameterFilter { $Name -eq 'env:COMPUTERNAME' }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "DNS Configuration" {
        It "Should configure DNS servers when enabled" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0100_Configure-System.ps1"
            $config = @{
                System = @{
                    SetDNSServers = $true
                    DNSServers = '8.8.8.8,1.1.1.1'
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
            Assert-MockCalled Get-NetAdapter -Times 1
        }
    }

    Context "Error Handling" {
        It "Should handle critical errors gracefully" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0100_Configure-System.ps1"
            Mock Get-CimInstance { throw "Critical system error" }

            $result = & $scriptPath 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }
}
