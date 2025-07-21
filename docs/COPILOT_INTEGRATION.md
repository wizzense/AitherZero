# GitHub Copilot Integration Guide

## Overview

AitherZero now includes seamless integration with GitHub Copilot code reviews, allowing you to automatically apply AI-suggested improvements to your codebase using PatchManager's atomic operations.

## Features

- 🤖 **Automatic Detection**: Monitors PRs for Copilot review comments
- 🎯 **Smart Categorization**: Classifies suggestions by type and severity
- ⚡ **Atomic Operations**: Uses PatchManager for safe, reversible changes
- 🔒 **Security First**: Validates suggestions before applying
- 📊 **Audit Trail**: Full logging of all automated changes
- 🔄 **GitHub Actions**: Automated workflow for CI/CD integration

## Quick Start

### Manual Usage

```powershell
# Load the automation domain
. ./aither-core/domains/automation/Automation.ps1

# Monitor current PR interactively
Watch-CopilotReviews -Interactive

# Monitor specific PR with auto-apply for simple fixes
Watch-CopilotReviews -PRNumber 123 -AutoApply

# Apply all pending suggestions
New-CopilotFix -PRNumber 123 -All

# Apply specific suggestion
New-CopilotFix -SuggestionId "comment_12345"
```

### GitHub Actions

The Copilot integration workflow triggers automatically when:
- A bot comments on a PR
- You manually trigger the workflow
- A pull request review comment is created

Manual trigger:
```bash
gh workflow run copilot-integration.yml -f pr_number=123 -f auto_apply=true
```

## Functions Reference

### Watch-CopilotReviews

Monitors pull requests for GitHub Copilot review comments and suggestions.

```powershell
Watch-CopilotReviews [-PRNumber <int>] [-AutoApply] [-Interactive] [-Repository <string>]
```

**Parameters:**
- `-PRNumber`: PR number to monitor (optional, uses current branch if not specified)
- `-AutoApply`: Automatically apply simple code fixes without prompting
- `-Interactive`: Run in interactive mode with prompts for each suggestion
- `-Repository`: Repository in format "owner/repo" (optional, uses current repo)

**Examples:**
```powershell
# Interactive mode for current PR
Watch-CopilotReviews -Interactive

# Auto-apply simple fixes for PR #123
Watch-CopilotReviews -PRNumber 123 -AutoApply

# Monitor specific repository
Watch-CopilotReviews -Repository "wizzense/AitherZero" -PRNumber 456
```

### Parse-CopilotSuggestion

Parses a GitHub Copilot comment to extract actionable suggestions.

```powershell
Parse-CopilotSuggestion -Comment <object>
```

**Returns:** PSCustomObject with:
- `Id`: Comment ID
- `Type`: Security, Performance, SimpleFix, Refactor, or Unknown
- `Description`: Summary of the suggestion
- `CodeBlock`: Extracted code (if any)
- `Severity`: High, Medium, or Low
- `Path`: File path (if specified)
- `Line`: Line number (if specified)

### Apply-CopilotSuggestion

Applies a parsed Copilot suggestion using PatchManager atomic operations.

```powershell
Apply-CopilotSuggestion -Suggestion <PSCustomObject> [-DryRun]
```

**Parameters:**
- `-Suggestion`: Parsed suggestion object from Parse-CopilotSuggestion
- `-DryRun`: Preview changes without applying them

**Behavior:**
- Uses `New-QuickFix` for simple fixes
- Uses `New-Hotfix` for security issues
- Uses `New-Patch` for other changes
- Automatically creates descriptive commit messages
- Comments on PR when suggestion is applied

### New-CopilotFix

Wrapper function for applying Copilot suggestions using PatchManager.

```powershell
New-CopilotFix [-PRNumber <int>] [-SuggestionId <string>] [-All]
```

**Parameters:**
- `-PRNumber`: PR number containing suggestions
- `-SuggestionId`: Specific suggestion ID to apply
- `-All`: Apply all pending suggestions

**Examples:**
```powershell
# Interactive mode for PR
New-CopilotFix -PRNumber 123

# Apply all suggestions
New-CopilotFix -PRNumber 123 -All

# Apply specific suggestion
New-CopilotFix -SuggestionId "12345"
```

## Configuration

Configuration is stored in `configs/copilot-integration.json`:

```json
{
  "copilotIntegration": {
    "enabled": true,
    "autoApply": {
      "enabled": false,
      "simpleFixes": true,
      "requireApproval": true,
      "excludePatterns": ["*test*", "*mock*", "*.md"]
    },
    "suggestions": {
      "priorityLabels": ["security", "performance", "bug"],
      "typeMappings": {
        "security": {
          "keywords": ["security", "vulnerability", "risk"],
          "severity": "high",
          "autoApply": false
        },
        "simpleFix": {
          "keywords": ["typo", "spelling", "comment"],
          "severity": "low",
          "autoApply": true
        }
      }
    },
    "commit": {
      "prefix": "[Copilot]",
      "groupRelated": true,
      "maxChangesPerCommit": 5
    },
    "security": {
      "validateSuggestions": true,
      "allowedFilePatterns": ["*.ps1", "*.psm1", "*.json", "*.yml"],
      "blockedPatterns": ["*secrets*", "*credentials*", "*.key"]
    }
  }
}
```

## Security Considerations

1. **Validation**: All suggestions are validated before applying
2. **File Patterns**: Only allowed file types can be modified
3. **Blocked Patterns**: Sensitive files are protected from changes
4. **Manual Approval**: High-severity changes require explicit approval
5. **Audit Trail**: All actions are logged for compliance

## Workflow Integration

### Automatic Workflow

The `.github/workflows/copilot-integration.yml` workflow:
1. Triggers on bot comments
2. Checks out code
3. Loads AitherCore and domains
4. Processes suggestions
5. Runs validation tests
6. Reports results

### Manual Integration

```yaml
- name: Process Copilot Suggestions
  shell: pwsh
  run: |
    . ./aither-core/domains/automation/Automation.ps1
    Watch-CopilotReviews -PRNumber ${{ github.event.pull_request.number }} -AutoApply
```

## Best Practices

1. **Review First**: Always review suggestions before auto-applying
2. **Test Coverage**: Ensure tests cover code being modified
3. **Incremental Changes**: Apply suggestions incrementally
4. **Monitor Results**: Check CI/CD results after applying
5. **Security First**: Never auto-apply security-related changes

## Troubleshooting

### Common Issues

**Issue**: "No Copilot suggestions found"
- Ensure the PR has Copilot review comments
- Check that the bot user is correctly identified
- Verify GitHub API access

**Issue**: "Failed to apply suggestion"
- Check file permissions
- Ensure no merge conflicts
- Verify the suggestion syntax

**Issue**: "Module not found"
- Load the automation domain first
- Ensure you're in the project root
- Check PowerShell version (7.0+ required)

### Debug Mode

```powershell
# Enable verbose output
$VerbosePreference = "Continue"
Watch-CopilotReviews -PRNumber 123 -Verbose

# Dry run mode
Apply-CopilotSuggestion -Suggestion $suggestion -DryRun
```

## Examples

### Example 1: Interactive Review
```powershell
# Start interactive review
Watch-CopilotReviews -Interactive

# Output:
# Monitoring PR #123 in wizzense/AitherZero for Copilot suggestions...
# Found 3 Copilot suggestions
# 
# Copilot suggestion: Fix typo in comment
# Apply this suggestion? (Y/N): Y
# [Copilot] Fix typo in comment in src/example.ps1
# ✅ Applied Copilot suggestion: Fix typo in comment
```

### Example 2: Automated Simple Fixes
```powershell
# Auto-apply simple fixes only
Watch-CopilotReviews -PRNumber 456 -AutoApply

# Output:
# Found 5 Copilot suggestions
# Auto-applying simple fix: Fix typo
# Auto-applying simple fix: Update comment
# Suggestion available: Refactor function (not auto-applied)
# Suggestion available: Security fix (not auto-applied)
```

### Example 3: CI/CD Integration
```yaml
name: Process Copilot Reviews
on:
  pull_request_review_comment:
    types: [created]

jobs:
  process:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Process Suggestions
        run: |
          ./scripts/Process-CopilotSuggestions.ps1 -PRNumber ${{ github.event.pull_request.number }}
```

## Future Enhancements

- [ ] Machine learning for suggestion quality
- [ ] Custom organization rules
- [ ] Metrics dashboard
- [ ] IDE integration
- [ ] Batch processing improvements
- [ ] Advanced conflict resolution

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review logs in `tests/results/`
3. Open an issue with the `copilot-integration` label
4. Include relevant PR numbers and error messages