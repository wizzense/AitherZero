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

### Developer Setup - ONE COMMAND! 🚀

```powershell
# Unified developer setup (recommended)
./Start-DeveloperSetup.ps1

# Quick setup (minimal, fast)
./Start-DeveloperSetup.ps1 -Profile Quick

# Full setup (all tools and features)
./Start-DeveloperSetup.ps1 -Profile Full

# Custom setup options
./Start-DeveloperSetup.ps1 -SkipAITools -SkipGitHooks
```

**What the developer setup includes:**
- ✅ Prerequisites validation (PowerShell 7, Git, etc.)
- ✅ Core development environment configuration
- ✅ VS Code settings and extensions
- ✅ Git pre-commit hooks
- ✅ AI development tools (Claude Code, Gemini CLI)
- ✅ PatchManager aliases and shortcuts
- ✅ Module path configuration

### Testing Commands - SIMPLE & FAST! 🚀

```powershell
# Run tests (default - core functionality, <30 seconds)
./tests/Run-Tests.ps1

# Test setup/installation experience
./tests/Run-Tests.ps1 -Setup

# Run all tests
./tests/Run-Tests.ps1 -All

# CI mode (for GitHub Actions)
./tests/Run-Tests.ps1 -All -CI
```

That's it! No complexity, no 15-minute test runs, no confusion.

### Linting Commands

```powershell
# PowerShell analysis (use VS Code task or manual PSScriptAnalyzer)
Invoke-ScriptAnalyzer -Path . -Recurse
```

### CRITICAL: PowerShell Access in WSL/Linux

**ALWAYS USE THIS PATH FOR POWERSHELL:**
```bash
# PowerShell 7 is located at:
/mnt/c/Program\ Files/PowerShell/7/pwsh.exe

# Alias already created:
alias pwsh='/mnt/c/Program\ Files/PowerShell/7/pwsh.exe'

# Usage examples:
pwsh -NoProfile -Command "Get-Host"
pwsh -NoProfile -File "./script.ps1"
```

**DO NOT FORGET THIS PATH. EVER.**


### Release Management - PAINLESS & AUTOMATED! 🚀

```powershell
# THE ONE AND ONLY RELEASE COMMAND:
./AitherRelease.ps1 -Version 1.2.3 -Message "Bug fixes"

# Or auto-increment version:
./AitherRelease.ps1 -Type patch -Message "Bug fixes"
./AitherRelease.ps1 -Type minor -Message "New features"
./AitherRelease.ps1 -Type major -Message "Breaking changes"

# Preview mode:
./AitherRelease.ps1 -Version 1.2.3 -Message "Test release" -DryRun
```

**What happens (fully automated):**
1. Creates a PR to update VERSION (respects branch protection)
2. Waits for CI checks to pass
3. Auto-merges the PR
4. Monitors release workflow
5. Reports when release is published

**That's it! No manual steps, no confusion, works every time!**

**Alternative: Use PatchManager's New-Release function:**
```powershell
Import-Module ./aither-core/modules/PatchManager -Force
New-Release -Version 1.2.3 -Message "Bug fixes"
```

### Build Commands - TRUE SIMPLICITY! 🎯

```powershell
# Build all platforms (default):
./build/Build-Package.ps1

# Build specific platform:
./build/Build-Package.ps1 -Platform windows
./build/Build-Package.ps1 -Platform linux
./build/Build-Package.ps1 -Platform macos

# Build with specific version:
./build/Build-Package.ps1 -Version "1.2.3"
```

**Output:**
- `AitherZero-v{version}-windows.zip` - Windows package
- `AitherZero-v{version}-linux.tar.gz` - Linux package  
- `AitherZero-v{version}-macos.tar.gz` - macOS package

No profiles. One package per platform. Dead simple.
### GitHub Actions Workflows - DEAD SIMPLE! 💯

The project has 6 GitHub Actions workflows:

**1. CI (ci.yml)** - Runs tests on every push/PR
- Triggers: Push to main/develop, all PRs
- What it does: Runs tests on Windows/Linux/macOS
- Runtime: ~2 minutes

**2. Release (release.yml)** - Creates releases manually
- Triggers: Manual dispatch only
- What it does: Creates tag, builds packages, publishes release
- Runtime: ~5 minutes

**3. Comprehensive Report (comprehensive-report.yml)** - 🆕 Complete auditing and HTML reporting system
- Triggers: Daily at 6 AM UTC, manual dispatch
- What it does: Generates comprehensive HTML reports with all audit data, feature maps, and health scores
- Runtime: ~10-15 minutes
- Outputs: Interactive HTML dashboard, downloadable from GitHub artifacts

**4. Audit (audit.yml)** - Documentation, testing, and duplicate detection
- Triggers: Weekly scheduled, PRs
- What it does: Audits documentation coverage, test analysis, duplicate detection

**5. Code Quality Remediation (code-quality-remediation.yml)** - Automated PSScriptAnalyzer fixes
- Triggers: Weekly scheduled, manual dispatch
- What it does: Automatically fixes code quality issues and creates PRs

**6. Security Scan (security-scan.yml)** - Security vulnerability scanning
- Triggers: Weekly scheduled, PRs
- What it does: CodeQL analysis, dependency scanning, secrets detection

#### Workflow Commands

```bash
# Create a release via GitHub UI
# Go to Actions → Release → Run workflow
# Enter version number and description

# Or use the release script locally:
./AitherRelease.ps1 -Version 1.2.3 -Message "Bug fixes"
./AitherRelease.ps1 -Type minor -Message "New features"
./AitherRelease.ps1 -Type major -Message "Breaking changes"

# Monitor CI status
gh run list --workflow=CI
gh run watch

# Generate comprehensive reports manually
gh workflow run comprehensive-report.yml
gh workflow run comprehensive-report.yml -f report_type=health-check
gh workflow run comprehensive-report.yml -f report_type=version-test -f version_test=0.8.0
```

### Comprehensive Reporting System Commands - 🆕 ENTERPRISE-GRADE REPORTING! 📊

```powershell
# Generate comprehensive HTML report
./scripts/reporting/Generate-ComprehensiveReport.ps1

# Generate with detailed analysis and custom title
./scripts/reporting/Generate-ComprehensiveReport.ps1 -IncludeDetailedAnalysis -ReportTitle "AitherZero v0.8.0 Release Validation"

# Generate dynamic feature map with HTML visualization
./scripts/reporting/Generate-DynamicFeatureMap.ps1 -HtmlOutput -IncludeDependencyGraph

# Complete analysis with all features
./scripts/reporting/Generate-DynamicFeatureMap.ps1 -AnalyzeIntegrations -VerboseOutput

# Custom report paths and versions
./scripts/reporting/Generate-ComprehensiveReport.ps1 -ReportPath "./reports/custom-report.html" -Version "0.8.0"
```

**What the comprehensive reporting system provides:**
- ✅ **Interactive HTML Dashboard** - Complete project health with drill-down analysis
- ✅ **Dynamic Feature Map** - Module relationships and capabilities visualization  
- ✅ **Health Scoring** - Weighted health grade (A-F) across all quality factors
- ✅ **Actionable Intelligence** - Prioritized remediation recommendations
- ✅ **Automated Daily Reports** - No manual intervention required
- ✅ **Professional Presentation** - Stakeholder-ready reports with charts and metrics
- ✅ **GitHub Integration** - Reports downloadable as artifacts with 90-day retention
- ✅ **Trend Analysis** - Historical health tracking and improvement monitoring

**Report Components:**
- 🎯 **Executive Summary** - Overall health grade and key metrics
- 📈 **Trend Analysis** - Health improvements over time
- 🧪 **Test Coverage Matrix** - 100% coverage achieved across 31 modules
- 🔒 **Security & Compliance** - Security scan results and vulnerability status
- 📝 **Documentation Health** - README coverage by directory
- 🔧 **Code Quality Metrics** - PSScriptAnalyzer findings and standards compliance
- 🗺️ **Dynamic Feature Map** - Interactive module visualization with dependencies
- 📦 **Build & Deployment Status** - Cross-platform readiness validation
- 📋 **Action Items** - Prioritized remediation plan with clear next steps

**Automated Reporting Schedule:**
- **Daily 6 AM UTC**: Full comprehensive report generation
- **Weekly**: Enhanced auditing with issue creation
- **On-Demand**: Manual trigger via GitHub Actions or command line
- **Release Preparation**: Version-specific testing and validation

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

AitherZero uses a modular PowerShell architecture with 30+ specialized modules:

- **LabRunner**: Lab automation orchestration
- **PatchManager**: Git workflow automation with PR/issue creation (v3.0 - Atomic Operations)
- **BackupManager**: File backup and consolidation
- **DevEnvironment**: Development environment setup
- **OpenTofuProvider**: Infrastructure deployment with cloud provider integrations (AWS, Azure, VMware, Hyper-V)
- **ISOManager**: ISO management and customization
- **ParallelExecution**: Runspace-based parallel processing
- **Logging**: Centralized logging across all operations
- **TestingFramework**: Pester-based testing integration
- **SecureCredentials**: Enterprise credential management
- **RemoteConnection**: Multi-protocol remote connections
- **SystemMonitoring**: System performance monitoring
- **SetupWizard**: Enhanced first-time setup with installation profiles
- **AIToolsIntegration**: AI development tools management (Claude Code, Gemini, etc.)
- **ConfigurationCarousel**: Multi-environment configuration management
- **ConfigurationCore**: Core configuration management system
- **ConfigurationManager**: Configuration integrity and management
- **ConfigurationRepository**: Git-based configuration repository management
- **OrchestrationEngine**: Advanced workflow and playbook execution
- **ProgressTracking**: Visual progress tracking for long-running operations
- **ModuleCommunication**: Inter-module communication and API system
- **PSScriptAnalyzerIntegration**: PowerShell code analysis automation
- **RestAPIServer**: REST API server for external integrations
- **RepoSync**: Repository synchronization utilities
- **ScriptManager**: One-off script execution management
- **SecurityAutomation**: Security hardening and compliance automation
- **SemanticVersioning**: Semantic versioning utilities
- **StartupExperience**: Interactive startup and configuration management
- **UnifiedMaintenance**: Unified maintenance operations
- **UtilityServices**: Common utility services
- **LicenseManager**: License management and feature access control

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

### PatchManager v3.0 Workflows (Atomic Operations)

**IMPORTANT**: PatchManager v3.0 eliminates git stashing issues and provides atomic operations:

#### Main Functions (Recommended)

```powershell
# Smart patch creation (auto-detects mode and approach)
New-Patch -Description "Clear description" -Changes {
    # Your changes here
}

# Quick fixes for minor changes (no branching)
New-QuickFix -Description "Fix typo in comment" -Changes {
    $content = Get-Content "file.ps1"
    $content = $content -replace "teh", "the"  
    Set-Content "file.ps1" -Value $content
}

# Feature development (automatic PR creation)
New-Feature -Description "Add authentication module" -Changes {
    # Feature implementation
    New-AuthenticationModule
}

# Emergency hotfixes (high priority, automatic PR)
New-Hotfix -Description "Fix critical security issue" -Changes {
    # Critical fix implementation
}
```

#### Advanced Usage

```powershell
# Explicit mode control
New-Patch -Description "Complex change" -Mode "Standard" -CreatePR -Changes {
    # Your changes
}

# Cross-fork operations
New-Feature -Description "Upstream feature" -TargetFork "upstream" -Changes {
    # Feature for upstream repository
}

# Dry run to preview
New-Patch -Description "Test change" -DryRun -Changes {
    # Preview what would happen
}
```

#### Legacy Compatibility

```powershell
# Legacy function still works (alias to New-Patch)
Invoke-PatchWorkflow -PatchDescription "Legacy syntax" -PatchOperation {
    # Your changes
} -CreatePR

# Other legacy functions remain available
Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup
```

### Git Workflow Best Practices - V3.0 ATOMIC OPERATIONS

**BREAKTHROUGH**: PatchManager v3.0 eliminates git stashing issues through atomic operations:

#### Key Improvements in v3.0

- **No More Git Stashing**: Eliminates the root cause of merge conflicts
- **Atomic Operations**: All-or-nothing operations with automatic rollback
- **Smart Mode Detection**: Automatically chooses the best approach
- **Multi-Mode System**: Simple/Standard/Advanced modes for different needs

#### Recommended Daily Workflow (v3.0)

```powershell
# Import the new PatchManager
Import-Module ./aither-core/modules/PatchManager -Force

# Quick fixes (no branching needed)
New-QuickFix -Description "Fix typo" -Changes { /* fix */ }

# Standard features (automatic branching and PR)
New-Feature -Description "Add new functionality" -Changes { /* implementation */ }

# Let smart mode choose automatically
New-Patch -Description "Smart analysis will determine best approach" -Changes { /* changes */ }

# Emergency fixes
New-Hotfix -Description "Critical security fix" -Changes { /* urgent fix */ }
```

#### v3.0 Modes Explained

- **Simple Mode**: Direct changes to current branch (for minor fixes)
- **Standard Mode**: Full branch workflow with PR creation
- **Advanced Mode**: Cross-fork operations and enterprise features

#### Migration from v2.x

```powershell
# OLD (v2.x) - Had stashing issues
Invoke-PatchWorkflow -PatchDescription "Feature" -PatchOperation {
    # Changes
} -CreatePR

# NEW (v3.0) - Atomic operations, no stashing
New-Feature -Description "Feature" -Changes {
    # Same changes
}

# Legacy syntax still works (automatic translation)
Invoke-PatchWorkflow -PatchDescription "Legacy" -PatchOperation {
    # Your changes
} -CreatePR  # This now uses New-Patch internally
```

#### Error Recovery (v3.0)

If something goes wrong, v3.0 provides automatic recovery:
- **Automatic Rollback**: Failed operations restore previous state
- **Smart Error Analysis**: Categorizes errors and suggests solutions  
- **No Manual Cleanup**: Atomic operations handle cleanup automatically

#### When to Use Each Function

```powershell
# Use New-QuickFix for:
# - Typos, formatting, minor documentation updates
# - Changes that don't need review

# Use New-Feature for:  
# - New functionality, enhancements
# - Changes that should have PR review

# Use New-Hotfix for:
# - Critical security fixes, production issues
# - Emergency changes that need immediate attention

# Use New-Patch for:
# - When you want smart auto-detection
# - Complex scenarios requiring custom mode selection
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
    Version = "3.0.0"
}
```

### Security Automation Commands

```powershell
# Import security automation module
Import-Module ./aither-core/modules/SecurityAutomation -Force

# Run security assessment
Get-ADSecurityAssessment -DomainName "mydomain.com"

# Enable advanced security features
Enable-CredentialGuard -Force
Enable-AdvancedAuditPolicy -AuditLevel "Enhanced"

# Certificate management
Install-EnterpriseCA -CAName "MyOrg-CA" -CAType "EnterpriseRootCA"
New-CertificateTemplate -TemplateName "WebServer" -Purpose "ServerAuthentication"
```

### License Management Commands

```powershell
# Import license manager
Import-Module ./aither-core/modules/LicenseManager -Force

# Check license status
Get-LicenseStatus

# Test feature access
Test-FeatureAccess -FeatureName "AdvancedReporting"

# Set license for organization
Set-License -LicenseKey "XXXX-XXXX-XXXX-XXXX" -OrganizationName "MyOrg"

# Get available features
Get-AvailableFeatures | Format-Table
```

### Module Communication Commands

```powershell
# Import module communication system
Import-Module ./aither-core/modules/ModuleCommunication -Force

# Register module API
Register-ModuleAPI -ModuleName "CustomModule" -APIVersion "1.0.0" -Endpoints @("health", "status")

# Invoke module API
Invoke-ModuleAPI -ModuleName "CustomModule" -Endpoint "health"

# Start message processor
Start-MessageProcessor -ProcessorName "MainProcessor"

# Create message channel
New-MessageChannel -ChannelName "CustomChannel" -ChannelType "Broadcast"
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

## What's New in v0.8.0

### Major Architecture Improvements
- **Consolidated Module System**: Enhanced AitherCore consolidation with 30+ modules
- **Improved Module Loading**: Standardized module import system with better error handling
- **Enhanced Configuration Management**: New ConfigurationCore and ConfigurationManager modules
- **ProgressTracking Integration**: Visual progress tracking across all operations

### PatchManager v3.0 - Atomic Operations
- **No More Git Stashing**: Eliminates merge conflicts through atomic operations
- **Smart Mode Detection**: Automatically chooses optimal workflow approach
- **New Commands**: New-Patch, New-QuickFix, New-Feature, New-Hotfix
- **Backward Compatibility**: Legacy commands still work with automatic translation

### Testing Infrastructure Improvements
- **Unified Test Framework**: Consolidated testing with parallel execution
- **Enhanced Test Discovery**: Automatic discovery of distributed module tests
- **Improved Performance**: Tests complete in under 30 seconds
- **Better Reporting**: Enhanced HTML and JSON test reports

### Security & Compliance Features
- **SecurityAutomation Module**: 21 functions for security hardening
- **Enhanced Auditing**: Comprehensive security scanning workflows
- **Code Quality Automation**: Automatic PSScriptAnalyzer fixes
- **License Management**: Feature access control and compliance

### Developer Experience Enhancements
- **Simplified Setup**: Start-DeveloperSetup.ps1 one-command installation
- **Enhanced Progress Tracking**: Visual feedback for long-running operations
- **Better Error Handling**: Comprehensive error recovery and diagnostics
- **Module Communication**: Inter-module API system for better integration

## Important Notes

- The main branch is `main` (not master)
- **CRITICAL: Always sync with remote before starting work** - Use `Sync-GitBranch -Force`
- **NEVER commit directly to main** - Always use PatchManager workflows
- **Fix divergence immediately** - Run `./scripts/Fix-GitDivergence.ps1` if branches diverge
- GitHub Actions run on develop branch and PRs
- The project supports Windows, Linux, and macOS
- Always use absolute paths with platform-agnostic construction
- PatchManager v3.0 provides atomic operations with New-Patch, New-QuickFix, New-Feature, New-Hotfix
- PatchManager automatically syncs with remote to prevent merge conflicts
- PatchManager v3.0 eliminates git stashing issues through atomic operations
- **NEW SIMPLE TESTING**: Just run `./tests/Run-Tests.ps1` - tests complete in <1 minute!
- SetupWizard provides intelligent first-time setup with progress tracking and installation profiles
- Installation profiles: minimal (infrastructure only), developer (includes AI tools), full (everything)
- ProgressTracking module offers visual feedback for long-running operations
- Configuration Carousel enables easy switching between multiple configuration sets
- Configuration repositories support Git-based custom configurations with multi-environment support
- Orchestration Engine provides advanced workflow execution with conditional logic and parallel processing
- AI Tools Integration automates installation and management of Claude Code, Gemini CLI, and other AI tools
- Module manifests should specify PowerShellVersion 7.0 minimum
- Use VS Code tasks for interactive development, command line for automation
- **COMPREHENSIVE CI/CD**: 5 workflows - CI (tests), Release (packages), Audit, Code Quality, Security Scan

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
- **Testing**: Just run `./tests/Run-Tests.ps1` - that's it!
- **First-time setup**: Use SetupWizard module for intelligent setup
- **Long-running operations**: Use ProgressTracking module for visual feedback
- **New user onboarding**: Use setup wizard with installation profiles
- **Environment validation**: Run setup tests with `./tests/Run-Tests.ps1 -Setup`

## Important Reminders

- **IMPORTANT: ALWAYS USE PATCHMANAGER**
  - For ALL Git operations, no exceptions
  - Creates consistent workflow tracking
  - Ensures proper issue and PR management
  - Provides rollback and validation capabilities