# Feature Branch PR Workflow

## Overview

This document explains how GitHub Actions workflows behave differently based on the **target branch** of a Pull Request, enabling incremental fixes in feature/copilot branches before merging to main branches.

## Problem Statement

When working on feature branches (especially copilot-generated branches), you may need to:
1. Fix specific issues in the feature branch itself
2. Make incremental improvements without full validation
3. Merge fixes quickly to unblock work
4. Apply full validation only when merging to main branches

## Solution

AitherZero now has **branch-aware PR validation** that applies different validation levels based on the PR target branch:

### Validation Levels

| PR Target Branch | Validation Level | Workflow | Purpose |
|------------------|------------------|----------|---------|
| `main`, `develop`, `dev` | **Full** | All standard workflows | Comprehensive validation for production/staging |
| `copilot/*`, `feature/*`, `fix/*` | **Light** | `feature-branch-pr-validation.yml` | Quick validation for incremental fixes |
| Other branches | **Light** | `feature-branch-pr-validation.yml` | Flexible validation for custom workflows |

## Workflow Behaviors

### 1. Feature Branch PR Validation (`feature-branch-pr-validation.yml`)

**Triggers:** PRs targeting any branch EXCEPT `main`, `develop`, `dev`

**What it does:**
- ✅ **Syntax validation** - Ensures PowerShell code parses correctly
- ✅ **Critical issue detection** - Checks for PSScriptAnalyzer errors/parse errors only
- ✅ **Change analysis** - Reviews file changes and impact
- ⏭️ **Skips** comprehensive tests, full quality checks, documentation requirements

**Purpose:** Enable quick fixes for specific branch issues without full validation overhead

### 2. PR Validation (`pr-validation.yml`)

**Triggers:** All PRs (any target branch)

**What it does:**
- 🎯 **Detects target branch** - Identifies if PR targets main or feature branch
- 📊 **Shows validation level** - Comments on PR explaining which validation applies
- ✅ **Syntax validation** - For trusted PRs from repository (not forks)
- 📋 **Change analysis** - File categorization and recommendations

**Behavior changes:**
- For **main branch PRs**: Shows "Full validation is applied"
- For **feature branch PRs**: Shows "Light validation applies; full validation when merging to dev/main"

### 3. Quality Validation (`quality-validation.yml`)

**Triggers:** PRs targeting `main`, `develop`, `dev` OR workflow_dispatch

**What it does:**
- 🔍 **Deep quality analysis** - Comprehensive PSScriptAnalyzer checks
- 📊 **Component quality scores** - Validates against quality standards
- ⏭️ **Skips for feature branch PRs** - Defers to `feature-branch-pr-validation.yml`

**Purpose:** Full quality gates only when merging to main branches

### 4. Comprehensive Test Execution (`comprehensive-test-execution.yml`)

**Triggers:** PRs targeting `main`, `develop`, `dev` only

**What it does:**
- 🧪 **Full test suite** - All unit and integration tests
- 📊 **Test aggregation** - Comprehensive reporting
- ⏭️ **Automatically skipped** for feature branch PRs

**Purpose:** Ensure production-ready code before merging to main branches

## Usage Examples

### Example 1: Fix Issue in Copilot Branch

```bash
# Scenario: A copilot branch has a specific issue that needs fixing

# 1. Create a fix branch from the copilot branch
git checkout copilot/my-feature
git checkout -b fix/copilot-issue

# 2. Make your fixes
# ... edit files ...

# 3. Create PR: fix/copilot-issue → copilot/my-feature
git push origin fix/copilot-issue
# Create PR via GitHub UI targeting copilot/my-feature

# Result:
# - feature-branch-pr-validation.yml runs (light validation)
# - Quick syntax and critical issue checks only
# - Can merge quickly to unblock work
```

### Example 2: Feature Branch to Dev (Full Validation)

```bash
# Scenario: Ready to merge feature work to dev

# Create PR: copilot/my-feature → dev
# (via GitHub UI)

# Result:
# - pr-validation.yml runs (with full validation note)
# - quality-validation.yml runs (comprehensive checks)
# - comprehensive-test-execution.yml runs (all tests)
# - Must pass all checks before merging
```

### Example 3: Hotfix to Production

```bash
# Scenario: Critical fix needs to go to main

# 1. Create hotfix branch from main
git checkout main
git pull
git checkout -b hotfix/critical-issue

# 2. Make minimal fix
# ... edit files ...

# 3. Create PR: hotfix/critical-issue → main
git push origin hotfix/critical-issue
# Create PR via GitHub UI targeting main

# Result:
# - FULL validation suite runs (all workflows)
# - Must pass all quality gates
# - Comprehensive testing required
```

## Decision Flow

```
PR Created
    │
    ├─ Target: main/develop/dev?
    │   │
    │   ├─ YES → Full Validation
    │   │         ├─ pr-validation.yml
    │   │         ├─ quality-validation.yml
    │   │         ├─ comprehensive-test-execution.yml
    │   │         └─ All other validation workflows
    │   │
    │   └─ NO → Light Validation
    │             ├─ feature-branch-pr-validation.yml
    │             └─ pr-validation.yml (with feature branch notice)
```

## Branch Naming Conventions

For optimal workflow behavior, use these naming patterns:

| Pattern | Purpose | Example |
|---------|---------|---------|
| `copilot/*` | GitHub Copilot generated branches | `copilot/fix-issue-123` |
| `feature/*` | Feature development | `feature/new-reporting` |
| `fix/*` | Bug fixes | `fix/syntax-error` |
| `hotfix/*` | Production hotfixes | `hotfix/critical-bug` |
| `bugfix/*` | General bug fixes | `bugfix/test-failure` |

## Workflow Configuration Details

### Feature Branch Detection Logic

In `feature-branch-pr-validation.yml`:
```yaml
on:
  pull_request:
    branches-ignore:
      - main
      - develop
      - dev
```

This ensures it ONLY triggers for PRs targeting non-main branches.

### Main Branch Detection Logic

In workflows that should only run for main branch PRs:
```yaml
on:
  pull_request:
    branches: [main, develop, dev]
```

This ensures they ONLY trigger for PRs targeting main branches.

### Branch Type Detection Job

All workflows include a branch detection job:
```yaml
jobs:
  detect-pr-target:
    name: 🎯 Detect PR Target Branch
    runs-on: ubuntu-latest
    outputs:
      is-main-branch-pr: ${{ steps.detect.outputs.is-main-branch-pr }}
      target-branch: ${{ steps.detect.outputs.target-branch }}
    
    steps:
      - name: 🔍 Detect Target Branch
        shell: bash
        run: |
          BASE_BRANCH="${{ github.event.pull_request.base.ref }}"
          
          if [[ "$BASE_BRANCH" == "main" || "$BASE_BRANCH" == "develop" || "$BASE_BRANCH" == "dev" ]]; then
            echo "is-main-branch-pr=true" >> $GITHUB_OUTPUT
          else
            echo "is-main-branch-pr=false" >> $GITHUB_OUTPUT
          fi
```

## Benefits

### ✅ Faster Iteration on Feature Branches
- Quick validation enables rapid fixes
- No waiting for full test suite
- Reduced CI/CD costs for incremental work

### ✅ Maintained Quality on Main Branches
- Full validation still applies when it matters
- Production/staging code gets comprehensive checks
- No compromise on release quality

### ✅ Clear Communication
- PR comments explain validation level
- Users understand what's required
- Reduced confusion about workflow behavior

### ✅ Flexible Development Process
- Supports incremental improvements
- Enables copilot-assisted workflows
- Accommodates various branching strategies

## Migration Guide

### For Existing Feature Branches

No action required! The new workflows will automatically detect and apply the appropriate validation level on the next PR update.

### For New Development

1. **Feature work:** Create branch from `dev`, work on it, PR back to dev (full validation)
2. **Quick fixes:** Create branch from feature branch, fix issue, PR to feature branch (light validation)
3. **Final merge:** PR feature branch to dev/main (full validation)

## Testing the Workflows

### Test Light Validation

```bash
# 1. Create a test feature branch
git checkout -b test/feature-validation
git commit --allow-empty -m "Test feature validation"
git push origin test/feature-validation

# 2. Create another branch from it
git checkout -b test/feature-validation-pr
git commit --allow-empty -m "Test PR to feature branch"
git push origin test/feature-validation-pr

# 3. Create PR: test/feature-validation-pr → test/feature-validation
# Expected: feature-branch-pr-validation.yml runs, light validation
```

### Test Full Validation

```bash
# 1. Create PR: test/feature-validation → dev
# Expected: All validation workflows run, comprehensive checks
```

## Troubleshooting

### Issue: Full validation running on feature branch PR

**Cause:** Target branch might be `main`, `develop`, or `dev`

**Solution:** Check PR target branch in GitHub UI; ensure it targets the feature branch

### Issue: Light validation running on main branch PR

**Cause:** Workflow configuration issue

**Solution:** Check that PR targets `main`, `develop`, or `dev`; contact maintainers if issue persists

### Issue: No validation running

**Cause:** Draft PR or fork PR (security restrictions)

**Solution:** Mark PR as ready for review; fork PRs require maintainer approval

## References

- [Main Workflow Documentation](.github/workflows/README.md)
- [PR Trigger Strategy](WORKFLOW-PR-TRIGGERS.md)
- [Duplicate Run Fix](DUPLICATE_RUN_FIX_SUMMARY.md)
- [GitHub Actions: Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#pull_request)

## Changelog

### 2025-11-03 - Initial Implementation
- **Added:** `feature-branch-pr-validation.yml` workflow
- **Modified:** `pr-validation.yml` to detect target branch
- **Modified:** `quality-validation.yml` to skip for feature branch PRs
- **Purpose:** Enable incremental fixes in feature branches with lighter validation
- **Issue:** [Link to issue or PR]

---

**Questions or feedback?** Open an issue or contact the AitherZero maintainers.
