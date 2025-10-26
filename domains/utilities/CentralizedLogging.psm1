#Requires -Version 7.0

<#
.SYNOPSIS
    Centralized Logging Wrapper for AitherZero
.DESCRIPTION
    Provides simplified, consistent logging interface for all AitherZero components.
    Automatically loads the core Logging module and provides convenience functions.
.NOTES
    Copyright © 2025 Aitherium Corporation
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import core logging module
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:LoggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"

if (Test-Path $script:LoggingModule) {
    Import-Module $script:LoggingModule -Force -ErrorAction SilentlyContinue
}

# Check if core logging is available
$script:CoreLoggingAvailable = (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) -ne $null

function Write-Log {
    <#
    .SYNOPSIS
        Simplified logging function for all AitherZero components
    .DESCRIPTION
        Provides a simple interface to the centralized logging system with automatic source detection
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        Log level (Trace, Debug, Information, Warning, Error, Critical)
    .PARAMETER Data
        Additional structured data to log
    .PARAMETER Exception
        Exception object to log
    .PARAMETER Source
        Source component (auto-detected if not specified)
    .EXAMPLE
        Write-Log "Starting operation" -Level Information
    .EXAMPLE
        Write-Log "Configuration loaded" -Data @{ConfigPath = $path}
    .EXAMPLE
        Write-Log "Operation failed" -Level Error -Exception $_.Exception
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet('Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$Level = 'Information',

        [hashtable]$Data = @{},

        [System.Exception]$Exception,

        [string]$Source
    )

    # Auto-detect source if not provided
    if (-not $Source) {
        $callStack = Get-PSCallStack
        if ($callStack.Count -gt 1) {
            $caller = $callStack[1]
            if ($caller.ScriptName) {
                $Source = [System.IO.Path]::GetFileNameWithoutExtension($caller.ScriptName)
            } else {
                $Source = $caller.Command
            }
        } else {
            $Source = "AitherZero"
        }
    }

    # Use core logging if available, otherwise fallback
    if ($script:CoreLoggingAvailable) {
        Write-CustomLog -Level $Level -Message $Message -Source $Source -Data $Data -Exception $Exception
    } else {
        # Fallback to simple console logging
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $color = @{
            'Trace' = 'DarkGray'
            'Debug' = 'Gray'
            'Information' = 'White'
            'Warning' = 'Yellow'
            'Error' = 'Red'
            'Critical' = 'Magenta'
        }[$Level]

        $logMessage = "[$timestamp] [$Level] [$Source] $Message"
        Write-Host $logMessage -ForegroundColor $color

        if ($Data.Count -gt 0) {
            Write-Host "  Data: $($Data | ConvertTo-Json -Compress)" -ForegroundColor DarkGray
        }

        if ($Exception) {
            Write-Host "  Exception: $Exception" -ForegroundColor Red
        }
    }
}

# Convenience functions for each log level
function Write-TraceLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [hashtable]$Data = @{},
        [string]$Source
    )
    Write-Log -Message $Message -Level 'Trace' -Data $Data -Source $Source
}

function Write-DebugLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [hashtable]$Data = @{},
        [string]$Source
    )
    Write-Log -Message $Message -Level 'Debug' -Data $Data -Source $Source
}

function Write-InfoLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [hashtable]$Data = @{},
        [string]$Source
    )
    Write-Log -Message $Message -Level 'Information' -Data $Data -Source $Source
}

function Write-WarningLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [hashtable]$Data = @{},
        [string]$Source
    )
    Write-Log -Message $Message -Level 'Warning' -Data $Data -Source $Source
}

function Write-ErrorLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [hashtable]$Data = @{},
        [System.Exception]$Exception,
        [string]$Source
    )
    Write-Log -Message $Message -Level 'Error' -Data $Data -Exception $Exception -Source $Source
}

function Write-CriticalLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [hashtable]$Data = @{},
        [System.Exception]$Exception,
        [string]$Source
    )
    Write-Log -Message $Message -Level 'Critical' -Data $Data -Exception $Exception -Source $Source
}

function Start-LoggedOperation {
    <#
    .SYNOPSIS
        Start a logged operation with automatic tracking
    .DESCRIPTION
        Wraps an operation with automatic start/end logging and performance tracking
    .PARAMETER Name
        Operation name
    .PARAMETER Description
        Operation description
    .EXAMPLE
        Start-LoggedOperation -Name "DataProcessing" -Description "Processing user data"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Description = "",

        [hashtable]$Data = @{},

        [string]$Source
    )

    Write-Log "Starting operation: $Name" -Level Information -Data (@{
        OperationName = $Name
        Description = $Description
    } + $Data) -Source $Source

    # Start performance tracking if available
    if (Get-Command Start-PerformanceTrace -ErrorAction SilentlyContinue) {
        Start-PerformanceTrace -Name $Name -Description $Description
    }

    return @{
        Name = $Name
        StartTime = Get-Date
        Description = $Description
    }
}

function Stop-LoggedOperation {
    <#
    .SYNOPSIS
        Stop a logged operation
    .DESCRIPTION
        Completes an operation started with Start-LoggedOperation
    .PARAMETER Operation
        Operation object returned from Start-LoggedOperation
    .PARAMETER Success
        Whether the operation succeeded
    .PARAMETER Data
        Additional data to log
    .EXAMPLE
        Stop-LoggedOperation -Operation $op -Success $true
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Operation,

        [bool]$Success = $true,

        [hashtable]$Data = @{},

        [string]$Source
    )

    $duration = New-TimeSpan -Start $Operation.StartTime -End (Get-Date)

    $logData = @{
        OperationName = $Operation.Name
        Success = $Success
        DurationMs = $duration.TotalMilliseconds
        DurationFormatted = $duration.ToString("hh\:mm\:ss\.fff")
    } + $Data

    $level = if ($Success) { 'Information' } else { 'Error' }
    $status = if ($Success) { 'completed successfully' } else { 'failed' }

    Write-Log "Operation '$($Operation.Name)' $status" -Level $level -Data $logData -Source $Source

    # Stop performance tracking if available
    if (Get-Command Stop-PerformanceTrace -ErrorAction SilentlyContinue) {
        Stop-PerformanceTrace -Name $Operation.Name
    }
}

function Write-TestResultLog {
    <#
    .SYNOPSIS
        Log test results in a structured format
    .DESCRIPTION
        Logs test execution results with standardized format
    .PARAMETER TestName
        Name of the test
    .PARAMETER TestType
        Type of test (Unit, Integration, E2E, etc.)
    .PARAMETER Result
        Test result (Passed, Failed, Skipped)
    .PARAMETER Duration
        Test duration
    .PARAMETER Details
        Additional test details
    .EXAMPLE
        Write-TestResultLog -TestName "UserAuthTest" -TestType "Unit" -Result "Passed" -Duration 1.5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TestName,

        [ValidateSet('Unit', 'Integration', 'E2E', 'Performance', 'Security', 'Syntax')]
        [string]$TestType = 'Unit',

        [ValidateSet('Passed', 'Failed', 'Skipped', 'Inconclusive')]
        [string]$Result,

        [double]$Duration = 0,

        [hashtable]$Details = @{}
    )

    $level = switch ($Result) {
        'Passed' { 'Information' }
        'Failed' { 'Error' }
        'Skipped' { 'Warning' }
        'Inconclusive' { 'Warning' }
    }

    $data = @{
        TestName = $TestName
        TestType = $TestType
        Result = $Result
        DurationMs = $Duration
        Category = 'TestResult'
    } + $Details

    Write-Log "Test '$TestName' [$TestType]: $Result" -Level $level -Data $data -Source "Testing"
}

function Write-CodeAnalysisLog {
    <#
    .SYNOPSIS
        Log code analysis results
    .DESCRIPTION
        Logs PSScriptAnalyzer or other code analysis results
    .PARAMETER AnalyzerType
        Type of analyzer (PSScriptAnalyzer, ESLint, etc.)
    .PARAMETER FilePath
        File being analyzed
    .PARAMETER Severity
        Issue severity
    .PARAMETER RuleName
        Rule that was violated
    .PARAMETER Message
        Issue message
    .EXAMPLE
        Write-CodeAnalysisLog -FilePath "script.ps1" -Severity "Warning" -RuleName "PSAvoidUsingCmdletAliases"
    #>
    [CmdletBinding()]
    param(
        [string]$AnalyzerType = 'PSScriptAnalyzer',

        [Parameter(Mandatory)]
        [string]$FilePath,

        [ValidateSet('Error', 'Warning', 'Information')]
        [string]$Severity = 'Warning',

        [Parameter(Mandatory)]
        [string]$RuleName,

        [string]$Message = "",

        [hashtable]$Details = @{}
    )

    $level = switch ($Severity) {
        'Error' { 'Error' }
        'Warning' { 'Warning' }
        'Information' { 'Information' }
    }

    $data = @{
        AnalyzerType = $AnalyzerType
        FilePath = $FilePath
        Severity = $Severity
        RuleName = $RuleName
        Category = 'CodeAnalysis'
    } + $Details

    Write-Log "Code analysis issue in $FilePath - $RuleName: $Message" -Level $level -Data $data -Source "CodeAnalysis"
}

function Get-CentralizedLogPath {
    <#
    .SYNOPSIS
        Get the current centralized log directory path
    .DESCRIPTION
        Returns the path where all logs are being stored
    #>
    [CmdletBinding()]
    param()

    if (Get-Command Get-LogPath -ErrorAction SilentlyContinue) {
        return Split-Path (Get-LogPath) -Parent
    }

    return Join-Path $script:ProjectRoot "logs"
}

function Show-LogSummary {
    <#
    .SYNOPSIS
        Display a summary of recent log activity
    .DESCRIPTION
        Shows statistics and recent entries from all log files
    .PARAMETER Hours
        Number of hours to look back (default: 24)
    #>
    [CmdletBinding()]
    param(
        [int]$Hours = 24
    )

    $logPath = Get-CentralizedLogPath

    if (-not (Test-Path $logPath)) {
        Write-Host "No logs found at: $logPath" -ForegroundColor Yellow
        return
    }

    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              Centralized Log Summary                         ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $cutoff = (Get-Date).AddHours(-$Hours)

    # Get all log files
    $logFiles = Get-ChildItem -Path $logPath -Filter "*.log" | Where-Object { $_.LastWriteTime -gt $cutoff }

    Write-Host "Log Files (Last $Hours hours):" -ForegroundColor Yellow
    foreach ($file in $logFiles) {
        $lines = (Get-Content $file.FullName | Measure-Object -Line).Lines
        $size = [Math]::Round($file.Length / 1KB, 2)
        Write-Host "  📄 $($file.Name): $lines lines, $size KB" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "Log Directory: $logPath" -ForegroundColor Gray
}

# Export all functions
Export-ModuleMember -Function @(
    'Write-Log',
    'Write-TraceLog',
    'Write-DebugLog',
    'Write-InfoLog',
    'Write-WarningLog',
    'Write-ErrorLog',
    'Write-CriticalLog',
    'Start-LoggedOperation',
    'Stop-LoggedOperation',
    'Write-TestResultLog',
    'Write-CodeAnalysisLog',
    'Get-CentralizedLogPath',
    'Show-LogSummary'
)
