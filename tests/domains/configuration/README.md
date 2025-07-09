# Configuration Domain Tests

This directory contains tests for the Configuration domain, which consolidates configuration management and environment switching functionality.

## Domain Overview

The Configuration domain consolidates the following legacy modules:
- **ConfigurationCore** - Core configuration management
- **ConfigurationCarousel** - Configuration environment switching
- **ConfigurationManager** - Configuration integrity and management
- **ConfigurationRepository** - Git-based configuration repository management

**Total Functions: 36**

## Function Reference

### Security and Validation (4 functions)
- `Test-ConfigurationSecurity` - Validate configuration for security issues
- `Get-ConfigurationHash` - Generate configuration hashes for integrity
- `Validate-Configuration` - Validate configuration structure and values
- `Test-ConfigurationSchema` - Validate configuration against schemas

### Core Configuration Management (11 functions)
- `Initialize-ConfigurationStorePath` - Initialize configuration storage paths
- `Save-ConfigurationStore` - Save configuration store to disk
- `Import-ExistingConfiguration` - Import existing configuration files
- `Invoke-BackupCleanup` - Clean up old configuration backups
- `Initialize-ConfigurationCore` - Initialize core configuration system
- `Initialize-DefaultSchemas` - Set up default configuration schemas
- `Get-ConfigurationStore` - Retrieve configuration store
- `Set-ConfigurationStore` - Update configuration store
- `Get-ModuleConfiguration` - Get module-specific configuration
- `Set-ModuleConfiguration` - Update module configuration
- `Register-ModuleConfiguration` - Register module configurations

### Configuration Carousel (Environment Switching) (12 functions)
- `Initialize-ConfigurationCarousel` - Initialize carousel system
- `Get-ConfigurationRegistry` - Retrieve configuration registry
- `Set-ConfigurationRegistry` - Update configuration registry
- `Switch-ConfigurationSet` - Switch between configuration sets
- `Get-AvailableConfigurations` - List available configurations
- `Add-ConfigurationRepository` - Add configuration repositories
- `Get-CurrentConfiguration` - Get current configuration
- `Backup-CurrentConfiguration` - Backup current configuration
- `Validate-ConfigurationSet` - Validate configuration sets
- `Test-ConfigurationAccessible` - Test configuration accessibility
- `Apply-ConfigurationSet` - Apply configuration sets
- `New-ConfigurationFromTemplate` - Create configurations from templates

### Event System (4 functions)
- `Publish-ConfigurationEvent` - Publish configuration events
- `Subscribe-ConfigurationEvent` - Subscribe to configuration events
- `Unsubscribe-ConfigurationEvent` - Unsubscribe from events
- `Get-ConfigurationEventHistory` - Get event history

### Environment Management (5 functions)
- `New-ConfigurationEnvironment` - Create new environments
- `Get-ConfigurationEnvironment` - Retrieve environment configuration
- `Set-ConfigurationEnvironment` - Update environment configuration
- `Backup-Configuration` - Create configuration backups
- `Restore-Configuration` - Restore configuration from backup

## Test Categories

### Unit Tests
- **Security Tests** - Test security validation and hash generation
- **Core Management Tests** - Test core configuration operations
- **Carousel Tests** - Test environment switching functionality
- **Event System Tests** - Test event publishing and subscription
- **Environment Tests** - Test environment management
- **Schema Tests** - Test configuration schema validation

### Integration Tests
- **End-to-End Configuration Tests** - Test complete configuration workflows
- **Cross-Environment Tests** - Test configuration switching scenarios
- **Repository Integration Tests** - Test Git-based configuration management
- **Hot Reload Tests** - Test configuration hot reloading
- **Multi-User Tests** - Test concurrent configuration access

### Security Tests
- **Configuration Security Tests** - Test security validation
- **Access Control Tests** - Test configuration access permissions
- **Encryption Tests** - Test configuration encryption/decryption
- **Audit Tests** - Test configuration audit logging

## Test Data

### Mock Configurations
- `test-base-config.json` - Base configuration for testing
- `test-dev-config.json` - Development environment configuration
- `test-prod-config.json` - Production environment configuration
- `test-invalid-config.json` - Invalid configuration for error testing

### Test Schemas
- `test-schema.json` - Test configuration schema
- `module-schema.json` - Module configuration schema
- `environment-schema.json` - Environment configuration schema

### Test Repositories
- `test-config-repo/` - Mock configuration repository
- `test-templates/` - Configuration templates for testing

## Test Execution

### Run All Configuration Domain Tests
```powershell
# Run all configuration tests
./tests/Run-Tests.ps1 -Domain configuration

# Run specific test categories
./tests/Run-Tests.ps1 -Domain configuration -Category unit
./tests/Run-Tests.ps1 -Domain configuration -Category integration
./tests/Run-Tests.ps1 -Domain configuration -Category security
```

### Run Individual Test Files
```powershell
# Run main configuration tests
Invoke-Pester ./tests/domains/configuration/Configuration.Tests.ps1

# Run with coverage
Invoke-Pester ./tests/domains/configuration/Configuration.Tests.ps1 -CodeCoverage
```

## Test Structure

```powershell
Describe "Configuration Domain Tests" {
    BeforeAll {
        # Import AitherCore for domain functions
        Import-Module ./aither-core/AitherCore.psm1 -Force
        
        # Initialize test environment
        $testContext = Initialize-TestEnvironment -Domain "configuration"
        
        # Set up test configuration files
        $testConfigPath = Join-Path $testContext.TempPath "test-configs"
        New-Item -ItemType Directory -Path $testConfigPath -Force
    }
    
    Context "Security and Validation" {
        It "Should validate configuration security" {
            # Test Test-ConfigurationSecurity
        }
        
        It "Should generate configuration hashes" {
            # Test Get-ConfigurationHash
        }
        
        It "Should validate configuration structure" {
            # Test Validate-Configuration
        }
        
        It "Should validate against schemas" {
            # Test Test-ConfigurationSchema
        }
    }
    
    Context "Core Configuration Management" {
        It "Should initialize configuration core" {
            # Test Initialize-ConfigurationCore
        }
        
        It "Should manage configuration store" {
            # Test Get-ConfigurationStore, Set-ConfigurationStore
        }
        
        It "Should handle module configurations" {
            # Test Get-ModuleConfiguration, Set-ModuleConfiguration
        }
    }
    
    Context "Configuration Carousel" {
        It "Should initialize carousel system" {
            # Test Initialize-ConfigurationCarousel
        }
        
        It "Should switch configuration sets" {
            # Test Switch-ConfigurationSet
        }
        
        It "Should manage configuration repositories" {
            # Test Add-ConfigurationRepository
        }
    }
    
    Context "Event System" {
        It "Should publish and subscribe to events" {
            # Test Publish-ConfigurationEvent, Subscribe-ConfigurationEvent
        }
        
        It "Should track event history" {
            # Test Get-ConfigurationEventHistory
        }
    }
    
    Context "Environment Management" {
        It "Should create and manage environments" {
            # Test New-ConfigurationEnvironment
        }
        
        It "Should backup and restore configurations" {
            # Test Backup-Configuration, Restore-Configuration
        }
    }
    
    AfterAll {
        # Clean up test environment
        Remove-TestEnvironment -Context $testContext
    }
}
```

## Expected Test Results

### Coverage Targets
- **Function Coverage**: 95% (34/36 functions)
- **Line Coverage**: 90%
- **Branch Coverage**: 85%

### Performance Targets
- **Configuration Load**: < 500ms
- **Environment Switch**: < 1 second
- **Configuration Validation**: < 200ms
- **Event Processing**: < 100ms

### Compatibility Targets
- **Windows**: 100% pass rate
- **Linux**: 100% pass rate
- **macOS**: 100% pass rate

## Legacy Module Compatibility

### Migration from ConfigurationCore
The configuration domain maintains backward compatibility with ConfigurationCore functions:
- All existing ConfigurationCore functions are available
- Legacy function names are preserved
- Configuration file formats remain compatible

### Migration from ConfigurationCarousel
Carousel functionality is integrated into the configuration domain:
- Environment switching capabilities
- Configuration repository management
- Multi-environment support

### Migration from ConfigurationManager
Configuration management functionality is consolidated:
- Configuration integrity checking
- Backup and restore operations
- Configuration validation

### Migration from ConfigurationRepository
Repository functionality is integrated:
- Git-based configuration management
- Configuration synchronization
- Template-based configuration creation

## Common Test Scenarios

### 1. Configuration Lifecycle Testing
```powershell
# Test complete configuration lifecycle
$config = Initialize-ConfigurationCore
Set-ModuleConfiguration -ModuleName "TestModule" -Configuration @{ Setting = "Value" }
$hash = Get-ConfigurationHash -Configuration $config
Validate-Configuration -Configuration $config
```

### 2. Environment Switching Testing
```powershell
# Test environment switching
Initialize-ConfigurationCarousel
$environments = Get-AvailableConfigurations
Switch-ConfigurationSet -ConfigurationName "dev" -Environment "development"
$current = Get-CurrentConfiguration
```

### 3. Event System Testing
```powershell
# Test event system
Subscribe-ConfigurationEvent -EventName "ConfigurationChanged" -Action { Write-Host "Config changed" }
Publish-ConfigurationEvent -EventName "ConfigurationChanged" -Data @{ Change = "Test" }
$history = Get-ConfigurationEventHistory
```

### 4. Security Testing
```powershell
# Test security validation
$securityResult = Test-ConfigurationSecurity -Configuration $testConfig
$schema = Test-ConfigurationSchema -Configuration $testConfig -Schema $testSchema
```

## Special Test Considerations

### Configuration File Handling
- Test configuration file locking and concurrent access
- Test configuration file corruption recovery
- Test configuration file format migration

### Environment Isolation
- Test environment isolation and separation
- Test environment-specific configuration overrides
- Test environment switching without data loss

### Performance Testing
- Test configuration loading performance with large files
- Test memory usage during configuration operations
- Test concurrent configuration access performance

### Security Testing
- Test configuration encryption and decryption
- Test sensitive data handling in configurations
- Test configuration access control

## Troubleshooting

### Common Test Issues
1. **File Permission Issues** - Ensure test has write access to configuration directories
2. **Configuration Lock Issues** - Ensure configuration files are not locked by other processes
3. **Schema Validation Issues** - Verify test schemas are properly formatted
4. **Environment Issues** - Check environment variable setup for tests

### Debug Commands
```powershell
# Enable verbose logging
$VerbosePreference = "Continue"

# Check configuration store status
Get-ConfigurationStore -IncludeMetadata

# Validate configuration
Validate-Configuration -Configuration $config -Verbose

# Check event history
Get-ConfigurationEventHistory -Last 10
```

## Contributing

### Adding New Tests
1. Follow the existing test structure
2. Add appropriate test configuration files
3. Update test documentation
4. Ensure cross-platform compatibility
5. Test security implications

### Test Guidelines
- Test all function parameters and variations
- Include both positive and negative test cases
- Test error conditions and edge cases
- Verify cross-platform compatibility
- Test performance and resource usage
- Test security and access control
- Test concurrent access scenarios