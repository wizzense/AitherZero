---
applyTo: "**/*.ps1"
description: "PatchManager workflows and common scenarios - UPDATED FOR CONSOLIDATED VERSION"
---

# PatchManager Workflows & Instructions (Consolidated v2.1 - IMPROVED)

This file provides comprehensive guidance for using the **IMPROVED CONSOLIDATED PatchManager** in the Aitherium Infrastructure Automation project.

## 🎯 Core PatchManager Functions (4 Total)

### Main Workflow Function (Primary)

Use `Invoke-PatchWorkflow` for ALL patch operations - this is the single entry point that now handles dirty working trees and creates issues by default:

```powershell
# Complete patch workflow with AUTOMATIC dirty tree handling
Invoke-PatchWorkflow -PatchDescription "Fix non-interactive mode issues" -PatchOperation {
    # Your code changes here
    Write-Host "Making changes..."
} -CreatePR -Priority "Medium"
# ✅ Auto-commits existing changes, creates issue by default, applies patch, creates PR

# Patch with testing validation
Invoke-PatchWorkflow -PatchDescription "Update module exports" -PatchOperation {
    # Code changes
    Update-ModuleManifest -Path "Module.psd1" -FunctionsToExport @("Function1")
} -TestCommands @("pwsh -Command 'Import-Module ./aither-core/modules/LabRunner -Force'") -CreatePR

# Simple patch without GitHub integration
Invoke-PatchWorkflow -PatchDescription "Quick local fix" -CreateIssue:$false -PatchOperation {
    # Your changes
} -DryRun
# ✅ No issue created, just handles changes and creates branch

# Emergency patch with everything enabled
Invoke-PatchWorkflow -PatchDescription "Critical security fix" -PatchOperation {
    # Critical changes
} -CreatePR -Priority "Critical"
# ✅ Creates issue, applies changes, creates PR, all automatically
```

## 🚀 KEY IMPROVEMENTS IN v2.1

### ✅ Automatic Dirty Working Tree Handling
- **NO MORE FAILURES** on uncommitted changes
- Automatically commits existing changes before starting patch workflow
- Sanitizes Unicode/emoji characters before committing
- Clear logging of what's being auto-committed

### ✅ Issue Creation by Default
- **Issues created automatically** unless explicitly disabled with `-CreateIssue:$false`
- **Issue created FIRST** (step 1) for proper tracking
- PR creation auto-links to issue when both are enabled

### ✅ Streamlined Single-Step Workflow
- One command does: auto-commit → create branch → create issue → apply changes → commit → (optional) create PR
- **No more multi-step processes** or failed workflows
- Perfect for quick fixes and major changes alike

## Common Scenarios (Updated)

### 1. Quick Development Fix (Most Common)
```powershell
# Just describe and do - everything else is automatic
Invoke-PatchWorkflow -PatchDescription "Fix module loading bug" -PatchOperation {
    # Your fix here
    $content = Get-Content "module.ps1" -Raw
    $content = $content -replace "Import-Module", "Import-Module -Force"
    Set-Content "module.ps1" -Value $content
}
# ✅ Result: Auto-commits any pending changes, creates branch, creates issue, applies fix, commits
```

### 2. Feature Development with PR
```powershell
# Add new feature with full GitHub integration
Invoke-PatchWorkflow -PatchDescription "Add new configuration validation" -PatchOperation {
    # Implementation here
    Add-Content "validators.ps1" -Value "function Test-Config { ... }"
} -CreatePR -TestCommands @("pwsh -File tests/validators.tests.ps1")
# ✅ Result: Full workflow with issue + PR + testing
```

### 3. Emergency Hotfix
```powershell
# Critical fix with high priority tracking
Invoke-PatchWorkflow -PatchDescription "Fix security vulnerability in auth module" -PatchOperation {
    # Security fix
    Update-AuthModule -SecurityPatch
} -CreatePR -Priority "Critical"
# ✅ Result: High-priority issue created, fix applied, PR ready for immediate review
```

### 4. Local-Only Changes
```powershell
# Work locally without GitHub overhead
Invoke-PatchWorkflow -PatchDescription "Experimental feature testing" -CreateIssue:$false -PatchOperation {
    # Experimental code
}
# ✅ Result: Just branch + commit, no GitHub integration
```

### Individual Component Functions (Advanced Use)

Use these for specific operations when you need fine-grained control:

```powershell
# Create issue only
New-PatchIssue -Description "Fix module loading" -Priority "High" -AffectedFiles @("Module.psm1")

# Create PR only (with optional issue linking)
New-PatchPR -Description "Fix module loading" -BranchName "patch/fix-loading" -IssueNumber 123

# Rollback operations
Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup
Invoke-PatchRollback -RollbackType "SpecificCommit" -CommitHash "abc123def" -DryRun
```

## ⚠️ IMPORTANT: Legacy Functions Archived

**These functions are NO LONGER available** (moved to Legacy folder):

- ❌ `Invoke-SimplifiedPatchWorkflow` → Use `Invoke-PatchWorkflow`
- ❌ `Invoke-GitControlledPatch` → Use `Invoke-PatchWorkflow`
- ❌ `New-SimpleIssueForPatch` → Use `New-PatchIssue`
- ❌ `New-SimplePRForPatch` → Use `New-PatchPR`
- ❌ `Invoke-QuickRollback` → Use `Invoke-PatchRollback`
- ❌ All other legacy functions (23 total)

## 🎯 New Workflow Philosophy

**Before v2.1:** Multi-step, failure-prone, required clean working tree
**After v2.1:** Single-step, handles any situation, creates tracking by default

```powershell
# OLD WAY (multiple steps, could fail):
git add .; git commit -m "Save work"  # Manual step
Invoke-PatchWorkflow -CreateIssue -CreatePR ...  # Could fail on dirty tree

# NEW WAY (one step, always works):
Invoke-PatchWorkflow -PatchDescription "Fix it" -CreatePR ...  # Handles everything automatically
```

## VS Code Tasks Integration

Use these VS Code tasks for common PatchManager workflows:

- **Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Create Feature Patch"**
- **Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Test Current Changes"**
- **Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Emergency Rollback"**
- **Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Validate All Modules"**

## Best Practices (Updated for v2.1)

1. **Use the main workflow** for most patch operations: `Invoke-PatchWorkflow`
2. **Issues created by default** - use `-CreateIssue:$false` only for quick local changes
3. **No more clean working tree requirement** - the workflow auto-commits existing changes
4. **Always use descriptive patch descriptions** that explain the what and why
5. **Include test commands** when possible to validate your changes
6. **Use DryRun mode first** to preview changes without executing them: `-DryRun`
7. **No emoji/Unicode output** - the new workflow sanitizes files and follows project standards
8. **Create PRs for review** using `-CreatePR` when changes need team review

## Error Handling Patterns

```powershell
# Pattern 1: Safe execution with rollback
try {
    Invoke-PatchWorkflow -PatchDescription "Risky change" -PatchOperation {
        # Risky code here
    } -TestCommands @("validation-command") -CreateIssue
} catch {
    Write-Error "Patch failed: $($_.Exception.Message)"
    # Use rollback if needed
    Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup
}

# Pattern 2: Emergency rollback
Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup -Force
```

## Testing Integration

Always run these tests after PatchManager operations:

```powershell
# Quick validation
pwsh -File "./tests/Run-BulletproofTests.ps1" -TestSuite "Unit" -CI

# Full validation
pwsh -File "./tests/Run-AllModuleTests.ps1" -Parallel

# Core-runner specific tests
pwsh -File "./test-noninteractive-fix.ps1" -TestMode All
```

## Log File Locations

PatchManager operations create logs in:

- `logs/patchmanager-operations-{date}.log`
- `logs/automated-error-tracking.json`

Always check these logs after operations for detailed execution information.

Always use PowerShell 7.0+ cross-platform syntax with forward slashes for paths.
