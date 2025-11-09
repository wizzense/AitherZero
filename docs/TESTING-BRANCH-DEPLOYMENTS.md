# Testing Guide: Branch-Specific GitHub Pages Deployments

## Quick Test Checklist

After merging this PR to dev-staging:

- [ ] Workflow runs without errors
- [ ] No environment protection warnings
- [ ] Deployment completes successfully
- [ ] Branch URL is accessible
- [ ] Navigation between branches works
- [ ] Test results are branch-specific

## Detailed Testing Steps

### 1. Monitor Deployment Workflow

```bash
# Merge to dev-staging
git checkout dev-staging
git merge copilot/update-dev-staging-pages
git push origin dev-staging
```

**Watch for:**
- GitHub Actions workflow triggers automatically
- "Deploy Jekyll with GitHub Pages" workflow runs
- All three jobs complete: setup → build → deploy
- No "environment protection" errors
- Successful deployment message

**View workflow:**
https://github.com/wizzense/AitherZero/actions/workflows/jekyll-gh-pages.yml

### 2. Verify Deployment Output

**Expected in workflow logs:**

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

### 3. Access Branch Deployment

**Main URL:**
https://wizzense.github.io/AitherZero/dev-staging/

**Branch Info Page:**
https://wizzense.github.io/AitherZero/dev-staging/branch-info.html

**Dashboard:**
https://wizzense.github.io/AitherZero/dev-staging/library/reports/dashboard.html

**Expected Content:**
- ✅ Branch name shows "dev-staging"
- ✅ Deployment timestamp is recent
- ✅ Links to other branches work
- ✅ Test results specific to dev-staging branch

### 4. Verify Branch Isolation

**Test that changes to dev-staging don't affect other branches:**

```bash
# Make a change to dev-staging
git checkout dev-staging
echo "Test change" >> index.md
git commit -am "Test: verify branch isolation"
git push origin dev-staging
```

**After deployment:**
- ✅ dev-staging deployment updates
- ✅ main deployment unchanged
- ✅ dev deployment unchanged

**Verify:**
- https://wizzense.github.io/AitherZero/ (main - should NOT change)
- https://wizzense.github.io/AitherZero/dev/ (dev - should NOT change)
- https://wizzense.github.io/AitherZero/dev-staging/ (should update)

### 5. Test Navigation

**From any branch deployment, verify these links work:**

- [ ] Link to deployments page: `/deployments.html`
- [ ] Link to main branch: `/`
- [ ] Link to dev branch: `/dev/`
- [ ] Link to dev-staging branch: `/dev-staging/`
- [ ] Link to branch-info page

**Navigation should:**
- Work without 404 errors
- Load correct branch content
- Show branch-specific test results

### 6. Verify Test Result Isolation

**Check that test results are branch-specific:**

1. **Run tests on dev-staging:**
   ```bash
   git checkout dev-staging
   ./library/automation-scripts/0402_Run-UnitTests.ps1
   git add library/reports/
   git commit -m "Update test results"
   git push origin dev-staging
   ```

2. **After deployment, verify:**
   - dev-staging dashboard shows NEW test results
   - main dashboard shows OLD test results (unchanged)
   - dev dashboard shows OLD test results (unchanged)

### 7. Test Parallel Deployments

**Trigger deployments from multiple branches simultaneously:**

```bash
# Terminal 1: Push to main
git checkout main
echo "Main update" >> README.md
git commit -am "Test: main deployment"
git push origin main

# Terminal 2: Push to dev (within 1 minute)
git checkout dev  
echo "Dev update" >> README.md
git commit -am "Test: dev deployment"
git push origin dev

# Terminal 3: Push to dev-staging (within 1 minute)
git checkout dev-staging
echo "Dev-staging update" >> README.md
git commit -am "Test: dev-staging deployment"
git push origin dev-staging
```

**Expected:**
- All three workflows run in parallel
- No conflicts or errors
- Each branch deploys to its own subdirectory
- All deployments complete successfully

### 8. Verify Workflow Permissions

**Check that workflow has correct permissions:**

In workflow logs, look for:
```
Permissions:
  contents: write ✓
  pages: write ✓
  id-token: write ✓
```

**If deployment fails with permission errors:**
1. Go to repository Settings → Actions → General
2. Under "Workflow permissions", select "Read and write permissions"
3. Click "Save"
4. Re-run the workflow

### 9. Check GitHub Pages Settings

**Verify Pages configuration:**

1. Go to repository Settings → Pages
2. Check source is set to: **gh-pages branch**
3. Verify build and deployment status shows recent activity
4. Check that multiple subdirectories exist (main, dev, dev-staging)

**If using "GitHub Actions" source instead:**
- This will NOT work with peaceiris/actions-gh-pages
- Change to "Deploy from a branch" → "gh-pages" → "/ (root)"

### 10. Rollback Test (Optional)

**If something goes wrong, test rollback:**

```bash
# Revert the changes
git revert f035f67  # or use the actual commit SHA
git push origin dev-staging
```

**Verify:**
- Old deployment behavior restored
- Workflow runs with previous configuration
- Can re-apply changes when ready

## Troubleshooting

### Issue: Deployment fails with "refused to deploy"

**Cause**: GitHub Pages source not configured correctly

**Fix**:
1. Settings → Pages
2. Source: "Deploy from a branch"
3. Branch: "gh-pages"
4. Folder: "/ (root)"
5. Save and re-run workflow

### Issue: 404 errors on branch URLs

**Cause**: Jekyll baseurl not configured correctly or files not deployed

**Fix**:
1. Check workflow logs for build errors
2. Verify `_config_branch.yml` was created with correct baseurl
3. Check that files were uploaded to correct subdirectory
4. Wait 5-10 minutes for GitHub Pages CDN to propagate

### Issue: Other branches disappeared

**Cause**: `keep_files: false` in workflow

**Fix**:
1. Already set to `keep_files: true` in this PR
2. If issue persists, check workflow file
3. Re-deploy other branches to restore them

### Issue: Cross-contamination of test results

**Cause**: Reports directory shared between branches

**Fix**:
1. Verify each branch has its own `library/reports/` directory
2. Don't copy reports between branches
3. Regenerate reports on each branch independently

## Success Criteria

✅ **All deployments successful** - No environment protection errors  
✅ **Branch URLs accessible** - All branch deployments load correctly  
✅ **Navigation works** - Links between branches functional  
✅ **Test results isolated** - Each branch shows its own data  
✅ **Parallel deployments** - Multiple branches deploy simultaneously  
✅ **No regressions** - Existing main branch deployment still works  

## Performance Metrics

**Expected workflow duration:**
- Setup job: ~10 seconds
- Build job: ~1-2 minutes
- Deploy job: ~30 seconds
- **Total**: ~2-3 minutes

**GitHub Pages propagation:**
- Initial deployment: ~5 minutes
- Updates: ~1-2 minutes

## Additional Verification

### Check gh-pages Branch

```bash
# Clone and inspect gh-pages branch
git clone -b gh-pages https://github.com/wizzense/AitherZero.git pages-check
cd pages-check

# Verify directory structure
ls -la
# Should show: dev/, dev-staging/, develop/, ring-*/, and files for main

# Check dev-staging specifically
ls -la dev-staging/
# Should show: branch-info.md, library/, index.md, etc.
```

### Validate HTML Output

```bash
# Download and validate a page
curl -s https://wizzense.github.io/AitherZero/dev-staging/branch-info.html | grep "dev-staging"
# Should return lines containing "dev-staging"

# Check dashboard exists
curl -I https://wizzense.github.io/AitherZero/dev-staging/library/reports/dashboard.html
# Should return: HTTP/2 200
```

## Reporting Issues

If you encounter issues:

1. **Capture workflow logs**: Copy full output from failed job
2. **Check browser console**: Look for JavaScript errors
3. **Verify URLs**: Test with curl or browser dev tools
4. **Document steps**: What you did, what happened, what you expected

**Report to**: GitHub Issues with label `deployment` and `documentation`

---

**Testing Status**: Ready for validation  
**Last Updated**: 2025-11-09  
**Version**: 1.0
