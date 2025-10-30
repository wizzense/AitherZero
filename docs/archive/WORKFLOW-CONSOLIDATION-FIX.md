# Workflow Consolidation and Release Fix

## Problem Statement

Docker images and cross-platform releases were not being built/published properly due to:
1. Redundant and conflicting workflow files (`docker-publish.yml` vs `deploy-pr-environment.yml`)
2. VERSION file set to "0.0.0.0" instead of "1.0.0.0"
3. YAML syntax error in `validate-config.yml` (markdown formatting in YAML string)
4. Workflow triggers not properly coordinated

## Root Cause

The repository had **two separate workflows** attempting to build Docker images:

1. **`docker-publish.yml`** - Triggered on `release: [published]`
2. **`deploy-pr-environment.yml`** - Triggered on `pull_request`, `push: tags`, and `release: [published]`

This caused conflicts and redundant builds. The `deploy-pr-environment.yml` workflow was already working correctly for PRs but also had release support that wasn't being utilized properly.

## Solution

### 1. Unified Workflow Architecture

**Primary Workflow**: `deploy-pr-environment.yml` (ALREADY WORKING)
- Handles **both PR preview environments AND production releases**
- Triggers:
  - `pull_request` → Build PR preview images (tags: `pr-X`, `pr-X-sha-xxx`)
  - `push: tags ['v*']` → Build release images (tags: `v1.0.0`, `1.0`, `1`, `latest`)
  - `release: [published]` → Build release images
  - `workflow_dispatch` → Manual builds
- Features:
  - Multi-platform builds (amd64, arm64)
  - Docker validation before build
  - Security scanning for releases
  - Smart image tagging based on event type
  - GitHub Container Registry (ghcr.io) publishing

**Secondary Workflow**: `release-automation.yml`
- Handles GitHub Release creation and artifacts
- Triggers: `push: tags ['v*']` and `workflow_dispatch`
- Creates:
  - GitHub Releases with release notes
  - ZIP and TAR.GZ source archives
  - Build metadata JSON
- Does NOT build Docker images (handled by deploy-pr-environment.yml)

**Disabled Workflow**: `docker-publish.yml` → `docker-publish.yml.disabled`
- Redundant with deploy-pr-environment.yml
- Was causing duplicate builds and conflicts
- Kept as reference but disabled

### 2. Release Flow (Working)

```
Developer Action: git push origin v1.0.0.0
         ↓
    [Tag Push Event]
         ↓
         ├─→ release-automation.yml
         │   ├─ Pre-release validation (syntax, tests, analysis)
         │   ├─ Update VERSION and AitherZero.psd1
         │   ├─ Create release packages (ZIP, TAR.GZ)
         │   ├─ Generate release notes
         │   └─ Create GitHub Release (publishes)
         │
         └─→ deploy-pr-environment.yml
             ├─ Detect release event (is-release: true)
             ├─ Validate Docker configuration
             ├─ Build multi-platform image
             ├─ Tag: v1.0.0.0, 1.0.0, 1.0, 1, latest
             ├─ Push to ghcr.io/wizzense/aitherzero
             └─ Security scan (Trivy)

Result: Complete release with GitHub artifacts AND Docker images
```

### 3. What Was Fixed

#### Version Updates
- ✅ `VERSION`: "0.0.0.0" → "1.0.0.0"
- ✅ `AitherZero.psd1`: ModuleVersion "0.0.0.0" → "1.0.0.0"

#### Workflow Fixes
- ✅ Disabled redundant `docker-publish.yml`
- ✅ Fixed YAML syntax error in `validate-config.yml` (line 114: removed markdown bold `**Status**` in YAML string)
- ✅ Documented that `deploy-pr-environment.yml` handles ALL Docker builds

#### Workflow Validation
- ✅ Runs actionlint on all workflows (no blocking errors)
- ✅ Shellcheck warnings in deploy-pr-environment.yml are non-critical (quoting style)

### 4. How to Release 1.0.0.0

```bash
# 1. Ensure changes are committed
git add VERSION AitherZero.psd1 .github/workflows/
git commit -m "fix: prepare version 1.0.0.0 release with consolidated workflows"
git push origin main

# 2. Create and push version tag
git tag -a v1.0.0.0 -m "Release v1.0.0.0 - Consolidated workflows and cross-platform support"
git push origin v1.0.0.0

# 3. Monitor GitHub Actions
# - release-automation.yml will create the GitHub Release
# - deploy-pr-environment.yml will build and push Docker images
# Both workflows run in parallel and are independent

# 4. Verify release
gh release view v1.0.0.0
docker pull ghcr.io/wizzense/aitherzero:v1.0.0.0
docker pull ghcr.io/wizzense/aitherzero:latest
```

### 5. Architecture Benefits

✅ **Single source of truth** for Docker builds (deploy-pr-environment.yml)
✅ **Works for both PRs and releases** (no duplication)
✅ **Multi-platform support** (linux/amd64, linux/arm64)
✅ **Smart tagging** based on event type (PR vs release)
✅ **Security scanning** for production releases
✅ **No conflicts** between workflows
✅ **Faster releases** (parallel execution)

### 6. PR Preview vs Release Images

#### PR Preview (Ephemeral)
- **Tags**: `pr-123`, `pr-123-sha-abc1234`
- **Purpose**: Testing and validation
- **Lifecycle**: Temporary, for PR review
- **Command**: `docker pull ghcr.io/wizzense/aitherzero:pr-123`

#### Release (Production)
- **Tags**: `v1.0.0.0`, `1.0.0`, `1.0`, `1`, `latest`
- **Purpose**: Production deployment
- **Lifecycle**: Permanent, immutable
- **Command**: `docker pull ghcr.io/wizzense/aitherzero:latest`

### 7. Platform Support

✅ **Windows**: Download ZIP from GitHub Release
✅ **Linux**: Download TAR.GZ from GitHub Release OR use Docker
✅ **macOS**: Download TAR.GZ from GitHub Release OR use Docker
✅ **Docker (all platforms)**: `docker pull ghcr.io/wizzense/aitherzero:latest`

### 8. Troubleshooting

#### If release doesn't create Docker images:
```bash
# Check if deploy-pr-environment.yml ran
gh run list --workflow="Deploy PR Environment and Releases" --limit 5

# View logs
gh run view <run-id> --log

# Manually trigger Docker build
gh workflow run "Deploy PR Environment and Releases" \
  --field release_tag=v1.0.0.0
```

#### If tag already exists:
```bash
# Delete remote tag
git push --delete origin v1.0.0.0

# Delete local tag
git tag -d v1.0.0.0

# Recreate and push
git tag -a v1.0.0.0 -m "Release v1.0.0.0"
git push origin v1.0.0.0
```

## Summary

The release system now uses a **unified workflow architecture** where:
- `deploy-pr-environment.yml` handles ALL Docker image builds (PRs + releases)
- `release-automation.yml` handles GitHub Release creation and artifacts
- Both workflows are triggered by tag pushes and work independently
- No redundancy, no conflicts, cross-platform support works correctly

**Ready to release 1.0.0.0!** 🚀
