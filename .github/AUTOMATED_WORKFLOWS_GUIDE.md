# Automated Workflows Guide

This guide explains how to enable and use the automated issue creation and Copilot automation workflows in AitherZero.

## 🤖 Overview

AitherZero includes three automated workflows for continuous code quality and issue resolution:

1. **Automated Copilot Agent** - Automatically analyzes code, creates issues, and assigns them for resolution
2. **Copilot Issue Commenter** - Adds helpful guidance comments to auto-created issues
3. **Copilot PR Automation** - Monitors issues and can create automated fix PRs

## 🚀 Quick Start

### Initial Setup

Automated workflows require an initial manual run to activate their schedule triggers:

1. **Navigate to GitHub Actions** in your repository
2. **Run the workflows manually** for the first time:
   - Go to Actions → "🤖 Automated Copilot Agent - Iterative Issue Resolution" → Run workflow
   - Select `main` branch
   - Keep defaults or set `force_analyze: true`
   - Click "Run workflow"

3. **Verify the workflow ran successfully**:
   - Check the workflow run completed without errors
   - Look for created issues with label `auto-created`

### After Initial Run

Once run manually once, the workflows will automatically trigger on:

- **Every 2 hours** (automated-copilot-agent schedule)
- **Push events to main/develop** (automated-copilot-agent)
- **When CI completes** (automated-copilot-agent via workflow_run)
- **When issues are opened/labeled** (automated-copilot-agent)
- **Every 3 hours** (copilot-pr-automation schedule)

## 📋 Workflow Details

### 1. Automated Copilot Agent

**File**: `.github/workflows/automated-copilot-agent.yml`

**Purpose**: Analyzes repository for code quality issues and automatically creates GitHub issues.

**Triggers**:
- **Schedule**: Every 2 hours, 7 days/week
- **Push**: On pushes to main/develop branches
- **Workflow Run**: After Intelligent CI Orchestrator completes
- **Issues**: When issues are opened or labeled
- **Pull Requests**: When PRs are opened, synchronized, or closed
- **Manual**: Via workflow_dispatch

**What It Does**:
1. Runs ultra-fast PSScriptAnalyzer analysis (core files only)
2. Executes optimized Pester tests
3. Scans for security vulnerabilities
4. Creates GitHub issues for:
   - Critical PSScriptAnalyzer errors
   - Unit test failures
   - Security vulnerabilities
   - Repository health concerns

**Issue Labels Applied**:
- `auto-created` - Marks issues created by automation
- `copilot-task` - Indicates issue assigned for Copilot resolution
- `priority-critical`, `priority-high`, `priority-medium`, `priority-low` - Priority level
- `code-quality`, `testing`, `security`, `maintenance` - Category labels

### 2. Copilot Issue Commenter

**File**: `.github/workflows/copilot-issue-commenter.yml`

**Purpose**: Adds detailed guidance comments to newly created auto-issues.

**Triggers**:
- **Workflow Run**: After Automated Copilot Agent completes successfully
- **Manual**: Via workflow_dispatch with specific issue number

**What It Does**:
1. Finds recently created issues with `auto-created` label
2. Adds comprehensive comment with:
   - Task instructions and resolution process
   - Phase-by-phase guidance
   - Quick commands for analysis
   - Success criteria checklist

### 3. Copilot PR Automation

**File**: `.github/workflows/copilot-pr-automation.yml`

**Purpose**: Monitors copilot-assigned issues and can create automated fix PRs.

**Triggers**:
- **Schedule**: Every 3 hours, 7 days/week
- **Issues**: When issues are assigned, labeled, or commented on
- **Pull Requests**: When PRs are opened, synchronized, or closed
- **Manual**: Via workflow_dispatch with optional issue number

**What It Does**:
1. Scans for actionable issues with `copilot-task` label
2. For PSScriptAnalyzer issues: Applies automatic fixes
3. For test failures: Attempts to fix common parameter conflicts
4. For security issues: Adds appropriate suppressions for test files
5. Creates PR with fixes if changes are made
6. Monitors PR progress and can auto-merge safe changes

## 🔧 Configuration

### Adjusting Schedule Frequency

To change how often workflows run, edit the cron expressions:

**Automated Copilot Agent** (line 22):
```yaml
schedule:
  # Every 2 hours
  - cron: '0 */2 * * *'
  
  # Change to every hour:
  - cron: '0 * * * *'
  
  # Change to every 6 hours:
  - cron: '0 */6 * * *'
```

**Copilot PR Automation** (line 12):
```yaml
schedule:
  # Every 3 hours
  - cron: '0 */3 * * *'
```

### Enabling/Disabling Workflows

To temporarily disable a workflow without deleting it:

1. Edit the workflow file
2. Comment out the triggers you want to disable:
   ```yaml
   on:
     # schedule:
     #   - cron: '0 */2 * * *'
     workflow_dispatch: # Keep manual trigger
   ```

### Adjusting Analysis Scope

The Automated Copilot Agent uses "ultra-fast" mode by default (analyzes only core files). To change:

Edit `.github/workflows/automated-copilot-agent.yml`, line 92-99:
```yaml
# Add more files to analyze
$coreFiles = @(
  './Start-AitherZero.ps1'
  './AitherZero.psm1'  # Add this
  './bootstrap.ps1'    # Add this
) | Where-Object { Test-Path $_ }
```

## 🧪 Testing

### Manual Testing

1. **Test Issue Creation**:
   ```bash
   # Go to Actions → Automated Copilot Agent
   # Click "Run workflow"
   # Set force_analyze: true
   # Click "Run workflow"
   ```

2. **Test PR Creation**:
   ```bash
   # Create a test issue with label: copilot-task
   # Go to Actions → Copilot PR Automation
   # Click "Run workflow"
   # Enter the issue number
   # Set force_pr_creation: true
   # Click "Run workflow"
   ```

3. **Test Issue Commenting**:
   ```bash
   # After creating an auto-issue
   # Go to Actions → Copilot Issue Commenter
   # Click "Run workflow"
   # Enter the issue number
   # Click "Run workflow"
   ```

### Validation Commands

After workflows run, validate with:

```powershell
# Initialize environment
./Initialize-AitherEnvironment.ps1

# Run analysis locally
./automation-scripts/0404_Run-PSScriptAnalyzer.ps1  # Code analysis
./automation-scripts/0402_Run-UnitTests.ps1         # Unit tests
./automation-scripts/0407_Validate-Syntax.ps1       # Syntax validation
```

## 🔍 Monitoring

### View Workflow Runs

- GitHub → Actions → Select workflow → View recent runs
- Check for errors or failures
- Review workflow logs for debugging

### View Created Issues

- GitHub → Issues → Filter by label: `auto-created`
- Sort by newest first
- Check for duplicates (workflow includes deduplication)

### View Automated PRs

- GitHub → Pull Requests → Filter by label: `automated-fix`
- Review changes before merging
- Check for `copilot-generated` label

## 📊 Expected Behavior

### Normal Operation

When working correctly, you should see:

1. **Issues created every 2 hours** if code quality issues are detected
2. **Comments added to issues** shortly after creation (via workflow_run trigger)
3. **PRs created for stale issues** (>2 hours old with no PR)
4. **Issues closed automatically** when fix PRs are merged

### What Gets Created

The automation will create issues for:

- ✅ **PSScriptAnalyzer Critical Errors** (priority: critical)
- ✅ **Unit Test Failures** (priority: high)
- ✅ **Security Vulnerabilities** (priority: high)
- ✅ **Repository Health Issues** (priority: medium)

It will NOT create issues for:

- ❌ Documentation-only changes
- ❌ Minor warnings (unless configured differently)
- ❌ Issues that already exist (deduplication logic)

## 🛠️ Troubleshooting

### Issues Not Being Created

1. **Check workflow is enabled**:
   - GitHub → Settings → Actions → General
   - Ensure "Allow all actions and reusable workflows" is selected

2. **Check permissions**:
   - Workflow needs: `contents: write`, `issues: write`, `pull-requests: write`
   - These are configured in the workflow files

3. **Check schedule trigger activated**:
   - Run workflow manually once to activate schedule
   - Wait for next scheduled run (check Actions tab)

4. **Check for analysis results**:
   - View workflow logs
   - Look for "Analysis complete" section
   - Verify critical issues were detected

### PRs Not Being Created

1. **Check for actionable issues**:
   - Issues must have `copilot-task` label
   - Issues must be >2 hours old (or use force_pr_creation)
   - Issues must be open

2. **Check workflow logs**:
   - Look for "Found X actionable issues"
   - Check for branch creation errors
   - Verify git push succeeded

3. **Check branch protection**:
   - Ensure workflow has permission to push branches
   - Check repository settings for branch protection rules

### Comments Not Being Added

1. **Check workflow_run trigger**:
   - Copilot Issue Commenter triggers after Automated Copilot Agent
   - Verify both workflows completed successfully

2. **Check issue age**:
   - Only comments on issues created within the last hour
   - Use manual trigger for older issues

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax Reference](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)
- [AitherZero Workflow Optimization Summary](.github/WORKFLOW_OPTIMIZATION_SUMMARY.md)
- [CI/CD Optimization Strategy](.github/CI_CD_OPTIMIZATION_STRATEGY.md)

## 🤝 Contributing

To improve the automated workflows:

1. Test changes in a feature branch
2. Use workflow_dispatch for manual testing
3. Monitor workflow runs and logs
4. Update this guide with new features or changes
5. Submit PR with improvements

---

**Last Updated**: 2025-10-27  
**Maintained by**: AitherZero Team
