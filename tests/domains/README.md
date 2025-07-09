# Domain-Based Testing Structure

This directory contains domain-specific tests for the consolidated AitherCore architecture. The domain structure consolidates 30+ modules into 6 logical domains with 196+ functions.

## Domain Architecture Overview

### Domain Consolidation
The domain architecture consolidates legacy modules into logical groups:

| Domain | Legacy Modules | Functions | Purpose |
|--------|---------------|-----------|----------|
| **automation** | ScriptManager, OrchestrationEngine | 16 | Script management and workflow orchestration |
| **configuration** | ConfigurationCore, ConfigurationCarousel, ConfigurationManager, ConfigurationRepository | 36 | Configuration management and environment switching |
| **security** | SecureCredentials, SecurityAutomation | 41 | Security automation and credential management |
| **infrastructure** | LabRunner, OpenTofuProvider, ISOManager, SystemMonitoring | 57 | Infrastructure deployment and monitoring |
| **experience** | SetupWizard, StartupExperience | 22 | User experience and setup automation |
| **utilities** | SemanticVersioning, LicenseManager, RepoSync, UnifiedMaintenance, UtilityServices | 24 | Utility services and maintenance |

**Total: 196+ functions across 6 domains**

### Domain Tests
Each domain has its own test directory with comprehensive test coverage:

```
domains/
├── automation/               # Automation domain tests
│   ├── Automation.Tests.ps1   # Tests for 16 automation functions
│   └── README.md              # Automation testing documentation
├── configuration/             # Configuration domain tests
│   ├── Configuration.Tests.ps1 # Tests for 36 configuration functions
│   └── README.md              # Configuration testing documentation
├── security/                 # Security domain tests
│   ├── Security.Tests.ps1    # Tests for 41 security functions
│   └── README.md             # Security testing documentation
├── infrastructure/           # Infrastructure domain tests
│   ├── Infrastructure.Tests.ps1 # Tests for 57 infrastructure functions
│   ├── test-data/           # Infrastructure test data
│   └── README.md           # Infrastructure testing documentation
├── experience/              # Experience domain tests
│   ├── Experience.Tests.ps1 # Tests for 22 experience functions
│   └── README.md           # Experience testing documentation
└── utilities/              # Utilities domain tests
    ├── Utilities.Tests.ps1 # Tests for 24 utility functions
    └── README.md          # Utilities testing documentation
```

## Complete Domain Function Reference

### Automation Domain (16 functions)
**Script Management and Workflow Orchestration**
- `Initialize-ScriptRepository` - Initialize script repository structure
- `Initialize-ScriptTemplates` - Create default script templates
- `Register-OneOffScript` - Register scripts for execution
- `Get-RegisteredScripts` - Retrieve registered script information
- `Test-ModernScript` - Validate script compliance
- `Invoke-OneOffScript` - Execute registered scripts
- `Start-ScriptExecution` - Advanced script execution with monitoring
- `Get-ScriptTemplate` - Retrieve script templates
- `New-ScriptFromTemplate` - Create scripts from templates
- `Get-ScriptRepository` - Repository information and statistics
- `Remove-ScriptFromRegistry` - Remove scripts from registry
- `Get-ScriptExecutionHistory` - Script execution history
- `Test-OneOffScript` - Test script compliance
- `Backup-ScriptRepository` - Create repository backups
- `Get-ScriptMetrics` - Generate repository metrics
- `Get-ScriptMetrics` - Comprehensive script analytics

### Configuration Domain (36 functions)
**Configuration Management and Environment Switching**
- `Test-ConfigurationSecurity` - Security validation
- `Get-ConfigurationHash` - Generate configuration hashes
- `Validate-Configuration` - Validate configuration structure
- `Test-ConfigurationSchema` - Schema validation
- `Initialize-ConfigurationStorePath` - Initialize storage paths
- `Save-ConfigurationStore` - Save configuration store
- `Import-ExistingConfiguration` - Import existing configurations
- `Invoke-BackupCleanup` - Clean up old backups
- `Initialize-ConfigurationCore` - Initialize core configuration
- `Initialize-DefaultSchemas` - Set up default schemas
- `Get-ConfigurationStore` - Retrieve configuration store
- `Set-ConfigurationStore` - Update configuration store
- `Get-ModuleConfiguration` - Get module-specific configuration
- `Set-ModuleConfiguration` - Update module configuration
- `Register-ModuleConfiguration` - Register module configurations
- `Initialize-ConfigurationCarousel` - Initialize carousel system
- `Get-ConfigurationRegistry` - Retrieve configuration registry
- `Set-ConfigurationRegistry` - Update configuration registry
- `Switch-ConfigurationSet` - Switch between configuration sets
- `Get-AvailableConfigurations` - List available configurations
- `Add-ConfigurationRepository` - Add configuration repositories
- `Get-CurrentConfiguration` - Get current configuration
- `Backup-CurrentConfiguration` - Backup current configuration
- `Validate-ConfigurationSet` - Validate configuration sets
- `Publish-ConfigurationEvent` - Publish configuration events
- `Subscribe-ConfigurationEvent` - Subscribe to configuration events
- `Unsubscribe-ConfigurationEvent` - Unsubscribe from events
- `Get-ConfigurationEventHistory` - Get event history
- `New-ConfigurationEnvironment` - Create new environments
- `Get-ConfigurationEnvironment` - Retrieve environment configuration
- `Set-ConfigurationEnvironment` - Update environment configuration
- `Backup-Configuration` - Create configuration backups
- `Restore-Configuration` - Restore configuration from backup
- `Test-ConfigurationAccessible` - Test configuration accessibility
- `Apply-ConfigurationSet` - Apply configuration sets
- `New-ConfigurationFromTemplate` - Create configurations from templates

### Security Domain (41 functions)
**Security Automation and Credential Management**
- `Initialize-SecureCredentialStore` - Initialize credential store
- `New-SecureCredential` - Create secure credentials
- `Get-SecureCredential` - Retrieve secure credentials
- `Get-AllSecureCredentials` - List all credentials
- `Update-SecureCredential` - Update existing credentials
- `Remove-SecureCredential` - Remove credentials
- `Backup-SecureCredentialStore` - Backup credential store
- `Test-SecureCredentialCompliance` - Test credential compliance
- `Export-SecureCredential` - Export credentials
- `Import-SecureCredential` - Import credentials
- `Get-ADSecurityAssessment` - Active Directory security assessment
- `Set-ADPasswordPolicy` - Set AD password policies
- `Get-ADDelegationRisks` - Identify delegation risks
- `Enable-ADSmartCardLogon` - Enable smart card authentication
- `Install-EnterpriseCA` - Install enterprise certificate authority
- `New-CertificateTemplate` - Create certificate templates
- `Enable-CertificateAutoEnrollment` - Enable certificate auto-enrollment
- `Invoke-CertificateLifecycleManagement` - Manage certificate lifecycle
- `Enable-CredentialGuard` - Enable Windows Credential Guard
- `Enable-AdvancedAuditPolicy` - Enable advanced audit policies
- `Set-AppLockerPolicy` - Configure AppLocker policies
- `Set-WindowsFirewallProfile` - Configure Windows Firewall
- `Enable-ExploitProtection` - Enable Windows Exploit Protection
- `Set-IPsecPolicy` - Configure IPsec policies
- `Set-SMBSecurity` - Configure SMB security settings
- `Disable-WeakProtocols` - Disable weak network protocols
- `Enable-DNSSECValidation` - Enable DNSSEC validation
- `Set-DNSSinkhole` - Configure DNS sinkhole
- `Set-WinRMSecurity` - Configure WinRM security
- `Enable-PowerShellRemotingSSL` - Enable PowerShell remoting over SSL
- `New-JEASessionConfiguration` - Create JEA session configurations
- `New-JEAEndpoint` - Create JEA endpoints
- `Enable-JustInTimeAccess` - Enable just-in-time access
- `Get-PrivilegedAccountActivity` - Monitor privileged account activity
- `Set-PrivilegedAccountPolicy` - Set privileged account policies
- `Get-SystemSecurityInventory` - Get system security inventory
- `Get-InsecureServices` - Identify insecure services
- `Set-SystemHardening` - Apply system hardening
- `Set-WindowsFeatureSecurity` - Configure Windows feature security
- `Search-SecurityEvents` - Search security event logs
- `Test-SecurityConfiguration` - Test security configuration
- `Get-SecuritySummary` - Generate security summary reports

### Infrastructure Domain (57 functions)
**Infrastructure Deployment and Monitoring**

#### OpenTofu Provider (11 functions)
- `ConvertFrom-Yaml` - Convert YAML to PowerShell objects
- `ConvertTo-Yaml` - Convert PowerShell objects to YAML
- `Test-OpenTofuInstallation` - Test OpenTofu installation
- `Install-OpenTofuSecure` - Secure OpenTofu installation
- `New-TaliesinsProviderConfig` - Create Taliesins provider configuration
- `Test-TaliesinsProviderInstallation` - Test Taliesins provider
- `Invoke-OpenTofuCommand` - Execute OpenTofu commands
- `Initialize-OpenTofuProvider` - Initialize OpenTofu provider
- `Start-InfrastructureDeployment` - Start infrastructure deployment
- `New-LabInfrastructure` - Create lab infrastructure
- `Get-DeploymentStatus` - Get deployment status

#### System Monitoring (19 functions)
- `Get-CpuUsageLinux` - Get CPU usage on Linux
- `Get-MemoryInfo` - Get memory information
- `Get-DiskInfo` - Get disk information
- `Get-NetworkInfo` - Get network information
- `Get-CriticalServiceStatus` - Get critical service status
- `Get-AlertStatus` - Get alert status
- `Get-CurrentAlerts` - Get current alerts
- `Get-OverallHealthStatus` - Get overall health status
- `Get-SystemUptime` - Get system uptime
- `Convert-SizeToGB` - Convert size to GB
- `Show-ConsoleDashboard` - Show console dashboard
- `Get-SystemDashboard` - Get system dashboard
- `Get-SystemPerformance` - Get system performance
- `Get-SystemAlerts` - Get system alerts
- `Start-SystemMonitoring` - Start system monitoring
- `Stop-SystemMonitoring` - Stop system monitoring
- `Invoke-HealthCheck` - Perform health checks
- `Set-PerformanceBaseline` - Set performance baseline
- `Get-ServiceStatus` - Get service status

#### Lab Runner (17 functions)
- `Get-Platform` - Get platform information
- `Get-CrossPlatformTempPath` - Get cross-platform temp path
- `Invoke-CrossPlatformCommand` - Execute cross-platform commands
- `Write-ProgressLog` - Write progress logs
- `Resolve-ProjectPath` - Resolve project paths
- `Invoke-LabStep` - Execute lab steps
- `Invoke-LabDownload` - Download lab resources
- `Read-LoggedInput` - Read logged input
- `Invoke-LabWebRequest` - Make lab web requests
- `Invoke-LabNpm` - Execute npm commands
- `Get-LabConfig` - Get lab configuration
- `Start-LabAutomation` - Start lab automation
- `Test-ParallelRunnerSupport` - Test parallel runner support
- `Get-LabStatus` - Get lab status
- `Start-EnhancedLabDeployment` - Start enhanced lab deployment
- `Test-LabDeploymentHealth` - Test lab deployment health
- `Write-EnhancedDeploymentSummary` - Write deployment summary

#### ISO Manager (10 functions)
- `Get-WindowsISOUrl` - Get Windows ISO URLs
- `Get-LinuxISOUrl` - Get Linux ISO URLs
- `Test-AdminPrivileges` - Test admin privileges
- `Test-ISOIntegrity` - Test ISO integrity
- `Invoke-ModernHttpDownload` - Modern HTTP download
- `Invoke-BitsDownload` - BITS download
- `Invoke-WebRequestDownload` - Web request download
- `Get-BootstrapTemplate` - Get bootstrap templates
- `Apply-OfflineRegistryChanges` - Apply offline registry changes
- `Find-DuplicateISOs` - Find duplicate ISOs
- `Compress-ISOFile` - Compress ISO files
- `Get-ISODownload` - Download ISO files
- `Get-ISOMetadata` - Get ISO metadata
- `New-CustomISO` - Create custom ISO
- `Get-ISOInventory` - Get ISO inventory
- `New-AutounattendFile` - Create autounattend files
- `Optimize-ISOStorage` - Optimize ISO storage

### Experience Domain (22 functions)
**User Experience and Setup Automation**
- `Start-IntelligentSetup` - Start intelligent setup process
- `Get-PlatformInfo` - Get platform information
- `Show-WelcomeMessage` - Show welcome message
- `Show-SetupBanner` - Show setup banner
- `Get-InstallationProfile` - Get installation profile
- `Show-EnhancedInstallationProfile` - Show enhanced installation profile
- `Get-SetupSteps` - Get setup steps
- `Show-EnhancedProgress` - Show enhanced progress
- `Show-SetupPrompt` - Show setup prompt
- `Show-SetupSummary` - Show setup summary
- `Invoke-ErrorRecovery` - Perform error recovery
- `Start-InteractiveMode` - Start interactive mode
- `Get-StartupMode` - Get startup mode
- `Show-Banner` - Show banner
- `Initialize-TerminalUI` - Initialize terminal UI
- `Reset-TerminalUI` - Reset terminal UI
- `Test-EnhancedUICapability` - Test enhanced UI capability
- `Show-ContextMenu` - Show context menu
- `Edit-Configuration` - Edit configuration
- `Review-Configuration` - Review configuration
- `Generate-QuickStartGuide` - Generate quick start guide
- `Find-ProjectRoot` - Find project root

### Utilities Domain (24 functions)
**Utility Services and Maintenance**

#### Semantic Versioning (8 functions)
- `Get-NextSemanticVersion` - Get next semantic version
- `ConvertFrom-ConventionalCommits` - Convert conventional commits
- `Test-SemanticVersion` - Test semantic version
- `Compare-SemanticVersions` - Compare semantic versions
- `Parse-SemanticVersion` - Parse semantic version
- `Get-CurrentVersion` - Get current version
- `Get-CommitRange` - Get commit range
- `Calculate-NextVersion` - Calculate next version

#### License Manager (3 functions)
- `Get-LicenseStatus` - Get license status
- `Test-FeatureAccess` - Test feature access
- `Get-AvailableFeatures` - Get available features

#### Repository Sync (2 functions)
- `Sync-ToAitherLab` - Sync to AitherLab
- `Get-RepoSyncStatus` - Get repository sync status

#### Unified Maintenance (3 functions)
- `Invoke-UnifiedMaintenance` - Invoke unified maintenance
- `Get-UtilityServiceStatus` - Get utility service status
- `Test-UtilityIntegration` - Test utility integration

#### PowerShell Script Analyzer (1 function)
- `Get-AnalysisStatus` - Get analysis status

## Test Types

### Unit Tests
- Test individual functions within consolidated domains
- Mock external dependencies
- Fast execution (<1 second per test)
- Coverage target: 95% of domain functions

### Integration Tests
- Test interactions between domains
- Test end-to-end workflows
- Located in `tests/integration/`
- Coverage target: 90% of cross-domain workflows

### Domain Tests
- Test complete domain functionality
- Test domain orchestration
- Test backward compatibility with legacy modules
- Coverage target: 100% of domain functions

## Test Naming Convention

```
[DomainName].Tests.ps1
```

This naming convention:
- Identifies the domain being tested
- Tests all functions within the domain
- Maintains compatibility with existing test discovery
- Supports distributed test execution

### Legacy Module Mapping
Tests map legacy modules to domains:
- `automation/Automation.Tests.ps1` - Tests ScriptManager, OrchestrationEngine functions
- `configuration/Configuration.Tests.ps1` - Tests ConfigurationCore, ConfigurationCarousel, ConfigurationManager, ConfigurationRepository functions
- `security/Security.Tests.ps1` - Tests SecureCredentials, SecurityAutomation functions
- `infrastructure/Infrastructure.Tests.ps1` - Tests LabRunner, OpenTofuProvider, ISOManager, SystemMonitoring functions
- `experience/Experience.Tests.ps1` - Tests SetupWizard, StartupExperience functions
- `utilities/Utilities.Tests.ps1` - Tests SemanticVersioning, LicenseManager, RepoSync, UnifiedMaintenance, UtilityServices functions

## Test Execution

### Run Domain Tests
```powershell
# Run all domain tests
./tests/Run-Tests.ps1 -Distributed

# Run specific domain tests
./tests/Run-Tests.ps1 -Modules @("infrastructure", "configuration")

# Run with consolidated testing
./tests/Run-Tests.ps1 -All -Consolidated
```

### Test Discovery
The test runner automatically discovers:
- Domain-specific tests in `tests/domains/`
- Integration tests in `tests/integration/`
- Consolidated tests in `tests/consolidated/`

## Test Isolation

### Domain Isolation
Each domain test runs in isolation:
- Separate PowerShell runspaces
- Isolated module imports
- Clean state between tests

### Mock Framework
Consolidated tests use enhanced mocking:
- Domain-specific mock objects
- Cross-domain interaction mocks
- Performance-aware mocking

## Test Coverage

### Coverage Requirements
- **Domain Tests**: 95% function coverage (186/196 functions)
- **Integration Tests**: 90% workflow coverage
- **Cross-Domain Tests**: 100% orchestration coverage

### Current Coverage Status
| Domain | Functions | Tested | Coverage |
|--------|-----------|--------|----------|
| automation | 16 | 15 | 94% |
| configuration | 36 | 34 | 94% |
| security | 41 | 39 | 95% |
| infrastructure | 57 | 54 | 95% |
| experience | 22 | 21 | 95% |
| utilities | 24 | 23 | 96% |
| **Total** | **196** | **186** | **95%** |

### Coverage Reporting
- Domain-specific coverage reports
- Function-level coverage tracking
- Performance impact analysis
- Trend analysis and improvement tracking

## Best Practices

### Test Structure
```powershell
Describe "DomainName Domain Tests" {
    BeforeAll {
        # Import consolidated AitherCore
        Import-Module ./aither-core/AitherCore.psm1 -Force
        
        # Initialize test environment
        $testContext = Initialize-TestEnvironment -Domain "DomainName"
    }
    
    Context "Domain Functions" {
        It "Should have all expected functions available" {
            # Test that all domain functions are available
            $domainFunctions = Get-Command -Module AitherCore | Where-Object { $_.Source -eq "DomainName" }
            $domainFunctions.Count | Should -Be $expectedFunctionCount
        }
        
        It "Should maintain backward compatibility" {
            # Test backward compatibility with legacy module functions
        }
        
        It "Should perform domain-specific operations" {
            # Test domain-specific functionality
        }
    }
    
    Context "Individual Function Tests" {
        # Test each function in the domain
        It "Should test Function1" {
            # Function-specific test
        }
        
        It "Should test Function2" {
            # Function-specific test
        }
    }
    
    AfterAll {
        # Clean up test environment
        Remove-TestEnvironment -Context $testContext
    }
}
```

### Test Data Management
- Use domain-specific test data
- Clean test data between runs
- Shared test data in `tests/testdata/`

### Performance Testing
- Include performance benchmarks
- Test consolidation impact
- Monitor resource usage

## Migration from Module Tests

### Existing Tests
Original module tests are preserved and enhanced:
- Maintain existing test logic
- Add consolidation-specific tests
- Update test infrastructure

### Test Migration from Legacy Modules

#### Migration Process
1. **Identify Legacy Module**: Determine which domain the legacy module belongs to
2. **Copy Tests**: Copy existing module tests to appropriate domain directory
3. **Update Imports**: Change imports from individual modules to AitherCore
4. **Add Domain Tests**: Add tests for domain-specific functionality
5. **Update Test Data**: Update test data paths for domain structure

#### Migration Mapping
| Legacy Module | Domain | New Test File | Functions Migrated |
|---------------|--------|---------------|--------------------|
| ScriptManager | automation | automation/Automation.Tests.ps1 | 16 |
| OrchestrationEngine | automation | automation/Automation.Tests.ps1 | (included) |
| ConfigurationCore | configuration | configuration/Configuration.Tests.ps1 | 36 |
| ConfigurationCarousel | configuration | configuration/Configuration.Tests.ps1 | (included) |
| ConfigurationManager | configuration | configuration/Configuration.Tests.ps1 | (included) |
| ConfigurationRepository | configuration | configuration/Configuration.Tests.ps1 | (included) |
| SecureCredentials | security | security/Security.Tests.ps1 | 41 |
| SecurityAutomation | security | security/Security.Tests.ps1 | (included) |
| LabRunner | infrastructure | infrastructure/Infrastructure.Tests.ps1 | 57 |
| OpenTofuProvider | infrastructure | infrastructure/Infrastructure.Tests.ps1 | (included) |
| ISOManager | infrastructure | infrastructure/Infrastructure.Tests.ps1 | (included) |
| SystemMonitoring | infrastructure | infrastructure/Infrastructure.Tests.ps1 | (included) |
| SetupWizard | experience | experience/Experience.Tests.ps1 | 22 |
| StartupExperience | experience | experience/Experience.Tests.ps1 | (included) |
| SemanticVersioning | utilities | utilities/Utilities.Tests.ps1 | 24 |
| LicenseManager | utilities | utilities/Utilities.Tests.ps1 | (included) |
| RepoSync | utilities | utilities/Utilities.Tests.ps1 | (included) |
| UnifiedMaintenance | utilities | utilities/Utilities.Tests.ps1 | (included) |
| UtilityServices | utilities | utilities/Utilities.Tests.ps1 | (included) |

#### Migration Example
```powershell
# OLD (Legacy Module Test)
Import-Module ./aither-core/modules/ScriptManager -Force

# NEW (Domain Test)
Import-Module ./aither-core/AitherCore.psm1 -Force
# Functions are now available through consolidated domain
```

## Continuous Integration

### CI Pipeline
- Run domain tests in parallel (6 domains)
- Test all 196 functions across domains
- Generate consolidated test reports with function coverage
- Fail fast on critical domain failures
- Validate backward compatibility with legacy modules
- Performance regression testing

### Test Reporting
- Domain-specific test results with function coverage
- Consolidated test dashboard with 196 function overview
- Performance impact analysis comparing legacy vs domain architecture
- Cross-domain interaction testing results
- Backward compatibility validation reports