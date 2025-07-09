# Domain-Based Testing Structure

This directory contains domain-specific tests for the consolidated AitherCore architecture.

## Test Organization

### Domain Tests
Each domain has its own test directory with comprehensive test coverage:

```
domains/
├── infrastructure/          # Infrastructure domain tests
│   ├── LabRunner.Consolidated.Tests.ps1
│   ├── OpenTofuProvider.Consolidated.Tests.ps1
│   ├── ISOManager.Consolidated.Tests.ps1
│   └── SystemMonitoring.Consolidated.Tests.ps1
├── configuration/          # Configuration domain tests
│   ├── ConfigurationCore.Consolidated.Tests.ps1
│   ├── EnvironmentProvider.Consolidated.Tests.ps1
│   ├── GitRepositoryProvider.Consolidated.Tests.ps1
│   └── ValidationProvider.Consolidated.Tests.ps1
├── security/              # Security domain tests
│   ├── SecureCredentials.Consolidated.Tests.ps1
│   └── SecurityAutomation.Consolidated.Tests.ps1
├── automation/            # Automation domain tests
│   └── ScriptManager.Consolidated.Tests.ps1
├── experience/            # Experience domain tests
│   ├── SetupWizard.Consolidated.Tests.ps1
│   └── StartupExperience.Consolidated.Tests.ps1
└── utilities/             # Utilities domain tests
    └── UtilityServices.Consolidated.Tests.ps1
```

## Test Types

### Unit Tests
- Test individual functions within consolidated domains
- Mock external dependencies
- Fast execution (<1 second per test)

### Integration Tests
- Test interactions between domains
- Test end-to-end workflows
- Located in `tests/integration/`

### Consolidated Tests
- Test AitherCore orchestration
- Test service registry functionality
- Located in `tests/consolidated/`

## Test Naming Convention

```
[ModuleName].Consolidated.Tests.ps1
```

This naming convention:
- Identifies the original module being tested
- Indicates it's testing consolidated functionality
- Maintains compatibility with existing test discovery

## Test Execution

### Run Domain Tests
```powershell
# Run all domain tests
./tests/Run-Tests.ps1 -Distributed

# Run specific domain tests
./tests/Run-Tests.ps1 -Modules @("infrastructure", "configuration")

# Run with consolidated testing
./tests/Run-Tests.ps1 -All -Consolidated
```

### Test Discovery
The test runner automatically discovers:
- Domain-specific tests in `tests/domains/`
- Integration tests in `tests/integration/`
- Consolidated tests in `tests/consolidated/`

## Test Isolation

### Domain Isolation
Each domain test runs in isolation:
- Separate PowerShell runspaces
- Isolated module imports
- Clean state between tests

### Mock Framework
Consolidated tests use enhanced mocking:
- Domain-specific mock objects
- Cross-domain interaction mocks
- Performance-aware mocking

## Test Coverage

### Coverage Requirements
- **Domain Tests**: 95% function coverage
- **Integration Tests**: 90% workflow coverage
- **Consolidated Tests**: 100% orchestration coverage

### Coverage Reporting
- Domain-specific coverage reports
- Consolidated coverage dashboard
- Trend analysis and improvement tracking

## Best Practices

### Test Structure
```powershell
Describe "ModuleName Consolidated Tests" {
    BeforeAll {
        # Import consolidated AitherCore
        Import-Module ./aither-core/AitherCore.psm1 -Force
        
        # Initialize test environment
        $testContext = Initialize-TestEnvironment -Domain "DomainName"
    }
    
    Context "Domain Functionality" {
        It "Should consolidate module functions" {
            # Test consolidated functionality
        }
        
        It "Should maintain backward compatibility" {
            # Test backward compatibility
        }
    }
    
    AfterAll {
        # Clean up test environment
        Remove-TestEnvironment -Context $testContext
    }
}
```

### Test Data Management
- Use domain-specific test data
- Clean test data between runs
- Shared test data in `tests/testdata/`

### Performance Testing
- Include performance benchmarks
- Test consolidation impact
- Monitor resource usage

## Migration from Module Tests

### Existing Tests
Original module tests are preserved and enhanced:
- Maintain existing test logic
- Add consolidation-specific tests
- Update test infrastructure

### Test Migration
- Copy existing test to domain directory
- Update imports for consolidated architecture
- Add consolidation validation tests
- Update test data paths

## Continuous Integration

### CI Pipeline
- Run domain tests in parallel
- Generate consolidated test reports
- Fail fast on critical domain failures

### Test Reporting
- Domain-specific test results
- Consolidated test dashboard
- Performance impact analysis