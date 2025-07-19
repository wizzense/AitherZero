# AitherZero Function Index

> 📚 **Complete Function Reference** - 196+ functions organized by domain for easy navigation

This index provides a comprehensive overview of all functions available in AitherZero's domain-based architecture.

## Quick Navigation

- [Infrastructure Domain (57 functions)](#infrastructure-domain---57-functions)
- [Security Domain (41 functions)](#security-domain---41-functions)
- [Configuration Domain (36 functions)](#configuration-domain---36-functions)
- [Utilities Domain (24 functions)](#utilities-domain---24-functions)
- [Experience Domain (22 functions)](#experience-domain---22-functions)
- [Automation Domain (16 functions)](#automation-domain---16-functions)

## Function Summary by Domain

| Domain | Functions | Primary Purpose |
|--------|-----------|-----------------|
| **Infrastructure** | 57 | Lab automation, infrastructure deployment, ISO management, system monitoring |
| **Security** | 41 | Credential management, security automation, compliance hardening |
| **Configuration** | 36 | Multi-environment configuration management and switching |
| **Utilities** | 24 | Semantic versioning, license management, maintenance utilities |
| **Experience** | 22 | Setup wizard, startup experience, user onboarding |
| **Automation** | 16 | Script management and workflow orchestration |
| **TOTAL** | **196** | **Complete infrastructure automation framework** |

---

## Infrastructure Domain - 57 Functions

**Location**: `aither-core/domains/infrastructure/`  
**Purpose**: Lab automation, infrastructure deployment, ISO management, and system monitoring

### LabRunner (17 functions)
- `Start-LabAutomation` - Initiate lab automation workflows
- `Invoke-LabStep` - Execute individual lab deployment steps
- `Get-LabStatus` - Monitor lab deployment status
- `Start-EnhancedLabDeployment` - Advanced lab deployment with monitoring
- `Test-LabConfiguration` - Validate lab configuration before deployment
- `New-LabEnvironment` - Create new lab environments
- `Stop-LabAutomation` - Gracefully stop lab automation processes
- `Get-LabConfiguration` - Retrieve lab configuration settings
- `Set-LabConfiguration` - Update lab configuration settings
- `Remove-LabEnvironment` - Clean up lab environments
- `Export-LabConfiguration` - Export lab configuration for backup
- `Import-LabConfiguration` - Import lab configuration from backup
- `Get-LabMetrics` - Retrieve lab performance metrics
- `Restart-LabServices` - Restart lab services
- `Update-LabSoftware` - Update software in lab environments
- `Backup-LabData` - Backup lab data and configurations
- `Restore-LabData` - Restore lab data from backup

### OpenTofuProvider (11 functions)
- `Start-InfrastructureDeployment` - Deploy infrastructure using OpenTofu
- `Initialize-OpenTofuProvider` - Initialize OpenTofu provider configuration
- `New-LabInfrastructure` - Create lab infrastructure resources
- `Test-OpenTofuConfiguration` - Validate OpenTofu configurations
- `Get-InfrastructureStatus` - Monitor infrastructure deployment status
- `Remove-InfrastructureDeployment` - Clean up infrastructure resources
- `Export-InfrastructureState` - Export and backup infrastructure state
- `Import-InfrastructureState` - Import infrastructure state
- `Plan-InfrastructureChanges` - Plan infrastructure changes
- `Apply-InfrastructureChanges` - Apply planned infrastructure changes
- `Rollback-InfrastructureDeployment` - Rollback infrastructure deployment

### ISOManager (10 functions)
- `Get-ISODownload` - Download ISO files from various sources
- `New-CustomISO` - Create custom ISO files with injected configurations
- `New-ISORepository` - Set up ISO repositories for management
- `Get-ISOInventory` - List and manage ISO inventory
- `Mount-ISO` - Mount ISO files for operations
- `Dismount-ISO` - Unmount ISO files
- `Test-ISOIntegrity` - Verify ISO file integrity and checksums
- `Copy-ISOToRepository` - Copy ISO files to repository
- `Remove-ISOFromRepository` - Remove ISO files from repository
- `Update-ISOMetadata` - Update ISO metadata and information

### SystemMonitoring (19 functions)
- `Get-SystemPerformance` - Retrieve detailed system performance metrics
- `Start-SystemMonitoring` - Begin continuous system monitoring
- `Get-SystemDashboard` - Generate system health dashboard
- `Get-SystemAlerts` - Retrieve system alerts and warnings
- `Set-PerformanceThreshold` - Configure performance alert thresholds
- `Export-SystemMetrics` - Export system metrics to various formats
- `Get-ProcessMonitoring` - Monitor specific processes and services
- `Stop-SystemMonitoring` - Stop system monitoring
- `Get-SystemHealth` - Get overall system health status
- `Set-MonitoringConfiguration` - Configure monitoring settings
- `Get-MonitoringHistory` - Retrieve historical monitoring data
- `Clear-MonitoringData` - Clear monitoring data
- `Send-SystemAlert` - Send system alerts
- `Get-ResourceUtilization` - Get resource utilization metrics
- `Set-AlertRules` - Configure alert rules
- `Get-SystemLogs` - Retrieve system logs
- `Analyze-SystemPerformance` - Analyze system performance trends
- `Generate-PerformanceReport` - Generate performance reports
- `Monitor-DiskSpace` - Monitor disk space usage

---

## Security Domain - 41 Functions

**Location**: `aither-core/domains/security/`  
**Purpose**: Enterprise credential management, security automation, and compliance hardening

### SecureCredentials (10 functions)
- `Get-SecureCredential` - Retrieve encrypted credentials securely
- `Set-SecureCredential` - Store credentials with enterprise encryption
- `New-SecureCredential` - Create new secure credential entries
- `Test-SecureCredentialCompliance` - Validate credential compliance
- `Remove-SecureCredential` - Securely remove credentials
- `Export-SecureCredentialAudit` - Generate credential audit reports
- `Import-SecureCredentialFromVault` - Import from external credential vaults
- `Backup-SecureCredentialStore` - Backup credential store
- `Restore-SecureCredentialStore` - Restore credential store from backup
- `Rotate-SecureCredential` - Rotate credentials for security

### SecurityAutomation (31 functions)
- `Get-ADSecurityAssessment` - Comprehensive Active Directory security analysis
- `Enable-CredentialGuard` - Enable Windows Credential Guard protection
- `Install-EnterpriseCA` - Deploy enterprise certificate authority
- `Enable-AdvancedAuditPolicy` - Configure advanced security auditing
- `Set-SystemHardening` - Apply system hardening configurations
- `New-CertificateTemplate` - Create certificate templates for PKI
- `Test-SecurityCompliance` - Validate security compliance status
- `Get-SecurityRecommendations` - Generate security improvement recommendations
- `Enable-BitLockerEncryption` - Enable and configure BitLocker
- `Set-WindowsFirewallRules` - Configure Windows Firewall rules
- `Install-SecurityUpdates` - Install security updates
- `Configure-UAC` - Configure User Account Control
- `Set-PasswordPolicy` - Configure password policies
- `Enable-WindowsDefender` - Configure Windows Defender
- `Set-AuditPolicy` - Configure audit policies
- `Get-SecurityEventLog` - Retrieve security event logs
- `Test-NetworkSecurity` - Test network security configuration
- `Configure-IPSec` - Configure IPSec settings
- `Set-RegistrySecuritySettings` - Configure registry security
- `Enable-AppLocker` - Configure AppLocker policies
- `Set-GroupPolicySettings` - Configure group policy security settings
- `Test-VulnerabilityAssessment` - Run vulnerability assessment
- `Generate-SecurityReport` - Generate security compliance reports
- `Configure-WSUS` - Configure Windows Server Update Services
- `Set-ServiceHardening` - Harden Windows services
- `Configure-SMB` - Configure SMB security settings
- `Set-NetworkAccessControl` - Configure network access controls
- `Enable-WindowsEventLogging` - Configure Windows event logging
- `Test-PortSecurity` - Test port security configuration
- `Configure-TLS` - Configure TLS/SSL settings
- `Set-SecurityBaseline` - Apply security baselines

---

## Configuration Domain - 36 Functions

**Location**: `aither-core/domains/configuration/`  
**Purpose**: Multi-environment configuration management and switching

### ConfigurationCore (11 functions)
- `Get-ConfigurationStore` - Retrieve configuration store
- `Set-ConfigurationValue` - Set configuration values
- `Get-ConfigurationValue` - Get configuration values
- `Test-ConfigurationStore` - Validate configuration store
- `Initialize-ConfigurationStore` - Initialize new configuration store
- `Backup-ConfigurationStore` - Backup configuration store
- `Restore-ConfigurationStore` - Restore configuration from backup
- `Merge-ConfigurationStore` - Merge configuration stores
- `Export-ConfigurationStore` - Export configuration store
- `Import-ConfigurationStore` - Import configuration store
- `Clear-ConfigurationStore` - Clear configuration store

### ConfigurationCarousel (12 functions)
- `Switch-ConfigurationSet` - Switch between configuration environments
- `Get-AvailableConfigurations` - List available configuration sets
- `Add-ConfigurationRepository` - Add Git-based configuration repositories
- `Remove-ConfigurationRepository` - Remove configuration repositories
- `Update-ConfigurationRepository` - Update configuration repositories
- `Get-ConfigurationEnvironments` - Get available environments
- `Set-DefaultConfiguration` - Set default configuration
- `Test-ConfigurationSwitch` - Test configuration switching
- `Get-CurrentConfiguration` - Get current active configuration
- `Backup-CurrentConfiguration` - Backup current configuration
- `Restore-PreviousConfiguration` - Restore previous configuration
- `Sync-ConfigurationEnvironments` - Synchronize configuration environments

### ConfigurationRepository (5 functions)
- `New-ConfigurationRepository` - Create new configuration repository
- `Clone-ConfigurationRepository` - Clone existing configuration repository
- `Sync-ConfigurationRepository` - Sync configuration repository
- `Push-ConfigurationChanges` - Push configuration changes to repository
- `Pull-ConfigurationChanges` - Pull configuration changes from repository

### ConfigurationManager (8 functions)
- `Validate-Configuration` - Validate configuration structure
- `Test-ConfigurationIntegrity` - Test configuration integrity
- `Get-ConfigurationDifferences` - Compare configurations
- `Repair-Configuration` - Repair configuration issues
- `Optimize-Configuration` - Optimize configuration settings
- `Generate-ConfigurationSchema` - Generate configuration schema
- `Convert-ConfigurationFormat` - Convert between configuration formats
- `Analyze-ConfigurationUsage` - Analyze configuration usage patterns

---

## Utilities Domain - 24 Functions

**Location**: `aither-core/domains/utilities/`  
**Purpose**: Semantic versioning, license management, maintenance operations, and common utilities

### SemanticVersioning (8 functions)
- `Get-NextSemanticVersion` - Calculate next semantic version based on change type
- `Compare-SemanticVersion` - Compare semantic versions for precedence
- `Test-SemanticVersionFormat` - Validate semantic version format
- `New-SemanticVersion` - Create semantic version objects
- `Parse-SemanticVersion` - Parse semantic version strings
- `Set-SemanticVersionMetadata` - Set version metadata
- `Get-SemanticVersionHistory` - Get version history
- `Export-SemanticVersionData` - Export version data

### LicenseManager (3 functions)
- `Test-FeatureAccess` - Test access to licensed features
- `Get-LicenseStatus` - Retrieve current license status
- `Set-License` - Configure license for organization

### RepoSync (2 functions)
- `Sync-ToAitherLab` - Synchronize to AitherLab repository
- `Sync-RepositoryChanges` - Synchronize repository changes

### UnifiedMaintenance (3 functions)
- `Invoke-UnifiedMaintenance` - Perform comprehensive maintenance
- `Get-MaintenanceStatus` - Check system maintenance status
- `Start-MaintenanceMode` - Enable maintenance mode

### UtilityServices (7 functions)
- `Get-CrossPlatformPath` - Cross-platform path operations
- `Test-PlatformFeature` - Platform feature detection
- `Invoke-PlatformFeatureWithFallback` - Platform-aware execution
- `ConvertTo-SafeFileName` - Generate safe filenames
- `Get-SystemInformation` - Retrieve system information
- `Test-NetworkConnectivity` - Test network connectivity
- `ConvertTo-Base64` - Convert data to Base64 encoding

### PSScriptAnalyzerIntegration (1 function)
- `Invoke-PSScriptAnalyzerScan` - Run PowerShell code analysis

---

## Experience Domain - 22 Functions

**Location**: `aither-core/domains/experience/`  
**Purpose**: Setup wizard, startup experience, and user onboarding

### SetupWizard (11 functions)
- `Start-IntelligentSetup` - Intelligent setup with installation profiles
- `Get-InstallationProfile` - Get installation profile configuration
- `Test-SetupPrerequisites` - Test setup prerequisites
- `Install-Prerequisites` - Install setup prerequisites
- `Configure-DevelopmentEnvironment` - Configure development environment
- `Set-InstallationProfile` - Set installation profile
- `Get-SetupProgress` - Get setup progress status
- `Complete-Setup` - Complete setup process
- `Rollback-Setup` - Rollback setup changes
- `Export-SetupConfiguration` - Export setup configuration
- `Import-SetupConfiguration` - Import setup configuration

### StartupExperience (11 functions)
- `Start-InteractiveMode` - Interactive startup with menu system
- `Generate-QuickStartGuide` - Generate platform-specific quick start guides
- `Show-WelcomeMessage` - Display welcome message
- `Get-UserPreferences` - Get user preferences
- `Set-UserPreferences` - Set user preferences
- `Initialize-UserEnvironment` - Initialize user environment
- `Show-FeatureOverview` - Show feature overview
- `Get-RecentActivity` - Get recent activity
- `Set-StartupConfiguration` - Set startup configuration
- `Test-StartupConfiguration` - Test startup configuration
- `Reset-StartupConfiguration` - Reset startup configuration

---

## Automation Domain - 16 Functions

**Location**: `aither-core/domains/automation/`  
**Purpose**: Script management and workflow orchestration

### ScriptManager (14 functions)
- `Register-OneOffScript` - Register scripts for execution
- `Invoke-OneOffScript` - Execute registered scripts
- `Get-ScriptTemplate` - Retrieve script templates
- `Start-ScriptExecution` - Advanced script execution with monitoring
- `Stop-ScriptExecution` - Stop script execution
- `Get-ScriptExecutionStatus` - Get script execution status
- `Get-ScriptExecutionHistory` - Get script execution history
- `Remove-OneOffScript` - Remove registered scripts
- `Update-ScriptTemplate` - Update script templates
- `Get-ScriptExecutionLog` - Get script execution logs
- `Test-ScriptSyntax` - Test script syntax
- `Get-ScriptDependencies` - Get script dependencies
- `Set-ScriptExecutionPolicy` - Set script execution policy
- `Export-ScriptExecutionReport` - Export script execution report

### OrchestrationEngine (2 functions)
- `Start-WorkflowExecution` - Start workflow execution
- `Get-WorkflowStatus` - Get workflow execution status

---

## Usage Examples

### Basic Function Discovery
```powershell
# Load all domains through AitherCore
Import-Module ./aither-core/AitherCore.psm1 -Force

# Or load specific domain
. "./aither-core/domains/infrastructure/LabRunner.ps1"

# Get available functions (example)
Get-Command -Module AitherCore | Where-Object {$_.Name -like "*Lab*"}
```

### Domain-Specific Usage
```powershell
# Infrastructure operations
Start-LabAutomation -ConfigurationName "WebServerLab"
Start-InfrastructureDeployment -ConfigurationPath "./infrastructure/main.tf"

# Security operations
Get-ADSecurityAssessment -DomainName "mydomain.com"
Enable-CredentialGuard -Force

# Configuration management
Switch-ConfigurationSet -ConfigurationName "production" -Environment "prod"
Get-ConfigurationStore

# Utilities
$nextVersion = Get-NextSemanticVersion -CurrentVersion "1.2.3" -ChangeType "minor"
Test-FeatureAccess -FeatureName "AdvancedReporting"
```

## Function Categories by Use Case

### Infrastructure Management
- **Lab Automation**: 17 functions in Infrastructure/LabRunner
- **Infrastructure Deployment**: 11 functions in Infrastructure/OpenTofuProvider
- **System Monitoring**: 19 functions in Infrastructure/SystemMonitoring
- **ISO Management**: 10 functions in Infrastructure/ISOManager

### Security & Compliance
- **Credential Management**: 10 functions in Security/SecureCredentials
- **Security Automation**: 31 functions in Security/SecurityAutomation

### Configuration & Environment Management
- **Core Configuration**: 11 functions in Configuration/ConfigurationCore
- **Environment Switching**: 12 functions in Configuration/ConfigurationCarousel
- **Repository Management**: 5 functions in Configuration/ConfigurationRepository
- **Configuration Validation**: 8 functions in Configuration/ConfigurationManager

### User Experience & Setup
- **Setup & Installation**: 11 functions in Experience/SetupWizard
- **User Interface**: 11 functions in Experience/StartupExperience

### Automation & Scripting
- **Script Management**: 14 functions in Automation/ScriptManager
- **Workflow Orchestration**: 2 functions in Automation/OrchestrationEngine

### Utilities & Maintenance
- **Version Management**: 8 functions in Utilities/SemanticVersioning
- **License Management**: 3 functions in Utilities/LicenseManager
- **Repository Sync**: 2 functions in Utilities/RepoSync
- **Maintenance**: 3 functions in Utilities/UnifiedMaintenance
- **Common Utilities**: 7 functions in Utilities/UtilityServices
- **Code Analysis**: 1 function in Utilities/PSScriptAnalyzerIntegration

---

## Navigation Tips

1. **By Domain**: Use the domain structure to find related functionality
2. **By Use Case**: Use the function categories to find functions for specific tasks
3. **By Name**: Use Ctrl+F to search for specific function names
4. **By Purpose**: Check function descriptions to understand capabilities

## Documentation Links

- **[Domain Architecture](aither-core/domains/README.md)** - Complete domain overview
- **[Infrastructure Domain](aither-core/domains/infrastructure/README.md)** - Infrastructure functions
- **[Security Domain](aither-core/domains/security/README.md)** - Security functions
- **[Configuration Domain](aither-core/domains/configuration/README.md)** - Configuration functions
- **[Utilities Domain](aither-core/domains/utilities/README.md)** - Utility functions
- **[Experience Domain](aither-core/domains/experience/README.md)** - User experience functions
- **[Automation Domain](aither-core/domains/automation/README.md)** - Automation functions

---

*This function index is maintained automatically and reflects the current domain-based architecture of AitherZero.*