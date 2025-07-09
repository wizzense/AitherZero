# Configuration Domain Tests

This directory contains tests for the consolidated configuration domain.

## Test Coverage

### ConfigurationCore.Consolidated.Tests.ps1
Tests for core configuration management:
- Configuration store operations
- Environment management
- Hot reload functionality
- Security and validation

### EnvironmentProvider.Consolidated.Tests.ps1
Tests for environment provider (ConfigurationCarousel):
- Environment switching
- Configuration inheritance
- Profile management
- Repository integration

### GitRepositoryProvider.Consolidated.Tests.ps1
Tests for Git repository provider (ConfigurationRepository):
- Repository creation and cloning
- Synchronization operations
- Version control integration
- Conflict resolution

### ValidationProvider.Consolidated.Tests.ps1
Tests for validation provider (ConfigurationManager):
- Configuration validation
- Schema enforcement
- Integrity checking
- Compliance validation

## Test Execution

```powershell
# Run all configuration tests
./tests/Run-Tests.ps1 -Modules @("configuration")

# Run specific configuration test
Invoke-Pester ./tests/domains/configuration/ConfigurationCore.Consolidated.Tests.ps1
```

## Test Dependencies

- AitherCore module import
- Configuration test data
- Mock Git repositories
- Validation schemas