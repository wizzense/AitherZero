# GitHub PR and Issue Auto-Closing Guide

## Overview

This document explains how the OpenTofu Lab Automation project's PatchManager now properly links GitHub issues to pull requests for automatic closure when PRs are merged.

## How It Works

### Issue and PR Creation Process

1. **Issue Creation First**: When `CreateIssue = $true`, PatchManager creates a GitHub issue first
2. **PR Creation with Linking**: When `CreatePullRequest = $true`, PatchManager creates a PR that includes the proper GitHub auto-closing keywords
3. **Automatic Closure**: When the PR is merged, GitHub automatically closes the linked issue

### GitHub Auto-Closing Keywords

The PR body now includes a "Related Issue" section with the proper GitHub keyword:

```markdown
### Related Issue
Closes #123
```

GitHub recognizes these keywords and automatically closes the referenced issue when the PR is merged:

- `Closes #123`
- `Fixes #123`
- `Resolves #123`

## Configuration

### Enhanced PatchManager Parameters

```powershell
$params = @{
    PatchDescription = "Your patch description"
    CreateIssue = $true           # Creates GitHub issue first
    CreatePullRequest = $true     # Creates PR with issue reference
    AutoValidate = $false         # Skip validation if needed
    Force = $true                 # Bypass validation issues
    DryRun = $false              # Set to true for testing
}

Invoke-EnhancedPatchManager @params
```

### Testing the Workflow

Use the included test scripts to validate the functionality:

```powershell
# Dry run test
.\test-force-issue-pr-linking.ps1 -DryRun

# Live test (creates actual issue and PR)
.\test-force-issue-pr-linking.ps1
```

## Merge Conflict Resolution

### Understanding Merge Conflicts

Merge conflicts occur when:

- Multiple people edit the same lines in a file
- Git cannot automatically merge changes
- Manual intervention is required

### Checking for Conflicts

```powershell
# Check current git status
git status

# Look for files marked as "both modified"
git diff --name-only --diff-filter=U
```

### Resolving Conflicts

1. **Identify Conflict Markers**: Look for these markers in files:

   ```text
   <<<<<<< HEAD
   Your changes
   =======
   Incoming changes
   >>>>>>> branch-name
   ```

2. **Choose the Correct Content**:
   - Keep your changes: Remove markers, keep content above `=======`
   - Keep incoming changes: Remove markers, keep content below `=======`
   - Merge both: Manually combine the changes appropriately

3. **Mark as Resolved**: After editing:

   ```powershell
   git add filename.ps1
   ```

4. **Complete the Merge**:

   ```powershell
   git commit -m "Resolve merge conflict in filename.ps1"
   ```

### Automated Conflict Resolution

PatchManager includes automated conflict resolution for common scenarios:

```powershell
# Resolve conflicts automatically where possible
Invoke-EnhancedGitOperations -ConflictResolution "Auto"

# Manual resolution with guidance
Invoke-EnhancedGitOperations -ConflictResolution "Interactive"
```

## Best Practices

### Branch Management

1. **Create Feature Branches**: Always work on feature branches, not main
2. **Keep Branches Small**: Smaller changes reduce conflict likelihood
3. **Sync Frequently**: Pull from main regularly to stay current

### PR and Issue Workflow

1. **One Issue Per PR**: Link each PR to exactly one issue for clean tracking
2. **Descriptive Titles**: Use clear, descriptive titles for both issues and PRs
3. **Complete Descriptions**: Include full context in issue and PR descriptions

### Conflict Prevention

1. **Coordinate Changes**: Communicate with team about file modifications
2. **Update Before Starting**: Always `git pull` before starting new work
3. **Small Commits**: Make frequent, small commits to reduce conflict scope

## Troubleshooting

### Common Issues

1. **"No merge to abort"**: No active merge conflict, check `git status`
2. **"MERGE_HEAD missing"**: No merge in progress, conflicts already resolved
3. **PR not auto-closing issue**: Check PR body contains `Closes #issue_number`

### Debug Commands

```powershell
# Check current branch and status
git branch --show-current
git status

# View recent commits
git log --oneline -10

# Check remote status
git remote -v
git fetch origin
```

### Getting Help

1. **Check Logs**: PatchManager logs all operations with detailed context
2. **Use Dry Run**: Test changes with `-DryRun` first
3. **Force When Needed**: Use `-Force` to bypass validation issues during testing

## Example Workflow

```powershell
# 1. Create issue and PR with auto-linking
$result = Invoke-EnhancedPatchManager -PatchDescription "Fix critical bug" -CreateIssue -CreatePullRequest -Force

# 2. Check results
Write-Host "Issue: $($result.IssueUrl)"
Write-Host "PR: $($result.PullRequestUrl)"

# 3. Verify PR contains "Closes #X" in body
# 4. When PR is merged, issue will automatically close
```

## Migration from Old Workflow

If you have existing PRs without proper issue linking:

1. **Edit PR Body**: Add `Closes #issue_number` to existing PRs
2. **Link Manually**: Use "Development" section in GitHub to link issues
3. **Update Workflow**: Use new PatchManager features for future work

---

**Last Updated**: June 19, 2025
**Version**: PatchManager v2.0 Enhanced
