# Contributing to AitherZero

Welcome to AitherZero! We're excited to have you contribute to our PowerShell-based infrastructure automation framework.

## 🚀 Quick Start for Contributors

### Prerequisites
- **PowerShell 7.0+** (cross-platform compatible)
- **Git** for version control
- **GitHub CLI** (optional but recommended)

### Getting Started
1. **Fork the repository** on GitHub
2. **Clone your fork**:
   ```powershell
   git clone https://github.com/yourusername/AitherZero.git
   cd AitherZero
   ```
3. **Follow the [Developer Onboarding Guide](docs/DEVELOPER-ONBOARDING.md)**
4. **Run initial setup**:
   ```powershell
   ./aither-core/aither-core.ps1 -Verbosity detailed
   ```

## 🔄 Development Workflow (Using PatchManager)

AitherZero uses **PatchManager v2.1** for all development workflows. This provides automated:
- ✅ Issue creation and tracking
- ✅ Branch management
- ✅ Pull request creation
- ✅ GitHub integration

### Creating Changes with PatchManager

```powershell
# Import PatchManager
Import-Module './aither-core/modules/PatchManager/PatchManager.psm1' -Force

# Make your changes using the automated workflow
Invoke-PatchWorkflow -PatchDescription "Add new feature X" -PatchOperation {
    # Your code changes here
    Write-Host "Making changes..."
} -CreatePR -Priority "Medium"
```

### Key PatchManager Features
- **Automatic dirty tree handling** - no need to commit changes first
- **Issue creation by default** - automatic tracking
- **Single-step workflow** - from changes to PR in one command
- **Testing integration** - validates changes before commit

## 📋 Code Standards

### PowerShell Guidelines
- **PowerShell 7.0+ syntax** - cross-platform compatible
- **Forward slashes** for all file paths (`/`)
- **One True Brace Style (OTBS)** for formatting
- **Comprehensive error handling** with try-catch blocks
- **Logging integration** using the Logging module

### Module Architecture
- Import modules from `aither-core/modules` using `Import-Module -Force`
- Use existing modules instead of creating new functionality:
  - **BackupManager** - File operations
  - **DevEnvironment** - Environment setup
  - **LabRunner** - Lab automation
  - **Logging** - Use `Write-CustomLog -Level 'INFO|WARN|ERROR|SUCCESS' -Message 'text'`
  - **PatchManager** - Git workflows
  - **TestingFramework** - Pester testing

### Function Structure
```powershell
function Get-ExampleFunction {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$InputParameter
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting $($MyInvocation.MyCommand.Name)"
    }

    process {
        try {
            # Your logic here
            Write-CustomLog -Level 'INFO' -Message "Processing $InputParameter"
        }
        catch {
            Write-CustomLog -Level 'ERROR' -Message "Error: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed $($MyInvocation.MyCommand.Name)"
    }
}
```

## 🧪 Testing Requirements

### Running Tests
```powershell
# Quick validation
./tests/Run-BulletproofValidation.ps1 -ValidationLevel 'Quick'

# Standard test suite
./tests/Run-BulletproofValidation.ps1 -ValidationLevel 'Standard'

# Complete testing
./tests/Run-BulletproofValidation.ps1 -ValidationLevel 'Complete'
```

### Test Guidelines
- **Pester 5.0+** framework
- **Comprehensive test coverage** for new features
- **Mock external dependencies** properly
- **Integration tests** for critical workflows

## 📝 Pull Request Process

### Using PatchManager (Recommended)
```powershell
# Complete workflow with PR creation
Invoke-PatchWorkflow -PatchDescription "Your feature description" -PatchOperation {
    # Your changes
} -CreatePR -TestCommands @("./tests/Run-BulletproofValidation.ps1 -ValidationLevel 'Standard'")
```

### Manual Process (Alternative)
1. Create feature branch from main
2. Make your changes
3. Run tests: `./tests/Run-BulletproofValidation.ps1`
4. Commit with descriptive messages
5. Push to your fork
6. Create pull request

### PR Requirements
- ✅ **Descriptive title and description**
- ✅ **All tests passing**
- ✅ **PSScriptAnalyzer compliance**
- ✅ **Documentation updates** (if applicable)
- ✅ **Issue linking** (automatic with PatchManager)

## 🏷️ Issue Management

### Using PatchManager for Issues
```powershell
# Create issue only
New-PatchIssue -Description "Bug description" -Priority "High" -AffectedFiles @("Module.psm1")

# Issues are created automatically with Invoke-PatchWorkflow
```

### Issue Labels (Auto-Applied)
- `patch` - Changes made via PatchManager
- `high-priority` - Critical issues
- `automated` - Automated processes
- `bug` - Bug reports
- `enhancement` - Feature requests

## 🔧 Development Environment

### VS Code Tasks
Use built-in VS Code tasks for common operations:
- **Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Create Feature Patch"**
- **Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Test Current Changes"**
- **Ctrl+Shift+P → Tasks: Run Task → "Tests: Run Bulletproof Validation"**

### Module Development
```powershell
# Import all modules for development
Get-ChildItem 'aither-core/modules' -Directory | ForEach-Object {
    Import-Module $_.FullName -Force
}

# Test module loading
Test-ModuleManifest 'aither-core/modules/YourModule/YourModule.psd1'
```

## 🚀 Release Management

### Creating Releases (Maintainers Only)

**IMPORTANT**: Always use `Invoke-ReleaseWorkflow` for creating releases. Never manually update VERSION files or create tags.

```powershell
# Import PatchManager
Import-Module './aither-core/modules/PatchManager' -Force

# Create a patch release
Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Bug fixes and improvements"

# Create a minor release
Invoke-ReleaseWorkflow -ReleaseType "minor" -Description "New features added"

# Create a major release
Invoke-ReleaseWorkflow -ReleaseType "major" -Description "Breaking changes"

# With auto-merge (requires permissions)
Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Automated patch" -AutoMerge

# Dry run to preview
Invoke-ReleaseWorkflow -ReleaseType "minor" -Description "Test release" -DryRun
```

### Release Process

The `Invoke-ReleaseWorkflow` command handles everything automatically:
1. ✅ Updates VERSION file
2. ✅ Creates PR with proper release notes
3. ✅ Waits for PR merge (optional)
4. ✅ Automatically creates and pushes release tag
5. ✅ Triggers build pipeline for release artifacts

### Alternative: GitHub Actions UI

You can also trigger releases from the GitHub Actions UI:
1. Go to Actions → Manual Release Creator
2. Click "Run workflow"
3. Select release type and enter description
4. The workflow uses `Invoke-ReleaseWorkflow` internally

## 🚨 Common Issues and Solutions

### PatchManager Workflow Fails
```powershell
# Check repository status
git status

# Use rollback if needed
Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup
```

### Module Import Issues
```powershell
# Force reimport
Import-Module './aither-core/modules/ModuleName' -Force -Verbose

# Check for errors
Get-Error
```

### Test Failures
```powershell
# Run specific module tests
./tests/Run-BulletproofValidation.ps1 -ValidationLevel 'Quick' -FailFast

# Check test logs
Get-ChildItem 'tests/results' -Filter '*.xml'
```

## 🌟 Best Practices

1. **Use PatchManager** for all changes - it handles Git, issues, and PRs automatically
2. **Test thoroughly** - use the bulletproof testing framework
3. **Follow logging standards** - use Write-CustomLog consistently
4. **Document changes** - update relevant documentation
5. **Cross-platform compatibility** - test on Windows, Linux, macOS when possible

## 📚 Additional Resources

- **[Developer Onboarding Guide](docs/DEVELOPER-ONBOARDING.md)** - Complete setup instructions
- **[PatchManager Guide](docs/PATCHMANAGER-COMPLETE-GUIDE.md)** - Detailed workflow documentation
- **[Testing Framework](docs/BULLETPROOF-TESTING-GUIDE.md)** - Testing best practices
- **[Architecture Overview](docs/COMPLETE-ARCHITECTURE.md)** - System design

## 🤝 Community Guidelines

- **Be respectful** and inclusive
- **Help others** learn and contribute
- **Share knowledge** through documentation
- **Ask questions** - we're here to help!

## 📧 Getting Help

- **Create an issue** for bugs or feature requests
- **Use GitHub Discussions** for questions
- **Check existing documentation** in the `docs/` folder
- **Review closed issues** for similar problems

Thank you for contributing to AitherZero! 🚀
