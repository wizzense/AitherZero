# PatchManager v3.1 - PR Awareness & Workflow Management

## Overview

PatchManager v3.1 addresses the key issue of creating multiple PRs without properly managing them. The new version includes intelligent PR awareness and workflow management to prevent PR pile-ups.

## Key Features

### 🎯 PR Awareness
- **Automatic Detection**: Checks for existing open PRs before creating new ones
- **Smart Warnings**: Alerts when multiple PRs are open
- **Workflow Suggestions**: Recommends best practices based on current state

### 🔄 Workflow Modes
- **SinglePR**: Prevents creating new PRs when 3+ are already open
- **Stacked**: Creates additional PRs for concurrent development  
- **Replace**: Closes old PRs when new ones are created
- **Auto**: Intelligently selects the best mode

### 🏠 Automatic Branch Management
- **Return to Main**: Automatically switches back to main branch after PR creation
- **Clean Workspace**: Prevents staying on patch branches unnecessarily

### 🧹 Cleanup Tools
- **Get-PatchStatus**: Shows current patch workflow state
- **Invoke-PatchCleanup**: Cleans up old branches and stale PRs

## Usage Examples

### Basic Usage with PR Awareness
```powershell
# Standard patch with automatic PR awareness
New-Patch -Description "Fix logging issue" -Changes {
    # Your changes here
}
# Will warn if multiple PRs exist and suggest appropriate action
```

### Workflow Mode Control
```powershell
# Force single PR mode (no new PRs if 3+ exist)
New-Feature -Description "New auth module" -WorkflowMode "SinglePR" -Changes {
    Add-AuthModule
}

# Replace mode (closes old PRs when new one is created)
New-Hotfix -Description "Critical fix" -WorkflowMode "Replace" -Changes {
    Fix-CriticalBug
}
```

### Auto Return to Main
```powershell
# Automatically return to main branch after PR creation
New-Feature -Description "Add feature" -ReturnToMain -Changes {
    Add-NewFeature
}
```

### Status and Cleanup
```powershell
# Check current patch workflow status
Get-PatchStatus

# Clean up merged branches and return to main
Invoke-PatchCleanup -DeleteMerged -ReturnToMain

# Clean up old branches (older than 14 days)
Invoke-PatchCleanup -DeleteOldBranches -DaysOld 14
```

## Workflow Mode Details

| Mode | When to Use | Behavior |
|------|-------------|----------|
| **SinglePR** | High activity periods | Warns when 3+ PRs exist, suggests consolidation |
| **Stacked** | Concurrent development | Allows multiple PRs for parallel work |
| **Replace** | Hotfixes/urgent changes | Closes old PRs when creating new ones |
| **Auto** | Default behavior | Selects best mode based on current state |

## Function Updates

### New Functions
- `Get-PatchStatus` - Comprehensive workflow status
- `Invoke-PatchCleanup` - Branch and PR cleanup
- `Get-OpenPatchPRs` - Internal PR detection

### Enhanced Functions
All main functions now support:
- `-WorkflowMode` parameter for controlling PR behavior
- `-ReturnToMain` switch for automatic branch management
- PR awareness before creating new PRs

### Updated Functions
- `New-Patch` - Full v3.1 feature set
- `New-Feature` - Enhanced with workflow modes
- `New-Hotfix` - Defaults to "Replace" mode for emergencies
- `New-QuickFix` - Optional PR creation with awareness

## Migration from v3.0

v3.1 is fully backward compatible. No code changes required, but new features are available:

```powershell
# v3.0 syntax (still works)
New-Feature -Description "Feature" -Changes { ... }

# v3.1 enhanced syntax
New-Feature -Description "Feature" -WorkflowMode "SinglePR" -ReturnToMain -Changes { ... }
```

## Best Practices

### Daily Workflow
1. **Check Status**: Start with `Get-PatchStatus`
2. **Clean Workspace**: Use `Invoke-PatchCleanup` weekly
3. **Smart Creation**: Let workflow modes guide your PR strategy
4. **Return to Main**: Always use `-ReturnToMain` for cleaner workflow

### Team Environment
- Use **SinglePR** mode during busy periods
- Use **Stacked** mode for parallel development
- Regular cleanup prevents branch pollution
- Status checks help coordinate team efforts

### Emergency Fixes
- `New-Hotfix` automatically uses **Replace** mode
- Critical fixes take precedence over existing PRs
- Auto-cleanup happens after hotfix creation

## Configuration

All features work out-of-the-box with intelligent defaults:
- **Auto** workflow mode adapts to your situation
- PR awareness activates automatically
- Branch management is optional but recommended

## Troubleshooting

### "Too Many PRs" Warning
- Check `Get-PatchStatus` to see open PRs
- Consider using `Invoke-PatchCleanup -DeleteMerged`
- Use `-WorkflowMode "Replace"` for urgent changes

### Stuck on Patch Branch
- Use `git checkout main` or
- Use `Invoke-PatchCleanup -ReturnToMain`

### Can't Create PR
- Ensure you have push permissions
- Check GitHub CLI authentication: `gh auth status`
- Verify branch exists on remote

## Summary

PatchManager v3.1 transforms PR management from manual to intelligent:
- **Prevents** PR pile-ups through awareness
- **Guides** best practices through workflow modes  
- **Automates** branch management and cleanup
- **Maintains** full backward compatibility

The result is a cleaner, more manageable patch workflow that scales with your development needs.