# AitherZero Module Architecture (v2.0)

## Overview

AitherZero has been consolidated from 30+ modules to 23 active modules through careful analysis and deduplication. This document describes the current module architecture and organization.

## Module Categories

### Core Infrastructure (4 modules - Required)

These modules provide essential functionality that all other modules depend on:

1. **Logging** - Centralized logging system with multiple output targets
2. **LicenseManager** - Feature licensing and access control
3. **ConfigurationCore** - Core configuration management and settings
4. **ModuleCommunication** - Inter-module messaging bus and event system

### Feature Modules (19 modules - Optional)

These modules provide specific functionality and can be loaded as needed:

#### Automation & Orchestration
- **LabRunner** - Lab automation orchestration and script execution
- **OrchestrationEngine** - Advanced workflow and playbook execution
- **ParallelExecution** - Runspace-based parallel task execution

#### Development & Operations
- **PatchManager** (v3.0) - Git workflow automation with atomic operations
- **DevEnvironment** - Development environment setup and configuration
- **TestingFramework** - Unified test orchestration with Pester integration
- **BackupManager** - File backup and consolidation utilities

#### Infrastructure & Deployment
- **OpenTofuProvider** - OpenTofu/Terraform infrastructure deployment
- **CloudProviderIntegration** - Cloud provider abstractions
- **ConfigurationCarousel** - Multi-environment configuration management
- **ConfigurationRepository** - Git-based configuration repository management

#### System Management
- **SystemMonitoring** - Real-time system performance monitoring
- **SecureCredentials** - Enterprise credential management
- **RemoteConnection** - Multi-protocol remote connections
- **ISOManager** - ISO download and management
- **ISOCustomizer** - ISO customization tools

#### User Experience
- **UserExperience** - Unified user interaction (consolidated from SetupManager, StartupExperience, and SetupWizard)
- **ProgressTracking** - Visual progress feedback for long operations
- **AIToolsIntegration** - AI development tools management

### Compatibility Layer

- **compatibility/** - Backward compatibility shims for deprecated modules

## Module Consolidation Details

### Modules Consolidated into UserExperience
- SetupManager → UserExperience
- StartupExperience → UserExperience  
- SetupWizard → UserExperience (maintained as alias)

### Modules Consolidated into UtilityServices
- UtilityManager → UtilityServices
- ScriptManager → UtilityServices
- RepoSync → UtilityServices
- UnifiedMaintenance → UtilityServices

### Modules Consolidated into CloudProviderIntegration
- CloudProvider → CloudProviderIntegration
- CloudIntegration → CloudProviderIntegration

### Deprecated Modules (Removed)
- RestAPIServer (functionality moved to other modules)
- SecurityAutomation (functionality moved to SecureCredentials)
- StartupExperience (consolidated into UserExperience)

## Module Communication

All modules communicate through the ModuleCommunication bus using:

- **APIs**: `Register-ModuleAPI` and `Invoke-ModuleAPI`
- **Events**: `Submit-ModuleEvent` and `Register-ModuleEventHandler`
- **Messages**: `Submit-ModuleMessage` for direct messaging

Note: Functions now use approved PowerShell verbs (Submit instead of Send, Register instead of Subscribe).

## Module Dependencies

### Dependency Hierarchy

```
Tier 1 (No Dependencies):
└── Logging

Tier 2 (Depends on Logging):
├── LicenseManager
├── ConfigurationCore
└── ModuleCommunication

Tier 3 (Depends on Tier 1-2):
├── All Feature Modules
└── Compatibility Shims
```

### Common Dependencies

Most feature modules depend on:
- Logging (for centralized logging)
- ModuleCommunication (for inter-module communication)
- ConfigurationCore (for settings management)

## Module Loading

Modules are loaded through several mechanisms:

1. **Core Auto-Loading**: Core modules load automatically at startup
2. **Feature Loading**: Feature modules load based on configuration or explicit request
3. **Lazy Loading**: Some modules load only when their functions are called
4. **Compatibility Loading**: Shim modules load to support legacy code

## Best Practices

1. **Use Core Modules**: Always leverage core infrastructure rather than reimplementing
2. **Communicate Through Bus**: Use ModuleCommunication for inter-module interaction
3. **Follow Naming Conventions**: Use approved PowerShell verbs in all functions
4. **Maintain Compatibility**: Update references when modules are consolidated
5. **Test Integration**: Ensure modules work together after changes

## Migration from Previous Architecture

If you have code referencing deprecated modules:

1. Update imports to use new consolidated modules
2. Use compatibility shims during transition
3. Update function calls to use new approved verbs
4. Test thoroughly after migration

Example migrations:
```powershell
# Old
Import-Module SetupManager
Send-ModuleMessage -Message "Hello"

# New  
Import-Module UserExperience
Submit-ModuleMessage -Message "Hello"
```

## Future Considerations

1. **Further Consolidation**: Additional opportunities exist to merge related modules
2. **Remove Compatibility Shims**: After migration period, remove backward compatibility
3. **Module Versioning**: Implement semantic versioning for all modules
4. **Performance Optimization**: Profile and optimize module loading times