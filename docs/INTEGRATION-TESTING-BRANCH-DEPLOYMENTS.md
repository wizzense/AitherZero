# Branch-Specific GitHub Pages Deployment - Integration Testing Guide

## Overview

This document provides step-by-step testing procedures to validate the integration of branch-specific GitHub Pages deployments with the PR ecosystem workflows and playbooks.

## Pre-Merge Validation ✅

These validations have been completed and all tests passed:

### 1. Workflow Syntax Validation
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/jekyll-gh-pages.yml'))"
# Result: ✅ YAML syntax valid
```

### 2. Branch Configuration Testing
```bash
# Test branch URL generation logic for all configured branches
./library/automation-scripts/0969_Validate-BranchDeployments.ps1 -ValidateBranchConfig
# Result: ✅ All branch configurations validated (main, dev, dev-staging, develop, ring-*)
```

### 3. Playbook Integration Validation
```bash
# Validate pr-ecosystem-report.psd1 has branch-aware PAGES_URL
./library/automation-scripts/0969_Validate-BranchDeployments.ps1 -ValidatePlaybooks
# Result: ✅ Playbook integration validated
```

### 4. Script Integration Validation
```bash
# Validate 0515_Generate-BuildMetadata.ps1 uses branch-aware URLs
./library/automation-scripts/0969_Validate-BranchDeployments.ps1 -ValidateScripts
# Result: ✅ Script integration validated
```

### 5. Comprehensive Validation
```bash
# Run all validations
./library/automation-scripts/0969_Validate-BranchDeployments.ps1 -All
# Result: ✅ All validations passed
```

## Post-Merge Testing Plan

After merging this PR to target branch (dev-staging, dev, or main), perform these tests:

### Test 1: Workflow Execution

**Objective**: Verify the jekyll-gh-pages workflow runs without errors

**Steps**:
1. Merge PR to target branch (e.g., dev-staging)
   ```bash
   git checkout dev-staging
   git merge copilot/add-branch-specific-gh-deployments
   git push origin dev-staging
   ```

2. Monitor workflow execution:
   - Navigate to: https://github.com/wizzense/AitherZero/actions/workflows/jekyll-gh-pages.yml
   - Watch for workflow trigger
   - Verify all three jobs complete: setup → build → deploy

3. Check for errors in logs:
   - ✅ No "environment protection" errors
   - ✅ Setup job outputs correct branch configuration
   - ✅ Build job creates _config_branch.yml
   - ✅ Deploy job uses peaceiris/actions-gh-pages

**Expected Output**:
```
Setup Deployment Configuration
✅ Branch: dev-staging
📂 Destination: dev-staging
🔗 Base URL: /dev-staging

Build Jekyll Site
✅ Created _config_branch.yml
✅ Created branch-info.md
✅ Jekyll build completed

Deploy to GitHub Pages
✅ Successfully deployed to GitHub Pages!
🌿 Branch: dev-staging
🔗 Deployment URL: https://wizzense.github.io/AitherZero/dev-staging/
```

**Success Criteria**:
- [ ] Workflow completes successfully
- [ ] No environment protection errors
- [ ] All jobs show green checkmarks
- [ ] Deployment URL is correct for branch

### Test 2: Branch Deployment Access

**Objective**: Verify branch-specific URL is accessible

**Steps**:
1. Wait 2-5 minutes for GitHub Pages to propagate
2. Access the branch-specific URL:
   ```
   https://wizzense.github.io/AitherZero/{branch}/
   ```
3. Verify page loads correctly
4. Check branch-info page:
   ```
   https://wizzense.github.io/AitherZero/{branch}/branch-info.html
   ```

**Expected Content**:
- ✅ Page loads without 404 error
- ✅ Branch name displayed correctly
- ✅ Deployment timestamp is recent
- ✅ Links to other branches work
- ✅ Test results/reports specific to this branch

**Success Criteria**:
- [ ] Main URL accessible
- [ ] Branch info page loads
- [ ] Navigation links work
- [ ] Content is branch-specific

### Test 3: Branch Isolation

**Objective**: Verify changes to one branch don't affect others

**Steps**:
1. Make a change to the target branch:
   ```bash
   git checkout dev-staging
   echo "Test change" >> README.md
   git commit -am "Test: verify branch isolation"
   git push origin dev-staging
   ```

2. Wait for deployment to complete

3. Verify deployments:
   - Check dev-staging updated: https://wizzense.github.io/AitherZero/dev-staging/
   - Check main unchanged: https://wizzense.github.io/AitherZero/
   - Check dev unchanged: https://wizzense.github.io/AitherZero/dev/

**Success Criteria**:
- [ ] Target branch deployment updated
- [ ] Main branch deployment unchanged
- [ ] Other branch deployments unchanged
- [ ] Each branch shows its own content

### Test 4: Parallel Deployments

**Objective**: Verify multiple branches can deploy simultaneously

**Steps**:
1. Push to multiple branches within short timeframe:
   ```bash
   # Terminal 1: Push to main
   git checkout main
   echo "Main update" >> index.md
   git commit -am "Test: parallel deployment"
   git push origin main
   
   # Terminal 2: Push to dev (within 1 minute)
   git checkout dev
   echo "Dev update" >> index.md
   git commit -am "Test: parallel deployment"
   git push origin dev
   
   # Terminal 3: Push to dev-staging (within 1 minute)
   git checkout dev-staging
   echo "Dev-staging update" >> index.md
   git commit -am "Test: parallel deployment"
   git push origin dev-staging
   ```

2. Monitor GitHub Actions:
   - Verify all three workflows run in parallel
   - Check concurrency groups (pages-main, pages-dev, pages-dev-staging)

3. Verify all deployments complete successfully

**Success Criteria**:
- [ ] All workflows trigger simultaneously
- [ ] No conflicts or cancellations
- [ ] Each uses correct concurrency group
- [ ] All deployments succeed
- [ ] Each branch has its own content

### Test 5: PR Ecosystem Integration

**Objective**: Verify PR workflows use correct branch-specific URLs

**Steps**:
1. Create a test PR to dev-staging
2. Let PR workflows run (pr-complete.yml, publish-test-reports.yml)
3. Check generated artifacts:
   ```bash
   # Download build metadata artifact
   # Check library/reports/build-metadata.json
   ```

4. Verify build metadata contains:
   ```json
   {
     "pages": {
       "base_url": "https://wizzense.github.io/AitherZero/dev-staging",
       "branch": "dev-staging",
       "branch_path": "/dev-staging"
     }
   }
   ```

5. Check PR comment contains correct deployment URLs

**Success Criteria**:
- [ ] Build metadata has correct branch-specific URLs
- [ ] PR comment references correct deployment
- [ ] Test reports published to correct branch path
- [ ] Dashboard accessible at branch-specific URL

### Test 6: Navigation and Links

**Objective**: Verify all inter-branch navigation works

**Steps**:
1. Start at deployments page: https://wizzense.github.io/AitherZero/deployments.html
2. Click each branch link:
   - Main Branch
   - Dev Branch
   - Dev-Staging Branch
   - Develop Branch
   - Ring branches (if applicable)

3. From each branch deployment:
   - Click "Other Branches" links
   - Verify they navigate to correct URLs
   - Check for 404 errors

**Success Criteria**:
- [ ] Deployments page lists all branches
- [ ] All links navigate to correct URLs
- [ ] No 404 errors on navigation
- [ ] Back navigation works correctly

### Test 7: Test Result Isolation

**Objective**: Verify test results are branch-specific

**Steps**:
1. Run tests on dev-staging branch:
   ```bash
   git checkout dev-staging
   ./library/automation-scripts/0402_Run-UnitTests.ps1
   git add library/reports/
   git commit -m "Update test results"
   git push origin dev-staging
   ```

2. Wait for deployment

3. Verify test results:
   - dev-staging dashboard shows NEW results
   - main dashboard shows OLD results (unchanged)
   - dev dashboard shows OLD results (unchanged)

**Success Criteria**:
- [ ] Test results specific to each branch
- [ ] No cross-contamination of data
- [ ] Dashboards reflect correct branch state
- [ ] Metrics are independent per branch

## Rollback Testing (Optional)

**Objective**: Verify ability to rollback if issues arise

**Steps**:
1. Identify commit to revert (this PR's merge commit)
2. Create revert:
   ```bash
   git revert {merge-commit-sha}
   git push origin {branch}
   ```

3. Verify workflow runs with old configuration
4. Re-apply changes when ready:
   ```bash
   git revert {revert-commit-sha}
   git push origin {branch}
   ```

**Success Criteria**:
- [ ] Revert applies cleanly
- [ ] Old workflow runs successfully
- [ ] Can re-apply changes
- [ ] No data loss during rollback

## Performance Metrics

Track these metrics during testing:

| Metric | Target | Actual |
|--------|--------|--------|
| Workflow Duration (total) | 2-3 min | |
| Setup Job | ~10 sec | |
| Build Job | 1-2 min | |
| Deploy Job | ~30 sec | |
| Pages Propagation (first deploy) | ~5 min | |
| Pages Propagation (updates) | 1-2 min | |

## Troubleshooting

### Issue: Deployment Fails with "refused to deploy"

**Cause**: GitHub Pages source not configured correctly

**Fix**:
1. Settings → Pages
2. Source: "Deploy from a branch"
3. Branch: "gh-pages"
4. Folder: "/ (root)"
5. Save and re-run workflow

### Issue: 404 Errors on Branch URLs

**Cause**: Jekyll baseurl not configured or files not deployed

**Fix**:
1. Check workflow logs for build errors
2. Verify `_config_branch.yml` created with correct baseurl
3. Verify files uploaded to correct subdirectory
4. Wait 5-10 minutes for CDN propagation

### Issue: Cross-Contamination of Test Results

**Cause**: Reports directory shared between branches

**Fix**:
1. Verify each branch has own `library/reports/` directory
2. Don't copy reports between branches
3. Regenerate reports on each branch independently

## Success Checklist

Complete testing when all these criteria are met:

- [ ] All workflows execute without errors
- [ ] Branch-specific URLs accessible for all configured branches
- [ ] Navigation between branches works correctly
- [ ] Test results isolated per branch
- [ ] Parallel deployments work without conflicts
- [ ] PR ecosystem generates correct branch-specific URLs
- [ ] Performance metrics within acceptable ranges
- [ ] No regressions in existing functionality

## Reporting Results

Document test results in PR comment:

```markdown
## Testing Results

### Pre-Merge Validation
✅ All validations passed

### Post-Merge Testing
- [ ] Test 1: Workflow Execution - {PASS/FAIL}
- [ ] Test 2: Branch Deployment Access - {PASS/FAIL}
- [ ] Test 3: Branch Isolation - {PASS/FAIL}
- [ ] Test 4: Parallel Deployments - {PASS/FAIL}
- [ ] Test 5: PR Ecosystem Integration - {PASS/FAIL}
- [ ] Test 6: Navigation and Links - {PASS/FAIL}
- [ ] Test 7: Test Result Isolation - {PASS/FAIL}

### Issues Found
{List any issues discovered during testing}

### Performance Metrics
{Report actual metrics vs targets}
```

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-09  
**Status**: Ready for Post-Merge Testing
