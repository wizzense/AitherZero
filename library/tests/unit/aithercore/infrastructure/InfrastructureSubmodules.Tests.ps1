#Requires -Version 7.0

BeforeAll {
    # Import the full AitherZero module for dependencies
    $AitherZeroPath = Join-Path $PSScriptRoot "../../../../AitherZero.psd1"
    Import-Module $AitherZeroPath -Force -Global -ErrorAction SilentlyContinue

    # Import the Infrastructure module
    $ModulePath = Join-Path $PSScriptRoot "../../../../aithercore/infrastructure/Infrastructure.psm1"
    Import-Module $ModulePath -Force -Global

    # Mock Write-InfraLog if needed
    if (-not (Get-Command Write-InfraLog -ErrorAction SilentlyContinue)) {
        Mock Write-InfraLog { }
    }

    # Mock configuration
    Mock Get-Configuration -ModuleName Infrastructure {
        return @{
            Infrastructure = @{
                Submodules = @{
                    Enabled = $true
                    AutoInit = $true
                    AutoUpdate = $false
                    Default = @{
                        Name = 'test-infrastructure'
                        Url = 'https://github.com/test/test-infra.git'
                        Path = 'infrastructure/test'
                        Branch = 'main'
                        Description = 'Test infrastructure'
                        Enabled = $true
                    }
                    Repositories = @{}
                    Behavior = @{
                        RecursiveInit = $true
                        ShallowClone = $false
                        ParallelJobs = 4
                    }
                }
            }
        }
    }

    # Mock Git commands
    Mock git -ModuleName Infrastructure { }
}

Describe "Infrastructure Submodule Management Tests" -Tags @("Unit", "Infrastructure", "Submodules") {

    Context "Module Exports New Functions" {
        It "Should export Initialize-InfrastructureSubmodule" {
            $exportedFunctions = Get-Command -Module Infrastructure -CommandType Function
            $exportedFunctions.Name | Should -Contain "Initialize-InfrastructureSubmodule"
        }

        It "Should export Update-InfrastructureSubmodule" {
            $exportedFunctions = Get-Command -Module Infrastructure -CommandType Function
            $exportedFunctions.Name | Should -Contain "Update-InfrastructureSubmodule"
        }

        It "Should export Get-InfrastructureSubmodule" {
            $exportedFunctions = Get-Command -Module Infrastructure -CommandType Function
            $exportedFunctions.Name | Should -Contain "Get-InfrastructureSubmodule"
        }

        It "Should export Sync-InfrastructureSubmodule" {
            $exportedFunctions = Get-Command -Module Infrastructure -CommandType Function
            $exportedFunctions.Name | Should -Contain "Sync-InfrastructureSubmodule"
        }

        It "Should export Remove-InfrastructureSubmodule" {
            $exportedFunctions = Get-Command -Module Infrastructure -CommandType Function
            $exportedFunctions.Name | Should -Contain "Remove-InfrastructureSubmodule"
        }
    }

    Context "Get-InfrastructureSubmodule" {
        It "Should return configured submodules" {
            Mock Test-Path -ModuleName Infrastructure { $false }
            Mock git -ModuleName Infrastructure { $global:LASTEXITCODE = 1 }

            $result = Get-InfrastructureSubmodule
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Contain "test-infrastructure"
        }

        It "Should show submodules with correct properties" {
            Mock Test-Path -ModuleName Infrastructure { $false }
            Mock git -ModuleName Infrastructure { $global:LASTEXITCODE = 1 }

            $result = Get-InfrastructureSubmodule
            $result[0].Url | Should -Be 'https://github.com/test/test-infra.git'
            $result[0].Path | Should -Be 'infrastructure/test'
            $result[0].Branch | Should -Be 'main'
            $result[0].IsDefault | Should -Be $true
        }

        It "Should handle disabled submodules configuration" {
            Mock Get-Configuration -ModuleName Infrastructure {
                return @{
                    Infrastructure = @{
                        Submodules = @{
                            Enabled = $false
                        }
                    }
                }
            }

            { Get-InfrastructureSubmodule } | Should -Not -Throw
        }
    }

    Context "Initialize-InfrastructureSubmodule" {
        BeforeEach {
            Mock Test-Path -ModuleName Infrastructure { $false }
            Mock git -ModuleName Infrastructure { $global:LASTEXITCODE = 0 }
        }

        It "Should support WhatIf parameter" {
            { Initialize-InfrastructureSubmodule -WhatIf } | Should -Not -Throw
        }

        It "Should initialize all enabled submodules by default" {
            Initialize-InfrastructureSubmodule -WhatIf
            # Should complete without errors
        }

        It "Should support Force parameter" {
            { Initialize-InfrastructureSubmodule -Force -WhatIf } | Should -Not -Throw
        }

        It "Should support Name parameter for specific submodule" {
            { Initialize-InfrastructureSubmodule -Name 'default' -WhatIf } | Should -Not -Throw
        }

        It "Should throw when Git is not available" {
            Mock Get-Command -ModuleName Infrastructure { $null } -ParameterFilter { $Name -eq "git" }
            
            { Initialize-InfrastructureSubmodule } | Should -Throw "Git is required*"
        }
    }

    Context "Update-InfrastructureSubmodule" {
        BeforeEach {
            Mock git -ModuleName Infrastructure { $global:LASTEXITCODE = 0 }
        }

        It "Should support WhatIf parameter" {
            { Update-InfrastructureSubmodule -WhatIf } | Should -Not -Throw
        }

        It "Should support Merge parameter" {
            { Update-InfrastructureSubmodule -Merge -WhatIf } | Should -Not -Throw
        }

        It "Should support Remote parameter" {
            { Update-InfrastructureSubmodule -Remote -WhatIf } | Should -Not -Throw
        }

        It "Should throw when Git is not available" {
            Mock Get-Command -ModuleName Infrastructure { $null } -ParameterFilter { $Name -eq "git" }
            
            { Update-InfrastructureSubmodule } | Should -Throw "Git is required*"
        }
    }

    Context "Sync-InfrastructureSubmodule" {
        BeforeEach {
            Mock Test-Path -ModuleName Infrastructure { $false }
            Mock git -ModuleName Infrastructure { $global:LASTEXITCODE = 0 }
            Mock Get-InfrastructureSubmodule -ModuleName Infrastructure {
                return @(
                    [PSCustomObject]@{
                        Name = 'test-infrastructure'
                        Path = 'infrastructure/test'
                        Enabled = $true
                    }
                )
            }
        }

        It "Should support WhatIf parameter" {
            { Sync-InfrastructureSubmodule -WhatIf } | Should -Not -Throw
        }

        It "Should support Force parameter" {
            { Sync-InfrastructureSubmodule -Force -WhatIf } | Should -Not -Throw
        }
    }

    Context "Remove-InfrastructureSubmodule" {
        BeforeEach {
            Mock git -ModuleName Infrastructure { $global:LASTEXITCODE = 0 }
        }

        It "Should support WhatIf parameter" {
            { Remove-InfrastructureSubmodule -Name 'default' -WhatIf } | Should -Not -Throw
        }

        It "Should support Clean parameter" {
            Mock Test-Path -ModuleName Infrastructure { $true }
            Mock Remove-Item -ModuleName Infrastructure { }
            
            { Remove-InfrastructureSubmodule -Name 'default' -Clean -WhatIf } | Should -Not -Throw
        }

        It "Should throw when Git is not available" {
            Mock Get-Command -ModuleName Infrastructure { $null } -ParameterFilter { $Name -eq "git" }
            
            { Remove-InfrastructureSubmodule -Name 'default' } | Should -Throw "Git is required*"
        }
    }
}

Describe "Configuration Integration Tests" -Tags @("Integration", "Infrastructure", "Configuration") {
    
    Context "Config.psd1 Submodules Section" {
        It "Should have Infrastructure.Submodules section in config.psd1" {
            $configPath = Join-Path $PSScriptRoot "../../../../config.psd1"
            $configContent = Get-Content -Path $configPath -Raw
            $scriptBlock = [scriptblock]::Create($configContent)
            $config = & $scriptBlock
            
            $config.Infrastructure.Submodules | Should -Not -BeNullOrEmpty
        }

        It "Should have Enabled property" {
            $configPath = Join-Path $PSScriptRoot "../../../../config.psd1"
            $configContent = Get-Content -Path $configPath -Raw
            $scriptBlock = [scriptblock]::Create($configContent)
            $config = & $scriptBlock
            
            $config.Infrastructure.Submodules.Enabled | Should -BeOfType [bool]
        }

        It "Should have Default submodule configuration" {
            $configPath = Join-Path $PSScriptRoot "../../../../config.psd1"
            $configContent = Get-Content -Path $configPath -Raw
            $scriptBlock = [scriptblock]::Create($configContent)
            $config = & $scriptBlock
            
            $config.Infrastructure.Submodules.Default | Should -Not -BeNullOrEmpty
            $config.Infrastructure.Submodules.Default.Name | Should -Be 'aitherium-infrastructure'
            $config.Infrastructure.Submodules.Default.Url | Should -BeLike '*github.com*aitherium-infrastructure*'
        }

        It "Should have Behavior configuration" {
            $configPath = Join-Path $PSScriptRoot "../../../../config.psd1"
            $configContent = Get-Content -Path $configPath -Raw
            $scriptBlock = [scriptblock]::Create($configContent)
            $config = & $scriptBlock
            
            $config.Infrastructure.Submodules.Behavior | Should -Not -BeNullOrEmpty
            $config.Infrastructure.Submodules.Behavior.RecursiveInit | Should -BeOfType [bool]
        }
    }
}
