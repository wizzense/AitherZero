# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AitherZero is a **standalone PowerShell automation framework** for OpenTofu/Terraform infrastructure management. It provides enterprise-grade infrastructure as code (IaC) automation with comprehensive testing and modular architecture.

**Technology Stack:**
- Primary Language: PowerShell 7.0+
- Secondary: JavaScript/Node.js (MCP server)
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

# First-time setup wizard
./Start-AitherZero.ps1 -Setup

# Preview mode
./Start-AitherZero.ps1 -WhatIf
```

### Testing Commands

```powershell
# Quick validation (3 seconds) - Use for rapid feedback during development
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick

# Standard validation (2-5 minutes) - Use before creating PRs
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Standard

# Complete validation (10-15 minutes) - Use for release preparation
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Complete

# CI mode with fail-fast
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Standard -CI -FailFast

# Quick module check
./Quick-ModuleCheck.ps1 -MaxParallelJobs 8

# Run all module tests
./tests/Run-AllModuleTests.ps1
```

### Linting Commands

```powershell
# PowerShell comprehensive lint
./comprehensive-lint-analysis.ps1

# JavaScript linting (from mcp-server directory)
cd mcp-server && npm run lint
```

### Build and Release

```powershell
# Create local releases (without pushing)
./Quick-Release.ps1 -Type Patch -NoPush
./Quick-Release.ps1 -Type Minor -NoPush
./Quick-Release.ps1 -Type Major -NoPush
```

## Architecture and Code Structure

### Module System

AitherZero uses a modular PowerShell architecture with 14+ specialized modules:

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
```

### Dynamic Repository Detection

The project works across fork chains (AitherZero → AitherLabs → Aitherium):
```powershell
$repoInfo = Get-GitRepositoryInfo
$targetRepo = "$($repoInfo.Owner)/$($repoInfo.Name)"
```

## VS Code Integration

The project includes 100+ pre-configured VS Code tasks in `.vscode/tasks.json`:

- **Testing**: Quick/Standard/Complete validation tasks
- **PatchManager**: Create patches, rollback, validate modules
- **Development**: Setup environment, import modules
- **Build**: Create local packages for different platforms

Access tasks via: `Ctrl+Shift+P → Tasks: Run Task`

## Key Files and Locations

- **Entry Point**: `Start-AitherZero.ps1`
- **Core Application**: `aither-core/aither-core.ps1`
- **Modules**: `aither-core/modules/`
- **Shared Utilities**: `aither-core/shared/`
- **Tests**: `tests/`
- **Configurations**: `configs/`
- **MCP Server**: `mcp-server/`
- **OpenTofu Templates**: `opentofu/`

## Development Guidelines

1. **PowerShell Version**: Always target PowerShell 7.0+ with cross-platform compatibility
2. **Testing**: Run Quick validation before commits, Standard before PRs
3. **Logging**: Use Write-CustomLog for all output
4. **Paths**: Use Join-Path for all path construction
5. **Git Operations**: Use PatchManager, never direct git commands
6. **Module Dependencies**: Import existing modules rather than reimplementing
7. **Error Handling**: Comprehensive try-catch with logging
8. **Code Style**: One True Brace Style (OTBS) with consistent formatting

## Important Notes

- The main branch is `main` (not master)
- GitHub Actions run on develop branch and PRs
- The project supports Windows, Linux, and macOS
- Always use absolute paths with platform-agnostic construction
- PatchManager v2.1 is consolidated to 4 core functions
- Bulletproof validation has three levels: Quick (30s), Standard (2-5m), Complete (10-15m)