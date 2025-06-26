#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Build AitherZero application packages for release
.DESCRIPTION
    Creates lean application packages for different platforms
.PARAMETER Platform
    Target platform (windows, linux, macos)
.PARAMETER Version
    Package version
.PARAMETER ArtifactExtension
    Archive format extension (zip, tar.gz)
#>

param(
    [Parameter(Mandatory)]
    [string]$Platform,

    [Parameter(Mandatory)]
    [string]$Version,

    [Parameter(Mandatory)]
    [string]$ArtifactExtension
)

$ErrorActionPreference = 'Stop'

Write-Host "Building lean AitherZero application package for $Platform..." -ForegroundColor Cyan

try {
    $buildDir = "build-output/$Platform"
    New-Item -Path $buildDir -ItemType Directory -Force | Out-Null

    $packageName = "AitherZero-$Version-$Platform"
    $packageDir = "$buildDir/$packageName"
    New-Item -Path $packageDir -ItemType Directory -Force | Out-Null

    Write-Host "Creating lean application package: $packageName" -ForegroundColor Yellow
    Write-Host '📦 Application-focused build (not a repository copy)' -ForegroundColor Cyan

    # Copy ONLY essential application files for running AitherZero
    Write-Host 'Copying core application files...' -ForegroundColor Yellow

    # Core runner and main entry point
    Copy-Item -Path 'aither-core/aither-core.ps1' -Destination "$packageDir/aither-core.ps1" -Force
    Write-Host '✓ Core runner script' -ForegroundColor Green

    # Essential modules only (not dev/test modules)
    $essentialModules = @(
        'Logging', 'LabRunner', 'DevEnvironment', 'BackupManager',
        'ScriptManager', 'UnifiedMaintenance', 'ParallelExecution'
    )

    New-Item -Path "$packageDir/modules" -ItemType Directory -Force | Out-Null
    foreach ($module in $essentialModules) {
        $modulePath = "aither-core/modules/$module"
        if (Test-Path $modulePath) {
            Copy-Item -Path $modulePath -Destination "$packageDir/modules/$module" -Recurse -Force
            Write-Host "✓ Essential module: $module" -ForegroundColor Green
        }
    }

    # Shared utilities
    if (Test-Path 'aither-core/shared') {
        Copy-Item -Path 'aither-core/shared' -Destination "$packageDir/shared" -Recurse -Force
        Write-Host '✓ Shared utilities' -ForegroundColor Green
    }

    # Essential scripts directory (runtime scripts only)
    if (Test-Path 'aither-core/scripts') {
        New-Item -Path "$packageDir/scripts" -ItemType Directory -Force | Out-Null
        # Copy only runtime scripts, not development/build scripts
        $runtimeScripts = Get-ChildItem -Path 'aither-core/scripts' -Filter '*.ps1' -File |
        Where-Object { $_.Name -notlike '*test*' -and $_.Name -notlike '*dev*' -and $_.Name -notlike '*build*' }
        foreach ($script in $runtimeScripts) {
            Copy-Item -Path $script.FullName -Destination "$packageDir/scripts/" -Force
            Write-Host "✓ Runtime script: $($script.Name)" -ForegroundColor Green
        }
    }

    # Essential configuration templates
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
    }

    # Essential documentation
    Copy-Item -Path 'README.md' -Destination "$packageDir/README.md" -Force
    Copy-Item -Path 'LICENSE' -Destination "$packageDir/LICENSE" -Force
    Write-Host '✓ Essential documentation' -ForegroundColor Green

    # Copy FIXED launcher templates instead of generating inline
    Write-Host 'Copying fixed launcher templates...' -ForegroundColor Yellow
    if (Test-Path 'templates/launchers/Start-AitherZero.ps1') {
        Copy-Item -Path 'templates/launchers/Start-AitherZero.ps1' -Destination "$packageDir/Start-AitherZero.ps1" -Force
        Write-Host '✓ PowerShell launcher (from template)' -ForegroundColor Green
    } else {
        Write-Warning 'PowerShell launcher template not found'
    }

    if (Test-Path 'templates/launchers/AitherZero.bat') {
        Copy-Item -Path 'templates/launchers/AitherZero.bat' -Destination "$packageDir/AitherZero.bat" -Force
        Write-Host '✓ Windows batch launcher (from template)' -ForegroundColor Green
    } else {
        Write-Warning 'Batch launcher template not found'
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

} catch {
    Write-Error "Build failed for $Platform : $($_.Exception.Message)"
    exit 1
}
