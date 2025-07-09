# AitherZero Core Orchestration System

## Overview

**AitherZero Core** has been completely redesigned with a **consolidated module architecture** that provides enterprise-grade orchestration, unified management, and seamless coordination of all infrastructure automation components.

### Consolidated Architecture (v2.0)

- **Consolidated Module System**: Unified loading and management of 25+ specialized modules
- **Intelligent Dependency Resolution**: Automatic module dependency detection and loading order
- **Backward Compatibility Layer**: 100% compatibility with existing scripts and functions
- **Unified Status Reporting**: Real-time module health monitoring and statistics
- **Graceful Degradation**: Core functionality continues even if optional modules fail
- **Enhanced Error Recovery**: Comprehensive error handling with detailed troubleshooting guidance

## Consolidated Module System Functions

### `Get-ConsolidatedModuleStatus`
Real-time status of all modules in the consolidated architecture.
```powershell
# Get overview of all modules
Get-ConsolidatedModuleStatus | Format-Table Name, Loaded, Version, Category, Required

# Get detailed information for a specific module
Get-ConsolidatedModuleStatus -ModuleName "PatchManager" -Detailed

# Get detailed information for all modules
Get-ConsolidatedModuleStatus -Detailed
```

### `Show-ModuleLoadingSummary`
Visual summary of module loading statistics and health.
```powershell
# Display comprehensive loading summary
Show-ModuleLoadingSummary
```

### Backward Compatibility Functions
Legacy function mappings that redirect to new consolidated functions:
```powershell
# These legacy functions automatically redirect to new implementations
Start-CoreApplication           # → Start-LabRunner
Initialize-CoreApplication      # → Initialize-LabRunner
Get-CoreApplicationStatus       # → Get-LabRunnerStatus
Start-InfrastructureDeployment  # → Start-OpenTofuDeployment
Start-CredentialManagement      # → Start-SecureCredentials
```

## Consolidated Module Ecosystem

### Core Infrastructure Modules (Required)
- **Logging**: Centralized logging system with multiple targets
- **LicenseManager**: Feature licensing and access control
- **ConfigurationCore**: Unified configuration management
- **ModuleCommunication**: Inter-module messaging bus

### Consolidated Feature Modules (25+ Modules)
- **LabRunner**: Lab automation and orchestration
- **PatchManager**: Git workflow automation with PR/issue creation
- **BackupManager**: Backup and recovery operations
- **DevEnvironment**: Development environment setup and management
- **OpenTofuProvider**: Infrastructure as code deployment
- **SecureCredentials**: Enterprise credential management
- **RemoteConnection**: Multi-protocol remote connections
- **SystemMonitoring**: System performance monitoring
- **ParallelExecution**: Parallel task execution with runspaces
- **ISOManager**: ISO download and management
- **ISOCustomizer**: ISO customization and templates
- **TestingFramework**: Unified testing with Pester integration
- **SetupWizard**: First-time setup with installation profiles
- **StartupExperience**: Enhanced startup UI and experience
- **ConfigurationCarousel**: Multi-environment configuration switching
- **ConfigurationRepository**: Git-based configuration management
- **OrchestrationEngine**: Advanced workflow and playbook execution
- **ProgressTracking**: Visual progress feedback for operations
- **AIToolsIntegration**: AI development tools (Claude Code, Gemini, etc.)
- **RestAPIServer**: REST API endpoints and webhooks
- **RepoSync**: Repository synchronization
- **ScriptManager**: Script repository and template management
- **SecurityAutomation**: Security hardening and compliance
- **UnifiedMaintenance**: System maintenance operations
- **PSScriptAnalyzerIntegration**: PowerShell analysis and quality

## Usage

### Quick Start with Consolidated Architecture
```powershell
# Run AitherZero with consolidated module loading
./Start-AitherZero.ps1

# Run with detailed module loading information
./Start-AitherZero.ps1 -Verbosity detailed

# Run specific modules
./Start-AitherZero.ps1 -Scripts "PatchManager,BackupManager"

# First-time setup with consolidated architecture
./Start-AitherZero.ps1 -Setup -InstallationProfile developer
```

### Module Status and Management
```powershell
# Check consolidated module status
Get-ConsolidatedModuleStatus | Format-Table

# Get detailed module information
Get-ConsolidatedModuleStatus -Detailed | Out-GridView

# Show loading summary
Show-ModuleLoadingSummary

# Check specific module
Get-ConsolidatedModuleStatus -ModuleName "PatchManager" -Detailed
```

### Backward Compatible Usage
```powershell
# All existing scripts continue to work exactly as before
./Start-AitherZero.ps1 -Auto
./Start-AitherZero.ps1 -WhatIf

# Legacy function calls are automatically redirected
Start-CoreApplication -ConfigPath ./configs/default-config.json
```

### Advanced Consolidated Features
```powershell
# Import specific consolidated modules manually
Import-Module "./aither-core/modules/PatchManager" -Force
Import-Module "./aither-core/modules/OrchestrationEngine" -Force

# Use new unified functions
New-Patch -Description "Update documentation" -Changes {
    # Your changes here
}

# Access consolidated module capabilities
Invoke-PlaybookWorkflow -PlaybookName "deployment-workflow"
Start-SystemMonitoring -EnableReporting
```

## Migration Guide

### For Existing Users (100% Backward Compatibility)
**Zero changes required!** All existing code continues to work exactly as before:
- All existing scripts and functions work unchanged
- Entry points remain the same: `./Start-AitherZero.ps1`
- All parameters and options preserved
- Legacy function calls automatically redirected to new implementations

### For New Development (Recommended)
Leverage the new consolidated architecture for enhanced capabilities:
1. Use `Get-ConsolidatedModuleStatus` to check module availability
2. Use `Show-ModuleLoadingSummary` for comprehensive health checks
3. Access 25+ consolidated modules for advanced features
4. Utilize new unified error handling and recovery mechanisms

### Migration Benefits
- **Enhanced Performance**: Optimized module loading with dependency resolution
- **Better Diagnostics**: Comprehensive module status tracking and reporting
- **Graceful Degradation**: Core functionality continues if optional modules fail
- **Unified Experience**: Consistent interface across all 25+ modules

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

## Consolidated Architecture Benefits

### Before (Individual Module Management)
```
User → Manual Module Import → Individual Modules → Separate Operations
- Manual dependency resolution
- Individual error handling
- Separate configuration per module
- No unified status reporting
```

### After (Consolidated Architecture)
```
User → AitherZero Core → Consolidated Module System → Coordinated Operations
- Automatic dependency resolution
- Unified error handling and recovery
- Centralized configuration management  
- Real-time module status tracking
```

### Architectural Advantages
- **Intelligent Module Loading**: Automatic dependency resolution and loading order
- **Unified Status Reporting**: Real-time health monitoring across all 25+ modules
- **Graceful Degradation**: Core functionality continues even if optional modules fail
- **Enhanced Error Recovery**: Comprehensive error handling with detailed troubleshooting
- **Backward Compatibility**: 100% compatibility with existing scripts and workflows
- **Centralized Configuration**: Shared configuration management across all modules
- **Performance Optimization**: Optimized loading strategies and resource management

## Module Dependency Resolution System

### Overview
AitherZero now includes an intelligent dependency resolution system that automatically determines the correct module load order based on module dependencies. This ensures that modules are loaded in the proper sequence, preventing dependency-related errors.

### Key Features
- **Automatic Dependency Detection**: Reads module manifest files to extract dependencies
- **Topological Sorting**: Uses Kahn's algorithm to determine optimal load order
- **Circular Dependency Handling**: Detects and gracefully handles circular dependencies
- **Logging Module Priority**: Ensures the Logging module is always loaded first
- **Visual Dependency Reporting**: Generate dependency graphs and reports

### Usage

#### Get Module Dependencies
```powershell
# Analyze all module dependencies
$dependencies = Get-ModuleDependencies

# Include optional dependencies
$dependencies = Get-ModuleDependencies -IncludeOptional
```

#### Resolve Module Load Order
```powershell
# Get the optimal load order for all modules
$loadOrder = Resolve-ModuleLoadOrder -DependencyGraph $dependencies

# Get load order for specific modules (includes their dependencies)
$loadOrder = Resolve-ModuleLoadOrder -DependencyGraph $dependencies -ModulesToLoad @('PatchManager', 'TestingFramework')
```

#### Generate Dependency Reports
```powershell
# Table view (default)
Get-ModuleDependencyReport

# Visual dependency graph
Get-ModuleDependencyReport -OutputFormat Graph

# Detailed list view
Get-ModuleDependencyReport -OutputFormat List

# Export as JSON
Get-ModuleDependencyReport -OutputFormat Json | Out-File dependencies.json
```

### Example Dependency Report
```
=== Module Dependency Report ===
Generated: 2025-01-09 10:30:00
Total Modules: 30

Load Order:
  1. Logging                    (no dependencies)
  2. ConfigurationCore          (no dependencies)
  3. ModuleCommunication        → Logging
  4. LicenseManager            → Logging
  5. ConfigurationCarousel     → ConfigurationCore, Logging
  ...

Dependency Summary:
Name                     DependencyCount DependencyDepth Status
----                     --------------- --------------- ------
TestingFramework                       3               2 OK
PatchManager                          2               1 OK
ConfigurationCarousel                 2               1 OK
```

### Testing Dependency Resolution
```powershell
# Run the dependency resolution test
./aither-core/tests/Test-DependencyResolution.ps1 -Verbose
```

## Version History

- **1.0.0**: Original individual module system
- **2.0.0**: **NEW** - Consolidated module architecture with intelligent orchestration
- **2.1.0**: Enhanced backward compatibility and unified status reporting

## Related

- [Unified Maintenance System](../../scripts/maintenance/)
- [Module Development Guide](../modules/)
- [Project Standards](../../.github/instructions/)
- [Testing Framework](../modules/TestingFramework/)
