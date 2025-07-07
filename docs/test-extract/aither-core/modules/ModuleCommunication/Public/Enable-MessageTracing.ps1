function Enable-MessageTracing {
    <#
    .SYNOPSIS
        Enable detailed message tracing
    .DESCRIPTION
        Turns on detailed tracing for message bus operations
    .PARAMETER Level
        Tracing level (Basic, Detailed, Verbose)
    .PARAMETER LogToFile
        Also log traces to file
    .PARAMETER FilePath
        File path for trace logs
    .EXAMPLE
        Enable-MessageTracing -Level Detailed -LogToFile -FilePath "communication-trace.log"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Basic', 'Detailed', 'Verbose')]
        [string]$Level = 'Basic',
        
        [Parameter()]
        [switch]$LogToFile,
        
        [Parameter()]
        [string]$FilePath = "communication-trace-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    )
    
    try {
        $script:Configuration.EnableTracing = $true
        $script:Configuration.TracingLevel = $Level
        $script:Configuration.TracingToFile = $LogToFile.IsPresent
        $script:Configuration.TracingFilePath = $FilePath
        
        # Initialize trace file if needed
        if ($LogToFile) {
            $traceHeader = @"
# ModuleCommunication Trace Log
# Started: $(Get-Date)
# Level: $Level
# ===============================================

"@
            $traceHeader | Out-File -FilePath $FilePath -Encoding UTF8
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Message tracing enabled (Level: $Level)"
        
        # Log initial state
        $initialState = @{
            EnabledAt = Get-Date
            Level = $Level
            Channels = $script:MessageBus.Channels.Count
            Subscriptions = $script:MessageBus.Subscriptions.Count
            APIs = $script:APIRegistry.APIs.Count
            ProcessorRunning = $script:MessageBus.Processor.Running
        }
        
        if ($LogToFile) {
            "Initial State: $($initialState | ConvertTo-Json -Compress)" | Out-File -FilePath $FilePath -Append -Encoding UTF8
        }
        
        return @{
            Success = $true
            Level = $Level
            LogToFile = $LogToFile.IsPresent
            FilePath = if ($LogToFile) { $FilePath } else { $null }
            InitialState = $initialState
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to enable tracing: $_"
        throw
    }
}