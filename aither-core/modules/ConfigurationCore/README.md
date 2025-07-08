# ConfigurationCore Module

The ConfigurationCore module provides unified configuration management for the entire AitherZero platform, serving as the central 
configuration system for all modules with advanced features for enterprise environments.

## 🚀 Features

- **Centralized Configuration**: Single source of truth for all module configurations
- **Environment Support**: Multiple environments (dev, staging, prod) with configuration overlays
- **Schema Validation**: Comprehensive schema-based validation with type checking
- **Hot Reload**: Automatic configuration reload when changes are detected
- **Variable Expansion**: Support for environment variables and cross-module references
- **Configuration Backup/Restore**: Built-in configuration versioning and recovery
- **Import/Export**: Support for JSON, YAML, and XML configuration formats
- **Security Features**: Sensitive data detection and hash validation
- **Cross-Platform**: Full support for Windows, Linux, and macOS
- **Modern PowerShell**: Built with PowerShell 7+ patterns and best practices

## 📊 Module Status

**Version**: 1.0.0  
**Functions Exported**: 20  
**Test Coverage**: 10/10 comprehensive tests passing  
**Platforms**: Windows, Linux, macOS  
**PowerShell Version**: 7.0+

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

## 🔧 All Available Functions

### Core Configuration Management
- `Initialize-ConfigurationCore` - Initialize the configuration system
- `Get-ModuleConfiguration` - Retrieve module configuration with environment overlays
- `Set-ModuleConfiguration` - Update module configuration
- `Test-ModuleConfiguration` - Validate module configuration
- `Register-ModuleConfiguration` - Register module schema and defaults

### Configuration Store Operations
- `Get-ConfigurationStore` - Get the complete configuration store
- `Set-ConfigurationStore` - Replace the entire configuration store
- `Export-ConfigurationStore` - Export configuration to JSON/YAML/XML
- `Import-ConfigurationStore` - Import configuration from file

### Environment Management
- `Get-ConfigurationEnvironment` - Get environment information
- `Set-ConfigurationEnvironment` - Switch active environment
- `New-ConfigurationEnvironment` - Create new environment
- `Remove-ConfigurationEnvironment` - Remove environment

### Schema and Validation
- `Get-ConfigurationSchema` - Get module schemas
- `Compare-Configuration` - Compare two configurations

### Hot Reload
- `Enable-ConfigurationHotReload` - Enable automatic reload
- `Disable-ConfigurationHotReload` - Disable automatic reload
- `Get-ConfigurationWatcher` - Get file watcher information

### Backup and Recovery
- `Backup-Configuration` - Create configuration backup
- `Restore-Configuration` - Restore from backup

## 🏗️ Integration with Other Modules

### Basic Integration Pattern

```powershell
# 1. Module initialization
function Initialize-MyModule {
    # Define schema
    $schema = @{
        Properties = @{
            ApiEndpoint = @{
                Type = 'string'
                Default = 'https://api.example.com'
                Required = $true
                Description = 'API endpoint URL'
            }
            MaxRetries = @{
                Type = 'int'
                Default = 3
                Min = 1
                Max = 10
                Description = 'Maximum retry attempts'
            }
            EnableLogging = @{
                Type = 'bool'
                Default = $true
                Description = 'Enable detailed logging'
            }
        }
    }
    
    # Register with ConfigurationCore
    Register-ModuleConfiguration -ModuleName 'MyModule' -Schema $schema
    
    # Get initial configuration
    $script:ModuleConfig = Get-ModuleConfiguration -ModuleName 'MyModule'
}

# 2. Use configuration throughout module
function Invoke-MyModuleOperation {
    $config = Get-ModuleConfiguration -ModuleName 'MyModule'
    
    if ($config.EnableLogging) {
        Write-CustomLog -Level 'INFO' -Message "Connecting to $($config.ApiEndpoint)"
    }
    
    # Use configuration values
    $retryCount = 0
    do {
        try {
            # API call using $config.ApiEndpoint
            break
        } catch {
            $retryCount++
            if ($retryCount -ge $config.MaxRetries) {
                throw
            }
            Start-Sleep -Seconds 1
        }
    } while ($retryCount -lt $config.MaxRetries)
}

# 3. Hot reload support (optional)
function Update-ModuleConfiguration {
    param([hashtable]$Configuration)
    
    $script:ModuleConfig = $Configuration
    Write-CustomLog -Level 'INFO' -Message "MyModule configuration reloaded"
    
    # Reinitialize components if needed
    if ($Configuration.ApiEndpoint -ne $script:OldEndpoint) {
        Initialize-ApiConnection -Endpoint $Configuration.ApiEndpoint
    }
}
```

### Advanced Integration with Environment-Specific Settings

```powershell
# Configure for different environments
function Set-MyModuleEnvironment {
    param([string]$Environment)
    
    switch ($Environment) {
        'development' {
            Set-ModuleConfiguration -ModuleName 'MyModule' -Environment 'development' -Configuration @{
                ApiEndpoint = 'https://dev-api.example.com'
                EnableLogging = $true
                MaxRetries = 5
            }
        }
        'production' {
            Set-ModuleConfiguration -ModuleName 'MyModule' -Environment 'production' -Configuration @{
                ApiEndpoint = 'https://api.example.com'
                EnableLogging = $false
                MaxRetries = 3
            }
        }
    }
}

# Get environment-specific configuration
function Get-MyModuleConfig {
    param([string]$Environment = $null)
    
    if ($Environment) {
        return Get-ModuleConfiguration -ModuleName 'MyModule' -Environment $Environment
    } else {
        return Get-ModuleConfiguration -ModuleName 'MyModule'
    }
}
```

## 🔐 Security Best Practices

### Sensitive Data Handling

```powershell
# Configure module with sensitive data detection
$schema = @{
    Properties = @{
        ApiKey = @{
            Type = 'string'
            Required = $true
            Sensitive = $true  # Mark as sensitive
            Description = 'API key for authentication'
        }
        DatabaseConnection = @{
            Type = 'string'
            Sensitive = $true
            Description = 'Database connection string'
        }
    }
}

Register-ModuleConfiguration -ModuleName 'SecureModule' -Schema $schema

# ConfigurationCore will warn about sensitive data in plain text
```

### Configuration Validation

```powershell
# Comprehensive validation example
$schema = @{
    Properties = @{
        ServerUrl = @{
            Type = 'string'
            Required = $true
            Pattern = '^https?://.*'  # Must be HTTP/HTTPS URL
            Description = 'Server URL'
        }
        Port = @{
            Type = 'int'
            Min = 1
            Max = 65535
            Default = 443
            Description = 'Server port'
        }
        Environment = @{
            Type = 'string'
            ValidValues = @('dev', 'staging', 'prod')
            Default = 'dev'
            Description = 'Target environment'
        }
    }
    AdditionalProperties = $false  # Strict schema - no unknown properties
}

Register-ModuleConfiguration -ModuleName 'ValidatedModule' -Schema $schema

# Test configuration before use
if (-not (Test-ModuleConfiguration -ModuleName 'ValidatedModule')) {
    $result = Test-ModuleConfiguration -ModuleName 'ValidatedModule' -Detailed
    Write-Error "Configuration invalid: $($result.Errors -join ', ')"
}
```

## 📝 Migration Guide

### From Legacy Configuration Patterns

```powershell
# OLD: Direct JSON file reading
$config = Get-Content 'config.json' | ConvertFrom-Json

# NEW: Centralized configuration
$config = Get-ModuleConfiguration -ModuleName 'MyModule'
```

```powershell
# OLD: Environment variables
$apiKey = $env:API_KEY
$maxRetries = [int]$env:MAX_RETRIES

# NEW: Schema-validated configuration with environment support
$config = Get-ModuleConfiguration -ModuleName 'MyModule'
$apiKey = $config.ApiKey  # Validated and typed
$maxRetries = $config.MaxRetries  # Validated range
```

## 🚀 Performance and Best Practices

### Caching Configuration

```powershell
# Cache configuration in module scope for performance
$script:CachedConfig = $null
$script:ConfigLastLoaded = $null

function Get-CachedModuleConfiguration {
    param([string]$ModuleName)
    
    if (-not $script:CachedConfig -or 
        (Get-Date) - $script:ConfigLastLoaded > [TimeSpan]::FromMinutes(5)) {
        
        $script:CachedConfig = Get-ModuleConfiguration -ModuleName $ModuleName
        $script:ConfigLastLoaded = Get-Date
    }
    
    return $script:CachedConfig
}
```

### Bulk Configuration Operations

```powershell
# Configure multiple modules efficiently
$configurations = @{
    'ModuleA' = @{ Setting1 = 'ValueA'; Setting2 = 42 }
    'ModuleB' = @{ Setting1 = 'ValueB'; Setting2 = 100 }
    'ModuleC' = @{ Setting1 = 'ValueC'; Setting2 = 200 }
}

foreach ($moduleName in $configurations.Keys) {
    Set-ModuleConfiguration -ModuleName $moduleName -Configuration $configurations[$moduleName]
}
```

## 🐛 Troubleshooting

### Common Issues

1. **Module not found errors**: Ensure ConfigurationCore is imported before other modules
2. **Schema validation failures**: Check schema property types and constraints
3. **Environment not found**: Verify environment exists with `Get-ConfigurationEnvironment -All`
4. **Hot reload not working**: Check if module implements `Update-ModuleConfiguration`

### Debug Configuration Issues

```powershell
# Enable verbose logging
Import-Module ConfigurationCore -Force -Verbose

# Check configuration store state
$store = Get-ConfigurationStore -IncludeMetadata
$store | ConvertTo-Json -Depth 5

# Validate specific module
$result = Test-ModuleConfiguration -ModuleName 'ProblemModule' -Detailed
$result.Errors
$result.Warnings

# Compare configurations
$comparison = Compare-Configuration -ReferenceConfiguration $oldConfig -DifferenceConfiguration $newConfig
$comparison.Modified
```

## 📚 Additional Resources

- **Module Manifest**: See `ConfigurationCore.psd1` for complete function list
- **Test Suite**: Run `./test-configurationcore.ps1` for comprehensive validation
- **Examples**: Check other AitherZero modules for integration examples
- **Schema Reference**: See `Initialize-DefaultSchemas.ps1` for schema examples

---

**ConfigurationCore**: The foundation of AitherZero's unified configuration management. Built for enterprise reliability with modern PowerShell best practices.