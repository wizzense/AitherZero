# AitherCore - Essential Modules for Basic Releases

## Overview

The `aithercore` directory contains the consolidated essential modules required for basic AitherZero releases. These modules form the minimal foundation needed to run core functionality without the full suite of domains.

## Purpose

This consolidation serves several key purposes:

1. **Minimal Distribution**: Enable lightweight releases with only core functionality
2. **Dependency Clarity**: Clearly identify and isolate critical dependencies
3. **Quick Start**: Allow users to get started with minimal module loading
4. **Basic Operations**: Support fundamental operations without advanced features

## Included Modules

### Core Foundation (Required by most modules)

#### 1. Logging.psm1
- **Size**: ~959 lines
- **Dependencies**: None
- **Used by**: 30+ modules across all domains
- **Purpose**: Centralized logging with structured output, audit logs, performance tracing
- **Key Functions**: `Write-CustomLog`, `Initialize-Logging`, `Write-AuditLog`

#### 2. Configuration.psm1
- **Size**: ~1091 lines
- **Dependencies**: None (may use Logging optionally)
- **Used by**: 15+ modules
- **Purpose**: Configuration management, environment switching, feature flags
- **Key Functions**: `Get-Configuration`, `Set-Configuration`, `Get-ConfigValue`

#### 3. TextUtilities.psm1
- **Size**: ~69 lines
- **Dependencies**: None
- **Used by**: UI modules
- **Purpose**: Text formatting and spacing utilities
- **Key Functions**: `Repair-TextSpacing`

### User Interface

#### 4. BetterMenu.psm1
- **Size**: ~488 lines
- **Dependencies**: TextUtilities
- **Purpose**: Interactive menu system with keyboard navigation
- **Key Functions**: `Show-BetterMenu`

#### 5. UserInterface.psm1
- **Size**: ~1029 lines
- **Dependencies**: TextUtilities, Configuration, BetterMenu
- **Purpose**: Unified UI system with menus, progress tracking, notifications
- **Key Functions**: `Show-UIMenu`, `Show-UIProgress`, `Show-UINotification`, `Initialize-AitherUI`

### Infrastructure & Security

#### 6. Infrastructure.psm1
- **Size**: ~182 lines
- **Dependencies**: Logging
- **Purpose**: Lightweight infrastructure essentials and provider detection
- **Key Functions**: `Initialize-Infrastructure`, `Get-InfrastructureProvider`

#### 7. Security.psm1
- **Size**: ~266 lines
- **Dependencies**: Logging
- **Purpose**: Security essentials, credential/certificate management
- **Key Functions**: Security and credential handling

### Orchestration

#### 8. OrchestrationEngine.psm1
- **Size**: ~1488 lines
- **Dependencies**: Logging, Configuration
- **Purpose**: Core orchestration system for script execution
- **Key Functions**: `Invoke-OrchestrationSequence`, `Get-OrchestrationPlaybook`

## Total Size

**Total Lines**: ~5,572 lines
**Total Modules**: 8 core modules

This represents approximately 23% of the total module codebase but provides 100% of the critical foundation functionality.

## Dependency Graph

```
TextUtilities (no deps)
    └── BetterMenu
        └── UserInterface
            └── (depends also on Configuration)

Logging (no deps)
    ├── Configuration (optional)
    ├── Infrastructure
    ├── Security
    └── OrchestrationEngine (also needs Configuration)
```

## Usage

### Loading AitherCore Only

```powershell
# Load the aithercore module
Import-Module ./aithercore/AitherCore.psd1

# Verify loaded
Get-Module AitherCore
```

### Loading Full AitherZero

```powershell
# Load the complete platform (includes all domains)
Import-Module ./AitherZero.psd1
```

## What's NOT Included

The following domains are NOT in aithercore (available in full release only):

- **development**: Git automation, issue tracking, PR management
- **documentation**: Documentation generation, project indexing
- **reporting**: Advanced reporting, tech debt analysis
- **testing**: Testing frameworks, quality validation, test generation
- **ai-agents**: AI workflow orchestration, Claude/Copilot integration
- **automation**: Advanced deployment automation (beyond core orchestration)

## Use Cases

### Basic Release
- Simple infrastructure operations
- Basic configuration management
- Interactive menus and UI
- Core logging
- Script orchestration

### Development/Testing
- Use full AitherZero.psd1 for complete functionality
- Includes all domains and advanced features

## Module Loading Order

When loading aithercore modules, follow this order:

1. TextUtilities (no dependencies)
2. Logging (no dependencies)
3. Configuration (optional Logging dependency)
4. BetterMenu (needs TextUtilities)
5. UserInterface (needs TextUtilities, Configuration, BetterMenu)
6. Infrastructure (needs Logging)
7. Security (needs Logging)
8. OrchestrationEngine (needs Logging, Configuration)

This order is automatically handled by the AitherCore.psm1 loader.

## Maintenance

When updating modules in the main `domains/` directory, remember to:

1. Evaluate if the change affects aithercore modules
2. Copy updated modules to aithercore if needed
3. Test aithercore loading independently
4. Update this documentation if dependencies change

## Future Considerations

- Consider versioning aithercore separately from full releases
- May add minimal testing module subset for validation
- Could extract even smaller "micro" core for embedded scenarios
