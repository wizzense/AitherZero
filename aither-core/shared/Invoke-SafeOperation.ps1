#Requires -Version 7.0

<#
.SYNOPSIS
    Standardized error handling utility for AitherZero operations (SHARED UTILITY)

.DESCRIPTION
    This shared utility provides consistent error handling patterns across the AitherZero
    codebase, with proper logging, context capture, and recovery mechanisms.

.PARAMETER Operation
    The operation to execute (ScriptBlock)

.PARAMETER OperationName
    Descriptive name for the operation (for logging)

.PARAMETER Context
    Additional context information for logging

.PARAMETER RetryCount
    Number of retry attempts (default: 0)

.PARAMETER RetryDelay
    Delay between retry attempts in seconds (default: 1)

.PARAMETER SuppressErrors
    Suppress error output and return null on failure

.PARAMETER ThrowOnError
    Throw exception on error (default behavior)

.PARAMETER LogLevel
    Log level for success messages (default: INFO)

.PARAMETER ErrorAction
    Error action preference (default: Stop)

.EXAMPLE
    # Basic safe operation:
    $result = Invoke-SafeOperation -Operation {
        Get-ChildItem -Path "C:\NonExistent" -ErrorAction Stop
    } -OperationName "List Directory"

.EXAMPLE
    # With retry logic:
    $result = Invoke-SafeOperation -Operation {
        Invoke-RestMethod -Uri "https://api.example.com/data"
    } -OperationName "API Call" -RetryCount 3 -RetryDelay 2

.EXAMPLE
    # Suppress errors and return null:
    $result = Invoke-SafeOperation -Operation {
        Import-Module "NonExistentModule" -ErrorAction Stop
    } -OperationName "Import Module" -SuppressErrors

.NOTES
    This utility:
    1. Provides consistent error handling patterns
    2. Integrates with centralized logging
    3. Supports retry mechanisms
    4. Captures detailed context information
    5. Offers flexible error handling strategies

    Usage pattern for functions:
    . "$PSScriptRoot/../../shared/Invoke-SafeOperation.ps1"
    $result = Invoke-SafeOperation -Operation { ... } -OperationName "..."
#>

function Invoke-SafeOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock]$Operation,

        [Parameter(Mandatory)]
        [string]$OperationName,

        [Parameter()]
        [hashtable]$Context = @{},

        [Parameter()]
        [int]$RetryCount = 0,

        [Parameter()]
        [int]$RetryDelay = 1,

        [Parameter()]
        [switch]$SuppressErrors,

        [Parameter()]
        [switch]$ThrowOnError,

        [Parameter()]
        [ValidateSet("ERROR", "WARN", "INFO", "SUCCESS", "DEBUG", "TRACE", "VERBOSE")]
        [string]$LogLevel = "INFO",

        [Parameter()]
        [System.Management.Automation.ActionPreference]$ErrorAction = 'Stop'
    )

    begin {
        # Ensure logging is available
        if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
            if (Test-Path "$PSScriptRoot/Initialize-Logging.ps1") {
                . "$PSScriptRoot/Initialize-Logging.ps1"
                Initialize-Logging
            } else {
                # Fallback logging
                function Write-CustomLog {
                    param($Message, $Level = "INFO", $Context = @{}, $Exception)
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $contextStr = if ($Context.Count -gt 0) { " {$($Context.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } | Join-String -Separator ', ')}" } else { "" }
                    $exceptionStr = if ($Exception) { " Exception: $($Exception.Message)" } else { "" }
                    Write-Host "[$timestamp] [$Level] $Message$contextStr$exceptionStr"
                }
            }
        }

        # Start performance tracking if available
        if (Get-Command Start-PerformanceTrace -ErrorAction SilentlyContinue) {
            Start-PerformanceTrace -Name $OperationName -Context $Context
        }

        $attempt = 0
        $maxAttempts = $RetryCount + 1
        $lastException = $null
    }

    process {
        do {
            $attempt++
            try {
                # Log operation start
                $attemptContext = $Context.Clone()
                $attemptContext.Attempt = $attempt
                $attemptContext.MaxAttempts = $maxAttempts
                
                Write-CustomLog -Message "Starting operation: $OperationName" -Level $LogLevel -Context $attemptContext

                # Execute the operation
                $result = & $Operation

                # Log success
                Write-CustomLog -Message "Operation completed successfully: $OperationName" -Level "SUCCESS" -Context $attemptContext

                # Stop performance tracking
                if (Get-Command Stop-PerformanceTrace -ErrorAction SilentlyContinue) {
                    Stop-PerformanceTrace -Name $OperationName -AdditionalContext @{ Success = $true }
                }

                return $result

            } catch {
                $lastException = $_.Exception
                $errorContext = $Context.Clone()
                $errorContext.Attempt = $attempt
                $errorContext.MaxAttempts = $maxAttempts
                $errorContext.ErrorType = $lastException.GetType().Name
                $errorContext.ErrorMessage = $lastException.Message

                # Log the error
                Write-CustomLog -Message "Operation failed: $OperationName" -Level "ERROR" -Context $errorContext -Exception $lastException

                # Check if we should retry
                if ($attempt -lt $maxAttempts) {
                    Write-CustomLog -Message "Retrying operation in $RetryDelay seconds: $OperationName" -Level "WARN" -Context $errorContext
                    Start-Sleep -Seconds $RetryDelay
                    continue
                }

                # All attempts failed
                break
            }
        } while ($attempt -lt $maxAttempts)

        # Handle final failure
        $finalErrorContext = $Context.Clone()
        $finalErrorContext.TotalAttempts = $attempt
        $finalErrorContext.FinalError = $lastException.Message

        Write-CustomLog -Message "Operation failed after $attempt attempts: $OperationName" -Level "ERROR" -Context $finalErrorContext -Exception $lastException

        # Stop performance tracking
        if (Get-Command Stop-PerformanceTrace -ErrorAction SilentlyContinue) {
            Stop-PerformanceTrace -Name $OperationName -AdditionalContext @{ Success = $false; Error = $lastException.Message }
        }

        # Handle error based on preferences
        if ($SuppressErrors) {
            return $null
        } elseif ($ThrowOnError -or $ErrorAction -eq 'Stop') {
            throw $lastException
        } else {
            return $null
        }
    }
}

function Invoke-SafeScript {
    <#
    .SYNOPSIS
        Execute a script file with standardized error handling
    
    .DESCRIPTION
        Wrapper around Invoke-SafeOperation for executing script files with proper
        error handling and logging.
    
    .PARAMETER ScriptPath
        Path to the script file to execute
    
    .PARAMETER Parameters
        Parameters to pass to the script
    
    .PARAMETER WorkingDirectory
        Working directory for script execution
    
    .EXAMPLE
        $result = Invoke-SafeScript -ScriptPath ".\scripts\deploy.ps1" -Parameters @{ Environment = "dev" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [Parameter()]
        [hashtable]$Parameters = @{},

        [Parameter()]
        [string]$WorkingDirectory,

        [Parameter()]
        [int]$RetryCount = 0,

        [Parameter()]
        [switch]$SuppressErrors
    )

    # Validate script path
    if (-not (Test-Path $ScriptPath)) {
        throw "Script file not found: $ScriptPath"
    }

    $scriptName = Split-Path $ScriptPath -Leaf
    $context = @{
        ScriptPath = $ScriptPath
        WorkingDirectory = $WorkingDirectory
        ParameterCount = $Parameters.Count
    }

    $operation = {
        $originalLocation = Get-Location
        try {
            if ($WorkingDirectory) {
                Set-Location $WorkingDirectory
            }

            if ($Parameters.Count -gt 0) {
                & $ScriptPath @Parameters
            } else {
                & $ScriptPath
            }
        } finally {
            Set-Location $originalLocation
        }
    }

    return Invoke-SafeOperation -Operation $operation -OperationName "Execute Script: $scriptName" -Context $context -RetryCount $RetryCount -SuppressErrors:$SuppressErrors
}

function Invoke-SafeModuleOperation {
    <#
    .SYNOPSIS
        Execute a module function with standardized error handling
    
    .DESCRIPTION
        Wrapper for executing module functions with proper error handling,
        module loading, and context capture.
    
    .PARAMETER ModuleName
        Name of the module containing the function
    
    .PARAMETER FunctionName
        Name of the function to execute
    
    .PARAMETER Parameters
        Parameters to pass to the function
    
    .EXAMPLE
        $result = Invoke-SafeModuleOperation -ModuleName "PatchManager" -FunctionName "New-Patch" -Parameters @{ Description = "Fix issue" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string]$FunctionName,

        [Parameter()]
        [hashtable]$Parameters = @{},

        [Parameter()]
        [int]$RetryCount = 0,

        [Parameter()]
        [switch]$SuppressErrors
    )

    $context = @{
        ModuleName = $ModuleName
        FunctionName = $FunctionName
        ParameterCount = $Parameters.Count
    }

    $operation = {
        # Ensure module is loaded
        if (-not (Get-Module $ModuleName -ErrorAction SilentlyContinue)) {
            if (Test-Path "$PSScriptRoot/Import-AitherModule.ps1") {
                . "$PSScriptRoot/Import-AitherModule.ps1"
                Import-AitherModule -ModuleName $ModuleName -Required
            } else {
                throw "Module not loaded and import utility not available: $ModuleName"
            }
        }

        # Execute the function
        $function = Get-Command $FunctionName -ErrorAction Stop
        if ($Parameters.Count -gt 0) {
            & $function @Parameters
        } else {
            & $function
        }
    }

    return Invoke-SafeOperation -Operation $operation -OperationName "Module Function: $ModuleName.$FunctionName" -Context $context -RetryCount $RetryCount -SuppressErrors:$SuppressErrors
}

# Export functions for use when this file is imported as a module
if ($MyInvocation.InvocationName -ne '.') {
    Export-ModuleMember -Function Invoke-SafeOperation, Invoke-SafeScript, Invoke-SafeModuleOperation
}