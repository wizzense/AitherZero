# Publishing AitherZero to WinGet and PowerShell Gallery

This document provides comprehensive guidance on publishing AitherZero to WinGet (Windows Package Manager) and PowerShell Gallery.

## Table of Contents

- [Overview](#overview)
- [PowerShell Gallery Publishing](#powershell-gallery-publishing)
- [WinGet Publishing](#winget-publishing)
- [Automated Publishing Workflow](#automated-publishing-workflow)
- [Prerequisites](#prerequisites)
- [Manual Publishing Steps](#manual-publishing-steps)
- [Troubleshooting](#troubleshooting)

---

## Overview

AitherZero can be distributed through multiple channels:

| Channel | Purpose | Audience | Update Frequency |
|---------|---------|----------|------------------|
| **GitHub Releases** | Source code & archives | Developers, CI/CD | Every release |
| **Docker Hub/GHCR** | Container images | DevOps, Cloud deployments | Every release |
| **PowerShell Gallery** | PowerShell modules | PowerShell users worldwide | Every stable release |
| **WinGet** | Windows application packages | Windows users | Every stable release |

---

## PowerShell Gallery Publishing

### What is PowerShell Gallery?

[PowerShell Gallery](https://www.powershellgallery.com/) is the central repository for PowerShell content. It allows users to discover, install, and update PowerShell modules using `Install-Module` and `Update-Module` cmdlets.

### Benefits

- ✅ **Easy Installation**: Users can install with `Install-Module AitherZero`
- ✅ **Automatic Updates**: Built-in update mechanism via `Update-Module`
- ✅ **Global Reach**: Accessible to all PowerShell users worldwide
- ✅ **Versioning**: Supports semantic versioning and pre-releases
- ✅ **Dependencies**: Automatic dependency resolution
- ✅ **Trusted Source**: Official Microsoft-hosted repository

### Requirements

#### Module Requirements

1. **Valid Module Manifest** (`.psd1`):
   - ✅ ModuleVersion
   - ✅ Author
   - ✅ Description
   - ✅ GUID
   - ✅ PowerShellVersion (minimum required)
   - ✅ FunctionsToExport
   - ✅ PrivateData.PSData with Tags, ProjectUri, LicenseUri

2. **Module Structure**:
   ```
   AitherZero/
   ├── AitherZero.psd1      # Module manifest (required)
   ├── AitherZero.psm1      # Root module (required)
   ├── LICENSE              # License file (required)
   ├── README.md            # Documentation (recommended)
   └── domains/             # Additional module files
   ```

3. **Naming Conventions**:
   - Module name must be unique in PowerShell Gallery
   - Follow PowerShell naming guidelines
   - Use approved PowerShell verbs

4. **Code Quality**:
   - Pass PSScriptAnalyzer validation
   - No critical errors
   - Follow PowerShell best practices

#### Account Requirements

1. **PowerShell Gallery Account**:
   - Sign in with Microsoft account at [powershellgallery.com](https://www.powershellgallery.com)
   - Verify email address
   - Generate API key for publishing

2. **API Key**:
   - Generate from account settings
   - Store securely (use GitHub Secrets for CI/CD)
   - Never commit to source control

### Current Status

✅ **Ready to Publish:**
- Valid module manifest with all required fields
- MIT License included
- ProjectUri and LicenseUri configured
- Module structure follows PowerShell standards
- Tags defined for discoverability

⚠️ **Before First Publish:**
- Validate module passes `Test-ModuleManifest`
- Ensure no naming conflicts
- Run PSScriptAnalyzer validation
- Test module installation locally

### Publishing Process

#### Automated (via GitHub Actions)

The workflow automatically publishes to PowerShell Gallery on stable releases:

```yaml
# Triggered on: Release published (non-prerelease)
name: Publish to PowerShell Gallery
on:
  release:
    types: [published]
```

**What it does:**
1. Validates module manifest
2. Runs PSScriptAnalyzer
3. Tests module loading
4. Publishes to PowerShell Gallery using API key
5. Verifies publication

#### Manual Publishing

```powershell
# 1. Prepare the module
Import-Module ./AitherZero.psd1 -Force

# 2. Validate manifest
Test-ModuleManifest ./AitherZero.psd1

# 3. Run quality checks
Invoke-ScriptAnalyzer -Path ./AitherZero.psm1 -Recurse

# 4. Publish to PowerShell Gallery
Publish-Module -Path . -NuGetApiKey $env:PSGALLERY_API_KEY -Verbose

# 5. Verify publication
Find-Module -Name AitherZero
```

### Installation After Publishing

Once published, users can install AitherZero with:

```powershell
# Install from PowerShell Gallery
Install-Module -Name AitherZero -Scope CurrentUser

# Import the module
Import-Module AitherZero

# Verify installation
Get-Module AitherZero
```

### Updating Existing Installation

```powershell
# Update to latest version
Update-Module -Name AitherZero

# Install specific version
Install-Module -Name AitherZero -RequiredVersion 1.2.0
```

---

## WinGet Publishing

### What is WinGet?

[WinGet](https://github.com/microsoft/winget-pkgs) is the Windows Package Manager, a comprehensive package manager solution for Windows. It allows users to discover, install, upgrade, remove, and configure applications.

### Benefits

- ✅ **Native Windows Integration**: Built into Windows 10/11
- ✅ **Simple Commands**: `winget install AitherZero`
- ✅ **Automatic Updates**: `winget upgrade --all`
- ✅ **Official Microsoft Tool**: Trusted by Windows users
- ✅ **Version Management**: Install specific versions easily
- ✅ **Silent Installation**: Ideal for automation and deployment

### Requirements

#### Package Requirements

1. **Installer or Portable Application**:
   - Downloadable installer (.msi, .exe, .msix, .appx)
   - OR portable archive (.zip with executable)
   - Publicly accessible URL (GitHub releases recommended)

2. **Manifest Files**:
   Three manifest files required in YAML format:
   - **Version Manifest** (`{Publisher}.{PackageName}.yaml`)
   - **Installer Manifest** (`{Publisher}.{PackageName}.installer.yaml`)
   - **Locale Manifest** (`{Publisher}.{PackageName}.locale.en-US.yaml`)

3. **Package Information**:
   - Unique package identifier (e.g., `Wizzense.AitherZero`)
   - Publisher information
   - License type and agreement
   - SHA256 hash of installer
   - Installation parameters

#### Repository Requirements

1. **Fork winget-pkgs Repository**:
   - Fork [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs)
   - Clone your fork
   - Create manifests in `manifests/w/Wizzense/AitherZero/{version}/`

2. **Pull Request Process**:
   - Submit PR to microsoft/winget-pkgs
   - Automated validation runs
   - Manual review by Microsoft team
   - Approval and merge (typically 1-7 days)

### Current Status

⚠️ **Preparation Needed:**

AitherZero is currently a PowerShell module without a traditional Windows installer. To publish to WinGet, we need to choose one of these approaches:

#### Option 1: Create a Windows Installer (Recommended)

**Create an MSI or EXE installer that:**
- Copies module files to a standard location
- Registers the module in PowerShell module path
- Creates Start Menu shortcuts
- Handles uninstallation cleanly

**Tools for creating installers:**
- WiX Toolset (MSI)
- Inno Setup (EXE)
- Advanced Installer (MSI)
- NSIS (EXE)

**Pros:**
- ✅ Professional installation experience
- ✅ Proper Windows integration
- ✅ Easy uninstallation
- ✅ Better for non-technical users

**Cons:**
- ❌ More complex build process
- ❌ Requires installer maintenance
- ❌ Larger package size

#### Option 2: Portable ZIP Package

**Use GitHub release ZIP with a wrapper script:**
- Package the module as a portable ZIP
- Include a setup script that installs to PowerShell module path
- WinGet downloads and extracts the ZIP
- User runs setup script

**Pros:**
- ✅ Simple to maintain
- ✅ Leverages existing release artifacts
- ✅ Smaller package size

**Cons:**
- ❌ Requires manual setup step
- ❌ Less polished user experience
- ❌ May confuse non-technical users

#### Option 3: PowerShell Script Installer

**Create a minimal EXE wrapper:**
- Small EXE that launches PowerShell
- Runs the bootstrap script automatically
- Provides GUI progress indicator

**Pros:**
- ✅ One-click installation
- ✅ Familiar to Windows users
- ✅ Can use existing bootstrap.ps1

**Cons:**
- ❌ Still requires development effort
- ❌ May trigger antivirus warnings

### Recommended Approach

**For AitherZero, we recommend Option 1 (Windows Installer) for the following reasons:**

1. **Professional Experience**: Provides a standard Windows installation experience
2. **WinGet Compatibility**: Best practice for WinGet packages
3. **Easy Discovery**: Users can find it in Windows Settings > Apps
4. **Clean Uninstall**: Proper removal through Windows mechanisms
5. **Future-Proof**: Supports additional Windows integrations (context menus, etc.)

### WinGet Manifest Structure

Once we have an installer, the manifests will look like this:

#### 1. Version Manifest (`Wizzense.AitherZero.yaml`)

```yaml
# yaml-language-server: $schema=https://aka.ms/winget-manifest.version.1.6.0.schema.json

PackageIdentifier: Wizzense.AitherZero
PackageVersion: 1.2.0
DefaultLocale: en-US
ManifestType: version
ManifestVersion: 1.6.0
```

#### 2. Installer Manifest (`Wizzense.AitherZero.installer.yaml`)

```yaml
# yaml-language-server: $schema=https://aka.ms/winget-manifest.installer.1.6.0.schema.json

PackageIdentifier: Wizzense.AitherZero
PackageVersion: 1.2.0
MinimumOSVersion: 10.0.17763.0
InstallerType: wix
Scope: user
InstallModes:
- interactive
- silent
- silentWithProgress
InstallerSwitches:
  Silent: /quiet
  SilentWithProgress: /passive
UpgradeBehavior: install
ReleaseDate: 2025-01-15
Installers:
- Architecture: x64
  InstallerUrl: https://github.com/wizzense/AitherZero/releases/download/v1.2.0/AitherZero-v1.2.0-Setup.msi
  InstallerSha256: [SHA256_HASH_HERE]
  ProductCode: '{PRODUCT_GUID_HERE}'
ManifestType: installer
ManifestVersion: 1.6.0
```

#### 3. Locale Manifest (`Wizzense.AitherZero.locale.en-US.yaml`)

```yaml
# yaml-language-server: $schema=https://aka.ms/winget-manifest.defaultLocale.1.6.0.schema.json

PackageIdentifier: Wizzense.AitherZero
PackageVersion: 1.2.0
PackageLocale: en-US
Publisher: Wizzense
PublisherUrl: https://github.com/wizzense
PublisherSupportUrl: https://github.com/wizzense/AitherZero/issues
PackageName: AitherZero
PackageUrl: https://github.com/wizzense/AitherZero
License: MIT
LicenseUrl: https://github.com/wizzense/AitherZero/blob/main/LICENSE
Copyright: Copyright (c) 2025 Aitherium Contributors
ShortDescription: Infrastructure automation platform with AI-powered orchestration
Description: |-
  AitherZero is an enterprise infrastructure automation platform featuring:
  - Number-based orchestration system (0000-9999)
  - Cross-platform support (Windows, Linux, macOS)
  - OpenTofu/Terraform integration
  - Comprehensive testing and validation
  - Domain-driven architecture
  - CI/CD automation
Moniker: aitherzero
Tags:
- automation
- infrastructure
- devops
- powershell
- terraform
- opentofu
- orchestration
- ci-cd
ReleaseNotes: See https://github.com/wizzense/AitherZero/releases/tag/v1.2.0
ReleaseNotesUrl: https://github.com/wizzense/AitherZero/releases/tag/v1.2.0
ManifestType: defaultLocale
ManifestVersion: 1.6.0
```

### Publishing Process (Once Installer Ready)

1. **Create Release with Installer**:
   ```bash
   # Build installer (MSI/EXE)
   # Upload to GitHub Release
   ```

2. **Generate WinGet Manifests**:
   ```bash
   # Install WinGet manifest creator
   winget install wingetcreate
   
   # Generate manifests
   wingetcreate new https://github.com/wizzense/AitherZero/releases/download/v1.2.0/AitherZero-Setup.msi
   ```

3. **Submit to WinGet**:
   ```bash
   # Fork winget-pkgs if not already done
   gh repo fork microsoft/winget-pkgs --clone
   
   # Create manifests directory
   mkdir -p manifests/w/Wizzense/AitherZero/1.2.0
   
   # Copy generated manifests
   cp *.yaml manifests/w/Wizzense/AitherZero/1.2.0/
   
   # Create PR
   git checkout -b aitherzero-1.2.0
   git add manifests/w/Wizzense/AitherZero/
   git commit -m "New version: Wizzense.AitherZero version 1.2.0"
   git push origin aitherzero-1.2.0
   
   # Create pull request
   gh pr create --repo microsoft/winget-pkgs --title "New version: Wizzense.AitherZero version 1.2.0"
   ```

4. **Automated Validation**:
   - WinGet team's bots validate manifests
   - Checks for proper YAML format
   - Verifies installer URL accessibility
   - Validates SHA256 hash
   - Checks for duplicate packages

5. **Manual Review**:
   - Microsoft team reviews submission
   - Typically takes 1-7 days
   - May request changes

6. **Approval and Merge**:
   - Once approved, manifests are merged
   - Package becomes available in WinGet within hours

### Installation After Publishing

Once published to WinGet, users can install with:

```powershell
# Search for the package
winget search AitherZero

# Install the package
winget install Wizzense.AitherZero

# Install specific version
winget install Wizzense.AitherZero --version 1.2.0

# Upgrade to latest
winget upgrade Wizzense.AitherZero

# Uninstall
winget uninstall Wizzense.AitherZero
```

---

## Automated Publishing Workflow

### GitHub Actions Integration

The publishing workflows are triggered automatically on release:

```yaml
name: Publish to Distribution Channels
on:
  release:
    types: [published]

jobs:
  publish-to-psgallery:
    # Publishes to PowerShell Gallery
    
  publish-to-winget:
    # Creates WinGet manifest PR
```

### Secrets Required

Configure these secrets in GitHub repository settings:

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `PSGALLERY_API_KEY` | PowerShell Gallery API key | Generate from [PowerShell Gallery account](https://www.powershellgallery.com/account/apikeys) |
| `WINGET_PAT` | GitHub PAT for WinGet PR | Generate from [GitHub Settings](https://github.com/settings/tokens) with `public_repo` scope |

### Workflow Features

- ✅ Automatic version detection from release tag
- ✅ Manifest validation before publishing
- ✅ Quality checks (PSScriptAnalyzer)
- ✅ Rollback capability on failure
- ✅ Notification on success/failure
- ✅ Dry-run mode for testing

---

## Prerequisites

### For PowerShell Gallery

1. **Create PowerShell Gallery Account**:
   - Visit https://www.powershellgallery.com
   - Sign in with Microsoft account
   - Verify email address

2. **Generate API Key**:
   - Go to https://www.powershellgallery.com/account/apikeys
   - Click "Create"
   - Set expiration (365 days recommended)
   - Select "Push new packages and package versions"
   - Copy API key immediately (shown only once)

3. **Add to GitHub Secrets**:
   - Go to GitHub repository Settings > Secrets and variables > Actions
   - Click "New repository secret"
   - Name: `PSGALLERY_API_KEY`
   - Value: Paste the API key
   - Click "Add secret"

### For WinGet

1. **Create Windows Installer** (if not already done):
   - Choose installer type (MSI recommended)
   - Set up build process
   - Test installer locally
   - Include in release artifacts

2. **Fork WinGet Repository**:
   ```bash
   gh repo fork microsoft/winget-pkgs --clone
   ```

3. **Generate GitHub PAT**:
   - Go to https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Select `public_repo` scope
   - Generate and copy token

4. **Add to GitHub Secrets**:
   - Repository Settings > Secrets and variables > Actions
   - Name: `WINGET_PAT`
   - Value: Paste the PAT

---

## Manual Publishing Steps

### Publishing to PowerShell Gallery Manually

```powershell
# Step 1: Validate the module
Test-ModuleManifest ./AitherZero.psd1

# Step 2: Test module loads correctly
Import-Module ./AitherZero.psd1 -Force
Get-Module AitherZero

# Step 3: Run quality checks
Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1

# Step 4: Test publishing (dry run)
Publish-Module -Path . -NuGetApiKey $env:PSGALLERY_API_KEY -WhatIf

# Step 5: Publish to PowerShell Gallery
Publish-Module -Path . -NuGetApiKey $env:PSGALLERY_API_KEY -Verbose

# Step 6: Verify publication (wait a few minutes)
Find-Module -Name AitherZero
```

### Publishing to WinGet Manually

```bash
# Step 1: Generate manifests using wingetcreate
wingetcreate new https://github.com/wizzense/AitherZero/releases/download/v1.2.0/AitherZero-Setup.msi

# Step 2: Review generated manifests
cat Wizzense.AitherZero.yaml
cat Wizzense.AitherZero.installer.yaml
cat Wizzense.AitherZero.locale.en-US.yaml

# Step 3: Validate manifests
winget validate --manifest manifests/w/Wizzense/AitherZero/1.2.0/

# Step 4: Test installation locally
winget install --manifest manifests/w/Wizzense/AitherZero/1.2.0/

# Step 5: Create PR to microsoft/winget-pkgs
cd winget-pkgs
git checkout -b aitherzero-1.2.0
mkdir -p manifests/w/Wizzense/AitherZero/1.2.0
cp ../manifests/*.yaml manifests/w/Wizzense/AitherZero/1.2.0/
git add manifests/w/Wizzense/AitherZero/
git commit -m "New version: Wizzense.AitherZero version 1.2.0"
git push origin aitherzero-1.2.0
gh pr create --title "New version: Wizzense.AitherZero version 1.2.0" --body "Automated submission for AitherZero v1.2.0"
```

---

## Troubleshooting

### PowerShell Gallery Issues

#### Problem: "Module name already exists"
**Solution**: Module names must be unique. If claimed, choose a different name or contact existing owner.

#### Problem: "Invalid manifest"
```powershell
# Test manifest validity
Test-ModuleManifest ./AitherZero.psd1

# Common issues:
# - Invalid GUID format
# - Missing required fields
# - Incorrect version format
```

#### Problem: "PSScriptAnalyzer errors"
```powershell
# Run analyzer to find issues
Invoke-ScriptAnalyzer -Path . -Recurse

# Fix reported issues or suppress specific rules
# in PSScriptAnalyzerSettings.psd1
```

#### Problem: "Authentication failed"
**Solution**: Verify API key is correct and not expired. Generate new key if needed.

### WinGet Issues

#### Problem: "Installer hash mismatch"
```powershell
# Calculate correct hash
$hash = Get-FileHash -Path AitherZero-Setup.msi -Algorithm SHA256
$hash.Hash
# Update InstallerSha256 in manifest
```

#### Problem: "Installer URL not accessible"
**Solution**: Ensure the installer is in a public GitHub release. Check URL is correct and accessible.

#### Problem: "Validation failed"
```bash
# Validate manifests locally
winget validate --manifest manifests/w/Wizzense/AitherZero/1.2.0/

# Fix any reported issues
```

#### Problem: "PR rejected"
**Solution**: Read reviewer comments carefully. Common issues:
- Missing or incorrect metadata
- License mismatch
- Installer issues
- Non-standard manifest format

---

## Summary

### PowerShell Gallery: ✅ Ready to Publish

**Current State**: Module is ready for publishing
**Next Step**: Configure API key and run publish workflow
**Estimated Time**: 15 minutes to set up, instant publication

### WinGet: ⚠️ Requires Installer

**Current State**: Need to create Windows installer
**Next Steps**:
1. Choose installer approach (MSI recommended)
2. Set up installer build process
3. Add installer to release workflow
4. Create WinGet manifests
5. Submit to WinGet repository

**Estimated Time**:
- Installer development: 2-4 hours
- Manifest creation: 30 minutes
- PR submission and approval: 1-7 days

### Recommended Timeline

**Phase 1: PowerShell Gallery (Immediate)**
- Week 1: Set up publishing workflow
- Week 1: Publish first version
- Ongoing: Automatic publishing with releases

**Phase 2: WinGet (Optional, Long-term)**
- Week 2-3: Design and build Windows installer
- Week 4: Test installer thoroughly
- Week 5: Create WinGet manifests
- Week 5-6: Submit to WinGet and await approval

---

## Additional Resources

### PowerShell Gallery
- [PowerShell Gallery](https://www.powershellgallery.com/)
- [Publishing Guidelines](https://docs.microsoft.com/en-us/powershell/gallery/how-to/publishing-packages/publishing-a-package)
- [Manifest Documentation](https://docs.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest)

### WinGet
- [WinGet Documentation](https://docs.microsoft.com/en-us/windows/package-manager/)
- [winget-pkgs Repository](https://github.com/microsoft/winget-pkgs)
- [Manifest Schema](https://github.com/microsoft/winget-pkgs/tree/master/doc/manifest/schema)
- [WinGet Create Tool](https://github.com/microsoft/winget-create)

### Tools
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
- [WiX Toolset](https://wixtoolset.org/) (MSI creation)
- [Inno Setup](https://jrsoftware.org/isinfo.php) (EXE creation)

---

**Last Updated**: 2025-10-29
**Version**: 1.0
**Maintained By**: AitherZero Team
