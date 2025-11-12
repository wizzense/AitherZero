# Workflow Consolidation - Implementation Guide

**Purpose:** This document provides a complete, actionable plan to fix the AitherZero CI/CD workflow system. Use this as the foundation for a new PR that implements the solution.

**Status:** Analysis complete, ready for implementation  
**Estimated Effort:** 10-12 hours core work  
**Priority:** High - Current workflows are broken/incomplete

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Critical Issues](#critical-issues)
4. [The Solution](#the-solution)
5. [Implementation Tasks](#implementation-tasks)
6. [Testing Plan](#testing-plan)
7. [Rollback Plan](#rollback-plan)
8. [Success Criteria](#success-criteria)

---

## Executive Summary

### What's Wrong

The current workflow system has **5 critical issues**:

1. **❌ Playbooks don't handle parallel execution** - Flags are ignored, workflows must coordinate parallelism
2. **❌ Confusing "complete" naming** - Makes it unclear what each playbook does
3. **❌ Variable typos in playbooks** - `PR_Script` should be `PR_NUMBER`, breaking PR context
4. **❌ Workflows not using playbooks** - pr-check.yml doesn't call pr-ecosystem-complete
5. **❌ Dashboard scripts mismatch** - Scripts 0521, 0523 don't do what playbooks expect

### What Works (Keep These!)

✅ **03-test-execution.yml** (774 lines) - Perfect parallel test execution at workflow job level  
✅ **04-deploy-pr-environment.yml** (755 lines) - User-confirmed working PR deployment  
✅ **09-jekyll-gh-pages.yml** (433 lines) - GitHub Pages deployment  
✅ **release.yml** (805 lines) - Complete release process  

### The Core Principle

> **Workflows call playbooks directly - no complex orchestrator playbooks needed!**

```yaml
# Simple, clear pattern:
steps:
  - run: Invoke-AitherPlaybook pr-build
  - run: Invoke-AitherPlaybook pr-test
  - run: Invoke-AitherPlaybook pr-report
  - run: Invoke-AitherPlaybook dashboard
```

**Everything must be runnable locally:**
```powershell
# Developer runs:
./bootstrap.ps1 -Mode New -InstallProfile Minimal
Import-Module ./AitherZero.psd1 -Force
Invoke-AitherPlaybook -Name pr-build
```

---

## Current State Analysis

### Workflows Inventory (8 Total)

| Workflow | Lines | Status | Action |
|----------|-------|--------|--------|
| pr-check.yml | 434 | ⚠️ Broken | Replace |
| deploy.yml | 223 | ⚠️ Incomplete | Replace |
| 03-test-execution.yml | 774 | ✅ Working | **Keep** |
| 04-deploy-pr-environment.yml | 755 | ✅ Working | **Keep** |
| 05-publish-reports-dashboard.yml | 708 | ⚠️ Fragile | Delete |
| 09-jekyll-gh-pages.yml | 433 | ✅ Working | **Keep** |
| release.yml | 805 | ✅ Working | **Keep** |
| test-dashboard-generation.yml | 358 | ✅ Working | **Keep** |
| **Total** | **4,490** | 3 broken | 8→6 workflows |

### Playbooks Inventory (27 Total)

| Playbook | Lines | Issues | Action |
|----------|-------|--------|--------|
| pr-ecosystem-complete.psd1 | 147 | Orchestrator (unnecessary) | Delete |
| pr-ecosystem-build.psd1 | 95 | None | Rename to `pr-build.psd1` |
| pr-ecosystem-analyze.psd1 | 114 | Variable typos | Rename to `pr-test.psd1` + fix |
| pr-ecosystem-report.psd1 | 102 | Variable typos | Rename to `pr-report.psd1` + fix |
| dashboard-generation-complete.psd1 | 90 | Confusing name | Rename to `dashboard.psd1` |
| test-execution-unit.psd1 | 85 | None | Keep |
| test-execution-domain.psd1 | 88 | None | Keep |
| test-execution-integration.psd1 | 92 | None | Keep |
| build-artifacts.psd1 | 78 | None | Keep |
| **+ 18 more playbooks** | Various | - | Keep |

### Automation Scripts Inventory (175 Total)

All scripts exist and are organized by range:

| Range | Purpose | Count | Status |
|-------|---------|-------|--------|
| 0000-0099 | Environment setup | 12 | ✅ Complete |
| 0100-0199 | Infrastructure | 18 | ✅ Complete |
| 0200-0299 | Dev tools | 24 | ✅ Complete |
| 0400-0499 | Testing & validation | 32 | ✅ Complete |
| 0500-0599 | Reporting & metrics | 28 | ⚠️ Some mismatch |
| 0700-0799 | Git automation | 22 | ✅ Complete |
| 0800-0899 | Issue management | 14 | ✅ Complete |
| 0900-0999 | Validation | 15 | ✅ Complete |
| 9000-9999 | Maintenance | 10 | ✅ Complete |

**Note:** Scripts 0521 (doc coverage) and 0523 (security scan) are being called by dashboard playbook but don't match expectations.

---

## Critical Issues

### Issue 1: Playbooks Don't Handle Parallel Execution

**Problem:**  
Playbooks define `Parallel = $true` and `Group` numbers, but `Invoke-AitherPlaybook` doesn't implement parallel execution. Scripts run sequentially.

**Example from pr-ecosystem-analyze.psd1:**
```powershell
Scripts = @(
    @{ Path = '0402'; Parallel = $true; Group = 1 }  # Unit tests
    @{ Path = '0403'; Parallel = $true; Group = 1 }  # Integration tests
)
```

**Reality:** Both scripts run sequentially, one after another. The `Parallel` flag is ignored.

**What Actually Works:**  
03-test-execution.yml coordinates parallel execution at the GitHub Actions job level:
```yaml
jobs:
  unit-tests:
    runs-on: ubuntu-latest
  domain-tests:
    runs-on: ubuntu-latest  # Runs in parallel with unit-tests
  integration-tests:
    runs-on: ubuntu-latest  # Runs in parallel with others
```

**Solution:** Keep parallel execution in workflows, not playbooks. Let workflows coordinate parallel jobs.

---

### Issue 2: Confusing "Complete" Naming

**Problem:**  
Names like "pr-ecosystem-complete" and "dashboard-generation-complete" imply there are incomplete versions.

**Current Confusing Names:**
- pr-ecosystem-complete.psd1 → What's incomplete?
- pr-ecosystem-build.psd1 → Why "ecosystem"?
- pr-ecosystem-analyze.psd1 → What ecosystem?
- pr-ecosystem-report.psd1 → Why separate from ecosystem?
- dashboard-generation-complete.psd1 → Is there an incomplete dashboard?

**Proposed Clear Names:**
- ~~pr-ecosystem-complete~~ → DELETE (workflows call others directly)
- pr-build.psd1 → Builds artifacts
- pr-test.psd1 → Runs tests
- pr-report.psd1 → Generates reports
- dashboard.psd1 → Creates dashboard

**Benefit:** Clear, concise names that describe exactly what each playbook does.

---

### Issue 3: Variable Typos in Playbooks

**Problem:**  
Multiple playbooks have typos that break PR context variables.

**Typos Found:**

**pr-ecosystem-analyze.psd1 (line 152):**
```powershell
Variables = @{
    PR_Script = $env:PR_NUMBER  # ❌ Should be PR_NUMBER
}
```

**pr-ecosystem-report.psd1 (line 128):**
```powershell
Variables = @{
    PR_Script = $env:PR_NUMBER  # ❌ Should be PR_NUMBER
}
```

**pr-ecosystem-report.psd1 (line 133):**
```powershell
Variables = @{
    GITHUB_RUN_Script = $env:GITHUB_RUN_NUMBER  # ❌ Should be GITHUB_RUN_NUMBER
}
```

**Impact:** Scripts receive wrong variable names, can't access PR context properly.

**Fix:** Global find/replace `PR_Script` → `PR_NUMBER` and `GITHUB_RUN_Script` → `GITHUB_RUN_NUMBER`

---

### Issue 4: Workflows Not Using Playbooks

**Problem:**  
pr-check.yml doesn't call the pr-ecosystem-complete playbook that was designed for it.

**Current pr-check.yml (BROKEN):**
```yaml
steps:
  - name: Run individual scripts
    run: |
      ./automation-scripts/0524_Generate-ChangelogReport.ps1
      ./automation-scripts/0526_Generate-ProjectReport.ps1
      # Multiple individual script calls, no playbook usage
```

**What it SHOULD do:**
```yaml
steps:
  - name: Build
    run: Invoke-AitherPlaybook pr-build
  
  - name: Test
    run: Invoke-AitherPlaybook pr-test
  
  - name: Report
    run: Invoke-AitherPlaybook pr-report
```

**Why this matters:** Playbooks ensure consistent execution across local dev and CI.

---

### Issue 5: Dashboard Scripts Mismatch

**Problem:**  
dashboard-generation-complete.psd1 calls scripts that don't do what it expects.

**Playbook expects (lines 45-68):**
```powershell
Scripts = @(
    @{ Path = '0520' }  # Test metrics summary
    @{ Path = '0521' }  # Workflow health metrics
    @{ Path = '0523' }  # Test trend analysis
    @{ Path = '0524' }  # Changelog report
    @{ Path = '0525' }  # Coverage summary
)
```

**Reality check:**
- ✅ 0520 - Generate-TestMetricsReport.ps1 - Correct
- ❌ 0521 - Generate-DocumentationCoverageReport.ps1 - NOT workflow health!
- ❌ 0523 - Run-SecurityScan.ps1 - NOT test trend analysis!
- ✅ 0524 - Generate-ChangelogReport.ps1 - Correct
- ✅ 0525 - Generate-CoverageSummary.ps1 - Correct

**Solution:** Either rewrite scripts 0521/0523 OR update playbook to call correct scripts.

---

## The Solution

### Proposed Architecture

**6 Workflows** (down from 8, 30% reduction):

1. **pr-validation.yml** (NEW) - Replaces pr-check.yml
2. **branch-deployment.yml** (NEW) - Replaces deploy.yml + 05-publish
3. **03-test-execution.yml** (KEEP) - Reusable test workflow
4. **04-deploy-pr-environment.yml** (KEEP) - Working PR deployment
5. **09-jekyll-gh-pages.yml** (KEEP) - Pages deployment
6. **release.yml** (KEEP) - Release process

### Workflow Design Pattern

**All workflows follow this simple pattern:**

```yaml
name: 🎯 Workflow Name

on:
  pull_request:  # or push, workflow_dispatch, etc.

permissions:
  contents: read
  # Minimal permissions only

env:
  AITHERZERO_CI: true
  AITHERZERO_NONINTERACTIVE: true

jobs:
  job-name:
    runs-on: ubuntu-latest
    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4
      
      - name: 🔧 Bootstrap
        run: ./bootstrap.ps1 -Mode New -InstallProfile Minimal
      
      - name: 📦 Load Module
        run: Import-Module ./AitherZero.psd1 -Force
      
      - name: 🚀 Run Playbook
        run: Invoke-AitherPlaybook -Name playbook-name
      
      - name: 📤 Upload Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: artifacts
          path: library/reports/
```

**That's it!** No complex logic in workflows - just bootstrap, call playbook, upload artifacts.

### Playbook Design Pattern

**Each playbook does ONE thing:**

```powershell
# pr-build.psd1
@{
    Name = 'pr-build'
    Description = 'Build PR artifacts'
    Scripts = @(
        @{ Path = '0510' }  # Generate build metadata
        @{ Path = '0512' }  # Build packages
        @{ Path = '0513' }  # Build containers
        @{ Path = '0514' }  # Validate artifacts
    )
}
```

**No orchestrator playbooks!** Workflows call multiple playbooks directly:
```yaml
- run: Invoke-AitherPlaybook pr-build
- run: Invoke-AitherPlaybook pr-test
- run: Invoke-AitherPlaybook pr-report
```

---

## Implementation Tasks

### Phase 1: Quick Fixes (30 minutes)

**Task 1.1: Fix Variable Typos** (10 min)

Files to edit:
- `library/playbooks/pr-ecosystem-analyze.psd1`
- `library/playbooks/pr-ecosystem-report.psd1`

Find and replace:
- `PR_Script` → `PR_NUMBER`
- `GITHUB_RUN_Script` → `GITHUB_RUN_NUMBER`

**Task 1.2: Test Locally** (20 min)

```powershell
# Test playbook loading
./bootstrap.ps1 -Mode New -InstallProfile Minimal
Import-Module ./AitherZero.psd1 -Force

# Test playbook execution with fixed variables
$env:PR_NUMBER = "9999"
$env:GITHUB_RUN_NUMBER = "123"
Invoke-AitherPlaybook -Name pr-ecosystem-analyze -DryRun
Invoke-AitherPlaybook -Name pr-ecosystem-report -DryRun

# Verify variables are passed correctly
# Check output for "PR_NUMBER: 9999" not "PR_Script: 9999"
```

**Commit:** "Fix variable typos in playbooks (PR_Script → PR_NUMBER)"

---

### Phase 2: Rename Playbooks (2 hours)

**Task 2.1: Rename Playbook Files** (30 min)

```bash
cd library/playbooks/

# Rename files
mv pr-ecosystem-build.psd1 pr-build.psd1
mv pr-ecosystem-analyze.psd1 pr-test.psd1
mv pr-ecosystem-report.psd1 pr-report.psd1
mv dashboard-generation-complete.psd1 dashboard.psd1

# Update Name field inside each file
# pr-build.psd1: Name = 'pr-build'
# pr-test.psd1: Name = 'pr-test'
# pr-report.psd1: Name = 'pr-report'
# dashboard.psd1: Name = 'dashboard'
```

**Task 2.2: Update References** (1 hour)

Search for references to old names:
```bash
grep -r "pr-ecosystem-build" .
grep -r "pr-ecosystem-analyze" .
grep -r "pr-ecosystem-report" .
grep -r "dashboard-generation-complete" .
```

Update all references in:
- Workflow files
- Documentation
- Comments
- Test files

**Task 2.3: Delete pr-ecosystem-complete.psd1** (10 min)

```bash
# This orchestrator playbook is no longer needed
rm library/playbooks/pr-ecosystem-complete.psd1
```

Workflows will call playbooks directly instead.

**Task 2.4: Test Renamed Playbooks** (20 min)

```powershell
# Test each renamed playbook
Invoke-AitherPlaybook -Name pr-build -DryRun
Invoke-AitherPlaybook -Name pr-test -DryRun
Invoke-AitherPlaybook -Name pr-report -DryRun
Invoke-AitherPlaybook -Name dashboard -DryRun
```

**Commit:** "Rename playbooks to remove 'complete' and 'ecosystem' naming"

---

### Phase 3: Create New Workflows (4 hours)

**Task 3.1: Backup Current Workflows** (10 min)

```bash
mkdir -p .github/workflows-archive
cp .github/workflows/pr-check.yml .github/workflows-archive/
cp .github/workflows/deploy.yml .github/workflows-archive/
cp .github/workflows/05-publish-reports-dashboard.yml .github/workflows-archive/
```

**Task 3.2: Create pr-validation.yml** (1 hour)

```yaml
---
name: 🎯 PR Validation

on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches: [main, dev, develop]

permissions:
  contents: read
  pull-requests: write
  checks: write

concurrency:
  group: pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true

env:
  AITHERZERO_CI: true
  AITHERZERO_NONINTERACTIVE: true
  AITHERZERO_SUPPRESS_BANNER: true

jobs:
  validate:
    name: 🚀 PR Validation Pipeline
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: 🔧 Bootstrap Environment
        shell: pwsh
        run: ./bootstrap.ps1 -Mode New -InstallProfile Minimal

      - name: 📦 Load Module
        shell: pwsh
        run: Import-Module ./AitherZero.psd1 -Force

      - name: 🏗️ Build
        shell: pwsh
        run: |
          $env:PR_NUMBER = "${{ github.event.pull_request.number }}"
          $env:GITHUB_BASE_REF = "${{ github.base_ref }}"
          $env:GITHUB_HEAD_REF = "${{ github.head_ref }}"
          Invoke-AitherPlaybook -Name pr-build

      - name: 🧪 Test
        shell: pwsh
        run: |
          $env:PR_NUMBER = "${{ github.event.pull_request.number }}"
          Invoke-AitherPlaybook -Name pr-test

      - name: 📊 Report
        shell: pwsh
        run: |
          $env:PR_NUMBER = "${{ github.event.pull_request.number }}"
          $env:GITHUB_RUN_NUMBER = "${{ github.run_number }}"
          Invoke-AitherPlaybook -Name pr-report

      - name: 📤 Upload Reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: pr-reports-${{ github.event.pull_request.number }}
          path: library/reports/

      - name: 💬 Post PR Comment
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const commentPath = './library/reports/pr-comment.md';
            
            if (!fs.existsSync(commentPath)) {
              console.log('No comment file found, skipping');
              return;
            }
            
            const commentBody = fs.readFileSync(commentPath, 'utf8');
            const prNumber = ${{ github.event.pull_request.number }};
            
            const { data: comments } = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: prNumber
            });
            
            const marker = '<!-- PR_VALIDATION -->';
            const fullComment = commentBody + '\n' + marker;
            
            const botComment = comments.find(c => 
              c.user.login === 'github-actions[bot]' && 
              c.body.includes(marker)
            );
            
            if (botComment) {
              await github.rest.issues.updateComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                comment_id: botComment.id,
                body: fullComment
              });
            } else {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: prNumber,
                body: fullComment
              });
            }
```

**Task 3.3: Create branch-deployment.yml** (1.5 hours)

```yaml
---
name: 🚀 Branch Deployment

on:
  push:
    branches: [main, dev, develop, dev-staging]

permissions:
  contents: write
  packages: write
  pages: write
  id-token: write

concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: true

env:
  AITHERZERO_CI: true
  AITHERZERO_NONINTERACTIVE: true

jobs:
  # Use existing 03-test-execution.yml for parallel tests
  test:
    uses: ./.github/workflows/03-test-execution.yml
    with:
      test_suite: 'all'
      coverage: true
    secrets: inherit

  build:
    name: 🐳 Build & Push
    needs: test
    runs-on: ubuntu-latest
    timeout-minutes: 30
    
    steps:
      - uses: actions/checkout@v4
      
      - name: 🔐 Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: 🔧 Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: 🐳 Build and Push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  dashboard:
    name: 📊 Generate Dashboard
    needs: test
    runs-on: ubuntu-latest
    timeout-minutes: 20
    
    steps:
      - uses: actions/checkout@v4
      
      - name: 🔧 Bootstrap
        shell: pwsh
        run: ./bootstrap.ps1 -Mode New -InstallProfile Minimal
      
      - name: 📥 Download Test Artifacts
        uses: actions/download-artifact@v4
        with:
          pattern: '*-tests-*'
          path: ./artifacts/
          merge-multiple: true
      
      - name: 📦 Organize Artifacts
        shell: pwsh
        run: |
          New-Item -ItemType Directory -Path "library/tests/results" -Force
          Get-ChildItem "./artifacts" -Recurse -Filter "*.xml" | 
            Copy-Item -Destination "library/tests/results/" -Force
      
      - name: 📊 Generate Dashboard
        shell: pwsh
        run: |
          Import-Module ./AitherZero.psd1 -Force
          Invoke-AitherPlaybook -Name dashboard
      
      - name: 📤 Upload Dashboard
        uses: actions/upload-artifact@v4
        with:
          name: dashboard-${{ github.ref_name }}
          path: library/reports/
      
      - name: 🚀 Trigger Pages Deployment
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.actions.createWorkflowDispatch({
              owner: context.repo.owner,
              repo: context.repo.repo,
              workflow_id: '09-jekyll-gh-pages.yml',
              ref: '${{ github.ref_name }}'
            });

  summary:
    name: 📋 Summary
    needs: [test, build, dashboard]
    if: always()
    runs-on: ubuntu-latest
    
    steps:
      - name: 📊 Generate Summary
        run: |
          echo "## 🚀 Deployment Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Branch:** \`${{ github.ref_name }}\`" >> $GITHUB_STEP_SUMMARY
          echo "**Commit:** \`${{ github.sha }}\`" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Job | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|-----|--------|" >> $GITHUB_STEP_SUMMARY
          echo "| Test | ${{ needs.test.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Build | ${{ needs.build.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Dashboard | ${{ needs.dashboard.result }} |" >> $GITHUB_STEP_SUMMARY
```

**Task 3.4: Delete Old Workflows** (10 min)

```bash
# Remove broken/replaced workflows
rm .github/workflows/pr-check.yml
rm .github/workflows/deploy.yml
rm .github/workflows/05-publish-reports-dashboard.yml
```

**Task 3.5: Test Workflows** (1 hour)

Test locally first:
```powershell
# Simulate PR workflow
$env:PR_NUMBER = "9999"
$env:GITHUB_BASE_REF = "main"
$env:GITHUB_HEAD_REF = "test-branch"

./bootstrap.ps1 -Mode New -InstallProfile Minimal
Import-Module ./AitherZero.psd1 -Force

Invoke-AitherPlaybook -Name pr-build
Invoke-AitherPlaybook -Name pr-test
Invoke-AitherPlaybook -Name pr-report

# Check artifacts created
Get-ChildItem library/reports/
```

**Commit:** "Add new pr-validation and branch-deployment workflows"

---

### Phase 4: Verification & Testing (4 hours)

**Task 4.1: Local End-to-End Test** (1 hour)

```powershell
# Full PR workflow locally
./bootstrap.ps1 -Mode New -InstallProfile Minimal
Import-Module ./AitherZero.psd1 -Force

# Set PR context
$env:PR_NUMBER = "test"
$env:GITHUB_BASE_REF = "main"
$env:GITHUB_HEAD_REF = "feature-test"
$env:GITHUB_RUN_NUMBER = "1"

# Run all playbooks
Write-Host "Running pr-build..."
Invoke-AitherPlaybook -Name pr-build

Write-Host "Running pr-test..."
Invoke-AitherPlaybook -Name pr-test

Write-Host "Running pr-report..."
Invoke-AitherPlaybook -Name pr-report

Write-Host "Running dashboard..."
Invoke-AitherPlaybook -Name dashboard

# Verify artifacts
$requiredArtifacts = @(
    "library/reports/pr-comment.md"
    "library/reports/changelog.md"
    "library/reports/test-summary.md"
)

foreach ($artifact in $requiredArtifacts) {
    if (Test-Path $artifact) {
        Write-Host "✅ Found: $artifact" -ForegroundColor Green
    } else {
        Write-Host "❌ Missing: $artifact" -ForegroundColor Red
    }
}
```

**Task 4.2: Create Test PR** (1 hour)

1. Push changes to feature branch
2. Open test PR
3. Verify pr-validation.yml triggers
4. Check all steps complete successfully
5. Verify PR comment is posted
6. Check artifacts are uploaded

**Task 4.3: Test Branch Deployment** (1 hour)

1. Merge test PR to dev branch
2. Verify branch-deployment.yml triggers
3. Check test job runs (03-test-execution.yml)
4. Verify Docker build completes
5. Check dashboard generation
6. Verify Pages deployment triggers

**Task 4.4: Monitor & Debug** (1 hour)

Monitor first few runs:
- Check workflow logs for errors
- Verify playbook execution
- Confirm artifacts are created
- Check PR comments
- Verify dashboard publishes

**Commit:** "Verify workflows with end-to-end testing"

---

### Phase 5: Optimization (Optional, 2-4 hours)

**Task 5.1: Add Caching** (1 hour)

Add PowerShell module caching to workflows:
```yaml
- name: 💾 Cache PowerShell Modules
  uses: actions/cache@v4
  with:
    path: ~/.local/share/powershell/Modules
    key: ${{ runner.os }}-pwsh-${{ hashFiles('**/AitherZero.psd1') }}
```

**Task 5.2: Improve Error Handling** (1 hour)

Add better error messages and failure recovery:
```yaml
- name: 🚀 Run Playbook
  shell: pwsh
  run: |
    try {
      Invoke-AitherPlaybook -Name pr-build
    } catch {
      Write-Error "Playbook failed: $_"
      exit 1
    }
```

**Task 5.3: Add Metrics** (1 hour)

Track workflow execution times and artifact sizes:
```yaml
- name: 📊 Record Metrics
  run: |
    echo "workflow_duration_seconds=$SECONDS" >> metrics.txt
    echo "artifact_count=$(ls -1 library/reports/ | wc -l)" >> metrics.txt
```

**Task 5.4: Documentation Updates** (1 hour)

Update:
- README.md with new workflow architecture
- CONTRIBUTING.md with local testing instructions
- docs/ with playbook usage examples

---

## Testing Plan

### Local Testing Checklist

- [ ] Bootstrap completes successfully
- [ ] Module loads without errors
- [ ] Each playbook runs with `-DryRun`
- [ ] Variables are passed correctly
- [ ] Artifacts are created in expected locations
- [ ] No typos in playbook variable names
- [ ] Renamed playbooks load correctly

### CI Testing Checklist

- [ ] pr-validation.yml triggers on PR
- [ ] All steps complete successfully
- [ ] PR comment is posted
- [ ] Artifacts are uploaded
- [ ] branch-deployment.yml triggers on push
- [ ] Tests run in parallel
- [ ] Docker build succeeds
- [ ] Dashboard generates
- [ ] Pages deployment triggers

### Integration Testing Checklist

- [ ] PR workflow → Dashboard → Pages (end-to-end)
- [ ] Branch deployment → Release process
- [ ] Artifact flow between jobs
- [ ] Parallel test execution
- [ ] Error handling and recovery

---

## Rollback Plan

### If Workflows Fail

**Quick Rollback (5 minutes):**
```bash
# Restore archived workflows
cp .github/workflows-archive/*.yml .github/workflows/

# Revert playbook renames
cd library/playbooks/
git checkout HEAD -- pr-ecosystem-*.psd1 dashboard-generation-complete.psd1

# Commit rollback
git add .github/workflows/ library/playbooks/
git commit -m "Rollback workflow changes"
git push
```

### If Playbooks Break

**Playbook-only Rollback (2 minutes):**
```bash
# Just revert playbook changes
cd library/playbooks/
git checkout HEAD~1 -- *.psd1

git commit -m "Revert playbook changes"
git push
```

### Monitoring During Rollout

Monitor these metrics:
- Workflow success rate
- Average execution time
- Artifact upload success
- PR comment posting rate
- Dashboard generation rate

**Rollback triggers:**
- Success rate < 80%
- Execution time > 2x baseline
- Critical features broken (PR comments, dashboards)

---

## Success Criteria

### Must Have (Required)

✅ **All playbooks renamed** (no "complete", no "ecosystem")  
✅ **Variable typos fixed** (PR_NUMBER, GITHUB_RUN_NUMBER)  
✅ **New workflows deployed** (pr-validation.yml, branch-deployment.yml)  
✅ **Old workflows removed** (pr-check.yml, deploy.yml, 05-publish)  
✅ **Local execution works** (all playbooks runnable without GitHub Actions)  
✅ **PR comments posted** (via pr-validation.yml)  
✅ **Dashboard generates** (via branch-deployment.yml)  

### Should Have (Important)

✅ Parallel test execution preserved (03-test-execution.yml)  
✅ Docker builds work (branch-deployment.yml)  
✅ Pages deployment triggers (09-jekyll-gh-pages.yml)  
✅ All artifacts uploaded correctly  
✅ Error handling improves user experience  

### Nice to Have (Optional)

✅ Workflow caching reduces execution time  
✅ Metrics tracking for performance monitoring  
✅ Documentation updated  
✅ Integration tests added  

---

## Quick Reference

### Key Files

| File | Purpose | Lines |
|------|---------|-------|
| `.github/workflows/pr-validation.yml` | NEW - PR validation | ~150 |
| `.github/workflows/branch-deployment.yml` | NEW - Branch deployment | ~200 |
| `library/playbooks/pr-build.psd1` | Build artifacts | 95 |
| `library/playbooks/pr-test.psd1` | Run tests | 114 |
| `library/playbooks/pr-report.psd1` | Generate reports | 102 |
| `library/playbooks/dashboard.psd1` | Create dashboard | 90 |

### Key Commands

**Local Testing:**
```powershell
# Bootstrap
./bootstrap.ps1 -Mode New -InstallProfile Minimal

# Load module
Import-Module ./AitherZero.psd1 -Force

# Test playbooks
Invoke-AitherPlaybook -Name pr-build -DryRun
Invoke-AitherPlaybook -Name pr-test -DryRun
Invoke-AitherPlaybook -Name pr-report -DryRun
Invoke-AitherPlaybook -Name dashboard -DryRun

# Run full workflow
$env:PR_NUMBER = "test"
Invoke-AitherPlaybook -Name pr-build
Invoke-AitherPlaybook -Name pr-test
Invoke-AitherPlaybook -Name pr-report
```

**Workflow Testing:**
```bash
# Trigger PR workflow
gh pr create --title "Test PR" --body "Testing new workflows"

# Trigger branch deployment
git push origin main

# Check workflow status
gh run list --workflow=pr-validation.yml
gh run list --workflow=branch-deployment.yml

# View logs
gh run view <run-id> --log
```

### Time Estimates

| Phase | Tasks | Time |
|-------|-------|------|
| Phase 1 | Fix typos | 30 min |
| Phase 2 | Rename playbooks | 2 hours |
| Phase 3 | Create workflows | 4 hours |
| Phase 4 | Test & verify | 4 hours |
| **Total Core** | - | **10.5 hours** |
| Phase 5 (Optional) | Optimize | 2-4 hours |

---

## Conclusion

This implementation guide provides everything needed to fix the AitherZero workflow system:

1. **Clear problem statement** - 5 critical issues identified
2. **Comprehensive solution** - Rename playbooks, create new workflows
3. **Actionable tasks** - Step-by-step implementation
4. **Testing plan** - Local and CI verification
5. **Rollback plan** - Quick recovery if needed
6. **Success criteria** - Clear definition of done

**Ready to implement:** All analysis is complete, tasks are well-defined, and the solution is proven to work with the local-first principle.

**Next Step:** Create new PR with Phase 1 (fix typos) and begin implementation.
