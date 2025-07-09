# Automation Domain

This domain handles script and automation management for AitherCore.

## Consolidated Modules

### ScriptManager
**Original Module**: `aither-core/modules/ScriptManager/`  
**Status**: Consolidated  
**Key Functions**:
- `Get-ScriptTemplate`
- `Invoke-OneOffScript`
- `Start-ScriptExecution`
- `Get-ScriptRepository`

## Automation Architecture

The automation domain provides script management and execution:

```
Automation Domain
├── ScriptManager (Core Service)
│   ├── Script Templates
│   ├── Script Execution
│   ├── Script Repository
│   └── One-Off Scripts
```

## Implementation Structure

```
automation/
├── ScriptManager.ps1           # Script management functions
└── README.md                  # This file
```

## Usage Examples

```powershell
# Get script template
$template = Get-ScriptTemplate -TemplateName "PowerShellModule"

# Execute one-off script
Invoke-OneOffScript -ScriptPath "./scripts/maintenance.ps1" -Parameters @{Mode = "Quick"}

# Start script execution with monitoring
Start-ScriptExecution -ScriptName "DeploymentScript" -ShowProgress

# Get script repository information
$repo = Get-ScriptRepository -RepositoryName "MaintenanceScripts"
```

## Features

### Script Templates
- Predefined script templates for common tasks
- Customizable template parameters
- Version control for template updates

### Script Execution
- Monitored script execution with progress tracking
- Error handling and recovery
- Logging integration with AitherCore

### Script Repository
- Centralized script storage and management
- Script versioning and metadata
- Access control and permissions

### One-Off Scripts
- Quick execution of maintenance scripts
- Parameter validation and sanitization
- Execution context isolation

## Integration

The automation domain integrates with:
- **Infrastructure Domain**: For infrastructure automation scripts
- **Configuration Domain**: For configuration management scripts
- **Security Domain**: For security automation scripts
- **Logging**: All script execution is logged

## Testing

Automation domain tests are located in:
- `tests/domains/automation/`
- Integration tests in `tests/integration/`

## Dependencies

- **Write-CustomLog**: Guaranteed available from AitherCore orchestration
- **Configuration Services**: Uses unified configuration management
- **Security Services**: Secure script execution and storage