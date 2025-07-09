# AitherCore Configuration Directory

## Directory Structure

The `configs` directory contains configuration files that control the behavior of the AitherCore platform and its
modules. This centralized configuration approach ensures consistency and simplifies deployment management.

```text
configs/
└── default-config.json    # Default platform configuration
```

## Overview

The configuration system in AitherCore provides:

- **Centralized Settings**: Single source of truth for platform configuration
- **Module Configuration**: Settings for all loaded modules
- **Environment Specific**: Support for multiple environments (dev, test, prod)
- **Runtime Flexibility**: Override capabilities for different scenarios
- **Version Control Friendly**: JSON format for easy diffing and merging

### Configuration Philosophy

1. **Convention Over Configuration**: Sensible defaults that work out-of-box
2. **Progressive Disclosure**: Basic settings visible, advanced settings available
3. **Validation First**: All configurations validated before use
4. **Hot Reload Support**: Changes can be applied without restart (where supported)

## Core Components

### default-config.json

The main configuration file that defines:

```json
{
  "platform": {
    "name": "AitherZero",
    "version": "0.6.25",
    "environment": "development",
    "features": {
      "advancedLogging": true,
      "performanceMonitoring": true,
      "experimentalFeatures": false
    }
  },
  "modules": {
    "autoLoad": true,
    "required": ["Logging", "LabRunner", "OpenTofuProvider"],
    "optional": ["DevEnvironment", "AIToolsIntegration"],
    "disabled": [],
    "settings": {
      "Logging": {
        "level": "Information",
        "targets": ["Console", "File"],
        "retentionDays": 30
      },
      "LabRunner": {
        "defaultTimeout": 3600,
        "parallelExecution": true,
        "maxConcurrency": 4
      }
    }
  },
  "paths": {
    "logs": "./logs",
    "temp": "./temp",
    "modules": "./aither-core/modules",
    "scripts": "./aither-core/scripts"
  },
  "security": {
    "requireSecureCredentials": true,
    "encryptionKeyPath": null,
    "auditLogging": true
  }
}
```

## Configuration Schema

### Platform Section
Controls core platform behavior:

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| name | string | Platform identifier | "AitherZero" |
| version | string | Platform version | Current version |
| environment | string | Deployment environment | "development" |
| features | object | Feature flags | See features table |

### Features Subsection
Toggle platform capabilities:

| Feature | Type | Description | Default |
|---------|------|-------------|---------|
| advancedLogging | boolean | Enable detailed logging | true |
| performanceMonitoring | boolean | Track performance metrics | true |
| experimentalFeatures | boolean | Enable experimental features | false |
| debugMode | boolean | Enable debug output | false |
| telemetry | boolean | Send anonymous usage data | false |

### Modules Section
Module loading and configuration:

| Property | Type | Description |
|----------|------|-------------|
| autoLoad | boolean | Automatically load modules |
| required | array | Modules that must load successfully |
| optional | array | Modules to attempt loading |
| disabled | array | Modules to skip |
| settings | object | Per-module configuration |

### Paths Section
File system locations:

| Property | Type | Description |
|----------|------|-------------|
| logs | string | Log file directory |
| temp | string | Temporary file directory |
| modules | string | Module search path |
| scripts | string | Script search path |
| cache | string | Cache directory |

### Security Section
Security and compliance settings:

| Property | Type | Description |
|----------|------|-------------|
| requireSecureCredentials | boolean | Enforce credential encryption |
| encryptionKeyPath | string | Path to encryption key |
| auditLogging | boolean | Enable audit trail |
| allowedHosts | array | Permitted remote hosts |

## Module System

### Module Configuration
Each module can have its own configuration section:

```json
{
  "modules": {
    "settings": {
      "ModuleName": {
        "setting1": "value1",
        "setting2": 123,
        "complexSetting": {
          "nested": true
        }
      }
    }
  }
}
```

### Module Discovery
Modules are discovered based on:
1. Paths specified in configuration
2. Convention-based locations
3. Explicitly registered paths

### Load Order
1. Core required modules (Logging first)
2. Additional required modules
3. Optional modules
4. Feature modules

## Usage

### Loading Configuration
```powershell
# Default configuration
$config = Get-Content ".\configs\default-config.json" | ConvertFrom-Json

# With overrides
$config = Get-PlatformConfiguration -ConfigPath ".\custom-config.json"
```

### Runtime Overrides
```powershell
# Override via parameters
Initialize-AitherPlatform -ConfigFile ".\prod-config.json" `
                         -LogLevel "Debug" `
                         -Features @('Experimental')

# Environment variables
$env:AITHERZERO_CONFIG = ".\override-config.json"
$env:AITHERZERO_LOG_LEVEL = "Verbose"
```

### Module-Specific Configuration
```powershell
# Get module configuration
$logConfig = Get-ModuleConfiguration -ModuleName "Logging"

# Update module configuration
Set-ModuleConfiguration -ModuleName "LabRunner" `
                       -Settings @{
                           defaultTimeout = 7200
                           maxConcurrency = 8
                       }
```

## Development Guidelines

### Configuration Best Practices

1. **Provide Defaults**: Every setting should have a sensible default
2. **Document Settings**: Include descriptions in schema
3. **Validate Early**: Check configuration at startup
4. **Type Safety**: Use appropriate JSON types
5. **Avoid Secrets**: Never store credentials in config files

### Adding New Settings

1. Update schema documentation
2. Add to default-config.json
3. Implement validation logic
4. Update relevant module code
5. Document in release notes

### Configuration Validation

```powershell
function Validate-Configuration {
    param($Config)
    
    # Required fields
    if (-not $Config.platform) {
        throw "Platform section required"
    }
    
    # Type validation
    if ($Config.modules.autoLoad -isnot [bool]) {
        throw "autoLoad must be boolean"
    }
    
    # Range validation
    if ($Config.modules.settings.LabRunner.maxConcurrency -lt 1) {
        throw "maxConcurrency must be >= 1"
    }
}
```

### Environment-Specific Configs

```powershell
# config-dev.json
{
  "environment": "development",
  "features": {
    "debugMode": true,
    "experimentalFeatures": true
  }
}

# config-prod.json
{
  "environment": "production",
  "features": {
    "debugMode": false,
    "experimentalFeatures": false
  },
  "security": {
    "requireSecureCredentials": true,
    "auditLogging": true
  }
}
```

## Advanced Features

### Configuration Inheritance
```json
{
  "_extends": "./base-config.json",
  "platform": {
    "environment": "staging"
  }
}
```

### Dynamic Configuration
```json
{
  "modules": {
    "settings": {
      "LabRunner": {
        "maxConcurrency": "${env:PROCESSOR_COUNT}"
      }
    }
  }
}
```

### Configuration Profiles
```json
{
  "profiles": {
    "minimal": {
      "modules": {
        "required": ["Logging"],
        "optional": []
      }
    },
    "full": {
      "modules": {
        "required": ["Logging", "LabRunner", "OpenTofuProvider"],
        "optional": ["*"]
      }
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **Module Load Failures**
   - Check module name spelling
   - Verify module path exists
   - Review module dependencies

2. **Invalid JSON**
   - Use JSON validator
   - Check for trailing commas
   - Verify quote consistency

3. **Missing Settings**
   - Compare with default-config.json
   - Check schema documentation
   - Review module requirements

### Debugging Configuration

```powershell
# Validate configuration
Test-Configuration -Path ".\configs\custom-config.json" -Verbose

# Show effective configuration
Get-EffectiveConfiguration -IncludeDefaults -IncludeOverrides

# Export current configuration
Export-Configuration -Path ".\current-config.json" -IncludeRuntime
```

## Migration Guide

### Upgrading Configuration

1. **Backup Current Config**
   ```powershell
   Copy-Item ".\configs\default-config.json" ".\configs\backup-$(Get-Date -Format 'yyyyMMdd').json"
   ```

2. **Apply Migration**
   ```powershell
   Update-Configuration -From "0.5.0" -To "0.6.0" -ConfigPath ".\configs\default-config.json"
   ```

3. **Validate Changes**
   ```powershell
   Test-Configuration -Path ".\configs\default-config.json" -Strict
   ```

### Version Compatibility

- Configurations are forward-compatible within major versions
- Breaking changes documented in release notes
- Migration tools provided for major version upgrades
- Schema versioning for validation

## Security Considerations

1. **No Secrets**: Use SecureCredentials module for sensitive data
2. **File Permissions**: Restrict config file access
3. **Validation**: Always validate untrusted configurations
4. **Audit Trail**: Log configuration changes
5. **Encryption**: Consider encrypting sensitive settings