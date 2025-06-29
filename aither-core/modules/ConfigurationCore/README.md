# ConfigurationCore Module

The ConfigurationCore module provides unified configuration management for the entire AitherZero platform, enabling centralized configuration storage, validation, and environment-specific overlays.

## Features

- **Centralized Configuration**: Single source of truth for all module configurations
- **Environment Support**: Multiple environments (dev, staging, prod) with configuration overlays
- **Schema Validation**: Define and validate configuration schemas for each module
- **Hot Reload**: Automatic configuration reload when changes are detected
- **Variable Expansion**: Support for environment variables and cross-module references
- **Configuration Backup/Restore**: Built-in configuration versioning and recovery

## Usage

### Initialize ConfigurationCore

```powershell
# Initialize with default settings
Initialize-ConfigurationCore

# Initialize with specific environment
Initialize-ConfigurationCore -Environment "production"

# Initialize from existing configuration file
Initialize-ConfigurationCore -ConfigPath "C:\AitherZero\config.json"
```

### Register Module Configuration

```powershell
# Register a module's configuration schema
Register-ModuleConfiguration -ModuleName "MyModule" -Schema @{
    Properties = @{
        ApiKey = @{
            Type = "string"
            Required = $true
            Description = "API key for external service"
        }
        MaxRetries = @{
            Type = "int"
            Default = 3
            Min = 1
            Max = 10
            Description = "Maximum number of retry attempts"
        }
        EnableLogging = @{
            Type = "bool"
            Default = $true
            Description = "Enable detailed logging"
        }
    }
} -DefaultConfiguration @{
    MaxRetries = 3
    EnableLogging = $true
}
```

### Get Module Configuration

```powershell
# Get configuration for current environment
$config = Get-ModuleConfiguration -ModuleName "LabRunner"

# Get configuration for specific environment
$prodConfig = Get-ModuleConfiguration -ModuleName "LabRunner" -Environment "production"

# Get raw configuration without environment overlay
$rawConfig = Get-ModuleConfiguration -ModuleName "LabRunner" -Raw
```

### Set Module Configuration

```powershell
# Set configuration for current environment
Set-ModuleConfiguration -ModuleName "LabRunner" -Configuration @{
    MaxConcurrentJobs = 10
    EnableParallelExecution = $true
}

# Set configuration for specific environment
Set-ModuleConfiguration -ModuleName "LabRunner" -Environment "production" -Configuration @{
    MaxConcurrentJobs = 20
}

# Merge with existing configuration
Set-ModuleConfiguration -ModuleName "LabRunner" -Configuration @{
    LogLevel = "DEBUG"
} -Merge
```

### Test Configuration Validity

```powershell
# Simple validation
if (Test-ModuleConfiguration -ModuleName "LabRunner") {
    Write-Host "Configuration is valid"
}

# Detailed validation results
$result = Test-ModuleConfiguration -ModuleName "LabRunner" -Detailed
if (-not $result.IsValid) {
    Write-Host "Errors: $($result.Errors -join ', ')"
    Write-Host "Warnings: $($result.Warnings -join ', ')"
}
```

## Configuration Schema Definition

Schemas support the following property attributes:

- **Type**: string, int, bool, array, hashtable
- **Default**: Default value if not specified
- **Required**: Whether the property must be provided
- **ValidValues**: Array of allowed values
- **Min/Max**: Numeric range constraints
- **Pattern**: Regular expression for string validation
- **Description**: Property description

## Variable Expansion

Configuration values support variable expansion:

```powershell
@{
    LogPath = "${ENV:TEMP}/aitherzero/logs"  # Environment variable
    SharedKey = "${CONFIG:Security.ApiKey}"   # Reference to another module's config
    Environment = "${ENVIRONMENT}"            # Current environment name
    Platform = "${PLATFORM}"                  # Current platform (Windows/Linux/macOS)
}
```

## Environment Management

```powershell
# Create new environment
New-ConfigurationEnvironment -Name "staging" -Description "Staging environment"

# Switch active environment
Set-ConfigurationEnvironment -Name "staging"

# Get current environment
$currentEnv = Get-ConfigurationEnvironment

# Remove environment
Remove-ConfigurationEnvironment -Name "staging"
```

## Hot Reload

```powershell
# Enable hot reload
Enable-ConfigurationHotReload

# Disable hot reload
Disable-ConfigurationHotReload
```

When hot reload is enabled, modules can implement `Update-ModuleConfiguration` to react to configuration changes automatically.

## Integration with Other Modules

Modules should integrate with ConfigurationCore by:

1. Registering their schema during module initialization
2. Using Get-ModuleConfiguration to retrieve settings
3. Optionally implementing Update-ModuleConfiguration for hot reload support

Example module integration:

```powershell
# In module initialization
Register-ModuleConfiguration -ModuleName $PSModule.Name -Schema $MyModuleSchema

# Get configuration
$script:ModuleConfig = Get-ModuleConfiguration -ModuleName $PSModule.Name

# Hot reload support (optional)
function Update-ModuleConfiguration {
    param([hashtable]$Configuration)
    $script:ModuleConfig = $Configuration
    # Reinitialize module components as needed
}
```