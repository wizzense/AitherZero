# UtilityServices - Unified Utility Services Platform

## Overview

UtilityServices is a comprehensive utility platform that consolidates and unifies four critical utility modules in the AitherZero ecosystem:

- **SemanticVersioning**: Intelligent version management with conventional commits
- **ProgressTracking**: Visual progress indicators and operation monitoring  
- **TestingFramework**: Comprehensive testing orchestration with module integration
- **ScriptManager**: Script management, execution, and repository functions

This unified module provides both individual service access and integrated workflows that leverage multiple utility services together for enhanced functionality.

## Key Features

### 🔧 Unified Service Management
- **Centralized Initialization**: Single point of control for all utility services
- **Health Monitoring**: Real-time service status and health checks
- **Configuration Management**: Shared configuration across all services
- **Event-Driven Architecture**: Cross-service communication and coordination

### 🎯 Integrated Workflows
- **Version-Aware Testing**: Test execution with automatic version detection
- **Progress-Aware Script Execution**: Script running with real-time progress tracking
- **Test-Driven Versioning**: Version management based on test results
- **Full Utility Workflows**: End-to-end processes using all services

### 📊 Comprehensive Monitoring
- **Real-Time Dashboard**: Interactive monitoring interface
- **Detailed Metrics**: Performance and usage analytics
- **Event System**: Cross-service event publishing and subscription
- **Comprehensive Reporting**: HTML, JSON, and text reports

### 🛠️ Developer Experience
- **Auto-Initialization**: Services load automatically on module import
- **Error Recovery**: Intelligent error handling and service recovery
- **Integration Testing**: Built-in validation of service integration
- **Cleanup Management**: Automatic resource cleanup on module unload

## Quick Start

### Basic Usage

```powershell
# Import the UtilityServices module
Import-Module UtilityServices

# Initialize all services (usually automatic)
Initialize-UtilityServices

# Check service status
Get-UtilityServiceStatus

# Run integrated operations
Start-IntegratedOperation -OperationType "VersionedTestSuite" -Parameters @{TestSuite = "All"}
```

### Dashboard Monitoring

```powershell
# Start interactive dashboard
Start-UtilityDashboard

# Start dashboard with custom settings
Start-UtilityDashboard -RefreshInterval 5 -ShowMetrics
```

### Report Generation

```powershell
# Export HTML report
Export-UtilityReport -Format HTML -OutputPath "./reports/utility-report.html"

# Export comprehensive JSON report with metrics
Export-UtilityReport -Format JSON -TimeRange "LastWeek" -IncludeMetrics
```

## Core Services

### SemanticVersioning Services
Intelligent version management with conventional commit parsing:

```powershell
# Get next semantic version
$nextVersion = Get-NextSemanticVersion

# Parse conventional commits
$commits = Parse-ConventionalCommits -Commits $commitList

# Create version tag
New-VersionTag -Version "1.2.3" -Message "Release version 1.2.3"

# Get version history
Get-VersionHistory -Count 10

# Generate release notes
Get-ReleaseNotes -FromVersion "1.2.0" -ToVersion "1.3.0" -Format Markdown
```

### ProgressTracking Services
Visual progress indicators and operation monitoring:

```powershell
# Start progress operation
$progressId = Start-ProgressOperation -OperationName "Deployment" -TotalSteps 10 -ShowTime -ShowETA

# Update progress
Update-ProgressOperation -OperationId $progressId -IncrementStep -StepName "Creating resources"

# Complete operation
Complete-ProgressOperation -OperationId $progressId -ShowSummary

# Multi-operation tracking
$operations = @(
    @{Name = "Module Loading"; Steps = 5},
    @{Name = "Environment Setup"; Steps = 8}
)
$multiOps = Start-MultiProgress -Title "System Initialization" -Operations $operations
```

### TestingFramework Services
Comprehensive testing orchestration with module integration:

```powershell
# Run unified test execution
$results = Invoke-UnifiedTestExecution -TestSuite "All" -TestProfile "Development" -GenerateReport

# Discover modules for testing
$modules = Get-DiscoveredModules

# Run parallel tests
$parallelResults = Invoke-ParallelTestExecution -TestPlan $testPlan -OutputPath "./results"

# Generate test reports
New-TestReport -Results $results -OutputPath "./reports" -TestSuite "All"

# Bulk test generation for modules without tests
Invoke-BulkTestGeneration -MaxConcurrency 3
```

### ScriptManager Services
Script management, execution, and repository functions:

```powershell
# Register a script
Register-OneOffScript -ScriptPath "./scripts/deploy.ps1" -Name "Deployment Script"

# Execute script with progress tracking
Invoke-OneOffScript -ScriptPath "./scripts/deploy.ps1" -Parameters @{Environment = "dev"}

# Get script repository information
$repository = Get-ScriptRepository -Path "./scripts"

# Start script execution with monitoring
Start-ScriptExecution -ScriptName "deploy" -Parameters @{Target = "production"} -Background
```

## Integrated Workflows

### Version-Aware Testing

Combine testing with semantic versioning for intelligent release management:

```powershell
# Run test suite with version awareness
$result = New-VersionedTestSuite -TestSuite "All" -VersioningConfig @{
    PreRelease = "alpha"
    CreateTag = $true
}

# Results include both test results and version information
Write-Host "Tests: $($result.TestResults.Summary)"
Write-Host "Version: $($result.VersionInfo.NextVersion)"
```

### Progress-Aware Script Execution

Execute scripts with integrated progress tracking and monitoring:

```powershell
# Execute script with visual progress tracking
$result = Invoke-ProgressAwareExecution -ScriptPath "./scripts/complex-deployment.ps1" -Parameters @{
    Environment = "production"
    ComponentCount = 5
}

# Get execution metrics
Write-Host "Execution time: $($result.Metrics.ExecutionTime)s"
Write-Host "Script result: $($result.ScriptExecution.Result)"
```

### Full Utility Workflow

Execute comprehensive workflows using all utility services:

```powershell
# Run complete utility workflow
$workflow = Start-IntegratedOperation -OperationType "FullUtilityWorkflow" -Parameters @{
    TestSuite = "All"
    VersionBump = "Minor"
    ScriptPath = "./scripts/post-release.ps1"
}

# Monitor workflow progress
Get-UtilityServiceStatus
```

## Configuration Management

### Shared Configuration

```powershell
# Get current configuration
$config = Get-UtilityConfiguration

# Update configuration
Set-UtilityConfiguration -Configuration @{
    LogLevel = 'DEBUG'
    EnableProgressTracking = $true
    MaxConcurrency = 8
    DefaultTimeout = 600
}

# Reset to defaults
Reset-UtilityConfiguration
```

### Service-Specific Settings

```powershell
# Initialize with custom configuration
Initialize-UtilityServices -Configuration @{
    EnableMetrics = $true
    LogLevel = 'INFO'
    EnableProgressTracking = $true
    EnableVersioning = $true
    DefaultTimeout = 300
    MaxConcurrency = 4
}
```

## Event System

### Publishing Events

```powershell
# Publish custom events
Publish-UtilityEvent -EventType "CustomOperation" -Data @{
    Operation = "Deployment"
    Environment = "Production"
    Success = $true
}
```

### Subscribing to Events

```powershell
# Subscribe to service events
Subscribe-UtilityEvent -EventType "TestExecutionCompleted" -Handler {
    param($event)
    Write-Host "Test completed: $($event.Data.TestSuite)"
}

# Subscribe to version events
Subscribe-UtilityEvent -EventType "VersionTagCreated" -Handler {
    param($event)
    Write-Host "New version tagged: $($event.Data.Version)"
}
```

### Event Management

```powershell
# Get recent events
$events = Get-UtilityEvents -Count 20

# Get events by type
$testEvents = Get-UtilityEvents -EventType "TestExecutionCompleted"

# Clear event history
Clear-UtilityEvents -EventType "TestIntegrationEvent"
Clear-UtilityEvents -Force  # Clear all
```

## Monitoring and Diagnostics

### Service Status

```powershell
# Get comprehensive service status
$status = Get-UtilityServiceStatus

# Check individual service health
foreach ($service in $status.Services.Keys) {
    $serviceInfo = $status.Services[$service]
    Write-Host "$service`: $($serviceInfo.Status) ($($serviceInfo.FunctionCount) functions)"
}
```

### Metrics Collection

```powershell
# Get metrics for different time ranges
$hourlyMetrics = Get-UtilityMetrics -TimeRange "LastHour"
$dailyMetrics = Get-UtilityMetrics -TimeRange "Last24Hours"
$weeklyMetrics = Get-UtilityMetrics -TimeRange "LastWeek"

# Analyze operation performance
$avgExecutionTime = $dailyMetrics.IntegratedOperations.AverageExecutionTime
$successRate = $dailyMetrics.IntegratedOperations.Successful / $dailyMetrics.IntegratedOperations.Total * 100
```

### Integration Testing

```powershell
# Test service integration
$testResults = Test-UtilityIntegration -TestLevel "Standard"

# Comprehensive integration testing
$comprehensiveResults = Test-UtilityIntegration -TestLevel "Comprehensive" -OutputPath "./test-results"

# Test specific services
$specificResults = Test-UtilityIntegration -Services @("ProgressTracking", "TestingFramework")
```

## Advanced Usage

### Custom Integrated Operations

```powershell
# Create custom integrated operations by extending the workflows
function Invoke-CustomDeploymentWorkflow {
    param($Environment, $Version)
    
    # Start integrated operation
    $operation = Start-IntegratedOperation -OperationType "CustomDeployment" -Parameters @{
        Environment = $Environment
        Version = $Version
    }
    
    return $operation
}
```

### Service Recovery

```powershell
# Reset specific services
Reset-UtilityServices -Services @("TestingFramework") -KeepConfiguration

# Full reset with confirmation
Reset-UtilityServices -Force

# Selective reset preserving data
Reset-UtilityServices -Services @("ProgressTracking") -KeepEventHistory -KeepConfiguration
```

### Performance Optimization

```powershell
# Configure for high-performance scenarios
Set-UtilityConfiguration -Configuration @{
    MaxConcurrency = [Environment]::ProcessorCount
    EnableMetrics = $false  # Disable for performance
    LogLevel = 'ERROR'      # Reduce logging overhead
}

# Monitor performance impact
$metrics = Get-UtilityMetrics -TimeRange "LastHour"
Write-Host "Average execution time: $($metrics.IntegratedOperations.AverageExecutionTime)s"
```

## API Reference

### Core Management Functions

| Function | Description |
|----------|-------------|
| `Initialize-UtilityServices` | Initialize utility services platform |
| `Get-UtilityServiceStatus` | Get current status of all services |
| `Get-UtilityMetrics` | Get performance and usage metrics |
| `Reset-UtilityServices` | Reset services to initial state |
| `Test-UtilityIntegration` | Test service integration and functionality |

### Integrated Operations

| Function | Description |
|----------|-------------|
| `Start-IntegratedOperation` | Start complex multi-service operations |
| `New-VersionedTestSuite` | Run tests with version awareness |
| `Invoke-ProgressAwareExecution` | Execute scripts with progress tracking |

### Monitoring and Reporting

| Function | Description |
|----------|-------------|
| `Start-UtilityDashboard` | Launch interactive dashboard |
| `Export-UtilityReport` | Generate comprehensive reports |
| `Get-UtilityEvents` | Retrieve service event history |
| `Clear-UtilityEvents` | Clear event history |

### Configuration Management

| Function | Description |
|----------|-------------|
| `Get-UtilityConfiguration` | Get current configuration |
| `Set-UtilityConfiguration` | Update configuration settings |
| `Reset-UtilityConfiguration` | Reset to default configuration |

### Event System

| Function | Description |
|----------|-------------|
| `Publish-UtilityEvent` | Publish cross-service events |
| `Subscribe-UtilityEvent` | Subscribe to service events |

## Best Practices

### Service Initialization
- Let services auto-initialize on module import
- Use `Initialize-UtilityServices` only for custom configurations
- Check service status before performing complex operations

### Error Handling
- Always check service status before operations
- Use try-catch blocks around integrated operations
- Monitor event system for error notifications

### Performance
- Configure appropriate concurrency levels for your environment
- Use progress tracking selectively for long-running operations
- Monitor metrics to identify performance bottlenecks

### Integration
- Leverage integrated workflows instead of manual service coordination
- Use the event system for loose coupling between operations
- Implement custom workflows by extending existing patterns

## Migration Guide

### From Individual Modules

If you were using individual utility modules, migration is straightforward:

```powershell
# Old approach
Import-Module SemanticVersioning
Import-Module ProgressTracking
Import-Module TestingFramework
Import-Module ScriptManager

# New unified approach
Import-Module UtilityServices
# All functions are now available through the unified module
```

### Compatibility

UtilityServices maintains 100% compatibility with existing function signatures. All original functions work exactly as before, but now benefit from:

- Shared configuration
- Cross-service event coordination
- Integrated error handling
- Unified monitoring and reporting

## Troubleshooting

### Common Issues

**Service Initialization Failures**
```powershell
# Check individual service status
$status = Get-UtilityServiceStatus
$status.Services | Where-Object { -not $_.Loaded }

# Reset and re-initialize failed services
Reset-UtilityServices -Services @("FailedServiceName") -Force
```

**Event System Issues**
```powershell
# Check event system status
$status = Get-UtilityServiceStatus
Write-Host "Event system enabled: $($status.EventSystem.Enabled)"

# Clear problematic event history
Clear-UtilityEvents -Force
```

**Performance Issues**
```powershell
# Monitor resource usage
$metrics = Get-UtilityMetrics -TimeRange "LastHour"
Write-Host "Operations: $($metrics.IntegratedOperations.Total)"
Write-Host "Average time: $($metrics.IntegratedOperations.AverageExecutionTime)s"

# Optimize configuration
Set-UtilityConfiguration -Configuration @{
    MaxConcurrency = 2
    EnableMetrics = $false
}
```

### Diagnostic Commands

```powershell
# Comprehensive system check
Test-UtilityIntegration -TestLevel "Comprehensive"

# Generate diagnostic report
Export-UtilityReport -Format HTML -IncludeMetrics -TimeRange "Last24Hours"

# Monitor real-time status
Start-UtilityDashboard -RefreshInterval 5 -ShowMetrics
```

## Contributing

When extending UtilityServices:

1. **Follow Integration Patterns**: New functionality should integrate with existing services
2. **Use Event System**: Leverage events for cross-service communication
3. **Implement Progress Tracking**: Provide visual feedback for long operations
4. **Add Comprehensive Testing**: Include integration tests for new workflows
5. **Update Documentation**: Maintain this README with new capabilities

## License

This module is part of the AitherZero project and follows the same licensing terms.

---

**UtilityServices v1.0.0** - Unified utility platform providing essential services for the AitherZero ecosystem with integrated workflows, comprehensive monitoring, and intelligent automation.