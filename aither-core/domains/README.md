# AitherCore Domains

This directory contains the domain-based organization of AitherCore functionality after module consolidation. The domain architecture consolidates 30+ legacy modules into 6 logical domains with **196+ functions**.

## Domain Architecture Overview

### Domain Consolidation Statistics
| Domain | Legacy Modules | Functions | Primary Purpose |
|--------|---------------|-----------|------------------|
| **infrastructure** | 4 modules | 57 functions | Infrastructure deployment and monitoring |
| **security** | 2 modules | 41 functions | Security automation and credential management |
| **configuration** | 4 modules | 36 functions | Configuration management and environment switching |
| **utilities** | 6 modules | 24 functions | Utility services and maintenance |
| **experience** | 2 modules | 22 functions | User experience and setup automation |
| **automation** | 2 modules | 16 functions | Script management and workflow orchestration |
| **TOTAL** | **20 modules** | **196 functions** | **Complete infrastructure automation** |

## Domain Structure

### Infrastructure Domain (`infrastructure/`) - 57 Functions
Handles all infrastructure-related operations:
- **LabRunner** (17 functions): Lab automation and script execution
- **OpenTofuProvider** (11 functions): Infrastructure deployment and management
- **ISOManager** (10 functions): ISO management and customization
- **SystemMonitoring** (19 functions): System performance monitoring

**Key Functions:**
- `Start-LabAutomation` - Start lab automation workflows
- `Start-InfrastructureDeployment` - Deploy infrastructure with OpenTofu
- `Get-ISODownload` - Download and manage ISO files
- `Get-SystemDashboard` - System monitoring dashboard

### Security Domain (`security/`) - 41 Functions
Security and credential management:
- **SecureCredentials** (10 functions): Enterprise credential management
- **SecurityAutomation** (31 functions): Security automation and compliance

**Key Functions:**
- `Get-SecureCredential` - Retrieve secure credentials
- `Get-ADSecurityAssessment` - Active Directory security assessment
- `Enable-CredentialGuard` - Enable Windows Credential Guard
- `Set-SystemHardening` - Apply system hardening configurations

### Configuration Domain (`configuration/`) - 36 Functions
Unified configuration management:
- **ConfigurationCore** (11 functions): Central configuration store and management
- **ConfigurationCarousel** (12 functions): Environment switching and management
- **ConfigurationRepository** (5 functions): Git-based configuration repositories
- **ConfigurationManager** (8 functions): Configuration validation and testing

**Key Functions:**
- `Get-ConfigurationStore` - Retrieve configuration store
- `Switch-ConfigurationSet` - Switch between configuration environments
- `Add-ConfigurationRepository` - Add Git-based configuration repositories
- `Validate-Configuration` - Validate configuration structure

### Utilities Domain (`utilities/`) - 24 Functions
Shared utility services:
- **SemanticVersioning** (8 functions): Semantic versioning utilities
- **LicenseManager** (3 functions): License management and feature access
- **RepoSync** (2 functions): Repository synchronization
- **UnifiedMaintenance** (3 functions): Unified maintenance operations
- **UtilityServices** (7 functions): Common utility functions
- **PSScriptAnalyzerIntegration** (1 function): PowerShell code analysis

**Key Functions:**
- `Get-NextSemanticVersion` - Calculate next semantic version
- `Test-FeatureAccess` - Test access to licensed features
- `Sync-ToAitherLab` - Synchronize to AitherLab repository
- `Invoke-UnifiedMaintenance` - Perform maintenance operations

### Experience Domain (`experience/`) - 22 Functions
User experience and setup:
- **SetupWizard** (11 functions): Intelligent setup and onboarding
- **StartupExperience** (11 functions): Interactive startup management

**Key Functions:**
- `Start-IntelligentSetup` - Intelligent setup with installation profiles
- `Get-InstallationProfile` - Get installation profile configuration
- `Start-InteractiveMode` - Interactive startup with menu system
- `Generate-QuickStartGuide` - Generate platform-specific quick start guides

### Automation Domain (`automation/`) - 16 Functions
Script and automation management:
- **ScriptManager** (14 functions): Script execution and template management
- **OrchestrationEngine** (2 functions): Workflow orchestration

**Key Functions:**
- `Register-OneOffScript` - Register scripts for execution
- `Invoke-OneOffScript` - Execute registered scripts
- `Get-ScriptTemplate` - Retrieve script templates
- `Start-ScriptExecution` - Advanced script execution with monitoring

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