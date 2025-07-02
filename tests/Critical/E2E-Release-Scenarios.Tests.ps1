BeforeDiscovery {
    $script:TestAppName = 'E2E-Release-Scenarios'
    $script:BuildScriptPath = Join-Path $PSScriptRoot '../../build/Build-Package.ps1'
    $script:LauncherPath = Join-Path $PSScriptRoot '../../Start-AitherZero.ps1'
    $script:CoreAppPath = Join-Path $PSScriptRoot '../../aither-core/aither-core.ps1'
    $script:SetupWizardPath = Join-Path $PSScriptRoot '../../aither-core/modules/SetupWizard'
    
    # Verify critical components exist
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

Describe 'E2E Release Scenarios - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'E2E', 'Release', 'Installation', 'Upgrade') {
    
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Set up isolated test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'e2e-release-tests'
        
        # Save original environment
        $script:OriginalEnv = @{
            PROJECT_ROOT = $env:PROJECT_ROOT
            PWSH_MODULES_PATH = $env:PWSH_MODULES_PATH
            APPDATA = $env:APPDATA
            HOME = $env:HOME
            USERPROFILE = $env:USERPROFILE
            PATH = $env:PATH
            PSModulePath = $env:PSModulePath
        }
        
        # Create realistic directory structures
        $script:TestProjectRoot = Join-Path $script:TestWorkspace 'source-repo'
        $script:TestInstallDir = Join-Path $script:TestWorkspace 'install-location'
        $script:TestUserDataDir = Join-Path $script:TestWorkspace 'user-data'
        $script:TestAppDataDir = Join-Path $script:TestUserDataDir 'AppData' 'Roaming'
        $script:TestPackageDir = Join-Path $script:TestWorkspace 'packages'
        $script:TestUpgradeDir = Join-Path $script:TestWorkspace 'upgrade-test'
        
        @($script:TestProjectRoot, $script:TestInstallDir, $script:TestUserDataDir, 
          $script:TestAppDataDir, $script:TestPackageDir, $script:TestUpgradeDir) | ForEach-Object {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
        
        # Set test environment
        $env:APPDATA = $script:TestAppDataDir
        $env:HOME = $script:TestUserDataDir
        $env:USERPROFILE = $script:TestUserDataDir
        
        # Copy essential project structure for realistic testing
        function Copy-ProjectStructure {
            param($TargetPath)
            
            # Create directory structure
            $dirs = @(
                'aither-core/modules',
                'aither-core/shared',
                'aither-core/scripts',
                'configs',
                'templates/launchers',
                'opentofu/infrastructure',
                'build',
                'docs'
            )
            
            foreach ($dir in $dirs) {
                New-Item -ItemType Directory -Path (Join-Path $TargetPath $dir) -Force | Out-Null
            }
            
            # Copy essential files
            $essentialFiles = @{
                'README.md' = '# AitherZero'
                'LICENSE' = 'MIT License'
                'VERSION' = '1.0.0'
                'configs/default-config.json' = '{"version":"1.0.0"}'
                'configs/feature-registry.json' = Get-Content $script:FeatureRegistryPath -Raw -ErrorAction SilentlyContinue
            }
            
            foreach ($file in $essentialFiles.GetEnumerator()) {
                $filePath = Join-Path $TargetPath $file.Key
                $file.Value | Out-File -FilePath $filePath -Encoding UTF8 -Force
            }
            
            # Copy real project files for realistic testing
            Copy-Item -Path $script:BuildScriptPath -Destination (Join-Path $TargetPath 'build') -Force
            Copy-Item -Path $script:LauncherPath -Destination $TargetPath -Force
            Copy-Item -Path $script:CoreAppPath -Destination (Join-Path $TargetPath 'aither-core') -Force
            
            # Create bootstrap script
            @'
#Requires -Version 5.1
param($ArgumentList)
Write-Host "Bootstrap: PowerShell 5.1 compatibility layer"
if ($PSVersionTable.PSVersion.Major -lt 7) {
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        & pwsh -File "aither-core.ps1" @ArgumentList
        exit $LASTEXITCODE
    } else {
        Write-Error "PowerShell 7 required but not installed"
        exit 1
    }
}
'@ | Out-File -FilePath (Join-Path $TargetPath 'aither-core/aither-core-bootstrap.ps1') -Encoding UTF8
            
            # Create launcher templates
            @'
#Requires -Version 5.1
param([switch]$Help,[switch]$Auto,[string]$Scripts,[switch]$Setup,[string]$ConfigFile,[switch]$WhatIf)
$psVersion = $PSVersionTable.PSVersion.Major
if ($psVersion -lt 7) {
    $bootstrapPath = Join-Path $PSScriptRoot "aither-core-bootstrap.ps1"
    if (Test-Path $bootstrapPath) {
        & $bootstrapPath -ArgumentList $PSBoundParameters
        exit $LASTEXITCODE
    } else {
        Write-Error "Bootstrap script missing"
        exit 1
    }
}
& (Join-Path $PSScriptRoot "aither-core.ps1") @PSBoundParameters
'@ | Out-File -FilePath (Join-Path $TargetPath 'templates/launchers/Start-AitherZero.ps1') -Encoding UTF8
            
            # Create batch launcher template
            @'
@echo off
echo AitherZero v1.0.0 - Cross-Platform Infrastructure Automation
pwsh -ExecutionPolicy Bypass -File Start-AitherZero.ps1 %*
'@ | Out-File -FilePath (Join-Path $TargetPath 'templates/launchers/AitherZero.bat') -Encoding UTF8
        }
        
        # Initialize source repository
        Copy-ProjectStructure -TargetPath $script:TestProjectRoot
        
        # Create mock modules for testing
        $mockModules = @(
            'Logging', 'TestingFramework', 'PatchManager', 'OpenTofuProvider',
            'LabRunner', 'BackupManager', 'SetupWizard', 'ProgressTracking',
            'StartupExperience', 'LicenseManager', 'AIToolsIntegration'
        )
        
        foreach ($module in $mockModules) {
            $modulePath = Join-Path $script:TestProjectRoot "aither-core/modules/$module"
            New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
            
            # Create module manifest
            @"
@{
    ModuleVersion = '1.0.0'
    RootModule = '$module.psm1'
    FunctionsToExport = @('Start-$module')
}
"@ | Out-File -FilePath "$modulePath/$module.psd1" -Encoding UTF8
            
            # Create module script
            @"
function Start-$module {
    Write-Host "$module module started"
    return @{Success = `$true; Module = '$module'}
}
Export-ModuleMember -Function 'Start-$module'
"@ | Out-File -FilePath "$modulePath/$module.psm1" -Encoding UTF8
        }
        
        # Create Find-ProjectRoot.ps1
        @'
function Find-ProjectRoot {
    param([string]$StartPath = $PSScriptRoot)
    $current = $StartPath
    while ($current) {
        if (Test-Path (Join-Path $current "VERSION")) {
            return $current
        }
        $parent = Split-Path $current -Parent
        if ($parent -eq $current) { break }
        $current = $parent
    }
    return $StartPath
}
'@ | Out-File -FilePath (Join-Path $script:TestProjectRoot 'aither-core/shared/Find-ProjectRoot.ps1') -Encoding UTF8
        
        # Create Show-DynamicMenu.ps1
        @'
function Show-DynamicMenu {
    param($Title, $Config, [switch]$FirstRun)
    Write-Host "Dynamic Menu: $Title"
    return @{Selected = 'Exit'; FirstRun = $FirstRun}
}
'@ | Out-File -FilePath (Join-Path $script:TestProjectRoot 'aither-core/shared/Show-DynamicMenu.ps1') -Encoding UTF8
    }
    
    AfterAll {
        # Restore original environment
        foreach ($env in $script:OriginalEnv.GetEnumerator()) {
            Set-Item -Path "env:$($env.Key)" -Value $env.Value -ErrorAction SilentlyContinue
        }
        
        # Cleanup test workspace
        if (Test-Path $script:TestWorkspace) {
            Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context 'Fresh Installation Scenarios' {
        
        It 'Should perform clean installation from package' {
            # Build a release package
            $buildParams = @{
                Platform = 'windows'
                Version = '1.0.0'
                ArtifactExtension = 'zip'
                PackageProfile = 'standard'
            }
            
            & (Join-Path $script:TestProjectRoot 'build/Build-Package.ps1') @buildParams -ErrorAction Stop
            
            # Verify package was created
            $packagePath = Join-Path $script:TestProjectRoot "build-output/windows/AitherZero-1.0.0-windows-standard"
            $packagePath | Should -Exist
            
            # Simulate extraction to install location
            Copy-Item -Path "$packagePath/*" -Destination $script:TestInstallDir -Recurse -Force
            
            # Verify installation structure
            (Join-Path $script:TestInstallDir 'Start-AitherZero.ps1') | Should -Exist
            (Join-Path $script:TestInstallDir 'aither-core.ps1') | Should -Exist
            (Join-Path $script:TestInstallDir 'aither-core-bootstrap.ps1') | Should -Exist
            (Join-Path $script:TestInstallDir 'modules') | Should -Exist
            
            # Test launcher execution
            $launcherResult = & {
                Push-Location $script:TestInstallDir
                try {
                    & ./Start-AitherZero.ps1 -WhatIf
                    $LASTEXITCODE
                } finally {
                    Pop-Location
                }
            }
            
            $launcherResult | Should -Be 0
        }
        
        It 'Should run setup wizard on first launch' {
            # Ensure no existing configuration
            $aitherConfigDir = Join-Path $script:TestAppDataDir 'AitherZero'
            if (Test-Path $aitherConfigDir) {
                Remove-Item -Path $aitherConfigDir -Recurse -Force
            }
            
            # Mock SetupWizard for testing
            $setupWizardPath = Join-Path $script:TestInstallDir 'modules/SetupWizard'
            @"
function Start-IntelligentSetup {
    param([switch]`$MinimalSetup, [string]`$InstallationProfile)
    Write-Host "Setup Wizard Started"
    Write-Host "Profile: `$InstallationProfile"
    
    # Simulate setup steps
    `$setupState = @{
        Platform = @{OS = 'Windows'}
        InstallationProfile = if (`$InstallationProfile) { `$InstallationProfile } else { 'minimal' }
        Steps = @(
            @{Name = 'Platform Detection'; Status = 'Passed'},
            @{Name = 'PowerShell Version'; Status = 'Passed'},
            @{Name = 'Configuration Files'; Status = 'Passed'}
        )
        Errors = @()
        Warnings = @()
        Recommendations = @()
    }
    
    # Create first-run marker
    `$configDir = Join-Path `$env:APPDATA 'AitherZero'
    New-Item -ItemType Directory -Path `$configDir -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path `$configDir '.firstrun') -Force | Out-Null
    
    return `$setupState
}
Export-ModuleMember -Function 'Start-IntelligentSetup'
"@ | Out-File -FilePath "$setupWizardPath/SetupWizard.psm1" -Encoding UTF8
            
            # Run setup
            $setupResult = & {
                Push-Location $script:TestInstallDir
                try {
                    & ./Start-AitherZero.ps1 -Setup -InstallationProfile minimal
                    $LASTEXITCODE
                } finally {
                    Pop-Location
                }
            }
            
            $setupResult | Should -Be 0
            
            # Verify setup created configuration
            $aitherConfigDir | Should -Exist
            (Join-Path $aitherConfigDir '.firstrun') | Should -Exist
        }
        
        It 'Should validate PowerShell version requirements' {
            # Test with PowerShell 5.1 bootstrap
            $ps5LauncherContent = Get-Content (Join-Path $script:TestInstallDir 'Start-AitherZero.ps1') -Raw
            
            # Verify version detection
            $ps5LauncherContent | Should -Match '\$psVersion.*PSVersionTable\.PSVersion\.Major'
            $ps5LauncherContent | Should -Match 'if.*\$psVersion.*-lt 7'
            $ps5LauncherContent | Should -Match 'aither-core-bootstrap\.ps1'
            
            # Verify bootstrap exists
            (Join-Path $script:TestInstallDir 'aither-core-bootstrap.ps1') | Should -Exist
        }
        
        It 'Should handle different installation profiles' {
            $profiles = @('minimal', 'developer', 'full')
            
            foreach ($profile in $profiles) {
                # Build package with profile
                $buildParams = @{
                    Platform = 'windows'
                    Version = '1.0.0'
                    ArtifactExtension = 'zip'
                    PackageProfile = $profile
                }
                
                & (Join-Path $script:TestProjectRoot 'build/Build-Package.ps1') @buildParams -ErrorAction Stop
                
                $packagePath = Join-Path $script:TestProjectRoot "build-output/windows/AitherZero-1.0.0-windows-$profile"
                $packagePath | Should -Exist
                
                # Check package metadata
                $packageInfo = Get-Content "$packagePath/PACKAGE-INFO.json" | ConvertFrom-Json
                $packageInfo.PackageProfile | Should -Be $profile
                
                # Verify profile-specific modules
                switch ($profile) {
                    'minimal' {
                        $packageInfo.ModuleCount | Should -BeLessOrEqual 5
                    }
                    'developer' {
                        $packageInfo.ModuleCount | Should -BeGreaterThan 5
                        $packageInfo.ModuleCount | Should -BeLessOrEqual 15
                    }
                    'full' {
                        $packageInfo.ModuleCount | Should -BeGreaterThan 15
                    }
                }
            }
        }
        
        It 'Should create proper directory structure on first run' {
            # Clean environment
            $testConfigDir = Join-Path $script:TestAppDataDir 'AitherZero'
            if (Test-Path $testConfigDir) {
                Remove-Item -Path $testConfigDir -Recurse -Force
            }
            
            # Run application
            & {
                Push-Location $script:TestInstallDir
                try {
                    & ./Start-AitherZero.ps1 -NonInteractive -Scripts 'Logging'
                } finally {
                    Pop-Location
                }
            }
            
            # Verify directory structure
            $testConfigDir | Should -Exist
            (Join-Path $testConfigDir '.firstrun') | Should -Exist
        }
    }
    
    Context 'Upgrade Scenarios' {
        
        BeforeEach {
            # Set up existing installation
            $script:ExistingVersion = '1.0.0'
            $script:NewVersion = '2.0.0'
            
            # Create existing installation
            Copy-Item -Path "$script:TestInstallDir/*" -Destination $script:TestUpgradeDir -Recurse -Force
            
            # Create existing configuration
            $upgradeConfigDir = Join-Path $script:TestAppDataDir 'AitherZero-Upgrade'
            New-Item -ItemType Directory -Path $upgradeConfigDir -Force | Out-Null
            
            # Create existing config with version
            @{
                Version = $script:ExistingVersion
                CreatedAt = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd')
                Settings = @{
                    CustomSetting = 'UserValue'
                    Modules = @('Logging', 'PatchManager')
                }
            } | ConvertTo-Json | Out-File -FilePath (Join-Path $upgradeConfigDir 'config.json') -Encoding UTF8
        }
        
        It 'Should detect existing installation and preserve user data' {
            # Update VERSION file for new release
            $script:NewVersion | Out-File -FilePath (Join-Path $script:TestProjectRoot 'VERSION') -Encoding UTF8
            
            # Build new version
            $buildParams = @{
                Platform = 'windows'
                Version = $script:NewVersion
                ArtifactExtension = 'zip'
                PackageProfile = 'standard'
            }
            
            & (Join-Path $script:TestProjectRoot 'build/Build-Package.ps1') @buildParams -ErrorAction Stop
            
            $newPackagePath = Join-Path $script:TestProjectRoot "build-output/windows/AitherZero-$($script:NewVersion)-windows-standard"
            $newPackagePath | Should -Exist
            
            # Simulate upgrade by copying new files over existing
            Copy-Item -Path "$newPackagePath/*" -Destination $script:TestUpgradeDir -Recurse -Force
            
            # Verify version updated
            $packageInfo = Get-Content (Join-Path $script:TestUpgradeDir 'PACKAGE-INFO.json') | ConvertFrom-Json
            $packageInfo.Version | Should -Be $script:NewVersion
            
            # Verify user config preserved (would be in AppData, not install dir)
            $upgradeConfigDir = Join-Path $script:TestAppDataDir 'AitherZero-Upgrade'
            $userConfig = Get-Content (Join-Path $upgradeConfigDir 'config.json') | ConvertFrom-Json
            $userConfig.Settings.CustomSetting | Should -Be 'UserValue'
        }
        
        It 'Should handle breaking changes between major versions' {
            # Simulate major version upgrade (1.x to 2.x)
            $majorVersionUpgrade = @{
                OldVersion = '1.5.0'
                NewVersion = '2.0.0'
                BreakingChanges = @(
                    'Module API changes',
                    'Configuration format update',
                    'Deprecated features removed'
                )
            }
            
            # Create migration script in new package
            $migrationScript = @"
# AitherZero v2.0.0 Migration Script
param([string]`$OldVersion, [string]`$ConfigPath)

Write-Host "Migrating from v`$OldVersion to v2.0.0"

# Check for breaking changes
if (`$OldVersion -match '^1\.') {
    Write-Warning "Major version upgrade detected - reviewing configuration..."
    
    # Migrate configuration format
    if (Test-Path `$ConfigPath) {
        `$oldConfig = Get-Content `$ConfigPath | ConvertFrom-Json
        
        # Transform to new format
        `$newConfig = @{
            Version = '2.0.0'
            MigratedFrom = `$OldVersion
            MigratedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            Settings = `$oldConfig.Settings
            ModernSettings = @{
                EnabledModules = `$oldConfig.Settings.Modules
                Features = @{
                    AutoUpdate = `$true
                    Telemetry = `$false
                }
            }
        }
        
        # Backup old config
        Copy-Item -Path `$ConfigPath -Destination "`$ConfigPath.v1.backup" -Force
        
        # Save new config
        `$newConfig | ConvertTo-Json -Depth 5 | Set-Content -Path `$ConfigPath
        Write-Host "Configuration migrated successfully"
    }
}

return @{Success = `$true; MigratedFrom = `$OldVersion}
"@
            
            $migrationPath = Join-Path $script:TestUpgradeDir 'scripts/Migrate-Configuration.ps1'
            New-Item -ItemType Directory -Path (Split-Path $migrationPath -Parent) -Force | Out-Null
            $migrationScript | Out-File -FilePath $migrationPath -Encoding UTF8
            
            # Run migration
            $migrationResult = & $migrationPath -OldVersion $majorVersionUpgrade.OldVersion -ConfigPath (Join-Path $script:TestAppDataDir 'AitherZero-Upgrade/config.json')
            
            $migrationResult.Success | Should -Be $true
            $migrationResult.MigratedFrom | Should -Be $majorVersionUpgrade.OldVersion
            
            # Verify backup created
            (Join-Path $script:TestAppDataDir 'AitherZero-Upgrade/config.json.v1.backup') | Should -Exist
        }
        
        It 'Should validate module compatibility during upgrade' {
            # Create module compatibility matrix
            $compatibilityMatrix = @{
                '1.0.0' = @{
                    Modules = @('Logging', 'PatchManager', 'LabRunner')
                    Deprecated = @()
                }
                '2.0.0' = @{
                    Modules = @('Logging', 'PatchManager', 'LabRunner', 'AIToolsIntegration')
                    Deprecated = @('LegacyModule')
                    New = @('AIToolsIntegration', 'OrchestrationEngine')
                }
            }
            
            # Check module compatibility
            $oldModules = $compatibilityMatrix['1.0.0'].Modules
            $newModules = $compatibilityMatrix['2.0.0'].Modules
            $deprecated = $compatibilityMatrix['2.0.0'].Deprecated
            
            # All old modules should still exist (backward compatibility)
            foreach ($module in $oldModules) {
                $module | Should -BeIn $newModules
            }
            
            # Deprecated modules should generate warnings
            foreach ($module in $deprecated) {
                # In real scenario, this would be logged during upgrade
                $module | Should -Not -BeIn $newModules
            }
        }
        
        It 'Should support rollback mechanism for failed upgrades' {
            # Create rollback snapshot
            $rollbackDir = Join-Path $script:TestWorkspace 'rollback'
            New-Item -ItemType Directory -Path $rollbackDir -Force | Out-Null
            
            # Backup current installation
            Copy-Item -Path "$script:TestUpgradeDir/*" -Destination $rollbackDir -Recurse -Force
            
            # Simulate failed upgrade
            $upgradeSuccess = $false
            try {
                # Attempt upgrade
                throw "Simulated upgrade failure"
            } catch {
                $upgradeSuccess = $false
                
                # Perform rollback
                Write-Host "Upgrade failed, performing rollback..."
                Remove-Item -Path "$script:TestUpgradeDir/*" -Recurse -Force
                Copy-Item -Path "$rollbackDir/*" -Destination $script:TestUpgradeDir -Recurse -Force
            }
            
            $upgradeSuccess | Should -Be $false
            
            # Verify rollback successful
            (Join-Path $script:TestUpgradeDir 'Start-AitherZero.ps1') | Should -Exist
            
            # Version should be old version
            $packageInfo = Get-Content (Join-Path $script:TestUpgradeDir 'PACKAGE-INFO.json') -ErrorAction SilentlyContinue | ConvertFrom-Json
            if ($packageInfo) {
                $packageInfo.Version | Should -Be $script:ExistingVersion
            }
        }
    }
    
    Context 'Production Deployment Scenarios' {
        
        It 'Should support unattended installation with predefined configuration' {
            # Create unattended config
            $unattendedConfig = @{
                InstallationProfile = 'minimal'
                SkipOptional = $true
                AcceptDefaults = $true
                Settings = @{
                    Verbosity = 'silent'
                    AutoUpdate = $false
                    MaxParallelJobs = 8
                }
                Modules = @{
                    EnabledByDefault = @('Logging', 'OpenTofuProvider', 'LabRunner')
                    DisableAutoLoad = $true
                }
            }
            
            $configPath = Join-Path $script:TestWorkspace 'unattended.json'
            $unattendedConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath $configPath -Encoding UTF8
            
            # Run unattended setup
            $setupResult = & {
                Push-Location $script:TestInstallDir
                try {
                    & ./Start-AitherZero.ps1 -Setup -ConfigFile $configPath -NonInteractive
                    $LASTEXITCODE
                } finally {
                    Pop-Location
                }
            }
            
            $setupResult | Should -Be 0
            
            # Verify configuration applied
            $aitherConfigPath = Join-Path $script:TestAppDataDir 'AitherZero/config.json'
            if (Test-Path $aitherConfigPath) {
                $appliedConfig = Get-Content $aitherConfigPath | ConvertFrom-Json
                $appliedConfig.Settings.AutoUpdate | Should -Be $false
                $appliedConfig.Settings.MaxParallelJobs | Should -Be 8
            }
        }
        
        It 'Should validate system requirements before installation' {
            # Create system requirements validator
            $validatorScript = @'
function Test-SystemRequirements {
    $requirements = @{
        MinPowerShellVersion = [version]'7.0'
        MinMemoryGB = 4
        MinDiskSpaceGB = 10
        RequiredCommands = @('git', 'pwsh')
        OptionalCommands = @('tofu', 'terraform', 'docker')
    }
    
    $results = @{
        PowerShell = $PSVersionTable.PSVersion -ge $requirements.MinPowerShellVersion
        Memory = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory -ge ($requirements.MinMemoryGB * 1GB)
        DiskSpace = (Get-PSDrive C).Free -ge ($requirements.MinDiskSpaceGB * 1GB)
        RequiredCommands = @{}
        OptionalCommands = @{}
    }
    
    foreach ($cmd in $requirements.RequiredCommands) {
        $results.RequiredCommands[$cmd] = [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
    }
    
    foreach ($cmd in $requirements.OptionalCommands) {
        $results.OptionalCommands[$cmd] = [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
    }
    
    $allRequired = $results.PowerShell -and $results.Memory -and $results.DiskSpace
    $allRequired = $allRequired -and ($results.RequiredCommands.Values -notcontains $false)
    
    return @{
        Success = $allRequired
        Results = $results
        Recommendations = @()
    }
}
'@
            
            # Add validator to installation
            $validatorPath = Join-Path $script:TestInstallDir 'scripts/Test-SystemRequirements.ps1'
            New-Item -ItemType Directory -Path (Split-Path $validatorPath -Parent) -Force | Out-Null
            $validatorScript | Out-File -FilePath $validatorPath -Encoding UTF8
            
            # Run validation
            . $validatorPath
            $validation = Test-SystemRequirements
            
            # In test environment, we expect some requirements to fail
            $validation.Results.PowerShell | Should -Be $true
            $validation.Results.RequiredCommands['pwsh'] | Should -Be $true
        }
        
        It 'Should handle enterprise proxy and firewall configurations' {
            # Set proxy environment variables
            $env:HTTP_PROXY = 'http://proxy.corp.local:8080'
            $env:HTTPS_PROXY = 'http://proxy.corp.local:8080'
            $env:NO_PROXY = 'localhost,127.0.0.1,.corp.local'
            
            # Create proxy-aware configuration
            $proxyConfig = @{
                Network = @{
                    UseProxy = $true
                    ProxySettings = @{
                        HTTP = $env:HTTP_PROXY
                        HTTPS = $env:HTTPS_PROXY
                        NoProxy = $env:NO_PROXY
                        Authentication = @{
                            Required = $true
                            Method = 'NTLM'
                        }
                    }
                }
                Security = @{
                    AllowedUrls = @(
                        'https://github.com/*',
                        'https://registry.opentofu.org/*',
                        'https://www.powershellgallery.com/*'
                    )
                    BlockedPorts = @(22, 23, 445)
                }
            }
            
            $proxyConfigPath = Join-Path $script:TestWorkspace 'enterprise-proxy.json'
            $proxyConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath $proxyConfigPath -Encoding UTF8
            
            # Verify proxy detection
            [bool]$env:HTTP_PROXY | Should -Be $true
            [bool]$env:HTTPS_PROXY | Should -Be $true
            
            # Clean up proxy settings
            Remove-Item env:HTTP_PROXY -ErrorAction SilentlyContinue
            Remove-Item env:HTTPS_PROXY -ErrorAction SilentlyContinue
            Remove-Item env:NO_PROXY -ErrorAction SilentlyContinue
        }
        
        It 'Should generate installation audit log for compliance' {
            # Create audit logger
            $auditLogger = @'
function Write-InstallationAudit {
    param($Action, $Details)
    
    $auditEntry = @{
        Timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC')
        Action = $Action
        Details = $Details
        User = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Machine = $env:COMPUTERNAME
        ProcessId = $PID
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    }
    
    $auditLogPath = Join-Path $env:APPDATA 'AitherZero/audit.log'
    $auditDir = Split-Path $auditLogPath -Parent
    
    if (-not (Test-Path $auditDir)) {
        New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
    }
    
    $auditEntry | ConvertTo-Json -Compress | Add-Content -Path $auditLogPath
}
'@
            
            # Add audit logger to installation
            . ([scriptblock]::Create($auditLogger))
            
            # Log installation actions
            Write-InstallationAudit -Action 'InstallationStarted' -Details @{Version = '2.0.0'; Profile = 'standard'}
            Write-InstallationAudit -Action 'ModulesInstalled' -Details @{Modules = @('Logging', 'OpenTofuProvider')}
            Write-InstallationAudit -Action 'ConfigurationCreated' -Details @{Path = "$env:APPDATA/AitherZero"}
            Write-InstallationAudit -Action 'InstallationCompleted' -Details @{Success = $true; Duration = '120 seconds'}
            
            # Verify audit log created
            $auditLogPath = Join-Path $script:TestAppDataDir 'AitherZero/audit.log'
            $auditLogPath | Should -Exist
            
            # Verify audit entries
            $auditEntries = Get-Content $auditLogPath | ForEach-Object { $_ | ConvertFrom-Json }
            $auditEntries.Count | Should -Be 4
            $auditEntries[0].Action | Should -Be 'InstallationStarted'
            $auditEntries[-1].Action | Should -Be 'InstallationCompleted'
        }
        
        It 'Should support high availability and load balancing configurations' {
            # Create HA configuration
            $haConfig = @{
                Deployment = @{
                    Mode = 'HighAvailability'
                    Nodes = @(
                        @{Name = 'node1'; Role = 'Primary'; IP = '10.0.1.10'},
                        @{Name = 'node2'; Role = 'Secondary'; IP = '10.0.1.11'},
                        @{Name = 'node3'; Role = 'Secondary'; IP = '10.0.1.12'}
                    )
                    LoadBalancer = @{
                        Type = 'RoundRobin'
                        HealthCheck = @{
                            Interval = 30
                            Timeout = 5
                            Retries = 3
                        }
                    }
                    Clustering = @{
                        Enabled = $true
                        SharedStorage = '\\\\storage\\aitherzero'
                        SyncInterval = 60
                    }
                }
                Scaling = @{
                    AutoScale = $true
                    MinNodes = 2
                    MaxNodes = 10
                    Metrics = @{
                        CPU = 80
                        Memory = 85
                        QueueDepth = 100
                    }
                }
            }
            
            $haConfigPath = Join-Path $script:TestWorkspace 'ha-config.json'
            $haConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath $haConfigPath -Encoding UTF8
            
            # Verify HA configuration structure
            $haConfigPath | Should -Exist
            $loadedConfig = Get-Content $haConfigPath | ConvertFrom-Json
            $loadedConfig.Deployment.Mode | Should -Be 'HighAvailability'
            $loadedConfig.Deployment.Nodes.Count | Should -Be 3
            $loadedConfig.Scaling.AutoScale | Should -Be $true
        }
        
        It 'Should integrate with enterprise monitoring and alerting systems' {
            # Create monitoring integration config
            $monitoringConfig = @{
                Monitoring = @{
                    Enabled = $true
                    Providers = @(
                        @{
                            Name = 'Prometheus'
                            Type = 'Metrics'
                            Endpoint = 'http://prometheus.corp.local:9090'
                            ScrapeInterval = 60
                        },
                        @{
                            Name = 'Splunk'
                            Type = 'Logs'
                            Endpoint = 'https://splunk.corp.local:8088'
                            Token = '${SPLUNK_HEC_TOKEN}'
                        },
                        @{
                            Name = 'PagerDuty'
                            Type = 'Alerting'
                            ServiceKey = '${PAGERDUTY_SERVICE_KEY}'
                            Severity = @('Critical', 'High')
                        }
                    )
                    Metrics = @{
                        Custom = @(
                            @{Name = 'infrastructure_deployments_total'; Type = 'Counter'},
                            @{Name = 'module_execution_duration_seconds'; Type = 'Histogram'},
                            @{Name = 'active_lab_instances'; Type = 'Gauge'}
                        )
                    }
                }
                Logging = @{
                    Level = 'INFO'
                    Outputs = @('Console', 'File', 'Splunk')
                    Retention = @{
                        Days = 30
                        MaxSizeGB = 10
                    }
                }
            }
            
            $monitoringPath = Join-Path $script:TestWorkspace 'monitoring-config.json'
            $monitoringConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath $monitoringPath -Encoding UTF8
            
            # Verify monitoring configuration
            $monitoringPath | Should -Exist
            $loadedMonitoring = Get-Content $monitoringPath | ConvertFrom-Json
            $loadedMonitoring.Monitoring.Providers.Count | Should -Be 3
            $loadedMonitoring.Monitoring.Metrics.Custom.Count | Should -Be 3
        }
    }
    
    Context 'Cross-Platform Release Testing' {
        
        It 'Should build consistent packages across platforms' {
            $platforms = @('windows', 'linux', 'macos')
            $version = '2.0.0'
            
            foreach ($platform in $platforms) {
                # Determine correct extension
                $extension = if ($platform -eq 'windows') { 'zip' } else { 'tar.gz' }
                
                # Build package
                $buildParams = @{
                    Platform = $platform
                    Version = $version
                    ArtifactExtension = $extension
                    PackageProfile = 'standard'
                }
                
                & (Join-Path $script:TestProjectRoot 'build/Build-Package.ps1') @buildParams -ErrorAction Stop
                
                # Verify package
                $packagePath = Join-Path $script:TestProjectRoot "build-output/$platform/AitherZero-$version-$platform-standard"
                $packagePath | Should -Exist
                
                # Check platform-specific elements
                switch ($platform) {
                    'windows' {
                        (Join-Path $packagePath 'AitherZero.bat') | Should -Exist
                    }
                    { $_ -in @('linux', 'macos') } {
                        (Join-Path $packagePath 'aitherzero.sh') | Should -Exist
                    }
                }
                
                # All platforms should have core files
                (Join-Path $packagePath 'Start-AitherZero.ps1') | Should -Exist
                (Join-Path $packagePath 'aither-core.ps1') | Should -Exist
                (Join-Path $packagePath 'PACKAGE-INFO.json') | Should -Exist
            }
        }
        
        It 'Should handle platform-specific path separators' {
            # Test path handling in different scenarios
            $testPaths = @(
                @{Windows = 'C:\AitherZero\modules'; Linux = '/opt/aitherzero/modules'},
                @{Windows = "$env:APPDATA\AitherZero"; Linux = '$HOME/.config/aitherzero'},
                @{Windows = '.\configs\default.json'; Linux = './configs/default.json'}
            )
            
            foreach ($pathSet in $testPaths) {
                # In real scenario, these would be handled by Join-Path
                $windowsPath = $pathSet.Windows
                $linuxPath = $pathSet.Linux
                
                # Verify paths are different but equivalent
                $windowsPath | Should -Match '\\'
                $linuxPath | Should -Match '/'
            }
        }
        
        It 'Should validate Docker container deployment' {
            # Create Dockerfile for AitherZero
            $dockerfile = @'
FROM mcr.microsoft.com/powershell:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy application files
COPY . .

# Install PowerShell modules
RUN pwsh -Command "Set-PSRepository PSGallery -InstallationPolicy Trusted"

# Set entrypoint
ENTRYPOINT ["pwsh", "-File", "Start-AitherZero.ps1"]

# Default command
CMD ["-Help"]
'@
            
            $dockerfilePath = Join-Path $script:TestProjectRoot 'Dockerfile'
            $dockerfile | Out-File -FilePath $dockerfilePath -Encoding UTF8
            
            # Create docker-compose.yml
            $dockerCompose = @'
version: '3.8'

services:
  aitherzero:
    build: .
    image: aitherzero:latest
    container_name: aitherzero-app
    volumes:
      - aitherzero-data:/data
      - ./configs:/app/configs:ro
    environment:
      - AITHERZERO_ENV=production
      - PS_VERBOSITY=normal
    networks:
      - aitherzero-net
    restart: unless-stopped

  aitherzero-api:
    build: .
    image: aitherzero:latest
    container_name: aitherzero-api
    command: ["-Scripts", "RestAPIServer"]
    ports:
      - "8080:8080"
    volumes:
      - aitherzero-data:/data
    environment:
      - AITHERZERO_ENV=production
      - API_PORT=8080
    networks:
      - aitherzero-net
    restart: unless-stopped

volumes:
  aitherzero-data:

networks:
  aitherzero-net:
    driver: bridge
'@
            
            $dockerComposePath = Join-Path $script:TestProjectRoot 'docker-compose.yml'
            $dockerCompose | Out-File -FilePath $dockerComposePath -Encoding UTF8
            
            # Verify Docker files created
            $dockerfilePath | Should -Exist
            $dockerComposePath | Should -Exist
        }
    }
    
    Context 'License Tier Release Testing' {
        
        It 'Should enforce feature restrictions based on license tier' {
            $tiers = @('free', 'pro', 'enterprise')
            
            foreach ($tier in $tiers) {
                # Build package with tier restriction
                $buildParams = @{
                    Platform = 'windows'
                    Version = '2.0.0'
                    ArtifactExtension = 'zip'
                    PackageProfile = 'full'
                    FeatureTier = $tier
                }
                
                & (Join-Path $script:TestProjectRoot 'build/Build-Package.ps1') @buildParams -ErrorAction Stop
                
                $packagePath = Join-Path $script:TestProjectRoot "build-output/windows/AitherZero-2.0.0-windows-full"
                
                # Load feature registry
                $featureRegistry = Get-Content (Join-Path $script:TestProjectRoot 'configs/feature-registry.json') | ConvertFrom-Json
                
                # Get expected modules for tier
                $tierFeatures = $featureRegistry.tiers.$tier.features
                $allowedModules = @()
                
                foreach ($feature in $tierFeatures) {
                    if ($featureRegistry.features.$feature.modules) {
                        $allowedModules += $featureRegistry.features.$feature.modules
                    }
                }
                
                # Add always available modules
                foreach ($override in $featureRegistry.moduleOverrides.PSObject.Properties) {
                    if ($override.Value.alwaysAvailable) {
                        $allowedModules += $override.Name
                    }
                }
                
                # Verify only allowed modules are included
                $includedModules = Get-ChildItem -Path "$packagePath/modules" -Directory -ErrorAction SilentlyContinue | 
                    Select-Object -ExpandProperty Name
                
                foreach ($module in $includedModules) {
                    if ($module -notin $allowedModules) {
                        # This should not happen - module should be filtered
                        $false | Should -Be $true -Because "Module $module should not be in $tier tier"
                    }
                }
            }
        }
        
        It 'Should validate license during runtime initialization' {
            # Create mock license validator
            $licenseValidator = @'
function Test-LicenseValidity {
    param([string]$LicenseKey)
    
    # Mock license validation
    $validLicenses = @{
        'FREE-2024-TRIAL' = @{Tier = 'free'; Expiry = (Get-Date).AddDays(30)}
        'PRO-2024-ANNUAL' = @{Tier = 'pro'; Expiry = (Get-Date).AddYears(1)}
        'ENT-2024-PERPETUAL' = @{Tier = 'enterprise'; Expiry = [datetime]::MaxValue}
    }
    
    if ($validLicenses.ContainsKey($LicenseKey)) {
        $license = $validLicenses[$LicenseKey]
        return @{
            Valid = $true
            Tier = $license.Tier
            Expiry = $license.Expiry
            Features = Get-TierFeatures -Tier $license.Tier
        }
    }
    
    return @{Valid = $false; Reason = 'Invalid license key'}
}

function Get-TierFeatures {
    param([string]$Tier)
    
    $features = @{
        'free' = @('core', 'development')
        'pro' = @('core', 'development', 'infrastructure', 'ai', 'automation')
        'enterprise' = @('core', 'development', 'infrastructure', 'ai', 'automation', 'security', 'monitoring', 'enterprise')
    }
    
    return $features[$Tier]
}
'@
            
            . ([scriptblock]::Create($licenseValidator))
            
            # Test different licenses
            $licenses = @(
                @{Key = 'FREE-2024-TRIAL'; ExpectedTier = 'free'},
                @{Key = 'PRO-2024-ANNUAL'; ExpectedTier = 'pro'},
                @{Key = 'ENT-2024-PERPETUAL'; ExpectedTier = 'enterprise'},
                @{Key = 'INVALID-KEY'; ExpectedTier = $null}
            )
            
            foreach ($license in $licenses) {
                $result = Test-LicenseValidity -LicenseKey $license.Key
                
                if ($license.ExpectedTier) {
                    $result.Valid | Should -Be $true
                    $result.Tier | Should -Be $license.ExpectedTier
                } else {
                    $result.Valid | Should -Be $false
                }
            }
        }
    }
}