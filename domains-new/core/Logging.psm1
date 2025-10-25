#Requires -Version 7.0

<#
.SYNOPSIS
    Consolidated logging service for AitherZero
.DESCRIPTION
    Provides comprehensive structured logging with multiple targets, levels, and performance tracking.
    Consolidates all logging functionality from utilities domain modules.
.NOTES
    Consolidated from:
    - domains/utilities/Logging.psm1
    - domains/utilities/LogViewer.psm1 
    - domains/utilities/LoggingDashboard.psm1
    - domains/utilities/LoggingEnhancer.psm1
#>

# Script variables
$script:LogPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "logs"
$script:LogLevel = "Information"
$script:LogTargets = @("Console", "File")
$script:LogBuffer = @()
$script:BufferSize = 100
$script:LogFile = $null
$script:AuditEnabled = $false
$script:IsInitialized = $false

# Log level enum
enum LogLevel {
    Trace = 0
    Debug = 1
    Information = 2
    Warning = 3
    Error = 4
    Critical = 5
}

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initialize logging system with configuration
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$Level = "Information",
        
        [string]$Path = $script:LogPath,
        
        [ValidateSet('Console', 'File', 'Json', 'EventLog')]
        [string[]]$Targets = @("Console", "File"),
        
        [switch]$EnableAudit
    )

    $script:LogLevel = $Level
    $script:LogPath = $Path
    $script:LogTargets = $Targets
    $script:AuditEnabled = $EnableAudit.IsPresent

    # Ensure log directory exists
    if (-not (Test-Path $script:LogPath)) {
        New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null
    }

    # Set log file path
    $logFileName = "aitherzero-$(Get-Date -Format 'yyyy-MM-dd').log"
    $script:LogFile = Join-Path $script:LogPath $logFileName

    $script:IsInitialized = $true
    
    # Log initialization message
    Write-CustomLog -Level 'Information' -Message "Logging system initialized with configuration" -Source "Logging" -Data @{
        Level = $Level
        Path = $Path
        AuditEnabled = $EnableAudit.IsPresent
        Targets = ($Targets -join ', ')
    }
}

function Write-CustomLog {
    <#
    .SYNOPSIS
        Main logging function with structured output
    #>
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

    # Initialize logging if not already done
    if (-not $script:IsInitialized) {
        Initialize-Logging
    }

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

function Clear-LogBuffer {
    <#
    .SYNOPSIS
        Clear buffered log entries with optional flush
    #>
    [CmdletBinding()]
    param(
        [switch]$Flush
    )
    
    if ($script:LogBuffer.Count -eq 0) { return }
    
    try {
        if ($Flush -and $script:LogFile) {
            $script:LogBuffer | ForEach-Object {
                $_ | ConvertTo-Json -Compress | Add-Content -Path $script:LogFile -Encoding UTF8
            }
        }
        
        $script:LogBuffer = @()
    }
    catch {
        Write-Warning "Failed to clear log buffer: $_"
    }
}

function Write-LogToConsole {
    <#
    .SYNOPSIS
        Write log entry to console with color coding
    #>
    param($Entry)
    
    $colors = @{
        'Trace' = 'DarkGray'
        'Debug' = 'Gray'
        'Information' = 'White'
        'Warning' = 'Yellow'
        'Error' = 'Red'
        'Critical' = 'Magenta'
    }
    
    $logMessage = "[$($Entry.Timestamp)] [$($Entry.Level.ToUpper())] [$($Entry.Source)] $($Entry.Message)"

    if ($Entry.Data.Count -gt 0) {
        $logMessage += " | Data: $($Entry.Data | ConvertTo-Json -Compress)"
    }
    
    Write-Host $logMessage -ForegroundColor $colors[$Entry.Level]
}

function Write-LogToFile {
    <#
    .SYNOPSIS
        Write log entry to file
    #>
    param($Entry)
    
    if (-not $script:LogFile) { return }
    
    try {
        $logLine = "[$($Entry.Timestamp)] [$($Entry.Level)] [$($Entry.Source)] $($Entry.Message)"
        
        if ($Entry.Data.Count -gt 0) {
            $logLine += " | Data: $($Entry.Data | ConvertTo-Json -Compress)"
        }
        
        if ($Entry.Exception) {
            $logLine += " | Exception: $($Entry.Exception)"
        }
        
        Add-Content -Path $script:LogFile -Value $logLine -Encoding UTF8
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

function Write-LogToJson {
    <#
    .SYNOPSIS
        Write log entry as JSON
    #>
    param($Entry)
    
    if (-not $script:LogFile) { return }
    
    try {
        $jsonFile = $script:LogFile -replace '\.log$', '.json'
        $Entry | ConvertTo-Json -Compress | Add-Content -Path $jsonFile -Encoding UTF8
    }
    catch {
        Write-Warning "Failed to write JSON log: $_"
    }
}

function Write-LogToEventLog {
    <#
    .SYNOPSIS
        Write to Windows Event Log (Windows only)
    #>
    param($Entry)
    
    if (-not $IsWindows) { return }
    
    try {
        $eventTypes = @{
            'Information' = 'Information'
            'Warning' = 'Warning'
            'Error' = 'Error'
            'Critical' = 'Error'
            'Debug' = 'Information'
            'Trace' = 'Information'
        }
        
        Write-EventLog -LogName Application -Source "AitherZero" -EventId 1001 -EntryType $eventTypes[$Entry.Level] -Message "$($Entry.Source): $($Entry.Message)"
    }
    catch {
        # Event log writing failed - ignore silently
    }
}

function Write-AuditLog {
    <#
    .SYNOPSIS
        Write audit log entry
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,
        
        [string]$Resource,
        [string]$User,
        [hashtable]$Details = @{}
    )

    if (-not $script:AuditEnabled) { return }

    $auditData = @{
        Action = $Action
        Resource = $Resource
        User = $User
        Details = $Details
        AuditType = "Security"
    }

    Write-CustomLog -Level 'Information' -Message "Audit: $Action" -Source "Audit" -Data $auditData
}

function Enable-AuditLogging {
    <#
    .SYNOPSIS
        Enable audit logging
    #>
    [CmdletBinding()]
    param()

    $script:AuditEnabled = $true
    Write-CustomLog -Level 'Information' -Message "Audit logging enabled" -Source "Audit"
}

function Disable-AuditLogging {
    <#
    .SYNOPSIS
        Disable audit logging
    #>
    [CmdletBinding()]
    param()

    $script:AuditEnabled = $false
    Write-CustomLog -Level 'Information' -Message "Audit logging disabled" -Source "Audit"
}

function Get-LogFiles {
    <#
    .SYNOPSIS
        Get available log files
    #>
    [CmdletBinding()]
    param(
        [int]$Days = 30
    )

    if (-not (Test-Path $script:LogPath)) {
        return @()
    }

    $cutoffDate = (Get-Date).AddDays(-$Days)
    Get-ChildItem -Path $script:LogPath -Filter "*.log" | 
        Where-Object { $_.LastWriteTime -gt $cutoffDate } |
        Sort-Object LastWriteTime -Descending
}

function Search-Logs {
    <#
    .SYNOPSIS
        Search log files for specific patterns
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,
        
        [ValidateSet('Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$Level,
        
        [string]$Source,
        
        [int]$Days = 7
    )

    $logFiles = Get-LogFiles -Days $Days
    $results = @()

    foreach ($logFile in $logFiles) {
        $content = Get-Content $logFile.FullName | Where-Object { $_ -match $Pattern }
        
        if ($Level) {
            $content = $content | Where-Object { $_ -match "\[$Level\]" }
        }
        
        if ($Source) {
            $content = $content | Where-Object { $_ -match "\[$Source\]" }
        }
        
        $results += $content | ForEach-Object {
            [PSCustomObject]@{
                File = $logFile.Name
                Date = $logFile.LastWriteTime
                Line = $_
            }
        }
    }

    return $results
}

function Export-LogReport {
    <#
    .SYNOPSIS
        Export log analysis report
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath = (Join-Path $script:LogPath "log-report.html"),
        [int]$Days = 7
    )

    $logs = Get-LogFiles -Days $Days
    $totalEntries = 0
    $levelCounts = @{}
    
    foreach ($log in $logs) {
        $content = Get-Content $log.FullName
        $totalEntries += $content.Count
        
        foreach ($line in $content) {
            if ($line -match '\[([A-Z]+)\]') {
                $level = $matches[1]
                $levelCounts[$level] = ($levelCounts[$level] ?? 0) + 1
            }
        }
    }

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Log Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>AitherZero Log Report</h1>
    <p>Generated: $(Get-Date)</p>
    <p>Period: Last $Days days</p>
    
    <h2>Summary</h2>
    <p>Total log entries: $totalEntries</p>
    
    <h2>Log Levels</h2>
    <table>
        <tr><th>Level</th><th>Count</th></tr>
"@

    foreach ($level in $levelCounts.Keys | Sort-Object) {
        $html += "<tr><td>$level</td><td>$($levelCounts[$level])</td></tr>"
    }

    $html += @"
    </table>
    
    <h2>Log Files</h2>
    <table>
        <tr><th>File</th><th>Size (KB)</th><th>Last Modified</th></tr>
"@

    foreach ($log in $logs) {
        $sizeKB = [math]::Round($log.Length / 1024, 2)
        $html += "<tr><td>$($log.Name)</td><td>$sizeKB</td><td>$($log.LastWriteTime)</td></tr>"
    }

    $html += "</table></body></html>"
    
    Set-Content -Path $OutputPath -Value $html -Encoding UTF8
    Write-CustomLog -Message "Log report exported" -Source "Logging" -Data @{ Path = $OutputPath }
    
    return $OutputPath
}

# Specialized logging functions for different modules
function Write-ConfigLog {
    param([string]$Level = 'Information', [string]$Message, [hashtable]$Data = @{})
    Write-CustomLog -Level $Level -Message $Message -Source "Configuration" -Data $Data
}

function Write-UILog {
    param([string]$Level = 'Information', [string]$Message, [hashtable]$Data = @{})
    Write-CustomLog -Level $Level -Message $Message -Source "UserInterface" -Data $Data
}

function Write-TestingLog {
    param([string]$Level = 'Information', [string]$Message, [hashtable]$Data = @{})
    Write-CustomLog -Level $Level -Message $Message -Source "Testing" -Data $Data
}

function Write-InfraLog {
    param([string]$Level = 'Information', [string]$Message, [hashtable]$Data = @{})
    Write-CustomLog -Level $Level -Message $Message -Source "Infrastructure" -Data $Data
}

# Export functions
Export-ModuleMember -Function @(
    'Write-CustomLog',
    'Write-ConfigLog', 
    'Write-UILog',
    'Write-TestingLog', 
    'Write-InfraLog',
    'Write-AuditLog',
    'Initialize-Logging',
    'Clear-LogBuffer',
    'Enable-AuditLogging',
    'Disable-AuditLogging',
    'Get-LogFiles',
    'Search-Logs',
    'Export-LogReport'
)