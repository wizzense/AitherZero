# Utilities Domain Tests

This directory contains tests for the Utilities domain, which consolidates utility services and maintenance functionality.

## Domain Overview

The Utilities domain consolidates the following legacy modules:
- **SemanticVersioning** - Semantic versioning utilities
- **LicenseManager** - License management and feature access control
- **RepoSync** - Repository synchronization utilities
- **UnifiedMaintenance** - Unified maintenance operations
- **UtilityServices** - Common utility services
- **PSScriptAnalyzerIntegration** - PowerShell code analysis automation

**Total Functions: 24**

## Function Reference

### Semantic Versioning (8 functions)
- `Get-NextSemanticVersion` - Calculate next semantic version based on changes
- `ConvertFrom-ConventionalCommits` - Convert conventional commits to version increments
- `Test-SemanticVersion` - Validate semantic version format
- `Compare-SemanticVersions` - Compare two semantic versions
- `Parse-SemanticVersion` - Parse semantic version string into components
- `Get-CurrentVersion` - Get current version from project files
- `Get-CommitRange` - Get commit range for version calculation
- `Calculate-NextVersion` - Calculate next version based on commit history

### License Management (3 functions)
- `Get-LicenseStatus` - Get current license status and information
- `Test-FeatureAccess` - Test access to specific features
- `Get-AvailableFeatures` - Get list of available features based on license

### Repository Synchronization (2 functions)
- `Sync-ToAitherLab` - Synchronize repository to AitherLab
- `Get-RepoSyncStatus` - Get repository synchronization status

### Unified Maintenance (3 functions)
- `Invoke-UnifiedMaintenance` - Perform unified maintenance operations
- `Get-UtilityServiceStatus` - Get status of utility services
- `Test-UtilityIntegration` - Test utility service integration

### PowerShell Script Analyzer (1 function)
- `Get-AnalysisStatus` - Get PowerShell script analysis status

### Utility Services (7 functions)
- Various utility service functions consolidated from UtilityServices module
- Cross-platform utility operations
- Common service management functions
- Utility integration and coordination

## Test Categories

### Unit Tests
- **Semantic Versioning Tests** - Test version calculation and comparison
- **License Management Tests** - Test license validation and feature access
- **Repository Sync Tests** - Test repository synchronization
- **Maintenance Tests** - Test maintenance operations
- **Utility Service Tests** - Test utility service operations
- **Script Analysis Tests** - Test PowerShell script analysis

### Integration Tests
- **End-to-End Utility Tests** - Test complete utility workflows
- **Cross-Domain Tests** - Test utility service integration with other domains
- **Service Integration Tests** - Test utility service interactions
- **Maintenance Integration Tests** - Test maintenance operation integration

### Service Tests
- **Service Health Tests** - Test utility service health and availability
- **Performance Tests** - Test utility service performance
- **Reliability Tests** - Test utility service reliability
- **Scalability Tests** - Test utility service scalability

## Test Execution

### Run All Utilities Domain Tests
```powershell
# Run all utilities tests
./tests/Run-Tests.ps1 -Domain utilities

# Run specific test categories
./tests/Run-Tests.ps1 -Domain utilities -Category unit
./tests/Run-Tests.ps1 -Domain utilities -Category integration
./tests/Run-Tests.ps1 -Domain utilities -Category service
```

### Run Individual Test Files
```powershell
# Run main utilities tests
Invoke-Pester ./tests/domains/utilities/Utilities.Tests.ps1

# Run with coverage
Invoke-Pester ./tests/domains/utilities/Utilities.Tests.ps1 -CodeCoverage
```

## Expected Test Results

### Coverage Targets
- **Function Coverage**: 95% (23/24 functions)
- **Line Coverage**: 90%
- **Branch Coverage**: 85%

### Performance Targets
- **Version Operations**: < 100ms
- **License Operations**: < 200ms
- **Sync Operations**: < 5 seconds
- **Maintenance Operations**: < 10 seconds

### Compatibility Targets
- **Windows**: 100% pass rate
- **Linux**: 100% pass rate
- **macOS**: 100% pass rate

## Legacy Module Compatibility

### Migration from SemanticVersioning
The utilities domain maintains backward compatibility with SemanticVersioning functions:
- All existing version calculation functions are available
- Version parsing and comparison logic is preserved
- Conventional commit integration is maintained

### Migration from LicenseManager
License management functionality is integrated:
- All license validation functions are available
- Feature access control is preserved
- License status reporting is maintained

### Migration from RepoSync
Repository synchronization functionality is consolidated:
- All synchronization functions are available
- Sync status reporting is preserved
- Integration with AitherLab is maintained

### Migration from UnifiedMaintenance
Maintenance functionality is integrated:
- All maintenance operations are available
- Service status reporting is preserved
- Integration with other domains is maintained

### Migration from UtilityServices
Utility service functionality is consolidated:
- All utility service functions are available
- Service management capabilities are preserved
- Cross-platform compatibility is maintained

### Migration from PSScriptAnalyzerIntegration
Script analysis functionality is integrated:
- PowerShell script analysis is available
- Analysis status reporting is preserved
- Integration with development workflows is maintained

## Common Test Scenarios

### 1. Semantic Versioning Testing
```powershell
# Test version calculation
$currentVersion = Get-CurrentVersion
$commits = Get-CommitRange -From $currentVersion
$nextVersion = Calculate-NextVersion -Commits $commits
Test-SemanticVersion -Version $nextVersion
```

### 2. License Management Testing
```powershell
# Test license validation
$licenseStatus = Get-LicenseStatus
$features = Get-AvailableFeatures
$hasAccess = Test-FeatureAccess -FeatureName "AdvancedReporting"
```

### 3. Repository Synchronization Testing
```powershell
# Test repository sync
$syncStatus = Get-RepoSyncStatus
$syncResult = Sync-ToAitherLab -Force
```

### 4. Maintenance Operations Testing
```powershell
# Test maintenance operations
$serviceStatus = Get-UtilityServiceStatus
$maintenanceResult = Invoke-UnifiedMaintenance -Operations @("cleanup", "update")
Test-UtilityIntegration
```

## Special Test Considerations

### Version Control Integration
- Tests may require Git repository access
- Version calculation tests use mock commit data
- Integration tests may require actual repository history

### License Validation
- License tests use mock license data
- Feature access tests validate against test configurations
- Integration tests may require actual license validation

### External Service Dependencies
- Repository sync tests may require network access
- Service integration tests may require external services
- Mock implementations are used for isolated testing

## Troubleshooting

### Common Test Issues
1. **Version Issues** - Ensure Git repository is properly initialized
2. **License Issues** - Check license configuration and test data
3. **Sync Issues** - Verify network connectivity for sync operations
4. **Service Issues** - Ensure utility services are available and responding

### Debug Commands
```powershell
# Enable verbose logging
$VerbosePreference = "Continue"

# Check version status
Get-CurrentVersion

# Check license status
Get-LicenseStatus

# Check sync status
Get-RepoSyncStatus

# Check service status
Get-UtilityServiceStatus
```

## Contributing

### Adding New Tests
1. Follow the existing test structure
2. Consider external service dependencies
3. Handle network and service availability
4. Test error conditions and edge cases
5. Ensure proper cleanup of test resources

### Test Guidelines
- Test all function parameters and variations
- Include both positive and negative test cases
- Test error conditions and recovery scenarios
- Verify cross-platform compatibility
- Test performance and resource usage
- Handle external service dependencies appropriately
- Test integration with other domains
- Ensure proper mock implementations for isolated testing