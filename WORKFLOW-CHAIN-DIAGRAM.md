# Complete Workflow Chain - Visual Guide

## New Architecture: Linked Workflow Chain

```
┌──────────────────────────────────────────────────────────────────┐
│  TRIGGER: Push to dev-staging (or main, dev, ring-*)            │
└────────────────┬─────────────────────────────────────────────────┘
                 │
    ┌────────────┼─────────────┐
    │            │             │
    ▼            ▼             ▼
┌─────────┐  ┌─────────┐  ┌──────────┐
│ deploy  │  │ 03-test │  │ pr-check │ (on PR only)
│ .yml    │  │ -exec   │  │ .yml     │
└─────────┘  └────┬────┘  └──────────┘
                  │
                  │ workflow_run (on completion)
                  │
                  ▼
          ┌────────────────┐
          │ 05-publish-    │
          │ reports-       │
          │ dashboard.yml  │
          └───────┬────────┘
                  │
                  ├─► Save reports as artifact
                  │
                  │ workflow_dispatch (trigger)
                  │
                  ▼
          ┌────────────────┐
          │ 09-jekyll-     │
          │ gh-pages.yml   │
          └───────┬────────┘
                  │
                  ├─► Download reports artifact
                  ├─► Build complete Jekyll site
                  │
                  │ actions/deploy-pages@v4
                  │
                  ▼
          ┌────────────────┐
          │  GitHub Pages  │
          │   Deployed!    │
          └────────────────┘
```

## Workflow Responsibilities

### 1. deploy.yml
**Trigger:** Push to branch  
**Does:**
- Builds Docker image (multi-platform)
- Pushes to GitHub Container Registry
- Deploys to staging (if dev-staging branch)

**Output:** Docker image in ghcr.io

---

### 2. 03-test-execution.yml
**Trigger:** Push to branch  
**Does:**
- Runs unit tests
- Runs domain tests  
- Runs integration tests
- Generates coverage reports

**Output:** Test results as artifacts

---

### 3. 05-publish-reports-dashboard.yml
**Trigger:** workflow_run after tests complete  
**Does:**
- Collects test results
- Generates interactive dashboard
- Creates PR-specific reports
- Saves everything as "combined-reports" artifact
- **Triggers Jekyll workflow** via workflow_dispatch

**Output:** 
- combined-reports artifact
- PR comment (deployment in progress)

---

### 4. 09-jekyll-gh-pages.yml
**Trigger:** workflow_dispatch from dashboard workflow  
**Does:**
- Downloads combined-reports artifact
- Builds complete Jekyll site
- Includes reports, dashboard, documentation
- **Deploys to GitHub Pages** via actions/deploy-pages@v4

**Output:**
- Live GitHub Pages site
- PR comment (deployment complete with URLs)

---

## Key Integration Points

### 🔗 Link #1: Tests → Dashboard
```yaml
# In 03-test-execution.yml
# No explicit link needed - 05 uses workflow_run trigger

# In 05-publish-reports-dashboard.yml
on:
  workflow_run:
    workflows: ["🧪 Test Execution (Complete Suite)"]
    types: [completed]
```

### 🔗 Link #2: Dashboard → Jekyll
```yaml
# In 05-publish-reports-dashboard.yml
- name: Trigger Jekyll Deployment
  uses: actions/github-script@v7
  with:
    script: |
      await github.rest.actions.createWorkflowDispatch({
        workflow_id: '09-jekyll-gh-pages.yml',
        ref: branch,
        inputs: {
          reports_run_id: context.runId.toString()
        }
      });
```

### 🔗 Link #3: Jekyll Downloads Reports
```yaml
# In 09-jekyll-gh-pages.yml
- name: Download Reports
  uses: actions/download-artifact@v4
  with:
    name: combined-reports
    run-id: ${{ github.event.inputs.reports_run_id }}
```

## Data Flow

```
Test Results (XML/JSON)
    │
    ▼
[Test Execution Workflow]
    │
    │ uploads artifacts
    │
    ▼
Test Artifacts (GitHub)
    │
    │ workflow_run trigger
    │
    ▼
[Dashboard Workflow]
    │
    ├─► Collect test results
    ├─► Generate dashboard.html
    ├─► Create index.md
    │
    │ uploads artifact
    │
    ▼
combined-reports artifact
    │
    │ workflow_dispatch trigger
    │ (passes run_id)
    │
    ▼
[Jekyll Workflow]
    │
    ├─► Download combined-reports
    ├─► Build Jekyll site
    │   (includes reports)
    │
    │ actions/deploy-pages
    │
    ▼
GitHub Pages (Live Site)
```

## Timing Expectations

**Total Time: 8-12 minutes** (from push to live site)

| Workflow | Duration | Notes |
|----------|----------|-------|
| deploy.yml | 3-5 min | Docker build (parallel) |
| 03-test-execution.yml | 3-5 min | Tests (parallel) |
| 05-publish-reports-dashboard.yml | 1-2 min | Generate reports |
| 09-jekyll-gh-pages.yml | 2-3 min | Build + deploy |

**Sequential:** Tests → Dashboard → Jekyll = 6-10 minutes  
**Parallel:** Docker build runs alongside

## Failure Handling

### If Tests Fail
- ✅ Dashboard workflow still runs (workflow_run on completion, not success)
- ✅ Dashboard shows failed test results
- ✅ Jekyll deploys site with failure indicators

### If Dashboard Generation Fails
- ❌ Jekyll won't be triggered (workflow_dispatch not called)
- ℹ️  Check 05-publish-reports-dashboard.yml logs

### If Jekyll Deployment Fails
- ❌ Site not updated
- ℹ️  Previous version remains live
- ℹ️  Check GitHub Pages source setting (must be "GitHub Actions")

## Comparison: Before vs After

### Before (Broken)
```
Push → deploy.yml ✅
Push → 03-test-execution.yml ✅
Push → 09-jekyll-gh-pages.yml ❌ (paths filter)
      ├─► Only ran if library/** changed
      └─► Conflicted with 05-publish-reports

05-publish-reports ❌ Tried to deploy with actions/deploy-pages
09-jekyll-gh-pages ❌ Tried to deploy with peaceiris/actions-gh-pages
                   ❌ Only one can work!
```

### After (Fixed)
```
Push → deploy.yml ✅
Push → 03-test-execution.yml ✅
       └─► 05-publish-reports ✅ (generates reports)
           └─► 09-jekyll-gh-pages ✅ (deploys site)
               └─► Single deployment method ✅
                   Always runs ✅
                   Includes reports ✅
```

## Configuration Check

**Required GitHub Pages Settings:**
```
Settings → Pages → Build and deployment
├─ Source: GitHub Actions ✅
├─ Branch: Not applicable (Actions deploy from workflow)
└─ Custom domain: (optional)
```

**Workflow Permissions:**
```
Settings → Actions → General → Workflow permissions
└─ Read and write permissions ✅
```

## Testing Checklist

After implementing this fix:

- [ ] Push to dev-staging branch
- [ ] Check Actions tab - all 4 workflows should run
- [ ] Wait 8-12 minutes for complete chain
- [ ] Visit https://[owner].github.io/[repo]/library/reports/dashboard.html
- [ ] Verify dashboard shows latest test results
- [ ] Create a test PR
- [ ] Verify PR gets comment with dashboard URL
- [ ] Check PR dashboard is accessible

---

**Last Updated:** 2025-11-11  
**Architecture Version:** 2.0 (Linked Workflow Chain)
