# AitherZero Test Suite

This directory contains all tests for the AitherZero project, organized by domain and test type.

## Test Structure

```
tests/
├── domains/          # Domain-specific unit tests
│   ├── infrastructure/
│   ├── configuration/
│   ├── utilities/
│   ├── security/
│   ├── experience/
│   └── automation/
├── integration/      # Integration tests
├── unit/            # Cross-domain unit tests
├── performance/     # Performance tests
└── README.md        # This file
```

## Running Tests

### All Tests
```powershell
Invoke-Pester -Path ./tests
```

### Domain-Specific Tests
```powershell
# Test a specific domain
Invoke-Pester -Path ./tests/domains/infrastructure

# Test a specific function
Invoke-Pester -Path ./tests/domains/infrastructure -TestName "New-LabVM"
```

### Integration Tests
```powershell
Invoke-Pester -Path ./tests/integration
```

### Performance Tests
```powershell
Invoke-Pester -Path ./tests/performance
```

## Test Coverage

Generate code coverage reports:
```powershell
Invoke-Pester -Path ./tests -CodeCoverage ./domains/**/*.psm1 -CodeCoverageOutputFile coverage.xml
```

## Writing Tests

### Naming Convention
- Test files: `<ModuleName>.Tests.ps1`
- Test names: Should describe what is being tested
- Use descriptive Context and It blocks

### Example Test
```powershell
BeforeAll {
    Import-Module ./AitherZeroCore.psm1 -Force
}

Describe "Configuration Module Tests" {
    Context "Get-Configuration" {
        It "Should return default configuration when no file exists" {
            $config = Get-Configuration
            $config | Should -Not -BeNullOrEmpty
            $config.Core.Name | Should -Be "AitherZero"
        }
        
        It "Should return specific section when requested" {
            $logging = Get-Configuration -Section "Logging"
            $logging | Should -Not -BeNullOrEmpty
            $logging.Level | Should -Be "Information"
        }
    }
}
```

## CI/CD Integration

Tests are automatically run on:
- Every commit (via GitHub Actions)
- Pull request creation and updates
- Nightly scheduled runs

## Test Categories

### Unit Tests
- Test individual functions in isolation
- Mock external dependencies
- Fast execution
- High code coverage

### Integration Tests
- Test interactions between modules
- Test with real dependencies
- Medium execution time
- End-to-end scenarios

### Performance Tests
- Measure execution time
- Monitor resource usage
- Identify bottlenecks
- Establish baselines

## Best Practices

1. **Write tests first** - Follow TDD principles
2. **Keep tests isolated** - Each test should be independent
3. **Use meaningful names** - Test names should describe behavior
4. **Mock external dependencies** - For unit tests
5. **Clean up after tests** - Remove test artifacts
6. **Test edge cases** - Include error conditions
7. **Maintain test data** - Use consistent test fixtures