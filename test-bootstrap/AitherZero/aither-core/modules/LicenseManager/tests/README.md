# LicenseManager Module Tests

This directory contains tests for the LicenseManager module functionality.

## Test Structure

The test suite validates:
- License validation and signature checking
- Feature access control
- Tier-based licensing
- Cache performance
- License hook registration
- Error handling and graceful degradation

## Running Tests

```powershell
# Run all license manager tests
Invoke-Pester -Path ./LicenseManager.Tests.ps1

# Test specific functionality
Invoke-Pester -Path ./LicenseManager.Tests.ps1 -Tag "FeatureAccess"
Invoke-Pester -Path ./LicenseManager.Tests.ps1 -Tag "Validation"
Invoke-Pester -Path ./LicenseManager.Tests.ps1 -Tag "Performance"
```

## Test Categories

- **Unit Tests**: Individual function testing
- **Integration Tests**: Module interaction testing
- **Performance Tests**: Cache and validation performance
- **Security Tests**: License signature validation
- **Compliance Tests**: Tier enforcement validation

## Test Data

Test licenses and feature registries are located in the test data directory. These include:
- Free tier test license
- Professional tier test license  
- Enterprise tier test license
- Invalid license examples
- Test feature registry configurations

## Adding Tests

When extending the LicenseManager module:
1. Add corresponding test cases
2. Include both valid and invalid scenarios
3. Test tier enforcement properly
4. Verify graceful degradation to free tier
5. Test cache behavior where applicable