# Official Release Process

## Overview

This document describes the official release process for AitherZero, including versioning, building, tagging, and publishing releases to multiple distribution channels:

- **GitHub Releases**: Source code, archives, and Docker images
- **PowerShell Gallery**: PowerShell module for easy installation
- **WinGet**: Windows Package Manager (requires installer - in development)

For detailed publishing information, see [PUBLISHING-GUIDE.md](PUBLISHING-GUIDE.md).

## 🚀 Quick Release (New!)

**The easiest way to create a release is from a pull request comment:**

```
/release v1.2.3
```

That's it! See [Comment-Triggered Releases](COMMENT-RELEASE.md) for full details.

## Release Methods

AitherZero supports two release methods:

### 1. Comment-Triggered Release (Recommended)
Comment on a PR with `/release vX.Y.Z` to automatically create a release. See [COMMENT-RELEASE.md](COMMENT-RELEASE.md) for complete documentation.

**Pros:**
- ✅ Fastest and simplest method
- ✅ One command from PR
- ✅ Automatic version file updates
- ✅ Built-in validation
- ✅ Progress notifications

**Usage:**
```
/release v1.2.3          # Stable release
/release v1.2.3 --pre    # Pre-release
```

### 2. Manual Tag Push (Traditional)
Manually update version files, commit, and push a tag. See below for complete steps.

**Pros:**
- ✅ Full control over commit message
- ✅ Works from any branch
- ✅ Can be scripted

**Usage:**
```bash
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
```

---

## Release Types

### Stable Releases
- **Format:** `v1.2.3` (semantic versioning)
- **Branch:** `main`
- **Frequency:** As needed
- **Testing:** Full test suite + validation
- **Artifacts:** ZIP, TAR.GZ, Docker images

### Pre-releases
- **Format:** `v1.2.3-beta.1`, `v1.2.3-rc.1`
- **Branch:** `main` or feature branches
- **Testing:** Standard test suite
- **Purpose:** Testing before stable release

### Development Builds
- **Format:** Not tagged (use branch names)
- **Testing:** Minimal
- **Purpose:** Internal testing only

## Versioning Strategy

AitherZero follows [Semantic Versioning 2.0.0](https://semver.org/):

- **MAJOR** (v2.0.0.0): Breaking changes, incompatible API changes
- **MINOR** (v1.1.1.0): New features, backward compatible
- **PATCH** (v1.0.1.0): Bug fixes, backward compatible
- **HOTFIX** (v1.0.1.1)

### Current Version: 1.1.0

## Prerequisites

Before creating a release:

1. ✅ All tests passing on main branch
2. ✅ Code quality checks passing (PSScriptAnalyzer)
3. ✅ Documentation up to date
4. ✅ CHANGELOG updated (use `./automation-scripts/0798_generate-changelog.ps1`)
5. ✅ VERSION file updated
6. ✅ Module manifest version updated (AitherZero.psd1)

## Release Checklist

### 1. Prepare Release Branch

```powershell
# Update version files
$version = "1.1.0"

# Update VERSION file
$version | Set-Content ./VERSION -NoNewline

# Update module manifest
$manifestPath = "./AitherZero.psd1"
$manifest = Import-PowerShellDataFile $manifestPath
$manifest.ModuleVersion = $version
# ... (update manifest - use Update-ModuleManifest in practice)

# Commit version bump
git add VERSION AitherZero.psd1
git commit -m "chore: bump version to v$version"
git push
```

### 2. Generate Changelog

```powershell
# Generate changelog from last release
./automation-scripts/0798_generate-changelog.ps1 -FromTag v1.0.7 -ToTag HEAD -Output CHANGELOG.md
```

### 3. Run Pre-Release Validation

```powershell
# Full validation suite
./automation-scripts/0407_validate-powershell-syntax.ps1
./automation-scripts/0402_run-unit-tests.ps1
./automation-scripts/0404_run-psscriptanalyzer.ps1

# Verify module loads
Import-Module ./AitherZero.psd1 -Force
Get-Module AitherZero
```

### 4. Tag the Release

```bash
# Create annotated tag
git tag -a v1.1.0 -m "Release v1.1.0"

# Push tag to trigger release workflow
git push origin v1.1.0
```

### 5. Monitor Release Workflow

The `release-automation.yml` workflow will automatically:

1. ✅ Run pre-release validation
2. ✅ Build release packages (ZIP, TAR.GZ)
3. ✅ Generate build info and release notes
4. ✅ Create GitHub Release
5. ✅ Upload release assets
6. ✅ Update `latest` tag (for stable releases)

The `docker-publish.yml` workflow will automatically:

1. ✅ Build Docker images for linux/amd64 and linux/arm64
2. ✅ Push images to GitHub Container Registry (ghcr.io)
3. ✅ Tag images appropriately (version, latest, sha)
4. ✅ Run security scan with Trivy
5. ✅ Test image functionality

### 6. Verify Release

```bash
# Check release on GitHub
gh release view v1.1.0

# Verify Docker image
docker pull ghcr.io/wizzense/aitherzero:v1.1.0
docker run -it --rm ghcr.io/wizzense/aitherzero:v1.1.0 pwsh -NoProfile -Command "Import-Module /opt/aitherzero/AitherZero.psd1; Get-Module AitherZero"

# Test installation from release
$url = "https://github.com/wizzense/AitherZero/releases/download/v1.1.0/AitherZero-v1.1.0.zip"
Invoke-WebRequest -Uri $url -OutFile "AitherZero-v1.1.0.zip"
Expand-Archive -Path "AitherZero-v1.1.0.zip" -DestinationPath ./test-install
cd test-install
./bootstrap.ps1 -Mode New -NonInteractive
```

### 7. Post-Release Tasks

- [ ] Update GitHub release notes if needed
- [ ] Announce release on relevant channels
- [ ] Update documentation website
- [ ] Create GitHub Discussion for release
- [ ] Monitor for issues/bug reports
- [ ] Plan next release cycle

## Manual Release (Workflow Dispatch)

You can also trigger releases manually:

```yaml
# Via GitHub Actions UI:
# 1. Go to Actions → Release Automation
# 2. Click "Run workflow"
# 3. Enter version number (e.g., 1.1.0)
# 4. Select if pre-release
# 5. Click "Run workflow"
```

Or via GitHub CLI:

```bash
gh workflow run release-automation.yml \
  -f version=1.1.0 \
  -f prerelease=false \
  -f run_full_tests=true
```

## Docker Image Publishing

### Automatic Publishing

Docker images are automatically built and published when:
- A version tag is pushed (e.g., `v1.1.0`)
- A GitHub release is published

### Manual Docker Build

```bash
# Build locally
docker build -t aitherzero:local .

# Build and push manually
gh workflow run docker-publish.yml \
  -f tag=v1.1.0 \
  -f push_to_registry=true
```

### Docker Image Tags

The following tags are automatically created:

- `v1.1.0` - Specific version
- `1.1` - Minor version
- `1` - Major version
- `latest` - Latest stable release
- `sha-abc1234` - Specific commit SHA

### Using Docker Images

```bash
# Pull specific version
docker pull ghcr.io/wizzense/aitherzero:v1.1.0

# Pull latest
docker pull ghcr.io/wizzense/aitherzero:latest

# Run interactively
docker run -it --rm ghcr.io/wizzense/aitherzero:latest

# Run with Docker Compose
docker-compose up -d
```

## Tag Management

### Clean Up Old Tags

To maintain a clean tag history, periodically run:

```powershell
# Dry run to see what would be deleted
./automation-scripts/0799_cleanup-old-tags.ps1 -DryRun

# Actually delete old tags
./automation-scripts/0799_cleanup-old-tags.ps1
```

This removes:
- Development tags (`vdev-*`)
- Old pre-v0.7 version tags
- Optionally v0.7.x and v0.8.x tags (if not needed)

### Tag Naming Convention

- **Stable releases:** `v1.2.3`
- **Pre-releases:** `v1.2.3-beta.1`, `v1.2.3-rc.1`
- **Latest pointer:** `latest` (force-updated)
- **DO NOT USE:** `vdev-*` or custom naming schemes

## Release Assets

Each release includes:

1. **AitherZero-vX.Y.Z.zip** - Windows-compatible archive
2. **AitherZero-vX.Y.Z.tar.gz** - Unix-compatible archive
3. **build-info.json** - Build metadata and information
4. **Docker images** - Multi-platform container images (ghcr.io)

## Troubleshooting

### Release Workflow Failed

1. Check GitHub Actions logs
2. Verify all tests pass locally
3. Ensure VERSION and manifest are updated
4. Check for syntax errors with `./automation-scripts/0407_validate-powershell-syntax.ps1`

### Docker Build Failed

1. Test Docker build locally: `docker build -t test .`
2. Check Dockerfile syntax
3. Verify all files are included (check .dockerignore)
4. Check GitHub Container Registry permissions

### Tag Already Exists

```bash
# Delete local tag
git tag -d v1.1.0

# Delete remote tag
git push origin --delete v1.1.0

# Recreate tag
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin v1.1.0
```

## Best Practices

1. **Always use annotated tags:** `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
2. **Test before tagging:** Run full validation suite
3. **Update changelog:** Document all changes
4. **Semantic versioning:** Follow semver strictly
5. **Clear release notes:** Explain what's new and what's changed
6. **Monitor releases:** Watch for issues after release
7. **Keep tags clean:** Remove old development tags
8. **Test Docker images:** Verify containers work before announcing

## Release Schedule

- **Major releases:** As needed (breaking changes)
- **Minor releases:** Monthly or when features are ready
- **Patch releases:** As needed (bug fixes)
- **Pre-releases:** Before major/minor releases for testing

## Distribution Channels

### PowerShell Gallery

AitherZero automatically publishes to PowerShell Gallery on stable releases.

**Status**: ✅ Ready to publish (workflow configured in `.github/workflows/publish-psgallery.yml`)

**Setup Required**:
1. Generate API key at https://www.powershellgallery.com/account/apikeys
2. Add to GitHub secrets as `PSGALLERY_API_KEY`
3. Future releases will automatically publish

**User Installation** (after first publish):
```powershell
Install-Module -Name AitherZero
Import-Module AitherZero
```

**Benefits**:
- ✅ Easy installation with `Install-Module`
- ✅ Automatic updates via `Update-Module`
- ✅ Global reach to PowerShell users
- ✅ Semantic versioning support

### WinGet (Windows Package Manager)

**Status**: ⚠️ In Development (requires Windows installer)

**Current Approach**: Template manifests and generation script ready
- Script: `automation-scripts/0797_generate-winget-manifests.ps1`
- Templates: `winget-manifests/*.template`

**What's Needed**:
1. Create a Windows installer (MSI or EXE)
2. Generate WinGet manifests using provided script
3. Submit PR to microsoft/winget-pkgs

**Future User Installation**:
```powershell
winget install Wizzense.AitherZero
```

**Documentation**: See [PUBLISHING-GUIDE.md](PUBLISHING-GUIDE.md) for detailed instructions on both publishing channels.

## Questions?

- Open an issue: https://github.com/wizzense/AitherZero/issues
- Start a discussion: https://github.com/wizzense/AitherZero/discussions

---

**Last Updated:** 2025-10-29
**Current Version:** v1.1.0
