# PatchManager Auto-Cleanup Feature Guide

## Overview

PatchManager v2.1 now includes intelligent post-merge cleanup functionality that automatically switches back to the main branch and deletes patch branches when PRs are merged. This eliminates the manual step of cleaning up after successful PR merges.

## Key Features

### 🔄 Automatic Branch Cleanup
- Monitors PRs for merge completion
- Automatically switches back to main branch
- Pulls latest changes from origin
- Deletes the local patch branch
- Provides completion notifications

### 🎯 Smart Monitoring
- Background job monitoring (non-blocking)
- Configurable check intervals
- Timeout protection
- Merge validation before cleanup
- Graceful failure handling

### 🚀 Seamless Integration
- Built into the main `Invoke-PatchWorkflow` function
- Optional feature (enabled with `-AutoCleanup`)
- Works with all PR types (standard and cross-fork)
- Compatible with existing workflows

## Usage Examples

### Basic Auto-Cleanup
```powershell
Invoke-PatchWorkflow -PatchDescription "Fix module loading issue" -CreatePR -AutoCleanup -PatchOperation {
    # Your changes here
    $content = Get-Content "module.ps1" -Raw
    $content = $content -replace "old pattern", "new pattern"
    Set-Content "module.ps1" -Value $content
}
```
**Result**: Creates PR, switches to main branch, starts background monitoring for merge completion.

### Custom Monitoring Settings
```powershell
Invoke-PatchWorkflow -PatchDescription "Quick fix with faster monitoring" -CreatePR -AutoCleanup `
    -CleanupCheckIntervalSeconds 15 -CleanupTimeoutMinutes 30 -PatchOperation {
    # Quick fix code
}
```
**Result**: Monitors every 15 seconds, times out after 30 minutes.

### Cross-Fork with Auto-Cleanup
```powershell
Invoke-PatchWorkflow -PatchDescription "Feature for upstream" -CreatePR -AutoCleanup `
    -TargetFork "upstream" -PatchOperation {
    # Feature code for upstream repository
}
```
**Result**: Creates cross-fork PR and monitors for merge in the upstream repository.

## Configuration Parameters

### AutoCleanup
- **Type**: Switch parameter
- **Default**: False (disabled)
- **Description**: Enables automatic post-merge cleanup monitoring

### CleanupCheckIntervalSeconds
- **Type**: Integer
- **Default**: 30 seconds
- **Range**: 10-300 seconds
- **Description**: How often to check PR status for merge completion

### CleanupTimeoutMinutes
- **Type**: Integer  
- **Default**: 60 minutes
- **Range**: 10-480 minutes (8 hours max)
- **Description**: Maximum time to monitor before giving up

## Workflow Process

### 1. PR Creation Phase
```
Invoke-PatchWorkflow -CreatePR -AutoCleanup
├── Creates patch branch
├── Commits changes  
├── Pushes branch
├── Creates GitHub issue (default)
├── Creates pull request
├── Switches back to main branch
└── Starts background monitoring job
```

### 2. Background Monitoring Phase
```
Background Monitoring Job
├── Checks PR status every N seconds
├── Validates merge completion
├── Handles PR state changes
│   ├── MERGED → Triggers cleanup
│   ├── CLOSED → Stops monitoring
│   └── OPEN → Continues monitoring
└── Times out after configured period
```

### 3. Auto-Cleanup Phase (when merged)
```
Post-Merge Cleanup
├── Validates PR was actually merged
├── Switches to main branch (if not already)
├── Pulls latest changes from origin
├── Deletes local patch branch
├── Shows completion notification
└── Updates repository status
```

## Monitoring Job Management

### Check Job Status
```powershell
# Get all running background jobs
Get-Job

# Check specific monitoring job
Get-Job -Id [JobId] | Receive-Job -Keep

# View job output
Receive-Job -Id [JobId]
```

### Manual Cleanup (if needed)
```powershell
# If monitoring fails or times out
Invoke-PostMergeCleanup -BranchName "patch/your-branch" -PullRequestNumber 123

# With merge validation
Invoke-PostMergeCleanup -BranchName "patch/your-branch" -PullRequestNumber 123 -ValidateMerge

# Force cleanup (skip validation)
Invoke-PostMergeCleanup -BranchName "patch/your-branch" -Force
```

## Benefits

### 🎯 Developer Experience
- **Zero manual cleanup**: No need to remember to clean up branches
- **Stay on main**: Automatically returns to main branch for next work
- **Current state**: Always has latest changes from merged PRs
- **Clean workspace**: No accumulation of old patch branches

### 🚀 Workflow Efficiency
- **Immediate feedback**: Know when your PR is merged
- **Background operation**: Non-blocking, continues other work
- **Smart defaults**: Works well out of the box
- **Flexible configuration**: Customize for different workflows

### 🛡️ Error Prevention
- **Merge validation**: Confirms PR was actually merged
- **Graceful failures**: Handles edge cases without breaking
- **Manual fallback**: Always provides manual cleanup options
- **Timeout protection**: Won't monitor indefinitely

## Error Handling

### Common Scenarios

#### GitHub CLI Not Available
```
Warning: GitHub CLI (gh) is required for PR monitoring
Fallback: Manual cleanup instructions provided
```

#### Network Issues
```
Warning: Could not check PR status: [error details]
Action: Continues monitoring with exponential backoff
```

#### PR Closed Without Merge
```
Warning: PR was closed without merging
Action: Stops monitoring, provides manual cleanup option
```

#### Monitoring Timeout
```
Warning: Monitoring timed out after 60 minutes
Action: Provides manual cleanup command
```

## Best Practices

### When to Use Auto-Cleanup
✅ **Recommended for**:
- Regular feature development
- Bug fixes and improvements
- Documentation updates
- Standard workflow patches

✅ **Especially useful for**:
- Frequent contributors
- Teams with many PRs
- Automated workflows
- Clean workspace maintenance

### When NOT to Use Auto-Cleanup
❌ **Avoid for**:
- Experimental branches you want to keep
- WIP branches that might need more work
- Branches with special merge requirements
- Complex multi-step workflows

### Configuration Recommendations

#### Fast Development Cycle
```powershell
-AutoCleanup -CleanupCheckIntervalSeconds 15 -CleanupTimeoutMinutes 30
```

#### Standard Development
```powershell
-AutoCleanup  # Use defaults (30s check, 60min timeout)
```

#### Long-Running Features
```powershell
-AutoCleanup -CleanupCheckIntervalSeconds 60 -CleanupTimeoutMinutes 240
```

## Integration with VS Code Tasks

### Enhanced Tasks (Coming Soon)
```json
{
    "label": "PatchManager: Create PR with Auto-Cleanup",
    "type": "shell",
    "command": "pwsh",
    "args": [
        "-Command",
        "Invoke-PatchWorkflow -PatchDescription '${input:description}' -CreatePR -AutoCleanup -PatchOperation { ${input:operation} }"
    ]
}
```

## Troubleshooting

### Job Monitoring Issues
```powershell
# Check for failed jobs
Get-Job | Where-Object { $_.State -eq 'Failed' }

# Remove completed/failed jobs
Get-Job | Remove-Job -Force

# Restart monitoring manually
Start-PostMergeMonitor -PullRequestNumber 123 -BranchName "patch/branch"
```

### Branch Cleanup Issues
```powershell
# Force cleanup if automatic fails
Invoke-PostMergeCleanup -BranchName "patch/branch" -Force

# Check git status
git status
git branch -a

# Manual branch deletion
git branch -D patch/branch-name
```

### GitHub API Rate Limits
```powershell
# Check rate limit status
gh api rate_limit

# Increase check interval if hitting limits
-CleanupCheckIntervalSeconds 60
```

## Compatibility

### Supported Scenarios
- ✅ Standard PRs within repository
- ✅ Cross-fork PRs (upstream/root)
- ✅ Auto-merge enabled PRs
- ✅ Squash merge, merge commit, rebase
- ✅ Windows, Linux, macOS
- ✅ GitHub.com and GitHub Enterprise

### Requirements
- PowerShell 7.0+
- GitHub CLI (`gh`) installed and authenticated
- Git repository with GitHub remote
- PatchManager v2.1+

## Future Enhancements

### Planned Features
- [ ] VS Code extension integration
- [ ] Slack/Teams notifications
- [ ] Multi-repository monitoring
- [ ] Smart cleanup scheduling
- [ ] Cleanup analytics and reporting

### Feedback and Contributions
This feature is part of PatchManager v2.1's enhanced automation capabilities. Feedback and contributions are welcome through GitHub issues and pull requests.

---

*This feature represents a significant improvement in developer workflow automation, reducing manual tasks and improving code repository hygiene.*
