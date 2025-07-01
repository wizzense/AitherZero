# AitherZero Test Suite

## Overview

This test suite provides comprehensive coverage for the AitherZero infrastructure automation framework using Pester 5.x.

## Directory Structure

```
tests/
├── Unit/              # Pure unit tests - one file per module function
├── Integration/       # Cross-module integration tests
├── E2E/               # End-to-end scenario tests
├── Performance/       # Performance benchmarks and load tests
├── Fixtures/          # Test data, mocks, and test resources
├── Shared/            # Common test utilities and helpers
├── Coverage/          # Code coverage reports and analysis
├── config/            # Test configuration files
├── helpers/           # Legacy test helpers (being refactored)
├── tools/             # Test generation and analysis tools
└── archive/           # Old test structure (reference only)
```

## Quick Start

### Run All Tests
```powershell
./Run-Tests.ps1
```

### Run Module Tests
```powershell
./Run-Tests.ps1 -Module Logging
```

### Run with Coverage
```powershell
./Run-Tests.ps1 -Coverage
```

### Run Specific Test Type
```powershell
./Run-Tests.ps1 -Type Unit
./Run-Tests.ps1 -Type Integration
./Run-Tests.ps1 -Type E2E
```

## Test Standards

### Unit Tests
- One test file per module file
- Test file naming: `{ModuleName}.{FunctionName}.Tests.ps1`
- Mock all external dependencies
- Test execution time < 100ms per test
- 100% function coverage required

### Integration Tests
- Test module interactions
- Test file naming: `{Feature}.Integration.Tests.ps1`
- Limited mocking (only external systems)
- Test execution time < 10s per test

### E2E Tests
- Complete workflow scenarios
- Test file naming: `{Scenario}.E2E.Tests.ps1`
- No mocking (except external services)
- Test execution time < 60s per test

### Performance Tests
- Benchmark critical operations
- Test file naming: `{Component}.Performance.Tests.ps1`
- Track metrics over time
- Flag regressions automatically

## Coverage Requirements

- **Functions**: 100% coverage required
- **Lines**: 90% minimum coverage
- **Branches**: 80% minimum coverage
- **Modules**: All exported functions must have tests

## Writing Tests

### Test Template
```powershell
#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/ModuleName'
    $script:ModuleName = 'ModuleName'
}

Describe 'ModuleName.FunctionName' {
    BeforeAll {
        Import-Module $script:ModulePath -Force
        # Setup mocks
    }
    
    Context 'Normal Operation' {
        It 'Should perform expected behavior' {
            # Test implementation
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle specific error gracefully' {
            # Error test
        }
    }
}
```

## CI/CD Integration

Tests run automatically on:
- Every pull request
- Pushes to main/develop branches
- Nightly builds
- Release tags

Failed tests block merges and deployments.

## Contributing

1. Write tests for any new functionality
2. Ensure all tests pass before committing
3. Maintain or improve code coverage
4. Follow the test standards above
5. Update this README for significant changes