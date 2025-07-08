function New-MessageChannel {
    <#
    .SYNOPSIS
        Create a new message channel
    .DESCRIPTION
        Creates a named channel for module communication
    .PARAMETER Name
        Name of the channel
    .PARAMETER Description
        Channel description
    .PARAMETER MaxMessages
        Maximum messages to queue in channel
    .PARAMETER MessageRetention
        How long to retain messages in seconds
    .EXAMPLE
        New-MessageChannel -Name "Configuration" -Description "Configuration change notifications"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$Description = '',

        [Parameter()]
        [int]$MaxMessages = 1000,

        [Parameter()]
        [int]$MessageRetention = 3600
    )

    try {
        # Check if channel already exists
        if ($script:MessageBus.Channels.ContainsKey($Name)) {
            Write-CustomLog -Level 'WARNING' -Message "Channel '$Name' already exists"
            return $script:MessageBus.Channels[$Name]
        }

        # Create channel
        $channel = @{
            Name = $Name
            Description = $Description
            CreatedAt = Get-Date
            MaxMessages = $MaxMessages
            MessageRetention = $MessageRetention
            MessageCount = 0
            SubscriptionCount = 0
            LastActivity = Get-Date
            Statistics = @{
                TotalMessages = 0
                DeliveredMessages = 0
                FailedDeliveries = 0
                ExpiredMessages = 0
            }
        }

        # Add to channels
        if ($script:MessageBus.Channels.TryAdd($Name, $channel)) {
            Write-CustomLog -Level 'SUCCESS' -Message "Channel created: $Name"

            # Publish channel creation event
            if (Get-Command 'Publish-ModuleEvent' -ErrorAction SilentlyContinue) {
                Publish-ModuleEvent -EventName 'ChannelCreated' -EventData @{
                    Channel = $Name
                    Description = $Description
                }
            }

            return $channel
        } else {
            throw "Failed to create channel"
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create channel: $_"
        throw
    }
}
