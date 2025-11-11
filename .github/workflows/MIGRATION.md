# CI/CD Pipeline Migration Guide

## Summary of Changes

The AitherZero CI/CD pipeline has been **dramatically simplified** from 13 workflows to 6 workflows.

This eliminates:
- ✅ PR comment spam (6+ → 1 comment)
- ✅ Race conditions (orchestrator vs workflow_run)
- ✅ Global bottlenecks (pages concurrency locks)
- ✅ Single points of failure (orchestrator)
- ✅ Useless deployments (ephemeral runners)

## What Changed

### Deleted Workflows (8)

These workflows have been **deleted** and their functionality consolidated:

1. **`01-master-orchestrator.yml`** → Consolidated into `pr-check.yml` and `deploy.yml`
2. **`02-pr-validation-build.yml`** → Merged into `pr-check.yml`
3. **`06-documentation.yml`** → Merged into `pr-check.yml` (docs job)
4. **`07-indexes.yml`** → Merged into `pr-check.yml` (docs job)
5. **`08-update-pr-title.yml`** → Removed (feature removed)
6. **`10-module-validation-performance.yml`** → Merged into `pr-check.yml` (validate job)
7. **`30-ring-status-dashboard.yml`** → Merged into `deploy.yml`
8. **`31-diagnose-ci-failures.yml`** → Removed (no longer needed)

### New Workflows (2)

1. **`pr-check.yml`** - Single consolidated PR validation workflow
   - Runs validation, tests, build, docker, docs in parallel
   - Posts ONE comprehensive summary comment
   
2. **`deploy.yml`** - Single deployment workflow for push events
   - Builds and pushes Docker images
   - Deploys to real environments (not ephemeral runners)
   - Publishes dashboards with branch-specific concurrency

### Renamed Workflows (1)

1. **`20-release-automation.yml`** → **`release.yml`**
   - Simplified and renamed for consistency
   - Removed workflow_call trigger (no orchestrator)

### Modified Workflows (3)

1. **`03-test-execution.yml`** - No changes (works as-is)
   - Still used by pr-check.yml via workflow_call
   - Can still run standalone

2. **`05-publish-reports-dashboard.yml`** - Fixed concurrency
   - Changed: `pages-publish` → `pages-publish-${{ github.ref }}`
   - No longer called by orchestrator (manual only)

3. **`09-jekyll-gh-pages.yml`** - Fixed concurrency
   - Changed: `pages-${{ github.ref_name }}` → `pages-${{ github.ref }}`

### Disabled Workflows (1)

1. **`04-deploy-pr-environment.yml`** → **`04-deploy-pr-environment.yml.disabled`**
   - Ephemeral deployments are useless (no external access)
   - Use Docker images instead

## Action Items by Role

### For All Team Members

**No action required!** The changes are transparent.

- ✅ You'll get **1 PR comment** instead of 6+ (less noise)
- ✅ PRs won't block each other anymore (faster merges)
- ✅ CI/CD will be faster and more reliable

### For PR Authors

**What to expect:**

1. **Before:** Multiple bot comments on your PR (validation, tests, build, docker, docs, etc.)
2. **After:** ONE comprehensive comment with all results

**Example PR comment (new format):**

```
## ✅ PR Check - PASSED

### 📋 Results

| Check | Status | Details |
|-------|--------|---------|
| ✅ Validation | SUCCESS | Syntax, Config, Manifests, Architecture |
| ✅ Tests | SUCCESS | Unit, Domain, Integration tests |
| ✅ Build | SUCCESS | Release packages |
| ✅ Docker | SUCCESS | Container build test |
| ✅ Docs | SUCCESS | Documentation generation |

### 🔗 Links
- [Workflow Run](...)
- [Test Results](...)
- [Build Artifacts](...)

### ✅ Ready to Merge

All checks passed! Your PR is ready for review.
```

### For Maintainers

**Required actions:**

1. **Update any automation scripts** that referenced old workflow names
   - Search for: `01-master-orchestrator`, `02-pr-validation-build`, etc.
   - Replace with: `pr-check.yml`, `deploy.yml`, `release.yml`

2. **Update documentation** that mentions workflow names
   - Check: README files, wiki pages, runbooks
   - Update: Workflow names and trigger descriptions

3. **Monitor first few PRs** after merge
   - Verify: Exactly 1 PR comment appears
   - Verify: All checks run successfully
   - Verify: No duplicate runs or race conditions

4. **Clean up disabled workflow file** after verification
   ```bash
   rm .github/workflows/04-deploy-pr-environment.yml.disabled
   rm .github/workflows/README.md.old
   ```

### For DevOps/Infrastructure

**Required actions:**

1. **Verify GitHub Pages concurrency** is working correctly
   - Test: Push to 2 different branches simultaneously
   - Verify: Both can deploy to Pages without waiting
   - Before: Second deployment queued waiting for first
   - After: Both deploy in parallel to different paths

2. **Verify staging deployments** work correctly
   - Test: Push to `dev-staging` branch
   - Verify: Docker image built and pushed
   - Verify: Staging environment deployed
   - Verify: Dashboard published

3. **Update monitoring/alerting** if needed
   - Update: Workflow names in monitoring dashboards
   - Update: Alert rules that reference old workflows

## Migration Timeline

| Phase | Timeline | Status |
|-------|----------|--------|
| Development | Nov 11, 2025 | ✅ Complete |
| Testing | Nov 11-12, 2025 | 🔄 In Progress |
| Rollout | Nov 12, 2025 | ⏳ Pending |
| Monitoring | Nov 12-19, 2025 | ⏳ Pending |
| Cleanup | Nov 19, 2025 | ⏳ Pending |

## Testing Checklist

Before considering this migration complete, verify:

- [ ] Create a test PR and verify:
  - [ ] Exactly 1 bot comment appears
  - [ ] Comment includes all check results (validate, test, build, docker, docs)
  - [ ] Workflow completes in reasonable time (< 15 minutes)
  - [ ] No duplicate workflow runs
  
- [ ] Push to `dev-staging` and verify:
  - [ ] Docker image is built and pushed to ghcr.io
  - [ ] Staging environment is deployed
  - [ ] Dashboard is published to GitHub Pages
  - [ ] No concurrency blocking
  
- [ ] Push to `main` and verify:
  - [ ] Docker image is built and pushed
  - [ ] Dashboard is published
  - [ ] No staging deployment (main doesn't deploy to staging)
  
- [ ] Create a release tag and verify:
  - [ ] Release workflow runs
  - [ ] GitHub release is created
  - [ ] Artifacts are uploaded

## Rollback Plan

If critical issues are discovered:

1. **Immediate rollback:**
   ```bash
   git revert <commit-sha>
   git push origin main
   ```

2. **Restore old workflows:**
   ```bash
   git checkout <previous-commit> -- .github/workflows/
   git commit -m "Rollback: Restore old CI/CD workflows"
   git push origin main
   ```

3. **Investigate issues:**
   - Review workflow run logs
   - Check for syntax errors
   - Verify trigger conditions
   - Test locally if possible

4. **Fix and retry:**
   - Address root cause
   - Test thoroughly
   - Redeploy with fixes

## Common Issues and Solutions

### Issue: PR comment not appearing

**Symptoms:** PR created but no bot comment

**Cause:** Workflow may have failed early

**Solution:**
1. Check Actions tab for workflow run
2. Look for errors in workflow logs
3. Verify workflow file syntax: `yamllint .github/workflows/pr-check.yml`

### Issue: Multiple PR comments

**Symptoms:** More than 1 bot comment on PR

**Cause:** Old workflows may still be running

**Solution:**
1. Check `.github/workflows/` directory
2. Verify old workflows are deleted
3. Cancel any running old workflow runs

### Issue: Deployment not triggering

**Symptoms:** Push to branch but deploy.yml doesn't run

**Cause:** Branch not in monitored list

**Solution:**
1. Check `deploy.yml` trigger branches
2. Add your branch if needed
3. Or push to existing branch (main, dev, dev-staging)

### Issue: Pages deployment conflict

**Symptoms:** "Deployment in progress" message, queuing

**Cause:** Old global concurrency lock may still be cached

**Solution:**
1. Wait for current deployment to finish
2. Cancel any stuck deployments
3. Retry - new concurrency should work

## Benefits Verification

After migration, you should observe:

### Metrics to Track

1. **PR Notification Count**
   - Before: 6+ notifications per PR commit
   - After: 1 notification per PR commit
   - **Target: 85% reduction**

2. **PR Validation Time**
   - Before: 15-20 minutes (sequential + duplicates)
   - After: 8-12 minutes (parallel, single run)
   - **Target: 40% reduction**

3. **Deploy Time**
   - Before: 10-15 minutes (global locks, queuing)
   - After: 8-10 minutes (branch-specific, no queuing)
   - **Target: 30% reduction**

4. **Workflow Failures**
   - Before: ~10% failure rate (race conditions, timeouts)
   - After: ~2% failure rate (simpler, more reliable)
   - **Target: 80% reduction in failures**

### Qualitative Improvements

- ✅ Developers report less notification spam
- ✅ PRs merge faster (no queuing)
- ✅ Easier to troubleshoot failures (simpler workflows)
- ✅ Less CI/CD maintenance burden

## Support

If you encounter issues:

1. **Check this guide first**
2. **Review workflow logs** in Actions tab
3. **Ask in team chat** - others may have same issue
4. **Create an issue** with:
   - Workflow name
   - Error message
   - Link to failed run
   - Steps to reproduce

## References

- [New Workflow Documentation](./.github/workflows/README.md)
- [pr-check.yml](./pr-check.yml)
- [deploy.yml](./deploy.yml)
- [release.yml](./release.yml)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

**Migration Owner:** Maya Infrastructure  
**Last Updated:** 2025-11-11  
**Status:** Testing Phase
