function Send-ModuleMessage {
    <#
    .SYNOPSIS
        Send a message to a module communication channel
    .DESCRIPTION
        Sends a message to all subscribers of a specific channel with optional filtering
    .PARAMETER Channel
        The channel to send to
    .PARAMETER MessageType
        Type of message for filtering
    .PARAMETER Data
        Message payload
    .PARAMETER SourceModule
        Module sending the message
    .PARAMETER Priority
        Message priority (Low, Normal, High)
    .PARAMETER TimeToLive
        Message expiration time in seconds
    .EXAMPLE
        Send-ModuleMessage -Channel "Configuration" -MessageType "ConfigChanged" -Data @{Module="LabRunner"; Setting="MaxJobs"} -SourceModule "ConfigurationCore"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Channel,
        
        [Parameter(Mandatory)]
        [string]$MessageType,
        
        [Parameter(Mandatory)]
        [object]$Data,
        
        [Parameter()]
        [string]$SourceModule = $MyInvocation.MyCommand.Module.Name,
        
        [Parameter()]
        [ValidateSet('Low', 'Normal', 'High')]
        [string]$Priority = 'Normal',
        
        [Parameter()]
        [int]$TimeToLive = 300
    )
    
    try {
        # Create message object
        $message = @{
            Id = [Guid]::NewGuid().ToString()
            Channel = $Channel
            MessageType = $MessageType
            Data = $Data
            SourceModule = $SourceModule
            Priority = $Priority
            Timestamp = Get-Date
            ExpiresAt = (Get-Date).AddSeconds($TimeToLive)
            ProcessedCount = 0
            Errors = @()
        }
        
        # Validate channel exists
        if (-not $script:MessageBus.Channels.ContainsKey($Channel)) {
            Write-CustomLog -Level 'WARNING' -Message "Channel '$Channel' does not exist. Creating it."
            New-MessageChannel -Name $Channel | Out-Null
        }
        
        # Add to message queue
        if ($script:MessageBus.MessageQueue.Count -ge $script:Configuration.MaxMessageQueueSize) {
            throw "Message queue is full (max: $($script:Configuration.MaxMessageQueueSize))"
        }
        
        $script:MessageBus.MessageQueue.Enqueue($message)
        
        # Trace if enabled
        if ($script:Configuration.EnableTracing) {
            Write-CustomLog -Level 'DEBUG' -Message "Message sent: Channel=$Channel, Type=$MessageType, ID=$($message.Id)"
        }
        
        # Wake up processor if high priority
        if ($Priority -eq 'High' -and $script:MessageBus.Processor.Running) {
            # Signal processor to process immediately
            [System.Threading.Thread]::Yield() | Out-Null
        }
        
        return $message.Id
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to send message: $_"
        throw
    }
}