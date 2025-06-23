# Core Application Module (CoreApp)

## Overview

**CoreApp is now the parent orchestration module** for the entire OpenTofu Lab Automation ecosystem. It provides unified management and coordination of all other modules while maintaining backward compatibility with existing functionality.

### Architecture Changes

- **Parent Module**: CoreApp now orchestrates all other modules
- **Unified Interface**: Single point of entry for all lab automation functions
- **Dynamic Module Loading**: Intelligent discovery and loading of available modules
- **Dependency Management**: Handles module dependencies and initialization order
- **Backward Compatibility**: All existing functions continue to work as before

## New Orchestration Functions

### `Initialize-CoreApplication`
Complete ecosystem initialization with environment setup and module loading.
```powershell
# Initialize with required modules only
Initialize-CoreApplication -RequiredOnly

# Initialize with all available modules
Initialize-CoreApplication -Force
```

### `Import-CoreModules`
Dynamic module discovery and import with dependency resolution.
```powershell
# Import only required modules (Logging, LabRunner)
Import-CoreModules -RequiredOnly

# Import all available modules
Import-CoreModules -Force
```

### `Get-CoreModuleStatus`
Comprehensive status of all modules in the ecosystem.
```powershell
Get-CoreModuleStatus | Format-Table Name, Required, Available, Loaded
```

### `Invoke-UnifiedMaintenance`
Orchestrated maintenance across all modules.
```powershell
# Quick maintenance
Invoke-UnifiedMaintenance -Mode Quick

# Full maintenance with auto-fixes
Invoke-UnifiedMaintenance -Mode Full -AutoFix
```

### `Start-DevEnvironmentSetup`
Complete development environment setup through orchestration.
```powershell
Start-DevEnvironmentSetup -Force
```

## Module Ecosystem

### Required Modules
- **Logging**: Centralized logging system ✓
- **LabRunner**: Lab automation and script execution ✓

### Optional Modules  
- **DevEnvironment**: Development environment management ✓
- **PatchManager**: Git-controlled patch management ⚠
- **BackupManager**: Backup and maintenance operations ✓
- **ParallelExecution**: Parallel task execution ✓
- **ScriptManager**: Script management and templates ✓
- **TestingFramework**: Unified testing framework ✓
- **UnifiedMaintenance**: Unified maintenance operations ⚠

*Note: ⚠ indicates modules with current issues that are being addressed*

## Usage

```powershell
# Import the module
Import-Module "$env:PWSH_MODULES_PATH/../core_app/" -Force

# Run the core application
Invoke-CoreApplication -ConfigPath "$env:PROJECT_ROOT/pwsh/core_app/default-config.json"

# Or use individual scripts
& "$env:PROJECT_ROOT/pwsh/core_app/scripts/0008_Install-OpenTofu.ps1"
```

## Usage Examples

### Basic Usage (Backward Compatible)
```powershell
# Traditional usage - still works exactly as before
Import-Module CoreApp
Invoke-CoreApplication -ConfigPath ./default-config.json
```

### New Orchestrated Usage
```powershell
# Modern orchestrated approach
Import-Module CoreApp

# Initialize the complete ecosystem
Initialize-CoreApplication

# Check what's available
Get-CoreModuleStatus

# Run unified maintenance
Invoke-UnifiedMaintenance -Mode Full -AutoFix

# Setup development environment
Start-DevEnvironmentSetup
```

### Advanced Module Management
```powershell
# Load only essential modules for performance
Import-CoreModules -RequiredOnly

# Force reload all modules
Import-CoreModules -Force

# Check loaded modules
Get-CoreModuleStatus | Where-Object { $_.Loaded }
```

## Migration Guide

### For Existing Users
No changes required! All existing code continues to work:
- `Invoke-CoreApplication` - ✓ Works as before
- `Start-LabRunner` - ✓ Works as before  
- `Get-CoreConfiguration` - ✓ Works as before
- `Test-CoreApplicationHealth` - ✓ Works as before

### For New Development
Use the new orchestration functions for enhanced capabilities:
1. Start with `Initialize-CoreApplication`
2. Use `Get-CoreModuleStatus` to check availability
3. Leverage `Invoke-UnifiedMaintenance` for maintenance
4. Use `Start-DevEnvironmentSetup` for environment setup

## Environment Variables

The module relies on these environment variables (automatically set by initialization):

- `$env:PROJECT_ROOT` - Root directory of the project
- `$env:PWSH_MODULES_PATH` - Path to PowerShell modules  
- `$env:PLATFORM` - Current platform (Windows/Linux/macOS)

## Integration

### With Existing Modules
CoreApp now manages and orchestrates:
- All modules in `../modules/` directory
- Dependency resolution and load ordering
- Cross-module communication and shared resources

### With External Tools
- OpenTofu/Terraform configurations
- Git workflows and patch management
- CI/CD pipelines and automation
- Development environment tools

## Key Features

- **Unified Interface**: Single entry point for all functionality
- **Dynamic Discovery**: Automatically finds and loads available modules
- **Dependency Management**: Handles module dependencies intelligently
- **Health Monitoring**: Comprehensive system health checks
- **Backward Compatibility**: 100% compatible with existing code
- **Environment Variable Based**: No hardcoded paths
- **Cross-Platform**: Works on Windows, Linux, and macOS
- **Modular**: Individual components can be used independently
- **Standardized**: Follows project PowerShell standards

## Scripts Included

All original scripts remain available in the `scripts/` directory:
- System configuration scripts (0100-0116)
- Software installation scripts (0200-0216)  
- Infrastructure scripts (0000-0010)
- Maintenance and cleanup scripts (9999)

## Configuration

The `default-config.json` provides standard settings that can be customized for different environments. Configuration is now enhanced with module-specific sections.

## Architecture Benefits

### Before (Individual Modules)
```
User → LabRunner → Individual Scripts
User → PatchManager → Git Operations  
User → BackupManager → Cleanup Tasks
```

### After (CoreApp Orchestration)
```
User → CoreApp → {All Modules} → Coordinated Operations
```

### Advantages
- **Single Point of Entry**: One module to import and manage everything
- **Intelligent Loading**: Only loads what's needed when it's needed
- **Unified Configuration**: Shared configuration across all modules
- **Better Error Handling**: Centralized error management and recovery
- **Enhanced Logging**: Coordinated logging across all components
- **Simplified Maintenance**: One interface for all maintenance operations

## Version History

- **1.0.0**: Original CoreApp implementation
- **2.0.0**: **NEW** - Parent orchestration module with dynamic module management

## Related

- [Unified Maintenance System](../../scripts/maintenance/)
- [Module Development Guide](../modules/)  
- [Project Standards](../../.github/instructions/)
- [Testing Framework](../modules/TestingFramework/)
