#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Logging Enhancer - Adds detailed logging throughout the system
.DESCRIPTION
    Provides functions to add rich, contextual logging to all operations
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Global execution context
$script:ExecutionContext = @{
    SessionId = [Guid]::NewGuid().ToString()
    StartTime = Get-Date
    Operations = @()
    CurrentOperation = $null
}

function Start-LoggedOperation {
    <#
    .SYNOPSIS
        Start a logged operation with full context
    .DESCRIPTION
        Begins tracking an operation with detailed logging
    .PARAMETER Name
        Name of the operation
    .PARAMETER Details
        Additional details to log
    .EXAMPLE
        Start-LoggedOperation -Name "ScriptExecution" -Details @{Script="0218_Install-GeminiCLI.ps1"}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [hashtable]$Details = @{},
        
        [string]$Source = "Operation"
    )
    
    $operation = @{
        Id = [Guid]::NewGuid().ToString()
        Name = $Name
        StartTime = Get-Date
        Details = $Details
        Source = $Source
        Steps = @()
    }
    
    $script:ExecutionContext.CurrentOperation = $operation
    $script:ExecutionContext.Operations += $operation
    
    # Log operation start with full context
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level 'Information' -Message "Starting operation: $Name" -Source $Source -Data @{
            OperationId = $operation.Id
            SessionId = $script:ExecutionContext.SessionId
            Details = $Details
            User = if ($IsWindows) { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } else { $env:USER }
            WorkingDirectory = $PWD.Path
            ParentProcess = (Get-Process -Id $PID).Parent.ProcessName
            MemoryUsage = [Math]::Round((Get-Process -Id $PID).WorkingSet64 / 1MB, 2)
        }
    }
    
    return $operation.Id
}

function Add-LoggedStep {
    <#
    .SYNOPSIS
        Add a step to the current operation
    .PARAMETER StepName
        Name of the step
    .PARAMETER Details
        Step details
    .PARAMETER Status
        Step status (Started, InProgress, Completed, Failed)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StepName,
        
        [hashtable]$Details = @{},
        
        [ValidateSet('Started', 'InProgress', 'Completed', 'Failed', 'Skipped')]
        [string]$Status = 'Started'
    )
    
    if (-not $script:ExecutionContext.CurrentOperation) {
        Start-LoggedOperation -Name "Ad-hoc Operation" -Source "System"
    }
    
    $step = @{
        Name = $StepName
        Timestamp = Get-Date
        Status = $Status
        Details = $Details
    }
    
    $script:ExecutionContext.CurrentOperation.Steps += $step
    
    # Determine log level based on status
    $level = switch ($Status) {
        'Failed' { 'Error' }
        'Skipped' { 'Warning' }
        default { 'Information' }
    }
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $level -Message "Step: $StepName [$Status]" -Source $script:ExecutionContext.CurrentOperation.Source -Data @{
            OperationId = $script:ExecutionContext.CurrentOperation.Id
            OperationName = $script:ExecutionContext.CurrentOperation.Name
            StepDetails = $Details
            ElapsedTime = ((Get-Date) - $script:ExecutionContext.CurrentOperation.StartTime).TotalSeconds
        }
    }
}

function Stop-LoggedOperation {
    <#
    .SYNOPSIS
        Complete a logged operation
    .PARAMETER Success
        Whether the operation succeeded
    .PARAMETER Error
        Error message if failed
    #>
    [CmdletBinding()]
    param(
        [bool]$Success = $true,
        
        [string]$Error,
        
        [hashtable]$Results = @{}
    )
    
    if (-not $script:ExecutionContext.CurrentOperation) {
        return
    }
    
    $operation = $script:ExecutionContext.CurrentOperation
    $operation.EndTime = Get-Date
    $operation.Duration = $operation.EndTime - $operation.StartTime
    $operation.Success = $Success
    $operation.Error = $Error
    $operation.Results = $Results
    
    # Calculate statistics
    $stats = @{
        TotalSteps = $operation.Steps.Count
        CompletedSteps = ($operation.Steps | Where-Object { $_.Status -eq 'Completed' }).Count
        FailedSteps = ($operation.Steps | Where-Object { $_.Status -eq 'Failed' }).Count
        SkippedSteps = ($operation.Steps | Where-Object { $_.Status -eq 'Skipped' }).Count
    }
    
    $level = if ($Success) { 'Information' } else { 'Error' }
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $level -Message "Completed operation: $($operation.Name)" -Source $operation.Source -Data @{
            OperationId = $operation.Id
            Success = $Success
            Duration = $operation.Duration.TotalSeconds
            Statistics = $stats
            Results = $Results
            Error = $Error
        }
    }
    
    # Write performance metrics if available
    if (Get-Command Write-StructuredLog -ErrorAction SilentlyContinue) {
        Write-StructuredLog -Message "Operation metrics" -Properties @{
            Operation = $operation.Name
            Duration = $operation.Duration.TotalMilliseconds
            StepCount = $stats.TotalSteps
            Success = $Success
        } -Metrics @{
            duration_ms = $operation.Duration.TotalMilliseconds
            steps_total = $stats.TotalSteps
            steps_completed = $stats.CompletedSteps
            steps_failed = $stats.FailedSteps
            memory_mb = [Math]::Round((Get-Process -Id $PID).WorkingSet64 / 1MB, 2)
        } -Source "Metrics"
    }
    
    $script:ExecutionContext.CurrentOperation = $null
    
    return $operation
}

function Write-DetailedLog {
    <#
    .SYNOPSIS
        Write a detailed log entry with automatic context
    .PARAMETER Message
        Log message
    .PARAMETER Level
        Log level
    .PARAMETER Data
        Additional data
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$Level = 'Information',
        
        [hashtable]$Data = @{},
        
        [string]$Source
    )
    
    # Get calling context
    $caller = Get-PSCallStack | Select-Object -Skip 1 -First 1
    if (-not $Source) {
        $Source = if ($caller.Command) { $caller.Command } else { 'Script' }
    }
    
    # Add automatic context (merge, don't overwrite)
    $contextData = @{
        SessionId = $script:ExecutionContext.SessionId
        Caller = $caller.Command
        Location = "$($caller.ScriptName):$($caller.ScriptLineNumber)"
        StackDepth = (Get-PSCallStack).Count
    }
    
    # Merge with provided data
    foreach ($key in $Data.Keys) {
        if (-not $contextData.ContainsKey($key)) {
            $contextData[$key] = $Data[$key]
        }
    }
    
    if ($script:ExecutionContext.CurrentOperation) {
        $contextData['OperationId'] = $script:ExecutionContext.CurrentOperation.Id
        $contextData['OperationName'] = $script:ExecutionContext.CurrentOperation.Name
    }
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source $Source -Data $contextData
    } else {
        # Fallback
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $color = @{
            'Critical' = 'Magenta'
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
            'Trace' = 'DarkGray'
        }[$Level]
        
        Write-Host "[$timestamp] [$Level] [$Source] $Message $(if ($contextData.Count) { "| $($contextData | ConvertTo-Json -Compress)" })" -ForegroundColor $color
    }
}

function Get-OperationSummary {
    <#
    .SYNOPSIS
        Get summary of all operations in the session
    #>
    [CmdletBinding()]
    param()
    
    $summary = @{
        SessionId = $script:ExecutionContext.SessionId
        SessionDuration = (Get-Date) - $script:ExecutionContext.StartTime
        TotalOperations = $script:ExecutionContext.Operations.Count
        SuccessfulOperations = ($script:ExecutionContext.Operations | Where-Object { $_.Success }).Count
        FailedOperations = ($script:ExecutionContext.Operations | Where-Object { -not $_.Success }).Count
        Operations = @()
    }
    
    foreach ($op in $script:ExecutionContext.Operations) {
        $summary.Operations += @{
            Name = $op.Name
            Duration = if ($op.Duration) { $op.Duration.TotalSeconds } else { $null }
            Success = $op.Success
            StepCount = $op.Steps.Count
            StartTime = $op.StartTime
            EndTime = $op.EndTime
        }
    }
    
    return $summary
}

function Enable-VerboseLogging {
    <#
    .SYNOPSIS
        Enable verbose logging for troubleshooting
    #>
    [CmdletBinding()]
    param()
    
    if (Get-Command Set-LogLevel -ErrorAction SilentlyContinue) {
        Set-LogLevel -Level 'Debug'
    }
    
    $script:VerboseLogging = $true
    
    Write-DetailedLog -Message "Verbose logging enabled" -Level 'Information' -Data @{
        PreviousLevel = $script:LogLevel
        NewLevel = 'Debug'
    }
}

function Disable-VerboseLogging {
    <#
    .SYNOPSIS
        Disable verbose logging
    #>
    [CmdletBinding()]
    param()
    
    if (Get-Command Set-LogLevel -ErrorAction SilentlyContinue) {
        Set-LogLevel -Level 'Information'
    }
    
    $script:VerboseLogging = $false
    
    Write-DetailedLog -Message "Verbose logging disabled" -Level 'Information'
}

function Write-FunctionEntry {
    <#
    .SYNOPSIS
        Log function entry with parameters
    .PARAMETER FunctionName
        Name of the function
    .PARAMETER BoundParameters
        Parameters passed to function (use $PSBoundParameters)
    #>
    [CmdletBinding()]
    param(
        [string]$FunctionName,
        [hashtable]$BoundParameters = @{}
    )
    
    if ($script:VerboseLogging) {
        Write-DetailedLog -Message "Entering function: $FunctionName" -Level 'Debug' -Data @{
            Parameters = $BoundParameters
            ParameterCount = $BoundParameters.Count
        } -Source $FunctionName
    }
}

function Write-FunctionExit {
    <#
    .SYNOPSIS
        Log function exit with results
    .PARAMETER FunctionName
        Name of the function
    .PARAMETER Result
        Function result
    #>
    [CmdletBinding()]
    param(
        [string]$FunctionName,
        $Result
    )
    
    if ($script:VerboseLogging) {
        Write-DetailedLog -Message "Exiting function: $FunctionName" -Level 'Debug' -Data @{
            HasResult = ($null -ne $Result)
            ResultType = if ($Result) { $Result.GetType().Name } else { 'null' }
        } -Source $FunctionName
    }
}

# Initialize module
Write-DetailedLog -Message "LoggingEnhancer module loaded" -Level 'Debug' -Data @{
    SessionId = $script:ExecutionContext.SessionId
    Functions = @(
        'Start-LoggedOperation',
        'Add-LoggedStep',
        'Stop-LoggedOperation',
        'Write-DetailedLog',
        'Get-OperationSummary',
        'Enable-VerboseLogging',
        'Disable-VerboseLogging',
        'Write-FunctionEntry',
        'Write-FunctionExit'
    )
}

# Export functions
Export-ModuleMember -Function @(
    'Start-LoggedOperation',
    'Add-LoggedStep',
    'Stop-LoggedOperation',
    'Write-DetailedLog',
    'Get-OperationSummary',
    'Enable-VerboseLogging',
    'Disable-VerboseLogging',
    'Write-FunctionEntry',
    'Write-FunctionExit'
)