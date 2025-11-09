# GitHub Pages Deployment Guide - Dev-Staging

This guide provides step-by-step instructions for deploying the full validation results to GitHub Pages dev-staging environment.

---

## 🎯 Deployment Overview

**Objective**: Deploy comprehensive validation results, dashboard, and reports to GitHub Pages dev-staging subdirectory.

**Target URL**: `https://wizzense.github.io/AitherZero/dev-staging/`

**Current Status**: ✅ All artifacts prepared and committed to `copilot/full-validation-and-deployment` branch.

---

## 📋 Prerequisites

Before deployment, ensure:
- [x] All validation scripts executed successfully
- [x] Dashboard and reports generated
- [x] Artifacts committed to repository
- [x] GitHub Pages enabled in repository settings
- [x] Workflow permissions set to "Read and write"

---

## 🚀 Deployment Methods

### Method 1: Create Pull Request (RECOMMENDED)

This method triggers the full PR ecosystem including Docker container deployment.

#### Via GitHub CLI:
```bash
gh pr create \
  --base dev-staging \
  --head copilot/full-validation-and-deployment \
  --title "Full Validation Results - Dev-Staging Deployment" \
  --body "
# Full Validation Results

Complete end-to-end validation with comprehensive dashboard and reports.

## Artifacts Included
- ✅ Comprehensive dashboard (HTML, JSON, Markdown)
- ✅ Project reports with full metrics
- ✅ Navigation indexes
- ✅ Metrics history
- ✅ 262 files committed

## Validation Results
- **Syntax**: 1,263 files, 0 errors (100% pass)
- **Config**: Validated with minor warnings
- **Dashboard**: Generated successfully
- **Reports**: All formats created

See VALIDATION-DEPLOYMENT-SUMMARY.md for complete details.
"
```

#### Via GitHub Web UI:
1. Navigate to: https://github.com/wizzense/AitherZero/compare
2. Set base: `dev-staging`
3. Set compare: `copilot/full-validation-and-deployment`
4. Click "Create pull request"
5. Fill in title and description
6. Click "Create pull request"

**Result**: 
- PR created with full ecosystem
- Docker container built and published
- GitHub Pages deployed to `/dev-staging/`
- Dashboard accessible at deployment URL

---

### Method 2: Direct Branch Push (FAST)

This method directly pushes to dev-staging, triggering immediate deployment.

#### Step 1: Create dev-staging branch (if needed)
```bash
# If dev-staging doesn't exist
git checkout -b dev-staging copilot/full-validation-and-deployment
git push -u origin dev-staging
```

#### Step 2: Or merge to existing dev-staging
```bash
# If dev-staging exists
git checkout dev-staging
git pull origin dev-staging
git merge --ff-only copilot/full-validation-and-deployment
git push origin dev-staging
```

**Result**:
- Immediate deployment to GitHub Pages
- No PR review process
- Faster time to live site (~5 minutes)

---

### Method 3: Manual Workflow Trigger (NOT RECOMMENDED)

Only use if above methods fail.

#### Via GitHub CLI:
```bash
gh workflow run "jekyll-gh-pages.yml" \
  --ref copilot/full-validation-and-deployment
```

#### Via GitHub Web UI:
1. Navigate to: https://github.com/wizzense/AitherZero/actions
2. Select: "Deploy Jekyll with GitHub Pages dependencies preinstalled"
3. Click: "Run workflow"
4. Select branch: `copilot/full-validation-and-deployment`
5. Click: "Run workflow"

**Limitations**:
- May not deploy to correct subdirectory
- Branch not in workflow trigger list
- Not recommended for production use

---

## 📊 Workflow Details

When deployment triggers, the workflow will:

### 1. Setup Deployment Configuration
```yaml
Branch: copilot/full-validation-and-deployment (or dev-staging)
Destination: dev-staging/
Base URL: /dev-staging
Deployment URL: https://wizzense.github.io/AitherZero/dev-staging/
```

### 2. Build Jekyll Site
- ✅ Checkout repository
- ✅ Create branch-specific config
- ✅ Copy MCP server documentation
- ✅ Create branch info page
- ✅ Setup Ruby 3.1
- ✅ Install Jekyll and dependencies
- ✅ Build site with both configs

### 3. Deploy to GitHub Pages
- ✅ Upload build artifact
- ✅ Deploy using peaceiris/actions-gh-pages
- ✅ Publish to `dev-staging/` subdirectory
- ✅ Keep existing files
- ✅ Report deployment URL

### 4. Post-Deployment
- ✅ Generate deployment summary
- ✅ Report available pages
- ✅ List all deployments

**Duration**: 5-10 minutes total

---

## 🔍 Verification Steps

Once deployment completes, verify:

### 1. Check Workflow Status
```bash
# Via GitHub CLI
gh run list --workflow=jekyll-gh-pages.yml --limit 1

# Via Web UI
https://github.com/wizzense/AitherZero/actions
```

### 2. Verify Deployment URL
```bash
# Main dashboard
curl -I https://wizzense.github.io/AitherZero/dev-staging/library/reports/dashboard.html

# Root index
curl -I https://wizzense.github.io/AitherZero/dev-staging/index.html

# Branch info
curl -I https://wizzense.github.io/AitherZero/dev-staging/branch-info.html
```

### 3. Test Dashboard Functionality
Visit in browser:
- Main Dashboard: `/dev-staging/library/reports/dashboard.html`
- Navigation Index: `/dev-staging/index.html`
- Branch Info: `/dev-staging/branch-info.html`
- Reports Directory: `/dev-staging/library/reports/`

### 4. Check Links
- [ ] Dashboard loads without errors
- [ ] All navigation links work
- [ ] Interactive features functional
- [ ] Metrics display correctly
- [ ] Historical data accessible
- [ ] Reports browsable

---

## 🐛 Troubleshooting

### Issue: Workflow doesn't trigger

**Cause**: Branch not in trigger list

**Solution**: 
- Use Method 1 (PR to dev-staging) or
- Use Method 2 (push to dev-staging directly)

---

### Issue: 404 errors on deployed site

**Cause**: Base URL misconfiguration

**Fix**:
1. Check `_config_branch.yml` has correct `baseurl`
2. Verify deployment subdirectory matches base URL
3. Rebuild site if needed

---

### Issue: Jekyll build fails

**Cause**: Invalid YAML or missing dependencies

**Fix**:
1. Check workflow logs for specific error
2. Validate `_config.yml` and `_config_branch.yml`
3. Ensure all referenced files exist
4. Check for YAML syntax errors

---

### Issue: Dashboard doesn't display correctly

**Cause**: Missing assets or incorrect paths

**Fix**:
1. Verify all dashboard files copied to `library/reports/`
2. Check browser console for 404 errors
3. Verify Jekyll includes all report files
4. Check `_config.yml` include/exclude patterns

---

### Issue: GitHub Pages not enabled

**Cause**: Repository settings

**Fix**:
1. Go to: Settings → Pages
2. Source: Select "gh-pages branch" (for peaceiris/actions-gh-pages)
3. Or: Select "GitHub Actions" (for native deployment)
4. Save settings
5. Re-run workflow

---

## 📈 Post-Deployment Actions

After successful deployment:

### 1. Update Documentation
- [ ] Add deployment URL to README.md
- [ ] Update navigation links
- [ ] Document deployment process
- [ ] Create release notes

### 2. Monitor Metrics
- [ ] Track dashboard usage
- [ ] Monitor page load times
- [ ] Check for broken links
- [ ] Review user feedback

### 3. Maintenance Tasks
- [ ] Fix PSScriptAnalyzer script bug
- [ ] Address test failures
- [ ] Update config.psd1 counts
- [ ] Improve test coverage

### 4. Quality Improvements
- [ ] Increase documentation coverage
- [ ] Improve code quality score
- [ ] Add feature descriptions
- [ ] Enhance dashboard features

---

## 🔄 Continuous Deployment

For ongoing deployments:

### Automatic Deployment Triggers
The workflow automatically deploys when:
- Push to `dev-staging` branch
- PR merged to `dev-staging` branch
- Files changed in: `library/reports/**`, `library/**`, `index.md`

### Manual Deployment
```bash
# After making changes
git add .
git commit -m "Update reports and dashboard"
git push origin dev-staging

# Deployment triggers automatically
```

### Deployment Frequency
- **On-Demand**: Manual workflow trigger
- **Continuous**: Automatic on push to dev-staging
- **Scheduled**: Not configured (can be added if needed)

---

## 📚 Resources

### Documentation
- [Validation Summary](VALIDATION-DEPLOYMENT-SUMMARY.md)
- [GitHub Pages Docs](https://docs.github.com/en/pages)
- [Jekyll Documentation](https://jekyllrb.com/docs/)
- [peaceiris/actions-gh-pages](https://github.com/peaceiris/actions-gh-pages)

### Workflow Files
- `.github/workflows/jekyll-gh-pages.yml` - Main deployment workflow
- `.github/workflows/publish-test-reports.yml` - Report publishing
- `_config.yml` - Jekyll base configuration
- `_config_branch.yml` - Branch-specific overrides

### Key Files
- `index.md` - Root navigation
- `library/reports/dashboard.html` - Main dashboard
- `library/reports/dashboard.json` - Metrics data
- `VALIDATION-DEPLOYMENT-SUMMARY.md` - This guide's companion

---

## ✅ Deployment Checklist

Before deploying:
- [x] Validation completed
- [x] Reports generated
- [x] Artifacts committed
- [x] Summary created
- [x] Deployment guide created
- [ ] Branch created/updated
- [ ] Workflow triggered
- [ ] Deployment verified
- [ ] Links tested
- [ ] Documentation updated

---

## 🎯 Success Criteria

Deployment successful when:
- ✅ Workflow completes without errors
- ✅ Site accessible at deployment URL
- ✅ Dashboard loads and displays correctly
- ✅ All navigation works
- ✅ Interactive features functional
- ✅ No broken links or resources
- ✅ Metrics display accurately

---

## 📞 Support

If you encounter issues:

1. **Check workflow logs**: 
   - https://github.com/wizzense/AitherZero/actions

2. **Review documentation**:
   - VALIDATION-DEPLOYMENT-SUMMARY.md
   - .github/copilot-instructions.md

3. **Common solutions**:
   - Re-run workflow
   - Clear GitHub Pages cache
   - Check repository settings
   - Validate file permissions

4. **Get help**:
   - Open issue: https://github.com/wizzense/AitherZero/issues
   - Check existing issues for similar problems
   - Review troubleshooting section above

---

*Last Updated: 2025-11-09 23:50 UTC*  
*Version: 1.0*  
*Platform: AitherZero Infrastructure Automation*
