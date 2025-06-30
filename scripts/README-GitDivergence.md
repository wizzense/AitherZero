# Git Divergence Fix Guide

## Quick Fix

If your git branches have diverged or you're experiencing merge conflicts:

```powershell
# Quick fix with automatic resolution
./scripts/Fix-GitDivergence.ps1 -Force

# Interactive fix with confirmations
./scripts/Fix-GitDivergence.ps1
```

## Prevention

Always use PatchManager for git operations:

```powershell
# Before starting work
Import-Module ./aither-core/modules/PatchManager -Force
Sync-GitBranch -Force

# Create changes
Invoke-PatchWorkflow -PatchDescription "Your changes" -PatchOperation {
    # Make your changes here
} -CreatePR
```

## Common Issues and Solutions

### Issue: "Your branch has diverged from origin/main"

**Cause**: Local commits that conflict with remote changes, often from cherry-picks or manual merges.

**Solution**:
```powershell
./scripts/Fix-GitDivergence.ps1 -Force
```

### Issue: "Failed to push refs"

**Cause**: Remote has changes not in local branch.

**Solution**:
```powershell
Sync-GitBranch -BranchName "main" -Force
```

### Issue: Duplicate tags

**Cause**: Tags created locally not pushed or conflicting with remote.

**Solution**:
```powershell
Sync-GitBranch -ValidateTags -CleanupOrphaned
```

## VS Code Tasks

Use these VS Code tasks (Ctrl+Shift+P → Tasks: Run Task):

- **Git: Sync Current Branch** - Sync current branch with remote
- **Git: Fix Branch Divergence** - Run full divergence fix
- **Git: Full Cleanup and Sync** - Complete cleanup of all branches

## Best Practices

1. **Always sync before work**: Run `Sync-GitBranch -Force` before starting
2. **Use PatchManager**: Never use git commands directly
3. **Fix immediately**: Don't let divergence persist
4. **Check status regularly**: Run `git status` to catch issues early
5. **Use PRs**: Always merge through pull requests, not local merges

## What the Fix Script Does

1. **Backs up current state** to `./git-backup/`
2. **Stashes uncommitted changes** safely
3. **Fixes main branch divergence** by syncing with remote
4. **Cleans up merged branches** that are no longer needed
5. **Removes orphaned branches** not on remote
6. **Validates and cleans tags**
7. **Prunes remote tracking**
8. **Restores stashed changes** if possible

## Emergency Recovery

If something goes wrong:

```powershell
# Check backup
Get-Content ./git-backup/git-state-*.json | ConvertFrom-Json

# Restore from backup branch
git checkout backup/main-[timestamp]

# Manual reset (last resort)
git fetch origin
git reset --hard origin/main
```