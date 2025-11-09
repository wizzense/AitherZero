# Automated Issue Tracking System

## Overview

AitherZero implements a comprehensive automated issue tracking system that detects failures, creates GitHub issues, and maintains them in an idempotent manner. This system ensures that issues are properly tracked without creating duplicates, and existing issues are updated with the latest information.

## Architecture

### Three-Tier Issue Creation System

#### 1. **Quality Validation Workflow** (`.github/workflows/quality-validation.yml`)
- **Trigger**: Pull requests and manual dispatch
- **Purpose**: Validates code quality of changed files
- **Issue Creation**: Creates issues for files that fail quality standards
- **Features**:
  - SHA256 fingerprint-based deduplication using file paths
  - Updates existing issues with new validation results
  - Links issues to PRs automatically
  - Non-blocking validation (allows PR merges)

#### 2. **Auto-Create Issues from Failures** (`.github/workflows/auto-create-issues-from-failures.yml`)
- **Trigger**: Manual dispatch (workflow_run triggers disabled to prevent duplicates)
- **Purpose**: Creates issues from test failures and code quality problems
- **Issue Creation**: Groups failures by file and creates/updates issues
- **Features**:
  - Updates existing issues instead of creating duplicates
  - Tracks failures over time
  - Provides actionable instructions for fixing

#### 3. **Phase 2 Intelligent Issue Creation** (`.github/workflows/phase2-intelligent-issue-creation.yml`)
- **Trigger**: Workflow completion, scheduled, manual dispatch
- **Purpose**: Comprehensive failure analysis across all failure types
- **Issue Creation**: AI-powered categorization and agent assignment
- **Features**:
  - Fingerprint-based deduplication using SHA256 hashes
  - Updates existing issues with new detection information
  - Automatic agent assignment based on failure type
  - Priority classification (p0, p1, p2)
  - Tracks:
    - Test failures
    - Syntax errors
    - Code quality issues
    - Security vulnerabilities
    - Workflow failures

## How Deduplication Works

### Fingerprinting Strategy

Each failure generates a unique fingerprint using SHA256 hashing:

```javascript
// Quality Validation - based on file path
const fingerprint = crypto.createHash('sha256')
  .update(file.FilePath.toLowerCase().replace(/\\/g, '/'))
  .digest('hex')
  .substring(0, 16);

// Phase 2 - based on failure characteristics
const normalizedData = JSON.stringify({
  type: failure.Type || failure.TestType || 'unknown',
  file: (failure.File || '').replace(/\\/g, '/').toLowerCase(),
  error: (failure.ErrorMessage || failure.Message || '').replace(/\d+/g, 'N').toLowerCase(),
  category: failure.Category || failure.RuleName || 'general'
});
const fingerprint = crypto.createHash('sha256')
  .update(normalizedData)
  .digest('hex')
  .substring(0, 16);
```

### Issue Tracking

Fingerprints are embedded in issue bodies as HTML comments:

```markdown
<!-- fingerprint:abc123def456 -->
```

When creating issues, workflows:
1. Query GitHub for existing open issues with matching labels
2. Check each issue body for fingerprint matches
3. If match found: Update issue with new detection comment
4. If no match: Create new issue with fingerprint embedded

## Issue Update Process

When an existing issue is found, workflows add an update comment:

```markdown
## 🔄 Updated Quality Validation Report

**Timestamp:** 2025-11-04T22:00:00Z
**Overall Score:** 75%
**Status:** Failed
**PR:** #123

### Detailed Findings
[Latest test/quality results]

### Workflow Context
- **Run ID:** [12345](link)
- **Latest PR:** #123

---
*This is an automated update. Issue remains open until quality standards are met.*
```

## Agent Assignment (Phase 2 Only)

Issues are automatically assigned to specialized AI agents based on failure characteristics:

| Agent | Expertise | Triggers |
|-------|-----------|----------|
| Maya Infrastructure | Hyper-V, VMs, networking | Files in `infrastructure/`, `vm/`, `network/` |
| Sarah Security | Certificates, credentials | Files in `security/`, errors containing "security" |
| Jessica Testing | Test infrastructure | Files in `tests/`, `.Tests.ps1`, Pester errors |
| Emma Frontend | UI/UX | Files in `experience/`, `ui/`, `menu/`, `wizard/` |
| Marcus Backend | PowerShell modules, APIs | `.psm1` files, `backend/` |
| Olivia Documentation | Technical writing | `.md` files, `docs/` |
| Rachel PowerShell | Scripting | Default for other PowerShell issues |

## Dashboard Integration

The automated issue system integrates with the comprehensive dashboard:

1. **Issue Creation**: Workflows create issues with detailed metadata
2. **Dashboard Generation**: Script `0512_Generate-Dashboard.ps1` collects metrics
3. **Publishing**: Workflow `publish-test-reports.yml` publishes to GitHub Pages
4. **Visibility**: Dashboard shows health scores, trends, and actionable items

Access the dashboard at: `https://wizzense.github.io/AitherZero/reports/dashboard.html`

## Manual Issue Management

### Closing Issues

Issues should be closed when:
- Underlying failure is fixed
- PR with fix is merged
- Tests pass consistently

Close issues with:
```bash
gh issue close <issue_number> --comment "Fixed in PR #<pr_number>"
```

### Purging Automated Issues

To reset the issue tracking system:

```bash
# List all automated issues
gh issue list --label "automated-issue" --state all

# Close all automated issues
gh issue list --label "automated-issue" --state open --json number --jq '.[].number' | \
  xargs -I {} gh issue close {}

# Archive closed issues (optional)
# Issues are automatically archived after 90 days of inactivity
```

### Manual Issue Creation

To manually create an issue with proper fingerprinting:

```bash
gh issue create \
  --title "Test Failure: MyTest" \
  --body "Failure details here\n\n<!-- fingerprint:manual-$(date +%s) -->" \
  --label "automated-issue,test-failure"
```

## Configuration

### Issue Labels

Standard labels used by the system:
- `automated-issue`: All automatically created issues
- `test-failure`: Test failures
- `code-quality`: Code quality issues
- `quality-validation`: Quality validation failures
- `syntax`: Syntax errors
- `security`: Security issues
- `p0`, `p1`, `p2`: Priority levels
- `agent-<name>`: Agent assignments (phase2 only)

### Workflow Triggers

Customize issue creation frequency by editing workflow triggers:

```yaml
# More frequent checks
on:
  schedule:
    - cron: '0 */4 * * *'  # Every 4 hours

# Less frequent checks
on:
  schedule:
    - cron: '0 3 * * *'    # Daily at 3 AM
```

## Best Practices

### For Developers

1. **Review Issues Regularly**: Check automated issues assigned to your areas
2. **Link PRs to Issues**: Use `Fixes #<issue>` in PR descriptions
3. **Don't Delete Issues**: Close them when fixed so history is preserved
4. **Update Stale Issues**: Add comments if working on a fix

### For Maintainers

1. **Monitor Dashboard**: Check dashboard weekly for trends
2. **Review High-Priority**: Focus on p0 and p1 issues first
3. **Clean Up Duplicates**: Rare, but if duplicates occur, close with comment pointing to canonical issue
4. **Adjust Thresholds**: Tune quality thresholds in workflows if too noisy

### For CI/CD

1. **Keep Workflows Updated**: Review workflow changes in PRs carefully
2. **Test Changes**: Use `dry_run: true` to preview issue creation
3. **Monitor Costs**: Issue creation uses GitHub API rate limits
4. **Backup Fingerprints**: Issue state artifacts retained for 90 days

## Troubleshooting

### Issues Not Being Created

1. Check workflow runs for errors
2. Verify GitHub permissions (issues: write)
3. Check if failure thresholds are met
4. Review workflow logs for API errors

### Duplicate Issues

1. Verify fingerprint logic is consistent
2. Check if multiple workflows are triggering simultaneously
3. Review issue query logic for label filtering
4. Consider disabling redundant workflows

### Missing Updates

1. Verify issue body contains fingerprint comment
2. Check GitHub API rate limits
3. Review workflow logs for update failures
4. Ensure issue is in "open" state

## Future Enhancements

Planned improvements:
- [ ] Auto-close issues when failures resolve
- [ ] Issue aging and staleness tracking
- [ ] Integration with GitHub Projects
- [ ] Slack/Teams notifications for critical issues
- [ ] ML-based failure prediction
- [ ] Issue clustering for related failures

## References

- [GitHub Issues API](https://docs.github.com/en/rest/issues)
- [GitHub Actions Script](https://github.com/actions/github-script)
- [Issue Deduplication Blog Post](https://github.blog/changelog/2021-03-19-create-issue-forms-beta/)
