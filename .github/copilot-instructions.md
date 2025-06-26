# AitherZero Infrastructure Automation - GitHub Copilot Instructions

This project is a **PowerShell-based infrastructure automation framework** using OpenTofu/Terraform for lab environments. Follow these instructions when generating code or providing assistance.

## Core Standards & Requirements

**PowerShell Version**: Always use PowerShell 7.0+ features and cross-platform compatible syntax.

**Path Handling**: Use `Join-Path` for ALL path construction to ensure cross-platform compatibility. Never use hardcoded forward or backward slashes.

**Code Style**: Follow One True Brace Style (OTBS) with consistent indentation and spacing.

**Module Architecture**: Import modules using `$env:PWSH_MODULES_PATH` with `Import-Module` and `-Force` parameter.

**Error Handling**: Always implement comprehensive try-catch blocks with detailed logging using the `Logging` module.

**Testing**: Use the bulletproof testing framework with `Run-BulletproofValidation.ps1` for comprehensive validation.

## Project Modules & Their Purposes

Use these existing modules instead of creating new functionality:

- **BackupManager**: File backup, cleanup, and consolidation operations
- **DevEnvironment**: Development environment preparation and validation
- **ISOCustomizer**: Enterprise-grade ISO customization with autounattend generation
- **ISOManager**: Enterprise ISO management and download operations
- **LabRunner**: Lab automation orchestration and test execution coordination
- **Logging**: Centralized logging with levels (INFO, WARN, ERROR, SUCCESS, DEBUG)
- **OpenTofuProvider**: OpenTofu/Terraform provider management and integration
- **ParallelExecution**: Runspace-based parallel task execution
- **PatchManager**: v2.1 CONSOLIDATED - 4 core functions: Invoke-PatchWorkflow, New-PatchIssue, New-PatchPR, Invoke-PatchRollback
- **RemoteConnection**: Enterprise remote connection management with security
- **RepoSync**: Repository synchronization and cross-fork operations
- **ScriptManager**: Script repository management and template handling
- **SecureCredentials**: Enterprise credential management and secure storage
- **TestingFramework**: Bulletproof testing wrapper with project-specific configurations
- **UnifiedMaintenance**: Unified entry point for all maintenance operations

## Code Generation Patterns

**Function Structure**: Use `[CmdletBinding(SupportsShouldProcess)]` with proper parameter validation and begin/process/end blocks.

**Parameter Validation**: Always include `[ValidateNotNullOrEmpty()]` and appropriate validation attributes.

**Logging Integration**: Use `Write-CustomLog -Level 'LEVEL' -Message 'MESSAGE'` for all logging operations.

**Cross-Platform Paths**: Use `Join-Path` and avoid hardcoded Windows-style paths.

**Module Dependencies**: Reference existing modules rather than reimplementing functionality.

**Environment Variables**: Use `$env:PWSH_MODULES_PATH` for module imports and `$env:PROJECT_ROOT` for project paths.

**Shared Utilities**: Always use shared utilities from `aither-core/shared/` directory:
```powershell
# Always import Find-ProjectRoot for path detection
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Use standardized module imports
Import-Module (Join-Path $projectRoot "aither-core/modules/ModuleName") -Force
```

**Shared Utilities**: Always use shared utilities from `aither-core/shared/` directory:
```powershell
# Always import Find-ProjectRoot for path detection
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Use standardized module imports
Import-Module (Join-Path $projectRoot "aither-core/modules/ModuleName") -Force
```

## Intelligent Workflow Patterns

**Problem Analysis**: When users describe issues, use semantic search to find similar problems and solutions:
- Search for error patterns in existing code
- Identify related modules and functions
- Check existing tests for similar scenarios
- Review documentation for established patterns

**Context-Aware Suggestions**: Leverage repository knowledge:
- Understand the current module being worked on
- Suggest appropriate VS Code tasks for the workflow
- Recommend testing strategies based on changes
- Identify cross-module dependencies and impacts

**Progressive Enhancement**: Build solutions incrementally:
1. Start with minimal viable solution using existing tools
2. Add comprehensive error handling and logging
3. Include appropriate tests and validation
4. Consider cross-platform compatibility
5. Add documentation and examples

**Tool Chain Integration**: Connect tools effectively:
```powershell
# Example: Complete development workflow
# 1. Make changes using PatchManager
Invoke-PatchWorkflow -PatchDescription "Add new feature" -PatchOperation {
    # Implementation
} -TestCommands @(
    # 2. Run appropriate tests
    "pwsh -File tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick",
    "pwsh -File tests/unit/modules/MyModule/MyModule-Core.Tests.ps1"
) -CreatePR

# 3. Use VS Code tasks for interactive workflows
# Ctrl+Shift+P → Tasks: Run Task → "🔧 Development: Setup Complete Environment"
```

## Infrastructure as Code Standards

**OpenTofu/Terraform**: Use HCL syntax with proper variable definitions and output declarations.

**Resource Naming**: Follow consistent naming conventions with environment prefixes.

**State Management**: Always consider remote state and workspace isolation.

**Security**: Never hardcode credentials; use variable files and secure practices.

## Testing & Quality Assurance

**Pester Tests**: Create comprehensive test suites with Describe-Context-It structure.

**Mock Strategy**: Use proper mocking for external dependencies and file system operations.

**Code Coverage**: Aim for high test coverage with meaningful assertions.

**Integration Tests**: Include end-to-end testing scenarios for critical workflows.

## Security & Best Practices

**Credential Handling**: Use secure strings and credential objects, never plain text passwords.

**Input Validation**: Validate all user inputs and external data sources.

**Least Privilege**: Follow principle of least privilege for all operations.

**Audit Logging**: Log all significant operations for security and troubleshooting.

## Advanced Copilot Features

**Context Awareness**: Leverage repository-specific instructions to provide context-aware suggestions.

**Prompt Integration**: Use specialized prompt templates for PowerShell development, testing, infrastructure, and troubleshooting.

**Code Review Assistance**: Generate code that adheres to project standards and includes inline comments for clarity.

**Documentation Generation**: Automatically include detailed help documentation for all functions and modules.

**Performance Optimization**: Suggest improvements for parallel execution, memory efficiency, and large dataset handling.

**Error Diagnosis**: Provide troubleshooting steps and common resolutions for errors encountered during development.

**Architecture Awareness**: Follow advanced architecture patterns from `instructions/advanced-architecture.instructions.md` including:
- Shared utilities integration (Find-ProjectRoot, etc.)
- Dynamic repository detection and cross-fork operations
- PatchManager v2.1 single-step workflows
- Bulletproof testing integration
- VS Code task creation patterns
- Comprehensive error handling and logging standards

## Advanced Development Patterns

**Repository-Aware Code**: All generated code should work across the fork chain (AitherZero → AitherLabs → Aitherium):
```powershell
# Dynamic repository detection
$repoInfo = Get-GitRepositoryInfo
$targetRepo = "$($repoInfo.Owner)/$($repoInfo.Name)"

# Cross-fork operations
Invoke-PatchWorkflow -Description "Feature" -TargetFork "upstream" -CreatePR
```

**Module Architecture Standards**: Follow standardized module patterns:
```powershell
# Module Structure (REQUIRED):
ModuleName/
├── ModuleName.psd1          # Manifest with proper exports
├── ModuleName.psm1          # Main module loader
├── Public/                  # Exported functions
├── Private/                 # Internal functions
└── README.md               # Module documentation

# Function structure template:
function Public-Function {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RequiredParam
    )

    begin {
        . "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"
    }

    process {
        try {
            if ($PSCmdlet.ShouldProcess($RequiredParam, "Operation")) {
                # Main logic with logging
                Write-CustomLog -Level 'INFO' -Message "Operation started"
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error: $($_.Exception.Message)"
            throw
        }
    }
}
```

**Cross-Platform Standards**: Ensure all code works on Windows, Linux, and macOS:
```powershell
# Use Join-Path for ALL path construction
$configPath = Join-Path $projectRoot "configs/app-config.json"

# Platform-aware conditionals when needed
if ($IsWindows) {
    # Windows-specific logic
} elseif ($IsLinux) {
    # Linux-specific logic
}
```

## Intelligent Workflow Patterns

**Problem Analysis**: When users describe issues, use semantic search to find similar problems and solutions:
- Search for error patterns in existing code
- Identify related modules and functions
- Check existing tests for similar scenarios
- Review documentation for established patterns

**Context-Aware Suggestions**: Leverage repository knowledge:
- Understand the current module being worked on
- Suggest appropriate VS Code tasks for the workflow
- Recommend testing strategies based on changes
- Identify cross-module dependencies and impacts

**Progressive Enhancement**: Build solutions incrementally:
1. Start with minimal viable solution using existing tools
2. Add comprehensive error handling and logging
3. Include appropriate tests and validation
4. Consider cross-platform compatibility
5. Add documentation and examples

## Tool Chain Integration

Connect tools effectively for complete development workflows:

```powershell
# Example: Complete development workflow
# 1. Make changes using PatchManager
Invoke-PatchWorkflow -PatchDescription "Add new feature" -PatchOperation {
    # Implementation
} -TestCommands @(
    # 2. Run appropriate tests
    "pwsh -File tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick",
    "pwsh -File tests/unit/modules/MyModule/MyModule-Core.Tests.ps1"
) -CreatePR

# 3. Use VS Code tasks for interactive workflows
# Ctrl+Shift+P → Tasks: Run Task → "🔧 Development: Setup Complete Environment"
```

## VS Code Integration & Available Tools

### Core Development Tasks
Use these VS Code tasks for primary development workflows:

**Testing & Validation**:
- `Ctrl+Shift+P → Tasks: Run Task → "🚀 Bulletproof Validation - Quick"` (30 seconds)
- `Ctrl+Shift+P → Tasks: Run Task → "🔥 Bulletproof Validation - Standard"` (2-5 minutes)
- `Ctrl+Shift+P → Tasks: Run Task → "🎯 Bulletproof Validation - Complete"` (10-15 minutes)
- `Ctrl+Shift+P → Tasks: Run Task → "⚡ Bulletproof Validation - Quick (Fail-Fast)"`

**PatchManager Workflows**:
- `Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Create Feature Patch"`
- `Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Quick Local Fix (No Issue)"`
- `Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Emergency Rollback"`
- `Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Validate All Modules"`

**Development Environment**:
- `Ctrl+Shift+P → Tasks: Run Task → "🔧 Development: Setup Complete Environment"`
- `Ctrl+Shift+P → Tasks: Run Task → "🏗️ Architecture: Validate Complete System"`
- `Ctrl+Shift+P → Tasks: Run Task → "🌐 Repository: Update All Cross-Fork Configs"`

**Build & Release**:
- `Ctrl+Shift+P → Tasks: Run Task → "📦 Local Build: Create Windows Package"`
- `Ctrl+Shift+P → Tasks: Run Task → "🐧 Local Build: Create Linux Package"`
- `Ctrl+Shift+P → Tasks: Run Task → "🚀 Local Build: Full Release Simulation"`

### Automated Tool Integration

**Testing Integration**: Always use bulletproof validation with appropriate level:
```powershell
# Quick validation (30 seconds) - Use for rapid feedback
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick"

# Standard validation (2-5 minutes) - Use for thorough testing
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Standard"

# Complete validation (10-15 minutes) - Use for release preparation
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Complete"

# CI mode with fail-fast for automated environments
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Standard" -CI -FailFast
```

**PatchManager Integration**: Use PatchManager v2.1 for ALL Git operations:
```powershell
# Primary workflow - handles dirty trees, creates issues by default
Invoke-PatchWorkflow -PatchDescription "Clear description of changes" -PatchOperation {
    # Your changes here - ANY working tree state is fine
    # PatchManager auto-commits existing changes first
} -CreatePR -TestCommands @("validation-command")

# Local-only changes (no GitHub integration)
Invoke-PatchWorkflow -PatchDescription "Local fix" -CreateIssue:$false -PatchOperation {
    # Your changes
}

# Cross-fork contributions to upstream
Invoke-PatchWorkflow -PatchDescription "Upstream improvement" -TargetFork "upstream" -CreatePR -PatchOperation {
    # Changes for upstream
}

# Emergency rollback operations
Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup -DryRun  # Preview first
Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup          # Execute
```

### Tool Selection Guidelines

**When to use VS Code tasks**:
- Interactive development workflows
- Quick access to common operations
- Visual feedback and progress tracking
- Testing specific modules or components
- Setting up development environments
- Running predefined automation sequences

**When to use command line tools directly**:
- Automated scripts and CI/CD pipelines
- Custom parameters not covered by tasks
- Debugging specific issues
- Advanced workflows requiring multiple commands
- One-off operations with specific requirements

**When to use PatchManager**:
- ALL Git operations (commits, branches, PRs)
- ANY code changes that should be tracked
- Cross-fork repository operations
- Issue creation and linking
- Rollback and recovery operations
- Coordinated workflows requiring Git and GitHub integration

**When to use Bulletproof Validation**:
- Before committing any changes (Quick level)
- Before creating pull requests (Standard level)
- Before releases (Complete level)
- In CI/CD pipelines with fail-fast mode
- When troubleshooting module issues

**When to use Find-ProjectRoot utility**:
- ALWAYS when building paths in scripts
- Module imports and dependency loading
- Cross-platform path construction
- Dynamic repository detection needs

## Collaboration and Feedback

**Team Standards**: Ensure generated code aligns with team coding standards and practices.

**Feedback Loop**: Continuously refine instructions based on team feedback and project evolution.

**Version Control**: Track changes to instructions and prompt templates to maintain consistency across the team.

**Training and Onboarding**: Use Copilot to assist new team members in understanding project architecture and standards.

When suggesting code changes or new features, always consider how they integrate with existing modules and follow these established patterns.
