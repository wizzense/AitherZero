# Phase 2: Intelligent Automated Issue Creation System

## Overview

Phase 2 builds on Phase 1's comprehensive test reporting infrastructure to create an intelligent automated issue creation system that captures ALL failure types from CI/CD workflows and creates well-organized, deduplicated issues with automatic agent assignment.

## Features

### 1. Comprehensive Failure Capture

The system captures all types of failures from CI/CD workflows:

- **Test Failures**: Pester unit and integration test failures with full error context
- **Syntax Errors**: PowerShell syntax errors with file and line information
- **Code Quality Issues**: PSScriptAnalyzer violations grouped by file and severity
- **Security Issues**: Security vulnerabilities and credential/certificate problems
- **Performance Issues**: Performance degradation and bottlenecks
- **Workflow Failures**: Failed CI/CD workflow runs with context

### 2. Intelligent Deduplication

**Fingerprint-Based Deduplication:**
- Creates unique fingerprints for each failure using normalized data
- Fingerprints normalize paths, error messages, and timestamps
- Persistent state tracking prevents duplicate issues across workflow runs
- Checks existing open issues before creating new ones

**Normalization Rules:**
- File paths: Convert to forward slashes, lowercase
- Error messages: Replace numbers with 'N', lowercase
- Timestamps: Completely removed from fingerprint
- GUIDs: Replaced with placeholder

### 3. Intelligent Agent Routing

Issues are automatically assigned to specialized Copilot agents based on:

- **File patterns**: Matches against `.github/copilot.yaml` patterns
- **Error content**: Analyzes error messages for keywords
- **Failure category**: Routes by test/syntax/security/etc.

**Agent Mapping:**
- `@maya` - Infrastructure issues (VMs, networks, Hyper-V, OpenTofu)
- `@sarah` - Security issues (certificates, credentials, vulnerabilities)
- `@jessica` - Testing issues (Pester, test infrastructure)
- `@emma` - UI/UX issues (menus, wizards, console interface)
- `@marcus` - Backend issues (PowerShell modules, APIs, performance)
- `@olivia` - Documentation issues (markdown files, guides)
- `@rachel` - PowerShell issues (general scripting, automation)

### 4. Rich Issue Context

Each created issue includes:

**Failure Details:**
- Error message and stack trace
- File path and line number
- Failure category and priority

**Workflow Context:**
- Link to failed workflow run
- Run ID and conclusion
- Timestamp and actor

**Agent Assignment:**
- Assigned agent with expertise area
- Recommended actions checklist
- Priority level (p0/p1/p2/p3)

**Actionable Guidance:**
- Suggested remediation steps
- Code snippets when applicable
- Links to related documentation

### 5. Priority System

**p0 - Critical** (Security issues)
- Security vulnerabilities
- Credential/certificate failures
- Immediate action required

**p1 - High** (Syntax errors, critical test failures)
- PowerShell syntax errors
- Failing unit tests
- Build-blocking issues

**p2 - Medium** (Code quality, non-critical tests)
- PSScriptAnalyzer violations
- Integration test failures
- Performance degradation

**p3 - Low** (Warnings, minor issues)
- Style warnings
- Documentation gaps
- Minor code smells

### 6. Auto-Closure Support

Issues can be automatically closed when:
- PR is created that references the issue with `Fixes #ISSUE_NUMBER` or `Closes #ISSUE_NUMBER`
- All tests pass in subsequent runs
- Issue fingerprint no longer appears in failure analysis

## Workflow Architecture

### Trigger Events

The Phase 2 workflow triggers on:

1. **workflow_run**: After these workflows complete:
   - `🧪 Comprehensive Test Execution`
   - `✅ PR Validation`
   - `🔍 Quality Validation`

2. **schedule**: Daily at 3 AM UTC to catch missed failures

3. **workflow_dispatch**: Manual trigger with options:
   - `dry_run`: Preview issues without creating them
   - `force_analysis`: Re-analyze even if no new failures

### Jobs

#### Job 1: Comprehensive Failure Analysis
- Downloads workflow artifacts from triggered workflows
- Parses test reports, syntax checks, quality analysis, security scans
- Categorizes all failures by type
- Saves comprehensive analysis to artifact

#### Job 2: Intelligent Issue Grouping & Deduplication
- Loads failure analysis
- Creates fingerprints for each unique failure
- Checks against existing open issues
- Determines appropriate agent for each issue
- Groups similar failures together
- Saves issue groups to artifact

#### Job 3: Create Intelligent Issues
- Loads issue groups
- Creates GitHub issues with rich context
- Assigns to appropriate Copilot agents
- Updates persistent issue state database
- Uploads updated state for future runs

#### Job 4: Dry Run Preview (Optional)
- Displays what issues would be created
- Shows agent assignments and priorities
- Useful for validating changes to grouping logic

## Usage

### Automatic Operation

Phase 2 runs automatically after configured workflows complete. No manual intervention needed.

### Manual Trigger

**Preview issues without creating them:**
```bash
# Via GitHub UI
Actions → Phase 2: Intelligent Issue Creation → Run workflow
  dry_run: true
```

**Create issues manually:**
```bash
# Via GitHub UI
Actions → Phase 2: Intelligent Issue Creation → Run workflow
  dry_run: false
```

**Force re-analysis:**
```bash
# Via GitHub UI
Actions → Phase 2: Intelligent Issue Creation → Run workflow
  force_analysis: true
```

### Local Testing

Test the analysis logic locally:

```powershell
# Run comprehensive tests to generate failures
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-phase1-production

# Check generated reports
Get-ChildItem ./reports -Filter "TestReport*.json" -Recurse
```

## Integration with Phase 1

Phase 2 depends on Phase 1's test execution and reporting infrastructure:

**Phase 1 provides:**
- Comprehensive test execution (all 290 test files)
- Standardized TestReport-*.json format
- PSScriptAnalyzer results
- Syntax validation results
- Test result artifacts

**Phase 2 consumes:**
- TestReport files from Phase 1 workflows
- PSScriptAnalyzer reports
- Syntax validation reports
- Workflow run metadata

## Dashboard Integration

Phase 2 results integrate with the AitherZero dashboard:

**Issue State Database:**
- Stored in `reports/issue-state/issue-fingerprints.json`
- Persisted across workflow runs via artifacts
- Tracks all created issue fingerprints
- Prevents duplicate issue creation

**Dashboard Consumption:**
- Dashboard script (0512) can read issue state
- Display issue creation trends
- Show agent assignment statistics
- Track issue resolution rates

## Configuration

### Customizing Agent Routing

Edit `.github/copilot.yaml` to customize agent routing:

```yaml
agents:
  my-new-agent:
    name: "Agent Name"
    description: "Agent description"
    file: ".github/agents/my-agent.md"
    expertise:
      - area1
      - area2
    file_patterns:
      - "path/to/files/**/*"
    keywords:
      - "keyword1"
      - "keyword2"
    labels:
      - label1
```

### Customizing Priority Levels

Edit `phase2-intelligent-issue-creation.yml` in the grouping step:

```yaml
priority: category === 'Security' ? 'p0' : 
          category === 'Syntax' ? 'p1' : 
          category === 'Tests' && failure.Critical ? 'p1' : 'p2'
```

### Customizing Deduplication

Edit the `createFingerprint` function in the grouping job:

```javascript
function createFingerprint(failure) {
  const normalizedData = JSON.stringify({
    type: failure.Type || failure.TestType || 'unknown',
    file: (failure.File || '').replace(/\\/g, '/').toLowerCase(),
    error: (failure.ErrorMessage || failure.Message || '').replace(/\d+/g, 'N').toLowerCase(),
    category: failure.Category || failure.RuleName || 'general'
    // Add custom normalization here
  });
  
  return crypto.createHash('sha256').update(normalizedData).digest('hex').substring(0, 16);
}
```

## Monitoring & Troubleshooting

### Check Workflow Runs

View Phase 2 execution history:
```
GitHub → Actions → Phase 2: Intelligent Issue Creation
```

### Review Analysis Results

Download analysis artifacts:
```bash
# Via GitHub UI
Actions → Workflow Run → Artifacts → comprehensive-failure-analysis
```

### Check Issue State

View persistent state:
```bash
# Via GitHub UI
Actions → Workflow Run → Artifacts → issue-state-db
```

### Common Issues

**No issues created despite failures:**
- Check if issues already exist for those fingerprints
- Verify workflow triggers are configured correctly
- Check artifact upload/download steps succeeded

**Duplicate issues created:**
- Check issue state database is being persisted correctly
- Verify fingerprint function is normalizing correctly
- Review existing issue search logic

**Wrong agent assigned:**
- Check file pattern matching in `.github/copilot.yaml`
- Verify `determineAgent` function logic
- Add more specific patterns for better matching

## Future Enhancements

Potential Phase 3 features:

1. **Auto-PR Creation**: Automatically create PRs for simple fixes
2. **Issue Clustering**: Group related issues together
3. **Trend Analysis**: Identify patterns in failures over time
4. **Smart Suggestions**: ML-based fix recommendations
5. **Cross-Repo Learning**: Learn from fixes in other repos
6. **Performance Tracking**: Track issue resolution time by agent
7. **Auto-Closure**: Close issues when tests pass in subsequent runs
8. **Notification System**: Notify agents when assigned

## Testing

Phase 2 includes comprehensive testing support:

**Dry Run Mode:**
```bash
# Preview what issues would be created
Actions → Run workflow → dry_run: true
```

**Local Validation:**
```powershell
# Generate test failures
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-comprehensive

# Check reports
Get-ChildItem ./reports -Recurse -Filter "*.json"
```

## Security Considerations

- **No secrets in issues**: Error messages sanitized to remove sensitive data
- **Controlled access**: Only workflows with proper permissions can create issues
- **Fingerprint privacy**: Fingerprints use hash, not raw data
- **State persistence**: Issue state stored securely in artifacts

## Performance

**Execution Time:**
- Analysis: ~30-60 seconds
- Grouping: ~15-30 seconds
- Issue creation: ~5-10 seconds per issue
- Total: Typically < 3 minutes for 10-20 issues

**Resource Usage:**
- Minimal GitHub Actions minutes
- Artifact storage: ~1-5 MB per run
- API calls: 1-2 per issue created

## Conclusion

Phase 2 provides intelligent, automated issue creation that:
- ✅ Captures ALL failure types
- ✅ Prevents duplicate issues
- ✅ Routes to appropriate agents
- ✅ Provides rich context
- ✅ Integrates with dashboard
- ✅ Supports auto-closure

This creates a seamless workflow from failure detection to automated remediation.
