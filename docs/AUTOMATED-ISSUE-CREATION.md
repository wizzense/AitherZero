# Automated Issue Creation System

## Overview

AitherZero includes an intelligent automated issue creation system that monitors test failures, code quality issues, and security vulnerabilities, automatically creating GitHub issues for problems that need attention.

## System Architecture

### Two Workflow Approaches

1. **Phase 2 - Intelligent Issue Creation** (`.github/workflows/phase2-intelligent-issue-creation.yml`)
   - **Status**: Active and recommended
   - **Features**: 
     - Comprehensive failure analysis across all categories
     - Intelligent deduplication using fingerprints
     - Automatic agent routing based on failure type
     - Rich context and metadata
     - Support for multiple report formats

2. **Auto-Create Issues from Test Failures** (`.github/workflows/auto-create-issues-from-failures.yml`)
   - **Status**: Disabled (automated triggers commented out)
   - **Reason**: Was creating duplicate issues
   - **Use**: Manual workflow_dispatch only

## How It Works

### Trigger Events

The Phase 2 workflow triggers on:

1. **Workflow Run Events**: After these workflows complete
   - "🧪 Comprehensive Test Execution"
   - "PR Validation"
   - "Quality Validation"

2. **Scheduled**: Daily at 3 AM UTC to catch missed failures

3. **Manual**: Via workflow_dispatch for testing

### Analysis Process

1. **Artifact Collection**
   - Downloads test artifacts from triggering workflow
   - Reads test reports from `./reports` and `./artifacts` directories
   - Searches for multiple report types: test results, syntax errors, code quality, security

2. **Failure Analysis**
   - **Test Failures**: Parses Pester test reports and extracts failed tests
   - **Syntax Errors**: Identifies PowerShell syntax issues
   - **Code Quality**: Analyzes PSScriptAnalyzer results
   - **Security Issues**: Checks for vulnerabilities
   - **Workflow Failures**: Detects failed workflow runs

3. **Intelligent Grouping**
   - Creates unique fingerprint for each failure type
   - Groups related failures together
   - Determines appropriate agent based on file type and error category

4. **Deduplication**
   - Queries existing open issues with `automated-issue` label
   - Checks fingerprint in issue body to avoid duplicates
   - Updates existing issues if they already exist

5. **Issue Creation**
   - Creates issues with rich context
   - Assigns to appropriate custom agent (@maya, @sarah, @jessica, etc.)
   - Adds relevant labels (automated-issue, category, priority, agent)
   - Includes workflow context, error details, and remediation steps

### Agent Assignment

Failures are automatically routed to specialized agents:

| Agent | Expertise | File Patterns |
|-------|-----------|---------------|
| **Maya Infrastructure** | Infrastructure, VMs, networking | `infrastructure/**`, `*vm*.ps1`, `*network*.ps1` |
| **Sarah Security** | Security, certificates, credentials | `security/**`, `*certificate*.ps1`, `*credential*.ps1` |
| **Jessica Testing** | Test infrastructure, Pester | `tests/**`, `*.Tests.ps1` |
| **Emma Frontend** | UI, menus, wizards | `experience/**`, `*ui*.ps1`, `*menu*.ps1` |
| **Marcus Backend** | PowerShell modules, APIs | `*.psm1`, `*api*.ps1` |
| **Olivia Documentation** | Documentation | `*.md`, `docs/**` |
| **Rachel PowerShell** | General PowerShell scripting | Default for other issues |

## Report Format Support

The system supports multiple test report formats:

### Standard Pester Format
```json
{
  "TestResults": {
    "Details": [
      {
        "Name": "Test Name",
        "ExpandedName": "Full.Test.Path",
        "Result": "Failed",
        "ErrorRecord": {
          "Exception": {
            "Message": "Detailed error message"
          },
          "ScriptStackTrace": "..."
        },
        "ScriptBlock": {
          "File": "/path/to/test.ps1",
          "StartPosition": {
            "Line": 42
          }
        },
        "Duration": "00:00:01.234"
      }
    ]
  }
}
```

### Simplified Format
```json
{
  "TestResults": {
    "Details": [
      {
        "Name": "Sample Test 1",
        "Result": "Failed",
        "Error": "Mock test failure for demonstration"
      }
    ]
  }
}
```

Both formats are supported with proper fallbacks.

## Recent Fixes (2025-11-02)

### 1. Workflow Event Conditionals
**Problem**: Incorrect conditional check `if: github.event.workflow_run`
**Fix**: Changed to `if: github.event_name == 'workflow_run'`
**Impact**: Ensures artifacts are only downloaded when actually available from workflow_run events

### 2. Error Message Parsing
**Problem**: Only checked for `ErrorRecord` field, missing `Error` field in simplified reports
**Fix**: Added fallback to check both `ErrorRecord` and `Error` fields
**Impact**: Error messages now properly captured from all report formats

### 3. Test Name Parsing
**Problem**: Only used `ExpandedName` which may not exist in all reports
**Fix**: Added fallback chain: `Name ?? ExpandedName ?? 'Unknown Test'`
**Impact**: Test names now consistently captured

## Usage

### Manual Trigger

To manually trigger issue creation:

```bash
# Via GitHub CLI
gh workflow run "Phase 2 - Intelligent Issue Creation" --ref main

# With dry run
gh workflow run "Phase 2 - Intelligent Issue Creation" --ref main -f dry_run=true
```

### Viewing Created Issues

```bash
# List all automated issues
gh issue list --label automated-issue

# List by category
gh issue list --label automated-issue --label test-failure
gh issue list --label automated-issue --label code-quality
gh issue list --label automated-issue --label security
```

### Closing Issues

Issues are automatically closed when:
1. Tests pass in subsequent runs
2. Code quality issues are resolved
3. Security vulnerabilities are fixed

Manual closing:
```bash
gh issue close <issue-number> --reason completed
```

## Configuration

### Environment Variables

- `ISSUE_STATE_DIR`: Directory for issue state tracking (default: `./reports/issue-state`)
- `AITHERZERO_CI`: Set to `true` in CI environments
- `AITHERZERO_NONINTERACTIVE`: Disables interactive prompts

### Permissions Required

```yaml
permissions:
  contents: read       # Read repository contents
  issues: write        # Create and update issues
  actions: read        # Read workflow artifacts
  checks: write        # Update check runs
  pull-requests: write # Comment on PRs
```

## Troubleshooting

### Issues Not Being Created

1. **Check workflow runs**: Verify the Phase 2 workflow is running
   ```bash
   gh run list --workflow="Phase 2 - Intelligent Issue Creation"
   ```

2. **Check for test failures**: Ensure there are actual failures to report
   ```bash
   gh run list --workflow="🧪 Comprehensive Test Execution" --status failure
   ```

3. **Check deduplication**: Existing issues prevent duplicates
   ```bash
   gh issue list --label automated-issue --state open
   ```

4. **Manual trigger for testing**: Use dry run to see what would be created
   ```bash
   gh workflow run "Phase 2 - Intelligent Issue Creation" -f dry_run=true
   ```

### Issues Not Being Assigned to Agents

- Agent mentions (e.g., @maya) are for GitHub Copilot custom agents
- They won't notify actual GitHub users
- Agents are defined in `.github/copilot.yaml`
- Used by GitHub Copilot for automatic task routing

### Duplicate Issues

If duplicates are being created:
1. Check fingerprint calculation in the workflow
2. Verify `automated-issue` label is being applied
3. Check issue body contains fingerprint comment: `<!-- fingerprint:xxxxx -->`

## Best Practices

1. **Review automated issues regularly**: Don't let them pile up
2. **Close resolved issues**: Help the system track what's been fixed
3. **Use manual triggers sparingly**: Let automatic triggers handle routine analysis
4. **Monitor workflow logs**: Check for analysis errors or parsing issues
5. **Keep report formats consistent**: Standardize on Pester output format

## Future Improvements

- [ ] Add support for more report formats (JUnit XML, NUnit, etc.)
- [ ] Implement auto-closing of issues when problems are resolved
- [ ] Add metrics and trends dashboard
- [ ] Support for custom agent assignment rules
- [ ] Integration with project boards
- [ ] Slack/Teams notifications for critical issues

## Related Documentation

- [GitHub Actions Workflows](../.github/workflows/)
- [Custom Agents Configuration](../.github/copilot.yaml)
- [Testing Guide](./TESTING.md)
- [Contributing Guide](./CONTRIBUTING.md)
