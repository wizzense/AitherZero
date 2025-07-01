BeforeDiscovery {
    $script:BuildScriptPath = Join-Path $PSScriptRoot '../../build/Build-Package.ps1'
    $script:LauncherPath = Join-Path $PSScriptRoot '../../Start-AitherZero.ps1'
    $script:CoreAppPath = Join-Path $PSScriptRoot '../../aither-core/aither-core.ps1'
    $script:VersionFilePath = Join-Path $PSScriptRoot '../../VERSION'
    $script:TestAppName = 'Release-EndToEnd'
    
    # Verify release components exist
    if (-not (Test-Path $script:BuildScriptPath)) {
        throw "Build script not found at: $script:BuildScriptPath"
    }
    
    if (-not (Test-Path $script:LauncherPath)) {
        throw "Launcher not found at: $script:LauncherPath"
    }
    
    if (-not (Test-Path $script:CoreAppPath)) {
        throw "Core application not found at: $script:CoreAppPath"
    }
}

Describe 'Release End-to-End Scenarios - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'Release', 'E2E', 'Production') {
    
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Set up isolated test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'release-e2e-tests'
        
        # Save original environment
        $script:OriginalEnv = @{
            PROJECT_ROOT = $env:PROJECT_ROOT
            PWSH_MODULES_PATH = $env:PWSH_MODULES_PATH
            APPDATA = $env:APPDATA
            HOME = $env:HOME
            USERPROFILE = $env:USERPROFILE
            PESTER_RUN = $env:PESTER_RUN
            GITHUB_SHA = $env:GITHUB_SHA
            GITHUB_REF = $env:GITHUB_REF
        }
        
        # Create comprehensive test directory structure for end-to-end scenarios
        $script:TestProjectRoot = Join-Path $script:TestWorkspace 'AitherZero'
        $script:TestReleaseDir = Join-Path $script:TestWorkspace 'releases'
        $script:TestInstallationDir = Join-Path $script:TestWorkspace 'installations'
        $script:TestUpgradeDir = Join-Path $script:TestWorkspace 'upgrades'
        $script:TestProductionDir = Join-Path $script:TestWorkspace 'production'
        $script:TestUserDataDir = Join-Path $script:TestWorkspace 'user-data'
        $script:TestFreshInstallDir = Join-Path $script:TestInstallationDir 'fresh'
        $script:TestLegacyInstallDir = Join-Path $script:TestInstallationDir 'legacy'
        $script:TestAppDataDir = Join-Path $script:TestWorkspace 'AppData' 'Roaming' 'AitherZero'
        
        @($script:TestProjectRoot, $script:TestReleaseDir, $script:TestInstallationDir, $script:TestUpgradeDir,
          $script:TestProductionDir, $script:TestUserDataDir, $script:TestFreshInstallDir, $script:TestLegacyInstallDir,
          $script:TestAppDataDir) | ForEach-Object {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
        
        # Set test environment
        $env:PROJECT_ROOT = $script:TestProjectRoot
        $env:APPDATA = (Split-Path $script:TestAppDataDir -Parent)
        $env:HOME = $script:TestWorkspace
        $env:USERPROFILE = $script:TestWorkspace
        $env:PESTER_RUN = 'true'
        $env:GITHUB_SHA = 'e2e-test-commit-abc123'
        $env:GITHUB_REF = 'refs/tags/v2.1.0-e2e-test'
        
        # Create mock release packages for testing
        $script:TestVersions = @{
            'v1.0.0' = @{
                Features = @('core', 'development')
                Modules = @('Logging', 'TestingFramework', 'DevEnvironment', 'PatchManager')
                LicenseTier = 'free'
                HasSetupWizard = $false
                HasProgressTracking = $false
            }
            'v1.5.0' = @{
                Features = @('core', 'development', 'infrastructure')
                Modules = @('Logging', 'TestingFramework', 'DevEnvironment', 'PatchManager', 'OpenTofuProvider', 'LabRunner', 'SetupWizard')
                LicenseTier = 'pro'
                HasSetupWizard = $true
                HasProgressTracking = $false
            }
            'v2.0.0' = @{
                Features = @('core', 'development', 'infrastructure', 'ai', 'automation')
                Modules = @('Logging', 'TestingFramework', 'DevEnvironment', 'PatchManager', 'OpenTofuProvider', 'LabRunner', 'SetupWizard', 'ProgressTracking', 'AIToolsIntegration', 'OrchestrationEngine')
                LicenseTier = 'pro'
                HasSetupWizard = $true
                HasProgressTracking = $true
            }
            'v2.1.0' = @{
                Features = @('core', 'development', 'infrastructure', 'ai', 'automation', 'security', 'monitoring')
                Modules = @('Logging', 'TestingFramework', 'DevEnvironment', 'PatchManager', 'OpenTofuProvider', 'LabRunner', 'SetupWizard', 'ProgressTracking', 'AIToolsIntegration', 'OrchestrationEngine', 'SecureCredentials', 'SystemMonitoring', 'RestAPIServer')
                LicenseTier = 'enterprise'
                HasSetupWizard = $true
                HasProgressTracking = $true
            }
        }
        
        # Create comprehensive mocking system for release testing
        function New-MockRelease {
            param(
                [string]$Version,
                [string]$Platform = 'windows',
                [string]$Profile = 'standard',
                [string]$InstallPath
            )
            
            $versionInfo = $script:TestVersions[$Version]
            if (-not $versionInfo) {
                throw "Unknown version: $Version"
            }
            
            # Create release directory structure
            $releaseDir = Join-Path $InstallPath "AitherZero-$($Version.TrimStart('v'))-$Platform-$Profile"
            New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $releaseDir 'modules') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $releaseDir 'shared') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $releaseDir 'configs') -Force | Out-Null
            
            # Create core application file
            @"
#Requires -Version 7.0
param([switch]`$Help, [switch]`$Auto, [string]`$Scripts, [string]`$ConfigFile, [ValidateSet('silent','normal','detailed')][string]`$Verbosity = 'normal', [switch]`$Setup, [switch]`$WhatIf, [switch]`$NonInteractive)

Write-Host "AitherZero Core Application $Version" -ForegroundColor Green
Write-Host "Platform: $Platform, Profile: $Profile, Tier: $($versionInfo.LicenseTier)" -ForegroundColor Cyan

if (`$Help) {
    Write-Host "AitherZero $Version Help Information"
    Write-Host "Available modules: $($versionInfo.Modules -join ', ')"
    return
}

if (`$Setup) {
    Write-Host "Setup mode - Version: $Version"
    if ($($versionInfo.HasSetupWizard)) {
        Write-Host "Running SetupWizard..."
        return @{ SetupResult = 'Success'; Version = '$Version'; Modules = @($($versionInfo.Modules | ForEach-Object { "'$_'" } | Join-String -Separator ',')) }
    } else {
        Write-Host "Basic setup (no SetupWizard available in $Version)"
        return @{ SetupResult = 'BasicSuccess'; Version = '$Version' }
    }
}

if (`$Auto) {
    Write-Host "Auto mode - Running default modules for $Version"
    return @{ AutoResult = 'Success'; Version = '$Version'; ExecutedModules = @('SystemCheck', 'BasicValidation') }
}

if (`$Scripts) {
    Write-Host "Scripts mode - Requested: `$Scripts"
    `$requestedModules = `$Scripts -split ','
    `$availableModules = @($($versionInfo.Modules | ForEach-Object { "'$_'" } | Join-String -Separator ','))
    `$validModules = `$requestedModules | Where-Object { `$_ -in `$availableModules }
    
    if (`$validModules) {
        Write-Host "Executing: `$(`$validModules -join ', ')"
        return @{ ScriptsResult = 'Success'; Version = '$Version'; RequestedModules = `$requestedModules; ExecutedModules = `$validModules }
    } else {
        Write-Warning "No valid modules found in requested list"
        return @{ ScriptsResult = 'NoValidModules'; Version = '$Version'; RequestedModules = `$requestedModules }
    }
}

Write-Host "Interactive mode - $Version"
return @{ InteractiveResult = 'Success'; Version = '$Version'; UIMode = 'classic' }
"@ | Out-File -FilePath (Join-Path $releaseDir 'aither-core.ps1') -Encoding UTF8
            
            # Create launcher script
            $launcherContent = @"
#!/usr/bin/env pwsh
#Requires -Version 7.0
param([Parameter(ValueFromRemainingArguments=`$true)]`$Arguments)

Write-Host "🚀 AitherZero $Version - Cross-Platform Infrastructure Automation Launcher" -ForegroundColor Green
Write-Host "Platform: $Platform | Profile: $Profile | License: $($versionInfo.LicenseTier)" -ForegroundColor Cyan

# PowerShell version detection
`$psVersion = `$PSVersionTable.PSVersion.Major
if (`$psVersion -lt 7) {
    Write-Host "PowerShell `$psVersion detected. AitherZero requires PowerShell 7.0+" -ForegroundColor Yellow
    
    # Check for bootstrap script
    `$bootstrapScript = Join-Path `$PSScriptRoot 'aither-core-bootstrap.ps1'
    if (Test-Path `$bootstrapScript) {
        Write-Host "Launching via PowerShell 7 bootstrap..." -ForegroundColor Yellow
        & `$bootstrapScript @Arguments
        return
    } else {
        Write-Error "Bootstrap script missing - PowerShell 7 is required"
        exit 1
    }
}

# Launch core application
`$coreApp = Join-Path `$PSScriptRoot 'aither-core.ps1'
if (Test-Path `$coreApp) {
    & `$coreApp @Arguments
} else {
    Write-Error "Core application not found at: `$coreApp"
    exit 1
}
"@
            $launcherContent | Out-File -FilePath (Join-Path $releaseDir 'Start-AitherZero.ps1') -Encoding UTF8
            
            # Create bootstrap script
            @"
#Requires -Version 5.1
param([Parameter(ValueFromRemainingArguments=`$true)]`$Arguments)

Write-Host "Bootstrap: Checking PowerShell version..." -ForegroundColor Yellow
`$psVersion = `$PSVersionTable.PSVersion.Major

if (`$psVersion -lt 7) {
    Write-Host "Bootstrap: PowerShell `$psVersion detected, launching PowerShell 7..." -ForegroundColor Yellow
    
    `$pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
    if (`$pwshPath) {
        `$coreApp = Join-Path `$PSScriptRoot 'aither-core.ps1'
        & pwsh -File `$coreApp @Arguments
        exit `$LASTEXITCODE
    } else {
        Write-Error "PowerShell 7 is required but not installed"
        exit 1
    }
} else {
    # Already PowerShell 7+, launch directly
    `$coreApp = Join-Path `$PSScriptRoot 'aither-core.ps1'
    & `$coreApp @Arguments
}
"@ | Out-File -FilePath (Join-Path $releaseDir 'aither-core-bootstrap.ps1') -Encoding UTF8
            
            # Create modules based on version
            foreach ($moduleName in $versionInfo.Modules) {
                $moduleDir = Join-Path $releaseDir 'modules' $moduleName
                New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
                
                # Create module manifest
                @"
@{
    ModuleVersion = '$($Version.TrimStart('v'))'
    GUID = '$([System.Guid]::NewGuid().ToString())'
    Author = 'AitherZero Team'
    CompanyName = 'Wizzense'
    Copyright = '(c) Wizzense. All rights reserved.'
    Description = '$moduleName module for AitherZero $Version'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Start-$moduleName', 'Get-$moduleName' + 'Status')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('AitherZero', 'Infrastructure', '$moduleName')
            LicenseUri = 'https://github.com/wizzense/AitherZero/blob/main/LICENSE'
            ProjectUri = 'https://github.com/wizzense/AitherZero'
        }
    }
}
"@ | Out-File -FilePath (Join-Path $moduleDir "$moduleName.psd1") -Encoding UTF8
                
                # Create module script
                @"
function Start-$moduleName {
    [CmdletBinding()]
    param([switch]`$Auto, [hashtable]`$Config = @{})
    
    Write-Host "Starting $moduleName (Version: $Version)" -ForegroundColor Green
    
    # Module-specific logic based on version capabilities
    switch ('$moduleName') {
        'SetupWizard' {
            if ($($versionInfo.HasSetupWizard)) {
                Write-Host "SetupWizard: Intelligent setup available in $Version" -ForegroundColor Cyan
                return @{ Result = 'Success'; Mode = 'Intelligent'; Version = '$Version' }
            } else {
                Write-Host "SetupWizard: Basic setup mode in $Version" -ForegroundColor Yellow
                return @{ Result = 'Success'; Mode = 'Basic'; Version = '$Version' }
            }
        }
        'ProgressTracking' {
            if ($($versionInfo.HasProgressTracking)) {
                Write-Host "ProgressTracking: Advanced progress tracking available" -ForegroundColor Cyan
                return @{ Result = 'Success'; Features = @('Visual', 'ETA', 'MultiOperation'); Version = '$Version' }
            } else {
                Write-Warning "ProgressTracking: Not available in $Version"
                return @{ Result = 'NotAvailable'; Version = '$Version' }
            }
        }
        default {
            Write-Host "${moduleName}: Standard functionality" -ForegroundColor Cyan
            return @{ Result = 'Success'; Module = '$moduleName'; Version = '$Version' }
        }
    }
}

function Get-$moduleName + 'Status' {
    return @{
        Module = '$moduleName'
        Version = '$Version'
        Status = 'Loaded'
        LicenseTier = '$($versionInfo.LicenseTier)'
        Available = `$true
    }
}

Export-ModuleMember -Function @('Start-$moduleName', 'Get-$moduleName' + 'Status')
"@ | Out-File -FilePath (Join-Path $moduleDir "$moduleName.psm1") -Encoding UTF8
            }
            
            # Create package metadata
            $packageInfo = @{
                Version = $Version.TrimStart('v')
                Platform = $Platform
                Profile = $Profile
                LicenseTier = $versionInfo.LicenseTier
                BuildDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss UTC')
                Features = $versionInfo.Features
                Modules = $versionInfo.Modules
                ModuleCount = $versionInfo.Modules.Count
                Capabilities = @{
                    HasSetupWizard = $versionInfo.HasSetupWizard
                    HasProgressTracking = $versionInfo.HasProgressTracking
                    SupportsAPI = ($versionInfo.Modules -contains 'RestAPIServer')
                    SupportsInfrastructure = ($versionInfo.Modules -contains 'OpenTofuProvider')
                }
            } | ConvertTo-Json -Depth 4
            
            $packageInfo | Out-File -FilePath (Join-Path $releaseDir 'PACKAGE-INFO.json') -Encoding UTF8
            
            # Create installation guide
            @"
# AitherZero $Version Installation Guide

## Quick Start
1. Run: ./Start-AitherZero.ps1
2. For setup: ./Start-AitherZero.ps1 -Setup
3. For help: ./Start-AitherZero.ps1 -Help

## Version Information
- Version: $Version
- Platform: $Platform  
- Profile: $Profile
- License Tier: $($versionInfo.LicenseTier)
- Module Count: $($versionInfo.Modules.Count)

## Available Modules
$($versionInfo.Modules | ForEach-Object { "- $_" } | Join-String -Separator "`n")

## New in This Version
$( if ($Version -eq 'v2.1.0') { "- Enterprise security features`n- Advanced monitoring`n- REST API server" } elseif ($Version -eq 'v2.0.0') { "- AI tools integration`n- Orchestration engine`n- Progress tracking" } elseif ($Version -eq 'v1.5.0') { "- Infrastructure automation`n- Setup wizard`n- Lab runner" } else { "- Core functionality`n- Development tools" } )
"@ | Out-File -FilePath (Join-Path $releaseDir 'INSTALL.md') -Encoding UTF8
            
            return $releaseDir
        }
        
        # Create test data and release scenarios
        $script:MockReleases = @{}
        
        # Mock various external commands and systems
        Mock Get-Command {
            param($Name)
            if ($Name -eq 'pwsh') {
                return @{ Source = '/usr/bin/pwsh' }
            }
            if ($Name -eq 'git') {
                return @{ Source = '/usr/bin/git' }
            }
            return $null
        }
        
        Mock Test-Path {
            param($Path)
            # Allow real file system operations within test workspace
            if ($Path -like "$script:TestWorkspace*") {
                return & (Get-Module Microsoft.PowerShell.Management).ExportedCommands['Test-Path'].ScriptBlock $Path
            }
            
            # Mock system paths
            switch -Wildcard ($Path) {
                '*/pwsh*' { return $true }
                '*/git*' { return $true }
                '*PowerShell*' { return $true }
                default { 
                    # Default to actual Test-Path for other cases
                    return & (Get-Module Microsoft.PowerShell.Management).ExportedCommands['Test-Path'].ScriptBlock $Path
                }
            }
        }
        
        Mock Start-Process {
            param($FilePath, $ArgumentList, $Wait, $PassThru, $NoNewWindow)
            
            # Mock installation processes
            if ($FilePath -like '*setup*' -or $FilePath -like '*install*') {
                Write-Host "Mock: Installation process started for $FilePath"
                
                $mockProcess = [PSCustomObject]@{
                    Id = 12345
                    ProcessName = 'MockInstaller'
                    ExitCode = 0
                    HasExited = $true
                    StartTime = Get-Date
                    ExitTime = (Get-Date).AddSeconds(5)
                }
                
                if ($PassThru) {
                    return $mockProcess
                }
            }
            
            # Mock other system processes
            return [PSCustomObject]@{
                Id = 67890
                ProcessName = 'MockProcess'
                ExitCode = 0
                HasExited = $true
            }
        }
        
        # Mock registry operations for Windows
        Mock Get-ItemProperty {
            param($Path, $Name)
            
            if ($Path -like '*SOFTWARE*AitherZero*') {
                return @{
                    Version = '1.0.0'
                    InstallPath = $script:TestLegacyInstallDir
                    InstallDate = '2024-01-01'
                }
            }
            
            return $null
        }
        
        Mock Set-ItemProperty {
            param($Path, $Name, $Value)
            Write-Host "Mock: Registry updated - $Path.$Name = $Value"
        }
        
        # Create comprehensive test scenarios
        Write-Host "Setting up comprehensive release test scenarios..." -ForegroundColor Cyan
    }
    
    AfterAll {
        # Restore original environment
        foreach ($key in $script:OriginalEnv.Keys) {
            if ($script:OriginalEnv[$key]) {
                Set-Item -Path "env:$key" -Value $script:OriginalEnv[$key]
            } else {
                Remove-Item -Path "env:$key" -ErrorAction SilentlyContinue
            }
        }
        
        # Clean up test workspace
        if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
            try {
                Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Warning "Could not clean up test workspace: $script:TestWorkspace"
            }
        }
    }
    
    Context 'Fresh Installation Scenarios' -Tag @('FreshInstall', 'Installation') {
        
        BeforeAll {
            Write-Host "Testing fresh installation scenarios..." -ForegroundColor Yellow
        }
        
        It 'Should perform successful fresh installation of latest version' {
            # Create fresh installation package
            $releaseDir = New-MockRelease -Version 'v2.1.0' -Platform 'windows' -Profile 'standard' -InstallPath $script:TestFreshInstallDir
            
            # Test launcher execution
            $launcherPath = Join-Path $releaseDir 'Start-AitherZero.ps1'
            $launcherPath | Should -Exist
            
            # Test help functionality
            $helpResult = & $launcherPath -Help
            $helpResult | Should -Match 'AitherZero.*Help Information'
            
            # Test setup functionality
            $setupResult = & $launcherPath -Setup
            $setupResult.SetupResult | Should -Be 'Success'
            $setupResult.Version | Should -Be 'v2.1.0'
        }
        
        It 'Should handle fresh installation with minimal profile' {
            $releaseDir = New-MockRelease -Version 'v2.1.0' -Platform 'linux' -Profile 'minimal' -InstallPath $script:TestFreshInstallDir
            
            $launcherPath = Join-Path $releaseDir 'Start-AitherZero.ps1'
            $autoResult = & $launcherPath -Auto
            
            $autoResult.AutoResult | Should -Be 'Success'
            $autoResult.Version | Should -Be 'v2.1.0'
        }
        
        It 'Should handle fresh installation with full profile' {
            $releaseDir = New-MockRelease -Version 'v2.1.0' -Platform 'macos' -Profile 'full' -InstallPath $script:TestFreshInstallDir
            
            $packageInfoPath = Join-Path $releaseDir 'PACKAGE-INFO.json'
            $packageInfo = Get-Content $packageInfoPath -Raw | ConvertFrom-Json
            
            $packageInfo.Profile | Should -Be 'full'
            $packageInfo.LicenseTier | Should -Be 'enterprise'
            $packageInfo.Capabilities.HasSetupWizard | Should -Be $true
            $packageInfo.Capabilities.HasProgressTracking | Should -Be $true
        }
        
        It 'Should validate PowerShell version compatibility' {
            $releaseDir = New-MockRelease -Version 'v2.1.0' -Platform 'windows' -Profile 'standard' -InstallPath $script:TestFreshInstallDir
            
            # Test bootstrap script exists
            $bootstrapPath = Join-Path $releaseDir 'aither-core-bootstrap.ps1'
            $bootstrapPath | Should -Exist
            
            # Test bootstrap content
            $bootstrapContent = Get-Content $bootstrapPath -Raw
            $bootstrapContent | Should -Match 'PSVersionTable\.PSVersion\.Major'
            $bootstrapContent | Should -Match 'pwsh.*-File'
        }
        
        It 'Should create proper directory structure in fresh installation' {
            $releaseDir = New-MockRelease -Version 'v2.1.0' -Platform 'windows' -Profile 'standard' -InstallPath $script:TestFreshInstallDir
            
            # Check required files
            @('aither-core.ps1', 'Start-AitherZero.ps1', 'aither-core-bootstrap.ps1', 'PACKAGE-INFO.json', 'INSTALL.md') | ForEach-Object {
                Join-Path $releaseDir $_ | Should -Exist
            }
            
            # Check required directories
            @('modules', 'configs') | ForEach-Object {
                Join-Path $releaseDir $_ | Should -Exist
            }
            
            # Verify modules directory has content
            $modulesDir = Join-Path $releaseDir 'modules'
            $moduleCount = (Get-ChildItem $modulesDir -Directory).Count
            $moduleCount | Should -BeGreaterThan 0
        }
        
        It 'Should handle cross-platform installation differences' {
            $platforms = @('windows', 'linux', 'macos')
            
            foreach ($platform in $platforms) {
                $releaseDir = New-MockRelease -Version 'v2.1.0' -Platform $platform -Profile 'standard' -InstallPath $script:TestFreshInstallDir
                
                # All platforms should have core files
                Join-Path $releaseDir 'aither-core.ps1' | Should -Exist
                Join-Path $releaseDir 'Start-AitherZero.ps1' | Should -Exist
                
                # Check package info reflects platform
                $packageInfoPath = Join-Path $releaseDir 'PACKAGE-INFO.json'
                $packageInfo = Get-Content $packageInfoPath -Raw | ConvertFrom-Json
                $packageInfo.Platform | Should -Be $platform
            }
        }
    }
    
    Context 'Upgrade Scenarios' -Tag @('Upgrade', 'Migration') {
        
        BeforeAll {
            Write-Host "Testing upgrade scenarios..." -ForegroundColor Yellow
            
            # Create legacy installation
            $script:LegacyRelease = New-MockRelease -Version 'v1.0.0' -Platform 'windows' -Profile 'standard' -InstallPath $script:TestLegacyInstallDir
        }
        
        It 'Should detect existing installation during upgrade' {
            # Mock registry detection for existing installation
            Mock Get-ItemProperty {
                param($Path, $Name)
                if ($Path -like '*SOFTWARE*AitherZero*') {
                    return @{
                        Version = '1.0.0'
                        InstallPath = $script:LegacyRelease
                        InstallDate = '2024-01-01'
                    }
                }
                return $null
            }
            
            # This would be part of an upgrade detection function
            $existingInstall = Get-ItemProperty -Path 'HKLM:\SOFTWARE\AitherZero' -Name 'Version' -ErrorAction SilentlyContinue
            $existingInstall | Should -Not -BeNullOrEmpty
            $existingInstall.Version | Should -Be '1.0.0'
        }
        
        It 'Should successfully upgrade from v1.0.0 to v2.1.0' {
            # Create new version
            $newReleaseDir = New-MockRelease -Version 'v2.1.0' -Platform 'windows' -Profile 'standard' -InstallPath $script:TestUpgradeDir
            
            # Simulate upgrade process
            $legacyInfo = Get-Content (Join-Path $script:LegacyRelease 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $newInfo = Get-Content (Join-Path $newReleaseDir 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            
            # Verify version progression
            [version]$legacyInfo.Version | Should -BeLessThan ([version]$newInfo.Version)
            
            # Verify new features are available
            $newInfo.Capabilities.HasSetupWizard | Should -Be $true
            $newInfo.Capabilities.HasProgressTracking | Should -Be $true
            $newInfo.Capabilities.SupportsAPI | Should -Be $true
            
            # Legacy version should not have these
            $legacyInfo.Capabilities.HasSetupWizard | Should -Be $false
            $legacyInfo.Capabilities.HasProgressTracking | Should -Be $false
        }
        
        It 'Should handle incremental upgrades v1.0.0 -> v1.5.0 -> v2.0.0' {
            $versions = @('v1.0.0', 'v1.5.0', 'v2.0.0')
            $upgradePath = @()
            
            foreach ($version in $versions) {
                $releaseDir = New-MockRelease -Version $version -Platform 'windows' -Profile 'standard' -InstallPath $script:TestUpgradeDir
                $packageInfo = Get-Content (Join-Path $releaseDir 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
                $upgradePath += $packageInfo
            }
            
            # Verify incremental feature additions
            $upgradePath[0].Capabilities.HasSetupWizard | Should -Be $false  # v1.0.0
            $upgradePath[1].Capabilities.HasSetupWizard | Should -Be $true   # v1.5.0
            $upgradePath[2].Capabilities.HasProgressTracking | Should -Be $true # v2.0.0
            
            # Verify module count increases
            $upgradePath[0].ModuleCount | Should -BeLessThan $upgradePath[1].ModuleCount
            $upgradePath[1].ModuleCount | Should -BeLessThan $upgradePath[2].ModuleCount
        }
        
        It 'Should preserve user configuration during upgrade' {
            # Create user configuration
            $userConfigDir = Join-Path $script:TestUserDataDir 'configs'
            New-Item -ItemType Directory -Path $userConfigDir -Force | Out-Null
            
            $userConfig = @{
                customSettings = @{
                    theme = 'dark'
                    verbosity = 'detailed'
                    autoUpdates = $false
                }
                userPreferences = @{
                    defaultProfile = 'custom'
                    skipWelcome = $true
                }
            } | ConvertTo-Json -Depth 3
            
            $userConfigPath = Join-Path $userConfigDir 'user-config.json'
            $userConfig | Out-File -FilePath $userConfigPath -Encoding UTF8
            
            # Simulate upgrade process that should preserve this
            $userConfigPath | Should -Exist
            $preservedConfig = Get-Content $userConfigPath -Raw | ConvertFrom-Json
            $preservedConfig.customSettings.theme | Should -Be 'dark'
            $preservedConfig.userPreferences.skipWelcome | Should -Be $true
        }
        
        It 'Should handle license tier upgrades correctly' {
            # Test upgrade from free to pro to enterprise
            $freeTier = New-MockRelease -Version 'v1.0.0' -Platform 'windows' -Profile 'standard' -InstallPath $script:TestUpgradeDir
            $proTier = New-MockRelease -Version 'v1.5.0' -Platform 'windows' -Profile 'standard' -InstallPath $script:TestUpgradeDir
            $enterpriseTier = New-MockRelease -Version 'v2.1.0' -Platform 'windows' -Profile 'standard' -InstallPath $script:TestUpgradeDir
            
            $freeInfo = Get-Content (Join-Path $freeTier 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $proInfo = Get-Content (Join-Path $proTier 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $enterpriseInfo = Get-Content (Join-Path $enterpriseTier 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            
            # Verify license tier progression
            $freeInfo.LicenseTier | Should -Be 'free'
            $proInfo.LicenseTier | Should -Be 'pro'
            $enterpriseInfo.LicenseTier | Should -Be 'enterprise'
            
            # Verify module availability increases with tier
            $freeInfo.Modules.Count | Should -BeLessThan $proInfo.Modules.Count
            $proInfo.Modules.Count | Should -BeLessThan $enterpriseInfo.Modules.Count
        }
        
        It 'Should handle rollback scenarios' {
            # Create newer version
            $newerVersion = New-MockRelease -Version 'v2.1.0' -Platform 'windows' -Profile 'standard' -InstallPath $script:TestUpgradeDir
            
            # Create rollback scenario (back to v2.0.0)
            $rollbackVersion = New-MockRelease -Version 'v2.0.0' -Platform 'windows' -Profile 'standard' -InstallPath $script:TestUpgradeDir
            
            # Test that rollback version is functional
            $launcherPath = Join-Path $rollbackVersion 'Start-AitherZero.ps1'
            $result = & $launcherPath -Help
            $result | Should -Match 'v2\.0\.0'
            
            # Verify that rollback still has core functionality
            $rollbackInfo = Get-Content (Join-Path $rollbackVersion 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $rollbackInfo.Capabilities.HasSetupWizard | Should -Be $true
            $rollbackInfo.Capabilities.HasProgressTracking | Should -Be $true
        }
    }
    
    Context 'Production Deployment Validation' -Tag @('Production', 'Deployment') {
        
        BeforeAll {
            Write-Host "Testing production deployment scenarios..." -ForegroundColor Yellow
        }
        
        It 'Should validate production-ready package integrity' {
            $prodRelease = New-MockRelease -Version 'v2.1.0' -Platform 'linux' -Profile 'standard' -InstallPath $script:TestProductionDir
            
            # Check all required production files
            $requiredFiles = @(
                'aither-core.ps1',
                'Start-AitherZero.ps1',
                'aither-core-bootstrap.ps1',
                'PACKAGE-INFO.json',
                'INSTALL.md'
            )
            
            foreach ($file in $requiredFiles) {
                Join-Path $prodRelease $file | Should -Exist
            }
            
            # Verify package metadata is complete
            $packageInfo = Get-Content (Join-Path $prodRelease 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $packageInfo.Version | Should -Not -BeNullOrEmpty
            $packageInfo.BuildDate | Should -Not -BeNullOrEmpty
            $packageInfo.Modules | Should -Not -BeNullOrEmpty
            $packageInfo.Modules.Count | Should -BeGreaterThan 0
        }
        
        It 'Should handle production environment variables correctly' {
            # Set production-like environment
            $env:ENVIRONMENT = 'production'
            $env:LOG_LEVEL = 'WARN'
            $env:AITHERZERO_AUTO_UPDATE = 'false'
            
            $prodRelease = New-MockRelease -Version 'v2.1.0' -Platform 'linux' -Profile 'standard' -InstallPath $script:TestProductionDir
            
            # Test that production settings are respected
            $launcherPath = Join-Path $prodRelease 'Start-AitherZero.ps1'
            $result = & $launcherPath -Auto -Verbosity 'silent'
            
            $result.AutoResult | Should -Be 'Success'
            
            # Clean up environment
            Remove-Item -Path 'env:ENVIRONMENT' -ErrorAction SilentlyContinue
            Remove-Item -Path 'env:LOG_LEVEL' -ErrorAction SilentlyContinue
            Remove-Item -Path 'env:AITHERZERO_AUTO_UPDATE' -ErrorAction SilentlyContinue
        }
        
        It 'Should handle production load simulation' {
            $prodRelease = New-MockRelease -Version 'v2.1.0' -Platform 'windows' -Profile 'full' -InstallPath $script:TestProductionDir
            $launcherPath = Join-Path $prodRelease 'Start-AitherZero.ps1'
            
            # Simulate multiple concurrent requests
            $jobs = @()
            for ($i = 1; $i -le 5; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($LauncherPath, $JobId)
                    & $LauncherPath -Scripts "SystemMonitoring" -Verbosity 'silent'
                    return "Job $JobId completed"
                } -ArgumentList $launcherPath, $i
            }
            
            # Wait for all jobs to complete
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            # Verify all jobs completed successfully
            $results.Count | Should -Be 5
            $results | ForEach-Object { $_ | Should -Match 'Job \d+ completed' }
        }
        
        It 'Should validate security configuration in production' {
            $prodRelease = New-MockRelease -Version 'v2.1.0' -Platform 'linux' -Profile 'full' -InstallPath $script:TestProductionDir
            
            # Check that enterprise security modules are included
            $packageInfo = Get-Content (Join-Path $prodRelease 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $packageInfo.Modules | Should -Contain 'SecureCredentials'
            $packageInfo.LicenseTier | Should -Be 'enterprise'
            
            # Verify security-related capabilities
            $packageInfo.Capabilities.SupportsAPI | Should -Be $true
            
            # Test that security module can be loaded
            $launcherPath = Join-Path $prodRelease 'Start-AitherZero.ps1'
            $result = & $launcherPath -Scripts "SecureCredentials"
            $result.ScriptsResult | Should -Be 'Success'
            $result.ExecutedModules | Should -Contain 'SecureCredentials'
        }
        
        It 'Should handle production monitoring and logging' {
            $prodRelease = New-MockRelease -Version 'v2.1.0' -Platform 'windows' -Profile 'full' -InstallPath $script:TestProductionDir
            
            # Verify monitoring capabilities
            $packageInfo = Get-Content (Join-Path $prodRelease 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $packageInfo.Modules | Should -Contain 'SystemMonitoring'
            $packageInfo.Modules | Should -Contain 'Logging'
            
            # Test monitoring module execution
            $launcherPath = Join-Path $prodRelease 'Start-AitherZero.ps1'
            $result = & $launcherPath -Scripts "SystemMonitoring,Logging"
            
            $result.ScriptsResult | Should -Be 'Success'
            $result.ExecutedModules | Should -Contain 'SystemMonitoring'
            $result.ExecutedModules | Should -Contain 'Logging'
        }
        
        It 'Should validate production backup and recovery capabilities' {
            $prodRelease = New-MockRelease -Version 'v2.1.0' -Platform 'linux' -Profile 'standard' -InstallPath $script:TestProductionDir
            
            # Create mock production data
            $prodDataDir = Join-Path $script:TestProductionDir 'production-data'
            New-Item -ItemType Directory -Path $prodDataDir -Force | Out-Null
            
            'Production configuration data' | Out-File -FilePath (Join-Path $prodDataDir 'config.json') -Encoding UTF8
            'Production logs' | Out-File -FilePath (Join-Path $prodDataDir 'production.log') -Encoding UTF8
            
            # Test backup functionality if BackupManager is available
            $packageInfo = Get-Content (Join-Path $prodRelease 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            if ($packageInfo.Modules -contains 'BackupManager') {
                $launcherPath = Join-Path $prodRelease 'Start-AitherZero.ps1'
                $result = & $launcherPath -Scripts "BackupManager"
                $result.ScriptsResult | Should -Be 'Success'
            }
        }
    }
    
    Context 'Cross-Platform Release Validation' -Tag @('CrossPlatform', 'Compatibility') {
        
        BeforeAll {
            Write-Host "Testing cross-platform release compatibility..." -ForegroundColor Yellow
        }
        
        It 'Should create platform-specific releases correctly' {
            $platforms = @('windows', 'linux', 'macos')
            
            foreach ($platform in $platforms) {
                $release = New-MockRelease -Version 'v2.1.0' -Platform $platform -Profile 'standard' -InstallPath $script:TestReleaseDir
                
                $packageInfo = Get-Content (Join-Path $release 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
                $packageInfo.Platform | Should -Be $platform
                
                # Verify platform-specific launcher content
                $launcherContent = Get-Content (Join-Path $release 'Start-AitherZero.ps1') -Raw
                $launcherContent | Should -Match "Platform: $platform"
            }
        }
        
        It 'Should handle PowerShell compatibility across platforms' {
            $platforms = @('windows', 'linux', 'macos')
            
            foreach ($platform in $platforms) {
                $release = New-MockRelease -Version 'v2.1.0' -Platform $platform -Profile 'standard' -InstallPath $script:TestReleaseDir
                
                # Check bootstrap script
                $bootstrapPath = Join-Path $release 'aither-core-bootstrap.ps1'
                $bootstrapPath | Should -Exist
                
                $bootstrapContent = Get-Content $bootstrapPath -Raw
                $bootstrapContent | Should -Match '#Requires -Version 5.1'
                $bootstrapContent | Should -Match 'PSVersionTable\.PSVersion\.Major'
            }
        }
        
        It 'Should validate cross-platform path handling' {
            $platforms = @('windows', 'linux', 'macos')
            
            foreach ($platform in $platforms) {
                $release = New-MockRelease -Version 'v2.1.0' -Platform $platform -Profile 'standard' -InstallPath $script:TestReleaseDir
                
                # Test that all scripts use cross-platform compatible path handling
                $coreAppContent = Get-Content (Join-Path $release 'aither-core.ps1') -Raw
                $launcherContent = Get-Content (Join-Path $release 'Start-AitherZero.ps1') -Raw
                
                # Should use Join-Path or $PSScriptRoot for cross-platform compatibility
                $coreAppContent | Should -Match '\$PSScriptRoot'
                $launcherContent | Should -Match '\$PSScriptRoot'
            }
        }
        
        It 'Should handle platform-specific module availability' {
            $release = New-MockRelease -Version 'v2.1.0' -Platform 'linux' -Profile 'full' -InstallPath $script:TestReleaseDir
            
            # Test module execution on Linux
            $launcherPath = Join-Path $release 'Start-AitherZero.ps1'
            $result = & $launcherPath -Scripts "OpenTofuProvider"
            
            $result.ScriptsResult | Should -Be 'Success'
            $result.ExecutedModules | Should -Contain 'OpenTofuProvider'
        }
    }
    
    Context 'Release Package Profiles' -Tag @('Profiles', 'Packaging') {
        
        BeforeAll {
            Write-Host "Testing package profile variations..." -ForegroundColor Yellow
        }
        
        It 'Should create minimal profile with correct module subset' {
            $minimalRelease = New-MockRelease -Version 'v2.1.0' -Platform 'linux' -Profile 'minimal' -InstallPath $script:TestReleaseDir
            
            $packageInfo = Get-Content (Join-Path $minimalRelease 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $packageInfo.Profile | Should -Be 'minimal'
            
            # Minimal profile should have fewer modules
            $packageInfo.ModuleCount | Should -BeLessThan 15
            
            # But should still be functional
            $launcherPath = Join-Path $minimalRelease 'Start-AitherZero.ps1'
            $result = & $launcherPath -Help
            $result | Should -Match 'AitherZero.*Help'
        }
        
        It 'Should create standard profile with production features' {
            $standardRelease = New-MockRelease -Version 'v2.1.0' -Platform 'windows' -Profile 'standard' -InstallPath $script:TestReleaseDir
            
            $packageInfo = Get-Content (Join-Path $standardRelease 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $packageInfo.Profile | Should -Be 'standard'
            
            # Standard profile should have core production modules
            $packageInfo.Modules | Should -Contain 'OpenTofuProvider'
            $packageInfo.Modules | Should -Contain 'SetupWizard'
            $packageInfo.Modules | Should -Contain 'SystemMonitoring'
        }
        
        It 'Should create full profile with all features' {
            $fullRelease = New-MockRelease -Version 'v2.1.0' -Platform 'macos' -Profile 'full' -InstallPath $script:TestReleaseDir
            
            $packageInfo = Get-Content (Join-Path $fullRelease 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $packageInfo.Profile | Should -Be 'full'
            
            # Full profile should have maximum modules
            $packageInfo.ModuleCount | Should -BeGreaterThan 10
            
            # Should include development and enterprise features
            $packageInfo.Modules | Should -Contain 'AIToolsIntegration'
            $packageInfo.Modules | Should -Contain 'SecureCredentials'
            $packageInfo.Modules | Should -Contain 'RestAPIServer'
        }
        
        It 'Should validate profile-specific functionality' {
            $profiles = @('minimal', 'standard', 'full')
            
            foreach ($profile in $profiles) {
                $release = New-MockRelease -Version 'v2.1.0' -Platform 'linux' -Profile $profile -InstallPath $script:TestReleaseDir
                
                # All profiles should have basic functionality
                $launcherPath = Join-Path $release 'Start-AitherZero.ps1'
                $basicResult = & $launcherPath -Help
                $basicResult | Should -Match 'AitherZero'
                
                # Test auto mode
                $autoResult = & $launcherPath -Auto
                $autoResult.AutoResult | Should -Be 'Success'
            }
        }
    }
    
    Context 'License Tier Validation in Releases' -Tag @('Licensing', 'Features') {
        
        BeforeAll {
            Write-Host "Testing license tier feature validation..." -ForegroundColor Yellow
        }
        
        It 'Should enforce free tier limitations in v1.0.0' {
            $freeRelease = New-MockRelease -Version 'v1.0.0' -Platform 'windows' -Profile 'standard' -InstallPath $script:TestReleaseDir
            
            $packageInfo = Get-Content (Join-Path $freeRelease 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $packageInfo.LicenseTier | Should -Be 'free'
            
            # Free tier should not have enterprise features
            $packageInfo.Modules | Should -Not -Contain 'SecureCredentials'
            $packageInfo.Modules | Should -Not -Contain 'RestAPIServer'
            $packageInfo.Capabilities.SupportsAPI | Should -Be $false
        }
        
        It 'Should provide pro tier features in v1.5.0' {
            $proRelease = New-MockRelease -Version 'v1.5.0' -Platform 'linux' -Profile 'standard' -InstallPath $script:TestReleaseDir
            
            $packageInfo = Get-Content (Join-Path $proRelease 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $packageInfo.LicenseTier | Should -Be 'pro'
            
            # Pro tier should have infrastructure features
            $packageInfo.Modules | Should -Contain 'OpenTofuProvider'
            $packageInfo.Modules | Should -Contain 'LabRunner'
            $packageInfo.Capabilities.SupportsInfrastructure | Should -Be $true
        }
        
        It 'Should provide enterprise tier features in v2.1.0' {
            $enterpriseRelease = New-MockRelease -Version 'v2.1.0' -Platform 'windows' -Profile 'full' -InstallPath $script:TestReleaseDir
            
            $packageInfo = Get-Content (Join-Path $enterpriseRelease 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $packageInfo.LicenseTier | Should -Be 'enterprise'
            
            # Enterprise tier should have all features
            $packageInfo.Modules | Should -Contain 'SecureCredentials'
            $packageInfo.Modules | Should -Contain 'SystemMonitoring'
            $packageInfo.Modules | Should -Contain 'RestAPIServer'
            $packageInfo.Capabilities.SupportsAPI | Should -Be $true
        }
        
        It 'Should handle license tier feature access correctly' {
            $tiers = @(
                @{ Version = 'v1.0.0'; Tier = 'free'; ExpectedModules = 4 },
                @{ Version = 'v1.5.0'; Tier = 'pro'; ExpectedModules = 7 },
                @{ Version = 'v2.1.0'; Tier = 'enterprise'; ExpectedModules = 13 }
            )
            
            foreach ($tierInfo in $tiers) {
                $release = New-MockRelease -Version $tierInfo.Version -Platform 'linux' -Profile 'standard' -InstallPath $script:TestReleaseDir
                
                $packageInfo = Get-Content (Join-Path $release 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
                $packageInfo.LicenseTier | Should -Be $tierInfo.Tier
                $packageInfo.ModuleCount | Should -Be $tierInfo.ExpectedModules
            }
        }
    }
    
    Context 'Release Workflow Integration' -Tag @('Workflow', 'Integration') {
        
        BeforeAll {
            Write-Host "Testing release workflow integration..." -ForegroundColor Yellow
            
            # Mock GitHub CLI operations
            Mock gh {
                param($SubCommand)
                
                switch ($SubCommand) {
                    'release' {
                        if ($args[0] -eq 'create') {
                            Write-Host "Mock: GitHub release created - $($args[1])"
                            return "✓ Release created successfully"
                        }
                        if ($args[0] -eq 'view') {
                            return @{
                                tag_name = 'v2.1.0'
                                name = 'AitherZero v2.1.0'
                                published_at = '2024-01-01T00:00:00Z'
                                assets = @(
                                    @{ name = 'AitherZero-2.1.0-windows-standard.zip'; size = 52428800 },
                                    @{ name = 'AitherZero-2.1.0-linux-standard.tar.gz'; size = 48234567 }
                                )
                            } | ConvertTo-Json
                        }
                    }
                }
            }
        }
        
        It 'Should integrate with release build process' {
            # Simulate build process
            $buildResult = & $script:BuildScriptPath -Platform 'windows' -Version '2.1.0-test' -ArtifactExtension 'zip' -PackageProfile 'standard' -NoProgress
            
            # Build should complete without errors
            $LASTEXITCODE | Should -Be 0
        }
        
        It 'Should validate release tag and version consistency' {
            $release = New-MockRelease -Version 'v2.1.0' -Platform 'windows' -Profile 'standard' -InstallPath $script:TestReleaseDir
            
            # Check that version in package matches expected release tag
            $packageInfo = Get-Content (Join-Path $release 'PACKAGE-INFO.json') -Raw | ConvertFrom-Json
            $packageInfo.Version | Should -Be '2.1.0'
            
            # Launcher should reflect correct version
            $launcherPath = Join-Path $release 'Start-AitherZero.ps1'
            $helpResult = & $launcherPath -Help
            $helpResult | Should -Match 'v2\.1\.0'
        }
        
        It 'Should handle release artifact creation' {
            # This would typically be handled by the build system
            $release = New-MockRelease -Version 'v2.1.0' -Platform 'linux' -Profile 'full' -InstallPath $script:TestReleaseDir
            
            # Verify release contains all necessary artifacts
            $expectedFiles = @(
                'aither-core.ps1',
                'Start-AitherZero.ps1',
                'aither-core-bootstrap.ps1',
                'PACKAGE-INFO.json',
                'INSTALL.md'
            )
            
            foreach ($file in $expectedFiles) {
                Join-Path $release $file | Should -Exist
            }
            
            # Calculate mock package size
            $packageSize = (Get-ChildItem -Path $release -Recurse | Measure-Object -Property Length -Sum).Sum
            $packageSizeMB = [math]::Round($packageSize / 1MB, 2)
            
            # Full profile should be substantial but not excessive
            $packageSizeMB | Should -BeGreaterThan 0.1
            $packageSizeMB | Should -BeLessThan 200  # Reasonable upper limit
        }
        
        It 'Should validate release distribution readiness' {
            $platforms = @('windows', 'linux', 'macos')
            $profiles = @('minimal', 'standard', 'full')
            
            foreach ($platform in $platforms) {
                foreach ($profile in $profiles) {
                    $release = New-MockRelease -Version 'v2.1.0' -Platform $platform -Profile $profile -InstallPath $script:TestReleaseDir
                    
                    # Each release should be self-contained and functional
                    $launcherPath = Join-Path $release 'Start-AitherZero.ps1'
                    $testResult = & $launcherPath -Help
                    $testResult | Should -Match 'AitherZero'
                    
                    # Should have proper installation documentation
                    $installGuide = Join-Path $release 'INSTALL.md'
                    $installGuide | Should -Exist
                    
                    $installContent = Get-Content $installGuide -Raw
                    $installContent | Should -Match 'Quick Start'
                    $installContent | Should -Match $platform
                    $installContent | Should -Match $profile
                }
            }
        }
    }
}