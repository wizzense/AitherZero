````instructions
# AitherZero Infrastructure Automation - GitHub Copilot Instructions (Updated)

This project is a **PowerShell-based infrastructure automation framework** using OpenTofu/Terraform for lab environments. Follow these instructions when generating code or providing assistance.

## 🚀 CI/CD & Build System Integration

**GitHub Actions Workflows**: The project uses a comprehensive CI/CD pipeline with these key workflows:
- **ci-and-release.yml**: Primary CI/CD pipeline with build, test, and release stages
- **pr-validation.yml**: PR validation with bulletproof testing and build verification
- **build-release.yml**: Cross-platform package building (Windows, Linux, macOS)
- **documentation.yml**: Automated documentation generation and deployment

**Build System**: Uses `build/Build-Package.ps1` with profiles:
- **minimal.json**: Core components only (fastest build)
- **standard.json**: Essential modules and features
- **development.json**: Full development environment with all tools

**Testing Integration**: Multi-level testing approach:
```powershell
# Quick validation (30 seconds) - Use for rapid feedback
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick"

# Standard validation (2-5 minutes) - Use for PR validation
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Standard"

# Complete validation (10-15 minutes) - Use for release preparation
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Complete"

# CI mode with fail-fast for automated environments
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Standard" -CI -FailFast
```

**Build Profile Usage**: When making changes, always test across profiles:
```powershell
# Test minimal build (essential functionality)
pwsh -File "build/Build-Package.ps1" -Profile "minimal" -Platform "current"

# Test standard build (typical deployment)
pwsh -File "build/Build-Package.ps1" -Profile "standard" -Platform "current"

# Test development build (full features)
pwsh -File "build/Build-Package.ps1" -Profile "development" -Platform "current"
```

## Core Standards & Requirements

**PowerShell Version**: Always use PowerShell 7.0+ features and cross-platform compatible syntax.

**Path Handling**: Use `Join-Path` for ALL path construction to ensure cross-platform compatibility. Never use hardcoded forward or backward slashes.

**Code Style**: Follow One True Brace Style (OTBS) with consistent indentation and spacing.

**Module Architecture**: Import modules using `$env:PWSH_MODULES_PATH` with `Import-Module` and `-Force` parameter.

**Error Handling**: Always implement comprehensive try-catch blocks with detailed logging using the `Logging` module.

**Testing**: Use the bulletproof testing framework with `Run-BulletproofValidation.ps1` for comprehensive validation.

**Build Integration**: Always consider build profiles when making changes:
- Test with minimal profile for essential functionality
- Validate with standard profile for typical deployments
- Use development profile for full feature testing

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

## 🔧 Code Generation Patterns

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

## 🧪 Testing & CI/CD Integration

**Pre-commit Testing**: Always run quick validation before committing:
```powershell
# Quick pre-commit check (30 seconds)
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick" -FailFast
```

**PR Validation**: Use standard validation for pull requests:
```powershell
# Standard PR validation (2-5 minutes)
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Standard" -CI
```

**Build Verification**: Test builds across profiles:
```powershell
# Build verification workflow
$profiles = @("minimal", "standard", "development")
foreach ($profile in $profiles) {
    pwsh -File "build/Build-Package.ps1" -Profile $profile -Platform "current" -WhatIf
}
```

**GitHub Actions Integration**: When modifying workflows, always:
1. Test locally with `act` if available
2. Use `WhatIf` for verification steps
3. Include proper error handling and fallback logic
4. Add comprehensive logging for debugging

## 🎯 PatchManager Integration Patterns

**Primary Workflow**: Use PatchManager v2.1 for ALL Git operations:
```powershell
# Complete workflow with build validation
Invoke-PatchWorkflow -PatchDescription "Clear description of changes" -PatchOperation {
    # Your changes here - ANY working tree state is fine
    # PatchManager auto-commits existing changes first
} -CreatePR -TestCommands @(
    "pwsh -File tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick",
    "pwsh -File build/Build-Package.ps1 -Profile minimal -Platform current"
)
```

**CI/CD Integration**: Coordinate with GitHub Actions:
```powershell
# Workflow that triggers CI/CD pipeline
Invoke-PatchWorkflow -PatchDescription "Feature with CI/CD integration" -PatchOperation {
    # Implementation changes
} -CreatePR -Priority "Medium" -TestCommands @(
    "pwsh -File tests/Run-BulletproofValidation.ps1 -ValidationLevel Standard -CI",
    "pwsh -File build/Build-Package.ps1 -Profile standard -Platform current"
)
```

## 🏗️ Advanced Architecture Patterns

**Build-Aware Development**: Always consider build implications:
```powershell
# Module changes that affect build profiles
function Update-ModuleForBuild {
    param(
        [string]$ModuleName,
        [string[]]$BuildProfiles = @("minimal", "standard", "development")
    )
    
    foreach ($profile in $BuildProfiles) {
        # Test module inclusion in each profile
        $buildConfig = Get-Content "build/profiles/$profile.json" | ConvertFrom-Json
        if ($buildConfig.modules -contains $ModuleName) {
            Write-Host "Module $ModuleName is included in $profile profile"
        }
    }
}
```

**Workflow-Aware Changes**: Consider GitHub Actions impact:
```powershell
# Function that updates workflows safely
function Update-WorkflowSafely {
    param([string]$WorkflowFile, [scriptblock]$Changes)
    
    try {
        # Backup existing workflow
        $backup = "$WorkflowFile.backup"
        Copy-Item $WorkflowFile $backup
        
        # Apply changes
        & $Changes
        
        # Validate workflow syntax
        if (Test-Path $WorkflowFile) {
            Write-Host "Workflow updated successfully"
        }
    } catch {
        # Restore backup on failure
        Move-Item $backup $WorkflowFile
        throw
    }
}
```

## 📊 VS Code Integration & Available Tools

### Core Development Tasks
Use these VS Code tasks for primary development workflows:

**Testing & Validation**:
- `Ctrl+Shift+P → Tasks: Run Task → "🚀 Bulletproof Validation - Quick"` (30 seconds)
- `Ctrl+Shift+P → Tasks: Run Task → "🔥 Bulletproof Validation - Standard"` (2-5 minutes)
- `Ctrl+Shift+P → Tasks: Run Task → "🎯 Bulletproof Validation - Complete"` (10-15 minutes)
- `Ctrl+Shift+P → Tasks: Run Task → "⚡ Bulletproof Validation - Quick (Fail-Fast)"`

**Build & Package Management**:
- `Ctrl+Shift+P → Tasks: Run Task → "📦 Local Build: Create Windows Package"`
- `Ctrl+Shift+P → Tasks: Run Task → "🐧 Local Build: Create Linux Package"`
- `Ctrl+Shift+P → Tasks: Run Task → "🚀 Local Build: Full Release Simulation"`
- `Ctrl+Shift+P → Tasks: Run Task → "🔍 Local Build: Test Local Package"`

**PatchManager Workflows**:
- `Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Create Feature Patch"`
- `Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Quick Local Fix (No Issue)"`
- `Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Emergency Rollback"`
- `Ctrl+Shift+P → Tasks: Run Task → "PatchManager: Validate All Modules"`

**Development Environment**:
- `Ctrl+Shift+P → Tasks: Run Task → "🔧 Development: Setup Complete Environment"`
- `Ctrl+Shift+P → Tasks: Run Task → "🏗️ Architecture: Validate Complete System"`
- `Ctrl+Shift+P → Tasks: Run Task → "🌐 Repository: Update All Cross-Fork Configs"`

### Advanced Workflows

**Turbo Mode Tasks** (High-Performance):
- `Ctrl+Shift+P → Tasks: Run Task → "⚡ TURBO: Lightning Module Check (3s)"`
- `Ctrl+Shift+P → Tasks: Run Task → "🚀 TURBO: Ultra-Fast Test Suite (10-30s)"`
- `Ctrl+Shift+P → Tasks: Run Task → "🔥 TURBO: Complete Test Suite (30-60s)"`
- `Ctrl+Shift+P → Tasks: Run Task → "🚀 TURBO: Full CI Simulation (Local)"`

**Release Management**:
- `Ctrl+Shift+P → Tasks: Run Task → "🚀 Quick Release: Patch Version"`
- `Ctrl+Shift+P → Tasks: Run Task → "🔧 Quick Release: Minor Version"`
- `Ctrl+Shift+P → Tasks: Run Task → "🎉 Quick Release: Major Version (v1.0.0 GA Ready!)"`

## 🎛️ Tool Selection Guidelines

**When to use VS Code tasks**:
- Interactive development workflows
- Quick access to common operations
- Visual feedback and progress tracking
- Testing specific modules or components
- Building and packaging operations
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

**When to use Build System**:
- Creating distributable packages
- Testing cross-platform compatibility
- Validating module dependencies
- Preparing for releases
- Testing different deployment scenarios

**When to use Bulletproof Validation**:
- Before committing any changes (Quick level)
- Before creating pull requests (Standard level)
- Before releases (Complete level)
- In CI/CD pipelines with fail-fast mode
- When troubleshooting module issues

## 🛠️ Workflow Optimization Patterns

**Development Workflow**:
```powershell
# Optimal development cycle
1. Write code changes
2. Run quick validation: pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick"
3. Test with minimal build: pwsh -File "build/Build-Package.ps1" -Profile "minimal" -Platform "current"
4. Use PatchManager for Git operations: Invoke-PatchWorkflow -PatchDescription "..." -CreatePR
```

**CI/CD Workflow**:
```powershell
# Automated pipeline integration
1. PatchManager creates PR with tests
2. GitHub Actions runs pr-validation.yml
3. Build-release.yml creates packages
4. Documentation.yml updates docs
5. ci-and-release.yml handles full release
```

**Release Workflow**:
```powershell
# Release preparation
1. Run complete validation: pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Complete"
2. Test all build profiles: foreach ($profile in @("minimal","standard","development")) { ... }
3. Create release: pwsh -File "Quick-Release.ps1" -Type "Minor"
4. Verify GitHub Actions success
```

## 🔍 Error Handling & Debugging

**Build Errors**: When build fails, check:
1. Build profile configuration (build/profiles/*.json)
2. Module dependencies and imports
3. Cross-platform path issues
4. PowerShell version compatibility

**Test Failures**: When tests fail, check:
1. Module loading and imports
2. Mocking configuration
3. Test data and fixtures
4. Cross-platform compatibility

**Workflow Failures**: When GitHub Actions fail, check:
1. Workflow syntax and structure
2. Required secrets and variables
3. Artifact dependencies
4. Cross-platform runner compatibility

## 🚀 Performance Optimization

**Parallel Execution**: Use ParallelExecution module for performance:
```powershell
# Parallel operations
Import-Module (Join-Path $projectRoot "aither-core/modules/ParallelExecution") -Force
$operations = @(
    { Test-Module "ModuleA" },
    { Test-Module "ModuleB" },
    { Test-Module "ModuleC" }
)
Invoke-ParallelOperation -Operations $operations -MaxParallelJobs 4
```

**Build Optimization**: Use appropriate build profiles:
- **minimal**: For quick testing and CI
- **standard**: For typical deployments
- **development**: For full feature development

**Test Optimization**: Use appropriate validation levels:
- **Quick**: For rapid feedback during development
- **Standard**: For PR validation and CI
- **Complete**: For release preparation

## 📚 Documentation Standards

**Module Documentation**: Every module must have:
- README.md with usage examples
- Function help documentation
- Build profile inclusion notes
- Cross-platform compatibility notes

**Workflow Documentation**: Every workflow must have:
- Clear description of purpose
- Input/output specifications
- Error handling documentation
- Performance characteristics

**Code Documentation**: Every function must have:
- Parameter descriptions
- Return value documentation
- Example usage
- Error conditions

## 🔗 Integration Points

**GitHub Actions**: Workflows integrate with:
- PatchManager for automated Git operations
- Build system for package creation
- Testing framework for validation
- Documentation generation

**VS Code**: Tasks integrate with:
- PowerShell execution environment
- Git operations through PatchManager
- Build system for packaging
- Testing framework for validation

**Build System**: Profiles integrate with:
- Module dependency resolution
- Cross-platform packaging
- Testing framework validation
- Release management

## 🎯 Best Practices Summary

1. **Always use PatchManager** for Git operations
2. **Test across build profiles** before committing
3. **Run appropriate validation level** for the context
4. **Use VS Code tasks** for interactive workflows
5. **Follow cross-platform patterns** for compatibility
6. **Include comprehensive error handling** in all code
7. **Document all changes** and integration points
8. **Optimize for performance** with parallel execution
9. **Validate GitHub Actions** before pushing
10. **Use shared utilities** instead of custom implementations

When suggesting code changes or new features, always consider how they integrate with the build system, testing framework, and CI/CD pipeline.

````
