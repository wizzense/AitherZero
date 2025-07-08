# AitherZero Integration Test Suite

## Overview

This directory contains comprehensive integration tests for the AitherZero Infrastructure Automation Framework. These tests focus on module-to-module interactions, end-to-end workflows, and real-world scenarios to ensure the entire system works cohesively.

## Test Suite Structure

### Core Integration Tests

| Test File | Purpose | Coverage |
|-----------|---------|----------|
| `Run-IntegrationTests.ps1` | Main test runner and orchestrator | All integration test coordination |
| `ConfigurationManagement.EndToEnd.Tests.ps1` | Configuration system integration | Multi-module configuration workflows |
| `PatchManager.Integration.Tests.ps1` | Git workflow and patch management | PatchManager + Git + other modules |
| `TestingFramework.Integration.Tests.ps1` | Test system coordination | TestingFramework + ParallelExecution + others |
| `CLI.Integration.Tests.ps1` | CLI and end-to-end workflows | Entry points + complete user workflows |
| `ModuleCommunication.Integration.Tests.ps1` | Inter-module communication | APIs + events + messaging |
| `SmokeTests.Integration.Tests.ps1` | Critical path validation | System health + core functionality |
| `ErrorScenarios.Integration.Tests.ps1` | Error handling and recovery | Resilience + edge cases |

### Integration Test Categories

#### 1. Module-to-Module Interactions
- **Configuration Modules**: ConfigurationCore + ConfigurationCarousel + ConfigurationRepository + ConfigurationManager
- **PatchManager Integration**: PatchManager + TestingFramework + ConfigurationCore + ModuleCommunication
- **TestingFramework Coordination**: TestingFramework + ParallelExecution + PatchManager + DevEnvironment
- **Communication System**: ModuleCommunication + all modules for event-driven coordination

#### 2. End-to-End Workflows
- **CLI Entry Points**: Start-AitherZero.ps1 + Start-DeveloperSetup.ps1 complete workflows
- **Configuration Lifecycle**: Initialize → Configure → Validate → Deploy → Monitor
- **Development Workflows**: Setup → Development → Testing → Patch Creation → Deployment
- **User Experience**: First-time setup → Daily operations → Maintenance

#### 3. Real-World Scenarios
- **Development Environment Setup**: Complete developer onboarding workflow
- **Configuration Management**: Multi-environment configuration promotion
- **Patch Management**: Feature development + testing + deployment
- **System Maintenance**: Backup + restore + upgrade workflows

#### 4. Error Scenarios and Edge Cases
- **System Failures**: Module loading failures + configuration corruption + communication failures
- **Invalid Input**: Malformed data + invalid parameters + injection attacks
- **Resource Exhaustion**: Memory + disk + network resource limitations
- **Concurrent Operations**: Race conditions + locking conflicts + deadlocks
- **Security Violations**: Unauthorized access + malicious input + privilege escalation

## Running Integration Tests

### Quick Start

```powershell
# Run all integration tests
./tests/integration/Run-IntegrationTests.ps1 -TestSuite All

# Run specific test categories
./tests/integration/Run-IntegrationTests.ps1 -TestSuite Core
./tests/integration/Run-IntegrationTests.ps1 -TestSuite Configuration
./tests/integration/Run-IntegrationTests.ps1 -TestSuite PatchManager
./tests/integration/Run-IntegrationTests.ps1 -TestSuite CLI
./tests/integration/Run-IntegrationTests.ps1 -TestSuite Communication
./tests/integration/Run-IntegrationTests.ps1 -TestSuite Smoke

# Run with additional options
./tests/integration/Run-IntegrationTests.ps1 -TestSuite All -IncludeSlowTests -CI
```

### Test Suite Options

| Test Suite | Description | Duration | Use Case |
|------------|-------------|----------|----------|
| `Smoke` | Critical path validation | < 2 minutes | CI/CD pipelines, quick validation |
| `Core` | Core module interactions | < 5 minutes | Development validation |
| `Configuration` | Configuration system integration | < 10 minutes | Configuration changes |
| `PatchManager` | Git workflow integration | < 15 minutes | Patch management validation |
| `CLI` | CLI and end-to-end workflows | < 10 minutes | User experience validation |
| `Communication` | Module communication testing | < 15 minutes | Communication system changes |
| `All` | Complete integration test suite | < 30 minutes | Full system validation |

### Advanced Usage

```powershell
# Run with parallel execution
./tests/integration/Run-IntegrationTests.ps1 -TestSuite Core -Parallel

# Run with custom output path
./tests/integration/Run-IntegrationTests.ps1 -TestSuite All -OutputPath "./custom-results"

# Run in CI mode (optimized for automation)
./tests/integration/Run-IntegrationTests.ps1 -TestSuite All -CI

# Include slow/long-running tests
./tests/integration/Run-IntegrationTests.ps1 -TestSuite All -IncludeSlowTests
```

## Test Architecture

### Test Environment Setup

Each integration test file follows this pattern:

```powershell
BeforeAll {
    # Setup test environment
    $ProjectRoot = Find-ProjectRoot
    
    # Import required modules
    $requiredModules = @("Module1", "Module2", "Module3")
    foreach ($module in $requiredModules) {
        Import-Module (Join-Path $ProjectRoot "aither-core/modules/$module") -Force
    }
    
    # Create test directory structure
    $TestRoot = Join-Path $TestDrive "test-category"
    New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null
    
    # Setup mock functions and test data
    # ...
}
```

### Test Execution Patterns

#### 1. Scenario-Based Testing
```powershell
It "Should handle complex workflow scenario" {
    # Arrange
    $scenario = @{
        Name = "ComplexWorkflow"
        Steps = @("step1", "step2", "step3")
        Expected = @{ Success = $true }
    }
    
    # Act
    $result = Invoke-WorkflowScenario -Scenario $scenario
    
    # Assert
    $result.Success | Should -Be $true
    $result.Steps.Count | Should -Be 3
    $result.Steps | ForEach-Object { $_.Success | Should -Be $true }
}
```

#### 2. Module Integration Testing
```powershell
It "Should integrate Module A with Module B" {
    # Arrange
    $moduleA = Initialize-ModuleA
    $moduleB = Initialize-ModuleB
    
    # Act
    $integrationResult = Test-ModuleIntegration -ModuleA $moduleA -ModuleB $moduleB
    
    # Assert
    $integrationResult.Success | Should -Be $true
    $integrationResult.Communication | Should -Be "Successful"
    $integrationResult.DataExchange | Should -Be "Valid"
}
```

#### 3. Error Scenario Testing
```powershell
It "Should handle error scenario gracefully" {
    # Arrange
    $errorScenario = { throw "Simulated error" }
    
    # Act
    $result = Test-ErrorHandling -Scenario $errorScenario
    
    # Assert
    $result.ErrorDetected | Should -Be $true
    $result.RecoveryAttempted | Should -Be $true
    $result.RecoverySuccessful | Should -Be $true
}
```

### Event Tracking and Reporting

All integration tests use a consistent event tracking system:

```powershell
# Event tracking setup
$script:IntegrationEvents = @()

function Publish-TestEvent {
    param([string]$EventName, [hashtable]$EventData)
    $script:IntegrationEvents += @{
        EventName = $EventName
        EventData = $EventData
        Timestamp = Get-Date
    }
}

# Usage in tests
Publish-TestEvent -EventName "ModuleIntegrationTested" -EventData @{
    ModuleA = "ConfigurationCore"
    ModuleB = "ConfigurationCarousel"
    Result = $integrationResult
}
```

## Test Data and Mocking

### Mock Functions

Integration tests use sophisticated mocking to simulate real-world scenarios:

```powershell
# Mock module operations
function Invoke-MockModuleOperation {
    param(
        [string]$Operation,
        [hashtable]$Parameters = @{},
        [bool]$ForceError = $false,
        [string]$ErrorType = "General"
    )
    
    # Return realistic mock results
    return @{
        Success = -not $ForceError
        Operation = $Operation
        Parameters = $Parameters
        # ... detailed results
    }
}

# Mock communication systems
function Submit-MockModuleEvent {
    param([string]$EventName, [hashtable]$EventData)
    
    # Simulate event processing
    $script:EventHistory += @{
        EventName = $EventName
        EventData = $EventData
        Timestamp = Get-Date
    }
}
```

### Test Data Patterns

```powershell
# Comprehensive test data structures
$script:TestData = @{
    Organizations = @{
        Development = @{
            Name = "Development Team"
            Environments = @("dev", "test", "staging")
            Repositories = @{
                "dev-config" = @{
                    Template = "default"
                    Settings = @{ verbosity = "detailed" }
                }
            }
        }
    }
    
    ConfigurationScenarios = @{
        SimpleDeployment = @{
            Name = "Simple Application Deployment"
            Steps = @("create-repo", "setup-environment", "deploy-config", "validate")
            ExpectedDuration = 30
        }
    }
    
    ValidationPolicies = @{
        Basic = @{
            RequiredFiles = @("README.md", "configs/app-config.json")
            RequiredDirectories = @("configs", "environments")
            ValidationRules = @("json-syntax", "schema-validation")
        }
    }
}
```

## Test Results and Reporting

### Test Result Structure

Each test generates structured results:

```powershell
$testResult = @{
    TestName = "Module Integration Test"
    Success = $true
    Duration = 1234.56  # milliseconds
    ModulesTested = @("ModuleA", "ModuleB")
    Scenarios = @(
        @{
            Name = "Basic Communication"
            Success = $true
            Details = @{ /* ... */ }
        }
    )
    Events = @(/* tracked events */)
    Metrics = @{
        ResponseTime = 123.45
        ThroughputOPS = 1000
        ErrorRate = 0.01
    }
}
```

### Report Generation

The test runner generates comprehensive reports:

```powershell
# HTML Report
$htmlReport = New-IntegrationTestReport -TestResults $results -OutputPath $OutputPath -Format "HTML"

# JSON Report
$jsonReport = New-IntegrationTestReport -TestResults $results -OutputPath $OutputPath -Format "JSON"

# Console Summary
Write-IntegrationTestSummary -TestResults $results
```

## Integration with CI/CD

### GitHub Actions Integration

```yaml
# .github/workflows/integration-tests.yml
name: Integration Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  integration-tests:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup PowerShell
      uses: azure/powershell@v1
      with:
        powershell-version: '7.0'
    
    - name: Run Integration Tests
      run: |
        ./tests/integration/Run-IntegrationTests.ps1 -TestSuite All -CI
```

### CI Test Profiles

| Profile | Test Suite | Duration | Use Case |
|---------|------------|----------|----------|
| `Quick` | Smoke | < 2 min | PR validation |
| `Standard` | Core + Configuration | < 15 min | Branch validation |
| `Complete` | All | < 30 min | Release validation |
| `Nightly` | All + Slow Tests | < 60 min | Comprehensive validation |

## Best Practices

### Test Design Principles

1. **Realistic Scenarios**: Tests should mirror real-world usage patterns
2. **Comprehensive Coverage**: Cover happy paths, error scenarios, and edge cases
3. **Isolated Testing**: Each test should be independent and not rely on others
4. **Deterministic Results**: Tests should produce consistent results across runs
5. **Fast Execution**: Optimize for quick feedback in CI/CD pipelines

### Mock Strategy

1. **Minimal Mocking**: Use real modules when possible, mock only external dependencies
2. **Realistic Behavior**: Mocks should behave like the real system
3. **Error Simulation**: Include error scenarios in mocks
4. **Performance Simulation**: Include realistic timing and resource usage

### Error Testing Guidelines

1. **Expected Failures**: Test expected error conditions and recovery
2. **Edge Cases**: Test boundary conditions and unusual inputs
3. **Resource Limits**: Test behavior under resource constraints
4. **Concurrent Operations**: Test race conditions and locking scenarios

## Troubleshooting

### Common Issues

#### Test Failures

```powershell
# Debug test failures
$env:PESTER_DEBUG = "true"
./tests/integration/Run-IntegrationTests.ps1 -TestSuite Core -Verbose

# Check test logs
Get-Content "./tests/integration/results/test-report-*.log"
```

#### Module Loading Issues

```powershell
# Verify module paths
$env:PSModulePath -split [System.IO.Path]::PathSeparator

# Check module availability
Get-Module -ListAvailable | Where-Object { $_.Name -like "*Aither*" }
```

#### Performance Issues

```powershell
# Run with performance profiling
./tests/integration/Run-IntegrationTests.ps1 -TestSuite Core -Parallel:$false

# Monitor resource usage
Get-Process | Where-Object { $_.Name -like "*pwsh*" } | Select-Object CPU,WS
```

### Environment Setup

#### Prerequisites

1. **PowerShell 7.0+**: Required for cross-platform support
2. **Pester 5.0+**: Testing framework
3. **Git**: For PatchManager integration tests
4. **Sufficient Resources**: 4GB RAM, 1GB disk space

#### Configuration

```powershell
# Set environment variables
$env:PROJECT_ROOT = "/path/to/AitherZero"
$env:INTEGRATION_TEST_MODE = "true"
$env:TEST_OUTPUT_PATH = "./test-results"

# Configure test timeouts
$env:INTEGRATION_TEST_TIMEOUT = "1800"  # 30 minutes
$env:SMOKE_TEST_TIMEOUT = "120"        # 2 minutes
```

## Contributing

### Adding New Integration Tests

1. **Create Test File**: Follow naming convention `*.Integration.Tests.ps1`
2. **Use Template**: Copy structure from existing integration tests
3. **Add to Runner**: Register in `Run-IntegrationTests.ps1`
4. **Document**: Update this README with new test information

### Test File Template

```powershell
#Requires -Module Pester

<#
.SYNOPSIS
    [Test Category] Integration Tests

.DESCRIPTION
    Integration tests for [specific functionality]:
    - [Test area 1]
    - [Test area 2]
    - [Test area 3]

.NOTES
    [Additional notes and requirements]
#>

BeforeAll {
    # Setup test environment
    # Import required modules
    # Create test data
    # Setup mocks
}

Describe "[Test Category] Integration Tests" {
    Context "[Test Context 1]" {
        It "Should [test scenario]" {
            # Arrange
            # Act
            # Assert
        }
    }
}

AfterAll {
    # Cleanup test environment
    # Clear test data
    # Reset mocks
}
```

## Support

For issues with integration tests:

1. **Check Logs**: Review test output and logs
2. **Verify Environment**: Ensure prerequisites are met
3. **Run Diagnostics**: Use built-in diagnostic tools
4. **Consult Documentation**: Review test-specific documentation
5. **Report Issues**: Create issues with detailed information

## Metrics and Monitoring

### Test Metrics

The integration test suite tracks:

- **Execution Time**: Total and per-test execution time
- **Success Rate**: Percentage of passing tests
- **Coverage**: Module and scenario coverage
- **Resource Usage**: Memory and CPU utilization
- **Error Patterns**: Common failure modes

### Performance Benchmarks

| Test Suite | Target Duration | Success Rate | Resource Usage |
|------------|----------------|---------------|-----------------|
| Smoke | < 2 minutes | > 95% | < 500MB RAM |
| Core | < 5 minutes | > 90% | < 1GB RAM |
| All | < 30 minutes | > 85% | < 2GB RAM |

### Monitoring Dashboard

Integration test results are tracked in:

- **CI/CD Pipelines**: Real-time test execution
- **Test Reports**: Historical trend analysis
- **Performance Metrics**: Resource usage trends
- **Error Analysis**: Failure pattern identification

This comprehensive integration test suite ensures the AitherZero system works reliably across all supported scenarios and environments.