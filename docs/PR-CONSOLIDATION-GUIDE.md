# 🔄 PR Consolidation Guide - PatchManager v2.1

## Overview

PatchManager now includes **intelligent PR consolidation** to automatically combine multiple open pull requests, reducing merge conflicts and simplifying the review process.

## ✨ Key Features

### 🎯 Automatic Integration
- **Built into `Invoke-PatchWorkflow`** - Just add `-AutoConsolidate`
- **Runs after PR creation** - Your new PR can trigger consolidation
- **Safe by default** - Only combines compatible PRs unless forced

### 🧠 Intelligent Strategies
- **Compatible**: Only combine PRs with no conflicts (safest)
- **RelatedFiles**: Combine PRs that modify related file areas
- **SameAuthor**: Combine PRs from the same author
- **ByPriority**: Combine based on priority levels
- **All**: Attempt to combine all possible PRs (use with caution)

### 🛡️ Built-in Safety
- **Conflict detection** before combining
- **DryRun mode** to preview consolidation
- **Rollback capability** if consolidation fails
- **Preserves original PRs** until consolidation is confirmed

## 🚀 Quick Start

### Basic Auto-Consolidation
```powershell
# Create PR and auto-consolidate compatible PRs
Invoke-PatchWorkflow -PatchDescription "Fix multiple issues" -CreatePR -AutoConsolidate -PatchOperation {
    Fix-ModuleLoading
    Fix-ConfigValidation
}
```

### Author-Based Consolidation
```powershell
# Consolidate your own PRs (up to 3)
Invoke-PatchWorkflow -PatchDescription "My latest fixes" -CreatePR -AutoConsolidate -ConsolidationStrategy "SameAuthor" -MaxPRsToConsolidate 3 -PatchOperation {
    Add-NewFeature
}
```

### Preview Consolidation
```powershell
# See what would be consolidated without making changes
Invoke-PRConsolidation -ConsolidationStrategy "Compatible" -DryRun
```

## 📋 Consolidation Strategies Explained

### 🛡️ Compatible (Recommended)
**Best for**: Daily development, safety-first approach
- Only combines PRs with **zero conflicts**
- Analyzes file overlap and change patterns
- **Safest option** - minimal risk of breaking changes

```powershell
Invoke-PRConsolidation -ConsolidationStrategy "Compatible"
```

### 📁 RelatedFiles

**Best for**: Feature work spanning multiple related files
- Combines PRs that modify **related file areas**
- Considers file dependencies and module relationships
- Good for coordinated feature development

```powershell
Invoke-PRConsolidation -ConsolidationStrategy "RelatedFiles"
```

### 👤 SameAuthor
**Best for**: Individual developers with multiple open PRs
- Combines PRs from the **same GitHub user**
- Maintains author consistency
- Perfect for consolidating your own work

```powershell
Invoke-PRConsolidation -ConsolidationStrategy "SameAuthor" -MaxPRsToConsolidate 3
```

### 🔥 ByPriority
**Best for**: Release coordination, critical fixes
- Combines PRs based on **priority labels**
- Groups Critical → High → Medium → Low
- Useful for release preparation

```powershell
Invoke-PRConsolidation -ConsolidationStrategy "ByPriority"
```

### ⚠️ All (Advanced)
**Best for**: Major refactoring, experienced teams
- Attempts to combine **all possible PRs**
- Uses advanced conflict resolution
- **Use with caution** - requires manual review

```powershell
Invoke-PRConsolidation -ConsolidationStrategy "All" -Force
```

## 📖 Complete Workflow Examples

### 1. 🎯 Feature Development Workflow
```powershell
# Develop feature with auto-consolidation
Invoke-PatchWorkflow -PatchDescription "Complete user authentication system" -CreatePR -AutoConsolidate -ConsolidationStrategy "RelatedFiles" -TestCommands @(
    "Test-AuthenticationModule",
    "Test-UserManagement"
) -PatchOperation {
    # Implement authentication
    Add-AuthenticationModule
    Update-UserManagement
    Add-SecurityValidation
}

# Result: Creates PR and consolidates any related authentication PRs
```

### 2. 🧹 Cleanup and Maintenance
```powershell
# Consolidate multiple maintenance PRs from yourself
Invoke-PatchWorkflow -PatchDescription "Weekly maintenance consolidation" -CreatePR -AutoConsolidate -ConsolidationStrategy "SameAuthor" -MaxPRsToConsolidate 5 -PatchOperation {
    # Apply maintenance fixes
    Update-Dependencies
    Fix-DeprecationWarnings
    Clean-ObsoleteCode
}

# Result: Combines up to 5 of your maintenance PRs into one
```

### 3. 🚨 Emergency Response
```powershell
# Critical fixes with priority-based consolidation
Invoke-PatchWorkflow -PatchDescription "SECURITY: Fix authentication bypass" -CreatePR -AutoConsolidate -ConsolidationStrategy "ByPriority" -Priority "Critical" -PatchOperation {
    # Apply security fix
    Fix-AuthenticationBypass
    Add-SecurityTests
}

# Result: Consolidates all critical/high priority PRs for coordinated release
```

### 4. 🔍 Preview Before Action
```powershell
# Analyze consolidation opportunities first
$consolidationPreview = Invoke-PRConsolidation -ConsolidationStrategy "Compatible" -DryRun

if ($consolidationPreview.Success) {
    Write-Host "Found $($consolidationPreview.GroupsFound) consolidation opportunities"
    # Proceed with actual consolidation
    Invoke-PRConsolidation -ConsolidationStrategy "Compatible"
} else {
    Write-Host "No consolidation opportunities found"
}
```

## 🛠️ Advanced Usage

### Custom Consolidation Logic
```powershell
# Combine multiple strategies
foreach ($strategy in @("SameAuthor", "Compatible", "RelatedFiles")) {
    $result = Invoke-PRConsolidation -ConsolidationStrategy $strategy -DryRun
    if ($result.Success) {
        Write-Host "Strategy '$strategy' found $($result.GroupsFound) opportunities"
        break
    }
}
```

### Rollback After Consolidation
```powershell
# If consolidation goes wrong, rollback
try {
    $consolidation = Invoke-PRConsolidation -ConsolidationStrategy "All"
    if (-not $consolidation.Success) {
        throw "Consolidation failed"
    }
} catch {
    Write-Warning "Consolidation failed, rolling back..."
    Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup
}
```

## 📊 Understanding Results

### Success Response
```powershell
@{
    Success = $true
    Strategy = "Compatible"
    PRsConsolidated = 3
    ConsolidatedPRUrl = "https://github.com/user/repo/pull/123"
    OriginalPRs = @(78, 79, 80)
    ConflictsResolved = 0
}
```

### No Opportunities Response
```powershell
@{
    Success = $false
    Message = "No consolidation opportunities found"
    Strategy = "Compatible"
    PRsAnalyzed = 5
    GroupsFound = 0
}
```

## ⚡ VS Code Integration

Use these VS Code tasks for common consolidation workflows:

- **Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Create Feature Patch"**
  - Includes consolidation options
- **Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Emergency Rollback"**
  - For rolling back failed consolidations

## 🔧 Configuration & Settings

### Global Settings
```powershell
# Set default consolidation preferences
$env:PATCH_MANAGER_DEFAULT_CONSOLIDATION = "Compatible"
$env:PATCH_MANAGER_MAX_PRS = "3"
```

### Per-Repository Settings
```json
// In .github/patch-manager-config.json
{
    "consolidation": {
        "defaultStrategy": "Compatible",
        "maxPRs": 5,
        "autoConsolidate": false,
        "allowedStrategies": ["Compatible", "SameAuthor"]
    }
}
```

## 🛡️ Safety & Best Practices

### ✅ Do's
- **Start with "Compatible" strategy** for safety
- **Use DryRun first** to preview changes
- **Test consolidated PRs** thoroughly before merging
- **Keep MaxPRsToConsolidate reasonable** (3-5)
- **Review consolidation results** before final merge

### ❌ Don'ts
- **Don't use "All" strategy** without careful review
- **Don't consolidate breaking changes** without team approval
- **Don't skip testing** after consolidation
- **Don't consolidate across major version changes**
- **Don't ignore conflict warnings**

### 🚨 Emergency Procedures
If consolidation causes issues:

1. **Immediate rollback**:
   ```powershell
   Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup
   ```

2. **Restore original PRs** (if available):
   ```powershell
   # Original PRs are preserved until consolidation is confirmed
   git checkout original-pr-branch-name
   ```

3. **Report the issue**:
   ```powershell
   New-PatchIssue -Description "Consolidation failure: [details]" -Priority "High"
   ```

## 📈 Benefits

### 🎯 Reduced Merge Conflicts
- **Intelligent conflict detection** before combining
- **Sequential rebasing** of compatible changes
- **Coordinated integration** of related features

### 🚀 Faster Review Process
- **Single PR to review** instead of multiple
- **Related changes grouped together** for context
- **Consistent coding standards** across consolidated changes

### 📊 Better Project Management
- **Fewer open PRs** to track
- **Clearer release planning** with consolidated features
- **Simplified testing** with grouped changes

## 🆘 Troubleshooting

### Common Issues

**"No consolidation opportunities found"**
- Normal when PRs have conflicts or are unrelated
- Try different strategies (SameAuthor, RelatedFiles)
- Check if PRs modify overlapping files

**"Consolidation failed with conflicts"**
- PRs have genuine conflicts requiring manual resolution
- Use DryRun to identify specific conflicts
- Consider consolidating smaller groups of PRs

**"GitHub API rate limit exceeded"**
- Wait for rate limit reset (usually 1 hour)
- Use personal access token with higher limits
- Reduce frequency of consolidation attempts

### Debug Mode
```powershell
# Enable verbose logging for debugging
$VerbosePreference = "Continue"
Invoke-PRConsolidation -ConsolidationStrategy "Compatible" -Verbose
```

---

## 🎉 Getting Started

**Ready to reduce your merge conflicts?**

1. **Start simple**: `Invoke-PatchWorkflow -PatchDescription "My fix" -CreatePR -AutoConsolidate`
2. **Preview first**: Add `-DryRun` to see what would happen
3. **Customize strategy**: Use `-ConsolidationStrategy "SameAuthor"` for your PRs

**Your pull request workflow just got a lot smoother! 🚀**
