#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for 0400_Install-TestingTools.ps1
.DESCRIPTION
    Tests the testing tools installation script functionality including module installation,
    WhatIf mode, and error handling.
#>

BeforeAll {
    # Get script path
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0400_Install-TestingTools.ps1"

    # Mock functions that the script uses
    Mock Install-Module {}
    Mock Uninstall-Module {}
    Mock Remove-Module {}
    Mock Set-PSRepository {}
    Mock Import-Module {}
    Mock Get-Module {
        return @([PSCustomObject]@{
            Name = 'TestModule'
            Version = [Version]'1.0.0'
            Path = 'C:\TestPath'
        })
    }
    Mock Get-PSRepository {
        return @([PSCustomObject]@{
            Name = 'PSGallery'
            InstallationPolicy = 'Untrusted'
        })
    }
    Mock Test-Path { return $true }
    Mock Get-Content { return '{"Testing":{"MinVersion":"5.0.0"}}' } -ParameterFilter { $Path -notlike "*0400_Install-TestingTools.ps1" }
    Mock ConvertFrom-Json {
        return @{
            Testing = @{
                MinVersion = '5.0.0'
            }
        }
    }
    Mock Set-Content {}
    Mock Write-Host {}
}

Describe "0400_Install-TestingTools" -Tag @('Unit', 'Testing', 'Installation') {

    Context "Script Metadata" {
        It "Should have correct metadata structure" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '#Requires -Version 7.0'
            $scriptContent | Should -Match 'Stage.*Testing'
            $scriptContent | Should -Match 'Order.*0400'
        }
    }

    Context "DryRun Mode" {
        It "Should preview installation without executing when DryRun is specified" {
            Mock Write-Host {}

            $result = & $scriptPath -DryRun
            $LASTEXITCODE | Should -Be 0

            Assert-MockCalled Install-Module -Times 0
            Assert-MockCalled Set-PSRepository -Times 0
        }

        It "Should log what tools would be installed in DryRun mode" {
            Mock Write-Host {} -ParameterFilter { $Object -like "*Would install testing tools*" }

            & $scriptPath -DryRun

            Assert-MockCalled Write-Host -ParameterFilter { $Object -like "*Would install testing tools*" }
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter" {
            Mock Write-Host {}

            { & $scriptPath -WhatIf } | Should -Not -Throw

            Assert-MockCalled Install-Module -Times 0
        }
    }

    Context "Module Installation" {
        BeforeEach {
            Mock Get-Module { return $null } -ParameterFilter { $ListAvailable -and $Name -eq 'PowerShellGet' }
            Mock Get-Module { return $null } -ParameterFilter { $ListAvailable -and $Name -eq 'Pester' }
            Mock Get-Module { return $null } -ParameterFilter { $ListAvailable -and $Name -eq 'PSScriptAnalyzer' }
            Mock Get-Module { return $null } -ParameterFilter { $ListAvailable -and $Name -eq 'Plaster' }
        }

        It "Should install PowerShellGet if not available or outdated" {
            Mock Get-Module {
                return @([PSCustomObject]@{
                    Version = [Version]'2.2.4'
                })
            } -ParameterFilter { $ListAvailable -and $Name -eq 'PowerShellGet' }

            & $scriptPath -Force

            Assert-MockCalled Install-Module -ParameterFilter {
                $Name -eq 'PowerShellGet' -and $MinimumVersion -eq '2.2.5'
            }
        }

        It "Should install Pester with specified minimum version" {
            & $scriptPath -Force

            Assert-MockCalled Install-Module -ParameterFilter {
                $Name -eq 'Pester' -and $MinimumVersion -eq '5.0.0'
            }
        }

        It "Should install PSScriptAnalyzer" {
            & $scriptPath -Force

            Assert-MockCalled Install-Module -ParameterFilter {
                $Name -eq 'PSScriptAnalyzer'
            }
        }

        It "Should install Plaster for test scaffolding" {
            & $scriptPath -Force

            Assert-MockCalled Install-Module -ParameterFilter {
                $Name -eq 'Plaster'
            }
        }

        It "Should set PSGallery as trusted repository" {
            & $scriptPath -Force

            Assert-MockCalled Set-PSRepository -ParameterFilter {
                $Name -eq 'PSGallery' -and $InstallationPolicy -eq 'Trusted'
            }
        }
    }
}
