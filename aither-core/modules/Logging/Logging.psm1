#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive centralized logging system for AitherZero

.DESCRIPTION
    Enterprise-grade logging module providing:
    - Multiple log levels with filtering
    - Structured logging with context
    - File and console output
    - Performance tracking
    - Call stack tracing
    - Module/function context
    - Configurable output formats
    - Log rotation and archiving
    - Debug trace capabilities

.NOTES
    - Thread-safe logging operations
    - Configurable via environment variables
    - Full trace capabilities for debugging
    - Cross-platform compatibility
#>

# Module-level variables for logging configuration
# Modern environment variable naming (AITHER_*) with LAB_* fallback for compatibility
$script:LoggingConfig = @{
    LogLevel = ($env:AITHER_LOG_LEVEL ?? $env:LAB_LOG_LEVEL ?? "INFO")
    ConsoleLevel = ($env:AITHER_CONSOLE_LEVEL ?? $env:LAB_CONSOLE_LEVEL ?? "INFO")
    LogFilePath = if ($env:AITHER_LOG_PATH ?? $env:LAB_LOG_PATH) {
        $env:AITHER_LOG_PATH ?? $env:LAB_LOG_PATH
    } elseif ($env:TEMP) {
        (Join-Path $env:TEMP "AitherZero.log")
    } elseif (Test-Path '/tmp') {
        "/tmp/AitherZero.log"
    } else {
        (Join-Path (Get-Location) "logs/AitherZero.log")
    }
    MaxLogSizeMB = [int]($env:AITHER_MAX_LOG_SIZE_MB ?? $env:LAB_MAX_LOG_SIZE_MB ?? 50)
    MaxLogFiles = [int]($env:AITHER_MAX_LOG_FILES ?? $env:LAB_MAX_LOG_FILES ?? 10)
    EnableTrace = [bool]::Parse(($env:AITHER_ENABLE_TRACE ?? $env:LAB_ENABLE_TRACE ?? 'false'))
    EnablePerformance = [bool]::Parse(($env:AITHER_ENABLE_PERFORMANCE ?? $env:LAB_ENABLE_PERFORMANCE ?? 'true'))  # Enable by default for better insights
    LogFormat = ($env:AITHER_LOG_FORMAT ?? $env:LAB_LOG_FORMAT ?? "Structured") # Structured, Simple, JSON
    EnableCallStack = [bool]::Parse(($env:AITHER_ENABLE_CALLSTACK ?? $env:LAB_ENABLE_CALLSTACK ?? 'true'))
    LogToFile = [bool]::Parse(($env:AITHER_LOG_TO_FILE ?? $env:LAB_LOG_TO_FILE ?? 'true'))
    LogToConsole = [bool]::Parse(($env:AITHER_LOG_TO_CONSOLE ?? $env:LAB_LOG_TO_CONSOLE ?? 'true'))
    Initialized = $false  # Track initialization state
}

# Log level hierarchy (higher numbers = more verbose)
$script:LogLevels = @{
    "SILENT" = 0
    "ERROR" = 1
    "WARN" = 2
    "INFO" = 3
    "SUCCESS" = 3
    "DEBUG" = 4
    "TRACE" = 5
    "VERBOSE" = 6
}

# Performance tracking
$script:PerformanceCounters = @{}
$script:CallStack = @()

function Initialize-LoggingSystem {
    <#
    .SYNOPSIS
        Initialize the logging system with configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$LogPath,

        [Parameter()]
        [ValidateSet("SILENT", "ERROR", "WARN", "INFO", "DEBUG", "TRACE", "VERBOSE")]
        [string]$LogLevel = "INFO",

        [Parameter()]
        [ValidateSet("SILENT", "ERROR", "WARN", "INFO", "DEBUG", "TRACE", "VERBOSE")]
        [string]$ConsoleLevel = "INFO",

        [Parameter()]
        [switch]$EnableTrace,

        [Parameter()]
        [switch]$EnablePerformance,

        [Parameter()]
        [switch]$Force
    )
      # Check if already initialized (unless forced)
    if ($script:LoggingConfig.Initialized -and -not $Force.IsPresent) {
        # Silently return if already initialized
        return
    }

    # Store previous initialization state to control messaging
    $wasInitialized = $script:LoggingConfig.Initialized

    if ($LogPath) { $script:LoggingConfig.LogFilePath = $LogPath }
    $script:LoggingConfig.LogLevel = $LogLevel
    $script:LoggingConfig.ConsoleLevel = $ConsoleLevel
    $script:LoggingConfig.EnableTrace = $EnableTrace.IsPresent
    $script:LoggingConfig.EnablePerformance = $EnablePerformance.IsPresent

    # Ensure log directory exists
    $logDir = Split-Path $script:LoggingConfig.LogFilePath -Parent
    if (-not (Test-Path $logDir)) {
        if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
    }

    # Initialize log file with session header
    $sessionHeader = @"
================================================================================
AitherZero - New Session Started
================================================================================
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
PowerShell Version: $($PSVersionTable.PSVersion)
OS: $($PSVersionTable.OS)
Platform: $($PSVersionTable.Platform)
User: $env:USERNAME
Machine: $env:COMPUTERNAME
Working Directory: $(Get-Location)
Log Level: $($script:LoggingConfig.LogLevel)
Console Level: $($script:LoggingConfig.ConsoleLevel)
Trace Enabled: $($script:LoggingConfig.EnableTrace)
Performance Tracking: $($script:LoggingConfig.EnablePerformance)
================================================================================

"@
      if ($script:LoggingConfig.LogToFile) {
        Add-Content -Path $script:LoggingConfig.LogFilePath -Value $sessionHeader -Encoding UTF8
    }
      # Mark as initialized
    $script:LoggingConfig.Initialized = $true

    # Only show initialization message if this is the first time or forced
    if (-not $wasInitialized -or $Force.IsPresent) {
        Write-CustomLog "Logging system initialized" -Level SUCCESS
    }
}

function Write-CustomLog {
    <#
    .SYNOPSIS
        Enhanced centralized logging function with full tracing capabilities
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter()]
        [ValidateSet("ERROR", "WARN", "WARNING", "INFO", "SUCCESS", "DEBUG", "TRACE", "VERBOSE")]
        [string]$Level = "INFO",

        [Parameter()]
        [string]$Source,

        [Parameter()]
        [hashtable]$Context = @{},

        [Parameter()]
        [hashtable]$AdditionalData = @{},

        [Parameter()]
        [string]$Category,

        [Parameter()]
        [int]$EventId,

        [Parameter()]
        [switch]$NoConsole,

        [Parameter()]
        [switch]$NoFile,

        [Parameter()]
        [Exception]$Exception
    )

    # Check if we should log this level
    $currentLogLevel = $script:LogLevels[$script:LoggingConfig.LogLevel]
    # Convert WARNING to WARN for backward compatibility
    if ($Level -eq "WARNING") { $Level = "WARN" }
    $currentConsoleLevel = $script:LogLevels[$script:LoggingConfig.ConsoleLevel]
    $messageLevel = $script:LogLevels[$Level]

    if ($messageLevel -gt $currentLogLevel -and $messageLevel -gt $currentConsoleLevel) {
        return # Skip logging if message level is too verbose for both outputs
    }
      # Get caller information for context
    $caller = Get-PSCallStack | Select-Object -Skip 1 -First 1
    if (-not $Source) {
        $Source = if ($caller.FunctionName -eq '<ScriptBlock>' -and $caller.ScriptName) {
            Split-Path $caller.ScriptName -Leaf
        } elseif ($caller.FunctionName -ne '<ScriptBlock>') {
            "$($caller.FunctionName)"
        } else {
            "PowerShell"
        }
    }

    # Build structured log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $processId = $PID
    $threadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId

    # Create base log object
    $logEntry = @{
        Timestamp = $timestamp
        Level = $Level
        Message = $Message
        Source = $Source
        ProcessId = $processId
        ThreadId = $threadId
        ScriptName = if ($caller.ScriptName) { Split-Path $caller.ScriptName -Leaf } else { "Interactive" }
        LineNumber = $caller.ScriptLineNumber
        FunctionName = $caller.FunctionName
    }
      # Add context information
    if ($Context.Count -gt 0 -or $AdditionalData.Count -gt 0) {
        # Merge Context and AdditionalData, with AdditionalData taking precedence
        $mergedContext = @{}
        foreach ($key in $Context.Keys) {
            $mergedContext[$key] = $Context[$key]
        }
        foreach ($key in $AdditionalData.Keys) {
            $mergedContext[$key] = $AdditionalData[$key]
        }
        $logEntry.Context = $mergedContext
    }

    if ($Category) {
        $logEntry.Category = $Category
    }

    if ($EventId) {
        $logEntry.EventId = $EventId
    }

    # Add call stack if enabled
    if ($script:LoggingConfig.EnableCallStack -and $Level -in @("ERROR", "DEBUG", "TRACE")) {
        $callStack = Get-PSCallStack | Select-Object -Skip 1 | ForEach-Object {
            "$($_.FunctionName) at $($_.ScriptName):$($_.ScriptLineNumber)"
        }
        $logEntry.CallStack = $callStack
    }

    # Add exception details if provided (enhanced with PowerShell 7+ features)
    if ($Exception) {
        $logEntry.Exception = @{
            Type = $Exception.GetType().FullName
            Message = $Exception.Message
            StackTrace = $Exception.StackTrace
            InnerException = if ($Exception.InnerException) { $Exception.InnerException.Message } else { $null }
            HResult = $Exception.HResult
            HelpLink = $Exception.HelpLink
            Source = $Exception.Source
            TargetSite = if ($Exception.TargetSite) { $Exception.TargetSite.Name } else { $null }
            Data = if ($Exception.Data.Count -gt 0) {
                $Exception.Data | ConvertTo-Json -Compress -ErrorAction SilentlyContinue
            } else {
                $null
            }
        }

        # Add inner exception chain for better debugging
        $innerExceptions = @()
        $currentException = $Exception.InnerException
        while ($currentException) {
            $innerExceptions += @{
                Type = $currentException.GetType().FullName
                Message = $currentException.Message
            }
            $currentException = $currentException.InnerException
        }
        if ($innerExceptions.Count -gt 0) {
            $logEntry.Exception.InnerExceptionChain = $innerExceptions
        }
    }

    # Format for console output
    $consoleMessage = Format-ConsoleMessage -LogEntry $logEntry

    # Format for file output
    $fileMessage = Format-FileMessage -LogEntry $logEntry

    # Output to console if appropriate
    if ($script:LoggingConfig.LogToConsole -and -not $NoConsole.IsPresent -and $messageLevel -le $currentConsoleLevel) {
        $color = Get-LogColor -Level $Level
        Write-Host $consoleMessage -ForegroundColor $color
    }

    # Output to file if appropriate (optimized with better error handling)
    if ($script:LoggingConfig.LogToFile -and -not $NoFile.IsPresent -and $messageLevel -le $currentLogLevel) {
        try {
            # Check if log rotation is needed (optimized check)
            $logFile = $script:LoggingConfig.LogFilePath
            
            # Defensive check: If logFile is null/empty, initialize with default path
            if (-not $logFile) {
                $logFile = if ($env:TEMP) {
                    (Join-Path $env:TEMP "AitherZero.log")
                } else {
                    "AitherZero.log"
                }
                $script:LoggingConfig.LogFilePath = $logFile
                Write-Host "[LOG] Using default log file path: $logFile" -ForegroundColor Yellow
            }
            
            if ((Test-Path $logFile -PathType Leaf) -and
                (Get-Item $logFile -ErrorAction SilentlyContinue)?.Length -gt ($script:LoggingConfig.MaxLogSizeMB * 1MB)) {
                Invoke-LogRotation
            }

            # Use StreamWriter for better performance with large volumes
            $logDir = Split-Path $logFile -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }

            # Thread-safe file writing
            $mutex = [System.Threading.Mutex]::new($false, "AitherZeroLogMutex")
            try {
                if ($mutex.WaitOne(1000)) {  # 1 second timeout
                    Add-Content -Path $logFile -Value $fileMessage -Encoding UTF8 -ErrorAction Stop
                } else {
                    throw "Timeout waiting for log file access"
                }
            } finally {
                $mutex.ReleaseMutex()
                $mutex.Dispose()
            }
        }
        catch {
            # Enhanced fallback with structured error information
            $errorDetails = @{
                Error = $_.Exception.Message
                LogFile = $script:LoggingConfig.LogFilePath
                ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            }
            Write-Host "[LOG ERROR] Failed to write to log file: $($errorDetails | ConvertTo-Json -Compress)" -ForegroundColor Red
        }
    }
}

function Format-ConsoleMessage {
    [CmdletBinding()]
    param([hashtable]$LogEntry)

    $source = if ($LogEntry.Source.Length -gt 20) {
        $LogEntry.Source.Substring(0, 17) + "..."
    } else {
        $LogEntry.Source.PadRight(20)
    }

    $levelPadded = $LogEntry.Level.PadRight(7)

    $message = "[$($LogEntry.Timestamp)] [$levelPadded] [$source] $($LogEntry.Message)"

    # Add context if present
    if ($LogEntry.Context -and $LogEntry.Context.Count -gt 0) {
        $contextStr = ($LogEntry.Context.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "
        $message += " {$contextStr}"
    }

    return $message
}

function Format-FileMessage {
    [CmdletBinding()]
    param([hashtable]$LogEntry)

    switch ($script:LoggingConfig.LogFormat) {
        "JSON" {
            return ($LogEntry | ConvertTo-Json -Compress)
        }
        "Simple" {
            return "[$($LogEntry.Timestamp)] [$($LogEntry.Level)] $($LogEntry.Message)"
        }
        default { # Structured
            $parts = @(
                "[$($LogEntry.Timestamp)]"
                "[$($LogEntry.Level)]"
                "[PID:$($LogEntry.ProcessId)]"
                "[TID:$($LogEntry.ThreadId)]"
                "[$($LogEntry.Source)]"
                "[$($LogEntry.ScriptName):$($LogEntry.LineNumber)]"
                "$($LogEntry.Message)"
            )

            # Add context
            if ($LogEntry.Context -and $LogEntry.Context.Count -gt 0) {
                $contextStr = ($LogEntry.Context.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "
                $parts += "{$contextStr}"
            }

            # Add call stack for errors/debug
            if ($LogEntry.CallStack) {
                $parts += "CallStack: $($LogEntry.CallStack -join ' -> ')"
            }

            # Add exception details
            if ($LogEntry.Exception) {
                $parts += "Exception: $($LogEntry.Exception.Type) - $($LogEntry.Exception.Message)"
                if ($LogEntry.Exception.StackTrace) {
                    $parts += "StackTrace: $($LogEntry.Exception.StackTrace)"
                }
            }

            return $parts -join " "
        }
    }
}

function Get-LogColor {
    [CmdletBinding()]
    param([string]$Level)

    switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "INFO" { "Cyan" }
        "DEBUG" { "DarkGray" }
        "TRACE" { "Magenta" }
        "VERBOSE" { "DarkCyan" }
        default { "White" }
    }
}

function Invoke-LogRotation {
    <#
    .SYNOPSIS
        Rotate log files when they become too large
    #>
    [CmdletBinding()]
    param()

    try {
        $logPath = $script:LoggingConfig.LogFilePath
        $logDir = Split-Path $logPath -Parent
        $logName = [System.IO.Path]::GetFileNameWithoutExtension($logPath)
        $logExt = [System.IO.Path]::GetExtension($logPath)

        # Move existing log files
        for ($i = $script:LoggingConfig.MaxLogFiles; $i -gt 1; $i--) {
            $oldFile = Join-Path $logDir "$logName.$($i-1)$logExt"
            $newFile = Join-Path $logDir "$logName.$i$logExt"

            if (Test-Path $oldFile) {
                Move-Item -Path $oldFile -Destination $newFile -Force -ErrorAction SilentlyContinue
            }
        }

        # Move current log to .1
        if (Test-Path $logPath) {
            $archiveFile = Join-Path $logDir "$logName.1$logExt"
            Move-Item -Path $logPath -Destination $archiveFile -Force -ErrorAction SilentlyContinue
        }

        # Clean up old files beyond retention
        $pattern = "$logName.*$logExt"
        Get-ChildItem -Path $logDir -Filter $pattern |
            Where-Object { $_.Name -match "$logName\.(\d+)$([regex]::Escape($logExt))$" } |
            Where-Object { [int]$Matches[1] -gt $script:LoggingConfig.MaxLogFiles } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "[LOG ERROR] Failed to rotate logs: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Start-PerformanceTrace {
    <#
    .SYNOPSIS
        Start performance tracking for a named operation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$OperationName,

        [Parameter()]
        [hashtable]$Context = @{}
    )

    # Support both -Name and -OperationName for compatibility
    $opName = if ($OperationName) { $OperationName } else { $Name }

    if (-not $script:LoggingConfig.EnablePerformance) { return }

    $script:PerformanceCounters[$opName] = @{
        StartTime = Get-Date
        Context = $Context
    }

    Write-CustomLog "Performance trace started: $opName" -Level TRACE -Context $Context
}

function Stop-PerformanceTrace {
    <#
    .SYNOPSIS
        Stop performance tracking and log results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$OperationName,

        [Parameter()]
        [hashtable]$AdditionalContext = @{}
    )

    # Support both -Name and -OperationName for compatibility
    $opName = if ($OperationName) { $OperationName } else { $Name }

    if (-not $script:LoggingConfig.EnablePerformance -or -not $script:PerformanceCounters.ContainsKey($opName)) {
        return
    }

    $counter = $script:PerformanceCounters[$opName]
    $endTime = Get-Date
    $duration = $endTime - $counter.StartTime

    $context = $counter.Context + $AdditionalContext + @{
        Duration = "$($duration.TotalMilliseconds)ms"
        StartTime = $counter.StartTime
        EndTime = $endTime
    }

    Write-CustomLog "Performance trace completed: $opName" -Level TRACE -Context $context

    # Remove from tracking
    $script:PerformanceCounters.Remove($opName)

    # Return result for tests
    return @{
        Operation = $opName
        ElapsedMilliseconds = $duration.TotalMilliseconds
        ElapsedTicks = $duration.Ticks
        StartTime = $counter.StartTime
        EndTime = $endTime
    }
}

function Write-TraceLog {
    <#
    .SYNOPSIS
        Write trace-level logging with enhanced context
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [hashtable]$Context = @{},

        [Parameter()]
        [string]$Category
    )
      if (-not $script:LoggingConfig.EnableTrace) { return }

    # Get detailed call information
    $caller = Get-PSCallStack | Select-Object -Skip 1 -First 1
    $enhancedContext = $Context.Clone()

    # Only add Function if it doesn't already exist to avoid duplicate key error
    if (-not $enhancedContext.ContainsKey('Function')) {
        $enhancedContext.Function = $caller.FunctionName
    }

    $enhancedContext.Line = $caller.ScriptLineNumber
    $enhancedContext.Command = if ($caller.InvocationInfo.Line) { $caller.InvocationInfo.Line.Trim() } else { "" }

    Write-CustomLog -Message $Message -Level TRACE -Context $enhancedContext -Category $Category
}

function Write-DebugContext {
    <#
    .SYNOPSIS
        Write debug information with variable context
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Message = "Debug Context Information",

        [Parameter()]
        [hashtable]$Variables = @{},

        [Parameter()]
        [string]$Context,

        [Parameter()]
        [string]$Scope = "Local"
    )

    # Support both -Context and -Scope for compatibility
    $scopeValue = if ($Context) { $Context } else { $Scope }

    $contextData = $Variables.Clone()

    # Add scope information if debug level
    if ($script:LogLevels[$script:LoggingConfig.LogLevel] -ge $script:LogLevels["DEBUG"]) {
        $caller = Get-PSCallStack | Select-Object -Skip 1 -First 1
        $contextData.Scope = $scopeValue
        $contextData.Function = $caller.FunctionName
        $contextData.Script = Split-Path $caller.ScriptName -Leaf
    }

    Write-CustomLog -Message $Message -Level DEBUG -Context $contextData
}

function Get-LoggingConfiguration {
    <#
    .SYNOPSIS
        Get current logging configuration
    #>
    [CmdletBinding()]
    param()

    return $script:LoggingConfig.Clone()
}

function Set-LoggingConfiguration {
    <#
    .SYNOPSIS
        Update logging configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet("SILENT", "ERROR", "WARN", "INFO", "DEBUG", "TRACE", "VERBOSE")]
        [string]$LogLevel,

        [Parameter()]
        [ValidateSet("SILENT", "ERROR", "WARN", "INFO", "DEBUG", "TRACE", "VERBOSE")]
        [string]$ConsoleLevel,

        [Parameter()]
        [string]$LogFilePath,

        [Parameter()]
        [switch]$EnableTrace,

        [Parameter()]
        [switch]$DisableTrace,

        [Parameter()]
        [switch]$EnablePerformance,

        [Parameter()]
        [switch]$DisablePerformance
    )

    if ($LogLevel) { $script:LoggingConfig.LogLevel = $LogLevel }
    if ($ConsoleLevel) { $script:LoggingConfig.ConsoleLevel = $ConsoleLevel }
    if ($LogFilePath) { $script:LoggingConfig.LogFilePath = $LogFilePath }
    if ($EnableTrace) { $script:LoggingConfig.EnableTrace = $true }
    if ($DisableTrace) { $script:LoggingConfig.EnableTrace = $false }
    if ($EnablePerformance) { $script:LoggingConfig.EnablePerformance = $true }
    if ($DisablePerformance) { $script:LoggingConfig.EnablePerformance = $false }

    Write-CustomLog "Logging configuration updated" -Level INFO -Context $script:LoggingConfig
}

function Write-BulkLog {
    <#
    .SYNOPSIS
        Write multiple log entries efficiently (PowerShell 7+ optimized)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$LogEntries,

        [Parameter()]
        [string]$DefaultLevel = "INFO",

        [Parameter()]
        [hashtable]$DefaultContext = @{},

        [Parameter()]
        [switch]$Parallel
    )

    begin {
        $entriesToProcess = @()
    }

    process {
        $entriesToProcess += $LogEntries
    }

    end {
        if ($Parallel -and $entriesToProcess.Count -gt 10) {
            # Use parallel processing for large batches (PowerShell 7+ feature)
            $modulePath = Join-Path $env:PWSH_MODULES_PATH "Logging"
            $entriesToProcess | ForEach-Object -Parallel {
                $entry = $_
                $level = if ($entry.Level) { $entry.Level } else { $using:DefaultLevel }
                $context = if ($entry.Context) { $entry.Context } else { $using:DefaultContext }

                # Import the logging module in the parallel runspace
                Import-Module $using:modulePath -Force
                Write-CustomLog -Message $entry.Message -Level $level -Context $context
            } -ThrottleLimit 5
        } else {
            # Sequential processing for smaller batches
            foreach ($entry in $entriesToProcess) {
                $level = if ($entry.Level) { $entry.Level } else { $DefaultLevel }
                $context = if ($entry.Context) { $entry.Context } else { $DefaultContext }
                Write-CustomLog -Message $entry.Message -Level $level -Context $context
            }
        }
    }
}

function Test-LoggingPerformance {
    <#
    .SYNOPSIS
        Test logging system performance and return metrics
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$MessageCount = 1000,

        [Parameter()]
        [switch]$FileOnly,

        [Parameter()]
        [switch]$ConsoleOnly
    )

    Write-CustomLog "Starting logging performance test with $MessageCount messages" -Level INFO

    $testParams = @{}
    if ($FileOnly) { $testParams.NoConsole = $true }
    if ($ConsoleOnly) { $testParams.NoFile = $true }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    1..$MessageCount | ForEach-Object {
        Write-CustomLog -Message "Performance test message $_" -Level INFO @testParams
    }

    $stopwatch.Stop()

    $metrics = @{
        MessageCount = $MessageCount
        TotalTimeMs = $stopwatch.ElapsedMilliseconds
        MessagesPerSecond = [math]::Round($MessageCount / ($stopwatch.ElapsedMilliseconds / 1000), 2)
        AverageTimePerMessage = [math]::Round($stopwatch.ElapsedMilliseconds / $MessageCount, 3)
        TestConfiguration = @{
            FileOnly = $FileOnly.IsPresent
            ConsoleOnly = $ConsoleOnly.IsPresent
            LogLevel = $script:LoggingConfig.LogLevel
            EnablePerformance = $script:LoggingConfig.EnablePerformance
        }
    }

    Write-CustomLog "Performance test completed" -Level SUCCESS -Context $metrics
    return $metrics
}

# Export all functions (updated with new PowerShell 7+ features)
Export-ModuleMember -Function Write-CustomLog, Initialize-LoggingSystem, Start-PerformanceTrace, Stop-PerformanceTrace, Write-TraceLog, Write-DebugContext, Get-LoggingConfiguration, Set-LoggingConfiguration, Write-BulkLog, Test-LoggingPerformance

# Dot-source public functions
Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

# Initialize logging system on module import (after functions are defined)
# Only initialize if not already initialized
if (-not $script:LoggingConfig.Initialized) {
    try {
        # Auto-initialization should be silent to avoid duplicate "initialized" messages
        # The explicit Initialize-LoggingSystem call from core runner will show the message
        $script:LoggingConfig.LogToConsole = $false  # Temporarily disable console output
        Initialize-LoggingSystem -ErrorAction SilentlyContinue
        $script:LoggingConfig.LogToConsole = $true   # Re-enable console output
    }
    catch {
        # If initialization fails, continue with basic logging
        Write-Warning "Logging system initialization had issues, using basic configuration"
        $script:LoggingConfig.LogToConsole = $true   # Ensure console output is re-enabled
    }
}
