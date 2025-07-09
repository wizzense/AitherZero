# AitherZero API Reference

This document provides comprehensive API reference for all AitherZero domains and functions.

## Overview

AitherZero provides a rich set of APIs organized into functional domains. This reference documents all public functions, their parameters, return values, and usage examples.

## Domain Structure

AitherZero is organized into six functional domains:

- **[Infrastructure Domain](#infrastructure-domain)**: Infrastructure management and deployment
- **[Configuration Domain](#configuration-domain)**: Configuration management and validation
- **[Security Domain](#security-domain)**: Security and credential management
- **[Automation Domain](#automation-domain)**: Script and automation management
- **[Experience Domain](#experience-domain)**: User experience and setup
- **[Utilities Domain](#utilities-domain)**: Shared utility services

## Infrastructure Domain

### LabRunner Functions

#### Start-LabAutomation
Starts lab automation workflows and processes.

```powershell
Start-LabAutomation [-LabName] <String> [[-ConfigPath] <String>] [[-Environment] <String>] [-WhatIf] [-Confirm]
```

**Parameters:**
- `LabName`: Name of the lab to start
- `ConfigPath`: Path to lab configuration file
- `Environment`: Target environment (dev, test, prod)
- `WhatIf`: Preview mode without making changes
- `Confirm`: Confirm before making changes

**Example:**
```powershell
Start-LabAutomation -LabName "test-lab" -Environment "dev"
```

#### Stop-LabAutomation
Stops running lab automation processes.

```powershell
Stop-LabAutomation [-LabName] <String> [-Force] [-WhatIf] [-Confirm]
```

**Parameters:**
- `LabName`: Name of the lab to stop
- `Force`: Force stop without graceful shutdown
- `WhatIf`: Preview mode without making changes
- `Confirm`: Confirm before making changes

**Example:**
```powershell
Stop-LabAutomation -LabName "test-lab" -Force
```

#### Get-LabStatus
Retrieves the status of lab automation processes.

```powershell
Get-LabStatus [[-LabName] <String>] [-Detailed]
```

**Parameters:**
- `LabName`: Name of specific lab (optional, returns all if omitted)
- `Detailed`: Include detailed status information

**Example:**
```powershell
Get-LabStatus -LabName "test-lab" -Detailed
```

### OpenTofuProvider Functions

#### New-VMDeployment
Creates new virtual machine deployments using OpenTofu.

```powershell
New-VMDeployment [-Name] <String> [-Template] <String> [[-Environment] <String>] [[-ResourceGroup] <String>] [-WhatIf] [-Confirm]
```

**Parameters:**
- `Name`: Name of the VM deployment
- `Template`: Template to use for deployment
- `Environment`: Target environment
- `ResourceGroup`: Resource group for deployment
- `WhatIf`: Preview mode without making changes
- `Confirm`: Confirm before making changes

**Example:**
```powershell
New-VMDeployment -Name "web-server-01" -Template "ubuntu-web" -Environment "dev"
```

#### Start-InfrastructureDeployment
Starts infrastructure deployment using OpenTofu templates.

```powershell
Start-InfrastructureDeployment [-ConfigPath] <String> [[-Environment] <String>] [-Validate] [-WhatIf] [-Confirm]
```

**Parameters:**
- `ConfigPath`: Path to deployment configuration
- `Environment`: Target environment
- `Validate`: Validate configuration before deployment
- `WhatIf`: Preview mode without making changes
- `Confirm`: Confirm before making changes

**Example:**
```powershell
Start-InfrastructureDeployment -ConfigPath "./configs/infrastructure.json" -Environment "dev" -Validate
```

#### Get-DeploymentStatus
Retrieves the status of infrastructure deployments.

```powershell
Get-DeploymentStatus [[-Name] <String>] [-Detailed]
```

**Parameters:**
- `Name`: Name of specific deployment (optional)
- `Detailed`: Include detailed status information

**Example:**
```powershell
Get-DeploymentStatus -Name "web-server-01" -Detailed
```

### ISOManager Functions

#### Get-ISODownload
Downloads ISO files from specified sources.

```powershell
Get-ISODownload [-Source] <String> [-Destination] <String> [[-Checksum] <String>] [-Verify] [-Force]
```

**Parameters:**
- `Source`: Source URL or path for ISO
- `Destination`: Destination path for downloaded ISO
- `Checksum`: Expected checksum for verification
- `Verify`: Verify ISO integrity after download
- `Force`: Force download even if file exists

**Example:**
```powershell
Get-ISODownload -Source "https://example.com/ubuntu.iso" -Destination "./isos/ubuntu.iso" -Verify
```

#### New-CustomISO
Creates custom ISO files with specified configurations.

```powershell
New-CustomISO [-Name] <String> [-BasePath] <String> [-OutputPath] <String> [[-CustomFiles] <String[]>] [-Bootable]
```

**Parameters:**
- `Name`: Name for the custom ISO
- `BasePath`: Base directory for ISO contents
- `OutputPath`: Output path for created ISO
- `CustomFiles`: Additional files to include
- `Bootable`: Create bootable ISO

**Example:**
```powershell
New-CustomISO -Name "custom-ubuntu" -BasePath "./base-files" -OutputPath "./custom.iso" -Bootable
```

### SystemMonitoring Functions

#### Start-SystemMonitoring
Starts system performance monitoring.

```powershell
Start-SystemMonitoring [[-Duration] <Int32>] [[-Interval] <Int32>] [[-Metrics] <String[]>] [-Continuous]
```

**Parameters:**
- `Duration`: Monitoring duration in seconds
- `Interval`: Monitoring interval in seconds
- `Metrics`: Specific metrics to monitor
- `Continuous`: Run continuous monitoring

**Example:**
```powershell
Start-SystemMonitoring -Duration 300 -Interval 5 -Metrics @("CPU", "Memory", "Disk")
```

#### Get-SystemMetrics
Retrieves current system performance metrics.

```powershell
Get-SystemMetrics [[-Metrics] <String[]>] [-Detailed]
```

**Parameters:**
- `Metrics`: Specific metrics to retrieve
- `Detailed`: Include detailed metric information

**Example:**
```powershell
Get-SystemMetrics -Metrics @("CPU", "Memory") -Detailed
```

## Configuration Domain

### ConfigurationCore Functions

#### Set-Configuration
Sets configuration values in the configuration store.

```powershell
Set-Configuration [-Key] <String> [-Value] <Object> [[-Environment] <String>] [-Global] [-Encrypt]
```

**Parameters:**
- `Key`: Configuration key
- `Value`: Configuration value
- `Environment`: Target environment
- `Global`: Set as global configuration
- `Encrypt`: Encrypt the configuration value

**Example:**
```powershell
Set-Configuration -Key "database.connectionString" -Value "Server=localhost;Database=mydb" -Environment "dev" -Encrypt
```

#### Get-Configuration
Retrieves configuration values from the configuration store.

```powershell
Get-Configuration [[-Key] <String>] [[-Environment] <String>] [-Decrypt] [-Default] <Object>]
```

**Parameters:**
- `Key`: Configuration key (optional, returns all if omitted)
- `Environment`: Target environment
- `Decrypt`: Decrypt encrypted values
- `Default`: Default value if key not found

**Example:**
```powershell
Get-Configuration -Key "database.connectionString" -Environment "dev" -Decrypt
```

#### Test-Configuration
Validates configuration values and structure.

```powershell
Test-Configuration [[-ConfigPath] <String>] [[-Schema] <String>] [-Detailed]
```

**Parameters:**
- `ConfigPath`: Path to configuration file
- `Schema`: Schema for validation
- `Detailed`: Include detailed validation results

**Example:**
```powershell
Test-Configuration -ConfigPath "./configs/app-config.json" -Schema "./schemas/config-schema.json" -Detailed
```

### ConfigurationCarousel Functions

#### Switch-ConfigurationSet
Switches between different configuration sets.

```powershell
Switch-ConfigurationSet [-ConfigurationName] <String> [[-Environment] <String>] [-Backup] [-Validate]
```

**Parameters:**
- `ConfigurationName`: Name of configuration set
- `Environment`: Target environment
- `Backup`: Backup current configuration
- `Validate`: Validate configuration before switching

**Example:**
```powershell
Switch-ConfigurationSet -ConfigurationName "production-config" -Environment "prod" -Backup -Validate
```

#### Get-AvailableConfigurations
Retrieves list of available configuration sets.

```powershell
Get-AvailableConfigurations [[-Environment] <String>] [-Detailed]
```

**Parameters:**
- `Environment`: Filter by environment
- `Detailed`: Include detailed configuration information

**Example:**
```powershell
Get-AvailableConfigurations -Environment "prod" -Detailed
```

### ConfigurationRepository Functions

#### New-ConfigurationRepository
Creates new configuration repositories.

```powershell
New-ConfigurationRepository [-RepositoryName] <String> [-LocalPath] <String> [[-Template] <String>] [[-RemoteUrl] <String>]
```

**Parameters:**
- `RepositoryName`: Name for the repository
- `LocalPath`: Local path for repository
- `Template`: Template to use for repository
- `RemoteUrl`: Remote repository URL

**Example:**
```powershell
New-ConfigurationRepository -RepositoryName "my-config" -LocalPath "./configs/my-config" -Template "default"
```

#### Sync-ConfigurationRepository
Synchronizes configuration repositories.

```powershell
Sync-ConfigurationRepository [-Path] <String> [[-Operation] <String>] [-Force] [-Verbose]
```

**Parameters:**
- `Path`: Path to repository
- `Operation`: Sync operation (pull, push, sync)
- `Force`: Force synchronization
- `Verbose`: Verbose output

**Example:**
```powershell
Sync-ConfigurationRepository -Path "./configs/my-config" -Operation "sync" -Verbose
```

## Security Domain

### SecureCredentials Functions

#### Get-SecureCredential
Retrieves secure credentials from the credential store.

```powershell
Get-SecureCredential [-Name] <String> [[-Environment] <String>] [-Decrypt] [-AsPlainText]
```

**Parameters:**
- `Name`: Credential name
- `Environment`: Target environment
- `Decrypt`: Decrypt credential
- `AsPlainText`: Return as plain text (use with caution)

**Example:**
```powershell
Get-SecureCredential -Name "database-admin" -Environment "prod" -Decrypt
```

#### Set-SecureCredential
Stores secure credentials in the credential store.

```powershell
Set-SecureCredential [-Name] <String> [-Credential] <PSCredential> [[-Environment] <String>] [-Encrypt] [-Force]
```

**Parameters:**
- `Name`: Credential name
- `Credential`: Credential object
- `Environment`: Target environment
- `Encrypt`: Encrypt credential
- `Force`: Force update if exists

**Example:**
```powershell
$cred = Get-Credential
Set-SecureCredential -Name "database-admin" -Credential $cred -Environment "prod" -Encrypt
```

#### Remove-SecureCredential
Removes secure credentials from the credential store.

```powershell
Remove-SecureCredential [-Name] <String> [[-Environment] <String>] [-Force] [-WhatIf] [-Confirm]
```

**Parameters:**
- `Name`: Credential name
- `Environment`: Target environment
- `Force`: Force removal without confirmation
- `WhatIf`: Preview mode without making changes
- `Confirm`: Confirm before making changes

**Example:**
```powershell
Remove-SecureCredential -Name "old-credential" -Environment "dev" -Confirm
```

### SecurityAutomation Functions

#### Start-SecurityScan
Starts security scanning and assessment.

```powershell
Start-SecurityScan [[-ScanType] <String>] [[-Target] <String>] [[-OutputPath] <String>] [-Detailed] [-Quiet]
```

**Parameters:**
- `ScanType`: Type of security scan
- `Target`: Target for scanning
- `OutputPath`: Output path for results
- `Detailed`: Include detailed scan results
- `Quiet`: Suppress output

**Example:**
```powershell
Start-SecurityScan -ScanType "vulnerability" -Target "localhost" -OutputPath "./security-scan.json" -Detailed
```

#### Get-SecurityStatus
Retrieves current security status and metrics.

```powershell
Get-SecurityStatus [[-Component] <String>] [-Detailed] [-Summary]
```

**Parameters:**
- `Component`: Specific component to check
- `Detailed`: Include detailed status information
- `Summary`: Return summary only

**Example:**
```powershell
Get-SecurityStatus -Component "credentials" -Detailed
```

## Automation Domain

### ScriptManager Functions

#### Invoke-ScriptExecution
Executes scripts with specified parameters.

```powershell
Invoke-ScriptExecution [-ScriptPath] <String> [[-Parameters] <Hashtable>] [[-Environment] <String>] [-Validate] [-WhatIf]
```

**Parameters:**
- `ScriptPath`: Path to script file
- `Parameters`: Parameters to pass to script
- `Environment`: Target environment
- `Validate`: Validate script before execution
- `WhatIf`: Preview mode without execution

**Example:**
```powershell
Invoke-ScriptExecution -ScriptPath "./scripts/deploy.ps1" -Parameters @{Environment="dev"} -Validate
```

#### Get-ScriptTemplate
Retrieves available script templates.

```powershell
Get-ScriptTemplate [[-Name] <String>] [[-Category] <String>] [-Detailed]
```

**Parameters:**
- `Name`: Template name (optional)
- `Category`: Template category
- `Detailed`: Include detailed template information

**Example:**
```powershell
Get-ScriptTemplate -Category "deployment" -Detailed
```

#### New-ScriptFromTemplate
Creates new scripts from templates.

```powershell
New-ScriptFromTemplate [-TemplateName] <String> [-OutputPath] <String> [[-Parameters] <Hashtable>] [-Force]
```

**Parameters:**
- `TemplateName`: Name of template to use
- `OutputPath`: Output path for new script
- `Parameters`: Parameters for template
- `Force`: Force creation if file exists

**Example:**
```powershell
New-ScriptFromTemplate -TemplateName "basic-deployment" -OutputPath "./scripts/my-deployment.ps1" -Parameters @{AppName="MyApp"}
```

## Experience Domain

### SetupWizard Functions

#### Start-IntelligentSetup
Starts intelligent setup wizard.

```powershell
Start-IntelligentSetup [[-InstallationProfile] <String>] [-MinimalSetup] [-SkipOptional] [-Force]
```

**Parameters:**
- `InstallationProfile`: Installation profile (minimal, developer, full)
- `MinimalSetup`: Use minimal setup
- `SkipOptional`: Skip optional components
- `Force`: Force setup even if already configured

**Example:**
```powershell
Start-IntelligentSetup -InstallationProfile "developer" -Force
```

#### Test-Prerequisites
Tests system prerequisites for AitherZero.

```powershell
Test-Prerequisites [[-Component] <String>] [-Detailed] [-Fix]
```

**Parameters:**
- `Component`: Specific component to test
- `Detailed`: Include detailed test results
- `Fix`: Attempt to fix issues automatically

**Example:**
```powershell
Test-Prerequisites -Component "powershell" -Detailed -Fix
```

#### Generate-QuickStartGuide
Generates personalized quick start guides.

```powershell
Generate-QuickStartGuide [[-SetupState] <Object>] [[-OutputPath] <String>] [[-Format] <String>]
```

**Parameters:**
- `SetupState`: Current setup state
- `OutputPath`: Output path for guide
- `Format`: Output format (markdown, html, pdf)

**Example:**
```powershell
Generate-QuickStartGuide -SetupState $setupResult -OutputPath "./my-quickstart.md" -Format "markdown"
```

### StartupExperience Functions

#### Start-InteractiveStartup
Starts interactive startup experience.

```powershell
Start-InteractiveStartup [[-Mode] <String>] [[-ConfigPath] <String>] [-SkipIntro] [-Verbose]
```

**Parameters:**
- `Mode`: Startup mode (interactive, guided, expert)
- `ConfigPath`: Configuration file path
- `SkipIntro`: Skip introduction
- `Verbose`: Verbose output

**Example:**
```powershell
Start-InteractiveStartup -Mode "guided" -ConfigPath "./configs/startup-config.json"
```

#### Get-UserPreferences
Retrieves user preferences and settings.

```powershell
Get-UserPreferences [[-Category] <String>] [[-User] <String>] [-Default]
```

**Parameters:**
- `Category`: Preference category
- `User`: Specific user (default: current user)
- `Default`: Return default preferences

**Example:**
```powershell
Get-UserPreferences -Category "display" -User "john.doe"
```

## Utilities Domain

### UtilityServices Functions

#### Register-Service
Registers services with the service registry.

```powershell
Register-Service [-ServiceName] <String> [-ServiceType] <String> [[-Configuration] <Hashtable>] [-StartImmediately]
```

**Parameters:**
- `ServiceName`: Name of the service
- `ServiceType`: Type of service
- `Configuration`: Service configuration
- `StartImmediately`: Start service immediately

**Example:**
```powershell
Register-Service -ServiceName "MyService" -ServiceType "Background" -Configuration @{Interval=60} -StartImmediately
```

#### Get-ServiceStatus
Retrieves service status information.

```powershell
Get-ServiceStatus [[-ServiceName] <String>] [-Detailed] [-IncludeMetrics]
```

**Parameters:**
- `ServiceName`: Specific service name (optional)
- `Detailed`: Include detailed status information
- `IncludeMetrics`: Include performance metrics

**Example:**
```powershell
Get-ServiceStatus -ServiceName "MyService" -Detailed -IncludeMetrics
```

#### Start-ServiceMonitoring
Starts service monitoring and health checks.

```powershell
Start-ServiceMonitoring [[-ServiceName] <String>] [[-Interval] <Int32>] [-Continuous] [-AlertOnFailure]
```

**Parameters:**
- `ServiceName`: Service to monitor (optional, monitors all if omitted)
- `Interval`: Monitoring interval in seconds
- `Continuous`: Run continuous monitoring
- `AlertOnFailure`: Send alerts on service failure

**Example:**
```powershell
Start-ServiceMonitoring -ServiceName "MyService" -Interval 30 -Continuous -AlertOnFailure
```

## Common Parameters

### Standard Parameters
Most functions support these standard parameters:
- `-Verbose`: Enable verbose output
- `-Debug`: Enable debug output
- `-ErrorAction`: Error handling behavior
- `-WarningAction`: Warning handling behavior
- `-InformationAction`: Information message handling
- `-ErrorVariable`: Variable to store errors
- `-WarningVariable`: Variable to store warnings
- `-InformationVariable`: Variable to store information messages
- `-OutVariable`: Variable to store output
- `-OutBuffer`: Output buffering
- `-PipelineVariable`: Pipeline variable name

### Risk Mitigation Parameters
Functions that make changes support these parameters:
- `-WhatIf`: Preview mode without making changes
- `-Confirm`: Confirm before making changes

### Common Patterns
```powershell
# Verbose execution
Get-Configuration -Key "mykey" -Verbose

# Debug mode
Start-LabAutomation -LabName "test" -Debug

# Preview mode
New-VMDeployment -Name "test-vm" -Template "ubuntu" -WhatIf

# Confirmation
Remove-SecureCredential -Name "old-cred" -Confirm
```

## Error Handling

### Exception Types
AitherZero uses specific exception types for different error conditions:
- `AitherConfigurationException`: Configuration-related errors
- `AitherSecurityException`: Security-related errors
- `AitherDeploymentException`: Deployment-related errors
- `AitherValidationException`: Validation-related errors

### Error Handling Patterns
```powershell
# Basic error handling
try {
    Start-LabAutomation -LabName "test-lab"
} catch {
    Write-Error "Failed to start lab: $($_.Exception.Message)"
}

# Specific error handling
try {
    Get-SecureCredential -Name "missing-cred"
} catch [AitherSecurityException] {
    Write-Warning "Security error: $($_.Exception.Message)"
} catch {
    Write-Error "Unexpected error: $($_.Exception.Message)"
}
```

## Return Values

### Common Return Types
- `[PSCustomObject]`: Structured data objects
- `[String]`: String values
- `[Boolean]`: Success/failure indicators
- `[Hashtable]`: Key-value collections
- `[Array]`: Collections of objects

### Status Objects
Many functions return status objects with common properties:
```powershell
@{
    Success = $true
    Message = "Operation completed successfully"
    Data = @{ ... }
    Timestamp = (Get-Date)
    Duration = (New-TimeSpan -Seconds 5)
}
```

## Best Practices

### Function Usage
1. **Use WhatIf**: Preview changes before execution
2. **Validate Parameters**: Use parameter validation
3. **Handle Errors**: Implement proper error handling
4. **Use Verbose**: Enable verbose output for troubleshooting
5. **Check Prerequisites**: Validate prerequisites before execution

### Performance Considerations
1. **Use Efficient Queries**: Optimize data retrieval
2. **Batch Operations**: Group related operations
3. **Cache Results**: Cache frequently used data
4. **Monitor Resources**: Monitor system resources
5. **Use Parallel Processing**: Utilize parallel execution where appropriate

### Security Considerations
1. **Protect Credentials**: Use secure credential management
2. **Validate Input**: Validate all user input
3. **Use Encryption**: Encrypt sensitive data
4. **Audit Operations**: Log security-relevant operations
5. **Follow Principle of Least Privilege**: Use minimal required permissions

## Related Documentation

- [Domain Documentation](aither-core/domains/README.md): Domain-specific documentation
- [Module Documentation](aither-core/modules/README.md): Module-specific documentation
- [Development Guidelines](docs/development/README.md): Development standards
- [Testing Framework](tests/README.md): Testing documentation
- [Quick Start Guide](docs/quickstart/README.md): Getting started guide
- [Configuration Guide](docs/configuration/README.md): Configuration documentation
- [Security Guide](docs/security/README.md): Security documentation