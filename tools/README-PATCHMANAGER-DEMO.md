# PatchManager Comprehensive Demo

This directory contains a comprehensive demonstration script for the PatchManager module, showcasing its full functionality and capabilities.

## Overview

The `demo-patchmanager.ps1` script provides interactive demonstrations of:
- ✅ **Basic patch workflows** - Create, apply, and commit patches
- ✅ **Advanced patch features** - Test commands, validation, and automated commits
- ✅ **Rollback capabilities** - Patch rollback and recovery operations
- ✅ **GitHub issue integration** - Automated issue creation and tracking
- ✅ **Cross-platform features** - Path handling and compatibility
- ✅ **Command aliases** - Convenient shortcuts for daily use

## Quick Start

### Basic Demo
```powershell
# Run basic patch workflow demonstration
.\demo-patchmanager.ps1 -DemoMode Basic -DryRun
```

### Interactive Advanced Demo
```powershell
# Run advanced features with interactive prompts
.\demo-patchmanager.ps1 -DemoMode Advanced -Interactive
```

### Complete Demo Suite
```powershell
# Run all demonstrations
.\demo-patchmanager.ps1 -DemoMode All -DryRun
```

## Demo Modes

| Mode | Description | Features Demonstrated |
|------|-------------|----------------------|
| `Basic` | Essential patch operations | Patch creation, aliases |
| `Advanced` | Advanced features | Test commands, validation, auto-commit |
| `Rollback` | Recovery operations | Patch creation + rollback scenarios |
| `Issues` | GitHub integration | Issue tracking, automated creation |
| `CrossPlatform` | Platform compatibility | Path fixes, environment setup |
| `All` | Complete demonstration | All features above |

## Parameters

### `-DemoMode`
Choose which demonstration to run:
- `Basic` - Essential patch workflows
- `Advanced` - Advanced patch features
- `Rollback` - Rollback and recovery
- `Issues` - GitHub issue integration
- `CrossPlatform` - Cross-platform features
- `All` - Complete demonstration suite

### `-DryRun`
Run demonstrations without making actual changes to your repository. Recommended for first-time users.

### `-Interactive`
Enable interactive prompts between demo sections. Useful for learning and understanding each step.

### `-Quiet`
Minimize output for automated scenarios.

## What Each Demo Shows

### 🚀 Basic Patch Workflow
- Creates a simple patch with file modifications
- Demonstrates automatic branch creation
- Shows commit and branch naming conventions
- **Files created**: `demo-timestamp.txt`

### 🔧 Advanced Patch Features
- Patch creation with validation testing
- Test command execution and verification
- Automated commit with uncommitted changes
- **Files created**: `demo-config.json`

### ↩️ Rollback Capabilities
- Creates a patch specifically for rollback demonstration
- Performs rollback operation using `Invoke-PatchRollback`
- Shows recovery scenarios and branch cleanup
- **Files created**: `demo-rollback-test.txt` (then rolled back)

### 🐛 Issue Tracking
- Demonstrates GitHub issue integration
- Shows automated issue creation workflows
- Displays issue data structure and formatting
- **Note**: In dry-run mode, shows issue data without creating actual GitHub issues

### 🌍 Cross-Platform Features
- Initializes cross-platform environment variables
- Demonstrates path standardization capabilities
- Shows platform detection and compatibility features
- Tests environment variable setup

### ⚡ Command Aliases
- Sets up convenient PatchManager aliases
- Demonstrates available shortcut commands
- Shows alias configuration for daily workflow

## Expected Output

The demo provides rich, colorful output with:
- 📋 **Step indicators** for each demonstration phase
- ✅ **Success markers** for completed operations
-  FAIL**Error indicators** with detailed information
- 📊 **Statistics summary** at completion
- 🎯 **Next steps** guidance

## Example Output
```
🚀 Starting PatchManager Comprehensive Demo
Demo Mode: Basic | Dry Run: True | Interactive: False

======================================================================
 🚀 PatchManager Demo: Basic Patch Workflow
======================================================================
   Create, apply, and commit a simple patch

📋 Step: 1. Creating a basic patch
   → Simple file modification with automatic commit
✅ Basic patch workflow completed successfully
   Branch: patch/20250618-194153-demo--basic-patch---update-demo-timestamp

📊 Demo Statistics:
   Duration: 00:02
   Tests Run: 2
   Tests Passed: 2
   Tests Failed: 0

🎉 All demonstrations completed successfully!
```

## Prerequisites

### Required Modules
- **PatchManager** - Core functionality
- **Logging** - Enhanced output (optional)

### Environment Variables
- `$env:PROJECT_ROOT` - Automatically detected or set to current directory
- `$env:PWSH_MODULES_PATH` - Set by PatchManager initialization

### Git Repository
- Must be run within a Git repository
- Git must be configured with user name and email
- Repository should have a `main` branch

## Safety Features

### Dry Run Mode
All demos support `-DryRun` mode which:
- ✅ Shows what operations would be performed
- ✅ Creates branch names and displays them
- ✅ Runs validation without making changes
-  FAILDoes not create actual files or commits
-  FAILDoes not push to remote repositories

### Error Handling
- Comprehensive error tracking and reporting
- Graceful degradation when modules are unavailable
- Clear error messages with troubleshooting guidance
- Automatic cleanup of failed operations

## Integration with PatchManager

The demo script uses the same PatchManager functions you would use in real scenarios:

```powershell
# Basic patch creation
Invoke-GitControlledPatch -PatchDescription "My patch" -PatchOperation { ... }

# Advanced patch with testing
Invoke-GitControlledPatch -PatchDescription "Advanced patch" `
    -PatchOperation { ... } `
    -TestCommands @("test-command-1", "test-command-2") `
    -AutoCommitUncommitted

# Rollback operations
Invoke-PatchRollback -BranchName "patch/..." -RollbackType "ResetToParent"
```

## Troubleshooting

### Module Import Errors
If you see module import errors:
```
⚠️  Could not import PatchManager module. Please ensure modules are available.
   Expected path: /path/to/aither-core/modules/PatchManager
```

**Solution**: Ensure you're running from the project root directory or set `$env:PROJECT_ROOT` correctly.

### Git Configuration Errors
If you see Git-related errors:
```
 FAILGit repository not properly configured
```

**Solution**: Ensure you're in a Git repository and have configured:
```bash
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

### Permission Errors
If you see permission-related errors:
```
 FAILFailed to create branch or commit
```

**Solution**:
- Run PowerShell as Administrator (Windows)
- Check file permissions in the repository directory
- Ensure Git has write access to the repository

## Advanced Usage

### Custom Demo Scenarios
You can modify the demo script to add your own scenarios:

```powershell
function Invoke-MyCustomDemo {
    Write-DemoHeader "My Custom Demo" "Description of what this demonstrates"

    try {
        Write-DemoStep "1. My custom step"

        $patchResult = Invoke-GitControlledPatch `
            -PatchDescription "My custom patch" `
            -PatchOperation {
                # Your custom operations here
                Write-Host "Performing custom operations..."
            } `
            -DryRun:$DryRun

        if ($patchResult.Success) {
            Write-DemoSuccess "Custom demo completed successfully"
        } else {
            Write-DemoError "Custom demo failed" $patchResult.Error
        }

    } catch {
        Write-DemoError "Custom demo encountered an exception" $_.Exception.Message
    }
}
```

### Automated Testing
Use the demo in CI/CD pipelines:

```powershell
# Automated validation in CI
.\demo-patchmanager.ps1 -DemoMode All -DryRun -Quiet
if ($LASTEXITCODE -ne 0) {
    Write-Error "PatchManager demo validation failed"
    exit 1
}
```

## Files Created

During demonstrations (when not using `-DryRun`), these temporary files may be created:
- `demo-timestamp.txt` - Basic demo timestamp file
- `demo-config.json` - Advanced demo configuration
- `demo-rollback-test.txt` - Rollback demo test file (then removed)

These files are safe to delete after the demonstration.

## Next Steps

After running the demo:

1. **Review created branches** - Use `git branch -a` to see demo branches
2. **Try manual patches** - Use `Invoke-GitControlledPatch` directly
3. **Set up aliases** - Run `Set-PatchManagerAliases` for daily use
4. **Explore advanced features** - Check automated error tracking
5. **Integrate with workflows** - Add PatchManager to your development process

## Support

For questions or issues:
- Review the PatchManager module documentation
- Check the project's GitHub repository
- Run the demo with `-Interactive` for step-by-step guidance
- Use `-DryRun` mode to safely explore functionality
