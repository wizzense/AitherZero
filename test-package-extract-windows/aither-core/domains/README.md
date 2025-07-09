# AitherCore Domains

This directory contains the domain-based organization of AitherCore functionality after module consolidation.

## Domain Structure

### Infrastructure Domain (`infrastructure/`)
Handles all infrastructure-related operations:
- **LabRunner**: Lab automation and script execution
- **OpenTofuProvider**: Infrastructure deployment and management
- **ISOManager**: ISO management and customization
- **SystemMonitoring**: System performance monitoring

### Configuration Domain (`configuration/`)
Unified configuration management:
- **Core**: Central configuration store and management
- **Carousel**: Environment switching and management
- **Repository**: Git-based configuration repositories
- **Manager**: Configuration validation and testing

### Security Domain (`security/`)
Security and credential management:
- **SecureCredentials**: Enterprise credential management
- **SecurityAutomation**: Security automation and compliance

### Automation Domain (`automation/`)
Script and automation management:
- **ScriptManager**: Script execution and template management

### Experience Domain (`experience/`)
User experience and setup:
- **SetupWizard**: Intelligent setup and onboarding
- **StartupExperience**: Interactive startup management

### Utilities Domain (`utilities/`)
Shared utility services:
- **UtilityServices**: Common utility functions and services

## Consolidation Benefits

1. **Logical Organization**: Functions grouped by business domain
2. **Reduced Complexity**: Single entry point with domain-specific organization
3. **Maintained Separation**: Clean separation of concerns within domains
4. **Easier Navigation**: Developers can find related functions easily
5. **Consistent Logging**: All domains use AitherCore logging orchestration

## Usage

After consolidation, all domain functionality is available through AitherCore:

```powershell
# Import AitherCore (includes all domains)
Import-Module ./aither-core/AitherCore.psm1

# Functions are available directly
Start-LabAutomation
Get-ISODownload
Set-Configuration
Get-SecureCredential
```

## Testing

Each domain has its own test suite:
- Domain-specific tests: `tests/domains/[domain]/`
- Integration tests: `tests/integration/`
- Consolidated tests: `tests/consolidated/`

## Documentation

Each domain directory contains:
- `README.md`: Domain-specific documentation
- Implementation files organized by functionality
- Test files for domain validation