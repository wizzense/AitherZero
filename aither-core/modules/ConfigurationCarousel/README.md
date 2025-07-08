# ConfigurationCarousel Module

## Module Overview

The ConfigurationCarousel module provides dynamic configuration management for AitherZero, allowing seamless switching between multiple
configuration sets and environments. It acts as a configuration orchestrator, enabling teams to maintain different configurations for various
deployment scenarios, environments, and use cases.

### Primary Purpose and Functionality
- Manages multiple configuration sets with easy switching capabilities
- Supports environment-specific configurations (dev, staging, prod)
- Provides configuration backup and restore functionality
- Enables Git-based configuration repositories
- Implements security policies per environment

### Key Features and Capabilities
- **Configuration Registry**: Central registry tracking all available configurations
- **Hot-Swapping**: Switch configurations without restarting AitherZero
- **Environment Awareness**: Different settings for dev, staging, and production
- **Backup Management**: Automatic backup before configuration changes
- **Validation Framework**: Ensures configuration integrity before switching
- **Security Policies**: Environment-specific security controls

### Integration Points with Other Modules
- **ConfigurationRepository Module**: Works with Git-based configuration repos
- **Logging Module**: Provides detailed logging of configuration changes
- **SetupWizard Module**: Integrates with initial setup workflows
- **All Core Modules**: Provides configuration to all AitherZero modules

## Directory Structure

```
ConfigurationCarousel/
├── ConfigurationCarousel.psd1      # Module manifest
├── ConfigurationCarousel.psm1      # Main module implementation
├── README.md                       # This documentation
└── [Runtime Directories]
    ├── configs/
    │   ├── carousel/              # Carousel registry and metadata
    │   ├── backups/               # Configuration backups
    │   └── environments/          # Environment-specific configs
```

### Runtime Directory Structure
When initialized, the module creates:
- `configs/carousel/carousel-registry.json`: Main registry file
- `configs/backups/`: Timestamped configuration backups
- `configs/environments/`: Environment-specific overrides

## Key Functions

### Switch-ConfigurationSet
Switches to a different configuration set with optional environment selection.

**Parameters:**
- `-ConfigurationName` [string] (Mandatory): Name of the target configuration
- `-Environment` [string]: Target environment (defaults to first available)
- `-BackupCurrent` [switch]: Create backup before switching
- `-Force` [switch]: Override validation failures

**Returns:** Hashtable with Success, PreviousConfiguration, NewConfiguration, Environment, ValidationResult, and ApplyResult

**Example:**
```powershell
# Switch to production configuration
Switch-ConfigurationSet -ConfigurationName "production-config" -Environment "prod" -BackupCurrent

# Force switch despite validation warnings
Switch-ConfigurationSet -ConfigurationName "experimental" -Force

# Simple switch with defaults
Switch-ConfigurationSet -ConfigurationName "team-config"
```

### Get-AvailableConfigurations
Lists all registered configuration sets with their details.

**Parameters:**
- `-IncludeDetails` [switch]: Include extended information (paths, accessibility, validation status)

**Returns:** Hashtable with CurrentConfiguration, CurrentEnvironment, TotalConfigurations, and Configurations array

**Example:**
```powershell
# Get basic configuration list
$configs = Get-AvailableConfigurations
$configs.Configurations | Format-Table Name, Description, Type, IsActive

# Get detailed information
$detailed = Get-AvailableConfigurations -IncludeDetails
$detailed.Configurations | Where-Object { $_.IsAccessible -eq $false }
```

### Add-ConfigurationRepository
Registers a new configuration set from various sources.

**Parameters:**
- `-Name` [string] (Mandatory): Configuration set name
- `-Source` [string] (Mandatory): Git URL, local path, or template name
- `-Description` [string]: Configuration description
- `-Environments` [string[]]: Supported environments (default: dev, staging, prod)
- `-SourceType` [string]: Type of source ('git', 'local', 'template', 'auto')
- `-Branch` [string]: Git branch to use (default: main)
- `-SetAsCurrent` [switch]: Immediately switch to this configuration

**Returns:** Hashtable with Success, Name, Path, ValidationResult, and optional SwitchResult

**Example:**
```powershell
# Add from Git repository
Add-ConfigurationRepository -Name "team-config" `
    -Source "https://github.com/myteam/aither-config.git" `
    -Description "Team custom configuration" `
    -SetAsCurrent

# Add from local directory
Add-ConfigurationRepository -Name "local-dev" `
    -Source "C:\MyConfigs\AitherDev" `
    -SourceType "local" `
    -Environments @('dev', 'test')

# Create from template
Add-ConfigurationRepository -Name "enterprise-setup" `
    -Source "enterprise" `
    -SourceType "template" `
    -Description "Enterprise configuration template"
```

### Remove-ConfigurationRepository
Removes a configuration repository from the carousel.

**Parameters:**
- `-Name` [string] (Mandatory): Configuration name to remove
- `-DeleteFiles` [switch]: Also delete configuration files from disk
- `-Force` [switch]: Allow removal of current configuration

**Returns:** Hashtable with Success, RemovedConfiguration, and FilesDeleted

**Example:**
```powershell
# Remove configuration but keep files
Remove-ConfigurationRepository -Name "old-config"

# Remove configuration and delete all files
Remove-ConfigurationRepository -Name "temp-config" -DeleteFiles

# Force remove current configuration
Remove-ConfigurationRepository -Name "current-config" -Force -DeleteFiles
```

### Get-CurrentConfiguration
Retrieves detailed information about the active configuration.

**Parameters:** None

**Returns:** Hashtable with Name, Environment, Description, Type, Path, Source, AvailableEnvironments, IsAccessible, and LastValidated

**Example:**
```powershell
# Get current configuration details
$current = Get-CurrentConfiguration
Write-Host "Active: $($current.Name) in $($current.Environment) environment"

# Check if current configuration is accessible
if (-not $current.IsAccessible) {
    Write-Warning "Current configuration path is not accessible!"
}
```

### Backup-CurrentConfiguration
Creates a backup of the current configuration set.

**Parameters:**
- `-Reason` [string]: Backup reason/description (default: "Manual backup")
- `-BackupName` [string]: Custom backup name (auto-generated if not provided)

**Returns:** Hashtable with Success, BackupName, BackupPath, and OriginalConfiguration

**Example:**
```powershell
# Create backup with reason
Backup-CurrentConfiguration -Reason "Before major update"

# Create backup with custom name
Backup-CurrentConfiguration -BackupName "pre-v2-upgrade" -Reason "Version 2.0 upgrade"

# Automated backup
$backup = Backup-CurrentConfiguration
Write-Host "Backup saved to: $($backup.BackupPath)"
```

### Validate-ConfigurationSet
Validates a configuration set for completeness and correctness.

**Parameters:**
- `-ConfigurationName` [string] (Mandatory): Configuration to validate
- `-Environment` [string]: Specific environment to validate (default: 'dev')

**Returns:** Hashtable with IsValid, Errors array, Warnings array, ConfigurationName, and Environment

**Example:**
```powershell
# Validate configuration
$validation = Validate-ConfigurationSet -ConfigurationName "new-config"
if (-not $validation.IsValid) {
    $validation.Errors | ForEach-Object { Write-Error $_ }
}

# Validate specific environment
$prodValidation = Validate-ConfigurationSet -ConfigurationName "prod-config" -Environment "prod"
```

## Configuration

### Registry Structure
The carousel registry (`carousel-registry.json`) contains:
```json
{
    "version": "1.0",
    "currentConfiguration": "default",
    "currentEnvironment": "dev",
    "configurations": {
        "default": {
            "name": "default",
            "description": "Default AitherZero configuration",
            "path": "../../configs",
            "type": "builtin",
            "environments": ["dev", "staging", "prod"]
        }
    },
    "environments": {
        "dev": {
            "name": "dev",
            "description": "Development environment",
            "securityPolicy": {
                "destructiveOperations": "allow",
                "autoConfirm": true
            }
        }
    },
    "lastUpdated": "2025-01-06 10:30:00"
}
```

### Environment Security Policies
Each environment can define security policies:
- **dev**: Permissive settings for development
- **staging**: Balanced settings with confirmations
- **prod**: Restrictive settings blocking dangerous operations

### Configuration Validation Rules
- Required directories: `configs/`, `environments/`
- Recommended files: `app-config.json`, `module-config.json`
- JSON files must be valid
- Environment must be in supported list

## Usage Examples

### Basic Configuration Management
```powershell
# Import the module
Import-Module ./aither-core/modules/ConfigurationCarousel -Force

# List available configurations
$configs = Get-AvailableConfigurations
$configs.Configurations | Format-Table Name, Type, Environments

# Switch to a different configuration
Switch-ConfigurationSet -ConfigurationName "team-config" -Environment "dev"

# Get current status
$current = Get-CurrentConfiguration
Write-Host "Using: $($current.Name) [$($current.Environment)]"
```

### Multi-Environment Workflow
```powershell
# Development work
Switch-ConfigurationSet -ConfigurationName "feature-branch" -Environment "dev"
# Do development work...

# Test in staging
Switch-ConfigurationSet -ConfigurationName "feature-branch" -Environment "staging" -BackupCurrent
# Run staging tests...

# Deploy to production
Switch-ConfigurationSet -ConfigurationName "production" -Environment "prod" -BackupCurrent
# Production deployment...
```

### Git-Based Configuration Management
```powershell
# Add team configuration from Git
Add-ConfigurationRepository -Name "team-shared" `
    -Source "https://github.com/ourteam/aither-configs.git" `
    -Description "Shared team configurations" `
    -Branch "main" `
    -SetAsCurrent

# Later, sync with remote changes
Import-Module ./aither-core/modules/ConfigurationRepository -Force
Sync-ConfigurationRepository -Path "./configs/carousel/team-shared" -Operation "pull"

# Switch back to this configuration
Switch-ConfigurationSet -ConfigurationName "team-shared"
```

### Backup and Restore Workflow
```powershell
# Create backup before risky operation
$backup = Backup-CurrentConfiguration -Reason "Before experimental changes"

# Make experimental changes...
# If something goes wrong, restore from backup:

# Manual restore (copy backup to active location)
# Note: Future versions will include Restore-Configuration function
Copy-Item -Path $backup.BackupPath -Destination "./configs/restored" -Recurse
Add-ConfigurationRepository -Name "restored-config" `
    -Source "./configs/restored" `
    -SourceType "local" `
    -SetAsCurrent
```

### Enterprise Configuration Template
```powershell
# Create enterprise configuration from template
Add-ConfigurationRepository -Name "enterprise-prod" `
    -Source "enterprise" `
    -SourceType "template" `
    -Description "Production enterprise setup" `
    -Environments @('staging', 'prod')  # No dev for production configs

# Validate before switching
$validation = Validate-ConfigurationSet -ConfigurationName "enterprise-prod" -Environment "prod"
if ($validation.IsValid) {
    Switch-ConfigurationSet -ConfigurationName "enterprise-prod" -Environment "prod"
}
```

## Integration with Other Modules

### With ConfigurationRepository Module
```powershell
# Create new configuration repository
Import-Module ./aither-core/modules/ConfigurationRepository -Force
New-ConfigurationRepository -RepositoryName "custom-config" `
    -LocalPath "./my-configs" `
    -Template "default"

# Add to carousel
Add-ConfigurationRepository -Name "custom-config" `
    -Source "./my-configs" `
    -SourceType "local"
```

### With SetupWizard Module
```powershell
# During setup, configurations are automatically registered
./Start-AitherZero.ps1 -Setup -InstallationProfile developer

# Check what was added
Get-AvailableConfigurations | Select-Object -ExpandProperty Configurations
```

## Dependencies

### Required PowerShell Modules
- **Logging Module**: For consistent logging output (optional, has fallback)

### External Tool Requirements
- **Git**: Required for Git-based configuration repositories
- **File System Access**: Read/write permissions to configuration directories

### Version Requirements
- PowerShell: 7.0 or higher
- Module Version: Included with AitherZero core
- No specific licensing requirements

## Best Practices

### Configuration Naming
- Use descriptive names: `production-web`, `dev-testing`, `client-xyz`
- Include environment in name for clarity
- Avoid special characters except hyphens and underscores

### Environment Usage
- **dev**: Experimental features, auto-confirmations enabled
- **staging**: Mirror production settings, manual confirmations
- **prod**: Restricted operations, audit logging enabled

### Backup Strategy
- Always backup before switching in production
- Use descriptive backup reasons
- Regularly clean old backups to save space

### Security Considerations
- Store sensitive data in environment-specific files
- Use Git repositories with proper access controls
- Review security policies for each environment
- Validate configurations before production use

## Troubleshooting

### Common Issues

1. **Configuration Not Found**
   ```powershell
   # List all configurations
   Get-AvailableConfigurations -IncludeDetails

   # Check if configuration exists
   $configs = Get-AvailableConfigurations
   $configs.Configurations.Name -contains "my-config"
   ```

2. **Validation Failures**
   ```powershell
   # Get detailed validation info
   $validation = Validate-ConfigurationSet -ConfigurationName "my-config"
   $validation.Errors | ForEach-Object { Write-Host "ERROR: $_" }
   $validation.Warnings | ForEach-Object { Write-Host "WARN: $_" }
   ```

3. **Permission Issues**
   ```powershell
   # Check directory permissions
   Test-Path "./configs/carousel" -PathType Container
   Get-Acl "./configs/carousel" | Format-List
   ```

4. **Registry Corruption**
   ```powershell
   # Reinitialize carousel (last resort)
   Remove-Item "./configs/carousel/carousel-registry.json" -Force
   Import-Module ./aither-core/modules/ConfigurationCarousel -Force
   # This will recreate default registry
   ```