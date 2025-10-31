# Automated Testing, Reporting, and Issue Creation Setup

## Overview

This document describes the automated testing, reporting, and issue creation infrastructure for AitherZero.

## Architecture

### 1. Continuous Testing Pipeline

The CI/CD pipeline automatically:
- Runs comprehensive tests on every PR and push to main/develop
- Generates detailed test reports and analysis
- Uploads reports as workflow artifacts
- Publishes reports to GitHub Pages
- Creates GitHub issues for test failures and code quality issues

### 2. GitHub Pages Dashboard

**URL:** `https://wizzense.github.io/AitherZero`

The GitHub Pages site provides:
- **Interactive Dashboard** - Real-time project metrics and status
- **Test Reports** - Detailed test execution results
- **Analysis Reports** - PSScriptAnalyzer code quality findings
- **Technical Debt Tracking** - Prioritized issues and improvements

### 3. Automated Issue Creation

When tests fail or code quality issues are detected, the system automatically:
1. Analyzes the failure patterns
2. Groups related failures by file/category
3. Creates or updates GitHub issues with:
   - Detailed failure information
   - File locations and line numbers
   - Instructions for @copilot to fix
   - Links to relevant workflow runs

Issues are labeled with:
- `automated-issue` - All auto-created issues
- `test-failure` - Test failures
- `code-quality` - PSScriptAnalyzer findings
- `p1`, `p2`, `p3` - Priority levels
- `bug` - For test failures

## Workflows

### Core CI Workflow: `intelligent-ci-orchestrator.yml`

**Triggers:**
- Push to main/develop branches
- Pull requests
- Manual workflow dispatch

**Jobs:**
1. **change-detection** - Determines what needs to run
2. **quick-validation** - Fast syntax checks
3. **core-validation** - PSScriptAnalyzer + project reports
4. **comprehensive-tests** - Full test suite (parallelized)
5. **security-validation** - Security scans (conditional)

**Artifacts:** Uploads test results and reports for downstream processing

### GitHub Pages: `jekyll-gh-pages.yml` & `publish-test-reports.yml`

**`jekyll-gh-pages.yml` Triggers:**
- Push to main/develop with changes to reports/, docs/, index.md
- Manual workflow dispatch

**`publish-test-reports.yml` Triggers:**
- After CI workflows complete
- Manual workflow dispatch

**Process:**
1. Collects test reports from CI artifacts
2. Organizes reports in `/reports` directory
3. Builds Jekyll site with all documentation and reports
4. Deploys to GitHub Pages

**Result:** All reports accessible at `https://wizzense.github.io/AitherZero`

### Issue Creation: `auto-create-issues-from-failures.yml`

**Triggers:**
- After CI workflows complete (especially on failure)
- Daily at 7 AM UTC (scheduled check)
- Manual workflow dispatch with dry-run option

**Process:**
1. **Analyze Test Failures:**
   - Downloads test artifacts from CI runs
   - Parses test reports (JSON format)
   - Extracts failure details (test name, error, location)

2. **Analyze Code Quality:**
   - Reviews PSScriptAnalyzer results
   - Identifies critical errors and high warning counts
   - Categorizes issues by severity

3. **Create/Update Issues:**
   - Groups failures by file for clarity
   - Checks for existing issues to avoid duplicates
   - Creates new issues or updates existing ones
   - Adds appropriate labels and priority
   - Includes @copilot instructions for fixes

**Dry Run Mode:** 
```bash
# Preview issues without creating them
gh workflow run auto-create-issues-from-failures.yml -f dry_run=true
```

### Report Analyzer: `intelligent-report-analyzer.yml`

**Triggers:**
- After CI workflows complete
- Daily at 6 AM UTC
- Manual workflow dispatch

**Process:**
- Analyzes comprehensive project reports
- Identifies optimization opportunities
- Creates strategic improvement issues
- Cleans up stale automated issues (30+ days old)

## Manual Testing

### Run Tests Locally

```powershell
# Run all unit tests
./automation-scripts/0402_Run-UnitTests.ps1

# Run specific test suite
./automation-scripts/0402_Run-UnitTests.ps1 -Path "./tests/unit/domains"

# Generate project report
./automation-scripts/0510_Generate-ProjectReport.ps1

# View dashboard
./automation-scripts/0511_Show-ProjectDashboard.ps1
```

### Trigger Workflows Manually

```bash
# Run CI pipeline
gh workflow run intelligent-ci-orchestrator.yml

# Publish reports to Pages
gh workflow run publish-test-reports.yml

# Create issues from current failures
gh workflow run auto-create-issues-from-failures.yml

# Preview issues (dry run)
gh workflow run auto-create-issues-from-failures.yml -f dry_run=true
```

## Viewing Reports

### GitHub Pages

Visit: `https://wizzense.github.io/AitherZero`

- Main dashboard with project metrics
- Links to all available reports
- Browsable report directory

### GitHub Actions

1. Go to **Actions** tab in repository
2. Click on a completed workflow run
3. Scroll to **Artifacts** section
4. Download report artifacts (e.g., `core-analysis-results`)

### Local Reports

Reports are generated in `/reports` directory:
- `dashboard.html` - Interactive HTML dashboard
- `TestReport-*.json` - Test execution results
- `psscriptanalyzer-*.json` - Code quality analysis
- `*.md` - Markdown reports and summaries

## Automated Issue Management

### Issue Lifecycle

1. **Creation:** Issue created when failure detected
2. **Updates:** Issue updated on subsequent failures with same pattern
3. **Resolution:** Close issue when tests pass
4. **Cleanup:** Auto-closed after 30 days of inactivity

### Issue Labels

- `automated-issue` - All auto-created issues
- `test-failure` - Failing tests
- `code-quality` - Code quality issues  
- `p0`, `p1`, `p2`, `p3` - Priority levels
- `auto-fixable` - Can be fixed automatically
- `needs-human-input` - Requires manual intervention
- `bug` - Defects and failures

### Finding Issues

```bash
# All automated issues
gh issue list --label "automated-issue"

# Test failures only
gh issue list --label "test-failure"

# High priority
gh issue list --label "p0,p1"

# Auto-fixable issues
gh issue list --label "auto-fixable"
```

## Configuration

### Jekyll Configuration

`_config.yml` controls:
- Site title and description
- Which files to include/exclude
- Theme and plugins
- URL structure

### Workflow Configuration

Edit workflows in `.github/workflows/` to:
- Change trigger conditions
- Adjust artifact retention
- Modify issue templates
- Update schedule times

## Troubleshooting

### No Reports on GitHub Pages

**Check:**
1. GitHub Pages is enabled in repository settings
2. Pages source is set to "GitHub Actions"
3. Jekyll workflow completed successfully
4. `_config.yml` and `index.md` exist in repository root

### Issues Not Being Created

**Check:**
1. Workflow has `issues: write` permission
2. Test artifacts were uploaded by CI
3. Test reports are in expected JSON format
4. Review workflow logs for errors

### Reports Not Uploading

**Check:**
1. CI workflow includes artifact upload steps
2. Path patterns match actual report locations
3. Reports are generated before upload step
4. Workflow has sufficient storage quota

## Future Enhancements

Potential improvements:
- AI-powered failure analysis and grouping
- Automatic PR creation for auto-fixable issues
- Trend analysis across multiple runs
- Performance regression detection
- Integration with external monitoring tools

## Support

For issues or questions:
1. Check workflow logs in GitHub Actions
2. Review this documentation
3. Check existing issues with `automated-issue` label
4. Create new issue with details of the problem
