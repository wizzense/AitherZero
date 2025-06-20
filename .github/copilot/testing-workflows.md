# Testing Workflows - GitHub Copilot Instructions

This guide provides patterns for running comprehensive tests in the Aitherium Infrastructure Automation project.

## Quick Test Commands

### 1. Run Bulletproof Test Suite

```powershell
# Quick smoke tests
pwsh ./tests/Run-BulletproofTests.ps1 -TestSuite Quick -LogLevel Normal

# Full comprehensive testing
pwsh ./tests/Run-BulletproofTests.ps1 -TestSuite All -LogLevel Detailed -GenerateReport
```

### 2. Non-Interactive Mode Validation

```powershell
# Test non-interactive core runner behavior
pwsh ./test-noninteractive-fix.ps1 -TestMode All

# Specific test types
pwsh ./test-noninteractive-fix.ps1 -TestMode Basic
pwsh ./test-noninteractive-fix.ps1 -TestMode Auto
```

### 3. Intelligent Test Discovery

```powershell
# Discover and run all tests automatically
pwsh ./tests/Invoke-IntelligentTests.ps1 -TestType All -Severity Comprehensive

# Module-specific testing
pwsh ./tests/Invoke-IntelligentTests.ps1 -TestType Module -ModuleName PatchManager
```

## VS Code Tasks Integration

Use these tasks from Command Palette (Ctrl+Shift+P → "Tasks: Run Task"):

- **Tests: Run Bulletproof Suite** - Comprehensive testing with report generation
- **Tests: Run Non-Interactive Validation** - Validate core runner behavior
- **Tests: Intelligent Test Discovery** - Auto-discover and run relevant tests
- **Run All Pester Tests** - Standard Pester test execution
- **Run Specific Module Tests** - Test individual modules

## Test Categories

### Bulletproof Testing
- **All**: Complete system validation (30+ minutes)
- **Core**: Core functionality tests (10 minutes)
- **Modules**: Module-specific tests (15 minutes)
- **Integration**: Cross-component testing (20 minutes)
- **Performance**: Performance benchmarks (25 minutes)
- **Quick**: Essential smoke tests (5 minutes)
- **NonInteractive**: Non-interactive mode validation (3 minutes)

### Test Types
- **Unit**: Individual function/module testing
- **Integration**: Component interaction testing
- **Smoke**: Basic functionality verification
- **Module**: Comprehensive module validation
- **Script**: Script-level testing

## Common Testing Patterns

### Pre-Commit Testing

```powershell
# Quick validation before commit
pwsh ./tests/Run-BulletproofTests.ps1 -TestSuite Quick -CI

# Full validation for important changes
pwsh ./tests/Run-BulletproofTests.ps1 -TestSuite Core -GenerateReport
```

### Module Development Testing

```powershell
# Test specific module during development
pwsh ./tests/Invoke-IntelligentTests.ps1 -TestType Module -ModuleName "YourModule"

# Run module-specific Pester tests
Invoke-Pester -Path "tests/unit/modules/YourModule" -Output Detailed
```

### CI/CD Integration

```powershell
# CI-optimized test run
pwsh ./tests/Run-BulletproofTests.ps1 -TestSuite All -CI -OutputPath "./test-results"

# Generate coverage reports
pwsh ./tests/Run-BulletproofTests.ps1 -TestSuite Modules -GenerateReport -CodeCoverage
```

## Test Output and Logging

### Log File Locations
Tests automatically generate log files in these locations:

```
tests/results/bulletproof/            # Bulletproof test results
tests/results/TestResults.xml         # Standard Pester results
tests/results/coverage.xml            # Code coverage reports
logs/                                 # General application logs
```

### Log Level Control

```powershell
# Silent - minimal output
-LogLevel Silent

# Normal - standard output
-LogLevel Normal

# Detailed - comprehensive logging
-LogLevel Detailed

# Verbose - debug-level output
-LogLevel Verbose
```

## Debugging Failed Tests

### View Test Results

```powershell
# Check latest test results
Get-Content "tests/results/bulletproof/latest-results.xml" | ConvertFrom-Json

# View failed test details
pwsh -Command "Import-Module Pester; Get-PesterResult -Path 'tests/results/TestResults.xml'"
```

### Isolate Failing Tests

```powershell
# Run specific failing test
Invoke-Pester -Path "tests/unit/modules/SpecificModule" -TestName "Failing Test Name"

# Debug with detailed output
Invoke-Pester -Path "tests/unit/modules/SpecificModule" -Output Diagnostic
```

## Performance Testing

### Benchmark Core Operations

```powershell
# Performance-focused test suite
pwsh ./tests/Run-BulletproofTests.ps1 -TestSuite Performance -LogLevel Detailed

# Benchmark specific operations
Measure-Command { pwsh ./core-runner/core_app/core-runner.ps1 -NonInteractive -Auto -WhatIf }
```

### Memory and Resource Testing

```powershell
# Monitor resource usage during tests
pwsh ./tests/Invoke-IntelligentTests.ps1 -TestType All -Severity Comprehensive | Tee-Object -FilePath "resource-usage.log"
```

## Best Practices

1. **Run Quick tests frequently** during development
2. **Use CI mode** for automated environments
3. **Generate reports** for important changes
4. **Check log files** for detailed debugging information
5. **Test non-interactive mode** for automation scenarios
6. **Validate module interactions** with integration tests
7. **Monitor performance** with benchmark tests

## Troubleshooting

### Common Issues

```powershell
# Fix module import issues
Import-Module ./core-runner/modules/TestingFramework -Force

# Clear test cache
Remove-Item tests/results/* -Recurse -Force

# Reset test environment
pwsh ./tests/Setup-TestingFramework.ps1 -RegenerateAll
```

### Environment Validation

```powershell
# Validate test environment
pwsh ./tests/Run-BulletproofTests.ps1 -TestSuite Quick -LogLevel Verbose

# Check PowerShell version compatibility
$PSVersionTable
```
