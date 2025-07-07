# ISOManagement Module v3.0.0

**Unified Enterprise-Grade ISO Lifecycle Management**

The ISOManagement module represents the consolidation of ISOManager v2.0.0 and ISOCustomizer v1.0.0 into a comprehensive, enterprise-grade solution for complete ISO lifecycle management. This unified module provides streamlined workflows for downloading, customizing, and deploying ISO images with advanced automation capabilities.

## 🚀 Key Features

### Complete ISO Lifecycle Management
- **Unified Workflow Engine**: Seamless integration from download to deployment-ready customization
- **Multi-Source Downloads**: Support for Windows, Linux, and custom ISO sources
- **Advanced Customization**: Autounattend generation, script injection, driver integration
- **Template Library**: Pre-built templates for common deployment scenarios
- **Batch Processing**: Pipeline automation for enterprise-scale deployments
- **Progress Tracking**: Real-time monitoring across all operations

### Enterprise Integration
- **Repository Management**: Structured organization with metadata tracking
- **Workflow History**: Comprehensive audit trail and performance analytics
- **Parallel Processing**: Efficient batch operations with configurable concurrency
- **Cross-Platform**: Full Windows, Linux, and macOS compatibility
- **Template System**: Extensible template library with custom template support

## 📋 What's New in v3.0.0

### Consolidated Architecture
- **Unified API**: Single module replacing ISOManager and ISOCustomizer
- **Integrated Workflows**: Download-to-deployment pipelines in single operations
- **Enhanced Templates**: Comprehensive template library with intelligent defaults
- **Backward Compatibility**: All existing function calls continue to work unchanged

### New Unified Functions
- `Start-ISOLifecycleWorkflow` - Complete ISO automation from download to deployment
- `New-DeploymentReadyISO` - One-step custom ISO creation with templates
- `Invoke-ISOPipeline` - Batch processing for multiple ISOs
- `Get-ISOTemplateLibrary` - Template management and discovery
- `Get-ISOWorkflowStatus` - Comprehensive workflow monitoring

### Enhanced Capabilities
- **Smart Templates**: Pre-configured scenarios for domain controllers, member servers, workstations
- **Pipeline Processing**: Sequential, parallel, and batch processing modes
- **Configuration Export/Import**: Save and share workflow configurations
- **Advanced Reporting**: HTML reports with performance metrics

## 🛠️ Quick Start

### Basic Installation and Setup

```powershell
# Import the unified module
Import-Module ./aither-core/modules/ISOManagement -Force

# Initialize default repository (automatic on first run)
Get-ISOManagementConfiguration -Section 'Runtime'

# View available templates
Get-ISOTemplateLibrary -OutputFormat 'Table'
```

### Simple Deployment-Ready ISO Creation

```powershell
# Create a Windows Server 2025 Domain Controller ISO
$dcConfig = @{
    DomainName = 'lab.local'
    DomainMode = '2016'
    ForestMode = '2016'
    SafeModePassword = 'SafeMode123!'
}

New-DeploymentReadyISO -ISOTemplate 'WindowsServer2025-DC' `
    -ComputerName 'DC-01' -AdminPassword 'P@ssw0rd123!' `
    -SourceISO 'WindowsServer2025' -OutputPath 'DC-01-Ready.iso' `
    -DomainConfiguration $dcConfig
```

### Complete Lifecycle Workflow

```powershell
# Download, customize, and validate in one operation
$downloadConfig = @{
    ISOType = 'Windows'
    Version = 'latest'
    Architecture = 'x64'
}

$customConfig = @{
    ComputerName = 'LAB-PC-01'
    AdminPassword = 'P@ssw0rd123!'
    TimeZone = 'Pacific Standard Time'
    EnableRDP = $true
    BootstrapScript = '.\Scripts\lab-setup.ps1'
}

Start-ISOLifecycleWorkflow -ISOName "Windows11" -ISOSource "Download" `
    -DownloadConfig $downloadConfig -CustomizationConfig $customConfig `
    -OutputPath "Windows11-Lab-Ready.iso" -WorkflowName "Lab-Setup"
```

## 📚 Function Reference

### 🔄 Unified Workflow Functions

#### Start-ISOLifecycleWorkflow
Complete ISO lifecycle automation from source to deployment-ready output.

**Key Parameters:**
- `ISOName` - Name/identifier for the ISO
- `ISOSource` - Source type ('Download', 'Local', 'Repository')
- `DownloadConfig` - Download configuration (when source is 'Download')
- `CustomizationConfig` - Customization settings and parameters
- `OutputPath` - Path for final deployment-ready ISO
- `WorkflowName` - Name for tracking and history

**Example:**
```powershell
Start-ISOLifecycleWorkflow -ISOName "Ubuntu22.04" -ISOSource "Download" `
    -DownloadConfig @{ISOType='Linux'; Version='22.04'} `
    -CustomizationConfig @{Packages=@('docker.io','nginx')} `
    -OutputPath "Ubuntu-WebServer.iso" -WorkflowName "WebServer-Deploy"
```

#### New-DeploymentReadyISO
Simplified template-based ISO creation with intelligent defaults.

**Templates Available:**
- `WindowsServer2025-DC` - Domain Controller deployment
- `WindowsServer2025-Member` - Domain member server
- `Windows11-Enterprise` - Enterprise workstation
- `Ubuntu22.04-Server` - Ubuntu server deployment
- `Custom` - Custom configuration

**Example:**
```powershell
New-DeploymentReadyISO -ISOTemplate 'Windows11-Enterprise' `
    -ComputerName 'WS-001' -AdminPassword 'P@ssw0rd!' `
    -SourceISO 'Windows11-Enterprise.iso' -OutputPath 'WS-001-Ready.iso' `
    -IPConfiguration @{IPAddress='192.168.1.100'; Gateway='192.168.1.1'}
```

#### Invoke-ISOPipeline
Batch processing for multiple ISOs with parallel execution support.

**Processing Modes:**
- `Sequential` - Process one at a time
- `Parallel` - Process multiple simultaneously
- `Batch` - Process in configurable batch sizes

**Example:**
```powershell
$isos = @(
    @{Name='DC-01'; Template='WindowsServer2025-DC'; SourceISO='Server2025.iso'},
    @{Name='FILE-01'; Template='WindowsServer2025-Member'; SourceISO='Server2025.iso'},
    @{Name='WEB-01'; Template='Ubuntu22.04-Server'; SourceISO='ubuntu-22.04.iso'}
)

Invoke-ISOPipeline -InputISOs $isos -OutputDirectory 'C:\DeploymentISOs' `
    -ProcessingMode 'Parallel' -MaxConcurrency 3 -GenerateReport
```

### 📖 Template and Configuration Functions

#### Get-ISOTemplateLibrary
Browse and manage the comprehensive template library.

**Example:**
```powershell
# View all templates in table format
Get-ISOTemplateLibrary -OutputFormat 'Table'

# Get Windows templates with detailed information
Get-ISOTemplateLibrary -TemplateType 'Windows' -IncludeDetails -IncludeExamples

# Show custom templates location
Get-ISOTemplateLibrary -ShowCustomTemplatesPath
```

#### Get-ISOWorkflowStatus
Monitor workflow execution with comprehensive status reporting.

**Example:**
```powershell
# Get today's workflows
Get-ISOWorkflowStatus -TimeRange 'Today' -OutputFormat 'Table'

# Get detailed status for specific workflow
Get-ISOWorkflowStatus -WorkflowId 'WF-20250707-143022-a1b2c3d4' -IncludeDetails
```

### 🗂️ Repository Management (from ISOManager)

All existing ISOManager functions remain available with full compatibility:

- `Get-ISODownload` - Download ISOs from multiple sources
- `Get-ISOInventory` - Repository inventory management
- `New-ISORepository` - Create structured repositories
- `Sync-ISORepository` - Repository synchronization
- `Optimize-ISOStorage` - Storage optimization and cleanup
- `Export-ISOInventory` / `Import-ISOInventory` - Inventory backup/restore

### 🔧 Customization Functions (from ISOCustomizer)

All existing ISOCustomizer functions remain available:

- `New-CustomISO` - Advanced ISO customization
- `New-AutounattendFile` - Generate Windows answer files
- `New-AdvancedAutounattendFile` - Complex autounattend scenarios
- `Get-AutounattendTemplate` / `Get-BootstrapTemplate` / `Get-KickstartTemplate` - Template access

### ✅ Validation and Utilities

- `Test-ISOIntegrity` - Unified integrity validation (enhanced from both modules)
- `Get-ISOMetadata` - Comprehensive metadata extraction
- `Get-ISOManagementConfiguration` - Module configuration management

## 🏗️ Advanced Usage Scenarios

### Enterprise Lab Deployment

```powershell
# Complete lab infrastructure deployment
$labConfig = @{
    Pipeline = @{
        Name = 'Enterprise Lab v2.1'
        ProcessingMode = 'Parallel'
        MaxConcurrency = 4
    }
    DefaultSettings = @{
        Organization = 'Contoso Corp'
        TimeZone = 'Eastern Standard Time'
        AdminPassword = 'LabP@ssw0rd123!'
    }
    ISOs = @(
        @{
            Name = 'DC-01'
            Template = 'WindowsServer2025-DC'
            SourceISO = 'download:WindowsServer2025'
            ComputerName = 'CONTOSO-DC-01'
            Configuration = @{
                DomainName = 'contoso.local'
                SafeModePassword = 'SafeMode123!'
                DNSForwarders = @('8.8.8.8', '8.8.4.4')
            }
        },
        @{
            Name = 'SQL-01'
            Template = 'WindowsServer2025-Member'
            SourceISO = 'WindowsServer2025.iso'
            ComputerName = 'CONTOSO-SQL-01'
            Configuration = @{
                JoinDomain = 'contoso.local'
                ServerRoles = @('SQL Server 2022')
                IPAddress = '192.168.100.20'
            }
        }
    )
}

# Execute lab deployment pipeline
$result = Invoke-ISOPipeline -PipelineConfiguration $labConfig `
    -OutputDirectory 'C:\LabDeployment' -GenerateReport

# Monitor progress
Get-ISOWorkflowStatus -TimeRange 'Today' -IncludePerformance
```

### Multi-Platform Development Environment

```powershell
# Create development environment ISOs
$devEnvironments = @(
    @{
        Name = 'DevWin11'
        Template = 'Windows11-Enterprise'
        SourceISO = 'Windows11-Enterprise.iso'
        ComputerName = 'DEV-WIN-01'
        Configuration = @{
            DeveloperMode = $true
            WSL = $true
            VisualStudio = $true
            DockerDesktop = $true
        }
    },
    @{
        Name = 'DevUbuntu'
        Template = 'Ubuntu22.04-Server'
        SourceISO = 'ubuntu-22.04-desktop-amd64.iso'
        ComputerName = 'dev-ubuntu-01'
        Configuration = @{
            Packages = @('docker.io', 'code', 'git', 'nodejs', 'python3-pip')
            Services = @('docker', 'ssh')
            Users = @(
                @{Username = 'developer'; Groups = @('sudo', 'docker')}
            )
        }
    }
)

# Process development environments
Invoke-ISOPipeline -InputISOs $devEnvironments `
    -OutputDirectory 'D:\DevEnvironments' -ProcessingMode 'Parallel'
```

### Configuration Management and Backup

```powershell
# Export current configuration
$config = Get-ISOManagementConfiguration -IncludeAdvanced
$config | ConvertTo-Json -Depth 10 | Out-File 'iso-management-backup.json'

# Create repository backup
Export-ISOInventory -RepositoryPath $repoPath -ExportPath 'inventory-backup.json' `
    -IncludeMetadata -IncludeIntegrity

# Workflow status reporting
Get-ISOWorkflowStatus -TimeRange 'Month' -OutputFormat 'Table' | 
    Out-File 'monthly-workflow-report.txt'
```

## 🎯 Template Library

### Built-in Templates

#### Windows Templates
- **WindowsServer2025-DC**: Domain Controller with AD DS, DNS, DHCP
- **WindowsServer2025-Member**: Domain member server with management tools
- **WindowsServer2025-Core**: Server Core for minimal deployments
- **Windows11-Enterprise**: Business workstation with enterprise features
- **Windows10-Pro**: Professional workstation configuration

#### Linux Templates
- **Ubuntu22.04-Server**: Ubuntu LTS server with SSH and common packages
- **Ubuntu20.04-Desktop**: Ubuntu desktop with GNOME environment
- **CentOS8-Server**: RHEL-compatible server with SELinux

### Custom Template Creation

```powershell
# Create custom template directory
$customPath = Join-Path (Get-ISOManagementConfiguration).Paths.DefaultRepositoryPath "Templates"

# Custom template example
$customTemplate = @{
    Name = 'WindowsServer2025-WebServer'
    DisplayName = 'Windows Server 2025 Web Server'
    Type = 'Windows'
    OSType = 'Server2025'
    Edition = 'Standard'
    WIMIndex = 3
    Description = 'Web server with IIS and .NET Framework'
    Features = @('IIS-WebServerRole', 'IIS-WebServer', 'NetFx4Extended-ASPNET45')
    UseCase = 'Web application hosting, ASP.NET applications'
    AutounattendTemplate = 'autounattend-webserver.xml'
    BootstrapTemplate = 'webserver-setup.ps1'
}

$customTemplate | ConvertTo-Json -Depth 10 | 
    Out-File (Join-Path $customPath "WindowsServer2025-WebServer.json")
```

## 🔧 Configuration and Environment

### Module Configuration

```powershell
# View current configuration
Get-ISOManagementConfiguration -OutputFormat 'Table'

# Check environment health
$health = Test-ISOManagementEnvironment
if (-not $health.IsHealthy) {
    Write-Host "Issues found:" -ForegroundColor Red
    $health.Issues | ForEach-Object { Write-Host "  • $_" -ForegroundColor Yellow }
}
```

### Repository Structure

```
ISO-Repository/
├── Windows/                    # Windows ISO files
├── Linux/                      # Linux distribution ISOs
├── Custom/                     # Custom or third-party ISOs
├── Templates/                  # Custom templates and configurations
├── Metadata/                   # ISO metadata and catalogs
├── Logs/                       # Operation and workflow logs
├── Temp/                       # Temporary processing files
├── Archive/                    # Archived old files
├── Backup/                     # File and configuration backups
├── repository.config.json      # Repository configuration
└── WorkflowHistory.json        # Workflow execution history
```

### Performance Tuning

```powershell
# Configure parallel processing
$config = @{
    MaxConcurrency = 4                    # Parallel operations
    DefaultTimeoutSeconds = 7200          # Extended timeout for large ISOs
    MaxHistoryEntries = 200               # Extended history retention
}

# Apply configuration (implementation depends on Set-ISOManagementConfiguration)
# Set-ISOManagementConfiguration -Section 'Performance' -Configuration $config
```

## 🔄 Migration from ISOManager/ISOCustomizer

### Automatic Migration
- **No Action Required**: All existing scripts continue to work unchanged
- **Enhanced Functionality**: Existing functions gain access to new unified features
- **Backward Compatibility**: 100% compatibility with existing function calls

### Taking Advantage of New Features

```powershell
# Old approach (still works)
$download = Get-ISODownload -ISOName "Windows11" -DownloadPath "C:\ISOs"
$custom = New-CustomISO -SourceISOPath $download.FilePath `
    -OutputISOPath "Windows11-Custom.iso" -AutounattendConfig $config

# New unified approach
$result = Start-ISOLifecycleWorkflow -ISOName "Windows11" -ISOSource "Download" `
    -CustomizationConfig $config -OutputPath "Windows11-Custom.iso"
```

### Template Migration

```powershell
# Convert existing configurations to templates
$existingConfig = @{
    ComputerName = 'SERVER-01'
    AdminPassword = 'P@ssw0rd!'
    Features = @('IIS-WebServerRole')
}

# Use with new template system
New-DeploymentReadyISO -ISOTemplate 'WindowsServer2025-Member' `
    -ComputerName $existingConfig.ComputerName `
    -AdminPassword $existingConfig.AdminPassword `
    -AdvancedOptions @{ServerFeatures = $existingConfig.Features}
```

## 📊 Monitoring and Reporting

### Workflow Monitoring

```powershell
# Real-time status monitoring
while ($true) {
    $status = Get-ISOWorkflowStatus -Status 'InProgress' -TimeRange 'Today'
    if ($status.Count -gt 0) {
        Write-Host "Active workflows: $($status.Count)" -ForegroundColor Green
        $status | Select-Object WorkflowName, Status, Duration | Format-Table
    }
    Start-Sleep -Seconds 30
}
```

### Performance Analytics

```powershell
# Generate performance report
$workflows = Get-ISOWorkflowStatus -TimeRange 'Month' -IncludePerformance
$analytics = $workflows | Group-Object Status | ForEach-Object {
    [PSCustomObject]@{
        Status = $_.Name
        Count = $_.Count
        AvgDuration = ($_.Group | Measure-Object -Property 'Performance.DurationMinutes' -Average).Average
        SuccessRate = [Math]::Round(($_.Count / $workflows.Count) * 100, 1)
    }
}

$analytics | Format-Table -AutoSize
```

### Health Monitoring

```powershell
# Daily health check script
function Test-ISOManagementHealth {
    $health = Test-ISOManagementEnvironment
    $repoSize = (Get-ChildItem -Path (Get-ISOManagementConfiguration).Paths.DefaultRepositoryPath -Recurse | 
                 Measure-Object -Property Length -Sum).Sum / 1GB
    
    $report = @{
        Timestamp = Get-Date
        IsHealthy = $health.IsHealthy
        Issues = $health.Issues
        Warnings = $health.Warnings
        RepositorySizeGB = [Math]::Round($repoSize, 2)
        ActiveWorkflows = (Get-ISOWorkflowStatus -Status 'InProgress').Count
        RecentFailures = (Get-ISOWorkflowStatus -Status 'Failed' -TimeRange 'Week').Count
    }
    
    return $report
}

# Run daily and log results
$healthCheck = Test-ISOManagementHealth
$healthCheck | ConvertTo-Json | Out-File "health-$(Get-Date -Format 'yyyy-MM-dd').json"
```

## 🚨 Troubleshooting

### Common Issues

#### Template Not Found
```powershell
# Check available templates
Get-ISOTemplateLibrary | Where-Object Name -like "*Server*"

# Verify template path
Get-ISOManagementConfiguration -Section 'Templates'
```

#### Workflow Failures
```powershell
# Check recent failed workflows
Get-ISOWorkflowStatus -Status 'Failed' -TimeRange 'Week' -IncludeDetails

# Review specific workflow
$workflow = Get-ISOWorkflowStatus -WorkflowId 'WF-20250707-143022-a1b2c3d4'
$workflow.Phases | Where-Object Status -eq 'Failed'
```

#### Storage Issues
```powershell
# Check repository size and cleanup
Optimize-ISOStorage -RepositoryPath $repoPath -MaxSizeGB 500 -DryRun
```

### Debug Mode

```powershell
# Enable verbose logging for troubleshooting
$VerbosePreference = 'Continue'
Import-Module ./aither-core/modules/ISOManagement -Force -Verbose

# Test environment
$health = Test-ISOManagementEnvironment -Verbose
```

## 🎯 Best Practices

### 1. Repository Organization
- Use descriptive naming conventions for ISOs
- Maintain separate directories for different OS types
- Regular inventory exports for backup
- Monitor repository size and optimize regularly

### 2. Template Management
- Create templates for common deployment scenarios
- Version control custom templates
- Test templates before production use
- Document template requirements and use cases

### 3. Workflow Design
- Use meaningful workflow names for tracking
- Configure appropriate timeout values for large ISOs
- Enable progress tracking for long-running operations
- Plan parallel processing based on system resources

### 4. Security Considerations
- Use SecureString for passwords in automation
- Validate ISO integrity before customization
- Secure template files and bootstrap scripts
- Regular security updates for base ISOs

### 5. Performance Optimization
- Use SSD storage for ISO processing
- Configure appropriate concurrency levels
- Clean up temporary files regularly
- Monitor system resources during batch operations

## 📝 Changelog

### v3.0.0 (Current)
- **Major**: Consolidated ISOManager and ISOCustomizer into unified module
- **New**: Start-ISOLifecycleWorkflow for complete automation
- **New**: New-DeploymentReadyISO with template-based creation
- **New**: Invoke-ISOPipeline for batch processing
- **New**: Comprehensive template library system
- **New**: Workflow tracking and history
- **Enhanced**: Parallel processing capabilities
- **Enhanced**: Progress tracking across all operations
- **Maintained**: 100% backward compatibility

### Previous Versions
- **ISOManager v2.0.0**: Enterprise repository management
- **ISOCustomizer v1.0.0**: Advanced ISO customization

## 🤝 Contributing

To contribute to the ISOManagement module:

1. Fork the AitherZero repository
2. Create a feature branch for your changes
3. Add comprehensive tests for new functionality
4. Update documentation and examples
5. Submit a pull request with detailed description

### Running Tests

```powershell
# Run module tests
Invoke-Pester ./aither-core/modules/ISOManagement/tests/

# Run integration tests
./tests/Run-Tests.ps1 -Module ISOManagement

# Test with sample configurations
New-DeploymentReadyISO -ISOTemplate 'WindowsServer2025-DC' -ValidateOnly
```

## 📄 License

This module is part of the AitherZero project and follows the project's licensing terms.

---

**Note**: This module requires PowerShell 7.0+ and integrates with the AitherZero ecosystem. For Windows ISO customization, Windows ADK is recommended but not required for basic operations. Enterprise features require appropriate licensing and infrastructure.

## 🔗 Quick Reference

| Task | Function | Example |
|------|----------|---------|
| Simple ISO Creation | `New-DeploymentReadyISO` | `-ISOTemplate 'Windows11-Enterprise'` |
| Complete Workflow | `Start-ISOLifecycleWorkflow` | `-ISOSource 'Download' -WorkflowName 'Lab'` |
| Batch Processing | `Invoke-ISOPipeline` | `-ProcessingMode 'Parallel'` |
| Monitor Progress | `Get-ISOWorkflowStatus` | `-TimeRange 'Today'` |
| Browse Templates | `Get-ISOTemplateLibrary` | `-OutputFormat 'Table'` |
| Check Configuration | `Get-ISOManagementConfiguration` | `-Section 'All'` |
| Legacy Download | `Get-ISODownload` | `-ISOName 'Windows11'` |
| Legacy Customize | `New-CustomISO` | `-SourceISOPath 'source.iso'` |

**Get Started**: `Import-Module ./aither-core/modules/ISOManagement -Force -Verbose`