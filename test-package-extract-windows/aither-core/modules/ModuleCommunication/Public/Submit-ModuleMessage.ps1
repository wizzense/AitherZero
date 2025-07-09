function Submit-ModuleMessage {
    <#
    .SYNOPSIS
        Submits a message to a module communication channel
    .DESCRIPTION
        Sends a message to a specified channel for processing by registered handlers
    .PARAMETER Channel
        The name of the channel to send the message to
    .PARAMETER MessageType
        The type of message being sent
    .PARAMETER Data
        The data payload of the message
    .PARAMETER Priority
        The priority level of the message (Low, Normal, High, Critical)
    .PARAMETER Timeout
        Timeout in seconds for message delivery
    .EXAMPLE
        Submit-ModuleMessage -Channel "notifications" -MessageType "alert" -Data @{Level="Warning"; Message="System warning"}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Channel,

        [Parameter(Mandatory)]
        [string]$MessageType,

        [Parameter()]
        [hashtable]$Data = @{},

        [Parameter()]
        [ValidateSet('Low', 'Normal', 'High', 'Critical')]
        [string]$Priority = 'Normal',

        [Parameter()]
        [int]$Timeout = 30
    )

    try {
        # Validate channel exists
        if (-not $script:MessageBus.Channels.ContainsKey($Channel)) {
            throw "Channel '$Channel' does not exist. Use New-MessageChannel to create it first."
        }

        # Create message object
        $message = @{
            Id = [Guid]::NewGuid().ToString()
            Channel = $Channel
            MessageType = $MessageType
            Data = $Data
            Priority = $Priority
            Timestamp = Get-Date
            Timeout = $Timeout
            Source = if ($PSCmdlet.MyInvocation.ScriptName) { 
                Split-Path $PSCmdlet.MyInvocation.ScriptName -Leaf 
            } else { 
                'Interactive' 
            }
        }

        # Add to message queue for processing
        $script:MessageBus.MessageQueue.Enqueue($message)

        # Process message immediately if processor is running
        if ($script:MessageBus.Processor.Running) {
            Start-Sleep -Milliseconds 50  # Allow processor to pick up message
        }

        Write-CustomLog -Level 'INFO' -Message "Message submitted to channel '$Channel' with ID '$($message.Id)'"

        return $message.Id
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to submit message to channel '$Channel': $_"
        throw
    }
}