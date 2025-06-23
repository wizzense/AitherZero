# Developer Onboarding Guide - Aitherium Infrastructure Automation

## 🎯 Welcome to the Aitherium Ecosystem

This guide will get you up and running with the Aitherium Infrastructure Automation project, a sophisticated PowerShell-based automation framework designed for infrastructure as code (IaC) development, testing, and deployment.

## 🚀 Quick Start (5 Minutes)

### 1. Clone and Initial Setup

```powershell
# Clone your development fork
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# Set up the development environment
pwsh -File "core-runner/setup-test-env.ps1"

# Verify installation
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick"
```

### 2. VS Code Setup (Recommended)

```bash
# Open in VS Code
code .

# Install recommended extensions (if prompted)
# The workspace will suggest PowerShell, Pester, and other relevant extensions
```

### 3. First Development Task

```powershell
# Test the PatchManager workflow (the heart of the system)
Import-Module './aither-core/modules/PatchManager' -Force

# Create your first patch (this won't make any changes, just demonstrates the workflow)
Invoke-PatchWorkflow -PatchDescription "Test onboarding workflow" -CreateIssue:$false -PatchOperation {
    Write-Host "Hello from the Aitherium ecosystem!"
} -DryRun

# Success! You're ready to start developing.
```

## 🏗️ Understanding the Architecture

### Repository Structure Overview

```
AitherZero/                     # Your Development Fork
├── 🧠 aither-core/            # Core Framework
│   ├── 🔧 shared/             # Shared utilities (NEW!)
│   ├── 📦 modules/            # PowerShell modules
│   ├── 🛠️ scripts/           # Automation scripts
│   └── core-runner.ps1        # Main entry point
├── 🧪 tests/                  # Comprehensive test suite
├── ⚙️ configs/               # Configuration files
├── 🏗️ opentofu/             # Infrastructure as Code
├── 📚 docs/                  # Documentation
└── 🎨 .vscode/               # VS Code integration
```

### Fork Chain Understanding

```
🔨 Your Fork (AitherZero)  →  🌐 Public (AitherLabs)  →  💎 Premium (Aitherium)
   wizzense/AitherZero         Aitherium/AitherLabs      Aitherium/Aitherium
   Development workspace       Public staging            Premium features
```

**Key Insight**: The system automatically detects which repository you're in and adjusts all operations accordingly. You never need to hardcode repository names!

## 📚 Essential Knowledge Areas

### 1. PatchManager v2.1 - Your Primary Tool

PatchManager is the revolutionary Git workflow automation system. **Everything Git-related goes through PatchManager**.

#### Basic Usage Pattern

```powershell
# The ONE command that does everything:
Invoke-PatchWorkflow -PatchDescription "Clear description of what you're doing" -PatchOperation {
    # Your changes here - any working tree state is fine!
    $content = Get-Content "some-file.ps1" -Raw
    $content = $content -replace "old-pattern", "new-pattern"
    Set-Content "some-file.ps1" -Value $content
}

# What happens automatically:
# ✅ Saves any uncommitted work
# ✅ Creates a branch
# ✅ Creates a GitHub issue for tracking
# ✅ Applies your changes
# ✅ Commits with clean messages
# ✅ Ready for PR creation if needed
```

#### Advanced Usage

```powershell
# Feature development with full tracking
Invoke-PatchWorkflow -PatchDescription "Add new validation to config parser" -PatchOperation {
    # Your feature implementation
} -CreatePR -TestCommands @("pwsh -File tests/unit/modules/ConfigParser/ConfigParser.Tests.ps1")

# Cross-fork contribution (to upstream AitherLabs)
Invoke-PatchWorkflow -PatchDescription "Improve error handling" -TargetFork "upstream" -CreatePR -PatchOperation {
    # Improvements for upstream
}

# Emergency fix (to premium Aitherium)
Invoke-PatchWorkflow -PatchDescription "Critical security fix" -TargetFork "root" -Priority "Critical" -CreatePR -PatchOperation {
    # Critical fixes
}
```

### 2. Shared Utilities System

**ALWAYS use shared utilities** instead of implementing your own:

```powershell
# ✅ CORRECT: Use shared Find-ProjectRoot
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# ✅ Import patterns by location:
# From modules: . "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
# From tests:  . "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"

# ❌ WRONG: Don't implement your own
$projectRoot = Split-Path $PSScriptRoot -Parent  # Never do this
```

### 3. Testing Framework

Every change needs appropriate testing:

```powershell
# Quick validation (30 seconds) - Run this before every commit
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick"

# Standard validation (2-5 minutes) - Run before PRs
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Standard"

# Complete validation (10-15 minutes) - Run before releases
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Complete"
```

### 4. VS Code Integration

Use **Ctrl+Shift+P → Tasks: Run Task** for common operations:

- **"🚀 Bulletproof Validation - Quick"** - Fast testing
- **"🔧 PatchManager: Create Feature Patch"** - Interactive patch creation
- **"🏗️ Architecture: Validate Complete System"** - System health check
- **"📚 Documentation: Generate/Update All Docs"** - Documentation updates

## 🎯 Common Development Workflows

### 1. Bug Fix Workflow

```powershell
# 1. Identify the issue and understand the scope
# 2. Create a patch with descriptive information
Invoke-PatchWorkflow -PatchDescription "Fix module loading issue in LabRunner" -PatchOperation {
    # Apply your fix
    $content = Get-Content "aither-core/modules/LabRunner/LabRunner.psm1" -Raw
    $content = $content -replace 'Import-Module ([^-])', 'Import-Module $1 -Force'
    Set-Content "aither-core/modules/LabRunner/LabRunner.psm1" -Value $content
} -TestCommands @(
    "Import-Module './aither-core/modules/LabRunner' -Force",
    "pwsh -File tests/unit/modules/LabRunner/LabRunner-Core.Tests.ps1"
)

# 3. Validate with quick tests
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick"

# 4. If tests pass, create PR (if needed)
# Re-run with -CreatePR if you want a pull request
```

### 2. Feature Development Workflow

```powershell
# 1. Plan your feature and understand dependencies
# 2. Implement with full tracking
Invoke-PatchWorkflow -PatchDescription "Add input validation to configuration system" -PatchOperation {
    # Create validation module
    New-Item "aither-core/modules/ConfigValidator" -ItemType Directory -Force

    # Implement validator
    @"
function Test-ConfigurationInput {
    param([string]`$Input, [string]`$Pattern)
    return `$Input -match `$Pattern
}
"@ | Out-File "aither-core/modules/ConfigValidator/Public/Test-ConfigurationInput.ps1"

    # Update existing module to use validation
    $configModule = "aither-core/modules/ConfigManager/Public/Set-Configuration.ps1"
    $content = Get-Content $configModule -Raw
    $enhanced = $content -replace '(param\([^)]+\))', '$1`n    if (-not (Test-ConfigurationInput $Value "^[a-zA-Z0-9_-]+$")) { throw "Invalid input" }'
    Set-Content $configModule -Value $enhanced
} -CreatePR -TestCommands @(
    "Import-Module './aither-core/modules/ConfigValidator' -Force",
    "Import-Module './aither-core/modules/ConfigManager' -Force",
    "pwsh -File tests/unit/modules/ConfigValidator/ConfigValidator-Core.Tests.ps1"
) -Priority "Medium"

# 3. Run comprehensive tests
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Standard"
```

### 3. Cross-Fork Contribution Workflow

```powershell
# 1. Understand what would benefit the upstream community
# 2. Implement improvement for upstream
Invoke-PatchWorkflow -PatchDescription "Improve error handling in TestingFramework" -TargetFork "upstream" -PatchOperation {
    # Enhance error handling for the community
    $testingFramework = "aither-core/modules/TestingFramework/Public/Invoke-TestSuite.ps1"
    $content = Get-Content $testingFramework -Raw

    # Add comprehensive error handling
    $enhanced = $content -replace '(Invoke-Pester.*)', @'
try {
    $1
    Write-CustomLog -Level 'SUCCESS' -Message "Test suite completed successfully"
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Test suite failed: $($_.Exception.Message)"
    throw
}
'@
    Set-Content $testingFramework -Value $enhanced
} -CreatePR -Priority "High"

# Result: Issue created in AitherLabs, PR from AitherZero → AitherLabs
```

### 4. Documentation Update Workflow

```powershell
# Update documentation across the project
Invoke-PatchWorkflow -PatchDescription "Update documentation for v2.1 release" -PatchOperation {
    # Update README
    $readme = Get-Content "README.md" -Raw
    $readme = $readme -replace 'Version: .*', 'Version: 2.1'
    Set-Content "README.md" -Value $readme

    # Update repository-specific documentation
    Update-RepositoryDocumentation

    # Update module documentation
    Get-ChildItem "aither-core/modules/*/README.md" | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        $updated = $content -replace '## Version\s+[\d.]+', '## Version 2.1'
        Set-Content $_.FullName -Value $updated
    }
} -CreatePR -Priority "Low"
```

## 🔧 Development Environment Setup

### Required Tools

1. **PowerShell 7.0+** - Cross-platform PowerShell
2. **Git** - Version control
3. **GitHub CLI** (`gh`) - For GitHub operations
4. **VS Code** (Recommended) - Best development experience
5. **OpenTofu/Terraform** (Optional) - For infrastructure work

### Installation Commands

```powershell
# Windows (using winget)
winget install Microsoft.PowerShell
winget install Git.Git
winget install GitHub.cli
winget install Microsoft.VisualStudioCode

# macOS (using Homebrew)
brew install powershell git gh visual-studio-code

# Linux (Ubuntu/Debian)
sudo apt update
sudo apt install -y powershell git
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh
```

### GitHub Authentication

```powershell
# Authenticate with GitHub
gh auth login

# Verify authentication
gh auth status
```

### Environment Variables

```powershell
# These are set automatically, but good to know:
$env:PROJECT_ROOT          # Project root path (auto-detected)
$env:PWSH_MODULES_PATH     # PowerShell modules path
```

## 🧪 Testing Your Setup

### Comprehensive System Check

```powershell
# Run the comprehensive diagnostics
# Use VS Code: Ctrl+Shift+P → Tasks: Run Task → "🔍 Debug: Comprehensive System Diagnostics"

# Or run manually:
pwsh -Command @"
Write-Host '🔍 System Diagnostics' -ForegroundColor Cyan
Write-Host "PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor White
Write-Host "Platform: $($PSVersionTable.Platform)" -ForegroundColor White

. './aither-core/shared/Find-ProjectRoot.ps1'
$projectRoot = Find-ProjectRoot
Write-Host "Project Root: $projectRoot" -ForegroundColor White

Get-ChildItem '$projectRoot/aither-core/modules' -Directory | ForEach-Object {
    try {
        Import-Module $_.FullName -Force
        Write-Host "✅ $($_.Name): OK" -ForegroundColor Green
    } catch {
        Write-Host "❌ $($_.Name): FAILED" -ForegroundColor Red
    }
}
"@
```

### Test Each Component

```powershell
# 1. Test shared utilities
. "./aither-core/shared/Find-ProjectRoot.ps1"
$root = Find-ProjectRoot
Write-Host "Project root: $root"

# 2. Test PatchManager
Import-Module './aither-core/modules/PatchManager' -Force
$repoInfo = Get-GitRepositoryInfo
Write-Host "Repository: $($repoInfo.GitHubRepo)"

# 3. Test bulletproof validation
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick"

# 4. Test VS Code tasks
# Ctrl+Shift+P → Tasks: Run Task → "🚀 Bulletproof Validation - Quick"
```

## 🎯 Best Practices for New Developers

### 1. Always Start with Shared Utilities

```powershell
# ✅ Every function should start like this:
function My-NewFunction {
    [CmdletBinding()]
    param()

    begin {
        # Import shared utilities
        . "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot

        Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"
    }

    process {
        try {
            # Your logic here
            Write-CustomLog -Level 'INFO' -Message "Operation started"
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error: $($_.Exception.Message)"
            throw
        }
    }
}
```

### 2. Use PatchManager for All Git Operations

```powershell
# ✅ ALWAYS use PatchManager
Invoke-PatchWorkflow -PatchDescription "What you're doing" -PatchOperation { ... }

# ❌ NEVER use manual Git commands
git add . && git commit -m "manual commit"  # Don't do this
```

### 3. Test Everything

```powershell
# ✅ Test before committing
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick"

# ✅ Include test commands in patches
-TestCommands @("pwsh -File tests/unit/modules/MyModule/MyModule.Tests.ps1")
```

### 4. Use VS Code Tasks

```powershell
# ✅ Use tasks instead of manual commands
# Ctrl+Shift+P → Tasks: Run Task → "🔧 PatchManager: Create Feature Patch"

# Instead of writing PowerShell manually in terminal
```

### 5. Follow Naming Conventions

- **Functions**: `Verb-Noun` (e.g., `Get-Configuration`, `Set-ModuleProperty`)
- **Variables**: `$camelCase` (e.g., `$configPath`, `$moduleInfo`)
- **Parameters**: `PascalCase` (e.g., `-ModuleName`, `-ConfigPath`)
- **Files**: `PascalCase.ps1` (e.g., `Get-Configuration.ps1`)

## 🚨 Common Pitfalls and Solutions

### Issue: "Cannot find module"

**Solution**: Use shared utilities and proper import patterns:

```powershell
# ✅ Correct
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
Import-Module "$projectRoot/aither-core/modules/ModuleName" -Force
```

### Issue: "Working tree is dirty"

**Solution**: This is now handled automatically by PatchManager v2.1! Just use `Invoke-PatchWorkflow` normally.

### Issue: "GitHub CLI not authenticated"

**Solution**:

```powershell
gh auth login
gh auth status  # Verify
```

### Issue: "Tests are failing"

**Solution**:

```powershell
# 1. Run quick validation to see what's broken
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick"

# 2. Run specific module tests
Invoke-Pester -Path "tests/unit/modules/ModuleName" -Output Detailed

# 3. Check for common issues:
#    - Module import paths
#    - Missing shared utility imports
#    - Hardcoded repository references
```

### Issue: "Cross-fork operations not working"

**Solution**: Ensure upstream remotes are configured:

```powershell
# Add upstream remote (if missing)
git remote add upstream https://github.com/Aitherium/AitherLabs.git

# Add root remote (if missing)
git remote add root https://github.com/Aitherium/Aitherium.git

# Verify
git remote -v
```

## 🎓 Next Steps

### 1. Explore the Codebase

- Browse `aither-core/modules/` to understand existing modules
- Look at `tests/unit/modules/` to see testing patterns
- Read `docs/` for detailed documentation

### 2. Practice Workflows

- Create a test patch: `Invoke-PatchWorkflow -PatchDescription "Practice patch" -CreateIssue:$false -PatchOperation { Write-Host "Learning!" } -DryRun`
- Run different validation levels: Quick → Standard → Complete
- Try VS Code tasks: Ctrl+Shift+P → Tasks: Run Task

### 3. Contribute

- Fix a small bug using PatchManager
- Add tests for untested code
- Improve documentation
- Contribute to upstream repositories

### 4. Advanced Topics

- Learn OpenTofu/Terraform for infrastructure work
- Explore parallel execution patterns
- Understand cross-platform compatibility requirements
- Study security and performance optimization

## 📞 Getting Help

### Documentation Resources

- **Complete Architecture**: `docs/COMPLETE-ARCHITECTURE.md`
- **PatchManager Guide**: `docs/PATCHMANAGER-COMPLETE-GUIDE.md`
- **Testing Guide**: `docs/TESTING-COMPLETE-GUIDE.md`
- **Shared Utilities**: `aither-core/shared/README.md`

### VS Code Help

- **Tasks**: Ctrl+Shift+P → Tasks: Run Task → [Browse available tasks]
- **Diagnostics**: "🔍 Debug: Comprehensive System Diagnostics"
- **Quick Tests**: "🚀 Bulletproof Validation - Quick"

### GitHub Copilot Integration

The project has extensive GitHub Copilot integration. Copilot will automatically:
- Suggest correct import patterns
- Follow project architecture standards
- Generate appropriate error handling
- Create proper test structures
- Use shared utilities correctly

---

**Welcome to the Aitherium ecosystem! You're now equipped with everything you need to be productive and contribute effectively to this sophisticated automation framework.**
