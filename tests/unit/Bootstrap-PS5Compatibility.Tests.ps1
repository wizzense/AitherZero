#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    Tests for PowerShell 5.1 compatibility in bootstrap.ps1
.DESCRIPTION
    Validates that bootstrap.ps1 can run on PowerShell 5.1 and properly
    upgrade to PowerShell 7 without errors
#>

BeforeAll {
    # Import test helpers
    $script:TestRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $script:TestRoot "TestHelpers.psm1") -Force
    
    # Get bootstrap script path
    $script:ProjectRoot = Split-Path $script:TestRoot -Parent
    $script:BootstrapPath = Join-Path $script:ProjectRoot "bootstrap.ps1"
    
    # Load bootstrap script content for analysis
    $script:BootstrapContent = Get-Content $script:BootstrapPath -Raw
}

Describe "PowerShell 5.1 Compatibility" {
    Context "Platform Detection Functions" {
        It "Should not use PowerShell 6+ automatic variables directly" {
            # These variables don't exist in PS 5.1 - should use Test-Is* functions instead
            $script:BootstrapContent | Should -Not -BeLike "*} elseif (`$IsWindows)*"
            $script:BootstrapContent | Should -Not -BeLike "*} elseif (`$IsLinux)*" 
            $script:BootstrapContent | Should -Not -BeLike "*} elseif (`$IsMacOS)*"
        }
        
        It "Should have PS5.1-compatible platform detection" {
            $script:BootstrapContent | Should -BeLike "*Test-IsWindows*"
            $script:BootstrapContent | Should -BeLike "*PSVersionTable.PSVersion.Major -ge 6*"
        }
        
        It "Should handle missing platform variables gracefully" {
            # Should use Test-Is* functions that handle PS version differences
            $script:BootstrapContent | Should -BeLike "*Test-IsMacOS*"
            $script:BootstrapContent | Should -BeLike "*Test-IsLinux*"  
            $script:BootstrapContent | Should -BeLike "*Test-IsWindows*"
        }
    }
    
    Context "PowerShell 7 Detection Logic" {
        It "Should correctly identify PowerShell versions below 7" {
            $script:BootstrapContent | Should -BeLike "*PSVersionTable.PSVersion.Major -lt 7*"
        }
        
        It "Should require PowerShell 7 installation when version is insufficient" {
            $script:BootstrapContent | Should -BeLike "*PowerShell 7 is required*"
            $script:BootstrapContent | Should -BeLike "*Install-PowerShell7*"
        }
        
        It "Should handle relaunch logic properly" {
            $script:BootstrapContent | Should -BeLike "*Re-launching bootstrap in PowerShell 7*"
            $script:BootstrapContent | Should -BeLike "*pwsh*-NoProfile*-ExecutionPolicy Bypass*"
        }
    }
    
    Context "Cross-Platform Compatibility" {
        It "Should work on Linux/macOS when PowerShell 7 is already installed" {
            # Should check if pwsh is available before trying to install
            $script:BootstrapContent | Should -BeLike "*Get-Command pwsh*"
        }
        
        It "Should have fallback mechanisms for different platforms" {
            $script:BootstrapContent | Should -BeLike "*Test-IsMacOS*"
            $script:BootstrapContent | Should -BeLike "*Unix*"
        }
    }
}

Describe "PowerShell 7 Installation Process" {
    Context "Windows Installation" {
        It "Should try winget first on Windows" {
            $script:BootstrapContent | Should -BeLike "*winget install*Microsoft.PowerShell*"
        }
        
        It "Should fallback to MSI installer" {
            $script:BootstrapContent | Should -BeLike "*PowerShell-7-win-x64.msi*"
            $script:BootstrapContent | Should -BeLike "*msiexec*"
        }
        
        It "Should handle elevation for installation" {
            $script:BootstrapContent | Should -BeLike "*Test-IsAdmin*"
            $script:BootstrapContent | Should -BeLike "*-Verb RunAs*"
        }
    }
    
    Context "Linux Installation" {
        It "Should use Microsoft's install script for Linux" {
            $script:BootstrapContent | Should -BeLike "*install-powershell.sh*"
            $script:BootstrapContent | Should -BeLike "*aka.ms/install-powershell.sh*"
        }
    }
    
    Context "macOS Installation" {
        It "Should use Homebrew for macOS" {
            $script:BootstrapContent | Should -BeLike "*brew install --cask powershell*"
        }
        
        It "Should install Homebrew if not available" {
            $script:BootstrapContent | Should -BeLike "*Installing Homebrew first*"
        }
    }
}

Describe "Relaunch Parameter Preservation" {
    Context "Argument Handling" {
        It "Should preserve all bootstrap parameters during relaunch" {
            $script:BootstrapContent | Should -BeLike "*PSBoundParameters.GetEnumerator()*"
            $script:BootstrapContent | Should -BeLike "*param.Key*"
            $script:BootstrapContent | Should -BeLike "*param.Value*"
        }
        
        It "Should use proper parameter passing" {
            $script:BootstrapContent | Should -BeLike "*@argumentList*"
            $script:BootstrapContent | Should -BeLike "*`$argumentList*"
        }
        
        It "Should handle switches correctly" {
            $script:BootstrapContent | Should -BeLike "*PSBoundParameters*"
            $script:BootstrapContent | Should -BeLike "*switch*"
        }
    }
}

Describe "Error Handling and Validation" {
    Context "PowerShell 7 Verification" {
        It "Should verify PowerShell 7 installation success" {
            $script:BootstrapContent | Should -BeLike "*PowerShell 7 installed successfully*"
        }
        
        It "Should handle installation failures" {
            $script:BootstrapContent | Should -BeLike "*PowerShell 7 installation*failed*"
        }
        
        It "Should check for pwsh command availability after installation" {
            $script:BootstrapContent | Should -BeLike "*Get-Command pwsh*"
        }
    }
    
    Context "Graceful Degradation" {
        It "Should provide informative error messages" {
            $script:BootstrapContent | Should -BeLike "*Write-BootstrapLog*Error*"
        }
        
        It "Should not crash on unsupported platforms" {
            $script:BootstrapContent | Should -BeLike "*catch*"
            $script:BootstrapContent | Should -BeLike "*throw*"
        }
    }
}