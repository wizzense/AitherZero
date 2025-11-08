# End-to-End Test Execution Guide

This guide describes the end-to-end (E2E) test suite for AitherZero's Interactive UI, CLI, and Orchestration Engine.

## Overview

The E2E test suite validates the complete functionality of the recently overhauled:
- **Interactive UI**: Menu systems, user prompts, and interactive components
- **CLI**: Command-line interface modes (List, Search, Run, Validate)
- **Orchestration Engine**: Playbook execution, job coordination, and workflow automation

## Test Files

### CLI-E2E.Tests.ps1 (15 tests)
Tests command-line interface functionality:
- List mode operations (scripts, playbooks)
- Search mode operations
- Validate mode operations
- Parameter validation
- Configuration loading
- Module integration

**Location**: `/tests/integration/CLI-E2E.Tests.ps1`

### InteractiveUI-E2E.Tests.ps1 (22 tests)
Tests interactive user interface components:
- Menu system (BetterMenu, UIMenu)
- UI components (borders, text, notifications, prompts)
- Playbook browser integration
- Module loading
- Color and formatting
- Error handling and fallback mechanisms

**Location**: `/tests/integration/InteractiveUI-E2E.Tests.ps1`

### Orchestration-E2E.Tests.ps1 (31 tests)
Tests orchestration and workflow automation:
- Playbook discovery and loading
- Sequence validation
- Job orchestration and dependencies
- Playbook execution and profiles
- Variable interpolation
- Conditional execution
- Error handling and retries
- Configuration integration
- Expression validation (GitHub Actions-style)

**Location**: `/tests/integration/Orchestration-E2E.Tests.ps1`

## Running Tests

### Run All E2E Tests
```powershell
Invoke-Pester -Path @(
    './tests/integration/CLI-E2E.Tests.ps1',
    './tests/integration/InteractiveUI-E2E.Tests.ps1',
    './tests/integration/Orchestration-E2E.Tests.ps1'
)
```

### Run Specific Test Suite
```powershell
# CLI tests only
Invoke-Pester -Path './tests/integration/CLI-E2E.Tests.ps1'

# Interactive UI tests only
Invoke-Pester -Path './tests/integration/InteractiveUI-E2E.Tests.ps1'

# Orchestration tests only
Invoke-Pester -Path './tests/integration/Orchestration-E2E.Tests.ps1'
```

### Run with Tags
```powershell
# Run all E2E tests
Invoke-Pester -Path './tests/integration' -Tag 'E2E'

# Run CLI-specific tests
Invoke-Pester -Path './tests/integration' -Tag 'E2E', 'CLI'

# Run orchestration-specific tests
Invoke-Pester -Path './tests/integration' -Tag 'E2E', 'Orchestration'
```

### Run with Detailed Output
```powershell
$config = New-PesterConfiguration
$config.Run.Path = './tests/integration/CLI-E2E.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
```

## Test Coverage

### Current Results (as of 2025-11-02)
- **Total E2E Tests**: 68
- **Passing**: 68 (100%)
- **Failed**: 0
- **Execution Time**: ~33 seconds

### Coverage by Component
| Component | Tests | Coverage Areas |
|-----------|-------|----------------|
| CLI | 15 | List, Search, Run, Validate modes; parameter validation; module integration |
| Interactive UI | 22 | Menus, UI components, playbook browser, error handling |
| Orchestration | 31 | Playbooks, sequences, jobs, configuration, expressions |

## Test Structure

### Test Organization
```
tests/integration/
├── CLI-E2E.Tests.ps1              # CLI functionality
├── InteractiveUI-E2E.Tests.ps1    # Interactive UI components
├── Orchestration-E2E.Tests.ps1    # Orchestration engine
└── PlaybookSelection.Tests.ps1    # Playbook selection logic
```

### Common Patterns

#### Module Import
All E2E tests import the main module:
```powershell
BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $script:ProjectRoot "AitherZero.psd1") -Force
    
    # Set test mode
    $env:AITHERZERO_TEST_MODE = "1"
    $env:AITHERZERO_NONINTERACTIVE = "1"
}
```

#### Test Naming
Tests follow descriptive naming conventions:
```powershell
Describe "Component Name" -Tag 'E2E', 'Category' {
    Context "Feature Area" {
        It "Should perform specific action" {
            # Test implementation
        }
    }
}
```

## Key Test Scenarios

### CLI Mode Testing
1. **List Operations**: Verify scripts and playbooks can be listed
2. **Search Functionality**: Test query-based script discovery
3. **Run Mode**: Validate script execution initiation
4. **Parameter Validation**: Ensure proper parameter handling

### Interactive UI Testing
1. **Menu Navigation**: Verify menu systems work correctly
2. **UI Components**: Test borders, text, notifications, prompts
3. **Playbook Browser**: Validate playbook discovery and display
4. **Error Handling**: Test fallback mechanisms for non-interactive environments

### Orchestration Testing
1. **Playbook Discovery**: Verify playbook files are found and loaded
2. **Sequence Validation**: Test numeric range validation (0000-9999)
3. **Job Dependencies**: Validate dependency graph construction
4. **Expression Syntax**: Test GitHub Actions-style expression parsing
5. **Configuration Integration**: Verify configuration loading and access

## Troubleshooting

### Common Issues

#### Tests Hang on Menu Input
**Symptom**: Tests timeout waiting for user input
**Solution**: Ensure `$env:AITHERZERO_NONINTERACTIVE = "1"` is set

#### Module Not Found Errors
**Symptom**: `Cannot find module 'AitherZero'`
**Solution**: Run tests from repository root or adjust module import path

#### Function Not Available
**Symptom**: `The term 'Function-Name' is not recognized`
**Solution**: Verify function is exported in module manifest and loaded properly

### Debug Mode
Run tests with verbose output:
```powershell
$config = New-PesterConfiguration
$config.Run.Path = './tests/integration/CLI-E2E.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$config.Debug.WriteDebugMessages = $true
Invoke-Pester -Configuration $config
```

## Continuous Integration

### GitHub Actions
E2E tests run automatically on:
- Pull request creation/updates
- Pushes to main branches
- Manual workflow dispatch

### CI Configuration
Tests are executed with:
```yaml
- name: Run E2E Tests
  shell: pwsh
  run: |
    $config = New-PesterConfiguration
    $config.Run.Path = './tests/integration'
    $config.Filter.Tag = 'E2E'
    $config.Output.Verbosity = 'Detailed'
    Invoke-Pester -Configuration $config
```

## Best Practices

### Writing New E2E Tests
1. **Use BeforeAll** for setup that applies to all tests
2. **Tag appropriately** with 'E2E' and specific categories
3. **Set non-interactive mode** to prevent hanging
4. **Test function existence** before testing functionality
5. **Use error handling** with `SilentlyContinue` for optional features
6. **Keep tests independent** - don't rely on execution order

### Test Maintenance
1. **Run tests after UI/CLI changes** to catch regressions
2. **Update tests when functions are renamed** or parameters change
3. **Add new tests for new features** in the UI/CLI/Orchestration areas
4. **Document complex test scenarios** with clear comments

## Related Documentation

- [Test Best Practices](./TEST-BEST-PRACTICES.md)
- [Testing Framework](../aithercore/testing/README.md)
- [Orchestration Engine](../aithercore/automation/README.md)
- [Interactive UI](../aithercore/experience/README.md)

## Contact

For questions about E2E tests:
- Check existing test files for patterns
- Review test output for specific errors
- Consult the main project documentation

---
**Last Updated**: 2025-11-02  
**Test Suite Version**: 1.0.0  
**Maintainer**: AitherZero Testing Team
