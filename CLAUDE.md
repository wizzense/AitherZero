# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🚨 CURRENT STATUS: MVP RECOVERY MODE
**Master Roadmap**: See `v1.0.0_roadmap.md` for complete execution plan
**Sub-Agent Instructions**: See `SUB-AGENT-INSTRUCTIONS.md` for detailed task assignments
**Current Phase**: PHASE 1 - IMMEDIATE CI/CD FIXES
**Priority**: CRITICAL - CI workflow syntax error blocking all automation

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

### Testing Commands - UNIFIED & LIGHTNING FAST! ⚡

```powershell
# UNIFIED TEST RUNNER - Replaces all legacy test runners
# Quick tests (core functionality, <30 seconds)
./tests/Run-UnifiedTests.ps1

# Setup and installation testing
./tests/Run-UnifiedTests.ps1 -TestSuite Setup

# All tests with comprehensive reporting
./tests/Run-UnifiedTests.ps1 -TestSuite All

# CI mode with dashboard and full auditing
./tests/Run-UnifiedTests.ps1 -TestSuite CI -GenerateDashboard -OutputFormat All

# Installation profile testing
./tests/Run-UnifiedTests.ps1 -TestSuite Installation -Profile developer

# Performance optimized parallel execution
./tests/Run-UnifiedTests.ps1 -TestSuite All -Performance -ShowProgress

# Distributed testing (uses TestingFramework)
./tests/Run-UnifiedTests.ps1 -Distributed -TestSuite All

# Legacy compatibility wrapper (maintains backward compatibility)
./tests/Run-Tests-Unified.ps1 -Quick
./tests/Run-Tests-Unified.ps1 -All -CI
./tests/Run-Tests-Unified.ps1 -Installation -Profile developer
```

**UNIFIED TEST RUNNER FEATURES:**
- ✅ **Sub-30-second execution** for Quick tests
- ✅ **Enterprise-grade dashboard** with HTML reporting
- ✅ **Full audit trail** and compliance reporting
- ✅ **Parallel execution** optimization
- ✅ **Real-time progress** tracking
- ✅ **Fail-fast strategy** for CI environments
- ✅ **Multiple output formats** (Console, JUnit, JSON, HTML)
- ✅ **Backward compatibility** with legacy test runners
- ✅ **Cross-platform support** (Windows, Linux, macOS)
- ✅ **Installation profile validation**
- ✅ **Performance benchmarking**

**LEGACY TEST RUNNERS** (being phased out):
- `Run-Tests.ps1` → Use `Run-UnifiedTests.ps1` instead
- `Run-CI-Tests.ps1` → Use `Run-UnifiedTests.ps1 -TestSuite CI`
- `Run-Installation-Tests.ps1` → Use `Run-UnifiedTests.ps1 -TestSuite Installation`

**MIGRATION WRAPPER:**
Use `Run-Tests-Unified.ps1` for seamless migration from legacy commands.

That's it! Unified testing with enterprise-grade reporting in <30 seconds!

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
### GitHub Actions Workflows - SIMPLIFIED & LIGHTNING FAST! ⚡

The project has 6 GitHub Actions workflows:

**1. CI (ci.yml)** - 🆕 SIMPLIFIED & UNIFIED! (Reduced from 1789 to 434 lines)
- Triggers: Push to main/develop, all PRs
- What it does: Unified testing using Run-UnifiedTests.ps1 + comprehensive dashboard
- Runtime: ~2 minutes (was ~8 minutes)
- Features: **Sub-30-second Quick tests**, **fail-fast strategy**, **unified test runner**
- Dashboard: **Enterprise-grade HTML dashboard** with full audit trail
- **MAJOR IMPROVEMENT**: Single test runner replaces 3 legacy runners

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

**🚀 CI WORKFLOW REVOLUTION:**
- **75% reduction** in CI workflow complexity (1789 → 434 lines)
- **Unified test runner** replaces 3 legacy runners
- **Sub-30-second Quick tests** for rapid feedback
- **Enterprise-grade dashboard** with comprehensive reporting
- **Fail-fast strategy** for faster CI feedback
- **Maintains full auditing** and compliance capabilities
- **No feature loss** - all functionality preserved and enhanced

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
# Load utilities domain (contains all AI tools functions)
. (Join-Path $projectRoot "aither-core/domains/utilities/Utilities.ps1")

# Install AI tools with full dependency management
Install-ClaudeCodeDependencies -WSLUsername "developer"
Install-GeminiCLIDependencies -SkipNodeInstall
Install-CodexCLIDependencies -Force

# Simplified installers (wrappers)
Install-ClaudeCode
Install-GeminiCLI
Install-CodexCLI

# Get AI tools status
Get-AIToolsStatus

# Update all AI tools
Update-AITools

# Update specific tools
Update-AITools -Tools @('claude-code', 'gemini')

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

### Domain System

AitherZero uses a consolidated domain-based PowerShell architecture with **196+ functions** organized into **6 business domains**:

#### Domain Structure (`aither-core/domains/`)

**Infrastructure Domain** (`aither-core/domains/infrastructure/`) - **57 Functions**:
- **LabRunner** (17 functions): Lab automation orchestration
- **OpenTofuProvider** (11 functions): Infrastructure deployment with cloud provider integrations (AWS, Azure, VMware, Hyper-V)
- **ISOManager** (10 functions): ISO management and customization
- **SystemMonitoring** (19 functions): System performance monitoring

**Security Domain** (`aither-core/domains/security/`) - **41 Functions**:
- **SecureCredentials** (10 functions): Enterprise credential management
- **SecurityAutomation** (31 functions): Security hardening and compliance automation

**Configuration Domain** (`aither-core/domains/configuration/`) - **36 Functions**:
- **ConfigurationCore** (11 functions): Core configuration management system
- **ConfigurationCarousel** (12 functions): Multi-environment configuration management
- **ConfigurationRepository** (5 functions): Git-based configuration repository management
- **ConfigurationManager** (8 functions): Configuration validation and testing

**Utilities Domain** (`aither-core/domains/utilities/`) - **24 Functions**:
- **SemanticVersioning** (8 functions): Semantic versioning utilities
- **LicenseManager** (3 functions): License management and feature access control
- **RepoSync** (2 functions): Repository synchronization utilities
- **UnifiedMaintenance** (3 functions): Unified maintenance operations
- **UtilityServices** (7 functions): Common utility services
- **PSScriptAnalyzerIntegration** (1 function): PowerShell code analysis automation

**Experience Domain** (`aither-core/domains/experience/`) - **22 Functions**:
- **SetupWizard** (11 functions): Enhanced first-time setup with installation profiles
- **StartupExperience** (11 functions): Interactive startup and configuration management

**Automation Domain** (`aither-core/domains/automation/`) - **16 Functions**:
- **ScriptManager** (14 functions): One-off script execution management
- **OrchestrationEngine** (2 functions): Advanced workflow and playbook execution

### Domain Structure Pattern

Each domain follows this structure:
```
DomainName/
├── DomainName.ps1          # Domain script with all functions
├── README.md               # Domain documentation
└── (legacy tests may exist in various locations)
```

All domains are loaded via dot sourcing or through AitherCore.psm1 orchestration.

### Important Patterns

#### Path Handling
Always use `Join-Path` for cross-platform compatibility:
```powershell
# Correct
$configPath = Join-Path $projectRoot "configs" "app-config.json"

# Wrong
$configPath = "$projectRoot/configs/app-config.json"
```

#### Domain Loading
```powershell
# Always use Find-ProjectRoot
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Load domains using dot sourcing
. (Join-Path $projectRoot "aither-core/domains/DomainName/DomainName.ps1")

# Or use AitherCore.psm1 for automatic loading
Import-Module (Join-Path $projectRoot "aither-core/AitherCore.psm1") -Force
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

**IMPORTANT**: PatchManager v3.0 is now integrated into the Automation domain and provides atomic operations:

#### Domain Loading

```powershell
# Load the Automation domain (contains PatchManager functions)
. (Join-Path $projectRoot "aither-core/domains/automation/Automation.ps1")

# Or use AitherCore.psm1 for automatic loading
Import-Module (Join-Path $projectRoot "aither-core/AitherCore.psm1") -Force
```

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
# Create PR after the patch
New-Patch -Description "Complex change" -CreatePR -Changes {
    # Your changes
}

# Dry run to preview
New-Patch -Description "Test change" -DryRun -Changes {
    # Preview what would happen
}
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
# Import the Automation domain (contains PatchManager functions)
. "$PSScriptRoot/aither-core/domains/automation/Automation.ps1"

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
# Run intelligent setup wizard (from Experience domain)
. "$PSScriptRoot/aither-core/domains/experience/Experience.ps1"
$setupResult = Start-IntelligentSetup

# Run minimal setup for CI/CD environments
$setupResult = Start-IntelligentSetup -MinimalSetup -SkipOptional

# Generate platform-specific quick start guide
Generate-QuickStartGuide -SetupState $setupResult
```

### ProgressTracking Usage

```powershell
# Track long-running operations with visual progress (from Experience domain)
. "$PSScriptRoot/aither-core/domains/experience/Experience.ps1"

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
# Import security domain (or use through AitherCore)
. "$PSScriptRoot/aither-core/domains/security/Security.ps1"

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
# Import utilities domain (or use through AitherCore)
. "$PSScriptRoot/aither-core/domains/utilities/Utilities.ps1"

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

## 🚨 MVP RECOVERY & WORKFLOW VALIDATION COMMANDS

### **Critical Issue Resolution Commands**

```bash
# Check GitHub workflow status
gh workflow list
gh run list --limit 10

# Validate YAML syntax in all workflows  
find .github/workflows -name "*.yml" -exec yamllint {} \;

# Test PowerShell syntax in CI workflow
pwsh -NoProfile -Command "Get-Content .github/workflows/ci.yml | Test-Path"

# Trigger specific workflows manually
gh workflow run ci.yml
gh workflow run comprehensive-report.yml
gh workflow run audit.yml
```

### **Test Infrastructure Validation**

```powershell
# Test unified test runner (CRITICAL - must work)
./tests/Run-UnifiedTests.ps1 -TestSuite Quick
./tests/Run-UnifiedTests.ps1 -TestSuite All -CI
./tests/Run-UnifiedTests.ps1 -WhatIf

# Validate PatchManager integration (CRITICAL)
Import-Module ./aither-core/modules/PatchManager -Force
New-Patch -Description "Test PatchManager integration" -WhatIf

# Test build script
./build/Build-Package.ps1 -Platform all -WhatIf

# Test comprehensive reporting
./scripts/reporting/Generate-ComprehensiveReport.ps1 -WhatIf
```

### **CI/CD Pipeline Validation**

```bash
# Full pipeline test (after fixes)
gh workflow run ci.yml
gh run watch

# Validate artifacts are generated
gh run list --workflow=ci.yml
gh run download [RUN_ID]

# Check release workflow
gh workflow run release.yml
gh workflow run trigger-release.yml
```

### **Sub-Agent Deployment Commands**

```powershell
# Deploy specific sub-agents for MVP recovery
# Agent 1: Fix CI syntax error
New-Patch -Description "Fix CI workflow PowerShell syntax error blocking all CI runs"

# Agent 2: Validate YAML syntax
New-Patch -Description "Validate and fix YAML syntax across all workflows"

# Agent 3: Test infrastructure validation
New-Patch -Description "Validate and fix unified test runner infrastructure"

# Monitor progress
gh run list --limit 5
gh workflow list
```

### **Quality Gate Validation**

```powershell
# Syntax validation
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
Get-ChildItem .github/workflows/*.yml | ForEach-Object { yamllint $_.FullName }

# Test execution validation
./tests/Run-UnifiedTests.ps1 -TestSuite Quick -CI

# Workflow validation
gh workflow run ci.yml --ref main
gh run watch
```

## Important Reminders

- **🚨 CURRENT PRIORITY: MVP RECOVERY**
  - Master roadmap: `v1.0.0_roadmap.md`
  - Sub-agent instructions: `SUB-AGENT-INSTRUCTIONS.md`
  - Focus: Fix CI workflow PowerShell syntax error FIRST

- **IMPORTANT: ALWAYS USE PATCHMANAGER**
  - For ALL Git operations, no exceptions
  - Creates consistent workflow tracking
  - Ensures proper issue and PR management
  - Provides rollback and validation capabilities