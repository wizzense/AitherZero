# AitherZero Centralized Logging and Reporting System

## Overview

AitherZero provides a comprehensive centralized logging and reporting system that ensures consistent logging across all components, separate log files by severity level, and unified dashboards for monitoring logs, test results, code analysis, and system metrics.

## Features

### 🎯 Core Features

- **Multiple Log Levels**: Trace, Debug, Information, Warning, Error, Critical
- **Separate Log Files**: Automatic separation by severity level for easier filtering
- **Structured Logging**: JSON-formatted logs with rich metadata
- **Audit Trail**: Compliance-ready audit logging with immutable records
- **Performance Tracking**: Automatic operation timing and metrics
- **Test Result Integration**: Automatic logging of test execution and results
- **Code Analysis Integration**: PSScriptAnalyzer results automatically logged
- **Unified Dashboard**: Single view for all logs, tests, analysis, and metrics
- **Multiple Output Targets**: Console, File, JSON, Windows Event Log
- **Auto-source Detection**: Automatically identifies calling script/module

### 📁 Log File Organization

All logs are written to the `./logs` directory with the following structure:

```
logs/
├── aitherzero-YYYY-MM-DD.log      # Combined log (all levels)
├── errors-YYYY-MM-DD.log          # Error messages only
├── warnings-YYYY-MM-DD.log        # Warning messages only
├── critical-YYYY-MM-DD.log        # Critical messages only
├── debug-YYYY-MM-DD.log           # Debug messages only
├── trace-YYYY-MM-DD.log           # Trace messages only
├── audit/
│   └── audit-YYYY-MM.jsonl        # Audit trail (monthly)
└── structured/
    └── structured-YYYY-MM-DD.jsonl # Structured JSON logs
```

## Quick Start

### 1. Basic Logging

```powershell
# Import the centralized logging module
Import-Module ./domains/utilities/CentralizedLogging.psm1

# Simple logging
Write-Log "Application started" -Level Information

# With additional data
Write-Log "User logged in" -Level Information -Data @{
    Username = "john.doe"
    IPAddress = "192.168.1.100"
}

# Error with exception
try {
    # Some operation
} catch {
    Write-ErrorLog "Operation failed" -Exception $_.Exception
}
```

### 2. Using Convenience Functions

```powershell
Write-TraceLog "Entering detailed execution path"
Write-DebugLog "Variable value: x = 42"
Write-InfoLog "Processing completed successfully"
Write-WarningLog "Resource usage approaching limit"
Write-ErrorLog "Failed to connect to database"
Write-CriticalLog "System component unavailable"
```

### 3. Operation Tracking

```powershell
# Start a tracked operation
$operation = Start-LoggedOperation -Name "DataProcessing" -Description "Processing batch data"

# Do your work here
Process-Data

# Stop the operation (automatically logs duration and performance metrics)
Stop-LoggedOperation -Operation $operation -Success $true -Data @{
    RecordsProcessed = 1000
}
```

### 4. Test Result Logging

```powershell
Write-TestResultLog `
    -TestName "UserAuthentication" `
    -TestType "Unit" `
    -Result "Passed" `
    -Duration 1.5 `
    -Details @{
        Assertions = 5
        Coverage = "95%"
    }
```

### 5. Code Analysis Logging

```powershell
Write-CodeAnalysisLog `
    -FilePath "scripts/MyScript.ps1" `
    -Severity "Warning" `
    -RuleName "PSAvoidUsingCmdletAliases" `
    -Message "Alias 'ls' used instead of Get-ChildItem" `
    -Details @{
        Line = 42
        Column = 5
    }
```

## Dashboard Usage

### Interactive Dashboard

Display the centralized dashboard with all sections:

```powershell
# Show dashboard with all sections
./Show-Dashboard.ps1 -ShowAll

# Show dashboard with auto-refresh every 30 seconds
./Show-Dashboard.ps1 -ShowAll -RefreshInterval 30

# Show only logs and tests
./Show-Dashboard.ps1 -ShowLogs -ShowTests

# Show only specific sections
./Show-Dashboard.ps1 -ShowAnalysis -ShowMetrics
```

### Export Reports

Generate comprehensive reports in various formats:

```powershell
# Export HTML report with all sections
./Show-Dashboard.ps1 -Export -Format HTML -ShowAll

# Export JSON report
./Show-Dashboard.ps1 -Export -Format JSON -ShowAll

# Export Markdown report
./Show-Dashboard.ps1 -Export -Format Markdown -ShowAll

# Export specific sections only
./Show-Dashboard.ps1 -Export -Format HTML -ShowTests -ShowAnalysis
```

### Log Summary

View a quick summary of log activity:

```powershell
Import-Module ./domains/utilities/CentralizedLogging.psm1
Show-LogSummary
```

## Module Reference

### CentralizedLogging Module

**Location**: `domains/utilities/CentralizedLogging.psm1`

#### Functions

##### Write-Log
Main logging function with automatic source detection.

**Parameters**:
- `Message` (string, required): The message to log
- `Level` (string): Log level (Trace, Debug, Information, Warning, Error, Critical)
- `Data` (hashtable): Additional structured data
- `Exception` (Exception): Exception object to log
- `Source` (string): Source component (auto-detected if not specified)

**Example**:
```powershell
Write-Log "Configuration loaded" -Level Information -Data @{
    ConfigFile = "config.psd1"
    SettingsCount = 42
}
```

##### Convenience Functions
- `Write-TraceLog`: Log trace-level message
- `Write-DebugLog`: Log debug-level message
- `Write-InfoLog`: Log information-level message
- `Write-WarningLog`: Log warning-level message
- `Write-ErrorLog`: Log error-level message
- `Write-CriticalLog`: Log critical-level message

##### Start-LoggedOperation
Start a tracked operation with automatic performance metrics.

**Parameters**:
- `Name` (string, required): Operation name
- `Description` (string): Operation description
- `Data` (hashtable): Additional data to log
- `Source` (string): Source component

**Returns**: Operation object to pass to `Stop-LoggedOperation`

**Example**:
```powershell
$op = Start-LoggedOperation -Name "Deployment" -Description "Deploying to production"
# Do work...
Stop-LoggedOperation -Operation $op -Success $true
```

##### Stop-LoggedOperation
Complete a tracked operation and log results.

**Parameters**:
- `Operation` (hashtable, required): Operation object from `Start-LoggedOperation`
- `Success` (bool): Whether the operation succeeded
- `Data` (hashtable): Additional data to log
- `Source` (string): Source component

##### Write-TestResultLog
Log test execution results.

**Parameters**:
- `TestName` (string, required): Name of the test
- `TestType` (string): Type (Unit, Integration, E2E, Performance, Security, Syntax)
- `Result` (string, required): Result (Passed, Failed, Skipped, Inconclusive)
- `Duration` (double): Test duration in seconds
- `Details` (hashtable): Additional test details

##### Write-CodeAnalysisLog
Log code analysis results.

**Parameters**:
- `AnalyzerType` (string): Type of analyzer (default: PSScriptAnalyzer)
- `FilePath` (string, required): File being analyzed
- `Severity` (string): Issue severity (Error, Warning, Information)
- `RuleName` (string, required): Rule that was violated
- `Message` (string): Issue message
- `Details` (hashtable): Additional details

##### Get-CentralizedLogPath
Get the current centralized log directory path.

**Returns**: String path to log directory

##### Show-LogSummary
Display a summary of recent log activity.

**Parameters**:
- `Hours` (int): Number of hours to look back (default: 24)

### CentralizedReporting Module

**Location**: `domains/utilities/CentralizedReporting.psm1`

#### Functions

##### Show-CentralizedDashboard
Display unified centralized dashboard.

**Parameters**:
- `RefreshInterval` (int): Auto-refresh interval in seconds (0 = no refresh)
- `ShowTests` (switch): Include test results section
- `ShowAnalysis` (switch): Include code analysis section
- `ShowLogs` (switch): Include recent logs section (default: true)
- `ShowMetrics` (switch): Include system metrics section
- `ShowAll` (switch): Show all sections

**Example**:
```powershell
Show-CentralizedDashboard -ShowAll -RefreshInterval 30
```

##### Export-CentralizedReport
Export comprehensive centralized report.

**Parameters**:
- `OutputPath` (string): Path for the report file
- `Format` (string): Report format (HTML, JSON, Markdown)
- `IncludeTests` (switch): Include test results
- `IncludeAnalysis` (switch): Include code analysis
- `IncludeLogs` (switch): Include log summary
- `IncludeMetrics` (switch): Include system metrics
- `IncludeAll` (switch): Include all sections

**Returns**: String path to generated report

**Example**:
```powershell
Export-CentralizedReport -Format HTML -IncludeAll
```

##### Get-LogFileAnalysis
Analyze log files for patterns and issues.

**Parameters**:
- `Hours` (int): Number of hours to analyze (default: 24)

**Returns**: Hashtable with analysis results

## Core Logging Module Reference

### Logging Module

**Location**: `domains/utilities/Logging.psm1`

This is the core logging infrastructure. For most use cases, use the `CentralizedLogging` wrapper instead.

#### Key Functions

##### Write-CustomLog
Core logging function used by the centralized logging wrapper.

**Parameters**:
- `Level` (string, required): Log level
- `Message` (string, required): Message to log
- `Source` (string): Source component
- `Data` (hashtable): Additional data
- `Exception` (Exception): Exception object

##### Write-AuditLog
Write audit trail entry for compliance tracking.

**Parameters**:
- `EventType` (string, required): Type (ScriptExecution, ConfigurationChange, AccessControl, DataModification, SystemChange, SecurityEvent)
- `Action` (string, required): Action performed
- `Target` (string): Target of the action
- `Details` (hashtable): Additional details
- `Result` (string): Result (Success, Failure, Warning)

**Example**:
```powershell
Write-AuditLog `
    -EventType 'ConfigurationChange' `
    -Action 'ModifyLogLevel' `
    -Target 'config.psd1' `
    -Result 'Success' `
    -Details @{
        OldValue = 'Information'
        NewValue = 'Debug'
    }
```

##### Write-StructuredLog
Write fully structured log entry.

**Parameters**:
- `Message` (string, required): Message
- `Properties` (hashtable): Custom properties
- `Level` (string): Log level
- `Source` (string): Source component
- `Tags` (string[]): Tags for categorization
- `CorrelationId` (string): Correlation ID for tracking
- `OperationId` (string): Operation ID
- `Metrics` (hashtable): Performance metrics

##### Search-Logs
Advanced log search with query language support.

**Parameters**:
- `Query` (string): Search query (supports key:value syntax)
- `LogTypes` (string[]): Types to search (standard, structured, audit)
- `StartTime` (datetime): Start time (default: -1 day)
- `EndTime` (datetime): End time (default: now)
- `MaxResults` (int): Maximum results to return (default: 1000)

**Example**:
```powershell
# Search for errors from specific source
Search-Logs -Query "level:Error AND source:DatabaseModule" -StartTime (Get-Date).AddHours(-2)

# Search audit logs
Search-Logs -Query "EventType:ConfigurationChange" -LogTypes @('audit')
```

##### Export-LogReport
Export logs in various report formats.

**Parameters**:
- `StartTime` (datetime): Start time (default: -7 days)
- `EndTime` (datetime): End time (default: now)
- `Format` (string): Format (HTML, CSV, JSON, PDF)
- `OutputPath` (string): Output directory
- `IncludeAudit` (switch): Include audit logs
- `IncludeMetrics` (switch): Include performance metrics
- `GroupBySource` (switch): Group by source component

**Returns**: String path to generated report

## Configuration

The logging system is configured in `config.psd1`:

```powershell
Logging = @{
    Level = 'Information'              # Minimum log level
    Path = './logs'                    # Log directory
    Targets = @('Console', 'File')    # Output targets
    RetentionDays = 30                # Log retention period
    SeparateLogFiles = $true          # Create separate files by level

    CentralizedLogging = @{
        Enabled = $true
        AutoDetectSource = $true       # Auto-detect calling script
        LogTestResults = $true         # Auto-log test results
        LogCodeAnalysis = $true        # Auto-log analysis results
        LogOperations = $true          # Track operations
    }

    AuditLogging = @{
        Enabled = $true
        Level = 'All'
        ComplianceMode = $true
        RetentionDays = 90
    }
}
```

## Best Practices

### 1. Use Appropriate Log Levels

- **Trace**: Very detailed diagnostic information
- **Debug**: Detailed information for debugging
- **Information**: General informational messages
- **Warning**: Potentially harmful situations
- **Error**: Error events that might still allow the application to continue
- **Critical**: Critical events that require immediate attention

### 2. Include Structured Data

Always include relevant structured data with your logs:

```powershell
Write-Log "User action completed" -Level Information -Data @{
    Action = "UpdateProfile"
    UserId = $userId
    Duration = $duration
    Success = $true
}
```

### 3. Use Operation Tracking for Long-Running Tasks

```powershell
$op = Start-LoggedOperation -Name "BatchProcessing" -Description "Processing 10,000 records"
try {
    # Do work
    Stop-LoggedOperation -Operation $op -Success $true -Data @{
        RecordsProcessed = 10000
    }
} catch {
    Stop-LoggedOperation -Operation $op -Success $false -Data @{
        Error = $_.Exception.Message
    }
}
```

### 4. Log Exceptions with Context

```powershell
try {
    Connect-Database -Server $server
} catch {
    Write-ErrorLog "Database connection failed" -Exception $_.Exception -Data @{
        Server = $server
        Database = $database
        Timeout = $timeout
    }
}
```

### 5. Use Custom Sources for Better Organization

```powershell
Write-Log "Cache invalidated" -Level Information -Source "CacheManager"
Write-Log "Query executed" -Level Debug -Source "DatabaseLayer"
```

## Integration with Testing Framework

The centralized logging system automatically integrates with the testing framework. Test results are automatically logged when using the TestingFramework module.

To manually log test results:

```powershell
Write-TestResultLog `
    -TestName "MyTest" `
    -TestType "Unit" `
    -Result "Passed" `
    -Duration 2.5
```

## Integration with Code Analysis

PSScriptAnalyzer results are automatically logged when running code analysis. To manually log analysis results:

```powershell
Write-CodeAnalysisLog `
    -FilePath $file `
    -Severity "Warning" `
    -RuleName $rule `
    -Message $message
```

## Viewing Logs

### 1. Using the Dashboard

```powershell
./Show-Dashboard.ps1 -ShowAll
```

### 2. Direct File Access

Logs are stored as plain text files in `./logs/` and can be viewed with any text editor or command-line tools:

```powershell
# View today's combined log
Get-Content ./logs/aitherzero-$(Get-Date -Format 'yyyy-MM-dd').log

# View today's errors only
Get-Content ./logs/errors-$(Get-Date -Format 'yyyy-MM-dd').log

# Monitor logs in real-time
Get-Content ./logs/aitherzero-$(Get-Date -Format 'yyyy-MM-dd').log -Wait -Tail 20
```

### 3. Using Search

```powershell
Import-Module ./domains/utilities/Logging.psm1

# Search for specific errors
Search-Logs -Query "level:Error AND source:Database"

# Search in the last hour
Search-Logs -Query "level:Warning" -StartTime (Get-Date).AddHours(-1)
```

### 4. Exporting Reports

```powershell
# Export HTML report
Export-LogReport -Format HTML -IncludeAudit

# Export CSV for analysis
Export-LogReport -Format CSV -StartTime (Get-Date).AddDays(-7)
```

## Examples

See `examples/CentralizedLogging-Example.ps1` for comprehensive examples of all logging features.

To run the examples:

```powershell
./examples/CentralizedLogging-Example.ps1
```

## Troubleshooting

### Logs Not Appearing

1. Check that the `./logs` directory exists and is writable
2. Verify the log level in `config.psd1` is not set too high
3. Ensure the logging module is imported correctly

### Dashboard Not Showing Data

1. Verify test results exist in `./tests/results/`
2. Verify analysis results exist in `./tests/analysis/`
3. Check that log files exist in `./logs/`

### Performance Issues

1. Adjust log level to reduce verbosity (use Information or Warning instead of Debug/Trace)
2. Enable log rotation if files are getting too large
3. Reduce the `RetentionDays` setting to automatically clean up old logs

## Support

For issues or questions about the centralized logging system:

1. Review this documentation
2. Check `examples/CentralizedLogging-Example.ps1` for working examples
3. Review the module source code in `domains/utilities/`
4. File an issue in the AitherZero repository

---

**Copyright © 2025 Aitherium Corporation**
