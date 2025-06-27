# PatchManager v2.1 - Complete Usage Guide

## 🎯 Overview

PatchManager v2.1 is the revolutionary Git workflow automation system that handles ALL your development workflows with intelligence and reliability. It's the single source of truth for patch operations, issue tracking, and cross-fork collaboration in the Aitherium ecosystem.

## 🚀 Key Features

### ✅ What's NEW in v2.1

- **Automatic Dirty Working Tree Handling** - No more failed workflows due to uncommitted changes
- **Issue Creation by Default** - Every patch automatically creates a tracking issue
- **Single-Step Workflow** - One command handles everything from start to finish
- **Cross-Fork Intelligence** - Automatically detects and targets the correct repository
- **Unicode/Emoji Sanitization** - Ensures clean, professional commits
- **Enhanced Error Recovery** - Robust error handling with automatic rollback options

### 🎪 Core Philosophy

**Before v2.1:** Multi-step, failure-prone processes requiring clean working trees
**After v2.1:** Single-step workflows that handle any situation automatically

## 📚 Complete Function Reference

### Primary Function: `Invoke-PatchWorkflow`

The main entry point for ALL patch operations. This function is your one-stop solution for:
- Branch creation and management
- Issue creation and tracking
- Patch application and testing
- Pull request creation
- Cross-fork operations

#### Basic Syntax
```powershell
Invoke-PatchWorkflow -PatchDescription "Description" -PatchOperation { <ScriptBlock> } [Parameters]
```

#### Core Parameters
- **`-PatchDescription`** (Required) - Clear description of what the patch does
- **`-PatchOperation`** (Required) - ScriptBlock containing your changes
- **`-CreatePR`** - Create pull request after applying patch
- **`-CreateIssue`** - Create GitHub issue (enabled by default)
- **`-TargetFork`** - Target repository ("current", "upstream", "root")
- **`-Priority`** - Issue priority ("Low", "Medium", "High", "Critical")
- **`-TestCommands`** - Array of test commands to validate changes
- **`-DryRun`** - Preview operations without executing them

#### Advanced Parameters
- **`-Force`** - Force operations even with validation warnings
- **`-SkipTests`** - Skip automated testing validation
- **`-CustomBranch`** - Use custom branch name instead of auto-generated
- **`-IssueLabels`** - Additional labels for created issues
- **`-AssignToSelf`** - Assign created issues to current user

### Supporting Functions

#### `New-PatchIssue`
Create standalone GitHub issues for tracking purposes.

```powershell
New-PatchIssue -Description "Issue description" -Priority "Medium" [-AffectedFiles @("file1.ps1")] [-DryRun]
```

#### `New-PatchPR`
Create standalone pull requests.

```powershell
New-PatchPR -Description "PR description" -BranchName "feature-branch" [-IssueNumber 123] [-DryRun]
```

#### `Invoke-PatchRollback`
Rollback operations and emergency recovery.

```powershell
Invoke-PatchRollback -RollbackType "LastCommit|SpecificCommit|LastBranch" [-CommitHash "abc123"] [-CreateBackup] [-DryRun]
```

## 🎯 Complete Usage Scenarios

### 1. Quick Development Fix (Most Common Use Case)

**Scenario**: You need to fix a bug quickly without dealing with Git complexity.

```powershell
# Single command handles everything
Invoke-PatchWorkflow -PatchDescription "Fix module loading issue in LabRunner" -PatchOperation {
    # Your fix here
    $content = Get-Content "aither-core/modules/LabRunner/LabRunner.psm1" -Raw
    $content = $content -replace 'Import-Module ([^-])', 'Import-Module $1 -Force'
    Set-Content "aither-core/modules/LabRunner/LabRunner.psm1" -Value $content
}

# What happens automatically:
# ✅ Saves any uncommitted changes in your working tree
# ✅ Creates branch: patch/20240622-154530-Fix-module-loading-issue-in-LabRunner
# ✅ Creates GitHub issue for tracking
# ✅ Applies your changes
# ✅ Commits with sanitized message
# ✅ Ready for manual PR creation or additional changes
```

### 2. Feature Development with Full Tracking

**Scenario**: You're adding a new feature and want complete GitHub integration.

```powershell
Invoke-PatchWorkflow -PatchDescription "Add input validation to configuration parser" -PatchOperation {
    # Add validation functions
    Add-Content "aither-core/modules/ConfigManager/Private/Validators.ps1" -Value @"
function Test-ConfigurationInput {
    param([string]`$InputValue, [string]`$ValidationPattern)
    return `$InputValue -match `$ValidationPattern
}
"@

    # Update main function to use validation
    $configPath = "aither-core/modules/ConfigManager/Public/Get-Configuration.ps1"
    $content = Get-Content $configPath -Raw
    $content = $content -replace '(param\(.*?\))', '$1`n    if (-not (Test-ConfigurationInput $ConfigName "^[a-zA-Z0-9-_]+$")) { throw "Invalid config name" }'
    Set-Content $configPath -Value $content
} -CreatePR -TestCommands @(
    "pwsh -File tests/unit/modules/ConfigManager/ConfigManager-Core.Tests.ps1",
    "Import-Module './aither-core/modules/ConfigManager' -Force"
) -Priority "Medium"

# What happens:
# ✅ Creates tracking issue with "Medium" priority
# ✅ Creates feature branch
# ✅ Applies your changes
# ✅ Runs validation tests
# ✅ Creates pull request
# ✅ Links PR to issue automatically
```

### 3. Cross-Fork Contribution (Contributing Upstream)

**Scenario**: You want to contribute improvements to the upstream AitherLabs repository.

```powershell
Invoke-PatchWorkflow -PatchDescription "Improve error handling in TestingFramework module" -TargetFork "upstream" -PatchOperation {
    # Enhanced error handling
    $testingFrameworkPath = "aither-core/modules/TestingFramework/Public/Invoke-TestSuite.ps1"
    $content = Get-Content $testingFrameworkPath -Raw

    # Add try-catch with detailed logging
    $enhanced = $content -replace '(Invoke-Pester.*)', @'
try {
    $1
    Write-CustomLog -Level 'SUCCESS' -Message "Test suite completed successfully"
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Test suite failed: $($_.Exception.Message)"
    Write-CustomLog -Level 'ERROR' -Message "Stack trace: $($_.ScriptStackTrace)"
    throw
}
'@
    Set-Content $testingFrameworkPath -Value $enhanced
} -CreatePR -Priority "High" -TestCommands @(
    "pwsh -File tests/unit/modules/TestingFramework/TestingFramework-Core.Tests.ps1"
)

# What happens:
# ✅ Creates issue in Aitherium/AitherLabs (upstream repository)
# ✅ Creates branch in your fork (wizzense/AitherZero)
# ✅ Applies improvements
# ✅ Creates cross-fork PR: wizzense/AitherZero → Aitherium/AitherLabs
# ✅ Links everything for perfect tracking
```

### 4. Emergency Hotfix to Production

**Scenario**: Critical security issue needs immediate attention in the premium repository.

```powershell
Invoke-PatchWorkflow -PatchDescription "SECURITY: Fix authentication bypass in core module" -TargetFork "root" -PatchOperation {
    # Critical security fix
    $authModulePath = "aither-core/modules/Authentication/Private/Validate-Token.ps1"
    $content = Get-Content $authModulePath -Raw

    # Fix the vulnerability
    $secure = $content -replace 'if \(\$token\)', 'if ($token -and $token.Length -gt 10 -and (Test-TokenSignature $token))'
    Set-Content $authModulePath -Value $secure

    # Add additional validation
    Add-Content "aither-core/modules/Authentication/Private/Test-TokenSignature.ps1" -Value @"
function Test-TokenSignature {
    param([string]`$Token)
    # Implement proper signature validation
    return `$Token -match '^[A-Za-z0-9+/]{40,}={0,2}$'
}
"@
} -CreatePR -Priority "Critical" -TestCommands @(
    "pwsh -File tests/security/Authentication-Security.Tests.ps1"
) -Force

# What happens:
# ✅ Creates CRITICAL priority issue in Aitherium/Aitherium (root/premium repo)
# ✅ Creates hotfix branch
# ✅ Applies security fixes
# ✅ Runs security tests
# ✅ Creates PR directly to premium repository
# ✅ Marked for immediate review due to "Critical" priority
```

### 5. Local Development Without GitHub Integration

**Scenario**: You want to experiment locally without creating issues or PRs.

```powershell
Invoke-PatchWorkflow -PatchDescription "Experimental performance optimization" -CreateIssue:$false -PatchOperation {
    # Experimental changes
    $performancePath = "aither-core/modules/PerformanceOptimizer/Public/Optimize-Operation.ps1"
    Add-Content $performancePath -Value @"
# Experimental caching mechanism
`$script:OperationCache = @{}
function Get-CachedResult {
    param([string]`$Key)
    return `$script:OperationCache[`$Key]
}
"@
} -DryRun

# What happens:
# ✅ Creates local branch only
# ✅ No GitHub issue created
# ✅ No PR created
# ✅ Perfect for experimentation
# ✅ -DryRun shows what would happen without executing
```

### 6. Comprehensive Testing Integration

**Scenario**: You're making changes that need extensive validation.

```powershell
Invoke-PatchWorkflow -PatchDescription "Refactor parallel execution engine" -PatchOperation {
    # Major refactoring
    $parallelPath = "aither-core/modules/ParallelExecution/Public/Invoke-ParallelOperation.ps1"
    $content = Get-Content $parallelPath -Raw

    # Replace old implementation with new async pattern
    $newImplementation = $content -replace 'Start-Job', 'Start-ThreadJob'
    $newImplementation = $newImplementation -replace 'Get-Job', 'Get-ThreadJob'
    Set-Content $parallelPath -Value $newImplementation

    # Update tests
    $testPath = "tests/unit/modules/ParallelExecution/ParallelExecution-Core.Tests.ps1"
    (Get-Content $testPath) -replace 'Start-Job', 'Start-ThreadJob' | Set-Content $testPath
} -CreatePR -TestCommands @(
    "pwsh -File tests/unit/modules/ParallelExecution/ParallelExecution-Core.Tests.ps1",
    "pwsh -File tests/integration/ParallelExecution-Integration.Tests.ps1",
    "pwsh -File tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick",
    "Import-Module './aither-core/modules/ParallelExecution' -Force"
) -Priority "High"

# What happens:
# ✅ Creates high-priority tracking issue
# ✅ Creates refactoring branch
# ✅ Applies all changes
# ✅ Runs comprehensive test suite
# ✅ Validates module loading
# ✅ Runs bulletproof validation
# ✅ Creates PR only if all tests pass
```

### 7. Documentation Updates

**Scenario**: Updating documentation across multiple files.

```powershell
Invoke-PatchWorkflow -PatchDescription "Update README and documentation for v2.1 release" -PatchOperation {
    # Update main README
    $readmePath = "README.md"
    $readme = Get-Content $readmePath -Raw
    $readme = $readme -replace 'Version: .*', 'Version: 2.1'
    $readme = $readme -replace 'Last Updated: .*', "Last Updated: $(Get-Date -Format 'yyyy-MM-dd')"
    Set-Content $readmePath -Value $readme

    # Update module documentation
    Get-ChildItem "aither-core/modules/*/README.md" | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        $updated = $content -replace '## Version\s+[\d.]+', '## Version 2.1'
        Set-Content $_.FullName -Value $updated
    }

    # Update configuration files
    Update-RepositoryDocumentation
} -CreatePR -Priority "Low" -TestCommands @(
    "pwsh -Command 'Get-ChildItem README.md | Test-Path'"
)

# What happens:
# ✅ Creates documentation update issue
# ✅ Updates all documentation files
# ✅ Runs repository documentation update
# ✅ Validates files exist and are readable
# ✅ Creates PR for documentation review
```

### 8. Rollback Operations

**Scenario**: Something went wrong and you need to undo changes.

```powershell
# Rollback the last commit
Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup

# Rollback to specific commit
Invoke-PatchRollback -RollbackType "SpecificCommit" -CommitHash "abc123def456" -CreateBackup

# Rollback to last branch (before current patch)
Invoke-PatchRollback -RollbackType "LastBranch" -CreateBackup

# Preview rollback without executing
Invoke-PatchRollback -RollbackType "LastCommit" -DryRun

# What happens:
# ✅ Creates backup of current state
# ✅ Safely reverts to specified state
# ✅ Logs all rollback operations
# ✅ Preserves important changes in backup
```

## 🎨 VS Code Integration

### Quick Task Access

Use Ctrl+Shift+P → Tasks: Run Task → [Task Name]:

- **"🔧 PatchManager: Create Feature Patch"** - Interactive patch creation
- **"🔧 PatchManager: Quick Local Fix (No Issue)"** - Local-only patches
- **"🔧 PatchManager: Emergency Rollback"** - Quick rollback operations
- **"🔧 PatchManager: Validate All Modules"** - Module validation workflow

### Task Parameters

Many tasks use VS Code input variables for interactive prompts:
- `${input:patchDescription}` - Description of your patch
- `${input:patchOperation}` - PowerShell code to execute
- `${input:testCommand}` - Test command to run
- `${input:priority}` - Issue priority level

## 🔍 Advanced Features

### Intelligent Branch Naming

Branches are automatically named with timestamp and sanitized description:
```
patch/20240622-154530-Fix-module-loading-issue-in-LabRunner
patch/20240622-160215-Add-input-validation-to-configuration-parser
```

### Unicode and Emoji Sanitization

All commit messages and branch names are automatically sanitized:
```powershell
# Input: "Fix 🐛 in module with unicode café"
# Output: "Fix bug in module with unicode cafe"
```

### Automatic Issue/PR Linking

When creating both issues and PRs, they're automatically linked:
- Issue numbers are referenced in PR descriptions
- PRs include "Closes #123" for automatic issue closing
- Related commits are cross-referenced

### Cross-Platform Support

All operations work identically on Windows, Linux, and macOS:
- Path handling uses cross-platform functions
- Git operations are normalized
- File operations respect platform conventions

### Error Recovery

Robust error handling with automatic recovery:
- Failed operations are logged with context
- Automatic rollback suggestions on errors
- Backup creation before destructive operations
- Detailed error messages with resolution steps

## 🎯 Best Practices

### 1. Descriptive Patch Descriptions
```powershell
# ✅ Good
-PatchDescription "Fix authentication timeout in remote connections"

# ❌ Avoid
-PatchDescription "fix stuff"
```

### 2. Atomic Changes
```powershell
# ✅ Good - Single responsibility
Invoke-PatchWorkflow -PatchDescription "Add input validation to user registration" -PatchOperation {
    # Only validation-related changes
}

# ❌ Avoid - Multiple unrelated changes
Invoke-PatchWorkflow -PatchDescription "Fix validation and update docs and refactor database" -PatchOperation {
    # Too many unrelated changes
}
```

### 3. Always Include Tests
```powershell
# ✅ Always include relevant tests
-TestCommands @(
    "pwsh -File tests/unit/modules/MyModule/MyModule-Core.Tests.ps1",
    "Import-Module './aither-core/modules/MyModule' -Force"
)
```

### 4. Use Appropriate Target Forks
```powershell
# ✅ Features for upstream
-TargetFork "upstream" -CreatePR

# ✅ Bug fixes for current development
# (no TargetFork parameter - defaults to current)

# ✅ Critical issues for production
-TargetFork "root" -Priority "Critical"
```

### 5. Preview with DryRun
```powershell
# ✅ Always preview complex operations first
Invoke-PatchWorkflow -PatchDescription "Complex refactoring" -PatchOperation {
    # Complex changes
} -DryRun

# Then execute without -DryRun when satisfied
```

## 🚨 Common Issues and Solutions

### Issue: "Working tree is dirty"
**Solution**: This is now handled automatically! v2.1 auto-commits existing changes.

### Issue: "GitHub CLI not authenticated"
**Solution**: Run `gh auth login` to authenticate with GitHub.

### Issue: "Remote 'upstream' not found"
**Solution**: Add upstream remote: `git remote add upstream https://github.com/Aitherium/AitherLabs.git`

### Issue: "Module import failed"
**Solution**: Ensure you're in the project root and modules exist:
```powershell
. "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
Import-Module "$projectRoot/aither-core/modules/PatchManager" -Force
```

### Issue: "Tests failed"
**Solution**: Fix test failures before proceeding, or use `-SkipTests` for urgent fixes (not recommended).

## 📊 Monitoring and Logs

### Log Files
- **Operations**: `logs/patchmanager-operations-{date}.log`
- **Errors**: `logs/automated-error-tracking.json`
- **Git Operations**: `.git/logs/`

### Monitoring Commands
```powershell
# View recent operations
Get-Content "logs/patchmanager-operations-$(Get-Date -Format 'yyyy-MM-dd').log" -Tail 50

# Check error tracking
Get-Content "logs/automated-error-tracking.json" | ConvertFrom-Json | Select-Object -Last 10
```

---

*PatchManager v2.1 represents the pinnacle of Git workflow automation, making complex operations simple, reliable, and intelligent.*
