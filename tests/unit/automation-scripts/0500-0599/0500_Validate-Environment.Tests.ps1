#Requires -Version 7.0

Describe "0500_Validate-Environment" {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0500_Validate-Environment.ps1"
        $script:ProjectRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
        $script:LoggingPath = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
        
        # Mock external dependencies
        Mock -CommandName Import-Module -ParameterFilter { $Path -like "*Logging.psm1" } -MockWith { }
        Mock -CommandName Write-CustomLog -MockWith { param($Message, $Level) Write-Host "[$Level] $Message" }
        Mock -CommandName git -MockWith { "git version 2.34.1" }
        Mock -CommandName tofu -MockWith { "OpenTofu v1.0.0" }
        Mock -CommandName node -MockWith { "v18.17.0" }
        Mock -CommandName npm -MockWith { "9.8.1" }
        Mock -CommandName docker -MockWith { "Docker version 24.0.5" }
        Mock -CommandName Invoke-WebRequest -MockWith { @{ StatusCode = 200 } }
        
        # Mock Windows-specific commands
        if ($IsWindows) {
            Mock -CommandName Get-WindowsOptionalFeature -MockWith { @{ State = 'Enabled' } }
            Mock -CommandName Get-Service -ParameterFilter { $Name -eq 'vmms' } -MockWith { @{ Status = 'Running' } }
        }
    }

    Context "Parameter Validation" {
        It "Should accept Configuration hashtable parameter" {
            { & $script:ScriptPath -Configuration @{} -WhatIf } | Should -Not -Throw
        }

        It "Should support ShouldProcess (WhatIf)" {
            $result = & $script:ScriptPath -WhatIf -Configuration @{} 2>&1
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Environment Validation" {
        BeforeEach {
            # Reset mocks
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName New-Item -MockWith { }
            Mock -CommandName Write-Host -MockWith { }
        }

        It "Should validate PowerShell version" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*Logging.psm1" } -MockWith { $false }
            
            $result = & $script:ScriptPath -Configuration @{} 2>&1
            $LASTEXITCODE | Should -BeIn @(0, 2)  # Success or warnings
        }

        It "Should check for Git installation" {
            Mock -CommandName git -MockWith { throw "Git not found" }
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*Logging.psm1" } -MockWith { $false }
            
            $result = & $script:ScriptPath -Configuration @{ InstallationOptions = @{ Git = @{ Required = $true } } } 2>&1
            $LASTEXITCODE | Should -Be 2  # Should exit with warning code
        }
    }

    Context "WhatIf Support" {
        It "Should show validation preview with WhatIf" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*Logging.psm1" } -MockWith { $false }
            Mock -CommandName Write-Host -MockWith { } -Verifiable
            
            $result = & $script:ScriptPath -WhatIf -Configuration @{} 2>&1
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Write-Host -AtLeast 1
        }
    }
}
TESTEOF < /dev/null
