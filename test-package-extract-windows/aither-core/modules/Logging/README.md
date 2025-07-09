# Logging Module v2.1.0

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
| Unit Tests | ✅ PASS | 5/5 | 0% | 0.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 5/5 | 0% | 0.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 5/5 | 0% | 0.5s |

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
| Unit Tests | ✅ PASS | 15/15 | 85.5% | 2.3s |

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
| Unit Tests | ❌ FAIL | 48/50 | 0% | 15.7s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Module Overview

The Logging module provides a comprehensive, enterprise-grade centralized logging system for AitherZero. It serves as the foundation for all logging operations across the framework, offering structured logging capabilities with multiple output targets, performance tracking, and call stack tracing.

**NEW in v2.1.0: PowerShell 7+ Modernization**
- Modern null-coalescing operators for cleaner code
- Enhanced exception logging with inner exception chains  
- Thread-safe file operations with mutex locking
- Bulk logging with parallel processing capabilities
- Built-in performance testing and monitoring
- Modern environment variable naming (AITHER_*) with backward compatibility

### Primary Purpose and Architecture

- **Centralized logging** for all AitherZero modules and operations
- **Thread-safe operations** for concurrent execution environments  
- **Cross-platform compatibility** (Windows, Linux, macOS)
- **Multiple output targets** (console, file, custom handlers)
- **Structured logging** with contextual information and metadata
- **Performance tracking** with operation timing and metrics
- **Automatic log rotation** to manage disk space

### Key Capabilities and Features

- **Multiple log levels**: SILENT, ERROR, WARN, INFO, SUCCESS, DEBUG, TRACE, VERBOSE
- **Configurable output formats**: Structured, Simple, JSON
- **Real-time filtering** based on log level for console and file outputs
- **Context enrichment** with script location, line numbers, and call stacks
- **Exception handling** with detailed error information and inner exception chains
- **Performance tracing** for operation timing and analysis (enabled by default)
- **Environment-based configuration** via AITHER_* or LAB_* environment variables
- **Automatic initialization** on module import
- **Bulk logging** with sequential or parallel processing
- **Built-in performance testing** and monitoring capabilities
- **Thread-safe operations** with mutex-based file locking
- **Modern PowerShell 7+ features** including null-coalescing operators

### Integration Patterns

```powershell
# Import the module
Import-Module ./aither-core/modules/Logging -Force

# Initialize with custom settings
Initialize-LoggingSystem -LogLevel "DEBUG" -EnableTrace -EnablePerformance

# Basic logging
Write-CustomLog -Message "Operation started" -Level "INFO"

# Context-aware logging
Write-CustomLog -Message "Processing file" -Level "INFO" -Context @{
    FileName = "test.ps1"
    Size = "1024KB"
}

# Performance tracking
Start-PerformanceTrace -Name "DatabaseQuery"
# ... perform operation ...
Stop-PerformanceTrace -Name "DatabaseQuery"
```

## Directory Structure

```
Logging/
├── Logging.psd1           # Module manifest
├── Logging.psm1           # Main module script
├── Public/                # Exported functions
│   └── Import-ProjectModule.ps1  # Helper for importing project modules
└── README.md              # This documentation
```

### Module Organization

- **Logging.psd1**: Module manifest defining dependencies, version, and exports
- **Logging.psm1**: Core logging functionality and configuration management
- **Public/**: Contains additional exported utility functions
- **Import-ProjectModule.ps1**: Utility function for loading other AitherZero modules with logging integration

## API Reference

### Main Functions

#### Write-CustomLog
Writes a log message with full context and formatting options.

```powershell
Write-CustomLog -Message <string> [-Level <string>] [-Source <string>] 
                [-Context <hashtable>] [-AdditionalData <hashtable>]
                [-Category <string>] [-EventId <int>] [-NoConsole] 
                [-NoFile] [-Exception <Exception>]
```

**Parameters:**
- `Message` (string, required): The log message to write
- `Level` (string): Log level (ERROR, WARN, INFO, SUCCESS, DEBUG, TRACE, VERBOSE). Default: INFO
- `Source` (string): Source identifier for the log entry
- `Context` (hashtable): Contextual key-value pairs
- `AdditionalData` (hashtable): Additional metadata (merged with Context)
- `Category` (string): Log category for filtering
- `EventId` (int): Numeric event identifier
- `NoConsole` (switch): Skip console output
- `NoFile` (switch): Skip file output
- `Exception` (Exception): Exception object to log with stack trace

**Returns:** None

**Example:**
```powershell
Write-CustomLog -Message "User authentication failed" -Level "ERROR" -Context @{
    UserName = "john.doe"
    IPAddress = "192.168.1.100"
    Attempts = 3
} -Exception $_.Exception
```

#### Initialize-LoggingSystem
Initializes the logging system with configuration options.

```powershell
Initialize-LoggingSystem [-LogPath <string>] [-LogLevel <string>] 
                        [-ConsoleLevel <string>] [-EnableTrace] 
                        [-EnablePerformance] [-Force]
```

**Parameters:**
- `LogPath` (string): Custom log file path
- `LogLevel` (string): File logging level threshold
- `ConsoleLevel` (string): Console output level threshold
- `EnableTrace` (switch): Enable trace-level logging
- `EnablePerformance` (switch): Enable performance tracking
- `Force` (switch): Force re-initialization

**Returns:** None

**Example:**
```powershell
Initialize-LoggingSystem -LogPath "C:\Logs\AitherZero.log" -LogLevel "DEBUG" -EnablePerformance
```

#### Start-PerformanceTrace / Stop-PerformanceTrace
Track performance of operations with timing metrics.

```powershell
Start-PerformanceTrace -Name <string> [-OperationName <string>] [-Context <hashtable>]
Stop-PerformanceTrace -Name <string> [-OperationName <string>] [-AdditionalContext <hashtable>]
```

**Parameters:**
- `Name`/`OperationName` (string): Unique identifier for the operation
- `Context` (hashtable): Initial context data
- `AdditionalContext` (hashtable): Additional context at completion

**Returns:** Performance result object with timing information

**Example:**
```powershell
Start-PerformanceTrace -Name "FileProcessing" -Context @{ FileCount = 100 }
# Process files...
$result = Stop-PerformanceTrace -Name "FileProcessing" -AdditionalContext @{ ProcessedCount = 95 }
Write-Host "Operation took $($result.ElapsedMilliseconds)ms"
```

#### Write-TraceLog
Writes trace-level logging with enhanced context information.

```powershell
Write-TraceLog -Message <string> [-Context <hashtable>] [-Category <string>]
```

**Parameters:**
- `Message` (string): Trace message
- `Context` (hashtable): Additional context
- `Category` (string): Trace category

**Returns:** None

#### Write-DebugContext
Writes debug information with variable context.

```powershell
Write-DebugContext [-Message <string>] [-Variables <hashtable>] 
                   [-Context <string>] [-Scope <string>]
```

**Parameters:**
- `Message` (string): Debug message. Default: "Debug Context Information"
- `Variables` (hashtable): Variables to include in debug output
- `Context`/`Scope` (string): Scope identifier. Default: "Local"

**Returns:** None

#### Get-LoggingConfiguration / Set-LoggingConfiguration
Get or update logging configuration at runtime.

```powershell
Get-LoggingConfiguration

Set-LoggingConfiguration [-LogLevel <string>] [-ConsoleLevel <string>] 
                        [-LogFilePath <string>] [-EnableTrace] 
                        [-DisableTrace] [-EnablePerformance] 
                        [-DisablePerformance]
```

#### Write-BulkLog (NEW in v2.1.0)
Write multiple log entries efficiently with optional parallel processing.

```powershell
Write-BulkLog -LogEntries <object[]> [-DefaultLevel <string>] 
              [-DefaultContext <hashtable>] [-Parallel]
```

**Parameters:**
- `LogEntries` (object[], required): Array of log entry objects
- `DefaultLevel` (string): Default log level for entries without level. Default: INFO
- `DefaultContext` (hashtable): Default context for entries without context
- `Parallel` (switch): Use parallel processing for large batches (>10 entries)

**Returns:** None

**Example:**
```powershell
$entries = @(
    @{ Message = "Process started"; Level = "INFO"; Context = @{ProcessId = 1234} }
    @{ Message = "Warning condition"; Level = "WARN" }
    @{ Message = "Process completed"; Level = "SUCCESS" }
)
Write-BulkLog -LogEntries $entries -Parallel
```

#### Test-LoggingPerformance (NEW in v2.1.0)
Test logging system performance and return detailed metrics.

```powershell
Test-LoggingPerformance [-MessageCount <int>] [-FileOnly] [-ConsoleOnly]
```

**Parameters:**
- `MessageCount` (int): Number of test messages to log. Default: 1000
- `FileOnly` (switch): Test file logging performance only
- `ConsoleOnly` (switch): Test console logging performance only

**Returns:** Performance metrics object with timing and throughput data

**Example:**
```powershell
$metrics = Test-LoggingPerformance -MessageCount 5000 -FileOnly
Write-Host "Throughput: $($metrics.MessagesPerSecond) messages/second"
Write-Host "Average latency: $($metrics.AverageTimePerMessage)ms per message"
```

## Core Concepts

### Log Levels

The module uses a hierarchical log level system:

1. **SILENT** (0): No output
2. **ERROR** (1): Critical errors requiring attention
3. **WARN** (2): Warning conditions
4. **INFO** (3): Informational messages
5. **SUCCESS** (3): Success confirmations (same priority as INFO)
6. **DEBUG** (4): Detailed debugging information
7. **TRACE** (5): Very detailed trace information
8. **VERBOSE** (6): Extremely verbose output

### Log Formatting

Three output formats are supported:

- **Structured** (default): Human-readable format with all context
- **Simple**: Basic timestamp, level, and message
- **JSON**: Machine-parseable JSON format

### Output Targets

Logs can be written to multiple targets:

- **Console**: Color-coded output based on log level
- **File**: Persistent storage with automatic rotation
- **Custom**: Extensible for additional targets

### Log Rotation

Automatic log rotation prevents unbounded disk usage:
- Configurable maximum file size (default: 50MB)
- Configurable file retention count (default: 10)
- Archived logs use numbered suffixes (.1, .2, etc.)

## Usage Patterns

### Common Usage Scenarios

#### Basic Application Logging
```powershell
# Module initialization
Write-CustomLog -Message "Module initialized" -Level "INFO"

# Operation tracking
Write-CustomLog -Message "Starting data import" -Level "INFO" -Source "DataImporter"
Write-CustomLog -Message "Import completed: 1000 records" -Level "SUCCESS"
```

#### Error Handling with Context
```powershell
try {
    # Risky operation
    $result = Invoke-DatabaseQuery -Query $sql
} catch {
    Write-CustomLog -Message "Database query failed" -Level "ERROR" -Context @{
        Query = $sql
        Database = $connectionString.Database
        ErrorCode = $_.Exception.HResult
    } -Exception $_.Exception
}
```

#### Performance Monitoring
```powershell
Start-PerformanceTrace -Name "BulkOperation"
foreach ($item in $items) {
    # Process item
}
$metrics = Stop-PerformanceTrace -Name "BulkOperation" -AdditionalContext @{
    ItemCount = $items.Count
    SuccessCount = $successCount
}
Write-CustomLog -Message "Bulk operation metrics" -Level "INFO" -Context $metrics
```

#### Debug Tracing
```powershell
Write-TraceLog -Message "Entering function" -Context @{
    Parameters = $PSBoundParameters
}

Write-DebugContext -Message "Variable state check" -Variables @{
    ConfigLoaded = $null -ne $config
    ItemCount = $items.Count
    CurrentIndex = $i
}
```

### Integration Examples

#### With Other AitherZero Modules
```powershell
# In PatchManager
Write-CustomLog -Message "Creating patch: $PatchDescription" -Level "INFO" -Source "PatchManager"

# In OrchestrationEngine
Start-PerformanceTrace -Name "PlaybookExecution" -Context @{
    PlaybookName = $PlaybookName
    StepCount = $steps.Count
}
```

#### Modern PowerShell 7+ Features (NEW in v2.1.0)

```powershell
# Enhanced exception logging with inner exception chains
try {
    Invoke-RiskyOperation
} catch {
    Write-CustomLog -Message "Operation failed with nested exceptions" -Level ERROR -Exception $_.Exception
    # Automatically logs full exception chain including inner exceptions
}

# Bulk logging with parallel processing
$operations = Get-LongRunningOperations
$logEntries = $operations | ForEach-Object {
    @{ 
        Message = "Processing operation $($_.Id)"
        Level = "INFO"
        Context = @{
            OperationId = $_.Id
            Duration = $_.EstimatedDuration
            Priority = $_.Priority
        }
    }
}
Write-BulkLog -LogEntries $logEntries -Parallel

# Performance monitoring and optimization
$metrics = Test-LoggingPerformance -MessageCount 10000
if ($metrics.MessagesPerSecond -lt 500) {
    Write-CustomLog -Message "Logging performance below threshold" -Level WARN -Context $metrics
    Set-LoggingConfiguration -LogLevel ERROR  # Reduce verbosity
}
```

#### With External Systems
```powershell
# API logging
Write-CustomLog -Message "API request" -Level "INFO" -Context @{
    Method = "GET"
    Endpoint = "/api/users"
    StatusCode = 200
    ResponseTime = "45ms"
}

# Batch API call logging
$apiCalls = @(
    @{ Message = "Authentication"; Level = "INFO"; Context = @{Endpoint = "/auth"} }
    @{ Message = "Data retrieval"; Level = "INFO"; Context = @{Endpoint = "/data"} }
    @{ Message = "Cache update"; Level = "SUCCESS"; Context = @{Endpoint = "/cache"} }
)
Write-BulkLog -LogEntries $apiCalls
```

### Best Practices

1. **Use appropriate log levels** to enable effective filtering
2. **Include context** for easier troubleshooting
3. **Use performance tracing** for critical operations
4. **Handle exceptions** with full error details
5. **Configure appropriate retention** for compliance
6. **Use categories** for logical grouping
7. **Enable trace only when debugging** to avoid performance impact

## Advanced Features

### Environment Variable Configuration

Configure logging via environment variables. **NEW in v2.1.0**: Modern AITHER_* naming with LAB_* fallback for backward compatibility.

```powershell
# Modern AITHER_* environment variables (recommended)
$env:AITHER_LOG_LEVEL = "DEBUG"
$env:AITHER_CONSOLE_LEVEL = "INFO"
$env:AITHER_LOG_PATH = "C:\Logs\Custom.log"
$env:AITHER_MAX_LOG_SIZE_MB = "100"
$env:AITHER_MAX_LOG_FILES = "20"
$env:AITHER_ENABLE_TRACE = "true"
$env:AITHER_ENABLE_PERFORMANCE = "true"  # Default: true
$env:AITHER_LOG_FORMAT = "JSON"
$env:AITHER_ENABLE_CALLSTACK = "true"
$env:AITHER_LOG_TO_FILE = "true"
$env:AITHER_LOG_TO_CONSOLE = "true"

# Legacy LAB_* environment variables (still supported)
$env:LAB_LOG_LEVEL = "DEBUG"
$env:LAB_CONSOLE_LEVEL = "INFO"
# ... etc (same names with LAB_ prefix)
```

**Priority Order:** AITHER_* variables take precedence over LAB_* variables, which take precedence over defaults.

### Call Stack Tracing

Automatic call stack capture for errors and debug logs:

```powershell
# Automatically included for ERROR and DEBUG levels when enabled
Write-CustomLog -Message "Critical error" -Level "ERROR"
# Output includes full call stack
```

### Thread Safety

All logging operations are thread-safe for concurrent environments:

```powershell
# Safe to use in parallel operations
1..10 | ForEach-Object -Parallel {
    Write-CustomLog -Message "Processing item $_" -Level "INFO"
}
```

## Configuration

### Module-Specific Settings

```powershell
# Runtime configuration
Set-LoggingConfiguration -LogLevel "TRACE" -EnablePerformance

# Check current configuration
$config = Get-LoggingConfiguration
Write-Host "Current log level: $($config.LogLevel)"
```

### Customization Options

1. **Custom log paths** for different environments
2. **Level filtering** separate for console and file
3. **Format selection** based on use case
4. **Performance tracking** toggle for production
5. **Trace mode** for deep debugging

### Performance Tuning Parameters

- **Disable console output** for high-throughput scenarios: `-NoConsole`
- **Disable file output** for ephemeral environments: `-NoFile`
- **Adjust rotation size** for log volume: `$env:AITHER_MAX_LOG_SIZE_MB`
- **Reduce retention** for space constraints: `$env:AITHER_MAX_LOG_FILES`
- **Disable call stacks** for performance: `$env:AITHER_ENABLE_CALLSTACK = "false"`
- **Use bulk logging** for high-volume scenarios: `Write-BulkLog -Parallel`
- **Monitor performance** with built-in testing: `Test-LoggingPerformance`

### Performance Improvements in v2.1.0

1. **Thread-safe file operations** - Mutex-based locking prevents file corruption
2. **Optimized file I/O** - Reduced overhead with streamlined writing operations
3. **Parallel bulk logging** - Process large batches efficiently with PowerShell 7+ parallelism
4. **Performance enabled by default** - Better insights without configuration
5. **Built-in performance monitoring** - Test and optimize logging throughput

**Typical Performance:**
- **File logging**: ~400-600 messages/second (depends on disk I/O)
- **Console logging**: ~1000+ messages/second
- **Parallel bulk logging**: 2-3x faster for batches >100 entries

## Integration with AitherZero

The Logging module is the foundation for all AitherZero logging:

1. **Automatic initialization** when any module loads
2. **Consistent formatting** across all components
3. **Centralized configuration** for the entire framework
4. **Performance metrics** aggregation
5. **Error correlation** across modules

Example module integration:
```powershell
# In any AitherZero module
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Message "Module loaded" -Level "INFO" -Source $MyInvocation.MyCommand.Module.Name
} else {
    Write-Host "[INFO] Module loaded"
}
```