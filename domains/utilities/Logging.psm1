#Requires -Version 7.0

<#
.SYNOPSIS
    Unified logging service for AitherZero
.DESCRIPTION
    Provides structured logging with multiple targets, log levels, and performance tracking
#>

# Script variables
$script:LogPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "logs"
$script:LogLevel = "Information"
$script:LogTargets = @("Console", "File")  # Enable both console and file by default
$script:LogBuffer = @()
$script:BufferSize = 100
$script:LogRotation = @{
    Enabled = $false
    MaxSizeMB = 10
    MaxFiles = 5
}
$script:PerformanceTrackers = @{}
$script:AuditEnabled = $false
$script:IsInitialized = $false
$script:InitLogWritten = $false
$script:LogSchema = @{
    Version = "1.0"
    Fields = @('Timestamp', 'Level', 'Source', 'Message', 'Data', 'User', 'Computer', 'ProcessId', 'ThreadId')
}

# Log level enum
enum LogLevel {
    Trace = 0
    Debug = 1
    Information = 2
    Warning = 3
    Error = 4
    Critical = 5
}

function Write-CustomLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Source = "General",

        [hashtable]$Data = @{},

        [System.Exception]$Exception
    )

    # Check if we should log this based on configured level
    $currentLevel = [LogLevel]::$script:LogLevel
    $messageLevel = [LogLevel]::$Level

    if ($messageLevel -lt $currentLevel) {
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"

    # Create structured log entry
    $logEntry = [PSCustomObject]@{
        Timestamp = $timestamp
        Level = $Level
        Source = $Source
        Message = $Message
        Data = $Data
        Exception = if ($Exception) { $Exception.ToString() } else { $null }
        ProcessId = $PID
        ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        User = if ($IsWindows) { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } else { $env:USER }
        Computer = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { $env:HOSTNAME }
        SessionId = $Host.InstanceId
        ScriptPath = if ($MyInvocation.ScriptName) { $MyInvocation.ScriptName } else { 'Interactive' }
    }

    # Send to all configured targets
    foreach ($target in $script:LogTargets) {
        switch ($target) {
            'Console' { Write-LogToConsole -Entry $logEntry }
            'File' { Write-LogToFile -Entry $logEntry }
            'Json' { Write-LogToJson -Entry $logEntry }
            'EventLog' { Write-LogToEventLog -Entry $logEntry }
        }
    }

    # Add to buffer for batch operations
    $script:LogBuffer += $logEntry
    if ($script:LogBuffer.Count -ge $script:BufferSize) {
        Clear-LogBuffer -Flush
    }
}

# Clear buffered log entries (with optional flush to file)
function Clear-LogBuffer {
    [CmdletBinding()]
    param(
        [switch]$Flush
    )

    if ($script:LogBuffer.Count -eq 0) { return }

    try {
        if ($Flush) {
            # Write all buffered entries to file before clearing
            $script:LogBuffer | ForEach-Object {
                if ($script:LogFile) {
                    $_ | ConvertTo-Json -Compress | Add-Content -Path $script:LogFile -Encoding UTF8
                }
            }
        }

        # Clear the buffer
        $script:LogBuffer = @()
    }
    catch {
        Write-Warning "Failed to clear log buffer: $_"
    }
}

# Console logging
function Write-LogToConsole {
    param($Entry)

    $colors = @{
        'Trace' = 'DarkGray'
        'Debug' = 'Gray'
        'Information' = 'White'
        'Warning' = 'Yellow'
        'Error' = 'Red'
        'Critical' = 'Magenta'
    }

    $logMessage = "[$($Entry.Timestamp)] [$($Entry.Level.ToUpper().PadRight(11))] [$($Entry.Source)] $($Entry.Message)"

    if ($Entry.Data.Count -gt 0) {
        $logMessage += " | Data: $($Entry.Data | ConvertTo-Json -Compress)"
    }

    Write-Host $logMessage -ForegroundColor $colors[$Entry.Level]
}

# File logging
function Write-LogToFile {
    param($Entry)

    if (-not (Test-Path $script:LogPath)) {
        New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null
    }

    # Create separate log files by level
    $levelLogFiles = @{
        'Error' = Join-Path $script:LogPath "errors-$(Get-Date -Format 'yyyy-MM-dd').log"
        'Critical' = Join-Path $script:LogPath "critical-$(Get-Date -Format 'yyyy-MM-dd').log"
        'Warning' = Join-Path $script:LogPath "warnings-$(Get-Date -Format 'yyyy-MM-dd').log"
        'Debug' = Join-Path $script:LogPath "debug-$(Get-Date -Format 'yyyy-MM-dd').log"
        'Trace' = Join-Path $script:LogPath "trace-$(Get-Date -Format 'yyyy-MM-dd').log"
    }

    # Main combined log file
    $logFile = Join-Path $script:LogPath "aitherzero-$(Get-Date -Format 'yyyy-MM-dd').log"

    # Check rotation on main log file
    if ($script:LogRotation.Enabled) {
        Invoke-LogRotation -LogFile $logFile
    }

    $logMessage = "[$($Entry.Timestamp)] [$($Entry.Level.ToUpper().PadRight(11))] [$($Entry.Source)] $($Entry.Message)"

    # Add data if present
    if ($Entry.Data -and $Entry.Data.Count -gt 0) {
        $logMessage += " | Data: $($Entry.Data | ConvertTo-Json -Compress)"
    }

    if ($Entry.Exception) {
        $logMessage += "`n  Exception: $($Entry.Exception)"
    }

    # Write to main combined log
    Add-Content -Path $logFile -Value $logMessage

    # Write to level-specific log file if applicable
    if ($levelLogFiles.ContainsKey($Entry.Level)) {
        $levelLogFile = $levelLogFiles[$Entry.Level]
        Add-Content -Path $levelLogFile -Value $logMessage
    }
}

# JSON logging
function Write-LogToJson {
    param($Entry)

    if (-not (Test-Path $script:LogPath)) {
        New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null
    }

    $jsonFile = Join-Path $script:LogPath "aitherzero-$(Get-Date -Format 'yyyy-MM-dd').json"

    $jsonEntry = $Entry | ConvertTo-Json -Compress
    Add-Content -Path $jsonFile -Value $jsonEntry
}

# Event log logging (Windows only)
function Write-LogToEventLog {
    param($Entry)

    if ($PSVersionTable.Platform -eq 'Win32NT') {
        # Create event log source if it doesn't exist
        $source = "AitherZero"
        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            [System.Diagnostics.EventLog]::CreateEventSource($source, "Application")
        }

        $EventNameType = switch ($Entry.Level) {
            'Trace' { 'Information' }
            'Debug' { 'Information' }
            'Information' { 'Information' }
            'Warning' { 'Warning' }
            'Error' { 'Error' }
            'Critical' { 'Error' }
        }

        Write-EventLog -LogName Application -Source $source -EventId 1000 -EntryType $EventNameType -Message $Entry.Message
    }
}

# Buffer management is handled by the Clear-LogBuffer function above

# Log rotation
function Invoke-LogRotation {
    param(
        [string]$LogFile
    )

    if (-not (Test-Path $LogFile)) {
        return
    }

    $fileInfo = Get-Item $LogFile
    $sizeMB = $fileInfo.Length / 1MB

    if ($sizeMB -ge $script:LogRotation.MaxSizeMB) {
        # Rotate logs
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($LogFile)
        $extension = [System.IO.Path]::GetExtension($LogFile)
        $directory = [System.IO.Path]::GetDirectoryName($LogFile)

        # Shift existing rotated files
        for ($i = $script:LogRotation.MaxFiles - 1; $i -ge 1; $i--) {
            $oldFile = Join-Path $directory "$baseName.$i$extension"
            $newFile = Join-Path $directory "$baseName.$($i + 1)$extension"

            if (Test-Path $oldFile) {
                if ($i -eq $script:LogRotation.MaxFiles - 1) {
                    Remove-Item $oldFile -Force
                } else {
                    Move-Item $oldFile $newFile -Force
                }
            }
        }

        # Rotate current file
        Move-Item $LogFile (Join-Path $directory "$baseName.1$extension") -Force
    }
}

# Configuration functions
function Set-LogLevel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$Level
    )

    $script:LogLevel = $Level
}

function Set-LogTargets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Console', 'File', 'Json', 'EventLog')]
        [string[]]$Targets
    )

    $script:LogTargets = $Targets
}

function Enable-LogRotation {
    [CmdletBinding()]
    param(
        [int]$MaxSizeMB = 10,
        [int]$MaxFiles = 5
    )

    $script:LogRotation.Enabled = $true
    $script:LogRotation.MaxSizeMB = $MaxSizeMB
    $script:LogRotation.MaxFiles = $MaxFiles

    Write-CustomLog -Level 'Information' -Message "Log rotation enabled (MaxSize: ${MaxSizeMB}MB, MaxFiles: $MaxFiles)" -Source "Logging"
}

function Disable-LogRotation {
    $script:LogRotation.Enabled = $false
    Write-CustomLog -Level 'Information' -Message "Log rotation disabled" -Source "Logging"
}

# Performance tracking
function Start-PerformanceTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Description = ""
    )

    $script:PerformanceTrackers[$Name] = @{
        StartTime = Get-Date
        Description = $Description
    }

    Write-CustomLog -Level 'Debug' -Message "Performance trace started: $Name" -Source "Performance" -Data @{
        Description = $Description
    }
}

function Stop-PerformanceTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not $script:PerformanceTrackers.ContainsKey($Name)) {
        Write-CustomLog -Level 'Warning' -Message "Performance trace not found: $Name" -Source "Performance"
        return
    }

    $tracker = $script:PerformanceTrackers[$Name]
    $duration = New-TimeSpan -Start $tracker.StartTime -End (Get-Date)

    Write-CustomLog -Level 'Information' -Message "Performance trace completed: $Name" -Source "Performance" -Data @{
        DurationMs = $duration.TotalMilliseconds
        DurationFormatted = $duration.ToString("hh\:mm\:ss\.fff")
        Description = $tracker.Description
    }

    $script:PerformanceTrackers.Remove($Name)

    return $duration
}

# Log querying
function Get-Logs {
    [CmdletBinding()]
    param(
        [datetime]$StartTime,
        [datetime]$EndTime = (Get-Date),
        [string]$Level,
        [string]$Source,
        [string]$Pattern
    )

    $logFile = Join-Path $script:LogPath "aitherzero-$(Get-Date -Format 'yyyy-MM-dd').log"

    if (-not (Test-Path $logFile)) {
        Write-Warning "No log file found for today"
        return
    }

    $logs = Get-Content $logFile | ForEach-Object {
        if ($_ -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})\] \[(\w+)\s*\] \[(\w+)\] (.*)$') {
            [PSCustomObject]@{
                Timestamp = [datetime]$Matches[1]
                Level = $Matches[2].Trim()
                Source = $Matches[3]
                Message = $Matches[4]
            }
        }
    }

    # Apply filters
    if ($StartTime) {
        $logs = $logs | Where-Object { $_.Timestamp -ge $StartTime }
    }

    if ($Level) {
        $logs = $logs | Where-Object { $_.Level -eq $Level.ToUpper() }
    }

    if ($Source) {
        $logs = $logs | Where-Object { $_.Source -eq $Source }
    }

    if ($Pattern) {
        $logs = $logs | Where-Object { $_.Message -match $Pattern }
    }

    return $logs
}

# Clear logs
function Clear-Logs {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$DaysToKeep = 7
    )

    $cutoffDate = (Get-Date).AddDays(-$DaysToKeep)

    Get-ChildItem -Path $script:LogPath -Filter "*.log" | Where-Object {
        $_.LastWriteTime -lt $cutoffDate
    } | ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.Name, "Delete log file")) {
            Remove-Item $_.FullName -Force
            Write-CustomLog -Level 'Information' -Message "Deleted old log file: $($_.Name)" -Source "Logging"
        }
    }
}

# Get current log path
function Get-LogPath {
    # Return the actual log file path, not just the directory
    if (-not [string]::IsNullOrEmpty($script:LogPath)) {
        return Join-Path $script:LogPath "aitherzero-$(Get-Date -Format 'yyyy-MM-dd').log"
    }
    return $null
}

# Initialize logging from configuration
function Initialize-Logging {
    [CmdletBinding()]
    param(
        [PSCustomObject]$Configuration,
        [switch]$Force
    )

    if ($script:IsInitialized -and -not $Force) {
        return
    }

    $configDetails = @{}

    if ($Configuration.Logging) {
        if ($Configuration.Logging.Level) {
            $script:LogLevel = $Configuration.Logging.Level
            $configDetails['Level'] = $Configuration.Logging.Level
        }

        if ($Configuration.Logging.Targets) {
            $script:LogTargets = $Configuration.Logging.Targets
            $configDetails['Targets'] = $Configuration.Logging.Targets -join ', '
        }

        if ($Configuration.Logging.Path) {
            $script:LogPath = $Configuration.Logging.Path
            $configDetails['Path'] = $Configuration.Logging.Path
        }

        if ($Configuration.Logging.AuditLogging.Enabled) {
            $script:AuditEnabled = $true
            $configDetails['AuditEnabled'] = $true
        }
    }

    $script:IsInitialized = $true

    # Only log initialization once per PowerShell session (use global variable)
    if (-not $global:AitherZeroLoggingInitialized) {
        Write-CustomLog -Level 'Information' -Message "Logging system initialized with configuration" -Source "Logging" -Data $configDetails
        $global:AitherZeroLoggingInitialized = $true
    }
}

# Audit trail functions
function Write-AuditLog {
    <#
    .SYNOPSIS
        Write an audit trail entry for compliance and security tracking
    .DESCRIPTION
        Creates immutable audit log entries for critical operations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ScriptExecution', 'ConfigurationChange', 'AccessControl', 'DataModification', 'SystemChange', 'SecurityEvent')]
        [string]$EventNameType,

        [Parameter(Mandatory)]
        [string]$Action,

        [string]$Target,

        [hashtable]$Details = @{},

        [ValidateSet('Success', 'Failure', 'Warning')]
        [string]$Result = 'Success',

        [string]$UserOverride
    )

    if (-not $script:AuditEnabled) {
        return
    }

    $auditEntry = [PSCustomObject]@{
        AuditId = [Guid]::NewGuid().ToString()
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        EventType = $EventNameType
        Action = $Action
        Target = $Target
        Result = $Result
        Details = $Details
        User = if ($UserOverride) { $UserOverride } else { if ($IsWindows) { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } else { $env:USER } }
        Computer = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { $env:HOSTNAME }
        ProcessId = $PID
        ParentProcessId = (Get-Process -Id $PID).Parent.Id
        CommandLine = [System.Environment]::CommandLine
        WorkingDirectory = $PWD.Path
        SessionId = $Host.InstanceId
        CorrelationId = if ($script:CurrentCorrelationId) { $script:CurrentCorrelationId } else { [Guid]::NewGuid().ToString() }
    }

    # Write to audit log file (append-only)
    $auditPath = Join-Path $script:LogPath "audit"
    if (-not (Test-Path $auditPath)) {
        New-Item -ItemType Directory -Path $auditPath -Force | Out-Null
    }

    $auditFile = Join-Path $auditPath "audit-$(Get-Date -Format 'yyyy-MM').jsonl"
    $auditEntry | ConvertTo-Json -Compress | Add-Content -Path $auditFile -Encoding UTF8

    # Also write to regular log for visibility
    Write-CustomLog -Level 'Information' -Message "AUDIT: $Action on $Target" -Source "Audit-$EventNameType" -Data @{
        AuditId = $auditEntry.AuditId
        Result = $Result
    }
}

function Enable-AuditLogging {
    <#
    .SYNOPSIS
        Enable audit trail logging
    #>
    [CmdletBinding()]
    param(
        [string]$CorrelationId = [Guid]::NewGuid().ToString()
    )

    $script:AuditEnabled = $true
    $script:CurrentCorrelationId = $CorrelationId
    Write-CustomLog -Level 'Information' -Message "Audit logging enabled" -Source "Logging"
    Write-AuditLog -EventType 'SystemChange' -Action 'EnableAuditLogging' -Result 'Success'
}

function Disable-AuditLogging {
    <#
    .SYNOPSIS
        Disable audit trail logging
    #>
    [CmdletBinding()]
    param()

    Write-AuditLog -EventType 'SystemChange' -Action 'DisableAuditLogging' -Result 'Success'
    $script:AuditEnabled = $false
    $script:CurrentCorrelationId = $null
    Write-CustomLog -Level 'Information' -Message "Audit logging disabled" -Source "Logging"
}

function Get-AuditLogs {
    <#
    .SYNOPSIS
        Query audit logs with filtering
    #>
    [CmdletBinding()]
    param(
        [datetime]$StartTime,
        [datetime]$EndTime = (Get-Date),
        [string]$EventNameType,
        [string]$User,
        [string]$Action,
        [string]$Result,
        [string]$CorrelationId
    )

    $auditPath = Join-Path $script:LogPath "audit"
    if (-not (Test-Path $auditPath)) {
        Write-Warning "No audit logs found"
        return
    }

    $logs = @()

    # Get relevant audit files based on date range
    $files = Get-ChildItem -Path $auditPath -Filter "audit-*.jsonl" |
        Where-Object {
            $dateMatch = $_.Name -match 'audit-(\d{4}-\d{2})\.jsonl'
            if ($dateMatch) {
                $fileMonth = [DateTime]::ParseExact($Matches[1], 'yyyy-MM', $null)
                $fileMonth -ge [DateTime]::new($StartTime.Year, $StartTime.Month, 1) -and
                $fileMonth -le $EndTime.Date
            }
        }

    foreach ($file in $files) {
        $entries = Get-Content $file.FullName | ForEach-Object {
            $_ | ConvertFrom-Json
        }

        # Apply filters
        if ($StartTime) {
            $entries = $entries | Where-Object { [DateTime]$_.Timestamp -ge $StartTime }
        }

        if ($EndTime) {
            $entries = $entries | Where-Object { [DateTime]$_.Timestamp -le $EndTime }
        }

        if ($EventNameType) {
            $entries = $entries | Where-Object { $_.EventType -eq $EventNameType }
        }

        if ($User) {
            $entries = $entries | Where-Object { $_.User -like "*$User*" }
        }

        if ($Action) {
            $entries = $entries | Where-Object { $_.Action -like "*$Action*" }
        }

        if ($Result) {
            $entries = $entries | Where-Object { $_.Result -eq $Result }
        }

        if ($CorrelationId) {
            $entries = $entries | Where-Object { $_.CorrelationId -eq $CorrelationId }
        }

        $logs += $entries
    }

    return $logs | Sort-Object Timestamp
}

function Write-StructuredLog {
    <#
    .SYNOPSIS
        Write a fully structured log entry with custom schema
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [hashtable]$Properties = @{},

        [string]$Level = 'Information',

        [string]$Source = 'Application',

        [string[]]$Tags = @(),

        [string]$CorrelationId,

        [string]$OperationId,

        [hashtable]$Metrics = @{}
    )

    $structuredEntry = [ordered]@{
        '@timestamp' = Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss.fffK"
        '@version' = $script:LogSchema.Version
        'level' = $Level
        'message' = $Message
        'source' = $Source
        'properties' = $Properties
        'tags' = $Tags
        'correlation_id' = if ($CorrelationId) { $CorrelationId } else { $script:CurrentCorrelationId }
        'operation_id' = if ($OperationId) { $OperationId } else { [Guid]::NewGuid().ToString() }
        'metrics' = $Metrics
        'environment' = @{
            'user' = if ($IsWindows) { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } else { $env:USER }
            'computer' = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { $env:HOSTNAME }
            'process_id' = $PID
            'thread_id' = [System.Threading.Thread]::CurrentThread.ManagedThreadId
            'powershell_version' = $PSVersionTable.PSVersion.ToString()
            'os' = [System.Environment]::OSVersion.VersionString
        }
    }

    # Write to structured log file
    $structuredPath = Join-Path $script:LogPath "structured"
    if (-not (Test-Path $structuredPath)) {
        New-Item -ItemType Directory -Path $structuredPath -Force | Out-Null
    }

    $structuredFile = Join-Path $structuredPath "structured-$(Get-Date -Format 'yyyy-MM-dd').jsonl"
    $structuredEntry | ConvertTo-Json -Compress -Depth 10 | Add-Content -Path $structuredFile -Encoding UTF8

    # Also write using standard logging
    Write-CustomLog -Level $Level -Message $Message -Source $Source -Data $Properties
}

function Search-Logs {
    <#
    .SYNOPSIS
        Advanced log search with query language support
    #>
    [CmdletBinding()]
    param(
        [string]$Query,

        [string[]]$LogTypes = @('standard', 'structured', 'audit'),

        [datetime]$StartTime = (Get-Date).AddDays(-1),

        [datetime]$EndTime = (Get-Date),

        [int]$MaxResults = 1000,

        [switch]$IncludeArchived
    )

    $results = @()

    # Parse query (simple implementation - could be enhanced)
    $filters = @{}
    if ($Query) {
        # Support simple key:value queries
        $Query -split '\s+AND\s+' | ForEach-Object {
            if ($_ -match '(\w+):(.+)') {
                $filters[$Matches[1]] = $Matches[2].Trim('"', "'")
            }
        }
    }

    # Search each log type
    foreach ($logType in $LogTypes) {
        switch ($logType) {
            'standard' {
                $logs = Get-Logs -StartTime $StartTime -EndTime $EndTime
                if ($filters.Count -gt 0) {
                    foreach ($filter in $filters.GetEnumerator()) {
                        $logs = $logs | Where-Object { $_.$($filter.Key) -like "*$($filter.Value)*" }
                    }
                }
                $results += $logs | Select-Object -First $MaxResults
            }

            'structured' {
                $structuredPath = Join-Path $script:LogPath "structured"
                if (Test-Path $structuredPath) {
                    $files = Get-ChildItem -Path $structuredPath -Filter "structured-*.jsonl"
                    foreach ($file in $files) {
                        $entries = Get-Content $file.FullName | ForEach-Object {
                            $_ | ConvertFrom-Json
                        }

                        # Apply time filter
                        $entries = $entries | Where-Object {
                            $timestamp = [DateTime]$_.'@timestamp'
                            $timestamp -ge $StartTime -and $timestamp -le $EndTime
                        }

                        # Apply query filters
                        if ($filters.Count -gt 0) {
                            foreach ($filter in $filters.GetEnumerator()) {
                                $entries = $entries | Where-Object {
                                    $value = $_
                                    $filter.Key -split '\.' | ForEach-Object { $value = $value.$_ }
                                    $value -like "*$($filter.Value)*"
                                }
                            }
                        }

                        $results += $entries | Select-Object -First ($MaxResults - $results.Count)
                        if ($results.Count -ge $MaxResults) { break }
                    }
                }
            }

            'audit' {
                $auditFilters = @{}
                if ($filters.ContainsKey('EventType')) { $auditFilters['EventType'] = $filters['EventType'] }
                if ($filters.ContainsKey('User')) { $auditFilters['User'] = $filters['User'] }
                if ($filters.ContainsKey('Action')) { $auditFilters['Action'] = $filters['Action'] }

                $auditLogs = Get-AuditLogs -StartTime $StartTime -EndTime $EndTime @auditFilters
                $results += $auditLogs | Select-Object -First ($MaxResults - $results.Count)
            }
        }

        if ($results.Count -ge $MaxResults) { break }
    }

    return $results | Sort-Object Timestamp -Descending | Select-Object -First $MaxResults
}

function Export-LogReport {
    <#
    .SYNOPSIS
        Export logs in various report formats
    #>
    [CmdletBinding()]
    param(
        [datetime]$StartTime = (Get-Date).AddDays(-7),

        [datetime]$EndTime = (Get-Date),

        [ValidateSet('HTML', 'CSV', 'JSON', 'PDF')]
        [string]$Format = 'HTML',

        [string]$OutputPath = (Join-Path $script:LogPath "reports"),

        [switch]$IncludeAudit,

        [switch]$IncludeMetrics,

        [switch]$GroupBySource
    )

    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Gather log data
    $logData = @{
        StandardLogs = Get-Logs -StartTime $StartTime -EndTime $EndTime
        StructuredLogs = Search-Logs -LogTypes @('structured') -StartTime $StartTime -EndTime $EndTime
    }

    if ($IncludeAudit) {
        $logData.AuditLogs = Get-AuditLogs -StartTime $StartTime -EndTime $EndTime
    }

    # Generate report filename
    $reportName = "LogReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').$($Format.ToLower())"
    $reportPath = Join-Path $OutputPath $reportName

    switch ($Format) {
        'JSON' {
            $logData | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath
        }

        'CSV' {
            # Flatten and export as CSV
            $allLogs = @()
            $allLogs += $logData.StandardLogs
            $allLogs += $logData.StructuredLogs | Select-Object @{n='Timestamp';e={$_.'@timestamp'}}, level, message, source
            if ($IncludeAudit) {
                $allLogs += $logData.AuditLogs | Select-Object Timestamp, @{n='Level';e={'Audit'}}, @{n='Message';e={$_.Action}}, @{n='Source';e={$_.EventType}}
            }
            $allLogs | Export-Csv -Path $reportPath -NoTypeInformation
        }

        'HTML' {
            # Generate HTML report
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Log Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th { background-color: #007acc; color: white; padding: 10px; text-align: left; }
        td { padding: 8px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f5f5f5; }
        .error { color: red; }
        .warning { color: orange; }
        .info { color: blue; }
    </style>
</head>
<body>
    <h1>AitherZero Log Report</h1>
    <p>Period: $($StartTime.ToString('yyyy-MM-dd HH:mm:ss')) - $($EndTime.ToString('yyyy-MM-dd HH:mm:ss'))</p>
    <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
"@

            if ($GroupBySource) {
                $grouped = $logData.StandardLogs | Group-Object Source
                $html += "<h2>Logs by Source</h2>"
                foreach ($group in $grouped) {
                    $html += "<h3>$($group.Name) ($($group.Count) entries)</h3>"
                    $html += "<table><tr><th>Timestamp</th><th>Level</th><th>Message</th></tr>"
                    foreach ($log in $group.Group | Select-Object -First 100) {
                        $levelClass = @{Error='error';Warning='warning';Information='info'}[$log.Level]
                        $html += "<tr><td>$($log.Timestamp)</td><td class='$levelClass'>$($log.Level)</td><td>$($log.Message)</td></tr>"
                    }
                    $html += "</table>"
                }
            } else {
                $html += "<h2>All Logs</h2><table><tr><th>Timestamp</th><th>Level</th><th>Source</th><th>Message</th></tr>"
                foreach ($log in $logData.StandardLogs | Select-Object -First 1000) {
                    $levelClass = @{Error='error';Warning='warning';Information='info'}[$log.Level]
                    $html += "<tr><td>$($log.Timestamp)</td><td class='$levelClass'>$($log.Level)</td><td>$($log.Source)</td><td>$($log.Message)</td></tr>"
                }
                $html += "</table>"
            }

            $html += "</body></html>"
            $html | Set-Content -Path $reportPath
        }

        'PDF' {
            Write-Warning "PDF export not yet implemented"
            return $null
        }
    }

    Write-CustomLog -Level 'Information' -Message "Log report exported to: $reportPath" -Source "Logging"
    return $reportPath
}

# Auto-initialize logging on module load (only once per session)
if (-not $script:IsInitialized) {
    try {
        # Try to load configuration if available
        $configPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "config.psd1"
        if (Test-Path $configPath) {
            $config = Import-PowerShellDataFile $configPath
            if ($config.Logging) {
                Initialize-Logging -Configuration $config
            }
        }
    } catch {
        # Fallback to default settings
        $script:IsInitialized = $true
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Write-CustomLog',
    'Set-LogLevel',
    'Set-LogTargets',
    'Enable-LogRotation',
    'Disable-LogRotation',
    'Start-PerformanceTrace',
    'Stop-PerformanceTrace',
    'Get-Logs',
    'Clear-Logs',
    'Get-LogPath',
    'Initialize-Logging',
    'Clear-LogBuffer',
    'Write-AuditLog',
    'Enable-AuditLogging',
    'Disable-AuditLogging',
    'Get-AuditLogs',
    'Write-StructuredLog',
    'Search-Logs',
    'Export-LogReport'
)