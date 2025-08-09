# Automation Domain

The Automation domain provides comprehensive deployment automation, parallel execution, and dependency management capabilities.

## Responsibilities

- Automated deployment orchestration
- Parallel script execution with dependency resolution
- Cross-platform installation automation
- Infrastructure provisioning automation
- CI/CD pipeline integration

## Status

✅ **Active** - Core functionality implemented

## Core Modules

### DeploymentAutomation.psm1
The primary automation engine providing:
- **Parallel Execution**: Run multiple scripts concurrently with configurable limits
- **Dependency Resolution**: Automatic topological sorting of script dependencies
- **Cross-Platform Support**: Works on Windows, Linux, and macOS
- **Integrated Logging**: Uses centralized logging from utilities domain
- **Stage-Based Execution**: Run specific deployment stages (Prepare, Core, Services, etc.)

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
```

### Parallel Execution Engine
- Uses ThreadJob module for true parallel execution
- Respects dependencies - won't start a script until its dependencies complete
- Configurable concurrency limits
- Automatic timeout handling

## Usage Examples

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
- **0400-0499**: Configuration and customization
- **0500-0599**: Validation and testing
- **9000-9999**: Cleanup and maintenance

## Integration with Bootstrap

The bootstrap script (`bootstrap.ps1`) automatically:
1. Ensures PowerShell 7 is installed
2. Installs Git if needed
3. Clones the repository
4. Launches the main application which can invoke deployment automation

## Best Practices

1. **Always use stages** - Group related scripts into logical stages
2. **Define dependencies** - Explicitly declare script dependencies
3. **Use centralized logging** - All scripts should use Write-CustomLog
4. **Handle errors gracefully** - Scripts should be idempotent
5. **Test in dry-run mode** - Always test with -DryRun first

## Migration from LabRunner

This module is the evolution of the original LabRunner, providing:
- Better dependency management
- True parallel execution
- Stage-based organization
- Integrated with domain architecture
- Uses centralized logging throughout