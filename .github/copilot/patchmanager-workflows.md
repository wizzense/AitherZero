# PatchManager Workflows - GitHub Copilot Instructions

This guide provides common patterns for using the PatchManager module in the Aitherium Infrastructure Automation project.

## Quick Start Commands

### 1. Create a Simple Patch
```powershell
Import-Module './aither-core/modules/PatchManager' -Force
Invoke-GitControlledPatch -PatchDescription "Fix issue XYZ" -DryRun
```

### 2. Apply Changes with Automated Testing
```powershell
Invoke-GitControlledPatch -PatchDescription "Update module functionality" `
    -PatchOperation {
        # Your changes here
        Update-ModuleFunction -Name "MyFunction"
    } `
    -TestCommands @(
        "pwsh -NoProfile -Command 'Import-Module ./aither-core/modules/TestingFramework -Force; Invoke-Pester'"
    ) `
    -AutoCommitUncommitted
```

### 3. Create Pull Request Workflow
```powershell
Invoke-GitControlledPatch -PatchDescription "Feature: New functionality" `
    -CreatePullRequest `
    -AutoCommitUncommitted `
    -TestCommands @("pwsh tests/Run-BulletproofTests.ps1 -TestSuite Quick")
```

## Common Patterns

### Error Handling with Issue Creation
```powershell
Invoke-MonitoredExecution -ScriptBlock {
    # Your risky operation here
    Invoke-ComplexOperation
} -Context @{
    Task = "Complex Operation"
    Environment = "Development"
} -CreateIssues -ErrorHandling "Comprehensive"
```

### Automated Error Tracking
```powershell
try {
    # Your operation
    Invoke-SomeOperation
} catch {
    Invoke-AutomatedErrorTracking -ErrorRecord $_ `
        -SourceFunction "Invoke-SomeOperation" `
        -Priority "High" `
        -AlwaysCreateIssue
}
```

### Enhanced Git Operations
```powershell
# Clean up and validate repository state
Invoke-EnhancedGitOperations -ValidateAfter

# With automatic validation
Invoke-EnhancedGitOperations -AutoValidate
```

## VS Code Tasks Integration

Use these tasks from the Command Palette (Ctrl+Shift+P → "Tasks: Run Task"):

- **PatchManager: Create Patch Branch** - Interactive patch creation
- **PatchManager: Apply Changes with Validation** - Apply changes with tests
- **PatchManager: Create PR with Tests** - Full workflow with PR creation
- **PatchManager: Quick Fix Workflow** - Streamlined fix process
- **PatchManager: Monitored Execution** - Execute with comprehensive monitoring

## Best Practices

1. **Always use DryRun first** to validate your patch operations
2. **Include test commands** for any significant changes
3. **Use descriptive patch descriptions** for better tracking
4. **Enable error tracking** for complex operations
5. **Validate git state** after operations

## Examples by Scenario

### Scenario: Bug Fix
```powershell
Invoke-GitControlledPatch -PatchDescription "Fix: Resolve null reference in logging" `
    -PatchOperation {
        # Fix the bug
        $content = Get-Content "./aither-core/modules/Logging/Logging.psm1"
        $content = $content -replace 'problematic pattern', 'fixed pattern'
        Set-Content "./aither-core/modules/Logging/Logging.psm1" -Value $content
    } `
    -TestCommands @("pwsh tests/unit/modules/Logging/Logging.Tests.ps1") `
    -AutoCommitUncommitted
```

### Scenario: Feature Addition
```powershell
Invoke-GitControlledPatch -PatchDescription "Feature: Add new backup retention policy" `
    -CreatePullRequest `
    -TestCommands @(
        "pwsh tests/Run-BulletproofTests.ps1 -TestSuite Modules",
        "pwsh tests/integration/BackupManager.Integration.Tests.ps1"
    )
```

### Scenario: Maintenance Task
```powershell
Invoke-MonitoredExecution -ScriptBlock {
    # Cleanup old files
    Get-ChildItem "./logs" -Filter "*.old" | Remove-Item -Force

    # Update dependencies
    Update-ModuleDependencies
} -Context @{
    Task = "Weekly Maintenance"
    Scheduled = $true
} -CreateIssues
```
