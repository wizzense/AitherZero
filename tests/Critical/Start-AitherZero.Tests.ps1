#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:LauncherPath = Join-Path $PSScriptRoot '../../Start-AitherZero.ps1'
    $script:ProjectRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
}

Describe 'AitherZero Launcher Critical Infrastructure Tests' -Tag 'Critical' {
    BeforeAll {
        # Store original environment
        $script:OriginalLocation = Get-Location
        $script:TestRoot = Join-Path $TestDrive 'AitherZeroLauncher'
        New-Item -Path $script:TestRoot -ItemType Directory -Force | Out-Null
        
        # Mock external commands that the launcher checks
        function Mock-ExternalCommand {
            param($Command, $Response, $ExitCode = 0)
            
            $mockPath = Join-Path $script:TestRoot "$Command.ps1"
            if ($Response) {
                @"
Write-Output '$Response'
exit $ExitCode
"@ | Set-Content $mockPath
            } else {
                "exit $ExitCode" | Set-Content $mockPath
            }
            
            # Add to PATH
            $env:PATH = "$script:TestRoot;$env:PATH"
        }
        
        # Create test environment structure
        $script:TestProjectRoot = Join-Path $script:TestRoot 'project'
        $script:TestCoreDir = Join-Path $script:TestProjectRoot 'aither-core'
        $script:TestModulesDir = Join-Path $script:TestCoreDir 'modules'
        $script:TestSharedDir = Join-Path $script:TestCoreDir 'shared'
        
        New-Item -Path $script:TestProjectRoot -ItemType Directory -Force | Out-Null
        New-Item -Path $script:TestCoreDir -ItemType Directory -Force | Out-Null
        New-Item -Path $script:TestModulesDir -ItemType Directory -Force | Out-Null
        New-Item -Path $script:TestSharedDir -ItemType Directory -Force | Out-Null
        
        # Create mock launcher
        $script:TestLauncher = Join-Path $script:TestProjectRoot 'Start-AitherZero.ps1'
        Copy-Item $script:LauncherPath $script:TestLauncher -Force
        
        # Create mock core script
        $script:TestCoreScript = Join-Path $script:TestCoreDir 'aither-core.ps1'
        @'
param(
    [string]$Verbosity = 'normal',
    [string]$ConfigFile,
    [string]$Scripts,
    [switch]$Auto,
    [switch]$Force,
    [switch]$NonInteractive,
    [switch]$Quiet,
    [switch]$WhatIf,
    [string]$UIMode
)

Write-Host "AitherZero Core Script Executed Successfully"
Write-Host "Parameters received:"
$PSBoundParameters.GetEnumerator() | ForEach-Object {
    Write-Host "  $($_.Key): $($_.Value)"
}
exit 0
'@ | Set-Content $script:TestCoreScript
        
        # Create mock bootstrap script
        $script:TestBootstrap = Join-Path $script:TestCoreDir 'aither-core-bootstrap.ps1'
        @'
param($Verbosity, $ConfigFile, $Scripts, [switch]$Auto, [switch]$Force, [switch]$NonInteractive, [switch]$Quiet, [switch]$WhatIf)
Write-Host "Bootstrap Script Executed for PowerShell 5.1 Compatibility"
exit 0
'@ | Set-Content $script:TestBootstrap
        
        # Create Find-ProjectRoot utility
        $script:FindProjectRoot = Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1'
        @"
function Find-ProjectRoot {
    param([string]`$StartPath)
    return '$script:TestProjectRoot'
}
"@ | Set-Content $script:FindProjectRoot
        
        Set-Location $script:TestProjectRoot
    }
    
    AfterAll {
        Set-Location $script:OriginalLocation
        # Restore PATH
        $env:PATH = $env:PATH -replace [regex]::Escape("$script:TestRoot;"), ""
        Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Help System and Parameter Validation' {
        It 'Should display help information' {
            $result = & $script:TestLauncher -Help
            
            $output = $result -join "`n"
            $output | Should -Match 'AitherZero Usage:'
            $output | Should -Match 'Modes:'
            $output | Should -Match '-Setup'
            $output | Should -Match '-Interactive'
            $output | Should -Match '-Auto'
            $output | Should -Match 'Examples:'
        }
        
        It 'Should display banner and version' {
            $result = & $script:TestLauncher -Help
            
            $output = $result -join "`n"
            $output | Should -Match 'AitherZero Infrastructure Automation Framework'
            $output | Should -Match 'Cross-Platform Infrastructure Automation with OpenTofu/Terraform'
        }
        
        It 'Should validate InstallationProfile parameter' {
            # Valid profiles should not throw
            { & $script:TestLauncher -Setup -InstallationProfile 'minimal' -WhatIf } | Should -Not -Throw
            { & $script:TestLauncher -Setup -InstallationProfile 'developer' -WhatIf } | Should -Not -Throw
            { & $script:TestLauncher -Setup -InstallationProfile 'full' -WhatIf } | Should -Not -Throw
            
            # Invalid profile should throw
            { & $script:TestLauncher -Setup -InstallationProfile 'invalid' -WhatIf } | Should -Throw
        }
        
        It 'Should validate Verbosity parameter' {
            { & $script:TestLauncher -Verbosity 'silent' -WhatIf } | Should -Not -Throw
            { & $script:TestLauncher -Verbosity 'normal' -WhatIf } | Should -Not -Throw
            { & $script:TestLauncher -Verbosity 'detailed' -WhatIf } | Should -Not -Throw
            { & $script:TestLauncher -Verbosity 'invalid' -WhatIf } | Should -Throw
        }
    }
    
    Context 'Setup Mode Execution' {
        BeforeEach {
            # Mock external tools
            Mock-ExternalCommand 'git' 'git version 2.40.0'
            Mock-ExternalCommand 'tofu' 'OpenTofu v1.6.0'
        }
        
        It 'Should execute basic setup mode' {
            $result = & $script:TestLauncher -Setup
            
            $output = $result -join "`n"
            $output | Should -Match 'First-Time Setup'
            $output | Should -Match 'PowerShell.*detected'
            $output | Should -Match 'Git detected'
            $output | Should -Match 'OpenTofu detected'
            $output | Should -Match 'Setup Complete'
        }
        
        It 'Should handle missing dependencies in setup' {
            # Remove git from PATH
            $env:PATH = $env:PATH -replace [regex]::Escape("$script:TestRoot;"), ""
            
            $result = & $script:TestLauncher -Setup
            
            $output = $result -join "`n"
            $output | Should -Match 'Git not found'
            $output | Should -Match 'required for PatchManager'
        }
        
        It 'Should use SetupWizard when available' {
            # Create mock SetupWizard module
            $setupWizardDir = Join-Path $script:TestModulesDir 'SetupWizard'
            New-Item -Path $setupWizardDir -ItemType Directory -Force | Out-Null
            
            $setupWizardScript = Join-Path $setupWizardDir 'SetupWizard.psm1'
            @'
function Start-IntelligentSetup {
    param($InstallationProfile)
    Write-Host "Intelligent Setup Wizard Executed"
    return @{ Errors = @() }
}
Export-ModuleMember -Function Start-IntelligentSetup
'@ | Set-Content $setupWizardScript
            
            $result = & $script:TestLauncher -Setup -InstallationProfile 'developer'
            
            $output = $result -join "`n"
            $output | Should -Match 'Starting Intelligent Setup Wizard'
            $output | Should -Match 'Intelligent Setup Wizard Executed'
        }
    }
    
    Context 'PowerShell Version Compatibility' {
        It 'Should detect PowerShell 7+ and show full compatibility message' {
            # This test runs on PowerShell 7+ so should show full compatibility
            $result = & $script:TestLauncher -Setup
            
            $output = $result -join "`n"
            $output | Should -Match 'PowerShell.*detected - Full compatibility'
        }
        
        It 'Should handle PowerShell version detection' {
            # Simulate version check by examining the script logic
            $launcherContent = Get-Content $script:TestLauncher -Raw
            $launcherContent | Should -Match '\$psVersion = \$PSVersionTable\.PSVersion\.Major'
            $launcherContent | Should -Match 'if \(\$psVersion -lt 7\)'
        }
        
        It 'Should use bootstrap script for PowerShell 5.1' {
            # The launcher should have logic to detect and use bootstrap
            $launcherContent = Get-Content $script:TestLauncher -Raw
            $launcherContent | Should -Match 'aither-core-bootstrap\.ps1'
            $launcherContent | Should -Match 'PowerShell.*detected - using compatibility bootstrap'
        }
    }
    
    Context 'Module Discovery and Loading' {
        BeforeEach {
            # Create test modules
            @('TestModule1', 'TestModule2', 'BrokenModule') | ForEach-Object {
                $moduleDir = Join-Path $script:TestModulesDir $_
                New-Item -Path $moduleDir -ItemType Directory -Force | Out-Null
                
                if ($_ -eq 'BrokenModule') {
                    # Create a module that will fail to load
                    "throw 'Module load error'" | Set-Content (Join-Path $moduleDir "$_.psm1")
                } else {
                    # Create a valid module
                    @"
function Test-$_ { return '$_ loaded successfully' }
Export-ModuleMember -Function Test-$_
"@ | Set-Content (Join-Path $moduleDir "$_.psm1")
                }
            }
        }
        
        It 'Should discover and load modules successfully' {
            $result = & $script:TestLauncher -Auto
            
            $output = $result -join "`n"
            $output | Should -Match 'Loading AitherZero modules'
            $output | Should -Match 'TestModule1'
            $output | Should -Match 'TestModule2'
            $output | Should -Match 'Loaded.*modules successfully'
        }
        
        It 'Should handle module loading failures gracefully' {
            $result = & $script:TestLauncher -Auto
            
            $output = $result -join "`n"
            $output | Should -Match 'BrokenModule.*Module load error'
        }
        
        It 'Should handle missing modules directory' {
            Remove-Item $script:TestModulesDir -Recurse -Force
            
            $result = & $script:TestLauncher -Auto
            
            $output = $result -join "`n"
            $output | Should -Match 'Modules directory not found'
            $output | Should -Match 'Some advanced features may not be available'
        }
    }
    
    Context 'Core Script Discovery and Execution' {
        It 'Should find core script in standard location' {
            $result = & $script:TestLauncher -Auto -Verbosity 'detailed'
            
            $output = $result -join "`n"
            $output | Should -Match 'AitherZero Core Script Executed Successfully'
            $output | Should -Match 'Verbosity: detailed'
        }
        
        It 'Should pass parameters correctly to core script' {
            $result = & $script:TestLauncher -Auto -Verbosity 'silent' -Force -NonInteractive
            
            $output = $result -join "`n"
            $output | Should -Match 'Verbosity: silent'
            $output | Should -Match 'Auto: True'
            $output | Should -Match 'Force: True'
            $output | Should -Match 'NonInteractive: True'
        }
        
        It 'Should handle missing core script gracefully' {
            Remove-Item $script:TestCoreScript -Force
            
            { & $script:TestLauncher -Auto } | Should -Throw
            
            # Should provide helpful troubleshooting information
            try {
                & $script:TestLauncher -Auto
            } catch {
                $errorOutput = $_.Exception.Message
                $errorOutput | Should -Match 'Core application file not found'
            }
        }
        
        It 'Should use Find-ProjectRoot utility when available' {
            # The launcher should attempt to use Find-ProjectRoot
            $launcherContent = Get-Content $script:TestLauncher -Raw
            $launcherContent | Should -Match 'Find-ProjectRoot'
            $launcherContent | Should -Match '\$projectRoot = Find-ProjectRoot'
        }
    }
    
    Context 'Enhanced Startup Experience' {
        BeforeEach {
            # Create mock StartupExperience module
            $startupDir = Join-Path $script:TestModulesDir 'StartupExperience'
            New-Item -Path $startupDir -ItemType Directory -Force | Out-Null
            
            $startupScript = Join-Path $startupDir 'StartupExperience.psm1'
            @'
function Get-StartupMode {
    param($Parameters)
    return @{ UseEnhancedUI = $true }
}

function Start-InteractiveMode {
    param($Profile, [switch]$SkipLicenseCheck)
    Write-Host "Enhanced Interactive Mode Started"
    Write-Host "Profile: $Profile"
    Write-Host "SkipLicenseCheck: $SkipLicenseCheck"
}

Export-ModuleMember -Function Get-StartupMode, Start-InteractiveMode
'@ | Set-Content $startupScript
        }
        
        It 'Should use enhanced startup for Interactive mode' {
            $result = & $script:TestLauncher -Interactive
            
            $output = $result -join "`n"
            $output | Should -Match 'Enhanced Interactive Mode Started'
        }
        
        It 'Should use enhanced startup for Quickstart mode' {
            $result = & $script:TestLauncher -Quickstart
            
            $output = $result -join "`n"
            $output | Should -Match 'Quickstart Experience'
            $output | Should -Match 'Enhanced interactive mode enabled'
            $output | Should -Match 'Enhanced Interactive Mode Started'
        }
        
        It 'Should fallback to traditional mode when enhanced startup fails' {
            # Create a failing StartupExperience module
            $startupDir = Join-Path $script:TestModulesDir 'StartupExperience'
            $startupScript = Join-Path $startupDir 'StartupExperience.psm1'
            "throw 'Startup failed'" | Set-Content $startupScript
            
            $result = & $script:TestLauncher -Interactive
            
            $output = $result -join "`n"
            $output | Should -Match 'Enhanced startup failed'
            $output | Should -Match 'Falling back to traditional mode'
            $output | Should -Match 'AitherZero Core Script Executed Successfully'
        }
    }
    
    Context 'License Management Integration' {
        BeforeEach {
            # Create mock LicenseManager module
            $licenseDir = Join-Path $script:TestModulesDir 'LicenseManager'
            New-Item -Path $licenseDir -ItemType Directory -Force | Out-Null
            
            $licenseScript = Join-Path $licenseDir 'LicenseManager.psm1'
            @'
function Set-License {
    param($LicenseKey)
    if ($LicenseKey -eq 'valid-license') {
        Write-Host "License applied successfully"
    } else {
        throw "Invalid license key"
    }
}
Export-ModuleMember -Function Set-License
'@ | Set-Content $licenseScript
        }
        
        It 'Should apply valid license successfully' {
            $result = & $script:TestLauncher -ApplyLicense 'valid-license' -Auto
            
            $output = $result -join "`n"
            $output | Should -Match 'Applying license'
            $output | Should -Match 'License applied successfully'
        }
        
        It 'Should handle invalid license gracefully' {
            $result = & $script:TestLauncher -ApplyLicense 'invalid-license' -Auto
            
            $output = $result -join "`n"
            $output | Should -Match 'Failed to apply license'
        }
    }
    
    Context 'Error Handling and Troubleshooting' {
        It 'Should provide troubleshooting information on core script failure' {
            # Make core script fail
            "exit 1" | Set-Content $script:TestCoreScript
            
            try {
                & $script:TestLauncher -Auto
            } catch {
                $errorOutput = $_.Exception.Message
                $errorOutput | Should -Match 'Core application exited with code: 1'
            }
        }
        
        It 'Should show PowerShell 7 installation guidance for older versions' {
            $launcherContent = Get-Content $script:TestLauncher -Raw
            $launcherContent | Should -Match 'https://aka.ms/powershell-release-windows'
            $launcherContent | Should -Match 'winget install Microsoft.PowerShell'
            $launcherContent | Should -Match 'choco install powershell-core'
        }
        
        It 'Should provide comprehensive error context' {
            Remove-Item $script:TestCoreScript -Force
            
            try {
                & $script:TestLauncher -Auto
            } catch {
                # Error handling should provide context
                $launcherContent = Get-Content $script:TestLauncher -Raw
                $launcherContent | Should -Match 'Troubleshooting Steps:'
                $launcherContent | Should -Match 'Try setup mode'
                $launcherContent | Should -Match 'Get help'
                $launcherContent | Should -Match 'Check PowerShell version'
            }
        }
    }
    
    Context 'Script Execution Modes' {
        It 'Should handle Scripts parameter correctly' {
            $result = & $script:TestLauncher -Scripts 'LabRunner','BackupManager' -Auto
            
            $output = $result -join "`n"
            $output | Should -Match 'Scripts: LabRunner,BackupManager'
        }
        
        It 'Should handle WhatIf mode' {
            $result = & $script:TestLauncher -WhatIf -Auto
            
            $output = $result -join "`n"
            $output | Should -Match 'WhatIf: True'
        }
        
        It 'Should handle ConfigFile parameter' {
            $configPath = Join-Path $script:TestRoot 'test-config.json'
            '{}' | Set-Content $configPath
            
            $result = & $script:TestLauncher -ConfigFile $configPath -Auto
            
            $output = $result -join "`n"
            $output | Should -Match "ConfigFile: $configPath"
        }
    }
    
    Context 'Exit Code Handling' {
        It 'Should exit with 0 on successful execution' {
            $process = Start-Process -FilePath 'pwsh' -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script:TestLauncher, '-Auto'
            ) -Wait -PassThru -WindowStyle Hidden
            
            $process.ExitCode | Should -Be 0
        }
        
        It 'Should exit with 1 on core script failure' {
            # Make core script fail
            "exit 1" | Set-Content $script:TestCoreScript
            
            $process = Start-Process -FilePath 'pwsh' -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script:TestLauncher, '-Auto'
            ) -Wait -PassThru -WindowStyle Hidden
            
            $process.ExitCode | Should -Be 1
        }
    }
}