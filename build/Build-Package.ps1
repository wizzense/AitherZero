#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Build AitherZero application packages for release with package profiles
.DESCRIPTION
    Creates application packages for different platforms with three profile options:
    - minimal: Core infrastructure only (~10MB) - CI/CD environments
    - standard: Production-ready platform (~50MB) - Enterprise deployments  
    - full: Complete development platform (~100MB) - Development environments
.PARAMETER Platform
    Target platform (windows, linux, macos)
.PARAMETER Version
    Package version
.PARAMETER ArtifactExtension
    Archive format extension (zip, tar.gz)
.PARAMETER PackageProfile
    Package profile: minimal, standard, or full (default: standard)
.PARAMETER NoProgress
    Disable visual progress tracking (useful for CI/CD environments)
.EXAMPLE
    ./Build-Package.ps1 -Platform "windows" -Version "1.0.0" -ArtifactExtension "zip" -PackageProfile "minimal"
.EXAMPLE
    ./Build-Package.ps1 -Platform "linux" -Version "1.0.0" -ArtifactExtension "tar.gz" -PackageProfile "full"
#>

param(
    [Parameter(Mandatory)]
    [string]$Platform,

    [Parameter(Mandatory)]
    [string]$Version,

    [Parameter(Mandatory)]
    [string]$ArtifactExtension,
    
    [Parameter()]
    [ValidateSet('minimal', 'standard', 'full')]
    [string]$PackageProfile = 'standard',
    
    [Parameter()]
    [ValidateSet('free', 'pro', 'enterprise')]
    [string]$FeatureTier,
    
    [switch]$NoProgress
)

$ErrorActionPreference = 'Stop'

Write-Host "Building AitherZero $PackageProfile package for $Platform..." -ForegroundColor Cyan

# Try to import ProgressTracking module (optional enhancement)
$progressAvailable = $false
$progressOperationId = $null
if (-not $NoProgress) {
    try {
        # Find project root and import ProgressTracking module
        $projectRoot = Split-Path -Parent $PSScriptRoot
        $progressModulePath = Join-Path $projectRoot "aither-core/modules/ProgressTracking"
        
        if (Test-Path $progressModulePath) {
            Import-Module $progressModulePath -Force -ErrorAction Stop
            $progressAvailable = $true
        
        # Calculate total steps for progress tracking
        $totalSteps = 0
        $totalSteps += 3  # Initial setup steps
        $totalSteps += 14 # Essential modules count
        $totalSteps += 5  # Additional copy operations (shared, scripts, configs, etc.)
        $totalSteps += 3  # Documentation and launchers
        $totalSteps += 3  # Metadata and validation
        
        # Start progress tracking
        $progressOperationId = Start-ProgressOperation `
            -OperationName "Building $Platform Package v$Version" `
            -TotalSteps $totalSteps `
            -ShowTime `
            -ShowETA `
            -Style 'Detailed'
            
            Write-Host "" # Add spacing after progress initialization
        }
    } catch {
        # Progress tracking is optional - continue without it
        $progressAvailable = $false
    }
}

try {
    $buildDir = "build-output/$Platform"
    New-Item -Path $buildDir -ItemType Directory -Force | Out-Null
    
    if ($progressAvailable) {
        Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Creating build directory"
    }

    $packageName = "AitherZero-$Version-$Platform-$PackageProfile"
    $packageDir = "$buildDir/$packageName"
    New-Item -Path $packageDir -ItemType Directory -Force | Out-Null
    
    if ($progressAvailable) {
        Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Setting up package structure"
    }

    Write-Host "Creating $PackageProfile application package: $packageName" -ForegroundColor Yellow
    Write-Host '📦 Application-focused build (not a repository copy)' -ForegroundColor Cyan
    
    if ($progressAvailable) {
        Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Preparing to copy files"
    }

    # Copy ONLY essential application files for running AitherZero
    Write-Host 'Copying core application files...' -ForegroundColor Yellow

    # Create aither-core directory structure
    $aithercoreDir = Join-Path $packageDir 'aither-core'
    New-Item -Path $aithercoreDir -ItemType Directory -Force | Out-Null
    Write-Host '✓ Created aither-core directory structure' -ForegroundColor Green
    
    # Core runner and main entry point
    Copy-Item -Path 'aither-core/aither-core.ps1' -Destination "$aithercoreDir/aither-core.ps1" -Force
    Write-Host '✓ Core runner script' -ForegroundColor Green
    
    # CRITICAL: Copy bootstrap script for PowerShell 5.1 compatibility
    $bootstrapPath = 'aither-core/aither-core-bootstrap.ps1'
    if (Test-Path $bootstrapPath) {
        # Copy to both locations - package root for validation and aither-core for runtime
        Copy-Item -Path $bootstrapPath -Destination "$packageDir/aither-core-bootstrap.ps1" -Force
        Copy-Item -Path $bootstrapPath -Destination "$aithercoreDir/aither-core-bootstrap.ps1" -Force
        Write-Host '✓ PowerShell compatibility bootstrap script' -ForegroundColor Green
    } else {
        Write-Warning "Bootstrap script not found at: $bootstrapPath"
        if ($progressAvailable) {
            Add-ProgressWarning -OperationId $progressOperationId -Warning "Bootstrap script missing: $bootstrapPath"
        }
    }
    
    if ($progressAvailable) {
        Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Copied core runner and bootstrap"
    }

    # Package Profile Definitions
    # Define base module lists
    $coreModules = @(
        'Logging', 'LabRunner', 'OpenTofuProvider',
        'ModuleCommunication', 'ConfigurationCore'
    )
    $platformServices = @(
        'ConfigurationCarousel', 'ConfigurationRepository', 'OrchestrationEngine',
        'ParallelExecution', 'ProgressTracking', 'StartupExperience'
    )
    $featureModules = @(
        'ISOManager', 'ISOCustomizer', 'SecureCredentials',
        'RemoteConnection', 'SystemMonitoring', 'RestAPIServer'
    )
    $essentialOperations = @(
        'BackupManager', 'UnifiedMaintenance', 'ScriptManager',
        'SecurityAutomation', 'SetupWizard'
    )
    $developmentTools = @(
        'DevEnvironment', 'PatchManager', 'TestingFramework', 'AIToolsIntegration'
    )
    $maintenanceOperations = @(
        'RepoSync'
    )
    
    # Define package profiles
    $packageProfiles = @{
        'minimal' = @{
            Description = 'Core infrastructure only (~10MB)'
            Modules = $coreModules
            EstimatedSize = '~10MB'
            UseCase = 'CI/CD environments, minimal deployments'
        }
        'standard' = @{
            Description = 'Production-ready platform (~50MB)'
            Modules = $coreModules + $platformServices + $featureModules + $essentialOperations
            EstimatedSize = '~50MB'
            UseCase = 'Production deployments, enterprise environments'
        }
        'full' = @{
            Description = 'Complete development platform (~100MB)'
            Modules = $coreModules + $platformServices + $featureModules + $developmentTools + $essentialOperations + $maintenanceOperations
            EstimatedSize = '~100MB'
            UseCase = 'Development environments, complete feature set'
        }
    }
    
    # Get modules for selected profile
    $profileInfo = $packageProfiles[$PackageProfile]
    $selectedModules = $profileInfo.Modules
    
    # Apply feature tier filtering if specified
    if ($FeatureTier) {
        Write-Host "Feature Tier: $FeatureTier" -ForegroundColor Cyan
        
        # Load feature registry
        $featureRegistryPath = Join-Path (Split-Path -Parent $PSScriptRoot) "configs/feature-registry.json"
        if (Test-Path $featureRegistryPath) {
            $featureRegistry = Get-Content $featureRegistryPath -Raw | ConvertFrom-Json
            
            # Get allowed modules for tier
            $allowedModules = @()
            $tierFeatures = $featureRegistry.tiers.$FeatureTier.features
            
            foreach ($feature in $tierFeatures) {
                if ($featureRegistry.features.$feature.modules) {
                    $allowedModules += $featureRegistry.features.$feature.modules
                }
            }
            
            # Add module overrides that are always available
            foreach ($override in $featureRegistry.moduleOverrides.PSObject.Properties) {
                if ($override.Value.alwaysAvailable) {
                    $allowedModules += $override.Name
                }
            }
            
            # Filter selected modules based on tier
            $originalCount = $selectedModules.Count
            $selectedModules = $selectedModules | Where-Object { $_ -in $allowedModules }
            $filteredCount = $originalCount - $selectedModules.Count
            
            if ($filteredCount -gt 0) {
                Write-Host "Filtered out $filteredCount modules due to $FeatureTier tier restrictions" -ForegroundColor Yellow
            }
        } else {
            Write-Warning "Feature registry not found. Building without tier restrictions."
        }
    }
    
    Write-Host "Package Profile: $PackageProfile" -ForegroundColor Yellow
    Write-Host "Description: $($profileInfo.Description)" -ForegroundColor Gray
    Write-Host "Use Case: $($profileInfo.UseCase)" -ForegroundColor Gray
    Write-Host "Estimated Size: $($profileInfo.EstimatedSize)" -ForegroundColor Gray
    Write-Host "Modules to include: $($selectedModules.Count)" -ForegroundColor Gray

    New-Item -Path (Join-Path $aithercoreDir "modules") -ItemType Directory -Force | Out-Null
    foreach ($module in $selectedModules) {
        $modulePath = Join-Path "aither-core" "modules" $module
        if (Test-Path $modulePath) {
            if ($progressAvailable) {
                Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Copying module: $module"
            }
            
            Copy-Item -Path $modulePath -Destination (Join-Path $aithercoreDir 'modules' $module) -Recurse -Force
            Write-Host "✓ Essential module: $module" -ForegroundColor Green
        } else {
            if ($progressAvailable) {
                # Still increment to maintain accurate progress
                Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Skipped missing module: $module"
                Add-ProgressWarning -OperationId $progressOperationId -Warning "Module not found: $module"
            }
        }
    }

    # Shared utilities
    if (Test-Path 'aither-core/shared') {
        if ($progressAvailable) {
            Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Copying shared utilities"
        }
        
        Copy-Item -Path 'aither-core/shared' -Destination "$aithercoreDir/shared" -Recurse -Force
        Write-Host '✓ Shared utilities' -ForegroundColor Green
    } else {
        if ($progressAvailable) {
            Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Skipped shared utilities"
        }
    }

    # Essential scripts directory (runtime scripts only)
    if (Test-Path 'aither-core/scripts') {
        if ($progressAvailable) {
            Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Processing runtime scripts"
        }
        
        New-Item -Path "$packageDir/scripts" -ItemType Directory -Force | Out-Null
        # Copy only runtime scripts, not development/build scripts
        $runtimeScripts = Get-ChildItem -Path 'aither-core/scripts' -Filter '*.ps1' -File |
        Where-Object { $_.Name -notlike '*test*' -and $_.Name -notlike '*dev*' -and $_.Name -notlike '*build*' }
        foreach ($script in $runtimeScripts) {
            Copy-Item -Path $script.FullName -Destination "$packageDir/scripts/" -Force
            Write-Host "✓ Runtime script: $($script.Name)" -ForegroundColor Green
        }
    } else {
        if ($progressAvailable) {
            Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Skipped scripts directory"
        }
    }

    # Essential configuration templates
    if ($progressAvailable) {
        Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Copying configuration templates"
    }
    
    New-Item -Path "$packageDir/configs" -ItemType Directory -Force | Out-Null
    $essentialConfigs = @(
        'default-config.json', 'core-runner-config.json', 'recommended-config.json', 'feature-registry.json'
    )
    foreach ($config in $essentialConfigs) {
        $configPath = "configs/$config"
        if (Test-Path $configPath) {
            Copy-Item -Path $configPath -Destination "$packageDir/configs/$config" -Force
            Write-Host "✓ Config template: $config" -ForegroundColor Green
        }
    }

    # OpenTofu templates (infrastructure automation core feature)
    if (Test-Path 'opentofu') {
        if ($progressAvailable) {
            Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Copying OpenTofu templates"
        }
        
        # Copy only essential OpenTofu files, not development/test environments
        New-Item -Path "$packageDir/opentofu" -ItemType Directory -Force | Out-Null
        $essentialTF = @('infrastructure', 'providers', 'modules')
        foreach ($tfDir in $essentialTF) {
            $tfPath = "opentofu/$tfDir"
            if (Test-Path $tfPath) {
                Copy-Item -Path $tfPath -Destination "$packageDir/opentofu/$tfDir" -Recurse -Force
                Write-Host "✓ OpenTofu: $tfDir" -ForegroundColor Green
            }
        }
    } else {
        if ($progressAvailable) {
            Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Skipped OpenTofu templates"
        }
    }

    # Essential documentation
    if ($progressAvailable) {
        Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Copying documentation"
    }
    
    Copy-Item -Path 'README.md' -Destination "$packageDir/README.md" -Force
    Copy-Item -Path 'LICENSE' -Destination "$packageDir/LICENSE" -Force
    Write-Host '✓ Essential documentation' -ForegroundColor Green

    # Copy FIXED launcher templates with validation
    Write-Host 'Copying and validating launcher templates...' -ForegroundColor Yellow
    
    if ($progressAvailable) {
        Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Creating and validating launchers"
    }
    
    # NEW: Copy modern CLI interface files (v1.4.1+)
    if (Test-Path 'aither.ps1') {
        Copy-Item -Path 'aither.ps1' -Destination "$packageDir/aither.ps1" -Force
        Write-Host '✓ Modern CLI interface (aither.ps1)' -ForegroundColor Green
    } else {
        Write-Warning 'Modern CLI interface (aither.ps1) not found'
        if ($progressAvailable) {
            Add-ProgressWarning -OperationId $progressOperationId -Warning "Modern CLI interface not found"
        }
    }
    
    if (Test-Path 'aither.bat') {
        Copy-Item -Path 'aither.bat' -Destination "$packageDir/aither.bat" -Force
        Write-Host '✓ Modern CLI batch wrapper (aither.bat)' -ForegroundColor Green
    } else {
        Write-Warning 'Modern CLI batch wrapper (aither.bat) not found'
        if ($progressAvailable) {
            Add-ProgressWarning -OperationId $progressOperationId -Warning "Modern CLI batch wrapper not found"
        }
    }
    
    if (Test-Path 'quick-setup-simple.ps1') {
        Copy-Item -Path 'quick-setup-simple.ps1' -Destination "$packageDir/quick-setup-simple.ps1" -Force
        Write-Host '✓ Quick setup script (quick-setup-simple.ps1)' -ForegroundColor Green
    } else {
        Write-Warning 'Quick setup script (quick-setup-simple.ps1) not found'
        if ($progressAvailable) {
            Add-ProgressWarning -OperationId $progressOperationId -Warning "Quick setup script not found"
        }
    }
    
    # CRITICAL: Validate PowerShell launcher template exists and has compatibility features
    $ps1TemplatePath = 'templates/launchers/Start-AitherZero.ps1'
    if (Test-Path $ps1TemplatePath) {
        $ps1Content = Get-Content $ps1TemplatePath -Raw
        
        # Validate template has PowerShell compatibility features
        $hasCompatibilityCheck = $ps1Content -match '\$psVersion.*PSVersionTable\.PSVersion\.Major'
        $hasBootstrapSupport = $ps1Content -match 'aither-core-bootstrap\.ps1'
        
        if ($hasCompatibilityCheck -and $hasBootstrapSupport) {
            # Template is valid - copy and update version
            $ps1Content = $ps1Content -replace 'v\d+\.\d+\.\d+', "v$Version"
            Set-Content -Path "$packageDir/Start-AitherZero.ps1" -Value $ps1Content -NoNewline
            Write-Host '✓ PowerShell launcher (validated template with compatibility)' -ForegroundColor Green
        } else {
            Write-Error "Template launcher is missing PowerShell compatibility features!"
            Write-Error "  Has version check: $hasCompatibilityCheck"
            Write-Error "  Has bootstrap support: $hasBootstrapSupport"
            throw "Template validation failed - launcher template is outdated"
        }
    } else {
        Write-Error "PowerShell launcher template not found at: $ps1TemplatePath"
        throw "Critical template missing - cannot create package"
    }

    if (Test-Path 'templates/launchers/AitherZero.bat') {
        # Copy and update version in batch launcher
        $batContent = Get-Content 'templates/launchers/AitherZero.bat' -Raw
        $batContent = $batContent -replace 'AitherZero v\d+\.\d+\.\d+', "AitherZero v$Version"
        Set-Content -Path "$packageDir/AitherZero.bat" -Value $batContent -NoNewline
        Write-Host '✓ Windows batch launcher (from template)' -ForegroundColor Green
    } else {
        Write-Warning 'Batch launcher template not found'
        if ($progressAvailable) {
            Add-ProgressWarning -OperationId $progressOperationId -Warning "Batch launcher template not found"
        }
    }

    # For non-Windows platforms, create Unix launcher script
    if ($Platform -ne 'windows') {
        $unixScript = "#!/bin/bash`necho `"🚀 AitherZero v$Version - $(if ($Platform -eq 'macos') { 'macOS' } else { 'Linux' }) Quick Start`"`necho `"Cross-Platform Infrastructure Automation with OpenTofu/Terraform`"`necho `"`"`npwsh -File `"Start-AitherZero.ps1`" `$@"
        Set-Content -Path "$packageDir/aitherzero.sh" -Value $unixScript -Encoding UTF8
        if (-not $IsWindows) {
            chmod +x "$packageDir/aitherzero.sh"
        }
        Write-Host '✓ Created Unix quick-start script' -ForegroundColor Green
    }

    # Create package metadata and docs
    Write-Host 'Creating package metadata...' -ForegroundColor Yellow
    
    if ($progressAvailable) {
        Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Creating metadata"
    }
    
    $packageInfo = @{
        Version        = $Version
        PackageType    = 'Application'
        PackageProfile = $PackageProfile
        BuildDate      = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss UTC')
        GitCommit      = $env:GITHUB_SHA
        GitRef         = $env:GITHUB_REF
        Platform       = $Platform
        Description    = $profileInfo.Description
        EstimatedSize  = $profileInfo.EstimatedSize
        UseCase        = $profileInfo.UseCase
        ModuleCount    = $selectedModules.Count
        Modules        = $selectedModules
        Components     = @(
            'Core runner', 'Platform modules', 'Configuration templates',
            'OpenTofu infrastructure', 'Application launcher'
        )
        Usage          = 'Run Start-AitherZero.ps1 to begin or aither-core.ps1 for direct access'
        Repository     = 'https://github.com/wizzense/AitherZero'
    }
    $packageInfo | ConvertTo-Json -Depth 3 | Set-Content "$packageDir/PACKAGE-INFO.json"

    # Create comprehensive installation guide
    $installGuide = @"
# AitherZero Application Package v$Version

## 🚀 Quick Start (30 Seconds)

### Windows Users:
1. **Double-click ``AitherZero.bat``** - that's it!
2. Or run: ``Start-AitherZero-Windows.ps1`` in PowerShell
3. Or run: ``pwsh -ExecutionPolicy Bypass -File Start-AitherZero.ps1``

### Linux/macOS Users:
1. **Run: ``./aitherzero.sh``** - that's it!
2. Or run: ``pwsh Start-AitherZero.ps1``

## 🔧 First Time Setup

Run setup wizard to check your environment:
```bash
# Windows
pwsh -ExecutionPolicy Bypass -File Start-AitherZero.ps1 -Setup

# Linux/macOS
./aitherzero.sh -Setup
```

## 📖 Usage Examples

```bash
# Interactive menu (default)
./Start-AitherZero.ps1

# Run all automation scripts
./Start-AitherZero.ps1 -Auto

# Run specific scripts
./Start-AitherZero.ps1 -Scripts 'LabRunner,BackupManager'

# Detailed output mode
./Start-AitherZero.ps1 -Verbosity detailed

# Get help
./Start-AitherZero.ps1 -Help
```

## ⚡ Requirements

- **PowerShell 7.0+** (required)
- **Git** (recommended for PatchManager and repository operations)
- **OpenTofu/Terraform** (recommended for infrastructure automation)

## 🔍 Troubleshooting

**Windows Execution Policy Issues:**
- Use ``AitherZero.bat`` (recommended)
- Or: ``pwsh -ExecutionPolicy Bypass -File Start-AitherZero.ps1``

**Module Loading Issues:**
- Run the setup: ``./Start-AitherZero.ps1 -Setup``
- Check PowerShell version: ``pwsh --version``

**Permission Issues (Linux/macOS):**
- Make executable: ``chmod +x aitherzero.sh``
- Or run directly: ``pwsh Start-AitherZero.ps1``

## 🌐 Support

- **Repository**: https://github.com/wizzense/AitherZero
- **Issues**: https://github.com/wizzense/AitherZero/issues
- **Documentation**: See repository docs/ folder for advanced usage
"@

    Set-Content -Path "$packageDir/INSTALL.md" -Value $installGuide
    Write-Host '✓ Installation guide created' -ForegroundColor Green

    # Calculate package size
    $packageSize = (Get-ChildItem -Path $packageDir -Recurse | Measure-Object -Property Length -Sum).Sum
    $packageSizeMB = [math]::Round($packageSize / 1MB, 2)

    Write-Host ''
    Write-Host '📦 Lean Application Package Created:' -ForegroundColor Green
    Write-Host "   Package: $packageName" -ForegroundColor White
    Write-Host "   Size: $packageSizeMB MB (lean build)" -ForegroundColor White
    Write-Host '   Type: Application (Essential components only)' -ForegroundColor White
    Write-Host ''

    Write-Host "✓ Package creation completed for $Platform" -ForegroundColor Green
    
    # Run validation if Test-PackageIntegrity.ps1 exists
    $validationScript = Join-Path (Split-Path $PSScriptRoot -Parent) "tests/validation/Test-PackageIntegrity.ps1"
    if (Test-Path $validationScript) {
        if ($progressAvailable) {
            Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Running validation"
        }
        
        Write-Host ''
        Write-Host '🔍 Running package integrity validation...' -ForegroundColor Cyan
        
        try {
            & $validationScript -PackagePath $packageDir -Platform $Platform -Version $Version -GenerateReport
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host '✅ Package validation passed!' -ForegroundColor Green
            } else {
                Write-Warning 'Package validation completed with warnings'
                if ($progressAvailable) {
                    Add-ProgressWarning -OperationId $progressOperationId -Warning "Package validation completed with warnings"
                }
            }
        } catch {
            Write-Warning "Package validation failed: $_"
            if ($progressAvailable) {
                Add-ProgressError -OperationId $progressOperationId -Error "Package validation failed: $_"
            }
        }
    } else {
        if ($progressAvailable) {
            Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Skipped validation"
        }
    }
    
    # Generate SHA256 checksum for archives
    if ($ArtifactExtension) {
        $archivePath = "$packageDir.$ArtifactExtension"
        
        if (Test-Path $archivePath) {
            Write-Host '🔐 Generating package checksum...' -ForegroundColor Yellow
            $hash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash
            Set-Content -Path "$archivePath.sha256" -Value $hash
            Write-Host "✓ SHA256: $hash" -ForegroundColor Green
        }
    }
    
    # CRITICAL: Post-build PowerShell compatibility validation
    Write-Host '🔍 Validating packaged launcher PowerShell compatibility...' -ForegroundColor Cyan
    
    $packagedLauncher = "$packageDir/Start-AitherZero.ps1"
    $packagedBootstrap = "$packageDir/aither-core-bootstrap.ps1"
    
    if (Test-Path $packagedLauncher) {
        $launcherContent = Get-Content $packagedLauncher -Raw
        
        # Validate packaged launcher has required features
        $validationResults = @{
            'PowerShell version detection' = $launcherContent -match '\$psVersion.*PSVersionTable\.PSVersion\.Major'
            'Bootstrap script support' = $launcherContent -match 'aither-core-bootstrap\.ps1'
            'PowerShell 5.1 compatibility' = $launcherContent -match 'if.*psVersion.*-lt 7'
            'Error handling for missing bootstrap' = $launcherContent -match 'bootstrap.*missing'
            'Cross-platform compatibility' = $launcherContent -match 'Cross-Platform.*Launcher'
        }
        
        $validationPassed = $true
        foreach ($check in $validationResults.GetEnumerator()) {
            if ($check.Value) {
                Write-Host "  ✅ $($check.Key)" -ForegroundColor Green
            } else {
                Write-Host "  ❌ $($check.Key)" -ForegroundColor Red
                $validationPassed = $false
            }
        }
        
        # Validate bootstrap script exists
        if (Test-Path $packagedBootstrap) {
            Write-Host "  ✅ Bootstrap script included" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Bootstrap script missing" -ForegroundColor Red
            $validationPassed = $false
        }
        
        if ($validationPassed) {
            Write-Host '✅ Package validation PASSED - PowerShell compatibility confirmed!' -ForegroundColor Green
        } else {
            Write-Error "Package validation FAILED - PowerShell compatibility issues detected!"
            throw "Package build failed validation - cannot release broken launcher"
        }
    } else {
        Write-Error "Packaged launcher not found at: $packagedLauncher"
        throw "Package build failed - launcher missing"
    }
    
    # Complete progress tracking if available
    if ($progressAvailable -and $progressOperationId) {
        Complete-ProgressOperation -OperationId $progressOperationId -ShowSummary
    }

} catch {
    # Log error to progress tracking if available
    if ($progressAvailable -and $progressOperationId) {
        Add-ProgressError -OperationId $progressOperationId -Error $_.Exception.Message
        Complete-ProgressOperation -OperationId $progressOperationId -ShowSummary
    }
    
    Write-Error "Build failed for $Platform : $($_.Exception.Message)"
    exit 1
}
