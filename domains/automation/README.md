# Automation Domain

The Automation domain provides comprehensive deployment automation, parallel execution, dependency management, and reusable script utilities.

## Responsibilities

- Automated deployment orchestration
- Parallel script execution with dependency resolution
- Cross-platform installation automation
- Infrastructure provisioning automation
- CI/CD pipeline integration
- **Common script utilities to eliminate code duplication**

## Status

✅ **Active** - Core functionality implemented

## Core Modules

### ScriptUtilities.psm1 ⭐ NEW
**Purpose**: Eliminate duplicate code across 125+ automation scripts

Provides reusable helper functions used by automation scripts:
- **Write-ScriptLog**: Centralized logging wrapper with fallback
- **Get-ProjectRoot**: Determine AitherZero project root path
- **Test-IsAdministrator**: Check for admin/root privileges
- **Get-PlatformName**: Get platform name (Windows/Linux/macOS)
- **Test-CommandAvailable**: Check if a command exists
- **Get-GitHubToken**: Retrieve GitHub authentication token
- **Invoke-WithRetry**: Execute script blocks with retry logic
- **Test-GitRepository**: Check if in a Git repository
- **Get-ScriptMetadata**: Extract metadata from script headers
- **Format-Duration**: Format TimeSpan into readable string

**Usage in automation scripts**:
```powershell
# Import at the top of your script
$ProjectRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $ProjectRoot "domains/automation/ScriptUtilities.psm1") -Force

# Use the functions
Write-ScriptLog -Message "Starting process" -Level Information
$root = Get-ProjectRoot
if (Test-IsAdministrator) {
    Write-ScriptLog "Running with elevated privileges"
}
```

### DeploymentAutomation.psm1
The primary automation engine providing:
- **Parallel Execution**: Run multiple scripts concurrently with configurable limits
- **Dependency Resolution**: Automatic topological sorting of script dependencies
- **Cross-Platform Support**: Works on Windows, Linux, and macOS
- **Integrated Logging**: Uses centralized logging from utilities domain
- **Stage-Based Execution**: Run specific deployment stages (Prepare, Core, Services, etc.)

### OrchestrationEngine.psm1
Advanced workflow orchestration with:
- **Playbook-based execution**: Define complex workflows
- **Sequence management**: Group scripts into logical sequences
- **Configuration-driven**: Use config.psd1 for workflow definitions

## Key Features

### Automated Script Discovery
Scripts are automatically discovered from the `automation-scripts` directory based on naming convention:
- Format: `NNNN_ScriptName.ps1` where NNNN is the priority (0000-9999)
- Lower numbers execute first
- Scripts can define dependencies and stages in their headers

### Script Metadata
Scripts can include metadata in comments:
```powershell
# Stage: Core
# Dependencies: Git, PowerShell7
# Tags: development, tools
```

### Parallel Execution Engine
- Uses ThreadJob module for true parallel execution
- Respects dependencies - won't start a script until its dependencies complete
- Configurable concurrency limits
- Automatic timeout handling

## Usage Examples

### Using ScriptUtilities in your scripts
```powershell
#Requires -Version 7.0
# Stage: Development
# Dependencies: Git

[CmdletBinding(SupportsShouldProcess)]
param()

# Import script utilities (replaces manual Write-ScriptLog definitions)
$ProjectRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $ProjectRoot "domains/automation/ScriptUtilities.psm1") -Force

Write-ScriptLog -Message "Starting installation" -Level Information

try {
    if (-not (Test-CommandAvailable -Name 'git')) {
        Write-ScriptLog -Message "Git is required" -Level Error
        exit 1
    }
    
    # Use Invoke-WithRetry for operations that may fail
    Invoke-WithRetry -ScriptBlock {
        git clone https://github.com/user/repo.git
    } -MaxAttempts 3 -DelaySeconds 5
    
    Write-ScriptLog -Message "Installation completed" -Level Information
} catch {
    Write-ScriptLog -Message "Installation failed: $_" -Level Error
    exit 1
}
```

### Using DeploymentAutomation
```powershell
# Import the automation domain
Import-Module ./domains/automation/DeploymentAutomation.psm1

# Run all automation scripts
Start-DeploymentAutomation

# Run with specific configuration
Start-DeploymentAutomation -Configuration @{
    Profile = "Developer"
    MaxRetries = 3
}

# Run only specific stage
Start-DeploymentAutomation -Stage "Core" -MaxConcurrency 4

# Dry run to see execution plan
Start-DeploymentAutomation -DryRun

# Run from configuration file
Start-DeploymentAutomation -Configuration "./deployment-config.json"
```

## Script Organization

Scripts in `automation-scripts/` are organized by priority and function:
- **0000-0099**: Environment preparation and prerequisites
- **0100-0199**: Core infrastructure components
- **0200-0299**: Development tools and utilities
- **0300-0399**: Services and applications
- **0400-0499**: Configuration, testing, and validation
- **0500-0599**: Reporting and metrics
- **0700-0799**: Git automation and AI tools
- **9000-9999**: Cleanup and maintenance

## Integration with Bootstrap

The bootstrap script (`bootstrap.ps1`) automatically:
1. Ensures PowerShell 7 is installed
2. Installs Git if needed
3. Clones the repository
4. Launches the main application which can invoke deployment automation

## Best Practices

1. **Use ScriptUtilities** - Import the module instead of duplicating helper functions
2. **Always use stages** - Group related scripts into logical stages
3. **Define dependencies** - Explicitly declare script dependencies
4. **Use Write-ScriptLog** - Centralized logging with automatic fallback
5. **Handle errors gracefully** - Scripts should be idempotent
6. **Test in dry-run mode** - Always test with -DryRun first
7. **Check platform compatibility** - Use Get-PlatformName and Test-IsAdministrator

## Code Deduplication Initiative

**Status**: 22 scripts refactored (0000-0499 range completed)

Previously, 55+ scripts had duplicate implementations of:
- Write-ScriptLog function (~40 lines each)
- Logging module initialization
- Basic utility functions

**ScriptUtilities.psm1** eliminates this duplication by providing:
- Single source of truth for common functions
- Automatic fallback for logging
- Cross-platform compatibility helpers
- Reusable patterns for all automation scripts

**Refactored scripts** (22 total):
- 0000-0099 range: 7 scripts
- 0100-0199 range: 5 scripts  
- 0200-0299 range: 7 scripts
- 0400-0499 range: 3 scripts

## Migration from LabRunner

This module is the evolution of the original LabRunner, providing:
- Better dependency management
- True parallel execution
- Stage-based organization
- Integrated with domain architecture
- Uses centralized logging throughout
- **Reusable utilities to eliminate code duplication**