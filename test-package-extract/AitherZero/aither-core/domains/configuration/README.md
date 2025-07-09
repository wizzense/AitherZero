# Configuration Domain

This domain provides unified configuration management for AitherCore.

## Consolidated Modules

### ConfigurationCore
**Original Module**: `aither-core/modules/ConfigurationCore/`  
**Status**: Consolidated (Primary)  
**Key Functions**:
- `Get-Configuration`
- `Set-Configuration`
- `Initialize-ConfigurationCore`
- `Get-ConfigurationStore`

### ConfigurationCarousel
**Original Module**: `aither-core/modules/ConfigurationCarousel/`  
**Status**: Consolidated (Environment Provider)  
**Key Functions**:
- `Switch-ConfigurationSet`
- `Get-AvailableConfigurations`
- `Add-ConfigurationRepository`

### ConfigurationRepository
**Original Module**: `aither-core/modules/ConfigurationRepository/`  
**Status**: Consolidated (Git Provider)  
**Key Functions**:
- `New-ConfigurationRepository`
- `Clone-ConfigurationRepository`
- `Sync-ConfigurationRepository`

### ConfigurationManager
**Original Module**: `aither-core/modules/ConfigurationManager/`  
**Status**: Consolidated (Validation Provider)  
**Key Functions**:
- `Test-ConfigurationIntegrity`
- `Validate-Configuration`
- `Get-ConfigurationValidationReport`

## Unified Configuration Architecture

The configuration domain implements a provider pattern:

```
ConfigurationCore (Primary Service)
├── EnvironmentProvider (ConfigurationCarousel)
├── GitRepositoryProvider (ConfigurationRepository)
└── ValidationProvider (ConfigurationManager)
```

## Implementation Structure

```
configuration/
├── ConfigurationCore.ps1          # Core configuration management
├── EnvironmentProvider.ps1        # Environment switching (Carousel)
├── GitRepositoryProvider.ps1      # Git repository management
├── ValidationProvider.ps1         # Configuration validation
└── README.md                     # This file
```

## Usage Examples

```powershell
# Get configuration
$config = Get-Configuration -Module "LabRunner"

# Set configuration with validation
Set-Configuration -Module "OpenTofuProvider" -Key "DefaultRegion" -Value "us-east-1"

# Switch environment
Switch-ConfigurationSet -ConfigurationName "production" -Environment "prod"

# Create configuration repository
New-ConfigurationRepository -RepositoryName "team-config" -LocalPath "./config"

# Validate configuration
$validation = Test-ConfigurationIntegrity -Module "All"
```

## Provider System

### Environment Provider (ConfigurationCarousel)
- Manages multiple configuration environments
- Handles environment switching and profiles
- Supports configuration inheritance

### Git Repository Provider (ConfigurationRepository)
- Git-based configuration repositories
- Synchronization with remote repositories
- Version control for configuration changes

### Validation Provider (ConfigurationManager)
- Configuration schema validation
- Integrity checking
- Compliance validation

## Configuration Store

The unified configuration store structure:

```powershell
$script:ConfigurationStore = @{
    Metadata = @{
        Version = "1.0"
        LastModified = Get-Date
        Platform = "Cross-Platform"
    }
    Core = @{}, # Core configuration management
    Environments = @{}, # Environment provider data
    Repositories = @{}, # Git repository provider data
    Validation = @{} # Validation provider data
}
```

## Testing

Configuration domain tests are located in:
- `tests/domains/configuration/`
- Integration tests in `tests/integration/`

## Dependencies

- **Write-CustomLog**: Guaranteed available from AitherCore orchestration
- **Security Services**: Uses SecureCredentials for sensitive configuration
- **File System Access**: Cross-platform file operations