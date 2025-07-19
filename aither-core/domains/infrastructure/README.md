# Infrastructure Domain

> 🏗️ **Complete Infrastructure Automation** - Lab deployment, OpenTofu/Terraform management, ISO customization, and system monitoring

This domain consolidates **4 legacy modules** into **57 specialized functions** for comprehensive infrastructure management.

## Domain Overview

**Function Count**: 57 functions  
**Legacy Modules Consolidated**: 4 (LabRunner, OpenTofuProvider, ISOManager, SystemMonitoring)  
**Primary Use Cases**: Infrastructure deployment, lab automation, ISO management, system monitoring

## Consolidated Components

### LabRunner (17 functions)
**Original Module**: `aither-core/modules/LabRunner/`  
**Status**: ✅ Consolidated  
**Purpose**: Lab automation and deployment orchestration

**Key Functions**:
- `Start-LabAutomation` - Initiate lab automation workflows
- `Invoke-LabStep` - Execute individual lab deployment steps
- `Get-LabStatus` - Monitor lab deployment status
- `Start-EnhancedLabDeployment` - Advanced lab deployment with monitoring
- `Test-LabConfiguration` - Validate lab configuration before deployment
- `New-LabEnvironment` - Create new lab environments
- `Stop-LabAutomation` - Gracefully stop lab automation processes

### OpenTofuProvider (11 functions)
**Original Module**: `aither-core/modules/OpenTofuProvider/`  
**Status**: ✅ Consolidated  
**Purpose**: OpenTofu/Terraform infrastructure deployment and management

**Key Functions**:
- `Start-InfrastructureDeployment` - Deploy infrastructure using OpenTofu
- `Initialize-OpenTofuProvider` - Initialize OpenTofu provider configuration
- `New-LabInfrastructure` - Create lab infrastructure resources
- `Test-OpenTofuConfiguration` - Validate OpenTofu configurations
- `Get-InfrastructureStatus` - Monitor infrastructure deployment status
- `Remove-InfrastructureDeployment` - Clean up infrastructure resources
- `Export-InfrastructureState` - Export and backup infrastructure state

### ISOManager (10 functions)
**Original Module**: `aither-core/modules/ISOManager/`  
**Status**: ✅ Consolidated  
**Purpose**: ISO management, customization, and repository operations

**Key Functions**:
- `Get-ISODownload` - Download ISO files from various sources
- `New-CustomISO` - Create custom ISO files with injected configurations
- `New-ISORepository` - Set up ISO repositories for management
- `Get-ISOInventory` - List and manage ISO inventory
- `Mount-ISO` - Mount ISO files for operations
- `Dismount-ISO` - Unmount ISO files
- `Test-ISOIntegrity` - Verify ISO file integrity and checksums

### SystemMonitoring (19 functions)
**Original Module**: `aither-core/modules/SystemMonitoring/`  
**Status**: ✅ Consolidated  
**Purpose**: Real-time system monitoring, performance tracking, and alerting

**Key Functions**:
- `Get-SystemPerformance` - Retrieve detailed system performance metrics
- `Start-SystemMonitoring` - Begin continuous system monitoring
- `Get-SystemDashboard` - Generate system health dashboard
- `Get-SystemAlerts` - Retrieve system alerts and warnings
- `Set-PerformanceThreshold` - Configure performance alert thresholds
- `Export-SystemMetrics` - Export system metrics to various formats
- `Get-ProcessMonitoring` - Monitor specific processes and services

## Usage Examples

```powershell
# Import Infrastructure Domain (or use through AitherCore)
. "$PSScriptRoot/../../../aither-core/domains/infrastructure/LabRunner.ps1"

# Lab Automation
Start-LabAutomation -ConfigurationName "WebServerLab" -EnvironmentType "Development"
Get-LabStatus -LabName "WebServerLab"

# Infrastructure Deployment  
Start-InfrastructureDeployment -ConfigurationPath "./infrastructure/main.tf" -Environment "staging"
Get-InfrastructureStatus -DeploymentId "deploy-12345"

# ISO Management
Get-ISODownload -ISOType "WindowsServer2022" -Destination "./isos/"
New-CustomISO -BaseISO "./base.iso" -CustomizationScript "./customize.ps1"

# System Monitoring
Start-SystemMonitoring -MonitoringProfile "Production" -AlertThresholds @{CPU=80; Memory=90; Disk=85}
Get-SystemDashboard -IncludeHistoricalData -TimeRange "24hours"
```

## Common Workflows

### Lab Environment Deployment
```powershell
# Complete lab setup workflow
$labConfig = @{
    Name = "DeveloperLab"
    Environment = "Development"
    VMs = @("WebServer", "Database", "LoadBalancer")
    NetworkConfig = "./configs/lab-network.json"
}

Start-LabAutomation -Configuration $labConfig
Test-LabConfiguration -ConfigurationName $labConfig.Name
Get-LabStatus -LabName $labConfig.Name -Detailed
```

### Infrastructure as Code Deployment
```powershell
# OpenTofu deployment with validation
Initialize-OpenTofuProvider -ConfigurationPath "./infrastructure"
Test-OpenTofuConfiguration -ConfigurationPath "./infrastructure" -Environment "production"
Start-InfrastructureDeployment -ConfigurationPath "./infrastructure" -Environment "production" -AutoApprove:$false
```

### System Monitoring Setup
```powershell
# Production monitoring configuration
$monitoringConfig = @{
    Profile = "Production"
    Thresholds = @{
        CPU = 80
        Memory = 90
        Disk = 85
        NetworkLatency = 100
    }
    AlertsEnabled = $true
    DashboardEnabled = $true
}

Start-SystemMonitoring @monitoringConfig
Get-SystemAlerts -Severity "Warning" -Last24Hours
```

## Implementation Structure

```
infrastructure/
├── LabRunner.ps1           # Lab automation functions (17 functions)
├── OpenTofuProvider.ps1    # Infrastructure deployment functions (11 functions)  
├── ISOManager.ps1          # ISO management functions (10 functions)
├── SystemMonitoring.ps1    # System monitoring functions (19 functions)
└── README.md              # This documentation
```

## Integration Points

- **Configuration Domain**: Retrieves environment-specific configurations
- **Security Domain**: Integrates with credential management for secure deployments
- **Utilities Domain**: Uses semantic versioning for infrastructure versioning
- **Experience Domain**: Provides setup wizards for complex infrastructure scenarios

## Testing

```powershell
# Run infrastructure domain tests
./tests/domains/infrastructure/Infrastructure.Tests.ps1

# Specific component testing
./tests/domains/infrastructure/LabRunner.Tests.ps1
./tests/domains/infrastructure/OpenTofuProvider.Tests.ps1
./tests/domains/infrastructure/SystemMonitoring.Tests.ps1
```

## Usage Examples

```powershell
# Start lab automation
Start-LabAutomation -Configuration $config -ShowProgress

# Deploy infrastructure
Start-InfrastructureDeployment -ConfigurationPath "./lab-config.yaml"

# Download and customize ISO
$iso = Get-ISODownload -ISOName "Windows11"
New-CustomISO -SourceISO $iso.FilePath -AutounattendPath $autounattend

# Monitor system performance
Start-SystemMonitoring -Interval 60 -Dashboard
```

## Testing

Infrastructure domain tests are located in:
- `tests/domains/infrastructure/`
- Integration tests in `tests/integration/`

## Dependencies

- **Write-CustomLog**: Guaranteed available from AitherCore orchestration
- **Find-ProjectRoot**: Shared utility for project root detection
- **Configuration Services**: Uses unified configuration management