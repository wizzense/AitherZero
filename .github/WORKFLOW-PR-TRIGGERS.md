# GitHub Actions PR Trigger Strategy

## Overview

This document explains how GitHub Actions workflows are configured to run on Pull Requests, ensuring comprehensive validation without duplicate runs or gaps in coverage.

## Problem Statement (RESOLVED)

Previously, the `pr-validation.yml` workflow only triggered on `opened` and `ready_for_review` events, causing validation checks to be skipped when PRs were updated with new commits. This created gaps in validation coverage where code changes could be pushed without triggering essential checks.

## Solution

All PR validation workflows now trigger on the complete set of PR lifecycle events:
- `opened` - When a PR is first created
- `synchronize` - When new commits are pushed to the PR branch ⭐ **CRITICAL**
- `reopened` - When a closed PR is reopened
- `ready_for_review` - When a draft PR is marked ready (if applicable)

## Workflow Configuration Matrix

| Workflow | PR Events | Path Filters | Purpose |
|----------|-----------|--------------|---------|
| `pr-validation.yml` | opened, synchronize, reopened, ready_for_review | ❌ None | Basic validation for ALL PRs |
| `quality-validation.yml` | opened, synchronize, reopened, ready_for_review | ✅ PowerShell files | Deep quality analysis |
| `validate-config.yml` | Default (opened, synchronize, reopened) | ✅ Config files | Config manifest validation |
| `validate-manifests.yml` | Default (opened, synchronize, reopened) | ✅ .psd1 files | Module manifest validation |
| `copilot-agent-router.yml` | opened, reopened, synchronize, ready_for_review | ❌ None | AI agent routing |
| `deploy-pr-environment.yml` | opened, synchronize, reopened, ready_for_review | ❌ None | Preview deployments |
| `documentation-automation.yml` | opened, synchronize, reopened, closed | ✅ Docs paths | Documentation updates |
| `index-automation.yml` | opened, synchronize, reopened, closed | ✅ Index paths | Index generation |

## Key Design Principles

### 1. Complementary Coverage
Workflows work together to provide comprehensive validation:
- **pr-validation.yml**: Catches ALL PR updates with basic checks
- **quality-validation.yml**: Deep analysis for PowerShell code changes
- **validate-*.yml**: Specific validation for config/manifest files

### 2. No Duplicate Runs
Each workflow uses concurrency groups to prevent wasteful duplicate runs:
```yaml
concurrency:
  group: workflow-name-${{ github.event.pull_request.number }}
  cancel-in-progress: true
```

### 3. Path Filters by Design
Some workflows use path filters intentionally:
- ✅ **Quality validation**: Only runs on PowerShell file changes (expensive checks)
- ✅ **Config validation**: Only runs when config files change
- ❌ **PR validation**: No filters - runs on all PRs for baseline checks

### 4. Default Event Types
When `types:` is not specified under `pull_request:`, GitHub uses defaults:
- `opened`
- `synchronize`
- `reopened`

This is why `validate-config.yml` and `validate-manifests.yml` work correctly without explicit `types:`.

## Verification Checklist

When adding or modifying PR workflows, ensure:

- [ ] **Include `synchronize` event** - Critical for running on PR updates
- [ ] **Consider `reopened` event** - Important for reopened PRs
- [ ] **Add concurrency control** - Prevents duplicate runs
- [ ] **Document path filters** - Explain why certain paths are included/excluded
- [ ] **Test on real PRs** - Verify triggers work as expected

## Common Issues and Solutions

### Issue: Workflow doesn't run when I push new commits to PR
**Solution**: Add `synchronize` to the event types list

### Issue: Workflow runs twice on PR updates
**Solution**: Add concurrency group with `cancel-in-progress: true`

### Issue: Workflow only runs for certain file changes
**Solution**: Check if path filters are too restrictive; remove or adjust as needed

## Testing Workflow Triggers

To test that workflows trigger correctly:

1. **Create a test PR**: `git checkout -b test/workflow-triggers`
2. **Push a commit**: Verify workflows run on PR creation
3. **Push another commit**: Verify workflows run on `synchronize` event
4. **Check Actions tab**: Confirm no duplicate runs
5. **Reopen PR** (if closed): Verify workflows run on `reopened` event

## References

- [GitHub Docs: Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#pull_request)
- [GitHub Docs: Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onpull_requestpull_request_targetbranchesbranches-ignore)
- [Concurrency documentation](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#concurrency)

## Changelog

### 2025-10-31 - Fixed pr-validation.yml
- **Issue**: pr-validation.yml only triggered on `opened` and `ready_for_review`
- **Fix**: Added `synchronize` and `reopened` to event types
- **Impact**: PR validation now runs consistently on every PR update
- **PR**: [#1735](https://github.com/wizzense/AitherZero/pull/1735)
