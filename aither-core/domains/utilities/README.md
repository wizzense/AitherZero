# Utilities Domain

> 🔧 **Shared Services & Utilities** - Semantic versioning, license management, maintenance operations, and common utilities

This domain consolidates **6 legacy modules** into **24 specialized functions** for shared utility services.

## Domain Overview

**Function Count**: 24 functions  
**Legacy Modules Consolidated**: 6 (SemanticVersioning, LicenseManager, RepoSync, UnifiedMaintenance, UtilityServices, PSScriptAnalyzerIntegration)  
**Primary Use Cases**: Version management, license compliance, repository synchronization, maintenance operations

## Consolidated Components

### SemanticVersioning (8 functions)
**Original Module**: `aither-core/modules/SemanticVersioning/`  
**Status**: ✅ Consolidated  
**Purpose**: Semantic version management and calculations

**Key Functions**:
- `Get-NextSemanticVersion` - Calculate next semantic version based on change type
- `Compare-SemanticVersion` - Compare semantic versions for precedence
- `Test-SemanticVersionFormat` - Validate semantic version format
- `New-SemanticVersion` - Create semantic version objects

### LicenseManager (3 functions)
**Original Module**: `aither-core/modules/LicenseManager/`  
**Status**: ✅ Consolidated  
**Purpose**: License management and feature access control

**Key Functions**:
- `Test-FeatureAccess` - Test access to licensed features
- `Get-LicenseStatus` - Retrieve current license status
- `Set-License` - Configure license for organization

### RepoSync (2 functions)
**Original Module**: `aither-core/modules/RepoSync/`  
**Status**: ✅ Consolidated  
**Purpose**: Repository synchronization utilities

**Key Functions**:
- `Sync-ToAitherLab` - Synchronize to AitherLab repository
- `Sync-RepositoryChanges` - Synchronize repository changes

### UnifiedMaintenance (3 functions)
**Original Module**: `aither-core/modules/UnifiedMaintenance/`  
**Status**: ✅ Consolidated  
**Purpose**: Unified maintenance operations

**Key Functions**:
- `Invoke-UnifiedMaintenance` - Perform comprehensive maintenance
- `Get-MaintenanceStatus` - Check system maintenance status
- `Start-MaintenanceMode` - Enable maintenance mode

### UtilityServices (7 functions)
**Original Module**: `aither-core/modules/UtilityServices/`  
**Status**: ✅ Consolidated  
**Purpose**: Common utility functions and cross-platform helpers

**Key Functions**:
- `Get-CrossPlatformPath` - Cross-platform path operations
- `Test-PlatformFeature` - Platform feature detection
- `Invoke-PlatformFeatureWithFallback` - Platform-aware execution
- `ConvertTo-SafeFileName` - Generate safe filenames

### PSScriptAnalyzerIntegration (1 function)
**Original Module**: `aither-core/modules/PSScriptAnalyzerIntegration/`  
**Status**: ✅ Consolidated  
**Purpose**: PowerShell code analysis integration

**Key Functions**:
- `Invoke-PSScriptAnalyzerScan` - Run PowerShell code analysis

## Utilities Architecture

The utilities domain provides shared services across all AitherCore domains:

```
Utilities Domain (24 functions)
├── SemanticVersioning (8 functions)
│   ├── Version Calculation
│   ├── Version Comparison  
│   └── Version Validation
├── LicenseManager (3 functions)
│   ├── Feature Access Control
│   ├── License Validation
│   └── Compliance Monitoring
├── RepoSync (2 functions)
│   ├── Repository Synchronization
│   └── Change Management
├── UnifiedMaintenance (3 functions)
│   ├── System Maintenance
│   ├── Cleanup Operations
│   └── Health Monitoring
├── UtilityServices (7 functions)
│   ├── Cross-Platform Helpers
│   ├── Common Utilities
│   └── Shared Resources
└── PSScriptAnalyzerIntegration (1 function)
    └── Code Quality Analysis
```

## Implementation Structure

```
utilities/
├── Utilities.ps1              # All consolidated utility functions (24 functions)
└── README.md                  # This documentation
```

## Usage Examples

```powershell
# Cross-platform path operations
$path = Get-CrossPlatformPath -Path "configs/app-config.json"

# Common utility functions
$result = Invoke-UtilityFunction -Function "ValidateInput" -Parameters @{Input = $userInput}

# Service implementations
$service = Get-UtilityService -ServiceName "FileProcessor"
```

## Features

### Cross-Platform Helpers
- Path manipulation and validation
- File system operations
- Platform-specific implementations

### Common Utilities
- Input validation and sanitization
- Data transformation functions
- Error handling utilities

### Service Implementations
- Shared service patterns
- Common business logic
- Reusable components

### Shared Resources
- Configuration templates
- Common data structures
- Utility constants

## Integration

The utilities domain is used by:
- **Infrastructure Domain**: For infrastructure utilities
- **Configuration Domain**: For configuration utilities
- **Security Domain**: For security utilities
- **Automation Domain**: For automation utilities
- **Experience Domain**: For user experience utilities

## Testing

Utilities domain tests are located in:
- `tests/domains/utilities/`
- Integration tests in `tests/integration/`

## Dependencies

- **Write-CustomLog**: Guaranteed available from AitherCore orchestration
- **Platform Services**: Cross-platform compatibility
- **Configuration Services**: Uses unified configuration management