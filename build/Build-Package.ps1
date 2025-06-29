#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Build AitherZero application packages for release
.DESCRIPTION
    Creates lean application packages for different platforms with optional progress tracking
.PARAMETER Platform
    Target platform (windows, linux, macos)
.PARAMETER Version
    Package version
.PARAMETER ArtifactExtension
    Archive format extension (zip, tar.gz)
.PARAMETER NoProgress
    Disable visual progress tracking (useful for CI/CD environments)
#>

param(
    [Parameter(Mandatory)]
    [string]$Platform,

    [Parameter(Mandatory)]
    [string]$Version,

    [Parameter(Mandatory)]
    [string]$ArtifactExtension,
    
    [switch]$NoProgress
)

$ErrorActionPreference = 'Stop'

Write-Host "Building lean AitherZero application package for $Platform..." -ForegroundColor Cyan

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

    $packageName = "AitherZero-$Version-$Platform"
    $packageDir = "$buildDir/$packageName"
    New-Item -Path $packageDir -ItemType Directory -Force | Out-Null
    
    if ($progressAvailable) {
        Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Setting up package structure"
    }

    Write-Host "Creating lean application package: $packageName" -ForegroundColor Yellow
    Write-Host '📦 Application-focused build (not a repository copy)' -ForegroundColor Cyan
    
    if ($progressAvailable) {
        Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Preparing to copy files"
    }

    # Copy ONLY essential application files for running AitherZero
    Write-Host 'Copying core application files...' -ForegroundColor Yellow

    # Core runner and main entry point
    Copy-Item -Path 'aither-core/aither-core.ps1' -Destination "$packageDir/aither-core.ps1" -Force
    Write-Host '✓ Core runner script' -ForegroundColor Green
    
    if ($progressAvailable) {
        Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Copied core runner"
    }

    # Essential modules only (not dev/test modules)
    $essentialModules = @(
        'Logging', 'LabRunner', 'DevEnvironment', 'BackupManager',
        'ScriptManager', 'UnifiedMaintenance', 'ParallelExecution',
        'PatchManager', 'OpenTofuProvider', 'SecureCredentials',
        'ISOManager', 'ISOCustomizer', 'RemoteConnection', 'TestingFramework'
    )

    New-Item -Path (Join-Path $packageDir "modules") -ItemType Directory -Force | Out-Null
    foreach ($module in $essentialModules) {
        $modulePath = Join-Path "aither-core" "modules" $module
        if (Test-Path $modulePath) {
            if ($progressAvailable) {
                Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Copying module: $module"
            }
            
            Copy-Item -Path $modulePath -Destination (Join-Path $packageDir 'modules' $module) -Recurse -Force
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
        
        Copy-Item -Path 'aither-core/shared' -Destination "$packageDir/shared" -Recurse -Force
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
        'default-config.json', 'core-runner-config.json', 'recommended-config.json'
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

    # Copy FIXED launcher templates instead of generating inline
    Write-Host 'Copying fixed launcher templates...' -ForegroundColor Yellow
    
    if ($progressAvailable) {
        Update-ProgressOperation -OperationId $progressOperationId -IncrementStep -StepName "Creating launchers"
    }
    
    if (Test-Path 'templates/launchers/Start-AitherZero.ps1') {
        Copy-Item -Path 'templates/launchers/Start-AitherZero.ps1' -Destination "$packageDir/Start-AitherZero.ps1" -Force
        Write-Host '✓ PowerShell launcher (from template)' -ForegroundColor Green
    } else {
        Write-Warning 'PowerShell launcher template not found'
        if ($progressAvailable) {
            Add-ProgressWarning -OperationId $progressOperationId -Warning "PowerShell launcher template not found"
        }
    }

    if (Test-Path 'templates/launchers/AitherZero.bat') {
        Copy-Item -Path 'templates/launchers/AitherZero.bat' -Destination "$packageDir/AitherZero.bat" -Force
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
        Version     = $Version
        PackageType = 'Application'
        BuildDate   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss UTC')
        GitCommit   = $env:GITHUB_SHA
        GitRef      = $env:GITHUB_REF
        Platform    = $Platform
        Description = 'Lean AitherZero application package with essential components only'
        Components  = @(
            'Core runner', 'Essential modules', 'Configuration templates',
            'OpenTofu infrastructure', 'Application launcher'
        )
        Usage       = 'Run Start-AitherZero.ps1 to begin or aither-core.ps1 for direct access'
        Repository  = 'https://github.com/wizzense/AitherZero'
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
