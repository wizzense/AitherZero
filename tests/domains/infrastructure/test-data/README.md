# Infrastructure Domain Test Data

This directory contains test data files and configurations for Infrastructure domain testing.

## Overview

The test data in this directory supports comprehensive testing of Infrastructure domain functionality including:

- **LabRunner**: Lab automation and script execution testing
- **OpenTofuProvider**: Infrastructure deployment testing
- **ISOManager**: ISO management and customization testing
- **SystemMonitoring**: System performance monitoring testing

## Directory Structure

```
test-data/
├── lab-configurations/          # Lab automation test configurations
├── opentofu-templates/         # OpenTofu template files for testing
├── iso-files/                  # ISO file samples and test data
├── monitoring-data/            # System monitoring test data
├── deployment-configs/         # Deployment configuration files
└── infrastructure-templates/   # Infrastructure template files
```

## Test Data Categories

### Lab Configurations
- **Basic Lab Configs**: Simple lab setup configurations
- **Complex Lab Configs**: Multi-node lab configurations
- **Error Scenarios**: Invalid configurations for error testing
- **Performance Configs**: Configurations for performance testing

### OpenTofu Templates
- **VM Templates**: Virtual machine deployment templates
- **Network Templates**: Network configuration templates
- **Storage Templates**: Storage configuration templates
- **Security Templates**: Security configuration templates

### ISO Files
- **Sample ISOs**: Small sample ISO files for testing
- **Custom ISOs**: Custom ISO configurations
- **Validation Data**: ISO validation test data
- **Performance Data**: ISO performance benchmarks

### Monitoring Data
- **System Metrics**: Sample system performance metrics
- **Alert Data**: Alert configuration and test data
- **Dashboard Data**: Dashboard configuration files
- **Historical Data**: Historical monitoring data samples

## File Formats

### Configuration Files
- **JSON**: Configuration data in JSON format
- **YAML**: YAML configuration files
- **PowerShell**: PowerShell configuration scripts
- **XML**: XML configuration data

### Template Files
- **OpenTofu**: `.tf` template files
- **PowerShell**: `.ps1` script templates
- **JSON**: JSON template files
- **YAML**: YAML template files

### Data Files
- **CSV**: Performance and monitoring data
- **JSON**: Structured test data
- **XML**: Configuration and metadata
- **Binary**: Sample files and ISOs

## Usage Guidelines

### Test Data Loading
```powershell
# Load infrastructure test data
$testData = Import-TestData -Domain "infrastructure"

# Load specific test category
$labData = Import-TestData -Domain "infrastructure" -Category "lab-configurations"
```

### Test Data Validation
```powershell
# Validate test data integrity
Test-TestDataIntegrity -Domain "infrastructure"

# Validate specific test files
Test-TestFile -Path "lab-configurations/basic-lab.json"
```

### Test Data Cleanup
```powershell
# Clean up test data after tests
Remove-TestData -Domain "infrastructure" -Temporary

# Reset test data to original state
Reset-TestData -Domain "infrastructure"
```

## Test Data Files

### Lab Configurations
- `basic-lab.json`: Basic single-node lab configuration
- `multi-node-lab.json`: Multi-node lab configuration
- `error-lab.json`: Invalid configuration for error testing
- `performance-lab.json`: Performance testing configuration

### OpenTofu Templates
- `vm-deployment.tf`: Virtual machine deployment template
- `network-config.tf`: Network configuration template
- `storage-config.tf`: Storage configuration template
- `security-config.tf`: Security configuration template

### ISO Test Files
- `sample-small.iso`: Small ISO file for basic testing
- `sample-custom.iso`: Custom ISO with modifications
- `validation-data.xml`: ISO validation metadata
- `performance-benchmark.json`: Performance benchmark data

### Monitoring Data
- `system-metrics.csv`: Sample system performance metrics
- `alert-config.json`: Alert configuration data
- `dashboard-config.yaml`: Dashboard configuration
- `historical-data.json`: Historical monitoring data

## Data Generation

### Automated Data Generation
```powershell
# Generate test data for infrastructure domain
Generate-TestData -Domain "infrastructure" -Type "all"

# Generate specific test data category
Generate-TestData -Domain "infrastructure" -Type "lab-configurations"
```

### Custom Data Creation
```powershell
# Create custom test configuration
$customConfig = New-TestConfiguration -Type "lab" -Name "custom-lab"

# Add custom test data
Add-TestData -Configuration $customConfig -Domain "infrastructure"
```

## Data Validation

### Validation Rules
- All JSON files must be valid JSON
- All YAML files must be valid YAML
- Configuration files must contain required fields
- Template files must be syntactically correct

### Validation Scripts
```powershell
# Run data validation
./scripts/Validate-TestData.ps1 -Domain "infrastructure"

# Validate specific file types
./scripts/Validate-TestData.ps1 -Domain "infrastructure" -FileType "json"
```

## Security Considerations

### Data Security
- No production data in test files
- No real credentials or secrets
- Sanitized data for security testing
- Secure handling of test data

### Access Control
- Test data access through proper APIs
- No direct file system access in tests
- Controlled test data distribution
- Audit trail for test data usage

## Maintenance

### Data Updates
- Regular updates to test data
- Version control for test data changes
- Documentation of data changes
- Impact assessment for updates

### Data Cleanup
- Regular cleanup of temporary data
- Archival of historical test data
- Removal of obsolete test data
- Optimization of data storage

## Best Practices

### Data Organization
- Clear naming conventions
- Logical directory structure
- Comprehensive documentation
- Version control integration

### Data Quality
- Regular validation of test data
- Automated data quality checks
- Consistent data formats
- Error handling for invalid data

### Performance Optimization
- Efficient data loading
- Caching of frequently used data
- Lazy loading for large datasets
- Memory management for test data

## Related Documentation

- [Infrastructure Domain Tests](../README.md)
- [Test Data Management](../../shared/test-data-management.md)
- [Testing Framework](../../README.md)
- [Infrastructure Domain Documentation](../../../aither-core/domains/infrastructure/README.md)