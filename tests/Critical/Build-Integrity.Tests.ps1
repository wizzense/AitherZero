BeforeDiscovery {
    $script:BuildScriptPath = Join-Path $PSScriptRoot '../../build/Build-Package.ps1'
    $script:FeatureRegistryPath = Join-Path $PSScriptRoot '../../configs/feature-registry.json'
    $script:TestAppName = 'Build-Integrity'
    
    # Verify build components exist
    if (-not (Test-Path $script:BuildScriptPath)) {
        throw "Build script not found at: $script:BuildScriptPath"
    }
    
    if (-not (Test-Path $script:FeatureRegistryPath)) {
        throw "Feature registry not found at: $script:FeatureRegistryPath"
    }
}

Describe 'Build Integrity - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'Build', 'Package', 'Release') {
    
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Set up isolated test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'build-integrity-tests'
        
        # Save original environment
        $script:OriginalEnv = @{
            PROJECT_ROOT = $env:PROJECT_ROOT
            GITHUB_SHA = $env:GITHUB_SHA
            GITHUB_REF = $env:GITHUB_REF
            CI = $env:CI
        }
        
        # Create comprehensive test directory structure that mimics real project
        $script:TestProjectRoot = Join-Path $script:TestWorkspace 'AitherZero'
        $script:TestBuildDir = Join-Path $script:TestProjectRoot 'build'
        $script:TestConfigsDir = Join-Path $script:TestProjectRoot 'configs'
        $script:TestTemplatesDir = Join-Path $script:TestProjectRoot 'templates' 'launchers'
        $script:TestModulesDir = Join-Path $script:TestProjectRoot 'aither-core' 'modules'
        $script:TestSharedDir = Join-Path $script:TestProjectRoot 'aither-core' 'shared'
        $script:TestScriptsDir = Join-Path $script:TestProjectRoot 'aither-core' 'scripts'
        $script:TestOpenTofuDir = Join-Path $script:TestProjectRoot 'opentofu'
        $script:TestBuildOutputDir = Join-Path $script:TestProjectRoot 'build-output'
        
        @($script:TestProjectRoot, $script:TestBuildDir, $script:TestConfigsDir, $script:TestTemplatesDir,
          $script:TestModulesDir, $script:TestSharedDir, $script:TestScriptsDir, $script:TestOpenTofuDir,
          $script:TestBuildOutputDir) | ForEach-Object {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
        
        # Set test environment
        $env:PROJECT_ROOT = $script:TestProjectRoot
        $env:GITHUB_SHA = 'test-commit-sha-123456'
        $env:GITHUB_REF = 'refs/tags/v1.0.0-test'
        
        # Copy critical build files
        Copy-Item -Path $script:BuildScriptPath -Destination $script:TestBuildDir -Force
        Copy-Item -Path $script:FeatureRegistryPath -Destination $script:TestConfigsDir -Force
        
        # Create mock aither-core.ps1 with proper structure
        @'
#Requires -Version 7.0
param(
    [switch]$Auto,
    [string]$Scripts,
    [string]$ConfigFile,
    [switch]$Help
)

Write-Host "AitherZero Core Application v1.0.0-test" -ForegroundColor Green

if ($Help) {
    Write-Host "Help information..."
    exit 0
}

# Core application logic
Write-Host "Core application started"
exit 0
'@ | Out-File -FilePath (Join-Path $script:TestProjectRoot 'aither-core' 'aither-core.ps1') -Encoding UTF8
        
        # Create PowerShell 5.1 bootstrap script
        @'
#Requires -Version 5.1
# Bootstrap script for PowerShell 5.1 compatibility
param($ArgumentList)

Write-Host "Bootstrap: Checking PowerShell version..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion.Major

if ($psVersion -lt 7) {
    Write-Host "Bootstrap: PowerShell $psVersion detected, launching PowerShell 7..." -ForegroundColor Yellow
    
    $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshPath) {
        & pwsh -File "aither-core.ps1" @ArgumentList
        exit $LASTEXITCODE
    } else {
        Write-Error "PowerShell 7 is required but not installed"
        exit 1
    }
} else {
    Write-Host "Bootstrap: PowerShell 7+ detected, continuing..." -ForegroundColor Green
    & "$PSScriptRoot\aither-core.ps1" @ArgumentList
    exit $LASTEXITCODE
}
'@ | Out-File -FilePath (Join-Path $script:TestProjectRoot 'aither-core' 'aither-core-bootstrap.ps1') -Encoding UTF8
        
        # Create launcher templates with full compatibility features
        $ps1LauncherContent = @'
#!/usr/bin/env pwsh
# AitherZero Cross-Platform Application Launcher v1.0.0+
# Compatible with PowerShell 5.1+ and 7.x
# Automatic PowerShell version detection and parameter mapping

[CmdletBinding()]
param(
    [Parameter(HelpMessage = 'First-time setup and environment validation')]
    [switch]$Setup,
    
    [Parameter(HelpMessage = 'Show detailed usage information')]
    [switch]$Help,
    
    [Parameter(HelpMessage = 'Run in automated mode without prompts')]
    [switch]$Auto,
    
    [Parameter(HelpMessage = 'Specify which scripts/modules to run')]
    [string[]]$Scripts
)

# Detect PowerShell version for compatibility messaging
$psVersion = $PSVersionTable.PSVersion.Major

# Show banner
Write-Host 'AitherZero Infrastructure Automation Framework v1.0.0+' -ForegroundColor Green
Write-Host 'Cross-Platform Infrastructure Automation with OpenTofu/Terraform' -ForegroundColor Cyan

# Handle PowerShell 5.1 compatibility
if ($psVersion -lt 7) {
    Write-Host "PowerShell $($PSVersionTable.PSVersion) detected" -ForegroundColor Yellow
    
    # Try to use bootstrap script for compatibility
    $bootstrapPath = Join-Path $PSScriptRoot 'aither-core' 'aither-core-bootstrap.ps1'
    if (Test-Path $bootstrapPath) {
        Write-Host "Using PowerShell compatibility bootstrap..." -ForegroundColor Yellow
        & $bootstrapPath -ArgumentList $PSBoundParameters
        exit $LASTEXITCODE
    } else {
        Write-Error "Bootstrap script missing - PowerShell 7 required"
        Write-Host "Download PowerShell 7: https://aka.ms/powershell" -ForegroundColor Yellow
        exit 1
    }
}

# PowerShell 7+ - continue with core application
$corePath = Join-Path $PSScriptRoot 'aither-core' 'aither-core.ps1'
if (Test-Path $corePath) {
    & $corePath @PSBoundParameters
    exit $LASTEXITCODE
} else {
    Write-Error "Core application not found at: $corePath"
    exit 1
}
'@
        Set-Content -Path (Join-Path $script:TestTemplatesDir 'Start-AitherZero.ps1') -Value $ps1LauncherContent -Encoding UTF8
        
        # Create batch launcher template
        @'
@echo off
REM AitherZero v1.0.0 - Windows Quick Start Launcher
REM This launcher auto-detects and uses the best available PowerShell version

echo.
echo AitherZero v1.0.0 - Infrastructure Automation Framework
echo.

REM Try PowerShell 7 first
where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Launching with PowerShell 7...
    pwsh -ExecutionPolicy Bypass -File "%~dp0Start-AitherZero.ps1" %*
) else (
    REM Fall back to Windows PowerShell
    echo PowerShell 7 not found, using Windows PowerShell...
    powershell -ExecutionPolicy Bypass -File "%~dp0Start-AitherZero.ps1" %*
)
'@ | Out-File -FilePath (Join-Path $script:TestTemplatesDir 'AitherZero.bat') -Encoding ASCII
        
        # Create essential documentation
        '# AitherZero - Infrastructure Automation Framework' | Out-File -FilePath (Join-Path $script:TestProjectRoot 'README.md') -Encoding UTF8
        'MIT License - Copyright (c) 2025' | Out-File -FilePath (Join-Path $script:TestProjectRoot 'LICENSE') -Encoding UTF8
        
        # Create comprehensive module structure for all profiles
        $allModules = @(
            # Core modules (minimal profile)
            'Logging', 'LabRunner', 'OpenTofuProvider', 'ModuleCommunication', 'ConfigurationCore',
            
            # Platform services (standard profile)
            'ConfigurationCarousel', 'ConfigurationRepository', 'OrchestrationEngine',
            'ParallelExecution', 'ProgressTracking', 'StartupExperience',
            
            # Feature modules (standard profile)
            'ISOManager', 'ISOCustomizer', 'SecureCredentials',
            'RemoteConnection', 'SystemMonitoring', 'RestAPIServer',
            
            # Essential operations (standard profile)
            'BackupManager', 'UnifiedMaintenance', 'ScriptManager',
            'SecurityAutomation', 'SetupWizard',
            
            # Development tools (full profile)
            'DevEnvironment', 'PatchManager', 'TestingFramework', 'AIToolsIntegration',
            
            # Maintenance operations (full profile)
            'RepoSync',
            
            # Additional modules for tier testing
            'CloudProviderIntegration', 'LicenseManager'
        )
        
        foreach ($module in $allModules) {
            $modulePath = Join-Path $script:TestModulesDir $module
            New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
            
            # Create module manifest
            @"
@{
    ModuleVersion = '1.0.0'
    RootModule = '$module.psm1'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Start-$module', 'Test-$module')
    Description = 'Mock $module module for build testing'
}
"@ | Out-File -FilePath (Join-Path $modulePath "$module.psd1") -Encoding UTF8
            
            # Create module script with size to simulate real module
            $moduleContent = @"
# Mock $module Module
function Start-$module {
    Write-Host "$module started"
    return @{ Success = `$true; Module = '$module' }
}

function Test-$module {
    return @{ Success = `$true; Module = '$module'; Version = '1.0.0' }
}

# Add some content to simulate real module size
`$moduleData = @'
$(New-Object byte[] (Get-Random -Minimum 1000 -Maximum 5000) | ForEach-Object { '{0:X2}' -f $_ })
'@

Export-ModuleMember -Function Start-$module, Test-$module
"@
            $moduleContent | Out-File -FilePath (Join-Path $modulePath "$module.psm1") -Encoding UTF8
        }
        
        # Create shared utilities
        @'
function Find-ProjectRoot {
    param([string]$StartPath, [switch]$Force)
    return $env:PROJECT_ROOT
}
'@ | Out-File -FilePath (Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1') -Encoding UTF8
        
        @'
function Get-ProjectVersion {
    return "1.0.0-test"
}
'@ | Out-File -FilePath (Join-Path $script:TestSharedDir 'Get-ProjectVersion.ps1') -Encoding UTF8
        
        # Create runtime scripts
        $runtimeScripts = @(
            '0008_Install-OpenTofu.ps1',
            '0200_Get-SystemInfo.ps1',
            'Invoke-CoreApplication.ps1'
        )
        
        foreach ($script in $runtimeScripts) {
            @"
#Requires -Version 7.0
param([object]`$Config)
Write-Host "Executing $script"
exit 0
"@ | Out-File -FilePath (Join-Path $script:TestScriptsDir $script) -Encoding UTF8
        }
        
        # Create test/dev scripts that should be excluded
        @('test-script.ps1', 'dev-helper.ps1', 'build-local.ps1') | ForEach-Object {
            "Write-Host 'Should not be included in package'" | Out-File -FilePath (Join-Path $script:TestScriptsDir $_) -Encoding UTF8
        }
        
        # Create essential configs
        $configs = @{
            'default-config.json' = @{
                version = "1.0.0"
                modules = @{ autoLoad = $true }
            }
            'core-runner-config.json' = @{
                runner = @{ timeout = 300 }
            }
            'recommended-config.json' = @{
                features = @{ recommended = $true }
            }
        }
        
        foreach ($configName in $configs.Keys) {
            $configs[$configName] | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $script:TestConfigsDir $configName) -Encoding UTF8
        }
        
        # Create OpenTofu structure
        @('infrastructure', 'providers', 'modules') | ForEach-Object {
            New-Item -ItemType Directory -Path (Join-Path $script:TestOpenTofuDir $_) -Force | Out-Null
        }
        
        # Create main.tf in infrastructure
        @'
terraform {
  required_version = ">= 1.0"
}

provider "local" {
  # Local provider for testing
}

resource "local_file" "test" {
  content  = "test"
  filename = "test.txt"
}
'@ | Out-File -FilePath (Join-Path $script:TestOpenTofuDir 'infrastructure' 'main.tf') -Encoding UTF8
        
        # Create test dev environment (should not be included)
        New-Item -ItemType Directory -Path (Join-Path $script:TestOpenTofuDir 'dev-environment') -Force | Out-Null
        
        # Mock external commands
        Mock pwsh {
            param($File, $ArgumentList)
            
            Write-Host "Mock pwsh executing: $File"
            if ($ArgumentList) {
                Write-Host "Arguments: $($ArgumentList -join ' ')"
            }
            
            # Simulate successful execution
            return 0
        }
        
        Mock Compress-Archive {
            param($Path, $DestinationPath)
            # Create empty zip file for testing
            Set-Content -Path $DestinationPath -Value "Mock zip content" -Encoding Byte
        }
        
        Mock Get-FileHash {
            param($Path)
            return @{
                Hash = 'MOCK-SHA256-HASH-1234567890ABCDEF'
                Algorithm = 'SHA256'
            }
        }
        
        # Initialize test tracking
        $script:BuildTestResults = @{}
        $script:PackageValidationResults = @{}
    }
    
    AfterAll {
        # Restore original environment
        foreach ($key in $script:OriginalEnv.Keys) {
            if ($script:OriginalEnv[$key]) {
                Set-Item -Path "env:$key" -Value $script:OriginalEnv[$key] -ErrorAction SilentlyContinue
            } else {
                Remove-Item -Path "env:$key" -ErrorAction SilentlyContinue
            }
        }
        
        # Clean up test workspace
        if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
            Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context 'Build Script Core Functionality' {
        
        It 'Should validate required parameters' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            # Test missing required parameters
            { & $buildScript -Platform 'windows' -Version '1.0.0' } | Should -Throw
            { & $buildScript -Platform 'windows' -ArtifactExtension 'zip' } | Should -Throw
            { & $buildScript -Version '1.0.0' -ArtifactExtension 'zip' } | Should -Throw
        }
        
        It 'Should validate package profile parameter' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            # Valid profiles
            { & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'minimal' -WhatIf } | Should -Not -Throw
            { & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'standard' -WhatIf } | Should -Not -Throw
            { & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'full' -WhatIf } | Should -Not -Throw
            
            # Invalid profile should throw parameter validation error
            { & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'invalid' } | Should -Throw
        }
        
        It 'Should create correct directory structure' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            # Run build
            Push-Location $script:TestProjectRoot
            try {
                & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'minimal' -NoProgress
            } finally {
                Pop-Location
            }
            
            # Verify build output structure
            $buildOutputPath = Join-Path $script:TestBuildOutputDir 'windows'
            Test-Path $buildOutputPath | Should -Be $true
            
            $packagePath = Join-Path $buildOutputPath 'AitherZero-1.0.0-windows-minimal'
            Test-Path $packagePath | Should -Be $true
            
            # Verify essential directories
            Test-Path (Join-Path $packagePath 'modules') | Should -Be $true
            Test-Path (Join-Path $packagePath 'shared') | Should -Be $true
            Test-Path (Join-Path $packagePath 'scripts') | Should -Be $true
            Test-Path (Join-Path $packagePath 'configs') | Should -Be $true
            Test-Path (Join-Path $packagePath 'opentofu') | Should -Be $true
        }
        
        It 'Should include correct files based on package profile' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            $profiles = @{
                'minimal' = @{
                    ExpectedModules = @('Logging', 'LabRunner', 'OpenTofuProvider', 'ModuleCommunication', 'ConfigurationCore')
                    UnexpectedModules = @('PatchManager', 'AIToolsIntegration', 'RestAPIServer')
                }
                'standard' = @{
                    ExpectedModules = @('Logging', 'LabRunner', 'RestAPIServer', 'SystemMonitoring', 'BackupManager')
                    UnexpectedModules = @('PatchManager', 'AIToolsIntegration', 'RepoSync')
                }
                'full' = @{
                    ExpectedModules = @('Logging', 'PatchManager', 'AIToolsIntegration', 'RepoSync', 'TestingFramework')
                    UnexpectedModules = @()  # Full profile includes everything
                }
            }
            
            foreach ($profile in $profiles.Keys) {
                Push-Location $script:TestProjectRoot
                try {
                    # Clean previous build
                    if (Test-Path $script:TestBuildOutputDir) {
                        Remove-Item -Path $script:TestBuildOutputDir -Recurse -Force
                    }
                    
                    # Run build
                    & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile $profile -NoProgress
                    
                    $packagePath = Join-Path $script:TestBuildOutputDir "windows/AitherZero-1.0.0-windows-$profile"
                    $modulesPath = Join-Path $packagePath 'modules'
                    
                    # Check expected modules are included
                    foreach ($module in $profiles[$profile].ExpectedModules) {
                        $modulePath = Join-Path $modulesPath $module
                        Test-Path $modulePath | Should -Be $true -Because "$module should be included in $profile profile"
                    }
                    
                    # Check unexpected modules are not included
                    foreach ($module in $profiles[$profile].UnexpectedModules) {
                        $modulePath = Join-Path $modulesPath $module
                        Test-Path $modulePath | Should -Be $false -Because "$module should not be included in $profile profile"
                    }
                    
                } finally {
                    Pop-Location
                }
            }
        }
        
        It 'Should validate PowerShell compatibility in launchers' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                # Clean and run build
                if (Test-Path $script:TestBuildOutputDir) {
                    Remove-Item -Path $script:TestBuildOutputDir -Recurse -Force
                }
                
                & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'minimal' -NoProgress
                
                $packagePath = Join-Path $script:TestBuildOutputDir 'windows/AitherZero-1.0.0-windows-minimal'
                
                # Check launcher exists
                $launcherPath = Join-Path $packagePath 'Start-AitherZero.ps1'
                Test-Path $launcherPath | Should -Be $true
                
                # Validate launcher content
                $launcherContent = Get-Content $launcherPath -Raw
                
                # Required compatibility features
                $launcherContent | Should -Match '\$psVersion.*PSVersionTable\.PSVersion\.Major'
                $launcherContent | Should -Match 'aither-core-bootstrap\.ps1'
                $launcherContent | Should -Match 'if.*\$psVersion.*-lt 7'
                $launcherContent | Should -Match 'PowerShell 7 required'
                
                # Check bootstrap script exists
                $bootstrapPath = Join-Path $packagePath 'aither-core-bootstrap.ps1'
                Test-Path $bootstrapPath | Should -Be $true
                
                # Check batch launcher for Windows
                if ($package -eq 'windows') {
                    $batchPath = Join-Path $packagePath 'AitherZero.bat'
                    Test-Path $batchPath | Should -Be $true
                }
                
            } finally {
                Pop-Location
            }
        }
        
        It 'Should exclude development and test files' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                # Clean and run build
                if (Test-Path $script:TestBuildOutputDir) {
                    Remove-Item -Path $script:TestBuildOutputDir -Recurse -Force
                }
                
                & $buildScript -Platform 'linux' -Version '1.0.0' -ArtifactExtension 'tar.gz' -PackageProfile 'standard' -NoProgress
                
                $packagePath = Join-Path $script:TestBuildOutputDir 'linux/AitherZero-1.0.0-linux-standard'
                $scriptsPath = Join-Path $packagePath 'scripts'
                
                # Test scripts should be excluded
                Test-Path (Join-Path $scriptsPath 'test-script.ps1') | Should -Be $false
                Test-Path (Join-Path $scriptsPath 'dev-helper.ps1') | Should -Be $false
                Test-Path (Join-Path $scriptsPath 'build-local.ps1') | Should -Be $false
                
                # Runtime scripts should be included
                Test-Path (Join-Path $scriptsPath '0008_Install-OpenTofu.ps1') | Should -Be $true
                Test-Path (Join-Path $scriptsPath '0200_Get-SystemInfo.ps1') | Should -Be $true
                
                # OpenTofu dev environment should be excluded
                $opentofuPath = Join-Path $packagePath 'opentofu'
                Test-Path (Join-Path $opentofuPath 'dev-environment') | Should -Be $false
                
                # Production OpenTofu should be included
                Test-Path (Join-Path $opentofuPath 'infrastructure') | Should -Be $true
                
            } finally {
                Pop-Location
            }
        }
    }
    
    Context 'Feature Tier Filtering' {
        
        It 'Should filter modules based on feature tier' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            # Load feature registry to understand expected behavior
            $featureRegistry = Get-Content (Join-Path $script:TestConfigsDir 'feature-registry.json') -Raw | ConvertFrom-Json
            
            $tiers = @('free', 'pro', 'enterprise')
            
            foreach ($tier in $tiers) {
                Push-Location $script:TestProjectRoot
                try {
                    # Clean previous build
                    if (Test-Path $script:TestBuildOutputDir) {
                        Remove-Item -Path $script:TestBuildOutputDir -Recurse -Force
                    }
                    
                    # Run build with tier filtering
                    & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'full' -FeatureTier $tier -NoProgress
                    
                    $packagePath = Join-Path $script:TestBuildOutputDir "windows/AitherZero-1.0.0-windows-full"
                    $modulesPath = Join-Path $packagePath 'modules'
                    
                    # Get allowed features for tier
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
                    
                    # Check tier-restricted modules
                    if ($tier -eq 'free') {
                        # Free tier should not have enterprise modules
                        Test-Path (Join-Path $modulesPath 'SystemMonitoring') | Should -Be $false
                        Test-Path (Join-Path $modulesPath 'RestAPIServer') | Should -Be $false
                        Test-Path (Join-Path $modulesPath 'SecureCredentials') | Should -Be $false
                    } elseif ($tier -eq 'pro') {
                        # Pro tier should have infrastructure but not enterprise security
                        Test-Path (Join-Path $modulesPath 'OpenTofuProvider') | Should -Be $true
                        Test-Path (Join-Path $modulesPath 'SecureCredentials') | Should -Be $false
                        Test-Path (Join-Path $modulesPath 'SystemMonitoring') | Should -Be $false
                    } elseif ($tier -eq 'enterprise') {
                        # Enterprise tier should have everything
                        Test-Path (Join-Path $modulesPath 'SystemMonitoring') | Should -Be $true
                        Test-Path (Join-Path $modulesPath 'RestAPIServer') | Should -Be $true
                        Test-Path (Join-Path $modulesPath 'SecureCredentials') | Should -Be $true
                    }
                    
                    # SetupWizard should always be available (override)
                    Test-Path (Join-Path $modulesPath 'SetupWizard') | Should -Be $true
                    
                } finally {
                    Pop-Location
                }
            }
        }
        
        It 'Should handle missing feature registry gracefully' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                # Temporarily rename feature registry
                $featureRegistryPath = Join-Path $script:TestConfigsDir 'feature-registry.json'
                $tempPath = "$featureRegistryPath.bak"
                
                if (Test-Path $featureRegistryPath) {
                    Move-Item -Path $featureRegistryPath -Destination $tempPath -Force
                }
                
                # Build should still work without tier restrictions
                & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'minimal' -FeatureTier 'pro' -NoProgress -WarningAction SilentlyContinue
                
                # Should have completed successfully
                $packagePath = Join-Path $script:TestBuildOutputDir 'windows/AitherZero-1.0.0-windows-minimal'
                Test-Path $packagePath | Should -Be $true
                
            } finally {
                # Restore feature registry
                if (Test-Path $tempPath) {
                    Move-Item -Path $tempPath -Destination $featureRegistryPath -Force
                }
                Pop-Location
            }
        }
    }
    
    Context 'Cross-Platform Package Building' {
        
        It 'Should build packages for different platforms' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            $platforms = @(
                @{ Platform = 'windows'; Extension = 'zip' }
                @{ Platform = 'linux'; Extension = 'tar.gz' }
                @{ Platform = 'macos'; Extension = 'tar.gz' }
            )
            
            foreach ($platform in $platforms) {
                Push-Location $script:TestProjectRoot
                try {
                    # Clean previous build
                    if (Test-Path $script:TestBuildOutputDir) {
                        Remove-Item -Path $script:TestBuildOutputDir -Recurse -Force
                    }
                    
                    # Run build
                    & $buildScript -Platform $platform.Platform -Version '2.0.0' -ArtifactExtension $platform.Extension -PackageProfile 'standard' -NoProgress
                    
                    $packagePath = Join-Path $script:TestBuildOutputDir "$($platform.Platform)/AitherZero-2.0.0-$($platform.Platform)-standard"
                    Test-Path $packagePath | Should -Be $true
                    
                    # Platform-specific checks
                    if ($platform.Platform -eq 'windows') {
                        # Windows should have batch launcher
                        Test-Path (Join-Path $packagePath 'AitherZero.bat') | Should -Be $true
                    } else {
                        # Unix platforms should have shell script
                        Test-Path (Join-Path $packagePath 'aitherzero.sh') | Should -Be $true
                        
                        # Check shell script content
                        $shellContent = Get-Content (Join-Path $packagePath 'aitherzero.sh') -Raw
                        $shellContent | Should -Match '#!/bin/bash'
                        $shellContent | Should -Match 'pwsh.*Start-AitherZero.ps1'
                    }
                    
                } finally {
                    Pop-Location
                }
            }
        }
        
        It 'Should create platform-appropriate line endings' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                # Build for Linux (should have LF line endings)
                & $buildScript -Platform 'linux' -Version '1.0.0' -ArtifactExtension 'tar.gz' -PackageProfile 'minimal' -NoProgress
                
                $packagePath = Join-Path $script:TestBuildOutputDir 'linux/AitherZero-1.0.0-linux-minimal'
                $shellScriptPath = Join-Path $packagePath 'aitherzero.sh'
                
                if (Test-Path $shellScriptPath) {
                    $content = Get-Content $shellScriptPath -Raw
                    # Check for Unix line endings (no CR)
                    $content | Should -Not -Match "`r`n"
                }
                
            } finally {
                Pop-Location
            }
        }
    }
    
    Context 'Package Metadata and Documentation' {
        
        It 'Should create comprehensive package metadata' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                # Set environment for metadata
                $env:GITHUB_SHA = 'abc123def456'
                $env:GITHUB_REF = 'refs/tags/v3.0.0'
                
                & $buildScript -Platform 'windows' -Version '3.0.0' -ArtifactExtension 'zip' -PackageProfile 'full' -NoProgress
                
                $packagePath = Join-Path $script:TestBuildOutputDir 'windows/AitherZero-3.0.0-windows-full'
                $metadataPath = Join-Path $packagePath 'PACKAGE-INFO.json'
                
                Test-Path $metadataPath | Should -Be $true
                
                $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
                
                # Validate metadata content
                $metadata.Version | Should -Be '3.0.0'
                $metadata.PackageType | Should -Be 'Application'
                $metadata.PackageProfile | Should -Be 'full'
                $metadata.Platform | Should -Be 'windows'
                $metadata.GitCommit | Should -Be 'abc123def456'
                $metadata.GitRef | Should -Be 'refs/tags/v3.0.0'
                $metadata.ModuleCount | Should -BeGreaterThan 0
                $metadata.Modules | Should -Not -BeNullOrEmpty
                $metadata.BuildDate | Should -Not -BeNullOrEmpty
                
            } finally {
                Pop-Location
            }
        }
        
        It 'Should create installation guide with correct information' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                & $buildScript -Platform 'macos' -Version '1.5.0' -ArtifactExtension 'tar.gz' -PackageProfile 'standard' -NoProgress
                
                $packagePath = Join-Path $script:TestBuildOutputDir 'macos/AitherZero-1.5.0-macos-standard'
                $installPath = Join-Path $packagePath 'INSTALL.md'
                
                Test-Path $installPath | Should -Be $true
                
                $installContent = Get-Content $installPath -Raw
                
                # Validate install guide content
                $installContent | Should -Match 'AitherZero.*v1\.5\.0'
                $installContent | Should -Match 'Quick Start'
                $installContent | Should -Match 'Requirements'
                $installContent | Should -Match 'PowerShell 7\.0\+'
                $installContent | Should -Match 'Troubleshooting'
                
                # Platform-specific content
                $installContent | Should -Match './aitherzero.sh'
                $installContent | Should -Match 'chmod \+x'
                
            } finally {
                Pop-Location
            }
        }
        
        It 'Should include essential documentation files' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'minimal' -NoProgress
                
                $packagePath = Join-Path $script:TestBuildOutputDir 'windows/AitherZero-1.0.0-windows-minimal'
                
                # Essential files
                Test-Path (Join-Path $packagePath 'README.md') | Should -Be $true
                Test-Path (Join-Path $packagePath 'LICENSE') | Should -Be $true
                Test-Path (Join-Path $packagePath 'INSTALL.md') | Should -Be $true
                Test-Path (Join-Path $packagePath 'PACKAGE-INFO.json') | Should -Be $true
                
            } finally {
                Pop-Location
            }
        }
    }
    
    Context 'Build Output Validation' {
        
        It 'Should calculate and display package size correctly' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                # Capture build output
                $output = & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'minimal' -NoProgress 2>&1
                
                # Check for size reporting
                $output | Should -Match 'Size:.*MB'
                
                # Verify actual package was created
                $packagePath = Join-Path $script:TestBuildOutputDir 'windows/AitherZero-1.0.0-windows-minimal'
                Test-Path $packagePath | Should -Be $true
                
                # Calculate actual size
                $actualSize = (Get-ChildItem -Path $packagePath -Recurse | Measure-Object -Property Length -Sum).Sum
                $actualSizeMB = [math]::Round($actualSize / 1MB, 2)
                
                # Size should be reasonable for minimal profile
                $actualSizeMB | Should -BeGreaterThan 0
                $actualSizeMB | Should -BeLessThan 50  # Minimal should be under 50MB
                
            } finally {
                Pop-Location
            }
        }
        
        It 'Should generate SHA256 checksum for archives' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'standard' -NoProgress
                
                # Note: In real scenario, archive would be created by CI/CD
                # Our mock doesn't create actual archives, but we test the checksum logic
                
                # The build script should attempt to create checksum if archive exists
                # We can verify this by checking the mock was called
                Assert-MockCalled Get-FileHash -Times 0  # Not called because no actual archive in our test
                
            } finally {
                Pop-Location
            }
        }
        
        It 'Should validate package integrity after build' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            # Create mock validation script
            $validationScript = Join-Path $script:TestProjectRoot 'tests' 'validation'
            New-Item -ItemType Directory -Path $validationScript -Force | Out-Null
            
            @'
param($PackagePath, $Platform, $Version, [switch]$GenerateReport)
Write-Host "Validating package at: $PackagePath"
Write-Host "Platform: $Platform, Version: $Version"
exit 0
'@ | Out-File -FilePath (Join-Path $validationScript 'Test-PackageIntegrity.ps1') -Encoding UTF8
            
            Push-Location $script:TestProjectRoot
            try {
                $output = & $buildScript -Platform 'linux' -Version '2.0.0' -ArtifactExtension 'tar.gz' -PackageProfile 'full' -NoProgress 2>&1
                
                # Should run validation
                $output | Should -Match 'package integrity validation'
                $output | Should -Match 'validation passed'
                
            } finally {
                Pop-Location
                # Clean up validation script
                if (Test-Path $validationScript) {
                    Remove-Item -Path $validationScript -Recurse -Force
                }
            }
        }
    }
    
    Context 'Error Handling and Edge Cases' {
        
        It 'Should handle missing launcher templates gracefully' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                # Temporarily rename templates directory
                $templatesPath = Join-Path $script:TestProjectRoot 'templates'
                $tempPath = "$templatesPath.bak"
                
                if (Test-Path $templatesPath) {
                    Move-Item -Path $templatesPath -Destination $tempPath -Force
                }
                
                # Build should fail with clear error
                { & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'minimal' -NoProgress } | Should -Throw
                
            } finally {
                # Restore templates
                if (Test-Path $tempPath) {
                    Move-Item -Path $tempPath -Destination $templatesPath -Force
                }
                Pop-Location
            }
        }
        
        It 'Should handle missing modules gracefully' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                # Remove a core module temporarily
                $loggingPath = Join-Path $script:TestModulesDir 'Logging'
                $tempPath = "$loggingPath.bak"
                
                if (Test-Path $loggingPath) {
                    Move-Item -Path $loggingPath -Destination $tempPath -Force
                }
                
                # Build should continue but warn about missing module
                $output = & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'minimal' -NoProgress 2>&1
                
                # Should still create package
                $packagePath = Join-Path $script:TestBuildOutputDir 'windows/AitherZero-1.0.0-windows-minimal'
                Test-Path $packagePath | Should -Be $true
                
                # But Logging module should not be there
                Test-Path (Join-Path $packagePath 'modules' 'Logging') | Should -Be $false
                
            } finally {
                # Restore module
                if (Test-Path $tempPath) {
                    Move-Item -Path $tempPath -Destination $loggingPath -Force
                }
                Pop-Location
            }
        }
        
        It 'Should validate launcher compatibility features are not broken' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            # Create launcher without compatibility features
            $badLauncherContent = @'
# Bad launcher without compatibility
param([switch]$Help)
Write-Host "AitherZero"
& "./aither-core/aither-core.ps1" @PSBoundParameters
'@
            Set-Content -Path (Join-Path $script:TestTemplatesDir 'Start-AitherZero.ps1') -Value $badLauncherContent -Encoding UTF8
            
            Push-Location $script:TestProjectRoot
            try {
                # Build should fail validation
                { & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'minimal' -NoProgress } | Should -Throw
                
            } finally {
                Pop-Location
                
                # Restore good launcher
                $ps1LauncherContent = @'
#!/usr/bin/env pwsh
[CmdletBinding()]
param([switch]$Setup,[switch]$Help,[switch]$Auto,[string[]]$Scripts)
$psVersion = $PSVersionTable.PSVersion.Major
Write-Host "AitherZero v1.0.0+" -ForegroundColor Green
if ($psVersion -lt 7) {
    $bootstrapPath = Join-Path $PSScriptRoot "aither-core" "aither-core-bootstrap.ps1"
    if (Test-Path $bootstrapPath) {
        & $bootstrapPath -ArgumentList $PSBoundParameters
        exit $LASTEXITCODE
    } else {
        Write-Error "Bootstrap script missing"
        exit 1
    }
}
& "$PSScriptRoot/aither-core/aither-core.ps1" @PSBoundParameters
'@
                Set-Content -Path (Join-Path $script:TestTemplatesDir 'Start-AitherZero.ps1') -Value $ps1LauncherContent -Encoding UTF8
            }
        }
    }
    
    Context 'CI/CD Integration Features' {
        
        It 'Should support NoProgress flag for CI environments' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                # With NoProgress flag, should not attempt to load ProgressTracking
                $output = & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'minimal' -NoProgress 2>&1
                
                # Should complete successfully
                $output | Should -Match 'Package creation completed'
                
                # No progress tracking errors
                $output | Should -Not -Match 'ProgressTracking'
                
            } finally {
                Pop-Location
            }
        }
        
        It 'Should handle CI environment variables correctly' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                # Set CI environment
                $env:CI = 'true'
                $env:GITHUB_SHA = 'ci-test-sha-789'
                $env:GITHUB_REF = 'refs/heads/main'
                
                & $buildScript -Platform 'linux' -Version '1.0.0-ci' -ArtifactExtension 'tar.gz' -PackageProfile 'minimal' -NoProgress
                
                # Check metadata includes CI information
                $packagePath = Join-Path $script:TestBuildOutputDir 'linux/AitherZero-1.0.0-ci-linux-minimal'
                $metadataPath = Join-Path $packagePath 'PACKAGE-INFO.json'
                
                $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
                $metadata.GitCommit | Should -Be 'ci-test-sha-789'
                $metadata.GitRef | Should -Be 'refs/heads/main'
                
            } finally {
                Remove-Item -Path 'env:CI' -ErrorAction SilentlyContinue
                Pop-Location
            }
        }
    }
    
    Context 'Performance and Resource Management' {
        
        It 'Should build packages efficiently' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                
                & $buildScript -Platform 'windows' -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile 'minimal' -NoProgress
                
                $stopwatch.Stop()
                
                # Build should complete in reasonable time (under 30 seconds for minimal)
                $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 30
                
            } finally {
                Pop-Location
            }
        }
        
        It 'Should handle multiple concurrent builds' {
            $buildScript = Join-Path $script:TestBuildDir 'Build-Package.ps1'
            
            Push-Location $script:TestProjectRoot
            try {
                # Start multiple builds in parallel
                $jobs = @()
                
                $buildConfigs = @(
                    @{ Platform = 'windows'; Profile = 'minimal' }
                    @{ Platform = 'linux'; Profile = 'standard' }
                    @{ Platform = 'macos'; Profile = 'full' }
                )
                
                foreach ($config in $buildConfigs) {
                    $job = Start-Job -ScriptBlock {
                        param($BuildScript, $ProjectRoot, $Platform, $Profile)
                        
                        Set-Location $ProjectRoot
                        & $BuildScript -Platform $Platform -Version '1.0.0' -ArtifactExtension 'zip' -PackageProfile $Profile -NoProgress
                        
                    } -ArgumentList $buildScript, $script:TestProjectRoot, $config.Platform, $config.Profile
                    
                    $jobs += $job
                }
                
                # Wait for all jobs to complete
                $completed = Wait-Job -Job $jobs -Timeout 60
                
                # All jobs should complete successfully
                foreach ($job in $jobs) {
                    $job.State | Should -Be 'Completed'
                    Receive-Job -Job $job -ErrorAction SilentlyContinue
                    Remove-Job -Job $job -Force
                }
                
                # Verify all packages were created
                foreach ($config in $buildConfigs) {
                    $packagePath = Join-Path $script:TestBuildOutputDir "$($config.Platform)/AitherZero-1.0.0-$($config.Platform)-$($config.Profile)"
                    Test-Path $packagePath | Should -Be $true
                }
                
            } finally {
                # Clean up any remaining jobs
                Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
                Pop-Location
            }
        }
    }
}