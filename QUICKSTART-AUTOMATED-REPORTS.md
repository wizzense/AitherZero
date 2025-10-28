# Quick Start: Automated Testing & Reporting

## What Was Added

This PR adds comprehensive automated testing, reporting, and issue creation infrastructure.

## 🚀 Quick Actions

### View Test Reports & Dashboard

**Option 1: GitHub Pages (Once Deployed)**
```
URL: https://wizzense.github.io/AitherZero
```

**Option 2: Manual Deployment**
```bash
# Trigger GitHub Pages build
gh workflow run jekyll-gh-pages.yml
```

### Create Issues from Test Failures

**Automatic:** Issues are created automatically when CI detects failures

**Manual:**
```bash
# Create issues now
gh workflow run auto-create-issues-from-failures.yml

# Preview without creating (dry run)
gh workflow run auto-create-issues-from-failures.yml -f dry_run=true
```

### Publish Latest Reports

```bash
# Collect and publish all reports to GitHub Pages
gh workflow run publish-test-reports.yml
```

### View Created Issues

```bash
# All automated issues
gh issue list --label "automated-issue"

# Test failures only
gh issue list --label "test-failure"

# High priority issues
gh issue list --label "p0,p1"
```

## 📊 What You Get

### 1. GitHub Pages Dashboard
- Interactive project dashboard at `https://wizzense.github.io/AitherZero`
- Live test reports and metrics
- Code quality analysis results
- Technical debt tracking

### 2. Automated Issue Creation
- **Test Failures** → GitHub issues with error details
- **Code Quality Problems** → Issues with PSScriptAnalyzer findings
- **Auto-updates** → Existing issues updated on new failures
- **@copilot Integration** → Issues include fix instructions for AI

### 3. Comprehensive Reports
- Test execution results (JSON)
- PSScriptAnalyzer code quality
- Project health dashboard (HTML)
- All accessible via GitHub Pages or workflow artifacts

## 🔄 Workflow Triggers

All workflows trigger automatically:

| Workflow | Trigger |
|----------|---------|
| **Issue Creation** | After CI completes, Daily at 7 AM UTC |
| **Publish Reports** | After CI completes, Push to main/develop |
| **Jekyll Pages** | Push to main/develop (reports/docs changes) |

## 📁 Files Added

### Configuration
- `index.md` - GitHub Pages homepage
- `_config.yml` - Jekyll configuration
- `.gitignore` - Updated with Jekyll exclusions

### Workflows
- `.github/workflows/auto-create-issues-from-failures.yml` - Issue creator (393 lines)
- `.github/workflows/publish-test-reports.yml` - Report publisher (138 lines)
- `.github/workflows/jekyll-gh-pages.yml` - Enhanced Pages deployment

### Documentation
- `docs/AUTOMATED-TESTING-REPORTING.md` - Complete guide (200+ lines)
- `QUICKSTART-AUTOMATED-REPORTS.md` - This file

### CI Integration
- Updated `intelligent-ci-orchestrator.yml` - Added reports/ to artifacts

## 🎯 Current Status

### ✅ Ready to Use
- All workflows are syntactically valid
- Logic tested with actual report files (500+ failures detected)
- Report parsing matches actual structure
- Issue templates ready
- Documentation complete

### ⏳ Waiting For
- CI run to generate fresh artifacts
- Jekyll deployment to GitHub Pages
- First automated issue creation

## 🧪 Testing

### Test Issue Creation Logic
```bash
# Check if reports exist and can be parsed
pwsh -Command "
  \$reports = Get-ChildItem ./reports -Filter 'TestReport*.json'
  foreach (\$r in \$reports) {
    \$data = Get-Content \$r.FullName | ConvertFrom-Json
    if (\$data.TestResults.Summary.Failed -gt 0) {
      Write-Host \"Found \$(\$data.TestResults.Summary.Failed) failures in \$(\$r.Name)\"
    }
  }
"
```

### Test Report Upload
```bash
# Run tests and check artifacts are created
pwsh ./automation-scripts/0402_Run-UnitTests.ps1 -NoCoverage
ls -la reports/TestReport*.json
```

### Test Jekyll Build Locally
```bash
# Install Jekyll (if not installed)
gem install jekyll bundler

# Build site
jekyll build

# Serve locally
jekyll serve
# Visit http://localhost:4000
```

## 🔍 Monitoring

### Check Workflow Status
```bash
# List recent workflow runs
gh run list --limit 10

# View specific workflow
gh run view <run-id>

# Download artifacts
gh run download <run-id>
```

### Check Issues Created
```bash
# Issues created in last 7 days
gh issue list --label "automated-issue" --state open --limit 50

# View specific issue
gh issue view <issue-number>
```

## 📚 Full Documentation

For detailed information, see:
- `docs/AUTOMATED-TESTING-REPORTING.md` - Complete architecture and usage guide

## 🆘 Troubleshooting

### No Reports on GitHub Pages
1. Check if Jekyll workflow ran successfully
2. Verify GitHub Pages is enabled (Settings → Pages → Source: GitHub Actions)
3. Check `_config.yml` and `index.md` are committed

### Issues Not Created
1. Check workflow logs for errors
2. Verify `issues: write` permission in workflow
3. Ensure test artifacts were uploaded by CI
4. Try dry-run mode: `gh workflow run auto-create-issues-from-failures.yml -f dry_run=true`

### Reports Not Found
1. Verify CI completed and uploaded artifacts
2. Check artifact names match workflow expectations
3. Review CI workflow logs for upload steps

## 💡 Tips

- Use **dry-run mode** to preview issues before creating them
- Check the **reports/** directory locally to see what will be published
- **Labels** help filter issues: `automated-issue`, `test-failure`, `p0-p3`
- Issues include **workflow run links** for debugging
- Old issues are **auto-closed** after 30 days of inactivity

## Next Steps

1. **Wait for CI** to run and generate fresh reports
2. **Check GitHub Pages** deployment after next push to main
3. **Review created issues** with `automated-issue` label
4. **Monitor dashboard** at GitHub Pages URL
5. **Let @copilot fix** issues automatically using the generated instructions

---

**Questions?** See `docs/AUTOMATED-TESTING-REPORTING.md` for complete documentation.
