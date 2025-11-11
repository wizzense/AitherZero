# GitHub Actions Workflow Architecture

## Overview

AitherZero uses a consolidated, event-driven workflow architecture designed to minimize conflicts and maximize efficiency.

## Workflow Organization

### PR Workflows (Pull Request Events)

#### `pr-check.yml` - PR Validation & Testing
- **Trigger:** `pull_request` (opened, synchronize, reopened, ready_for_review)
- **Concurrency Group:** `pr-check-${{ github.event.pull_request.number }}`
- **Purpose:** Comprehensive PR validation
- **Jobs:**
  - Validation (syntax, config, manifests, architecture)
  - Testing (delegates to `03-test-execution.yml`)
  - Build (packages, no deployment)
  - Build Docker (container images)
  - Documentation generation
  - Summary (comprehensive PR status)

#### `04-deploy-pr-environment.yml` - PR Environment Deployment
- **Trigger:** `pull_request` (opened, synchronize, reopened, ready_for_review)
- **Concurrency Group:** `pr-env-${{ github.event.pull_request.number || ... }}`
- **Purpose:** Deploy ephemeral test environments for PRs
- **Jobs:**
  - Check deployment conditions
  - Validate Docker configuration
  - Build and push PR-specific containers
  - Deploy PR environment
  - Post deployment status

**No Conflicts:** Different concurrency groups (`pr-check-XXX` vs `pr-env-XXX`) allow both to run in parallel.

### Push Workflows (Branch Push Events)

#### `deploy.yml` - Docker Build & Deployment
- **Trigger:** `push` to main, dev, develop, dev-staging, ring-*
- **Concurrency Group:** `deploy-${{ github.ref }}`
- **Purpose:** Build and push Docker images, deploy to staging
- **Jobs:**
  - Build and push Docker (multi-platform)
  - Deploy to staging (dev-staging branch only)
  - Summary

**Note:** Dashboard publishing removed to avoid conflicts with Jekyll workflow.

#### `09-jekyll-gh-pages.yml` - GitHub Pages Deployment
- **Trigger:** `push` to main, dev, develop, dev-staging, ring-* (paths: `library/**`, `index.md`, `_config.yml`)
- **Concurrency Group:** `pages-${{ github.ref }}`
- **Purpose:** Build and deploy Jekyll site to GitHub Pages
- **Jobs:**
  - Setup (determine branch-specific deployment config)
  - Generate Dashboard (runs dashboard-generation-complete playbook)
  - Build (Jekyll site build)
  - Deploy (branch-specific GitHub Pages deployment)

**Path Filters:** Only runs when `library/**` or documentation files change.

**No Conflicts:** Different concurrency groups (`deploy-XXX` vs `pages-XXX`) and path filters ensure proper separation.

### Test & Dashboard Workflows

#### `03-test-execution.yml` - Test Execution
- **Trigger:** `workflow_call`, `workflow_dispatch`
- **Concurrency Group:** `tests-${{ github.event.pull_request.number || github.ref }}`
- **Purpose:** Comprehensive test suite execution
- **Jobs:**
  - Prepare (test matrix generation)
  - Unit tests (parallel by range: 0000-0099, 0100-0199, etc.)
  - Domain tests (parallel by domain: configuration, infrastructure, etc.)
  - Integration tests
  - Coverage and performance metrics
  - Summary

**Called By:** `pr-check.yml` for PR validation

#### `05-publish-reports-dashboard.yml` - Dashboard Publishing
- **Trigger:** 
  - `pull_request` (opened, synchronize, reopened, ready_for_review) - **NEW for complete PR ecosystem**
  - `workflow_run` (after `03-test-execution.yml` completes)
  - `workflow_dispatch` (manual)
- **Concurrency Group:** `pages-publish-${{ github.ref }}`
- **Purpose:** Collect test results and publish dashboard to GitHub Pages
- **Jobs:**
  - Collect reports (download artifacts, organize results, generate dashboard)
  - Publish to Pages (Jekyll build and deployment)

**Automatic Triggers:** 
- Runs on PR events for complete PR ecosystem deployment
- Runs after `03-test-execution.yml` completes to publish test results

### Release Workflows

#### `release.yml` - Release Creation
- **Trigger:** 
  - `push` to tags matching `v*`
  - `workflow_dispatch` (manual)
- **Concurrency Group:** `release-${{ github.event.inputs.version || github.ref_name }}`
- **Purpose:** Create releases, build packages, publish artifacts
- **Jobs:**
  - Pre-release validation
  - Create release
  - Build MCP server
  - Publish Docker image
  - Post-release tasks

#### `04-deploy-pr-environment.yml` - Release Deployment
- **Additional Triggers:** 
  - `push` to tags matching `v*`
  - `release` (published)
- **Purpose:** Also handles release deployments (dual-purpose workflow)

### Manual/Testing Workflows

#### `test-dashboard-generation.yml` - Dashboard Testing
- **Trigger:** `workflow_dispatch` (manual only)
- **Concurrency Group:** `test-dashboard-${{ github.ref }}`
- **Purpose:** Test dashboard generation and coverage before merging

## Concurrency Strategy

### Concurrency Groups (No Overlaps)

| Workflow | Group Pattern | Cancel-in-Progress |
|----------|---------------|-------------------|
| `pr-check.yml` | `pr-check-{PR#}` | Yes |
| `04-deploy-pr-environment.yml` | `pr-env-{PR#\|tag\|ref}` | No |
| `deploy.yml` | `deploy-{ref}` | Yes |
| `09-jekyll-gh-pages.yml` | `pages-{ref}` | Yes |
| `05-publish-reports-dashboard.yml` | `pages-publish-{ref}` | Yes |
| `03-test-execution.yml` | `tests-{PR#\|ref}` | Yes |
| `release.yml` | `release-{version\|ref}` | No |
| `test-dashboard-generation.yml` | `test-dashboard-{ref}` | Yes |

**Key Points:**
- Different prefixes prevent conflicts between workflow types
- PR workflows use PR number for isolation
- Push workflows use branch reference for isolation
- Release workflows preserve in-progress deployments (`cancel-in-progress: false`)

## Complete PR Ecosystem

**Every PR gets a self-contained deployment ecosystem** with all components deployed based on the target branch (main, dev, dev-staging, or ring branches).

### PR Ecosystem Components

When a PR is opened against **main**, **dev**, **dev-staging**, or any **ring-** branch, the following workflows collaborate to create a complete ecosystem:

#### 1. 🐳 Docker Container (via `04-deploy-pr-environment.yml`)
- **Published to**: GitHub Container Registry (GHCR)
- **Image Tags**:
  - `ghcr.io/{owner}/{repo}:pr-{number}-{branch}-latest` (primary tag)
  - `ghcr.io/{owner}/{repo}:pr-{number}-latest` (quick reference)
  - `ghcr.io/{owner}/{repo}:pr-{number}-{commit}` (commit-specific)
  - `ghcr.io/{owner}/{repo}:{ring}-pr-{number}-latest` (ring-specific)
- **Multi-platform**: Linux amd64 (arm64 optional)
- **Build Args**: PR number, branch, commit SHA, deployment ring
- **Labels**: Full OCI labels with PR metadata

**Example for PR #123 targeting dev:**
```bash
docker pull ghcr.io/wizzense/aitherzero:pr-123-dev-latest
docker run -it --rm ghcr.io/wizzense/aitherzero:pr-123-dev-latest
```

#### 2. 📊 GitHub Pages Dashboard (via `05-publish-reports-dashboard.yml`)
- **URL Pattern**: `https://{owner}.github.io/{repo}/{branch-path}library/reports/pr-{number}/`
- **Branch-Specific Paths**:
  - **main** → `/{repo}/library/reports/pr-{number}/`
  - **dev** → `/{repo}/dev/library/reports/pr-{number}/`
  - **dev-staging** → `/{repo}/dev-staging/library/reports/pr-{number}/`
  - **ring-0/1/2** → `/{repo}/ring-{0|1|2}/library/reports/pr-{number}/`
- **Contents**:
  - Full dashboard HTML with metrics visualization
  - Test results and coverage reports
  - Code quality metrics
  - Workflow health metrics
  - Ring deployment metrics
  - Container deployment information

**Example for PR #123 targeting dev:**
```
https://wizzense.github.io/AitherZero/dev/library/reports/pr-123/
```

#### 3. 📦 Release Packages (via `pr-check.yml`)
- **Formats**: Both ZIP and TAR.GZ
- **Naming**: `AitherZero-v{version}-pr{number}.{zip|tar.gz}`
- **Contents**: Complete runtime package with all modules
- **Availability**: GitHub Actions artifacts (30-day retention)
- **Metadata**: Full build metadata with PR info (branch, commit, timestamp)

**Artifact Name**: `build-artifacts-pr-{number}`

#### 4. 📋 Test Results (via `pr-check.yml` → `03-test-execution.yml`)
- **Unit Tests**: By script range (0000-0099, 0100-0199, etc.)
- **Domain Tests**: By module (configuration, infrastructure, security, etc.)
- **Integration Tests**: Full system integration
- **Coverage**: Code coverage metrics
- **Performance**: Performance metrics and timing

### PR Ecosystem Flow

```
PR #123 opened against 'dev' branch
│
├── pr-check.yml (concurrency: pr-check-123)
│   ├── ✅ Validation (syntax, config, manifests)
│   ├── ✅ Tests (calls 03-test-execution.yml)
│   ├── ✅ Build Packages → 📦 Artifacts available
│   ├── ✅ Build Docker (test only, no push)
│   ├── ✅ Docs generation
│   └── ✅ Summary with ecosystem links
│
├── 04-deploy-pr-environment.yml (concurrency: pr-env-123)
│   ├── ✅ Check deployment trigger
│   ├── ✅ Validate Docker config
│   ├── ✅ Build and PUSH container → 🐳 ghcr.io/.../pr-123-dev-latest
│   ├── ✅ Deploy environment
│   └── ✅ Security scan & status comment
│
└── 05-publish-reports-dashboard.yml (concurrency: pages-publish-123)
    ├── ✅ Collect test results
    ├── ✅ Generate dashboard (playbook: dashboard-generation-complete)
    ├── ✅ Create PR-specific dashboard
    ├── ✅ Build Jekyll site
    └── ✅ Deploy to Pages → 📊 .../dev/library/reports/pr-123/

Result: Complete self-contained ecosystem for PR #123 on 'dev' branch! 🎉
```

### Branch-Aware Deployment

Each target branch has its own deployment path on GitHub Pages:

| Target Branch | Docker Tag Prefix | Pages Path | Deployment Ring |
|---------------|-------------------|------------|-----------------|
| `main` | `pr-{N}-main-` | `/library/reports/pr-{N}/` | production |
| `dev` | `pr-{N}-dev-` | `/dev/library/reports/pr-{N}/` | dev |
| `dev-staging` | `pr-{N}-dev-staging-` | `/dev-staging/library/reports/pr-{N}/` | staging |
| `ring-0` | `pr-{N}-ring-0-` | `/ring-0/library/reports/pr-{N}/` | ring-0 |
| `ring-1` | `pr-{N}-ring-1-` | `/ring-1/library/reports/pr-{N}/` | ring-1 |
| `ring-2` | `pr-{N}-ring-2-` | `/ring-2/library/reports/pr-{N}/` | ring-2 |

### Accessing PR Ecosystem

After workflows complete, the PR comment will include:

- 🐳 **Docker**: Pull command with exact image tag
- 📊 **Dashboard**: Direct URL to PR-specific GitHub Pages deployment
- 📦 **Packages**: Link to workflow artifacts
- 🧪 **Tests**: Summary with links to detailed results

**Everything is isolated by PR number and target branch!**

## Event Flow Examples

### Example 1: PR Opened (Complete Ecosystem)
```
Event: pull_request (opened) on PR #123 targeting 'dev'
├── pr-check.yml (concurrency: pr-check-123)
│   ├── Validate (syntax, config, manifests)
│   ├── Test (calls 03-test-execution.yml)
│   ├── Build Packages → 📦 build-artifacts-pr-123
│   ├── Build Docker (test build only)
│   ├── Docs generation
│   └── Summary with full ecosystem info
│
├── 04-deploy-pr-environment.yml (concurrency: pr-env-123)
│   ├── Check deployment conditions
│   ├── Validate Docker config
│   ├── Build and PUSH PR container → 🐳 ghcr.io/.../pr-123-dev-latest
│   ├── Deploy PR environment
│   └── Post status comment with container info
│
└── 05-publish-reports-dashboard.yml (concurrency: pages-publish-123)
    ├── Download test artifacts
    ├── Generate dashboard (playbook)
    ├── Create PR-specific dashboard
    ├── Build Jekyll site
    └── Deploy to Pages → 📊 .../dev/library/reports/pr-123/

All run in parallel (different concurrency groups)
Result: Complete self-contained ecosystem for PR #123! 🎉
```

### Example 2: Push to Main (Code Change)
```
Event: push to main (non-library files)
├── deploy.yml (concurrency: deploy-main)
│   ├── Build Docker image
│   ├── Push to GHCR
│   └── Summary
│
└── release.yml (concurrency: release-main)
    └── (only if tag push, skips)

09-jekyll-gh-pages.yml does NOT run (path filter not matched)
```

### Example 3: Push to Main (Library Change)
```
Event: push to main (library/** files)
├── deploy.yml (concurrency: deploy-main)
│   └── Build Docker image
│
├── 09-jekyll-gh-pages.yml (concurrency: pages-main)
│   ├── Setup (branch config)
│   ├── Generate Dashboard (playbook)
│   ├── Build Jekyll site
│   └── Deploy to GitHub Pages
│
└── release.yml (concurrency: release-main)
    └── (only if tag push, skips)

Both deploy.yml and jekyll run (different purposes, no conflict)
```

### Example 4: Test Execution Completes
```
Event: workflow_run (03-test-execution.yml completes)
└── 05-publish-reports-dashboard.yml (concurrency: pages-publish-main)
    ├── Download test artifacts
    ├── Organize test results
    ├── Generate dashboard (playbook)
    ├── Build Jekyll site
    └── Deploy to GitHub Pages

Automatically publishes test results and dashboard after tests complete
```

## Dashboard Generation

### Dashboard Playbook
- **Name:** `dashboard-generation-complete`
- **Location:** `library/playbooks/dashboard-generation-complete.psd1`
- **Scripts:**
  - `0520_Collect-RingMetrics.ps1` - Ring deployment metrics
  - `0521_Collect-WorkflowHealth.ps1` - Workflow health metrics
  - `0522_Collect-CodeMetrics.ps1` - Code quality metrics
  - `0523_Collect-TestMetrics.ps1` - Test result metrics
  - `0524_Collect-QualityMetrics.ps1` - Quality analysis metrics
  - `0525_Generate-DashboardHTML.ps1` - HTML dashboard generation

### Dashboard Publishing Workflows
1. **`09-jekyll-gh-pages.yml`** - Primary dashboard generation on push
2. **`05-publish-reports-dashboard.yml`** - Test results dashboard after test execution

## Troubleshooting

### Workflow Not Triggering
1. **Check trigger configuration** - Verify `'on':` section has correct events
2. **Check branch filters** - Ensure branch is in allowed list
3. **Check path filters** - Verify changed files match path patterns
4. **Check concurrency** - Another run might be in progress (if `cancel-in-progress: true`)

### Workflow Conflicts
1. **Different concurrency groups** - Workflows can run in parallel
2. **Same concurrency group** - Only one runs (newer cancels older if `cancel-in-progress: true`)
3. **GitHub Pages conflicts** - Only one workflow should deploy to Pages at a time

### Common Issues
- **Missing `workflow_run` trigger** - Workflow expects to be called but has no trigger
- **Duplicate GitHub Pages deployment** - Multiple workflows trying to deploy simultaneously
- **Incorrect concurrency group** - Workflows accidentally sharing groups

## Best Practices

1. **Use specific concurrency groups** - Include workflow purpose in prefix (e.g., `pr-check-`, `pr-env-`)
2. **Path filters for efficiency** - Only run workflows when relevant files change
3. **Workflow dependencies** - Use `workflow_call` and `workflow_run` for coordination
4. **Error handling** - Use `continue-on-error` and `if: always()` for resilience
5. **Documentation** - Keep this file updated when adding/modifying workflows

## Recent Changes

### 2025-11-11: Workflow Conflict Resolution
- **Fixed:** Added `workflow_run` trigger to `05-publish-reports-dashboard.yml`
- **Fixed:** Removed duplicate GitHub Pages deployment from `deploy.yml`
- **Fixed:** Enabled `04-deploy-pr-environment.yml` with PR triggers
- **Fixed:** Updated concurrency groups to prevent conflicts

## Related Documentation
- `.github/workflows/README.md` - Workflow overview
- `.github/workflows/TROUBLESHOOTING-PLAYBOOK.md` - Troubleshooting guide
- `library/playbooks/dashboard-generation-complete.psd1` - Dashboard generation playbook
