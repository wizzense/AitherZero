# Workflow Coordination Guide

## Overview
This document describes how AitherZero's GitHub Actions workflows work together and how to prevent duplicate issue creation.

## Problem Fixed
Previously, multiple workflows were creating duplicate and useless issues due to:
- Aggressive scheduling (hourly, daily, every 4 hours)
- Multiple workflows triggering on the same events
- Weak deduplication logic
- No coordination between workflows

## Current Workflow Strategy

### Manual Trigger Only (workflow_dispatch)
All issue-creating workflows now require manual triggering to prevent spam:

1. **automated-copilot-agent.yml**
   - Purpose: Analyze code and create targeted issues for Copilot
   - Trigger: Manual only (workflow_dispatch)
   - Also responds to: issues (opened, labeled), PRs (opened, synchronize, closed)

2. **auto-create-issues-from-failures.yml**
   - Purpose: Create issues from test failures
   - Trigger: Manual only (workflow_dispatch)
   - Use when: CI shows test failures that need attention

3. **intelligent-report-analyzer.yml**
   - Purpose: Analyze comprehensive reports and create issues
   - Trigger: Manual only (workflow_dispatch)
   - Use when: Need deep analysis of accumulated technical debt

4. **ai-agent-coordinator.yml**
   - Purpose: Coordinate multiple AI agents
   - Trigger: Manual only (workflow_dispatch)
   - Also responds to: issues (opened, labeled, assigned), PRs

5. **auto-create-prs-for-issues.yml**
   - Purpose: Group related issues and create PRs
   - Trigger: issues (labeled)
   - Note: Runs when P1-P10 priority labels added to issues

6. **copilot-pr-automation.yml**
   - Purpose: Automate PR creation for assigned issues
   - Trigger: issues (assigned, labeled, commented), PRs
   - Note: Responds to issue/PR events, no schedule

7. **create-issues-now.yml**
   - Purpose: One-time issue creation from analysis
   - Trigger: Manual only (workflow_dispatch)

### Issue Cleanup

**close-auto-issues.yml**
- Purpose: Bulk close auto-created/automated issues
- Trigger: Manual only (workflow_dispatch)
- Use when: Need to clean up duplicate or obsolete issues
- Supports dry-run mode

## Workflow Relationships

```
Manual Analysis → Issue Creation → Issue Labeling → PR Creation → PR Review
       ↓                ↓                 ↓               ↓
  [Manual WF]    [Manual/Event]   [auto-create-prs] [copilot-pr]
```

### Recommended Usage Flow

1. **When CI fails:**
   - Review the failure in CI output
   - If real issues exist, manually trigger `auto-create-issues-from-failures.yml`

2. **For code quality issues:**
   - Manually trigger `automated-copilot-agent.yml` to analyze and create issues
   - Review created issues before proceeding

3. **To work on issues:**
   - Add P1-P10 priority labels to issues
   - `auto-create-prs-for-issues.yml` automatically groups and creates PRs
   - Or assign to yourself/Copilot to trigger PR creation

4. **For bulk cleanup:**
   - Use `close-auto-issues.yml` with dry-run first
   - Review the list of issues to be closed
   - Run again with dry-run=false to close them

## Label Conventions

### Issue Labels
- `auto-created` - Issues created by automated-copilot-agent
- `automated-issue` - Issues created by other automation workflows
- `needs-priority` - Issue needs P1-P10 label before processing
- `copilot-task` - Issue suitable for GitHub Copilot
- `P1` through `P10` - Priority levels (P1=highest, P10=lowest)

### Deduplication Strategy
Workflows check for existing issues by:
1. Matching title patterns (first 30 characters)
2. Matching label combinations
3. Checking issue state (open only)
4. Updating existing issues rather than creating duplicates

## Disabled Schedules (Previously Active)

These schedules were disabled to prevent duplicate issues:

- ❌ `automated-copilot-agent.yml`: Hourly 9am-5pm UTC, Mon-Fri
- ❌ `auto-create-issues-from-failures.yml`: Daily at 7am UTC
- ❌ `intelligent-report-analyzer.yml`: Daily at 6am UTC
- ❌ `ai-agent-coordinator.yml`: Daily at 2am UTC
- ❌ `auto-create-prs-for-issues.yml`: Every 4 hours
- ❌ `copilot-pr-automation.yml`: Every 4 hours, business days

## CI/CD Workflows (Not Issue-Creating)

These workflows run automatically and don't create issues:

- `intelligent-ci-orchestrator.yml` - Main CI pipeline
- `quality-validation.yml` - Code quality checks
- `pr-validation.yml` - PR validation
- `validate-config.yml` - Config validation
- `validate-manifests.yml` - Manifest validation
- `jekyll-gh-pages.yml` - Documentation deployment
- `publish-test-reports.yml` - Test report publishing
- `enhanced-cost-optimizer.yml` - Weekly cost optimization (safe schedule)

## Best Practices

1. **Before Creating Issues:**
   - Review existing open issues
   - Check if the problem is already reported
   - Consider if manual issue creation is more appropriate

2. **Manual Triggers:**
   - Use workflow_dispatch for controlled issue creation
   - Review the dry-run output when available
   - Clean up old issues before creating new ones

3. **Issue Management:**
   - Add priority labels promptly
   - Close duplicates immediately
   - Update existing issues rather than creating new ones

4. **Coordination:**
   - One workflow at a time for issue creation
   - Wait for PR creation before creating more issues
   - Use issue labels to track automated vs manual issues

## Troubleshooting

### Too Many Issues Created
1. Run `close-auto-issues.yml` with dry-run=true
2. Review what would be closed
3. Run with dry-run=false to clean up
4. Verify no schedules are re-enabled

### Issues Not Being Created
1. Check if workflow needs manual trigger
2. Verify labels are correct
3. Check workflow run logs
4. Ensure deduplication isn't preventing creation

### Duplicates Still Appearing
1. Check which workflow created them (see issue body)
2. Verify that workflow's schedule is disabled
3. Check if multiple workflows are responding to same event
4. Review deduplication logic in that workflow

## Future Improvements

Potential enhancements (not yet implemented):
- Global issue creation lock/semaphore
- Centralized deduplication service
- Issue creation rate limiting
- Automated duplicate detection and merging
- Better tracking of what's been processed
