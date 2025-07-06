# AitherZero Bulletproof Testing Workflow

You are assisting with testing in the AitherZero Infrastructure Automation project. This project uses a sophisticated bulletproof testing system with multiple validation levels.

## Testing Architecture

**Primary Testing System**: Bulletproof Validation Framework
**Test Levels**: Quick (30s) → Standard (2-5min) → Complete (10-15min)
**Coverage**: Unit tests, integration tests, module validation, core runner testing
**Framework**: Pester 5.0+ with custom wrappers and automated reporting

## Current Testing Commands

### Bulletproof Validation (Primary)

```powershell
# Core validation - Use for rapid feedback during development
pwsh -File "tests/Run-Tests.ps1"

# Setup validation - Use for setup/installation testing
pwsh -File "tests/Run-Tests.ps1" -Setup

# All tests - Use for comprehensive validation
pwsh -File "tests/Run-Tests.ps1" -All

# CI/CD mode with fail-fast
pwsh -File "tests/Run-Tests.ps1" -All -CI
```

### Core Runner Testing

```powershell
# Test non-interactive modes
pwsh -File "./test-noninteractive-fix.ps1" -TestMode "All"

# Test specific modes
pwsh -File "./test-noninteractive-fix.ps1" -TestMode "Auto"
pwsh -File "./test-noninteractive-fix.ps1" -TestMode "Scripts"
```

### Module-Specific Testing

```powershell
# Test specific module
Invoke-Pester -Path "tests/unit/modules/ModuleName" -Output Detailed

# Test all modules with coverage
pwsh -File "./tests/Run-AllModuleTests.ps1" -Parallel -OutputFormat "NUnitXml"
```

## VS Code Testing Tasks

### Quick Access (Ctrl+Shift+P → Tasks: Run Task)

- **🚀 Bulletproof Validation - Quick**: Fast 30-second validation
- **🔥 Bulletproof Validation - Standard**: Comprehensive 2-5 minute validation
- **🎯 Bulletproof Validation - Complete**: Full 10-15 minute validation
- **Tests: Run Non-Interactive Validation**: Core runner testing
- **Tests: Intelligent Test Discovery**: Smart test selection

### Advanced Testing Tasks

- **⚡ Bulletproof Validation - Quick (Fail-Fast)**: Stop on first failure
- **🔧 Bulletproof Validation - CI Mode**: CI-optimized execution
- **📊 Bulletproof Validation - Performance Focus**: Parallel execution

## Test Development Patterns

### Standard Test Structure

```powershell
BeforeAll {
    # Import shared utilities
    . "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot

    # Import module under test
    Import-Module "$projectRoot/aither-core/modules/ModuleName" -Force

    # Mock external dependencies
    Mock Invoke-ExternalCommand { return @{ Success = $true } }
}

Describe "ModuleName Core Functionality" -Tags @('Unit', 'ModuleName', 'Fast') {
    Context "When function is called with valid parameters" {
        It "Should return expected result" {
            # Test implementation
            $result = Invoke-ModuleFunction -Parameter "value"
            $result | Should -Be "expected"
        }
    }
}
```

### Integration Test Pattern

```powershell
Describe "Cross-Module Integration" -Tags @('Integration', 'Slow') {
    BeforeEach {
        # Setup integration test environment
        $tempDir = New-TemporaryDirectory
    }

    AfterEach {
        # Cleanup
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "Should integrate with dependent modules" {
        # Integration test
    }
}
```

## Testing Best Practices

### Test Tagging Strategy

- **Fast**: Tests that run under 1 second
- **Slow**: Tests that take longer than 1 second
- **Unit**: Isolated unit tests
- **Integration**: Cross-module or external dependency tests
- **ModuleName**: Tests specific to a module
- **CrossPlatform**: Tests that validate cross-platform behavior

### Mock Strategy

```powershell
# Mock external commands
Mock git { return "mocked output" }

# Mock file system operations
Mock Test-Path { return $true }
Mock Get-Content { return "mocked content" }

# Mock module functions
Mock Write-CustomLog { }
```

## Continuous Integration Patterns

### Pre-Commit Validation

```powershell
# Minimal validation for fast feedback
pwsh -File "tests/Run-Tests.ps1" -CI
```

### Pre-Push Validation

```powershell
# Comprehensive validation before push
pwsh -File "tests/Run-Tests.ps1" -All -CI
```

### Release Validation

```powershell
# Complete validation for releases
pwsh -File "tests/Run-Tests.ps1" -All
```

## Test Result Analysis

### Log Locations

- **Test Results**: `tests/results/TestResults.xml`
- **Coverage Reports**: `tests/results/coverage.xml`
- **Bulletproof Logs**: `tests/results/bulletproof-validation/`
- **Module Test Results**: `tests/results/module-tests/`

### Result Validation

```powershell
# Check test results programmatically
$testResults = Import-Clixml "tests/results/TestResults.xml"
if ($testResults.Failed.Count -gt 0) {
    Write-Error "Tests failed: $($testResults.Failed.Count) failures"
    exit 1
}
```

## Common Testing Scenarios

### New Feature Testing

1. Write unit tests first (TDD approach)
2. Run quick validation during development
3. Add integration tests for cross-module interactions
4. Run standard validation before committing
5. Include in bulletproof test suite

### Bug Fix Testing

1. Create reproduction test that fails
2. Implement fix
3. Verify test now passes
4. Run regression tests with bulletproof validation
5. Validate fix doesn't break other functionality

### Performance Testing

1. Use performance-focused bulletproof validation
2. Include timing assertions in tests
3. Test with parallel execution enabled
4. Validate memory usage and resource cleanup

### Cross-Platform Testing

1. Tag tests with 'CrossPlatform'
2. Test on Windows (primary) and Linux/macOS when possible
3. Use platform detection in tests when needed
4. Validate path handling across platforms

## Error Diagnosis

### Test Failure Investigation

1. Review bulletproof validation logs
2. Run individual failed tests in isolation
3. Use VS Code debugging with tests
4. Check for environment-specific issues

### Performance Issues

1. Run with performance focus
2. Check parallel execution metrics
3. Profile memory usage during tests
4. Validate cleanup operations

Remember: Always prioritize bulletproof validation for comprehensive testing. Use the three-tier approach (Quick/Standard/Complete) based on your development phase and urgency.
