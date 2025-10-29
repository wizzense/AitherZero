# AitherCore Build and Distribution

This directory contains build scripts and workflows for creating distributable packages of AitherCore.

## Overview

AitherCore is packaged as a standalone distribution containing 11 essential modules from AitherZero. The build process creates platform-specific packages for Windows, Linux, and macOS.

## Build Process

### Local Build

To build packages locally:

```powershell
# Build for all platforms
./tools/Build-AitherCorePackage.ps1

# Build for specific platforms
./tools/Build-AitherCorePackage.ps1 -Platforms Windows,Linux

# Build with specific version
./tools/Build-AitherCorePackage.ps1 -Version "1.0.1"

# Build with examples
./tools/Build-AitherCorePackage.ps1 -IncludeExamples

# Build to custom output directory
./tools/Build-AitherCorePackage.ps1 -OutputPath "./releases"

# Skip validation (faster build)
./tools/Build-AitherCorePackage.ps1 -SkipValidation
```

### Automated Build (GitHub Actions)

The build workflow can be triggered:

1. **Manual Dispatch** - From GitHub Actions UI:
   - Go to Actions → "Build AitherCore Packages"
   - Click "Run workflow"
   - Specify version and options

2. **Git Tag** - Push a tag:
   ```bash
   git tag aithercore-v1.0.0
   git push origin aithercore-v1.0.0
   ```

3. **Automated Release** - The workflow will:
   - Build packages for all platforms (Windows, Linux, macOS)
   - Run validation tests
   - Create GitHub release with all packages
   - Generate release notes

## Package Contents

Each platform package includes:

### Core Files
- **11 PowerShell Modules**:
  - Logging.psm1, Configuration.psm1, TextUtilities.psm1
  - Performance.psm1, Bootstrap.psm1, PackageManager.psm1
  - BetterMenu.psm1, UserInterface.psm1
  - Infrastructure.psm1, Security.psm1, OrchestrationEngine.psm1
- **AitherCore.psd1** - Module manifest
- **AitherCore.psm1** - Module loader

### Documentation
- README.md - Overview and module descriptions
- USAGE-EXAMPLES.md - Practical code examples
- QUICKSTART.md - 5-minute quick start guide
- ARCHITECTURAL-REVIEW-COMPLETE.md - Detailed analysis
- COMPREHENSIVE-ANALYSIS-REPORT.md - Module breakdown
- ARCHITECTURE-DECISION.md - Design rationale

### Installation Scripts
- **Windows**: `Install-Windows.ps1`
- **Linux/macOS**: `Install-Unix.ps1`

### Additional Files
- LICENSE - Software license
- VERSION.txt - Build information

## Package Formats

- **Windows**: `.zip` archive
- **Linux**: `.tar.gz` archive
- **macOS**: `.tar.gz` archive

## Installation

### Windows

```powershell
# Extract
Expand-Archive -Path AitherCore-v1.0.0-Windows.zip -DestinationPath .
cd AitherCore

# Install for current user
./Install-Windows.ps1

# Install for all users (requires admin)
./Install-Windows.ps1 -Scope AllUsers

# Verify
Import-Module AitherCore
Get-Module AitherCore
```

### Linux/macOS

```bash
# Extract
tar -xzf AitherCore-v1.0.0-Linux.tar.gz
cd AitherCore

# Install for current user
pwsh ./Install-Unix.ps1

# Install for all users (requires sudo)
sudo pwsh ./Install-Unix.ps1 -Scope AllUsers

# Verify
pwsh -c "Import-Module AitherCore; Get-Module AitherCore"
```

## Build Script Features

### Validation
- Checks all 11 required modules are present
- Validates module manifest
- Tests module loading
- Verifies function exports (90 functions)

### Package Structure
- Creates proper PowerShell module directory layout
- Includes platform-specific installation scripts
- Generates VERSION.txt with build information
- Preserves all documentation

### Platform Support
- Windows (PowerShell 7+)
- Linux (PowerShell 7+)
- macOS (PowerShell 7+)

### Build Options
- `OutputPath` - Where to create packages (default: ./dist/aithercore)
- `Version` - Package version (default: from manifest)
- `Platforms` - Target platforms (Windows, Linux, macOS, All)
- `IncludeExamples` - Include example scripts
- `SkipValidation` - Skip validation for faster builds

## GitHub Actions Workflow

### Workflow Inputs

**version** (required): Package version (e.g., "1.0.0")  
**include_examples** (optional): Include example scripts (default: false)  
**create_release** (optional): Create GitHub Release (default: true)

### Workflow Jobs

1. **build-packages** - Builds packages on all platforms in parallel
   - Runs on Ubuntu, Windows, and macOS runners
   - Validates package contents
   - Uploads artifacts

2. **create-release** - Creates GitHub release
   - Downloads all platform packages
   - Generates release notes
   - Creates tagged release
   - Attaches all package files

## Development

### Testing the Build

```powershell
# Quick validation
./tools/Build-AitherCorePackage.ps1 -Platforms Windows -SkipValidation

# Full build with validation
./tools/Build-AitherCorePackage.ps1 -Platforms All

# Test package installation
cd ./dist/aithercore
Expand-Archive AitherCore-v1.0.0-Windows.zip -DestinationPath ./test
cd test/AitherCore
Import-Module ./AitherCore.psd1
Get-Command -Module AitherCore | Measure-Object
```

### Build Artifacts

Build artifacts are stored in:
- Local builds: `./dist/aithercore/`
- GitHub Actions: Available as workflow artifacts
- Releases: Attached to GitHub releases

### Troubleshooting

**Problem**: Module fails to load  
**Solution**: Check that all 11 modules are present in source

**Problem**: Package size too large  
**Solution**: Ensure only necessary files are included, no temp files

**Problem**: Installation script fails  
**Solution**: Verify PowerShell 7+ is installed and execution policy allows scripts

## Release Checklist

Before creating a release:

1. ✅ Update version in AitherCore.psd1
2. ✅ Test module loads locally
3. ✅ Run full validation: `./tools/Build-AitherCorePackage.ps1 -Platforms All`
4. ✅ Review package contents
5. ✅ Test installation on target platform
6. ✅ Update CHANGELOG.md
7. ✅ Tag release: `git tag aithercore-v1.0.0`
8. ✅ Push tag: `git push origin aithercore-v1.0.0`
9. ✅ Verify GitHub Actions build completes
10. ✅ Test download and install from release

## Statistics

- **Package Size**: ~200-300 KB per platform (compressed)
- **Uncompressed**: ~7,500 lines of PowerShell code
- **Build Time**: ~30-60 seconds per platform
- **Total Functions**: 90 exported functions
- **Documentation**: 6 comprehensive guides

## Support

For issues with the build process:
- Check workflow logs in GitHub Actions
- Review build script output
- Ensure all prerequisites are met
- Open an issue with build logs

For AitherCore usage questions:
- See documentation in the package
- Visit: https://github.com/wizzense/AitherZero
