# UnifiedMaintenance Module

## Test Status
- **Last Run**: 2025-07-08 17:29:43 UTC
- **Status**: ✅ PASSING (10/10 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

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

The UnifiedMaintenance module consolidates all project maintenance functionality into a single, coherent system that integrates with PatchManager for change control and includes comprehensive automated testing workflows. It serves as the central maintenance hub for the AitherZero project, providing automated testing, infrastructure health monitoring, and continuous maintenance operations.

### Core Purpose and Functionality

- **Unified Maintenance Operations**: Single interface for all maintenance tasks
- **Automated Test Workflows**: Integrated Pester and pytest execution
- **Infrastructure Health Monitoring**: Comprehensive system health checks
- **PatchManager Integration**: Change control for all maintenance operations
- **Continuous Monitoring**: Long-running health and performance monitoring
- **Issue Tracking**: Recurring issue detection and prevention

### Architecture and Design

The module implements a maintenance-first architecture:
- **Operation Orchestration**: Coordinates complex maintenance workflows
- **Test Integration**: Seamlessly integrates multiple testing frameworks
- **Health Assessment**: Multi-layer infrastructure health evaluation
- **Change Control**: PatchManager integration for all modifications
- **Reporting System**: Comprehensive maintenance and test reporting
- **Monitoring Engine**: Continuous system monitoring capabilities

### Integration Points

- **PatchManager**: All changes go through change control
- **TestingFramework**: Integration with unified testing system
- **LabRunner**: Module loading and testing
- **Pester**: PowerShell testing framework
- **Python pytest**: Python code testing capabilities
- **Script Analysis**: PowerShell script syntax validation

## Directory Structure

```
UnifiedMaintenance/
├── UnifiedMaintenance.psd1       # Module manifest
├── UnifiedMaintenance.psm1       # Core module with all maintenance logic
└── README.md                     # This documentation

# Related maintenance directories:
TestResults/                      # Default test results location
HealthReport/                     # Infrastructure health reports
IssueTracking/                    # Issue tracking data
ContinuousMonitoring.log          # Continuous monitoring log
```

## Function Documentation

### Core Maintenance Functions

#### Invoke-UnifiedMaintenance
Main entry point for all maintenance operations with multiple operation modes.

**Parameters:**
- `Mode` (string): Operation mode ('Quick', 'Full', 'Test', 'TestOnly', 'Continuous', 'Track', 'Report', 'All')
- `AutoFix` (switch): Enable automatic issue remediation
- `UpdateChangelog` (switch): Update changelog during maintenance
- `UsePatchManager` (switch): Use PatchManager for change control

**Returns:** Maintenance results object

**Example:**
```powershell
# Quick maintenance check
Invoke-UnifiedMaintenance -Mode Quick

# Full maintenance with auto-fix
Invoke-UnifiedMaintenance -Mode Full -AutoFix

# Test-only mode with PatchManager
Invoke-UnifiedMaintenance -Mode TestOnly -UsePatchManager

# Complete maintenance with all options
Invoke-UnifiedMaintenance -Mode All -AutoFix -UpdateChangelog -UsePatchManager
```

#### Invoke-AutomatedTestWorkflow
Runs comprehensive automated test suites including Pester, pytest, integration, and performance tests.

**Parameters:**
- `TestCategory` (string): Test category ('Unit', 'Integration', 'Performance', 'All')
- `GenerateCoverage` (switch): Enable code coverage collection
- `Parallel` (switch): Enable parallel test execution (reserved)
- `OutputPath` (string): Directory for test results and reports

**Returns:** Comprehensive test results object

**Example:**
```powershell
# Run all tests with coverage
$results = Invoke-AutomatedTestWorkflow -TestCategory All -GenerateCoverage

# Run unit tests only
$results = Invoke-AutomatedTestWorkflow -TestCategory Unit -OutputPath "./unit-results"

# Performance testing
$results = Invoke-AutomatedTestWorkflow -TestCategory Performance
```

#### Invoke-InfrastructureHealth
Performs comprehensive infrastructure health checks with optional auto-remediation.

**Parameters:**
- `AutoFix` (switch): Attempt automatic remediation of issues
- `OutputPath` (string): Path for health report output

**Returns:** Infrastructure health assessment object

**Example:**
```powershell
# Basic health check
$health = Invoke-InfrastructureHealth

# Health check with auto-fix
$health = Invoke-InfrastructureHealth -AutoFix

# Generate detailed health report
$health = Invoke-InfrastructureHealth -OutputPath "./health-reports"
```

#### Start-ContinuousMonitoring
Starts continuous monitoring of system health and optional test execution.

**Parameters:**
- `IntervalMinutes` (int): Monitoring interval in minutes (default: 30)
- `RunTests` (switch): Include test execution in monitoring
- `LogPath` (string): Path for monitoring log file

**Returns:** None (runs continuously)

**Example:**
```powershell
# Start basic continuous monitoring
Start-ContinuousMonitoring

# Monitor with tests every 15 minutes
Start-ContinuousMonitoring -IntervalMinutes 15 -RunTests

# Custom log location
Start-ContinuousMonitoring -LogPath "./monitoring/system.log"
```

#### Invoke-RecurringIssueTracking
Tracks and analyzes recurring issues with prevention recommendations.

**Parameters:**
- `IncludePreventionCheck` (switch): Include prevention analysis
- `OutputPath` (string): Output directory for tracking reports

**Returns:** Issue tracking results object

**Example:**
```powershell
# Basic issue tracking
$issues = Invoke-RecurringIssueTracking

# Include prevention analysis
$issues = Invoke-RecurringIssueTracking -IncludePreventionCheck

# Generate tracking report
$issues = Invoke-RecurringIssueTracking -OutputPath "./issue-analysis"
```

### Internal Helper Functions

#### Write-MaintenanceLog
Specialized logging function for maintenance operations.

**Parameters:**
- `Message` (string): Log message
- `Level` (string): Log level ('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'MAINTENANCE')

**Example:**
```powershell
Write-MaintenanceLog "Starting maintenance operation" 'MAINTENANCE'
Write-MaintenanceLog "Operation completed successfully" 'SUCCESS'
```

#### Get-ProjectRoot
Returns the project root directory path with cross-platform support.

#### Test-Prerequisites
Validates required dependencies and modules before maintenance operations.

#### Invoke-MaintenanceStep
Executes a maintenance step with error handling and logging.

## Features

### Automated Testing
- **Multi-Framework Support**: Pester (PowerShell) and pytest (Python)
- **Coverage Analysis**: Code coverage collection and reporting
- **Performance Benchmarking**: Module import and execution timing
- **Integration Testing**: Cross-module integration validation
- **Comprehensive Reporting**: Markdown reports with detailed results

### Infrastructure Health
- **Module Health**: Validates module loading and functionality
- **Script Syntax**: PowerShell script syntax validation
- **Test Framework**: Validates testing infrastructure
- **Dependency Checking**: Ensures all prerequisites are met
- **Auto-Remediation**: Automatic fixing of common issues

### Change Control
- **PatchManager Integration**: All changes go through proper workflow
- **Rollback Capability**: Ability to rollback failed operations
- **Change Documentation**: Automatic changelog updates
- **Test Validation**: Pre-commit testing of changes

### Monitoring & Tracking
- **Continuous Health Monitoring**: Long-running system observation
- **Issue Pattern Detection**: Identifies recurring problems
- **Performance Tracking**: Monitors system performance over time
- **Alert Generation**: Notifications for critical issues

## Usage Guide

### Getting Started

```powershell
# Import the module
Import-Module ./aither-core/modules/UnifiedMaintenance

# Run quick health check
Invoke-UnifiedMaintenance -Mode Quick

# Run comprehensive maintenance
Invoke-UnifiedMaintenance -Mode All -AutoFix
```

### Common Workflows

#### Daily Maintenance
```powershell
# 1. Quick health assessment
$health = Invoke-InfrastructureHealth

# 2. Run unit tests
$tests = Invoke-AutomatedTestWorkflow -TestCategory Unit

# 3. Check for issues
if ($health.OverallHealth -ne 'Good' -or $tests.Categories.Pester.Failed -gt 0) {
    # Run full maintenance with auto-fix
    Invoke-UnifiedMaintenance -Mode Full -AutoFix
}
```

#### Pre-Release Testing
```powershell
# 1. Comprehensive test suite
$results = Invoke-AutomatedTestWorkflow -TestCategory All -GenerateCoverage

# 2. Infrastructure validation
$health = Invoke-InfrastructureHealth -OutputPath "./pre-release-health"

# 3. Generate release report
$report = @{
    TestResults = $results
    HealthCheck = $health
    Timestamp = Get-Date
    Version = "v1.0.0"
}

$report | ConvertTo-Json -Depth 10 | Out-File "./release-validation.json"
```

#### Continuous Integration
```powershell
# CI-friendly maintenance with PatchManager
Invoke-UnifiedMaintenance -Mode Test -UsePatchManager

# Or test-only mode for pure validation
Invoke-UnifiedMaintenance -Mode TestOnly
```

#### Issue Investigation
```powershell
# 1. Check current health
$health = Invoke-InfrastructureHealth

# 2. Track recurring issues
$issues = Invoke-RecurringIssueTracking -IncludePreventionCheck

# 3. Run diagnostic tests
$tests = Invoke-AutomatedTestWorkflow -TestCategory All

# 4. Generate investigation report
$investigation = @{
    Health = $health
    Issues = $issues
    Tests = $tests
}
```

### Advanced Scenarios

#### Custom Maintenance Modes
```powershell
# Create custom maintenance routine
function Invoke-CustomMaintenance {
    param($Severity = "Standard")
    
    switch ($Severity) {
        "Light" {
            Invoke-UnifiedMaintenance -Mode Quick
        }
        "Standard" {
            Invoke-UnifiedMaintenance -Mode Full -AutoFix
        }
        "Heavy" {
            Invoke-UnifiedMaintenance -Mode All -AutoFix -UpdateChangelog -UsePatchManager
        }
    }
}
```

#### Maintenance Scheduling
```powershell
# Set up scheduled maintenance
$trigger = New-ScheduledTaskTrigger -Daily -At "2:00 AM"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument @"
    -NoProfile -Command "
    Import-Module ./aither-core/modules/UnifiedMaintenance;
    Invoke-UnifiedMaintenance -Mode Quick
    "
"@

Register-ScheduledTask -TaskName "AitherZeroMaintenance" -Trigger $trigger -Action $action
```

## Configuration

### Test Configuration

Default test settings in the module:

```powershell
$testConfig = @{
    Pester = @{
        OutputPath = "$OutputPath/PesterResults.xml"
        Verbosity = "Detailed"
        Coverage = @{
            Enabled = $GenerateCoverage
            Path = @("$ProjectRoot/aither-core/modules", "$ProjectRoot/aither-core")
            OutputPath = "$OutputPath/PesterCoverage.xml"
        }
    }
    Pytest = @{
        OutputPath = "$OutputPath/pytestResults.xml"
        CoveragePath = "$OutputPath/pytestCoverage.xml"
        HtmlCoverage = "$OutputPath/htmlcov"
    }
}
```

### Health Check Configuration

Default health assessment criteria:

```powershell
$healthCriteria = @{
    Modules = @{
        RequiredModules = @('LabRunner', 'PatchManager')
        LoadingTimeout = 30
    }
    Scripts = @{
        SyntaxCheckPaths = @("$ProjectRoot/core-runner")
        MaxErrors = 0
    }
    TestFramework = @{
        RequiredFrameworks = @('Pester', 'Python')
        MinimumVersions = @{
            Pester = "5.0.0"
            Python = "3.8.0"
        }
    }
}
```

### Monitoring Configuration

```powershell
$monitoringConfig = @{
    DefaultInterval = 30  # minutes
    HealthThresholds = @{
        Good = @{ CriticalIssues = 0; MajorIssues = 0 }
        Fair = @{ CriticalIssues = 0; MajorIssues = 2 }
        Poor = @{ CriticalIssues = 1; MajorIssues = 5 }
    }
    AlertLevels = @{
        Critical = "Immediate"
        Major = "Within 1 hour"
        Minor = "Within 24 hours"
    }
}
```

## Integration

### PatchManager Integration

```powershell
# Maintenance operations with change control
if ($UsePatchManager -and (Get-Command Invoke-GitControlledPatch -ErrorAction SilentlyContinue)) {
    $results = Invoke-GitControlledPatch `
        -PatchDescription "Unified Maintenance: $Mode" `
        -PatchOperation {
            Invoke-MaintenanceOperations -Mode $Mode -AutoFix:$AutoFix
        } `
        -TestCommands @("Import-Module $projectRoot/aither-core/modules/LabRunner -Force")
}
```

### Test Framework Integration

```powershell
# Integration with Pester
Import-Module Pester -Force
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = "$ProjectRoot/tests"
$pesterConfig.Output.Verbosity = 'Detailed'
$pesterResults = Invoke-Pester -Configuration $pesterConfig

# Integration with Python pytest
$pytestArgs = @("$ProjectRoot/py/tests", '-v', '--tb=short')
if ($GenerateCoverage) {
    $pytestArgs += @('--cov=py.labctl', '--cov-report=xml')
}
$output = python -m pytest @pytestArgs
```

### Event System Usage

```powershell
# Publish maintenance events
Publish-MaintenanceEvent -Type "MaintenanceStarted" -Data @{
    Mode = $Mode
    Timestamp = Get-Date
}

# Subscribe to health events
Subscribe-HealthEvent -Handler {
    param($Event)
    if ($Event.Health -eq 'Poor') {
        Start-EmergencyMaintenance
    }
}
```

## Report Examples

### Test Workflow Report

Generated markdown report structure:
```markdown
# Automated Test Workflow Report
Generated: 2025-07-06 10:30:00
Test Category: All
Coverage Enabled: True

## Summary

### PowerShell Pester Tests
- Total:   45
- Passed:  43
- Failed:  2
- Skipped: 0

### Python pytest Tests
- Exit Code: 0
- Success:   True

### Performance Benchmarks
- Module Import Time:    2.34s
- Runner Performance:    1.87s
```

### Health Report Structure

```json
{
    "timestamp": "2025-07-06T10:30:00Z",
    "overallHealth": "Good",
    "checks": {
        "modules": {
            "LabRunner": {
                "exists": true,
                "loadsCorrectly": true,
                "functions": ["Initialize-LabRunner", "Start-LabExecution"]
            }
        },
        "scriptSyntax": {
            "totalScripts": 25,
            "errorCount": 0,
            "errors": []
        },
        "testFramework": {
            "pesterAvailable": true,
            "pytestAvailable": true,
            "testFilesExist": true
        }
    }
}
```

## Best Practices

1. **Regular Maintenance**
   - Run quick checks daily
   - Full maintenance weekly
   - Comprehensive maintenance before releases

2. **Change Control**
   - Always use PatchManager for significant changes
   - Test changes before applying
   - Keep detailed maintenance logs

3. **Monitoring**
   - Set up continuous monitoring for production
   - Configure appropriate alert thresholds
   - Regular review of monitoring data

4. **Testing Strategy**
   - Include all test categories in maintenance
   - Maintain high code coverage
   - Address test failures promptly

## Troubleshooting

### Common Issues

1. **Prerequisites Missing**
   ```powershell
   # Check and install missing components
   Test-Prerequisites -ProjectRoot $projectRoot
   Install-MissingPrerequisites
   ```

2. **Module Loading Failures**
   ```powershell
   # Debug module loading
   Import-Module $modulePath -Force -Verbose
   Get-Module $moduleName | Format-List *
   ```

3. **Test Execution Problems**
   ```powershell
   # Check test environment
   Test-TestingEnvironment
   Reset-TestEnvironment
   ```

### Debug Mode

```powershell
# Enable debug output
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

# Run maintenance with full logging
Invoke-UnifiedMaintenance -Mode Test -Verbose -Debug

# Check internal state
Get-MaintenanceState | Format-List *
```

## Performance Considerations

1. **Test Execution**
   - Use parallel execution when possible
   - Cache test results for repeated runs
   - Skip expensive tests in quick modes

2. **Health Checks**
   - Limit deep scanning in continuous monitoring
   - Use incremental checks when possible
   - Cache validation results

3. **Monitoring**
   - Adjust monitoring intervals based on system load
   - Archive old monitoring data
   - Use efficient data storage formats

## Contributing

To contribute to the UnifiedMaintenance module:

1. Test all maintenance operations
2. Ensure compatibility with existing workflows
3. Add comprehensive error handling
4. Update documentation with examples
5. Validate cross-platform functionality

## License

This module is part of the AitherZero project and follows the project's licensing terms.