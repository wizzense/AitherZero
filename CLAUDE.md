# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AitherZero is a **standalone PowerShell automation framework** for OpenTofu/Terraform infrastructure management. It provides enterprise-grade infrastructure as code (IaC) automation with comprehensive testing and modular architecture.

**Technology Stack:**
- Primary Language: PowerShell 7.0+
- Infrastructure: OpenTofu/Terraform
- Testing: Pester framework
- CI/CD: GitHub Actions

## Common Development Commands

### Running the Application

```powershell
# Interactive mode (default)
./Start-AitherZero.ps1

# Automated mode
./Start-AitherZero.ps1 -Auto

# Run specific modules
./Start-AitherZero.ps1 -Scripts "LabRunner,BackupManager"

# First-time setup wizard with installation profiles
./Start-AitherZero.ps1 -Setup
./Start-AitherZero.ps1 -Setup -InstallationProfile minimal
./Start-AitherZero.ps1 -Setup -InstallationProfile developer
./Start-AitherZero.ps1 -Setup -InstallationProfile full

# Preview mode
./Start-AitherZero.ps1 -WhatIf
```

### Testing Commands

```powershell
# Quick validation (30 seconds) - Use for rapid feedback during development
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick

# Standard validation (2-5 minutes) - Use before creating PRs
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Standard

# Complete validation (10-15 minutes) - Use for release preparation
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Complete

# CI mode with fail-fast
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Standard -CI -FailFast

# Run all module tests
./tests/Run-AllModuleTests.ps1

# Run specific module tests
./tests/Invoke-DynamicTests.ps1 -ModuleName "PatchManager"
./tests/Invoke-DynamicTests.ps1 -ModuleName "SetupWizard"
./tests/Invoke-DynamicTests.ps1 -ModuleName "ProgressTracking"

# Test change detection
./tests/Test-ChangeDetection.ps1

# Code coverage analysis
./tests/Run-CodeCoverage.ps1

# Launcher functionality tests
./tests/Test-LauncherFunctionality.ps1

# Performance monitoring tests
./Test-PerformanceMonitoring.ps1

# Quickstart experience testing
./tests/Run-BulletproofValidation.ps1 -QuickstartSimulation -CrossPlatformTesting
```

### Linting Commands

```powershell
# PowerShell analysis (use VS Code task or manual PSScriptAnalyzer)
Invoke-ScriptAnalyzer -Path . -Recurse
```


### Release Management Commands

```powershell
# AUTOMATED RELEASE WORKFLOW - One command does everything!
Import-Module ./aither-core/modules/PatchManager -Force

# Patch release (1.2.3 -> 1.2.4)
Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Bug fixes and improvements"

# Minor release (1.2.3 -> 1.3.0)
Invoke-ReleaseWorkflow -ReleaseType "minor" -Description "New features added"

# Major release (1.2.3 -> 2.0.0)
Invoke-ReleaseWorkflow -ReleaseType "major" -Description "Breaking changes"

# Specific version release
Invoke-ReleaseWorkflow -Version "1.2.14" -Description "Critical security fix"

# With auto-merge (requires permissions)
Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Automated patch" -AutoMerge

# Dry run to preview
Invoke-ReleaseWorkflow -ReleaseType "minor" -Description "Test release" -DryRun

# The command handles EVERYTHING:
# ✓ Updates VERSION file
# ✓ Creates PR with proper description
# ✓ Waits for PR merge (optional)
# ✓ Automatically creates and pushes release tag
# ✓ Monitors build pipeline
# ✓ No manual steps required!

# Manual approach (if needed):
# After PR is merged, tag and push the release
git checkout main
git pull
$version = Get-Content "VERSION" -Raw
git tag -a "v$($version.Trim())" -m "Release v$($version.Trim())"
git push origin "v$($version.Trim())"

# Monitor release build
gh run list --workflow="Build & Release Pipeline" --limit 1
gh run watch
```

### Quick Release Workflow

```powershell
# RECOMMENDED: Use PatchManager's built-in release automation
Import-Module ./aither-core/modules/PatchManager -Force
Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Bug fixes and improvements"

# Alternative: Standalone script (creates PR only, manual tag required)
./scripts/Create-Release.ps1 -ReleaseType "patch" -Description "Bug fixes and improvements"

# Alternative: Full automation script
./scripts/Create-AutomatedRelease.ps1 -ReleaseType "patch" -Description "Bug fixes" -SkipPR
```

### Build Testing Commands

```powershell
# Test build locally before release
./build/Build-Package.ps1 -Platform "windows" -Version "test" -ArtifactExtension "zip" -PackageProfile "standard"

# Test all profiles
@("minimal", "standard", "full") | ForEach-Object {
    ./build/Build-Package.ps1 -Platform "windows" -Version "test" -ArtifactExtension "zip" -PackageProfile $_
}

# Validate build output
./tests/Test-BuildOutput.ps1 -Platform "windows" -Profile "standard"
```
### GitHub Actions Workflows

The project uses a unified CI/CD pipeline with 3 streamlined workflows:

```bash
# Intelligent CI/CD Pipeline - Main testing and validation
# Triggers: Push to main/develop, PRs, manual dispatch
# Features: Smart change detection, cross-platform testing, security analysis

# Build & Release Pipeline - Package building and releases  
# Triggers: Version tags (v*), manual dispatch
# Features: Multi-profile builds (minimal/standard/full), cross-platform packages

# Documentation & Sync Pipeline - Documentation and repository sync
# Triggers: Documentation changes, daily schedule, manual dispatch
# Features: API documentation generation, repository synchronization
```

#### Workflow Commands

```bash
# Trigger workflows manually
gh workflow run "Intelligent CI/CD Pipeline"
gh workflow run "Build & Release Pipeline" 
gh workflow run "Documentation & Sync Pipeline"

# Monitor workflow status
gh run list --workflow="Intelligent CI/CD Pipeline"
gh run watch

# View workflow logs
gh run view --log
```

### AI Tools Integration Commands

```powershell
# Install Claude Code
Import-Module ./aither-core/modules/AIToolsIntegration -Force
Install-ClaudeCode

# Install Gemini CLI
Install-GeminiCLI

# Get AI tools status
Get-AIToolsStatus

# Update all AI tools
Update-AITools

# Remove AI tools
Remove-AITools -Tools @('claude-code')
```

### Configuration Management Commands

```powershell
# Configuration Carousel - Switch between configuration sets
Import-Module ./aither-core/modules/ConfigurationCarousel -Force

# List available configurations
Get-AvailableConfigurations

# Switch to a different configuration
Switch-ConfigurationSet -ConfigurationName "my-custom-config" -Environment "dev"

# Add a new configuration repository
Add-ConfigurationRepository -Name "team-config" -Source "https://github.com/myorg/aither-config.git"

# Backup current configuration
Backup-CurrentConfiguration -Reason "Before testing new setup"

# Configuration Repository Management
Import-Module ./aither-core/modules/ConfigurationRepository -Force

# Create a new configuration repository
New-ConfigurationRepository -RepositoryName "my-aither-config" -LocalPath "./my-config" -Template "default"

# Clone an existing configuration repository
Clone-ConfigurationRepository -RepositoryUrl "https://github.com/user/config.git" -LocalPath "./custom-config"

# Sync configuration repository
Sync-ConfigurationRepository -Path "./my-config" -Operation "sync"
```

### Orchestration Engine Commands

```powershell
# Import orchestration engine
Import-Module ./aither-core/modules/OrchestrationEngine -Force

# Run a playbook
Invoke-PlaybookWorkflow -PlaybookName "sample-deployment" -Parameters @{environment="dev"; deployTarget="lab-01"}

# Create a new playbook definition
$playbook = New-PlaybookDefinition -Name "my-workflow" -Description "Custom deployment workflow"

# Get workflow status
Get-PlaybookStatus

# Stop a running workflow
Stop-PlaybookWorkflow -WorkflowId "workflow-20250629-123456-1234"

# Create step definitions
$step1 = New-ScriptStep -Name "Setup" -Command "Write-Host 'Setting up environment'"
$step2 = New-ConditionalStep -Name "Conditional Deploy" -Condition "`$env.context -eq 'prod'" -ThenSteps @($deployStep)
$step3 = New-ParallelStep -Name "Parallel Tasks" -ParallelSteps @($task1, $task2, $task3)
```

## Architecture and Code Structure

### Module System

AitherZero uses a modular PowerShell architecture with 18+ specialized modules:

- **LabRunner**: Lab automation orchestration
- **PatchManager**: Git workflow automation with PR/issue creation
- **BackupManager**: File backup and consolidation
- **DevEnvironment**: Development environment setup
- **OpenTofuProvider**: Infrastructure deployment
- **ISOManager/ISOCustomizer**: ISO management and customization
- **ParallelExecution**: Runspace-based parallel processing
- **Logging**: Centralized logging across all operations
- **TestingFramework**: Pester-based testing integration
- **SecureCredentials**: Enterprise credential management
- **RemoteConnection**: Multi-protocol remote connections
- **SystemMonitoring**: System performance monitoring
- **CloudProviderIntegration**: Cloud provider abstractions
- **SetupWizard**: Enhanced first-time setup with installation profiles
- **AIToolsIntegration**: AI development tools management (Claude Code, Gemini, etc.)
- **ConfigurationCarousel**: Multi-environment configuration management
- **ConfigurationRepository**: Git-based configuration repository management
- **OrchestrationEngine**: Advanced workflow and playbook execution

### Module Structure Pattern

Each module follows this structure:
```
ModuleName/
├── ModuleName.psd1         # Module manifest
├── ModuleName.psm1         # Module script
├── Public/                 # Exported functions
├── Private/               # Internal functions
└── tests/                 # Module-specific tests
```

### Important Patterns

#### Path Handling
Always use `Join-Path` for cross-platform compatibility:
```powershell
# Correct
$configPath = Join-Path $projectRoot "configs" "app-config.json"

# Wrong
$configPath = "$projectRoot/configs/app-config.json"
```

#### Module Imports
```powershell
# Always use Find-ProjectRoot
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Import modules with -Force
Import-Module (Join-Path $projectRoot "aither-core/modules/ModuleName") -Force
```

#### Logging
Use the centralized logging module:
```powershell
Write-CustomLog -Level 'INFO' -Message "Operation started"
Write-CustomLog -Level 'ERROR' -Message "Error: $($_.Exception.Message)"
Write-CustomLog -Level 'SUCCESS' -Message "Operation completed"
Write-CustomLog -Level 'WARNING' -Message "Potential issue detected"
Write-CustomLog -Level 'DEBUG' -Message "Debug information"
```

#### Error Handling
```powershell
try {
    # Main logic
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Error: $($_.Exception.Message)"
    throw
}
```

#### Platform-Aware Code
```powershell
if ($IsWindows) {
    # Windows-specific code
} elseif ($IsLinux) {
    # Linux-specific code
} elseif ($IsMacOS) {
    # macOS-specific code
}
```

### PatchManager Workflows

**IMPORTANT**: Use PatchManager for ALL Git operations:

```powershell
# Standard workflow - creates issue and PR
Invoke-PatchWorkflow -PatchDescription "Clear description" -PatchOperation {
    # Your changes here
} -CreatePR

# Local-only changes
Invoke-PatchWorkflow -PatchDescription "Local fix" -CreateIssue:$false -PatchOperation {
    # Your changes
}

# Emergency rollback
Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup

# Validate module manifest
Invoke-PatchValidation -ModuleName "ModuleName"
```

### Git Workflow Best Practices - PREVENTING BRANCH DIVERGENCE

**CRITICAL**: Follow these practices to prevent branch divergence and merge conflicts:

#### Before Starting Any Work

```powershell
# ALWAYS sync with remote before making changes
Import-Module ./aither-core/modules/PatchManager -Force

# Sync current branch with remote
Sync-GitBranch -Force

# Or if you need to fix existing divergence
./scripts/Fix-GitDivergence.ps1
```

#### PatchManager Automatic Sync

PatchManager v2.1+ automatically syncs with remote before creating branches:
- Fetches latest from origin/main
- Detects if local main is behind/ahead/diverged
- Resets local main to match remote if diverged
- Creates new branches from synchronized main

#### Manual Git Operations (AVOID THESE)

**DO NOT** use these commands directly - use PatchManager instead:
```powershell
# DON'T DO THIS:
git checkout -b feature-branch  # Creates from potentially outdated local
git commit -m "message"         # May cause conflicts
git merge                       # Can create divergence

# DO THIS INSTEAD:
Invoke-PatchWorkflow -PatchDescription "Your feature" -PatchOperation {
    # Your changes
} -CreatePR
```

#### Fixing Divergence Issues

If branches have already diverged:

```powershell
# Option 1: Use the fix script
./scripts/Fix-GitDivergence.ps1 -Force

# Option 2: Use Sync-GitBranch
Sync-GitBranch -BranchName "main" -Force -CleanupOrphaned -ValidateTags

# Option 3: Manual fix (last resort)
git checkout main
git fetch origin main
git reset --hard origin/main  # WARNING: Loses local commits
```

#### Preventing Common Issues

1. **Always use PatchManager** for all git operations
2. **Never commit directly to main** - PatchManager prevents this
3. **Sync before starting work** - Run `Sync-GitBranch` first
4. **Let PatchManager handle branches** - It auto-syncs and prevents conflicts
5. **Don't cherry-pick between branches** - Creates divergence
6. **Avoid manual merges** - Use PR process instead

#### Daily Workflow

```powershell
# Start of day
Sync-GitBranch -Force

# Create new feature
Invoke-PatchWorkflow -PatchDescription "New feature" -PatchOperation {
    # Make changes
} -CreatePR

# After PR is merged
Invoke-PostMergeCleanup -BranchName "patch/your-branch"
```

### Dynamic Repository Detection

The project works across fork chains (AitherZero → AitherLabs → Aitherium):
```powershell
$repoInfo = Get-GitRepositoryInfo
$targetRepo = "$($repoInfo.Owner)/$($repoInfo.Name)"
```

### SetupWizard Usage

```powershell
# Run intelligent setup wizard
Import-Module ./aither-core/modules/SetupWizard -Force
$setupResult = Start-IntelligentSetup

# Run minimal setup for CI/CD environments
$setupResult = Start-IntelligentSetup -MinimalSetup -SkipOptional

# Generate platform-specific quick start guide
Generate-QuickStartGuide -SetupState $setupResult
```

### ProgressTracking Usage

```powershell
# Track long-running operations with visual progress
Import-Module ./aither-core/modules/ProgressTracking -Force

# Start tracking an operation
$operationId = Start-ProgressOperation -OperationName "Deploying Infrastructure" -TotalSteps 10 -ShowTime -ShowETA

# Update progress
Update-ProgressOperation -OperationId $operationId -IncrementStep -StepName "Creating VMs"

# Complete operation with summary
Complete-ProgressOperation -OperationId $operationId -ShowSummary

# Multi-operation tracking
$operations = @(
    @{Name = "Module Loading"; Steps = 5},
    @{Name = "Environment Setup"; Steps = 8},
    @{Name = "Validation"; Steps = 3}
)
$multiOps = Start-MultiProgress -Title "AitherZero Initialization" -Operations $operations
```

### Event System Usage

```powershell
# Subscribe to events
Subscribe-TestEvent -EventName "ModuleLoaded" -Action {
    param($EventData)
    Write-CustomLog -Level 'INFO' -Message "Module loaded: $($EventData.ModuleName)"
}

# Publish events
Publish-TestEvent -EventName "ModuleLoaded" -EventData @{
    ModuleName = "PatchManager"
    Version = "2.1.0"
}
```

## VS Code Integration

The project includes 100+ pre-configured VS Code tasks in `.vscode/tasks.json`:

- **Testing**: Quick/Standard/Complete validation tasks
- **PatchManager**: Create patches, rollback, validate modules
- **Development**: Setup environment, import modules
- **Build**: Create local packages for different platforms
- **OpenTofu**: Plan and apply infrastructure changes

Access tasks via: `Ctrl+Shift+P → Tasks: Run Task`

### When to Use VS Code Tasks vs Command Line

- **VS Code Tasks**: When working in VS Code and needing visual feedback
- **Command Line**: For automation, CI/CD, or scripting
- **PatchManager**: For all Git operations regardless of interface

## Key Files and Locations

- **Entry Point**: `Start-AitherZero.ps1`
- **Core Application**: `aither-core/aither-core.ps1`
- **Modules**: `aither-core/modules/`
- **Shared Utilities**: `aither-core/shared/`
- **Tests**: `tests/`
- **Configurations**: `configs/`
- **OpenTofu Templates**: `opentofu/`
- **VS Code Configuration**: `.vscode/`
- **GitHub Workflows**: `.github/workflows/`

## Development Guidelines

1. **PowerShell Version**: Always target PowerShell 7.0+ with cross-platform compatibility
2. **Testing**: Run Quick validation before commits, Standard before PRs
3. **Logging**: Use Write-CustomLog for all output
4. **Paths**: Use Join-Path for all path construction
5. **Git Operations**: Use PatchManager, never direct git commands
6. **Module Dependencies**: Import existing modules rather than reimplementing
7. **Error Handling**: Comprehensive try-catch with logging
8. **Code Style**: One True Brace Style (OTBS) with consistent formatting
9. **Platform Awareness**: Use $IsWindows, $IsLinux, $IsMacOS for conditional logic
10. **Event System**: Use Publish-TestEvent/Subscribe-TestEvent for decoupled communication

## Important Notes

- The main branch is `main` (not master)
- **CRITICAL: Always sync with remote before starting work** - Use `Sync-GitBranch -Force`
- **NEVER commit directly to main** - Always use PatchManager workflows
- **Fix divergence immediately** - Run `./scripts/Fix-GitDivergence.ps1` if branches diverge
- GitHub Actions run on develop branch and PRs
- The project supports Windows, Linux, and macOS
- Always use absolute paths with platform-agnostic construction
- PatchManager v2.1 is consolidated to 4 core functions (now includes Sync-GitBranch)
- PatchManager automatically syncs with remote to prevent merge conflicts
- Bulletproof validation has four levels: Quick (30s), Standard (2-5m), Complete (10-15m), Quickstart (new user validation)
- SetupWizard provides intelligent first-time setup with progress tracking and installation profiles
- Installation profiles: minimal (infrastructure only), developer (includes AI tools), full (everything)
- ProgressTracking module offers visual feedback for long-running operations
- Configuration Carousel enables easy switching between multiple configuration sets
- Configuration repositories support Git-based custom configurations with multi-environment support
- Orchestration Engine provides advanced workflow execution with conditional logic and parallel processing
- AI Tools Integration automates installation and management of Claude Code, Gemini CLI, and other AI tools
- Module manifests should specify PowerShellVersion 7.0 minimum
- Use VS Code tasks for interactive development, command line for automation
- Quickstart validation includes platform detection, dependency checking, and guided setup

## Progressive Enhancement Methodology

When implementing features:
1. Start with basic functionality
2. Add error handling and validation
3. Implement logging and monitoring
4. Add cross-platform support
5. Integrate with event system
6. Add comprehensive tests
7. Document with examples

## Tool Selection Guidelines

- **Simple file operations**: Use PowerShell cmdlets
- **Complex Git workflows**: Use PatchManager
- **Parallel operations**: Use ParallelExecution module
- **Remote operations**: Use RemoteConnection module
- **Infrastructure deployment**: Use OpenTofuProvider module
- **Testing**: Use TestingFramework module with Pester
- **First-time setup**: Use SetupWizard module for intelligent setup
- **Long-running operations**: Use ProgressTracking module for visual feedback
- **New user onboarding**: Use quickstart validation and setup wizard
- **Environment validation**: Use bulletproof validation with appropriate level

## Important Reminders

- **IMPORTANT: ALWAYS USE PATCHMANAGER**
  - For ALL Git operations, no exceptions
  - Creates consistent workflow tracking
  - Ensures proper issue and PR management
  - Provides rollback and validation capabilities