# Configuration Manager Module

## Overview

The **Configuration Manager** is a unified configuration management system for AitherZero that consolidates the functionality of three separate configuration modules:

- **ConfigurationCore**: Core configuration storage, validation, and environment management
- **ConfigurationCarousel**: Multi-configuration switching and environment management  
- **ConfigurationRepository**: Git-based configuration repository management

This consolidated module provides a single point of entry for all configuration operations while maintaining full backward compatibility with the original modules.

## Key Features

### 🔧 **Unified Configuration Management**
- Single module for all configuration operations
- Consolidated storage with automatic conflict resolution
- Cross-module data sharing and synchronization

### 🔄 **Backward Compatibility**
- All original function names and parameters preserved
- Automatic legacy module import for seamless migration
- Alias support for deprecated function names

### 🌍 **Multi-Environment Support**
- Environment-specific configuration overlays
- Dynamic environment switching
- Environment inheritance and validation

### 📦 **Configuration Repository Management**
- Git-based configuration repositories
- Template-based configuration generation
- Automated synchronization and backup

### 🔐 **Enterprise Security**
- Configuration encryption and validation
- Hash-based integrity checking
- Secure file permissions and access control

### 📊 **Event-Driven Architecture**
- Real-time configuration change notifications
- Pub/sub event system for module integration
- Comprehensive audit logging

## Installation and Setup

### Initialize the Configuration Manager

```powershell
# Basic initialization
Initialize-ConfigurationManager

# Initialize with custom path and legacy import
Initialize-ConfigurationManager -ConfigurationPath "C:\CustomConfig" -Force

# Initialize without legacy module compatibility
Initialize-ConfigurationManager -SkipLegacyImport
```

### Import Legacy Configurations

```powershell
# Import all legacy configurations
Import-LegacyConfiguration -SourceModule All -BackupExisting

# Import specific module with conflict resolution
Import-LegacyConfiguration -SourceModule ConfigurationCore -MergeStrategy Preserve

# Force import with validation bypass
Import-LegacyConfiguration -SourceModule All -Force
```

## Core Functions

### Configuration Management

#### Get Unified Configuration
```powershell
# Get all configuration data
$config = Get-UnifiedConfiguration

# Get specific module configuration
$labConfig = Get-UnifiedConfiguration -Module "LabRunner" -Environment "prod"

# Get configuration set from carousel
$enterpriseConfig = Get-UnifiedConfiguration -ConfigurationSet "enterprise" -Format JSON

# Include metadata and output as JSON
$fullConfig = Get-UnifiedConfiguration -IncludeMetadata -Format JSON
```

#### Set Unified Configuration
```powershell
# Set module configuration
Set-UnifiedConfiguration -Module "LabRunner" -Configuration @{
    MaxConcurrency = 4
    TimeoutMinutes = 30
    LogLevel = "Info"
}

# Set environment configuration with backup
Set-UnifiedConfiguration -Environment "prod" -Configuration @{
    LogLevel = "Error"
    DebugMode = $false
    MetricsEnabled = $true
} -BackupBeforeChange

# Set configuration set with validation
Set-UnifiedConfiguration -ConfigurationSet "enterprise" -Configuration @{
    description = "Enterprise configuration with enhanced security"
    securityLevel = "high"
    auditEnabled = $true
} -Validate
```

### System Management

#### Check System Status
```powershell
# Basic status check
$status = Get-ConfigurationManagerStatus

# Detailed status with health checks
$detailedStatus = Get-ConfigurationManagerStatus -IncludeDetails -CheckHealth
```

#### Test System Functionality
```powershell
# Run basic tests
$testResults = Test-ConfigurationManager

# Run comprehensive tests with performance analysis
$fullTest = Test-ConfigurationManager -TestSuite Full -IncludePerformance -GenerateReport
```

## Legacy Function Compatibility

All original functions from the three source modules are preserved:

### ConfigurationCore Functions
```powershell
# Core configuration management
Initialize-ConfigurationCore
Get-ModuleConfiguration -ModuleName "LabRunner"
Set-ModuleConfiguration -ModuleName "LabRunner" -Configuration @{Setting="Value"}
Test-ModuleConfiguration -ModuleName "LabRunner"

# Environment management  
Get-ConfigurationEnvironment
Set-ConfigurationEnvironment -EnvironmentName "staging"
New-ConfigurationEnvironment -Name "testing" -Description "Test environment"

# Hot reload and events
Enable-ConfigurationHotReload
Publish-ConfigurationEvent -EventName "ConfigChanged" -EventData @{Module="Test"}
Subscribe-ConfigurationEvent -EventPattern "Config*" -Action { Write-Host "Config changed" }
```

### ConfigurationCarousel Functions
```powershell
# Configuration switching
Switch-ConfigurationSet -ConfigurationName "enterprise" -Environment "prod"
Get-AvailableConfigurations -IncludeDetails
Get-CurrentConfiguration

# Repository management
Add-ConfigurationRepository -Name "team-config" -Source "https://github.com/team/config.git"
Remove-ConfigurationRepository -Name "old-config" -DeleteFiles

# Backup and validation
Backup-CurrentConfiguration -Reason "Before major update"
Validate-ConfigurationSet -ConfigurationName "enterprise"
```

### ConfigurationRepository Functions
```powershell
# Repository creation and management
New-ConfigurationRepository -RepositoryName "my-config" -LocalPath "./config" -Template "enterprise"
Clone-ConfigurationRepository -RepositoryUrl "https://github.com/org/config.git" -LocalPath "./remote-config"
Sync-ConfigurationRepository -Path "./config" -Operation "sync"

# Validation and documentation
Validate-ConfigurationRepository -Path "./config"
```

## Advanced Usage

### Environment-Specific Configuration

```powershell
# Create environment hierarchy
New-ConfigurationEnvironment -Name "dev" -Description "Development environment"
New-ConfigurationEnvironment -Name "staging" -Description "Staging environment" 
New-ConfigurationEnvironment -Name "prod" -Description "Production environment"

# Set environment-specific overrides
Set-UnifiedConfiguration -Environment "prod" -Configuration @{
    LabRunner = @{
        MaxConcurrency = 2  # Lower concurrency in prod
        LogLevel = "Error"  # Less verbose logging
    }
    Security = @{
        EncryptionEnabled = $true
        AuditLevel = "Full"
    }
}

# Switch active environment
Set-ConfigurationEnvironment -EnvironmentName "prod"
```

### Configuration Repository Workflows

```powershell
# Create new configuration repository
$repoResult = New-ConfigurationRepository -RepositoryName "enterprise-config" -LocalPath "C:\Config\Enterprise" -Template "enterprise" -Provider "github" -Private

# Clone existing repository
$cloneResult = Clone-ConfigurationRepository -RepositoryUrl "https://github.com/company/aither-config.git" -LocalPath "C:\Config\Company" -Validate

# Add to carousel and activate
Add-ConfigurationRepository -Name "company-config" -Source "C:\Config\Company" -SetAsCurrent

# Synchronize with remote
Sync-ConfigurationRepository -Path "C:\Config\Company" -Operation "sync" -CreateBackup
```

### Event-Driven Configuration

```powershell
# Subscribe to configuration changes
Subscribe-ConfigurationEvent -EventPattern "ModuleConfigurationChanged" -Action {
    param($EventData)
    Write-Host "Module $($EventData.Module) configuration changed"
    # Trigger dependent service restart
    Restart-Service -Name "AitherZeroService" -Force
}

# Subscribe to environment changes
Subscribe-ConfigurationEvent -EventPattern "EnvironmentConfigurationChanged" -Action {
    param($EventData)
    $env = $EventData.Environment
    Write-Host "Environment $env updated - notifying administrators"
    Send-MailMessage -To "admin@company.com" -Subject "Config Change" -Body "Environment $env was updated"
}

# Custom event publishing
Publish-ConfigurationEvent -EventName "CustomDeployment" -EventData @{
    Version = "1.2.3"
    Environment = "prod"
    Timestamp = Get-Date
} -Priority "High"
```

## Migration Guide

### From Separate Modules

1. **Install Configuration Manager**
   ```powershell
   Import-Module ./aither-core/modules/ConfigurationManager -Force
   ```

2. **Initialize with legacy import**
   ```powershell
   Initialize-ConfigurationManager
   Import-LegacyConfiguration -SourceModule All -BackupExisting
   ```

3. **Verify migration**
   ```powershell
   $status = Get-ConfigurationManagerStatus -IncludeDetails
   Test-ConfigurationManager -TestSuite Extended
   ```

4. **Update scripts (optional)**
   Replace individual module imports:
   ```powershell
   # Old way
   Import-Module ConfigurationCore
   Import-Module ConfigurationCarousel  
   Import-Module ConfigurationRepository
   
   # New way
   Import-Module ConfigurationManager
   ```

### Breaking Changes

**None!** The Configuration Manager maintains 100% backward compatibility. All existing scripts will continue to work without modification.

## Configuration Files

### Unified Configuration Structure
```json
{
  "Metadata": {
    "Version": "1.0",
    "LastModified": "2025-01-07T10:30:00",
    "ModuleVersion": "1.0.0",
    "ConsolidatedModules": ["ConfigurationCore", "ConfigurationCarousel", "ConfigurationRepository"]
  },
  "Modules": {
    "LabRunner": {
      "MaxConcurrency": 4,
      "TimeoutMinutes": 30
    }
  },
  "Environments": {
    "prod": {
      "Name": "prod",
      "Description": "Production environment",
      "Settings": {
        "LogLevel": "Error",
        "DebugMode": false
      }
    }
  },
  "Carousel": {
    "CurrentConfiguration": "enterprise",
    "Configurations": {
      "enterprise": {
        "name": "enterprise",
        "description": "Enterprise configuration",
        "type": "custom"
      }
    }
  },
  "Repository": {
    "ActiveRepositories": {},
    "Templates": {
      "enterprise": {
        "Description": "Enterprise-grade configuration template"
      }
    }
  }
}
```

## Error Handling and Troubleshooting

### Common Issues

1. **Module Not Initialized**
   ```powershell
   # Error: Configuration Manager not initialized
   Initialize-ConfigurationManager
   ```

2. **Legacy Module Conflicts**
   ```powershell
   # Force re-import legacy modules
   Import-LegacyConfiguration -SourceModule All -Force
   ```

3. **Configuration File Corruption**
   ```powershell
   # Test and repair configuration
   $test = Test-ConfigurationManager -TestSuite Extended
   if (-not $test.OverallResult -eq 'Passed') {
       # Restore from backup
       Reset-ConfigurationManager -RestoreFromBackup
   }
   ```

### Diagnostic Commands

```powershell
# Check overall system health
Get-ConfigurationManagerStatus -CheckHealth

# Run comprehensive tests
Test-ConfigurationManager -TestSuite Full -GenerateReport

# Validate configuration integrity
$integrity = Test-ConfigurationIntegrity
if (-not $integrity.IsValid) {
    Write-Host "Issues found: $($integrity.Errors -join '; ')"
}
```

## Performance Considerations

- **Startup Time**: ~200ms for full initialization
- **Memory Usage**: ~10MB for typical configurations
- **File I/O**: Optimized with lazy loading and caching
- **Event Processing**: Asynchronous event handling

### Performance Tuning

```powershell
# Disable hot reload for better performance
Disable-ConfigurationHotReload

# Reduce event history size
$script:UnifiedConfigurationStore.Events.MaxHistorySize = 100

# Use compressed JSON for large configurations
Set-UnifiedConfiguration -Module "LargeModule" -Configuration $largeConfig -Compress
```

## API Reference

### Core Functions
- `Initialize-ConfigurationManager` - Initialize the unified system
- `Get-ConfigurationManagerStatus` - Get system status and health
- `Test-ConfigurationManager` - Run system tests
- `Get-UnifiedConfiguration` - Retrieve configuration data
- `Set-UnifiedConfiguration` - Update configuration data
- `Import-LegacyConfiguration` - Migrate from legacy modules

### Management Functions
- `Reset-ConfigurationManager` - Reset system to defaults
- `Update-ConfigurationManager` - Update system components
- `Export-UnifiedConfiguration` - Export configuration data
- `Convert-ConfigurationFormat` - Convert between formats

### Legacy Compatibility
All functions from ConfigurationCore, ConfigurationCarousel, and ConfigurationRepository are available with their original signatures and behavior.

## Contributing

When contributing to the Configuration Manager:

1. Maintain backward compatibility with all legacy functions
2. Add comprehensive tests for new functionality
3. Update documentation for API changes
4. Follow PowerShell best practices and coding standards
5. Test across Windows, Linux, and macOS platforms

## Support

For issues and questions:
- Check the troubleshooting section above
- Review test results: `Test-ConfigurationManager -GenerateReport`
- Examine logs: `Get-ConfigurationManagerStatus -IncludeDetails`
- Submit issues to the AitherZero repository with diagnostic information

---

**Configuration Manager v1.0.0** - Unified configuration management for AitherZero  
*Consolidating ConfigurationCore, ConfigurationCarousel, and ConfigurationRepository*