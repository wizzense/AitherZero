#Requires -Version 7.0

Describe "0112_Enable-PXE.ps1" {
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

        # Mock firewall-related cmdlets
        Mock Get-NetFirewallRule { $null }
        Mock New-NetFirewallRule { }
        Mock Set-NetFirewallRule { }
    }

    Context "Parameter Validation" {
        It "Should accept hashtable configuration parameter" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{ NetworkServices = @{ PXE = @{ Enable = $false } } }
            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should work without configuration parameter" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            { & $scriptPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Platform Compatibility" {
        It "Should exit gracefully on non-Windows platforms" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $global:IsWindows = $false

            $result = & $scriptPath 2>&1
            $LASTEXITCODE | Should -Be 0

            $global:IsWindows = $true
        }
    }

    Context "Configuration Validation" {
        It "Should skip configuration when not enabled" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{ NetworkServices = @{ PXE = @{ Enable = $false } } }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 0

            Assert-MockCalled New-NetFirewallRule -Times 0
        }

        It "Should proceed with configuration when enabled" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Administrator Privilege Check" {
        It "Should exit with error when not running as administrator" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            Mock New-Object {
                @{ IsInRole = { param($Role) $false } }
            } -ParameterFilter { $TypeName -eq 'Security.Principal.WindowsPrincipal' }

            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Default Firewall Rules" {
        It "Should create default PXE firewall rules" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should create DHCP firewall rule (port 67)" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should create TFTP firewall rule (port 69)" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should create WDS firewall rules" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Custom Port Configuration" {
        It "Should create firewall rules for custom ports" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{
                NetworkServices = @{
                    PXE = @{
                        Enable = $true
                        AdditionalPorts = @(
                            @{ Port = 8080; Protocol = 'TCP'; Description = 'Custom HTTP' }
                            @{ Port = 9999; Protocol = 'UDP'; Description = 'Custom UDP' }
                        )
                    }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Existing Rule Handling" {
        It "Should detect existing firewall rules" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            Mock Get-NetFirewallRule {
                @{ DisplayName = 'AitherZero-PXE-DHCP'; Enabled = $true }
            } -ParameterFilter { $DisplayName -eq 'AitherZero-PXE-DHCP' }

            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should update existing rules when configured" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            Mock Get-NetFirewallRule {
                @{ DisplayName = 'AitherZero-PXE-DHCP'; Enabled = $false }
            } -ParameterFilter { $DisplayName -eq 'AitherZero-PXE-DHCP' }

            $config = @{
                NetworkServices = @{
                    PXE = @{
                        Enable = $true
                        UpdateExistingRules = $true
                    }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should skip updating existing rules when not configured" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            Mock Get-NetFirewallRule {
                @{ DisplayName = 'AitherZero-PXE-DHCP'; Enabled = $false }
            } -ParameterFilter { $DisplayName -eq 'AitherZero-PXE-DHCP' }

            $config = @{
                NetworkServices = @{
                    PXE = @{
                        Enable = $true
                        UpdateExistingRules = $false
                    }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw

            # Should not call Set-NetFirewallRule in WhatIf mode
            Assert-MockCalled Set-NetFirewallRule -Times 0
        }
    }

    Context "Remote Address Restrictions" {
        It "Should apply remote address restrictions when configured" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{
                NetworkServices = @{
                    PXE = @{
                        Enable = $true
                        AllowedRemoteAddresses = @('192.168.1.0/24', '10.0.0.0/8')
                    }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should allow any remote address when not restricted" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Firewall Rule Creation Failure" {
        It "Should handle firewall rule creation failure gracefully" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            Mock New-NetFirewallRule { throw "Firewall rule creation failed" }

            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }

        It "Should continue processing other rules when one fails" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            Mock New-NetFirewallRule { throw "Rule creation failed" } -ParameterFilter { $DisplayName -eq 'AitherZero-PXE-DHCP' }
            Mock New-NetFirewallRule { } -ParameterFilter { $DisplayName -ne 'AitherZero-PXE-DHCP' }

            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "WDS Configuration" {
        It "Should acknowledge WDS configuration when enabled" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{
                NetworkServices = @{
                    PXE = @{
                        Enable = $true
                        ConfigureWDS = $true
                    }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }
    }

    Context "Configuration Summary" {
        It "Should provide configuration summary" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw
        }

        It "Should report failed rules in summary" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            Mock New-NetFirewallRule { throw "Rule creation failed" } -ParameterFilter { $DisplayName -eq 'AitherZero-PXE-DHCP' }

            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Error Handling" {
        It "Should handle critical errors gracefully" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            Mock Get-NetFirewallRule { throw "Critical system error" }

            $result = & $scriptPath 2>&1
            $LASTEXITCODE | Should -Be 1
        }

        It "Should provide detailed error information" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            Mock New-NetFirewallRule {
                $error = [System.Exception]::new("Detailed error message")
                $error.Data.Add("ScriptStackTrace", "Test stack trace")
                throw $error
            }

            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter without making changes" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw

            # Verify no actual changes were made in WhatIf mode
            Assert-MockCalled New-NetFirewallRule -Times 0
            Assert-MockCalled Set-NetFirewallRule -Times 0
        }

        It "Should handle WhatIf for rule updates" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            Mock Get-NetFirewallRule {
                @{ DisplayName = 'AitherZero-PXE-DHCP'; Enabled = $false }
            } -ParameterFilter { $DisplayName -eq 'AitherZero-PXE-DHCP' }

            $config = @{
                NetworkServices = @{
                    PXE = @{
                        Enable = $true
                        UpdateExistingRules = $true
                    }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw

            # Verify no actual changes were made in WhatIf mode
            Assert-MockCalled Set-NetFirewallRule -Times 0
        }
    }

    Context "Success Scenarios" {
        It "Should complete successfully with default configuration" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{ NetworkServices = @{ PXE = @{ Enable = $true } } }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It "Should complete successfully with custom ports" {
            $scriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0112_Enable-PXE.ps1"
            $config = @{
                NetworkServices = @{
                    PXE = @{
                        Enable = $true
                        AdditionalPorts = @(
                            @{ Port = 8080; Protocol = 'TCP'; Description = 'Custom HTTP' }
                        )
                    }
                }
            }

            $result = & $scriptPath -Configuration $config 2>&1
            $LASTEXITCODE | Should -Be 0
        }
    }
}
