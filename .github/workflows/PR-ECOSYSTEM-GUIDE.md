# Complete PR Ecosystem - Quick Reference

## 🎯 Overview

Every PR targeting **main**, **dev**, **dev-staging**, or **ring-*** branches gets a **complete self-contained deployment ecosystem**.

## 🚀 What You Get

### For PR #123 targeting 'dev' branch:

#### 🐳 Docker Container
```bash
# Pull the container
docker pull ghcr.io/wizzense/aitherzero:pr-123-dev-latest

# Run it
docker run -it --rm ghcr.io/wizzense/aitherzero:pr-123-dev-latest

# View on GitHub
https://github.com/wizzense/AitherZero/pkgs/container/aitherzero
```

**Available Tags:**
- `pr-123-dev-latest` (primary, updates with each push)
- `pr-123-latest` (quick reference)
- `pr-123-a1b2c3d4` (commit-specific, immutable)
- `dev-pr-123-latest` (ring-specific)

#### 📊 GitHub Pages Dashboard
```
https://wizzense.github.io/AitherZero/dev/library/reports/pr-123/
```

**Includes:**
- Full interactive dashboard
- Test results and coverage
- Code quality metrics
- Workflow health metrics
- Ring deployment status
- Performance metrics

#### 📦 Release Packages
**Artifact Name**: `build-artifacts-pr-123`

**Download from**: GitHub Actions → Workflow Run → Artifacts

**Files:**
- `AitherZero-v{version}-pr123.zip` (Windows/Cross-platform)
- `AitherZero-v{version}-pr123.tar.gz` (Linux/macOS)
- `build-metadata.json` (Build information)

**Contents**: Complete AitherZero runtime with all modules

## 📋 Branch-Specific Deployment Paths

| Your PR Targets | Docker Tag | Dashboard URL |
|-----------------|------------|---------------|
| `main` | `pr-{N}-main-latest` | `/{repo}/library/reports/pr-{N}/` |
| `dev` | `pr-{N}-dev-latest` | `/{repo}/dev/library/reports/pr-{N}/` |
| `dev-staging` | `pr-{N}-dev-staging-latest` | `/{repo}/dev-staging/library/reports/pr-{N}/` |
| `ring-0` | `pr-{N}-ring-0-latest` | `/{repo}/ring-0/library/reports/pr-{N}/` |
| `ring-1` | `pr-{N}-ring-1-latest` | `/{repo}/ring-1/library/reports/pr-{N}/` |
| `ring-2` | `pr-{N}-ring-2-latest` | `/{repo}/ring-2/library/reports/pr-{N}/` |

## 🔄 Workflow Flow

```
1. You open PR #123 targeting 'dev'
   ↓
2. Three workflows run in parallel:
   ├── pr-check.yml → Builds packages, runs tests
   ├── 04-deploy-pr-environment.yml → Publishes Docker container
   └── 05-publish-reports-dashboard.yml → Deploys dashboard
   ↓
3. PR comment shows ecosystem status with direct links
   ↓
4. Complete ecosystem ready! 🎉
   - 🐳 Docker: ghcr.io/.../pr-123-dev-latest
   - 📊 Dashboard: .../dev/library/reports/pr-123/
   - 📦 Packages: Download from artifacts
```

## 💬 PR Comment Format

After workflows complete, you'll see a comment like:

```markdown
## ✅ PR Check - PASSED

### 📋 Validation Results
| Check | Status |
|-------|--------|
| ✅ Validation | SUCCESS |
| ✅ Tests | SUCCESS |
| ✅ Build | SUCCESS |
| ✅ Docker | SUCCESS |
| ✅ Docs | SUCCESS |

### 🚀 PR Ecosystem Status

#### 🐳 Docker Container
- Image Tag: `ghcr.io/wizzense/aitherzero:pr-123-dev-latest`
- Package URL: https://github.com/.../pkgs/container/aitherzero
- Status: ✅ Published

#### 📊 Dashboard & GitHub Pages
- Dashboard URL: https://wizzense.github.io/AitherZero/dev/library/reports/pr-123/
- Status: ✅ Deployed

#### 📦 Release Packages
- Format: ZIP and TAR.GZ
- Naming: `AitherZero-v{version}-pr123.{zip|tar.gz}`
- Status: ✅ Available now

### 🔗 Quick Links
- Workflow Run
- Test Artifacts
- Build Artifacts
- Container Packages
```

## 🎓 Key Features

### 1. Branch-Aware Isolation
- Each target branch has its own deployment path
- PRs to `dev` don't conflict with PRs to `main`
- Ring deployments are completely isolated

### 2. Automatic Updates
- Every push to your PR branch updates:
  - Docker container (new tags)
  - Dashboard (refreshed)
  - Packages (rebuilt)

### 3. Parallel Execution
- All three workflows run simultaneously
- Different concurrency groups prevent conflicts
- Fast feedback (typically 5-10 minutes total)

### 4. Self-Contained
- Everything you need in one place
- No manual deployment steps
- Just open a PR and get the full ecosystem!

## 🔍 Finding Your Deployments

### Docker Container
1. Go to: https://github.com/{owner}/{repo}/pkgs/container/aitherzero
2. Filter by tag: `pr-{your-pr-number}-`
3. Click to see all tags and pull commands

### Dashboard
1. Check the PR comment for the direct URL
2. Or construct: `https://{owner}.github.io/{repo}/{branch-path}/library/reports/pr-{number}/`
3. Bookmark it for quick access!

### Release Packages
1. Go to the workflow run (link in PR comment)
2. Scroll to "Artifacts" section at bottom
3. Download `build-artifacts-pr-{number}`

## ⚡ Tips & Tricks

### Testing the Docker Container Locally
```bash
# Pull your PR's container
docker pull ghcr.io/wizzense/aitherzero:pr-123-dev-latest

# Run it interactively
docker run -it --rm ghcr.io/wizzense/aitherzero:pr-123-dev-latest pwsh

# Check version
docker run --rm ghcr.io/wizzense/aitherzero:pr-123-dev-latest cat /app/VERSION
```

### Viewing Dashboard Metrics
```bash
# Open in browser
open https://wizzense.github.io/AitherZero/dev/library/reports/pr-123/

# Or use curl to check deployment
curl -I https://wizzense.github.io/AitherZero/dev/library/reports/pr-123/
```

### Downloading Packages via CLI
```bash
# Using GitHub CLI
gh run download {run-id} -n build-artifacts-pr-123

# Extract and test
unzip AitherZero-*.zip
cd AitherZero
pwsh -Command "Import-Module ./AitherZero.psd1"
```

## 🛠️ Troubleshooting

### "Dashboard not found" (404)
- Wait 2-3 minutes for GitHub Pages to update
- Check workflow status (05-publish-reports-dashboard.yml)
- Verify PR is targeting a supported branch

### "Docker pull fails"
- Ensure you're authenticated: `echo $PAT | docker login ghcr.io -u USERNAME --password-stdin`
- Verify tag exists in package registry
- Check workflow status (04-deploy-pr-environment.yml)

### "No artifacts available"
- Wait for pr-check.yml workflow to complete
- Check if build job succeeded
- Artifacts expire after 30 days

## 📚 More Information

- **Full Documentation**: `.github/workflows/WORKFLOW-ARCHITECTURE.md`
- **Workflow Fixes**: `.github/workflows/FIXES-SUMMARY.md`
- **Quick Reference**: `.github/workflows/README-WORKFLOW-FIXES.md`

---

**Questions?** Check the PR comment for status updates and direct links to all ecosystem components!
