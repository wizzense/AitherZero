# Infrastructure Domain Tests

This directory contains tests for the Infrastructure domain, which consolidates infrastructure deployment and monitoring functionality.

## Domain Overview

The Infrastructure domain consolidates the following legacy modules:
- **LabRunner** - Lab automation orchestration
- **OpenTofuProvider** - Infrastructure deployment with OpenTofu/Terraform
- **ISOManager** - ISO management and customization
- **SystemMonitoring** - System performance monitoring

**Total Functions: 57**

## Function Reference

### OpenTofu Provider (11 functions)
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

### System Monitoring (19 functions)
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

### Lab Runner (17 functions)
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

### ISO Manager (10 functions)
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

## Test Categories

### Unit Tests
- **OpenTofu Provider Tests** - Test OpenTofu integration and deployment
- **System Monitoring Tests** - Test system monitoring and health checks
- **Lab Runner Tests** - Test lab automation and orchestration
- **ISO Manager Tests** - Test ISO management and customization

### Integration Tests
- **End-to-End Deployment Tests** - Test complete deployment workflows
- **Cross-Platform Tests** - Test functionality across operating systems
- **Performance Tests** - Test system performance and monitoring
- **Multi-Service Tests** - Test interactions between infrastructure services

### Infrastructure Tests
- **Deployment Tests** - Test infrastructure deployment scenarios
- **Monitoring Tests** - Test system monitoring and alerting
- **Resource Tests** - Test resource provisioning and management
- **Recovery Tests** - Test disaster recovery and backup scenarios

## Test Execution

### Run All Infrastructure Domain Tests
```powershell
# Run all infrastructure tests
./tests/Run-Tests.ps1 -Domain infrastructure

# Run specific test categories
./tests/Run-Tests.ps1 -Domain infrastructure -Category unit
./tests/Run-Tests.ps1 -Domain infrastructure -Category integration
./tests/Run-Tests.ps1 -Domain infrastructure -Category infrastructure
```

### Run Individual Test Files
```powershell
# Run main infrastructure tests
Invoke-Pester ./tests/domains/infrastructure/Infrastructure.Tests.ps1

# Run with coverage
Invoke-Pester ./tests/domains/infrastructure/Infrastructure.Tests.ps1 -CodeCoverage
```

## Expected Test Results

### Coverage Targets
- **Function Coverage**: 95% (54/57 functions)
- **Line Coverage**: 90%
- **Branch Coverage**: 85%

### Performance Targets
- **Deployment Operations**: < 30 seconds
- **System Monitoring**: < 2 seconds
- **Lab Automation**: < 10 seconds
- **ISO Operations**: < 5 seconds

### Compatibility Targets
- **Windows**: 100% pass rate
- **Linux**: 95% pass rate
- **macOS**: 90% pass rate

## Legacy Module Compatibility

### Migration from LabRunner
The infrastructure domain maintains backward compatibility with LabRunner functions:
- All existing lab automation functions are available
- Legacy script execution workflows are preserved
- Progress tracking integration is maintained

### Migration from OpenTofuProvider
OpenTofu provider functionality is integrated:
- All infrastructure deployment functions are available
- Provider configurations are preserved
- Cloud provider adapters are maintained

### Migration from ISOManager
ISO management functionality is consolidated:
- All ISO management functions are available
- ISO download and customization workflows are preserved
- Storage optimization features are maintained

### Migration from SystemMonitoring
System monitoring functionality is integrated:
- All monitoring functions are available
- Performance monitoring workflows are preserved
- Alert management features are maintained

## Common Test Scenarios

### 1. Infrastructure Deployment Testing
```powershell
# Test infrastructure deployment
Initialize-OpenTofuProvider
$deployment = Start-InfrastructureDeployment -ConfigPath "test-config.tf"
$status = Get-DeploymentStatus -DeploymentId $deployment.Id
```

### 2. System Monitoring Testing
```powershell
# Test system monitoring
Start-SystemMonitoring
$performance = Get-SystemPerformance
$alerts = Get-CurrentAlerts
Stop-SystemMonitoring
```

### 3. Lab Automation Testing
```powershell
# Test lab automation
$labConfig = Get-LabConfig -LabName "TestLab"
Start-LabAutomation -Config $labConfig
$status = Get-LabStatus -LabName "TestLab"
```

### 4. ISO Management Testing
```powershell
# Test ISO management
$isoUrl = Get-WindowsISOUrl -Version "Server2022"
Get-ISODownload -Url $isoUrl -OutputPath "./test-iso"
$integrity = Test-ISOIntegrity -ISOPath "./test-iso/server2022.iso"
```

## Special Test Considerations

### Infrastructure Resources
- Tests may require cloud provider credentials for full testing
- Mock providers are used for unit testing
- Integration tests may provision actual infrastructure resources

### Platform Dependencies
- Some functions are platform-specific (Windows, Linux, macOS)
- Cross-platform compatibility is tested where applicable
- Platform detection is used to skip unsupported tests

### Performance Impact
- Infrastructure tests may have longer execution times
- System monitoring tests may affect system performance
- Resource cleanup is critical to prevent test interference

## Troubleshooting

### Common Test Issues
1. **Resource Issues** - Ensure sufficient system resources for testing
2. **Permission Issues** - Verify appropriate permissions for infrastructure operations
3. **Network Issues** - Check network connectivity for download and deployment tests
4. **Platform Issues** - Ensure platform-specific dependencies are available

### Debug Commands
```powershell
# Enable verbose logging
$VerbosePreference = "Continue"

# Check system status
Get-SystemDashboard

# Test OpenTofu installation
Test-OpenTofuInstallation

# Check lab status
Get-LabStatus -LabName "TestLab"
```

## Contributing

### Adding New Tests
1. Follow the existing test structure
2. Consider resource requirements and cleanup
3. Handle platform-specific functionality
4. Test error conditions and edge cases
5. Ensure proper resource cleanup

### Test Guidelines
- Test all function parameters and variations
- Include both positive and negative test cases
- Test error conditions and recovery scenarios
- Verify cross-platform compatibility where applicable
- Test performance and resource usage
- Ensure proper cleanup of test resources
- Handle long-running operations appropriately