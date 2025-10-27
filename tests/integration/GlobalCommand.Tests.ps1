#Requires -Version 7.0

Describe "Global Command Installation" {
    BeforeAll {
        $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $script:InstallScript = Join-Path $script:ProjectRoot "tools/Install-GlobalCommand.ps1"
        $script:LauncherScript = Join-Path $script:ProjectRoot "tools/aitherzero-launcher.ps1"
        
        # Determine platform-specific paths
        $script:IsWindowsPlatform = $IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6)
        if ($script:IsWindowsPlatform) {
            $script:ExpectedBinPath = Join-Path $env:LOCALAPPDATA "AitherZero\bin"
        } else {
            $script:ExpectedBinPath = Join-Path $HOME ".local/bin"
        }
    }

    Context "Installation Script Validation" {
        It "Install-GlobalCommand.ps1 should exist" {
            Test-Path $script:InstallScript | Should -Be $true
        }

        It "Install-GlobalCommand.ps1 should be valid PowerShell" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $script:InstallScript -Raw), 
                [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It "Install-GlobalCommand.ps1 should have Install action" {
            $content = Get-Content $script:InstallScript -Raw
            $content | Should -Match "function Install-GlobalCommand"
        }

        It "Install-GlobalCommand.ps1 should have Uninstall action" {
            $content = Get-Content $script:InstallScript -Raw
            $content | Should -Match "function Uninstall-GlobalCommand"
        }

        It "Install-GlobalCommand.ps1 should handle PATH management" {
            $content = Get-Content $script:InstallScript -Raw
            $content | Should -Match "Add-ToUserPath|SetEnvironmentVariable"
        }
    }

    Context "Launcher Script Validation" {
        It "aitherzero-launcher.ps1 should exist" {
            Test-Path $script:LauncherScript | Should -Be $true
        }

        It "aitherzero-launcher.ps1 should be valid PowerShell" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $script:LauncherScript -Raw), 
                [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It "aitherzero-launcher.ps1 should have Find-AitherZeroInstallation function" {
            $content = Get-Content $script:LauncherScript -Raw
            $content | Should -Match "function Find-AitherZeroInstallation"
        }

        It "aitherzero-launcher.ps1 should check AITHERZERO_ROOT" {
            $content = Get-Content $script:LauncherScript -Raw
            $content | Should -Match 'AITHERZERO_ROOT'
        }

        It "aitherzero-launcher.ps1 should forward arguments to Start-AitherZero.ps1" {
            $content = Get-Content $script:LauncherScript -Raw
            $content | Should -Match "Start-AitherZero\.ps1"
        }
    }

    Context "Installation Simulation (WhatIf)" {
        It "Should run installation with -WhatIf without errors" {
            { & $script:InstallScript -Action Install -InstallPath $script:ProjectRoot -WhatIf } | 
                Should -Not -Throw
        }

        It "Should identify correct bin path for platform" {
            $output = & $script:InstallScript -Action Install -InstallPath $script:ProjectRoot -WhatIf -Verbose 4>&1
            $verboseOutput = $output | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseOutput | Should -Match $script:ExpectedBinPath
        }
    }

    Context "Launcher Logic Validation" {
        It "Should handle AITHERZERO_ROOT environment variable" {
            # Mock environment and test
            $originalRoot = $env:AITHERZERO_ROOT
            try {
                $env:AITHERZERO_ROOT = $script:ProjectRoot
                
                # Source the launcher to test its functions
                $launcherContent = Get-Content $script:LauncherScript -Raw
                
                # Extract the Find-AitherZeroInstallation function
                if ($launcherContent -match '(?s)function Find-AitherZeroInstallation \{(.+?)\n\}') {
                    $functionBody = $matches[1]
                    # Basic check that it would use AITHERZERO_ROOT
                    $functionBody | Should -Match 'AITHERZERO_ROOT'
                }
            } finally {
                $env:AITHERZERO_ROOT = $originalRoot
            }
        }

        It "Should check common installation paths" {
            $content = Get-Content $script:LauncherScript -Raw
            $content | Should -Match 'AitherZero'  # Should check for AitherZero in home directory
            $content | Should -Match 'possiblePaths'  # Should have a list of possible paths
        }

        It "Should provide helpful error message when installation not found" {
            $content = Get-Content $script:LauncherScript -Raw
            $content | Should -Match 'installation not found'
            $content | Should -Match 'bootstrap\.ps1'  # Should mention how to install
        }
    }

    Context "Integration with Bootstrap" {
        It "bootstrap.ps1 should reference Install-GlobalCommand" {
            $bootstrapPath = Join-Path $script:ProjectRoot "bootstrap.ps1"
            $content = Get-Content $bootstrapPath -Raw
            $content | Should -Match "Install-GlobalCommand"
        }

        It "bootstrap.ps1 should call Install-GlobalCommand after installation" {
            $bootstrapPath = Join-Path $script:ProjectRoot "bootstrap.ps1"
            $content = Get-Content $bootstrapPath -Raw
            # Should have logic to run the install script
            $content | Should -Match "tools/Install-GlobalCommand\.ps1"
        }

        It "bootstrap.ps1 should uninstall global command during removal" {
            $bootstrapPath = Join-Path $script:ProjectRoot "bootstrap.ps1"
            $content = Get-Content $bootstrapPath -Raw
            $content | Should -Match "Uninstall.*global.*command|Remove.*global.*command"
        }
    }

    Context "Cross-Platform Support" {
        It "Should handle Windows-specific paths" {
            $content = Get-Content $script:InstallScript -Raw
            $content | Should -Match "IsWindows|IsWindowsPlatform"
            $content | Should -Match "\.cmd"  # Windows batch file wrapper
        }

        It "Should handle Linux/macOS paths" {
            $content = Get-Content $script:InstallScript -Raw
            # Script should handle Unix systems without explicit $IsLinux/$IsMacOS variables
            $content | Should -Match "\.local/bin|chmod"
        }

        It "Should manage PATH appropriately for each platform" {
            $content = Get-Content $script:InstallScript -Raw
            # Windows uses registry, Unix uses shell profiles
            $content | Should -Match "SetEnvironmentVariable|bashrc|zshrc"
        }

        It "Should handle shell profiles on Unix" {
            $content = Get-Content $script:InstallScript -Raw
            $content | Should -Match "\.bashrc"
            $content | Should -Match "\.zshrc"
            $content | Should -Match "\.profile"
        }
    }

    Context "Documentation" {
        It "README.md should document the global command" {
            $readmePath = Join-Path $script:ProjectRoot "README.md"
            $content = Get-Content $readmePath -Raw
            $content | Should -Match "aitherzero.*command|global.*command"
        }

        It "README.md should explain how to use global command" {
            $readmePath = Join-Path $script:ProjectRoot "README.md"
            $content = Get-Content $readmePath -Raw
            $content | Should -Match "aitherzero.*-Mode|aitherzero from anywhere"
        }

        It "README.md should document uninstallation" {
            $readmePath = Join-Path $script:ProjectRoot "README.md"
            $content = Get-Content $readmePath -Raw
            $content | Should -Match "Uninstall|Remove.*global.*command"
        }
    }
}
