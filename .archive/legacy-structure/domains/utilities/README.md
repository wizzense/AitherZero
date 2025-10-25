# Utilities Domain

The Utilities domain provides common services and helper functions used across all other domains.

## Responsibilities

- Unified logging service
- Performance monitoring and tracing
- Common helper functions
- Cross-platform compatibility utilities
- Error handling and retry logic

## Key Modules

### Logging.psm1
Provides structured logging capabilities for all components.

**Public Functions:**
- `Write-CustomLog` - Write structured log entries
- `Get-LogPath` - Get current log file path
- `Clear-Logs` - Clear old log files
- `Set-LogLevel` - Configure logging verbosity
- `Enable-LogRotation` - Enable automatic log rotation

## Usage Examples

```powershell
# Import the core module
Import-Module ./aitherzero.psm1

# Write a log entry
Write-CustomLog -Level "Information" -Message "Starting VM creation" -Source "Lab"

# Write with structured data
Write-CustomLog -Level "Error" -Message "Failed to create VM" -Data @{
    VMName = "TestVM"
    Error = $_.Exception.Message
}

# Set log level
Set-LogLevel -Level "Debug"

# Enable log rotation
Enable-LogRotation -MaxSizeMB 100 -MaxFiles 10
```

## Log Levels

1. **Trace** - Detailed diagnostic information
2. **Debug** - Debugging information
3. **Information** - General informational messages
4. **Warning** - Warning messages
5. **Error** - Error messages
6. **Critical** - Critical failure messages

## Log Output Formats

The logging module supports multiple output formats:
- Console output with color coding
- File output in JSON format
- File output in plain text
- Event log integration (Windows)

## Performance Considerations

- Logs are buffered for performance
- Asynchronous writing for file outputs
- Automatic compression of rotated logs
- Configurable retention policies