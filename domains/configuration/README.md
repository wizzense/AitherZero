# Configuration Domain

The Configuration domain provides centralized configuration management for all AitherZero components.

## Responsibilities

- Centralized configuration storage and retrieval
- Environment-specific configuration management
- Configuration validation and schema enforcement
- Settings persistence and migration
- Configuration hot-reloading

## Key Modules

### Configuration.psm1
Core configuration management functionality.

**Public Functions:**
- `Get-Configuration` - Retrieve configuration values
- `Set-Configuration` - Update configuration values
- `Test-Configuration` - Validate configuration
- `Export-Configuration` - Export configuration to file
- `Import-Configuration` - Import configuration from file

## Usage Examples

```powershell
# Import the core module
Import-Module ./AitherZeroCore.psm1

# Get a configuration value
$vmPath = Get-Configuration -Key "Infrastructure.DefaultVMPath"

# Set a configuration value
Set-Configuration -Key "Logging.Level" -Value "Debug"

# Get entire configuration section
$infraConfig = Get-Configuration -Section "Infrastructure"

# Validate configuration
Test-Configuration -ThrowOnError

# Export configuration
Export-Configuration -Path "./config-backup.json"
```

## Configuration Structure

```json
{
  "Core": {
    "Version": "1.0.0",
    "Environment": "Development"
  },
  "Infrastructure": {
    "DefaultVMPath": "C:\\VMs",
    "DefaultMemory": "2GB",
    "DefaultCPU": 2
  },
  "Logging": {
    "Level": "Information",
    "Path": "./logs",
    "MaxFileSize": "10MB"
  }
}
```

## Environment Management

The configuration domain supports multiple environments:
- Development
- Testing
- Staging
- Production

Switch environments using:
```powershell
Set-Configuration -Key "Core.Environment" -Value "Production"
```

## Schema Validation

Configuration values are validated against schemas to ensure type safety and required fields.