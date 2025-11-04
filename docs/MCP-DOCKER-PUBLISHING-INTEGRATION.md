# MCP Server and Docker Publishing Integration

## Overview

This document describes the implementation of automated MCP server publishing and Docker image deployment integrated into the AitherZero release workflow.

## What Was Added

### 1. MCP Server Publishing (npm to GitHub Packages)

**Package Details:**
- **Package Name:** `@aitherzero/mcp-server`
- **Registry:** GitHub Packages (npm.pkg.github.com)
- **Scope:** `@aitherzero`
- **Access:** Public

**Publishing Process:**
1. When a release is created (tag push or manual trigger)
2. MCP server is built from TypeScript source
3. Version in `package.json` is updated to match release version
4. Package is published to GitHub Packages
5. Tarball is created and attached to GitHub Release
6. Users can install via:
   - `npm install @aitherzero/mcp-server@<version>` (from GitHub Packages)
   - Download `.tgz` file from release assets

**Configuration Files:**
- `mcp-server/package.json` - Updated with publishing metadata
- `mcp-server/.npmrc` - GitHub Packages registry configuration
- `mcp-server/LICENSE` - Required for npm publishing

### 2. Docker Image Publishing (to GitHub Container Registry)

**Image Details:**
- **Registry:** GitHub Container Registry (ghcr.io)
- **Image Name:** `ghcr.io/wizzense/aitherzero`
- **Platforms:** linux/amd64, linux/arm64
- **Tags Generated:**
  - Version-specific: `1.0.0`, `1.0`, `1`
  - `latest` (for non-prerelease versions only)
  - SHA-based: `sha-<commit>`

**Publishing Process:**
1. Multi-stage Docker build using GitHub Actions
2. Images built for both amd64 and arm64 architectures
3. Pushed to GitHub Container Registry
4. Container health check validates image functionality
5. Users can pull via: `docker pull ghcr.io/wizzense/aitherzero:<version>`

### 3. GitHub Pages Documentation

**Added:**
- MCP server documentation automatically copied to `docs/mcp-server/`
- Deployed to GitHub Pages on every update
- Accessible at: `https://wizzense.github.io/AitherZero/docs/mcp-server/`

**Included Files:**
- `README.md` → `index.md`
- `QUICKSTART.md` → `quickstart.md`
- `IMPLEMENTATION-SUMMARY.md` → `implementation.md`

### 4. Enhanced Release Notes

Release notes now include:
- MCP server installation instructions
- Docker image usage examples
- AI assistant configuration (Claude, VS Code/Copilot)
- Links to package and container registries
- System requirements for each distribution format

## Workflow Changes

### `.github/workflows/release-automation.yml`

**New Jobs:**
1. `build-mcp-server` - Builds and publishes MCP server
   - Depends on: `create-release`
   - Timeout: 15 minutes
   - Outputs: Package tarball and npm publish

2. `publish-docker-image` - Builds and publishes Docker images
   - Depends on: `create-release`
   - Timeout: 30 minutes
   - Outputs: Multi-platform container images

**Modified Jobs:**
1. `post-release` - Updated to include new job dependencies and summary

**Permissions Added:**
- `packages: write` - Required for GitHub Packages and Container Registry

### `.github/workflows/jekyll-gh-pages.yml`

**Changes:**
1. Added path triggers for MCP server docs
2. Added step to copy MCP documentation to GitHub Pages
3. Updated deployment success message

## Installation Methods

### 1. Platform Package (Traditional)
```powershell
iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1 | iex
```

### 2. Docker Container (Isolated)
```bash
docker pull ghcr.io/wizzense/aitherzero:latest
docker run -it --rm ghcr.io/wizzense/aitherzero:latest
```

### 3. MCP Server (AI Integration)
```bash
npm install @aitherzero/mcp-server
```

## Testing the Implementation

To validate this implementation:

### 1. Test MCP Server Publishing
```bash
# Create a test release
git tag v1.0.1-test
git push origin v1.0.1-test

# Wait for workflow to complete
# Check GitHub Packages: https://github.com/wizzense/AitherZero/pkgs/npm/%40aitherzero%2Fmcp-server

# Test installation
npm install @aitherzero/mcp-server@1.0.1-test
```

### 2. Test Docker Publishing
```bash
# After release workflow completes
docker pull ghcr.io/wizzense/aitherzero:1.0.1-test

# Test the image
docker run --rm ghcr.io/wizzense/aitherzero:1.0.1-test pwsh -Command "Get-Module AitherZero -ListAvailable"
```

### 3. Test GitHub Pages Deployment
```bash
# After pages workflow completes
# Visit: https://wizzense.github.io/AitherZero/docs/mcp-server/
curl -I https://wizzense.github.io/AitherZero/docs/mcp-server/
```

## Security Considerations

1. **GitHub Token Permissions:**
   - `contents: write` - Create releases
   - `packages: write` - Publish to registries
   - `pages: write` - Deploy to GitHub Pages
   - `id-token: write` - OIDC authentication

2. **Container Security:**
   - Non-root user (`aitherzero`)
   - Health checks enabled
   - Multi-stage build for minimal image size

3. **Package Registry:**
   - Published to GitHub Packages (scoped to organization)
   - Public access for open-source distribution
   - Authenticated via `NODE_AUTH_TOKEN` (GITHUB_TOKEN)

## Architecture Benefits

### For Users:
- **Multiple Installation Options:** Choose the format that fits your use case
- **AI Integration:** Use natural language to manage infrastructure
- **Container Isolation:** Run in isolated environments without dependency conflicts
- **Version Control:** Pin to specific versions or use latest

### For Developers:
- **Automated Publishing:** No manual steps required
- **Multi-platform Support:** Reach more users (arm64, amd64)
- **Documentation Sync:** Always up-to-date on GitHub Pages
- **Release Coordination:** All artifacts published together

### For CI/CD:
- **Consistent Environments:** Docker images for reproducible builds
- **Easy Integration:** npm package for automation scripts
- **Platform Flexibility:** Use Docker, npm, or direct installation

## Future Enhancements

Potential improvements:
1. Publish MCP server to public npm registry (npmjs.com)
2. Add automated tests before publishing
3. Create separate Docker images for development/production
4. Add version compatibility checks
5. Implement automatic changelog generation
6. Add security scanning for container images
7. Create helm charts for Kubernetes deployment

## Troubleshooting

### MCP Server Publishing Fails
- Check `NODE_AUTH_TOKEN` is set correctly
- Verify `packages: write` permission
- Ensure version doesn't already exist
- Check package.json syntax

### Docker Publishing Fails
- Verify Dockerfile syntax
- Check platform compatibility
- Ensure sufficient disk space
- Review build logs for errors

### GitHub Pages Not Updating
- Check workflow triggered correctly
- Verify path patterns match
- Ensure Pages is enabled in repo settings
- Check deployment logs

## Related Documentation

- [MCP Server README](../mcp-server/README.md)
- [Docker Documentation](../DOCKER.md)
- [Release Automation Workflow](../.github/workflows/release-automation.yml)
- [GitHub Pages Workflow](../.github/workflows/jekyll-gh-pages.yml)

---

**Date:** 2025-11-02
**Version:** 1.0.0
**Status:** Implementation Complete ✅
