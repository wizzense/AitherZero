#Requires -Version 7.0

<#
.SYNOPSIS
    Initialize logging system for all modules with fallback support (SHARED UTILITY)

.DESCRIPTION
    This shared utility provides a standardized way to initialize logging across all modules.
    It ensures that Write-CustomLog is always available, either from the Logging module or
    via a fallback implementation for isolated testing scenarios.

.PARAMETER Force
    Force re-initialization of logging system

.PARAMETER LogLevel
    Set specific log level during initialization

.PARAMETER NoImport
    Skip importing the Logging module, only provide fallback

.EXAMPLE
    # From any module:
    . "$PSScriptRoot/../../shared/Initialize-Logging.ps1"
    Initialize-Logging

.EXAMPLE
    # Force reinitialize with specific log level:
    Initialize-Logging -Force -LogLevel "DEBUG"

.NOTES
    This utility:
    1. Attempts to import the centralized Logging module
    2. Provides fallback Write-CustomLog implementation if needed
    3. Ensures consistent logging behavior across all modules
    4. Supports test isolation scenarios

    Usage pattern for modules:
    Add this to the top of any module (.psm1) file:
    . "$PSScriptRoot/../../shared/Initialize-Logging.ps1"
    Initialize-Logging
#>

function Initialize-Logging {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [ValidateSet("SILENT", "ERROR", "WARN", "INFO", "DEBUG", "TRACE", "VERBOSE")]
        [string]$LogLevel = "INFO",

        [Parameter()]
        [switch]$NoImport
    )

    # Skip if already initialized (unless forced)
    if (-not $Force -and (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        return
    }

    # Find project root for module imports
    $projectRoot = $null
    if (Test-Path "$PSScriptRoot/Find-ProjectRoot.ps1") {
        . "$PSScriptRoot/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
    } else {
        # Fallback project root detection
        $currentPath = $PSScriptRoot
        while ($currentPath -and $currentPath -ne (Split-Path $currentPath -Parent)) {
            if (Test-Path (Join-Path $currentPath "aither-core")) {
                $projectRoot = $currentPath
                break
            }
            $currentPath = Split-Path $currentPath -Parent
        }
    }

    # Try to import the centralized Logging module
    $loggingImported = $false
    if (-not $NoImport -and $projectRoot) {
        $loggingModulePath = Join-Path $projectRoot "aither-core" "shared" "Logging"
        if (Test-Path $loggingModulePath) {
            try {
                Import-Module $loggingModulePath -Force -ErrorAction Stop
                $loggingImported = $true
                Write-Verbose "Centralized Logging module imported successfully"
            } catch {
                Write-Verbose "Failed to import centralized Logging module: $($_.Exception.Message)"
            }
        }
    }

    # Provide fallback Write-CustomLog if needed
    if (-not $loggingImported -and -not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Global:Write-CustomLog {
            param(
                [Parameter(Mandatory)]
                [AllowEmptyString()]
                [string]$Message,

                [Parameter()]
                [ValidateSet("ERROR", "WARN", "INFO", "SUCCESS", "DEBUG", "TRACE", "VERBOSE")]
                [string]$Level = "INFO",

                [Parameter()]
                [string]$Source,

                [Parameter()]
                [hashtable]$Context = @{},

                [Parameter()]
                [switch]$NoConsole,

                [Parameter()]
                [switch]$NoFile,

                [Parameter()]
                [Exception]$Exception
            )

            # Simple fallback implementation for test isolation
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logEntry = "[$timestamp] [$Level] $Message"
            
            if ($Context.Count -gt 0) {
                $contextStr = ($Context.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "
                $logEntry += " {$contextStr}"
            }

            if ($Exception) {
                $logEntry += " Exception: $($Exception.Message)"
            }

            # Color coding for console output
            $color = switch ($Level) {
                'ERROR' { 'Red' }
                'WARN' { 'Yellow' }
                'SUCCESS' { 'Green' }
                'INFO' { 'Cyan' }
                'DEBUG' { 'DarkGray' }
                'TRACE' { 'Magenta' }
                'VERBOSE' { 'DarkCyan' }
                default { 'White' }
            }

            if (-not $NoConsole) {
                Write-Host $logEntry -ForegroundColor $color
            }

            # Basic file logging if available
            if (-not $NoFile -and $env:TEMP) {
                $logFile = Join-Path $env:TEMP "AitherZero-Fallback.log"
                try {
                    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
                } catch {
                    # Silently fail for fallback logging
                }
            }
        }
        
        Write-Verbose "Fallback Write-CustomLog function created"
    }

    # Initialize logging system if centralized module was imported
    if ($loggingImported -and (Get-Command Initialize-LoggingSystem -ErrorAction SilentlyContinue)) {
        try {
            Initialize-LoggingSystem -LogLevel $LogLevel -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "Failed to initialize logging system: $($_.Exception.Message)"
        }
    }
}

# Export the function for use when this file is imported as a module
if ($MyInvocation.InvocationName -ne '.') {
    Export-ModuleMember -Function Initialize-Logging
}