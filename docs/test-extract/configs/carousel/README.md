# Configuration Carousel

The Configuration Carousel is a sophisticated configuration management system that enables seamless switching between different configuration sets and environments in AitherZero. It provides multi-environment support with security policies and configuration versioning.

## Directory Structure

```
carousel/
└── carousel-registry.json    # Central registry of configurations and environments
```

## Overview

The Configuration Carousel system provides:

1. **Multi-Environment Support**: Separate configurations for dev, staging, and production
2. **Security Policies**: Environment-specific security controls
3. **Configuration Sets**: Manage multiple configuration profiles
4. **Version Control**: Track configuration changes over time
5. **Easy Switching**: Quick transitions between configurations

## Configuration Files

### carousel-registry.json

The main registry file containing environment definitions and configuration mappings:

```json
{
  "version": "1.0",
  "currentConfiguration": "default",
  "currentEnvironment": "dev",
  "lastUpdated": "2025-06-29 05:51:12",
  "environments": { ... },
  "configurations": { ... }
}
```

## Usage

### Basic Operations

```powershell
# Import the Configuration Carousel module
Import-Module ./aither-core/modules/ConfigurationCarousel -Force

# List available configurations
Get-AvailableConfigurations

# Switch to a different configuration
Switch-ConfigurationSet -ConfigurationName "production-config" -Environment "prod"

# Get current configuration
Get-CurrentConfiguration

# Backup current configuration
Backup-CurrentConfiguration -Reason "Before major update"
```

### Advanced Usage

```powershell
# Add a new configuration repository
Add-ConfigurationRepository -Name "team-config" -Source "https://github.com/myorg/aither-config.git"

# Create custom environment
New-ConfigurationEnvironment -Name "qa" -SecurityPolicy @{
    destructiveOperations = "confirm"
    autoConfirm = $false
}

# Export configuration for sharing
Export-ConfigurationSet -Name "my-config" -Path "./export/my-config.zip"

# Import configuration from file
Import-ConfigurationSet -Path "./export/team-config.zip"
```

## Configuration Options

### Environment Definitions

Each environment in the registry has specific properties:

```json
{
  "environments": {
    "dev": {
      "name": "dev",
      "description": "Development environment",
      "securityPolicy": {
        "destructiveOperations": "allow",    # allow, confirm, block
        "autoConfirm": true                   # Auto-confirm operations
      }
    }
  }
}
```

#### Security Policy Options

| Option | Values | Description |
|--------|--------|-------------|
| destructiveOperations | allow, confirm, block | How to handle dangerous operations |
| autoConfirm | true, false | Whether to auto-confirm operations |

### Configuration Definitions

Each configuration set contains:

```json
{
  "configurations": {
    "default": {
      "name": "default",
      "type": "builtin",              # builtin, custom, repository
      "description": "Default AitherZero configuration",
      "path": "../../configs",        # Relative path to config files
      "environments": ["dev", "staging", "prod"]  # Supported environments
    }
  }
}
```

#### Configuration Types

| Type | Description | Use Case |
|------|-------------|----------|
| builtin | Ships with AitherZero | Default configurations |
| custom | User-created | Organization-specific configs |
| repository | Git-based | Shared team configurations |

## Best Practices

### Environment Strategy

1. **Development Environment**
   - Allow all operations
   - Auto-confirm for speed
   - Minimal security restrictions

2. **Staging Environment**
   - Confirm destructive operations
   - No auto-confirm
   - Moderate security

3. **Production Environment**
   - Block destructive operations
   - No auto-confirm
   - Maximum security

### Configuration Management

1. **Naming Conventions**
   ```
   <purpose>-<environment>-config
   Examples:
   - webapp-dev-config
   - infrastructure-prod-config
   - testing-staging-config
   ```

2. **Version Control**
   - Always backup before changes
   - Use descriptive backup reasons
   - Maintain configuration history

3. **Repository Structure**
   ```
   my-aither-config/
   ├── environments/
   │   ├── dev.json
   │   ├── staging.json
   │   └── prod.json
   ├── configurations/
   │   ├── base-config.json
   │   ├── app-config.json
   │   └── infra-config.json
   └── carousel-registry.json
   ```

## Security Considerations

### Access Control

1. **File Permissions**
   ```powershell
   # Restrict registry access
   Set-ItemProperty -Path "carousel-registry.json" -Name IsReadOnly -Value $true
   ```

2. **Environment Isolation**
   - Never share production configs with dev
   - Use separate credential stores per environment
   - Audit configuration changes

3. **Sensitive Data**
   - Store secrets in secure vaults
   - Reference secrets by key, not value
   - Encrypt configuration repositories

### Audit Trail

The carousel system maintains an audit trail:

```powershell
# View configuration history
Get-ConfigurationHistory

# View specific change
Get-ConfigurationChange -ChangeId "2025-06-29-001"

# Export audit log
Export-ConfigurationAudit -StartDate "2025-06-01" -Path "./audit.log"
```

## Advanced Features

### Configuration Inheritance

Create base configurations that others extend:

```json
{
  "configurations": {
    "base": {
      "name": "base",
      "type": "builtin",
      "abstract": true
    },
    "app-dev": {
      "name": "app-dev",
      "type": "custom",
      "extends": "base",
      "overrides": {
        "InstallVSCode": true,
        "InstallDockerDesktop": true
      }
    }
  }
}
```

### Dynamic Configuration

Support for dynamic values:

```json
{
  "configurations": {
    "dynamic": {
      "name": "dynamic",
      "variables": {
        "hostname": "${env:COMPUTERNAME}",
        "timestamp": "${date:yyyy-MM-dd}",
        "user": "${env:USERNAME}"
      }
    }
  }
}
```

### Configuration Validation

Built-in validation rules:

```json
{
  "configurations": {
    "validated": {
      "name": "validated",
      "validation": {
        "required": ["InstallGit", "InstallPwsh"],
        "oneOf": ["InstallDocker", "InstallPodman"],
        "custom": "Test-MyConfiguration"
      }
    }
  }
}
```

## Integration with Other Modules

### SetupWizard Integration

The SetupWizard automatically registers configurations:

```powershell
# During setup
Start-IntelligentSetup -RegisterWithCarousel
```

### ConfigurationRepository Integration

Sync with Git repositories:

```powershell
# Clone configuration repository
Clone-ConfigurationRepository -RepositoryUrl "https://github.com/org/configs.git"

# Auto-register with carousel
Register-RepositoryConfigurations -Path "./configs"
```

### LicenseManager Integration

Feature availability based on configuration:

```powershell
# Check if configuration supports features
Test-ConfigurationFeatures -ConfigName "enterprise-config"
```

## Troubleshooting

### Common Issues

1. **Configuration Not Found**
   ```powershell
   # Verify configuration exists
   Test-ConfigurationExists -Name "my-config"
   
   # Re-scan configurations
   Update-ConfigurationRegistry
   ```

2. **Environment Mismatch**
   ```powershell
   # Check compatible environments
   Get-ConfigurationEnvironments -ConfigName "prod-config"
   ```

3. **Permission Denied**
   ```powershell
   # Check current permissions
   Get-ConfigurationPermissions
   
   # Request elevation if needed
   Request-ConfigurationAccess -Environment "prod"
   ```

### Diagnostic Commands

```powershell
# Full system diagnostic
Test-CarouselHealth

# Configuration validation
Test-ConfigurationIntegrity -Name "my-config"

# Environment validation
Test-EnvironmentPolicy -Environment "prod"

# Export diagnostic report
Export-CarouselDiagnostics -Path "./diagnostics.json"
```

## Examples

### Example: Multi-Environment Setup

```powershell
# 1. Create environments
$environments = @("dev", "qa", "staging", "prod")
foreach ($env in $environments) {
    New-ConfigurationEnvironment -Name $env -SecurityPolicy @{
        destructiveOperations = if ($env -eq "prod") { "block" } else { "confirm" }
        autoConfirm = $env -eq "dev"
    }
}

# 2. Create configuration sets
New-ConfigurationSet -Name "webapp" -Environments $environments
New-ConfigurationSet -Name "infrastructure" -Environments @("staging", "prod")

# 3. Switch between them
Switch-ConfigurationSet -ConfigurationName "webapp" -Environment "dev"
# Do development work...

Switch-ConfigurationSet -ConfigurationName "webapp" -Environment "qa"
# Run tests...

Switch-ConfigurationSet -ConfigurationName "infrastructure" -Environment "prod"
# Deploy infrastructure...
```

### Example: Team Configuration Repository

```powershell
# 1. Create team repository
New-ConfigurationRepository -RepositoryName "team-aither-config" -LocalPath "./team-config"

# 2. Add team-specific configurations
Add-ConfigurationToRepository -Repository "team-aither-config" -ConfigFile @{
    TeamName = "DevOps"
    InstallTools = @("kubectl", "helm", "terraform")
    CloudProviders = @("AWS", "Azure")
}

# 3. Share with team
Publish-ConfigurationRepository -Repository "team-aither-config" -Remote "https://github.com/myorg/team-config.git"

# 4. Team members clone and use
Clone-ConfigurationRepository -RepositoryUrl "https://github.com/myorg/team-config.git"
Switch-ConfigurationSet -ConfigurationName "team-devops" -Environment "dev"
```

## See Also

- [Main Configuration Documentation](../README.md)
- [ConfigurationCarousel Module](../../aither-core/modules/ConfigurationCarousel/README.md)
- [ConfigurationRepository Module](../../aither-core/modules/ConfigurationRepository/README.md)