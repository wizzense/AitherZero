# Complete Branch Build Ecosystem

## 🎯 Overview

Every push to **main**, **dev**, **dev-staging**, or **ring-*** branches triggers a complete, fully-published build ecosystem that includes:

1. 🐳 **Docker Container** - Multi-platform image published to GHCR
2. 🧪 **Test Execution** - Comprehensive validation and quality checks
3. 📊 **Dashboard & Reports** - Interactive metrics and test results
4. 📄 **GitHub Pages** - Branch-specific documentation deployment

## 🔄 Complete Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Developer pushes to main/dev/dev-staging/ring-*            │
└─────────────────────┬───────────────────────────────────────┘
                      │
      ┌───────────────┼───────────────┬───────────────────┐
      │               │               │                   │
      ▼               ▼               ▼                   ▼
┌──────────┐   ┌─────────────┐  ┌──────────┐     ┌──────────────┐
│ deploy   │   │ 03-test-    │  │ 09-jekyll│     │ 05-publish-  │
│ .yml     │   │ execution   │  │ -gh-pages│     │ reports-     │
│          │   │ .yml        │  │ .yml     │     │ dashboard    │
└────┬─────┘   └──────┬──────┘  └────┬─────┘     │ .yml         │
     │                │              │            │ (after tests)│
     │                │              │            └──────────────┘
     ▼                ▼              ▼                   ▲
┌──────────┐   ┌─────────────┐  ┌──────────┐           │
│ Docker   │   │ Test        │  │ Jekyll   │           │
│ Image    │   │ Results     │  │ Site     │           │
│ Built    │   │ Generated   │  │ Built    │           │
└────┬─────┘   └──────┬──────┘  └────┬─────┘           │
     │                │              │                  │
     ▼                │              │                  │
┌──────────┐          └──────────────┼──────────────────┘
│ Push to  │                         │ (workflow_run)
│ GHCR     │                         │
└────┬─────┘                         ▼
     │                         ┌──────────┐
     ▼                         │ Dashboard│
┌──────────┐                   │ Published│
│ ghcr.io/ │                   └────┬─────┘
│ {repo}:  │                        │
│ {branch} │                        ▼
└──────────┘                   ┌──────────┐
                               │ GitHub   │
                               │ Pages    │
                               │ Updated  │
                               └──────────┘
```

## 🚀 Workflow Responsibilities

### 1. deploy.yml - Docker Build & Push

**Triggers:** Push to main/dev/dev-staging/ring-* branches

**Actions:**
- ✅ Builds multi-platform Docker images (amd64, arm64)
- ✅ Pushes to GitHub Container Registry (ghcr.io)
- ✅ Tags with branch name and commit SHA
- ✅ Deploys to staging (if dev-staging branch)

**Outputs:**
- Docker image: `ghcr.io/{owner}/{repo}:{branch}`
- Docker image: `ghcr.io/{owner}/{repo}:sha-{commit}`

**Summary:**
- Provides complete deployment status
- Links to test execution workflow
- Links to GitHub Pages dashboard
- Shows container registry location

**Concurrency:** `deploy-${{ github.ref }}` (per-branch)

### 2. 03-test-execution.yml - Test & Validation

**Triggers:** 
- Push to main/dev/dev-staging/ring-* branches
- Called by pr-check.yml for PRs (workflow_call)
- Manual execution (workflow_dispatch)

**Actions:**
- ✅ Runs unit tests (by script ranges)
- ✅ Runs domain tests (by module)
- ✅ Runs integration tests
- ✅ Generates code coverage reports
- ✅ Validates code quality

**Outputs:**
- Test results (XML, JSON) as artifacts
- Coverage reports as artifacts
- Test execution summary

**Triggers After Completion:**
- `05-publish-reports-dashboard.yml` (via workflow_run)

**Concurrency:** `tests-${{ github.ref }}` (per-branch)

### 3. 05-publish-reports-dashboard.yml - Dashboard Publishing

**Triggers:** 
- After 03-test-execution.yml completes (workflow_run)
- Pull request events
- Manual execution

**Actions:**
- ✅ Collects test results from 03-test-execution.yml
- ✅ Generates interactive HTML dashboard
- ✅ Creates JSON metrics files
- ✅ Publishes to branch-specific GitHub Pages path
- ✅ Creates PR-specific dashboards (for PRs)

**Outputs:**
- Dashboard at: `https://{owner}.github.io/{repo}/{branch}/library/reports/`
- PR dashboard at: `https://{owner}.github.io/{repo}/{branch}/library/reports/pr-{number}/`

**Concurrency:** `publish-reports-dashboard-${{ github.ref }}` (per-branch)

### 4. 09-jekyll-gh-pages.yml - GitHub Pages Deployment

**Triggers:**
- Push to main/dev/dev-staging/ring-* branches (when paths match)
- Manual execution

**Paths Monitored:**
- `library/reports/**`
- `library/**`
- `index.md`
- `_config.yml`
- `integrations/mcp-server/README.md`

**Actions:**
- ✅ Builds Jekyll site with branch-specific configuration
- ✅ Creates branch information page
- ✅ Deploys to branch-specific subdirectory
- ✅ Preserves other branch deployments (keep_files: true)

**Deployment Paths:**
- main → `/` (root)
- dev → `/dev/`
- dev-staging → `/dev-staging/`
- ring-0 → `/ring-0/`
- ring-1 → `/ring-1/`
- ring-2 → `/ring-2/`

**Concurrency:** `jekyll-pages-${{ github.ref }}` (per-branch)

## 📊 Branch-Specific Artifacts

### For main branch push:

| Artifact | Location |
|----------|----------|
| **Docker Image** | `ghcr.io/{owner}/{repo}:main` |
| **Dashboard** | `https://{owner}.github.io/{repo}/` |
| **Reports** | `https://{owner}.github.io/{repo}/library/reports/` |
| **Test Results** | Artifacts in 03-test-execution.yml run |

### For dev branch push:

| Artifact | Location |
|----------|----------|
| **Docker Image** | `ghcr.io/{owner}/{repo}:dev` |
| **Dashboard** | `https://{owner}.github.io/{repo}/dev/` |
| **Reports** | `https://{owner}.github.io/{repo}/dev/library/reports/` |
| **Test Results** | Artifacts in 03-test-execution.yml run |

### For dev-staging branch push:

| Artifact | Location |
|----------|----------|
| **Docker Image** | `ghcr.io/{owner}/{repo}:dev-staging` |
| **Dashboard** | `https://{owner}.github.io/{repo}/dev-staging/` |
| **Reports** | `https://{owner}.github.io/{repo}/dev-staging/library/reports/` |
| **Test Results** | Artifacts in 03-test-execution.yml run |
| **Staging Deploy** | https://staging.aitherzero.example.com |

### For ring-* branches:

| Artifact | Location |
|----------|----------|
| **Docker Image** | `ghcr.io/{owner}/{repo}:ring-{N}` |
| **Dashboard** | `https://{owner}.github.io/{repo}/ring-{N}/` |
| **Reports** | `https://{owner}.github.io/{repo}/ring-{N}/library/reports/` |
| **Test Results** | Artifacts in 03-test-execution.yml run |

## 🎓 Key Features

### 1. Complete Isolation

Each branch has its own deployment path - no conflicts between branches!

- main deployments don't affect dev
- dev deployments don't affect staging
- ring deployments are completely separate

### 2. Parallel Execution

All workflows run in parallel for maximum speed:

- Docker builds while tests run
- Jekyll builds while dashboard generates
- Independent concurrency groups prevent conflicts

### 3. Automatic Triggers

No manual steps required - everything is automatic:

1. Push to branch → All workflows trigger
2. Tests complete → Dashboard publishes
3. Reports updated → GitHub Pages rebuilds

### 4. Branch-Aware URLs

All URLs include branch context:

- Docker: `ghcr.io/{repo}:{branch}`
- Dashboard: `https://{owner}.github.io/{repo}/{branch}/`
- Tests reference correct branch deployment

## 📈 Performance Expectations

### Typical Timeline (from push to complete):

```
0:00 - Push received
0:01 - Workflows start (deploy, test-execution, jekyll-gh-pages)
0:02 - Docker build begins (multi-platform)
0:02 - Test execution begins (parallel test suites)
0:02 - Jekyll build begins (if paths match)
0:05 - Tests complete (~3-5 minutes)
0:06 - Dashboard publishing begins (after tests)
0:08 - Docker build completes (~6-8 minutes for multi-platform)
0:08 - Jekyll site deployed (~6-8 minutes total)
0:10 - Dashboard published (~4-5 minutes after tests)
0:10 - Complete ecosystem ready! 🎉
```

**Total time: ~10 minutes from push to full ecosystem**

## 🔍 Monitoring Your Build

### View All Workflows

Navigate to: `https://github.com/{owner}/{repo}/actions`

Filter by:
- Branch: Select your target branch
- Workflow: Choose specific workflow
- Status: success, failure, in_progress

### Check Deployment Status

Each workflow provides a summary with:

1. **deploy.yml Summary:**
   - Docker image status
   - Container registry link
   - Test execution link
   - Dashboard URL
   - GitHub Pages link

2. **03-test-execution.yml Summary:**
   - Test results by suite
   - Coverage percentage
   - Failed tests (if any)
   - Artifact download links

3. **05-publish-reports-dashboard.yml Summary:**
   - Dashboard URL
   - Report collection status
   - GitHub Pages deployment link

4. **09-jekyll-gh-pages.yml Summary:**
   - Branch-specific deployment URL
   - Jekyll build status
   - All branch deployments list

### Quick Health Check

```bash
# Check Docker image exists
docker pull ghcr.io/{owner}/{repo}:{branch}

# Check GitHub Pages deployment
curl -I https://{owner}.github.io/{repo}/{branch}/

# Check dashboard
curl -I https://{owner}.github.io/{repo}/{branch}/library/reports/dashboard.html
```

## 🛠️ Troubleshooting

### "Tests didn't run after push"

**Check:**
1. Branch is in trigger list (main, dev, dev-staging, ring-*)
2. Workflow file exists and is valid YAML
3. Actions are enabled in repository settings

**Fix:**
- Manual trigger: Go to Actions → Test Execution → Run workflow

### "Dashboard not updated"

**Check:**
1. Test execution workflow completed
2. 05-publish workflow triggered after tests
3. GitHub Pages source is set correctly

**Fix:**
- Workflows tab → 05-publish-reports-dashboard → Check status
- Re-run workflow if failed

### "Jekyll site not deploying"

**Check:**
1. Push changed files in monitored paths
2. jekyll-gh-pages.yml workflow triggered
3. GitHub Pages is enabled

**Fix:**
- Settings → Pages → Source → gh-pages branch
- Re-run jekyll-gh-pages.yml workflow

### "Docker image not found"

**Check:**
1. deploy.yml workflow completed successfully
2. Build and push step succeeded
3. Registry authentication is correct

**Fix:**
- Check workflow logs for build errors
- Verify permissions in Settings → Actions → General

## 📚 Additional Documentation

- **PR Ecosystem:** [PR-ECOSYSTEM-GUIDE.md](PR-ECOSYSTEM-GUIDE.md)
- **Workflow Architecture:** [WORKFLOW-ARCHITECTURE.md](WORKFLOW-ARCHITECTURE.md)
- **CI/CD Overview:** [README.md](README.md)
- **Branch Deployments:** `/deployments.md`

## ✨ Summary

Every push to main, dev, dev-staging, or ring branches gets:

✅ **Docker container** - Built and pushed to GHCR  
✅ **Complete tests** - Unit, domain, and integration  
✅ **Interactive dashboard** - Metrics and visualizations  
✅ **GitHub Pages** - Branch-specific documentation

**All automatically, in ~10 minutes, with zero manual steps!**

---

*Last Updated: 2025-11-11*  
*Version: 2.0 - Complete Branch Build Ecosystem*  
*Platform: AitherZero Infrastructure Automation*
