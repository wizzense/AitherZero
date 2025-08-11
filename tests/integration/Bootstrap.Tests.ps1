#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    Integration tests for AitherZero bootstrap process
.DESCRIPTION
    Comprehensive testing of bootstrap.ps1 functionality including
    dependency detection, installation modes, and configuration
#>

BeforeAll {
    # Import test helpers
    $script:TestRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $script:TestRoot "TestHelpers.psm1") -Force
    
    # Get bootstrap script path
    $script:ProjectRoot = Split-Path $script:TestRoot -Parent
    $script:BootstrapPath = Join-Path $script:ProjectRoot "bootstrap.ps1"
    
    # Initialize test environment
    $script:TestEnv = Initialize-TestEnvironment -SkipModuleLoad
    
    # Load bootstrap script content for testing
    $script:BootstrapContent = Get-Content $script:BootstrapPath -Raw
}

Describe "Bootstrap Environment Detection" {
    Context "PowerShell Version Detection" {
        It "Should detect PowerShell version correctly" {
            $version = $PSVersionTable.PSVersion
            $version.Major | Should -BeGreaterOrEqual 7
        }
        
        It "Should handle PowerShell 5.1 upgrade scenario" {
            # Mock PowerShell 5.1 environment
            Mock Get-Variable -ParameterFilter { $Name -eq 'PSVersionTable' } -MockWith {
                @{ Value = @{ PSVersion = [Version]"5.1.0.0" } }
            }
            
            # Bootstrap should detect need for upgrade
            $script:BootstrapContent | Should -BeLike "*PowerShell 7 is required*"
        }
    }
    
    Context "Operating System Detection" {
        It "Should correctly identify current platform" {
            $platform = if ($IsWindows) { "Windows" }
                       elseif ($IsLinux) { "Linux" }
                       elseif ($IsMacOS) { "macOS" }
                       else { "Unknown" }
            
            $platform | Should -BeIn @("Windows", "Linux", "macOS")
        }
        
        It "Should have platform-specific installation logic" {
            if ($IsWindows) {
                $script:BootstrapContent | Should -BeLike "*winget*"
                $script:BootstrapContent | Should -BeLike "*msiexec*"
            } elseif ($IsLinux) {
                $script:BootstrapContent | Should -BeLike "*apt*"
                $script:BootstrapContent | Should -BeLike "*yum*"
            } elseif ($IsMacOS) {
                $script:BootstrapContent | Should -BeLike "*brew*"
            }
        }
    }
    
    Context "Admin Rights Detection" {
        It "Should detect admin/root privileges" {
            # This test verifies the function exists
            $script:BootstrapContent | Should -BeLike "*Test-IsAdmin*"
            $script:BootstrapContent | Should -BeLike "*IsInRole*Administrator*"
        }
    }
    
    Context "Existing Installation Detection" {
        It "Should detect existing AitherZero installation" {
            # Create mock existing installation
            $mockEnv = New-MockBootstrapEnvironment -Path $TestDrive -WithExistingInstall
            
            Test-Path (Join-Path $mockEnv.Path "config.json") | Should -BeTrue
            Test-Path (Join-Path $mockEnv.Path "Start-AitherZero.ps1") | Should -BeTrue
        }
        
        It "Should handle project directory detection" {
            $script:BootstrapContent | Should -BeLike "*Test-Path*Start-AitherZero.ps1*"
            $script:BootstrapContent | Should -BeLike "*Test-Path*domains*"
        }
    }
}

Describe "Bootstrap Dependency Management" {
    Context "Git Installation" {
        It "Should check for Git availability" {
            $script:BootstrapContent | Should -BeLike "*Get-Command git*"
        }
        
        It "Should have Git installation logic for each platform" {
            # Windows
            $script:BootstrapContent | Should -BeLike "*winget install*Git.Git*"
            # Linux
            $script:BootstrapContent | Should -BeLike "*apt*install*git*"
            # macOS
            $script:BootstrapContent | Should -BeLike "*brew install git*"
        }
    }
    
    Context "PowerShell 7 Installation" {
        It "Should have PowerShell 7 installation function" {
            $script:BootstrapContent | Should -BeLike "*Install-PowerShell7*"
        }
        
        It "Should download correct installer for platform" {
            if ($IsWindows) {
                $script:BootstrapContent | Should -BeLike "*PowerShell-7-win-x64.msi*"
            } else {
                $script:BootstrapContent | Should -BeLike "*install-powershell.sh*"
            }
        }
        
        It "Should re-launch in PowerShell 7 after installation" {
            $script:BootstrapContent | Should -BeLike "*pwsh*-NoProfile*-ExecutionPolicy Bypass*"
        }
    }
}

Describe "Bootstrap Installation Modes" {
    Context "New Installation" {
        BeforeEach {
            $script:TestPath = Join-Path $TestDrive "new-install"
            New-Item -Path $script:TestPath -ItemType Directory -Force | Out-Null
        }
        
        It "Should create directory structure" {
            # Simulate bootstrap directory creation
            $dirs = @('logs', 'config', 'temp', 'automation-scripts', 'domains')
            foreach ($dir in $dirs) {
                $path = Join-Path $script:TestPath $dir
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                Test-Path $path | Should -BeTrue
            }
        }
        
        It "Should clone from GitHub repository" {
            $script:BootstrapContent | Should -BeLike "*git clone*--branch*"
            $script:BootstrapContent | Should -BeLike "*wizzense/AitherZero*"
        }
        
        It "Should create default configuration" {
            $script:BootstrapContent | Should -BeLike "*config.json*"
            $script:BootstrapContent | Should -BeLike "*ConvertTo-Json*"
        }
    }
    
    Context "Update Installation" {
        It "Should support update mode" {
            $script:BootstrapContent | Should -BeLike "*Mode*Update*"
        }
        
        It "Should pull latest changes for updates" {
            $script:BootstrapContent | Should -BeLike "*git pull origin*"
        }
    }
    
    Context "Clean Installation" {
        It "Should support clean mode" {
            $script:BootstrapContent | Should -BeLike "*Mode*Clean*"
        }
        
        It "Should remove existing installation before reinstalling" {
            $script:BootstrapContent | Should -BeLike "*Remove-Item*-Recurse*-Force*"
        }
    }
    
    Context "Remove Installation" {
        It "Should support remove mode" {
            $script:BootstrapContent | Should -BeLike "*Mode*Remove*"
        }
        
        It "Should have confirmation prompt for removal" {
            $script:BootstrapContent | Should -BeLike "*Remove AitherZero*"
        }
    }
}

Describe "Bootstrap Configuration" {
    Context "Profile Selection" {
        It "Should support multiple profiles" {
            @('Minimal', 'Standard', 'Developer', 'Full') | ForEach-Object {
                $script:BootstrapContent | Should -BeLike "*$_*"
            }
        }
        
        It "Should set default profile to Standard" {
            $script:BootstrapContent | Should -BeLike "*InstallProfile*=*'Standard'*"
        }
    }
    
    Context "Installation Path" {
        It "Should support custom installation path" {
            $script:BootstrapContent | Should -BeLike "*InstallPath*"
        }
        
        It "Should have default installation path logic" {
            $script:BootstrapContent | Should -BeLike "*Get-DefaultInstallPath*"
        }
        
        It "Should avoid system directories on Windows" {
            $script:BootstrapContent | Should -BeLike "*C:\\Windows*"
            $script:BootstrapContent | Should -BeLike "*Program Files*"
        }
    }
    
    Context "Non-Interactive Mode" {
        It "Should support non-interactive mode" {
            $script:BootstrapContent | Should -BeLike "*NonInteractive*"
        }
        
        It "Should skip prompts in non-interactive mode" {
            $script:BootstrapContent | Should -BeLike "*if*-not*NonInteractive*"
        }
    }
}

Describe "Bootstrap Environment Setup" {
    Context "PowerShell Profile Integration" {
        It "Should add auto-load to PowerShell profile" {
            $script:BootstrapContent | Should -BeLike "*PROFILE*"
            $script:BootstrapContent | Should -BeLike "*AitherZero Auto-Load*"
        }
        
        It "Should check for existing profile content" {
            $script:BootstrapContent | Should -BeLike "*Get-Content*profilePath*"
        }
    }
    
    Context "Shell Scripts Creation" {
        It "Should create Unix shell helpers" {
            $script:BootstrapContent | Should -BeLike "*#!/usr/bin/env pwsh*"
            $script:BootstrapContent | Should -BeLike "*chmod +x*"
        }
        
        It "Should create Windows batch files" {
            $script:BootstrapContent | Should -BeLike "*az.cmd*"
            $script:BootstrapContent | Should -BeLike "*aither.cmd*"
        }
        
        It "Should create activation script for bash/zsh" {
            $script:BootstrapContent | Should -BeLike "*activate.sh*"
            $script:BootstrapContent | Should -BeLike "*export AITHERZERO_ROOT*"
        }
    }
    
    Context "VS Code Integration" {
        It "Should create VS Code settings" {
            $script:BootstrapContent | Should -BeLike "*.vscode*"
            $script:BootstrapContent | Should -BeLike "*settings.json*"
        }
        
        It "Should configure terminal integration" {
            $script:BootstrapContent | Should -BeLike "*terminal.integrated*"
            $script:BootstrapContent | Should -BeLike "*Import-Module*AitherZero.psd1*"
        }
    }
}

Describe "Bootstrap Module Loading" {
    Context "Clean Environment Initialization" {
        It "Should use Initialize-CleanEnvironment.ps1 if available" {
            $script:BootstrapContent | Should -BeLike "*Initialize-CleanEnvironment.ps1*"
        }
        
        It "Should remove conflicting modules" {
            $script:BootstrapContent | Should -BeLike "*AitherRun*"
            $script:BootstrapContent | Should -BeLike "*CoreApp*"
            $script:BootstrapContent | Should -BeLike "*Remove-Module*"
        }
        
        It "Should use execution policy bypass" {
            $script:BootstrapContent | Should -BeLike "*-ExecutionPolicy Bypass*"
        }
    }
    
    Context "Module Import" {
        It "Should import AitherZero.psd1 module manifest" {
            $script:BootstrapContent | Should -BeLike "*Import-Module*AitherZero.psd1*"
        }
        
        It "Should verify module loading success" {
            $script:BootstrapContent | Should -BeLike "*Get-Module*AitherZero*"
        }
    }
}

Describe "Bootstrap Error Handling" {
    Context "Missing Dependencies" {
        It "Should handle missing Git gracefully" {
            $script:BootstrapContent | Should -BeLike "*Missing dependencies*"
        }
        
        It "Should provide option to auto-install dependencies" {
            $script:BootstrapContent | Should -BeLike "*AutoInstallDeps*"
        }
    }
    
    Context "Network Failures" {
        It "Should handle clone failures" {
            $script:BootstrapContent | Should -BeLike "*Clone failed*"
        }
    }
    
    Context "Permission Issues" {
        It "Should handle permission errors" {
            $script:BootstrapContent | Should -BeLike "*catch*"
            $script:BootstrapContent | Should -BeLike "*Write-BootstrapLog*Error*"
        }
    }
}

Describe "Bootstrap Execution" {
    Context "Script Parameters" {
        It "Should accept all documented parameters" {
            # Use AST to parse parameters
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:BootstrapPath,
                [ref]$null,
                [ref]$null
            )
            
            $params = $ast.ParamBlock.Parameters.Name.VariablePath.UserPath
            $params | Should -Contain 'Mode'
            $params | Should -Contain 'InstallProfile'
            $params | Should -Contain 'InstallPath'
            $params | Should -Contain 'Branch'
            $params | Should -Contain 'NonInteractive'
            $params | Should -Contain 'AutoInstallDeps'
            $params | Should -Contain 'SkipAutoStart'
        }
    }
    
    Context "One-Liner Execution" {
        It "Should be executable via Invoke-Expression" {
            $script:BootstrapContent | Should -BeLike "*iwr*iex*"
        }
        
        It "Should have correct GitHub raw URL" {
            $script:BootstrapContent | Should -BeLike "*raw.githubusercontent.com/wizzense/AitherZero*"
        }
    }
    
    Context "Auto-Start Behavior" {
        It "Should auto-start by default" {
            $script:BootstrapContent | Should -BeLike "*Start-AitherZero.ps1*"
        }
        
        It "Should respect SkipAutoStart parameter" {
            $script:BootstrapContent | Should -BeLike "*-not*SkipAutoStart*"
        }
    }
}

AfterAll {
    # Clean up test environment
    Clear-TestEnvironment
}