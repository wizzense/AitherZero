# TestingFramework Module

## Test Status
- **Last Run**: 2025-07-08 18:50:21 UTC
- **Status**: ✅ PASSING (49/49 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 49/49 | 0% | 3.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 6/6 | 0% | 1.3s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ❌ FAIL | 43/49 | 0% | 3.4s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.4s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ❌ FAIL | 43/49 | 0% | 3.6s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 10/10 | 0% | 1s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 0.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Module Overview

The TestingFramework module serves as the central orchestrator for all testing activities across the AitherZero project. It provides unified test execution, module integration, cross-platform validation, and seamless integration with VS Code and GitHub Actions, making it the backbone of the project's quality assurance infrastructure.

### Core Purpose and Functionality

- **Unified Test Orchestration**: Single entry point for all test types (unit, integration, performance)
- **Module Integration**: Automatic discovery and testing of all project modules
- **Parallel Execution**: Optimized test execution using the ParallelExecution module
- **Multi-Platform Support**: Native support for Windows, Linux, and macOS
- **CI/CD Integration**: Built-in support for GitHub Actions and VS Code
- **Comprehensive Reporting**: HTML, JSON, and console-based test reports
- **Event-Driven Architecture**: Module communication via publish/subscribe pattern

### Architecture and Design

The module implements a layered architecture:
- **Orchestration Layer**: Coordinates test execution across modules
- **Execution Engines**: Sequential and parallel test runners
- **Provider System**: Pluggable test providers for different test types
- **Reporting Engine**: Multi-format report generation
- **Event System**: Decoupled communication between components
- **Legacy Compatibility**: Support for existing test scripts

### Integration Points

- **Pester**: PowerShell testing framework integration
- **ParallelExecution**: Parallel test execution capabilities
- **Logging Module**: Centralized logging with fallback support
- **VS Code**: Real-time test results and discovery
- **GitHub Actions**: CI/CD workflow integration
- **Module System**: Automatic module discovery and loading

## Directory Structure

```
TestingFramework/
├── TestingFramework.psd1         # Module manifest
├── TestingFramework.psm1         # Core module with 1300+ lines of orchestration logic
└── README.md                     # This documentation

# Related test directories (project-wide):
tests/
├── unit/                         # Unit tests for modules
│   └── modules/
│       ├── LabRunner/
│       ├── PatchManager/
│       └── ...
├── integration/                  # Integration tests
├── performance/                  # Performance tests
└── results/                      # Test results and reports
```

## Function Documentation

### Core Testing Functions

#### Invoke-UnifiedTestExecution
Central entry point for all testing activities with module integration.

**Parameters:**
- `TestSuite` (string): Test suite to execute ('All', 'Unit', 'Integration', 'Performance', 'Modules', 'Quick', 'NonInteractive')
- `TestProfile` (string): Configuration profile ('Development', 'CI', 'Production', 'Debug')
- `Modules` (string[]): Specific modules to test (default: all discovered modules)
- `Parallel` (switch): Enable parallel test execution
- `OutputPath` (string): Path for test results and reports
- `VSCodeIntegration` (switch): Enable VS Code integration features
- `GenerateReport` (switch): Generate comprehensive HTML/JSON reports

**Returns:** Array of test results

**Example:**
```powershell
# Run all tests with report generation
Invoke-UnifiedTestExecution -TestSuite "All" -GenerateReport

# Run unit tests for specific modules in parallel
Invoke-UnifiedTestExecution -TestSuite "Unit" -Modules @("LabRunner", "PatchManager") -Parallel

# CI mode with VS Code integration
Invoke-UnifiedTestExecution -TestSuite "All" -TestProfile "CI" -VSCodeIntegration -GenerateReport
```

#### Get-DiscoveredModules
Discovers and validates project modules for testing.

**Parameters:**
- `SpecificModules` (string[]): Filter for specific module names

**Returns:** Array of module information objects

**Example:**
```powershell
# Discover all modules
$modules = Get-DiscoveredModules

# Discover specific modules
$modules = Get-DiscoveredModules -SpecificModules @("LabRunner", "SystemMonitoring")
```

#### New-TestExecutionPlan
Creates an intelligent test execution plan with dependency resolution.

**Parameters:**
- `TestSuite` (string): Test suite type (required)
- `Modules` (array): Modules to include (required)
- `TestProfile` (string): Test profile (required)

**Returns:** Test execution plan object

**Example:**
```powershell
# Create execution plan
$plan = New-TestExecutionPlan -TestSuite "All" -Modules $modules -TestProfile "Development"
```

### Test Execution Functions

#### Invoke-ParallelTestExecution
Executes tests in parallel using the ParallelExecution module.

**Parameters:**
- `TestPlan` (hashtable): Test execution plan (required)
- `OutputPath` (string): Output directory (required)

**Returns:** Array of test results

**Example:**
```powershell
# Execute tests in parallel
$results = Invoke-ParallelTestExecution -TestPlan $plan -OutputPath "./results"
```

#### Invoke-SequentialTestExecution
Executes tests sequentially with proper error handling.

**Parameters:**
- `TestPlan` (hashtable): Test execution plan (required)
- `OutputPath` (string): Output directory (required)

**Returns:** Array of test results

**Example:**
```powershell
# Execute tests sequentially
$results = Invoke-SequentialTestExecution -TestPlan $plan -OutputPath "./results"
```

### Reporting Functions

#### New-TestReport
Generates comprehensive test reports in multiple formats.

**Parameters:**
- `Results` (array): Test results array (required)
- `OutputPath` (string): Output directory (required)
- `TestSuite` (string): Test suite name (required)

**Returns:** Path to generated HTML report

**Example:**
```powershell
# Generate test report
$reportPath = New-TestReport -Results $results -OutputPath "./reports" -TestSuite "All"
```

#### Export-VSCodeTestResults
Exports test results in VS Code compatible format.

**Parameters:**
- `Results` (array): Test results (required)
- `OutputPath` (string): Output directory (required)

**Returns:** None (creates JSON file)

**Example:**
```powershell
# Export for VS Code
Export-VSCodeTestResults -Results $results -OutputPath "./results"
```

### Event System Functions

#### Publish-TestEvent
Publishes test events for module communication.

**Parameters:**
- `EventType` (string): Event type (required)
- `Data` (hashtable): Event data

**Returns:** None

**Example:**
```powershell
# Publish test completion event
Publish-TestEvent -EventType "TestExecutionCompleted" -Data @{
    TestSuite = "Unit"
    Results = $results
}
```

#### Subscribe-TestEvent
Subscribes to test events.

**Parameters:**
- `EventType` (string): Event type to subscribe to (required)
- `Handler` (scriptblock): Event handler (required)

**Returns:** None

**Example:**
```powershell
# Subscribe to test events
Subscribe-TestEvent -EventType "TestExecutionCompleted" -Handler {
    param($Event)
    Write-Host "Tests completed: $($Event.Data.TestSuite)"
}
```

### Provider System Functions

#### Register-TestProvider
Registers a module as a test provider.

**Parameters:**
- `ModuleName` (string): Module name (required)
- `TestTypes` (string[]): Supported test types (required)
- `Handler` (scriptblock): Test handler (required)

**Returns:** None

**Example:**
```powershell
# Register custom test provider
Register-TestProvider -ModuleName "CustomTests" -TestTypes @("Custom", "Specialized") -Handler {
    param($TestConfig)
    # Custom test logic
}
```

### Legacy Compatibility Functions

#### Invoke-PesterTests
Legacy compatibility function for existing Pester test scripts.

**Parameters:**
- `OutputPath` (string): Output directory
- `VSCodeIntegration` (switch): VS Code integration

**Returns:** Test results

**Example:**
```powershell
# Run Pester tests (legacy)
$results = Invoke-PesterTests -OutputPath "./results"
```

#### Invoke-BulletproofTest
Executes bulletproof tests with comprehensive validation.

**Parameters:**
- `TestName` (string): Test name (required)
- `Type` (string): Test type ('Core', 'Module', 'System', 'Performance', 'Integration')
- `Critical` (switch): Mark as critical test

**Returns:** Test results

**Example:**
```powershell
# Run critical system test
Invoke-BulletproofTest -TestName "CoreSystemValidation" -Type "System" -Critical
```

## Features

### Test Orchestration
- **Intelligent Planning**: Automatic test dependency resolution
- **Module Discovery**: Finds and validates all testable modules
- **Profile-Based Configuration**: Different settings for dev/CI/production
- **Retry Logic**: Configurable retry for flaky tests

### Parallel Execution
- **Runspace Pools**: Efficient parallel execution
- **Automatic Scaling**: Scales to available CPU cores
- **Result Aggregation**: Combines results from parallel runs
- **Error Isolation**: Failures don't affect other tests

### Comprehensive Reporting
- **HTML Reports**: Rich, interactive HTML reports
- **JSON Export**: Machine-readable test data
- **Console Output**: Real-time test progress
- **VS Code Integration**: Test results in VS Code UI

### Cross-Platform Support
- **Platform Detection**: Automatic platform-specific adjustments
- **Path Normalization**: Cross-platform path handling
- **Shell Compatibility**: Works with PowerShell Core on all platforms

## Usage Guide

### Getting Started

```powershell
# Import the module
Import-Module ./aither-core/modules/TestingFramework

# Run quick validation
Invoke-UnifiedTestExecution -TestSuite "Quick"

# Run all tests with reporting
Invoke-UnifiedTestExecution -TestSuite "All" -GenerateReport
```

### Common Workflows

#### Development Testing
```powershell
# 1. Run unit tests during development
Invoke-UnifiedTestExecution -TestSuite "Unit" -TestProfile "Development"

# 2. Test specific module changes
Invoke-UnifiedTestExecution -TestSuite "Unit" -Modules @("MyModule") -Verbose

# 3. Run with debugging
Invoke-UnifiedTestExecution -TestSuite "Unit" -TestProfile "Debug"
```

#### CI/CD Pipeline
```powershell
# 1. Full test suite for CI
Invoke-UnifiedTestExecution -TestSuite "All" -TestProfile "CI" -GenerateReport

# 2. Parallel execution for speed
Invoke-UnifiedTestExecution -TestSuite "All" -Parallel -TestProfile "CI"

# 3. Non-interactive tests only
Invoke-UnifiedTestExecution -TestSuite "NonInteractive" -TestProfile "CI"
```

#### Performance Testing
```powershell
# 1. Run performance tests
Invoke-UnifiedTestExecution -TestSuite "Performance" -GenerateReport

# 2. Establish performance baseline
$baseline = Invoke-UnifiedTestExecution -TestSuite "Performance" -TestProfile "Production"
Save-TestBaseline -Results $baseline -Name "v1.0-baseline"

# 3. Compare against baseline
$current = Invoke-UnifiedTestExecution -TestSuite "Performance"
Compare-TestResults -Current $current -Baseline $baseline
```

### Advanced Scenarios

#### Custom Test Suites
```powershell
# Define custom test suite
$customSuite = @{
    Name = "SecurityTests"
    Modules = @("SecureCredentials", "SecurityAutomation")
    TestTypes = @("Unit", "Integration")
    Profile = "Production"
}

# Execute custom suite
Invoke-UnifiedTestExecution @customSuite
```

#### Test Result Analysis
```powershell
# Get detailed test metrics
$results = Invoke-UnifiedTestExecution -TestSuite "All"
$metrics = $results | Measure-TestMetrics

# Find slow tests
$slowTests = $results | Where-Object { $_.Duration -gt 5 } | 
    Sort-Object Duration -Descending

# Generate failure report
$failures = $results | Where-Object { -not $_.Success }
$failures | Export-TestFailures -Path "./failure-analysis.md"
```

## Configuration

### Test Profiles

Configuration profiles control test behavior:

```powershell
# Development Profile
@{
    Verbosity = "Detailed"
    TimeoutMinutes = 15
    MockLevel = "High"
    RetryCount = 2
}

# CI Profile
@{
    Verbosity = "Normal"
    TimeoutMinutes = 45
    MockLevel = "Standard"
    RetryCount = 3
}

# Production Profile
@{
    Verbosity = "Normal"
    TimeoutMinutes = 60
    MockLevel = "Low"
    RetryCount = 1
}

# Debug Profile
@{
    Verbosity = "Verbose"
    TimeoutMinutes = 120
    MockLevel = "None"
    ParallelJobs = 1
}
```

### Module Test Configuration

Per-module test settings in `tests/unit/modules/[ModuleName]/test-config.json`:

```json
{
    "testConfig": {
        "timeout": 300,
        "parallel": true,
        "coverage": {
            "enabled": true,
            "threshold": 80
        },
        "mocks": {
            "filesystem": true,
            "network": true
        }
    }
}
```

### Performance Tuning

```powershell
# Optimize for speed
Set-TestConfiguration -Profile "Speed" -Settings @{
    ParallelJobs = [Environment]::ProcessorCount
    SkipCoverage = $true
    FastFail = $true
}

# Optimize for thoroughness
Set-TestConfiguration -Profile "Thorough" -Settings @{
    ParallelJobs = 1
    Coverage = $true
    RetryCount = 3
    ExtendedValidation = $true
}
```

## Integration

### VS Code Integration

`.vscode/settings.json` configuration:
```json
{
    "powershell.pester.useLegacyCodeLens": false,
    "powershell.pester.outputVerbosity": "Detailed",
    "aitherzero.testing.autoDiscovery": true,
    "aitherzero.testing.showInlineResults": true
}
```

### GitHub Actions Integration

`.github/workflows/test.yml`:
```yaml
- name: Run Tests
  run: |
    Import-Module ./aither-core/modules/TestingFramework
    Invoke-UnifiedTestExecution -TestSuite "All" -TestProfile "CI" -GenerateReport
    
- name: Upload Test Results
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: tests/results/
```

### Event System Usage

```powershell
# Monitor test progress
Subscribe-TestEvent -EventType "TestPhaseStarted" -Handler {
    param($Event)
    Write-Host "Starting phase: $($Event.Data.Phase)"
}

# React to test failures
Subscribe-TestEvent -EventType "TestFailed" -Handler {
    param($Event)
    Send-Alert -Message "Test failed: $($Event.Data.TestName)"
}
```

## Best Practices

1. **Test Organization**
   - Keep unit tests close to code
   - Separate integration tests
   - Use descriptive test names
   - Group related tests

2. **Performance**
   - Use parallel execution for independent tests
   - Mock expensive operations
   - Set appropriate timeouts
   - Cache test data

3. **Reliability**
   - Avoid test interdependencies
   - Clean up test artifacts
   - Use proper assertions
   - Handle async operations correctly

4. **Reporting**
   - Generate reports for CI builds
   - Archive historical results
   - Track test metrics over time
   - Monitor test coverage

## Troubleshooting

### Common Issues

1. **Tests not discovered**
   - Check module manifest exists
   - Verify test file naming convention
   - Ensure proper directory structure

2. **Parallel execution failures**
   - Check for shared state
   - Verify thread safety
   - Review resource locks

3. **Performance issues**
   - Profile slow tests
   - Check for memory leaks
   - Review mock complexity

### Debug Mode

```powershell
# Enable full debugging
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

# Run with trace
Invoke-UnifiedTestExecution -TestSuite "Unit" -TestProfile "Debug" -Verbose -Debug

# Check internal state
Get-TestFrameworkState | Format-List *
```

## Test Patterns

### Unit Test Pattern
```powershell
Describe "Module-Function" {
    BeforeAll {
        Import-Module $ModulePath -Force
    }
    
    Context "When valid input provided" {
        It "Should return expected result" {
            $result = Invoke-Function -Parameter "value"
            $result | Should -Be "expected"
        }
    }
    
    Context "When invalid input provided" {
        It "Should throw meaningful error" {
            { Invoke-Function -Parameter $null } | Should -Throw
        }
    }
}
```

### Integration Test Pattern
```powershell
Describe "Module Integration" {
    BeforeAll {
        Initialize-TestEnvironment
    }
    
    AfterAll {
        Remove-TestEnvironment
    }
    
    It "Should work with dependent modules" {
        $result = Invoke-IntegratedWorkflow
        $result.Success | Should -Be $true
    }
}
```

## Contributing

To contribute to the TestingFramework:

1. Add tests for new functionality
2. Ensure all tests pass locally
3. Update documentation
4. Run full test suite
5. Submit PR with test results

## License

This module is part of the AitherZero project and follows the project's licensing terms.